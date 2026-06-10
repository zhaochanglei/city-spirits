extends RefCounted
class_name RadarUiMath

const DEFAULT_HEADING := Vector2.UP
const MIN_HEADING_DISTANCE_METERS := 0.5


func get_heading_from_motion(
	previous_position: Vector2,
	next_position: Vector2,
	fallback_heading: Vector2 = DEFAULT_HEADING
) -> Vector2:
	var movement := next_position - previous_position
	if movement.length() < MIN_HEADING_DISTANCE_METERS:
		return _normalized_or_default(fallback_heading)

	return movement.normalized()


func get_arrow_rotation_for_heading(heading: Vector2) -> float:
	var normalized_heading := _normalized_or_default(heading)
	return normalized_heading.angle() - DEFAULT_HEADING.angle()


func _normalized_or_default(heading: Vector2) -> Vector2:
	if heading.length() <= 0.001:
		return DEFAULT_HEADING

	return heading.normalized()
