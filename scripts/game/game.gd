extends Node2D

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const GOBLIN_SCENE := preload("res://scenes/actors/goblin.tscn")
const LEVEL_SCENE := preload("res://scenes/world/dungeon_level.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const COMBAT_VISUALS_SCENE := preload("res://scenes/combat_visuals.tscn")
const FOG_OF_WAR_SCENE := preload("res://scenes/world/fog_of_war.tscn")
const PICKUP_SCENE := preload("res://scenes/world/pickup.tscn")

var player: Player
var level: DungeonLevel
var hud: GameHud
var goblins: Array[Goblin] = []
var attack: AttackDefinition
var last_attack_time := -10.0
var buffered_attack_position := Vector2.ZERO
var buffered_attack := false
var projectiles: Array[Dictionary] = []
var delayed_hits: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var game_paused := false
var completed := false
var combat_visuals: CombatVisuals
var fog_of_war: FogOfWar
var discoveries: Dictionary = {}
var encounter_active := false
var triggered_encounters: Dictionary = {}
var travel_progress := 0.0
var previous_player_position := Vector2.ZERO
var encounter_rng := RandomNumberGenerator.new()
var pickups: Array[WorldPickup] = []
var inventory: Array[PickupDefinition] = []

func _ready() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.class_selected.connect(start_run)
	hud.encounter_dialog.option_chosen.connect(resolve_encounter)
	combat_visuals = COMBAT_VISUALS_SCENE.instantiate()
	add_child(combat_visuals)
	fog_of_war = FOG_OF_WAR_SCENE.instantiate()
	add_child(fog_of_war)
	queue_redraw()

func start_run(stats: CharacterStats) -> void:
	hud.class_box.hide()
	player = PLAYER_SCENE.instantiate()
	player.configure(stats)
	player.position = Vector2(180, 295)
	player.died.connect(on_player_died)
	add_child(player)
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)
	camera.make_current()
	attack = make_attack(stats.display_name)
	combat_visuals.effects = effects
	combat_visuals.projectiles = projectiles
	combat_visuals.refresh(attack)
	load_floor(1)
	previous_player_position = player.position
	hud.set_status("WASD moves. Click or Space attacks. Reach the stairs.")

func make_attack(selected_class: String) -> AttackDefinition:
	var value := AttackDefinition.new()
	if selected_class == "Warrior":
		value.display_name = "Cleave"; value.kind = "melee"; value.range = 78.0; value.impact_delay = 0.18; value.color = Color("b9dcff")
	elif selected_class == "Mage":
		value.display_name = "Fireball"; value.kind = "aoe_projectile"; value.range = 360.0; value.mana_cost = 15.0; value.projectile_speed = 420.0; value.area_radius = 90.0; value.color = Color("ff6b35")
	else:
		value.display_name = "Throwing dagger"; value.kind = "projectile"; value.range = 420.0; value.projectile_speed = 620.0; value.color = Color("f6bd60")
	return value

func load_floor(number: int) -> void:
	if level != null: level.queue_free()
	for goblin in goblins: if is_instance_valid(goblin): goblin.queue_free()
	goblins.clear()
	for pickup in pickups: if is_instance_valid(pickup): pickup.queue_free()
	pickups.clear()
	projectiles.clear(); delayed_hits.clear(); effects.clear()
	level = LEVEL_SCENE.instantiate()
	level.setup(number)
	level.set_player(player)
	level.room_entered.connect(on_room_entered)
	level.exit_reached.connect(on_exit_reached)
	add_child(level)
	move_child(level, 0)
	player.position = Vector2(180, 295)
	previous_player_position = player.position
	hud.set_floor(number)
	if not discoveries.has(number): discoveries[number] = MapDiscovery.new()
	fog_of_war.configure(level, discoveries[number])
	hud.configure_minimap(level, discoveries[number], player)
	spawn_floor_pickups()

func spawn_floor_pickups() -> void:
	for spawn in level.pickup_spawns:
		var pickup: WorldPickup = PICKUP_SCENE.instantiate()
		pickup.configure(load(spawn.resource))
		pickup.position = spawn.position
		add_child(pickup)
		pickups.append(pickup)

