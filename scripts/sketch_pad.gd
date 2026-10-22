class_name SketchPad
extends Control

# A drawing pad for sketching your house with a finger or mouse. "Sharpen"
# straightens the wobbly strokes (fewer points, snapped to a grid so lines
# become straight and corners meet), and to_pixels() turns the lines into the
# cells of a pixel-art grid (see pixel_house.gd).

signal changed

const GRID := 12.0
const JOIN_DISTANCE := 30.0
const PEN := Color(0.2, 0.15, 0.25)

var strokes: Array = []          # PackedVector2Array each
var current := PackedVector2Array()
var drawing := false
var sharpened := false

func _init() -> void:
	custom_minimum_size = Vector2(480, 360)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drawing = true
			current = PackedVector2Array([event.position])
		elif drawing:
			drawing = false
			if current.size() >= 2:
				strokes.append(current)
				sharpened = false
				changed.emit()
			current = PackedVector2Array()
			queue_redraw()
	elif event is InputEventMouseMotion and drawing:
		var p: Vector2 = event.position.clamp(Vector2.ZERO, size)
		if current[current.size() - 1].distance_to(p) > 3.0:
			current.append(p)
			queue_redraw()

func undo() -> void:
	if not strokes.is_empty():
		strokes.pop_back()
		changed.emit()
		queue_redraw()

func clear() -> void:
	strokes = []
	current = PackedVector2Array()
	sharpened = false
	changed.emit()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.99, 0.98, 0.94))
	var x := 0.0
	while x < size.x:
		var y := 0.0
		while y < size.y:
			draw_circle(Vector2(x, y), 1.2, Color(0.8, 0.78, 0.85))
			y += GRID * 2.0
		x += GRID * 2.0
	for stroke in strokes:
		draw_polyline(stroke, PEN, 6.0 if sharpened else 5.0, true)
		if sharpened:
			for p in stroke:
				draw_circle(p, 3.5, PEN)
	if current.size() >= 2:
		draw_polyline(current, PEN, 5.0, true)

# Straightens every stroke: fewer points, snapped to the grid, nearly-closed
# shapes closed.
func sharpen() -> void:
	var cleaned: Array = []
	for stroke in strokes:
		var points := _simplify(stroke, 10.0)
		var out := PackedVector2Array()
		for p in points:
			var q := Vector2(roundf(p.x / GRID) * GRID, roundf(p.y / GRID) * GRID)
			if out.is_empty() or out[out.size() - 1] != q:
				out.append(q)
		if out.size() >= 3 and points[0].distance_to(points[points.size() - 1]) < 28.0:
			out[out.size() - 1] = out[0]
		if out.size() >= 2:
			cleaned.append(out)
	_join_ends(cleaned)
	strokes = cleaned
	sharpened = true
	changed.emit()
	queue_redraw()

# Strokes that almost meet get joined (so the paint bucket can't leak out of a
# corner that was left open): each stroke end moves to a nearby corner of another
# stroke, or onto a nearby stretch of one.
func _join_ends(cleaned: Array) -> void:
	for i in range(cleaned.size()):
		var stroke: PackedVector2Array = cleaned[i]
		for end in [0, stroke.size() - 1]:
			var best := stroke[end]
			var best_d := JOIN_DISTANCE
			for j in range(cleaned.size()):
				if j == i:
					continue
				for corner in cleaned[j]:
					if stroke[end].distance_to(corner) < best_d:
						best_d = stroke[end].distance_to(corner)
						best = corner
			if best_d == JOIN_DISTANCE:
				var best_s := JOIN_DISTANCE * 0.7
				for j in range(cleaned.size()):
					if j == i:
						continue
					var other: PackedVector2Array = cleaned[j]
					for k in range(other.size() - 1):
						var t := clampf((stroke[end] - other[k]).dot(other[k + 1] - other[k]) / maxf((other[k + 1] - other[k]).length_squared(), 0.001), 0.0, 1.0)
						var on_line: Vector2 = other[k] + (other[k + 1] - other[k]) * t
						if stroke[end].distance_to(on_line) < best_s:
							best_s = stroke[end].distance_to(on_line)
							best = on_line
			stroke[end] = best
		cleaned[i] = stroke

# Douglas-Peucker line simplification.
func _simplify(points: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var worst := 0.0
	var worst_i := 0
	var a := points[0]
	var b := points[points.size() - 1]
	for i in range(1, points.size() - 1):
		var d := _distance_to_segment(points[i], a, b)
		if d > worst:
			worst = d
			worst_i = i
	if worst <= epsilon:
		return PackedVector2Array([a, b])
	var left := _simplify(points.slice(0, worst_i + 1), epsilon)
	var right := _simplify(points.slice(worst_i), epsilon)
	left.resize(left.size() - 1)
	left.append_array(right)
	return left

func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	if ab.length_squared() == 0.0:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

# The strokes as pixel-grid outline cells (value 1), cells_w x cells_h.
func to_pixels(cells_w: int, cells_h: int) -> PackedByteArray:
	var cells := PackedByteArray()
	cells.resize(cells_w * cells_h)
	var scale := Vector2(cells_w / maxf(size.x, 1.0), cells_h / maxf(size.y, 1.0))
	for stroke in strokes:
		for i in range(stroke.size() - 1):
			var a := Vector2i((stroke[i] * scale).floor()).clamp(Vector2i.ZERO, Vector2i(cells_w - 1, cells_h - 1))
			var b := Vector2i((stroke[i + 1] * scale).floor()).clamp(Vector2i.ZERO, Vector2i(cells_w - 1, cells_h - 1))
			_line(cells, cells_w, a, b)
	return cells

# Bresenham: a connected run of cells (so the paint bucket can't leak through).
func _line(cells: PackedByteArray, width: int, a: Vector2i, b: Vector2i) -> void:
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var p := a
	while true:
		cells[p.y * width + p.x] = 1
		if p == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy
