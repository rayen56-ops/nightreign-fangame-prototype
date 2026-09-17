extends Node2D
## Gameplay markers use actual visible map state; red cells are attack snapshots.
var boss_bar: Label
var combat_bar: Label

func _ready() -> void:
	z_index = -1
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

func _process(_delta: float) -> void:
	queue_redraw()
	var map := World.current_map
	if map == null:
		return
	combat_bar.text = combat_status_text()
	var character: Dictionary = NightRun.character_data()
	combat_bar.tooltip_text = "Skill: %s\nUltimate: %s" % [String(character.skill), String(character.ultimate)]
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
