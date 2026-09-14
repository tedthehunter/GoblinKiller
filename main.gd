extends Node2D

const GRID_SIZE := 80
const WORLD_SEED := 48271
const CAMERA_LIMIT := 2000000000
const ACTIVE_ENEMY_TARGET := 20
const ENEMY_DESPAWN_DISTANCE := 1500.0
const ENEMY_SPAWN_OFFSET := 56.0
const BASE_GOBLIN_SPAWN_RATE := 0.45
const GOBLIN_SPAWN_RATE_RAMP := 0.035
const MAX_GOBLIN_SPAWN_MULTIPLIER := 10.0
const PLAYER_MOVE_SPEED := 240.0
const ATTACK_INPUT_BUFFER := 0.16
const CLASS_DATA := {
	"Warrior": {"health": 140.0, "mana": 0.0, "damage": 28.0, "attack_speed": 1.1, "color": Color("4f8ee8")},
	"Mage": {"health": 80.0, "mana": 100.0, "damage": 40.0, "attack_speed": 0.75, "color": Color("9b5de5")},
	"Thief": {"health": 95.0, "mana": 0.0, "damage": 19.0, "attack_speed": 2.0, "color": Color("f4a261")}
}
const ATTACKS := {
	"Warrior": {"name": "Cleave", "kind": "melee", "range": 78.0, "mana_cost": 0.0, "impact_delay": 0.18, "color": Color("b9dcff")},
	"Thief": {"name": "Throwing dagger", "kind": "projectile", "range": 420.0, "mana_cost": 0.0, "projectile_speed": 620.0, "color": Color("f6bd60")},
	"Mage": {"name": "Fireball", "kind": "aoe_projectile", "range": 360.0, "mana_cost": 15.0, "projectile_speed": 420.0, "area_radius": 90.0, "color": Color("ff6b35")}
}

var player: Entity
var goblins: Array[Entity] = []
var world_camera: Camera2D
var spawn_rng := RandomNumberGenerator.new()
var travel_direction := Vector2.ZERO
var selected_class := ""
var last_attack_time := -10.0
var buffered_attack_position := Vector2.ZERO
var has_buffered_attack := false
var pending_hits: Array[Dictionary] = []
var pending_enemy_hits: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var visual_effects: Array[Dictionary] = []
var title: Label
var status: Label
var hp_bar: ProgressBar
var mp_bar: ProgressBar
var class_box: VBoxContainer
var pause_menu: PanelContainer
var game_paused := false
var elapsed_game_time := 0.0
var goblin_spawn_progress := 0.0

class Entity:
	extends Node2D
	var entity_name := ""
	var health := 1.0
	var max_health := 1.0
	var mana := 0.0
	var max_mana := 0.0
	var mana_regen := 0.0
	var damage := 1.0
	var attack_speed := 1.0
	var tint := Color.WHITE
	var radius := 22.0
	var attack_timer := 0.0

	func configure(label: String, values: Dictionary, color: Color) -> void:
		entity_name = label
		max_health = values.health
		health = max_health
		max_mana = values.get("mana", 0.0)
		mana = max_mana
		mana_regen = 10.0 if max_mana > 0.0 else 0.0
		damage = values.damage
		attack_speed = values.attack_speed
		tint = color
		queue_redraw()

	func hit(amount: float) -> void:
		health = max(0.0, health - amount)
		queue_redraw()

	func restore_mana(delta: float) -> void:
		if max_mana > 0.0:
			mana = min(max_mana, mana + mana_regen * delta)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, tint)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color("20242b"), 2.0)
		draw_rect(Rect2(-radius, -radius - 13, radius * 2, 6), Color("2a2d34"))
		draw_rect(Rect2(-radius, -radius - 13, radius * 2 * health / max_health, 6), Color("e63946"))
		draw_string(ThemeDB.fallback_font, Vector2(-radius, radius + 18), entity_name, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, 13, Color.WHITE)

func _ready() -> void:
	spawn_rng.seed = WORLD_SEED
	create_interface()
	queue_redraw()

