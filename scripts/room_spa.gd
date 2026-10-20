extends Control

# A calm room to pamper a pet: massage, face mask, bubbles, then a sleep under
# a dimmed sky. Each treatment helps a little; doing all four in one visit
# is a full Spa Day, which earns a sticker and a bonus.

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const Confetti = preload("res://scripts/confetti.gd")

const SLEEP_SECONDS := 4.0

@onready var background: TextureRect = %Background
@onready var dim: ColorRect = %Dim
@onready var progress: Label = %Progress
@onready var pet: TextureRect = %Petal

var treatments := {}
var done := {}
var busy := false

func _ready() -> void:
	treatments = {
		"massage": %MassageButton,
		"mask": %MaskButton,
		"bubbles": %BubbleButton,
		"sleep": %SleepButton,
	}
	background.texture = load(PetalState.room_bg("spa", "res://Sprites/backgrounds/grooming_room.jpg"))
	PetCameo.spawn(pet)
	%BackButton.pressed.connect(func() -> void: PetalState.navigate_to_room.emit("grooming"))
	%MassageButton.pressed.connect(_treat.bind("massage", "💆 ahhh...", _massage))
	%MaskButton.pressed.connect(_treat.bind("mask", "🥒 so fresh!", _mask))
	%BubbleButton.pressed.connect(_treat.bind("bubbles", "🫧 bubbly!", _bubbles))
	%SleepButton.pressed.connect(_treat.bind("sleep", "💤 sweet dreams", _sleep))
	_refresh_progress()

func _refresh_progress() -> void:
	var stars := ""
	for id in treatments:
		stars += "⭐" if done.has(id) else "▫️"
	progress.text = stars

func _treat(id: String, message: String, effect: Callable) -> void:
	if busy:
		return
	busy = true
	_set_buttons_disabled(true)
	Feedback.pop(self, message, pet.global_position + Vector2(40, -20))
	await effect.call()
	if not is_instance_valid(self):
		return
	PetalState.spa_treatment()
	var first_time := not done.has(id)
	done[id] = true
	_refresh_progress()
	if first_time and done.size() == treatments.size():
		PetalState.spa_day_complete()
		Confetti.burst(self, pet.global_position + pet.size / 2.0, 30)
		Feedback.pop(self, "💆 Spa Day complete!", pet.global_position + Vector2(-20, -60))
	busy = false
	_set_buttons_disabled(false)

func _set_buttons_disabled(value: bool) -> void:
	for id in treatments:
		treatments[id].disabled = value

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

# Floats little emoji up from around the pet.
func _drift(emoji: String, count: int, spread: float) -> void:
	var centre := pet.global_position + pet.size / 2.0
	for i in range(count):
		if not is_instance_valid(self):
			return
		var label := Label.new()
		label.text = emoji
		label.add_theme_font_size_override("font_size", 34)
		label.z_index = 10
		label.position = centre + Vector2(randf_range(-spread, spread), randf_range(-20.0, 60.0))
		add_child(label)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(label, "position:y", label.position.y - 140.0, 1.4)
		tween.tween_property(label, "modulate:a", 0.0, 1.4)
		tween.chain().tween_callback(label.queue_free)
		await _wait(0.22)

func _massage() -> void:
	PetCameo.cuddle(pet)
	await _drift("💗", 6, 90.0)
	await _wait(0.4)

func _mask() -> void:
	var cucumbers := Label.new()
	cucumbers.text = "🥒  🥒"
	cucumbers.add_theme_font_size_override("font_size", 40)
	cucumbers.position = pet.global_position + Vector2(pet.size.x * 0.28, pet.size.y * 0.18)
	cucumbers.z_index = 10
	add_child(cucumbers)
	await _drift("✨", 5, 90.0)
	await _wait(1.0)
	if is_instance_valid(cucumbers):
		cucumbers.queue_free()

func _bubbles() -> void:
	PetCameo.jump_for_joy(pet)
	await _drift("🫧", 9, 120.0)
	await _wait(0.4)

func _sleep() -> void:
	dim.visible = true
	create_tween().tween_property(dim, "modulate:a", 1.0, 0.6)
	PetCameo.sleep(pet)
	await _drift("💤", 5, 60.0)
	await _wait(SLEEP_SECONDS - 1.2)
	if not is_instance_valid(self):
		return
	PetCameo.wake(pet)
	var tween := create_tween()
	tween.tween_property(dim, "modulate:a", 0.0, 0.6)
	await tween.finished
	if is_instance_valid(self):
		dim.visible = false
