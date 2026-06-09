extends RefCounted
class_name CaptureSystem


func get_capture_chance(monster: Dictionary, throw_multiplier: float) -> float:
	var base_capture_rate := float(monster.get("base_capture_rate", 0.35))
	return clampf(base_capture_rate * throw_multiplier, 0.0, 0.95)


func attempt_capture(
	monster: Dictionary,
	throw_multiplier: float,
	roll: float = -1.0,
	escape_on_failure: bool = false
) -> Dictionary:
	var capture_chance := get_capture_chance(monster, throw_multiplier)
	var actual_roll := roll
	if actual_roll < 0.0:
		actual_roll = randf()

	var success := actual_roll <= capture_chance
	return {
		"monster_id": str(monster.get("id", "")),
		"success": success,
		"escaped": escape_on_failure and not success,
		"chance": capture_chance,
		"roll": actual_roll,
		"throw_multiplier": throw_multiplier
	}
