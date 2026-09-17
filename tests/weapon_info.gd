extends Node

var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("WEAPON INFO QA %s: %s" % ["PASS" if value else "FAIL", label])

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	CharacterCatalog.select_character("wylder")
	var ids := [
		"longsword",
		"greatsword",
		"uchigatana",
		"rapier",
		"misericorde",
		"glintstone_staff",
		"finger_seal",
		"sacred_blade",
	]

	for weapon_id: String in ids:
		var weapon := NightRun.make_weapon(weapon_id)
		var info := weapon.get_info()
		check(info.contains("Archetype:"), "tooltip exposes archetype " + weapon_id)
		check(info.contains("Attack:"), "tooltip exposes attack shape " + weapon_id)
		check(info.contains("Scaling:"), "tooltip exposes scaling " + weapon_id)
		check(info.contains("Current damage:"), "tooltip exposes deterministic damage " + weapon_id)
		check(not info.contains("Base damage:"), "tooltip hides legacy dice damage " + weapon_id)
		check(not info.contains("Mass:"), "tooltip hides irrelevant mass " + weapon_id)
		check(not info.contains("Damage Bonus:"), "tooltip hides legacy damage bonus " + weapon_id)

	var greatsword_info := NightRun.make_weapon("greatsword").get_info()
	check(greatsword_info.contains("Sweep"), "greatsword names sweep pattern")
	check(greatsword_info.contains("75% side damage"), "greatsword explains side-hit multiplier")

	var rapier_info := NightRun.make_weapon("rapier").get_info()
	check(rapier_info.contains("Thrust"), "rapier names thrust pattern")
	check(rapier_info.contains("2-tile reach"), "rapier explains two-tile reach")

	var dagger_info := NightRun.make_weapon("misericorde").get_info()
	check(dagger_info.contains("Burst"), "dagger names burst pattern")
	check(dagger_info.contains("2 hits at 65% each"), "dagger explains burst hit model")

	var staff_info := NightRun.make_weapon("glintstone_staff").get_info()
	check(staff_info.contains("Attack: Ranged cast"), "staff identifies ranged cast")
	check(staff_info.contains("Spell: Glintstone Bolt"), "staff exposes spell name")
	check(staff_info.contains("Range: 6 tiles"), "staff exposes cast range")
	check(staff_info.contains("Affinity: Magic"), "staff exposes magic affinity")

	CharacterCatalog.select_character("revenant")
	var seal := NightRun.make_weapon("finger_seal")
	var seal_info := seal.get_info()
	check(seal_info.contains("Spell: Sacred Spark"), "seal exposes incantation name")
	check(seal_info.contains("Range: 4 tiles"), "seal exposes cast range")
	check(seal_info.contains("Affinity: Holy"), "seal exposes holy affinity")
	check(seal_info.contains("Current damage: %d" % NightRun.weapon_damage(seal, "revenant")), "tooltip damage follows selected character scaling")

	var report := {
		"checks": checks,
		"failures": failures,
		"weapon_count": ids.size(),
	}
	FileAccess.open("res://docs/WEAPON_INFO_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("WEAPON INFO QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
