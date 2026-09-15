class_name Character
extends Node2D

signal died(character: Character)

var stats: CharacterStats
var health := 1.0
var mana := 0.0
var radius := 20.0

func configure(value: CharacterStats, health_scale := 1.0, damage_scale := 1.0) -> void:
	stats = value.duplicate()
	stats.max_health *= health_scale
	stats.damage *= damage_scale
	health = stats.max_health
	mana = stats.max_mana
	queue_redraw()

func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	queue_redraw()
	if health <= 0.0:
		died.emit(self)

func restore_mana(delta: float) -> void:
	if stats.max_mana > 0.0:
		mana = minf(stats.max_mana, mana + 10.0 * delta)

func _draw() -> void:
	if stats == null: return
	draw_circle(Vector2.ZERO, radius, stats.color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color("20242b"), 2.0)
	draw_rect(Rect2(-radius, -radius - 13, radius * 2.0, 6), Color("2a2d34"))
	draw_rect(Rect2(-radius, -radius - 13, radius * 2.0 * health / stats.max_health, 6), Color("e63946"))
	draw_string(ThemeDB.fallback_font, Vector2(-radius, radius + 17), stats.display_name, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 13, Color.WHITE)
