class_name NightControllerInput
extends RefCounted

const STICK_ACTIVATE := 0.55
const STICK_NEUTRAL := 0.30


static func button_command(button_index: int) -> StringName:
	match button_index:
		JOY_BUTTON_DPAD_UP:
			return &"move_n"
		JOY_BUTTON_DPAD_DOWN:
			return &"move_s"
		JOY_BUTTON_DPAD_LEFT:
			return &"move_w"
		JOY_BUTTON_DPAD_RIGHT:
			return &"move_e"
		JOY_BUTTON_A:
			return &"interact"
		JOY_BUTTON_X:
			return &"skill"
		JOY_BUTTON_Y:
			return &"ultimate"
		JOY_BUTTON_LEFT_SHOULDER:
			return &"flask"
		JOY_BUTTON_RIGHT_SHOULDER:
			return &"cast"
		JOY_BUTTON_LEFT_STICK:
			return &"wait"
		JOY_BUTTON_RIGHT_STICK:
			return &"grace"
		JOY_BUTTON_START:
			return &"inventory"
		JOY_BUTTON_BACK:
			return &"equipment"
	return &""


static func command_direction(command: StringName) -> Vector2i:
	match command:
		&"move_n":
			return Vector2i.UP
		&"move_s":
			return Vector2i.DOWN
		&"move_w":
			return Vector2i.LEFT
		&"move_e":
			return Vector2i.RIGHT
	return Vector2i.ZERO


static func axis_direction(axes: Vector2, threshold: float = STICK_ACTIVATE) -> Vector2i:
	if axes.length() < threshold:
		return Vector2i.ZERO
	var octant := posmod(int(round(atan2(axes.y, axes.x) / (PI / 4.0))), 8)
	match octant:
		0:
			return Vector2i.RIGHT
		1:
			return Vector2i.DOWN + Vector2i.RIGHT
		2:
			return Vector2i.DOWN
		3:
			return Vector2i.DOWN + Vector2i.LEFT
		4:
			return Vector2i.LEFT
		5:
			return Vector2i.UP + Vector2i.LEFT
		6:
			return Vector2i.UP
		7:
			return Vector2i.UP + Vector2i.RIGHT
	return Vector2i.ZERO


static func is_neutral(axes: Vector2) -> bool:
	return axes.length() <= STICK_NEUTRAL


static func catalyst_profile(item: Item) -> Dictionary:
	if item == null or not item.has_meta("night_weapon"):
		return {}
	var profile := NightRun.weapon_archetype(String(item.get_meta("night_weapon")))
	return profile if profile.has("cast") else {}


static func facing_cast_target(map: Map, actor: Monster, facing: Vector2i) -> Vector2i:
	if map == null or actor == null:
		return Utils.INVALID_POS
	var weapon := actor.equipment.get_equipped_item(Equipment.Slot.MELEE)
	var profile := catalyst_profile(weapon)
	if profile.is_empty():
		return Utils.INVALID_POS
	var direction := facing.sign()
	if direction == Vector2i.ZERO:
		return Utils.INVALID_POS
	var source := map.find_monster_position(actor)
	if source == Utils.INVALID_POS:
		return Utils.INVALID_POS
	var cast: Dictionary = profile.get("cast", {})
	var cast_range := maxi(1, int(cast.get("range", 1)))
	var last_visible := Utils.INVALID_POS
	for distance in range(1, cast_range + 1):
		var pos := source + direction * distance
		if not map.is_in_bounds(pos) or not map.is_visible(pos):
			break
		last_visible = pos
		if map.is_opaque(pos) or map.get_monster(pos) != null:
			break
	return last_visible
