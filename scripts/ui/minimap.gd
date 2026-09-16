class_name MiniMap
extends Control

const MAP_ORIGIN := Vector2(32, 94)
const MAP_SIZE := Vector2(210, 88)

var level: DungeonLevel
var discovery: MapDiscovery
var player: Player

func configure(current_level: DungeonLevel, current_discovery: MapDiscovery, current_player: Player) -> void:
	level = current_level
	discovery = current_discovery
	player = current_player
	queue_redraw()

func refresh() -> void:
	queue_redraw()

func map_bounds() -> Rect2:
	if level == null: return Rect2()
	var bounds := Rect2()
	for room in level.rooms:
		bounds = room.rect if bounds.size == Vector2.ZERO else bounds.merge(room.rect)
	return bounds.grow(20.0)

func to_map(world_position: Vector2, bounds: Rect2) -> Vector2:
	return MAP_ORIGIN + (world_position - bounds.position) / bounds.size * MAP_SIZE

func _draw() -> void:
	draw_rect(Rect2(MAP_ORIGIN - Vector2(7, 25), MAP_SIZE + Vector2(14, 32)), Color("10151ddd"), true)
	draw_rect(Rect2(MAP_ORIGIN - Vector2(7, 25), MAP_SIZE + Vector2(14, 32)), Color("697386"), false, 1.0)
	draw_string(ThemeDB.fallback_font, MAP_ORIGIN - Vector2(0, 8), "DISCOVERED MAP", HORIZONTAL_ALIGNMENT_LEFT, MAP_SIZE.x, 13, Color("dbeafe"))
	if level == null or discovery == null: return
	var bounds := map_bounds()
	for cell in level.get_walkable_cells(MapDiscovery.CELL_SIZE):
		var center := discovery.cell_center(cell)
		if not discovery.is_discovered(center): continue
		var scale := MAP_SIZE / bounds.size
		var cell_size := Vector2.ONE * MapDiscovery.CELL_SIZE * scale
		draw_rect(Rect2(to_map(center, bounds) - cell_size * 0.5, cell_size), Color("758da3") if discovery.is_visible(center) else Color("3f5164"), true)
	if player != null:
		draw_circle(to_map(player.position, bounds), 4.0, player.stats.color)
