class_name GherkinTestRunner
extends RefCounted
## Orchestrates test execution across features and scenarios.
##
## Discovers feature files, loads step definitions, parses features,
## and executes scenarios with result aggregation.

signal run_started(feature_count: int)
signal run_completed(result: TestResult.SuiteResult)
signal feature_started(feature: GherkinAST.Feature)
signal feature_completed(result: TestResult.FeatureResult)
signal scenario_started(scenario: GherkinAST.Scenario)
signal scenario_completed(result: TestResult.ScenarioResult)

var _registry: StepRegistry
var _parser: GherkinParser
var _file_scanner: FileScanner
var _scene_tree: SceneTree = null

## Configuration
var features_path: String = "res://tests/features"
var steps_path: String = "res://tests/steps"
var tag_filter: Array[String] = []
var fail_fast: bool = false


func _init(scene_tree: SceneTree = null) -> void:
	_registry = StepRegistry.new()
	_parser = GherkinParser.new()
	_file_scanner = FileScanner.new()
	_scene_tree = scene_tree


## Set the SceneTree for async step support.
func set_scene_tree(tree: SceneTree) -> void:
	_scene_tree = tree


## Get the step registry for manual step registration.
func get_registry() -> StepRegistry:
	return _registry


## Run all tests in the configured paths.
func run_all() -> TestResult.SuiteResult:
	var suite_result := TestResult.SuiteResult.new()
	suite_result.start_time = Time.get_ticks_msec()

	# Load step definitions
	_load_steps(steps_path)

	# Find and parse all feature files
	var feature_files := _file_scanner.find_feature_files(features_path)
	run_started.emit(feature_files.size())

	for file_path in feature_files:
		var feature_result := await run_feature_file(file_path)
		suite_result.feature_results.append(feature_result)

		# Collect undefined steps
		for scenario in feature_result.scenario_results:
			if scenario.status == TestResult.Status.UNDEFINED:
				for step in scenario.step_results:
					if step.status == TestResult.Status.UNDEFINED:
						var step_sig := "%s %s" % [step.keyword, step.step_text]
						if not suite_result.undefined_steps.has(step_sig):
							suite_result.undefined_steps.append(step_sig)

		if fail_fast and not feature_result.is_passed():
			break

	suite_result.end_time = Time.get_ticks_msec()
	suite_result.total_duration_ms = suite_result.end_time - suite_result.start_time

	run_completed.emit(suite_result)
	return suite_result


## Run a specific feature file.
func run_feature_file(file_path: String) -> TestResult.FeatureResult:
	var content := FileScanner.read_file(file_path)
	if content.is_empty():
		var empty_result := TestResult.FeatureResult.new()
		empty_result.file_path = file_path
		empty_result.feature_name = "Error: Could not read file"
		return empty_result

	var feature := _parser.parse(content, file_path)
	return await run_feature(feature)


## Run a parsed feature.
func run_feature(feature: GherkinAST.Feature) -> TestResult.FeatureResult:
	var result := TestResult.FeatureResult.new()
	result.feature_name = feature.name
	result.file_path = feature.source_path
	result.tags = feature.get_tag_names()

	feature_started.emit(feature)
	var start_time := Time.get_ticks_msec()

	var executor := ScenarioExecutor.new(_registry)
	executor.set_context(TestContext.new(_scene_tree))

	# Run scenarios at feature level
	for scenario_item in feature.scenarios:
		# Check tag filter
		if not _matches_tag_filter(scenario_item):
			continue

		var scenario_result: TestResult.ScenarioResult

		if scenario_item is GherkinAST.ScenarioOutline:
			# Expand scenario outline into multiple scenarios
			var expanded := _expand_scenario_outline(scenario_item)
			for expanded_scenario in expanded:
				scenario_started.emit(expanded_scenario)
				scenario_result = await executor.execute_scenario(
					expanded_scenario, feature.background
				)
				scenario_result.feature_name = feature.name
				result.scenario_results.append(scenario_result)
				scenario_completed.emit(scenario_result)

				if fail_fast and not scenario_result.is_passed():
					break
		else:
			scenario_started.emit(scenario_item)
			scenario_result = await executor.execute_scenario(scenario_item, feature.background)
			scenario_result.feature_name = feature.name
			result.scenario_results.append(scenario_result)
			scenario_completed.emit(scenario_result)

		if fail_fast and result.scenario_results.size() > 0:
			if not result.scenario_results[-1].is_passed():
				break

	# Run scenarios within rules
	for rule in feature.rules:
		var rule_background := rule.background if rule.background else feature.background

		for scenario_item in rule.scenarios:
			if not _matches_tag_filter(scenario_item):
				continue

			var scenario_result: TestResult.ScenarioResult

			if scenario_item is GherkinAST.ScenarioOutline:
				var expanded := _expand_scenario_outline(scenario_item)
				for expanded_scenario in expanded:
					scenario_started.emit(expanded_scenario)
					scenario_result = await executor.execute_scenario(
						expanded_scenario, rule_background
					)
					scenario_result.feature_name = feature.name
					result.scenario_results.append(scenario_result)
					scenario_completed.emit(scenario_result)

					if fail_fast and not scenario_result.is_passed():
						break
			else:
				scenario_started.emit(scenario_item)
				scenario_result = await executor.execute_scenario(scenario_item, rule_background)
				scenario_result.feature_name = feature.name
				result.scenario_results.append(scenario_result)
				scenario_completed.emit(scenario_result)

			if fail_fast and result.scenario_results.size() > 0:
				if not result.scenario_results[-1].is_passed():
					break

		if fail_fast and not result.is_passed():
			break

	result.duration_ms = Time.get_ticks_msec() - start_time
	feature_completed.emit(result)
	return result


