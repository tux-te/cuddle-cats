extends "res://scripts/room_vet.gd"

# A grooming appointment: trim the nails, brush, wash, blow-dry and finish
# with a pretty bow. Same flow as the vet visit (see room_vet.gd), and just
# as gentle - the clippers only ever snip a tiny bit of nail.

const GROOM_STEPS := {
	"nails": "✂️ Nails",
	"brush": "🪮 Brush",
	"wash": "🛁 Wash",
	"dry": "💨 Blow-dry",
	"style": "🎀 Style",
}
const NAIL_TAPS := 4
const BRUSH_TAPS := 4
const BOWS := ["🎀", "🌸", "⭐", "💎", "🌈"]
const GROOMING_BG := "res://Sprites/backgrounds/grooming_room.jpg"

var nail_taps := 0
var brush_taps := 0

func _steps() -> Dictionary:
	return GROOM_STEPS

func _title() -> String:
	return "✂️ Groomer"

func _intro_hint() -> String:
	return "Tap each tool to make %s fluffy and fabulous" % PetalState.pet_name

func _progress_text() -> String:
	return "Grooming %d / %d" % [done.size(), GROOM_STEPS.size()]

func _background_path() -> String:
	return PetalState.room_bg("grooming", GROOMING_BG)

func _step_reward() -> void:
	PetalState.groomer_step()

func _complete_reward() -> void:
	PetalState.groomer_complete()

func _certificate_lines() -> Array:
	return [
		["✨ Groomed & Gorgeous ✨", 34],
		["%s looks fabulous!" % PetalState.pet_name, 26],
		["✂️ Nails   🪮 Brush   🛁 Wash   💨 Dry   🎀 Style", 24],
	]

func _run_step(id: String) -> void:
	match id:
		"nails": await _nails()
		"brush": await _brush()
		"wash": await _wash()
		"dry": await _dry()
		"style": await _style()

func _nails() -> void:
	nail_taps += 1
	readout.text = "✂️ snip! %s" % "🐾".repeat(nail_taps)
	Feedback.pop(self, "snip!", pet.global_position + Vector2(pet.size.x * randf_range(0.2, 0.8), pet.size.y * 0.85))
	buttons["nails"].text = "✂️ Nails (%d/%d)" % [nail_taps, NAIL_TAPS]
	if nail_taps < NAIL_TAPS:
		hint.text = "Tap the ✂️ button for the next paw!"
		return
	nail_taps = 0
	readout.text = "Four neat paws! 🐾🐾🐾🐾"
	PetCameo.jump_for_joy(pet)
	await _wait(1.2)
	if not is_instance_valid(self):
		return
	readout.text = ""
	await _finish_step("nails")

func _brush() -> void:
	brush_taps += 1
	readout.text = "🪮 brush brush..."
	Feedback.pop(self, "✨ so soft", pet.global_position + Vector2(pet.size.x * randf_range(0.2, 0.7), pet.size.y * 0.3))
	buttons["brush"].text = "🪮 Brush (%d/%d)" % [brush_taps, BRUSH_TAPS]
	if brush_taps < BRUSH_TAPS:
		hint.text = "Tap the 🪮 button again!"
		return
	brush_taps = 0
	readout.text = "Super soft and fluffy! ☁️"
	await _wait(1.2)
	if not is_instance_valid(self):
		return
	readout.text = ""
	await _finish_step("brush")

func _wash() -> void:
	hint.text = "🛁 Bubbles everywhere!"
	for i in range(6):
		var b := Label.new()
		b.text = "🫧"
		b.add_theme_font_size_override("font_size", randi_range(36, 70))
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.position = pet.global_position + Vector2(randf_range(0, pet.size.x - 40), randf_range(0, pet.size.y - 40))
		b.z_index = 8
		add_child(b)
		var t := create_tween().set_parallel(true)
		t.tween_property(b, "position:y", b.position.y - 120.0, 1.6)
		t.tween_property(b, "modulate:a", 0.0, 1.6)
		t.chain().tween_callback(b.queue_free)
		await _wait(0.35)
		if not is_instance_valid(self):
			return
	readout.text = "Squeaky clean! 🫧"
	await _wait(1.0)
	if not is_instance_valid(self):
		return
	readout.text = ""
	await _finish_step("wash")

func _dry() -> void:
	hint.text = "💨 Whoosh!"
	for i in range(8):
		var w := Label.new()
		w.text = "💨"
		w.add_theme_font_size_override("font_size", 56)
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		w.position = Vector2(pet.global_position.x - 120.0, pet.global_position.y + randf_range(0, pet.size.y - 40))
		w.z_index = 8
		add_child(w)
		var t := create_tween().set_parallel(true)
		t.tween_property(w, "position:x", pet.global_position.x + pet.size.x + 60.0, 0.9)
		t.tween_property(w, "modulate:a", 0.0, 0.9)
		t.chain().tween_callback(w.queue_free)
		var wiggle := create_tween()
		wiggle.tween_property(pet, "rotation_degrees", 4.0, 0.08)
		wiggle.tween_property(pet, "rotation_degrees", -4.0, 0.08)
		wiggle.tween_property(pet, "rotation_degrees", 0.0, 0.08)
		await _wait(0.3)
		if not is_instance_valid(self):
			return
	readout.text = "Fluffy and dry! ☀️"
	await _wait(1.0)
	if not is_instance_valid(self):
		return
	readout.text = ""
	await _finish_step("dry")

func _style() -> void:
	var bow := Label.new()
	bow.text = BOWS[randi() % BOWS.size()]
	bow.add_theme_font_size_override("font_size", 72)
	bow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bow.position = pet.global_position + Vector2(pet.size.x * 0.4, -10.0)
	bow.z_index = 6
	add_child(bow)
	Feedback.pop(self, "💖 fabulous!", pet.global_position)
	Confetti.burst(self, pet.global_position + pet.size / 2.0, 16)
	PetCameo.jump_for_joy(pet)
	await _wait(1.4)
	if not is_instance_valid(self):
		return
	await _finish_step("style")
