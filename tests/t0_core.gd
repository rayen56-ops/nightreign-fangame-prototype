extends Node

var checks := 0
var failures: Array[String] = []
var fingerprints: Dictionary = {}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("T0 %s: %s" % ["PASS" if value else "FAIL", label])

func _ready() -> void:
	call_deferred("run")

func stairs_position(map: Map, type: Obstacle.Type) -> Vector2i:
	for x in map.width:
		for y in map.height:
			var p := Vector2i(x, y)
			if map.get_stairs_type(p) == type:
				return p
	return Utils.INVALID_POS

func path_exists(map: Map, start: Vector2i, goal: Vector2i) -> bool:
	if start == Utils.INVALID_POS or goal == Utils.INVALID_POS:
		return false
	var queue: Array[Vector2i] = [start]
	var seen: Dictionary = {start: true}
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if p == goal:
			return true
		for offset: Vector2i in Utils.ALL_DIRECTIONS:
			var next := p + offset
			if not map.is_in_bounds(next) or seen.has(next):
				continue
			if not map.get_cell(next).is_walkable():
				continue
			seen[next] = true
			queue.append(next)
	return false

func fingerprint(map: Map) -> String:
	var text := "%d:%dx%d|" % [map.depth, map.width, map.height]
	for x in map.width:
		for y in map.height:
			var p := Vector2i(x, y)
			var cell := map.get_cell(p)
			text += str(cell.terrain.type) + ":" + str(map.get_stairs_type(p)) + ";"
	return text.sha256_text()

func night_enemy_count(map: Map) -> int:
	var count := 0
	for monster in map.get_monsters():
		if monster.has_meta("night_enemy"):
			count += 1
	return count

func capture_chain(generation_seed: int, verify_structure: bool) -> Dictionary:
	CharacterCatalog.select_character("wylder")
	World.initialize(generation_seed)
	var result: Dictionary = {}
	for depth in range(1, WorldPlan.TOTAL_FLOORS + 1):
		var map := World.current_map
		if depth in [1, 10, 19]:
			result[depth] = fingerprint(map)
		if verify_structure:
			check(map.depth == depth, "floor %02d has correct depth" % depth)
			var up := stairs_position(map, Obstacle.Type.STAIRS_UP)
			check(up != Utils.INVALID_POS, "floor %02d has entrance stairs" % depth)
			if depth < WorldPlan.FINAL_FLOOR:
				var down := stairs_position(map, Obstacle.Type.STAIRS_DOWN)
				check(down != Utils.INVALID_POS, "floor %02d has descent stairs" % depth)
				check(path_exists(map, up, down), "floor %02d entrance connects to descent" % depth)
				check(night_enemy_count(map) == NightRun.floor_enemy_count(depth), "floor %02d spawns expected enemy budget" % depth)
			else:
				check(stairs_position(map, Obstacle.Type.STAIRS_DOWN) == Utils.INVALID_POS, "floor 20 has no further descent")
				var bosses := 0
				for monster in map.get_monsters():
					if monster.get_meta("night_enemy", "") == "gladius":
						bosses += 1
				check(bosses == 1, "floor 20 contains exactly one Nightlord prototype")
				check(NightRun.turns_until_next_tide(map) == -1, "Night's Tide is disabled in final arena")
		if depth < WorldPlan.FINAL_FLOOR:
			World.handle_level_transition("level_%d" % (depth + 1), Obstacle.Type.STAIRS_DOWN)
	return result

