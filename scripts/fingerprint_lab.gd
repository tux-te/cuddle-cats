class_name FingerprintLab
extends Control

# The Mystery room's fingerprint lab. The kid presses their finger, then the
# pet presses a paw, and both prints are compared with the one left at the
# crime scene - it never matches either of them. Then every suspect's print is
# compared too; a match only means "same pattern", so it narrows the suspects
# without naming the culprit (see room_mystery.gd for who shares a pattern).

signal closed(matching: Array)

const Sfx = preload("res://scripts/sfx.gd")
const INK := Color(0.23, 0.16, 0.16, 1)
const PURPLE := Color(0.25, 0.2, 0.55, 1)

var crime_kind := ""
var suspects: Array = []   # [{"id", "name", "emoji", "kind"}]
var pet_kind := ""
var pet_label := ""

var your_view: FingerprintView
var pet_view: FingerprintView
var your_caption: Label
var pet_caption: Label
var paw_button: Button
var results: VBoxContainer
var matching: Array = []
const HOLD_SECONDS := 0.8
const INK_SPEED := 190.0   # pixels per second the ink spreads while held
var pressing := false
var pad_done := false
var press_time := 0.0
var your_kind := ""
var your_seed := 0

# `data`: crime_kind, suspects, your_kind, pet_kind, pet_name.
static func open(parent: Node, data: Dictionary) -> FingerprintLab:
	var lab := FingerprintLab.new()
	lab.set_anchors_preset(Control.PRESET_FULL_RECT)
	lab.crime_kind = String(data["crime_kind"])
	lab.suspects = data["suspects"]
	lab.pet_kind = String(data["pet_kind"])
	lab.pet_label = String(data["pet_name"])
	parent.add_child(lab)
	lab._build()
	return lab

func _build() -> void:
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
	style.bg_color = Color(0.96, 0.96, 1.0)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(820, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)

	box.add_child(_label("🖐 Fingerprint lab", 30, PURPLE))
	box.add_child(_label("A print was left at the crime scene. Hold your finger on your card until the ink spreads, then it's your pet's turn!", 18, INK))

	var prints := HBoxContainer.new()
	prints.alignment = BoxContainer.ALIGNMENT_CENTER
	prints.add_theme_constant_override("separation", 24)
	box.add_child(prints)
	var crime_view := FingerprintView.new()
	crime_view.kind = crime_kind
	crime_view.ink = Color(0.6, 0.15, 0.25)
	prints.add_child(_slot("🔍 Crime scene", crime_view, FingerprintView.KINDS[crime_kind]))
	your_view = FingerprintView.new()
	your_view.mouse_filter = Control.MOUSE_FILTER_STOP
	your_view.gui_input.connect(_on_pad_input)
	your_caption = _label("👆 Hold your finger on the card", 18, INK)
	prints.add_child(_slot_with(PetalState.player_name if PetalState.player_name != "" else "You", your_view, your_caption))
	pet_view = FingerprintView.new()
	pet_caption = _label("?", 18, INK)
	prints.add_child(_slot_with(pet_label, pet_view, pet_caption))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	paw_button = _button("🐾 %s's turn" % pet_label, _on_paw)
	paw_button.disabled = true
	buttons.add_child(paw_button)

	results = VBoxContainer.new()
	results.add_theme_constant_override("separation", 6)
	box.add_child(results)

	var close := _button("Close", func() -> void: _close())
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(close)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 52)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	return button

func _slot(title: String, view: FingerprintView, caption_text: String) -> VBoxContainer:
	return _slot_with(title, view, _label(caption_text, 18, INK))

func _slot_with(title: String, view: FingerprintView, caption: Label) -> VBoxContainer:
	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", 4)
	slot.add_child(_label(title, 20, PURPLE))
	slot.add_child(view)
	slot.add_child(caption)
	return slot

# A fresh print "stamps" on: it fades and pops in.
func _stamp(view: FingerprintView, kind: String) -> void:
	view.kind = kind
	view.pivot_offset = view.size / 2.0
	view.modulate.a = 0.0
	view.scale = Vector2(1.2, 1.2)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(view, "modulate:a", 1.0, 0.4)
	tween.tween_property(view, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)

