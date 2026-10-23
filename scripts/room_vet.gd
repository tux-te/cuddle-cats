extends Control

# A visit to the vet. Weigh the pet, measure her, listen to her heartbeat,
# give her a brave little shot and check her teeth. Finish all five for a
# check-up certificate, a sticker and a bonus. Nothing here can go wrong or
# hurt: the shot is a tiny pinch and a bandage, and she's always "so brave".

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const Confetti = preload("res://scripts/confetti.gd")

const STEPS := {
	"weigh": "⚖️ Weigh",
	"measure": "📏 Measure",
	"heart": "🩺 Heartbeat",
	"shot": "💉 Shot",
	"teeth": "🦷 Teeth",
}
# One painted clinic per kind of animal; small furry pets share the mouse one.
const BACKGROUNDS := {
	"cat": "res://Sprites/backgrounds/vet_cat.jpg",
	"dog": "res://Sprites/backgrounds/vet_dog.jpg",
	"bird": "res://Sprites/backgrounds/vet_bird.jpg",
	"gerbil": "res://Sprites/backgrounds/vet_mouse.jpg",
	"bunny": "res://Sprites/backgrounds/vet_mouse.jpg",
}
const TEETH_TAPS := 3
const TEXT_COLOR := Color(0.1, 0.4, 0.45)

var pet: TextureRect
var progress: Label
var hint: Label
var readout: Label
var buttons := {}
var done := {}
var busy := false
var teeth_taps := 0
var pet_home := Vector2.ZERO
var weight_kg := 0.0
var height_cm := 0
var bpm := 0

func _ready() -> void:
	# The same pet always weighs the same, so a visit feels like a real record.
	var seed_value := absi(PetalState.active_pet.hash())
	weight_kg = 2.5 + float(seed_value % 40) / 10.0
	height_cm = 20 + seed_value % 16
	bpm = 90 + seed_value % 30
	_build()
	await get_tree().process_frame
	pet_home = pet.position
	PetCameo.spawn(pet)

func _build() -> void:
	var bg_path := PetalState.room_bg("vet", BACKGROUNDS.get(PetalState.pet_species(), ""))
	if ResourceLoader.exists(bg_path):
		var bg := TextureRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.texture = load(bg_path)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(bg)
	else:
		# Plain pastel clinic until there's a painted background.
		var bg := ColorRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.color = Color(0.82, 0.95, 0.95)
		add_child(bg)
		var floor_strip := ColorRect.new()
		floor_strip.anchor_top = 0.72
		floor_strip.anchor_right = 1.0
		floor_strip.anchor_bottom = 1.0
		floor_strip.color = Color(0.7, 0.88, 0.9)
		add_child(floor_strip)

	var title := _label("🏥 Vet Check-up", 30, Vector2(20, 12))
	title.size = Vector2(420, 48)
	var back := Button.new()
	back.text = "⬅ Home"
	back.position = Vector2(20, 70)
	back.size = Vector2(160, 46)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func() -> void: PetalState.navigate_to_room.emit("living"))
	add_child(back)

	progress = _label("", 28, Vector2.ZERO)
	progress.set_anchors_preset(Control.PRESET_CENTER_TOP)
	progress.offset_left = -250.0
	progress.offset_right = 250.0
	progress.offset_top = 14.0
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Little wall chart so it looks like a clinic.
	var chart := _label("🩻   💊   🩹", 48, Vector2.ZERO)
	chart.set_anchors_preset(Control.PRESET_CENTER_TOP)
	chart.offset_left = -200.0
	chart.offset_right = 200.0
	chart.offset_top = 80.0
	chart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	pet = TextureRect.new()
	pet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pet.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pet.offset_left = -140.0
	pet.offset_right = 140.0
	pet.offset_top = -400.0
	pet.offset_bottom = -140.0
	pet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(pet)

	readout = _label("", 40, Vector2.ZERO)
	readout.set_anchors_preset(Control.PRESET_CENTER_TOP)
	readout.offset_left = -300.0
	readout.offset_right = 300.0
	readout.offset_top = 160.0
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readout.z_index = 5

	hint = _label("Tap each tool to give %s a check-up" % PetalState.pet_name, 22, Vector2.ZERO)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -400.0
	hint.offset_right = 400.0
	hint.offset_top = -150.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_left = -490.0
	row.offset_right = 490.0
	row.offset_top = -100.0
	row.offset_bottom = -20.0
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	for id in STEPS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(170, 80)
		b.add_theme_font_size_override("font_size", 20)
		b.text = STEPS[id]
		b.pressed.connect(_on_step.bind(id))
		row.add_child(b)
		buttons[id] = b
	_refresh_progress()

