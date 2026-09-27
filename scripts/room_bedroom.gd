extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")

@onready var background: TextureRect = %Background

func _ready() -> void:
	_refresh_background()
	_place_on_perch_if_kiwi()
	_build_perch_toggles()
	PetCameo.spawn(%Petal)
	%CuddleButton.pressed.connect(_on_cuddle)
	%NapButton.pressed.connect(_on_nap)
	%PhotoBookButton.pressed.connect(_on_photo_book)
	_refresh_friend()

func _refresh_background() -> void:
	if not PetalState.perch_items().is_empty():
		background.texture = load(PetalState.perch_background_path())
	else:
		background.texture = load(PetalState.room_bg("bedroom", "res://Sprites/backgrounds/bedroom.jpg"))

# Small "on/off" buttons for each perch decoration (bed/toy/feeder), built
# dynamically since this scene is shared by every pet and most have none.
func _build_perch_toggles() -> void:
	var items := PetalState.perch_items()
	if items.is_empty():
		return
	var labels := {"bed": "🛏️ Bed", "toy": "🔔 Toy", "feeder": "🍽️ Feeder"}
	var row := HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.offset_left = -180.0
	row.offset_right = 180.0
	row.offset_top = 66.0
	row.offset_bottom = 106.0
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	var decor: Dictionary = PetalState.perch_decor()
	for id in items:
		var btn := Button.new()
		btn.text = String(labels.get(id, id))
		btn.toggle_mode = true
		btn.button_pressed = decor.get(id, true)
		btn.custom_minimum_size = Vector2(110, 40)
		btn.pressed.connect(_on_perch_toggle.bind(id))
		row.add_child(btn)

func _on_perch_toggle(id: String) -> void:
	PetalState.toggle_perch_item(id)
	_refresh_background()

# Every other room just sits the pet in a generic corner box, but Kiwi's
# perch art has actual branches to land on, so she (and any visiting friend)
# get moved onto them instead of floating in the usual bottom-left corner.
# Boxes are fractions of the room's canvas, hand-picked against the perch
# artwork: Kiwi on the swing seat, her friend on the lower ladder branch.
const PERCH_PETAL_BOX := Rect2(0.594, 0.295, 0.061, 0.080)
const PERCH_FRIEND_BOX := Rect2(0.364, 0.456, 0.078, 0.063)

func _place_on_perch_if_kiwi() -> void:
	if PetalState.perch_items().is_empty():
		return
	_apply_perch_box(%Petal, PERCH_PETAL_BOX)
	_apply_perch_box(%Friend, PERCH_FRIEND_BOX)

func _apply_perch_box(node: TextureRect, box: Rect2) -> void:
	node.anchor_left = box.position.x
	node.anchor_top = box.position.y
	node.anchor_right = box.position.x + box.size.x
	node.anchor_bottom = box.position.y + box.size.y
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0
	node.grow_horizontal = Control.GROW_DIRECTION_BOTH
	node.grow_vertical = Control.GROW_DIRECTION_BOTH

# Whoever's visiting (see room_living.gd) rests here too, alongside the pet -
# just a quiet presence to pet, no walk-in/play minigame like the living room.
func _refresh_friend() -> void:
	var visiting: String = PetalState.visiting_friend
	if visiting == "":
		%Friend.visible = false
		return
	%Friend.texture = load(PetalState.FRIENDS[visiting]["cutout"])
	%Friend.visible = true
	%Friend.mouse_filter = Control.MOUSE_FILTER_STOP
	if not %Friend.gui_input.is_connected(_on_friend_input):
		%Friend.gui_input.connect(_on_friend_input)

func _on_friend_input(event: InputEvent) -> void:
	var is_click: bool = event is InputEventMouseButton and event.pressed
	var is_touch: bool = event is InputEventScreenTouch and event.pressed
	if not (is_click or is_touch):
		return
	PetalState.pet_friend()
	Feedback.pop(self, PetalState.friend_reactions(PetalState.visiting_friend).pick_random(), %Friend.global_position + Vector2(60, 20))
	_bounce_friend()

func _bounce_friend() -> void:
	%Friend.pivot_offset = %Friend.size / 2.0
	var tween := create_tween()
	tween.tween_property(%Friend, "scale", Vector2(1.12, 0.9), 0.08)
	tween.tween_property(%Friend, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_ELASTIC)

func _on_cuddle() -> void:
	PetalState.cuddle()
	PetCameo.jump_for_joy(%Petal)
	Feedback.pop(self, "🥰 +hugs", %CuddleButton.global_position)

func _on_nap() -> void:
	PetalState.nap()
	PetCameo.sleep(%Petal)
	Feedback.pop(self, "💤 zzz", %NapButton.global_position)

func _on_photo_book() -> void:
	PetalState.navigate_to_room.emit("photobook")
