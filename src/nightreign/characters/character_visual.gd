class_name NightreignCharacterVisual
extends Resource
## Pure visual data. Grid footprint and combat statistics belong to the existing model.
## Animation dictionaries support both legacy row-block atlases and T1 column-offset sheets.
@export var display_name: String = "Wylder"
@export var atlas: Texture2D
@export var frame_size := Vector2i(32, 32)
@export var pivot := Vector2i(16, 24)
@export var shared_direction: bool = false
@export var directions: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1)]
@export var animations: Dictionary = {}

func animation_data(name: String) -> Dictionary:
	if animations.has(name):
		return animations[name]
	return animations.get("idle", {"row": 0, "column": 0, "frames": 1, "fps": 1.0, "loop": true})

func direction_row(direction: Vector2i) -> int:
	if shared_direction:
		return 0
	var index := directions.find(direction.sign())
	return maxi(0, index)
