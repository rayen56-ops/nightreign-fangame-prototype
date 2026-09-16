extends Node
var checks: int = 0
var failures: Array[String] = []

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
	# Exact integer-scale copy of the engine framebuffer, with no mockup or compositing.
	rendered.resize(1152, 648, Image.INTERPOLATE_NEAREST)
	rendered.save_png("res://docs/characters/" + filename + "-2x.png")

func run() -> void:
	DisplayProfiles.apply_profile(DisplayProfiles.Profile.DESKTOP_STANDARD)
	var menu_scene := load("res://scenes/menu/main_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().create_timer(0.3).timeout
	check(menu.choices.size() == 2, "two visible character choices")
	await capture("selection")
	menu.queue_free()
	await get_tree().process_frame
	for id: String in ["wylder", "revenant"]:
		menu = menu_scene.instantiate()
		get_tree().root.add_child(menu)
		get_tree().current_scene = menu
		menu.choices[id].pressed.emit()
		check(CharacterCatalog.selected_id == id, "selection button sets " + id)
		seed(15092026)
		menu.get_node("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PlayButton").pressed.emit()
		await get_tree().create_timer(0.65).timeout
		var game := get_tree().current_scene
		check(game.name == "Game", "menu starts real game " + id)
		var actor: Actor = get_tree().get_first_node_in_group("player")
		check(actor != null and actor.nightreign_visual.definition.display_name == CharacterCatalog.get_display_name(), "correct character resource " + id)
		check(actor.character.texture.resource_path.contains("/" + id + "/"), "correct texture " + id)
		check(actor.character.region_rect.size == Vector2(32, 32), "32x32 sprite " + id)
		check(actor.character.offset == Vector2(-8, -8), "feet anchor " + id)
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
	var report := {"checks": checks, "failures": failures, "capture": "Godot viewport framebuffer", "characters": ["wylder", "revenant"]}
	FileAccess.open("res://docs/characters/qa.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("CHARACTER QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
