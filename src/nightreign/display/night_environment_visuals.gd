class_name NightEnvironmentVisuals
extends RefCounted

const FLOOR_TILE := &"floor-7-nsew"

const KIND_NONE := &"none"
const KIND_FLOOR := &"floor"
const KIND_WALL := &"wall"
const KIND_GRATE := &"grate"
const KIND_HOLE := &"hole"
const KIND_DOOR_OPEN := &"door_open"
const KIND_DOOR_CLOSED := &"door_closed"
const KIND_GRACE := &"grace"
const KIND_DESCENT := &"descent"


static func ground_tile_for(terrain_type: int) -> StringName:
	match terrain_type:
		Terrain.Type.DUNGEON_FLOOR, 		Terrain.Type.DUNGEON_FLOOR_GRATE, 		Terrain.Type.DUNGEON_HOLE, 		Terrain.Type.DUNGEON_DOOR_OPEN, 		Terrain.Type.DUNGEON_DOOR_CLOSED:
			return FLOOR_TILE
	return &""


static func semantic_kind(terrain: Terrain, obstacle: Obstacle = null) -> StringName:
	if obstacle != null:
		match obstacle.type:
			Obstacle.Type.STAIRS_UP:
				return KIND_GRACE
			Obstacle.Type.STAIRS_DOWN:
				return KIND_DESCENT
			Obstacle.Type.DOOR_OPEN:
				return KIND_DOOR_OPEN
			Obstacle.Type.DOOR_CLOSED:
				return KIND_DOOR_CLOSED

	if terrain == null:
		return KIND_NONE
	match terrain.type:
		Terrain.Type.DUNGEON_FLOOR:
			return KIND_FLOOR
		Terrain.Type.DUNGEON_WALL, Terrain.Type.DUNGEON_WALL_VENTED:
			return KIND_WALL
		Terrain.Type.DUNGEON_FLOOR_GRATE:
			return KIND_GRATE
		Terrain.Type.DUNGEON_HOLE:
			return KIND_HOLE
		Terrain.Type.DUNGEON_DOOR_OPEN:
			return KIND_DOOR_OPEN
		Terrain.Type.DUNGEON_DOOR_CLOSED:
			return KIND_DOOR_CLOSED
	return KIND_NONE


static func interaction_label(kind: StringName) -> String:
	match kind:
		KIND_GRACE:
			return "賜福"
		KIND_DESCENT:
			return "下一層"
		KIND_DOOR_OPEN:
			return "開啟的門"
		KIND_DOOR_CLOSED:
			return "關閉的門"
		KIND_GRATE:
			return "格柵地板"
		KIND_HOLE:
			return "坑洞"
	return ""


static func accent_color(kind: StringName) -> Color:
	match kind:
		KIND_GRACE:
			return Color(0.94, 0.73, 0.30, 1.0)
		KIND_DESCENT:
			return Color(0.62, 0.78, 0.88, 1.0)
		KIND_DOOR_OPEN, KIND_DOOR_CLOSED:
			return Color(0.67, 0.49, 0.30, 1.0)
		KIND_GRATE:
			return Color(0.43, 0.50, 0.57, 1.0)
		KIND_HOLE:
			return Color(0.10, 0.12, 0.17, 1.0)
		KIND_WALL:
			return Color(0.32, 0.38, 0.46, 1.0)
		_:
			return Color(0.20, 0.24, 0.30, 1.0)


static func is_high_priority(kind: StringName) -> bool:
	return kind in [KIND_GRACE, KIND_DESCENT, KIND_DOOR_OPEN, KIND_DOOR_CLOSED]
