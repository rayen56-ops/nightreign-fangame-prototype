class_name NightAbilityAction
extends ActorAction
var ability: String
var direction: Vector2i
func _init(kind: String, dir := Vector2i.ZERO) -> void:
	super(World.player)
	ability = kind
	direction = dir
func _execute(map: Map, result: ActionResult) -> bool:
	return NightRun.use_ability(ability, direction, map, result)
