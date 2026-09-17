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

func run() -> void:
	var cases := {
		"longsword": {"archetype": "straight_sword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH},
		"greatsword": {"archetype": "greatsword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH},
		"uchigatana": {"archetype": "katana", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH},
		"misericorde": {"archetype": "dagger", "item": Item.Type.KNIFE, "skill": Skills.Type.KNIFE, "damage": Damage.Type.PIERCE},
		"glintstone_staff": {"archetype": "staff", "item": Item.Type.WAND, "skill": Skills.Type.UTILITY, "damage": Damage.Type.BLUNT},
		"finger_seal": {"archetype": "seal", "item": Item.Type.WAND, "skill": Skills.Type.UTILITY, "damage": Damage.Type.BLUNT},
		"sacred_blade": {"archetype": "straight_sword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH}
	}

	var map := _sandbox()
	for weapon_id: String in cases:
		var expected: Dictionary = cases[weapon_id]
		var weapon := NightRun.make_weapon(weapon_id)
		check(weapon.get_meta("night_weapon", "") == weapon_id, "weapon identity " + weapon_id)
		check(weapon.get_meta("night_archetype", "") == expected.archetype, "archetype " + weapon_id)
		check(weapon.type == expected.item, "item type " + weapon_id)
		check(weapon.skill_type == expected.skill, "skill type " + weapon_id)
		check(weapon.damage_types.size() == 1 and weapon.damage_types[0] == expected.damage, "damage profile " + weapon_id)
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

	World.player.add_item(greatsword)
	World.player.equipment.equip(greatsword, Equipment.Slot.MELEE)
	var wolf := NightRun.spawn_enemy("wolf", map, Vector2i(9, 8), 1)
	wolf.max_hp = 100
	wolf.hp = 100
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
