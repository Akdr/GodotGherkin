class_name JsonReporter
extends RefCounted
## Machine-readable JSON output reporter.
##
## Produces JSON output suitable for parsing by AI assistants and automation tools.

var _output_path: String = ""
var _result: TestResult.SuiteResult = null


func _init(output_path: String = "") -> void:
	_output_path = output_path


## Report start of test run (no output for JSON).
func report_start(_feature_count: int) -> void:
	pass


## Report feature start (no output for JSON).
func report_feature_start(_feature: GherkinAST.Feature) -> void:
	pass


## Report feature completion (no output for JSON).
func report_feature_complete(_result: TestResult.FeatureResult) -> void:
	pass


## Report scenario start (no output for JSON).
func report_scenario_start(_scenario: GherkinAST.Scenario) -> void:
	pass


## Report scenario completion (no output for JSON).
func report_scenario_complete(_result: TestResult.ScenarioResult) -> void:
	pass


## Report full suite results as JSON.
func report_results(result: TestResult.SuiteResult) -> void:
	_result = result
	var json_output := result.to_json()

	if _output_path:
		_write_to_file(json_output)
	else:
		print(json_output)


## Get the result as a Dictionary (for programmatic access).
func get_result_dict() -> Dictionary:
	if _result:
		return _result.to_dict()
	return {}


## Get the result as JSON string.
func get_result_json() -> String:
	if _result:
		return _result.to_json()
	return "{}"


## Write JSON output to a file.
func _write_to_file(json_output: String) -> void:
	var file := FileAccess.open(_output_path, FileAccess.WRITE)
	if file:
		file.store_string(json_output)
		file.close()
	else:
		push_error("JsonReporter: Could not write to file: %s" % _output_path)
		# Fall back to stdout
		print(json_output)
