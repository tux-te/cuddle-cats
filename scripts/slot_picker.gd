class_name SlotPicker
extends Control

# Full-screen popup listing the save slots, so each kid keeps their own
# game. Tap a card to play it; a filled slot has a small bin button that asks
# "Delete?" before erasing anything.

signal slot_chosen(slot: int)
signal cancelled

var list: VBoxContainer
var confirming := 0 # slot awaiting delete confirmation, 0 = none

static func open(parent: Node) -> SlotPicker:
	var picker := SlotPicker.new()
	picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(picker)
	picker._build()
	return picker

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
	style.bg_color = Color(1, 0.96, 0.98, 1)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var heading := Label.new()
	heading.text = "Who's playing? 🐾"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color(0.72, 0.31, 0.47, 1))
	box.add_child(heading)

	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	box.add_child(list)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 52)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func() -> void:
		cancelled.emit()
		queue_free())
	box.add_child(back)
	_refresh()

func _refresh() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for slot in range(1, PetalState.SLOT_COUNT + 1):
		list.add_child(_row(slot))

func _row(slot: int) -> Control:
	var info := PetalState.slot_summary(slot)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var card := Button.new()
	card.custom_minimum_size = Vector2(440, 76)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_font_size_override("font_size", 26)
	if info["exists"]:
		var who := String(info["player"]) if String(info["player"]) != "" else "Player %d" % slot
		card.text = "%s\n%s · %d coins" % [who, info["pet"], info["coins"]]
	else:
		card.text = "✨ New game %d" % slot
	card.pressed.connect(func() -> void: slot_chosen.emit(slot))
	row.add_child(card)

	if not info["exists"]:
		return row
	if confirming == slot:
		var sure := Button.new()
		sure.text = "Delete? ✅"
		sure.custom_minimum_size = Vector2(130, 76)
		sure.add_theme_font_size_override("font_size", 22)
		sure.pressed.connect(func() -> void:
			PetalState.delete_slot(slot)
			confirming = 0
			_refresh())
		row.add_child(sure)
		var keep := Button.new()
		keep.text = "❌"
		keep.custom_minimum_size = Vector2(70, 76)
		keep.add_theme_font_size_override("font_size", 26)
		keep.pressed.connect(func() -> void:
			confirming = 0
			_refresh())
		row.add_child(keep)
	else:
		var bin := Button.new()
		bin.text = "🗑"
		bin.custom_minimum_size = Vector2(70, 76)
		bin.add_theme_font_size_override("font_size", 28)
		bin.pressed.connect(func() -> void:
			confirming = slot
			_refresh())
		row.add_child(bin)
	return row
