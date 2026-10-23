extends Control

# A calm room to pamper a pet. Tap her to brush her fur, switch the bubbles
# on and off, drag the cucumber slices onto her eyes, then put her to sleep.
# Doing all four in one visit is a full Spa Day: a sticker and a bonus.

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const Confetti = preload("res://scripts/confetti.gd")

const BRUSH_TAPS := 4
const BUBBLE_SECONDS := 3.0
const MASK_SECONDS := 60
const SLEEP_SECONDS := 4.0
const TRAY_POS := Vector2(1010, 330)
const HINT := "👆 Tap to brush   🧴 Tap the lotion, then rub her   🥒 Drag cucumbers to her eyes"
const TREATMENTS := ["brush", "lotion", "bubbles", "candles", "mask", "nails", "tea", "sleep"]
const LOTION_DISTANCE := 800.0
# How far one squirt of lotion lasts while rubbing (so it takes two squirts).
const SQUIRT_RUB_DISTANCE := 400.0
const BOTTLE_POS := Vector2(70, 250)
const BOTTLE_SIZE := Vector2(102, 180)
const CANDLE_SECONDS := 3.0
const NAIL_COLOURS := [Color(1, 0.4, 0.7), Color(0.65, 0.4, 1), Color(0.3, 0.7, 1), Color(1, 0.8, 0.2)]

@onready var background: TextureRect = %Background
@onready var dim: ColorRect = %Dim
@onready var progress: Label = %Progress
@onready var hint: Label = %Hint
@onready var pet: TextureRect = %Petal
@onready var bubble_button: Button = %BubbleButton
@onready var sleep_button: Button = %SleepButton
@onready var lotion_button: Button = %LotionButton
@onready var candle_button: Button = %CandleButton
@onready var nail_button: Button = %NailButton
@onready var tea_button: Button = %TeaButton

var done := {}
var brush_taps := 0
var bubbles_on := false
var bubble_time := 0.0
var sleeping := false
var cucumbers: Label = null
var dragging := false
var drag_offset := Vector2.ZERO
var mask_on := false
var lotion_on := false
var rub_distance := 0.0
var rub_since_dab := 0.0
var cream_left := 0.0
var cream_blobs: Array[Label] = []
var bottle: TextureButton = null
var candles_on := false
var candle_time := 0.0
var candle_nodes: Array[Label] = []
var glow: ColorRect = null
var nail_step := 0
var paws: Array[Label] = []
var tea_busy := false

func _ready() -> void:
	background.texture = load(PetalState.room_bg("spa", "res://Sprites/backgrounds/spa.jpg"))
	PetCameo.spawn(pet)
	pet.mouse_filter = Control.MOUSE_FILTER_STOP
	pet.gui_input.connect(_on_pet_input)
	%BackButton.pressed.connect(func() -> void: PetalState.navigate_to_room.emit("grooming"))
	bubble_button.pressed.connect(_toggle_bubbles)
	sleep_button.pressed.connect(_sleep)
	lotion_button.visible = false
	_build_bottle()
	candle_button.pressed.connect(_toggle_candles)
	nail_button.pressed.connect(_paint_nails)
	tea_button.pressed.connect(_serve_tea)
	_build_candles()

	cucumbers = Label.new()
	cucumbers.text = "🥒🥒"
	cucumbers.add_theme_font_size_override("font_size", 64)
	cucumbers.position = TRAY_POS
	cucumbers.mouse_filter = Control.MOUSE_FILTER_STOP
	cucumbers.gui_input.connect(_on_cucumber_input)
	add_child(cucumbers)

	glow = ColorRect.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.color = Color(1, 0.65, 0.25, 0.16)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.visible = false
	add_child(glow)
	move_child(glow, background.get_index() + 1)

	var bubble_timer := Timer.new()
	bubble_timer.wait_time = 0.25
	bubble_timer.autostart = true
	bubble_timer.timeout.connect(_bubble_tick)
	add_child(bubble_timer)

	hint.text = HINT
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
	if sleeping:
		return
	if lotion_on:
		_rub(event)
		return
	if not (event is InputEventMouseButton and event.pressed):
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
	if candles_on:
		candle_time += 0.25
		if candle_time >= CANDLE_SECONDS:
			candle_time = -1000.0
			_finish("candles", "🕯️ so cosy!")
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
		for left in range(MASK_SECONDS, 0, -1):
			hint.text = "🥒 Relaxing... %d" % left
			await get_tree().create_timer(1.0).timeout
			if not is_instance_valid(self):
				return
		hint.text = HINT
		_finish("mask", "🥒 so fresh!")
		cucumbers.z_index = 0
		mask_on = false
	create_tween().tween_property(cucumbers, "position", TRAY_POS, 0.3)

