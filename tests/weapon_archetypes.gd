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

func _sandbox(id: String = "wylder") -> Map:
	CharacterCatalog.select_character(id)
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
		"longsword": {"archetype": "straight_sword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH, "pattern": "single", "casts": false, "sprite": "night-longsword"},
		"greatsword": {"archetype": "greatsword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH, "pattern": "sweep", "casts": false, "sprite": "night-greatsword"},
		"uchigatana": {"archetype": "katana", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH, "pattern": "single", "casts": false, "sprite": "night-katana"},
		"rapier": {"archetype": "thrusting_sword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.PIERCE, "pattern": "thrust", "casts": false, "sprite": "night-rapier"},
		"misericorde": {"archetype": "dagger", "item": Item.Type.KNIFE, "skill": Skills.Type.KNIFE, "damage": Damage.Type.PIERCE, "pattern": "burst", "casts": false, "sprite": "night-dagger"},
		"glintstone_staff": {"archetype": "staff", "item": Item.Type.WAND, "skill": Skills.Type.UTILITY, "damage": Damage.Type.BLUNT, "pattern": "single", "casts": true, "sprite": "night-staff"},
		"finger_seal": {"archetype": "seal", "item": Item.Type.WAND, "skill": Skills.Type.UTILITY, "damage": Damage.Type.BLUNT, "pattern": "single", "casts": true, "sprite": "night-seal"},
		"sacred_blade": {"archetype": "straight_sword", "item": Item.Type.SWORD, "skill": Skills.Type.SWORD, "damage": Damage.Type.SLASH, "pattern": "single", "casts": false, "sprite": "night-sacred-blade"}
	}

	var map := _sandbox()
	var seen_sprite_coords: Dictionary = {}
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
		check(profile.has("cast") == expected.casts, "cast capability " + weapon_id)
		check(weapon.sprite_name == StringName(expected.sprite), "dedicated sprite identity " + weapon_id)
		var sprite_coords := ItemTiles.get_coords(weapon.sprite_name)
		check(sprite_coords != Utils.INVALID_POS, "sprite exists in shared ItemTiles atlas " + weapon_id)
		check(not seen_sprite_coords.has(sprite_coords), "weapon sprite coordinate is unique " + weapon_id)
		seen_sprite_coords[sprite_coords] = weapon_id
		check(weapon.is_weapon(), "recognized as weapon " + weapon_id)
		World.player.add_item(weapon)
		check(PlayerEquipAction.new(weapon, Equipment.Slot.MELEE).apply(map).success, "equips in melee slot " + weapon_id)
		var clone := ItemFactory.clone(weapon)
		check(clone.get_meta("night_weapon", "") == weapon_id and clone.get_meta("night_archetype", "") == expected.archetype, "clone preserves weapon metadata " + weapon_id)
		check(NightRun.weapon_description(weapon).contains("Archetype:"), "description exposes archetype " + weapon_id)

	check(seen_sprite_coords.size() == cases.size(), "all Nightreign weapons have unique atlas cells")

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

	# Rapier attacks through one empty tile, but never through blockers.
	map = _sandbox()
	var rapier := NightRun.make_weapon("rapier")
	_equip(rapier, map)
	var rapier_target := NightRun.spawn_enemy("wolf", map, Vector2i(9, 7), 1)
	_set_hp(rapier_target, 100)
	NightRun.charge = 0
	var rapier_damage := NightRun.weapon_damage(rapier, "wylder")
	var thrust := PlayerAttackMoveAction.new(Vector2i.UP).apply(map)
	check(thrust != null and thrust.success, "rapier thrust reaches a target two tiles away")
	check(map.find_monster_position(World.player) == Vector2i(9, 9), "rapier thrust attacks without stepping forward")
	check(rapier_target.hp == 100 - rapier_damage and NightRun.charge == 12, "rapier thrust deals one deterministic hit and one charge event")
	map = _sandbox()
	rapier = NightRun.make_weapon("rapier")
	_equip(rapier, map)
	var advance := PlayerAttackMoveAction.new(Vector2i.UP).apply(map)
	check(advance != null and advance.success and map.find_monster_position(World.player) == Vector2i(9, 8), "rapier moves normally when no reach target exists")
	map = _sandbox()
	rapier = NightRun.make_weapon("rapier")
	_equip(rapier, map)
	var blocked_target := NightRun.spawn_enemy("wolf", map, Vector2i(9, 7), 1)
	_set_hp(blocked_target, 100)
	var blocker := Obstacle.new()
	blocker.type = Obstacle.Type.DOOR_CLOSED
	map.get_cell(Vector2i(9, 8)).obstacle = blocker
	var blocked_thrust := PlayerAttackMoveAction.new(Vector2i.UP).apply(map)
	check(blocked_target.hp == 100, "rapier cannot thrust through a closed door")
	check(blocked_thrust != null and not blocked_thrust.success, "blocked rapier action does not phase through obstacle")

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

	# The existing fire-at-location gesture becomes catalyst casting when a staff/seal is in main hand.
	map = _sandbox()
	var staff := NightRun.make_weapon("glintstone_staff")
	_equip(staff, map)
	var staff_target := NightRun.spawn_enemy("wolf", map, Vector2i(9, 4), 1)
	_set_hp(staff_target, 100)
	NightRun.charge = 0
	var staff_damage := NightRun.weapon_damage(staff, "wylder")
	var cast_turn := World.current_turn
	var staff_cast := World.apply_player_action(PlayerFireAction.new(Vector2i(9, 4)))
	check(staff_cast != null and staff_cast.success and World.current_turn == cast_turn + 1, "staff cast consumes exactly one turn")
	check(staff_target.hp == 100 - staff_damage, "staff cast hits first monster on line with INT-scaled damage")
	check(NightRun.charge == 12, "staff cast grants attack charge once")
	cast_turn = World.current_turn
	var too_far := World.apply_player_action(PlayerFireAction.new(Vector2i(9, 2)))
	check(too_far != null and not too_far.success and World.current_turn == cast_turn, "out-of-range staff cast fails without spending a turn")

	map = _sandbox("revenant")
	seal = NightRun.make_weapon("finger_seal")
	_equip(seal, map)
	var seal_target := NightRun.spawn_enemy("soldier", map, Vector2i(9, 5), 1)
	_set_hp(seal_target, 100)
	NightRun.charge = 0
	var seal_damage := NightRun.weapon_damage(seal, "revenant")
	var seal_cast := PlayerFireAction.new(Vector2i(9, 5)).apply(map)
	check(seal_cast != null and seal_cast.success, "sacred seal uses fire-at-location cast path")
	check(seal_target.hp == 100 - seal_damage, "sacred seal deals FAI-scaled ranged damage")
	seal_target.hp = seal_damage
	NightRun.runes = 0
	NightRun.charge = 0
	var seal_kill := PlayerFireAction.new(Vector2i(9, 5)).apply(map)
	check(seal_kill != null and seal_kill.success and seal_target.is_dead, "sacred cast can kill Nightreign enemy")
	check(NightRun.runes == 12 and NightRun.charge == 30, "spell kill grants runes plus attack/kill charge")

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