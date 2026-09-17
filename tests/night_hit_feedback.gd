extends Node

var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("M2 HIT QA %s: %s" % ["PASS" if value else "FAIL", label])

func _ready() -> void:
	call_deferred("run")

func _sandbox(character_id: String = "wylder") -> Map:
	CharacterCatalog.select_character(character_id)
	World.initialize(22092026)
	var map := NightRun.make_arena(1, "")
	map.id = "hit_feedback_qa"
	World.current_map = map
	map.get_cell(Vector2i(9, 9)).monster = World.player
	NightRun.telegraphs.clear()
	NightRun.floor_turns[map.id] = 0
	NightRun.night_stage[map.id] = 0
	return map

func _equip(id: String) -> Item:
	var weapon := NightRun.make_weapon(id)
	World.player.add_item(weapon)
	World.player.equipment.equip(weapon, Equipment.Slot.MELEE)
	return weapon

func _set_hp(monster: Monster, amount: int) -> void:
	monster.max_hp = amount
	monster.hp = amount

func _hits(result: ActionResult) -> Array[HitEffect]:
	var ret: Array[HitEffect] = []
	for effect: ActionEffect in result.effects:
		if effect is HitEffect:
			ret.append(effect as HitEffect)
	return ret

func _popups(result: ActionResult) -> Array[StatusPopupEffect]:
	var ret: Array[StatusPopupEffect] = []
	for effect: ActionEffect in result.effects:
		if effect is StatusPopupEffect:
			ret.append(effect as StatusPopupEffect)
	return ret

