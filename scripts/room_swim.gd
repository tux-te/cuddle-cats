extends Control

# A pool for pets who can swim (see the "swim" frames in PetalState.PETS).
# She paddles laps across the water, then climbs out and hops for joy.

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")

const LAPS := 2

@onready var back_button: Button = %BackButton
@onready var swim_button: Button = %SwimButton
@onready var swim_sprite: TextureRect = %SwimSprite

var is_swimming := false

func _ready() -> void:
	PetCameo.spawn(%Petal)
	back_button.pressed.connect(func(): PetalState.navigate_to_room.emit("garden"))
	swim_button.pressed.connect(_on_swim)
	swim_button.visible = PetalState.has_anim("swim")

func _on_swim() -> void:
	if is_swimming or not PetalState.has_anim("swim"):
		return
	is_swimming = true
	swim_button.disabled = true
	Feedback.pop(self, "🏊 splash!", swim_button.global_position)

	# She swims in the pool itself, not on the deck where she normally sits.
	%Petal.visible = false
	swim_sprite.visible = true
	var frames := PetalState.anim_frames("swim")
	for _lap in range(LAPS):
		for frame in frames:
			if not is_instance_valid(self):
				return
			swim_sprite.texture = frame
			await get_tree().create_timer(0.3).timeout
	if not is_instance_valid(self):
		return
	swim_sprite.visible = false
	%Petal.visible = true
	PetalState.go_swimming()
	PetCameo.jump_for_joy(%Petal)
	swim_button.disabled = false
	is_swimming = false
