extends RefCounted
## Step definitions for testing DataTable and DocString argument passing.

const StepRegistryScript = preload("res://addons/godot_gherkin/steps/step_registry.gd")
const TestContextScript = preload("res://addons/godot_gherkin/runner/test_context.gd")


func register_steps(registry: StepRegistryScript) -> void:
	# Data table steps
	registry.given("the player has the following stats:", _set_player_stats)
	registry.given("the following users exist:", _set_users)
	registry.then("the player should have {int} total runs", _check_total_runs)
	registry.then("the player should have {int} total victories", _check_total_victories)
	registry.then("there should be {int} users", _check_user_count)
	registry.then("user {string} should be an admin", _check_user_admin)

	# Doc string steps
	registry.given("a JSON configuration:", _set_json_config)
	registry.then("the config should have debug enabled", _check_debug_enabled)


func _set_player_stats(ctx: TestContextScript, table: Array) -> void:
	# table is Array of Arrays: [["stat", "value"], ["total_runs", "30"], ...]
	# Skip header row, parse key-value pairs
	var stats := {}
	for i in range(1, table.size()):
		var row: Array = table[i]
		if row.size() >= 2:
			stats[row[0]] = row[1].to_int()
	ctx.set_value("player_stats", stats)


func _set_users(ctx: TestContextScript, table: Array) -> void:
	# table: [["name", "role", "level"], ["Alice", "admin", "50"], ...]
	var users: Array = []
	var headers: Array = table[0] if table.size() > 0 else []

	for i in range(1, table.size()):
		var row: Array = table[i]
		var user := {}
		for j in range(mini(headers.size(), row.size())):
			user[headers[j]] = row[j]
		users.append(user)

	ctx.set_value("users", users)


func _check_total_runs(ctx: TestContextScript, expected: int) -> void:
	var stats: Dictionary = ctx.get_value("player_stats", {})
	var actual: int = stats.get("total_runs", 0)
	ctx.assert_equal(actual, expected, "Total runs mismatch")


func _check_total_victories(ctx: TestContextScript, expected: int) -> void:
	var stats: Dictionary = ctx.get_value("player_stats", {})
	var actual: int = stats.get("total_victories", 0)
	ctx.assert_equal(actual, expected, "Total victories mismatch")


func _check_user_count(ctx: TestContextScript, expected: int) -> void:
	var users: Array = ctx.get_value("users", [])
	ctx.assert_equal(users.size(), expected, "User count mismatch")


func _check_user_admin(ctx: TestContextScript, name: String) -> void:
	var users: Array = ctx.get_value("users", [])
	var found := false
	for user in users:
		if user.get("name") == name and user.get("role") == "admin":
			found = true
			break
	ctx.assert_true(found, "User '%s' should be an admin" % name)


func _set_json_config(ctx: TestContextScript, content: String) -> void:
	# content is the doc string content (JSON text)
	var json := JSON.new()
	var error := json.parse(content)
	if error == OK:
		ctx.set_value("config", json.data)
	else:
		ctx.fail("Failed to parse JSON: %s" % json.get_error_message())


func _check_debug_enabled(ctx: TestContextScript) -> void:
	var config: Dictionary = ctx.get_value("config", {})
	ctx.assert_true(config.get("debug", false), "Config debug should be enabled")
