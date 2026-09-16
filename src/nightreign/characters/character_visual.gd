class_name NightreignCharacterVisual
extends Resource
## Pure visual data. Grid footprint and combat statistics belong to the existing model.
@export var display_name: String = "Wylder"
@export var atlas: Texture2D
@export var frame_size := Vector2i(32, 32)
@export var pivot := Vector2i(16, 24)
@export var shared_direction: bool = false
@export var directions: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1)]
@export var animations: Dictionary = {}
