class_name PlayerUpgradeWeaponAction
extends BaseAction

var item: Item


func _init(p_item: Item) -> void:
	item = p_item


func _execute(map: Map, result: ActionResult) -> bool:
	return NightRun.upgrade_weapon(item, map, result)


func _to_string() -> String:
	return "PlayerUpgradeWeaponAction(item: %s)" % item
