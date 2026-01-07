extends RefCounted
## Instruments GDScript source code for coverage tracking.
##
## Self-reference for headless mode compatibility
const GDScriptInstrumentorScript = preload(
	"res://addons/godot_gherkin/coverage/gdscript_instrumentor.gd"
)
const GDScriptLexerScript = preload("res://addons/godot_gherkin/coverage/gdscript_lexer.gd")
const CoverageTrackerScript = preload("res://addons/godot_gherkin/coverage/coverage_tracker.gd")
##
## Transforms GDScript source by inserting coverage tracking calls
## at the beginning of each executable line.

## Template for coverage hit call
const HIT_TEMPLATE := 'CoverageTracker.hit("%s", %d)'

var _lexer: GDScriptLexerScript


func _init() -> void:
	_lexer = GDScriptLexerScript.new()


## Instrument a GDScript file and return the transformed source.
## Also registers the file with the coverage tracker.
func instrument_file(file_path: String) -> String:
	var source := _read_file(file_path)
	if source.is_empty():
		return ""

	return instrument_source(source, file_path)


## Instrument GDScript source code.
## Returns transformed source with coverage tracking calls inserted.
func instrument_source(source: String, file_path: String) -> String:
	var executable_lines := _lexer.get_executable_lines(source)

	if executable_lines.is_empty():
		return source

	# Register file with coverage tracker
	var tracker := CoverageTrackerScript.get_instance()
	tracker.register_file(file_path, executable_lines, source)

	# Transform source
	return _insert_coverage_calls(source, file_path, executable_lines)


## Insert coverage tracking calls into source.
func _insert_coverage_calls(source: String, file_path: String, lines: Array[int]) -> String:
	var source_lines := source.split("\n")
	var result := PackedStringArray()

	# Add import for coverage tracker at the top (after any extends/class_name)
	var insert_pos := _find_import_position(source_lines)

	for i in range(source_lines.size()):
		var line_num := i + 1
		var line := source_lines[i]

		# Insert coverage import after extends/class_name
		if i == insert_pos:
			result.append(
				(
					"const CoverageTracker = preload("
					+ '"res://addons/godot_gherkin/coverage/coverage_tracker.gd")'
				)
			)

		if line_num in lines:
			# Get the indentation of this line
			var indent := _get_indentation(line)
			# Insert coverage call before the line
			result.append("%s%s" % [indent, HIT_TEMPLATE % [file_path, line_num]])

		result.append(line)

	return "\n".join(result)


## Find the position to insert the coverage import.
## Should be after extends/class_name but before other code.
func _find_import_position(lines: Array) -> int:
	var pos := 0

	for i in range(lines.size()):
		var stripped: String = lines[i].strip_edges()

		# Skip empty lines and comments at the top
		if stripped.is_empty() or stripped.begins_with("#"):
			pos = i + 1
			continue

		# Skip extends and class_name
		if stripped.begins_with("extends ") or stripped.begins_with("class_name "):
			pos = i + 1
			continue

		# Stop at first real code
		break

	return pos


## Get the indentation (leading whitespace) of a line.
func _get_indentation(line: String) -> String:
	var indent := ""
	for c in line:
		if c == " " or c == "\t":
			indent += c
		else:
			break
	return indent


## Read a file and return its contents.
func _read_file(path: String) -> String:
	var abs_path := path
	if path.begins_with("res://"):
		abs_path = ProjectSettings.globalize_path(path)

	var file := FileAccess.open(abs_path, FileAccess.READ)
	if not file:
		push_error("GDScriptInstrumentor: Could not read file: %s" % path)
		return ""

	var content := file.get_as_text()
	file.close()
	return content


## Write instrumented source to a temporary file and return the path.
func write_instrumented(source: String, original_path: String) -> String:
	# Create a temp path for the instrumented file
	var temp_dir := "user://coverage_temp/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))

	# Generate temp filename based on original path
	var filename := original_path.get_file()
	var temp_path := temp_dir + filename

	var file := FileAccess.open(ProjectSettings.globalize_path(temp_path), FileAccess.WRITE)
	if not file:
		push_error("GDScriptInstrumentor: Could not write temp file: %s" % temp_path)
		return ""

	file.store_string(source)
	file.close()

	return temp_path


## Instrument multiple files matching include/exclude patterns.
## Returns dictionary of original_path -> instrumented_source
func instrument_files(
	include_patterns: Array[String], exclude_patterns: Array[String]
) -> Dictionary:
	var results := {}

	# Find all GDScript files
	var files := _find_gdscript_files(include_patterns, exclude_patterns)

	for file_path in files:
		var instrumented := instrument_file(file_path)
		if not instrumented.is_empty():
			results[file_path] = instrumented

	return results


## Find GDScript files matching patterns.
func _find_gdscript_files(
	include_patterns: Array[String], exclude_patterns: Array[String]
) -> Array[String]:
	var files: Array[String] = []

	# Default include pattern if none specified
	if include_patterns.is_empty():
		include_patterns = ["res://**/*.gd"]

	# Default exclude patterns
	if exclude_patterns.is_empty():
		exclude_patterns = ["res://addons/**"]

	# For now, do a simple recursive scan of res://
	# TODO: Implement proper glob matching
	_scan_directory("res://", files, include_patterns, exclude_patterns)

	return files


## Recursively scan a directory for GDScript files.
func _scan_directory(
	path: String,
	files: Array[String],
	include_patterns: Array[String],
	exclude_patterns: Array[String]
) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			# Check if directory should be excluded
			if not _matches_any_pattern(full_path + "/", exclude_patterns):
				_scan_directory(full_path, files, include_patterns, exclude_patterns)
		else:
			if file_name.ends_with(".gd"):
				# Check include/exclude patterns
				if _matches_any_pattern(full_path, include_patterns):
					if not _matches_any_pattern(full_path, exclude_patterns):
						files.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()


## Check if a path matches any of the given glob patterns.
func _matches_any_pattern(path: String, patterns: Array[String]) -> bool:
	for pattern in patterns:
		if _matches_glob(path, pattern):
			return true
	return false


## Simple glob pattern matching.
## Supports * (single segment) and ** (multiple segments).
func _matches_glob(path: String, pattern: String) -> bool:
	# Normalize paths
	path = path.replace("\\", "/")
	pattern = pattern.replace("\\", "/")

	# Handle ** (match any number of path segments)
	if "**" in pattern:
		var parts := pattern.split("**")
		if parts.size() == 2:
			var prefix := parts[0]
			var suffix := parts[1]

			# Check prefix
			if not prefix.is_empty() and not path.begins_with(prefix):
				return false

			# Check suffix (may contain wildcards like *.gd)
			if not suffix.is_empty():
				if suffix.begins_with("/"):
					suffix = suffix.substr(1)
				# Convert suffix wildcards to regex
				if "*" in suffix:
					var suffix_regex := suffix.replace(".", "\\.").replace("*", "[^/]*")
					var regex := RegEx.new()
					regex.compile(suffix_regex + "$")
					if not regex.search(path):
						return false
				elif not path.ends_with(suffix):
					return false

			return true

	# Handle * (match single segment)
	if "*" in pattern:
		var regex_pattern := pattern.replace(".", "\\.").replace("*", "[^/]*")
		var regex := RegEx.new()
		regex.compile("^" + regex_pattern + "$")
		return regex.search(path) != null

	# Exact match
	return path == pattern
