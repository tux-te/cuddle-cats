extends Control

# The Garden's weather is fetched live from Open-Meteo for Washington, DC
# each time the room opens. If it's rainy (or stormy), Princess Petal
# doesn't want to go outside and the Stroll button is disabled.

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")

const SUNNY_BG := "res://Sprites/backgrounds/garden_sunny.jpg"
const RAIN_BG := "res://Sprites/backgrounds/garden_rain.jpg"
const SNOW_BG := "res://Sprites/backgrounds/garden_snow.jpg"

const WEATHER_URL := "https://api.open-meteo.com/v1/forecast?latitude=38.9072&longitude=-77.0369&current_weather=true&temperature_unit=fahrenheit"

const RAIN_CODES := [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]
const SNOW_CODES := [71, 73, 75, 77, 85, 86]

const Confetti = preload("res://scripts/confetti.gd")

# Little visitors drift across the garden; tap one to catch it (and let it go).
const CRITTERS := ["🦋", "🐞", "🐝", "🐛", "🦗", "🐌"]
# Painted critters in Sprites/garden. When any are there they're used instead
# of the emoji above, so the two styles never mix in one garden.
const CRITTER_ART := {
	"🦋": "res://Sprites/garden/butterfly.png",
	"🐞": "res://Sprites/garden/ladybug.png",
	"🐝": "res://Sprites/garden/bee.png",
	"🐛": "res://Sprites/garden/caterpillar.png",
	"🦗": "res://Sprites/garden/cricket.png",
	"🐌": "res://Sprites/garden/snail.png",
}
const CRITTER_ART_HEIGHT := 90.0
const CRITTER_EVERY_MIN := 2.5
const CRITTER_EVERY_MAX := 5.0
const CRITTERS_FOR_BONUS := 5
# Tap the grass to plant one of these; they grow in and stay while you visit.
const FLOWERS := ["🌸", "🌼", "🌷", "🌻", "🌹", "🪻"]
const MAX_FLOWERS := 24
const FLOWERS_FOR_BONUS := 6
const STROLL_FINDS := [
	{"text": "🍓 found a berry!", "coins": 1},
	{"text": "🍄 found a mushroom!", "coins": 1},
	{"text": "🌰 found an acorn!", "coins": 1},
	{"text": "🪙 found a shiny coin!", "coins": 2},
	{"text": "💎 found a sparkly gem!", "coins": 3},
]

const WALK_LEFT_X := 200.0
const WALK_RIGHT_X := 1000.0

@onready var background: TextureRect = %Background
@onready var status_label: Label = %StatusLabel
@onready var stroll_button: Button = %StrollButton
@onready var fish_button: Button = %FishButton
@onready var http: HTTPRequest = %WeatherRequest

var walk_frames: Array[Texture2D] = []
var is_raining := false
var is_strolling := false
var critters_caught := 0
var flowers_planted := 0
var meadow: Control
var critter_timer: Timer

func _ready() -> void:
	walk_frames = PetalState.anim_frames("walk")

	background.texture = load(SUNNY_BG)
	PetCameo.spawn(%Petal)
	stroll_button.pressed.connect(_on_stroll)
	stroll_button.disabled = true
	status_label.text = "🌤️ Checking today's weather in Washington, DC..."

	fish_button.pressed.connect(_on_fish)
	# Only pets with swimming art get the pool.
	%SwimPoolButton.visible = PetalState.has_anim("swim")
	%SwimPoolButton.pressed.connect(func(): PetalState.navigate_to_room.emit("swimpool"))

	http.request_completed.connect(_on_weather_response)
	var err := http.request(WEATHER_URL)
	if err != OK:
		_use_fallback()

	_apply_season_tint()
	_build_meadow()

# A see-through layer over the grass that turns taps into flowers. It sits
# just above the background, so the pet, buttons and critters stay on top.
func _build_meadow() -> void:
	meadow = Control.new()
	meadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	meadow.mouse_filter = Control.MOUSE_FILTER_STOP
	meadow.gui_input.connect(_on_meadow_input)
	add_child(meadow)
	move_child(meadow, background.get_index() + 1)

	var hint := Label.new()
	hint.text = "👆 Tap the grass to plant flowers   🦋 Tap the critters!"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.2, 0.4, 0.2))
	hint.add_theme_color_override("font_outline_color", Color.WHITE)
	hint.add_theme_constant_override("outline_size", 5)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -400.0
	hint.offset_right = 400.0
	hint.offset_top = -150.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	critter_timer = Timer.new()
	critter_timer.one_shot = true
	critter_timer.timeout.connect(_spawn_critter)
	add_child(critter_timer)
	critter_timer.start(1.5)

