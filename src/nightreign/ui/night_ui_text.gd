class_name NightUiText
extends RefCounted

## Nightreign combat-facing Traditional Chinese copy. Keep official game terms here
## instead of scattering display strings across gameplay scripts.

const CHARACTER_NAMES := {
	"wylder": "追蹤者",
	"revenant": "復仇者",
}

const WEAPON_ARCHETYPE_NAMES := {
	"longsword": "直劍",
	"greatsword": "大劍",
	"uchigatana": "刀",
	"rapier": "刺劍",
	"misericorde": "短劍",
	"glintstone_staff": "手杖",
	"finger_seal": "聖印記",
	"sacred_blade": "直劍",
}

const SKILL_NAMES := {
	"Claw Shot": "鉤爪射擊",
	"Summon Spirit": "召喚靈魂",
}

const ULTIMATE_NAMES := {
	# Keep Onslaught Stake in source-language until a verified official TC name is available.
	"Immortal March": "不死行軍",
}


static func character_name(id: String, fallback := "") -> String:
	return String(CHARACTER_NAMES.get(id, fallback))


static func weapon_name(id: String, fallback := "") -> String:
	return String(WEAPON_ARCHETYPE_NAMES.get(id, fallback))


static func skill_name(source_name: String) -> String:
	return String(SKILL_NAMES.get(source_name, source_name))


static func ultimate_name(source_name: String) -> String:
	return String(ULTIMATE_NAMES.get(source_name, source_name))


static func ready_or_turns(remaining_turns: int) -> String:
	return "就緒" if remaining_turns <= 0 else "%d回合" % remaining_turns


static func ultimate_state(charge: int) -> String:
	return "就緒" if charge >= 100 else "%d%%" % charge


static func combat_status(character_id: String, weapon_label: String, cooldown: int, charge: int, flasks: int) -> String:
	return "%s | %s | 技藝 %s | 絕活 %s | 聖杯瓶 %d" % [
		character_name(character_id, character_id),
		weapon_label,
		ready_or_turns(cooldown),
		ultimate_state(charge),
		flasks,
	]


static func combat_tooltip(skill: String, ultimate: String) -> String:
	return "技藝：%s\n絕活：%s\n手把：左搖桿/十字鍵 移動 | X/□ 技藝 | Y/△ 絕活 | LB/L1 聖杯瓶 | RB/R1 施放 | L3 等待" % [
		skill_name(skill),
		ultimate_name(ultimate),
	]


static func expedition_progress(turns: int, remaining_tide_turns: int, night_stage: int) -> String:
	var tide_text := "黑夜雨 %d回合後逼近" % remaining_tide_turns if night_stage < 2 else "深夜 | 黑夜雨已收縮"
	return "尋找通往下一層的道路 | 回合 %d | %s" % [turns, tide_text]


static func boss_search() -> String:
	return "尋找黑夜王「三頭野獸」"


static func boss_status(hp: int, max_hp: int, split_done: bool, telegraph_active: bool) -> String:
	var state := "離開紅色危險區" if telegraph_active else ("分裂階段" if split_done else "黑夜王")
	return "三頭野獸  %d / %d  |  %s" % [hp, max_hp, state]


static func victory() -> String:
	return "黑夜王 已擊敗"
