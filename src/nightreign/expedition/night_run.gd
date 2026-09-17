extends Node
## Turn-based adaptation layer. Map, FOV, Action and equipment remain upstream systems.
var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/nightreign/data/expedition.json"))
var weapon_profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/nightreign/data/weapon_archetypes.json"))
var cooldown: int = 0
var charge: int = 0
var immortal: int = 0
var sixth_sense: bool = true
var runes: int = 0
var won: bool = false
var family_index: int = 0
var flasks: int = 3
var prepared: Dictionary = {}
var grace_used: Dictionary = {}
var facing := Vector2i.DOWN
var telegraphs: Dictionary = {}
var run_log: Array[String] = []
var healing_fields: Array[Dictionary] = []
var pending_ghosts: Array[Dictionary] = []
var floor_turns: Dictionary = {}
var night_stage: Dictionary = {}
const FAMILY := ["Helen", "Frederick", "Sebastian"]

func character_data() -> Dictionary:
	return data.characters[CharacterCatalog.selected_id]

func progression() -> Dictionary:
	return data.floor_progression

func total_floors() -> int:
	return int(progression().total_floors)

func boss_floor() -> int:
	return int(progression().boss_floor)

func milestone_count(depth: int) -> int:
	var count := 0
	for milestone: Variant in progression().milestones:
		if depth >= int(milestone):
			count += 1
	return count

func floor_enemy_count(depth: int) -> int:
	if depth >= boss_floor():
		return 0
	var cfg: Dictionary = progression().enemy_count
	var count := int(cfg.base)
	count += int((depth - 1) / 2) * int(cfg.per_two_floors)
	count += milestone_count(depth) * int(cfg.milestone_bonus)
	return mini(int(cfg.max), count)

func floor_hp_multiplier(depth: int) -> float:
	var cfg: Dictionary = progression().hp_multiplier
	return float(cfg.base) + float(maxi(0, depth - 1)) * float(cfg.per_floor)

func floor_damage_multiplier(depth: int) -> float:
	var cfg: Dictionary = progression().damage_multiplier
	return float(cfg.base) + float(maxi(0, depth - 1)) * float(cfg.per_floor)

func floor_rune_multiplier(depth: int) -> float:
	var cfg: Dictionary = progression().rune_multiplier
	return float(cfg.base) + float(maxi(0, depth - 1)) * float(cfg.per_floor)

func floor_elite_chance(depth: int) -> float:
	if depth >= boss_floor():
		return 0.0
	var cfg: Dictionary = progression().elite
	var chance := float(cfg.base_chance)
	chance += float(maxi(0, depth - 1)) * float(cfg.per_floor)
	chance += float(milestone_count(depth)) * float(cfg.milestone_bonus)
	return minf(float(cfg.max_chance), chance)

func floor_enemy_pool(depth: int) -> Array[String]:
	var pool: Array[String] = []
	for raw_entry: Variant in progression().enemy_pools:
		var entry: Dictionary = raw_entry
		if depth < int(entry.from_floor):
			continue
		pool.clear()
		for raw_id: Variant in entry.ids:
			pool.append(String(raw_id))
	return pool

func floor_weapon_drops(depth: int) -> int:
	var cfg: Dictionary = progression().weapon_drops
	var count := int(cfg.base) + int((depth - 1) / 7) * int(cfg.per_seven_floors)
	return mini(int(cfg.max), count)

func floor_warming_stones(depth: int) -> int:
	var cfg: Dictionary = progression().warming_stones
	var count := int(cfg.base) + milestone_count(depth) * int(cfg.milestone_bonus)
	return mini(int(cfg.max), count)

func night_threshold(map: Map, index: int) -> int:
	var cfg: Dictionary = data.night_tide
	var base := int(cfg.thresholds[index])
	var minimum := int(cfg.minimum_thresholds[index])
	var reduction := int(cfg.threshold_reduction_per_floor[index]) * maxi(0, map.depth - 1)
	return maxi(minimum, base - reduction)

func note(message: String) -> void:
	run_log.append(message)
	World.message_logged.emit(message, LogMessages.Level.NORMAL)

