class_name HomeCanvas
extends Control

# Draws the front of the player's house from a PetalState.my_home design. All
# the drawing is done in a fixed 600x480 picture that is scaled to fit.

const WORLD := Vector2(600, 480)
const WALL_TOP := 180.0
const GROUND := 370.0
const BROWN := Color(0.55, 0.38, 0.25)
const GRASS := Color(0.55, 0.82, 0.5)

var design: Dictionary = {}
var pixel_texture: ImageTexture = null

func set_design(value: Dictionary) -> void:
	design = value
	pixel_texture = null
	if String(design.get("style", "build")) == "drawn" and not (design["pixels"] as PackedByteArray).is_empty():
		pixel_texture = ImageTexture.create_from_image(PixelHouse.make_image(design["pixels"]))
	queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(560, 450)
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _col(index: int) -> Color:
	return PetalState.SET_COLORS[clampi(index, 0, PetalState.SET_COLORS.size() - 1)]

func _has(extra: String) -> bool:
	return (design.get("extras", []) as Array).has(extra)

func _draw() -> void:
	if design.is_empty():
		return
	var fit := minf(size.x / WORLD.x, size.y / WORLD.y)
	draw_set_transform((size - WORLD * fit) / 2.0, 0.0, Vector2(fit, fit))
	var wall := _col(int(design["wall"]))
	var roof := _col(int(design["roof"]))
	var door := _col(int(design["door"]))

	draw_rect(Rect2(0, 0, WORLD.x, WORLD.y), Color(0.75, 0.9, 1.0))
	draw_circle(Vector2(70, 60), 34, Color(1.0, 0.9, 0.4))
	for cloud in [Vector2(430, 60), Vector2(520, 100)]:
		draw_circle(cloud, 24, Color.WHITE)
		draw_circle(cloud + Vector2(26, 6), 20, Color.WHITE)
		draw_circle(cloud + Vector2(-24, 8), 18, Color.WHITE)
	draw_rect(Rect2(0, GROUND, WORLD.x, WORLD.y - GROUND), GRASS)

	if pixel_texture != null:
		_draw_drawn_house()
		return
	if _has("tree"):
		draw_rect(Rect2(40, 260, 22, 115), BROWN)
		for blob in [[Vector2(51, 235), 52.0], [Vector2(24, 272), 34.0], [Vector2(80, 270), 34.0]]:
			draw_circle(blob[0], blob[1], Color(0.35, 0.7, 0.35))

	# House body, then chimney, then the roof over both.
	var body := Rect2(150, WALL_TOP, 300, GROUND - WALL_TOP)
	draw_rect(body, wall)
	draw_rect(body, wall.darkened(0.35), false, 3.0)
	if _has("chimney"):
		draw_rect(Rect2(375, 75, 36, 100), Color(0.7, 0.35, 0.3))
		draw_rect(Rect2(370, 68, 46, 12), Color(0.55, 0.28, 0.24))
	var top := _draw_roof(String(design["roof_style"]), roof)

	_draw_path()
	var window_style := String(design["window"])
	for cx in [215.0, 385.0]:
		if _has("shutters"):
			draw_rect(Rect2(cx - 50, 232, 15, 76), door)
			draw_rect(Rect2(cx + 35, 232, 15, 76), door)
		_draw_window(Vector2(cx, 270), window_style)
		if _has("flowers"):
			draw_rect(Rect2(cx - 38, 304, 76, 12), BROWN)
			for i in range(5):
				draw_circle(Vector2(cx - 30 + i * 15, 303), 6, [Color("ff9ec4"), Color("ffd84d"), Color("ffffff")][i % 3])
	_draw_door(String(design["door_style"]), door)

	var number := String(design.get("number", ""))
	if number != "":
		var plate := Rect2(266, 205, 68, 28)
		draw_rect(plate, Color.WHITE)
		draw_rect(plate, Color(0.4, 0.4, 0.5), false, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(plate.position.x, plate.position.y + 22), number, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 22, Color(0.2, 0.2, 0.3))

	if _has("wreath"):
		draw_arc(Vector2(300, 290), 13, 0.0, TAU, 24, Color(0.2, 0.6, 0.3), 6.0)
		draw_circle(Vector2(300, 303), 4, Color(0.9, 0.2, 0.3))
	if _has("balloons"):
		for b in [[Vector2(448, 300), Color("f25c6e")], [Vector2(470, 285), Color("ffd84d")], [Vector2(490, 305), Color("6cb8ff")]]:
			draw_line(b[0] + Vector2(0, 16), Vector2(462, 372), Color(0.4, 0.4, 0.4), 1.5)
			draw_circle(b[0], 16, b[1])
	if _has("lights"):
		for i in range(13):
			draw_circle(Vector2(150 + i * 25.0, WALL_TOP + 4), 5, [Color("ffd84d"), Color("ff9ec4"), Color("6cb8ff"), Color("b6e36b")][i % 4])
	if _has("flag"):
		draw_line(Vector2(300, top), Vector2(300, top - 42), Color(0.3, 0.3, 0.3), 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(300, top - 42), Vector2(336, top - 32), Vector2(300, top - 22)]), Color(0.95, 0.3, 0.4))
	if _has("flowers"):
		for i in range(14):
			var p := Vector2(30 + (i * 83) % 540, 392 + (i * 37) % 70)
			draw_circle(p, 6, [Color("ff9ec4"), Color("ffd84d"), Color("ffffff"), Color("a87be8")][i % 4])
			draw_circle(p, 2.5, Color(1.0, 0.8, 0.2))
	if _has("mailbox"):
		draw_rect(Rect2(127, 372, 8, 58), BROWN)
		draw_rect(Rect2(108, 350, 46, 28), Color(0.85, 0.25, 0.3))
		draw_rect(Rect2(150, 340, 5, 20), Color(0.95, 0.85, 0.2))
	if _has("fence"):
		for x in range(8, 600, 26):
			if x > 236 and x < 350:
				continue
			draw_rect(Rect2(x, 405, 14, 58), Color.WHITE)
			draw_colored_polygon(PackedVector2Array([Vector2(x, 405), Vector2(x + 7, 394), Vector2(x + 14, 405)]), Color.WHITE)
		draw_rect(Rect2(0, 418, 236, 7), Color(0.92, 0.92, 0.92))
		draw_rect(Rect2(350, 418, 250, 7), Color(0.92, 0.92, 0.92))
		draw_rect(Rect2(0, 440, 236, 7), Color(0.92, 0.92, 0.92))
		draw_rect(Rect2(350, 440, 250, 7), Color(0.92, 0.92, 0.92))
	_draw_street_sign()

