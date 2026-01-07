extends RefCounted
## Command-line interface for running Gherkin tests.
##
## Self-reference for headless mode compatibility
const GherkinCLIScript = preload("res://addons/godot_gherkin/runner/cli_runner.gd")
const GherkinTestRunnerScript = preload("res://addons/godot_gherkin/runner/test_runner.gd")
const GherkinASTScript = preload("res://addons/godot_gherkin/core/gherkin_ast.gd")
const GherkinParserScript = preload("res://addons/godot_gherkin/core/gherkin_parser.gd")
const TestResultScript = preload("res://addons/godot_gherkin/runner/test_result.gd")
const ConsoleReporterScript = preload(
	"res://addons/godot_gherkin/runner/reporters/console_reporter.gd"
)
const JsonReporterScript = preload("res://addons/godot_gherkin/runner/reporters/json_reporter.gd")
const FileScannerScript = preload("res://addons/godot_gherkin/util/file_scanner.gd")
const CoverageTrackerScript = preload("res://addons/godot_gherkin/coverage/coverage_tracker.gd")
const CoverageReporterScript = preload("res://addons/godot_gherkin/coverage/coverage_reporter.gd")
const GDScriptInstrumentorScript = preload(
	"res://addons/godot_gherkin/coverage/gdscript_instrumentor.gd"
)
##
## Parses command-line arguments and orchestrates test execution.
## Designed for headless execution with AI assistants and CI/CD systems.

## Exit codes
const EXIT_SUCCESS := 0
const EXIT_FAILURE := 1
const EXIT_ERROR := 2

var _runner: GherkinTestRunnerScript
var _reporter: Variant  # ConsoleReporter or JsonReporter
var _scene_tree: SceneTree = null

## Configuration from CLI args
var features_path: String = "res://tests/features"
var steps_path: String = "res://tests/steps"
var specific_feature: String = ""
var tags: Array[String] = []
var format: String = "console"
var output_path: String = ""
var verbose: bool = false
var dry_run: bool = false
var fail_fast: bool = false
var no_color: bool = false

## Coverage configuration
var coverage_enabled: bool = false
var coverage_output: String = ""  # Empty = stdout
var coverage_include: Array[String] = []
var coverage_exclude: Array[String] = []

## Internal coverage state
var _coverage_temp_dir := "res://tests/coverage/.temp/"
var _instrumented_files: Array[String] = []
var _is_coverage_subprocess := false


func _init(scene_tree: SceneTree = null) -> void:
	_scene_tree = scene_tree


## Run tests with the given command-line arguments.
## Returns exit code (0 = success, 1 = failures, 2 = error).
func run(args: PackedStringArray) -> int:
	# Parse arguments
	var parse_result := _parse_args(args)
	if parse_result != EXIT_SUCCESS:
		return parse_result

	# Create runner
	_runner = GherkinTestRunnerScript.new(_scene_tree)
	_runner.features_path = features_path
	_runner.steps_path = steps_path
	_runner.tag_filter = tags
	_runner.fail_fast = fail_fast

	# Create reporter
	_create_reporter()

	# Connect signals
	_runner.run_started.connect(_on_run_started)
	_runner.feature_started.connect(_on_feature_started)
	_runner.feature_completed.connect(_on_feature_completed)
	_runner.scenario_started.connect(_on_scenario_started)
	_runner.scenario_completed.connect(_on_scenario_completed)
	_runner.run_completed.connect(_on_run_completed)

	# Handle dry run
	if dry_run:
		return _do_dry_run()

	# Handle coverage - spawn subprocess with temp project
	if coverage_enabled and not _is_coverage_subprocess:
		return await _run_coverage_subprocess()

	# Enable coverage tracking if in subprocess
	if _is_coverage_subprocess:
		var tracker := CoverageTrackerScript.get_instance()
		tracker.clear()
		tracker.enable()

	# Run tests
	var result: TestResultScript.SuiteResult

	if specific_feature:
		# Run specific feature
		var feature_result := await _runner.run_feature_file(specific_feature)
		result = TestResultScript.SuiteResult.new()
		result.feature_results.append(feature_result)
		result.total_duration_ms = feature_result.duration_ms
	else:
		# Run all features
		result = await _runner.run_all()

	# Report results
	_reporter.report_results(result)

	# Generate coverage report if in subprocess
	if _is_coverage_subprocess:
		_output_coverage_report()

	# Return appropriate exit code
	if result.is_passed():
		return EXIT_SUCCESS
	return EXIT_FAILURE


