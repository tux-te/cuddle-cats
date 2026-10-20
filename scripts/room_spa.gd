extends Control

# A calm room to pamper a pet. Tap her to brush her fur, switch the bubbles
# on and off, drag the cucumber slices onto her eyes, then put her to sleep.
# Doing all four in one visit is a full Spa Day: a sticker and a bonus.

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const Confetti = preload("res://scripts/confetti.gd")

const BRUSH_TAPS := 4
const BUBBLE_SECONDS := 3.0
const MASK_SECONDS := 3.0
const SLEEP_SECONDS := 4.0
const TRAY_POS := Vector2(1010, 330)
const TREATMENTS := ["brush", "bubbles", "mask", "sleep"]

@onready var background: TextureRect = %Background
@onready var dim: ColorRect = %Dim
@onready var progress: Label = %Progress
@onready var hint: Label = %Hint
@onready var pet: TextureRect = %Petal
@onready var bubble_button: Button = %BubbleButton
@onready var sleep_button: Button = %SleepButton

var done := {}
var brush_taps := 0
var bubbles_on := false
var bubble_time := 0.0
var sleeping := false
var cucumbers: Label = null
var dragging := false
var drag_offset := Vector2.ZERO
var mask_on := false

func _ready() -> void:
	background.texture = load(PetalState.room_bg("spa", "res://Sprites/backgrounds/grooming_room.jpg"))
	PetCameo.spawn(pet)
	pet.mouse_filter = Control.MOUSE_FILTER_STOP
	pet.gui_input.connect(_on_pet_input)
	%BackButton.pressed.connect(func() -> void: PetalState.navigate_to_room.emit("grooming"))
	bubble_button.pressed.connect(_toggle_bubbles)
	sleep_button.pressed.connect(_sleep)

	cucumbers = Label.new()
	cucumbers.text = "🥒🥒"
	cucumbers.add_theme_font_size_override("font_size", 64)
	cucumbers.position = TRAY_POS
	cucumbers.mouse_filter = Control.MOUSE_FILTER_STOP
	cucumbers.gui_input.connect(_on_cucumber_input)
	add_child(cucumbers)

	var bubble_timer := Timer.new()
	bubble_timer.wait_time = 0.25
	bubble_timer.autostart = true
	bubble_timer.timeout.connect(_bubble_tick)
	add_child(bubble_timer)

	hint.text = "👆 Tap her to brush   🥒 Drag the cucumbers to her eyes"
	_refresh_progress()

func _refresh_progress() -> void:
	var stars := ""
	for id in TREATMENTS:
		stars += "⭐" if done.has(id) else "▫️"
	progress.text = stars

# Marks a treatment finished; the fourth one in a visit wins the Spa Day.
func _finish(id: String, message: String) -> void:
	PetalState.spa_treatment()
	Feedback.pop(self, message, pet.global_position + Vector2(40, -20))
	if done.has(id):
		return
	done[id] = true
	_refresh_progress()
	if done.size() == TREATMENTS.size():
		PetalState.spa_day_complete()
		Confetti.burst(self, pet.global_position + pet.size / 2.0, 30)
		Feedback.pop(self, "💆 Spa Day complete!", pet.global_position + Vector2(-20, -60))

func _centre() -> Vector2:
	return pet.global_position + pet.size / 2.0

# Floats one little emoji up from around the pet.
func _drift(emoji: String, spread: float) -> void:
	var label := Label.new()
	label.text = emoji
	label.add_theme_font_size_override("font_size", 34)
	label.z_index = 10
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = _centre() + Vector2(randf_range(-spread, spread), randf_range(-20.0, 70.0))
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 150.0, 1.4)
	tween.tween_property(label, "modulate:a", 0.0, 1.4)
	tween.chain().tween_callback(label.queue_free)

# --- Brush: tap her ---------------------------------------------------------

func _on_pet_input(event: InputEvent) -> void:
	if sleeping or not (event is InputEventMouseButton and event.pressed):
		return
	for i in range(3):
		_drift("✨", 80.0)
	PetCameo.cuddle(pet)
	brush_taps += 1
	if brush_taps % BRUSH_TAPS == 0:
		_finish("brush", "✨ so soft")

# --- Bubbles: on / off ------------------------------------------------------

func _toggle_bubbles() -> void:
	if sleeping:
		return
	bubbles_on = not bubbles_on
	bubble_button.text = "🫧 Bubbles: on" if bubbles_on else "🫧 Bubbles: off"

func _bubble_tick() -> void:
	if not bubbles_on:
		return
	_drift("🫧", 150.0)
	bubble_time += 0.25
	if bubble_time >= BUBBLE_SECONDS:
		bubble_time = 0.0
		_finish("bubbles", "🫧 bubbly!")

# --- Face mask: drag the cucumbers onto her eyes ----------------------------

func _eye_zone() -> Rect2:
	return Rect2(pet.global_position + Vector2(pet.size.x * 0.1, 0), Vector2(pet.size.x * 0.8, pet.size.y * 0.5))

func _on_cucumber_input(event: InputEvent) -> void:
	if sleeping or mask_on:
		return
	if event is InputEventMouseButton:
		if event.pressed:
			dragging = true
			drag_offset = cucumbers.position - cucumbers.get_parent().get_local_mouse_position()
		elif dragging:
			dragging = false
			_drop_cucumbers()
	elif event is InputEventMouseMotion and dragging:
		cucumbers.position = get_local_mouse_position() + drag_offset

func _drop_cucumbers() -> void:
	if _eye_zone().has_point(get_global_mouse_position()):
		mask_on = true
		cucumbers.position = pet.global_position + Vector2(pet.size.x * 0.28, pet.size.y * 0.16)
		cucumbers.z_index = 5
		for i in range(3):
			_drift("✨", 90.0)
		await get_tree().create_timer(MASK_SECONDS).timeout
		if not is_instance_valid(self):
			return
		_finish("mask", "🥒 so fresh!")
		cucumbers.z_index = 0
		mask_on = false
	create_tween().tween_property(cucumbers, "position", TRAY_POS, 0.3)

# --- Sleep ------------------------------------------------------------------

func _sleep() -> void:
	if sleeping or mask_on:
		return
	sleeping = true
	sleep_button.disabled = true
	dim.visible = true
	create_tween().tween_property(dim, "modulate:a", 1.0, 0.6)
	PetCameo.sleep(pet)
	for i in range(4):
		_drift("💤", 60.0)
		await get_tree().create_timer(0.7).timeout
		if not is_instance_valid(self):
			return
	await get_tree().create_timer(SLEEP_SECONDS - 2.8).timeout
	if not is_instance_valid(self):
		return
	PetCameo.wake(pet)
	_finish("sleep", "💤 sweet dreams")
	var tween := create_tween()
	tween.tween_property(dim, "modulate:a", 0.0, 0.6)
	await tween.finished
	if is_instance_valid(self):
		dim.visible = false
		sleeping = false
		sleep_button.disabled = false
