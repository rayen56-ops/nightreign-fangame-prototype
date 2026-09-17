class_name HitEffect
extends ActionEffect

var direction: Vector2
var source: Monster
var took_damage: bool = false
var damage: int = 0
var affinity: StringName = &"physical"


func _init(
	p_target: Monster,
	p_direction: Vector2,
	p_location: Vector2i,
	p_source: Monster,
	p_took_damage: bool = false,
	p_damage: int = 0,
	p_affinity: StringName = &"physical"
) -> void:
	super(p_target, p_location)
	direction = p_direction
	source = p_source
	took_damage = p_took_damage
	damage = maxi(0, p_damage)
	affinity = p_affinity


func _to_string() -> String:
	return (
		"HitEffect(target: %s, direction: %s, source: %s, took_damage: %s, damage: %d, affinity: %s)"
		% [target, direction, source, took_damage, damage, affinity]
	)


func involves_player() -> bool:
	return source == World.player or target == World.player
