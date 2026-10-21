extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const Confetti = preload("res://scripts/confetti.gd")
const Sfx = preload("res://scripts/sfx.gd")
const SetCanvas = preload("res://scripts/pet_set_canvas.gd")
const PlayStage = preload("res://scripts/pet_play_stage.gd")

const PET_SIZE := Vector2(130, 120)
const STAGE_SIZE := Vector2(700, 360)
# Where the pet stands on the stage (top-left of her picture).
const SPOT_IDLE := Vector2(285, 140)
const SPOT_BED := Vector2(110, 125)
const SPOT_BOWL := Vector2(405, 150)
const SPOT_TOY := Vector2(330, 175)

const PATTERN_LABELS := {
	"plain": "➖ Plain", "stripes": "🦓 Stripes", "dots": "⚪ Dots", "hearts": "💗 Hearts",
	"stars": "⭐ Stars", "checks": "🏁 Checks", "paws": "🐾 Paws",
}
const SHAPE_LABELS := {
	"round": "⭕ Round", "square": "🟦 Square", "heart": "💗 Heart", "star": "⭐ Star",
	"tall": "🥫 Tall", "wide": "🥣 Wide",
	"ball": "🔴 Ball", "bone": "🦴 Bone", "fish": "🐟 Fish",
}
const INK := Color(0.4, 0.25, 0.3)

var design: Dictionary = {}
var mode := "set"   # "set" = bed & bowl, "play" = play space
var kind := "bed"
var pet_id := ""

var canvas: Control
var petal: TextureRect
var kind_buttons := {}
var swatches := {"color": [], "trim": []}
var pattern_buttons := {}
var stamp_buttons := {}
var shape_row: HFlowContainer
var shape_buttons := {}
var name_button: Button

var play_stage: Control
var room_stage: Control
var room_options: VBoxContainer
var wall_buttons := {}
var floor_buttons := {}
var room_coin_label: Label
var weather_button: Button
var set_actions: HBoxContainer
var play_actions: HBoxContainer
var set_options: VBoxContainer
var play_options: VBoxContainer
var mode_buttons := {}
var theme_buttons := {}
var shop_buttons := {}
var coin_label: Label
var put_away_button: Button

func _ready() -> void:
	pet_id = PetalState.active_pet
	var paper := ColorRect.new()
	paper.color = Color(1.0, 0.9, 0.94)
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(paper)
	_build()
	design = PetalState.pet_set(pet_id)
	canvas.food_color = SetCanvas.FOOD_COLORS.get(PetalState.pet_species(), SetCanvas.FOOD_COLORS["cat"])
	canvas.bed_name_default = "%s's Bed" % PetalState.pet_name
	canvas.bowl_name_default = "%s's Bowl" % PetalState.pet_name
	play_stage.load_space(PetalState.play_space(pet_id))
	room_stage.load_space(PetalState.play_room(pet_id))
	_refresh()
	_refresh_shop()
	_show_mode()
	PetalState.coins_changed.connect(_refresh_shop)
	petal.position = SPOT_IDLE
	PetCameo.spawn(petal)

