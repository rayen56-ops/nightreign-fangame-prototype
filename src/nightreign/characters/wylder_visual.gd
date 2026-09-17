extends Node
## Presentation only: never submits actions or changes map occupancy.
var definition: NightreignCharacterVisual
var facing := Vector2i.DOWN
var animation: String = "idle"
var elapsed: float = 0.0
var sprite: Sprite2D

func _ready() -> void:
	definition = CharacterCatalog.get_visual()
	sprite = get_parent().get_node("%Character")
	sprite.texture = definition.atlas
	sprite.hframes = 1
	sprite.vframes = 1
	sprite.frame = 0
	sprite.flip_h = false
	sprite.region_enabled = true
	sprite.offset = Vector2(Vector2i(8, 16) - definition.pivot)
	_render()

func face(direction: Vector2i) -> void:
	if direction != Vector2i.ZERO:
		facing = direction.sign()

func play(next: String) -> void:
	if animation == "death":
		return
	if not definition.animations.has(next):
		push_warning("Unknown character animation: %s" % next)
		return
	animation = next
	elapsed = 0.0
	_render()

func current_phase() -> String:
	var data: Dictionary = definition.animations.get(animation, {})
	var phases: Array = data.get("phases", [])
	if phases.is_empty():
		return animation
	var index := _current_frame_index(data)
	return str(phases[mini(index, phases.size() - 1)])

func _process(delta: float) -> void:
	if definition == null or not definition.animations.has(animation):
		return
	elapsed += delta
	var data: Dictionary = definition.animations[animation]
	if not bool(data.get("loop", false)) and elapsed >= _animation_duration(data) and animation != "death":
		animation = "idle"
		elapsed = 0.0
	_render()

func _animation_duration(data: Dictionary) -> float:
	var fps := maxf(float(data.get("fps", 1.0)), 0.001)
	return float(data.get("frames", 1)) / fps

func _current_frame_index(data: Dictionary) -> int:
	var frame_count := maxi(int(data.get("frames", 1)), 1)
	var frame := int(elapsed * float(data.get("fps", 1.0)))
	return frame % frame_count if bool(data.get("loop", false)) else mini(frame, frame_count - 1)

func _render() -> void:
	if definition == null or sprite == null or not definition.animations.has(animation):
		return
	var data: Dictionary = definition.animations[animation]
	var frame := _current_frame_index(data)
	var direction_index := 0
	if not definition.shared_direction:
		direction_index = definition.directions.find(facing)
		if direction_index < 0:
			direction_index = 0
	var row := int(data.get("row", 0)) + direction_index
	sprite.region_rect = Rect2(Vector2(frame, row) * Vector2(definition.frame_size), Vector2(definition.frame_size))
	sprite.visible = true
