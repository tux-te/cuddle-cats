extends Control

# Draws a pet's bed and bowl from a design (see PetalState.pet_set). Everything
# is shapes and emoji - no art files - so every colour / pattern / shape
# combination a kid picks just works.

const BED_CENTER := Vector2(175, 238)
const BOWL_CENTER := Vector2(560, 238)
const NAME_Y := 324.0

# bed shape -> half-width and half-height of the top face
const BED_SIZES := {
	"round": Vector2(150, 58), "square": Vector2(140, 56),
	"heart": Vector2(140, 64), "star": Vector2(160, 66),
}
# bowl shape -> half-width, half-height of the opening, body height, how much
# the bottom narrows
const BOWL_SIZES := {
	"round": Vector4(78, 22, 54, 0.72), "tall": Vector4(58, 17, 80, 0.8),
	"wide": Vector4(98, 26, 38, 0.8),
}
const FOOD_COLORS := {
	"dog": Color("9a5b34"), "cat": Color("9a5b34"), "bird": Color("e8c26a"),
	"gerbil": Color("e8c26a"), "bunny": Color("f08a2e"),
}

var design: Dictionary = {}
var bed_name_default := "Bed"
var bowl_name_default := "Bowl"
var food_color: Color = FOOD_COLORS["cat"]

var bed_stamp: Label
var bowl_stamp: Label
var bed_name: Label
var bowl_name: Label

func _ready() -> void:
	bed_stamp = _make_label(44, Vector2(90, 60))
	bowl_stamp = _make_label(30, Vector2(70, 44))
	bed_name = _make_label(22, Vector2(330, 32))
	bowl_name = _make_label(22, Vector2(330, 32))
	bed_name.add_theme_color_override("font_color", Color(0.4, 0.25, 0.3))
	bowl_name.add_theme_color_override("font_color", Color(0.4, 0.25, 0.3))
	_place(bed_name, Vector2(BED_CENTER.x, NAME_Y))
	_place(bowl_name, Vector2(BOWL_CENTER.x, NAME_Y))
	if not design.is_empty():
		_update_labels()

func set_design(value: Dictionary) -> void:
	design = value
	queue_redraw()
	if bed_stamp:
		_update_labels()

func _make_label(font_size: int, label_size: Vector2) -> Label:
	var label := Label.new()
	label.size = label_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _place(label: Label, center: Vector2) -> void:
	label.position = center - label.size / 2.0

func _update_labels() -> void:
	var bed: Dictionary = design["bed"]
	var bowl: Dictionary = design["bowl"]
	bed_stamp.text = String(bed["stamp"])
	_place(bed_stamp, BED_CENTER + Vector2(0, 2))
	bowl_stamp.text = String(bowl["stamp"])
	var dims: Vector4 = BOWL_SIZES[bowl["shape"]]
	_place(bowl_stamp, BOWL_CENTER + Vector2(0, 8 + dims.z * 0.1))
	bed_name.text = String(bed["name"]) if String(bed["name"]) != "" else bed_name_default
	bowl_name.text = String(bowl["name"]) if String(bowl["name"]) != "" else bowl_name_default

func _draw() -> void:
	draw_style_box(_box(Color(1.0, 0.95, 0.9), 22), Rect2(Vector2.ZERO, size))
	draw_colored_polygon(_ellipse(Vector2(size.x / 2.0, 280), size.x * 0.48, 80), Color(0.96, 0.85, 0.72))
	if design.is_empty():
		return
	_draw_bed(design["bed"])
	_draw_bowl(design["bowl"])

static func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box

static func _col(index: int) -> Color:
	return PetalState.SET_COLORS[clampi(index, 0, PetalState.SET_COLORS.size() - 1)]

# --- Bed ---------------------------------------------------------------------

func _draw_bed(piece: Dictionary) -> void:
	var shape := String(piece["shape"])
	var half: Vector2 = BED_SIZES[shape]
	var main := _col(int(piece["color"]))
	var trim := _col(int(piece["trim"]))
	var c := BED_CENTER

	draw_colored_polygon(_outline(shape, c + Vector2(0, 24), half.x * 1.05, half.y), Color(0, 0, 0, 0.1))
	for dy in [16, 12, 8, 4]:
		draw_colored_polygon(_outline(shape, c + Vector2(0, dy), half.x, half.y), trim.darkened(0.3))
	var top := _outline(shape, c, half.x, half.y)
	draw_colored_polygon(top, trim)
	draw_colored_polygon(_scaled(top, c, 0.8, Vector2(0, 2)), trim.darkened(0.22))
	var cushion := _scaled(top, c, 0.76, Vector2(0, 5))
	draw_colored_polygon(cushion, main)
	_draw_pattern(String(piece["pattern"]), cushion, trim, 1.0)
	_outline_line(cushion, main.darkened(0.25))

# --- Bowl --------------------------------------------------------------------

