class_name NightAttackPreview
extends RefCounted


static func _is_on_eight_way_ray(delta: Vector2i) -> bool:
	if delta == Vector2i.ZERO:
		return false
	if delta.x == 0 or delta.y == 0:
		return true
	return absi(delta.x) == absi(delta.y)


static func _sweep_directions(direction: Vector2i) -> Array[Vector2i]:
	var forward := direction.sign()
	var directions: Array[Vector2i] = [forward]
	if forward.x == 0:
		directions.append(Vector2i(-1, forward.y))
		directions.append(Vector2i(1, forward.y))
	elif forward.y == 0:
		directions.append(Vector2i(forward.x, -1))
		directions.append(Vector2i(forward.x, 1))
	else:
		directions.append(Vector2i(forward.x, 0))
		directions.append(Vector2i(0, forward.y))
	return directions


static func _melee_cells(source: Vector2i, target: Vector2i, profile: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if source == target:
		return cells
	var direction := (target - source).sign()
	var pattern := String(profile.get("attack_pattern", "single"))
	if pattern == "sweep":
		for delta: Vector2i in _sweep_directions(direction):
			cells.append(source + delta)
	elif pattern == "thrust":
		var reach := maxi(1, int(profile.get("reach", 2)))
		for distance in range(1, reach + 1):
			cells.append(source + direction * distance)
	else:
		cells.append(source + direction)
	return cells


static func _cast_cells(source: Vector2i, target: Vector2i, cast_range: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if source == target or cast_range <= 0:
		return cells
	var trajectory := Utils.calculate_trajectory(source, target)
	var stop := mini(trajectory.size(), cast_range + 1)
	for i in range(1, stop):
		cells.append(trajectory[i])
	return cells


static func _melee_target_in_range(source: Vector2i, target: Vector2i, profile: Dictionary) -> bool:
	var delta := target - source
	if not _is_on_eight_way_ray(delta):
		return false
	var distance := maxi(absi(delta.x), absi(delta.y))
	var pattern := String(profile.get("attack_pattern", "single"))
	if pattern == "thrust":
		return distance >= 1 and distance <= maxi(1, int(profile.get("reach", 2)))
	return distance == 1


static func affinity(profile: Dictionary, fallback: StringName = &"physical") -> StringName:
	if profile.has("cast"):
		var cast: Dictionary = profile.get("cast", {})
		return StringName(String(cast.get("affinity", fallback)))
	return fallback


static func preview_color(p_affinity: StringName) -> Color:
	match p_affinity:
		&"magic":
			return Color(0.42, 0.78, 1.0, 0.28)
		&"holy":
			return Color(1.0, 0.80, 0.30, 0.28)
		_:
			return Color(0.96, 0.92, 0.84, 0.22)


static func build(
	profile: Dictionary,
	source: Vector2i,
	target: Vector2i,
	fallback_affinity: StringName = &"physical"
) -> Dictionary:
	var p_affinity := affinity(profile, fallback_affinity)
	var cells: Array[Vector2i] = []
	var preview := {
		"cells": cells,
		"target_in_range": false,
		"consumes_turn": false,
		"pattern": String(profile.get("attack_pattern", "single")),
		"affinity": p_affinity,
		"range": 1,
	}
	if profile.is_empty() or source == target:
		return preview

	if profile.has("cast"):
		var cast: Dictionary = profile.get("cast", {})
		var cast_range := maxi(1, int(cast.get("range", 1)))
		preview["pattern"] = "cast"
		preview["range"] = cast_range
		preview["cells"] = _cast_cells(source, target, cast_range)
		var delta := target - source
		preview["target_in_range"] = maxi(absi(delta.x), absi(delta.y)) <= cast_range
		return preview

	var pattern := String(profile.get("attack_pattern", "single"))
	preview["range"] = maxi(1, int(profile.get("reach", 1))) if pattern == "thrust" else 1
	preview["cells"] = _melee_cells(source, target, profile)
	preview["target_in_range"] = _melee_target_in_range(source, target, profile)
	return preview
