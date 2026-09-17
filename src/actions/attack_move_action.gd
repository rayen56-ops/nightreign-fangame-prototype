class_name AttackMoveAction
extends ActorAction

var direction: Vector2i


func _init(p_actor: Monster, dir: Vector2i) -> void:
	super(p_actor)
	direction = dir


func _player_thrust_reach() -> int:
	if actor != World.player:
		return 1
	var weapon := actor.equipment.get_equipped_item(Equipment.Slot.MELEE)
	if weapon == null or not weapon.has_meta("night_weapon"):
		return 1
	var profile := NightRun.weapon_archetype(String(weapon.get_meta("night_weapon")))
	if String(profile.get("attack_pattern", "single")) != "thrust":
		return 1
	return maxi(2, int(profile.get("reach", 2)))


func _try_reach_attack(map: Map, result: ActionResult, current_pos: Vector2i) -> bool:
	var reach := _player_thrust_reach()
	if reach <= 1:
		return false
	var forward := direction.sign()
	# A thrust cannot phase through walls, doors, allies or any other occupied tile.
	for distance in range(1, reach):
		var through_pos := current_pos + forward * distance
		if not map.is_in_bounds(through_pos):
			return false
		if not map.get_cell(through_pos).is_walkable() or map.get_obstacle(through_pos) != null:
			return false
		if map.get_monster(through_pos) != null:
			return false
	var target_pos := current_pos + forward * reach
	if not map.is_in_bounds(target_pos):
		return false
	var target := map.get_monster(target_pos)
	if target == null or target.has_meta("family"):
		return false
	return MeleeAction.new(actor, forward, reach)._execute(map, result)


func _execute(map: Map, result: ActionResult) -> bool:
	if not super(map, result):
		return false

	var current_pos := map.find_monster_position(actor)
	if current_pos == Utils.INVALID_POS:
		push_error("AttackMoveAction actor is not present on the current map: %s" % actor)
		return false

	if actor.has_status_effect(StatusEffect.Type.CONFUSED):
		direction = Utils.ALL_DIRECTIONS.pick_random()

	if actor.has_status_effect(StatusEffect.Type.PARALYZED):
		if actor == World.player:
			result.message = "You are paralyzed!"
			result.message_level = LogMessages.Level.TERRIBLE
		else:
			result.message = "%s tries to move but is paralyzed!" % actor.name
			result.message_level = LogMessages.Level.BAD
		return true

	if actor == World.player:
		NightRun.facing = direction

	var new_pos := current_pos + direction
	if not map.is_in_bounds(new_pos):
		return false

	var target := map.get_monster(new_pos)
	if target and target.has_meta("family"):
		result.message = "Your family occupies that tile."
		return false

	if target:
		var melee := MeleeAction.new(actor, direction)
		return melee._execute(map, result)

	if _try_reach_attack(map, result, current_pos):
		return true

	var move := MoveAction.new(actor, direction)
	return move._execute(map, result)


func _to_string() -> String:
	return "AttackMoveAction(actor: %s, direction: %s)" % [actor, direction]
