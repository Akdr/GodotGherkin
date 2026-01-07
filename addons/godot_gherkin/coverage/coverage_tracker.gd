extends RefCounted
## Tracks code coverage hits during test execution.
##
## Self-reference for headless mode compatibility
const CoverageTrackerScript = preload("res://addons/godot_gherkin/coverage/coverage_tracker.gd")
##
## Records which lines of instrumented code are executed and how many times.
## Used to generate coverage reports in LCOV format.

## Global singleton instance for coverage tracking.
static var _instance: CoverageTrackerScript = null

## Coverage data: file_path -> { line_number -> hit_count }
var _hits: Dictionary = {}

## Tracked files: file_path -> { "lines": total_executable_lines, "source": original_source }
var _files: Dictionary = {}

## Whether coverage is currently enabled.
var _enabled: bool = false


## Get the global singleton instance.
static func get_instance() -> CoverageTrackerScript:
	if not _instance:
		_instance = CoverageTrackerScript.new()
	return _instance


## Reset the global singleton (useful for testing).
static func reset_instance() -> void:
	_instance = null


## Enable coverage tracking.
func enable() -> void:
	_enabled = true


## Disable coverage tracking.
func disable() -> void:
	_enabled = false


## Check if coverage is enabled.
func is_enabled() -> bool:
	return _enabled


## Record a hit for a specific file and line.
## Called by instrumented code: CoverageTracker.hit("res://file.gd", 42)
static func hit(file_path: String, line: int) -> void:
	var instance := get_instance()
	if not instance._enabled:
		return

	# Auto-register file if not already registered
	if not instance._files.has(file_path):
		instance._files[file_path] = {"lines": [], "source": ""}

	if not instance._hits.has(file_path):
		instance._hits[file_path] = {}

	var file_hits: Dictionary = instance._hits[file_path]
	if not file_hits.has(line):
		file_hits[line] = 0
		# Add line to tracked lines if auto-registered
		var file_info: Dictionary = instance._files[file_path]
		var lines: Array = file_info.get("lines", [])
		if line not in lines:
			lines.append(line)
			file_info["lines"] = lines
	file_hits[line] += 1


## Register a file for coverage tracking.
## Called during instrumentation to track total executable lines.
func register_file(file_path: String, executable_lines: Array[int], source: String = "") -> void:
	_files[file_path] = {"lines": executable_lines, "source": source}
	# Initialize hits for all executable lines to 0
	if not _hits.has(file_path):
		_hits[file_path] = {}
	for line in executable_lines:
		if not _hits[file_path].has(line):
			_hits[file_path][line] = 0


## Get coverage data for a specific file.
func get_file_coverage(file_path: String) -> Dictionary:
	if not _files.has(file_path):
		return {}

	var file_info: Dictionary = _files[file_path]
	var file_hits: Dictionary = _hits.get(file_path, {})
	var executable_lines: Array = file_info.get("lines", [])

	var lines_found := executable_lines.size()
	var lines_hit := 0

	for line in executable_lines:
		if file_hits.get(line, 0) > 0:
			lines_hit += 1

	var percentage := 0.0
	if lines_found > 0:
		percentage = (float(lines_hit) / float(lines_found)) * 100.0

	return {
		"file": file_path,
		"lines_found": lines_found,
		"lines_hit": lines_hit,
		"percentage": percentage,
		"hits": file_hits.duplicate()
	}


## Get coverage summary for all tracked files.
func get_summary() -> Dictionary:
	var total_lines := 0
	var total_hit := 0
	var files: Array[Dictionary] = []

	for file_path in _files:
		var file_cov := get_file_coverage(file_path)
		files.append(file_cov)
		total_lines += file_cov.lines_found
		total_hit += file_cov.lines_hit

	var percentage := 0.0
	if total_lines > 0:
		percentage = (float(total_hit) / float(total_lines)) * 100.0

	return {
		"total_lines": total_lines, "total_hit": total_hit, "percentage": percentage, "files": files
	}


## Generate LCOV format report.
func generate_lcov() -> String:
	var output := PackedStringArray()
	output.append("TN:GodotGherkin Coverage")

	for file_path in _files:
		var file_info: Dictionary = _files[file_path]
		var file_hits: Dictionary = _hits.get(file_path, {})
		var executable_lines: Array = file_info.get("lines", [])

		output.append("SF:%s" % file_path)

		# Line data
		var lines_hit := 0
		for line in executable_lines:
			var hits: int = file_hits.get(line, 0)
			output.append("DA:%d,%d" % [line, hits])
			if hits > 0:
				lines_hit += 1

		# Summary
		output.append("LF:%d" % executable_lines.size())
		output.append("LH:%d" % lines_hit)
		output.append("end_of_record")

	return "\n".join(output)


## Clear all coverage data.
func clear() -> void:
	_hits.clear()
	_files.clear()


## Get list of tracked files.
func get_tracked_files() -> Array[String]:
	var files: Array[String] = []
	for file_path in _files:
		files.append(file_path)
	return files
