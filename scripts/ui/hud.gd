class_name GameHud
extends CanvasLayer

signal class_selected(stats: CharacterStats)

var status: Label
var hp_bar: ProgressBar
var mp_bar: ProgressBar
var class_box: VBoxContainer
var pause_menu: PanelContainer
var floor_label: Label
var minimap: MiniMap
var encounter_dialog: EncounterDialog
var item_prompt: Label

func _ready() -> void:
	status = make_label(Vector2(24, 50), 16)
	floor_label = make_label(Vector2(24, 20), 24)
	hp_bar = make_bar(Vector2(704, 18), Color("e63946"))
	mp_bar = make_bar(Vector2(704, 48), Color("3a86ff"))
	class_box = VBoxContainer.new()
	class_box.position = Vector2(340, 165)
	class_box.size = Vector2(280, 200)
	var prompt := Label.new()
	prompt.text = "Choose your class"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 24)
	class_box.add_child(prompt)
	for path in ["res://data/classes/warrior.tres", "res://data/classes/mage.tres", "res://data/classes/thief.tres"]:
		var stats: CharacterStats = load(path)
		var button := Button.new()
		button.text = stats.display_name
		button.custom_minimum_size = Vector2(280, 40)
		button.pressed.connect(select_class.bind(stats))
		class_box.add_child(button)
	add_child(class_box)
	pause_menu = PanelContainer.new()
	pause_menu.position = Vector2(350, 180)
	pause_menu.size = Vector2(260, 110)
	var box := VBoxContainer.new()
	var text := Label.new()
	text.text = "PAUSED\nPress Esc to resume"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 22)
	box.add_child(text)
	pause_menu.add_child(box)
	pause_menu.hide()
	add_child(pause_menu)
	minimap = preload("res://scenes/ui/minimap.tscn").instantiate()
	add_child(minimap)
	encounter_dialog = preload("res://scenes/ui/encounter_dialog.tscn").instantiate()
	add_child(encounter_dialog)
	item_prompt = make_label(Vector2(300, 500), 16)
	item_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_prompt.size = Vector2(360, 28)
	set_status("Select a class to begin your descent.")

func select_class(stats: CharacterStats) -> void:
	class_selected.emit(stats)

func make_label(at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label

func make_bar(at: Vector2, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = at
	bar.size = Vector2(230, 23)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override("fill", fill)
	add_child(bar)
	return bar

func set_status(value: String) -> void:
	status.text = value

func set_floor(number: int) -> void:
	floor_label.text = "GOBLIN KILLER  |  FLOOR %d" % number

func update_player(player: Player) -> void:
	if player == null: return
	hp_bar.max_value = player.stats.max_health
	hp_bar.value = player.health
	mp_bar.visible = player.stats.max_mana > 0.0
	mp_bar.max_value = player.stats.max_mana
	mp_bar.value = player.mana
	minimap.refresh()

func configure_minimap(level: DungeonLevel, discovery: MapDiscovery, player: Player) -> void:
	minimap.configure(level, discovery, player)

func present_encounter(encounter: EncounterDefinition) -> void:
	encounter_dialog.present(encounter)

func set_item_prompt(text: String) -> void:
	item_prompt.text = text
