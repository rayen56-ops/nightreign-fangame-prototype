extends Node

const ESCAPE_LEVEL = "_exit"

# World is a main global singleton that holds the game state and handles
# mutations. Eventually it should be serializable and loadable from a save file.

signal world_initialized
signal map_changed(map: Map)
signal effect_occurred(effect: ActionEffect)
signal message_logged(message: String, level: int)
signal turn_started
signal turn_ended
signal game_ended
signal energy_updated(monster: Monster)

# Like NetHack, we world_plan the dungeon in advance, but levels are only created when
# they are first visited.
var world_plan: WorldPlan

# Always keep a reference to the player
var player: Monster

# Keep track of generated maps
var maps: Dictionary  # Map[id] -> Map
var current_map: Map

# Turn management
var current_turn: int

# Is the game over?
var game_over: bool = false

# Keep track of the max depth reached
var max_depth: int = 1

# Stable expedition seed. A concrete seed guarantees the same floor topology
# regardless of previous combat/item RNG consumption.
var generation_seed: int = 1

# The player's faction affinity
var faction_affinities: Dictionary = {
	Factions.Type.HUMAN: 100,  # There could be different human factions with different affinities
	Factions.Type.CRITTERS: -30,  # Somewhat hostile. Maybe add taming?
	Factions.Type.MONSTERS: -100,  # Initially hostile but can improve
	Factions.Type.UNDEAD: -100,  # Initially hostile but can improve
}


func _init() -> void:
	Log.i("===========================")
	Log.i("= Godot Roguelike Example =")
	Log.i("===========================")
	Log.i("")


func _ready() -> void:
	initialize()


func initialize(seed_override: int = -1) -> void:
	Log.i("Initializing world...")

	# Initialize all vars. Normal runs receive a fresh seed; tests/daily runs can
	# provide one explicitly and reproduce the complete floor chain.
	if seed_override >= 0:
		generation_seed = seed_override
	else:
		randomize()
		generation_seed = randi()
	current_turn = 1
	game_over = false
	max_depth = 1

	# Create a new world world_plan
	world_plan = WorldPlan.new(WorldPlan.WorldType.NORMAL)
	Log.i("World world_plan created: %s" % world_plan)

	# Create the player with starting equipment
	# TODO: Choose role based at main menu
	player = MonsterFactory.create_monster(&"knight", Roles.Type.KNIGHT)
	Roles.equip_monster(player, Roles.Type.KNIGHT)
	Log.i("Player created: %s" % player)

	# Create the first level
	maps.clear()
	var plan := world_plan.get_first_level_plan()
	var map := _generate_map(plan)
	maps[map.id] = map
	current_map = map

	# Add the player to the main entrance. Never put side effects inside assert():
	# release exports may compile assertions out entirely.
	var player_placed := map.add_monster_at_stairs(player, Obstacle.Type.STAIRS_UP)
	assert(player_placed, "Failed to add player to main entrance")
	if not player_placed:
		push_error("Failed to add player to main entrance")
		return

	NightRun.reset_run()

	# Compute FOV before the first turn
	update_vision()

	# Signal that the world is ready
	map_changed.emit(current_map)
	world_initialized.emit()


func _find_stairs(map: Map, type: Obstacle.Type) -> Vector2i:
	for x in map.width:
		for y in map.height:
			var p := Vector2i(x, y)
			if map.get_stairs_type(p) == type:
				return p
	return Utils.INVALID_POS


func _has_immediate_player_egress(map: Map, spawn: Vector2i) -> bool:
	if spawn == Utils.INVALID_POS:
		return false
	for direction: Vector2i in Utils.ALL_DIRECTIONS:
		var target := spawn + direction
		if not map.is_in_bounds(target):
			continue
		var cell := map.get_cell(target)
		if cell.is_walkable() and map.get_monster(target) == null:
			return true
	return false


