extends Node
var checks: int = 0
var failures: Array[String] = []
const MENU_BUTTON_ROOT := "CenterContainer/PanelContainer/MarginContainer/VBoxContainer/"

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
	print("CHARACTER QA %s: %s" % ["PASS" if value else "FAIL", description])

func _ready() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var rendered := get_viewport().get_texture().get_image()
	check(rendered.get_size() == Vector2i(576, 324), "native render size " + filename)
	rendered.save_png("res://docs/characters/" + filename + ".png")
	rendered.resize(1152, 648, Image.INTERPOLATE_NEAREST)
	rendered.save_png("res://docs/characters/" + filename + "-2x.png")

func _check_visual_contract(actor: Actor, id: String) -> void:
	var controller = actor.nightreign_visual
	var visual: NightreignCharacterVisual = controller.definition
	check(visual.has_t1_contract(), "48x64 T1 visual contract " + id)
	check(visual.frame_size == Vector2i(48, 64), "48x64 frame size " + id)
	check(visual.pivot == Vector2i(24, 60), "24,60 pivot " + id)
	check(not visual.shared_direction, "eight explicit directions " + id)
	check(visual.directions.size() == 8, "eight direction entries " + id)
	check(visual.atlas.get_width() == 192 and visual.atlas.get_height() == 2560, "192x2560 atlas " + id)
	check(actor.character.region_rect.size == Vector2(48, 64), "48x64 rendered sprite " + id)
	check(actor.character.offset == Vector2(-16, -44), "feet anchor 8,16 " + id)
	for required: String in ["idle", "move", "melee_attack", "hit", "death"]:
		check(visual.animations.has(required), "animation exists %s %s" % [id, required])
	var expected_rows := {"idle": 0, "move": 8, "melee_attack": 16, "hit": 24, "death": 32}
	for key: String in expected_rows:
		check(int(visual.animations[key].row) == int(expected_rows[key]), "animation row %s %s" % [id, key])
	var attack: Dictionary = visual.animations["melee_attack"]
	var expected_phases: Array = ["windup", "swing", "release", "recover"] if id == "wylder" else ["windup", "strum", "release", "recover"]
	check(attack.get("phases", []) == expected_phases, "semantic attack phases " + id)
	controller.play("melee_attack")
	check(controller.current_phase() == "windup", "attack begins in windup " + id)
	controller.elapsed = 1.01 / float(attack.fps)
	controller._render()
	check(controller.current_phase() == expected_phases[1], "attack enters active phase " + id)
	controller.play("idle")
	for direction_index in range(visual.directions.size()):
		controller.face(visual.directions[direction_index])
		controller.play("idle")
		var expected_y := float(direction_index * visual.frame_size.y)
		check(actor.character.region_rect.position.y == expected_y, "direction row %d %s" % [direction_index, id])

func run() -> void:
	DisplayProfiles.apply_profile(DisplayProfiles.Profile.DESKTOP_STANDARD)
	var menu_scene := load("res://scenes/menu/main_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().create_timer(0.3).timeout
	check(menu.has_node(MENU_BUTTON_ROOT + "PlayButton"), "Wylder choice is visible")
	check(menu.has_node(MENU_BUTTON_ROOT + "RevenantButton"), "Revenant choice is visible")
	await capture("selection")
	menu.queue_free()
	await get_tree().process_frame
	for id: String in ["wylder", "revenant"]:
		menu = menu_scene.instantiate()
		get_tree().root.add_child(menu)
		get_tree().current_scene = menu
		var button_name := "PlayButton" if id == "wylder" else "RevenantButton"
		menu.get_node(MENU_BUTTON_ROOT + button_name).pressed.emit()
		check(CharacterCatalog.selected_id == id, "menu selects " + id)
		seed(15092026)
		await get_tree().create_timer(0.65).timeout
		var game := get_tree().current_scene
		check(game.name == "Game", "menu starts real game " + id)
		var actor: Actor = get_tree().get_first_node_in_group("player")
		check(actor != null and actor.nightreign_visual.definition.display_name == CharacterCatalog.get_display_name(), "correct character resource " + id)
		check(actor.character.texture.resource_path.contains("/" + id + "/t1-atlas.png"), "correct T1 atlas " + id)
		_check_visual_contract(actor, id)
		check(game.get_node("UI/HUD").status_text.text.contains(CharacterCatalog.get_display_name()), "HUD identity " + id)
		var start := World.current_map.find_monster_position(World.player)
		check(World.current_map.get_monster(start) == World.player, "one cell occupancy " + id)
		var turn := World.current_turn
		await game._handle_player_action(PlayerRestAction.new())
		check(World.current_turn == turn + 1, "real turn resolves " + id)
		await get_tree().create_timer(0.2).timeout
		await capture(id + "-gameplay")
		Modals.show_inventory(InventoryModal.Tab.EQUIPMENT)
		await get_tree().create_timer(0.25).timeout
		check(Modals.has_visible_modals(), "equipment opens " + id)
		Modals.hide_inventory()
		await get_tree().create_timer(0.2).timeout
		game.queue_free()
		await get_tree().process_frame
	var report := {"checks": checks, "failures": failures, "capture": "Godot viewport framebuffer", "characters": ["wylder", "revenant"], "frame_size": [48, 64], "pivot": [24, 60]}
	FileAccess.open("res://docs/characters/qa.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("CHARACTER QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
