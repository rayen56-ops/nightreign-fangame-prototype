class_name NightEnvironmentOverlay
extends Node2D

var current_map: Map


func set_map(map: Map) -> void:
	current_map = map
	queue_redraw()


func clear_map() -> void:
	current_map = null
	queue_redraw()


func _cell_origin(pos: Vector2i) -> Vector2:
	return Vector2(pos * Constants.TILE_SIZE)


func _draw_floor(pos: Vector2i) -> void:
	var origin := _cell_origin(pos)
	# A faint cool glaze unifies the inherited dungeon tiles without hiding their texture.
	draw_rect(Rect2(origin, Vector2(16, 16)), Color(0.10, 0.14, 0.20, 0.10))
	# Small deterministic corner wear keeps rooms readable at 1x without visual noise.
	if posmod(pos.x * 3 + pos.y * 5, 7) == 0:
		draw_line(origin + Vector2(3, 12), origin + Vector2(6, 11), Color(0.40, 0.45, 0.51, 0.16), 1.0)


func _draw_wall(pos: Vector2i) -> void:
	var origin := _cell_origin(pos)
	draw_rect(Rect2(origin, Vector2(16, 3)), Color(0.38, 0.44, 0.52, 0.24))
	draw_rect(Rect2(origin + Vector2(0, 13), Vector2(16, 3)), Color(0.02, 0.03, 0.05, 0.34))
	draw_line(origin + Vector2(1, 3), origin + Vector2(1, 12), Color(0.30, 0.35, 0.42, 0.18), 1.0)


func _draw_grate(pos: Vector2i) -> void:
	var origin := _cell_origin(pos)
	var accent := NightEnvironmentVisuals.accent_color(NightEnvironmentVisuals.KIND_GRATE)
	draw_rect(Rect2(origin + Vector2(2, 2), Vector2(12, 12)), Color(accent, 0.16))
	for x in [4, 8, 12]:
		draw_line(origin + Vector2(x, 3), origin + Vector2(x, 13), Color(accent, 0.56), 1.0)
	draw_line(origin + Vector2(3, 7), origin + Vector2(13, 7), Color(accent, 0.38), 1.0)
	draw_line(origin + Vector2(3, 11), origin + Vector2(13, 11), Color(accent, 0.38), 1.0)


func _draw_hole(pos: Vector2i) -> void:
	var origin := _cell_origin(pos)
	var accent := NightEnvironmentVisuals.accent_color(NightEnvironmentVisuals.KIND_HOLE)
	draw_rect(Rect2(origin + Vector2(2, 2), Vector2(12, 12)), Color(accent, 0.88))
	draw_rect(Rect2(origin + Vector2(3, 3), Vector2(10, 10)), Color(0.02, 0.025, 0.04, 0.92))
	draw_line(origin + Vector2(4, 4), origin + Vector2(11, 3), Color(0.34, 0.39, 0.47, 0.42), 1.0)
	draw_line(origin + Vector2(12, 5), origin + Vector2(13, 10), Color(0.34, 0.39, 0.47, 0.32), 1.0)


func _draw_closed_door(pos: Vector2i) -> void:
	var origin := _cell_origin(pos)
	var wood := NightEnvironmentVisuals.accent_color(NightEnvironmentVisuals.KIND_DOOR_CLOSED)
	var iron := Color(0.78, 0.70, 0.56, 0.92)
	draw_rect(Rect2(origin + Vector2(2, 1), Vector2(12, 14)), Color(0.08, 0.07, 0.07, 0.64))
	draw_rect(Rect2(origin + Vector2(3, 2), Vector2(10, 12)), Color(wood, 0.80))
	draw_line(origin + Vector2(5, 3), origin + Vector2(5, 13), Color(0.24, 0.16, 0.10, 0.92), 1.0)
	draw_line(origin + Vector2(10, 3), origin + Vector2(10, 13), Color(0.24, 0.16, 0.10, 0.92), 1.0)
	draw_line(origin + Vector2(3, 6), origin + Vector2(13, 6), iron, 1.0)
	draw_line(origin + Vector2(3, 11), origin + Vector2(13, 11), iron, 1.0)
	draw_circle(origin + Vector2(10.5, 8.5), 1.0, Color(0.95, 0.78, 0.34, 1.0))


