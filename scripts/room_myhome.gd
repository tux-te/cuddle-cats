extends Control

# "My Home": design the front of your own house and, just for fun, give it an
# address. Two ways to make the house: build it from parts, or draw it (sketch
# pad -> Sharpen lines -> pixel art you paint with a bucket). Every change is
# saved straight away (PetalState.my_home).

const PetCameo = preload("res://scripts/pet_cameo.gd")
const Confetti = preload("res://scripts/confetti.gd")
const Sfx = preload("res://scripts/sfx.gd")

const INK := Color(0.23, 0.16, 0.16, 1)
const PINK := Color(0.72, 0.31, 0.47, 1)
const PET_SIZE := Vector2(110, 120)

var design: Dictionary = {}
var canvas: HomeCanvas
var petal: TextureRect
var address_label: Label
var swatches := {}        # "wall" / "roof" / "door" -> [Button, ...]
var pick_buttons := {}    # "roof_style" / "window" / "door_style" -> {id: Button}
var extra_buttons := {}   # extra id -> Button
var address_fields := {}  # "number" / "street" / "town" -> LineEdit
var mode := "build"       # "build", "sketch", "pixel" or "drawn" (see _set_mode)
var sketch: SketchPad
var pixel_house: PixelHouse
var build_scroll: ScrollContainer
var draw_panel: VBoxContainer
var draw_hint: Label
var sketch_group: VBoxContainer
var pixel_group: VBoxContainer
var result_group: VBoxContainer
var paint_swatches: Array = []

func _ready() -> void:
	design = PetalState.my_home_from_save(PetalState.my_home)
	var paper := ColorRect.new()
	paper.color = Color(1.0, 0.94, 0.88)
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(paper)
	_build()
	PetCameo.spawn(petal)
	_refresh()
	_set_mode("drawn" if String(design["style"]) == "drawn" else "build")
	if not (design["pixels"] as PackedByteArray).is_empty():
		pixel_house.set_cells(design["pixels"])
	tree_exiting.connect(func() -> void: PetalState.save_my_home(design))

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	left.add_child(modes)
	modes.add_child(_action("🧱 Build a house", _on_build_mode))
	modes.add_child(_action("✏️ Draw my house", _on_draw_mode))
	canvas = HomeCanvas.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(canvas)
	sketch = SketchPad.new()
	sketch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sketch)
	pixel_house = PixelHouse.new()
	pixel_house.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pixel_house.changed.connect(_on_pixels_changed)
	left.add_child(pixel_house)
	address_label = _label("", 22, INK)
	left.add_child(address_label)
	for field in [["number", "House number", PetalState.HOME_NUMBER_MAX], ["street", "Street", PetalState.HOME_STREET_MAX], ["town", "Town (optional)", PetalState.HOME_TOWN_MAX]]:
		left.add_child(_address_field(field[0], field[1], field[2]))

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(520, 0)
	row.add_child(right)
	build_scroll = ScrollContainer.new()
	build_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(build_scroll)
	draw_panel = VBoxContainer.new()
	draw_panel.add_theme_constant_override("separation", 10)
	right.add_child(draw_panel)
	_build_draw_panel()
	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 8)
	build_scroll.add_child(options)

	var top := HBoxContainer.new()
	options.add_child(top)
	var pet_slot := Control.new()
	pet_slot.custom_minimum_size = PET_SIZE
	top.add_child(pet_slot)
	petal = TextureRect.new()
	petal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	petal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	petal.size = PET_SIZE
	petal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pet_slot.add_child(petal)
	var heading := _label("🏠 Design your home", 28, PINK)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)

	for field in [["wall", "🎨 Walls"], ["roof", "🏠 Roof colour"], ["door", "🚪 Door colour"]]:
		options.add_child(_section(field[1]))
		options.add_child(_swatch_row(field[0]))
	options.add_child(_section("🏠 Roof shape"))
	options.add_child(_pick_row("roof_style", PetalState.HOME_ROOFS))
	options.add_child(_section("🪟 Windows"))
	options.add_child(_pick_row("window", PetalState.HOME_WINDOWS))
	options.add_child(_section("🚪 Door shape"))
	options.add_child(_pick_row("door_style", PetalState.HOME_DOORS))
	options.add_child(_section("✨ Extras"))
	options.add_child(_extras_row())

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	options.add_child(buttons)
	buttons.add_child(_action("🎲 Surprise me", _surprise))
	buttons.add_child(_action("✅ Done", _done))

