class_name ConsoleReporter
extends RefCounted
## Human-readable console output reporter.
##
## Displays test results with optional ANSI colors for terminal output.

var use_colors: bool = true
var verbose: bool = false

## ANSI color codes
const RESET := "\u001b[0m"
const GREEN := "\u001b[32m"
const RED := "\u001b[31m"
const YELLOW := "\u001b[33m"
const CYAN := "\u001b[36m"
const DIM := "\u001b[2m"
const BOLD := "\u001b[1m"

## Status symbols
const PASS_SYMBOL := "\u2713"  # Check mark
const FAIL_SYMBOL := "\u2717"  # X mark
const SKIP_SYMBOL := "-"
const PENDING_SYMBOL := "?"


func _init(colors: bool = true, p_verbose: bool = false) -> void:
	use_colors = colors
	verbose = p_verbose


## Report start of test run.
func report_start(feature_count: int) -> void:
	_print("\n%s" % _colorize("Running %d feature(s)...\n" % feature_count, CYAN))


## Report feature start.
func report_feature_start(feature: GherkinAST.Feature) -> void:
	_print("%s %s" % [_colorize("Feature:", BOLD), feature.name])


## Report feature completion.
func report_feature_complete(result: TestResult.FeatureResult) -> void:
	if not verbose:
		return
	_print("")  # Extra line after feature


## Report scenario start.
func report_scenario_start(scenario: GherkinAST.Scenario) -> void:
	if verbose:
		_print("  %s %s" % [_colorize("Scenario:", BOLD), scenario.name])


## Report scenario completion.
func report_scenario_complete(result: TestResult.ScenarioResult) -> void:
	if verbose:
		# Print step details
		for step in result.step_results:
			var symbol := _get_status_symbol(step.status)
			var color := _get_status_color(step.status)
			_print("    %s %s %s" % [_colorize(symbol, color), step.keyword, step.step_text])

			if step.error_message:
				_print("      %s" % _colorize(step.error_message, RED))
	else:
		# Compact output - just show pass/fail for scenario
		var symbol := _get_status_symbol(result.status)
		var color := _get_status_color(result.status)
		_print(
			"  %s %s %s"
			% [_colorize(symbol, color), _colorize("Scenario:", DIM), result.scenario_name]
		)

		if result.error_message and result.status == TestResult.Status.FAILED:
			_print("    %s" % _colorize(result.error_message, RED))


## Report full suite results.
func report_results(result: TestResult.SuiteResult) -> void:
	_print("")

	# Summary line
	var passed := result.passed_scenarios()
	var failed := result.failed_scenarios()
	var total := result.total_scenarios()

	var summary_parts: Array[String] = []
	summary_parts.append("%d scenarios" % total)

	if passed > 0:
		summary_parts.append(_colorize("%d passed" % passed, GREEN))
	if failed > 0:
		summary_parts.append(_colorize("%d failed" % failed, RED))

	var skipped := result.skipped_scenarios()
	if skipped > 0:
		summary_parts.append(_colorize("%d skipped" % skipped, YELLOW))

	_print(", ".join(summary_parts))

	# Steps summary
	var step_parts: Array[String] = []
	step_parts.append("%d steps" % result.total_steps())
	if result.passed_steps() > 0:
		step_parts.append(_colorize("%d passed" % result.passed_steps(), GREEN))
	if result.failed_steps() > 0:
		step_parts.append(_colorize("%d failed" % result.failed_steps(), RED))

	_print(", ".join(step_parts))

	# Duration
	_print(
		_colorize("Finished in %.2fs" % (result.total_duration_ms / 1000.0), DIM)
	)

	# Undefined steps
	if result.undefined_steps.size() > 0:
		_print("")
		_print(_colorize("Undefined steps:", YELLOW))
		for step in result.undefined_steps:
			_print("  - %s" % step)

	_print("")


## Get the status symbol.
func _get_status_symbol(status: TestResult.Status) -> String:
	match status:
		TestResult.Status.PASSED:
			return PASS_SYMBOL
		TestResult.Status.FAILED:
			return FAIL_SYMBOL
		TestResult.Status.SKIPPED:
			return SKIP_SYMBOL
		TestResult.Status.PENDING, TestResult.Status.UNDEFINED:
			return PENDING_SYMBOL
		_:
			return "?"


## Get the color for a status.
func _get_status_color(status: TestResult.Status) -> String:
	match status:
		TestResult.Status.PASSED:
			return GREEN
		TestResult.Status.FAILED:
			return RED
		TestResult.Status.SKIPPED:
			return YELLOW
		TestResult.Status.PENDING, TestResult.Status.UNDEFINED:
			return YELLOW
		_:
			return RESET


## Apply ANSI color to text.
func _colorize(text: String, color: String) -> String:
	if use_colors:
		return color + text + RESET
	return text


## Print a line.
func _print(text: String) -> void:
	print(text)
