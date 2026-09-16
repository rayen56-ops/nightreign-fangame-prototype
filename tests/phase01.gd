extends Node
var failures: Array[String] = []
var checks: int = 0
var game: Node
var enemy_updates: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("QA %s: %s" % ["PASS" if value else "FAIL", label])

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	if "--qa-revenant" in OS.get_cmdline_user_args():
		CharacterCatalog.select_character("revenant")
	seed(15092026)
	game = load("res://scenes/game/game.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await get_tree().create_timer(0.3).timeout
	var map: Map = World.current_map
	check(Constants.TILE_SIZE == 16, "16 pixel logical grid")
	check(map.rooms.size() > 0 and map.has_stairs_up() and map.has_stairs_down(), "BSP dungeon with entrances")
	var start := map.find_monster_position(World.player)
	check(map.is_visible(start) and map.was_seen(start), "FOV and seen memory initialized")
	var hidden := 0
	for x in map.width:
		for y in map.height:
			if not map.is_visible(Vector2i(x, y)):
				hidden += 1
	check(hidden > 0, "fog conceals unseen tiles")
	var player_actor: Actor = get_tree().get_first_node_in_group("player")
	check(player_actor.character.region_rect.size == Vector2(32, 32), "Wylder frame is 32x32")
	check(player_actor.character.offset == Vector2(-8, -8), "frame pivot aligned to one tile feet")
	var required := ["move_n", "move_ne", "move_e", "move_se", "move_s", "move_sw", "move_w", "move_nw", "wait", "confirm", "cancel", "inventory", "interact", "skill", "ultimate"]
	for action: String in required:
		check(InputMap.has_action(action), "InputMap " + action)
	# Verify production enemy turn processing before isolating the movement fixture.
	World.energy_updated.connect(func(monster: Monster) -> void:
		if monster != World.player:
			enemy_updates += 1)
	var turn := World.current_turn
	World.apply_player_action(PlayerRestAction.new())
	check(World.current_turn == turn + 1 and enemy_updates > 0, "rest resolves one turn and processes enemy energy")
	# Choose a real generated room interior and remove enemies only in this test process.
	for monster in map.get_monsters():
		if monster != World.player:
			map.find_and_remove_monster(monster)
	var center := Vector2i(-1, -1)
	for x in range(2, map.width - 2):
		for y in range(2, map.height - 2):
			var valid := true
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var cell := map.get_cell(Vector2i(x + dx, y + dy))
					valid = valid and cell.is_walkable() and cell.obstacle == null
			if valid:
				center = Vector2i(x, y)
	check(center != Vector2i(-1, -1), "generated dungeon contains movement test area")
	var directions := [Vector2i.UP, Vector2i(1,-1), Vector2i.RIGHT, Vector2i(1,1), Vector2i.DOWN, Vector2i(-1,1), Vector2i.LEFT, Vector2i(-1,-1)]
	var inputs := ["move_n", "move_ne", "move_e", "move_se", "move_s", "move_sw", "move_w", "move_nw"]
	for i in directions.size():
		map.find_and_remove_monster(World.player)
		map.get_cell(center).monster = World.player
		turn = World.current_turn
		Input.action_press(inputs[i])
		var action: BaseAction = await game._check_player_input()
		Input.action_release(inputs[i])
		var result := World.apply_player_action(action)
		var destination: Vector2i = center + directions[i]
		check(result != null and result.success and map.find_monster_position(World.player) == destination and World.current_turn == turn + 1, "input %s moves exactly one grid action" % inputs[i])
		check(map.get_monster(center) == null and map.get_monster(destination) == World.player, "single tile occupancy " + inputs[i])
		player_actor.init(center)
		player_actor.move_to(destination)
		await get_tree().create_timer(0.14).timeout
		check(World.current_turn == turn + 1 and player_actor.position == Vector2(destination * 16), "animation cannot add turns " + inputs[i])
	var weapon := World.player.equipment.get_equipped_item(Equipment.Slot.MELEE)
	check(weapon != null and World.player.has_item(weapon), "initial weapon is in inventory")
	var unequip := World.apply_player_action(PlayerUnequipAction.new(weapon))
	check(unequip.success and not World.player.equipment.is_item_equipped(weapon), "unequip action")
	var equip := World.apply_player_action(PlayerEquipAction.new(weapon, Equipment.Slot.MELEE))
	check(equip.success and World.player.equipment.get_equipped_item(Equipment.Slot.MELEE) == weapon, "equip action")
	# A wall rejection must not consume a turn, even with an oversized sprite.
	map.find_and_remove_monster(World.player)
	map.get_cell(center).monster = World.player
	var blocked_cell := map.get_cell(center + Vector2i.RIGHT)
	var previous_type := blocked_cell.terrain.type
	blocked_cell.terrain.type = Terrain.Type.DUNGEON_WALL
	turn = World.current_turn
	var blocked := World.apply_player_action(PlayerAttackMoveAction.new(Vector2i.RIGHT))
	check(not blocked.success and World.current_turn == turn and map.find_monster_position(World.player) == center, "blocked movement does not spend a turn")
	blocked_cell.terrain.type = previous_type
	var fingerprints: Array[String] = []
	for generation_seed in [11, 22, 33]:
		seed(generation_seed)
		World.initialize()
		var generated := World.current_map
		var fingerprint := ""
		for x in generated.width:
			for y in generated.height:
				fingerprint += str(generated.get_terrain(Vector2i(x,y)).type)
		fingerprints.append(fingerprint.sha256_text())
		check(generated.rooms.size() > 0 and generated.has_stairs_up() and generated.has_stairs_down(), "procedural dungeon seed %d" % generation_seed)
	check(fingerprints[0] != fingerprints[1] and fingerprints[1] != fingerprints[2], "different seeds generate different maps")
	# New reproducible dungeon for screenshot comparison; freeze only rendering clocks.
	seed(15092026)
	game._initialize()
	await get_tree().create_timer(0.5).timeout
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	player_actor = get_tree().get_first_node_in_group("player")
	player_actor.nightreign_visual.set_process(false)
	player_actor.nightreign_visual.play("idle")
	var original_turn := World.current_turn
	var original_pos := World.current_map.find_monster_position(World.player)
	var original_hp := World.player.hp
	var original_map := World.current_map
	var camera_position: Vector2 = game.get_node("CameraController").position
	for profile in [DisplayProfiles.Profile.DESKTOP_STANDARD, DisplayProfiles.Profile.DESKTOP_PET]:
		DisplayProfiles.apply_profile(profile)
		await get_tree().create_timer(0.25).timeout
		var expected := Vector2i(1152, 648) if profile == 0 else Vector2i(576, 324)
		check(get_window().size == expected, "physical window %s" % expected)
		check(get_viewport().get_visible_rect().size == Vector2(576, 324), "logical viewport stays 576x324")
		check(World.current_map == original_map and World.current_turn == original_turn and World.player.hp == original_hp and World.current_map.find_monster_position(World.player) == original_pos, "profile preserves game state")
		check(game.get_node("CameraController").position == camera_position and game.get_node("CameraController").zoom == Vector2.ONE, "profile preserves camera framing")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var screenshot := get_viewport().get_texture().get_image()
			screenshot.save_png("res://docs/logical_%s.png" % ("standard" if profile == 0 else "pet"))
			# Export the actual logical render at the verified window output size.
			# This avoids capturing unrelated overlapping desktop windows.
			screenshot.resize(expected.x, expected.y, Image.INTERPOLATE_NEAREST)
			screenshot.save_png("res://docs/render_%s.png" % ("standard" if profile == 0 else "pet"))
	Modals.toggle_inventory(InventoryModal.Tab.INVENTORY)
	await get_tree().create_timer(0.2).timeout
	check(Modals.has_visible_modals(), "inventory modal opens")
	check(Modals.modal_stack[0].get_parent() == game.get_node("UI"), "inventory resides in separate UI layer")
	Modals.hide_inventory()
	Modals.toggle_inventory(InventoryModal.Tab.EQUIPMENT)
	await get_tree().create_timer(0.2).timeout
	check(Modals.has_visible_modals(), "equipment modal opens")
	Modals.hide_inventory()
	var report := {"checks": checks, "failures": failures, "engine": Engine.get_version_info().string}
	FileAccess.open("res://docs/qa-results.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
