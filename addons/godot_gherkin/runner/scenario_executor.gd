class_name ScenarioExecutor
extends RefCounted
## Executes a single scenario with proper step handling.
##
## Manages step execution order, And/But keyword resolution,
## async step support, and result collection.

signal step_started(step: GherkinAST.Step)
signal step_completed(step: GherkinAST.Step, result: TestResult.StepResult)

var _registry: StepRegistry
var _context: TestContext
var _previous_keyword: String = "Given"


func _init(registry: StepRegistry, context: TestContext = null) -> void:
	_registry = registry
	_context = context if context else TestContext.new()


## Set the test context.
func set_context(context: TestContext) -> void:
	_context = context


## Get the current test context.
func get_context() -> TestContext:
	return _context


## Execute a scenario with optional background steps.
func execute_scenario(
	scenario: GherkinAST.Scenario, background: GherkinAST.Background = null
) -> TestResult.ScenarioResult:
	var result := TestResult.ScenarioResult.new()
	result.scenario_name = scenario.name
	result.tags = scenario.get_tag_names()
	result.line = scenario.location.line if scenario.location else 0
	result.status = TestResult.Status.PASSED

	var start_time := Time.get_ticks_msec()

	# Reset context for new scenario
	_context.reset()
	_previous_keyword = "Given"

	# Execute background steps first
	if background:
		for step in background.steps:
			var step_result := await _execute_step(step)
			result.step_results.append(step_result)

			if step_result.status != TestResult.Status.PASSED:
				result.status = step_result.status
				result.error_message = step_result.error_message
				# Skip remaining steps on failure
				_skip_remaining_steps(scenario.steps, result)
				break

	# Execute scenario steps (only if background passed)
	if result.status == TestResult.Status.PASSED:
		for step in scenario.steps:
			var step_result := await _execute_step(step)
			result.step_results.append(step_result)

			if step_result.status != TestResult.Status.PASSED:
				result.status = step_result.status
				result.error_message = step_result.error_message
				# Skip remaining steps
				var remaining := scenario.steps.slice(scenario.steps.find(step) + 1)
				_skip_remaining_steps(remaining, result)
				break

	result.duration_ms = Time.get_ticks_msec() - start_time
	return result


## Execute a single step.
func _execute_step(step: GherkinAST.Step) -> TestResult.StepResult:
	var result := TestResult.StepResult.new()
	result.step_text = step.text
	result.keyword = step.keyword
	result.line = step.location.line if step.location else 0

	step_started.emit(step)
	var start_time := Time.get_ticks_msec()

	# Resolve And/But to actual keyword for step lookup
	var effective_keyword := _resolve_keyword(step.keyword)

	# Find matching step definition
	var step_def := _registry.find_step(effective_keyword, step.text)

	if not step_def:
		result.status = TestResult.Status.UNDEFINED
		result.error_message = "No step definition found for: %s %s" % [step.keyword, step.text]
		result.duration_ms = Time.get_ticks_msec() - start_time
		step_completed.emit(step, result)
		return result

	# Execute the step
	var exec_result = step_def.execute(step.text, _context)

	# Handle async execution (if result is a coroutine)
	if exec_result is Object and exec_result.has_method("is_valid"):
		# This might be a signal or coroutine result
		exec_result = await exec_result

	# Check for execution errors
	if exec_result is Dictionary and exec_result.get("error", false):
		result.status = TestResult.Status.FAILED
		result.error_message = exec_result.get("message", "Step execution failed")
	elif _context.has_failures():
		result.status = TestResult.Status.FAILED
		result.error_message = _context.get_last_error()
	else:
		result.status = TestResult.Status.PASSED

	result.duration_ms = Time.get_ticks_msec() - start_time
	step_completed.emit(step, result)
	return result


## Resolve And/But/Asterisk to the previous effective keyword.
func _resolve_keyword(keyword: String) -> String:
	if keyword in ["And", "But", "*"]:
		return _previous_keyword

	_previous_keyword = keyword
	return keyword


## Mark remaining steps as skipped.
func _skip_remaining_steps(steps: Array, result: TestResult.ScenarioResult) -> void:
	for step: GherkinAST.Step in steps:
		var step_result := TestResult.StepResult.new()
		step_result.step_text = step.text
		step_result.keyword = step.keyword
		step_result.line = step.location.line if step.location else 0
		step_result.status = TestResult.Status.SKIPPED
		step_result.error_message = "Skipped due to previous failure"
		result.step_results.append(step_result)
