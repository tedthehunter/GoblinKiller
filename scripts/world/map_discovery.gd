class_name MapDiscovery
extends RefCounted

const CELL_SIZE := 20

var discovered: Dictionary = {}
var visible: Dictionary = {}

func begin_visibility_frame() -> void:
	visible.clear()

func reveal(world_position: Vector2) -> void:
	var cell := to_cell(world_position)
	discovered[cell] = true
	visible[cell] = true

func is_discovered(world_position: Vector2) -> bool:
	return discovered.has(to_cell(world_position))

func is_visible(world_position: Vector2) -> bool:
	return visible.has(to_cell(world_position))

func to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / CELL_SIZE), floori(world_position.y / CELL_SIZE))

func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE + CELL_SIZE * 0.5, cell.y * CELL_SIZE + CELL_SIZE * 0.5)
