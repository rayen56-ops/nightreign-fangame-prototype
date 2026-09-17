extends Node

var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("WEAPON QA %s: %s" % ["PASS" if value else "FAIL", label])

func _ready() -> void:
	call_deferred("run")

func _sandbox() -> Map:
	CharacterCatalog.select_character("wylder")
	World.initialize(17092026)
	var map := NightRun.make_arena(1, "")
	map.id = "weapon_qa"
	World.current_map = map
	map.get_cell(Vector2i(9, 9)).monster = World.player
	NightRun.telegraphs.clear()
	NightRun.floor_turns[map.id] = 0
	NightRun.night_stage[map.id] = 0
	return map

func _equip(weapon: Item, map: Map) -> void:
	World.player.add_item(weapon)
	World.player.equipment.equip(weapon, Equipment.Slot.MELEE)

func _set_hp(monster: Monster, amount: int) -> void:
	monster.max_hp = amount
	monster.hp = amount

func run() -> void:
	var cases := {
		"longsword": {"archetype": "straight_sword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH, "pattern": "single"},
		"greatsword": {"archetype": "greatsword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH, "pattern": "sweep"},
		"uchigatana": {"archetype": "katana", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH, "pattern": "single"},
		"misericorde": {"archetype": "dagger", "item": Item.Type.KNIFE, "skill": Skills.Type.KNIFE, "damage": Damage.Type.PIERCE, "pattern": "burst"},
		"glintstone_staff": {"archetype": "staff", "item": Item.Type.WAND, "skill": Skills.Type.UTILITY, "damage": Damage.Type.BLUNT, "pattern": "single"},
		"finger_seal": {"archetype": "seal", "item": Item.Type.WAND, "skill": Skills.Type.UTILITY, "damage": Damage.Type.BLUNT, "pattern": "single"},
		"sacred_blade": {"archetype": "straight_sword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH, "pattern": "single"}
	}

	var map := _sandbox()
	for weapon_id: String in cases:
		var expected: Dictionary = cases[weapon_id]
		var weapon := NightRun.make_weapon(weapon_id)
		var profile := NightRun.weapon_archetype(weapon_id)
		check(weapon.get_meta("night_weapon", "") == weapon_id, "weapon identity " + weapon_id)
		check(weapon.get_meta("night_archetype", "") == expected.archetype, "archetype " + weapon_id)
		check(weapon.type == expected.item, "item type " + weapon_id)
		check(weapon.skill_type == expected.skill, "skill type " + weapon_id)
		check(weapon.damage_types.size() == 1 and weapon.damage_types[0] == expected.damage, "damage profile " + weapon_id)
		check(String(profile.get("attack_pattern", "")) == expected.pattern, "attack pattern " + weapon_id)
		check(weapon.is_weapon(), "recognized as weapon " + weapon_id)
		World.player.add_item(weapon)
		check(PlayerEquipAction.new(weapon, Equipment.Slot.MELEE).apply(map).success, "equips in melee slot " + weapon_id)
		var clone := ItemFactory.clone(weapon)
		check(clone.get_meta("night_weapon", "") == weapon_id and clone.get_meta("night_archetype", "") == expected.archetype, "clone preserves weapon metadata " + weapon_id)
		check(NightRun.weapon_description(weapon).contains("Archetype:"), "description exposes archetype " + weapon_id)

	var greatsword := NightRun.make_weapon("greatsword")
	check(NightRun.weapon_damage(greatsword, "wylder") > NightRun.weapon_damage(greatsword, "revenant"), "greatsword STR scaling favors Wylder")
	var seal := NightRun.make_weapon("finger_seal")
	check(NightRun.weapon_damage(seal, "revenant") > NightRun.weapon_damage(seal, "wylder"), "seal FAI scaling favors Revenant")

	# Greatsword attacks the forward tile plus the two neighboring directions.
	map = _sandbox()
	greatsword = NightRun.make_weapon("greatsword")
	_equip(greatsword, map)
	var sweep_primary := NightRun.spawn_enemy("wolf", map, Vector2i(9, 8), 1)
	var sweep_left := NightRun.spawn_enemy("wolf", map, Vector2i(8, 8), 1)
	var sweep_right := NightRun.spawn_enemy("wolf", map, Vector2i(10, 8), 1)
	var sweep_behind := NightRun.spawn_enemy("wolf", map, Vector2i(9, 10), 1)
	for enemy: Monster in [sweep_primary, sweep_left, sweep_right, sweep_behind]:
		_set_hp(enemy, 100)
	NightRun.charge = 0
	var sweep_base := NightRun.weapon_damage(greatsword, "wylder")
	var sweep_side := maxi(1, roundi(float(sweep_base) * 0.75))
	var sweep_result := PlayerAttackMoveAction.new(Vector2i.UP).apply(map)
	check(sweep_result != null and sweep_result.success, "greatsword sweep resolves as one action")
	check(sweep_primary.hp == 100 - sweep_base, "greatsword sweep deals full damage forward")
	check(sweep_left.hp == 100 - sweep_side and sweep_right.hp == 100 - sweep_side, "greatsword sweep clips both neighboring directions")
	check(sweep_behind.hp == 100, "greatsword sweep does not hit behind player")
	check(NightRun.charge == 12, "greatsword sweep grants attack charge once per action")

	# Dagger spends one action/charge event on a compact two-hit burst.
	map = _sandbox()
	var dagger := NightRun.make_weapon("misericorde")
	_equip(dagger, map)
	var dagger_target := NightRun.spawn_enemy("wolf", map, Vector2i(9, 8), 1)
	_set_hp(dagger_target, 100)
	NightRun.charge = 0
	var dagger_base := NightRun.weapon_damage(dagger, "wylder")
	var dagger_hit := maxi(1, roundi(float(dagger_base) * 0.65))
	var dagger_result := PlayerAttackMoveAction.new(Vector2i.UP).apply(map)
	check(dagger_result != null and dagger_result.success, "dagger burst resolves as one action")
	check(dagger_target.hp == 100 - dagger_hit * 2, "dagger burst lands two scaled hits")
	check(NightRun.charge == 12, "dagger burst grants attack charge once per action")

	# Baseline deterministic melee and kill rewards remain intact.
	map = _sandbox()
	greatsword = NightRun.make_weapon("greatsword")
	_equip(greatsword, map)
	var wolf := NightRun.spawn_enemy("wolf", map, Vector2i(9, 8), 1)
	_set_hp(wolf, 100)
	var expected_player_damage := NightRun.weapon_damage(greatsword, "wylder")
	Dice.set_seed(1)
	var first := PlayerAttackMoveAction.new(Vector2i.UP).apply(map)
	check(first != null and first.success and not first.message.contains("miss"), "player melee uses deterministic Nightreign resolver")
	check(wolf.hp == 100 - expected_player_damage, "player melee deals exact scaling damage")

	World.player.hp = 72
	wolf.set_meta("night_damage", 7)
	Dice.set_seed(999999)
	var enemy_hit := MeleeAction.new(wolf, Vector2i.DOWN).apply(map)
	check(enemy_hit != null and enemy_hit.success, "Nightreign enemy melee resolves")
	check(World.player.hp == 65, "Nightreign enemy melee deals exact configured damage")

	wolf.hp = expected_player_damage
	NightRun.runes = 0
	NightRun.charge = 0
	var kill := PlayerAttackMoveAction.new(Vector2i.UP).apply(map)
	check(kill != null and kill.success and wolf.is_dead, "deterministic melee can kill Nightreign enemy")
	check(map.find_monster_position(wolf) == Utils.INVALID_POS, "killed Nightreign enemy leaves map")
	check(NightRun.runes == 9, "melee kill awards enemy runes")
	check(NightRun.charge == 30, "melee kill grants attack and kill ultimate charge")

	var report := {
		"checks": checks,
		"failures": failures,
		"weapon_count": cases.size(),
		"archetypes": NightRun.weapon_profiles.archetypes.keys()
	}
	FileAccess.open("res://docs/WEAPON_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("WEAPON QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
