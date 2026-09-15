class_name AttackDefinition
extends Resource

@export_enum("melee", "projectile", "aoe_projectile") var kind := "melee"
@export var display_name := "Attack"
@export var range := 80.0
@export var mana_cost := 0.0
@export var impact_delay := 0.18
@export var projectile_speed := 600.0
@export var area_radius := 90.0
@export var color := Color.WHITE
