extends RefCounted
## Example step definitions for the calculator feature.

const StepRegistryScript = preload("res://addons/godot_gherkin/steps/step_registry.gd")
const TestContextScript = preload("res://addons/godot_gherkin/runner/test_context.gd")


func register_steps(registry: StepRegistryScript) -> void:
	# Background
	registry.given("the calculator is reset", _reset_calculator)
	registry.given("the calculator shows {int}", _set_initial_value)

	# When steps
	registry.when("I add {int} and {int}", _add_two_numbers)
	registry.when("I add {int}", _add_number)
	registry.when("I subtract {int} from {int}", _subtract)
	registry.when("I multiply {int} by {int}", _multiply)

	# Then steps
	registry.then("the result should be {int}", _check_result)


func _reset_calculator(ctx: TestContextScript) -> void:
	ctx.set_value("result", 0)


func _set_initial_value(ctx: TestContextScript, value: int) -> void:
	ctx.set_value("result", value)


func _add_two_numbers(ctx: TestContextScript, a: int, b: int) -> void:
	ctx.set_value("result", a + b)


func _add_number(ctx: TestContextScript, value: int) -> void:
	var current: int = ctx.get_value("result", 0)
	ctx.set_value("result", current + value)


func _subtract(ctx: TestContextScript, subtrahend: int, minuend: int) -> void:
	ctx.set_value("result", minuend - subtrahend)


func _multiply(ctx: TestContextScript, a: int, b: int) -> void:
	ctx.set_value("result", a * b)


func _check_result(ctx: TestContextScript, expected: int) -> void:
	var actual: int = ctx.get_value("result", 0)
	ctx.assert_equal(actual, expected, "Calculator result mismatch")
