class_name NightControllerPreview
extends RefCounted


static func _melee_target_distance(profile: Dictionary) -> int:
	if String(profile.get("attack_pattern", "single")) == "thrust":
		return maxi(1, int(profile.get("reach", 2)))
	return 1


static func _clip_thrust_cells(map: Map, source: Vector2i, direction: Vector2i, reach: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for distance in range(1, reach + 1):
		var pos := source + direction * distance
		if not map.is_in_bounds(pos) or not map.is_visible(pos):
			break
		cells.append(pos)
		if not map.get_cell(pos).is_walkable() or map.get_obstacle(pos) != null:
			break
		if map.get_monster(pos) != null:
			break
	return cells


static func _filter_footprint_cells(map: Map, cells: Array) -> Array[Vector2i]:
	var visible: Array[Vector2i] = []
	for value in cells:
		var pos: Vector2i = value
		if map.is_in_bounds(pos) and map.is_visible(pos):
			visible.append(pos)
	return visible


static func build(
	map: Map,
	actor: Monster,
	profile: Dictionary,
	fallback_affinity: StringName,
	facing: Vector2i
) -> Dictionary:
	if map == null or actor == null or profile.is_empty():
		return {}
	var direction := facing.sign()
	if direction == Vector2i.ZERO:
		return {}
	var source := map.find_monster_position(actor)
	if source == Utils.INVALID_POS:
		return {}

	if profile.has("cast"):
		var target := NightControllerInput.facing_cast_target(map, actor, direction)
		if target == Utils.INVALID_POS:
			return {}
		var cast_preview := NightAttackPreview.build(profile, source, target, fallback_affinity)
		cast_preview["target"] = target
		cast_preview["input_mode"] = "controller"
		return cast_preview

	var distance := _melee_target_distance(profile)
	var target := source + direction * distance
	var preview := NightAttackPreview.build(profile, source, target, fallback_affinity)
	var pattern := String(profile.get("attack_pattern", "single"))
	if pattern == "thrust":
		preview["cells"] = _clip_thrust_cells(map, source, direction, distance)
		var thrust_cells: Array = preview.get("cells", [])
		if not thrust_cells.is_empty():
			preview["target"] = thrust_cells[-1]
	else:
		preview["cells"] = _filter_footprint_cells(map, preview.get("cells", []))
		var footprint_cells: Array = preview.get("cells", [])
		if not footprint_cells.is_empty():
			preview["target"] = source + direction
	preview["input_mode"] = "controller"
	return preview
