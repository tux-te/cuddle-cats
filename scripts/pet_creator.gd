class_name PetCreator
extends Control

# The "Make your cat" screen opened by the + in the pet picker. The kid picks a
# name, breed, fur colour, girl/boy, age, personality and favourite treat while
# a live preview shows the result; Create hands the choices to
# PetalState.create_custom_pet (see "Custom cats" there).

signal created(id: String)
signal cancelled

const INK := Color(0.23, 0.16, 0.16, 1)
const PINK := Color(0.72, 0.31, 0.47, 1)

var spec := {}
var preview: TextureRect
var name_button: Button
var summary: Label
# choice key -> [[button, value], ...], so Surprise me can re-select every row.
var rows := {}

static func open(parent: Node) -> PetCreator:
	var creator := PetCreator.new()
	creator.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(creator)
	creator._build()
	return creator

func _build() -> void:
	spec = {
		"name": PetalState.CAT_NAME_IDEAS.pick_random(), "breed": "persian", "coat": "natural",
		"gender": "girl", "age": "young", "personality": "playful", "treat": PetalState.SPECIES_TREATS["cat"][0],
	}

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.23, 0.16, 0.16, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.96, 0.98, 1)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)

	var heading := Label.new()
	heading.text = "🐱 Make your cat ✨"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", PINK)
	outer.add_child(heading)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	outer.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(260, 340)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left.add_child(preview)
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 18)
	summary.add_theme_color_override("font_color", INK)
	left.add_child(summary)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 10)
	scroll.add_child(options)

	options.add_child(_section_label("Name"))
	name_button = Button.new()
	name_button.custom_minimum_size = Vector2(300, 52)
	name_button.add_theme_font_size_override("font_size", 24)
	name_button.pressed.connect(_edit_name)
	options.add_child(name_button)

	options.add_child(_section_label("Breed"))
	options.add_child(_choice_row("breed", _labels(PetalState.CAT_BREEDS)))
	options.add_child(_section_label("Fur colour"))
	options.add_child(_choice_row("coat", _labels(PetalState.CAT_COATS), true))
	options.add_child(_section_label("Girl or boy?"))
	options.add_child(_choice_row("gender", PetalState.CAT_GENDERS))
	options.add_child(_section_label("Age"))
	options.add_child(_choice_row("age", PetalState.CAT_AGES))
	options.add_child(_section_label("Personality"))
	options.add_child(_choice_row("personality", _labels(PetalState.CAT_PERSONALITIES)))
	options.add_child(_section_label("Favourite treat"))
	var treats := {}
	for treat in PetalState.SPECIES_TREATS["cat"]:
		treats[treat] = treat
	options.add_child(_choice_row("treat", treats))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	outer.add_child(buttons)
	buttons.add_child(_action_button("Cancel", _on_cancel))
	buttons.add_child(_action_button("🎲 Surprise me", _surprise))
	var create := _action_button("Create 🐱", _on_create)
	create.add_theme_color_override("font_color", PINK)
	buttons.add_child(create)

	_refresh()

# {key: {"label": ...}} tables -> {key: label} for _choice_row.
func _labels(table: Dictionary) -> Dictionary:
	var out := {}
	for key in table:
		out[key] = String(table[key]["label"])
	return out

func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", PINK)
	return label

func _action_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 56)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(action)
	return button

# One row of pick-one buttons for spec[key]. Fur colours are drawn as swatches.
func _choice_row(key: String, choices: Dictionary, swatches := false) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	var group := ButtonGroup.new()
	rows[key] = []
	for value in choices:
		var button := Button.new()
		button.text = String(choices[value])
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0, 48)
		button.add_theme_font_size_override("font_size", 20)
		if swatches:
			_style_swatch(button, PetalState.CAT_COATS[value]["swatch"])
		button.button_pressed = String(spec[key]) == String(value)
		button.pressed.connect(_pick.bind(key, value))
		flow.add_child(button)
		rows[key].append([button, value])
	return flow

func _style_swatch(button: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(12)
		box.set_content_margin_all(10)
		if state.ends_with("pressed"):
			box.set_border_width_all(5)
			box.border_color = PINK
		button.add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, INK)

func _pick(key: String, value) -> void:
	spec[key] = value
	_refresh()

func _edit_name() -> void:
	var editor := NameEditor.open(self, "Name your cat 🐱", String(spec["name"]), "Cancel")
	editor.submitted.connect(func(text: String) -> void:
		if text.strip_edges() != "":
			spec["name"] = text.strip_edges()
		_refresh())

func _surprise() -> void:
	spec["name"] = PetalState.CAT_NAME_IDEAS.pick_random()
	spec["breed"] = PetalState.CAT_BREEDS.keys().pick_random()
	spec["coat"] = PetalState.CAT_COATS.keys().pick_random()
	spec["gender"] = PetalState.CAT_GENDERS.keys().pick_random()
	spec["age"] = PetalState.CAT_AGES.keys().pick_random()
	spec["personality"] = PetalState.CAT_PERSONALITIES.keys().pick_random()
	spec["treat"] = PetalState.SPECIES_TREATS["cat"].pick_random()
	for key in rows:
		for pair in rows[key]:
			pair[0].button_pressed = String(pair[1]) == String(spec[key])
	_refresh()

func _refresh() -> void:
	name_button.text = "✏️ %s" % spec["name"]
	preview.texture = load(PetalState.spec_cutout(spec))
	PetalState.apply_tint_info(preview, PetalState.spec_tint(spec))
	summary.text = "%s\n%s\nLoves %s" % [spec["name"], PetalState.spec_profile(spec), spec["treat"]]

func _on_create() -> void:
	var id := PetalState.create_custom_pet(spec)
	if id == "":
		cancelled.emit()
	else:
		created.emit(id)
	queue_free()

func _on_cancel() -> void:
	cancelled.emit()
	queue_free()