# Holding a finger on the card: the ink spreads out from where it touches. The
# print is made from that real press the first time (where and when you touched)
# and then kept, so it is always your print.
func _on_pad_input(event: InputEvent) -> void:
	if pad_done or pressing:
		return
	var is_down: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not is_down:
		return
	var at: Vector2 = event.position
	pressing = true
	press_time = 0.0
	if PetalState.finger_print.is_empty():
		your_seed = hash([at, Time.get_ticks_usec()])
		your_kind = FingerprintView.KINDS.keys()[absi(your_seed) % FingerprintView.KINDS.size()]
	else:
		your_seed = int(PetalState.finger_print["seed"])
		your_kind = String(PetalState.finger_print["kind"])
	your_view.seed_value = your_seed
	your_view.reveal_center = at
	your_view.reveal_radius = 0.0
	your_view.kind = your_kind
	your_caption.text = "Scanning… keep holding 🔍"
	set_process(true)

func _process(delta: float) -> void:
	if not pressing:
		set_process(false)
		return
	press_time += delta
	your_view.reveal_radius = press_time * INK_SPEED
	your_view.scan_position = absf(fmod(press_time * 1.4, 2.0) - 1.0)

func _input(event: InputEvent) -> void:
	var is_up: bool = (event is InputEventMouseButton and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	if pressing and is_up:
		_lift_finger()

func _lift_finger() -> void:
	pressing = false
	your_view.scan_position = -1.0
	if press_time < HOLD_SECONDS:
		your_view.kind = ""
		your_view.reveal_radius = -1.0
		your_caption.text = "Hold a little longer! 👆"
		return
	pad_done = true
	your_view.reveal_radius = -1.0
	your_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if PetalState.finger_print.is_empty():
		PetalState.finger_print = {"kind": your_kind, "seed": your_seed}
		PetalState.save_game()
		your_caption.text = "%s - your very own print! ✨" % FingerprintView.KINDS[your_kind]
	else:
		your_caption.text = "%s - that's your print again!" % FingerprintView.KINDS[your_kind]
	_stamp_pop(your_view)
	Sfx.chime(self)
	paw_button.disabled = false

func _stamp_pop(view: FingerprintView) -> void:
	view.pivot_offset = view.size / 2.0
	var tween := create_tween()
	tween.tween_property(view, "scale", Vector2(1.08, 1.08), 0.12)
	tween.tween_property(view, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)

func _on_paw() -> void:
	paw_button.disabled = true
	pet_view.seed_value = absi(("paw" + PetalState.active_pet).hash())
	_stamp(pet_view, pet_kind)
	pet_caption.text = FingerprintView.KINDS[pet_kind]
	_compare()

func _compare() -> void:
	for child in results.get_children():
		child.queue_free()
	results.add_child(_label(_verdict("You", your_kind), 18, INK))
	results.add_child(_label(_verdict(pet_label, pet_kind), 18, INK))
	results.add_child(_label("🕵️ Suspects' prints - same pattern as the crime scene?", 20, PURPLE))
	var grid := HFlowContainer.new()
	grid.alignment = FlowContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	results.add_child(grid)
	matching = []
	for suspect in suspects:
		var same: bool = suspect["kind"] == crime_kind
		if same:
			matching.append(suspect["id"])
		var view := FingerprintView.new()
		view.custom_minimum_size = Vector2(96, 108)
		view.kind = String(suspect["kind"])
		view.ink = Color(0.6, 0.15, 0.25) if same else Color(0.2, 0.17, 0.4)
		var cell := VBoxContainer.new()
		cell.add_child(_label("%s %s" % [suspect["emoji"], suspect["name"]], 16, INK))
		cell.add_child(view)
		cell.add_child(_label("✅ Same pattern" if same else "❌ Different", 16, Color(0.6, 0.15, 0.25) if same else INK))
		grid.add_child(cell)
	results.add_child(_label("Careful: lots of animals share a pattern, so a match only narrows it down. Use the clues too!", 16, PURPLE))

func _verdict(who: String, kind: String) -> String:
	if kind == crime_kind:
		return "%s: a %s too - but %s was right here, so it's only a lookalike pattern!" % [who, FingerprintView.KINDS[kind], who]
	return "%s: a %s. The crime scene is a %s - different, so it wasn't %s! ✅" % [who, FingerprintView.KINDS[kind], FingerprintView.KINDS[crime_kind], who]

func _close() -> void:
	closed.emit(matching)
	queue_free()
