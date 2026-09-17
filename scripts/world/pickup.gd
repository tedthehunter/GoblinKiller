class_name WorldPickup
extends Node2D

var definition: PickupDefinition

func configure(value: PickupDefinition) -> void:
	definition = value
	queue_redraw()

func _draw() -> void:
	if definition == null: return
	draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(12, 0), Vector2(0, 12), Vector2(-12, 0)]), definition.color)
	draw_string(ThemeDB.fallback_font, Vector2(-42, 28), definition.display_name, HORIZONTAL_ALIGNMENT_CENTER, 84, 12, Color.WHITE)
