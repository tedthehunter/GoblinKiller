class_name Goblin
extends Character

var attack_cooldown := 0.0

func pursue(target: Player, delta: float, level: DungeonLevel) -> bool:
	var distance := position.distance_to(target.position)
	if distance > 48.0:
		var desired := position + position.direction_to(target.position) * 32.0 * delta
		position = level.clamp_actor_position(desired, radius, position)
		return false
	attack_cooldown -= delta
	if attack_cooldown <= 0.0:
		attack_cooldown = 1.0 / stats.attack_speed
		return true
	return false
