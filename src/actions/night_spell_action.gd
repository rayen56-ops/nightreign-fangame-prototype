class_name NightSpellAction
extends ActorAction

var target_pos: Vector2i


func _init(p_target_pos: Vector2i) -> void:
	super(World.player)
	target_pos = p_target_pos


static func is_catalyst(item: Item) -> bool:
	if item == null or not item.has_meta("night_weapon"):
		return false
	var weapon_id := String(item.get_meta("night_weapon"))
	var profile := NightRun.weapon_archetype(weapon_id)
	return profile.has("cast")


func _catalyst() -> Item:
	var item := actor.equipment.get_equipped_item(Equipment.Slot.MELEE)
	return item if is_catalyst(item) else null


func _execute(map: Map, result: ActionResult) -> bool:
	if not super(map, result):
		return false

	var weapon := _catalyst()
	if weapon == null:
		result.message = "Equip a staff or sacred seal to cast."
		return false

	if actor.has_status_effect(StatusEffect.Type.PARALYZED):
		result.message = "You are paralyzed and cannot cast!"
		result.message_level = LogMessages.Level.TERRIBLE
		return true

	var source_pos := map.find_monster_position(actor)
	if source_pos == Utils.INVALID_POS or not map.is_in_bounds(target_pos) or target_pos == source_pos:
		return false

	var weapon_id := String(weapon.get_meta("night_weapon"))
	var profile := NightRun.weapon_archetype(weapon_id)
	var cast: Dictionary = profile.cast
	var cast_range := int(cast.get("range", 1))
	var delta := target_pos - source_pos
	var distance := maxi(absi(delta.x), absi(delta.y))
	if distance > cast_range:
		result.message = "%s reaches only %d tiles." % [String(cast.name), cast_range]
		return false

	var impact_pos := target_pos
	var hit_monster: Monster = null
	var blocked_by_family := false
	var trajectory := Utils.calculate_trajectory(source_pos, target_pos)
	for i in range(1, trajectory.size()):
		var p := trajectory[i]
		if map.is_opaque(p):
			impact_pos = p
			break
		var monster := map.get_monster(p)
		if monster == null:
			continue
		impact_pos = p
		if monster.has_meta("family"):
			blocked_by_family = true
		else:
			hit_monster = monster
		break

	result.effects.append(ProjectileEffect.new(actor, hit_monster, source_pos, impact_pos, weapon))
	result.extra_nutrition_consumed = 2

	if blocked_by_family:
		result.message = "%s blocks your line of fire." % map.get_monster(impact_pos).name
		return true

	if hit_monster == null:
		result.message = "%s dissipates at %s." % [String(cast.name), impact_pos]
		return true

	# Reuse the deterministic Nightreign player resolver so catalyst scaling,
	# Holy boss interaction and attack charge stay consistent with melee weapons.
	var base := NightRun.resolve_melee(actor, hit_monster)
	var multiplier := float(cast.get("multiplier", 1.0))
	var damage := maxi(1, roundi(float(base.damage) * multiplier))
	damage = NightRun.protect_damage(hit_monster, damage)
	hit_monster.hp = maxi(0, hit_monster.hp - damage)

	var direction := Vector2(impact_pos - source_pos).normalized()
	var affinity := StringName(String(cast.get("affinity", weapon.get_meta("night_affinity", "physical"))))
	var hit := HitEffect.new(hit_monster, direction, impact_pos, actor, damage > 0, damage, affinity)
	result.add_effect(hit)
	result.add_effect(StatusPopupEffect.new(hit_monster, impact_pos, str(damage), hit.feedback_color()))
	for event: Dictionary in base.special_events:
		result.add_effect(
			StatusPopupEffect.new(
				hit_monster,
				impact_pos,
				NightRun.status_event_text(event),
				NightRun.status_event_color(event)
			)
		)

	if hit_monster.hp <= 0:
		hit_monster.is_dead = true
		if hit_monster != World.player:
			if hit_monster.has_meta("night_enemy"):
				NightRun.on_killed(hit_monster)
			hit_monster.drop_everything()
			map.find_and_remove_monster(hit_monster)
		result.add_effect(DeathEffect.new(hit_monster, impact_pos, actor == World.player))
		result.message = "%s hits %s for %d. %s is felled!" % [String(cast.name), hit_monster.name, damage, hit_monster.name]
		result.message_level = LogMessages.Level.GOOD
	else:
		result.message = "%s hits %s for %d." % [String(cast.name), hit_monster.name, damage]

	return true


func _to_string() -> String:
	return "NightSpellAction(target_pos: %s)" % target_pos
