extends Control

# The play space: a themed backdrop with toys and scenery (see
# PetalState.PLAY_ITEMS) that can be dragged anywhere. Tap a toy to make it
# bounce; the last one touched is "selected" so it can be put away.

signal changed
signal selection_changed

const ITEM_SIZE := Vector2(72, 72)
const ITEM_FONT := 54
const EDGE := Vector2(36, 44)

var backdrop := "cosy"
var selected: Label = null
var items: Array[Label] = []
var dragging: Label = null
var drag_offset := Vector2.ZERO
var drag_moved := false

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var timer := Timer.new()
	timer.wait_time = 0.22
	timer.autostart = true
	timer.timeout.connect(_spawn_weather)
	add_child(timer)

# --- Weather -----------------------------------------------------------------

# Tap the weather button to cycle: nothing, petals, snow, rain, stars.
const WEATHER := ["", "🌸", "❄️", "💧", "⭐"]
var weather := 0

func next_weather() -> String:
	weather = (weather + 1) % WEATHER.size()
	return WEATHER[weather]

func _spawn_weather() -> void:
	if weather == 0 or not is_visible_in_tree():
		return
	var drop := Label.new()
	drop.text = WEATHER[weather]
	drop.add_theme_font_size_override("font_size", randi_range(18, 32))
	drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop.z_index = 2000
	drop.position = Vector2(randf_range(0, size.x), -30)
	add_child(drop)
	var fall := 2.2 if WEATHER[weather] == "💧" else randf_range(3.0, 4.5)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(drop, "position:y", size.y + 20, fall)
	tween.tween_property(drop, "position:x", drop.position.x + randf_range(-60, 60), fall)
	tween.chain().tween_callback(drop.queue_free)

# --- Items -------------------------------------------------------------------

func load_space(space: Dictionary) -> void:
	for item in items:
		item.queue_free()
	items.clear()
	selected = null
	backdrop = String(space["theme"])
	for entry in space["items"]:
		_make_item(String(entry["id"]), Vector2(float(entry["x"]), float(entry["y"])))
	queue_redraw()
	selection_changed.emit()

func to_space() -> Dictionary:
	var list: Array = []
	for item in items:
		var center := item.position + item.size / 2.0
		list.append({"id": String(item.get_meta("id")), "x": center.x, "y": center.y})
	return {"theme": backdrop, "items": list}

func is_full() -> bool:
	return items.size() >= PetalState.PLAY_MAX_ITEMS

