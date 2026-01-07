extends RefCounted
## Generates coverage reports in various formats.
##
## Self-reference for headless mode compatibility
const CoverageReporterScript = preload("res://addons/godot_gherkin/coverage/coverage_reporter.gd")
const CoverageTrackerScript = preload("res://addons/godot_gherkin/coverage/coverage_tracker.gd")
##
## Provides utilities for writing LCOV reports and printing console summaries.


## Write LCOV report to a file.
static func write_lcov(output_path: String) -> bool:
	var tracker := CoverageTrackerScript.get_instance()
	var lcov_content := tracker.generate_lcov()

	# Ensure directory exists
	var dir_path := output_path.get_base_dir()
	if not dir_path.is_empty():
		DirAccess.make_dir_recursive_absolute(_to_absolute(dir_path))

	var file := FileAccess.open(_to_absolute(output_path), FileAccess.WRITE)
	if not file:
		push_error("CoverageReporter: Could not write to %s" % output_path)
		return false

	file.store_string(lcov_content)
	file.close()
	return true


## Print coverage summary to console.
static func print_summary() -> void:
	var tracker := CoverageTrackerScript.get_instance()
	var summary := tracker.get_summary()

	if summary.files.is_empty():
		return

	print("")
	print("=== Coverage Summary ===")

	# Sort files by path
	var files: Array = summary.files
	files.sort_custom(func(a, b): return a.file < b.file)

	# Calculate column widths
	var max_path_len := 0
	for file_cov in files:
		var display_path := _shorten_path(file_cov.file)
		max_path_len = max(max_path_len, display_path.length())
	max_path_len = min(max_path_len, 40)  # Cap at 40 chars

	for file_cov in files:
		var display_path := _shorten_path(file_cov.file)
		if display_path.length() > max_path_len:
			display_path = "..." + display_path.right(max_path_len - 3)

		var pct_str := "%5.1f%%" % file_cov.percentage
		var lines_str := "(%d/%d lines)" % [file_cov.lines_hit, file_cov.lines_found]

		# Color based on coverage
		var color := _get_coverage_color(file_cov.percentage)
		print(
			(
				"  %s%s  %s %s%s"
				% [
					color,
					display_path.rpad(max_path_len),
					pct_str,
					lines_str,
					"\u001b[0m" if color else ""
				]
			)
		)

	# Print separator and total
	var separator := "─".repeat(max_path_len + 25)
	print("  %s" % separator)

	var total_color := _get_coverage_color(summary.percentage)
	print(
		(
			"  %sTotal:%s  %5.1f%% (%d/%d lines)%s"
			% [
				total_color,
				" ".repeat(max_path_len - 5),
				summary.percentage,
				summary.total_hit,
				summary.total_lines,
				"\u001b[0m" if total_color else ""
			]
		)
	)
	print("")


## Get ANSI color code based on coverage percentage.
static func _get_coverage_color(percentage: float) -> String:
	if percentage >= 80.0:
		return "\u001b[32m"  # Green
	if percentage >= 50.0:
		return "\u001b[33m"  # Yellow
	return "\u001b[31m"  # Red


## Shorten a resource path for display.
static func _shorten_path(path: String) -> String:
	# Remove res:// prefix
	if path.begins_with("res://"):
		path = path.substr(6)
	return path


## Convert a resource path to absolute filesystem path.
static func _to_absolute(path: String) -> String:
	if path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path