# Returns the y of the roof's highest point (for the flag).
func _draw_roof(style: String, roof: Color) -> float:
	var edge := roof.darkened(0.35)
	var points: PackedVector2Array
	match style:
		"flat":
			draw_rect(Rect2(135, 148, 330, 40), roof)
			draw_rect(Rect2(135, 148, 330, 40), edge, false, 3.0)
			draw_rect(Rect2(135, 138, 330, 10), roof.lightened(0.2))
			return 138.0
		"dome":
			points = PackedVector2Array()
			for step in range(25):
				var a := PI * step / 24.0
				points.append(Vector2(300 - 175 * cos(a), 190 - 105 * sin(a)))
		"barn":
			points = PackedVector2Array([Vector2(130, 190), Vector2(158, 118), Vector2(300, 76), Vector2(442, 118), Vector2(470, 190)])
		_:
			points = PackedVector2Array([Vector2(125, 190), Vector2(300, 70), Vector2(475, 190)])
	draw_colored_polygon(points, roof)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, edge, 3.0)
	var highest := 999.0
	for p in points:
		highest = minf(highest, p.y)
	return highest

func _draw_path() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(272, GROUND), Vector2(328, GROUND), Vector2(372, WORLD.y), Vector2(228, WORLD.y)]), Color(0.93, 0.85, 0.68))