# A scroll box keeps every control reachable above the bottom bar: the stage
# and its buttons on the left, the design controls on the right.
func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	scroll.add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	margin.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	var stage := Control.new()
	stage.custom_minimum_size = STAGE_SIZE
	left.add_child(stage)
	canvas = SetCanvas.new()
	canvas.size = STAGE_SIZE
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(canvas)
	play_stage = PlayStage.new()
	play_stage.size = STAGE_SIZE
	play_stage.changed.connect(_on_play_changed)
	play_stage.selection_changed.connect(_refresh_put_away)
	stage.add_child(play_stage)
	room_stage = PlayStage.new()
	room_stage.is_room = true
	room_stage.size = STAGE_SIZE
	room_stage.changed.connect(_on_play_changed)
	room_stage.selection_changed.connect(_refresh_put_away)
	stage.add_child(room_stage)
	petal = TextureRect.new()
	petal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	petal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	petal.size = PET_SIZE
	petal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(petal)

	set_actions = _action_row(left)
	set_actions.add_child(_action_button("😴 Nap", _on_nap))
	set_actions.add_child(_action_button("🍽️ Eat", _on_eat))
	set_actions.add_child(_action_button("🧸 Play", _on_toy))
	set_actions.add_child(_action_button("🎲 Surprise me!", _on_surprise))
	set_actions.add_child(_action_button("✅ I love it!", _on_done))
	play_actions = _action_row(left)
	play_actions.add_child(_action_button("🎉 Play!", _on_play))
	put_away_button = _action_button("🧺 Put away", _on_put_away)
	play_actions.add_child(put_away_button)
	weather_button = _action_button("🌦️ Weather", _on_weather)
	play_actions.add_child(weather_button)
	play_actions.add_child(_action_button("🧹 Clear all", _on_clear))
	play_actions.add_child(_action_button("✅ I love it!", _on_play_done))

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.97, 0.98)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	columns.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	outer.add_child(modes)
	var mode_group := ButtonGroup.new()
	for entry in [["set", "🛏️ Bed & Bowl"], ["play", "🎪 Play Space"], ["room", "🏠 Play Room"]]:
		var tab := Button.new()
		tab.text = entry[1]
		tab.toggle_mode = true
		tab.button_group = mode_group
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0, 50)
		tab.add_theme_font_size_override("font_size", 17)
		tab.pressed.connect(_on_mode.bind(String(entry[0])))
		modes.add_child(tab)
		mode_buttons[entry[0]] = tab
	set_options = VBoxContainer.new()
	set_options.add_theme_constant_override("separation", 8)
	outer.add_child(set_options)
	play_options = VBoxContainer.new()
	play_options.add_theme_constant_override("separation", 8)
	outer.add_child(play_options)
	room_options = VBoxContainer.new()
	room_options.add_theme_constant_override("separation", 8)
	outer.add_child(room_options)
	var options := set_options
	_build_play_options()
	_build_room_options()

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	options.add_child(tabs)
	var group := ButtonGroup.new()
	for entry in [["bed", "🛏️ Bed"], ["bowl", "🥣 Bowl"], ["toy", "🧸 Toy"], ["pillow", "🛋️ Pillow"]]:
		var tab := Button.new()
		tab.text = entry[1]
		tab.toggle_mode = true
		tab.button_group = group
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0, 46)
		tab.add_theme_font_size_override("font_size", 17)
		tab.pressed.connect(_on_kind.bind(String(entry[0])))
		tabs.add_child(tab)
		kind_buttons[entry[0]] = tab

	for field in ["color", "trim"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		options.add_child(_titled("🎨 Colour" if field == "color" else "🎀 Trim", row))
		for i in range(PetalState.SET_COLORS.size()):
			var swatch := Button.new()
			swatch.custom_minimum_size = Vector2(32, 32)
			swatch.pressed.connect(_on_swatch.bind(field, i))
			row.add_child(swatch)
			swatches[field].append(swatch)

	var patterns := HFlowContainer.new()
	options.add_child(_titled("✨ Pattern", patterns))
	for id in PetalState.SET_PATTERNS:
		pattern_buttons[id] = _option_button(patterns, PATTERN_LABELS[id], 17, Vector2(0, 38), _on_pattern.bind(id))

	var stamps := HFlowContainer.new()
	options.add_child(_titled("🌟 Stamp", stamps))
	for id in PetalState.SET_STAMPS:
		stamp_buttons[id] = _option_button(stamps, id if id != "" else "🚫", 22, Vector2(44, 40), _on_stamp.bind(id))

	shape_row = HFlowContainer.new()
	options.add_child(_titled("📐 Shape", shape_row))

	name_button = Button.new()
	name_button.custom_minimum_size = Vector2(0, 44)
	name_button.add_theme_font_size_override("font_size", 19)
	name_button.pressed.connect(_on_name)
	options.add_child(name_button)
	var hint := Label.new()
	hint.text = "💭 %s has a secret favourite colour. Can you find it?" % PetalState.pet_name
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", INK)
	options.add_child(hint)

func _action_row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row

# The shop: themes and toys, each showing its price until it's bought.
func _build_play_options() -> void:
	coin_label = Label.new()
	coin_label.add_theme_font_size_override("font_size", 20)
	coin_label.add_theme_color_override("font_color", INK)
	play_options.add_child(coin_label)
	var themes := HFlowContainer.new()
	play_options.add_child(_titled("🌍 Place", themes))
	for id in PetalState.PLAY_THEMES:
		theme_buttons[id] = _option_button(themes, "", 16, Vector2(0, 40), _on_theme.bind(id))
	var shop := HFlowContainer.new()
	shop.add_theme_constant_override("h_separation", 4)
	shop.add_theme_constant_override("v_separation", 4)
	play_options.add_child(_titled("🛍️ Toys", shop))
	for id in PetalState.PLAY_ITEMS:
		var button := _option_button(shop, "", 17, Vector2(82, 66), _on_shop.bind(id))
		button.toggle_mode = false
		shop_buttons[id] = button

func _build_room_options() -> void:
	room_coin_label = Label.new()
	room_coin_label.add_theme_font_size_override("font_size", 20)
	room_coin_label.add_theme_color_override("font_color", INK)
	room_options.add_child(room_coin_label)
	var walls := HFlowContainer.new()
	room_options.add_child(_titled("🎨 Walls", walls))
	for id in PetalState.ROOM_WALLS:
		wall_buttons[id] = _option_button(walls, "", 15, Vector2(0, 38), _on_wall.bind(id))
	var floors := HFlowContainer.new()
	room_options.add_child(_titled("🟫 Floor", floors))
	for id in PetalState.ROOM_FLOORS:
		floor_buttons[id] = _option_button(floors, "", 15, Vector2(0, 38), _on_floor.bind(id))
	var furniture := HFlowContainer.new()
	furniture.add_theme_constant_override("h_separation", 4)
	furniture.add_theme_constant_override("v_separation", 4)
	room_options.add_child(_titled("🛋️ Stuff", furniture))
	for id in PetalState.ROOM_ITEMS:
		var button := _option_button(furniture, "", 17, Vector2(72, 62), _on_shop.bind(id))
		button.toggle_mode = false
		shop_buttons[id] = button

func _stage() -> Control:
	return room_stage if mode == "room" else play_stage

func _titled(title: String, content: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(92, 0)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", INK)
	row.add_child(label)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(content)
	return row

func _action_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(128, 48)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	return button

func _option_button(parent: Control, text: String, font_size: int, min_size: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

# --- Showing the current design ---------------------------------------------

func _piece() -> Dictionary:
	return design[kind]

func _refresh() -> void:
	canvas.set_design(design)
	var piece := _piece()
	for id in kind_buttons:
		kind_buttons[id].set_pressed_no_signal(id == kind)
	for field in swatches:
		for i in range(swatches[field].size()):
			swatches[field][i].add_theme_stylebox_override("normal", _swatch_style(i, i == int(piece[field])))
			swatches[field][i].add_theme_stylebox_override("hover", _swatch_style(i, true))
			swatches[field][i].add_theme_stylebox_override("pressed", _swatch_style(i, true))
	for id in pattern_buttons:
		pattern_buttons[id].set_pressed_no_signal(id == piece["pattern"])
	for id in stamp_buttons:
		stamp_buttons[id].set_pressed_no_signal(id == piece["stamp"])
	_rebuild_shapes()
	name_button.visible = kind == "bed" or kind == "bowl"
	name_button.text = "✏️ Name the %s: %s" % [kind, canvas.bed_name.text if kind == "bed" else canvas.bowl_name.text]

func _price_text(id: String) -> String:
	if PetalState.play_cost(id) == 0:
		return "free"
	return "✓" if PetalState.play_unlocked(id) else "🪙 %d" % PetalState.play_cost(id)

func _refresh_shop() -> void:
	coin_label.text = "🪙 You have %d Treat Coin%s" % [PetalState.coins, "" if PetalState.coins == 1 else "s"]
	room_coin_label.text = coin_label.text
	for id in wall_buttons:
		_label_choice(wall_buttons[id], id, id == room_stage.wall)
	for id in floor_buttons:
		_label_choice(floor_buttons[id], id, id == room_stage.floor_id)
	for id in shop_buttons:
		var data: Dictionary = PetalState.play_def(id)
		var button: Button = shop_buttons[id]
		button.text = "%s\n%s" % [data["emoji"], _price_text(id)]
		button.tooltip_text = String(data["label"])
		button.modulate = Color.WHITE if PetalState.play_unlocked(id) or PetalState.coins >= PetalState.play_cost(id) else Color(0.6, 0.6, 0.6)
	for id in theme_buttons:
		var data: Dictionary = PetalState.PLAY_THEMES[id]
		theme_buttons[id].text = "%s %s %s" % [data["emoji"], data["label"], "" if PetalState.play_cost(id) == 0 and id == "cosy" else _price_text(id)]
		theme_buttons[id].set_pressed_no_signal(id == play_stage.backdrop)
		theme_buttons[id].modulate = Color.WHITE if PetalState.play_unlocked(id) or PetalState.coins >= PetalState.play_cost(id) else Color(0.6, 0.6, 0.6)

func _label_choice(button: Button, id: String, current: bool) -> void:
	var data: Dictionary = PetalState.play_def(id)
	button.text = "%s %s %s" % [data["emoji"], data["label"], _price_text(id) if PetalState.play_cost(id) > 0 else ""]
	button.set_pressed_no_signal(current)
	button.modulate = Color.WHITE if PetalState.play_unlocked(id) or PetalState.coins >= PetalState.play_cost(id) else Color(0.6, 0.6, 0.6)

func _refresh_put_away() -> void:
	put_away_button.disabled = _stage().selected == null

func _swatch_style(index: int, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PetalState.SET_COLORS[index]
	style.set_corner_radius_all(16)
	style.set_border_width_all(4 if selected else 1)
	style.border_color = INK if selected else PetalState.SET_COLORS[index].darkened(0.3)
	return style

# The bed and the bowl each have their own shapes to choose from.
func _rebuild_shapes() -> void:
	for child in shape_row.get_children():
		shape_row.remove_child(child)
		child.queue_free()
	shape_buttons.clear()
	for id in PetalState.SET_SHAPES[kind]:
		var button := _option_button(shape_row, SHAPE_LABELS[id], 17, Vector2(0, 38), _on_shape.bind(id))
		button.set_pressed_no_signal(id == _piece()["shape"])
		shape_buttons[id] = button

func _changed() -> void:
	PetalState.save_pet_set(pet_id, design)
	_refresh()
	_boing(canvas)

# A little squash-and-bounce so every tap feels alive.
func _boing(node: Control) -> void:
	Sfx.pop(self)
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2(1.025, 0.975)
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- Bed & Bowl or Play Space ------------------------------------------------

func _on_mode(which: String) -> void:
	mode = which
	_show_mode()

func _show_mode() -> void:
	var playing := mode == "play"
	var decorating := mode == "room"
	canvas.visible = mode == "set"
	play_stage.visible = playing
	room_stage.visible = mode == "room"
	set_actions.visible = mode == "set"
	play_actions.visible = playing or decorating
	set_options.visible = mode == "set"
	play_options.visible = playing
	room_options.visible = decorating
	weather_button.visible = playing
	for id in mode_buttons:
		mode_buttons[id].set_pressed_no_signal(id == mode)
	_refresh_put_away()
	_refresh_shop()

func _on_shop(id: String) -> void:
	if not _buy(id, shop_buttons[id]):
		return
	if _stage().is_full():
		_pop("🧺 full! put one away", shop_buttons[id])
		return
	_stage().add_item(id)
	Sfx.pop(self)

func _on_theme(id: String) -> void:
	if not _buy(id, theme_buttons[id]):
		theme_buttons[id].set_pressed_no_signal(id == play_stage.backdrop)
		return
	play_stage.set_theme_id(id)
	Sfx.chime(self)

# Spends coins the first time; shows how many more are needed if short.
func _buy(id: String, button: Control) -> bool:
	if PetalState.play_unlocked(id):
		return true
	var short := PetalState.play_cost(id) - PetalState.coins
	if not PetalState.try_buy_play(id):
		_pop("🔒 need %d more coins" % short, button)
		return false
	_pop("🔓 bought! ✨", button)
	Sfx.chime(self)
	_refresh_shop()
	return true

func _on_wall(id: String) -> void:
	if not _buy(id, wall_buttons[id]):
		wall_buttons[id].set_pressed_no_signal(id == room_stage.wall)
		return
	room_stage.set_wall_id(id)
	Sfx.chime(self)

func _on_floor(id: String) -> void:
	if not _buy(id, floor_buttons[id]):
		floor_buttons[id].set_pressed_no_signal(id == room_stage.floor_id)
		return
	room_stage.set_floor_id(id)
	Sfx.chime(self)

func _on_play_changed() -> void:
	PetalState.save_play_space(pet_id, play_stage.to_space())
	PetalState.save_play_room(pet_id, room_stage.to_space())
	_refresh_shop()

func _on_put_away() -> void:
	_stage().remove_selected()
	Sfx.pop(self)

func _on_weather() -> void:
	var icon: String = play_stage.next_weather()
	Sfx.pop(self)
	_pop("%s" % (icon if icon != "" else "☀️ sunny"), petal)

func _on_clear() -> void:
	_stage().clear_all()

# The pet runs round her toys one by one, so the space comes alive.
var playing_now := false

func _on_play() -> void:
	if playing_now:
		return
	if _stage().items.is_empty():
		_pop("buy something first! 🛍️", petal)
		return
	playing_now = true
	var order: Array = _stage().items.duplicate()
	order.shuffle()
	for item in order.slice(0, 5):
		if not is_instance_valid(item) or not is_instance_valid(petal):
			break
		var center: Vector2 = item.position + item.size / 2.0
		var spot := (center - PET_SIZE / 2.0 + Vector2(-50, 10)).clamp(Vector2.ZERO, STAGE_SIZE - PET_SIZE)
		var tween := create_tween()
		tween.tween_property(petal, "position", spot, 0.5).set_trans(Tween.TRANS_SINE)
		await tween.finished
		if not is_instance_valid(petal):
			break
		_stage().bounce(item)
		Sfx.pop(self)
		_pop(["wheee!", "yay!", "fun!", "🥰", "again!"].pick_random(), petal)
		await PetCameo.jump_for_joy(petal)
	playing_now = false

func _on_play_done() -> void:
	if mode == "room":
		PetalState.finish_play_room(pet_id, room_stage.to_space())
	else:
		PetalState.finish_play_space(pet_id, play_stage.to_space())
	var at := petal.global_position + petal.size / 2.0
	Confetti.burst(self, at, 24)
	Sfx.fanfare(self)
	_pop("🎉 What a lovely room!" if mode == "room" else "🎉 What a play space!", petal)
	PetCameo.jump_for_joy(petal)

# --- Choosing things ---------------------------------------------------------

func _on_kind(which: String) -> void:
	kind = which
	_refresh()

func _on_swatch(field: String, index: int) -> void:
	_piece()[field] = index
	_changed()
	if field == "color" and index == PetalState.favourite_color(pet_id):
		_pop("💖 my favourite colour!", petal)
		Sfx.chime(self)
		Confetti.burst(self, petal.global_position + petal.size / 2.0, 16)
		PetCameo.jump_for_joy(petal)

func _on_pattern(id: String) -> void:
	_piece()["pattern"] = id
	_changed()

func _on_stamp(id: String) -> void:
	_piece()["stamp"] = id
	_changed()
	if id != "":
		var stamp_label: Label = canvas.get(kind + "_stamp")
		Confetti.burst(self, stamp_label.global_position + stamp_label.size / 2.0, 8)

func _on_shape(id: String) -> void:
	_piece()["shape"] = id
	_changed()

func _on_name() -> void:
	var title := "Name the %s ✏️" % kind
	var editor := NameEditor.open(self, title, String(_piece()["name"]), "Cancel")
	editor.submitted.connect(_on_named)

func _on_named(text: String) -> void:
	_piece()["name"] = text.left(PetalState.SET_NAME_MAX)
	_changed()

func _on_surprise() -> void:
	for which in PetalState.SET_KINDS:
		var piece: Dictionary = design[which]
		piece["color"] = randi() % PetalState.SET_COLORS.size()
		piece["trim"] = (int(piece["color"]) + 3 + randi() % 6) % PetalState.SET_COLORS.size()
		piece["pattern"] = PetalState.SET_PATTERNS.pick_random()
		piece["stamp"] = PetalState.SET_STAMPS.pick_random()
		piece["shape"] = PetalState.SET_SHAPES[which].pick_random()
	_changed()
	_pop("🎲 ta-da!", petal)

# --- The pet tries it out ----------------------------------------------------

func _on_nap() -> void:
	_walk_pet(SPOT_BED, "😴 so cozy!")

func _on_toy() -> void:
	await _walk_pet(SPOT_TOY, "🧸 wheee!")
	for i in range(2):
		if is_instance_valid(petal):
			await PetCameo.jump_for_joy(petal)

func _on_eat() -> void:
	_walk_pet(SPOT_BOWL, "😋 yum yum!")

func _walk_pet(spot: Vector2, text: String) -> void:
	var tween := create_tween()
	tween.tween_property(petal, "position", spot, 0.6).set_trans(Tween.TRANS_SINE)
	await tween.finished
	if not is_instance_valid(petal):
		return
	_pop(text, petal)
	PetCameo.jump_for_joy(petal)

func _on_done() -> void:
	PetalState.finish_pet_set(pet_id, design)
	Sfx.fanfare(self)
	var at := petal.global_position + petal.size / 2.0
	Confetti.burst(self, at, 24)
	_pop("🎉 Beautiful set!", petal)
	PetCameo.jump_for_joy(petal)

func _pop(text: String, near: Control) -> void:
	Feedback.pop(self, text, near.global_position - global_position + Vector2(0, -20))
