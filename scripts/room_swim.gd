extends Control

# A pool for pets who can swim (see the "swim" frames in PetalState.PETS).
# She paddles laps across the water, then climbs out and hops for joy.

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")

const Confetti = preload("res://scripts/confetti.gd")
const Sfx = preload("res://scripts/sfx.gd")

const LAPS := 2

# Toys drift across the water; tap one to pop it (it squeaks and bubbles).
const TOYS := ["🦆", "🛟", "⚽", "🐠", "🐳", "🦀"]
const TOY_EVERY_MIN := 2.0
const TOY_EVERY_MAX := 4.0
const TOYS_FOR_BONUS := 5
const DROPLETS := 16

@onready var back_button: Button = %BackButton
@onready var swim_button: Button = %SwimButton
@onready var swim_sprite: TextureRect = %SwimSprite

var is_swimming := false
var toys_popped := 0
var toy_timer: Timer
var splash_button: Button

func _ready() -> void:
	PetCameo.spawn(%Petal)
	back_button.pressed.connect(func(): PetalState.navigate_to_room.emit("garden"))
	swim_button.pressed.connect(_on_swim)
	swim_button.visible = PetalState.has_anim("swim")
	_build_extras()

func _build_extras() -> void:
	splash_button = Button.new()
	splash_button.text = "💦 Splash!"
	splash_button.add_theme_font_size_override("font_size", 22)
	splash_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	splash_button.offset_left = -140.0 if not swim_button.visible else 160.0
	splash_button.offset_right = splash_button.offset_left + 200.0
	splash_button.offset_top = -110.0
	splash_button.offset_bottom = -20.0
	splash_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	splash_button.pressed.connect(_on_splash)
	add_child(splash_button)

	var hint := Label.new()
	hint.text = "👆 Pop the floating toys!"
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.1, 0.35, 0.6))
	hint.add_theme_color_override("font_outline_color", Color.WHITE)
	hint.add_theme_constant_override("outline_size", 5)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -300.0
	hint.offset_right = 300.0
	hint.offset_top = -150.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	toy_timer = Timer.new()
	toy_timer.one_shot = true
	toy_timer.timeout.connect(_spawn_toy)
	add_child(toy_timer)
	toy_timer.start(1.0)

func _spawn_toy() -> void:
	if not is_instance_valid(self):
		return
	var toy := Label.new()
	toy.text = TOYS[randi() % TOYS.size()]
	toy.add_theme_font_size_override("font_size", 64)
	toy.mouse_filter = Control.MOUSE_FILTER_STOP
	toy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toy.pivot_offset = Vector2(32, 40)
	toy.z_index = 5
	var from_left := randf() < 0.5
	var y := randf_range(size.y * 0.30, size.y * 0.62)
	var x_from := -90.0 if from_left else size.x + 30.0
	var x_to := size.x + 30.0 if from_left else -90.0
	toy.position = Vector2(x_from, y)
	add_child(toy)
	var drift := create_tween()
	drift.tween_property(toy, "position:x", x_to, randf_range(7.0, 11.0))
	drift.tween_callback(toy.queue_free)
	# Bobbing on the waves.
	var bob := create_tween().set_loops()
	bob.tween_property(toy, "position:y", y - 12.0, 0.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(toy, "position:y", y + 12.0, 0.6).set_trans(Tween.TRANS_SINE)
	toy.tree_exiting.connect(bob.kill)
	toy.gui_input.connect(_on_toy_input.bind(toy))
	toy_timer.start(randf_range(TOY_EVERY_MIN, TOY_EVERY_MAX))

func _on_toy_input(event: InputEvent, toy: Label) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if toy.has_meta("popped"):
		return
	toy.set_meta("popped", true)
	toys_popped += 1
	var at := toy.global_position
	Sfx.pop(self)
	Feedback.pop(self, "%s squeak! +1 🪙" % toy.text, at)
	_bubbles(at + Vector2(30, 30), 8)
	PetalState.pop_pool_toy()
	toy.queue_free()
	if toys_popped == TOYS_FOR_BONUS:
		Feedback.pop(self, "🎉 Pool Party!", %Petal.global_position)
		Confetti.burst(self, %Petal.global_position + Vector2(80, 40), 30)
		PetalState.pool_party()
		PetCameo.jump_for_joy(%Petal)

# A little burst of bubbles that float up and pop.
func _bubbles(at: Vector2, count: int) -> void:
	for _i in range(count):
		var b := Label.new()
		b.text = "🫧"
		b.add_theme_font_size_override("font_size", randi_range(24, 44))
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.position = at + Vector2(randf_range(-30, 30), randf_range(-10, 10))
		b.z_index = 8
		add_child(b)
		var t := create_tween().set_parallel(true)
		t.tween_property(b, "position:y", b.position.y - randf_range(60, 140), 1.0)
		t.tween_property(b, "position:x", b.position.x + randf_range(-30, 30), 1.0)
		t.tween_property(b, "modulate:a", 0.0, 1.0)
		t.chain().tween_callback(b.queue_free)

func _on_splash() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.55)
	Sfx.pop(self)
	for _i in range(DROPLETS):
		var d := Label.new()
		d.text = "💦" if randf() < 0.4 else "💧"
		d.add_theme_font_size_override("font_size", randi_range(28, 52))
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.position = center
		d.z_index = 8
		add_child(d)
		var peak := center + Vector2(randf_range(-380, 380), randf_range(-300, -120))
		var land := Vector2(peak.x + randf_range(-60, 60), center.y + randf_range(0, 60))
		var t := create_tween()
		t.tween_property(d, "position", peak, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(d, "position", land, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(d, "modulate:a", 0.0, 0.3).set_delay(0.5)
		t.tween_callback(d.queue_free)
	Feedback.pop(self, "💦 SPLASH!", splash_button.global_position)
	PetalState.splash()
	if not is_swimming:
		PetCameo.jump_for_joy(%Petal)

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
			# Bubbles trail behind her as she paddles.
			_bubbles(swim_sprite.global_position + swim_sprite.size * Vector2(0.4, 0.6), 2)
			await get_tree().create_timer(0.3).timeout
	if not is_instance_valid(self):
		return
	swim_sprite.visible = false
	%Petal.visible = true
	PetalState.go_swimming()
	PetCameo.jump_for_joy(%Petal)
	swim_button.disabled = false
	is_swimming = false