func run() -> void:
	check(WorldPlan.TOTAL_FLOORS == 20 and WorldPlan.FINAL_FLOOR == 20, "world contract is twenty floors")
	var plan := WorldPlan.new(WorldPlan.WorldType.NORMAL)
	check(plan.levels.size() == 20, "world plan creates exactly twenty levels")
	for depth in range(1, 21):
		var level: WorldPlan.LevelPlan = plan.levels[depth - 1]
		check(level.id == "level_%d" % depth and level.depth == depth, "plan floor %02d identity" % depth)
		check(level.up_destination == (World.ESCAPE_LEVEL if depth == 1 else "level_%d" % (depth - 1)), "plan floor %02d up link" % depth)
		check(level.down_destination == ("" if depth == 20 else "level_%d" % (depth + 1)), "plan floor %02d down link" % depth)
	check(plan.levels[19].type == WorldPlan.LevelType.ARENA, "floor 20 is the Nightlord arena")
	check(plan.levels[18].type == WorldPlan.LevelType.DUNGEON, "floor 19 remains procedural")

	var previous_count := -1
	var previous_hp := 0.0
	var previous_damage := 0.0
	var previous_elite := -1.0
	var previous_tide_0 := 9999
	var previous_tide_1 := 9999
	var probe := NightRun.make_arena(1, "")
	for depth in range(1, 20):
		probe.depth = depth
		var count := NightRun.floor_enemy_count(depth)
		var hp := NightRun.floor_hp_multiplier(depth)
		var damage := NightRun.floor_damage_multiplier(depth)
		var elite := NightRun.floor_elite_chance(depth)
		var tide_0 := NightRun.night_threshold(probe, 0)
		var tide_1 := NightRun.night_threshold(probe, 1)
		check(count >= previous_count, "enemy budget never decreases at floor %02d" % depth)
		check(hp >= previous_hp and damage >= previous_damage, "enemy stats never decrease at floor %02d" % depth)
		check(elite >= previous_elite, "elite pressure never decreases at floor %02d" % depth)
		check(tide_0 <= previous_tide_0 and tide_1 <= previous_tide_1 and tide_0 < tide_1, "tide pressure is ordered at floor %02d" % depth)
		previous_count = count
		previous_hp = hp
		previous_damage = damage
		previous_elite = elite
		previous_tide_0 = tide_0
		previous_tide_1 = tide_1

	var first := capture_chain(16092026, true)
	var repeated := capture_chain(16092026, false)
	var alternate := capture_chain(16092027, false)
	for depth in [1, 10, 19]:
		check(first[depth] == repeated[depth], "same seed reproduces floor %02d topology" % depth)
	var changed := false
	for depth in [1, 10, 19]:
		changed = changed or first[depth] != alternate[depth]
	check(changed, "different seed changes at least one sampled floor")

	# Turn economy smoke check on an isolated arena: one legal player action advances
	# exactly one turn; one rejected action advances nothing.
	CharacterCatalog.select_character("wylder")
	World.initialize(16092026)
	var arena := NightRun.make_arena(1, "")
	arena.id = "t0_turn_arena"
	World.current_map = arena
	arena.get_cell(Vector2i(9, 9)).monster = World.player
	NightRun.prepared.erase(arena.id)
	NightRun.prepare_map(arena)
	for monster in arena.get_monsters().duplicate():
		if monster != World.player:
			arena.find_and_remove_monster(monster)
	var enemy := NightRun.spawn_enemy("wolf", arena, Vector2i(9, 5), 1)
	var before := World.current_turn
	World.apply_player_action(PlayerRestAction.new())
	check(World.current_turn == before + 1 and arena.find_monster_position(enemy) != Vector2i(9, 5), "one legal action advances one global turn and one enemy action")
	NightRun.cooldown = 3
	before = World.current_turn
	var enemy_pos := arena.find_monster_position(enemy)
	var failed := World.apply_player_action(NightAbilityAction.new("skill", Vector2i.UP))
	check(failed != null and not failed.success and World.current_turn == before and arena.find_monster_position(enemy) == enemy_pos, "rejected action consumes zero turns")

	var report := {
		"stage": "T0",
		"checks": checks,
		"failures": failures,
		"engine": Engine.get_version_info().string,
		"floors": WorldPlan.TOTAL_FLOORS,
		"sampled_seed_fingerprints": first
	}
	FileAccess.open("res://docs/T0_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("T0 QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