func _draw_open_door(pos: Vector2i) -> void:
	var origin := _cell_origin(pos)
	var wood := NightEnvironmentVisuals.accent_color(NightEnvironmentVisuals.KIND_DOOR_OPEN)
	draw_rect(Rect2(origin + Vector2(1, 1), Vector2(3, 14)), Color(wood, 0.78))
	draw_rect(Rect2(origin + Vector2(12, 1), Vector2(3, 14)), Color(wood, 0.78))
	draw_rect(Rect2(origin + Vector2(4, 12), Vector2(8, 2)), Color(0.73, 0.61, 0.42, 0.50))
	draw_line(origin + Vector2(4, 2), origin + Vector2(12, 2), Color(0.78, 0.70, 0.56, 0.76), 1.0)


func _draw_grace(pos: Vector2i) -> void:
	var origin := _cell_origin(pos)
	var gold := NightEnvironmentVisuals.accent_color(NightEnvironmentVisuals.KIND_GRACE)
	var center := origin + Vector2(8, 10)
	# Grace reads as a low golden pool with a thin rising wisp, not as a staircase.
	draw_circle(center, 5.0, Color(gold, 0.14))
	draw_arc(center, 5.0, 0.0, TAU, 20, Color(gold, 0.94), 1.0)
	draw_arc(center, 3.0, 0.0, TAU, 16, Color(gold, 0.54), 1.0)
	draw_line(origin + Vector2(8, 10), origin + Vector2(7, 6), Color(gold, 0.88), 1.0)
	draw_line(origin + Vector2(7, 6), origin + Vector2(9, 3), Color(gold, 0.96), 1.0)
	draw_line(origin + Vector2(9, 3), origin + Vector2(10, 6), Color(gold, 0.58), 1.0)


func _draw_descent(pos: Vector2i) -> void:
	var origin := _cell_origin(pos)
	var accent := NightEnvironmentVisuals.accent_color(NightEnvironmentVisuals.KIND_DESCENT)
	# Three bright step edges and a down chevron stay readable even in grayscale.
	draw_line(origin + Vector2(4, 4), origin + Vector2(12, 4), Color(accent, 0.62), 1.0)
	draw_line(origin + Vector2(5, 7), origin + Vector2(12, 7), Color(accent, 0.78), 1.0)
	draw_line(origin + Vector2(6, 10), origin + Vector2(12, 10), Color(accent, 0.96), 1.0)
	draw_line(origin + Vector2(5, 11), origin + Vector2(8, 14), Color(accent, 0.96), 1.0)
	draw_line(origin + Vector2(11, 11), origin + Vector2(8, 14), Color(accent, 0.96), 1.0)


func _draw() -> void:
	if current_map == null:
		return
	for x in range(current_map.width):
		for y in range(current_map.height):
			var pos := Vector2i(x, y)
			if not current_map.was_seen(pos):
				continue
			var cell := current_map.get_cell(pos)
			var kind := NightEnvironmentVisuals.semantic_kind(cell.terrain, cell.obstacle)
			match kind:
				NightEnvironmentVisuals.KIND_FLOOR:
					_draw_floor(pos)
				NightEnvironmentVisuals.KIND_WALL:
					_draw_wall(pos)
				NightEnvironmentVisuals.KIND_GRATE:
					_draw_floor(pos)
					_draw_grate(pos)
				NightEnvironmentVisuals.KIND_HOLE:
					_draw_hole(pos)
				NightEnvironmentVisuals.KIND_DOOR_OPEN:
					_draw_open_door(pos)
				NightEnvironmentVisuals.KIND_DOOR_CLOSED:
					_draw_closed_door(pos)
				NightEnvironmentVisuals.KIND_GRACE:
					_draw_floor(pos)
					_draw_grace(pos)
				NightEnvironmentVisuals.KIND_DESCENT:
					_draw_floor(pos)
					_draw_descent(pos)
