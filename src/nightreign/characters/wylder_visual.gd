extends Node
## Presentation only: never submits actions or changes map occupancy.
## Shared controller for every Nightfarer visual resource.
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
	# Actors live on a 16 px grid. Pivot is authored at the character's foot contact.
	sprite.offset = Vector2(Vector2i(8, 16) - definition.pivot)
	_render()

func face(direction: Vector2i) -> void:
	if direction != Vector2i.ZERO:
		facing = direction.sign()
		_render()

func play(next: String) -> void:
	if animation == "death":
		return
	animation = next if definition.animations.has(next) else "idle"
	elapsed = 0.0
	_render()

func _process(delta: float) -> void:
	elapsed += delta
	var data := definition.animation_data(animation)
	var frames := maxi(1, int(data.get("frames", 1)))
	var fps := maxf(0.01, float(data.get("fps", 1.0)))
	if not bool(data.get("loop", false)) and elapsed >= float(frames) / fps and animation != "death":
		animation = "idle"
		elapsed = 0.0
	_render()

func _render() -> void:
	if definition == null or sprite == null or definition.atlas == null:
		return
	var data := definition.animation_data(animation)
	var frames := maxi(1, int(data.get("frames", 1)))
	var fps := maxf(0.01, float(data.get("fps", 1.0)))
	var frame := int(elapsed * fps)
	frame = frame % frames if bool(data.get("loop", false)) else mini(frame, frames - 1)
	var row := int(data.get("row", 0)) + definition.direction_row(facing)
	var column := int(data.get("column", 0)) + frame
	var origin := Vector2(column * definition.frame_size.x, row * definition.frame_size.y)
	sprite.region_rect = Rect2(origin, Vector2(definition.frame_size))
	sprite.visible = true
