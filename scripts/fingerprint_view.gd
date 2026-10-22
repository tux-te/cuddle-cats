class_name FingerprintView
extends Control

# One fingerprint, drawn as ridge lines on a little paper card. `kind` is one
# of KINDS (empty shows the blank card). Used by the Mystery room's
# fingerprint lab (see fingerprint_lab.gd).

const KINDS := {
	"loop": "Loop",
	"whorl": "Swirl",
	"arch": "Hill",
	"tent": "Tent",
	"double": "Double swirl",
}

var kind := "":
	set(value):
		kind = value
		queue_redraw()
var ink := Color(0.2, 0.17, 0.4, 1)
# Each print is a little different: the seed tilts, shifts and wobbles the ridges.
var seed_value := 0:
	set(value):
		seed_value = value
		queue_redraw()
# While a finger is held down the ink spreads out from where it touched (pixels
# from the card's corner); a negative radius shows the whole print.
var reveal_radius := -1.0:
	set(value):
		reveal_radius = value
		queue_redraw()
var reveal_center := Vector2.ZERO
# A bright "scanner" line sweeping over the card (0..1 down the card), like a
# phone fingerprint unlock; negative hides it.
var scan_position := -1.0:
	set(value):
		scan_position = value
		queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(170, 190)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

# Ridge lines for a pattern, in a -1..1 box (y grows downwards).
static func ridges(which: String) -> Array:
	var lines: Array = []
	match which:
		"whorl":
			for i in range(8):
				lines.append(_ellipse(Vector2.ZERO, 0.12 + 0.11 * i, 0.14 + 0.125 * i))
		"loop":
			for i in range(6):
				var r := 0.18 + 0.14 * i
				var line := PackedVector2Array([Vector2(-r, 0.95)])
				line.append(Vector2(-r, 0.0))
				for step in range(1, 12):
					var a := PI * step / 12.0
					line.append(Vector2(-r * cos(a), -r * sin(a)))
				line.append(Vector2(r, 0.0))
				line.append(Vector2(r, 0.95))
				lines.append(line)
			lines.append(_ellipse(Vector2(0, 0.05), 0.07, 0.12))
		"arch":
			for i in range(8):
				var y := -0.15 + 0.14 * i
				lines.append(_curve(func(x: float) -> float: return y - 0.4 * (1.0 - x * x)))
		"tent":
			for i in range(8):
				var y := -0.05 + 0.14 * i
				lines.append(_curve(func(x: float) -> float: return y - 0.75 * (1.0 - absf(x))))
		"double":
			for i in range(3):
				lines.append(_ellipse(Vector2(0, 0), 0.62 + 0.14 * i, 0.82 + 0.06 * i))
			for i in range(3):
				lines.append(_ellipse(Vector2(-0.18, -0.22), 0.1 + 0.1 * i, 0.1 + 0.1 * i))
				lines.append(_ellipse(Vector2(0.18, 0.24), 0.1 + 0.1 * i, 0.1 + 0.1 * i))
	return lines

static func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var line := PackedVector2Array()
	for step in range(25):
		var a := TAU * step / 24.0
		line.append(center + Vector2(rx * cos(a), ry * sin(a)))
	return line

static func _curve(height: Callable) -> PackedVector2Array:
	var line := PackedVector2Array()
	for step in range(21):
		var x := -0.9 + 1.8 * step / 20.0
		line.append(Vector2(x, height.call(x)))
	return line

func _draw() -> void:
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.99, 0.97, 0.92)
	card.set_corner_radius_all(14)
	card.set_border_width_all(2)
	card.border_color = Color(0.6, 0.55, 0.75)
	draw_style_box(card, Rect2(Vector2.ZERO, size))
	if kind == "":
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(0, size.y * 0.58), "?", HORIZONTAL_ALIGNMENT_CENTER, size.x, 64, Color(0.6, 0.55, 0.75, 0.6))
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tilt := rng.randf_range(-0.22, 0.22)
	var shift := Vector2(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.06, 0.06))
	var phase_a := rng.randf_range(0.0, TAU)
	var phase_b := rng.randf_range(0.0, TAU)
	var wobble := rng.randf_range(0.01, 0.03)
	var centre := size / 2.0
	var scale := Vector2(size.x * 0.42, size.y * 0.42)
	for line in ridges(kind):
		var points := PackedVector2Array()
		for p in line:
			var q: Vector2 = p + Vector2(sin(p.y * 6.0 + phase_a), cos(p.x * 6.0 + phase_b)) * wobble
			points.append(centre + (q.rotated(tilt) + shift) * scale)
		_draw_inked(points)
	if scan_position >= 0.0:
		var y := size.y * (0.08 + 0.84 * scan_position)
		draw_line(Vector2(8, y), Vector2(size.x - 8, y), Color(0.3, 0.9, 1.0, 0.9), 4.0, true)

# Draws only the stretches of a ridge the spreading ink has reached.
func _draw_inked(points: PackedVector2Array) -> void:
	if reveal_radius < 0.0:
		draw_polyline(points, ink, 3.0, true)
		return
	var run := PackedVector2Array()
	for point in points:
		if point.distance_to(reveal_center) <= reveal_radius:
			run.append(point)
		else:
			if run.size() > 1:
				draw_polyline(run, ink, 3.0, true)
			run = PackedVector2Array()
	if run.size() > 1:
		draw_polyline(run, ink, 3.0, true)
