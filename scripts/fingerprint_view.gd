class_name FingerprintView
extends Control

# One print on a little paper card: a person's fingerprint (`kind` is one of
# KINDS; empty shows the blank card) or an animal's foot. Prints are painted
# pixel by pixel like real ink: dense ridges that change thickness, an uneven
# oval edge, tiny gaps where the ink skipped, and ragged edges on the feet.
# Used by the Mystery room's fingerprint lab (see fingerprint_lab.gd).

const KINDS := {
	"loop": "Loop",
	"whorl": "Swirl",
	"arch": "Hill",
	"tent": "Tent",
	"double": "Double swirl",
}

# Whose print this is: a person's "finger" (ridge patterns, see KINDS) or an
# animal's foot. The animal feet are drawn as ink stamps.
const FOOT_NAMES := {
	"finger": "Fingerprint", "paw": "Paw print", "hoof_split": "Hoof print (two toes)", "hoof_round": "Hoof print",
	"bird": "Bird foot print", "claw": "Clawed foot print", "trail": "Slime trail",
}
const PAPER := Color(0.99, 0.97, 0.92)
# The picture is painted a bit bigger than the card so it stays sharp.
const IMAGE_SCALE := 1.25
# Distance between two ridges (the print's box is -1..1 across).
const RIDGE_PERIOD := 0.07

var foot := "finger":
	set(value):
		foot = value
		queue_redraw()

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
# How much of the print shows, top to bottom (0..1) while the scanner sweeps
# down the card; a negative value shows all of it.
var reveal := -1.0:
	set(value):
		reveal = value
		queue_redraw()
# A bright "scanner" line sweeping over the card (0..1 down the card), like a
# phone fingerprint unlock; negative hides it.
var scan_position := -1.0:
	set(value):
		scan_position = value
		queue_redraw()

var _texture: ImageTexture
var _texture_key := ""

func _init() -> void:
	custom_minimum_size = Vector2(170, 190)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var card := StyleBoxFlat.new()
	card.bg_color = PAPER
	card.set_corner_radius_all(14)
	card.set_border_width_all(2)
	card.border_color = Color(0.6, 0.55, 0.75)
	draw_style_box(card, Rect2(Vector2.ZERO, size))
	if foot == "finger" and kind == "":
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(0, size.y * 0.58), "?", HORIZONTAL_ALIGNMENT_CENTER, size.x, 64, Color(0.6, 0.55, 0.75, 0.6))
		return
	if size.x < 8.0 or size.y < 8.0:
		return
	var tex := _get_texture()
	if reveal < 0.0 or reveal >= 1.0:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	elif reveal > 0.0:
		draw_texture_rect_region(tex, Rect2(0, 0, size.x, size.y * reveal), Rect2(0, 0, tex.get_width(), tex.get_height() * reveal))
	if scan_position >= 0.0:
		var y := size.y * (0.08 + 0.84 * scan_position)
		draw_line(Vector2(8, y), Vector2(size.x - 8, y), Color(0.3, 0.9, 1.0, 0.9), 4.0, true)

func _get_texture() -> ImageTexture:
	var w := int(size.x * IMAGE_SCALE)
	var h := int(size.y * IMAGE_SCALE)
	var key := "%s|%s|%d|%s|%d|%d" % [foot, kind, seed_value, ink.to_html(), w, h]
	if key != _texture_key:
		_texture_key = key
		_texture = ImageTexture.create_from_image(make_image(w, h))
	return _texture

# The print as a transparent picture: ink colour, alpha = how dark the ink is.
func make_image(w: int, h: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	var tilt := rng.randf_range(-0.25, 0.25)
	var shift := Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05))
	var prims: Array = _foot_prims(rng) if foot != "finger" else []
	var data := PackedByteArray()
	data.resize(w * h * 4)
	var r := int(ink.r * 255.0)
	var g := int(ink.g * 255.0)
	var b := int(ink.b * 255.0)
	var half := Vector2(w, h) / 2.0
	var unit := Vector2(0.42 * w, 0.42 * h)
	for y in range(h):
		for x in range(w):
			var p := (Vector2(x + 0.5, y + 0.5) - half) / unit
			var alpha: float
			if foot == "finger":
				alpha = _finger_alpha(p, noise, tilt, shift)
			else:
				alpha = _foot_alpha(p, noise, prims)
			if alpha > 0.004:
				var i := (y * w + x) * 4
				data[i] = r
				data[i + 1] = g
				data[i + 2] = b
				data[i + 3] = int(alpha * 255.0)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)

