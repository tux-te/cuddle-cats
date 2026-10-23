extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")

const FISH_MIN_WAIT := 1.5
const FISH_MAX_WAIT := 3.5
const FISH_BITE_WINDOW := 1.6

const FISH_COLORS := [
	{"name": "Blue", "color": Color(0.35, 0.6, 1.0)},
	{"name": "Orange", "color": Color(1.0, 0.55, 0.15)},
	{"name": "Golden", "color": Color(1.0, 0.85, 0.2)},
	{"name": "Purple", "color": Color(0.7, 0.4, 0.95)},
	{"name": "Green", "color": Color(0.35, 0.85, 0.5)},
	{"name": "Pink", "color": Color(1.0, 0.55, 0.75)},
]

# What can be on the line. Rarer catches pay extra coins and get a bigger fuss.
const CATCHES := [
	{"emoji": "🐟", "weight": 40, "bonus": 0},
	{"emoji": "🐠", "weight": 25, "bonus": 0},
	{"emoji": "🐡", "weight": 15, "bonus": 1},
	{"emoji": "🦀", "weight": 8, "bonus": 2},
	{"emoji": "🐙", "weight": 6, "bonus": 3},
	{"emoji": "🐳", "weight": 4, "bonus": 5},
	{"emoji": "🦄", "weight": 2, "bonus": 10},
]
const MAX_NIBBLES := 2

enum FishState { IDLE, WAITING, BITING, SHOWING, READY_TO_RELEASE }

@onready var fish_button: Button = %FishButton
@onready var fish_display: Label = %FishDisplay
@onready var rod_sprite: TextureRect = %RodSprite
@onready var back_button: Button = %BackButton
@onready var swim_button: Button = %SwimButton
@onready var swim_sprite: TextureRect = %SwimSprite

var rod_frames: Array[Texture2D] = []
var fish_state: FishState = FishState.IDLE
var is_swimming := false

func _ready() -> void:
	for i in range(10):
		rod_frames.append(load("res://Sprites/fishing_rod/frame_%02d.png" % i))

	PetCameo.spawn(%Petal)
	fish_button.pressed.connect(_on_fish)
	back_button.pressed.connect(_on_back)

	swim_button.visible = PetalState.has_anim("swim")
	swim_button.pressed.connect(_on_swim)

func _on_back() -> void:
	PetalState.navigate_to_room.emit("garden")

func _on_swim() -> void:
	if is_swimming or not PetalState.has_anim("swim"):
		return
	is_swimming = true
	swim_button.disabled = true
	Feedback.pop(self, "🏊 splash!", swim_button.global_position)

	# She swims out in the lake itself, not on the bank where she normally
	# stands - swap in a sprite positioned over the water for the dip.
	%Petal.visible = false
	swim_sprite.visible = true
	var frames := PetalState.anim_frames("swim")
	for frame in frames:
		if not is_instance_valid(self):
			return
		swim_sprite.texture = frame
		await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(self):
		return
	swim_sprite.visible = false
	%Petal.visible = true
	PetalState.go_swimming()
	PetCameo.jump_for_joy(%Petal)
	swim_button.disabled = false
	is_swimming = false

func _on_fish() -> void:
	match fish_state:
		FishState.IDLE:
			_start_fishing()
		FishState.WAITING:
			Feedback.pop(self, "🎣 not yet...", fish_button.global_position)
		FishState.BITING:
			_catch_fish()
		FishState.SHOWING:
			_take_photo_with_fish()
		FishState.READY_TO_RELEASE:
			_release_fish()

func _play_rod_frames(frame_indices: Array, delay: float) -> void:
	for index in frame_indices:
		if not is_instance_valid(self):
			return
		rod_sprite.texture = rod_frames[index]
		await get_tree().create_timer(delay).timeout