## Parse command-line arguments.
func _parse_args(args: PackedStringArray) -> int:
	var i := 0

	while i < args.size():
		var arg := args[i]

		match arg:
			"--feature", "-f":
				i += 1
				if i >= args.size():
					_print_error("--feature requires a path argument")
					return EXIT_ERROR
				specific_feature = args[i]

			"--features":
				i += 1
				if i >= args.size():
					_print_error("--features requires a path argument")
					return EXIT_ERROR
				features_path = args[i]

			"--steps":
				i += 1
				if i >= args.size():
					_print_error("--steps requires a path argument")
					return EXIT_ERROR
				steps_path = args[i]

			"--tags", "-t":
				i += 1
				if i >= args.size():
					_print_error("--tags requires a tag argument")
					return EXIT_ERROR
				tags.append(args[i])

			"--format":
				i += 1
				if i >= args.size():
					_print_error("--format requires a format argument (console, json)")
					return EXIT_ERROR
				format = args[i]

			"--output", "-o":
				i += 1
				if i >= args.size():
					_print_error("--output requires a path argument")
					return EXIT_ERROR
				output_path = args[i]

			"--verbose", "-v":
				verbose = true

			"--dry-run":
				dry_run = true

			"--fail-fast":
				fail_fast = true

			"--no-color":
				no_color = true

			"--coverage":
				coverage_enabled = true

			"--coverage-subprocess":
				# Internal flag - running in temp project for coverage
				_is_coverage_subprocess = true
				coverage_enabled = true

			"--coverage-output":
				i += 1
				if i >= args.size():
					_print_error("--coverage-output requires a path argument")
					return EXIT_ERROR
				coverage_output = args[i]

			"--coverage-include":
				i += 1
				if i >= args.size():
					_print_error("--coverage-include requires a glob pattern argument")
					return EXIT_ERROR
				coverage_include.append(args[i])

			"--coverage-exclude":
				i += 1
				if i >= args.size():
					_print_error("--coverage-exclude requires a glob pattern argument")
					return EXIT_ERROR
				coverage_exclude.append(args[i])

			"--help", "-h":
				_print_help()
				return EXIT_ERROR

			_:
				if arg.begins_with("-"):
					_print_error("Unknown option: %s" % arg)
					return EXIT_ERROR

		i += 1

	return EXIT_SUCCESS


## Create the appropriate reporter.
func _create_reporter() -> void:
	match format:
		"json":
			_reporter = JsonReporterScript.new(output_path)
		_:
			_reporter = ConsoleReporterScript.new(not no_color, verbose)


## Do a dry run (list scenarios without executing).
func _do_dry_run() -> int:
	print("Dry run - listing scenarios:\n")

	var file_scanner := FileScannerScript.new()
	var parser := GherkinParserScript.new()
	var feature_files := file_scanner.find_feature_files(features_path)

	for file_path in feature_files:
		var content := FileScannerScript.read_file(file_path)
		var feature := parser.parse(content, file_path)

		print("Feature: %s" % feature.name)
		print("  File: %s" % file_path)

		for scenario in feature.scenarios:
			if scenario is GherkinASTScript.ScenarioOutline:
				var instance_count: int = scenario.get_instance_count()
				print("  - %s (%d examples)" % [scenario.name, instance_count])
			else:
				print("  - %s" % scenario.name)

		print("")

	return EXIT_SUCCESS


## Signal handlers
func _on_run_started(feature_count: int) -> void:
	_reporter.report_start(feature_count)


func _on_feature_started(feature: GherkinASTScript.Feature) -> void:
	_reporter.report_feature_start(feature)


func _on_feature_completed(result: TestResultScript.FeatureResult) -> void:
	_reporter.report_feature_complete(result)


func _on_scenario_started(scenario: GherkinASTScript.Scenario) -> void:
	_reporter.report_scenario_start(scenario)


