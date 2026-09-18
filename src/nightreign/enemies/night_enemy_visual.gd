class_name NightEnemyVisual
extends Node2D

var enemy_id: String = ""
var elite := false
var animation := "idle"
var elapsed := 0.0
var look_left := false
var character_sprite: Sprite2D


func setup(p_enemy_id: String, p_elite: bool) -> void:
	enemy_id = p_enemy_id
	elite = p_elite


func _ready() -> void:
	character_sprite = get_parent().get_node("%Character") as Sprite2D
	if character_sprite != null:
		character_sprite.visible = false
	set_process(true)
	queue_redraw()


func face(direction: Vector2i) -> void:
	if direction.x < 0:
		look_left = true
	elif direction.x > 0:
		look_left = false
	_update_pose_transform()


func play(next: String) -> void:
	if animation == "death":
		return
	if next not in ["idle", "move", "melee_attack", "hit", "death"]:
		return
	animation = next
	elapsed = 0.0
	_update_pose_transform()


func current_signature() -> String:
	return NightEnemyVisualProfile.signature(enemy_id)


func _process(delta: float) -> void:
	elapsed += delta
	match animation:
		"move":
			if elapsed >= 0.18:
				animation = "idle"
				elapsed = 0.0
		"melee_attack":
			if elapsed >= 0.25:
				animation = "idle"
				elapsed = 0.0
		"hit":
			if elapsed >= 0.20:
				animation = "idle"
				elapsed = 0.0
		"death":
			pass
		_:
			if elapsed >= 1.0:
				elapsed = 0.0
	_update_pose_transform()


func _update_pose_transform() -> void:
	var bob := 0.0
	if animation == "idle" and elapsed >= 0.5:
		bob = -1.0
	elif animation == "move":
		bob = -1.0 if int(elapsed * 18.0) % 2 == 0 else 0.0
	elif animation == "melee_attack":
		bob = -1.0
	elif animation == "hit":
		bob = 1.0

	scale.x = -1.0 if look_left else 1.0
	position = Vector2(16.0 if look_left else 0.0, bob)
	if animation == "hit":
		modulate = Color(1.0, 0.48, 0.42, 1.0)
	else:
		modulate = Color.WHITE


func _rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(Vector2(x, y), Vector2(w, h)), color)


func _line(a: Vector2, b: Vector2, color: Color, width := 1.0) -> void:
	draw_line(a, b, color, width)


func _draw_elite_marks() -> void:
	if not elite:
		return
	var gold := NightEnemyVisualProfile.elite_accent()
	_line(Vector2(1, 1), Vector2(5, 1), gold)
	_line(Vector2(1, 1), Vector2(1, 5), gold)
	_line(Vector2(15, 1), Vector2(11, 1), gold)
	_line(Vector2(15, 1), Vector2(15, 5), gold)


func _draw_soldier(profile: Dictionary) -> void:
	var body: Color = profile.body
	var accent: Color = profile.accent
	var metal: Color = profile.metal
	var shadow := Color(0.04, 0.05, 0.07, 0.65)

	# Upright shield-and-sword read: broad shield left, helmet high, blade right.
	_rect(5, 13, 7, 2, shadow)
	_rect(6, 10, 2, 4, body.darkened(0.18))
	_rect(9, 10, 2, 4, body.darkened(0.18))
	_rect(6, 5, 5, 7, body)
	_rect(6, 2, 5, 4, metal.darkened(0.18))
	_rect(7, 1, 4, 2, metal)
	_line(Vector2(7, 4), Vector2(10, 4), Color(0.06, 0.07, 0.09, 0.92))
	_rect(2, 5, 4, 7, accent)
	_rect(3, 6, 2, 5, accent.lightened(0.12))
	_line(Vector2(4, 6), Vector2(4, 11), metal.darkened(0.12))
	_line(Vector2(12, 4), Vector2(14, 12), metal, 1.0)
	_line(Vector2(11, 7), Vector2(14, 6), metal.darkened(0.10), 1.0)


func _draw_wolf(profile: Dictionary) -> void:
	var body: Color = profile.body
	var accent: Color = profile.accent
	var shadow := Color(0.03, 0.04, 0.055, 0.68)

	# Low horizontal body, long tail and four grounded legs make it readable at a glance.
	_rect(2, 13, 12, 2, shadow)
	_rect(4, 7, 8, 5, body)
	_rect(11, 6, 4, 5, body.lightened(0.06))
	_line(Vector2(4, 8), Vector2(1, 5), body.lightened(0.04), 2.0)
	_line(Vector2(1, 5), Vector2(0, 4), body.lightened(0.04), 1.0)
	_rect(5, 11, 2, 4, body.darkened(0.12))
	_rect(10, 11, 2, 4, body.darkened(0.12))
	_rect(12, 4, 1, 3, body)
	_rect(14, 5, 1, 3, body)
	_rect(13, 7, 1, 1, accent)
	_line(Vector2(12, 10), Vector2(15, 10), Color(0.10, 0.08, 0.08, 0.88), 1.0)


func _draw_skeleton(profile: Dictionary) -> void:
	var bone: Color = profile.body
	var cloth: Color = profile.accent
	var metal: Color = profile.metal
	var dark := Color(0.05, 0.055, 0.06, 0.90)

	# Thin bone columns plus a full-height spear create a very different negative space.
	_rect(7, 1, 4, 4, bone)
	_rect(8, 2, 1, 1, dark)
	_rect(10, 2, 1, 1, dark)
	_line(Vector2(9, 5), Vector2(9, 11), bone, 1.0)
	_line(Vector2(6, 6), Vector2(12, 6), bone, 1.0)
	_line(Vector2(6, 8), Vector2(12, 8), bone.darkened(0.08), 1.0)
	_line(Vector2(7, 6), Vector2(6, 10), bone, 1.0)
	_line(Vector2(11, 6), Vector2(13, 8), bone, 1.0)
	_rect(7, 10, 5, 2, cloth)
	_line(Vector2(8, 12), Vector2(7, 15), bone, 1.0)
	_line(Vector2(10, 12), Vector2(11, 15), bone, 1.0)
	_line(Vector2(13, 2), Vector2(13, 15), metal, 1.0)
	var spear_tip := PackedVector2Array([Vector2(13, 0), Vector2(11.5, 3), Vector2(14.5, 3)])
	draw_colored_polygon(spear_tip, metal.lightened(0.10))


func _draw() -> void:
	if not NightEnemyVisualProfile.supports(enemy_id):
		return
	var profile := NightEnemyVisualProfile.get_profile(enemy_id)
	match enemy_id:
		"soldier":
			_draw_soldier(profile)
		"wolf":
			_draw_wolf(profile)
		"skeleton":
			_draw_skeleton(profile)
	_draw_elite_marks()