func add_item(id: String) -> void:
	var at := Vector2(randf_range(110, size.x - 110), randf_range(size.y * 0.5, size.y - 60))
	var item := _make_item(id, at)
	select(item)
	item.scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(item, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	changed.emit()

func remove_selected() -> void:
	if selected == null:
		return
	var gone := selected
	items.erase(gone)
	select(null)
	var tween := create_tween()
	tween.tween_property(gone, "scale", Vector2.ZERO, 0.2)
	tween.tween_callback(gone.queue_free)
	changed.emit()

func clear_all() -> void:
	for item in items:
		item.queue_free()
	items.clear()
	select(null)
	changed.emit()

func set_theme_id(id: String) -> void:
	backdrop = id
	queue_redraw()
	changed.emit()

func select(item: Label) -> void:
	selected = item
	queue_redraw()
	selection_changed.emit()

func _make_item(id: String, center: Vector2) -> Label:
	var label := Label.new()
	label.text = String(PetalState.PLAY_ITEMS[id]["emoji"])
	label.set_meta("id", id)
	label.size = ITEM_SIZE
	label.pivot_offset = ITEM_SIZE / 2.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", ITEM_FONT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_move_to(label, center)
	items.append(label)
	return label

func _move_to(item: Label, center: Vector2) -> void:
	var c := center.clamp(EDGE, size - EDGE)
	item.position = c - item.size / 2.0
	item.z_index = int(c.y)

# Every toy has its own trick when tapped.
func bounce(item: Label) -> void:
	if not is_instance_valid(item):
		return
	var tween := create_tween()
	match String(item.get_meta("id")):
		"balloon":
			var home := item.position
			tween.tween_property(item, "position:y", home.y - 90, 0.5).set_trans(Tween.TRANS_SINE)
			tween.tween_property(item, "position:y", home.y, 0.7).set_trans(Tween.TRANS_SINE)
			return
		"ball", "yarn", "car":
			var home := item.position
			var dir := 1.0 if home.x < size.x - 160 else -1.0
			tween.tween_property(item, "position:x", home.x + 120.0 * dir, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(item, "rotation", 6.0 * dir, 0.5)
			tween.tween_property(item, "position:x", home.x, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			tween.parallel().tween_property(item, "rotation", 0.0, 0.5)
			return
		"wheel", "horse", "fountain", "rainbow", "castle", "circus", "coaster":
			tween.tween_property(item, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_BACK)
			tween.tween_property(item, "rotation", TAU, 0.6)
			tween.tween_property(item, "rotation", 0.0, 0.0)
			tween.tween_property(item, "scale", Vector2.ONE, 0.2)
			return
	tween.tween_property(item, "scale", Vector2(1.35, 1.35), 0.12)
	tween.tween_property(item, "rotation", 0.3, 0.08)
	tween.tween_property(item, "rotation", -0.3, 0.1)
	tween.tween_property(item, "rotation", 0.0, 0.08)
	tween.tween_property(item, "scale", Vector2.ONE, 0.15)

func _item_at(point: Vector2) -> Label:
	for i in range(items.size() - 1, -1, -1):
		if Rect2(items[i].position, items[i].size).grow(4).has_point(point):
			return items[i]
	return null

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = _item_at(event.position)
			select(dragging)
			if dragging:
				drag_offset = dragging.position + dragging.size / 2.0 - event.position
				drag_moved = false
		elif dragging:
			if drag_moved:
				changed.emit()
			else:
				bounce(dragging)
			dragging = null
	elif event is InputEventMouseMotion and dragging:
		_move_to(dragging, event.position + drag_offset)
		drag_moved = true
		queue_redraw()

# --- Backdrops ---------------------------------------------------------------

func _draw() -> void:
	var w := size.x
	var h := size.y
	match backdrop:
		"meadow":
			draw_rect(Rect2(0, 0, w, h), Color("9edcff"))
			draw_circle(Vector2(w - 90, 70), 38, Color("ffe066"))
			_cloud(Vector2(150, 70))
			_cloud(Vector2(400, 110))
			draw_colored_polygon(_ground(h * 0.55, 60), Color("8fd46b"))
			draw_rect(Rect2(0, h * 0.68, w, h), Color("7ac957"))
		"beach":
			draw_rect(Rect2(0, 0, w, h), Color("b5e6ff"))
			draw_circle(Vector2(90, 70), 36, Color("ffe066"))
			_cloud(Vector2(420, 70))
			draw_rect(Rect2(0, h * 0.42, w, h * 0.22), Color("4fb4e8"))
			for i in range(8):
				draw_arc(Vector2(40 + i * 90, h * 0.5), 18, PI, TAU, 10, Color(1, 1, 1, 0.7), 3.0)
			draw_rect(Rect2(0, h * 0.62, w, h), Color("f6dfa4"))
		"night":
			draw_rect(Rect2(0, 0, w, h), Color("1d2456"))
			draw_circle(Vector2(w - 100, 70), 34, Color("fff3b0"))
			draw_circle(Vector2(w - 88, 62), 30, Color("1d2456"))
			for i in range(30):
				var p := Vector2(fposmod(i * 197.0, w), fposmod(i * 83.0, h * 0.55))
				draw_circle(p, 1.5 + (i % 3), Color(1, 1, 0.85, 0.9))
			draw_colored_polygon(_ground(h * 0.62, 40), Color("2d5a45"))
			draw_rect(Rect2(0, h * 0.74, w, h), Color("264d3b"))
		"candy":
			for i in range(14):
				draw_rect(Rect2(i * w / 14.0, 0, w / 14.0 + 1, h), Color("ffd6ec") if i % 2 == 0 else Color("fff0f8"))
			draw_rect(Rect2(0, h * 0.62, w, h), Color("cfeee0"))
			for i in range(10):
				draw_circle(Vector2(30 + i * 70, h * 0.62 + 30 + (i % 3) * 36), 9, Color("ffb3d9") if i % 2 == 0 else Color("ffe08a"))
		_:
			draw_rect(Rect2(0, 0, w, h), Color("ffeef2"))
			draw_rect(Rect2(w * 0.38, 28, 190, 120), Color("bfe6ff"))
			draw_rect(Rect2(w * 0.38, 28, 190, 120), Color("ffffff"), false, 8.0)
			draw_line(Vector2(w * 0.38 + 95, 28), Vector2(w * 0.38 + 95, 148), Color.WHITE, 6.0)
			draw_rect(Rect2(0, h * 0.6, w, h), Color("f6d6bd"))
			draw_colored_polygon(PackedVector2Array(_oval(Vector2(w * 0.5, h * 0.82), 250, 52)), Color("ffc2d8"))
	if selected and is_instance_valid(selected):
		draw_arc(selected.position + selected.size / 2.0, 42, 0, TAU, 32, Color(0.72, 0.31, 0.47), 4.0)

func _cloud(at: Vector2) -> void:
	for offset in [Vector2(0, 0), Vector2(30, -12), Vector2(60, 0), Vector2(28, 8)]:
		draw_circle(at + offset, 26, Color(1, 1, 1, 0.9))

func _oval(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(40):
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

# Gentle rolling hills along the top of the ground.
func _ground(top: float, wave: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, size.y))
	for i in range(21):
		var x := size.x * i / 20.0
		pts.append(Vector2(x, top + sin(i * 0.7) * wave * 0.4))
	pts.append(Vector2(size.x, size.y))
	return pts
