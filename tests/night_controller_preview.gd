extends Node

var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("M2 CONTROLLER PREVIEW QA %s: %s" % ["PASS" if value else "FAIL", label])

func _ready() -> void:
	call_deferred("run")

func _sandbox() -> Map:
	CharacterCatalog.select_character("wylder")
	World.initialize(25092026)
	var map := NightRun.make_arena(1, "")
	map.id = "controller_preview_qa"
	World.current_map = map
	map.get_cell(Vector2i(9, 9)).monster = World.player
	for x in map.width:
		for y in map.height:
			map.visible_cells[x][y] = true
	return map

func _equip(id: String) -> Item:
	var weapon := NightRun.make_weapon(id)
	World.player.add_item(weapon)
	World.player.equipment.equip(weapon, Equipment.Slot.MELEE)
	return weapon

func _preview(map: Map, id: String, facing: Vector2i) -> Dictionary:
	var weapon := _equip(id)
	var profile := NightRun.weapon_archetype(id)
	var affinity := StringName(String(weapon.get_meta("night_affinity", "physical")))
	return NightControllerPreview.build(map, World.player, profile, affinity, facing)

func run() -> void:
	var map := _sandbox()
	var turn_before := World.current_turn

	var preview := _preview(map, "longsword", Vector2i.RIGHT)
	check(preview.input_mode == "controller", "straight sword preview is tagged as controller-owned")
	check(preview.pattern == "single", "straight sword preserves single attack pattern")
	check(preview.cells == [Vector2i(10, 9)], "straight sword shows one facing tile")
	check(preview.target == Vector2i(10, 9), "straight sword marker follows facing")

	preview = _preview(map, "greatsword", Vector2i.RIGHT)
	check(preview.input_mode == "controller", "greatsword preview is controller-owned")
	check(preview.pattern == "sweep", "greatsword preserves sweep pattern")
	check(preview.cells.size() == 3, "greatsword controller preview exposes all three sweep cells")
	check(preview.cells == [Vector2i(10, 9), Vector2i(10, 8), Vector2i(10, 10)], "greatsword east footprint matches mouse/combat geometry")
	check(preview.target == Vector2i(10, 9), "greatsword marker stays on forward tile")

	preview = _preview(map, "rapier", Vector2i.RIGHT)
	check(preview.pattern == "thrust", "rapier controller preview preserves thrust pattern")
	check(preview.cells == [Vector2i(10, 9), Vector2i(11, 9)], "rapier controller preview shows two-tile reach")
	check(preview.target == Vector2i(11, 9), "rapier marker sits on full-reach tile")
	var blocker := NightRun.spawn_enemy("wolf", map, Vector2i(10, 9), 1)
	preview = _preview(map, "rapier", Vector2i.RIGHT)
	check(preview.cells == [Vector2i(10, 9)], "rapier preview stops at first occupied tile")
	check(preview.target == Vector2i(10, 9), "blocked rapier marker moves to collision tile")
	map.find_and_remove_monster(blocker)

	preview = _preview(map, "misericorde", Vector2i.UP + Vector2i.LEFT)
	check(preview.pattern == "burst", "dagger controller preview preserves burst identity")
	check(preview.cells == [Vector2i(8, 8)], "dagger supports diagonal facing preview")
	check(preview.target == Vector2i(8, 8), "dagger marker follows diagonal facing")

	preview = _preview(map, "glintstone_staff", Vector2i.RIGHT)
	check(preview.pattern == "cast", "staff controller preview identifies cast")
	check(preview.affinity == &"magic", "staff controller preview keeps magic affinity")
	check(preview.cells.size() == 6, "staff controller preview shows six-tile trajectory")
	check(preview.target == Vector2i(15, 9), "staff marker reaches six tiles without cursor")
	var cast_blocker := NightRun.spawn_enemy("wolf", map, Vector2i(12, 9), 1)
	preview = _preview(map, "glintstone_staff", Vector2i.RIGHT)
	check(preview.cells == [Vector2i(10, 9), Vector2i(11, 9), Vector2i(12, 9)], "staff trajectory stops at first monster")
	check(preview.target == Vector2i(12, 9), "staff controller target snaps to collision monster")
	map.find_and_remove_monster(cast_blocker)

	preview = _preview(map, "finger_seal", Vector2i.UP)
	check(preview.affinity == &"holy", "seal controller preview keeps holy affinity")
	check(preview.cells.size() == 4, "seal controller preview respects four-tile range")
	check(preview.target == Vector2i(9, 5), "seal target reaches exactly four tiles")
	check(NightControllerPreview.build(map, World.player, NightRun.weapon_archetype("finger_seal"), &"holy", Vector2i.ZERO).is_empty(), "zero facing produces no controller preview")

	var driver := NightControllerDriver.new()
	NightRun.facing = Vector2i.DOWN
	driver.set_controller_active()
	check(driver.controller_active, "controller activity enables controller preview ownership")
	check(driver.controller_preview_direction() == Vector2i.DOWN, "controller activation inherits current character facing")
	driver.set_controller_active(Vector2i.LEFT)
	check(driver.controller_preview_direction() == Vector2i.LEFT, "deliberate controller direction updates preview facing")
	driver.set_controller_inactive()
	check(not driver.controller_active, "keyboard or mouse handoff can disable controller ownership")
	driver.free()

	check(World.current_turn == turn_before, "building and switching previews consumes no turn")

	var report := {
		"checks": checks,
		"failures": failures,
		"controller_owned": true,
		"patterns": ["single", "sweep", "thrust", "burst", "cast"],
		"collision_clipped": true,
		"turn_safe": World.current_turn == turn_before,
	}
	FileAccess.open("res://docs/M2_CONTROLLER_PREVIEW_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("M2 CONTROLLER PREVIEW QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