func _start_fishing() -> void:
	fish_state = FishState.WAITING
	fish_button.disabled = true
	fish_button.text = "🎣 casting..."
	await _play_rod_frames([1, 2, 3, 4, 5], 0.08)
	if not is_instance_valid(self) or fish_state != FishState.WAITING:
		return
	fish_button.disabled = false
	fish_button.text = "🎣 waiting for a bite..."
	# A few cheeky nibbles first: tapping early is harmless, it just says "not yet".
	for i in randi() % (MAX_NIBBLES + 1):
		await get_tree().create_timer(randf_range(FISH_MIN_WAIT, FISH_MAX_WAIT) * 0.5).timeout
		if not is_instance_valid(self) or fish_state != FishState.WAITING:
			return
		Feedback.pop(self, "💦 nibble nibble...", fish_button.global_position)
		rod_sprite.texture = rod_frames[5 + (i % 2)]
	var wait_time := randf_range(FISH_MIN_WAIT, FISH_MAX_WAIT)
	await get_tree().create_timer(wait_time).timeout
	if not is_instance_valid(self) or fish_state != FishState.WAITING:
		return
	fish_state = FishState.BITING
	fish_button.text = "🐟 PULL BACK!"
	rod_sprite.texture = rod_frames[6]
	Feedback.pop(self, "🐟 bite!", fish_button.global_position)
	await get_tree().create_timer(FISH_BITE_WINDOW).timeout
	if not is_instance_valid(self) or fish_state != FishState.BITING:
		return
	fish_state = FishState.IDLE
	fish_button.text = "🎣 Fish"
	rod_sprite.texture = rod_frames[0]
	Feedback.pop(self, "the fish got away...", fish_button.global_position)

func _catch_fish() -> void:
	var caught: Dictionary = FISH_COLORS[randi() % FISH_COLORS.size()]
	var prize := _roll_catch()
	fish_state = FishState.SHOWING
	fish_button.disabled = true
	fish_button.text = "🎣 reeling in..."
	await _play_rod_frames([7, 8, 9], 0.1)
	if not is_instance_valid(self):
		return
	rod_sprite.texture = rod_frames[0]
	fish_display.text = prize["emoji"]
	fish_display.modulate = caught["color"]
	fish_display.visible = true
	fish_display.pivot_offset = fish_display.size / 2.0
	fish_display.scale = Vector2.ZERO
	var pop_in := create_tween()
	pop_in.tween_property(fish_display, "scale", Vector2.ONE * (1.0 + 0.1 * prize["bonus"]), 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if prize["bonus"] >= 5:
		# Big catches shimmer through the rainbow.
		var shimmer := create_tween().set_loops(3)
		for c in FISH_COLORS:
			shimmer.tween_property(fish_display, "modulate", c["color"], 0.15)
	if prize["bonus"] > 0:
		PetalState.add_coins(prize["bonus"])
	fish_button.disabled = false
	fish_button.text = "📸 Take a Photo"
	PetalState.catch_fish()
	PetCameo.jump_for_joy(%Petal)
	if prize["bonus"] >= 5:
		Feedback.pop(self, "✨ WOW! A super rare catch! +%d 🪙" % prize["bonus"], fish_display.global_position)
	elif prize["bonus"] > 0:
		Feedback.pop(self, "🌟 Ooh, a rare one! +%d 🪙" % prize["bonus"], fish_display.global_position)
	else:
		Feedback.pop(self, "👀 a %s fish!" % caught["name"], fish_display.global_position)

func _take_photo_with_fish() -> void:
	fish_state = FishState.READY_TO_RELEASE
	fish_button.text = "🌊 Let It Go"
	var image := get_viewport().get_texture().get_image()
	PetalState.take_photo(ImageTexture.create_from_image(image))
	Feedback.pop(self, "📸 say cheese!", fish_display.global_position)

func _release_fish() -> void:
	fish_state = FishState.IDLE
	fish_display.visible = false
	fish_button.text = "🎣 Fish"
	Feedback.pop(self, "🌊 back you go!", fish_button.global_position)

func _roll_catch() -> Dictionary:
	var total := 0
	for c in CATCHES:
		total += c["weight"]
	var roll := randi() % total
	for c in CATCHES:
		roll -= c["weight"]
		if roll < 0:
			return c
	return CATCHES[0]