func reset_run() -> void:
	cooldown = 0
	charge = 0
	immortal = 0
	sixth_sense = true
	runes = 0
	won = false
	flasks = 3
	family_index = 0
	prepared.clear()
	grace_used.clear()
	telegraphs.clear()
	run_log.clear()
	healing_fields.clear()
	pending_ghosts.clear()
	floor_turns.clear()
	night_stage.clear()
	World.player.max_hp = int(character_data().hp)
	World.player.hp = World.player.max_hp
	World.player.inventory.clear()
	for slot in Equipment.Slot.values():
		World.player.equipment.unequip(slot)
	var weapon := make_weapon(character_data().starting_weapon)
	World.player.add_item(weapon)
	World.player.equipment.equip(weapon, Equipment.Slot.MELEE)
	prepare_map(World.current_map)

func weapon_archetype_id(id: String) -> String:
	assert(data.weapons.has(id), "Unknown Nightreign weapon: %s" % id)
	assert(weapon_profiles.weapons.has(id), "Missing weapon archetype mapping: %s" % id)
	return String(weapon_profiles.weapons[id])

func weapon_archetype(id: String) -> Dictionary:
	var archetype_id := weapon_archetype_id(id)
	assert(weapon_profiles.archetypes.has(archetype_id), "Unknown weapon archetype: %s" % archetype_id)
	return weapon_profiles.archetypes[archetype_id]

func weapon_sprite_name(id: String) -> StringName:
	assert(weapon_profiles.sprites.has(id), "Missing weapon sprite mapping: %s" % id)
	return StringName(String(weapon_profiles.sprites[id]))

func _item_type_from_name(type_name: String) -> int:
	match type_name:
		"SWORD": return Item.Type.SWORD
		"KNIFE": return Item.Type.KNIFE
		"WAND": return Item.Type.WAND
	push_error("Unsupported Nightreign item type: %s" % type_name)
	return Item.Type.MELEE

func _skill_type_from_name(type_name: String) -> int:
	match type_name:
		"SWORD": return Skills.Type.SWORD
		"KNIFE": return Skills.Type.KNIFE
		"UTILITY": return Skills.Type.UTILITY
	push_error("Unsupported Nightreign skill type: %s" % type_name)
	return Skills.Type.NONE

func _damage_type_from_name(type_name: String) -> int:
	match type_name:
		"SLASH": return Damage.Type.SLASH
		"PIERCE": return Damage.Type.PIERCE
		"BLUNT": return Damage.Type.BLUNT
	push_error("Unsupported Nightreign damage type: %s" % type_name)
	return Damage.Type.BLUNT

func make_weapon(id: String) -> Item:
	var entry: Dictionary = data.weapons[id]
	var archetype_id := weapon_archetype_id(id)
	var archetype: Dictionary = weapon_archetype(id)
	var item := Item.new(true)
	item.set_meta("night_weapon", id)
	item.set_meta("night_archetype", archetype_id)
	item.set_meta("night_affinity", String(entry.affinity))
	item.name = entry.name
	item.type = _item_type_from_name(String(archetype.item_type))
	item.skill_type = _skill_type_from_name(String(archetype.skill_type))
	item.damage = [1, int(entry.base)]
	item.damage_types = [_damage_type_from_name(String(archetype.damage_type))]
	item.sprite_name = weapon_sprite_name(id)
	item._mass = 0.0
	return item

func weapon_damage(item: Item, character_id: String = "") -> int:
	if character_id.is_empty():
		character_id = CharacterCatalog.selected_id
	if item == null or not item.has_meta("night_weapon"):
		return 3
	var entry: Dictionary = data.weapons[item.get_meta("night_weapon")]
	var total := float(entry.base)
	for stat: String in entry.scaling:
		total += float(data.grades[data.characters[character_id].grades[stat]]) * float(data.scaling[entry.scaling[stat]])
	return roundi(total) + item.enhancement

func weapon_damage_type(item: Item) -> int:
	if item == null or not item.has_meta("night_weapon"):
		return Damage.Type.BLUNT
	var profile: Dictionary = weapon_archetype(String(item.get_meta("night_weapon")))
	return _damage_type_from_name(String(profile.damage_type))

func weapon_description(item: Item) -> String:
	if item == null or not item.has_meta("night_weapon"):
		return ""
	var entry: Dictionary = data.weapons[item.get_meta("night_weapon")]
	var parts: Array[String] = []
	for stat: String in entry.scaling:
		parts.append(stat + " " + entry.scaling[stat])
	var profile: Dictionary = weapon_archetype(String(item.get_meta("night_weapon")))
	return "Archetype: %s\nScaling: %s\nAffinity: %s\nYour attack: %d\nNo stat requirement." % [profile.label, ", ".join(parts), entry.affinity, weapon_damage(item)]

