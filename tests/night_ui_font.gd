extends Node

var checks := 0
var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
	print("M2 WEB FONT QA %s: %s" % ["PASS" if value else "FAIL", label])


func _all_non_ascii_covered(font: Font, text: String) -> bool:
	for i in text.length():
		var codepoint := text.unicode_at(i)
		if codepoint < 128:
			continue
		if not font.has_char(codepoint):
			return false
	return true


func _ready() -> void:
	call_deferred("run")


func run() -> void:
	var bundled := NightUiFont.bundled_cjk_font()
	check(bundled != null, "bundled Traditional Chinese font loads as a Godot Font")
	if bundled == null:
		_finish()
		return

	var composite := NightUiFont.hud_font()
	check(composite != null, "HUD composite font builds")
	check(composite.base_font != null, "HUD keeps the original primary pixel font")
	check(composite.fallbacks.size() == 1, "HUD uses exactly one bundled CJK fallback")
	check(composite.fallbacks[0] == bundled, "HUD fallback points at the bundled CJK font")

	for glyph in ["追", "蹤", "復", "仇", "藝", "絕", "黑", "夜", "雨", "獸", "徒", "手"]:
		check(bundled.has_char(glyph.unicode_at(0)), "bundled font contains %s" % glyph)

	var samples: Array[String] = [
		NightUiText.character_name("wylder"),
		NightUiText.character_name("revenant"),
		NightUiText.weapon_name("greatsword"),
		NightUiText.weapon_name("rapier"),
		NightUiText.weapon_name("finger_seal"),
		NightUiText.skill_name("Claw Shot"),
		NightUiText.skill_name("Summon Spirit"),
		NightUiText.ultimate_name("Immortal March"),
		NightUiText.combat_status("wylder", "大劍", 3, 42, 2),
		NightUiText.combat_tooltip("Summon Spirit", "Immortal March"),
		NightUiText.expedition_progress(12, 8, 0),
		NightUiText.expedition_progress(104, 0, 2),
		NightUiText.boss_search(),
		NightUiText.boss_status(120, 150, false, false),
		NightUiText.boss_status(80, 150, true, false),
		NightUiText.boss_status(50, 150, true, true),
		NightUiText.victory(),
		"徒手",
	]
	for sample in samples:
		check(_all_non_ascii_covered(bundled, sample), "font covers UI sample: %s" % sample)

	check(composite.has_char("A".unicode_at(0)), "composite font still covers ASCII through PixelOperator")
	check(composite.has_char("追".unicode_at(0)), "composite font resolves Traditional Chinese fallback")

	_finish()


func _finish() -> void:
	var report := {
		"checks": checks,
		"failures": failures,
		"font_path": NightUiFont.CJK_FONT_PATH,
		"font_mode": "PixelOperator + bundled zh-TW fallback",
	}
	FileAccess.open("res://docs/M2_WEB_FONT_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("M2 WEB FONT QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
