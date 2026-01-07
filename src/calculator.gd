extends RefCounted
## Simple calculator for coverage testing.

var _value: float = 0.0


func reset() -> void:
	_value = 0.0


func get_value() -> float:
	return _value


func set_value(value: float) -> void:
	_value = value


func add(amount: float) -> float:
	_value += amount
	return _value


func subtract(amount: float) -> float:
	_value -= amount
	return _value


func multiply(amount: float) -> float:
	_value *= amount
	return _value


func divide(amount: float) -> float:
	if amount == 0.0:
		push_error("Division by zero")
		return _value
	_value /= amount
	return _value
