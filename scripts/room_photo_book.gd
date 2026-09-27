extends Control

@onready var grid: GridContainer = %Grid
@onready var scroll: ScrollContainer = %ScrollContainer
@onready var sub_label: Label = %SubLabel
@onready var empty_label: Label = %EmptyLabel

var sticker_picker: PopupPanel = null
var picker_index := -1
var last_photo_count := 0

func _ready() -> void:
	PetalState.photo_taken.connect(_refresh)
	_build_sticker_picker()
	_refresh()

func _refresh() -> void:
	for child in grid.get_children():
		child.queue_free()

	for i in range(PetalState.photos.size()):
		grid.add_child(_build_page(i))

	sub_label.text = "%d photo%s" % [PetalState.photos.size(), "" if PetalState.photos.size() == 1 else "s"]
	empty_label.visible = PetalState.photos.is_empty()

	# Jump to the newest page when a photo is actually added (not when a
	# sticker toggle just re-triggers this while decorating an older page).
	if PetalState.photos.size() > last_photo_count:
		await get_tree().process_frame
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	last_photo_count = PetalState.photos.size()

func _build_page(index: int) -> Control:
	var photo: Dictionary = PetalState.photos[index]

	var page := VBoxContainer.new()
	page.custom_minimum_size = Vector2(270, 240)
	page.add_theme_constant_override("separation", 4)

	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(270, 170)
	rect.texture = photo["texture"]
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	page.add_child(rect)

	var caption := Label.new()
	caption.text = String(photo.get("caption", ""))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", Color(0.4, 0.3, 0.3, 1))
	page.add_child(caption)

	var stickers_row := HBoxContainer.new()
	stickers_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for sticker_id in photo.get("stickers", []):
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 22)
		label.text = String(PetalState.STICKERS.get(sticker_id, {}).get("emoji", ""))
		stickers_row.add_child(label)

	var add_button := Button.new()
	add_button.text = "+ sticker"
	add_button.add_theme_font_size_override("font_size", 14)
	add_button.pressed.connect(_open_sticker_picker.bind(index))
	stickers_row.add_child(add_button)

	page.add_child(stickers_row)
	return page

# Builds a small reusable popup listing every sticker the player has already
# earned in the Sticker Book - kids decorate photos with stickers they've
# won, not ones they haven't seen yet.
func _build_sticker_picker() -> void:
	sticker_picker = PopupPanel.new()
	var list := GridContainer.new()
	list.name = "List"
	list.columns = 4
	list.add_theme_constant_override("h_separation", 8)
	list.add_theme_constant_override("v_separation", 8)
	sticker_picker.add_child(list)
	add_child(sticker_picker)

func _open_sticker_picker(index: int) -> void:
	picker_index = index
	var list: GridContainer = sticker_picker.get_node("List")
	for child in list.get_children():
		child.queue_free()

	for sticker_id in PetalState.STICKERS:
		if not PetalState.earned_stickers.get(sticker_id, false):
			continue
		var btn := Button.new()
		btn.text = String(PetalState.STICKERS[sticker_id]["emoji"])
		btn.add_theme_font_size_override("font_size", 22)
		btn.custom_minimum_size = Vector2(48, 48)
		btn.pressed.connect(_on_sticker_picked.bind(sticker_id))
		list.add_child(btn)

	if list.get_child_count() == 0:
		var hint := Label.new()
		hint.text = "Earn stickers around the house first! 🌟"
		list.add_child(hint)

	sticker_picker.popup_centered()

func _on_sticker_picked(sticker_id: String) -> void:
	PetalState.toggle_photo_sticker(picker_index, sticker_id)
	sticker_picker.hide()
