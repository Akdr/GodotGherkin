extends RefCounted
## Step definitions to verify Background execution.

const StepRegistryScript = preload("res://addons/godot_gherkin/steps/step_registry.gd")
const TestContextScript = preload("res://addons/godot_gherkin/runner/test_context.gd")


func register_steps(registry: StepRegistryScript) -> void:
	registry.given("the counter is initialized to {int}", _init_counter)
	registry.when("I increment the counter by {int}", _increment_counter)
	registry.then("the counter should be {int}", _check_counter)


func _init_counter(ctx: TestContextScript, value: int) -> void:
	# This MUST be called by Background for tests to pass
	ctx.set_value("counter", value)
	ctx.set_value("background_executed", true)


func _increment_counter(ctx: TestContextScript, amount: int) -> void:
	var current: int = ctx.get_value("counter", 0)
	ctx.set_value("counter", current + amount)


func _check_counter(ctx: TestContextScript, expected: int) -> void:
	# First verify Background was executed
	var bg_executed: bool = ctx.get_value("background_executed", false)
	ctx.assert_true(bg_executed, "Background step was NOT executed!")

	var actual: int = ctx.get_value("counter", -999)
	ctx.assert_equal(actual, expected, "Counter value mismatch")