func _label(text: String, size: int, at: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT_COLOR)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _refresh_progress() -> void:
	progress.text = "Check-up %d / %d" % [done.size(), STEPS.size()]
	for id in buttons:
		buttons[id].text = ("✅ " if done.has(id) else "") + STEPS[id]

func _on_step(id: String) -> void:
	if busy:
		return
	busy = true
	match id:
		"weigh": await _weigh()
		"measure": await _measure()
		"heart": await _heartbeat()
		"shot": await _shot()
		"teeth": await _teeth()
	if not is_instance_valid(self):
		return
	busy = false

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _count_up(prefix: String, to_value: float, unit: String, decimals: int) -> void:
	readout.visible = true
	var steps := 14
	for i in range(1, steps + 1):
		var v := to_value * float(i) / float(steps)
		if i < steps:
			v += randf_range(-0.3, 0.3) * (1.0 - float(i) / float(steps))
		readout.text = "%s %s %s" % [prefix, String.num(maxf(v, 0.0), decimals), unit]
		await _wait(0.07)
		if not is_instance_valid(self):
			return

func _finish_step(id: String) -> void:
	done[id] = true
	_refresh_progress()
	PetalState.vet_step()
	if done.size() == STEPS.size():
		await _wait(0.8)
		if is_instance_valid(self):
			_certificate()

func _weigh() -> void:
	hint.text = "⚖️ Hop on the scale!"
	var scale_pad := _label("⚖️", 96, Vector2.ZERO)
	scale_pad.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	scale_pad.offset_left = -50.0
	scale_pad.offset_top = -230.0
	var tween := create_tween()
	tween.tween_property(pet, "position:y", pet_home.y - 30.0, 0.3)
	await tween.finished
	await _count_up("%s weighs" % PetalState.pet_name, weight_kg, "kg", 1)
	if not is_instance_valid(self):
		return
	readout.text = "%s weighs %.1f kg!" % [PetalState.pet_name, weight_kg]
	Feedback.pop(self, "⭐ perfect weight!", pet.global_position)
	await _wait(1.2)
	if not is_instance_valid(self):
		return
	scale_pad.queue_free()
	pet.position.y = pet_home.y
	readout.text = ""
	await _finish_step("weigh")

func _measure() -> void:
	hint.text = "📏 Stand up tall!"
	var tape := ColorRect.new()
	tape.color = Color(1, 0.85, 0.3)
	tape.size = Vector2(26, 0)
	tape.position = Vector2(pet.global_position.x + pet.size.x + 20.0, pet.global_position.y + pet.size.y)
	tape.z_index = 4
	add_child(tape)
	var rise := create_tween().set_parallel(true)
	rise.tween_property(tape, "size:y", pet.size.y * 0.9, 1.0)
	rise.tween_property(tape, "position:y", pet.global_position.y + pet.size.y * 0.1, 1.0)
	await _count_up("%s is" % PetalState.pet_name, float(height_cm), "cm tall", 0)
	if not is_instance_valid(self):
		return
	readout.text = "%s is %d cm tall!" % [PetalState.pet_name, height_cm]
	PetCameo.jump_for_joy(pet)
	await _wait(1.2)
	if not is_instance_valid(self):
		return
	tape.queue_free()
	readout.text = ""
	await _finish_step("measure")

