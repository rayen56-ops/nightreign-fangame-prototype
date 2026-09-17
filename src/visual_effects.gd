class_name VisualEffects
extends RefCounted

const PROJECTILE_SPEED := 400.0
const WEAPON_CUE_DURATION := 0.14


static func weapon_visual_profile(item: Item) -> StringName:
	if item == null or not item.has_meta("night_archetype"):
		return &""
	var archetype_id := String(item.get_meta("night_archetype", ""))
	var archetypes: Dictionary = NightRun.weapon_profiles.get("archetypes", {})
	if not archetypes.has(archetype_id):
		return &""
	var profile: Dictionary = archetypes[archetype_id]
	return StringName(String(profile.get("visual_profile", "")))


static func _line(root: Node2D, points: PackedVector2Array, width: float, color: Color) -> Line2D:
	var line := Line2D.new()
	line.points = points
	line.width = width
	line.default_color = color
	line.antialiased = false
	root.add_child(line)
	return line


static func _arc_points(
	forward: Vector2, from_angle: float, to_angle: float, radius: float, count: int = 9
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(count):
		var amount := float(index) / float(maxi(1, count - 1))
		points.append(forward.rotated(lerpf(from_angle, to_angle, amount)) * radius)
	return points


static func animate_weapon_attack(
	parent: Node, origin: Vector2, direction: Vector2, item: Item
) -> void:
	var profile := weapon_visual_profile(item)
	if profile == &"" or profile in [&"glintstone", &"incantation"]:
		return

	var forward := direction.normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.DOWN
	var side := Vector2(-forward.y, forward.x)
	var cue := Node2D.new()
	cue.position = origin
	parent.add_child(cue)

	match profile:
		&"greatsword_sweep":
			_line(
				cue,
				_arc_points(forward, -1.22, 1.22, Constants.TILE_SIZE * 1.35, 11),
				4.0,
				Color(0.95, 0.90, 0.78, 0.95)
			)
		&"rapier_thrust":
			_line(
				cue,
				PackedVector2Array([forward * 3.0, forward * Constants.TILE_SIZE * 2.15]),
				2.0,
				Color(0.90, 0.95, 1.0, 0.95)
			)
		&"dagger_double":
			_line(
				cue,
				PackedVector2Array([side * -4.0, forward * Constants.TILE_SIZE * 0.95 + side * 3.0]),
				2.0,
				Color(1.0, 0.92, 0.82, 0.95)
			)
			_line(
				cue,
				PackedVector2Array([side * 4.0, forward * Constants.TILE_SIZE * 0.95 + side * -3.0]),
				2.0,
				Color(1.0, 0.92, 0.82, 0.78)
			)
		&"katana_slash":
			_line(
				cue,
				PackedVector2Array([
					forward * -2.0 - side * Constants.TILE_SIZE * 0.72,
					forward * Constants.TILE_SIZE * 1.15 + side * Constants.TILE_SIZE * 0.62
				]),
				2.5,
				Color(0.86, 0.94, 1.0, 0.95)
			)
		_:
			_line(
				cue,
				_arc_points(forward, -0.72, 0.72, Constants.TILE_SIZE * 1.05, 7),
				2.5,
				Color(0.92, 0.92, 0.92, 0.9)
			)

	var tween := parent.create_tween().set_parallel(true)
	tween.tween_property(cue, "modulate:a", 0.0, WEAPON_CUE_DURATION)
	tween.tween_property(cue, "scale", Vector2(1.08, 1.08), WEAPON_CUE_DURATION)
	tween.finished.connect(cue.queue_free)


static func _magic_projectile(profile: StringName) -> Node2D:
	var root := Node2D.new()
	var core := Polygon2D.new()
	root.add_child(core)

	if profile == &"glintstone":
		core.polygon = PackedVector2Array([
			Vector2(8, 0), Vector2(1, -4), Vector2(-5, 0), Vector2(1, 4)
		])
		core.color = Color(0.42, 0.78, 1.0, 1.0)
		_line(
			root,
			PackedVector2Array([Vector2(-12, 0), Vector2(-3, 0)]),
			2.0,
			Color(0.28, 0.62, 1.0, 0.72)
		)
	else:
		core.polygon = PackedVector2Array([
			Vector2(6, 0), Vector2(2, -5), Vector2(-3, -3), Vector2(-5, 0),
			Vector2(-3, 3), Vector2(2, 5)
		])
		core.color = Color(1.0, 0.80, 0.30, 1.0)
		_line(
			root,
			PackedVector2Array([Vector2(-9, 0), Vector2(7, 0)]),
			1.5,
			Color(1.0, 0.91, 0.55, 0.82)
		)
		_line(
			root,
			PackedVector2Array([Vector2(0, -7), Vector2(0, 7)]),
			1.5,
			Color(1.0, 0.91, 0.55, 0.82)
		)
	return root


static func animate_projectile(
	parent: Node,
	start_pos: Vector2i,
	end_pos: Vector2i,
	item: Item = null,
	is_thrown_item: bool = false
) -> void:
	var projectile: Node2D
	var visual_profile := weapon_visual_profile(item)
	if is_thrown_item and item:
		var thrown_sprite := Sprite2D.new()
		thrown_sprite.texture = ItemTiles.get_texture(item.sprite_name)
		projectile = thrown_sprite
	elif visual_profile in [&"glintstone", &"incantation"]:
		projectile = _magic_projectile(visual_profile)
	else:
		var arrow_sprite := Sprite2D.new()
		arrow_sprite.texture = preload("res://assets/textures/fx/arrow.png")
		projectile = arrow_sprite

	var start := Vector2(start_pos) * Constants.TILE_SIZE_VEC2 + Constants.HALF_TILE_SIZE_VEC2
	var end := Vector2(end_pos) * Constants.TILE_SIZE_VEC2 + Constants.HALF_TILE_SIZE_VEC2
	projectile.position = start
	parent.add_child(projectile)

	var distance := start.distance_to(end)
	var duration := distance / PROJECTILE_SPEED * (2.0 if is_thrown_item else 1.0)
	projectile.rotation = (end - start).angle()

	var tween := parent.create_tween().set_parallel(true)
	tween.tween_property(projectile, "position", end, duration).set_ease(Tween.EASE_IN_OUT)

	if visual_profile in [&"glintstone", &"incantation"]:
		tween.tween_property(projectile, "scale", Vector2(1.22, 1.22), duration).set_ease(Tween.EASE_OUT)

	if is_thrown_item:
		(
			tween
			. tween_property(projectile, "rotation", PI * 8 * distance / PROJECTILE_SPEED, duration)
			. set_ease(Tween.EASE_IN_OUT)
		)
		tween.tween_property(projectile, "scale", Vector2(1.2, 1.2), duration / 2.0).set_ease(
			Tween.EASE_IN_OUT
		)
		(
			tween
			. chain()
			. tween_property(projectile, "scale", Vector2(1.0, 1.0), duration / 2.0)
			. set_ease(Tween.EASE_IN_OUT)
		)

	await tween.finished
	projectile.queue_free()


static func create_explosion(
	parent: Node, pos: Vector2i, _big: bool = false, _item: Item = null
) -> void:
	var explosion := AnimatedSprite2D.new()
	explosion.sprite_frames = preload("res://scenes/fx/explosion.tres")
	explosion.position = Vector2(pos) * Constants.TILE_SIZE_VEC2 + Constants.HALF_TILE_SIZE_VEC2
	parent.add_child(explosion)
	explosion.play()
	await explosion.animation_finished
	explosion.queue_free()
