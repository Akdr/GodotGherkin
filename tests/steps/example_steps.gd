extends RefCounted
## Example step definitions for the calculator feature.
## Uses the Calculator class from src/ to demonstrate coverage tracking.

const StepRegistryScript = preload("res://addons/godot_gherkin/steps/step_registry.gd")
const TestContextScript = preload("res://addons/godot_gherkin/runner/test_context.gd")
const CalculatorScript = preload("res://src/calculator.gd")


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


func _get_calculator(ctx: TestContextScript) -> CalculatorScript:
	var calc: CalculatorScript = ctx.get_value("calculator", null)
	if not calc:
		calc = CalculatorScript.new()
		ctx.set_value("calculator", calc)
	return calc


func _reset_calculator(ctx: TestContextScript) -> void:
	var calc := _get_calculator(ctx)
	calc.reset()


func _set_initial_value(ctx: TestContextScript, value: int) -> void:
	var calc := _get_calculator(ctx)
	calc.set_value(value)


func _add_two_numbers(ctx: TestContextScript, a: int, b: int) -> void:
	var calc := _get_calculator(ctx)
	calc.set_value(a)
	calc.add(b)


func _add_number(ctx: TestContextScript, value: int) -> void:
	var calc := _get_calculator(ctx)
	calc.add(value)


func _subtract(ctx: TestContextScript, subtrahend: int, minuend: int) -> void:
	var calc := _get_calculator(ctx)
	calc.set_value(minuend)
	calc.subtract(subtrahend)


func _multiply(ctx: TestContextScript, a: int, b: int) -> void:
	var calc := _get_calculator(ctx)
	calc.set_value(a)
	calc.multiply(b)


func _check_result(ctx: TestContextScript, expected: int) -> void:
	var calc := _get_calculator(ctx)
	var actual := int(calc.get_value())
	ctx.assert_equal(actual, expected, "Calculator result mismatch")
