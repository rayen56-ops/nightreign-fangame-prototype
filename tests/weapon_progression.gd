extends Node

const InventoryItemScene := preload("res://scenes/ui/inventory_item.tscn")

var checks := 0
var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("M3 WEAPON PROGRESSION QA %s: %s" % ["PASS" if value else "FAIL", label])


func _ready() -> void:
	call_deferred("run")


func _sandbox(depth: int = 1) -> Map:
	CharacterCatalog.select_character("wylder")
	World.initialize(25092026 + depth)
	var map := NightRun.make_arena(depth, "")
	map.id = "m3_weapon_progression_%d" % depth
	World.current_map = map
	map.get_cell(Vector2i(9, 9)).monster = World.player
	World.game_over = false
	World.player.is_dead = false
	World.player.inventory.clear()
	for slot in Equipment.Slot.values():
		World.player.equipment.unequip(slot)
	NightRun.runes = 0
	NightRun.charge = 0
	NightRun.cooldown = 0
	NightRun.immortal = 0
	NightRun.telegraphs.clear()
	NightRun.prepared.clear()
	NightRun.grace_used.clear()
	NightRun.floor_turns[map.id] = 0
	NightRun.night_stage[map.id] = 0
	return map


func _move_player(map: Map, to: Vector2i) -> void:
	var current := map.find_monster_position(World.player)
	if current != Utils.INVALID_POS:
		map.get_cell(current).monster = null
	map.get_cell(to).monster = World.player


func _has_keys(dict: Dictionary, expected: Array[String]) -> bool:
	if dict.size() != expected.size():
		return false
	for key in expected:
		if not dict.has(key):
			return false
	return true


