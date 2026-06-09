extends Node
class_name MockLocationService

signal location_changed(position: Vector2)

var current_position := Vector2.ZERO


func get_current_position() -> Vector2:
	return current_position


func set_current_position(position: Vector2) -> void:
	current_position = position
	location_changed.emit(current_position)


func move_by(delta: Vector2) -> void:
	set_current_position(current_position + delta)


func reset() -> void:
	set_current_position(Vector2.ZERO)
