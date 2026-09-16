extends Node
## Turn-based adaptation layer. Map, FOV, Action and equipment remain upstream systems.
var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/nightreign/data/expedition.json"))
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
const FAMILY := ["Helen", "Frederick", "Sebastian"]

func character_data() -> Dictionary:
	return data.characters[CharacterCatalog.selected_id]

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
	World.player.max_hp = int(character_data().hp)
	World.player.hp = World.player.max_hp
	World.player.inventory.clear()
	for slot in Equipment.Slot.values():
		World.player.equipment.unequip(slot)
	var weapon := make_weapon(character_data().starting_weapon)
	World.player.add_item(weapon)
	World.player.equipment.equip(weapon, Equipment.Slot.MELEE)
	prepare_map(World.current_map)

func make_weapon(id: String) -> Item:
	var entry: Dictionary = data.weapons[id]
	var item := Item.new(true)
	item.set_meta("night_weapon", id)
	item.name = entry.name
	item.type = Item.Type.SWORD
	item.skill_type = Skills.Type.SWORD
	item.damage = [1, int(entry.base)]
	item.damage_types = [Damage.Type.SLASH]
	# Reuse a verified upstream sword icon until the art pass replaces item icons.
	item.sprite_name = ItemFactory.create_item(&"longsword").sprite_name
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

func weapon_description(item: Item) -> String:
	if item == null or not item.has_meta("night_weapon"):
		return ""
	var entry: Dictionary = data.weapons[item.get_meta("night_weapon")]
	var parts: Array[String] = []
	for stat: String in entry.scaling:
		parts.append(stat + " " + entry.scaling[stat])
	return "Scaling: %s\nAffinity: %s\nYour attack: %d\nNo stat requirement." % [", ".join(parts), entry.affinity, weapon_damage(item)]

func spawn_enemy(id: String, map: Map, pos: Vector2i) -> Monster:
	var entry: Dictionary = data.enemies[id]
	var enemy := MonsterFactory.create_monster(StringName(entry.template))
	enemy.set_meta("night_enemy", id)
	enemy.name = entry.name
	enemy.max_hp = int(entry.hp)
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
	var types := ["soldier", "wolf", "skeleton"]
	for i in mini(5 + map.depth if map.depth < 3 else 0, floors.size()):
		spawn_enemy(types[i % types.size()], map, floors.pop_back())
	if map.depth == 3 and not floors.is_empty():
		spawn_enemy("gladius", map, Vector2i(9, 4))
		floors.erase(Vector2i(9, 4))
	for id: String in data.weapons:
		if floors.is_empty(): break
		map.add_item(floors.pop_back(), make_weapon(id))
	# Holy armament is guaranteed at the entrance, making the first boss weakness usable.
	map.add_item(start, make_weapon("sacred_blade"))
	for i in mini(3, floors.size()):
		var bolus := Item.new(true)
		bolus.name = "Warming Stone"
		bolus.set_meta("warming_stone", true)
		bolus.type = Item.Type.CONSUMABLE
		bolus.hp = 1 # Marks the item as usable; the action creates a healing field.
		bolus._mass = 0
		bolus.sprite_name = ItemFactory.create_item(&"poison_splash_potion").sprite_name
		map.add_item(floors.pop_back(), bolus)

func make_arena() -> Map:
	var map := Map.new(19, 17, 3, "level_3")
	for x in map.width:
		for y in map.height:
			var terrain := Terrain.new()
			terrain.type = Terrain.Type.DUNGEON_WALL if x == 0 or y == 0 or x == 18 or y == 16 else Terrain.Type.DUNGEON_FLOOR
			map.get_cell(Vector2i(x,y)).terrain = terrain
	var stairs := Obstacle.new()
	stairs.type = Obstacle.Type.STAIRS_UP
	stairs.destination_level = "level_2"
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
	if attacker == World.player:
		var weapon := attacker.equipment.get_equipped_item(Equipment.Slot.MELEE)
		amount = weapon_damage(weapon)
		charge = mini(100, charge + 12)
		if defender.get_meta("night_enemy", "") == "gladius" and weapon and weapon.has_meta("night_weapon"):
			if data.weapons[weapon.get_meta("night_weapon")].affinity == "holy":
				amount += 5
				var buildup := int(defender.get_meta("holy_buildup", 0)) + 1
				defender.set_meta("holy_buildup", buildup % 3)
				if buildup >= 3:
					defender.set_meta("stagger", 1)
	elif attacker.has_meta("night_enemy"):
		amount = int(data.enemies[attacker.get_meta("night_enemy")].damage)
	elif attacker.has_meta("family"):
		amount = [5, 8, 6][int(attacker.get_meta("family"))] + (4 if immortal > 0 else 0)
	if defender == World.player: charge = mini(100, charge + 6)
	result.damage = protect_damage(defender, amount)
	result.damage_type = Damage.Type.SLASH
	result.killed = result.damage >= defender.hp
	return result

func on_killed(monster: Monster) -> void:
	if not monster.has_meta("night_enemy"): return
	var id: String = monster.get_meta("night_enemy")
	runes += int(data.enemies[id].runes)
	charge = mini(100, charge + 18)
	telegraphs.erase(monster.get_instance_id())
	if CharacterCatalog.selected_id == "revenant" and id != "gladius" and randf() < 0.25:
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