func collect_pickups() -> void:
	for pickup in pickups.duplicate():
		if player.position.distance_to(pickup.position) > 28.0: continue
		pickups.erase(pickup)
		if pickup.definition.kind == "gear":
			player.stats.max_health += pickup.definition.health_bonus
			player.health += pickup.definition.health_bonus
			player.stats.damage += pickup.definition.damage_bonus
			player.stats.attack_speed += pickup.definition.attack_speed_bonus
			hud.set_status("Equipped %s." % pickup.definition.display_name)
		else:
			inventory.append(pickup.definition)
			hud.set_status("Picked up %s. Press E to use it." % pickup.definition.display_name)
		pickup.queue_free()
	update_item_prompt()

func use_item() -> void:
	if inventory.is_empty(): return
	var item: PickupDefinition = inventory.pop_front()
	player.health = minf(player.stats.max_health, player.health + item.health_restore)
	player.mana = minf(player.stats.max_mana, player.mana + item.mana_restore)
	hud.set_status("Used %s." % item.display_name)
	update_item_prompt()

func update_item_prompt() -> void:
	if inventory.is_empty(): hud.set_item_prompt("")
	else: hud.set_item_prompt("E: Use %s" % inventory[0].display_name)

func on_room_entered(room_id: String) -> void:
	var room := level.room_for_id(room_id)
	var path := "res://data/encounters/floor_%02d_%s.tres" % [level.floor_number, room_id]
	if not ResourceLoader.exists(path): return
	var group: SpawnGroup = load(path)
	spawn_encounter(room.rect, group)
	hud.set_status("Encounter: %d goblins defend this room!" % group.quantity)

func spawn_encounter(room: Rect2, group: SpawnGroup) -> void:
	for index in group.quantity:
		var goblin: Goblin = GOBLIN_SCENE.instantiate()
		goblin.configure(group.enemy_stats, group.health_multiplier, group.damage_multiplier)
		goblin.position = Vector2(room.position.x + 70 + (index % 3) * 70, room.position.y + 70 + (index / 3) * 70)
		goblin.died.connect(on_goblin_died)
		add_child(goblin)
		goblins.append(goblin)

func on_goblin_died(goblin: Character) -> void:
	goblins.erase(goblin)
	goblin.queue_free()

func on_exit_reached() -> void:
	if not goblins.is_empty():
		hud.set_status("The way is sealed. Defeat the room's goblins first.")
		return
	if level.floor_number == 1:
		load_floor(2)
		hud.set_status("Floor 2: clear the dungeon and claim the altar.")
	else:
		completed = true
		hud.set_status("VICTORY! The dungeon has been cleared. Press R to begin again.")

func on_player_died(_value: Character) -> void:
	hud.set_status("Defeated. Press R to choose another class.")

func trigger_encounter(resource_path: String) -> void:
	if encounter_active: return
	var encounter: EncounterDefinition = load(resource_path)
	encounter_active = true
	hud.present_encounter(encounter)

func resolve_encounter(option: Dictionary) -> void:
	encounter_active = false
	var amount: float = option.get("amount", 0.0)
	if option.effect == "heal":
		player.health = minf(player.stats.max_health, player.health + amount)
		hud.set_status("You recover %d health." % amount)
	elif option.effect == "mana":
		player.mana = minf(player.stats.max_mana, player.mana + amount)
		hud.set_status("You recover %d mana." % amount)
	else:
		hud.set_status("You continue deeper into the dungeon.")

func update_noncombat_encounters() -> void:
	if encounter_active: return
	for encounter in level.location_encounters:
		var key := "%d_%s" % [level.floor_number, encounter.id]
		if not triggered_encounters.has(key) and player.position.distance_to(encounter.position) < 36.0:
			triggered_encounters[key] = true
			trigger_encounter(encounter.resource)
			return
	travel_progress += player.position.distance_to(previous_player_position)
	previous_player_position = player.position
	if travel_progress >= 480.0:
		travel_progress = 0.0
		if encounter_rng.randf() <= 0.55: trigger_encounter("res://data/encounters/traveler_cache.tres")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		game_paused = not game_paused
		hud.pause_menu.visible = game_paused
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_R and (completed or (player != null and player.health <= 0.0)):
		get_tree().reload_current_scene(); return
	if game_paused or completed or player == null or player.health <= 0.0: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_E: use_item(); return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: try_attack(get_global_mouse_position())
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE: try_attack(get_global_mouse_position())