# --- Fingertips ------------------------------------------------------------

# A number that grows steadily away from the pattern's core: the ridges are
# the lines where it passes a whole multiple of RIDGE_PERIOD.
func _ridge_field(q: Vector2) -> float:
	match kind:
		"whorl":
			return sqrt(q.x * q.x * 1.15 + q.y * q.y) + 0.05 * atan2(q.y, q.x) / TAU
		"loop":
			# Distance from a line running down from the core: arches on top, straight ridges down the sides.
			return absf(q.x) if q.y > -0.1 else Vector2(q.x, q.y + 0.1).length()
		"arch":
			return q.y + 0.38 * exp(-q.x * q.x / 0.3)
		"tent":
			return q.y + 0.55 * exp(-absf(q.x) * 2.6)
		"double":
			var a := Vector2(-0.25, -0.3)
			var d := Vector2(0.5, 0.6)
			var t := clampf((q - a).dot(d) / d.length_squared(), 0.0, 1.0)
			return (q - (a + d * t)).length()
	return q.length()

func _finger_alpha(p: Vector2, noise: FastNoiseLite, tilt: float, shift: Vector2) -> float:
	var q := (p - shift).rotated(-tilt)
	var e := q.x * q.x / 0.72 + q.y * q.y / 0.9
	if e > 1.3:
		return 0.0
	# A fingertip is an oval with a rough, uneven edge.
	e += 0.16 * noise.get_noise_2d(p.x * 3.0 + 40.0, p.y * 3.0)
	var mask := 1.0 - smoothstep(0.7, 0.98, e)
	if mask <= 0.0:
		return 0.0
	var psi := _ridge_field(q) + 0.03 * noise.get_noise_2d(q.x * 1.6, q.y * 1.6 + 100.0)
	var wave := cos(TAU * psi / RIDGE_PERIOD + 0.9 * noise.get_noise_2d(q.x * 5.0 + 200.0, q.y * 5.0))
	# Ridges get thicker and thinner where the finger pressed harder or softer.
	var cut := -0.15 + 0.35 * noise.get_noise_2d(q.x * 2.5 + 300.0, q.y * 2.5)
	var ridge := smoothstep(cut - 0.22, cut + 0.22, wave)
	# Tiny gaps where the ink skipped (sweat pores).
	var gaps := smoothstep(0.3, 0.7, noise.get_noise_2d(q.x * 38.0 + 500.0, q.y * 38.0))
	var pressure := mask * (0.85 + 0.15 * noise.get_noise_2d(q.x * 2.0 + 700.0, q.y * 2.0))
	return clampf(ridge * (1.0 - 0.85 * gaps) * pressure, 0.0, 1.0) * 0.95

# --- Animal feet -----------------------------------------------------------

