class_name EncounterDialog
extends PanelContainer

signal option_chosen(option: Dictionary)

var title_label: Label
var description_label: Label
var options_box: VBoxContainer

func _ready() -> void:
	position = Vector2(270, 155)
	size = Vector2(420, 230)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	box.add_child(title_label)
	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.custom_minimum_size = Vector2(380, 58)
	box.add_child(description_label)
	options_box = VBoxContainer.new()
	box.add_child(options_box)
	add_child(box)
	hide()

func present(encounter: EncounterDefinition) -> void:
	title_label.text = encounter.title
	description_label.text = encounter.description
	for child in options_box.get_children(): child.queue_free()
	for option in encounter.options:
		var button := Button.new()
		button.text = option.label
		button.custom_minimum_size = Vector2(380, 34)
		button.pressed.connect(choose.bind(option))
		options_box.add_child(button)
	show()

func choose(option: Dictionary) -> void:
	hide()
	option_chosen.emit(option)
