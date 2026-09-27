extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")

@onready var background: TextureRect = %Background

func _ready() -> void:
	background.texture = load(PetalState.room_bg("bedroom", "res://Sprites/backgrounds/bedroom.jpg"))
	PetCameo.spawn(%Petal)
	%CuddleButton.pressed.connect(_on_cuddle)
	%NapButton.pressed.connect(_on_nap)
	%PhotoBookButton.pressed.connect(_on_photo_book)
	_refresh_friend()

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