# A foot is a few shapes: ["e", cx, cy, rx, ry, rotation, is_hole] ellipses and
# ["c", ax, ay, bx, by, radius, is_hole] rounded lines.
func _foot_prims(rng: RandomNumberGenerator) -> Array:
	var rot := rng.randf_range(-0.15, 0.15)
	var prims: Array = []
	match foot:
		"paw":
			prims.append(["e", 0.0, 0.3, 0.46, 0.36, rot, false])
			for toe in [[-0.7, -0.1, -0.45], [-0.26, -0.5, -0.14], [0.26, -0.5, 0.14], [0.7, -0.1, 0.45]]:
				prims.append(["e", toe[0], toe[1], 0.17, 0.24, toe[2] + rot, false])
		"hoof_split":
			prims.append(["e", -0.3, 0.05, 0.25, 0.6, 0.1 + rot, false])
			prims.append(["e", 0.3, 0.05, 0.25, 0.6, -0.1 + rot, false])
			prims.append(["e", -0.4, 0.78, 0.08, 0.08, 0.0, false])
			prims.append(["e", 0.4, 0.78, 0.08, 0.08, 0.0, false])
		"hoof_round":
			prims.append(["e", 0.0, 0.0, 0.58, 0.62, rot, false])
			prims.append(["e", 0.0, -0.08, 0.38, 0.42, rot, true])
			prims.append(["e", 0.0, 0.34, 0.11, 0.34, 0.0, true])
			prims.append(["e", 0.0, 0.14, 0.1, 0.2, rot, false])
		"bird":
			var heel := Vector2(0, 0.15)
			for tip in [Vector2(-0.55, -0.62), Vector2(0, -0.8), Vector2(0.55, -0.62)]:
				prims.append(["c", heel.x, heel.y, tip.x, tip.y, 0.075, false])
			prims.append(["c", heel.x, heel.y, 0.02, 0.72, 0.065, false])
		"claw":
			prims.append(["e", 0.0, 0.3, 0.32, 0.26, rot, false])
			for angle in [-0.9, -0.45, 0.0, 0.45, 0.9]:
				var from := Vector2(sin(angle) * 0.2, 0.25)
				var tip := Vector2(sin(angle) * 0.78, 0.3 - cos(angle) * 0.85)
				prims.append(["c", from.x, from.y, tip.x, tip.y, 0.065, false])
				var along := (tip - from).normalized()
				prims.append(["c", tip.x, tip.y, tip.x + along.x * 0.2, tip.y + along.y * 0.2, 0.03, false])
		"trail":
			var last := Vector2(0, 0.9)
			for step in range(1, 21):
				var t := step / 20.0
				var next := Vector2(sin(t * TAU * 1.5) * 0.3, 0.9 - t * 1.8)
				prims.append(["c", last.x, last.y, next.x, next.y, 0.06, false])
				last = next
			prims.append(["e", 0.0, 0.85, 0.2, 0.15, 0.0, false])
	# Add a cheap "too far away to matter" test for each shape.
	for prim in prims:
		var centre: Vector2
		var reach: float
		if prim[0] == "e":
			centre = Vector2(prim[1], prim[2])
			reach = maxf(prim[3], prim[4])
		else:
			centre = (Vector2(prim[1], prim[2]) + Vector2(prim[3], prim[4])) / 2.0
			reach = (Vector2(prim[3], prim[4]) - Vector2(prim[1], prim[2])).length() / 2.0 + prim[5]
		prim.append(centre)
		prim.append((reach + 0.1) * (reach + 0.1))
	return prims

# Signed distance to a shape (negative inside), and where along it the point
# is, used for the fine lines pressed into the ink.
func _shape_distance(prim: Array, p: Vector2) -> Vector2:
	if prim[0] == "e":
		var c := Vector2(prim[1], prim[2])
		var local := (p - c).rotated(-float(prim[5]))
		var k := Vector2(local.x / prim[3], local.y / prim[4]).length()
		var small := minf(prim[3], prim[4])
		return Vector2((k - 1.0) * small, k * small)
	var a := Vector2(prim[1], prim[2])
	var ab := Vector2(prim[3], prim[4]) - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	var d := (p - (a + ab * t)).length()
	return Vector2(d - float(prim[5]), d)

func _foot_alpha(p: Vector2, noise: FastNoiseLite, prims: Array) -> float:
	var best := 1000.0
	var lines := 0.0
	var hole := 1000.0
	for prim in prims:
		if (p - prim[7]).length_squared() > prim[8]:
			continue
		var sd := _shape_distance(prim, p)
		if prim[6]:
			hole = minf(hole, sd.x)
		elif sd.x < best:
			best = sd.x
			lines = sd.y
	if best > 0.05:
		return 0.0
	# Ragged ink edge, then the hollow parts are cut out.
	var rough := 0.014 * noise.get_noise_2d(p.x * 14.0, p.y * 14.0 + 60.0)
	var cover := 1.0 - smoothstep(-0.012, 0.012, best + rough)
	if hole < 1000.0:
		cover *= smoothstep(-0.012, 0.012, hole + rough)
	if cover <= 0.0:
		return 0.0
	# Fine rings pressed into the pad, mottled ink and little paper-coloured specks.
	var rings := 0.84 + 0.16 * cos(TAU * lines / 0.06)
	var mottle := 0.82 + 0.18 * noise.get_noise_2d(p.x * 6.0 + 20.0, p.y * 6.0)
	var specks := smoothstep(0.45, 0.8, noise.get_noise_2d(p.x * 30.0 + 90.0, p.y * 30.0))
	var strength := 0.8 if foot == "trail" else 0.92
	return clampf(cover * rings * mottle * (1.0 - 0.7 * specks) * strength, 0.0, 1.0)
