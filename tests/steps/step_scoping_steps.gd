extends RefCounted
## Step definitions for testing tag-based step scoping.

const StepRegistryScript = preload("res://addons/godot_gherkin/steps/step_registry.gd")
const TestContextScript = preload("res://addons/godot_gherkin/runner/test_context.gd")


func register_steps(registry: StepRegistryScript) -> void:
	# Context setup steps
	registry.given("I am on the pause menu", _on_pause_menu)
	registry.given("I am in multiplayer lobby", _on_multiplayer_lobby)
	registry.given("I am on an unknown screen", _on_unknown_screen)

	# Scoped button check for pause menu (only matches @pause_menu scenarios)
	registry.then("I should see a {string} button", _check_pause_button).for_tags(["@pause_menu"])

	# Scoped button check for multiplayer (only matches @multiplayer scenarios)
	registry.then("I should see a {string} button", _check_multiplayer_button).for_tags(
		["@multiplayer"]
	)

	# Fallback unscoped button check (matches scenarios without specific tags)
	registry.then("I should see a {string} button", _check_generic_button)


func _on_pause_menu(ctx: TestContextScript) -> void:
	ctx.set_value("screen", "pause_menu")
	ctx.set_value("buttons", ["Resume", "Settings", "Quit"])


func _on_multiplayer_lobby(ctx: TestContextScript) -> void:
	ctx.set_value("screen", "multiplayer")
	ctx.set_value("buttons", ["Ready", "Invite", "Leave"])


func _on_unknown_screen(ctx: TestContextScript) -> void:
	ctx.set_value("screen", "unknown")
	ctx.set_value("buttons", ["Generic", "OK", "Cancel"])


func _check_pause_button(ctx: TestContextScript, button_name: String) -> void:
	var screen: String = ctx.get_value("screen", "")
	ctx.assert_equal(screen, "pause_menu", "Should be on pause menu screen")
	var buttons: Array = ctx.get_value("buttons", [])
	ctx.assert_true(button_name in buttons, "Pause menu should have '%s' button" % button_name)


func _check_multiplayer_button(ctx: TestContextScript, button_name: String) -> void:
	var screen: String = ctx.get_value("screen", "")
	ctx.assert_equal(screen, "multiplayer", "Should be in multiplayer lobby")
	var buttons: Array = ctx.get_value("buttons", [])
	ctx.assert_true(
		button_name in buttons, "Multiplayer lobby should have '%s' button" % button_name
	)


func _check_generic_button(ctx: TestContextScript, button_name: String) -> void:
	# This is the fallback - works for any screen
	var buttons: Array = ctx.get_value("buttons", [])
	ctx.assert_true(button_name in buttons, "Screen should have '%s' button" % button_name)
