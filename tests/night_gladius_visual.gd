extends Node

const ActorScene := preload("res://scenes/actor/actor.tscn")

var checks := 0
var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("M2 GLADIUS VISUAL QA %s: %s" % ["PASS" if value else "FAIL", label])


func _ready() -> void:
	call_deferred("run")


func _sandbox() -> Map:
	CharacterCatalog.select_character("wylder")
	World.initialize(24092026)
	var map := NightRun.make_arena(20, "")
	map.id = "gladius_visual_qa"
	World.current_map = map
	map.get_cell(Vector2i(9, 9)).monster = World.player
	NightRun.telegraphs.clear()
	return map


func _actor_for(monster: Monster, pos: Vector2i) -> Actor:
	var actor := ActorScene.instantiate() as Actor
	actor.monster = monster
	actor.init(pos)
	add_child(actor)
	return actor


func run() -> void:
	var map := _sandbox()
	var pos := Vector2i(9, 5)
	var gladius := NightRun.spawn_enemy("gladius", map, pos, 20)
	var actor := _actor_for(gladius, pos)
	await get_tree().process_frame

	check(actor.nightreign_visual is NightGladiusVisual, "Gladius Actor uses dedicated boss visual")
	check(not actor.character.visible, "borrowed coyote sprite is hidden for Gladius")
	var visual := actor.nightreign_visual as NightGladiusVisual
	check(visual.enemy_id == "gladius", "boss visual keeps Gladius identity")
	check(visual.head_count() == 3, "Gladius reads as a three-headed beast")
	check(visual.current_state() == NightGladiusVisual.STATE_HUNT, "healthy Gladius begins in hunt presentation")
	check(not visual.chain_spread(), "chains remain gathered before split phase")
	var hunt_fire := visual.flame_intensity()
	check(hunt_fire > 0.5 and hunt_fire < 0.8, "hunt phase carries visible but controlled flame")

	var contract := visual.presentation_contract()
	check(contract.grid_occupancy == Vector2i.ONE, "oversized boss art never changes one-cell gameplay occupancy")
	check((contract.visual_bounds as Vector2i).x > Constants.TILE_SIZE, "boss art is allowed to overhang the 16px grid cell")
	check((contract.visual_bounds as Vector2i).y > Constants.TILE_SIZE, "boss silhouette gains vertical presence beyond one tile")

	NightRun.telegraphs[gladius.get_instance_id()] = [Vector2i(9, 6), Vector2i(9, 7)]
	check(visual.current_state() == NightGladiusVisual.STATE_TELEGRAPH, "real flame-sweep telegraph drives boss presentation")
	check(visual.flame_intensity() > hunt_fire, "telegraph visibly intensifies Gladius flame")
	check(not visual.chain_spread(), "telegraph does not fake split-chain state")

	NightRun.telegraphs.erase(gladius.get_instance_id())
	gladius.set_meta("split_done", true)
	check(visual.current_state() == NightGladiusVisual.STATE_SPLIT, "split_done metadata drives split presentation")
	check(visual.chain_spread(), "split phase visibly opens the chains")
	check(visual.flame_intensity() > hunt_fire, "split phase remains visually hotter than hunt")

	gladius.set_meta("stagger", 1)
	check(visual.current_state() == NightGladiusVisual.STATE_STAGGERED, "holy stagger overrides aggressive boss pose")
	check(visual.flame_intensity() < hunt_fire, "stagger visibly suppresses flame")
	check(not visual.chain_spread(), "stagger closes the aggressive chain-spread cue")

	gladius.set_meta("stagger", 0)
	gladius.set_meta("recovery", 1)
	check(visual.current_state() == NightGladiusVisual.STATE_RECOVERY, "post-sweep recovery has a readable visual state")
	check(visual.flame_intensity() < hunt_fire, "recovery communicates an opening by lowering flame")

	gladius.set_meta("recovery", 0)
	var grid_before := actor.grid_pos
	visual.face(Vector2i.LEFT)
	check(visual.scale.x < 0.0, "Gladius visual mirrors left")
	check(actor.grid_pos == grid_before, "boss facing remains presentation-only")
	visual.face(Vector2i.RIGHT)
	check(visual.scale.x > 0.0, "Gladius visual mirrors right")
	visual.play("hit")
	check(visual.animation == "hit", "Gladius participates in shared hit presentation")
	visual._process(0.23)
	check(visual.animation == "idle", "Gladius hit presentation returns to idle")
	actor.free()
	map.get_cell(pos).monster = null

	var echo_pos := Vector2i(12, 5)
	var echo := NightRun.spawn_enemy("gladius_echo", map, echo_pos, 20)
	var echo_actor := _actor_for(echo, echo_pos)
	await get_tree().process_frame
	check(echo_actor.nightreign_visual is NightGladiusVisual, "Gladius echo uses the same boss visual language")
	var echo_visual := echo_actor.nightreign_visual as NightGladiusVisual
	check(echo_visual.current_state() == NightGladiusVisual.STATE_ECHO, "echo has a dedicated presentation state")
	check(echo_visual.head_count() == 1, "split echo reads as one hunting head rather than another full boss")
	check(not echo_visual.chain_spread(), "echo never advertises the main split-chain state")
	check(echo_visual.flame_intensity() < hunt_fire, "echo flame is subordinate to the main body")
	check((echo_visual.presentation_contract().visual_bounds as Vector2i).x < (contract.visual_bounds as Vector2i).x, "echo silhouette is smaller than the main boss")
	check(echo_visual.presentation_contract().grid_occupancy == Vector2i.ONE, "echo also remains one gameplay cell")
	check(not echo_actor.character.visible, "echo borrowed coyote sprite is hidden")
	echo_actor.free()
	map.get_cell(echo_pos).monster = null

	var soldier_pos := Vector2i(6, 5)
	var soldier := NightRun.spawn_enemy("soldier", map, soldier_pos, 20)
	var soldier_actor := _actor_for(soldier, soldier_pos)
	await get_tree().process_frame
	check(soldier_actor.nightreign_visual is NightEnemyVisual, "regular soldier keeps the M2.9 silhouette path")
	check(not (soldier_actor.nightreign_visual is NightGladiusVisual), "boss visual does not leak onto regular enemies")
	soldier_actor.free()

	var report := {
		"checks": checks,
		"failures": failures,
		"boss": "gladius",
		"states": ["hunt", "telegraph", "split", "staggered", "recovery", "echo"],
		"head_count": 3,
		"grid_occupancy": [1, 1],
	}
	FileAccess.open("res://docs/M2_GLADIUS_VISUAL_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("M2 GLADIUS VISUAL QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
