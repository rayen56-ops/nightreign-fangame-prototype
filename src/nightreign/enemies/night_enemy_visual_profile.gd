class_name NightEnemyVisualProfile
extends RefCounted

const PROFILES := {
	"soldier": {
		"posture": "upright",
		"signature": "shield_sword",
		"bounds": Vector2i(13, 16),
		"body": Color(0.22, 0.25, 0.31, 1.0),
		"accent": Color(0.53, 0.34, 0.24, 1.0),
		"metal": Color(0.55, 0.59, 0.63, 1.0),
	},
	"wolf": {
		"posture": "low",
		"signature": "quadruped",
		"bounds": Vector2i(16, 10),
		"body": Color(0.24, 0.27, 0.31, 1.0),
		"accent": Color(0.62, 0.18, 0.15, 1.0),
		"metal": Color(0.38, 0.41, 0.45, 1.0),
	},
	"skeleton": {
		"posture": "spindly",
		"signature": "bones_spear",
		"bounds": Vector2i(12, 16),
		"body": Color(0.70, 0.69, 0.61, 1.0),
		"accent": Color(0.36, 0.43, 0.48, 1.0),
		"metal": Color(0.48, 0.53, 0.57, 1.0),
	},
}


static func supports(enemy_id: String) -> bool:
	return PROFILES.has(enemy_id)


static func get_profile(enemy_id: String) -> Dictionary:
	return PROFILES.get(enemy_id, {}).duplicate(true)


static func posture(enemy_id: String) -> String:
	return String(PROFILES.get(enemy_id, {}).get("posture", ""))


static func signature(enemy_id: String) -> String:
	return String(PROFILES.get(enemy_id, {}).get("signature", ""))


static func bounds(enemy_id: String) -> Vector2i:
	return PROFILES.get(enemy_id, {}).get("bounds", Vector2i.ZERO)


static func elite_accent() -> Color:
	return Color(0.93, 0.72, 0.25, 1.0)