func _heartbeat() -> void:
	hint.text = "🩺 Shhh... listen to her heart"
	var heart := _label("❤️", 90, Vector2.ZERO)
	heart.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	heart.offset_left = -45.0
	heart.offset_top = -420.0
	heart.pivot_offset = Vector2(45, 45)
	for i in range(6):
		Feedback.pop(self, "thump-thump" if i % 2 == 0 else "thump", heart.global_position + Vector2(100, 0))
		var beat := create_tween()
		beat.tween_property(heart, "scale", Vector2(1.4, 1.4), 0.12)
		beat.tween_property(heart, "scale", Vector2.ONE, 0.2)
		await _wait(0.6)
		if not is_instance_valid(self):
			return
	readout.text = "💓 %d beats a minute - strong and steady!" % bpm
	readout.add_theme_font_size_override("font_size", 30)
	await _wait(1.5)
	if not is_instance_valid(self):
		return
	heart.queue_free()
	readout.text = ""
	readout.add_theme_font_size_override("font_size", 40)
	await _finish_step("heart")

func _shot() -> void:
	hint.text = "💉 Just a tiny pinch... count with me!"
	for n in ["3...", "2...", "1..."]:
		readout.text = n
		await _wait(0.7)
		if not is_instance_valid(self):
			return
	readout.text = "All done! 🌟"
	Feedback.pop(self, "💪 so brave!", pet.global_position)
	var bandage := _label("🩹", 48, Vector2.ZERO)
	bandage.global_position = pet.global_position + Vector2(pet.size.x * 0.55, pet.size.y * 0.45)
	bandage.z_index = 6
	PetCameo.jump_for_joy(pet)
	Confetti.burst(self, pet.global_position + pet.size / 2.0, 14)
	await _wait(1.4)
	if not is_instance_valid(self):
		return
	readout.text = ""
	await _finish_step("shot")

func _teeth() -> void:
	# Three taps: "open wide", "brush brush", "sparkle".
	var prompts := ["😮 Open wide!", "🪥 Brush brush brush!", "✨ Sparkly clean!"]
	teeth_taps += 1
	readout.text = prompts[teeth_taps - 1]
	Feedback.pop(self, "🦷", pet.global_position + Vector2(pet.size.x / 2.0, 0))
	buttons["teeth"].text = "🦷 Teeth (%d/%d)" % [teeth_taps, TEETH_TAPS]
	if teeth_taps < TEETH_TAPS:
		hint.text = "Tap the 🦷 button again!"
		return
	teeth_taps = 0
	await _wait(1.0)
	if not is_instance_valid(self):
		return
	readout.text = ""
	await _finish_step("teeth")

func _certificate() -> void:
	PetalState.vet_checkup_complete()
	var name_text := PetalState.pet_name
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.1, 0.25, 0.3, 0.6)
	dim.z_index = 30
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.z_index = 31
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.98, 0.9)
	style.border_color = Color(1, 0.8, 0.3)
	style.set_border_width_all(8)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var lines := [
		["🏅 Check-up Certificate 🏅", 34],
		["%s is healthy and brave!" % name_text, 26],
		["⚖️ %.1f kg     📏 %d cm     💓 %d bpm" % [weight_kg, height_cm, bpm], 24],
		["💉 Shot done   🦷 Teeth sparkly", 24],
	]
	for line in lines:
		var l := Label.new()
		l.text = line[0]
		l.add_theme_font_size_override("font_size", line[1])
		l.add_theme_color_override("font_color", Color(0.25, 0.2, 0.15))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	var ok := Button.new()
	ok.text = "Yay! 🎉"
	ok.custom_minimum_size = Vector2(200, 60)
	ok.add_theme_font_size_override("font_size", 24)
	ok.pressed.connect(func() -> void:
		dim.queue_free()
		center.queue_free()
		done.clear()
		_refresh_progress()
		hint.text = "Tap each tool for another check-up")
	box.add_child(ok)
	Confetti.burst(self, get_viewport_rect().size / 2.0, 40)
