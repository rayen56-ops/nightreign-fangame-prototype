class_name NightreignCharacterVisual
extends Resource
## Pure visual data. Grid footprint and combat statistics belong to the existing model.
@export var display_name: String = "Wylder"
@export var atlas: Texture2D
@export var frame_size := Vector2i(48, 64)
@export var pivot := Vector2i(24, 60)
@export var shared_direction: bool = false
@export var directions: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1)]
@export var animations: Dictionary = {}

func has_t1_contract() -> bool:
	return frame_size == Vector2i(48, 64) and pivot == Vector2i(24, 60) and directions.size() == 8 and not shared_direction
