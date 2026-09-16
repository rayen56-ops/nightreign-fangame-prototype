class_name WorldPlan
extends RefCounted

enum WorldType { NORMAL, ARENA }
enum LevelType { DUNGEON, ESCAPE, END, ARENA }

const TOTAL_FLOORS := 20
const FINAL_FLOOR := 20


class LevelPlan:
	var id: String
	var type: LevelType
	var depth: int
	var up_destination: String
	var down_destination: String
	var has_amulet: bool = false

	func _init(
		p_id: String,
		p_type: LevelType,
		p_depth: int,
		p_up: String = "",
		p_down: String = "",
		p_has_amulet: bool = false
	) -> void:
		id = p_id
		type = p_type
		depth = p_depth
		up_destination = p_up
		down_destination = p_down
		has_amulet = p_has_amulet

	func _to_string() -> String:
		var type_str: String = LevelType.keys()[type]
		return (
			"LevelPlan<%s>: type=%s depth=%d up=%s down=%s amulet=%s"
			% [
				id,
				type_str,
				depth,
				up_destination if up_destination else "none",
				down_destination if down_destination else "none",
				has_amulet
			]
		)


var levels: Array[LevelPlan]


func _init(world_type: WorldType = WorldType.NORMAL) -> void:
	levels = []

	match world_type:
		WorldType.NORMAL:
			# T0 contract: one continuous 20-floor expedition. Floors 1-19 are
			# procedural dungeons; floor 20 is the Nightlord arena. Content themes
			# are layered later, but the transition graph is production-ready now.
			for depth in range(1, TOTAL_FLOORS + 1):
				var level_id := "level_%d" % depth
				var up_destination := World.ESCAPE_LEVEL if depth == 1 else "level_%d" % (depth - 1)
				var down_destination := "" if depth == FINAL_FLOOR else "level_%d" % (depth + 1)
				var level_type := LevelType.ARENA if depth == FINAL_FLOOR else LevelType.DUNGEON
				levels.append(
					LevelPlan.new(
						level_id,
						level_type,
						depth,
						up_destination,
						down_destination,
						depth == FINAL_FLOOR
					)
				)

		WorldType.ARENA:
			levels.append(LevelPlan.new("arena", LevelType.ARENA, 1, "", "", false))


func _to_string() -> String:
	var output := "WorldPlan[\n"
	for level in levels:
		output += level._to_string() + "\n"
	output += "]"
	return output


func get_first_level_plan() -> LevelPlan:
	return levels[0]


func get_level_plan(level_id: String) -> LevelPlan:
	for level in levels:
		if level.id == level_id:
			return level
	return null