func _has_walkable_route(map: Map, start: Vector2i, goal: Vector2i) -> bool:
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
			var next_cell := map.get_cell(next)
			var contract_walkable := next_cell.is_walkable()
			if (
				not contract_walkable
				and next_cell.terrain
				and next_cell.terrain.is_walkable()
				and next_cell.obstacle
				and next_cell.obstacle.type == Obstacle.Type.DOOR_CLOSED
			):
				contract_walkable = true
			if not contract_walkable:
				continue
			seen[next] = true
			queue.append(next)
	return false


func _floor_generation_seed(depth: int, attempt: int = 0) -> int:
	# Keep floor generation on a dedicated deterministic stream. This avoids
	# topology changing when unrelated systems consume global random numbers.
	var mixed := generation_seed ^ (depth * 1000003) ^ (attempt * 97409)
	mixed = absi(mixed)
	return mixed + 1


func _generated_map_meets_t0_contract(map: Map, plan: WorldPlan.LevelPlan) -> bool:
	if map == null or map.depth != plan.depth:
		return false
	var up := _find_stairs(map, Obstacle.Type.STAIRS_UP)
	var down := _find_stairs(map, Obstacle.Type.STAIRS_DOWN)
	if plan.up_destination != "" and up == Utils.INVALID_POS:
		return false
	if plan.down_destination != "" and down == Utils.INVALID_POS:
		return false
	if plan.down_destination == "" and down != Utils.INVALID_POS:
		return false
	if up != Utils.INVALID_POS and not _has_immediate_player_egress(map, up):
		return false
	if up != Utils.INVALID_POS and down != Utils.INVALID_POS and not _has_walkable_route(map, up, down):
		return false
	return true


func _generate_map(plan: WorldPlan.LevelPlan) -> Map:
	match plan.type:
		WorldPlan.LevelType.ARENA:
			seed(_floor_generation_seed(plan.depth))
			if plan.depth == WorldPlan.FINAL_FLOOR:
				var final_map := NightRun.make_arena(plan.depth, plan.up_destination)
				assert(_generated_map_meets_t0_contract(final_map, plan), "Final arena violates T0 map contract")
				return final_map
			var arena_generator := MapGeneratorFactory.create_generator(
				MapGeneratorFactory.GeneratorType.ARENA
			)
			return arena_generator.generate_map(20, 15, {"depth": plan.depth})

		WorldPlan.LevelType.DUNGEON:
			# Procedural generation is a contract, not a hope. If a random layout ever
			# misses stairs or disconnects the route, regenerate immediately. This is
			# deterministic for a fixed run seed because retries consume the same RNG stream.
			for attempt in range(8):
				# Re-seed per floor+attempt so generation is independent of all other
				# random activity that happened earlier in the run.
				var floor_seed := _floor_generation_seed(plan.depth, attempt)
				seed(floor_seed)
				Dice.set_seed(floor_seed + 17)
				var generator := MapGeneratorFactory.create_generator(
					MapGeneratorFactory.GeneratorType.DUNGEON
				)
				var target_rooms := mini(36, 26 + int(plan.depth / 3))
				var candidate: Map = generator.generate_map(
					30,
					20,
					{
						"min_room_size": 5,
						"max_room_size": 9,
						"size_variation": 0.6,
						"room_placement_attempts": 500,
						"target_room_count": target_rooms,
						"border_buffer": 3,
						"room_expansion_chance": 0.5,
						"max_expansion_attempts": 3,
						"horizontal_expansion_bias": 0.5,
						"depth": plan.depth,
						"has_up_stairs": plan.up_destination != "",
						"has_down_stairs": plan.down_destination != "",
						"has_amulet": plan.has_amulet
					}
				)
				if _generated_map_meets_t0_contract(candidate, plan):
					return candidate
				Log.w("Rejected invalid procedural floor %d (attempt %d/8)" % [plan.depth, attempt + 1])
			assert(false, "Failed to generate a valid floor %d after 8 attempts" % plan.depth)
			return null

		_:
			Log.e("Unsupported level type: %s" % plan.type)
			assert(false)
			return null


