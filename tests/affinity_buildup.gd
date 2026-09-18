extends Node

var checks := 0
var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("M3 AFFINITY QA %s: %s" % ["PASS" if value else "FAIL", label])


func _ready() -> void:
	call_deferred("run")


func _sandbox(character_id: String = "wylder", depth: int = 1) -> Map:
	CharacterCatalog.select_character(character_id)
	World.initialize(26092026 + depth)
	var map := NightRun.make_arena(depth, "")
	map.id = "m3_affinity_%s_%d" % [character_id, depth]
	World.current_map = map
	map.get_cell(Vector2i(9, 9)).monster = World.player
	World.player.inventory.clear()
	for slot in Equipment.Slot.values():
		World.player.equipment.unequip(slot)
	NightRun.charge = 0
	NightRun.runes = 0
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
	monster.is_dead = false


func _popups(result: ActionResult) -> Array[StatusPopupEffect]:
	var ret: Array[StatusPopupEffect] = []
	for effect: ActionEffect in result.effects:
		if effect is StatusPopupEffect:
			ret.append(effect as StatusPopupEffect)
	return ret


func _popup_contains(result: ActionResult, needle: String) -> bool:
	for popup: StatusPopupEffect in _popups(result):
		if popup.text.contains(needle):
			return true
	return false


