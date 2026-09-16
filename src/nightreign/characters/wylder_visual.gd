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
	animation = next
	elapsed = 0.0
	_render()

func _process(delta: float) -> void:
	elapsed += delta
	var data: Dictionary = definition.animations[animation]
	if not data.loop and elapsed >= float(data.frames) / float(data.fps) and animation != "death":
		animation = "idle"
		elapsed = 0.0
	_render()

func _render() -> void:
	var data: Dictionary = definition.animations[animation]
	var frame := int(elapsed * float(data.fps))
	frame = frame % int(data.frames) if data.loop else mini(frame, int(data.frames) - 1)
	var row := int(data.row) + (0 if definition.shared_direction else definition.directions.find(facing))
	sprite.region_rect = Rect2(Vector2(frame, row) * Vector2(definition.frame_size), Vector2(definition.frame_size))
	sprite.visible = true