# --- Sleep ------------------------------------------------------------------

func _sleep() -> void:
	if sleeping:
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

# --- Lotion: switch it on, then rub her -------------------------------------

# The lotion bottle: tap it for a squirt on her fur, rub her to work it in, and
# tap it again when it has all been rubbed in to get more.
func _build_bottle() -> void:
	bottle = TextureButton.new()
	bottle.texture_normal = load("res://Sprites/spa_lotion_bottle.png")
	bottle.ignore_texture_size = true
	bottle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bottle.custom_minimum_size = BOTTLE_SIZE
	bottle.size = BOTTLE_SIZE
	bottle.position = BOTTLE_POS
	bottle.pivot_offset = Vector2(BOTTLE_SIZE.x / 2.0, BOTTLE_SIZE.y)
	bottle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bottle.pressed.connect(_squirt_lotion)
	add_child(bottle)

func _squirt_lotion() -> void:
	if sleeping:
		return
	_clear_cream()
	cream_left = 1.0
	lotion_on = true
	hint.text = "🧴 Rub her with your finger to rub the lotion in!"
	# The bottle gets squeezed...
	var squeeze := bottle.create_tween()
	squeeze.tween_property(bottle, "scale", Vector2(1.12, 0.84), 0.1)
	squeeze.tween_property(bottle, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC)
	# ...and blobs of lotion drop onto her fur.
	var nozzle := bottle.position + Vector2(BOTTLE_SIZE.x * 0.5, 10.0)
	for i in range(3):
		var blob := Label.new()
		blob.text = "🤍"
		blob.add_theme_font_size_override("font_size", 52)
		blob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blob.z_index = 6
		blob.position = nozzle
		blob.scale = Vector2(0.4, 0.4)
		add_child(blob)
		cream_blobs.append(blob)
		var target := pet.position + Vector2(pet.size.x * randf_range(0.3, 0.7), pet.size.y * randf_range(0.3, 0.7)) - Vector2(26, 26)
		var drop := blob.create_tween().set_parallel(true)
		drop.tween_property(blob, "position", target, 0.45).set_delay(0.12 * i).set_trans(Tween.TRANS_QUAD)
		drop.tween_property(blob, "scale", Vector2.ONE, 0.45).set_delay(0.12 * i)
	Feedback.pop(self, "🧴 squirt!", bottle.global_position + Vector2(0, -30))

func _clear_cream() -> void:
	for blob in cream_blobs:
		if is_instance_valid(blob):
			blob.queue_free()
	cream_blobs.clear()

