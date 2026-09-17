extends Node

var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("M2 PREVIEW QA %s: %s" % ["PASS" if value else "FAIL", label])

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	World.initialize(23092026)
	var turn_before := World.current_turn
	var source := Vector2i(5, 5)

	var straight := NightRun.weapon_archetype("longsword")
	var preview := NightAttackPreview.build(straight, source, Vector2i(6, 5))
	check(preview.pattern == "single", "straight sword preview identifies single pattern")
	check(preview.cells == [Vector2i(6, 5)], "straight sword previews one adjacent cell")
	check(preview.target_in_range, "straight sword adjacent target is in range")
	check(not NightAttackPreview.build(straight, source, Vector2i(7, 5)).target_in_range, "straight sword two-tile target is out of range")

	var greatsword := NightRun.weapon_archetype("greatsword")
	preview = NightAttackPreview.build(greatsword, source, Vector2i(6, 5))
	check(preview.pattern == "sweep", "greatsword preview identifies sweep pattern")
	check(preview.cells.size() == 3, "greatsword sweep previews three cells")
	check(preview.cells == [Vector2i(6, 5), Vector2i(6, 4), Vector2i(6, 6)], "east greatsword footprint matches combat sweep")
	check(preview.target_in_range, "greatsword adjacent target is in range")
	check(not NightAttackPreview.build(greatsword, source, Vector2i(7, 5)).target_in_range, "greatsword does not claim a two-tile target")
	preview = NightAttackPreview.build(greatsword, source, Vector2i(6, 4))
	check(preview.cells == [Vector2i(6, 4), Vector2i(6, 5), Vector2i(5, 4)], "diagonal greatsword footprint matches melee sweep directions")
	check(not preview.cells.has(source), "greatsword preview never highlights the player tile")

	var rapier := NightRun.weapon_archetype("rapier")
	preview = NightAttackPreview.build(rapier, source, Vector2i(7, 5))
	check(preview.cells.size() == 2, "rapier preview exposes two-cell reach")
	check(preview.cells == [Vector2i(6, 5), Vector2i(7, 5)], "rapier preview is a straight two-cell thrust")
	check(preview.target_in_range, "rapier two-tile target is in range")
	check(not NightAttackPreview.build(rapier, source, Vector2i(8, 5)).target_in_range, "rapier three-tile target is out of range")
	check(not NightAttackPreview.build(rapier, source, Vector2i(7, 6)).target_in_range, "rapier off-axis target is not falsely advertised")

	var dagger := NightRun.weapon_archetype("misericorde")
	preview = NightAttackPreview.build(dagger, source, Vector2i(5, 4))
	check(preview.cells == [Vector2i(5, 4)], "dagger burst keeps a one-cell footprint")
	check(preview.pattern == "burst", "dagger preview preserves burst identity")
	check(preview.target_in_range, "dagger adjacent target is in range")

	var staff := NightRun.weapon_archetype("glintstone_staff")
	preview = NightAttackPreview.build(staff, source, Vector2i(13, 5), &"physical")
	check(preview.pattern == "cast", "staff preview identifies cast targeting")
	check(preview.range == 6, "staff preview reads six-tile cast range from data")
	check(preview.cells.size() == 6, "staff preview clips trajectory to cast range")
	check(preview.cells[-1] == Vector2i(11, 5), "staff preview stops at six tiles")
	check(not preview.target_in_range, "staff marks an eight-tile cursor as out of range")
	check(NightAttackPreview.build(staff, source, Vector2i(10, 5)).target_in_range, "staff accepts target inside six-tile range")
	check(preview.affinity == &"magic", "staff cast overrides fallback with magic affinity")

	var seal := NightRun.weapon_archetype("finger_seal")
	preview = NightAttackPreview.build(seal, source, Vector2i(9, 5), &"physical")
	check(preview.range == 4, "seal preview reads four-tile cast range from data")
	check(preview.cells.size() == 4, "seal preview shows its full four-tile trajectory")
	check(preview.affinity == &"holy", "seal preview carries holy affinity")
	check(preview.target_in_range, "seal target at four tiles is in range")

	var magic_color := NightAttackPreview.preview_color(&"magic")
	var holy_color := NightAttackPreview.preview_color(&"holy")
	var physical_color := NightAttackPreview.preview_color(&"physical")
	check(magic_color.b > magic_color.r, "magic preview is visibly blue")
	check(holy_color.r > holy_color.b, "holy preview is visibly warm gold")
	check(absf(physical_color.r - physical_color.b) < 0.2, "physical preview stays neutral")
	check(not bool(preview.consumes_turn), "preview contract explicitly consumes no turn")
	check(World.current_turn == turn_before, "building previews does not advance World turn")

	var report := {
		"checks": checks,
		"failures": failures,
		"patterns": ["single", "sweep", "thrust", "burst", "cast"],
		"turn_safe": World.current_turn == turn_before,
	}
	FileAccess.open("res://docs/M2_ATTACK_PREVIEW_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("M2 PREVIEW QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
