extends Node

var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("M2 CONTROLLER QA %s: %s" % ["PASS" if value else "FAIL", label])

func _ready() -> void:
	call_deferred("run")

func _sandbox(character_id: String = "wylder") -> Map:
	CharacterCatalog.select_character(character_id)
	World.initialize(24092026)
	var map := NightRun.make_arena(1, "")
	map.id = "controller_qa"
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

func run() -> void:
	# Standard Godot joypad positions map to Nightreign combat semantics.
	check(NightControllerInput.button_command(JOY_BUTTON_DPAD_UP) == &"move_n", "D-pad up maps north")
	check(NightControllerInput.button_command(JOY_BUTTON_DPAD_DOWN) == &"move_s", "D-pad down maps south")
	check(NightControllerInput.button_command(JOY_BUTTON_DPAD_LEFT) == &"move_w", "D-pad left maps west")
	check(NightControllerInput.button_command(JOY_BUTTON_DPAD_RIGHT) == &"move_e", "D-pad right maps east")
	check(NightControllerInput.button_command(JOY_BUTTON_A) == &"interact", "A/Cross is context interact")
	check(NightControllerInput.button_command(JOY_BUTTON_X) == &"skill", "X/Square triggers skill")
	check(NightControllerInput.button_command(JOY_BUTTON_Y) == &"ultimate", "Y/Triangle triggers ultimate")
	check(NightControllerInput.button_command(JOY_BUTTON_LEFT_SHOULDER) == &"flask", "left shoulder uses flask")
	check(NightControllerInput.button_command(JOY_BUTTON_RIGHT_SHOULDER) == &"cast", "right shoulder casts catalyst")
	check(NightControllerInput.button_command(JOY_BUTTON_LEFT_STICK) == &"wait", "left stick click waits")
	check(NightControllerInput.button_command(JOY_BUTTON_RIGHT_STICK) == &"grace", "right stick click uses grace")
	check(NightControllerInput.button_command(JOY_BUTTON_START) == &"inventory", "start opens inventory")
	check(NightControllerInput.button_command(JOY_BUTTON_BACK) == &"equipment", "back/view opens equipment")
	check(NightControllerInput.button_command(JOY_BUTTON_B) == &"", "B/Circle stays reserved for cancel")

	# Left stick is quantized into eight deliberate tile directions.
	check(NightControllerInput.axis_direction(Vector2(0.9, 0.0)) == Vector2i.RIGHT, "stick east quantizes east")
	check(NightControllerInput.axis_direction(Vector2(-0.9, 0.0)) == Vector2i.LEFT, "stick west quantizes west")
	check(NightControllerInput.axis_direction(Vector2(0.0, -0.9)) == Vector2i.UP, "stick north quantizes north")
	check(NightControllerInput.axis_direction(Vector2(0.0, 0.9)) == Vector2i.DOWN, "stick south quantizes south")
	check(NightControllerInput.axis_direction(Vector2(0.8, -0.8)) == Vector2i.UP + Vector2i.RIGHT, "stick northeast keeps diagonal")
	check(NightControllerInput.axis_direction(Vector2(-0.8, -0.8)) == Vector2i.UP + Vector2i.LEFT, "stick northwest keeps diagonal")
	check(NightControllerInput.axis_direction(Vector2(0.8, 0.8)) == Vector2i.DOWN + Vector2i.RIGHT, "stick southeast keeps diagonal")
	check(NightControllerInput.axis_direction(Vector2(-0.8, 0.8)) == Vector2i.DOWN + Vector2i.LEFT, "stick southwest keeps diagonal")
	check(NightControllerInput.axis_direction(Vector2(0.2, 0.1)) == Vector2i.ZERO, "small stick noise stays in deadzone")
	check(NightControllerInput.is_neutral(Vector2(0.1, 0.1)), "small stick input rearms step latch")
	check(not NightControllerInput.is_neutral(Vector2(0.7, 0.0)), "held stick is not neutral")

	# Controller catalyst fire uses facing and real weapon data, without a mouse cursor.
	var map := _sandbox()
	var turn_before := World.current_turn
	var staff := _equip("glintstone_staff")
	check(not NightControllerInput.catalyst_profile(staff).is_empty(), "staff is recognized as catalyst")
	check(NightControllerInput.facing_cast_target(map, World.player, Vector2i.UP) == Vector2i(9, 3), "staff facing cast reaches six visible tiles")
	check(NightControllerInput.facing_cast_target(map, World.player, Vector2i.UP + Vector2i.LEFT) == Vector2i(3, 3), "staff facing cast supports diagonal direction")
	var blocker := NightRun.spawn_enemy("wolf", map, Vector2i(9, 6), 1)
	check(NightControllerInput.facing_cast_target(map, World.player, Vector2i.UP) == Vector2i(9, 6), "facing cast stops at first monster")
	map.find_and_remove_monster(blocker)
	check(NightControllerInput.facing_cast_target(map, World.player, Vector2i.UP) == Vector2i(9, 3), "cast range restores after blocker leaves")

	var seal := _equip("finger_seal")
	check(not NightControllerInput.catalyst_profile(seal).is_empty(), "seal is recognized as catalyst")
	check(NightControllerInput.facing_cast_target(map, World.player, Vector2i.UP) == Vector2i(9, 5), "seal facing cast respects four-tile range")
	check(NightControllerInput.facing_cast_target(map, World.player, Vector2i.ZERO) == Utils.INVALID_POS, "zero facing refuses controller cast")
	var sword := _equip("longsword")
	check(NightControllerInput.catalyst_profile(sword).is_empty(), "melee weapon is not misclassified as catalyst")
	check(NightControllerInput.facing_cast_target(map, World.player, Vector2i.UP) == Utils.INVALID_POS, "melee weapon has no facing cast target")
	check(World.current_turn == turn_before, "controller targeting helpers consume no turn")

	var driver := NightControllerDriver.new()
	check(driver != null, "controller gameplay driver instantiates headlessly")
	driver.free()

	var report := {
		"checks": checks,
		"failures": failures,
		"eight_way": true,
		"mouse_free_cast": true,
		"turn_safe_targeting": World.current_turn == turn_before,
	}
	FileAccess.open("res://docs/M2_CONTROLLER_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("M2 CONTROLLER QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
