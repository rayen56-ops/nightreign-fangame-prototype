extends Node2D
## Gameplay markers use actual visible map state; red cells are attack snapshots.
var boss_bar: Label
var combat_bar: Label
var attack_preview: Dictionary = {}
var attack_preview_target: Vector2i = Utils.INVALID_POS
var controller_driver: NightControllerDriver

func _ready() -> void:
	z_index = -1
	controller_driver = preload("res://src/nightreign/input/night_controller_driver.gd").new()
	add_child(controller_driver)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var backing := ColorRect.new()
	backing.position = Vector2(177,276)
	backing.size = Vector2(399,38)
	backing.color = Color(0.04,0.03,0.07,0.93)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(backing)
	boss_bar = Label.new()
	boss_bar.position = Vector2(180, 279)
	boss_bar.add_theme_font_size_override("font_size", 10)
	boss_bar.add_theme_color_override("font_color", Color("e8bd77"))
	layer.add_child(boss_bar)
	combat_bar = Label.new()
	combat_bar.position = Vector2(180, 294)
	combat_bar.add_theme_font_size_override("font_size", 9)
	combat_bar.add_theme_color_override("font_color", Color("c8d7e8"))
	layer.add_child(combat_bar)

func _weapon_status_label() -> String:
	if World.player == null:
		return "Unarmed"
	var item := World.player.equipment.get_equipped_item(Equipment.Slot.MELEE)
	if item == null:
		return "Unarmed"
	if item.has_meta("night_weapon"):
		var profile: Dictionary = NightRun.weapon_archetype(String(item.get_meta("night_weapon")))
		return String(profile.get("label", item.name))
	return item.name

func combat_status_text() -> String:
	if World.player == null:
		return ""
	var skill_state := "READY" if NightRun.cooldown <= 0 else "%dt" % NightRun.cooldown
	var ultimate_state := "READY" if NightRun.charge >= 100 else "%d%%" % NightRun.charge
	return "%s | %s | Skill %s | Ult %s | Flask %d" % [
		CharacterCatalog.get_display_name(),
		_weapon_status_label(),
		skill_state,
		ultimate_state,
		NightRun.flasks,
	]

func _night_weapon_context() -> Dictionary:
	if World.player == null:
		return {}
	var item := World.player.equipment.get_equipped_item(Equipment.Slot.MELEE)
	if item == null or not item.has_meta("night_weapon"):
		return {}
	var profile: Dictionary = NightRun.weapon_archetype(String(item.get_meta("night_weapon")))
	if profile.is_empty():
		return {}
	return {
		"item": item,
		"profile": profile,
		"affinity": StringName(String(item.get_meta("night_affinity", "physical"))),
	}

func _thrust_path_clear(map: Map, preview: Dictionary) -> bool:
	var cells: Array = preview.get("cells", [])
	if cells.size() <= 1:
		return true
	for i in range(cells.size() - 1):
		var pos: Vector2i = cells[i]
		if not map.is_in_bounds(pos):
			return false
		if not map.get_cell(pos).is_walkable() or map.get_obstacle(pos) != null:
			return false
		if map.get_monster(pos) != null:
			return false
	return true

func _clip_cast_cells(map: Map, cells: Array) -> Array[Vector2i]:
	var clipped: Array[Vector2i] = []
	for value in cells:
		var pos: Vector2i = value
		if not map.is_in_bounds(pos):
			break
		clipped.append(pos)
		if map.is_opaque(pos) or map.get_monster(pos) != null:
			break
	return clipped

func _build_attack_preview() -> Dictionary:
	var map := World.current_map
	if map == null or World.player == null or World.game_over or Modals.has_visible_modals():
		return {}
	var game := get_parent()
	if game != null:
		if not bool(game.get("waiting_for_player_input")):
			return {}
		if game.get("_throw_selection") != null:
			return {}
	var context := _night_weapon_context()
	if context.is_empty():
		return {}
	var source := map.find_monster_position(World.player)
	if source == Utils.INVALID_POS:
		return {}
	var profile: Dictionary = context.profile

	# A controller owns the preview after its last deliberate input. Keyboard or mouse
	# button input hands preview ownership back to the original cursor path.
	if controller_driver != null and controller_driver.controller_active:
		return NightControllerPreview.build(
			map,
			World.player,
			profile,
			context.affinity,
			controller_driver.controller_preview_direction()
		)

	var mouse_pos := get_local_mouse_position()
	var tile_pos := Vector2i(mouse_pos / Constants.TILE_SIZE)
	if not map.is_in_bounds(tile_pos) or not map.is_visible(tile_pos):
		return {}
	var terrain := map.get_terrain(tile_pos)
	if terrain.type == Terrain.Type.EMPTY:
		return {}
	if source == tile_pos:
		return {}
	var preview := NightAttackPreview.build(profile, source, tile_pos, context.affinity)
	if profile.has("cast"):
		preview["cells"] = _clip_cast_cells(map, preview.get("cells", []))
		preview["target"] = tile_pos
		preview["input_mode"] = "mouse"
		return preview
	var target := map.get_monster(tile_pos)
	if target == null or target == World.player or not target.is_hostile_to(World.player):
		return {}
	if not bool(preview.get("target_in_range", false)):
		return {}
	if String(preview.get("pattern", "")) == "thrust" and not _thrust_path_clear(map, preview):
		return {}
	preview["target"] = tile_pos
	preview["input_mode"] = "mouse"
	return preview

