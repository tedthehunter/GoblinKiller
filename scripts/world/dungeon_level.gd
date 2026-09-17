class_name DungeonLevel
extends Node2D

signal room_entered(room_id: String)
signal exit_reached

var floor_number := 1
var rooms: Array[Dictionary] = []
var corridors: Array[Rect2] = []
var entered_rooms := {}
var exit_rect := Rect2()
var player: Player
var location_encounters: Array[Dictionary] = []

func setup(number: int) -> void:
	floor_number = number
	if number == 1:
		rooms = [
			{"id": "entry", "rect": Rect2(50, 170, 310, 250), "spawns": 0},
			{"id": "guard", "rect": Rect2(510, 100, 310, 260), "spawns": 4},
			{"id": "stairs", "rect": Rect2(960, 170, 300, 250), "spawns": 6}
		]
		corridors = [Rect2(290, 245, 270, 100), Rect2(770, 245, 250, 100)]
		exit_rect = Rect2(1165, 245, 56, 100)
		location_encounters = [{"id":"shrine", "position":Vector2(650, 190), "resource":"res://data/encounters/ancient_shrine.tres"}]
	else:
		rooms = [
			{"id": "entry", "rect": Rect2(50, 150, 310, 260), "spawns": 3},
			{"id": "vault", "rect": Rect2(510, 80, 330, 300), "spawns": 6},
			{"id": "victory", "rect": Rect2(990, 150, 300, 260), "spawns": 8}
		]
		corridors = [Rect2(290, 240, 270, 90), Rect2(760, 240, 280, 90)]
		exit_rect = Rect2(1095, 225, 80, 100)
		location_encounters = [{"id":"echo", "position":Vector2(660, 155), "resource":"res://data/encounters/arcane_echo.tres"}]
	queue_redraw()

func set_player(value: Player) -> void:
	player = value

func clamp_actor_position(desired: Vector2, radius: float, current_position: Vector2) -> Vector2:
	if is_walkable(desired, radius): return desired
	var horizontal := Vector2(desired.x, current_position.y)
	var vertical := Vector2(current_position.x, desired.y)
	if is_walkable(horizontal, radius): return horizontal
	if is_walkable(vertical, radius): return vertical
	return current_position

func is_walkable(point: Vector2, radius: float) -> bool:
	for room in rooms:
		if room.rect.grow(-radius).has_point(point): return true
	for corridor in corridors:
		if corridor.grow(-radius).has_point(point): return true
	return false

func get_walkable_cells(cell_size: int) -> Array[Vector2i]:
	var cells: Dictionary = {}
	for area in get_walkable_areas():
		# Cell coordinates must be based on the same global origin used by MapDiscovery.
		# Starting at area.position shifted fog tiles whenever a room began off-grid.
		var first_x := floori(area.position.x / cell_size)
		var last_x := ceili(area.end.x / cell_size)
		var first_y := floori(area.position.y / cell_size)
		var last_y := ceili(area.end.y / cell_size)
		for x in range(first_x, last_x):
			for y in range(first_y, last_y):
				var cell := Vector2i(x, y)
				# Include every cell that touches a floor shape. Testing only a cell center
				# leaves narrow room-edge and corner strips permanently outside the fog.
				if area.intersects(get_cell_rect(cell, cell_size)): cells[cell] = true
	var result: Array[Vector2i] = []
	for cell in cells: result.append(cell)
	return result

func get_cell_rect(cell: Vector2i, cell_size: int) -> Rect2:
	return Rect2(Vector2(cell.x * cell_size, cell.y * cell_size), Vector2.ONE * cell_size)

func get_walkable_cell_sample(cell: Vector2i, cell_size: int) -> Vector2:
	var cell_rect := get_cell_rect(cell, cell_size)
	for area in get_walkable_areas():
		var overlap := area.intersection(cell_rect)
		if overlap.size.x > 0.0 and overlap.size.y > 0.0:
			return overlap.get_center()
	return cell_rect.get_center()

func get_walkable_areas() -> Array[Rect2]:
	var areas: Array[Rect2] = []
	for room in rooms: areas.append(room.rect)
	for corridor in corridors: areas.append(corridor)
	return areas

func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var distance := from.distance_to(to)
	var steps := maxi(1, ceili(distance / 8.0))
	for step in range(1, steps + 1):
		if not is_walkable(from.lerp(to, float(step) / steps), 1.0): return false
	return true

func update_player_location() -> void:
	if player == null: return
	for room in rooms:
		if room.rect.has_point(player.position) and not entered_rooms.has(room.id):
			entered_rooms[room.id] = true
			room_entered.emit(room.id)
	if exit_rect.has_point(player.position):
		exit_reached.emit()

func room_for_id(room_id: String) -> Dictionary:
	for room in rooms:
		if room.id == room_id: return room
	return {}

func _draw() -> void:
	for room in rooms:
		draw_rect(room.rect, Color("17202a"), true)
		draw_rect(room.rect, Color("60758a"), false, 6.0)
	for corridor in corridors:
		draw_rect(corridor, Color("17202a"), true)
		draw_rect(corridor, Color("60758a"), false, 6.0)
	draw_shared_doorways()
	for room in rooms:
		for x in range(int(room.rect.position.x), int(room.rect.end.x), 40):
			draw_line(Vector2(x, room.rect.position.y), Vector2(x, room.rect.end.y), Color("22313f"))
		for y in range(int(room.rect.position.y), int(room.rect.end.y), 40):
			draw_line(Vector2(room.rect.position.x, y), Vector2(room.rect.end.x, y), Color("22313f"))
	var label := "STAIRS TO FLOOR 2" if floor_number == 1 else "VICTORY ALTAR"
	var color := Color("f6bd60") if floor_number == 1 else Color("ffd166")
	draw_rect(exit_rect, color, true)
	draw_string(ThemeDB.fallback_font, exit_rect.position + Vector2(-35, -10), label, HORIZONTAL_ALIGNMENT_CENTER, exit_rect.size.x + 70, 14, color)

func draw_shared_doorways() -> void:
	# Corridors deliberately overlap rooms by more than an actor radius. Remove the two
	# rectangle borders in each overlap so the shared area looks and behaves like a doorway.
	for corridor in corridors:
		for room in rooms:
			var doorway := corridor.intersection(room.rect)
			if doorway.size.x <= 0.0 or doorway.size.y <= 0.0: continue
			draw_rect(doorway.grow(4.0), Color("17202a"), true)
			draw_line(Vector2(doorway.position.x, corridor.position.y), Vector2(doorway.end.x, corridor.position.y), Color("60758a"), 6.0)
			draw_line(Vector2(doorway.position.x, corridor.end.y), Vector2(doorway.end.x, corridor.end.y), Color("60758a"), 6.0)
