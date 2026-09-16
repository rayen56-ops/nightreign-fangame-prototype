class_name NightWeaponAttackAction
extends ActorAction
## Deliberate weapon attack used by T1 combat language. Movement bump-attacks remain intact.

var direction: Vector2i

func _init(dir: Vector2i) -> void:
	super(World.player)
	direction = dir.sign()

func _execute(map: Map, result: ActionResult) -> bool:
	if not super(map, result) or actor != World.player or direction == Vector2i.ZERO:
		return false
	if World.game_over or actor.is_dead:
		return false
	if actor.has_status_effect(StatusEffect.Type.PARALYZED):
		result.message = "You are paralyzed and cannot attack!"
		result.message_level = LogMessages.Level.TERRIBLE
		return true

	NightRun.facing = direction
	var weapon := actor.equipment.get_equipped_item(Equipment.Slot.MELEE)
	var profile := _profile(weapon)
	var origin := map.find_monster_position(actor)
	if origin == Utils.INVALID_POS:
		return false

	var targets := _collect_targets(map, origin, profile)
	if targets.is_empty():
		result.message = "%s cuts through empty night." % _weapon_name(weapon)
		return true

	# One attack animation, then one or more impacts depending on the archetype.
	result.add_effect(AttackEffect.new(actor, Vector2(direction) * -1.0, targets[0], origin))
	var damage := NightRun.weapon_damage(weapon)
	var hit_names: Array[String] = []
	for target: Monster in targets:
		if target == null or target.is_dead:
			continue
		NightRun.hurt(target, damage, result)
		hit_names.append(target.name)
		if not target.is_dead:
			_apply_status(target, profile, result)
	NightRun.charge = mini(100, NightRun.charge + 12)
	result.extra_nutrition_consumed = 2
	result.message = "%s [%s] hits %s." % [_weapon_name(weapon), String(profile.pattern).capitalize(), ", ".join(hit_names)]
	return true

func _weapon_name(weapon: Item) -> String:
	return weapon.name if weapon != null else "Unarmed strike"

func _profile(weapon: Item) -> Dictionary:
	var fallback := {"reach": 1, "pattern": "single", "poise": 1, "status": {}}
	if weapon == null or not weapon.has_meta("night_weapon"):
		return fallback
	var weapon_id := String(weapon.get_meta("night_weapon"))
	if not NightRun.data.weapons.has(weapon_id):
		return fallback
	var entry: Dictionary = NightRun.data.weapons[weapon_id]
	var archetype := String(entry.get("archetype", "straight_sword"))
	if not NightRun.data.weapon_archetypes.has(archetype):
		return fallback
	return NightRun.data.weapon_archetypes[archetype]

func _collect_targets(map: Map, origin: Vector2i, profile: Dictionary) -> Array[Monster]:
	var found: Array[Monster] = []
	var pattern := String(profile.get("pattern", "single"))
	var reach := maxi(1, int(profile.get("reach", 1)))
	if pattern == "sweep":
		for dir in _fan_directions(direction):
			_append_target_at(map, origin + dir, found)
		return found
	if pattern == "line":
		for step in range(1, reach + 1):
			var pos := origin + direction * step
			if not map.is_in_bounds(pos) or map.is_opaque(pos):
				break
			var target := map.get_monster(pos)
			if target != null:
				if target != actor and not target.has_meta("family"):
					found.append(target)
				break
		return found
	_append_target_at(map, origin + direction, found)
	return found

func _append_target_at(map: Map, pos: Vector2i, found: Array[Monster]) -> void:
	if not map.is_in_bounds(pos):
		return
	var target := map.get_monster(pos)
	if target != null and target != actor and not target.has_meta("family") and target not in found:
		found.append(target)

func _fan_directions(center: Vector2i) -> Array[Vector2i]:
	var ring: Array[Vector2i] = [
		Vector2i.DOWN,
		Vector2i.DOWN + Vector2i.LEFT,
		Vector2i.LEFT,
		Vector2i.UP + Vector2i.LEFT,
		Vector2i.UP,
		Vector2i.UP + Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.DOWN + Vector2i.RIGHT,
	]
	var index := ring.find(center.sign())
	if index < 0:
		return [center.sign()]
	return [ring[(index + ring.size() - 1) % ring.size()], ring[index], ring[(index + 1) % ring.size()]]

func _apply_status(target: Monster, profile: Dictionary, result: ActionResult) -> void:
	var statuses: Dictionary = profile.get("status", {})
	for raw_name: Variant in statuses.keys():
		var status := String(raw_name)
		var threshold := int(NightRun.data.status_thresholds.get(status, 100))
		var key := "night_buildup_%s" % status
		var buildup := int(target.get_meta(key, 0)) + int(statuses[status])
		if buildup < threshold:
			target.set_meta(key, buildup)
			continue
		target.set_meta(key, buildup - threshold)
		if status == "bleed":
			var burst := maxi(1, roundi(float(target.max_hp) * 0.15))
			NightRun.hurt(target, burst, result)
			NightRun.note("Blood loss erupts for %d damage." % burst)
