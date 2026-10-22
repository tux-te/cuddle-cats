class_name PixelHouse
extends Control

# A little pixel-art picture you can paint: a grid of cells where 0 is empty
# sky, 1 is the outline and 2..13 are the 12 palette colours (value - 2 indexes
# PetalState.SET_COLORS). Tap to bucket-fill a region or paint single pixels.

signal changed

const OUTLINE := Color(0.2, 0.15, 0.25)

var cells := PackedByteArray()
var paint := 2           # the value painted by fill / pen
var tool := "fill"       # "fill" or "pen"

func _init() -> void:
	custom_minimum_size = Vector2(480, 360)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP

static func colour_of(value: int) -> Color:
	if value == 0:
		return Color(0, 0, 0, 0)
	if value == 1:
		return OUTLINE
	return PetalState.SET_COLORS[clampi(value - 2, 0, PetalState.SET_COLORS.size() - 1)]

static func make_image(data: PackedByteArray) -> Image:
	var image := Image.create(PetalState.HOME_PIX_W, PetalState.HOME_PIX_H, false, Image.FORMAT_RGBA8)
	for y in range(PetalState.HOME_PIX_H):
		for x in range(PetalState.HOME_PIX_W):
			image.set_pixel(x, y, colour_of(data[y * PetalState.HOME_PIX_W + x]))
	return image

func set_cells(data: PackedByteArray) -> void:
	cells = data.duplicate()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.78, 0.92, 1.0))
	if cells.size() == PetalState.HOME_PIX_W * PetalState.HOME_PIX_H:
		draw_texture_rect(ImageTexture.create_from_image(make_image(cells)), Rect2(Vector2.ZERO, size), false)

func _cell_at(p: Vector2) -> Vector2i:
	return Vector2i(int(p.x / size.x * PetalState.HOME_PIX_W), int(p.y / size.y * PetalState.HOME_PIX_H)).clamp(Vector2i.ZERO, Vector2i(PetalState.HOME_PIX_W - 1, PetalState.HOME_PIX_H - 1))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_apply(_cell_at(event.position), true)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and tool == "pen":
		_apply(_cell_at(event.position), false)

func _apply(cell: Vector2i, first: bool) -> void:
	var index := cell.y * PetalState.HOME_PIX_W + cell.x
	if tool == "pen":
		cells[index] = paint
	elif first:
		flood_fill(cell, paint)
	queue_redraw()
	changed.emit()

# Fills the connected same-colour region the cell is in (the outline stops it).
func flood_fill(start: Vector2i, value: int) -> void:
	var width := PetalState.HOME_PIX_W
	var target := cells[start.y * width + start.x]
	if target == 1 or target == value:
		return
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= width or p.y >= PetalState.HOME_PIX_H:
			continue
		var i := p.y * width + p.x
		if cells[i] != target:
			continue
		cells[i] = value
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))
