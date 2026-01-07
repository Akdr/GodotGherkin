extends RefCounted
## Simple inventory for coverage testing.

var _items: Dictionary = {}  # item_name -> count


func clear() -> void:
	_items.clear()


func add_item(item_name: String, count: int = 1) -> void:
	if not _items.has(item_name):
		_items[item_name] = 0
	_items[item_name] += count


func remove_item(item_name: String, count: int = 1) -> bool:
	if not _items.has(item_name):
		return false
	if _items[item_name] < count:
		return false
	_items[item_name] -= count
	if _items[item_name] <= 0:
		_items.erase(item_name)
	return true


func get_item_count(item_name: String) -> int:
	return _items.get(item_name, 0)


func get_total_items() -> int:
	var total := 0
	for count in _items.values():
		total += count
	return total


func has_item(item_name: String) -> bool:
	return _items.has(item_name) and _items[item_name] > 0


func get_all_items() -> Dictionary:
	return _items.duplicate()
