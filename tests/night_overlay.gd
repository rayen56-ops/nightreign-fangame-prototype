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
	check(text.contains("追蹤者"), "Wylder uses official Traditional Chinese identity")
	check(text.contains("大劍"), "starting weapon archetype is localized")
	check(text.contains("技藝 就緒"), "ready character skill uses official term")
	check(text.contains("絕活 0%"), "ultimate charge uses official term")
	check(text.contains("聖杯瓶 3"), "flask count is localized")
	check(not text.contains("Wylder"), "combat bar does not leak English Wylder label")
	check(not text.contains("Skill"), "combat bar does not leak legacy Skill label")
	check(not text.contains("Ult "), "combat bar does not leak legacy Ult label")
	check(not text.contains("Flask"), "combat bar does not leak legacy Flask label")

	NightRun.cooldown = 3
	NightRun.charge = 100
	NightRun.flasks = 1
	text = overlay.combat_status_text()
	check(text.contains("技藝 3回合"), "skill cooldown shows remaining turns in Traditional Chinese")
	check(text.contains("絕活 就緒"), "full ultimate charge switches to localized ready state")
	check(text.contains("聖杯瓶 1"), "flask count updates immediately")

	var rapier := NightRun.make_weapon("rapier")
	World.player.add_item(rapier)
	World.player.equipment.equip(rapier, Equipment.Slot.MELEE)
	text = overlay.combat_status_text()
	check(text.contains("刺劍"), "HUD follows current equipped weapon with official weapon category")
	check(not text.contains("大劍"), "HUD does not retain stale weapon state")
	check(not text.contains("Thrusting Sword"), "localized HUD hides English archetype label")

	CharacterCatalog.select_character("revenant")
	World.initialize(21092027)
	text = overlay.combat_status_text()
	check(text.contains("復仇者"), "Revenant uses official Traditional Chinese identity")
	check(text.contains("聖印記"), "Revenant catalyst category is localized")
	check(text.contains("技藝 就緒"), "Revenant character skill starts ready")
	check(text.contains("絕活 0%"), "Revenant ultimate starts at zero")
	check(not text.contains("Revenant"), "combat bar does not leak English Revenant label")
	check(not text.contains("Sacred Seal"), "combat bar does not leak English catalyst label")

	NightRun.cooldown = 8
	NightRun.charge = 42
	NightRun.flasks = 2
	text = overlay.combat_status_text()
	check(text.contains("技藝 8回合"), "Revenant cooldown is rendered from live state")
	check(text.contains("絕活 42%"), "partial ultimate charge is rendered from live state")
	check(text.contains("聖杯瓶 2"), "Revenant flask state is rendered from live state")

	# Centralized copy contract: official names and weapon categories stay consistent.
	check(NightUiText.character_name("wylder") == "追蹤者", "central copy maps Wylder to 追蹤者")
	check(NightUiText.character_name("revenant") == "復仇者", "central copy maps Revenant to 復仇者")
	check(NightUiText.weapon_name("longsword") == "直劍", "straight sword category is localized")
	check(NightUiText.weapon_name("greatsword") == "大劍", "greatsword category is localized")
	check(NightUiText.weapon_name("uchigatana") == "刀", "katana category is localized")
	check(NightUiText.weapon_name("rapier") == "刺劍", "thrusting sword category is localized")
	check(NightUiText.weapon_name("misericorde") == "短劍", "dagger category is localized")
	check(NightUiText.weapon_name("glintstone_staff") == "手杖", "staff category is localized")
	check(NightUiText.weapon_name("finger_seal") == "聖印記", "sacred seal category is localized")
	check(NightUiText.weapon_name("sacred_blade") == "直劍", "holy straight sword keeps localized archetype")
	check(NightUiText.skill_name("Claw Shot") == "鉤爪射擊", "Wylder skill uses verified official Traditional Chinese name")
	check(NightUiText.skill_name("Summon Spirit") == "召喚靈魂", "Revenant skill uses verified official Traditional Chinese name")
	check(NightUiText.ultimate_name("Immortal March") == "不死行軍", "Revenant ultimate uses verified official Traditional Chinese name")
	check(NightUiText.ultimate_name("Onslaught Stake") == "Onslaught Stake", "unverified proper name deliberately falls back instead of inventing translation")

	var tooltip := NightUiText.combat_tooltip("Summon Spirit", "Immortal March")
	check(tooltip.contains("技藝：召喚靈魂"), "tooltip localizes character skill label and verified name")
	check(tooltip.contains("絕活：不死行軍"), "tooltip localizes ultimate label and verified name")
	check(tooltip.contains("手把："), "tooltip exposes localized controller legend")
	check(tooltip.contains("聖杯瓶"), "controller legend localizes flask action")
	check(not tooltip.contains("Skill:"), "tooltip removes legacy English Skill label")
	check(not tooltip.contains("Ultimate:"), "tooltip removes legacy English Ultimate label")
	check(not tooltip.contains("Pad:"), "tooltip removes legacy English Pad label")

	var progress := NightUiText.expedition_progress(12, 8, 0)
	check(progress.contains("尋找通往下一層的道路"), "expedition objective is localized")
	check(progress.contains("回合 12"), "turn counter is localized")
	check(progress.contains("黑夜雨 8回合後逼近"), "Night's Rain countdown uses official Traditional Chinese term")
	var deep_night := NightUiText.expedition_progress(104, 0, 2)
	check(deep_night.contains("深夜"), "deep-night state is localized")
	check(deep_night.contains("黑夜雨已收縮"), "fully encroached rain state is readable")
	check(NightUiText.boss_search() == "尋找黑夜王「三頭野獸」", "boss objective uses official Black Nightlord target naming")
	check(NightUiText.boss_status(120, 150, false, false).contains("黑夜王"), "boss idle state names Black Nightlord")
	check(NightUiText.boss_status(80, 150, true, false).contains("分裂階段"), "boss split state is localized")
	check(NightUiText.boss_status(50, 150, true, true).contains("離開紅色危險區"), "telegraph warning is localized and actionable")
	check(NightUiText.victory() == "黑夜王 已擊敗", "victory banner is localized")

	overlay.free()
	var report := {
		"checks": checks,
		"failures": failures,
		"locale": "zh-TW",
		"official_terms": ["追蹤者", "復仇者", "技藝", "絕活", "黑夜王", "黑夜雨"],
		"wylder_weapon": "大劍",
		"revenant_weapon": "聖印記",
	}
	FileAccess.open("res://docs/M2_HUD_QA.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("M2 HUD QA COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
