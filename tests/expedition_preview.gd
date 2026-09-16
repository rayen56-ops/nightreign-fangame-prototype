extends Node
var failures: Array[String] = []
var checks := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
	print("M1 UI %s: %s" % ["PASS" if condition else "FAIL", label])

func _ready() -> void:
	call_deferred("run")

func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var rendered := get_viewport().get_texture().get_image()
	rendered.resize(1152,648,Image.INTERPOLATE_NEAREST)
	rendered.save_png("res://docs/" + id + ".png")

func run() -> void:
	for id: String in ["wylder", "revenant"]:
		CharacterCatalog.select_character(id)
		var game: Node = load("res://scenes/game/game.tscn").instantiate()
		get_tree().root.add_child(game)
		get_tree().current_scene = game
		await get_tree().create_timer(0.2).timeout
		World.handle_level_transition("level_3", Obstacle.Type.STAIRS_DOWN)
		var map := World.current_map
		map.find_and_remove_monster(World.player)
		map.get_cell(Vector2i(9,8)).monster = World.player
		World.update_vision()
		game._update_actors()
		await game._handle_player_action(PlayerRestAction.new())
		await get_tree().create_timer(0.2).timeout
		check(not NightRun.telegraphs.is_empty(), id + " visible boss telegraph")
		await capture("m1-" + id + "-boss")
		var turn := World.current_turn
		if id == "wylder":
			Input.action_press("skill")
			get_tree().create_timer(0.15).timeout.connect(func() -> void:
				check(Modals.modal_stack[0] is DirectionModal, "R opens direction targeting")
				Modals.modal_stack[0].direction_selected.emit(Vector3i(0,-1,0))
				Modals.modal_stack[0]._close_modal())
			var action: BaseAction = await game._check_player_input()
			Input.action_release("skill")
			await game._handle_player_action(action)
			check(World.current_turn == turn + 1 and map.find_monster_position(World.player) == Vector2i(9,5), "directional claw moves player to large enemy")
		else:
			Input.action_press("skill")
			var action: BaseAction = await game._check_player_input()
			Input.action_release("skill")
			await game._handle_player_action(action)
			check(World.current_turn == turn + 1 and NightRun.cooldown == 8, "R summons family without targeting")
			await capture("m1-revenant-family")
		var hp_top: Control = game.get_node("UI/HUD/%HP")
		var left: Control = game.get_node("UI/HUD/%LeftPanel")
		print("SIDEBAR GEOMETRY ",left.get_global_rect()," HUD ", game.get_node("UI/HUD").get_global_rect())
		check(left.get_global_rect().position.y >= 0 and left.get_global_rect().end.y <= 324, "entire sidebar fits viewport " + id)
		check(hp_top.get_global_rect().position.y >= 0 and hp_top.get_global_rect().end.y <= 324, "health HUD within viewport " + id)
		check(game.get_node("UI/HUD/%InventoryButton").get_global_rect().end.y <= 324, "inventory button within viewport " + id)
		# Outcome fixture: use the real death and victory signals, then inspect the modal.
		for monster in map.get_monsters().duplicate():
			if monster.get_meta("night_enemy", "") == "gladius": NightRun.hurt(monster, monster.hp, ActionResult.new())
		await get_tree().create_timer(1.3).timeout
		check(World.game_over and Modals.has_visible_modals(), id + " victory opens result modal")
		var modal: GameOverModal = Modals.modal_stack[0]
		check(modal.get_node("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/GameOverLabel").text == "NIGHTLORD FELLED", "victory title " + id)
		await capture("m1-" + id + "-victory")
		modal._on_main_menu_button_pressed()
		await get_tree().create_timer(0.3).timeout
		check(get_tree().current_scene.name == "MainMenu", "result returns to character selection " + id)
		get_tree().current_scene.queue_free()
		await get_tree().process_frame
	var report := {"checks": checks, "failures": failures, "screenshots": "Godot framebuffer of staged gameplay QA scenes; victory screenshot uses a lethal-hit fixture"}
	FileAccess.open("res://docs/M1_UI_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("M1 UI QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)