func _suppress_legacy_path_preview() -> void:
	if attack_preview.is_empty():
		return
	var game := get_parent()
	if game == null:
		return
	var renderer := game.get("map_renderer") as MapRenderer
	if renderer == null or renderer.highlight_layer == null:
		return
	for child in renderer.highlight_layer.get_children():
		child.visible = false
		child.queue_free()

func _process(_delta: float) -> void:
	attack_preview = _build_attack_preview()
	attack_preview_target = attack_preview.get("target", Utils.INVALID_POS)
	_suppress_legacy_path_preview()
	queue_redraw()
	var map := World.current_map
	if map == null:
		return
	combat_bar.text = combat_status_text()
	var character: Dictionary = NightRun.character_data()
	combat_bar.tooltip_text = "Skill: %s\nUltimate: %s\nPad: LS/D-pad Move | X Skill | Y Ult | LB Flask | RB Cast | L3 Wait" % [String(character.skill), String(character.ultimate)]
	if map.depth < NightRun.boss_floor():
		var remaining := NightRun.turns_until_next_tide(map)
		var stage := NightRun.get_night_stage(map)
		var tide_text := "Tide in %d" % remaining if stage < 2 else "DEEP NIGHT"
		boss_bar.text = "Find the descent  |  Turn %d  |  %s" % [NightRun.get_floor_turns(map), tide_text]
	else:
		boss_bar.text = "Find Gladius, Beast of Night"
	for monster in map.get_monsters():
		if monster.get_meta("night_enemy", "") == "gladius":
			var pos := map.find_monster_position(monster)
			if map.visible_cells[pos.x][pos.y]:
				var phase := "SPLIT PHASE" if bool(monster.get_meta("split_done", false)) else "Beast of Night"
				boss_bar.text = "GLADIUS  %d / %d   |   %s" % [monster.hp, monster.max_hp, "LEAVE RED TILES" if NightRun.telegraphs.has(monster.get_instance_id()) else phase]
	if NightRun.won:
		boss_bar.text = "NIGHTLORD FELLED"

func _draw_attack_preview(map: Map) -> void:
	if attack_preview.is_empty():
		return
	var cells: Array = attack_preview.get("cells", [])
	var affinity: StringName = attack_preview.get("affinity", &"physical")
	var fill := NightAttackPreview.preview_color(affinity)
	var outline := Color(fill.r, fill.g, fill.b, 0.92)
	for value in cells:
		var cell: Vector2i = value
		if not map.is_in_bounds(cell) or not map.visible_cells[cell.x][cell.y]:
			continue
		var rect := Rect2(Vector2(cell * Constants.TILE_SIZE), Vector2.ONE * Constants.TILE_SIZE)
		draw_rect(rect.grow(-1), fill)
		draw_rect(rect.grow(-1), outline, false, 1)
		if cell == attack_preview_target and bool(attack_preview.get("target_in_range", false)):
			draw_rect(rect.grow(-4), Color(fill.r, fill.g, fill.b, 0.55))

func _draw() -> void:
	var map := World.current_map
	if map == null:
		return
	# Night's Tide sits above terrain and below actors/telegraphs.
	if map.depth < NightRun.boss_floor() and NightRun.get_night_stage(map) > 0:
		for x in map.width:
			for y in map.height:
				var p := Vector2i(x, y)
				if not map.visible_cells[x][y] or not map.get_cell(p).is_walkable() or not NightRun.is_in_tide(map, p):
					continue
				var rect := Rect2(Vector2(p * Constants.TILE_SIZE), Vector2.ONE * Constants.TILE_SIZE)
				draw_rect(rect, Color(0.07, 0.04, 0.16, 0.66))
				draw_rect(rect.grow(-1), Color(0.22, 0.20, 0.46, 0.45), false, 1)
	for field in NightRun.healing_fields:
		if field.map == map.id and map.visible_cells[field.position.x][field.position.y]:
			draw_arc(Vector2(field.position * 16) + Vector2(8,8), 20, 0, TAU, 24, Color("d6b76b"), 1)
	_draw_attack_preview(map)
	for cells: Array in NightRun.telegraphs.values():
		for cell: Vector2i in cells:
			if map.is_in_bounds(cell) and map.visible_cells[cell.x][cell.y] and map.get_cell(cell).is_walkable():
				var rect := Rect2(Vector2(cell * Constants.TILE_SIZE), Vector2.ONE * Constants.TILE_SIZE)
				draw_rect(rect.grow(-1), Color(0.96, 0.19, 0.12, 0.46))
				draw_rect(rect.grow(-1), Color("f9a163"), false, 1)
	for x in map.width:
		for y in map.height:
			if not map.visible_cells[x][y]:
				continue
			var cell := map.get_cell(Vector2i(x,y))
			var center := Vector2(x * 16 + 8, y * 16 + 9)
			if cell.obstacle and cell.obstacle.type == Obstacle.Type.STAIRS_UP:
				draw_arc(center, 6, 0, TAU, 12, Color("cfb86b"), 1)
			if cell.monster and cell.monster.has_meta("family"):
				draw_arc(center, 7, 0, TAU, 12, Color("87dfd3"), 1)
			if cell.monster and cell.monster.get_meta("night_enemy", "") == "gladius":
				draw_arc(center, 10, 0, TAU, 16, Color("e88e42"), 2)
			elif cell.monster and cell.monster.get_meta("night_enemy", "") == "gladius_echo":
				draw_arc(center, 8, 0, TAU, 14, Color("c66a55"), 1)