func try_attack(aim: Vector2, allow_buffer := true) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var cooldown := 1.0 / player.stats.attack_speed
	if now - last_attack_time < cooldown:
		if allow_buffer and cooldown - (now - last_attack_time) <= 0.16: buffered_attack_position = aim; buffered_attack = true
		return
	if player.mana < attack.mana_cost:
		hud.set_status("Not enough mana for %s." % attack.display_name); return
	last_attack_time = now; buffered_attack = false; player.mana -= attack.mana_cost
	var direction := player.position.direction_to(aim)
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	if attack.kind == "melee":
		var angle := player.position.angle_to_point(aim)
		effects.append({"kind":"slash", "position":player.position, "angle":angle, "remaining":attack.impact_delay})
		delayed_hits.append({"remaining":attack.impact_delay, "origin":player.position, "angle":angle})
	else:
		projectiles.append({"position":player.position, "target":player.position + direction * attack.range})
	combat_visuals.refresh(attack)

func resolve_melee(origin: Vector2, angle: float) -> void:
	for goblin in goblins.duplicate():
		if is_instance_valid(goblin) and origin.distance_to(goblin.position) <= attack.range and absf(wrapf(origin.angle_to_point(goblin.position) - angle, -PI, PI)) <= 0.9: goblin.take_damage(player.stats.damage)

func resolve_projectile(position: Vector2, target: Goblin) -> void:
	if attack.kind == "aoe_projectile":
		effects.append({"kind":"blast", "position":position, "remaining":0.35})
		for goblin in goblins.duplicate(): if is_instance_valid(goblin) and goblin.position.distance_to(position) <= attack.area_radius: goblin.take_damage(player.stats.damage)
	elif target != null: target.take_damage(player.stats.damage)

func _process(delta: float) -> void:
	if player == null or game_paused or completed or encounter_active: return
	if player.health <= 0.0: return
	player.restore_mana(delta)
	var movement := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	)
	player.move_in_level(movement, delta, level)
	collect_pickups()
	update_noncombat_encounters()
	if encounter_active: return
	level.update_player_location()
	fog_of_war.update_visibility(player.position)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): try_attack(get_global_mouse_position())
	if buffered_attack and Time.get_ticks_msec() / 1000.0 - last_attack_time >= 1.0 / player.stats.attack_speed: try_attack(buffered_attack_position, false)
	for hit in delayed_hits.duplicate():
		hit.remaining -= delta
		if hit.remaining <= 0.0: delayed_hits.erase(hit); resolve_melee(hit.origin, hit.angle)
	for shot in projectiles.duplicate():
		shot.position = shot.position.move_toward(shot.target, attack.projectile_speed * delta)
		var hit_target: Goblin
		for goblin in goblins:
			if is_instance_valid(goblin) and shot.position.distance_to(goblin.position) <= goblin.radius + 8.0: hit_target = goblin; break
		if hit_target != null: projectiles.erase(shot); resolve_projectile(shot.position, hit_target)
		elif shot.position.distance_to(shot.target) < 2.0:
			projectiles.erase(shot)
			if attack.kind == "aoe_projectile": resolve_projectile(shot.target, null)
	for goblin in goblins.duplicate():
		if is_instance_valid(goblin) and goblin.pursue(player, delta, level):
			player.take_damage(goblin.stats.damage)
			effects.append({"kind":"enemy", "position":goblin.position, "angle":goblin.position.angle_to_point(player.position), "remaining":0.14})
	for effect in effects.duplicate():
		effect.remaining -= delta
		if effect.remaining <= 0.0: effects.erase(effect)
	hud.update_player(player)
	combat_visuals.refresh(attack)