func spawn_enemy(id: String, map: Map, pos: Vector2i, depth: int = -1, force_elite: bool = false) -> Monster:
	var entry: Dictionary = data.enemies[id]
	var enemy := MonsterFactory.create_monster(StringName(entry.template))
	if depth < 1:
		depth = map.depth
	var scales_with_floor := bool(entry.get("scales_with_floor", true))
	var hp_multiplier := floor_hp_multiplier(depth) if scales_with_floor else 1.0
	var damage_multiplier := floor_damage_multiplier(depth) if scales_with_floor else 1.0
	var rune_multiplier := floor_rune_multiplier(depth) if scales_with_floor else 1.0
	var elite := force_elite and id not in ["gladius", "gladius_echo"]
	if elite:
		var elite_cfg: Dictionary = progression().elite
		hp_multiplier *= float(elite_cfg.hp_multiplier)
		damage_multiplier *= float(elite_cfg.damage_multiplier)
		rune_multiplier *= float(elite_cfg.rune_multiplier)
	enemy.set_meta("night_enemy", id)
	enemy.set_meta("night_depth", depth)
	enemy.set_meta("night_elite", elite)
	enemy.set_meta("night_damage", maxi(1, roundi(float(entry.damage) * damage_multiplier)))
	enemy.set_meta("night_runes", maxi(0, roundi(float(entry.runes) * rune_multiplier)))
	enemy.name = ("Night-Touched " if elite else "") + String(entry.name)
	enemy.max_hp = maxi(1, roundi(float(entry.hp) * hp_multiplier))
	enemy.hp = enemy.max_hp
	enemy.inventory.clear()
	for slot in Equipment.Slot.values():
		enemy.equipment.unequip(slot)
	enemy.faction = Factions.Type.MONSTERS
	enemy.behavior = Monster.Behavior.AGGRESSIVE
	map.get_cell(pos).monster = enemy
	return enemy

func prepare_map(map: Map) -> void:
	if prepared.has(map.id):
		return
	prepared[map.id] = true
	floor_turns[map.id] = 0
	night_stage[map.id] = 0
	telegraphs.clear()
	var start := map.find_monster_position(World.player)
	var floors: Array[Vector2i] = []
	for x in map.width:
		for y in map.height:
			var p := Vector2i(x, y)
			var cell := map.get_cell(p)
			cell.items.clear()
			if cell.monster != World.player:
				cell.monster = null
			if cell.obstacle and cell.obstacle.type not in [Obstacle.Type.STAIRS_UP, Obstacle.Type.STAIRS_DOWN]:
				cell.obstacle = null
			if cell.terrain.type == Terrain.Type.DUNGEON_DOOR_CLOSED:
				cell.terrain.type = Terrain.Type.DUNGEON_DOOR_OPEN
			if cell.is_walkable() and cell.obstacle == null and p.distance_to(start) > 4:
				floors.append(p)
	floors.shuffle()

	if map.depth == boss_floor():
		var preferred := Vector2i(int(map.width / 2), int(map.height / 3))
		var boss_pos := preferred
		if not map.is_in_bounds(boss_pos) or not map.get_cell(boss_pos).is_walkable() or map.get_monster(boss_pos) != null:
			boss_pos = floors.pop_back() if not floors.is_empty() else preferred
		spawn_enemy("gladius", map, boss_pos, map.depth)
		return

	var pool := floor_enemy_pool(map.depth)
	if pool.is_empty():
		pool.append("wolf")
		pool.append("soldier")
	for i in mini(floor_enemy_count(map.depth), floors.size()):
		var enemy_id: String = pool[randi_range(0, pool.size() - 1)]
		var elite := randf() < floor_elite_chance(map.depth)
		spawn_enemy(enemy_id, map, floors.pop_back(), map.depth, elite)

	var weapon_ids: Array = data.weapons.keys()
	for i in mini(floor_weapon_drops(map.depth), floors.size()):
		var weapon_id := String(weapon_ids[randi_range(0, weapon_ids.size() - 1)])
		map.add_item(floors.pop_back(), make_weapon(weapon_id))
	# Preserve a fair boss-prep route without handing out Holy on every floor.
	if map.depth == boss_floor() - 1:
		map.add_item(start, make_weapon("sacred_blade"))

	for i in mini(floor_warming_stones(map.depth), floors.size()):
		var bolus := Item.new(true)
		bolus.name = "Warming Stone"
		bolus.set_meta("warming_stone", true)
		bolus.type = Item.Type.CONSUMABLE
		bolus.hp = 1
		bolus._mass = 0
		bolus.sprite_name = ItemFactory.create_item(&"poison_splash_potion").sprite_name
		map.add_item(floors.pop_back(), bolus)