func _rub(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		return
	var step: float = event.relative.length()
	rub_distance += step
	rub_since_dab += step
	cream_left = maxf(0.0, cream_left - step / SQUIRT_RUB_DISTANCE)
	# The lotion on her fur fades as it is rubbed in.
	for blob in cream_blobs:
		if is_instance_valid(blob):
			blob.modulate.a = clampf(cream_left * 1.5, 0.0, 1.0)
	if rub_since_dab >= 45.0:
		rub_since_dab = 0.0
		_dab(pet.global_position + get_local_mouse_position() - pet.position)
	if rub_distance >= LOTION_DISTANCE:
		rub_distance = 0.0
		cream_left = 0.0
		lotion_on = false
		_clear_cream()
		hint.text = HINT
		_drift("💗", 80.0)
		_finish("lotion", "🧴 so smooth!")
	elif cream_left <= 0.0:
		lotion_on = false
		_clear_cream()
		hint.text = "🧴 All rubbed in! Tap the lotion bottle for more!"
		var wiggle := bottle.create_tween()
		for angle in [-8.0, 8.0, -6.0, 6.0, 0.0]:
			wiggle.tween_property(bottle, "rotation_degrees", angle, 0.1)

# A little blob of cream that fades away.
func _dab(at: Vector2) -> void:
	var cream := Label.new()
	cream.text = "🤍"
	cream.add_theme_font_size_override("font_size", 30)
	cream.position = get_local_mouse_position() - Vector2(15, 20)
	cream.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cream.z_index = 6
	add_child(cream)
	var tween := create_tween()
	tween.tween_property(cream, "modulate:a", 0.0, 1.2)
	tween.tween_callback(cream.queue_free)

# --- Candles: on / off ------------------------------------------------------

func _build_candles() -> void:
	for x in [0.16, 0.26, 0.74, 0.84]:
		var candle := Label.new()
		candle.text = "🕯️"
		candle.add_theme_font_size_override("font_size", 56)
		candle.anchor_left = x
		candle.anchor_right = x
		candle.anchor_top = 0.62
		candle.anchor_bottom = 0.62
		candle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		candle.visible = false
		add_child(candle)
		candle_nodes.append(candle)

func _toggle_candles() -> void:
	if sleeping:
		return
	candles_on = not candles_on
	candle_time = 0.0
	candle_button.text = "🕯️ Candles: on" if candles_on else "🕯️ Candles: off"
	glow.visible = candles_on
	for candle in candle_nodes:
		candle.visible = candles_on
		if candles_on:
			var flicker := create_tween().set_loops()
			flicker.tween_property(candle, "scale", Vector2(1.08, 1.08), 0.35 + randf() * 0.2)
			flicker.tween_property(candle, "scale", Vector2(1.0, 1.0), 0.35 + randf() * 0.2)
			candle.set_meta("flicker", flicker)
		elif candle.has_meta("flicker"):
			candle.get_meta("flicker").kill()

# --- Nail polish: tap to paint her paws a new colour ------------------------

func _paint_nails() -> void:
	if sleeping:
		return
	if paws.is_empty():
		for x in [0.3, 0.62]:
			var paw := Label.new()
			paw.text = "●"
			paw.add_theme_font_size_override("font_size", 34)
			paw.position = Vector2(pet.size.x * x, pet.size.y * 0.8)
			paw.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pet.add_child(paw)
			paws.append(paw)
	var colour: Color = NAIL_COLOURS[nail_step % NAIL_COLOURS.size()]
	nail_step += 1
	for paw in paws:
		paw.add_theme_color_override("font_color", colour)
	for i in range(3):
		_drift("💅", 60.0)
	if nail_step == 1:
		_finish("nails", "💅 pretty paws!")

# --- Tea and snack ----------------------------------------------------------

func _serve_tea() -> void:
	if sleeping or tea_busy:
		return
	tea_busy = true
	tea_button.disabled = true
	var tray := Label.new()
	tray.text = "🍵🍓"
	tray.add_theme_font_size_override("font_size", 56)
	tray.position = pet.global_position + Vector2(pet.size.x * 0.55, pet.size.y * 0.45)
	tray.z_index = 8
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray)
	PetCameo.eat(pet)
	await get_tree().create_timer(1.6).timeout
	if not is_instance_valid(self):
		return
	tray.queue_free()
	_finish("tea", "😋 yummy!")
	tea_busy = false
	tea_button.disabled = false
