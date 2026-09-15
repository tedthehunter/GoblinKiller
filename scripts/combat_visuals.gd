class_name CombatVisuals
extends Node2D

# Presentation-only layer. Game logic owns hit resolution; this node only draws it above the world.
var effects: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var attack: AttackDefinition

func refresh(current_attack: AttackDefinition) -> void:
	attack = current_attack
	queue_redraw()

func _draw() -> void:
	if attack == null: return
	for effect in effects:
		if effect.kind == "blast":
			draw_arc(effect.position, attack.area_radius * (1.0 - effect.remaining / 0.35), 0.0, TAU, 24, attack.color, 4.0)
		else:
			var radius := 42.0 if effect.kind == "slash" else 29.0
			var color := attack.color if effect.kind == "slash" else Color("ff8c69")
			draw_arc(effect.position, radius, effect.angle - 0.9, effect.angle + 0.9, 16, color, 4.0)
	for shot in projectiles:
		draw_circle(shot.position, 10.0 if attack.kind == "aoe_projectile" else 6.0, attack.color)
