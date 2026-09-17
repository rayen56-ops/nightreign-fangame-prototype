class_name MeleeAction
extends ActorAction

var direction: Vector2i
var reach: int = 1


func _init(p_actor: Monster, dir: Vector2i, p_reach: int = 1) -> void:
	super(p_actor)
	direction = dir
	reach = maxi(1, p_reach)


func _player_weapon_profile() -> Dictionary:
	if actor != World.player:
		return {}
	var weapon := actor.equipment.get_equipped_item(Equipment.Slot.MELEE)
	if weapon == null or not weapon.has_meta("night_weapon"):
		return {}
	return NightRun.weapon_archetype(String(weapon.get_meta("night_weapon")))


func _attack_affinity() -> StringName:
	if actor == World.player:
		var weapon := actor.equipment.get_equipped_item(Equipment.Slot.MELEE)
		if weapon != null and weapon.has_meta("night_weapon"):
			return StringName(String(weapon.get_meta("night_affinity", "physical")))
	return &"physical"


func _sweep_directions(dir: Vector2i) -> Array[Vector2i]:
	var forward := dir.sign()
	var directions: Array[Vector2i] = [forward]
	if forward.x == 0:
		directions.append(Vector2i(-1, forward.y))
		directions.append(Vector2i(1, forward.y))
	elif forward.y == 0:
		directions.append(Vector2i(forward.x, -1))
		directions.append(Vector2i(forward.x, 1))
	else:
		directions.append(Vector2i(forward.x, 0))
		directions.append(Vector2i(0, forward.y))
	return directions


func _scaled_result(base: Combat.MeleeAttackResult, defender: Monster, multiplier: float) -> Combat.MeleeAttackResult:
	var scaled := Combat.MeleeAttackResult.new()
	scaled.damage = NightRun.protect_damage(defender, maxi(1, roundi(float(base.damage) * multiplier)))
	scaled.damage_type = base.damage_type
	scaled.killed = scaled.damage >= defender.hp
	return scaled


func _apply_resolved_hit(
	map: Map,
	result: ActionResult,
	current_pos: Vector2i,
	target_pos: Vector2i,
	target_monster: Monster,
	combat_result: Combat.MeleeAttackResult
) -> void:
	target_monster.hp = max(0, target_monster.hp - combat_result.damage)
	result.message = Combat.format_melee_attack_message(actor, target_monster, combat_result)
	if target_monster == World.player:
		result.message_level = LogMessages.Level.BAD
	result.add_effect(AttackEffect.new(actor, Vector2(target_pos - current_pos) * -1, target_monster, current_pos))

	var uses_nightreign_rules := actor == World.player or actor.has_meta("night_enemy") or actor.has_meta("family")
	if uses_nightreign_rules and combat_result.damage > 0:
		var hit := HitEffect.new(
			target_monster,
			Vector2(target_pos - current_pos).normalized(),
			target_pos,
			actor,
			true,
			combat_result.damage,
			_attack_affinity()
		)
		result.add_effect(hit)
		result.add_effect(
			StatusPopupEffect.new(target_monster, target_pos, str(combat_result.damage), hit.feedback_color())
		)

	if combat_result.killed:
		target_monster.is_dead = true
		if target_monster != World.player:
			if target_monster.has_meta("night_enemy"):
				NightRun.on_killed(target_monster)
			target_monster.drop_everything()
			map.find_and_remove_monster(target_monster)
			result.message_level = LogMessages.Level.GOOD
		result.add_effect(DeathEffect.new(target_monster, target_pos, actor == World.player))


func _execute_player_pattern(
	map: Map,
	result: ActionResult,
	current_pos: Vector2i,
	target_pos: Vector2i,
	target_monster: Monster,
	profile: Dictionary
) -> bool:
	var pattern := String(profile.get("attack_pattern", "single"))
	if pattern in ["single", "thrust"]:
		return false

	# Resolve the primary strike once so attack charge, affinities and boss buildup
	# remain action-scoped. Extra sweep/burst hits derive from that deterministic hit.
	var base := NightRun.resolve_melee(actor, target_monster)
	var hits := 0

	if pattern == "sweep":
		_apply_resolved_hit(map, result, current_pos, target_pos, target_monster, base)
		hits += 1
		var sweep := _sweep_directions(direction)
		var side_multiplier := float(profile.get("side_multiplier", 0.75))
		for i in range(1, sweep.size()):
			var side_pos := current_pos + sweep[i]
			if not map.is_in_bounds(side_pos):
				continue
			var side_target := map.get_monster(side_pos)
			if side_target == null or side_target == World.player or side_target.has_meta("family"):
				continue
			var side_result := _scaled_result(base, side_target, side_multiplier)
			_apply_resolved_hit(map, result, current_pos, side_pos, side_target, side_result)
			hits += 1
		result.message = "Greatsword sweep strikes %d target%s." % [hits, "" if hits == 1 else "s"]
		return true

	if pattern == "burst":
		var hit_count := maxi(1, int(profile.get("hits", 2)))
		var hit_multiplier := float(profile.get("hit_multiplier", 0.65))
		for i in hit_count:
			if target_monster.is_dead or map.find_monster_position(target_monster) == Utils.INVALID_POS:
				break
			var burst_result := _scaled_result(base, target_monster, hit_multiplier)
			_apply_resolved_hit(map, result, current_pos, target_pos, target_monster, burst_result)
			hits += 1
		result.message = "Dagger burst lands %d hit%s." % [hits, "" if hits == 1 else "s"]
		return true

	push_warning("Unknown Nightreign attack pattern: %s" % pattern)
	return false


func _execute(map: Map, result: ActionResult) -> bool:
	if not super(map, result):
		return false

	var current_pos := map.find_monster_position(actor)
	if current_pos == Utils.INVALID_POS:
		return false

	if actor.has_status_effect(StatusEffect.Type.PARALYZED):
		if actor == World.player:
			result.message = "You are paralyzed and cannot attack!"
			result.message_level = LogMessages.Level.TERRIBLE
		else:
			result.message = "%s tries to attack but is paralyzed!" % actor.name
			result.message_level = LogMessages.Level.BAD
		return true

	if actor.has_status_effect(StatusEffect.Type.CONFUSED):
		direction = Utils.ALL_DIRECTIONS.pick_random()

	var target_pos := current_pos + direction.sign() * reach
	if not map.is_in_bounds(target_pos):
		return false

	var target_monster := map.get_monster(target_pos)
	if not target_monster:
		return false

	var profile := _player_weapon_profile()
	if not profile.is_empty() and _execute_player_pattern(map, result, current_pos, target_pos, target_monster, profile):
		result.extra_nutrition_consumed = 2
		return true

	# The Nightreign adaptation uses deterministic damage for the player, expedition enemies,
	# and Revenant family summons. Unrelated upstream actors keep the original resolver.
	var uses_nightreign_rules := actor == World.player or actor.has_meta("night_enemy") or actor.has_meta("family")
	var combat_result := (
		NightRun.resolve_melee(actor, target_monster)
		if uses_nightreign_rules
		else Combat.resolve_melee_attack(actor, target_monster)
	)

	_apply_resolved_hit(map, result, current_pos, target_pos, target_monster, combat_result)

	# Mark the action as exercise for nutrition processing
	result.extra_nutrition_consumed = 2
	return true


func _to_string() -> String:
	return "MeleeAction(actor: %s, direction: %s, reach: %d)" % [actor, direction, reach]
