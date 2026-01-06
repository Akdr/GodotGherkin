extends RefCounted
## Step definitions for testing multiple {string} parameter capture.

const StepRegistryScript = preload("res://addons/godot_gherkin/steps/step_registry.gd")
const TestContextScript = preload("res://addons/godot_gherkin/runner/test_context.gd")


func register_steps(registry: StepRegistryScript) -> void:
	registry.given("a section named {string}", _set_section_name)
	registry.then("the {string} section should mention {string}", _check_section_content)
	registry.then("copying {string} to {string} should produce {string}", _check_three_strings)
	registry.then(
		"the {string} section at index {int} should contain {string}", _check_mixed_params
	)


func _set_section_name(ctx: TestContextScript, section_name: String) -> void:
	ctx.set_value("section_name", section_name)
	ctx.set_value("section_content", "This section covers attack and defense strategies.")


func _check_section_content(ctx: TestContextScript, section: String, keyword: String) -> void:
	# This is the critical test: section should be "Combat", keyword should be "attack"
	# Before fix: section="Combat", keyword="Combat" (WRONG - captured nested group)
	# After fix: section="Combat", keyword="attack" (CORRECT)
	ctx.assert_equal(
		section, ctx.get_value("section_name", ""), "First {string} param should match section name"
	)
	ctx.assert_equal(keyword, "attack", "Second {string} param should be 'attack'")


func _check_three_strings(
	ctx: TestContextScript, first: String, second: String, result: String
) -> void:
	# Verify all three string parameters are captured correctly
	ctx.assert_equal(first, "hello", "First {string} should be 'hello'")
	ctx.assert_equal(second, "world", "Second {string} should be 'world'")
	ctx.assert_equal(result, "hello world", "Third {string} should be 'hello world'")


func _check_mixed_params(
	ctx: TestContextScript, section: String, index: int, content: String
) -> void:
	# Test mixing {string} and {int} parameters
	ctx.assert_equal(section, "Settings", "First {string} should be 'Settings'")
	ctx.assert_equal(index, 3, "{int} param should be 3")
	ctx.assert_equal(content, "options", "Second {string} should be 'options'")
