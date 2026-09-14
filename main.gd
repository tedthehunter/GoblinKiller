extends Node2D

const ARENA := Rect2(32, 86, 896, 410)
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
var selected_class := ""
var last_attack_time := -10.0
var pending_hits: Array[Dictionary] = []
var pending_enemy_hits: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var visual_effects: Array[Dictionary] = []
var title: Label
var status: Label
var stats: Label
var class_box: VBoxContainer

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
	create_interface()
	queue_redraw()

func _draw() -> void:
	draw_rect(ARENA, Color("17202a"), true)
	draw_rect(ARENA, Color("5c677d"), false, 2.0)
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
	stats = Label.new()
	stats.position = Vector2(610, 25)
	stats.size = Vector2(318, 55)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui.add_child(stats)
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
	status.text = "Select a class to enter the arena."

func start_level(choice_name: String) -> void:
	selected_class = choice_name
	class_box.hide()
	player = Entity.new()
	player.configure(choice_name, CLASS_DATA[choice_name], CLASS_DATA[choice_name].color)
	player.position = Vector2(190, 292)
	add_child(player)
	for index in range(5):
		var goblin := Entity.new()
		goblin.configure("Goblin %d" % (index + 1), {"health": 55.0, "mana": 0.0, "damage": 9.0, "attack_speed": 0.65}, Color("55a630"))
		goblin.position = Vector2(680 + index * 75, 190 + index * 100)
		add_child(goblin)
		goblins.append(goblin)
	status.text = "Click or press Space: %s." % ATTACKS[selected_class].name

func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.health <= 0.0 or goblins.is_empty(): return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		attack()
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		attack()

func nearest_target(max_range: float) -> Entity:
	var target: Entity
	for goblin in goblins:
		if not is_instance_valid(goblin): continue
		if player.position.distance_to(goblin.position) <= max_range and (target == null or player.position.distance_to(goblin.position) < player.position.distance_to(target.position)):
			target = goblin
	return target

func attack() -> void:
	var attack_data: Dictionary = ATTACKS[selected_class]
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_attack_time < 1.0 / player.attack_speed: return
	if player.mana < attack_data.mana_cost:
		status.text = "Not enough Mana for %s." % attack_data.name
		return
	var target := nearest_target(attack_data.range)
	if target == null:
		status.text = "No target in %d range." % attack_data.range
		return
	last_attack_time = now
	player.mana -= attack_data.mana_cost
	if attack_data.kind == "melee":
		var angle := player.position.angle_to_point(target.position)
		visual_effects.append({"kind": "slash", "position": player.position, "angle": angle, "color": attack_data.color, "radius": attack_data.range, "remaining": attack_data.impact_delay, "duration": attack_data.impact_delay})
		pending_hits.append({"remaining": attack_data.impact_delay, "target": target, "origin": player.position, "angle": angle, "damage": player.damage, "attack": attack_data})
		status.text = "Warrior winds up Cleave."
	else:
		projectiles.append({"position": player.position, "target": target, "attack": attack_data})
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
		if goblins.is_empty(): status.text = "Victory! Every goblin is defeated. Press R to choose a class again."

func update_attacks(delta: float) -> void:
	for hit in pending_hits.duplicate():
		hit.remaining -= delta
		if hit.remaining <= 0.0:
			pending_hits.erase(hit)
			if is_instance_valid(hit.target):
				resolve_hit(hit.target, hit.damage, hit.attack, hit.origin, hit.angle)
	for hit in pending_enemy_hits.duplicate():
		hit.remaining -= delta
		if hit.remaining <= 0.0:
			pending_enemy_hits.erase(hit)
			if is_instance_valid(hit.target) and hit.target.health > 0.0:
				hit.target.hit(hit.damage)
				status.text = "%s hits you for %d damage!" % [hit.source_name, hit.damage]
	for projectile in projectiles.duplicate():
		if not is_instance_valid(projectile.target):
			projectiles.erase(projectile)
			continue
		var target_position: Vector2 = projectile.target.position
		projectile.position = projectile.position.move_toward(target_position, projectile.attack.projectile_speed * delta)
		if projectile.position.distance_to(target_position) < 2.0:
			projectiles.erase(projectile)
			resolve_hit(projectile.target, player.damage, projectile.attack, target_position)
	for effect in visual_effects.duplicate():
		effect.remaining -= delta
		if effect.remaining <= 0.0: visual_effects.erase(effect)
	queue_redraw()

func _process(delta: float) -> void:
	if player == null: return
	if Input.is_key_pressed(KEY_R) and (goblins.is_empty() or player.health <= 0.0):
		get_tree().reload_current_scene()
		return
	player.restore_mana(delta)
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
	var mana_text := "" if player.max_mana <= 0.0 else "   MP %d/%d" % [player.mana, player.max_mana]
	stats.text = "%s\nHP %d/%d%s   Damage %d   Speed %.1f" % [selected_class, player.health, player.max_health, mana_text, player.damage, player.attack_speed]
