extends Node

var checks := 0
var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("WEAPON VISUAL QA %s: %s" % ["PASS" if value else "FAIL", label])


func _ready() -> void:
	call_deferred("run")


func run() -> void:
	var cases := {
		"longsword": "straight_slash",
		"greatsword": "greatsword_sweep",
		"uchigatana": "katana_slash",
		"rapier": "rapier_thrust",
		"misericorde": "dagger_double",
		"glintstone_staff": "glintstone",
		"finger_seal": "incantation",
		"sacred_blade": "straight_slash"
	}
	var seen_profiles: Dictionary = {}
	for weapon_id: String in cases:
		var expected := String(cases[weapon_id])
		var archetype := NightRun.weapon_archetype(weapon_id)
		check(String(archetype.get("visual_profile", "")) == expected, "data profile " + weapon_id)
		var weapon := NightRun.make_weapon(weapon_id)
		check(VisualEffects.weapon_visual_profile(weapon) == StringName(expected), "runtime profile " + weapon_id)
		var clone := ItemFactory.clone(weapon)
		check(VisualEffects.weapon_visual_profile(clone) == StringName(expected), "clone profile " + weapon_id)
		seen_profiles[expected] = true

	check(seen_profiles.size() == 7, "seven distinct archetype visual profiles")
	check(VisualEffects.weapon_visual_profile(null) == &"", "null item has no visual profile")

	var report := {
		"checks": checks,
		"failures": failures,
		"weapon_count": cases.size(),
		"visual_profiles": seen_profiles.keys()
	}
	FileAccess.open("res://docs/WEAPON_VISUAL_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("WEAPON VISUAL QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
