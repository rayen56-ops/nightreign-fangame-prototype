extends Node
var checks := 0
var failures: Array[String] = []
var expeditions: Array[Dictionary] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("M1 %s: %s" % ["PASS" if value else "FAIL", label])

func _ready() -> void:
	call_deferred("run")

func sandbox(id: String = "wylder") -> Map:
	CharacterCatalog.select_character(id)
	seed(16092026)
	World.initialize()
	var map := NightRun.make_arena()
	map.id = "qa_arena"
	map.depth = 1
	World.current_map = map
	map.get_cell(Vector2i(9,9)).monster = World.player
	NightRun.telegraphs.clear()
	World.update_vision()
	return map

func pos(monster: Monster) -> Vector2i:
	return World.current_map.find_monster_position(monster)

func relocate(monster: Monster, to: Vector2i) -> void:
	World.current_map.find_and_remove_monster(monster)
	World.current_map.get_cell(to).monster = monster

func run() -> void:
	var fingerprints: Array[String] = []
	for i in 2:
		seed(16092026)
		World.initialize()
		var fingerprint := ""
		for x in World.current_map.width:
			for y in World.current_map.height:
				var c := World.current_map.get_cell(Vector2i(x,y))
				fingerprint += str(c.terrain.type) + (c.monster.name if c.monster else "")
		fingerprints.append(fingerprint.sha256_text())
	check(fingerprints[0] == fingerprints[1], "same seed reproduces terrain and enemy placement")
	var map := sandbox()
	var greatsword := NightRun.make_weapon("greatsword")
	check(NightRun.weapon_damage(greatsword, "wylder") > NightRun.weapon_damage(greatsword, "revenant"), "STR A scaling favors Wylder")
	var seal := NightRun.make_weapon("finger_seal")
	check(NightRun.weapon_damage(seal, "revenant") > NightRun.weapon_damage(seal, "wylder"), "FAI scaling favors Revenant")
	for id: String in ["wylder", "revenant"]:
		CharacterCatalog.select_character(id)
		for weapon_id: String in NightRun.data.weapons:
			var weapon := NightRun.make_weapon(weapon_id)
			World.player.add_item(weapon)
			check(PlayerEquipAction.new(weapon, Equipment.Slot.MELEE).apply(map).success, id + " equips " + weapon_id + " without stat requirement")
			check(ItemFactory.clone(weapon).get_meta("night_weapon", "") == weapon_id, "pickup/split clone preserves " + weapon_id)
	map = sandbox()
	var wolf := NightRun.spawn_enemy("wolf", map, Vector2i(9,5))
	wolf._base_speed = Monster.SPEED_VERY_FAST
	var turn := World.current_turn
	World.apply_player_action(PlayerRestAction.new())
	check(World.current_turn == turn + 1 and pos(wolf) == Vector2i(9,6), "one player wait gives fast enemy exactly one move")
	NightRun.cooldown = 3
	turn = World.current_turn
	check(not World.apply_player_action(NightAbilityAction.new("skill", Vector2i.UP)).success, "cooldown rejects skill")
	check(World.current_turn == turn and NightRun.cooldown == 3 and pos(wolf) == Vector2i(9,6), "failed action costs no turn or enemy move")
	NightRun.cooldown = 0
	World.apply_player_action(NightAbilityAction.new("skill", Vector2i.UP))
	check(pos(wolf) == Vector2i(9,8) and wolf.hp == 9, "Claw Shot pulls and damages")
	check(NightRun.cooldown == 5, "claw cooldown starts at five complete turns")
	for i in 5: World.apply_player_action(PlayerRestAction.new())
	check(NightRun.cooldown == 0, "cooldown expires after five actions")
	map = sandbox()
	var charge := NightRun.charge
	for i in 12: World.apply_player_action(PlayerRestAction.new())
	check(NightRun.charge == charge, "resting cannot farm ultimate charge")
	World.player.hp = 2
	check(NightRun.protect_damage(World.player, 10) == 1 and not NightRun.sixth_sense, "Sixth Sense prevents one lethal hit")
	check(NightRun.protect_damage(World.player, 10) == 10, "Sixth Sense cannot prevent a second hit")
	map = sandbox()
	NightRun.floor_turns[map.id] = int(NightRun.data.night_tide.thresholds[0]) - 1
	World.apply_player_action(PlayerRestAction.new())
	check(NightRun.get_night_stage(map) == 1, "Night's Tide enters encroaching stage on schedule")
	NightRun.floor_turns[map.id] = int(NightRun.data.night_tide.thresholds[1]) - 1
	relocate(World.player, Vector2i(1,1))
	var tide_hp := World.player.hp
	World.apply_player_action(PlayerRestAction.new())
	check(NightRun.get_night_stage(map) == 2 and World.player.hp == tide_hp - int(NightRun.data.night_tide.damage[1]), "Deep Night damages player outside safe region")
	map = sandbox()
	wolf = NightRun.spawn_enemy("wolf", map, Vector2i(9,7))
	var other := NightRun.spawn_enemy("wolf", map, Vector2i(10,7))
	NightRun.charge = 100
	World.apply_player_action(NightAbilityAction.new("ultimate", Vector2i.UP))
	check(wolf.is_dead and other.is_dead and NightRun.charge == 0, "Onslaught Stake damages target and neighbors, spending charge")
	map = sandbox("revenant")
	wolf = NightRun.spawn_enemy("soldier", map, Vector2i(9,6))
	World.apply_player_action(NightAbilityAction.new("skill"))
	var family: Monster
	for ally in map.get_monsters():
		if ally.has_meta("family"): family = ally
	check(family != null and family.name == "Helen", "Revenant summons first named family member")
	check(NightRun.cooldown == 8, "summon cooldown is eight turns")
	NightRun.charge = 100
	World.player.hp = 1
	World.apply_player_action(NightAbilityAction.new("ultimate"))
	check(NightRun.immortal == 3 and NightRun.protect_damage(World.player, 100) == 0, "Immortal March prevents death and leaves three turns")
	map.find_and_remove_monster(wolf)
	for i in 3: World.apply_player_action(PlayerRestAction.new())
	check(NightRun.immortal == 0 and NightRun.protect_damage(World.player, 100) == 100, "immortality expires on schedule")
	map = sandbox()
	World.player.hp = 20
	World.apply_player_action(NightAbilityAction.new("flask"))
	check(World.player.hp == 48 and NightRun.flasks == 2, "Crimson Flask heals and consumes one charge")
	relocate(World.player, Vector2i(9,13))
	World.apply_player_action(NightAbilityAction.new("grace"))
	check(World.player.hp == 72 and NightRun.flasks == 3, "Grace refills health and flasks")
	turn = World.current_turn
	check(not World.apply_player_action(NightAbilityAction.new("grace")).success and World.current_turn == turn, "same Grace cannot be farmed")
	World.player.hp = 20
	NightRun.place_warming_stone(World.player, map, ActionResult.new())
	for i in 3: World.apply_player_action(PlayerRestAction.new())
	check(World.player.hp == 38 and NightRun.healing_fields.is_empty(), "Warming Stone heals six per turn for three turns")
	map = sandbox()
	var boss := NightRun.spawn_enemy("gladius", map, Vector2i(9,5))
	var hp := World.player.hp
	World.apply_player_action(PlayerRestAction.new())
	check(NightRun.telegraphs.has(boss.get_instance_id()) and World.player.hp == hp, "boss telegraph precedes damage")
	var locked: Array = NightRun.telegraphs[boss.get_instance_id()].duplicate()
	World.apply_player_action(PlayerAttackMoveAction.new(Vector2i.RIGHT))
	check(World.player.hp == hp - 16 and not NightRun.telegraphs.has(boss.get_instance_id()), "standing inside marked three-wide sweep deals sixteen damage")
	relocate(World.player, Vector2i(9,9))
	World.apply_player_action(PlayerRestAction.new()) # Boss recovery opening.
	World.apply_player_action(PlayerRestAction.new())
	relocate(World.player, Vector2i(12,9))
	hp = World.player.hp
	World.apply_player_action(PlayerRestAction.new())
	check(World.player.hp == hp and not Vector2i(12,9) in locked, "attack uses locked cells instead of tracking the player")
	var holy := NightRun.make_weapon("sacred_blade")
	World.player.add_item(holy)
	World.player.equipment.equip(holy, Equipment.Slot.MELEE)
	NightRun.resolve_melee(World.player,boss)
	check(boss.get_meta("stagger", 0) == 0, "one holy strike cannot stunlock boss")
	NightRun.resolve_melee(World.player,boss)
	NightRun.resolve_melee(World.player,boss)
	check(boss.get_meta("stagger", 0) == 1, "three holy strikes stagger boss")
	map = sandbox()
	boss = NightRun.spawn_enemy("gladius", map, Vector2i(9,5))
	boss.hp = int(boss.max_hp / 2)
	World.apply_player_action(PlayerRestAction.new())
	var echoes := 0
	for enemy in map.get_monsters():
		if enemy.get_meta("night_enemy", "") == "gladius_echo":
			echoes += 1
	check(bool(boss.get_meta("split_done", false)) and echoes == 2, "Gladius splits into two hunting echoes at half health")
	map = sandbox("revenant")
	World.player.hp = 1
	NightRun.spawn_enemy("wolf", map, Vector2i(9,8))
	World.apply_player_action(PlayerRestAction.new())
	check(World.game_over and World.player.is_dead, "lethal enemy action ends expedition")
	turn = World.current_turn
	check(World.apply_player_action(PlayerRestAction.new()) == null and World.current_turn == turn, "game over rejects further turns")
	CharacterCatalog.select_character("wylder")
	World.initialize()
	var original := World.current_map
	var entrance := pos(World.player)
	World.handle_level_transition("level_2", Obstacle.Type.STAIRS_DOWN)
	var old_count := original.get_monsters().size()
	var down := Utils.INVALID_POS
	for x in original.width:
		for y in original.height:
			if original.get_stairs_type(Vector2i(x,y)) == Obstacle.Type.STAIRS_DOWN: down = Vector2i(x,y)
	var blocker := NightRun.spawn_enemy("wolf", original, down)
	World.handle_level_transition("level_1", Obstacle.Type.STAIRS_UP)
	check(World.current_map == original and pos(World.player) == down and pos(blocker) != down, "returning to occupied stairs safely relocates blocker")
	check(original.get_items(entrance).size() == 1 and original.get_monsters().size() == old_count + 2, "revisited floor preserves loot and enemies without respawn")
	for id: String in ["wylder", "revenant"]:
		await expedition(id)
	var report := {"checks": checks, "failures": failures, "expeditions": expeditions}
	FileAccess.open("res://docs/M1_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("M1 QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)