func _on_scenario_completed(result: TestResultScript.ScenarioResult) -> void:
	_reporter.report_scenario_complete(result)


func _on_run_completed(_result: TestResultScript.SuiteResult) -> void:
	pass  # Results are reported in run()


## Print an error message.
func _print_error(message: String) -> void:
	printerr("Error: %s" % message)
	printerr("Use --help for usage information.")


## Run coverage by creating temp project and spawning subprocess.
func _run_coverage_subprocess() -> int:
	# Create temp project directory
	var abs_temp_dir := ProjectSettings.globalize_path(_coverage_temp_dir)
	_remove_dir_recursive(abs_temp_dir)
	DirAccess.make_dir_recursive_absolute(abs_temp_dir)

	# Copy essential project files
	var project_root := ProjectSettings.globalize_path("res://")
	_copy_file(project_root.path_join("project.godot"), abs_temp_dir.path_join("project.godot"))

	# Copy addon
	_copy_dir_recursive(
		ProjectSettings.globalize_path("res://addons/godot_gherkin"),
		abs_temp_dir.path_join("addons/godot_gherkin")
	)

	# Copy tests
	_copy_dir_recursive(
		ProjectSettings.globalize_path("res://tests"),
		abs_temp_dir.path_join("tests")
	)

	# Copy source directories from include patterns (before instrumentation overwrites them)
	for pattern in coverage_include:
		# Extract base directory before any wildcards
		var path := pattern.trim_prefix("res://")
		var wildcard_pos := path.find("*")
		if wildcard_pos > 0:
			path = path.substr(0, wildcard_pos).trim_suffix("/")
		var base_dir := path.get_base_dir() if "/" in path else path
		if not base_dir.is_empty():
			var src_dir := ProjectSettings.globalize_path("res://" + base_dir)
			var dst_dir := abs_temp_dir.path_join(base_dir)
			if DirAccess.dir_exists_absolute(src_dir):
				_copy_dir_recursive(src_dir, dst_dir)

	# Instrument target files and copy to temp
	var instrumentor := GDScriptInstrumentorScript.new()
	var files := instrumentor.instrument_files(coverage_include, coverage_exclude)

	if files.is_empty():
		if verbose:
			print("No files to instrument for coverage.")

	for file_path: String in files:
		var instrumented_source: String = files[file_path]
		var relative_path: String = file_path.trim_prefix("res://")
		var temp_file_path := abs_temp_dir.path_join(relative_path)

		# Ensure directory exists
		DirAccess.make_dir_recursive_absolute(temp_file_path.get_base_dir())

		# Write instrumented file
		var file := FileAccess.open(temp_file_path, FileAccess.WRITE)
		if file:
			file.store_string(instrumented_source)
			file.close()
			if verbose:
				print("  Instrumented: %s" % file_path)

	if verbose and not files.is_empty():
		print("Instrumented %d file(s) for coverage." % files.size())

	# Build subprocess arguments
	var godot_path := OS.get_executable_path()
	var subprocess_args := PackedStringArray([
		"--headless",
		"--path", abs_temp_dir,
		"--script", "tests/run_tests.gd",
		"--",
		"--coverage-subprocess"
	])

	# Pass through relevant arguments
	if not features_path.is_empty() and features_path != "res://tests/features":
		subprocess_args.append_array(["--features", features_path])
	if not steps_path.is_empty() and steps_path != "res://tests/steps":
		subprocess_args.append_array(["--steps", steps_path])
	if not specific_feature.is_empty():
		subprocess_args.append_array(["--feature", specific_feature])
	for tag in tags:
		subprocess_args.append_array(["--tags", tag])
	if format != "console":
		subprocess_args.append_array(["--format", format])
	if verbose:
		subprocess_args.append("--verbose")
	if fail_fast:
		subprocess_args.append("--fail-fast")
	if no_color:
		subprocess_args.append("--no-color")

	# Run subprocess and capture output
	var output := []
	var exit_code := OS.execute(godot_path, subprocess_args, output, true)

	# Print subprocess output
	for line in output:
		print(line)

	# Write coverage output to file if specified (in original project location)
	if not coverage_output.is_empty():
		# The LCOV data is in the subprocess output, extract and save it
		var lcov_content := _extract_lcov_from_output(output)
		if not lcov_content.is_empty():
			var abs_output := ProjectSettings.globalize_path(coverage_output)
			DirAccess.make_dir_recursive_absolute(abs_output.get_base_dir())
			var out_file := FileAccess.open(abs_output, FileAccess.WRITE)
			if out_file:
				out_file.store_string(lcov_content)
				out_file.close()
				print("Coverage report written to: %s" % coverage_output)

	# Clean up temp directory
	_remove_dir_recursive(abs_temp_dir)

	return exit_code


