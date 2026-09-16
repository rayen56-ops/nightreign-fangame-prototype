class_name NightEnemyAction
extends ActorAction
func _init(monster: Monster) -> void:
	super(monster)
func _execute(map: Map, result: ActionResult) -> bool:
	return NightRun.act_enemy(actor, map, result)
