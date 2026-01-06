extends RefCounted
## Shared state and assertions for step execution.
##
## Self-reference for headless mode compatibility
const TestContextScript = preload("res://addons/godot_gherkin/runner/test_context.gd")
##
## Each scenario gets a fresh TestContext that persists across steps
## within that scenario. Provides state storage and assertion helpers.

## Scenario-scoped state storage.
var _state: Dictionary = {}

## Optional SceneTree reference for async operations.
var _scene_tree: SceneTree = null

## Current scene for scene-based testing.
var _current_scene: Node = null

## Assertion tracking.
var assertions_passed: int = 0
var assertions_failed: int = 0
var _last_error: String = ""


func _init(scene_tree: SceneTree = null) -> void:
	_scene_tree = scene_tree


# === State Management ===


## Set a value in the context state.
func set_value(key: String, value: Variant) -> void:
	_state[key] = value


## Get a value from the context state.
func get_value(key: String, default: Variant = null) -> Variant:
	return _state.get(key, default)


## Check if a key exists in the state.
func has_value(key: String) -> bool:
	return _state.has(key)


## Remove a value from the state.
func remove_value(key: String) -> void:
	_state.erase(key)


## Clear all state.
func clear_state() -> void:
	_state.clear()


## Clear all state and reset counters.
func reset() -> void:
	_state.clear()
	assertions_passed = 0
	assertions_failed = 0
	_last_error = ""
	free_scene()


# === SceneTree Access ===


## Get the SceneTree (may be null in headless mode).
func get_tree() -> SceneTree:
	return _scene_tree


## Set the SceneTree reference.
func set_tree(tree: SceneTree) -> void:
	_scene_tree = tree


## Check if SceneTree is available.
func has_tree() -> bool:
	return _scene_tree != null


# === Scene Management ===


## Load and instantiate a scene.
func load_scene(path: String) -> Node:
	free_scene()

	var packed := load(path) as PackedScene
	if not packed:
		_record_error("Failed to load scene: %s" % path)
		return null

	_current_scene = packed.instantiate()

	if _scene_tree:
		_scene_tree.root.add_child(_current_scene)

	return _current_scene


## Get the current scene.
func get_scene() -> Node:
	return _current_scene


## Get a node from the current scene by path.
func get_node(path: String) -> Node:
	if _current_scene:
		return _current_scene.get_node_or_null(path)
	return null


## Free the current scene.
func free_scene() -> void:
	if _current_scene and is_instance_valid(_current_scene):
		_current_scene.queue_free()
		_current_scene = null


# === Assertions ===


## Assert that two values are equal.
func assert_equal(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual == expected:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected %s but got %s" % [expected, actual]
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that two values are not equal.
func assert_not_equal(actual: Variant, not_expected: Variant, message: String = "") -> bool:
	if actual != not_expected:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected value to not equal %s" % [not_expected]
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a condition is true.
func assert_true(condition: bool, message: String = "") -> bool:
	if condition:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected condition to be true"
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a condition is false.
func assert_false(condition: bool, message: String = "") -> bool:
	if not condition:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected condition to be false"
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a value is not null.
func assert_not_null(value: Variant, message: String = "") -> bool:
	if value != null:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected non-null value"
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a value is null.
func assert_null(value: Variant, message: String = "") -> bool:
	if value == null:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected null but got %s" % [value]
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a container contains an item.
func assert_contains(container: Variant, item: Variant, message: String = "") -> bool:
	var contains := false

	if container is String:
		contains = container.contains(str(item))
	elif container is Array:
		contains = container.has(item)
	elif container is Dictionary:
		contains = container.has(item)
	else:
		_record_error("assert_contains: Unsupported container type")
		assertions_failed += 1
		return false

	if contains:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected %s to contain %s" % [container, item]
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a container does not contain an item.
func assert_not_contains(container: Variant, item: Variant, message: String = "") -> bool:
	var contains := false

	if container is String:
		contains = container.contains(str(item))
	elif container is Array:
		contains = container.has(item)
	elif container is Dictionary:
		contains = container.has(item)
	else:
		_record_error("assert_not_contains: Unsupported container type")
		assertions_failed += 1
		return false

	if not contains:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected %s to not contain %s" % [container, item]
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a value is greater than another.
func assert_greater(actual: Variant, threshold: Variant, message: String = "") -> bool:
	if actual > threshold:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected %s to be greater than %s" % [actual, threshold]
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a value is less than another.
func assert_less(actual: Variant, threshold: Variant, message: String = "") -> bool:
	if actual < threshold:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected %s to be less than %s" % [actual, threshold]
	_record_error(msg)
	assertions_failed += 1
	return false


## Fail with a message.
func fail(message: String = "Test failed") -> bool:
	_record_error(message)
	assertions_failed += 1
	return false


# === Error Tracking ===


## Record an error message.
func _record_error(message: String) -> void:
	_last_error = message
	push_error("ASSERTION FAILED: " + message)


## Get the last error message.
func get_last_error() -> String:
	return _last_error


## Check if any assertions failed.
func has_failures() -> bool:
	return assertions_failed > 0


## Get total assertion count.
func total_assertions() -> int:
	return assertions_passed + assertions_failed