func _build_draw_panel() -> void:
	var heading := _label("✏️ Draw your house", 26, PINK)
	draw_panel.add_child(heading)
	draw_hint = _label("", 18, INK)
	draw_panel.add_child(draw_hint)

	sketch_group = VBoxContainer.new()
	sketch_group.add_theme_constant_override("separation", 8)
	draw_panel.add_child(sketch_group)
	sketch_group.add_child(_action("✨ Sharpen my lines", func() -> void: sketch.sharpen()))
	sketch_group.add_child(_action("↩ Undo", func() -> void: sketch.undo()))
	sketch_group.add_child(_action("🗑 Start over", func() -> void: sketch.clear()))
	sketch_group.add_child(_action("🎨 Make it pixel art!", _to_pixels))

	pixel_group = VBoxContainer.new()
	pixel_group.add_theme_constant_override("separation", 8)
	draw_panel.add_child(pixel_group)
	var palette := HFlowContainer.new()
	palette.add_theme_constant_override("h_separation", 4)
	palette.add_theme_constant_override("v_separation", 4)
	pixel_group.add_child(palette)
	for i in range(PetalState.SET_COLORS.size()):
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(40, 40)
		swatch.pressed.connect(_pick_paint.bind(i))
		palette.add_child(swatch)
		paint_swatches.append(swatch)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	pixel_group.add_child(tools)
	tools.add_child(_action("🪣 Fill", func() -> void: pixel_house.tool = "fill"))
	tools.add_child(_action("✏️ Pen", func() -> void: pixel_house.tool = "pen"))
	pixel_group.add_child(_action("🧽 Erase a spot", func() -> void:
		pixel_house.tool = "pen"
		pixel_house.paint = 0))
	pixel_group.add_child(_action("🔁 Draw again", _back_to_sketch))
	pixel_group.add_child(_action("✅ Use this house", _use_pixels))

	result_group = VBoxContainer.new()
	result_group.add_theme_constant_override("separation", 8)
	draw_panel.add_child(result_group)
	result_group.add_child(_action("🎨 Paint it more", func() -> void: _set_mode("pixel")))
	result_group.add_child(_action("🔁 Draw a new house", _back_to_sketch))
	result_group.add_child(_action("✅ Done", _done))

func _on_build_mode() -> void:
	design["style"] = "build"
	_set_mode("build")
	_refresh()

func _on_draw_mode() -> void:
	if not (design["pixels"] as PackedByteArray).is_empty():
		design["style"] = "drawn"
		_set_mode("drawn")
		_refresh()
	else:
		_set_mode("sketch")

func _set_mode(which: String) -> void:
	mode = which
	canvas.visible = mode == "build" or mode == "drawn"
	sketch.visible = mode == "sketch"
	pixel_house.visible = mode == "pixel"
	build_scroll.visible = mode == "build"
	draw_panel.visible = mode != "build"
	sketch_group.visible = mode == "sketch"
	pixel_group.visible = mode == "pixel"
	result_group.visible = mode == "drawn"
	match mode:
		"sketch":
			draw_hint.text = "Draw the front of your house with your finger or mouse. Then tap Sharpen to make the lines neat!"
		"pixel":
			draw_hint.text = "Pick a colour, then tap a space to fill it. Use Pen for single pixels."
		"drawn":
			draw_hint.text = "Here is your house!"
	if mode == "pixel":
		_pick_paint(clampi(pixel_house.paint - 2, 0, PetalState.SET_COLORS.size() - 1))

func _to_pixels() -> void:
	if sketch.strokes.is_empty():
		draw_hint.text = "Draw your house first - then I can turn it into pixel art!"
		return
	if not sketch.sharpened:
		sketch.sharpen()
	pixel_house.set_cells(sketch.to_pixels(PetalState.HOME_PIX_W, PetalState.HOME_PIX_H))
	_set_mode("pixel")

func _back_to_sketch() -> void:
	_set_mode("sketch")

func _use_pixels() -> void:
	design["pixels"] = pixel_house.cells.duplicate()
	design["style"] = "drawn"
	_set_mode("drawn")
	_refresh()
	var at := petal.global_position + petal.size / 2.0
	Confetti.burst(self, at, 20)
	PetCameo.jump_for_joy(petal)

func _on_pixels_changed() -> void:
	design["pixels"] = pixel_house.cells.duplicate()