func run() -> void:
	# Baseline melee now emits the hit animation payload and a matching damage number.
	var map := _sandbox()
	var sword := _equip("longsword")
	var target := NightRun.spawn_enemy("wolf", map, Vector2i(9, 8), 1)
	_set_hp(target, 100)
	var expected := NightRun.weapon_damage(sword, "wylder")
	var result := PlayerAttackMoveAction.new(Vector2i.UP).apply(map)
	var hits := _hits(result)
	var popups := _popups(result)
	check(hits.size() == 1, "single melee emits one HitEffect")
	check(hits[0].damage == expected, "single melee HitEffect carries exact applied damage")
	check(hits[0].affinity == &"physical", "single melee carries physical affinity")
	check(popups.size() == 1 and popups[0].text == str(expected), "single melee emits matching damage number")
	check(popups[0].color == hits[0].feedback_color(), "physical damage number uses hit affinity color")

	# Sweep feedback must follow every target, including scaled side hits.
	map = _sandbox()
	var greatsword := _equip("greatsword")
	var primary := NightRun.spawn_enemy("wolf", map, Vector2i(9, 8), 1)
	var left := NightRun.spawn_enemy("wolf", map, Vector2i(8, 8), 1)
	var right := NightRun.spawn_enemy("wolf", map, Vector2i(10, 8), 1)
	for enemy: Monster in [primary, left, right]:
		_set_hp(enemy, 100)
	var full_damage := NightRun.weapon_damage(greatsword, "wylder")
	var side_damage := maxi(1, roundi(float(full_damage) * 0.75))
	result = PlayerAttackMoveAction.new(Vector2i.UP).apply(map)
	hits = _hits(result)
	popups = _popups(result)
	check(hits.size() == 3, "greatsword sweep emits feedback for all three struck targets")
	var sweep_amounts: Array[int] = []
	for hit: HitEffect in hits:
		sweep_amounts.append(hit.damage)
	sweep_amounts.sort()
	var expected_amounts: Array[int] = [side_damage, side_damage, full_damage]
	expected_amounts.sort()
	check(sweep_amounts == expected_amounts, "greatsword feedback preserves full and side-hit damage")
	check(popups.size() == 3, "greatsword sweep emits three readable damage numbers")

	# Dagger burst should look and read like two distinct impacts.
	map = _sandbox()
	var dagger := _equip("misericorde")
	target = NightRun.spawn_enemy("wolf", map, Vector2i(9, 8), 1)
	_set_hp(target, 100)
	var dagger_hit := maxi(1, roundi(float(NightRun.weapon_damage(dagger, "wylder")) * 0.65))
	result = PlayerAttackMoveAction.new(Vector2i.UP).apply(map)
	hits = _hits(result)
	check(hits.size() == 2, "dagger burst emits two HitEffects")
	check(hits[0].damage == dagger_hit and hits[1].damage == dagger_hit, "dagger feedback carries each scaled hit separately")
	check(_popups(result).size() == 2, "dagger burst emits two damage numbers")

	# Holy melee keeps the same deterministic hit path but gets gold affinity feedback.
	map = _sandbox()
	var sacred := _equip("sacred_blade")
	target = NightRun.spawn_enemy("wolf", map, Vector2i(9, 8), 1)
	_set_hp(target, 100)
	result = PlayerAttackMoveAction.new(Vector2i.UP).apply(map)
	hits = _hits(result)
	check(hits.size() == 1 and hits[0].affinity == &"holy", "Sacred Blade melee emits holy feedback")
	check(hits[0].feedback_color().r > hits[0].feedback_color().b, "holy feedback is warm gold rather than neutral")

	# Staff/seal projectile impacts carry their actual elemental identity and damage.
	map = _sandbox()
	var staff := _equip("glintstone_staff")
	target = NightRun.spawn_enemy("wolf", map, Vector2i(9, 4), 1)
	_set_hp(target, 100)
	var staff_damage := NightRun.weapon_damage(staff, "wylder")
	result = PlayerFireAction.new(Vector2i(9, 4)).apply(map)
	hits = _hits(result)
	popups = _popups(result)
	check(hits.size() == 1 and hits[0].damage == staff_damage, "staff impact carries exact spell damage")
	check(hits[0].affinity == &"magic", "staff impact carries magic affinity")
	check(popups.size() == 1 and popups[0].color == hits[0].feedback_color(), "staff damage number uses glintstone blue")
	check(hits[0].feedback_color().b > hits[0].feedback_color().r, "magic feedback is visibly blue")

	map = _sandbox("revenant")
	var seal := _equip("finger_seal")
	target = NightRun.spawn_enemy("soldier", map, Vector2i(9, 5), 1)
	_set_hp(target, 100)
	var seal_damage := NightRun.weapon_damage(seal, "revenant")
	result = PlayerFireAction.new(Vector2i(9, 5)).apply(map)
	hits = _hits(result)
	check(hits.size() == 1 and hits[0].damage == seal_damage, "seal impact carries exact incantation damage")
	check(hits[0].affinity == &"holy", "seal impact carries holy affinity")
	check(_popups(result).size() == 1 and _popups(result)[0].color == hits[0].feedback_color(), "seal damage number uses holy gold")

	# Enemy deterministic melee also produces an exact physical impact payload.
	map = _sandbox()
	var wolf := NightRun.spawn_enemy("wolf", map, Vector2i(9, 8), 1)
	wolf.set_meta("night_damage", 7)
	World.player.hp = 72
	result = MeleeAction.new(wolf, Vector2i.DOWN).apply(map)
	hits = _hits(result)
	check(hits.size() == 1, "Nightreign enemy melee emits one HitEffect")
	check(hits[0].target == World.player and hits[0].damage == 7, "enemy hit feedback matches applied player damage")
	check(hits[0].affinity == &"physical", "enemy melee defaults to physical feedback")
	check(_popups(result).size() == 1 and _popups(result)[0].text == "7", "enemy melee exposes damage number")

	var report := {
		"checks": checks,
		"failures": failures,
		"profiles": ["physical", "magic", "holy"],
	}
	FileAccess.open("res://docs/M2_HIT_FEEDBACK_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("M2 HIT QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
