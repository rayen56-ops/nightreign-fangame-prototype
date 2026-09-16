class_name AttackMoveAction
extends ActorAction

var direction: Vector2i


func _init(p_actor: Monster, dir: Vector2i) -> void:
	super(p_actor)
	direction = dir


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

	var move := MoveAction.new(actor, direction)
	return move._execute(map, result)


func _to_string() -> String:
	return "AttackMoveAction(actor: %s, direction: %s)" % [actor, direction]