func _draw_window(c: Vector2, style: String) -> void:
	var glass := Color(0.85, 0.94, 1.0)
	var frame := Color(1, 1, 1)
	match style:
		"round":
			draw_circle(c, 33, frame)
			draw_circle(c, 28, glass)
			draw_line(c + Vector2(-28, 0), c + Vector2(28, 0), frame, 3.0)
			draw_line(c + Vector2(0, -28), c + Vector2(0, 28), frame, 3.0)
		"arch":
			draw_rect(Rect2(c.x - 33, c.y - 8, 66, 42), frame)
			draw_circle(Vector2(c.x, c.y - 8), 33, frame)
			draw_rect(Rect2(c.x - 28, c.y - 8, 56, 37), glass)
			draw_circle(Vector2(c.x, c.y - 8), 28, glass)
			draw_line(Vector2(c.x, c.y - 36), Vector2(c.x, c.y + 29), frame, 3.0)
		"tall":
			draw_rect(Rect2(c.x - 26, c.y - 42, 52, 84), frame)
			draw_rect(Rect2(c.x - 21, c.y - 37, 42, 74), glass)
			draw_line(Vector2(c.x, c.y - 37), Vector2(c.x, c.y + 37), frame, 3.0)
			draw_line(Vector2(c.x - 21, c.y), Vector2(c.x + 21, c.y), frame, 3.0)
		_:
			draw_rect(Rect2(c.x - 33, c.y - 33, 66, 66), frame)
			draw_rect(Rect2(c.x - 28, c.y - 28, 56, 56), glass)
			draw_line(c + Vector2(-28, 0), c + Vector2(28, 0), frame, 3.0)
			draw_line(c + Vector2(0, -28), c + Vector2(0, 28), frame, 3.0)

func _draw_door(style: String, door: Color) -> void:
	var edge := door.darkened(0.35)
	match style:
		"square":
			draw_rect(Rect2(268, 262, 64, 108), door)
			draw_rect(Rect2(268, 262, 64, 108), edge, false, 3.0)
		"double":
			draw_rect(Rect2(262, 262, 76, 108), door)
			draw_rect(Rect2(262, 262, 76, 108), edge, false, 3.0)
			draw_line(Vector2(300, 262), Vector2(300, 370), edge, 3.0)
			draw_circle(Vector2(292, 320), 4.5, Color(1.0, 0.85, 0.3))
			draw_circle(Vector2(308, 320), 4.5, Color(1.0, 0.85, 0.3))
			return
		_:
			draw_rect(Rect2(268, 276, 64, 94), door)
			draw_circle(Vector2(300, 276), 32, door)
			draw_rect(Rect2(268, 276, 64, 94), edge, false, 3.0)
	draw_circle(Vector2(320, 326), 4.5, Color(1.0, 0.85, 0.3))

func _draw_street_sign() -> void:
	var street := String(design.get("street", ""))
	var town := String(design.get("town", ""))
	if street == "" and town == "":
		return
	draw_rect(Rect2(518, 395, 7, 70), BROWN)
	var font := ThemeDB.fallback_font
	if street != "":
		var board := Rect2(400, 392, 190, 32)
		draw_rect(board, Color(0.15, 0.5, 0.35))
		draw_rect(board, Color.WHITE, false, 2.0)
		draw_string(font, Vector2(board.position.x, board.position.y + 23), street, HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 18, Color.WHITE)
	if town != "":
		var board2 := Rect2(420, 428, 150, 26)
		draw_rect(board2, Color(0.95, 0.9, 0.7))
		draw_string(font, Vector2(board2.position.x, board2.position.y + 19), town, HORIZONTAL_ALIGNMENT_CENTER, board2.size.x, 15, Color(0.3, 0.2, 0.15))

# A house the player drew and painted as pixel art, with the address under it.
func _draw_drawn_house() -> void:
	draw_texture_rect(pixel_texture, Rect2(60, 20, 480, 360), false)
	var line := ("%s %s" % [design.get("number", ""), design.get("street", "")]).strip_edges()
	if String(design.get("town", "")) != "":
		line = "%s, %s" % [line, design["town"]] if line != "" else String(design["town"])
	if line != "":
		var board := Rect2(100, 400, 400, 44)
		draw_rect(board, Color(0.15, 0.5, 0.35))
		draw_rect(board, Color.WHITE, false, 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(board.position.x, board.position.y + 31), line, HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 26, Color.WHITE)
