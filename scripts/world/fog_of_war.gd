class_name FogOfWar
extends Node2D

const VISIBILITY_RADIUS := 170.0

var level: DungeonLevel
var discovery: MapDiscovery

func configure(current_level: DungeonLevel, current_discovery: MapDiscovery) -> void:
	level = current_level
	discovery = current_discovery
	queue_redraw()

func update_visibility(player_position: Vector2) -> void:
	if level == null or discovery == null: return
	discovery.begin_visibility_frame()
	for cell in level.get_walkable_cells(MapDiscovery.CELL_SIZE):
		var sample := level.get_walkable_cell_sample(cell, MapDiscovery.CELL_SIZE)
		if player_position.distance_to(sample) <= VISIBILITY_RADIUS and level.has_line_of_sight(player_position, sample):
			discovery.reveal(sample)
	queue_redraw()

func _draw() -> void:
	if level == null or discovery == null: return
	for cell in level.get_walkable_cells(MapDiscovery.CELL_SIZE):
		var center := discovery.cell_center(cell)
		if discovery.is_visible(center): continue
		var alpha := 0.72 if discovery.is_discovered(center) else 1.0
		draw_rect(Rect2(center - Vector2.ONE * MapDiscovery.CELL_SIZE * 0.5, Vector2.ONE * MapDiscovery.CELL_SIZE), Color(0.02, 0.03, 0.06, alpha), true)