## Output coverage report (called in subprocess).
func _output_coverage_report() -> void:
	var tracker := CoverageTrackerScript.get_instance()
	tracker.disable()

	# Print console summary
	CoverageReporterScript.print_summary()

	# Output LCOV to stdout (parent process will capture it)
	print(tracker.generate_lcov())


## Extract LCOV content from subprocess output.
func _extract_lcov_from_output(output: Array) -> String:
	var lcov_lines := PackedStringArray()
	var in_lcov := false

	for line in output:
		var text: String = str(line)
		for subline in text.split("\n"):
			if subline.begins_with("TN:"):
				in_lcov = true
			if in_lcov:
				lcov_lines.append(subline)
				if subline == "end_of_record":
					# Check if more records follow
					pass

	return "\n".join(lcov_lines)


## Copy a single file.
func _copy_file(src: String, dst: String) -> void:
	var src_file := FileAccess.open(src, FileAccess.READ)
	if not src_file:
		return
	var content := src_file.get_as_text()
	src_file.close()

	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	var dst_file := FileAccess.open(dst, FileAccess.WRITE)
	if dst_file:
		dst_file.store_string(content)
		dst_file.close()


## Recursively copy a directory.
func _copy_dir_recursive(src: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(dst)

	var dir := DirAccess.open(src)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name != "." and file_name != "..":
			var src_path := src.path_join(file_name)
			var dst_path := dst.path_join(file_name)

			if dir.current_is_dir():
				_copy_dir_recursive(src_path, dst_path)
			else:
				_copy_file(src_path, dst_path)

		file_name = dir.get_next()

	dir.list_dir_end()


## Recursively remove a directory and its contents.
func _remove_dir_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path := path.path_join(file_name)
			if dir.current_is_dir():
				_remove_dir_recursive(full_path)
			else:
				DirAccess.remove_absolute(full_path)
		file_name = dir.get_next()

	dir.list_dir_end()
	DirAccess.remove_absolute(path)


## Print help message.
func _print_help() -> void:
	print(
		"""
GodotGherkin - BDD Testing Framework for Godot

Usage:
  godot --headless --script tests/run_tests.gd -- [options]

Options:
  --feature, -f <path>   Run a specific feature file
  --features <path>      Path to features directory (default: res://tests/features)
  --steps <path>         Path to steps directory (default: res://tests/steps)
  --tags, -t <tag>       Filter by tag (can be used multiple times)
                         Use ~@tag to exclude a tag
  --format <type>        Output format: console (default), json
  --output, -o <path>    Write output to file
  --verbose, -v          Show step details
  --dry-run              List scenarios without executing
  --fail-fast            Stop on first failure
  --no-color             Disable colored output
  --help, -h             Show this help message

Coverage Options:
  --coverage             Enable coverage (instruments, runs, restores automatically)
  --coverage-output <path>   Write LCOV to file (default: stdout)
  --coverage-include <glob>  Files to include (can repeat, e.g. "res://src/**/*.gd")
  --coverage-exclude <glob>  Files to exclude (can repeat, e.g. "res://addons/**")

Examples:
  # Run all tests
  godot --headless --script tests/run_tests.gd

  # Run specific feature
  godot --headless --script tests/run_tests.gd -- --feature tests/features/login.feature

  # Run with tags
  godot --headless --script tests/run_tests.gd -- --tags @smoke --tags ~@slow

  # JSON output
  godot --headless --script tests/run_tests.gd -- --format json

  # Run with coverage
  godot --headless --script tests/run_tests.gd -- --coverage --coverage-include "res://src/**/*.gd"

Exit Codes:
  0  All tests passed
  1  One or more tests failed
  2  Error (invalid arguments, missing files, etc.)
"""
	)
