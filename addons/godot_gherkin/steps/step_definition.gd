class_name StepDefinition
extends RefCounted
## Represents a single step definition with its pattern and callback.
##
## Step definitions map Gherkin step text to executable GDScript functions.

## The original Cucumber Expression pattern.
var pattern: String = ""

## Compiled regex and parameter types.
var _compiled: StepMatcher.CompileResult = null

## The callback function to execute.
var callback: Callable

## The step type constraint ("Given", "When", "Then", or "" for any).
var step_type: String = ""

## Source location for debugging (optional).
var source_location: String = ""


func _init(
	p_pattern: String,
	p_callback: Callable,
	p_step_type: String = "",
	p_source: String = ""
) -> void:
	pattern = p_pattern
	callback = p_callback
	step_type = p_step_type
	source_location = p_source
	_compile()


## Compile the pattern to regex.
func _compile() -> void:
	_compiled = StepMatcher.compile_pattern(pattern)
	if not _compiled.success:
		push_error("Failed to compile step pattern '%s': %s" % [pattern, _compiled.error])


## Check if this step definition matches the given step text.
func matches(step_text: String) -> bool:
	if not _compiled or not _compiled.success:
		return false
	var match_result := StepMatcher.match_step(step_text, _compiled)
	return match_result.matched


## Get match result with extracted arguments.
func get_match(step_text: String) -> StepMatcher.MatchResult:
	if not _compiled or not _compiled.success:
		return StepMatcher.MatchResult.failure()
	return StepMatcher.match_step(step_text, _compiled)


## Execute the step with the given context and step text.
## Returns the result of the callback, or an error if execution fails.
func execute(step_text: String, context: Variant) -> Variant:
	var match_result := get_match(step_text)
	if not match_result.matched:
		return _create_error("Step does not match pattern: %s" % pattern)

	# Build arguments: context first, then extracted parameters
	var args: Array = [context]
	args.append_array(match_result.arguments)

	# Execute callback
	if not callback.is_valid():
		return _create_error("Step callback is not valid")

	return callback.callv(args)


## Execute the step asynchronously (returns result that may be a coroutine).
func execute_async(step_text: String, context: Variant) -> Variant:
	return execute(step_text, context)


## Get the compiled regex pattern (for debugging).
func get_regex_pattern() -> String:
	if _compiled and _compiled.regex:
		return _compiled.regex.get_pattern()
	return ""


## Get the parameter types (for introspection).
func get_parameter_types() -> Array[ParameterTypes.ParameterType]:
	if _compiled:
		return _compiled.param_types
	return []


## Check if compilation was successful.
func is_valid() -> bool:
	return _compiled != null and _compiled.success


## Create an error result.
func _create_error(message: String) -> Dictionary:
	return {"error": true, "message": message}


func _to_string() -> String:
	var type_str := step_type if step_type else "*"
	return "StepDefinition(%s '%s')" % [type_str, pattern]
