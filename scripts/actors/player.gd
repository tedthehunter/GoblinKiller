class_name Player
extends Character

var move_speed := 240.0
var travel_direction := Vector2.RIGHT

func move_in_level(input_direction: Vector2, delta: float, level: DungeonLevel) -> void:
	if input_direction.length_squared() == 0.0: return
	travel_direction = input_direction.normalized()
	var desired := position + travel_direction * move_speed * delta
	position = level.clamp_actor_position(desired, radius, position)
