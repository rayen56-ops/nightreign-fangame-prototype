class_name AttackMoveAction
extends ActorAction


func _init(delta: Vector2i) -> void:
	self.delta = delta


func perform() -> bool:
	var map := World.current_map
	if not map or not actor:
		return false

	var current_pos := map.find_monster_position(actor)
	if current_pos == Utils.INVALID_POS:
		return false

	var destination := current_pos + delta
	if not map.is_in_bounds(destination):
		return false

	var target := map.get_monster(destination)
	if target and target != actor:
		return MeleeAction.new(delta).set_actor(actor).perform()

	return MoveAction.new(delta).set_actor(actor).perform()