# Apply an action (presumably from the player) to the world and complete the turn.
func apply_player_action(action: BaseAction) -> ActionResult:
	if game_over or player.is_dead:
		return null
	Log.i("[color=lime]======== TURN %d STARTED ========[/color]" % World.current_turn)
	turn_started.emit()

	# Apply the player's action
	Log.i("Applying action: %s" % action)
	var result := action.apply(current_map)
	if not result:
		Log.i("[color=gray]==== TURN CANCELLED (Action Failed) ====[/color]")
		return null

	# If the action failed, return early without advancing the turn
	if not result.success:
		if result.message:
			message_logged.emit(result.message, result.message_level)
		Log.i("[color=gray]==== TURN CANCELLED (Result False) ====[/color]")
		return result

	# Update all monster systems
	for monster in current_map.get_monsters():
		# Update status effects
		monster.tick_status_effects()

		# Check encumbrance
		monster.tick_encumbrance()

	# Process player nutrition
	var nutrition_cost := 1 + result.extra_nutrition_consumed
	var nutrition_result := player.nutrition.decrease(nutrition_cost)
	if nutrition_result.message:
		message_logged.emit(nutrition_result.message, LogMessages.Level.BAD)
	if nutrition_result.died:
		player.is_dead = true
		effect_occurred.emit(
			DeathEffect.new(player, current_map.find_monster_position(player), true)
		)
		game_over = true
		game_ended.emit()
		return result

	# Recovery is limited to consumables and Sites of Grace.

	# Accumulate energy for all monsters
	for monster in current_map.get_monsters():
		monster.energy = Monster.SPEED_NORMAL

	# Build a list of results from the action
	var results: Array[ActionResult] = [result]

	# Give turns to monsters that have enough energy
	var monsters := current_map.get_monsters()
	Log.d("Checking %d monsters for turns" % monsters.size())
	for monster in monsters:
		if monster == player:
			continue

		# Only act if we have enough energy
		if monster.energy >= Monster.SPEED_NORMAL:
			var monster_action: ActorAction = NightEnemyAction.new(monster)
			if monster_action:
				var monster_result := monster_action.apply(current_map)
				results.append(monster_result)
			# Consume energy after acting
			monster.energy -= Monster.SPEED_NORMAL
			energy_updated.emit(monster)

	NightRun.end_turn()

	# Update area effects
	update_area_effects()

	# Update vision
	update_vision()

	# Now emit all the results
	for res in results:
		# Emit effects
		for effect in res.effects:
			effect_occurred.emit(effect)

		# Emit messages
		if res.message:
			message_logged.emit(res.message, res.message_level)

	# Emit turn ended signal
	Log.i("[color=lime]-------- TURN %d ENDED --------[/color]" % World.current_turn)
	turn_ended.emit()

	# Mark the turn as over
	current_turn += 1

	# Is the player dead?
	if player.is_dead:
		game_over = true
		game_ended.emit()

	return result


func handle_special_level(id: String) -> void:
	match id:
		ESCAPE_LEVEL:
			# Request confirmation before letting the player leave
			var confirmed: Variant = await Modals.confirm(
				"Confirm Escape",
				"Are you sure you want to leave the dungeon? This will end your adventure."
			)
			if confirmed:
				current_map.find_and_remove_monster(player)
				message_logged.emit("[color=cyan]You have escaped the dungeon.[/color]", LogMessages.Level.NORMAL)
				game_ended.emit()


