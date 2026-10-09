extends RefCounted

const Confetti = preload("res://scripts/confetti.gd")
const Sfx = preload("res://scripts/sfx.gd")

# Little celebration when a crown goes on - each style has its own: gold gets
# a fanfare and confetti, silver twinkles, the pink tiara floats hearts, and
# the flower crown rains petals. Pure tweens + emoji, no art needed.

const EMOJI := {
	"crown_silver": "✨",
	"crown_tiara": "💖",
	"crown_flower": "🌸",
}

static func play(room: Control, head: Vector2, crown_id: String) -> void:
	if not is_instance_valid(room):
		return
	match crown_id:
		"crown_gold":
			Sfx.fanfare(room)
			Confetti.burst(room, head, 28)
		"crown_silver":
			Sfx.chime(room)
			_twinkle(room, head, EMOJI[crown_id])
		"crown_tiara":
			Sfx.pop(room)
			_float_up(room, head, EMOJI[crown_id])
		"crown_flower":
			Sfx.pop(room)
			_rain_down(room, head, EMOJI[crown_id])

static func _spawn(room: Control, text: String, at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.position = at
	label.z_index = 20
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(label)
	return label

# Sparkles pop in and out in a ring around the crown.
static func _twinkle(room: Control, head: Vector2, text: String) -> void:
	for i in range(10):
		var angle := TAU * float(i) / 10.0
		var label := _spawn(room, text, head + Vector2(cos(angle), sin(angle) * 0.6) * randf_range(60.0, 110.0), randi_range(22, 38))
		label.modulate.a = 0.0
		var tween := room.create_tween()
		tween.tween_interval(randf_range(0.0, 0.5))
		tween.tween_property(label, "modulate:a", 1.0, 0.2)
		tween.tween_property(label, "modulate:a", 0.0, 0.4)
		tween.tween_callback(label.queue_free)

static func _float_up(room: Control, head: Vector2, text: String) -> void:
	for i in range(8):
		var label := _spawn(room, text, head + Vector2(randf_range(-70.0, 70.0), 0.0), randi_range(24, 40))
		var tween := room.create_tween()
		tween.set_parallel(true)
		tween.tween_property(label, "position:y", head.y - randf_range(90.0, 160.0), 1.1).set_delay(randf_range(0.0, 0.4))
		tween.tween_property(label, "modulate:a", 0.0, 1.1).set_delay(randf_range(0.0, 0.4))
		tween.chain().tween_callback(label.queue_free)

static func _rain_down(room: Control, head: Vector2, text: String) -> void:
	for i in range(12):
		var label := _spawn(room, text, head + Vector2(randf_range(-90.0, 90.0), -60.0), randi_range(22, 34))
		var tween := room.create_tween()
		tween.set_parallel(true)
		tween.tween_property(label, "position:y", head.y + randf_range(100.0, 180.0), 1.4).set_delay(randf_range(0.0, 0.6))
		tween.tween_property(label, "position:x", label.position.x + randf_range(-40.0, 40.0), 1.4).set_delay(randf_range(0.0, 0.6))
		tween.tween_property(label, "rotation_degrees", randf_range(-90.0, 90.0), 1.4).set_delay(randf_range(0.0, 0.6))
		tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(1.0)
		tween.chain().tween_callback(label.queue_free)
