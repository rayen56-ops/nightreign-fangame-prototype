extends Node

var failures: Array[String] = []
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("T1 ART %s: %s" % ["PASS" if value else "FAIL", label])

func _ready() -> void:
	call_deferred("run")

func validate_character(id: String) -> void:
	CharacterCatalog.select_character(id)
	var visual := CharacterCatalog.get_visual()
	check(visual != null, "%s visual resource loads" % id)
	if visual == null:
		return
	check(visual.atlas != null, "%s atlas loads" % id)
	check(visual.frame_size == Vector2i(64, 64), "%s uses 64x64 logical combat frames" % id)
	check(visual.pivot == Vector2i(24, 60), "%s uses grounded 24,60 pivot" % id)
	check(visual.directions.size() == 8, "%s declares eight directions" % id)
	check(visual.animations.has("idle"), "%s has idle pose" % id)
	check(visual.animations.has("melee_attack"), "%s has melee attack pose" % id)
	if visual.atlas:
		check(visual.atlas.get_width() == 64, "%s normalized atlas is 64 px wide" % id)
		check(visual.atlas.get_height() == 1024, "%s normalized atlas is 16 rows tall" % id)
	for direction: Vector2i in visual.directions:
		var idle := visual.region_for("idle", direction, 0.0)
		var attack := visual.region_for("melee_attack", direction, 0.0)
		check(idle.size == Vector2(64, 64), "%s idle region valid for %s" % [id, direction])
		check(attack.size == Vector2(64, 64), "%s attack region valid for %s" % [id, direction])
		check(int(attack.position.y) == int(idle.position.y) + 8 * 64, "%s attack block follows idle block for %s" % [id, direction])

func run() -> void:
	validate_character("wylder")
	validate_character("revenant")
	CharacterCatalog.select_character("wylder")
	var report := {"stage": "T1-character-art", "checks": checks, "failures": failures}
	FileAccess.open("res://docs/T1_CHARACTER_ART_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("T1 CHARACTER ART QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