## Expand a scenario outline into concrete scenarios.
func _expand_scenario_outline(outline: GherkinAST.ScenarioOutline) -> Array[GherkinAST.Scenario]:
	var scenarios: Array[GherkinAST.Scenario] = []

	for examples in outline.examples:
		if not examples.table or examples.table.rows.size() < 2:
			continue  # Need header + at least one data row

		var headers := examples.table.get_headers()
		var data_rows := examples.table.get_data_rows()

		for row_idx in range(data_rows.size()):
			var row := data_rows[row_idx]
			var scenario := GherkinAST.Scenario.new()
			scenario.name = "%s (Example %d)" % [outline.name, row_idx + 1]
			scenario.tags = outline.tags.duplicate()
			scenario.location = outline.location

			# Replace placeholders in steps
			for step in outline.steps:
				var new_step := GherkinAST.Step.new()
				new_step.keyword = step.keyword
				new_step.location = step.location
				new_step.text = step.text

				# Replace <placeholder> with values
				var row_values := row.get_values()
				for col_idx in range(headers.size()):
					if col_idx < row_values.size():
						var placeholder := "<%s>" % headers[col_idx]
						new_step.text = new_step.text.replace(placeholder, row_values[col_idx])

				scenario.steps.append(new_step)

			scenarios.append(scenario)

	return scenarios


## Check if a scenario matches the tag filter.
func _matches_tag_filter(scenario: Variant) -> bool:
	if tag_filter.is_empty():
		return true

	var scenario_tags: Array[String] = []
	if scenario is GherkinAST.Scenario:
		scenario_tags = scenario.get_tag_names()
	elif scenario is GherkinAST.ScenarioOutline:
		scenario_tags = scenario.get_tag_names()

	for filter_tag in tag_filter:
		# Exclusion filter (starts with ~)
		if filter_tag.begins_with("~"):
			var excluded_tag := filter_tag.substr(1)
			if excluded_tag in scenario_tags:
				return false
		else:
			# Inclusion filter
			if filter_tag in scenario_tags:
				return true

	# If only exclusion filters, include by default
	var has_inclusion := false
	for filter_tag in tag_filter:
		if not filter_tag.begins_with("~"):
			has_inclusion = true
			break

	return not has_inclusion


## Load step definition files from the steps path.
func _load_steps(path: String) -> void:
	_registry.clear()

	if not FileScanner.dir_exists(path):
		push_warning("GherkinTestRunner: Steps directory not found: %s" % path)
		return

	var step_files := _file_scanner.find_step_files(path)

	for file_path in step_files:
		_load_step_file(file_path)


## Load a single step definition file.
func _load_step_file(file_path: String) -> void:
	var script := load(file_path) as GDScript
	if not script:
		push_warning("GherkinTestRunner: Could not load step file: %s" % file_path)
		return

	# Create instance and look for register_steps method
	var instance = script.new()
	if instance.has_method("register_steps"):
		instance.register_steps(_registry)
	else:
		push_warning("GherkinTestRunner: Step file missing register_steps method: %s" % file_path)
