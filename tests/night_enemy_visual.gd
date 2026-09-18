extends Node

const ActorScene := preload("res://scenes/actor/actor.tscn")

var checks := 0
var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("M2 ENEMY VISUAL QA %s: %s" % ["PASS" if value else "FAIL", label])


func _ready() -> void:
	call_deferred("run")


func _sandbox() -> Map:
	CharacterCatalog.select_character("wylder")
	World.initialize(23092026)
	var map := NightRun.make_arena(1, "")
	map.id = "enemy_visual_qa"
	World.current_map = map
	map.get_cell(Vector2i(9, 9)).monster = World.player
	return map


func _spawn_actor(enemy_id: String, pos: Vector2i, elite := false) -> Actor:
	var enemy := NightRun.spawn_enemy(enemy_id, World.current_map, pos, 1, elite)
	var actor := ActorScene.instantiate() as Actor
	actor.monster = enemy
	actor.init(pos)
	add_child(actor)
	return actor


func run() -> void:
	var ids := ["soldier", "wolf", "skeleton"]
	for enemy_id in ids:
		check(NightEnemyVisualProfile.supports(enemy_id), "%s has a dedicated Nightreign silhouette" % enemy_id)
		check(not NightEnemyVisualProfile.get_profile(enemy_id).is_empty(), "%s profile is data-backed" % enemy_id)
		check(NightEnemyVisualProfile.bounds(enemy_id) != Vector2i.ZERO, "%s declares visual bounds" % enemy_id)
		check(NightEnemyVisualProfile.posture(enemy_id) != "", "%s declares posture language" % enemy_id)
		check(NightEnemyVisualProfile.signature(enemy_id) != "", "%s declares a silhouette signature" % enemy_id)

	check(not NightEnemyVisualProfile.supports("gladius"), "Gladius is not disguised as a normal enemy silhouette")
	check(not NightEnemyVisualProfile.supports("gladius_echo"), "Gladius echo stays out of the normal-enemy pass")
	check(NightEnemyVisualProfile.posture("soldier") == "upright", "soldier reads as a tall upright threat")
	check(NightEnemyVisualProfile.posture("wolf") == "low", "wolf reads as a low horizontal threat")
	check(NightEnemyVisualProfile.posture("skeleton") == "spindly", "skeleton reads through thin negative space")
	check(NightEnemyVisualProfile.signature("soldier") == "shield_sword", "soldier identity comes from shield plus sword")
	check(NightEnemyVisualProfile.signature("wolf") == "quadruped", "wolf identity comes from four-legged profile")
	check(NightEnemyVisualProfile.signature("skeleton") == "bones_spear", "skeleton identity comes from bones plus spear")
	check(NightEnemyVisualProfile.signature("soldier") != NightEnemyVisualProfile.signature("wolf"), "soldier and wolf cannot collapse to one silhouette")
	check(NightEnemyVisualProfile.signature("soldier") != NightEnemyVisualProfile.signature("skeleton"), "soldier and skeleton cannot collapse to one silhouette")
	check(NightEnemyVisualProfile.signature("wolf") != NightEnemyVisualProfile.signature("skeleton"), "wolf and skeleton cannot collapse to one silhouette")

	var soldier_bounds := NightEnemyVisualProfile.bounds("soldier")
	var wolf_bounds := NightEnemyVisualProfile.bounds("wolf")
	var skeleton_bounds := NightEnemyVisualProfile.bounds("skeleton")
	check(soldier_bounds.y > soldier_bounds.x, "soldier bounds reinforce vertical posture")
	check(wolf_bounds.x > wolf_bounds.y, "wolf bounds reinforce horizontal posture")
	check(skeleton_bounds.y > skeleton_bounds.x, "skeleton bounds reinforce vertical posture")
	check(wolf_bounds.y < soldier_bounds.y, "wolf sits lower than soldier")
	check(NightEnemyVisualProfile.elite_accent().get_luminance() > 0.5, "elite accent remains bright enough to read on dark floors")

	# Integration contract: a real expedition enemy Actor swaps the borrowed sprite for the silhouette node.
	var map := _sandbox()
	var soldier := _spawn_actor("soldier", Vector2i(7, 7))
	await get_tree().process_frame
	check(soldier.nightreign_visual is NightEnemyVisual, "soldier Actor attaches NightEnemyVisual")
	check(not soldier.character.visible, "soldier borrowed upstream sprite is hidden")
	var soldier_visual := soldier.nightreign_visual as NightEnemyVisual
	check(soldier_visual.enemy_id == "soldier", "soldier visual keeps the Nightreign enemy id")
	check(soldier_visual.current_signature() == "shield_sword", "soldier Actor exposes shield-sword signature")
	var soldier_grid := soldier.grid_pos
	soldier_visual.face(Vector2i.LEFT)
	check(soldier_visual.scale.x < 0.0, "enemy silhouette can face left without a second asset")
	check(soldier.grid_pos == soldier_grid, "visual facing never changes grid occupancy")
	soldier_visual.face(Vector2i.RIGHT)
	check(soldier_visual.scale.x > 0.0, "enemy silhouette can face right")
	soldier_visual.play("hit")
	check(soldier_visual.animation == "hit", "enemy visual responds to hit phase")
	soldier_visual._process(0.21)
	check(soldier_visual.animation == "idle", "hit phase returns to idle presentation")
	soldier.free()

	map.get_cell(Vector2i(7, 7)).monster = null
	var wolf := _spawn_actor("wolf", Vector2i(8, 7))
	await get_tree().process_frame
	check(wolf.nightreign_visual is NightEnemyVisual, "wolf Actor attaches NightEnemyVisual")
	check((wolf.nightreign_visual as NightEnemyVisual).current_signature() == "quadruped", "wolf Actor exposes quadruped signature")
	check(not wolf.character.visible, "wolf borrowed coyote sprite is hidden")
	wolf.free()

	map.get_cell(Vector2i(8, 7)).monster = null
	var skeleton := _spawn_actor("skeleton", Vector2i(10, 7))
	await get_tree().process_frame
	check(skeleton.nightreign_visual is NightEnemyVisual, "skeleton Actor attaches NightEnemyVisual")
	check((skeleton.nightreign_visual as NightEnemyVisual).current_signature() == "bones_spear", "skeleton Actor exposes bone-spear signature")
	check(not skeleton.character.visible, "skeleton borrowed upstream sprite is hidden")
	skeleton.free()

	map.get_cell(Vector2i(10, 7)).monster = null
	var elite := _spawn_actor("soldier", Vector2i(11, 7), true)
	await get_tree().process_frame
	check((elite.nightreign_visual as NightEnemyVisual).elite, "elite metadata reaches silhouette presentation")
	check(elite.monster.get_meta("night_elite", false), "elite presentation mirrors gameplay metadata rather than inventing state")
	elite.free()

	var report := {
		"checks": checks,
		"failures": failures,
		"enemy_ids": ids,
		"signatures": {
			"soldier": NightEnemyVisualProfile.signature("soldier"),
			"wolf": NightEnemyVisualProfile.signature("wolf"),
			"skeleton": NightEnemyVisualProfile.signature("skeleton"),
		},
		"boss_deferred": ["gladius", "gladius_echo"],
	}
	FileAccess.open("res://docs/M2_ENEMY_VISUAL_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("M2 ENEMY VISUAL QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
