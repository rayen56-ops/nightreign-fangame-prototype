class_name NightGladiusVisual
extends Node2D

const STATE_HUNT := &"hunt"
const STATE_TELEGRAPH := &"telegraph"
const STATE_SPLIT := &"split"
const STATE_STAGGERED := &"staggered"
const STATE_RECOVERY := &"recovery"
const STATE_ECHO := &"echo"

var enemy_id := "gladius"
var animation := "idle"
var elapsed := 0.0
var look_left := false
var character_sprite: Sprite2D


func setup(p_enemy_id: String) -> void:
	enemy_id = p_enemy_id


func _ready() -> void:
	character_sprite = get_parent().get_node("%Character") as Sprite2D
	if character_sprite != null:
		character_sprite.visible = false
	queue_redraw()


func _monster() -> Monster:
	var actor := get_parent() as Actor
	return actor.monster if actor != null else null


func current_state() -> StringName:
	var monster := _monster()
	if enemy_id == "gladius_echo":
		return STATE_ECHO
	if monster == null:
		return STATE_HUNT
	if int(monster.get_meta("stagger", 0)) > 0:
		return STATE_STAGGERED
	if int(monster.get_meta("recovery", 0)) > 0:
		return STATE_RECOVERY
	if NightRun.telegraphs.has(monster.get_instance_id()):
		return STATE_TELEGRAPH
	if bool(monster.get_meta("split_done", false)):
		return STATE_SPLIT
	return STATE_HUNT


func head_count() -> int:
	return 1 if enemy_id == "gladius_echo" else 3


func chain_spread() -> bool:
	return current_state() == STATE_SPLIT


func flame_intensity() -> float:
	match current_state():
		STATE_TELEGRAPH:
			return 1.0
		STATE_SPLIT:
			return 0.82
		STATE_STAGGERED, STATE_RECOVERY:
			return 0.28
		STATE_ECHO:
			return 0.42
		_:
			return 0.62


func presentation_contract() -> Dictionary:
	return {
		"state": String(current_state()),
		"head_count": head_count(),
		"chain_spread": chain_spread(),
		"flame_intensity": flame_intensity(),
		"visual_bounds": Vector2i(32, 24) if enemy_id == "gladius" else Vector2i(20, 15),
		"grid_occupancy": Vector2i.ONE,
	}


func face(direction: Vector2i) -> void:
	if direction.x < 0:
		look_left = true
	elif direction.x > 0:
		look_left = false
	_update_transform()


func play(next: String) -> void:
	if animation == "death":
		return
	if next not in ["idle", "move", "melee_attack", "hit", "death"]:
		return
	animation = next
	elapsed = 0.0
	_update_transform()


func _process(delta: float) -> void:
	elapsed += delta
	if animation == "move" and elapsed >= 0.20:
		animation = "idle"
		elapsed = 0.0
	elif animation == "melee_attack" and elapsed >= 0.28:
		animation = "idle"
		elapsed = 0.0
	elif animation == "hit" and elapsed >= 0.22:
		animation = "idle"
		elapsed = 0.0
	_update_transform()
	queue_redraw()


func _update_transform() -> void:
	var bob := 0.0
	if animation == "idle" and elapsed >= 0.5:
		bob = -1.0
	elif animation == "move":
		bob = -1.0 if int(elapsed * 16.0) % 2 == 0 else 0.0
	elif animation == "melee_attack":
		bob = -2.0
	elif animation == "hit":
		bob = 1.0

	scale.x = -1.0 if look_left else 1.0
	position = Vector2(16.0 if look_left else 0.0, bob)
	modulate = Color(1.0, 0.52, 0.45, 1.0) if animation == "hit" else Color.WHITE


func _line(a: Vector2, b: Vector2, color: Color, width := 1.0) -> void:
	draw_line(a, b, color, width)


func _rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(Vector2(x, y), Vector2(w, h)), color)


func _draw_chain(a: Vector2, b: Vector2, spread := false) -> void:
	var metal := Color(0.43, 0.45, 0.48, 0.90)
	var delta := b - a
	var length := maxf(delta.length(), 0.001)
	var step := delta.normalized() * 2.4
	var cursor := a
	var index := 0
	while cursor.distance_to(a) <= length:
		var radius := 1.1 if index % 2 == 0 else 0.8
		draw_arc(cursor, radius, 0.0, TAU, 8, metal.lightened(0.08 if spread else 0.0), 1.0)
		cursor += step
		index += 1