func _draw_bowl(piece: Dictionary) -> void:
	var dims: Vector4 = BOWL_SIZES[piece["shape"]]
	var rx := dims.x
	var ry := dims.y
	var rb := rx * dims.w
	var ryb := ry * dims.w
	var main := _col(int(piece["color"]))
	var trim := _col(int(piece["trim"]))
	var cx := BOWL_CENTER.x
	var ty := BOWL_CENTER.y - dims.z * 0.5
	var by := BOWL_CENTER.y + dims.z * 0.5

	draw_colored_polygon(_ellipse(Vector2(cx, by + ryb * 0.5), rx * 1.12, ryb * 1.2), Color(0, 0, 0, 0.1))

	# The body is the hull of the top and bottom ellipses; the rim drawn on
	# top hides the part above the front edge.
	var body := Geometry2D.convex_hull(_ellipse(Vector2(cx, ty), rx, ry) + _ellipse(Vector2(cx, by), rb, ryb))
	body.remove_at(body.size() - 1)
	draw_colored_polygon(body, main)
	_draw_pattern(String(piece["pattern"]), body, trim, 0.75)
	_outline_line(body, main.darkened(0.25))

	draw_colored_polygon(_ellipse(Vector2(cx, ty), rx, ry), trim)
	draw_colored_polygon(_ellipse(Vector2(cx, ty + 1), rx - 9, ry - 4), trim.darkened(0.45))
	draw_colored_polygon(_ellipse(Vector2(cx, ty), rx - 14, ry - 7), food_color)
	draw_colored_polygon(_ellipse(Vector2(cx, ty - 3), (rx - 14) * 0.6, (ry - 7) * 0.55), food_color.lightened(0.18))
	for i in range(9):
		var a := i * 2.4
		var f := fmod(i * 0.37, 0.8) + 0.1
		var p := Vector2(cx + cos(a) * (rx - 22) * f, ty - 2 + sin(a) * (ry - 10) * f)
		draw_colored_polygon(_ellipse(p, 3.5, 2.8, 10), food_color.darkened(0.25))

# --- Patterns ----------------------------------------------------------------

# Each tile is clipped to the shape it decorates, so a pattern never spills
# over the edge of the bed or bowl.
func _draw_pattern(pattern: String, clip: PackedVector2Array, color: Color, u: float) -> void:
	if pattern == "plain":
		return
	var box := Rect2(clip[0], Vector2.ZERO)
	for p in clip:
		box = box.expand(p)
	for tile in _tiles(pattern, box, u):
		for part in Geometry2D.intersect_polygons(tile, clip):
			if part.size() >= 3 and not Geometry2D.triangulate_polygon(part).is_empty():
				draw_colored_polygon(part, color)

func _tiles(pattern: String, box: Rect2, u: float) -> Array[PackedVector2Array]:
	var tiles: Array[PackedVector2Array] = []
	match pattern:
		"stripes":
			var x := box.position.x
			while x < box.end.x:
				tiles.append(_rect(Vector2(x, box.position.y), Vector2(20 * u, box.size.y)))
				x += 40 * u
		"checks":
			var s := 26.0 * u
			var row := 0
			var y := box.position.y
			while y < box.end.y:
				var col := 0
				var x := box.position.x
				while x < box.end.x:
					if (row + col) % 2 == 0:
						tiles.append(_rect(Vector2(x, y), Vector2(s, s)))
					x += s
					col += 1
				y += s
				row += 1
		_:
			var spacing := (58.0 if pattern == "paws" else 40.0) * u
			var row := 0
			var y := box.position.y + spacing * 0.5
			while y < box.end.y:
				var x := box.position.x + spacing * (0.5 if row % 2 == 0 else 1.0)
				while x < box.end.x:
					tiles.append_array(_motif(pattern, Vector2(x, y), u))
					x += spacing
				y += spacing * 0.8
				row += 1
	return tiles

func _motif(pattern: String, at: Vector2, u: float) -> Array[PackedVector2Array]:
	var motif: Array[PackedVector2Array] = []
	match pattern:
		"dots":
			motif.append(_ellipse(at, 7 * u, 7 * u, 12))
		"hearts":
			motif.append(_outline("heart", at, 12 * u, 12 * u))
		"stars":
			motif.append(_outline("star", at, 13 * u, 13 * u))
		"paws":
			motif.append(_ellipse(at + Vector2(0, 5) * u, 9 * u, 7 * u, 12))
			for toe in [Vector2(-10, -6), Vector2(0, -11), Vector2(10, -6)]:
				motif.append(_ellipse(at + toe * u, 3.8 * u, 3.8 * u, 8))
	return motif

# --- Shape helpers -----------------------------------------------------------

static func _ellipse(c: Vector2, rx: float, ry: float, n := 48) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

static func _rect(at: Vector2, rect_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(rect_size.x, 0), at + rect_size, at + Vector2(0, rect_size.y)])

static func _outline(shape: String, c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match shape:
		"square":
			var r := ry * 0.6
			var corners := [Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]
			for k in range(4):
				var middle: Vector2 = c + Vector2(corners[k].x * (rx - r), corners[k].y * (ry - r))
				for i in range(7):
					var a := -PI / 2.0 + (k + i / 6.0) * PI / 2.0
					pts.append(middle + Vector2(cos(a) * r, sin(a) * r))
		"heart":
			for i in range(56):
				var t := TAU * i / 56.0
				var hx := 16.0 * pow(sin(t), 3.0)
				var hy := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				pts.append(Vector2(c.x + hx / 16.0 * rx, c.y + (hy - 2.5) / 14.5 * ry))
		"star":
			for i in range(10):
				var a := -PI / 2.0 + TAU * i / 10.0
				var radius := 1.0 if i % 2 == 0 else 0.5
				pts.append(c + Vector2(cos(a) * rx * radius, sin(a) * ry * radius))
		_:
			pts = _ellipse(c, rx, ry)
	return pts

static func _scaled(poly: PackedVector2Array, c: Vector2, k: float, offset: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in poly:
		pts.append(c + (p - c) * k + offset)
	return pts

func _outline_line(poly: PackedVector2Array, color: Color) -> void:
	var closed := poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, color, 2.0)
