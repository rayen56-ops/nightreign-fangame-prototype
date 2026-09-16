extends Node

var checks := 0
var failures: Array[String] = []
const CENTER := Vector2i(9, 9)
const ALLOWED_GRADES := ["S", "A", "B", "C", "D", "E"]
const ALLOWED_PATTERNS := ["single", "sweep", "line"]

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("T1 %s: %s" % ["PASS" if value else "FAIL", label])

func _ready() -> void:
	call_deferred("run")

func new_arena(id: String) -> Map:
	CharacterCatalog.select_character("wylder")
	World.initialize(16092026)
	var arena := NightRun.make_arena(1, "")
	arena.id = id
	World.current_map = arena
	World.game_over = false
	World.player.is_dead = false
	arena.get_cell(CENTER).monster = World.player
	return arena

func clear_enemies(arena: Map) -> void:
	for monster in arena.get_monsters().duplicate():
		if monster != World.player:
			arena.find_and_remove_monster(monster)

func equip_weapon(id: String) -> Item:
	var item := NightRun.make_weapon(id)
	World.player.add_item(item)
	World.player.equipment.equip(item, Equipment.Slot.MELEE)
	return item

func test_data_contracts() -> void:
	check(String(NightRun.data.revision).begins_with("T1"), "combat database carries a T1 revision")
	check(NightRun.data.weapon_archetypes.size() >= 7, "weapon archetype catalogue is established")
	for character_id: String in NightRun.data.characters:
		var character: Dictionary = NightRun.data.characters[character_id]
		for stat: String in character.grades:
			check(String(character.grades[stat]) in ALLOWED_GRADES, "%s %s uses only S-E grades" % [character_id, stat])
	for archetype_id: String in NightRun.data.weapon_archetypes:
		var profile: Dictionary = NightRun.data.weapon_archetypes[archetype_id]
		check(int(profile.get("reach", 0)) >= 1, "%s has a positive reach contract" % archetype_id)
		check(String(profile.get("pattern", "")) in ALLOWED_PATTERNS, "%s has a supported attack pattern" % archetype_id)
		check(int(profile.get("poise", -1)) >= 0, "%s defines poise pressure" % archetype_id)
	for weapon_id: String in NightRun.data.weapons:
		var weapon: Dictionary = NightRun.data.weapons[weapon_id]
		var archetype := String(weapon.get("archetype", ""))
		check(NightRun.data.weapon_archetypes.has(archetype), "%s references a real archetype" % weapon_id)
		for stat: String in weapon.scaling:
			check(String(weapon.scaling[stat]) in ALLOWED_GRADES, "%s scaling stays inside S-E" % weapon_id)

func test_greatsword_sweep() -> void:
	var arena := new_arena("t1_sweep")
	clear_enemies(arena)
	equip_weapon("greatsword")
	var left := NightRun.spawn_enemy("soldier", arena, CENTER + Vector2i(-1, -1), 1)
	var front := NightRun.spawn_enemy("soldier", arena, CENTER + Vector2i(0, -1), 1)
	var right := NightRun.spawn_enemy("soldier", arena, CENTER + Vector2i(1, -1), 1)
	var result := NightWeaponAttackAction.new(Vector2i.UP).apply(arena)
	check(result.success, "greatsword sweep is a legal deliberate attack")
	check(left.hp < left.max_hp and front.hp < front.max_hp and right.hp < right.max_hp, "greatsword sweep hits the three-tile forward fan")

func test_reach_weapons() -> void:
	var arena := new_arena("t1_reach")
	clear_enemies(arena)
	equip_weapon("spear")
	var spear_target := NightRun.spawn_enemy("soldier", arena, CENTER + Vector2i.UP * 2, 1)
	var result := NightWeaponAttackAction.new(Vector2i.UP).apply(arena)
	check(result.success and spear_target.hp < spear_target.max_hp, "spear reaches a target two cells away")

	clear_enemies(arena)
	var too_far := NightRun.spawn_enemy("soldier", arena, CENTER + Vector2i.UP * 3, 1)
	var too_far_hp := too_far.hp
	result = NightWeaponAttackAction.new(Vector2i.UP).apply(arena)
	check(result.success and too_far.hp == too_far_hp, "spear does not exceed its two-cell reach")

	clear_enemies(arena)
	equip_weapon("glintstone_staff")
	var staff_target := NightRun.spawn_enemy("soldier", arena, CENTER + Vector2i.UP * 4, 1)
	result = NightWeaponAttackAction.new(Vector2i.UP).apply(arena)
	check(result.success and staff_target.hp < staff_target.max_hp, "staff line attack reaches four cells")

func test_bleed_threshold() -> void:
	var arena := new_arena("t1_bleed")
	clear_enemies(arena)
	equip_weapon("uchigatana")
	var target := NightRun.spawn_enemy("gladius", arena, CENTER + Vector2i.UP, 20)
	var start_hp := target.hp
	var first := NightWeaponAttackAction.new(Vector2i.UP).apply(arena)
	var hp1 := target.hp
	var second := NightWeaponAttackAction.new(Vector2i.UP).apply(arena)
	var hp2 := target.hp
	var third := NightWeaponAttackAction.new(Vector2i.UP).apply(arena)
	var hp3 := target.hp
	check(first.success and second.success and third.success, "katana attacks execute through one action contract")
	var damage1 := start_hp - hp1
	var damage2 := hp1 - hp2
	var damage3 := hp2 - hp3
	check(damage1 == damage2, "bleed does not burst below threshold")
	check(damage3 > damage2, "third katana hit crosses threshold and bursts blood loss")
	check(int(target.get_meta("night_buildup_bleed", -1)) == 2, "bleed overflow is preserved after proc")

func test_turn_economy() -> void:
	var arena := new_arena("t1_turn")
	clear_enemies(arena)
	equip_weapon("greatsword")
	var before := World.current_turn
	var result := World.apply_player_action(NightWeaponAttackAction.new(Vector2i.UP))
	check(result != null and result.success, "empty deliberate weapon swing remains a legal committed action")
	check(World.current_turn == before + 1, "one deliberate weapon swing consumes exactly one turn")
	before = World.current_turn
	result = World.apply_player_action(NightWeaponAttackAction.new(Vector2i.ZERO))
	check(result != null and not result.success and World.current_turn == before, "invalid zero-direction attack consumes zero turns")

func run() -> void:
	test_data_contracts()
	test_greatsword_sweep()
	test_reach_weapons()
	test_bleed_threshold()
	test_turn_economy()
	var report := {
		"stage": "T1-combat-language",
		"checks": checks,
		"failures": failures,
		"engine": Engine.get_version_info().string,
		"archetypes": NightRun.data.weapon_archetypes.size(),
		"weapons": NightRun.data.weapons.size()
	}
	FileAccess.open("res://docs/T1_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("T1 QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