func run() -> void:
	check(NightRun.data.has("status_buildup"), "expedition data exposes status buildup table")
	check(NightRun.status_buildup_config("blood_loss").label == "Blood Loss", "blood-loss config has readable label")
	check(NightRun.status_buildup_config("holy_stagger").label == "Holy Break", "holy stagger config has readable label")

	var uchigatana := NightRun.make_weapon("uchigatana")
	var katana_buildup := NightRun.weapon_buildup(uchigatana)
	check(String(katana_buildup.status) == "blood_loss", "Uchigatana carries Blood Loss buildup")
	check(int(katana_buildup.amount) == 45, "Uchigatana applies 45 buildup per action")
	check(uchigatana.get_info().contains("Buildup: Blood Loss +45/action"), "Uchigatana tooltip exposes buildup")
	check(NightRun.weapon_description(uchigatana).contains("Buildup: Blood Loss +45/action"), "weapon description exposes buildup")

	var seal := NightRun.make_weapon("finger_seal")
	var seal_buildup := NightRun.weapon_buildup(seal)
	check(String(seal_buildup.status) == "holy_stagger", "Finger Seal carries Holy Break buildup")
	check(int(seal_buildup.amount) == 1, "Finger Seal adds one Holy Break point per action")
	check(seal.get_info().contains("Buildup: Holy Break +1/action"), "Finger Seal tooltip exposes Holy Break")

	var sacred := NightRun.make_weapon("sacred_blade")
	check(String(NightRun.weapon_buildup(sacred).status) == "holy_stagger", "Sacred Blade shares Holy Break buildup")
	check(NightRun.weapon_affinity(sacred) == &"holy", "Sacred Blade affinity remains Holy")
	check(NightRun.weapon_affinity(uchigatana) == &"physical", "Uchigatana affinity remains physical")

	var map := _sandbox()
	var wolf := NightRun.spawn_enemy("wolf", map, Vector2i(9, 8), 1)
	_set_hp(wolf, 100)
	check(NightRun.status_buildup_threshold(wolf, "blood_loss") == 80, "wolf has lower Blood Loss threshold")
	check(NightRun.status_buildup_threshold(wolf, "holy_stagger") == 0, "wolf is not accidentally Holy-Break susceptible")
	check(NightRun.status_buildup_value(wolf, "blood_loss") == 0, "new target starts with zero Blood Loss meter")

	_equip("uchigatana")
	var katana_base := NightRun.weapon_damage(World.player.equipment.get_equipped_item(Equipment.Slot.MELEE), "wylder")
	var first := NightRun.resolve_melee(World.player, wolf)
	check(first.damage == katana_base, "first katana hit deals base deterministic damage")
	check(first.affinity == &"physical", "combat result carries physical affinity")
	check(first.special_events.size() == 1, "first katana action emits one buildup event")
	var first_event: Dictionary = first.special_events[0]
	check(String(first_event.status) == "blood_loss", "first event identifies Blood Loss")
	check(int(first_event.meter_before) == 0 and int(first_event.meter_after) == 45, "first event records 0 -> 45 buildup")
	check(int(first_event.threshold) == 80, "first event exposes target-specific threshold")
	check(not bool(first_event.triggered), "first hit does not proc Blood Loss")
	check(int(first_event.proc_damage) == 0, "non-proc event adds no burst damage")
	check(NightRun.status_buildup_value(wolf, "blood_loss") == 45, "target stores accumulated Blood Loss")

	var second := NightRun.resolve_melee(World.player, wolf)
	check(second.special_events.size() == 1, "second katana action emits one buildup event")
	var second_event: Dictionary = second.special_events[0]
	check(bool(second_event.triggered), "second katana action procs Blood Loss at 90/80")
	check(int(second_event.meter_before) == 45, "proc event remembers previous meter")
	check(int(second_event.meter_after) == 0, "Blood Loss meter resets after proc")
	check(int(second_event.proc_damage) == 15, "100 HP target takes deterministic 15% Blood Loss burst")
	check(second.damage == katana_base + 15, "Blood Loss burst is added exactly once to attack damage")
	check(second.killed == (second.damage >= wolf.hp), "proc damage participates in kill prediction")
	check(NightRun.status_buildup_value(wolf, "blood_loss") == 0, "stored meter resets after Blood Loss")

	var third := NightRun.resolve_melee(World.player, wolf)
	check(int(third.special_events[0].meter_after) == 45, "new Blood Loss cycle starts after proc")
	check(third.damage == katana_base, "post-proc cycle returns to base damage before next trigger")

	var skeleton := NightRun.spawn_enemy("skeleton", map, Vector2i(8, 8), 1)
	_set_hp(skeleton, 100)
	check(NightRun.status_buildup_threshold(skeleton, "blood_loss") == 0, "skeleton explicitly reports Blood Loss immunity")
	var immune := NightRun.resolve_melee(World.player, skeleton)
	check(immune.special_events.is_empty(), "immune skeleton creates no fake buildup event")
	check(NightRun.status_buildup_value(skeleton, "blood_loss") == 0, "immune skeleton never stores Blood Loss meter")
	check(immune.damage == katana_base, "immunity does not alter ordinary physical damage")

	var soldier := NightRun.spawn_enemy("soldier", map, Vector2i(10, 8), 1)
	_set_hp(soldier, 100)
	check(NightRun.status_buildup_threshold(soldier, "blood_loss") == 100, "soldier uses standard Blood Loss threshold")
	var soldier_a := NightRun.resolve_melee(World.player, soldier)
	var soldier_b := NightRun.resolve_melee(World.player, soldier)
	var soldier_c := NightRun.resolve_melee(World.player, soldier)
	check(not bool(soldier_a.special_events[0].triggered), "soldier first katana hit does not proc")
	check(not bool(soldier_b.special_events[0].triggered), "soldier second katana hit does not proc at 90/100")
	check(bool(soldier_c.special_events[0].triggered), "soldier third katana hit procs at 135/100")
	check(int(soldier_c.special_events[0].proc_damage) == 15, "soldier Blood Loss burst follows same deterministic rule")

	map = _sandbox("wylder", 20)
	var gladius := NightRun.spawn_enemy("gladius", map, Vector2i(9, 8), 20)
	_set_hp(gladius, 300)
	sacred = _equip("sacred_blade")
	var sacred_base := NightRun.weapon_damage(sacred, "wylder")
	check(NightRun.enemy_affinity_bonus(gladius, &"holy") == 5, "Gladius preserves existing +5 Holy weakness")
	check(NightRun.enemy_affinity_bonus(gladius, &"magic") == 0, "Gladius does not invent a magic weakness")
	check(NightRun.status_buildup_threshold(gladius, "holy_stagger") == 3, "Gladius Holy Break threshold is data-driven")
	check(NightRun.status_buildup_threshold(gladius, "blood_loss") == 120, "Gladius has high Blood Loss threshold")

	var holy1 := NightRun.resolve_melee(World.player, gladius)
	check(holy1.damage == sacred_base + 5, "Holy weakness remains flat +5 deterministic damage")
	check(holy1.affinity == &"holy", "combat result exposes Holy affinity")
	check(holy1.special_events.size() == 1, "first Holy attack emits one buildup event")
	check(int(holy1.special_events[0].meter_after) == 1, "first Holy hit builds 1/3")
	check(not bool(holy1.special_events[0].triggered), "first Holy hit does not stagger")
	check(int(gladius.get_meta("stagger", 0)) == 0, "Gladius stays active before threshold")

	var holy2 := NightRun.resolve_melee(World.player, gladius)
	check(int(holy2.special_events[0].meter_after) == 2, "second Holy hit builds 2/3")
	check(not bool(holy2.special_events[0].triggered), "second Holy hit does not stagger")
	var holy3 := NightRun.resolve_melee(World.player, gladius)
	check(bool(holy3.special_events[0].triggered), "third Holy hit triggers Holy Break")
	check(int(holy3.special_events[0].meter_after) == 0, "Holy Break meter resets on trigger")
	check(int(holy3.special_events[0].proc_damage) == 0, "Holy Break staggers rather than adding hidden burst damage")
	check(int(gladius.get_meta("stagger", 0)) == 1, "Holy Break sets real Gladius stagger state")
	check(holy3.damage == sacred_base + 5, "Holy Break does not double-dip damage")

	var skel_holy := NightRun.spawn_enemy("skeleton", map, Vector2i(8, 8), 20)
	_set_hp(skel_holy, 100)
	var vs_skeleton := NightRun.resolve_melee(World.player, skel_holy)
	check(NightRun.enemy_affinity_bonus(skel_holy, &"holy") == 4, "skeletal enemy has explicit Holy affinity weakness")
	check(vs_skeleton.damage == sacred_base + 4, "Holy affinity bonus applies through generic resolver")
	check(vs_skeleton.special_events.is_empty(), "skeleton Holy weakness does not imply Holy Break susceptibility")

	# Real melee effects expose the buildup meter and trigger to the player.
	map = _sandbox()
	uchigatana = _equip("uchigatana")
	wolf = NightRun.spawn_enemy("wolf", map, Vector2i(9, 8), 1)
	_set_hp(wolf, 200)
	var action1 := PlayerAttackMoveAction.new(Vector2i.UP).apply(map)
	check(action1 != null and action1.success, "katana melee action resolves")
	check(_popup_contains(action1, "Blood Loss 45/80"), "first katana action displays buildup meter")
	var hp_after_first := wolf.hp
	var action2 := PlayerAttackMoveAction.new(Vector2i.UP).apply(map)
	check(action2 != null and action2.success, "second katana melee action resolves")
	check(_popup_contains(action2, "Blood Loss +30"), "Blood Loss trigger displays deterministic burst amount")
	check(wolf.hp < hp_after_first, "triggering action applies real additional damage")

	# Catalyst path uses the same Holy Break event system and feedback.
	map = _sandbox("revenant", 20)
	seal = _equip("finger_seal")
	gladius = NightRun.spawn_enemy("gladius", map, Vector2i(9, 5), 20)
	_set_hp(gladius, 400)
	var cast1 := PlayerFireAction.new(Vector2i(9, 5)).apply(map)
	var cast2 := PlayerFireAction.new(Vector2i(9, 5)).apply(map)
	var cast3 := PlayerFireAction.new(Vector2i(9, 5)).apply(map)
	check(cast1.success and cast2.success and cast3.success, "three seal casts resolve through catalyst path")
	check(_popup_contains(cast1, "Holy Break 1/3"), "first seal cast displays 1/3 Holy Break")
	check(_popup_contains(cast2, "Holy Break 2/3"), "second seal cast displays 2/3 Holy Break")
	check(_popup_contains(cast3, "Holy Break"), "third seal cast displays Holy Break trigger")
	check(int(gladius.get_meta("stagger", 0)) == 1, "seal-triggered Holy Break reaches real boss state")
	check(NightRun.status_buildup_value(gladius, "holy_stagger") == 0, "seal-triggered Holy meter resets")

	var report := {
		"checks": checks,
		"failures": failures,
		"statuses": ["blood_loss", "holy_stagger"],
		"affinities": ["physical", "magic", "holy"],
		"blood_loss_action_scoped": true,
		"holy_stagger_threshold": 3,
	}
	FileAccess.open("res://docs/M3_AFFINITY_BUILDUP_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("M3 AFFINITY QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