func handle_level_transition(destination_level: String, coming_from_stairs: Obstacle.Type) -> void:
	NightRun.telegraphs.clear()
	# Get the level plan for the destination
	var plan := world_plan.get_level_plan(destination_level)
	if not plan:
		Log.e("No level plan found for %s" % destination_level)
		return

	# Generate or load the next level
	if not maps.has(destination_level):
		var map := _generate_map(plan)
		map.id = destination_level
		maps[destination_level] = map

	# Remove player from current map
	for monster in current_map.get_monsters().duplicate():
		if monster.has_meta("family"): current_map.find_and_remove_monster(monster)
	current_map.find_and_remove_monster(player)

	# Switch to the new map
	current_map = maps[destination_level]
	max_depth = maxi(max_depth, current_map.depth)

	# Add player at appropriate entrance based on which stairs they used
	var target_stairs_type := (
		Obstacle.Type.STAIRS_DOWN
		if coming_from_stairs == Obstacle.Type.STAIRS_UP
		else Obstacle.Type.STAIRS_UP
	)
	# A returning entrance may be occupied; move its inhabitant to a nearby free tile.
	for x in current_map.width:
		for y in current_map.height:
			var p := Vector2i(x,y)
			if current_map.get_stairs_type(p) != target_stairs_type: continue
			var occupant := current_map.get_monster(p)
			if occupant == null: continue
			var moved := false
			for radius in range(1, maxi(current_map.width, current_map.height)):
				for dx in range(-radius, radius + 1):
					for dy in range(-radius, radius + 1):
						var free := p + Vector2i(dx,dy)
						if current_map.is_in_bounds(free) and current_map.get_cell(free).is_walkable() and current_map.get_monster(free) == null:
							current_map.get_cell(free).monster = occupant
							current_map.get_cell(p).monster = null
							moved = true
							break
					if moved: break
				if moved: break
	assert(
		current_map.add_monster_at_stairs(player, target_stairs_type),
		"Failed to add player at stairs"
	)

	NightRun.prepare_map(current_map)

	# Update FOV for new position
	var player_pos := current_map.find_monster_position(player)
	current_map.compute_fov(player_pos)

	# Signal that the map has changed
	map_changed.emit(current_map)


## Updates all area effects and applies their damage
func update_area_effects() -> void:
	var messages: Array[String] = []

	for x in range(current_map.width):
		for y in range(current_map.height):
			var cell := current_map.get_cell(Vector2i(x, y))
			var pos := Vector2i(x, y)

			# Check for armed grenades and handle their countdown
			for item in cell.items:
				if item.type == Item.Type.GRENADE and item.is_armed:
					item.turns_to_activate -= 1
					if item.turns_to_activate <= 0:
						# Remove the grenade from the map
						current_map.remove_item(pos, item)
						# Apply the grenade's area effect
						if item.aoe_config:
							current_map.apply_aoe(
								pos,
								item.aoe_config.radius,
								item.aoe_config.type,
								item.damage,
								item.aoe_config.turns
							)
							messages.append("%s explodes!" % item.get_name(Item.NameFormat.THE))
							# Create visual explosion effect
							await VisualEffects.create_explosion(
								get_tree().current_scene, pos, true
							)
						else:
							Log.e("Armed grenade has no AOE config: %s" % item)

	# Apply damage from each effect *after* the grenades have exploded
	for x in range(current_map.width):
		for y in range(current_map.height):
			var cell := current_map.get_cell(Vector2i(x, y))
			var pos := Vector2i(x, y)

			# Apply damage from each effect
			for effect in cell.area_effects:
				if cell.monster:
					var monster: Monster = cell.monster
					var result := Combat.resolve_aoe_damage(monster, effect.damage, effect.type)
					if result.killed:
						monster.is_dead = true
						if monster != player:
							messages.append(
								"%s is killed!" % monster.get_name(Monster.NameFormat.THE)
							)
							effect_occurred.emit(DeathEffect.new(monster, pos, monster == player))
							monster.drop_everything()
			# Update effect durations
			cell.update_effects()

	# Log all messages at once
	for msg in messages:
		message_logged.emit(msg, LogMessages.Level.NORMAL)


func update_vision() -> void:
	var player_pos := current_map.find_monster_position(player)
	if player.has_status_effect(StatusEffect.Type.BLIND):
		current_map.clear_fov(player_pos)
	else:
		current_map.compute_fov(player_pos)

