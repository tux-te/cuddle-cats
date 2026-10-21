extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const Confetti = preload("res://scripts/confetti.gd")
const SetCanvas = preload("res://scripts/pet_set_canvas.gd")

const PET_SIZE := Vector2(130, 120)
const STAGE_SIZE := Vector2(700, 360)
# Where the pet stands on the stage (top-left of her picture).
const SPOT_IDLE := Vector2(285, 140)
const SPOT_BED := Vector2(110, 125)
const SPOT_BOWL := Vector2(405, 150)

const PATTERN_LABELS := {
	"plain": "➖ Plain", "stripes": "🦓 Stripes", "dots": "⚪ Dots", "hearts": "💗 Hearts",
	"stars": "⭐ Stars", "checks": "🏁 Checks", "paws": "🐾 Paws",
}
const SHAPE_LABELS := {
	"round": "⭕ Round", "square": "🟦 Square", "heart": "💗 Heart", "star": "⭐ Star",
	"tall": "🥫 Tall", "wide": "🥣 Wide",
}
const INK := Color(0.4, 0.25, 0.3)

var design: Dictionary = {}
var kind := "bed"
var pet_id := ""

var canvas: Control
var petal: TextureRect
var kind_buttons := {}
var swatches := {"color": [], "trim": []}
var pattern_buttons := {}
var stamp_buttons := {}
var shape_row: HFlowContainer
var shape_buttons := {}
var name_button: Button

func _ready() -> void:
	pet_id = PetalState.active_pet
	var paper := ColorRect.new()
	paper.color = Color(1.0, 0.9, 0.94)
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(paper)
	_build()
	design = PetalState.pet_set(pet_id)
	canvas.food_color = SetCanvas.FOOD_COLORS.get(PetalState.pet_species(), SetCanvas.FOOD_COLORS["cat"])
	canvas.bed_name_default = "%s's Bed" % PetalState.pet_name
	canvas.bowl_name_default = "%s's Bowl" % PetalState.pet_name
	_refresh()
	petal.position = SPOT_IDLE
	PetCameo.spawn(petal)

