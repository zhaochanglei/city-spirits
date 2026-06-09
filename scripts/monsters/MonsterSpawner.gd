extends RefCounted
class_name MonsterSpawner

const SPAWN_OFFSETS := [
	Vector2(58.0, -72.0),
	Vector2(-96.0, -34.0),
	Vector2(112.0, 18.0),
	Vector2(-42.0, 104.0),
	Vector2(26.0, 132.0),
	Vector2(138.0, -96.0),
	Vector2(-126.0, 82.0),
	Vector2(6.0, -142.0),
	Vector2(154.0, 76.0),
	Vector2(-154.0, -112.0)
]


func spawn_monsters(player_position: Vector2, templates: Array) -> Array[Dictionary]:
	var count := mini(Constants.RADAR_MONSTER_COUNT, templates.size())
	count = clampi(count, 5, 10)

	var spawned: Array[Dictionary] = []
	for index in range(count):
		var template: Dictionary = templates[index]
		var monster := template.duplicate(true)
		monster["spawn_index"] = index
		monster["world_position"] = player_position + SPAWN_OFFSETS[index % SPAWN_OFFSETS.size()]
		spawned.append(monster)

	return spawned


func get_radar_position(
	monster: Dictionary,
	player_position: Vector2,
	radar_center: Vector2,
	pixels_per_meter: float
) -> Vector2:
	var world_position: Vector2 = monster.get("world_position", Vector2.ZERO)
	return radar_center + ((world_position - player_position) * pixels_per_meter)


func get_distance_meters(monster: Dictionary, player_position: Vector2) -> float:
	var world_position: Vector2 = monster.get("world_position", Vector2.ZERO)
	return world_position.distance_to(player_position)


func with_distance(monster: Dictionary, player_position: Vector2) -> Dictionary:
	var result := monster.duplicate(true)
	result["distance_meters"] = get_distance_meters(monster, player_position)
	return result