func _draw() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var view_center := Vector2.ZERO if player == null else player.position
	if world_camera != null:
		view_center = world_camera.get_screen_center_position()
	var visible_area := Rect2(view_center - viewport_size * 0.5 - Vector2(GRID_SIZE, GRID_SIZE), viewport_size + Vector2(GRID_SIZE * 2, GRID_SIZE * 2))
	draw_rect(visible_area, Color("17202a"), true)
	var first_x := floori(visible_area.position.x / GRID_SIZE) * GRID_SIZE
	var first_y := floori(visible_area.position.y / GRID_SIZE) * GRID_SIZE
	for x in range(first_x, int(visible_area.end.x) + GRID_SIZE, GRID_SIZE):
		draw_line(Vector2(x, visible_area.position.y), Vector2(x, visible_area.end.y), Color("263746"), 1.0)
	for y in range(first_y, int(visible_area.end.y) + GRID_SIZE, GRID_SIZE):
		draw_line(Vector2(visible_area.position.x, y), Vector2(visible_area.end.x, y), Color("263746"), 1.0)
	for effect in visual_effects:
		var progress: float = 1.0 - effect.remaining / effect.duration
		if effect.kind == "slash":
			draw_arc(effect.position, effect.get("radius", 42.0), effect.angle - 0.9, effect.angle + 0.9, 16, effect.color, effect.get("width", 5.0) * (1.0 - progress))
		elif effect.kind == "blast":
			draw_arc(effect.position, effect.radius * progress, 0.0, TAU, 24, effect.color, 4.0 * (1.0 - progress))
	for projectile in projectiles:
		var color: Color = projectile.attack.color
		var size := 10.0 if projectile.attack.kind == "aoe_projectile" else 6.0
		draw_circle(projectile.position, size, color)

func create_interface() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	title = Label.new()
	title.position = Vector2(32, 20)
	title.text = "GOBLIN KILLER  |  Combat Prototype"
	title.add_theme_font_size_override("font_size", 24)
	ui.add_child(title)
	status = Label.new()
	status.position = Vector2(32, 55)
	status.add_theme_font_size_override("font_size", 16)
	ui.add_child(status)
	var resource_box := VBoxContainer.new()
	resource_box.position = Vector2(700, 20)
	resource_box.size = Vector2(228, 54)
	resource_box.add_theme_constant_override("separation", 6)
	hp_bar = create_resource_bar("HP", Color("e63946"))
	mp_bar = create_resource_bar("MP", Color("3a86ff"))
	resource_box.add_child(hp_bar)
	resource_box.add_child(mp_bar)
	ui.add_child(resource_box)
	class_box = VBoxContainer.new()
	class_box.position = Vector2(340, 175)
	class_box.size = Vector2(280, 190)
	var prompt := Label.new()
	prompt.text = "Choose your class"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 24)
	class_box.add_child(prompt)
	for choice_name in CLASS_DATA:
		var button := Button.new()
		button.text = choice_name
		button.custom_minimum_size = Vector2(280, 38)
		button.pressed.connect(start_level.bind(choice_name))
		class_box.add_child(button)
	ui.add_child(class_box)
	pause_menu = PanelContainer.new()
	pause_menu.position = Vector2(350, 150)
	pause_menu.size = Vector2(260, 190)
	var pause_background := StyleBoxFlat.new()
	pause_background.bg_color = Color("20242bf2")
	pause_background.border_color = Color("697386")
	pause_background.set_border_width_all(2)
	pause_background.corner_radius_top_left = 10
	pause_background.corner_radius_top_right = 10
	pause_background.corner_radius_bottom_left = 10
	pause_background.corner_radius_bottom_right = 10
	pause_menu.add_theme_stylebox_override("panel", pause_background)
	var pause_box := VBoxContainer.new()
	pause_box.add_theme_constant_override("separation", 12)
	pause_menu.add_child(pause_box)
	var pause_title := Label.new()
	pause_title.text = "PAUSED"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 28)
	pause_box.add_child(pause_title)
	var resume_button := Button.new()
	resume_button.text = "Resume  (Esc)"
	resume_button.custom_minimum_size = Vector2(220, 42)
	resume_button.pressed.connect(toggle_pause)
	pause_box.add_child(resume_button)
	var restart_button := Button.new()
	restart_button.text = "Restart Game"
	restart_button.custom_minimum_size = Vector2(220, 42)
	restart_button.pressed.connect(restart_game)
	pause_box.add_child(restart_button)
	pause_menu.hide()
	ui.add_child(pause_menu)
	status.text = "Select a class to enter the arena."