func night_center(map: Map) -> Vector2i:
	for x in map.width:
		for y in map.height:
			var p := Vector2i(x, y)
			if map.get_stairs_type(p) == Obstacle.Type.STAIRS_DOWN:
				return p
	# Boss arenas and unusual test maps may not have a descent.
	return Vector2i(int(map.width / 2), int(map.height / 2))

func get_night_stage(map: Map) -> int:
	return int(night_stage.get(map.id, 0))

func get_floor_turns(map: Map) -> int:
	return int(floor_turns.get(map.id, 0))

func turns_until_next_tide(map: Map) -> int:
	if map.depth >= boss_floor():
		return -1
	var turns := get_floor_turns(map)
	var stage := get_night_stage(map)
	if stage >= 2:
		return 0
	return maxi(0, night_threshold(map, stage) - turns)

func safe_radius(map: Map) -> int:
	var stage := get_night_stage(map)
	if stage <= 0:
		return maxi(map.width, map.height)
	var radii: Array = data.night_tide.safe_radius
	return int(radii[mini(stage - 1, radii.size() - 1)])

func is_in_tide(map: Map, pos: Vector2i) -> bool:
	if map == null or map.depth >= boss_floor() or get_night_stage(map) <= 0:
		return false
	var center := night_center(map)
	var delta := pos - center
	return maxi(absi(delta.x), absi(delta.y)) > safe_radius(map)

func _advance_nights_tide(map: Map) -> void:
	if map.depth >= boss_floor() or World.player.is_dead:
		return
	var turns := get_floor_turns(map) + 1
	floor_turns[map.id] = turns
	var stage := 0
	for index in range(2):
		if turns >= night_threshold(map, index):
			stage += 1
	var old_stage := get_night_stage(map)
	if stage != old_stage:
		night_stage[map.id] = stage
		if stage == 1:
			note("Night's Tide encroaches. Move toward the descent.")
		elif stage >= 2:
			note("Deep Night closes in. The safe route is collapsing.")
	var player_pos := map.find_monster_position(World.player)
	if is_in_tide(map, player_pos):
		var damages: Array = data.night_tide.damage
		var damage := int(damages[mini(stage - 1, damages.size() - 1)])
		damage = protect_damage(World.player, damage)
		World.player.hp = maxi(0, World.player.hp - damage)
		note("Night's Tide burns for %d damage." % damage)
		if World.player.hp <= 0:
			World.player.is_dead = true