func _draw_flame(origin: Vector2, intensity: float, phase: float) -> void:
	var outer := Color(0.93, 0.19, 0.08, 0.42 + intensity * 0.36)
	var inner := Color(1.0, 0.61, 0.16, 0.58 + intensity * 0.36)
	var height := 2.0 + intensity * 5.0
	var sway := sin(phase * 5.0 + origin.x) * intensity
	var outer_points := PackedVector2Array([
		origin + Vector2(-2.0, 0.0),
		origin + Vector2(sway - 1.0, -height * 0.55),
		origin + Vector2(sway, -height),
		origin + Vector2(sway + 1.4, -height * 0.45),
		origin + Vector2(2.0, 0.0),
	])
	draw_colored_polygon(outer_points, outer)
	var inner_points := PackedVector2Array([
		origin + Vector2(-1.0, 0.0),
		origin + Vector2(sway * 0.5, -height * 0.62),
		origin + Vector2(1.0, 0.0),
	])
	draw_colored_polygon(inner_points, inner)


func _draw_head(center: Vector2, scale_factor: float, intensity: float) -> void:
	var fur := Color(0.12, 0.13, 0.16, 1.0)
	var ember := Color(0.78, 0.16, 0.08, 1.0)
	var size := Vector2(6, 5) * scale_factor
	draw_rect(Rect2(center - size * 0.5, size), fur)
	_line(center + Vector2(size.x * 0.22, 0), center + Vector2(size.x * 0.52, 1), fur.lightened(0.06), 1.0)
	_rect(center.x + size.x * 0.12, center.y - 1, 1, 1, ember)
	_draw_flame(center + Vector2(-1, -size.y * 0.45), intensity, elapsed)


func _draw_gladius() -> void:
	var state := current_state()
	var intensity := flame_intensity()
	var fur := Color(0.105, 0.11, 0.14, 1.0)
	var ember := Color(0.70, 0.12, 0.07, 0.86)
	var shadow := Color(0.02, 0.025, 0.04, 0.70)
	var lift := -2.0 if state == STATE_TELEGRAPH else (1.0 if state in [STATE_STAGGERED, STATE_RECOVERY] else 0.0)

	# Boss art intentionally overhangs its one-tile footprint. Occupancy remains 1x1.
	draw_ellipse_shadow(Vector2(8, 14), Vector2(14, 3), shadow)
	_rect(-2, 7, 20, 7, fur)
	_rect(1, 12, 4, 5, fur.darkened(0.08))
	_rect(11, 12, 4, 5, fur.darkened(0.08))
	_line(Vector2(-1, 9), Vector2(-7, 5), fur.lightened(0.04), 2.0)

	var spread := 3.0 if state == STATE_SPLIT else 0.0
	var centers := [
		Vector2(5 - spread, 5 + lift),
		Vector2(10, 3 + lift),
		Vector2(15 + spread, 5 + lift),
	]
	for center in centers:
		_draw_head(center, 1.0, intensity)

	# A central ember seam makes the body read as fire-bound rather than a normal wolf.
	_line(Vector2(3, 8), Vector2(15, 8), Color(ember, 0.38 + intensity * 0.42), 1.0)

	if state == STATE_SPLIT:
		_draw_chain(Vector2(5, 8), Vector2(-7, 12), true)
		_draw_chain(Vector2(13, 8), Vector2(25, 12), true)
	else:
		_draw_chain(Vector2(5, 8), Vector2(0, 13))
		_draw_chain(Vector2(13, 8), Vector2(18, 13))

	if state == STATE_TELEGRAPH:
		draw_arc(Vector2(8, 8), 13.0, PI * 1.10, PI * 1.90, 18, Color(1.0, 0.27, 0.10, 0.58), 1.0)


func draw_ellipse_shadow(center: Vector2, radii: Vector2, color: Color) -> void:
	# CanvasItem has no ellipse primitive; horizontal strokes form a crisp pixel ellipse.
	for y in range(-int(radii.y), int(radii.y) + 1):
		var normalized := float(y) / maxf(radii.y, 1.0)
		var half_width := radii.x * sqrt(maxf(0.0, 1.0 - normalized * normalized))
		_line(center + Vector2(-half_width, y), center + Vector2(half_width, y), color, 1.0)


func _draw_echo() -> void:
	var fur := Color(0.10, 0.11, 0.14, 0.88)
	var intensity := flame_intensity()
	draw_ellipse_shadow(Vector2(8, 13), Vector2(7, 2), Color(0.02, 0.025, 0.04, 0.58))
	_rect(3, 7, 10, 5, fur)
	_rect(10, 5, 5, 5, fur.lightened(0.04))
	_rect(5, 11, 2, 4, fur)
	_rect(11, 11, 2, 4, fur)
	_draw_head(Vector2(13, 6), 0.76, intensity)
	_draw_chain(Vector2(5, 9), Vector2(0, 12))


func _draw() -> void:
	if enemy_id == "gladius_echo":
		_draw_echo()
	else:
		_draw_gladius()