func create_resource_bar(resource_name: String, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(228, 24)
	bar.show_percentage = false
	bar.tooltip_text = resource_name
	var background := StyleBoxFlat.new()
	background.bg_color = Color("20242b")
	background.border_color = Color("697386")
	background.set_border_width_all(1)
	background.corner_radius_top_left = 4
	background.corner_radius_top_right = 4
	background.corner_radius_bottom_left = 4
	background.corner_radius_bottom_right = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func start_level(choice_name: String) -> void:
	selected_class = choice_name
	class_box.hide()
	player = Entity.new()
	player.configure(choice_name, CLASS_DATA[choice_name], CLASS_DATA[choice_name].color)
	player.position = Vector2(480, 300)
	add_child(player)
	configure_camera()
	update_world_enemies()
	status.text = "Move with WASD. Aim with the mouse; click or press Space: %s." % ATTACKS[selected_class].name

func configure_camera() -> void:
	world_camera = Camera2D.new()
	world_camera.position_smoothing_enabled = true
	world_camera.position_smoothing_speed = 8.0
	world_camera.drag_horizontal_enabled = true
	world_camera.drag_vertical_enabled = true
	world_camera.drag_left_margin = 0.22
	world_camera.drag_top_margin = 0.22
	world_camera.drag_right_margin = 0.22
	world_camera.drag_bottom_margin = 0.22
	world_camera.limit_left = -CAMERA_LIMIT
	world_camera.limit_top = -CAMERA_LIMIT
	world_camera.limit_right = CAMERA_LIMIT
	world_camera.limit_bottom = CAMERA_LIMIT
	player.add_child(world_camera)
	world_camera.make_current()

func get_visible_world_rect() -> Rect2:
	var viewport_size := get_viewport().get_visible_rect().size
	var view_center := player.position if world_camera == null else world_camera.get_screen_center_position()
	return Rect2(view_center - viewport_size * 0.5, viewport_size)

func update_world_enemies(delta := 0.0) -> void:
	for goblin in goblins.duplicate():
		if is_instance_valid(goblin) and goblin.position.distance_to(player.position) > ENEMY_DESPAWN_DISTANCE:
			goblins.erase(goblin)
			goblin.queue_free()
	if goblins.size() >= ACTIVE_ENEMY_TARGET:
		return
	var spawn_multiplier := minf(1.0 + elapsed_game_time * GOBLIN_SPAWN_RATE_RAMP, MAX_GOBLIN_SPAWN_MULTIPLIER)
	goblin_spawn_progress += BASE_GOBLIN_SPAWN_RATE * spawn_multiplier * delta
	while goblin_spawn_progress >= 1.0 and goblins.size() < ACTIVE_ENEMY_TARGET:
		goblin_spawn_progress -= 1.0
		spawn_enemy_at_viewport_edge()

func spawn_enemy_at_viewport_edge() -> void:
	var view := get_visible_world_rect()
	var position := Vector2.ZERO
	var edge := preferred_spawn_edge()
	match edge:
		0: position = Vector2(view.position.x - ENEMY_SPAWN_OFFSET, spawn_rng.randf_range(view.position.y, view.end.y))
		1: position = Vector2(view.end.x + ENEMY_SPAWN_OFFSET, spawn_rng.randf_range(view.position.y, view.end.y))
		2: position = Vector2(spawn_rng.randf_range(view.position.x, view.end.x), view.position.y - ENEMY_SPAWN_OFFSET)
		_: position = Vector2(spawn_rng.randf_range(view.position.x, view.end.x), view.end.y + ENEMY_SPAWN_OFFSET)
	var goblin := Entity.new()
	goblin.configure("Goblin", {"health": 55.0, "mana": 0.0, "damage": 9.0, "attack_speed": 0.65}, Color("55a630"))
	goblin.position = position
	add_child(goblin)
	goblins.append(goblin)

func preferred_spawn_edge() -> int:
	if travel_direction.length_squared() == 0.0:
		return spawn_rng.randi_range(0, 3)
	if absf(travel_direction.x) > absf(travel_direction.y):
		return 1 if travel_direction.x > 0.0 else 0
	return 3 if travel_direction.y > 0.0 else 2

func toggle_pause() -> void:
	game_paused = not game_paused
	pause_menu.visible = game_paused

func restart_game() -> void:
	game_paused = false
	get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if game_paused: return
	if player == null or player.health <= 0.0: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		attack(get_global_mouse_position())
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		attack(get_global_mouse_position())

func attack(aim_position: Vector2, allow_buffer := true) -> void:
	var attack_data: Dictionary = ATTACKS[selected_class]
	var now := Time.get_ticks_msec() / 1000.0
	var cooldown := 1.0 / player.attack_speed
	if now - last_attack_time < cooldown:
		if allow_buffer and cooldown - (now - last_attack_time) <= ATTACK_INPUT_BUFFER:
			buffered_attack_position = aim_position
			has_buffered_attack = true
		return
	has_buffered_attack = false
	if player.mana < attack_data.mana_cost:
		status.text = "Not enough Mana for %s." % attack_data.name
		return
	var aim_direction := player.position.direction_to(aim_position)
	if aim_direction == Vector2.ZERO: aim_direction = Vector2.RIGHT
	var aim_end := player.position + aim_direction * minf(player.position.distance_to(aim_position), attack_data.range)
	last_attack_time = now
	player.mana -= attack_data.mana_cost
	if attack_data.kind == "melee":
		var angle := player.position.angle_to_point(aim_position)
		visual_effects.append({"kind": "slash", "position": player.position, "angle": angle, "color": attack_data.color, "radius": attack_data.range, "remaining": attack_data.impact_delay, "duration": attack_data.impact_delay})
		pending_hits.append({"remaining": attack_data.impact_delay, "origin": player.position, "angle": angle, "damage": player.damage, "attack": attack_data})
		status.text = "Warrior winds up Cleave."
	else:
		projectiles.append({"position": player.position, "aim_end": aim_end, "attack": attack_data})
		status.text = "%s casts %s." % [selected_class, attack_data.name]

func resolve_hit(target: Entity, amount: float, attack_data: Dictionary, impact_position: Vector2, attack_angle := 0.0) -> void:
	if attack_data.kind == "melee":
		var hits := 0
		for goblin in goblins.duplicate():
			if is_instance_valid(goblin) and goblin.position.distance_to(impact_position) <= attack_data.range:
				if absf(wrapf(impact_position.angle_to_point(goblin.position) - attack_angle, -PI, PI)) <= 0.9:
					apply_damage(goblin, amount)
					hits += 1
		if not goblins.is_empty(): status.text = "Cleave hits %d goblin%s for %d damage." % [hits, "s" if hits != 1 else "", amount]
	elif attack_data.kind == "aoe_projectile":
		visual_effects.append({"kind": "blast", "position": impact_position, "color": attack_data.color, "radius": attack_data.area_radius, "remaining": 0.35, "duration": 0.35})
		var hits := 0
		for goblin in goblins.duplicate():
			if is_instance_valid(goblin) and goblin.position.distance_to(impact_position) <= attack_data.area_radius:
				apply_damage(goblin, amount)
				hits += 1
		if not goblins.is_empty(): status.text = "Fireball explodes for %d damage (%d goblins)." % [amount, hits]
	else:
		apply_damage(target, amount)
		if not goblins.is_empty(): status.text = "%s hits %s for %d damage." % [attack_data.name, target.entity_name, amount]

func apply_damage(target: Entity, amount: float) -> void:
	if not is_instance_valid(target): return
	target.hit(amount)
	if target.health <= 0.0:
		goblins.erase(target)
		target.queue_free()

func update_attacks(delta: float) -> void:
	for hit in pending_hits.duplicate():
		hit.remaining -= delta
		if hit.remaining <= 0.0:
			pending_hits.erase(hit)
			resolve_hit(null, hit.damage, hit.attack, hit.origin, hit.angle)
	for hit in pending_enemy_hits.duplicate():
		hit.remaining -= delta
		if hit.remaining <= 0.0:
			pending_enemy_hits.erase(hit)
			if is_instance_valid(hit.target) and hit.target.health > 0.0:
				hit.target.hit(hit.damage)
				status.text = "%s hits you for %d damage!" % [hit.source_name, hit.damage]
	for projectile in projectiles.duplicate():
		var target_position: Vector2 = projectile.aim_end
		projectile.position = projectile.position.move_toward(target_position, projectile.attack.projectile_speed * delta)
		var hit_target: Entity
		for goblin in goblins:
			if is_instance_valid(goblin) and projectile.position.distance_to(goblin.position) <= goblin.radius + 8.0:
				hit_target = goblin
				break
		if hit_target != null:
			projectiles.erase(projectile)
			resolve_hit(hit_target, player.damage, projectile.attack, projectile.position)
		elif projectile.position.distance_to(target_position) < 2.0:
			projectiles.erase(projectile)
			if projectile.attack.kind == "aoe_projectile":
				resolve_hit(null, player.damage, projectile.attack, target_position)
	for effect in visual_effects.duplicate():
		effect.remaining -= delta
		if effect.remaining <= 0.0: visual_effects.erase(effect)
	queue_redraw()

func _process(delta: float) -> void:
	if player == null: return
	if game_paused: return
	elapsed_game_time += delta
	if Input.is_key_pressed(KEY_R) and player.health <= 0.0:
		get_tree().reload_current_scene()
		return
	player.restore_mana(delta)
	if has_buffered_attack:
		if player.health <= 0.0:
			has_buffered_attack = false
		elif Time.get_ticks_msec() / 1000.0 - last_attack_time >= 1.0 / player.attack_speed:
			var buffered_aim := buffered_attack_position
			has_buffered_attack = false
			attack(buffered_aim, false)
	if player.health > 0.0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		attack(get_global_mouse_position())
	hp_bar.max_value = player.max_health
	hp_bar.value = player.health
	mp_bar.visible = player.max_mana > 0.0
	if mp_bar.visible:
		mp_bar.max_value = player.max_mana
		mp_bar.value = player.mana
	if player.health > 0.0:
		var movement := Vector2(
			float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
		)
		if movement.length_squared() > 0.0:
			travel_direction = movement.normalized()
			player.position += travel_direction * PLAYER_MOVE_SPEED * delta
		update_world_enemies(delta)
	update_attacks(delta)
	for goblin in goblins:
		var direction := goblin.position.direction_to(player.position)
		if goblin.position.distance_to(player.position) > 48:
			goblin.position += direction * 32.0 * delta
		else:
			goblin.attack_timer -= delta
			if goblin.attack_timer <= 0.0:
				goblin.attack_timer = 1.0 / goblin.attack_speed
				var impact_delay := 0.14
				visual_effects.append({"kind": "slash", "position": goblin.position, "angle": goblin.position.angle_to_point(player.position), "color": Color("ff8c69"), "radius": 29.0, "width": 3.0, "remaining": impact_delay, "duration": impact_delay})
				pending_enemy_hits.append({"remaining": impact_delay, "source_name": goblin.entity_name, "target": player, "damage": goblin.damage})
	if player.health <= 0.0:
		status.text = "Defeated. Press R to try another class."