func run() -> void:
	var progression := NightRun.weapon_progression()
	check(progression.has("rarities"), "weapon progression exposes rarity table")
	check(progression.has("drop_bands"), "weapon progression exposes floor drop bands")
	check(progression.has("upgrade_costs"), "weapon progression exposes upgrade costs")

	var expected_rarities := {
		"common": {"bonus": 0, "cap": 2, "label": "Common"},
		"uncommon": {"bonus": 1, "cap": 3, "label": "Uncommon"},
		"rare": {"bonus": 2, "cap": 4, "label": "Rare"},
		"legendary": {"bonus": 3, "cap": 5, "label": "Legendary"},
	}
	var base_damage := -1
	for rarity_id: String in expected_rarities:
		var expected: Dictionary = expected_rarities[rarity_id]
		var weapon := NightRun.make_weapon("rapier", rarity_id, 0)
		check(NightRun.weapon_rarity(weapon) == rarity_id, "rarity metadata " + rarity_id)
		check(NightRun.weapon_rarity_label(weapon) == expected.label, "rarity label " + rarity_id)
		check(NightRun.weapon_rarity_bonus(weapon) == expected.bonus, "rarity damage bonus " + rarity_id)
		check(NightRun.weapon_upgrade_level(weapon) == 0, "new explicit rarity starts at +0 " + rarity_id)
		check(NightRun.weapon_upgrade_cap(weapon) == expected.cap, "upgrade cap follows rarity " + rarity_id)
		check(weapon.enhancement == expected.bonus, "enhancement cache includes rarity bonus " + rarity_id)
		check(NightRun.weapon_rarity_color(weapon).a == 1.0, "rarity color is opaque " + rarity_id)
		var damage := NightRun.weapon_damage(weapon, "wylder")
		if rarity_id == "common":
			base_damage = damage
		check(damage == base_damage + int(expected.bonus), "deterministic damage includes rarity bonus " + rarity_id)

	var common := NightRun.make_weapon("greatsword")
	check(NightRun.weapon_rarity(common) == "common", "default make_weapon remains common")
	check(NightRun.weapon_upgrade_level(common) == 0, "starting/default weapon remains +0")
	check(common.enhancement == 0, "common +0 keeps legacy damage baseline")

	var clamped := NightRun.make_weapon("rapier", "legendary", 99)
	check(NightRun.weapon_upgrade_level(clamped) == 5, "explicit upgrade is clamped to rarity cap")
	check(clamped.enhancement == 8, "legendary +5 total bonus is rarity 3 plus upgrade 5")
	check(NightRun.weapon_upgrade_cost(clamped) == -1, "maxed weapon has no next upgrade cost")

	var rare_plus_two := NightRun.make_weapon("rapier", "rare", 2)
	var rare_zero := NightRun.make_weapon("rapier", "rare", 0)
	check(NightRun.weapon_damage(rare_plus_two, "wylder") == NightRun.weapon_damage(rare_zero, "wylder") + 2, "+N adds one deterministic damage per level")
	check(rare_plus_two.get_name().contains("[Rare] +2 Rapier"), "inventory name exposes rarity and actual +N")
	var info := rare_plus_two.get_info()
	check(info.contains("Rarity: Rare (+2 damage)"), "tooltip explains rarity bonus")
	check(info.contains("Upgrade: +2 / +4"), "tooltip explains current upgrade and cap")
	check(info.contains("Next upgrade: 55 runes at a Site of Grace"), "tooltip exposes next rune cost and location")
	check(info.contains("Current damage: %d" % NightRun.weapon_damage(rare_plus_two, "wylder")), "tooltip damage includes progression")

	var clone := ItemFactory.clone(rare_plus_two)
	check(clone.get_meta("night_rarity", "") == "rare", "clone preserves rarity metadata")
	check(int(clone.get_meta("night_upgrade", -1)) == 2, "clone preserves +N metadata")
	check(clone.enhancement == rare_plus_two.enhancement, "clone preserves enhancement cache")
	check(NightRun.weapon_damage(clone, "wylder") == NightRun.weapon_damage(rare_plus_two, "wylder"), "clone preserves progressed weapon damage")

	check(_has_keys(NightRun.weapon_rarity_weights(1), ["common", "uncommon"]), "floor 1 only rolls common/uncommon")
	check(_has_keys(NightRun.weapon_rarity_weights(5), ["common", "uncommon", "rare"]), "floor 5 introduces rare")
	check(_has_keys(NightRun.weapon_rarity_weights(10), ["common", "uncommon", "rare", "legendary"]), "floor 10 introduces legendary")
	check(_has_keys(NightRun.weapon_rarity_weights(15), ["uncommon", "rare", "legendary"]), "floor 15 removes common drops")

	seed(31122026)
	for depth in [1, 5, 10, 15, 19]:
		var allowed := NightRun.weapon_rarity_weights(depth)
		for i in range(40):
			var drop := NightRun.make_weapon_drop("longsword", depth)
			check(allowed.has(NightRun.weapon_rarity(drop)), "floor %d drop rarity stays inside configured band" % depth)
			var band := NightRun.weapon_drop_band(depth)
			var min_upgrade := int(band.get("upgrade_min", 0))
			var max_upgrade := int(band.get("upgrade_max", min_upgrade))
			check(NightRun.weapon_upgrade_level(drop) >= min_upgrade, "floor %d drop respects minimum +N" % depth)
			check(NightRun.weapon_upgrade_level(drop) <= mini(max_upgrade, NightRun.weapon_upgrade_cap(drop)), "floor %d drop respects maximum +N/cap" % depth)

	var map := _sandbox(1)
	var upgrade_weapon := NightRun.make_weapon("longsword", "common", 0)
	World.player.add_item(upgrade_weapon)
	_move_player(map, Vector2i(9, 13))
	check(NightRun.is_at_grace(map), "stairs-up entrance is recognized as Site of Grace")
	check(NightRun.weapon_upgrade_cost(upgrade_weapon) == 20, "first upgrade costs 20 runes")
	NightRun.runes = 100
	var damage_before := NightRun.weapon_damage(upgrade_weapon, "wylder")
	var turn_before := World.current_turn
	var result := World.apply_player_action(PlayerUpgradeWeaponAction.new(upgrade_weapon))
	check(result != null and result.success, "weapon upgrade resolves through player action system")
	check(World.current_turn == turn_before + 1, "successful weapon upgrade consumes exactly one turn")
	check(NightRun.runes == 80, "successful +1 deducts exact rune cost")
	check(NightRun.weapon_upgrade_level(upgrade_weapon) == 1, "successful action increments +N")
	check(upgrade_weapon.enhancement == 1, "common +1 enhancement cache stays synchronized")
	check(NightRun.weapon_damage(upgrade_weapon, "wylder") == damage_before + 1, "successful +1 increases deterministic damage by one")
	check(result.message.contains("+1") and result.message.contains("20 runes"), "upgrade result explains level and cost")
	check(NightRun.weapon_upgrade_cost(upgrade_weapon) == 35, "second upgrade cost advances to 35 runes")

	# Failure: away from grace. No runes, level or turn may change.
	_move_player(map, Vector2i(9, 9))
	NightRun.runes = 100
	turn_before = World.current_turn
	var level_before := NightRun.weapon_upgrade_level(upgrade_weapon)
	result = World.apply_player_action(PlayerUpgradeWeaponAction.new(upgrade_weapon))
	check(result != null and not result.success, "upgrade away from grace fails")
	check(World.current_turn == turn_before, "failed off-grace upgrade consumes zero turns")
	check(NightRun.runes == 100, "failed off-grace upgrade consumes zero runes")
	check(NightRun.weapon_upgrade_level(upgrade_weapon) == level_before, "failed off-grace upgrade keeps +N")

	# Failure: insufficient runes at grace.
	_move_player(map, Vector2i(9, 13))
	NightRun.runes = 34
	turn_before = World.current_turn
	result = World.apply_player_action(PlayerUpgradeWeaponAction.new(upgrade_weapon))
	check(result != null and not result.success, "insufficient-rune upgrade fails")
	check(World.current_turn == turn_before, "insufficient-rune failure consumes zero turns")
	check(NightRun.runes == 34, "insufficient-rune failure consumes zero runes")
	check(NightRun.weapon_upgrade_level(upgrade_weapon) == 1, "insufficient-rune failure keeps +N")

	# Reach common cap +2, then verify hard stop.
	NightRun.runes = 200
	turn_before = World.current_turn
	result = World.apply_player_action(PlayerUpgradeWeaponAction.new(upgrade_weapon))
	check(result != null and result.success, "common weapon can reach +2 cap")
	check(NightRun.weapon_upgrade_level(upgrade_weapon) == 2, "common cap is +2")
	check(NightRun.runes == 165, "second common upgrade deducts 35 runes")
	var capped_turn := World.current_turn
	var capped_runes := NightRun.runes
	result = World.apply_player_action(PlayerUpgradeWeaponAction.new(upgrade_weapon))
	check(result != null and not result.success, "upgrade beyond rarity cap fails")
	check(World.current_turn == capped_turn, "cap failure consumes zero turns")
	check(NightRun.runes == capped_runes, "cap failure consumes zero runes")
	check(NightRun.weapon_upgrade_cost(upgrade_weapon) == -1, "capped weapon reports no next cost")

	# Inventory category and rarity presentation are wired to real UI nodes.
	check(Item.Type.WAND in InventoryItemList.Sections["Weapons"], "staff/seal WAND weapons appear in Weapons inventory section")
	var inventory_row := InventoryItemScene.instantiate() as InventoryItem
	add_child(inventory_row)
	await get_tree().process_frame
	inventory_row.item = rare_plus_two
	check(inventory_row.label.text.contains("[Rare] +2 Rapier"), "inventory row exposes rarity and +N")
	check(inventory_row.label.get_theme_color("font_color") == NightRun.weapon_rarity_color(rare_plus_two), "inventory row uses configured rarity color")
	inventory_row.queue_free()
	await get_tree().process_frame

	# Pre-boss Holy safety route is now a meaningful progressed item.
	map = _sandbox(19)
	seed(19092026)
	NightRun.prepare_map(map)
	var start := map.find_monster_position(World.player)
	var sacred: Item = null
	for item: Item in map.get_items(start):
		if item.get_meta("night_weapon", "") == "sacred_blade":
			sacred = item
			break
	check(sacred != null, "floor 19 still guarantees Sacred Blade at player start")
	if sacred != null:
		check(NightRun.weapon_rarity(sacred) == "rare", "guaranteed Sacred Blade is Rare")
		check(NightRun.weapon_upgrade_level(sacred) == 2, "guaranteed Sacred Blade is +2")
		check(String(sacred.get_meta("night_affinity", "")) == "holy", "guaranteed Sacred Blade keeps Holy affinity")

	var report := {
		"checks": checks,
		"failures": failures,
		"rarities": ["common", "uncommon", "rare", "legendary"],
		"upgrade_costs": progression.upgrade_costs,
		"upgrade_location": "Site of Grace",
		"successful_upgrade_consumes_turn": true,
		"failed_upgrade_consumes_turn": false,
	}
	FileAccess.open("res://docs/M3_WEAPON_PROGRESSION_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("M3 WEAPON PROGRESSION QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