func _on_meadow_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# Only the grass (lower part of the picture), not the sky.
	if event.position.y < size.y * 0.45:
		return
	_plant_flower(event.position)

func _plant_flower(at: Vector2) -> void:
	var flowers := get_tree().get_nodes_in_group("garden_flowers")
	if flowers.size() >= MAX_FLOWERS:
		flowers[0].queue_free()
	var flower := Label.new()
	flower.text = FLOWERS[randi() % FLOWERS.size()]
	flower.add_theme_font_size_override("font_size", 56)
	flower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flower.add_to_group("garden_flowers")
	add_child(flower)
	move_child(flower, meadow.get_index() + 1)
	flower.position = at - Vector2(28, 56)
	flower.pivot_offset = Vector2(28, 70)
	flower.scale = Vector2.ZERO
	var grow := create_tween()
	grow.tween_property(flower, "scale", Vector2(1.25, 1.25), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_property(flower, "scale", Vector2.ONE, 0.15)
	flowers_planted += 1
	if flowers_planted == FLOWERS_FOR_BONUS:
		Feedback.pop(self, "🌺 what a beautiful garden! +3 🪙", at)
		Confetti.burst(self, at, 24)
		PetalState.add_coins(3)
		PetCameo.jump_for_joy(%Petal)

func _spawn_critter() -> void:
	if is_instance_valid(self) and not is_raining:
		var kind := _pick_critter()
		var critter := _make_critter(kind)
		var from_left := randf() < 0.5
		var y := randf_range(size.y * 0.2, size.y * 0.65)
		var x_from := -100.0 if from_left else size.x + 40.0
		var x_to := size.x + 40.0 if from_left else -100.0
		critter.position = Vector2(x_from, y)
		critter.z_index = 5
		add_child(critter)
		var fly := create_tween().set_parallel(true)
		fly.tween_property(critter, "position:x", x_to, randf_range(5.0, 8.0))
		# A lazy wobble up and down as it drifts.
		var bob := create_tween().set_loops()
		bob.tween_property(critter, "position:y", y - 30.0, 0.5).set_trans(Tween.TRANS_SINE)
		bob.tween_property(critter, "position:y", y + 30.0, 0.5).set_trans(Tween.TRANS_SINE)
		critter.set_meta("bob", bob)
		fly.chain().tween_callback(func() -> void: _remove_critter(critter))
		critter.gui_input.connect(_on_critter_input.bind(critter))
	if is_instance_valid(self):
		critter_timer.start(randf_range(CRITTER_EVERY_MIN, CRITTER_EVERY_MAX))

# The emoji for a critter that has art, or any emoji when no art exists yet.
func _pick_critter() -> String:
	var with_art: Array = []
	for kind in CRITTER_ART:
		if ResourceLoader.exists(CRITTER_ART[kind]):
			with_art.append(kind)
	var pool: Array = with_art if not with_art.is_empty() else CRITTERS
	return pool[randi() % pool.size()]

func _make_critter(kind: String) -> Control:
	var path: String = CRITTER_ART.get(kind, "")
	if path != "" and ResourceLoader.exists(path):
		var pic := TextureRect.new()
		pic.texture = load(path)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tex_size: Vector2 = pic.texture.get_size()
		pic.size = Vector2(CRITTER_ART_HEIGHT * tex_size.x / tex_size.y, CRITTER_ART_HEIGHT)
		pic.mouse_filter = Control.MOUSE_FILTER_STOP
		pic.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pic.set_meta("kind", kind)
		return pic
	var label := Label.new()
	label.text = kind
	label.add_theme_font_size_override("font_size", 64)
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	label.set_meta("kind", kind)
	return label

func _remove_critter(critter: Control) -> void:
	if not is_instance_valid(critter):
		return
	var bob = critter.get_meta("bob", null)
	if bob is Tween:
		bob.kill()
	critter.queue_free()

func _on_critter_input(event: InputEvent, critter: Control) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if critter.has_meta("caught"):
		return
	critter.set_meta("caught", true)
	critters_caught += 1
	var at := critter.global_position
	Feedback.pop(self, "%s got you! +1 🪙" % critter.get_meta("kind"), at)
	Confetti.burst(self, at + Vector2(30, 30), 8)
	PetalState.catch_critter()
	_remove_critter(critter)
	if critters_caught == CRITTERS_FOR_BONUS:
		Feedback.pop(self, "🦋 Bug Buddy! They all love you!", %Petal.global_position)
		Confetti.burst(self, %Petal.global_position + Vector2(80, 40), 30)
		PetalState.critter_buddy()
		PetCameo.jump_for_joy(%Petal)

func _apply_season_tint() -> void:
	var month: int = Time.get_datetime_dict_from_system()["month"]
	var tint := Color(1, 1, 1)
	if month in [3, 4, 5]:
		tint = Color(0.95, 1.0, 0.93) # spring
	elif month in [6, 7, 8]:
		tint = Color(1.0, 0.98, 0.9) # summer
	elif month in [9, 10, 11]:
		tint = Color(1.0, 0.9, 0.78) # fall
	else:
		tint = Color(0.9, 0.95, 1.0) # winter
	background.modulate = tint

func _on_weather_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not is_instance_valid(self):
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_use_fallback()
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not (parsed is Dictionary) or not parsed.has("current_weather"):
		_use_fallback()
		return
	var current: Dictionary = parsed["current_weather"]
	var code := int(current.get("weathercode", 0))
	var temp = current.get("temperature", null)
	_apply_weather(code, temp)

func _apply_weather(code: int, temp) -> void:
	var temp_text := "%d°F" % int(round(temp)) if temp != null else ""
	if RAIN_CODES.has(code):
		is_raining = true
		background.texture = load(RAIN_BG)
		status_label.text = "🌧️ It's rainy in Washington, DC right now (%s)." % temp_text
	elif SNOW_CODES.has(code):
		is_raining = false
		background.texture = load(SNOW_BG)
		status_label.text = "❄️ It's snowing in Washington, DC right now (%s)." % temp_text
	else:
		is_raining = false
		background.texture = load(SUNNY_BG)
		status_label.text = "☀️ It's lovely in Washington, DC right now (%s)." % temp_text
	_refresh_stroll_button()

func _use_fallback() -> void:
	if not is_instance_valid(self):
		return
	is_raining = false
	background.texture = load(SUNNY_BG)
	status_label.text = "🌤️ Couldn't check today's weather - let's assume it's nice!"
	_refresh_stroll_button()

func _refresh_stroll_button() -> void:
	if is_raining:
		stroll_button.disabled = true
		stroll_button.text = "🌧️ Stay Inside"
		Feedback.pop(self, "🌧️ doesn't want wet %s!" % ("wings" if PetalState.PETS[PetalState.active_pet]["species"] == "bird" else "paws"), %Petal.global_position + Vector2(20, -20))
	else:
		stroll_button.disabled = false
		stroll_button.text = "🌷 Stroll"

func _on_stroll() -> void:
	if is_raining or is_strolling:
		return
	is_strolling = true
	stroll_button.disabled = true

	await _walk_to(WALK_RIGHT_X)
	if not is_instance_valid(self):
		return
	# Something turns up on every walk.
	var find: Dictionary = STROLL_FINDS[randi() % STROLL_FINDS.size()]
	Feedback.pop(self, find["text"], %Petal.global_position + Vector2(0, -30))
	PetalState.add_coins(find["coins"])
	PetCameo.jump_for_joy(%Petal)
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(self):
		return
	await _walk_to(WALK_LEFT_X)

	if not is_instance_valid(self):
		return
	PetalState.stroll()
	Feedback.pop(self, "🌼 lovely stroll!", stroll_button.global_position)
	stroll_button.disabled = is_raining
	is_strolling = false

func _on_fish() -> void:
	PetalState.navigate_to_room.emit("fishing")

func _walk_to(target_x: float) -> void:
	var start_x: float = %Petal.position.x
	var steps := 14
	for i in range(steps):
		if not walk_frames.is_empty():
			%Petal.texture = walk_frames[i % walk_frames.size()]
		%Petal.position.x = lerp(start_x, target_x, float(i + 1) / float(steps))
		if start_x > target_x:
			%Petal.scale.x = -1.0
		else:
			%Petal.scale.x = 1.0
		await get_tree().create_timer(0.05).timeout
		if not is_instance_valid(self):
			return