func _spawn_gladius_echoes(actor: Monster, map: Map, result: ActionResult) -> bool:
	var origin := map.find_monster_position(actor)
	var spawned := 0
	for offset: Vector2i in [Vector2i.LEFT * 2, Vector2i.RIGHT * 2, Vector2i.UP * 2, Vector2i.DOWN * 2, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if spawned >= 2:
			break
		var pos := origin + offset
		if not map.is_in_bounds(pos) or not map.get_cell(pos).is_walkable() or map.get_monster(pos) != null:
			continue
		var echo := spawn_enemy("gladius_echo", map, pos)
		echo.set_meta("boss_echo", true)
		spawned += 1
	if spawned > 0:
		telegraphs.erase(actor.get_instance_id())
		result.message = "Gladius divides into hunting echoes!"
		return true
	return false

func make_arena(depth: int = 20, up_destination: String = "level_19") -> Map:
	var map := Map.new(19, 17, depth, "level_%d" % depth)
	for x in map.width:
		for y in map.height:
			var terrain := Terrain.new()
			terrain.type = Terrain.Type.DUNGEON_WALL if x == 0 or y == 0 or x == 18 or y == 16 else Terrain.Type.DUNGEON_FLOOR
			map.get_cell(Vector2i(x,y)).terrain = terrain
	var stairs := Obstacle.new()
	stairs.type = Obstacle.Type.STAIRS_UP
	stairs.destination_level = up_destination
	map.get_cell(Vector2i(9, 13)).obstacle = stairs
	return map

func first_target(map: Map, dir: Vector2i, distance: int) -> Monster:
	var p := map.find_monster_position(World.player)
	for i in range(1, distance + 1):
		var target := p + dir * i
		if not map.is_in_bounds(target) or map.is_opaque(target): return null
		var monster := map.get_monster(target)
		if monster and not monster.has_meta("family"):
			return monster
	return null

func use_ability(kind: String, dir: Vector2i, map: Map, result: ActionResult) -> bool:
	if World.game_over or World.player.is_dead or kind not in ["skill", "ultimate", "flask", "grace"]:
		return false
	if kind == "flask":
		if flasks <= 0 or World.player.hp == World.player.max_hp:
			result.message = "No healing needed, or no flask charges."
			return false
		flasks -= 1
		World.player.hp = mini(World.player.max_hp, World.player.hp + 28)
		result.message = "Flask of Crimson Tears restores 28 HP."
		return true
	if kind == "grace":
		var p := map.find_monster_position(World.player)
		if map.get_stairs_type(p) != Obstacle.Type.STAIRS_UP or grace_used.has(map.id):
			result.message = "Rest at this floor's entrance once per expedition."
			return false
		grace_used[map.id] = true
		World.player.hp = World.player.max_hp
		flasks = 3
		cooldown = 0
		sixth_sense = true
		result.message = "Site of Grace: health and flasks restored."
		return true
	if kind == "skill" and cooldown > 0:
		result.message = "Skill ready in %d turns." % cooldown
		return false
	if kind == "ultimate" and charge < 100:
		result.message = "Ultimate charge %d / 100." % charge
		return false
	if CharacterCatalog.selected_id == "wylder":
		if dir == Vector2i.ZERO: return false
		var target := first_target(map, dir, 5 if kind == "skill" else 3)
		if target == null:
			result.message = "No enemy on that clear line."
			return false
		var origin := map.find_monster_position(World.player)
		var pos := map.find_monster_position(target)
		if kind == "skill":
			if target.get_meta("night_enemy", "") == "gladius":
				var landing := pos - dir
				if landing == origin or not map.get_cell(landing).is_walkable() or map.get_monster(landing):
					result.message = "No clear landing for the claw."
					return false
				map.find_and_remove_monster(World.player)
				map.get_cell(landing).monster = World.player
				result.add_effect(MoveEffect.new(World.player, landing, origin))
			else:
				var landing := origin + dir
				if pos != landing and map.get_monster(landing) == null:
					map.find_and_remove_monster(target)
					map.get_cell(landing).monster = target
					result.add_effect(MoveEffect.new(target, landing, pos))
			hurt(target, 5, result)
			cooldown = int(character_data().cooldown) + 1
			result.message = "Claw Shot!"
		else:
			hurt(target, 32, result)
			for enemy in map.get_monsters().duplicate():
				if enemy != World.player and enemy != target and not enemy.has_meta("family") and map.find_monster_position(enemy).distance_to(pos) <= 1.5:
					hurt(enemy, 16, result)
			charge = 0
			result.message = "Onslaught Stake detonates!"
	else:
		if kind == "skill":
			var p := map.find_monster_position(World.player)
			var landing := Utils.INVALID_POS
			for offset: Vector2i in Utils.ALL_DIRECTIONS:
				var candidate := p + offset
				if map.is_in_bounds(candidate) and map.get_cell(candidate).is_walkable() and map.get_monster(candidate) == null:
					landing = candidate
					break
			if landing == Utils.INVALID_POS:
				result.message = "No space to summon family."
				return false
			for old in map.get_monsters().duplicate():
				if old.has_meta("family") and not old.has_meta("ghost"): map.find_and_remove_monster(old)
			var family := MonsterFactory.create_monster(&"skeleton")
			family.name = FAMILY[family_index]
			family.set_meta("family", family_index)
			family.set_meta("ttl", 13)
			family.hp = 24
			family.max_hp = 24
			family.faction = Factions.Type.HUMAN
			map.get_cell(landing).monster = family
			family_index = (family_index + 1) % FAMILY.size()
			cooldown = int(character_data().cooldown) + 1
			result.message = "%s answers the lyre." % family.name
		else:
			immortal = 4
			charge = 0
			for ally in map.get_monsters():
				if ally.has_meta("family"):
					ally.hp = ally.max_hp
					ally.set_meta("ttl", 13)
					for enemy in map.get_monsters().duplicate():
						if enemy.has_meta("night_enemy") and map.find_monster_position(enemy).distance_to(map.find_monster_position(ally)) <= 3:
							hurt(enemy, 12, result)
			result.message = "Immortal March: cannot fall below 1 HP for 3 turns."
	return true

func protect_damage(target: Monster, amount: int) -> int:
	if immortal > 0 and (target == World.player or target.has_meta("family")):
		return mini(amount, maxi(0, target.hp - 1))
	if target == World.player and CharacterCatalog.selected_id == "wylder" and sixth_sense and amount >= target.hp:
		sixth_sense = false
		note("Sixth Sense prevents death!")
		return maxi(0, target.hp - 1)
	return amount

func hurt(target: Monster, amount: int, result: ActionResult) -> void:
	var pos := World.current_map.find_monster_position(target)
	amount = protect_damage(target, amount)
	target.hp = maxi(0, target.hp - amount)
	if target.hp == 0:
		target.is_dead = true
		if target != World.player:
			on_killed(target)
			World.current_map.find_and_remove_monster(target)
		result.add_effect(DeathEffect.new(target, pos, true))
	else:
		result.add_effect(HitEffect.new(target, Vector2.ZERO, pos, World.player, true))

func resolve_melee(attacker: Monster, defender: Monster) -> Combat.MeleeAttackResult:
	var result := Combat.MeleeAttackResult.new()
	var amount := 4
	var resolved_damage_type := Damage.Type.SLASH
	if attacker == World.player:
		var weapon := attacker.equipment.get_equipped_item(Equipment.Slot.MELEE)
		amount = weapon_damage(weapon)
		resolved_damage_type = weapon_damage_type(weapon)
		charge = mini(100, charge + 12)
		if defender.get_meta("night_enemy", "") == "gladius" and weapon and weapon.has_meta("night_weapon"):
			if data.weapons[weapon.get_meta("night_weapon")].affinity == "holy":
				amount += 5
				var buildup := int(defender.get_meta("holy_buildup", 0)) + 1
				defender.set_meta("holy_buildup", buildup % 3)
				if buildup >= 3:
					defender.set_meta("stagger", 1)
	elif attacker.has_meta("night_enemy"):
		amount = int(attacker.get_meta("night_damage", data.enemies[attacker.get_meta("night_enemy")].damage))
	elif attacker.has_meta("family"):
		amount = [5, 8, 6][int(attacker.get_meta("family"))] + (4 if immortal > 0 else 0)
	if defender == World.player: charge = mini(100, charge + 6)
	result.damage = protect_damage(defender, amount)
	result.damage_type = resolved_damage_type
	result.killed = result.damage >= defender.hp
	return result

func on_killed(monster: Monster) -> void:
	if not monster.has_meta("night_enemy"): return
	var id: String = monster.get_meta("night_enemy")
	runes += int(monster.get_meta("night_runes", data.enemies[id].runes))
	charge = mini(100, charge + 18)
	telegraphs.erase(monster.get_instance_id())
	if CharacterCatalog.selected_id == "revenant" and id not in ["gladius", "gladius_echo"] and randf() < 0.25:
		pending_ghosts.append({"position": World.current_map.find_monster_position(monster), "map": World.current_map.id})
	if id == "gladius":
		won = true
		call_deferred("_finish_victory")

func _finish_victory() -> void:
	if World.player.is_dead: return
	World.game_over = true
	note("NIGHTLORD FELLED - expedition complete.")
	World.game_ended.emit()

func end_turn() -> void:
	_advance_nights_tide(World.current_map)
	cooldown = maxi(0, cooldown - 1)
	immortal = maxi(0, immortal - 1)
	World.player.nutrition.value = Nutrition.STARTING_NUTRITION
	var map := World.current_map
	for field in healing_fields.duplicate():
		if field.map != map.id: continue
		for creature in map.get_monsters():
			if not creature.is_dead and map.find_monster_position(creature).distance_to(field.position) <= 1.5:
				creature.hp = mini(creature.max_hp, creature.hp + 6)
		field.turns -= 1
		if field.turns <= 0: healing_fields.erase(field)
	for ghost in pending_ghosts:
		if ghost.map != map.id or not map.is_in_bounds(ghost.position) or map.get_monster(ghost.position): continue
		var spirit := MonsterFactory.create_monster(&"skeleton")
		spirit.name = "Fallen Spirit"
		spirit.set_meta("family", 0)
		spirit.set_meta("ghost", true)
		spirit.set_meta("ttl", 4)
		spirit.max_hp = 8
		spirit.hp = 8
		spirit.faction = Factions.Type.HUMAN
		map.get_cell(ghost.position).monster = spirit
		note("Necromancy: a fallen spirit joins the fight.")
	pending_ghosts.clear()

func place_warming_stone(actor: Monster, map: Map, result: ActionResult) -> void:
	healing_fields.append({"position": map.find_monster_position(actor), "map": map.id, "turns": 3})
	result.message = "Warming Stone: all nearby creatures heal 6 HP each turn, for 3 turns."

func clear_line(map: Map, origin: Vector2i, destination: Vector2i) -> bool:
	var distance := maxi(absi(destination.x - origin.x), absi(destination.y - origin.y))
	for step in range(1, distance):
		var p := Vector2i(Vector2(origin).lerp(Vector2(destination), float(step) / distance).round())
		if map.is_opaque(p): return false
	return true

func act_enemy(actor: Monster, map: Map, result: ActionResult) -> bool:
	if actor.is_dead or World.player.is_dead: return true
	var origin := map.find_monster_position(actor)
	if origin == Utils.INVALID_POS: return true
	var target: Monster = World.player
	if actor.has_meta("family"):
		var life := int(actor.get_meta("ttl")) - 1
		actor.set_meta("ttl", life)
		if life <= 0:
			map.find_and_remove_monster(actor)
			return true
		target = null
		var best := INF
		for candidate in map.get_monsters():
			if not candidate.has_meta("night_enemy"): continue
			var distance := origin.distance_to(map.find_monster_position(candidate))
			if distance < best:
				best = distance
				target = candidate
		if target == null: return true
	else:
		for ally in map.get_monsters():
			if ally.has_meta("family") and origin.distance_to(map.find_monster_position(ally)) <= 1.5:
				target = ally
	var destination := map.find_monster_position(target)
	if actor.has_meta("family") and origin.distance_to(destination) <= [2.0, 1.5, 3.0][int(actor.get_meta("family"))] and clear_line(map, origin, destination):
		hurt(target, [5, 8, 6][int(actor.get_meta("family"))] + (4 if immortal > 0 else 0), result)
		return true
	if actor.get_meta("night_enemy", "") == "gladius":
		if actor.hp <= actor.max_hp / 2 and not bool(actor.get_meta("split_done", false)):
			actor.set_meta("split_done", true)
			if _spawn_gladius_echoes(actor, map, result):
				return true
		if int(actor.get_meta("recovery", 0)) > 0:
			actor.set_meta("recovery", 0)
			result.message = "Gladius recovers: an opening to attack."
			return true
		if int(actor.get_meta("stagger", 0)) > 0:
			actor.set_meta("stagger", 0)
			telegraphs.erase(actor.get_instance_id())
			result.message = "Holy damage interrupts Gladius."
			return true
		var key := actor.get_instance_id()
		if telegraphs.has(key):
			var cells: Array = telegraphs[key]
			for victim in map.get_monsters().duplicate():
				if victim == actor or victim.has_meta("night_enemy"): continue
				if map.find_monster_position(victim) in cells:
					hurt(victim, 16 if actor.hp > actor.max_hp / 2 else 21, result)
			telegraphs.erase(key)
			actor.set_meta("recovery", 1)
			result.message = "Gladius unleashes the marked flame sweep!"
			return true
		if origin.distance_to(destination) <= 6:
			var cells: Array[Vector2i] = []
			var dir := (destination - origin).sign()
			var perpendicular := Vector2i(-dir.y, dir.x)
			for step in range(1, 7):
				for side in range(-1, 2):
					var cell := origin + dir * step + perpendicular * side
					if map.is_in_bounds(cell): cells.append(cell)
			telegraphs[key] = cells
			result.message = "Gladius draws back: leave the red tiles before your next action!"
			return true
	if origin.distance_to(destination) <= 1.5:
		return MeleeAction.new(actor, destination - origin)._execute(map, result)
	if origin.distance_to(destination) > 9: return true
	var dir := (destination - origin).sign()
	for step: Vector2i in [dir, Vector2i(dir.x, 0), Vector2i(0, dir.y)]:
		if step == Vector2i.ZERO: continue
		var p := origin + step
		if map.is_in_bounds(p) and map.get_cell(p).is_walkable() and map.get_monster(p) == null:
			return MoveAction.new(actor, step)._execute(map, result)
	return true
