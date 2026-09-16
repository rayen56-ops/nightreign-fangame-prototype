extends Node

var checks := 0
var failures: Array[String] = []
const EXPECTED_DIRECTIONS := [
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1)
]

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("T1 %s: %s" % ["PASS" if value else "FAIL", label])

func validate_character(id: String) -> void:
	CharacterCatalog.select_character(id)
	var visual := CharacterCatalog.get_visual()
	check(visual != null, "%s visual loads" % id)
	if visual == null:
		return
	check(visual.frame_size == Vector2i(48, 64), "%s uses native 48x64 frames" % id)
	check(visual.pivot == Vector2i(24, 60), "%s uses fixed-foot pivot 24,60" % id)
	check(not visual.shared_direction, "%s has independent direction rows" % id)
	check(visual.directions == EXPECTED_DIRECTIONS, "%s direction rows are S/SW/W/NW/N/NE/E/SE" % id)
	check(visual.atlas != null, "%s combat atlas loads" % id)
	if visual.atlas:
		check(visual.atlas.get_width() == 240 and visual.atlas.get_height() == 512, "%s atlas is 5x8 frames" % id)
	for name in ["idle", "move", "melee_attack", "hit", "death"]:
		check(visual.animations.has(name), "%s defines %s" % [id, name])
	var attack: Dictionary = visual.animations.get("melee_attack", {})
	check(int(attack.get("column", -1)) == 1 and int(attack.get("frames", 0)) == 4, "%s attack spans windup/swing/release/recover" % id)
	for dir in EXPECTED_DIRECTIONS:
		var row := visual.direction_row(dir)
		check(row >= 0 and row < 8, "%s resolves direction %s to valid row" % [id, dir])

func _ready() -> void:
	validate_character("wylder")
	validate_character("revenant")
	var report := {"stage":"T1-character-visual", "checks":checks, "failures":failures, "engine":Engine.get_version_info().string}
	print("T1 CHARACTER VISUAL QA: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