# A scroll box keeps every control reachable above the bottom bar: the stage
# and its buttons on the left, the design controls on the right.
func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	scroll.add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	margin.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	var stage := Control.new()
	stage.custom_minimum_size = STAGE_SIZE
	left.add_child(stage)
	canvas = SetCanvas.new()
	canvas.size = STAGE_SIZE
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(canvas)
	petal = TextureRect.new()
	petal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	petal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	petal.size = PET_SIZE
	petal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(petal)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	left.add_child(actions)
	actions.add_child(_action_button("😴 Nap", _on_nap))
	actions.add_child(_action_button("🍽️ Eat", _on_eat))
	actions.add_child(_action_button("🎲 Surprise me!", _on_surprise))
	actions.add_child(_action_button("✅ I love it!", _on_done))

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.97, 0.98)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	columns.add_child(panel)
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 8)
	panel.add_child(options)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	options.add_child(tabs)
	var group := ButtonGroup.new()
	for entry in [["bed", "🛏️ Bed"], ["bowl", "🥣 Bowl"]]:
		var tab := Button.new()
		tab.text = entry[1]
		tab.toggle_mode = true
		tab.button_group = group
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0, 46)
		tab.add_theme_font_size_override("font_size", 22)
		tab.pressed.connect(_on_kind.bind(String(entry[0])))
		tabs.add_child(tab)
		kind_buttons[entry[0]] = tab

	for field in ["color", "trim"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		options.add_child(_titled("🎨 Colour" if field == "color" else "🎀 Trim", row))
		for i in range(PetalState.SET_COLORS.size()):
			var swatch := Button.new()
			swatch.custom_minimum_size = Vector2(32, 32)
			swatch.pressed.connect(_on_swatch.bind(field, i))
			row.add_child(swatch)
			swatches[field].append(swatch)

	var patterns := HFlowContainer.new()
	options.add_child(_titled("✨ Pattern", patterns))
	for id in PetalState.SET_PATTERNS:
		pattern_buttons[id] = _option_button(patterns, PATTERN_LABELS[id], 17, Vector2(0, 38), _on_pattern.bind(id))

	var stamps := HFlowContainer.new()
	options.add_child(_titled("🌟 Stamp", stamps))
	for id in PetalState.SET_STAMPS:
		stamp_buttons[id] = _option_button(stamps, id if id != "" else "🚫", 22, Vector2(44, 40), _on_stamp.bind(id))

	shape_row = HFlowContainer.new()
	options.add_child(_titled("📐 Shape", shape_row))

	name_button = Button.new()
	name_button.custom_minimum_size = Vector2(0, 44)
	name_button.add_theme_font_size_override("font_size", 19)
	name_button.pressed.connect(_on_name)
	options.add_child(name_button)

func _titled(title: String, content: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(92, 0)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", INK)
	row.add_child(label)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(content)
	return row

func _action_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 48)
	button.add_theme_font_size_override("font_size", 19)
	button.pressed.connect(action)
	return button

func _option_button(parent: Control, text: String, font_size: int, min_size: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

# --- Showing the current design ---------------------------------------------

func _piece() -> Dictionary:
	return design[kind]

func _refresh() -> void:
	canvas.set_design(design)
	var piece := _piece()
	for id in kind_buttons:
		kind_buttons[id].set_pressed_no_signal(id == kind)
	for field in swatches:
		for i in range(swatches[field].size()):
			swatches[field][i].add_theme_stylebox_override("normal", _swatch_style(i, i == int(piece[field])))
			swatches[field][i].add_theme_stylebox_override("hover", _swatch_style(i, true))
			swatches[field][i].add_theme_stylebox_override("pressed", _swatch_style(i, true))
	for id in pattern_buttons:
		pattern_buttons[id].set_pressed_no_signal(id == piece["pattern"])
	for id in stamp_buttons:
		stamp_buttons[id].set_pressed_no_signal(id == piece["stamp"])
	_rebuild_shapes()
	var label := "bed" if kind == "bed" else "bowl"
	name_button.text = "✏️ Name the %s: %s" % [label, canvas.bed_name.text if kind == "bed" else canvas.bowl_name.text]

func _swatch_style(index: int, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PetalState.SET_COLORS[index]
	style.set_corner_radius_all(16)
	style.set_border_width_all(4 if selected else 1)
	style.border_color = INK if selected else PetalState.SET_COLORS[index].darkened(0.3)
	return style

# The bed and the bowl each have their own shapes to choose from.
func _rebuild_shapes() -> void:
	for child in shape_row.get_children():
		shape_row.remove_child(child)
		child.queue_free()
	shape_buttons.clear()
	for id in PetalState.SET_SHAPES[kind]:
		var button := _option_button(shape_row, SHAPE_LABELS[id], 17, Vector2(0, 38), _on_shape.bind(id))
		button.set_pressed_no_signal(id == _piece()["shape"])
		shape_buttons[id] = button

func _changed() -> void:
	PetalState.save_pet_set(pet_id, design)
	_refresh()

# --- Choosing things ---------------------------------------------------------

func _on_kind(which: String) -> void:
	kind = which
	_refresh()

func _on_swatch(field: String, index: int) -> void:
	_piece()[field] = index
	_changed()

func _on_pattern(id: String) -> void:
	_piece()["pattern"] = id
	_changed()

func _on_stamp(id: String) -> void:
	_piece()["stamp"] = id
	_changed()

func _on_shape(id: String) -> void:
	_piece()["shape"] = id
	_changed()

func _on_name() -> void:
	var title := "Name the %s ✏️" % kind
	var editor := NameEditor.open(self, title, String(_piece()["name"]), "Cancel")
	editor.submitted.connect(_on_named)

func _on_named(text: String) -> void:
	_piece()["name"] = text.left(PetalState.SET_NAME_MAX)
	_changed()

func _on_surprise() -> void:
	for which in ["bed", "bowl"]:
		var piece: Dictionary = design[which]
		piece["color"] = randi() % PetalState.SET_COLORS.size()
		piece["trim"] = (int(piece["color"]) + 3 + randi() % 6) % PetalState.SET_COLORS.size()
		piece["pattern"] = PetalState.SET_PATTERNS.pick_random()
		piece["stamp"] = PetalState.SET_STAMPS.pick_random()
		piece["shape"] = PetalState.SET_SHAPES[which].pick_random()
	_changed()
	_pop("🎲 ta-da!", petal)

# --- The pet tries it out ----------------------------------------------------

func _on_nap() -> void:
	_walk_pet(SPOT_BED, "😴 so cozy!")

func _on_eat() -> void:
	_walk_pet(SPOT_BOWL, "😋 yum yum!")

func _walk_pet(spot: Vector2, text: String) -> void:
	var tween := create_tween()
	tween.tween_property(petal, "position", spot, 0.6).set_trans(Tween.TRANS_SINE)
	await tween.finished
	if not is_instance_valid(petal):
		return
	_pop(text, petal)
	PetCameo.jump_for_joy(petal)

func _on_done() -> void:
	PetalState.finish_pet_set(pet_id, design)
	var at := petal.global_position + petal.size / 2.0
	Confetti.burst(self, at, 24)
	_pop("🎉 Beautiful set!", petal)
	PetCameo.jump_for_joy(petal)

func _pop(text: String, near: Control) -> void:
	Feedback.pop(self, text, near.global_position - global_position + Vector2(0, -20))