func path_step(goal: Vector2i) -> Vector2i:
	var map := World.current_map
	var start := pos(World.player)
	var queue: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if p == goal: break
		for offset: Vector2i in Utils.ALL_DIRECTIONS:
			var next := p + offset
			if not map.is_in_bounds(next) or previous.has(next) or not map.get_cell(next).is_walkable(): continue
			var occupant := map.get_monster(next)
			if occupant and occupant.has_meta("family"): continue
			previous[next] = p
			queue.append(next)
	if not previous.has(goal): return Vector2i.ZERO
	var next := goal
	while previous[next] != start and next != start: next = previous[next]
	return next - start

func expedition(id: String) -> void:
	CharacterCatalog.select_character(id)
	seed(16092026)
	World.initialize()
	# Every action below uses the real turn pipeline; no health, damage or position cheats.
	var initial := World.current_map.get_items(pos(World.player)).duplicate()
	for item in initial:
		World.apply_player_action(PlayerPickupAction.new([ItemSelection.new(item, 1)]))
		if item.has_meta("night_weapon"):
			World.apply_player_action(PlayerEquipAction.new(item, Equipment.Slot.MELEE))
	var visited: Array[int] = [1]
	var actions := 0
	while not World.game_over and actions < 700:
		if World.current_map.depth >= 3:
			break
		actions += 1
		var map := World.current_map
		var p := pos(World.player)
		var action: BaseAction
		var danger: Array = []
		for cells: Array in NightRun.telegraphs.values(): danger.append_array(cells)
		if p in danger:
			for offset: Vector2i in Utils.ALL_DIRECTIONS:
				var candidate := p + offset
				if map.is_in_bounds(candidate) and map.get_cell(candidate).is_walkable() and map.get_monster(candidate) == null and not candidate in danger:
					action = PlayerAttackMoveAction.new(offset)
					break
		if action == null and World.player.hp <= World.player.max_hp - 25 and NightRun.flasks > 0:
			action = NightAbilityAction.new("flask")
		if action == null and id == "revenant" and NightRun.cooldown == 0:
			action = NightAbilityAction.new("skill")
		if action == null and id == "revenant" and NightRun.charge == 100:
			action = NightAbilityAction.new("ultimate")
		if action == null:
			for enemy in map.get_monsters():
				if enemy.has_meta("night_enemy") and p.distance_to(pos(enemy)) <= 1.5:
					action = NightAbilityAction.new("ultimate", (pos(enemy)-p).sign()) if id == "wylder" and NightRun.charge == 100 else PlayerAttackMoveAction.new(pos(enemy)-p)
					break
		if action == null and map.get_stairs_type(p) == Obstacle.Type.STAIRS_UP and not NightRun.grace_used.has(map.id) and World.player.hp < World.player.max_hp:
			action = NightAbilityAction.new("grace")
		if action == null and map.get_stairs_type(p) == Obstacle.Type.STAIRS_DOWN:
			action = PlayerMoveDownstairsAction.new()
		if action == null:
			var goal := Utils.INVALID_POS
			if map.depth < 3:
				for x in map.width:
					for y in map.height:
						if map.get_stairs_type(Vector2i(x,y)) == Obstacle.Type.STAIRS_DOWN: goal = Vector2i(x,y)
			else:
				for enemy in map.get_monsters():
					if enemy.get_meta("night_enemy", "") == "gladius": goal = pos(enemy)
			var step := path_step(goal) if goal != Utils.INVALID_POS else Vector2i.ZERO
			action = PlayerAttackMoveAction.new(step) if step != Vector2i.ZERO else PlayerRestAction.new()
		World.apply_player_action(action)
		if not World.current_map.depth in visited: visited.append(World.current_map.depth)
		await get_tree().process_frame
	check(visited == [1,2,3], id + " traverses the first three procedural floors via real actions")
	check(not World.player.is_dead, id + " survives the three-floor smoke route")
	expeditions.append({"character": id, "floors": visited, "actions": actions, "hp": World.player.hp, "won": NightRun.won, "runes": NightRun.runes})
	World.initialize()
	check(not World.game_over and not NightRun.won and NightRun.runes == 0 and NightRun.flasks == 3, id + " new expedition resets run state")