func _pick_paint(index: int) -> void:
	pixel_house.paint = index + 2
	if pixel_house.tool != "fill" and pixel_house.tool != "pen":
		pixel_house.tool = "fill"
	for i in range(paint_swatches.size()):
		paint_swatches[i].add_theme_stylebox_override("normal", _swatch_style(i, i == index))
		paint_swatches[i].add_theme_stylebox_override("hover", _swatch_style(i, true))
		paint_swatches[i].add_theme_stylebox_override("pressed", _swatch_style(i, true))

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _section(text: String) -> Label:
	var label := _label(text, 20, PINK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label

func _action(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 52)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(action)
	return button

func _swatch_row(field: String) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	swatches[field] = []
	for i in range(PetalState.SET_COLORS.size()):
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(36, 36)
		swatch.pressed.connect(_set_value.bind(field, i))
		flow.add_child(swatch)
		swatches[field].append(swatch)
	return flow

func _pick_row(field: String, choices: Dictionary) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	var group := ButtonGroup.new()
	pick_buttons[field] = {}
	for id in choices:
		var button := Button.new()
		button.text = String(choices[id])
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0, 44)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_set_value.bind(field, id))
		flow.add_child(button)
		pick_buttons[field][id] = button
	return flow

func _extras_row() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for id in PetalState.HOME_EXTRAS:
		var button := Button.new()
		button.text = String(PetalState.HOME_EXTRAS[id])
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 44)
		button.add_theme_font_size_override("font_size", 18)
		button.toggled.connect(_on_extra.bind(id))
		flow.add_child(button)
		extra_buttons[id] = button
	return flow

func _address_field(field: String, hint: String, max_chars: int) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = hint
	edit.max_length = max_chars
	edit.custom_minimum_size = Vector2(0, 46)
	edit.add_theme_font_size_override("font_size", 20)
	edit.text = String(design[field])
	edit.text_changed.connect(func(text: String) -> void:
		design[field] = text
		_refresh(false))
	edit.focus_exited.connect(func() -> void: PetalState.save_my_home(design))
	edit.text_submitted.connect(func(_t: String) -> void: edit.release_focus())
	address_fields[field] = edit
	return edit

func _set_value(field: String, value) -> void:
	design[field] = value
	_refresh()

func _on_extra(on: bool, id: String) -> void:
	var extras: Array = design["extras"]
	if on and not extras.has(id):
		extras.append(id)
	elif not on:
		extras.erase(id)
	design["extras"] = extras
	_refresh()

func _surprise() -> void:
	design["wall"] = randi() % PetalState.SET_COLORS.size()
	design["roof"] = randi() % PetalState.SET_COLORS.size()
	design["door"] = randi() % PetalState.SET_COLORS.size()
	design["roof_style"] = PetalState.HOME_ROOFS.keys().pick_random()
	design["window"] = PetalState.HOME_WINDOWS.keys().pick_random()
	design["door_style"] = PetalState.HOME_DOORS.keys().pick_random()
	var extras: Array = []
	for id in PetalState.HOME_EXTRAS:
		if randf() < 0.4:
			extras.append(id)
	design["extras"] = extras
	_refresh()

func _done() -> void:
	PetalState.save_my_home(design)
	var at := petal.global_position + petal.size / 2.0
	Confetti.burst(self, at, 24)
	Sfx.fanfare(self)
	PetCameo.jump_for_joy(petal)

func _swatch_style(index: int, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PetalState.SET_COLORS[index]
	style.set_corner_radius_all(18)
	style.set_border_width_all(4 if selected else 1)
	style.border_color = INK if selected else PetalState.SET_COLORS[index].darkened(0.3)
	return style

# `save` is false while typing, so the file isn't rewritten on every key.
func _refresh(save := true) -> void:
	canvas.set_design(design)
	for field in swatches:
		for i in range(swatches[field].size()):
			var selected: bool = i == int(design[field])
			swatches[field][i].add_theme_stylebox_override("normal", _swatch_style(i, selected))
			swatches[field][i].add_theme_stylebox_override("hover", _swatch_style(i, true))
			swatches[field][i].add_theme_stylebox_override("pressed", _swatch_style(i, true))
	for field in pick_buttons:
		for id in pick_buttons[field]:
			pick_buttons[field][id].set_pressed_no_signal(id == design[field])
	for id in extra_buttons:
		extra_buttons[id].set_pressed_no_signal((design["extras"] as Array).has(id))
	var line := ("%s %s" % [design["number"], design["street"]]).strip_edges()
	if String(design["town"]) != "":
		line = "%s, %s" % [line, design["town"]] if line != "" else String(design["town"])
	address_label.text = "📮 " + line if line != "" else "📮 Type your address below - it's just for fun!"
	if save:
		PetalState.save_my_home(design)
