extends Node

const NightOverlayScript := preload("res://src/nightreign/expedition/night_overlay.gd")

var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("M2 HUD QA %s: %s" % ["PASS" if value else "FAIL", label])

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var overlay := NightOverlayScript.new()

	CharacterCatalog.select_character("wylder")
	World.initialize(21092026)
	var text := overlay.combat_status_text()
	check(text.contains("Wylder"), "Wylder identity is always visible")
	check(text.contains("Greatsword"), "starting weapon archetype is visible")
	check(text.contains("Skill READY"), "ready skill state is visible")
	check(text.contains("Ult 0%"), "ultimate charge starts visible at zero")
	check(text.contains("Flask 3"), "flask count is visible")

	NightRun.cooldown = 3
	NightRun.charge = 100
	NightRun.flasks = 1
	text = overlay.combat_status_text()
	check(text.contains("Skill 3t"), "skill cooldown shows remaining turns")
	check(text.contains("Ult READY"), "full ultimate charge switches to ready state")
	check(text.contains("Flask 1"), "flask count updates immediately")

	var rapier := NightRun.make_weapon("rapier")
	World.player.add_item(rapier)
	World.player.equipment.equip(rapier, Equipment.Slot.MELEE)
	text = overlay.combat_status_text()
	check(text.contains("Thrusting Sword"), "HUD follows current equipped weapon")
	check(not text.contains("Greatsword"), "HUD does not retain stale weapon state")

	CharacterCatalog.select_character("revenant")
	World.initialize(21092027)
	text = overlay.combat_status_text()
	check(text.contains("Revenant"), "Revenant identity is visible after reselect")
	check(text.contains("Sacred Seal"), "Revenant catalyst archetype is visible")
	check(text.contains("Skill READY"), "Revenant skill starts ready")
	check(text.contains("Ult 0%"), "Revenant ultimate starts at zero")

	NightRun.cooldown = 8
	NightRun.charge = 42
	NightRun.flasks = 2
	text = overlay.combat_status_text()
	check(text.contains("Skill 8t"), "Revenant cooldown is rendered from live state")
	check(text.contains("Ult 42%"), "partial ultimate charge is rendered from live state")
	check(text.contains("Flask 2"), "Revenant flask state is rendered from live state")

	overlay.free()
	var report := {
		"checks": checks,
		"failures": failures,
		"wylder_weapon": "Greatsword",
		"revenant_weapon": "Sacred Seal",
	}
	FileAccess.open("res://docs/M2_HUD_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("M2 HUD QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
