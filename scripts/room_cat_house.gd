extends Control

# Design a cat house with a scratching post. Every pet secretly wants a colour,
# a pattern, a height and a post style. In "Ask her" mode you survey her: tap an
# option and she tells you whether she likes it. In "Build" mode you pick the
# choices, then "Show her" to see how many she loves. All four is a Dream House.

const PetCameo = preload("res://scripts/pet_cameo.gd")
const Confetti = preload("res://scripts/confetti.gd")

const COLORS := {
	"pink": Color(1.0, 0.62, 0.78), "blue": Color(0.55, 0.75, 1.0), "purple": Color(0.75, 0.6, 1.0),
	"yellow": Color(1.0, 0.9, 0.5), "green": Color(0.6, 0.88, 0.62),
}
const PATTERN_EMOJI := {"hearts": "💗", "stars": "⭐", "flowers": "🌸"}
const POST_COLORS := {"rope": Color(0.82, 0.68, 0.45), "carpet": Color(0.62, 0.52, 0.72), "tree": Color(0.55, 0.38, 0.25)}
const POST_TOP := {"rope": "🧶", "carpet": "🐾", "tree": "🌳"}
const CATEGORIES := {
	"color": {"emoji": "🎨", "label": "Colour"},
	"pattern": {"emoji": "🌸", "label": "Pattern"},
	"height": {"emoji": "📏", "label": "Height"},
	"post": {"emoji": "🪢", "label": "Post"},
}

var surveying := true
var house_view: Control = null
var pet: TextureRect = null
var speech: Label = null
var learned: Label = null
var show_button: Button = null
var ask_button: Button = null
var build_button: Button = null
var buttons := {} # category -> {choice: Button}

func _ready() -> void:
	var wall := ColorRect.new()
	wall.color = Color(0.99, 0.93, 0.82)
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wall)
	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0.78, 0.6, 0.42)
	floor_rect.anchor_top = 0.8
	floor_rect.anchor_right = 1.0
	floor_rect.anchor_bottom = 1.0
	add_child(floor_rect)

	house_view = Control.new()
	house_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	house_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(house_view)

	pet = TextureRect.new()
	pet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pet.size = Vector2(200, 190)
	add_child(pet)

	_build_panel()
	resized.connect(_redraw)
	_set_mode(true)
	await get_tree().process_frame
	_redraw()
	PetCameo.spawn(pet)

func _base_y() -> float:
	return size.y * 0.9

func _label_of(category: String, choice: String) -> String:
	match category:
		"pattern":
			return "%s %s" % [PATTERN_EMOJI.get(choice, "〰️"), choice.capitalize()]
		"post":
			return "%s %s" % [POST_TOP[choice], choice.capitalize()]
	return choice.capitalize()

# --- Controls ---------------------------------------------------------------

func _build_panel() -> void:
	var margin := MarginContainer.new()
	margin.anchor_left = 0.52
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	column.add_child(top)
	var title := Label.new()
	title.text = "🏡 Cat House"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.45, 0.25, 0.55))
	top.add_child(title)
	ask_button = _button("📋 Ask her", func() -> void: _set_mode(true))
	build_button = _button("🎨 Build", func() -> void: _set_mode(false))
	top.add_child(ask_button)
	top.add_child(build_button)
	top.add_child(_button("⬅ Living", func() -> void: PetalState.navigate_to_room.emit("living")))

	speech = Label.new()
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.custom_minimum_size = Vector2(0, 56)
	speech.add_theme_font_size_override("font_size", 20)
	speech.add_theme_color_override("font_color", Color(0.3, 0.2, 0.35))
	column.add_child(speech)

	for category in CATEGORIES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		column.add_child(row)
		var name_label := Label.new()
		name_label.text = "%s %s" % [CATEGORIES[category]["emoji"], CATEGORIES[category]["label"]]
		name_label.custom_minimum_size = Vector2(100, 0)
		name_label.add_theme_font_size_override("font_size", 17)
		row.add_child(name_label)
		buttons[category] = {}
		for choice in PetalState.HOUSE_CHOICES[category]:
			var button := _button(_label_of(category, choice), _choose.bind(category, choice))
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(button)
			buttons[category][choice] = button

	learned = Label.new()
	learned.add_theme_font_size_override("font_size", 18)
	learned.add_theme_color_override("font_color", Color(0.3, 0.2, 0.35))
	column.add_child(learned)
	show_button = _button("✅ Show her!", _show_her)
	show_button.custom_minimum_size = Vector2(0, 52)
	show_button.add_theme_font_size_override("font_size", 22)
	column.add_child(show_button)

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(action)
	return button

func _set_mode(survey: bool) -> void:
	surveying = survey
	show_button.visible = not survey
	ask_button.modulate = Color(1, 0.9, 0.4) if survey else Color.WHITE
	build_button.modulate = Color.WHITE if survey else Color(1, 0.9, 0.4)
	speech.text = "Ask me what I like! Tap an option and I'll tell you 😺" if survey else "Build my dream house! 🏡 Then tap Show her."
	_refresh()

func _refresh() -> void:
	var wants := PetalState.house_wants_for_pet()
	var known := PetalState.house_known_for_pet()
	var design := PetalState.house_design_for_pet()
	var summary := ""
	for category in CATEGORIES:
		for choice in buttons[category]:
			var button: Button = buttons[category][choice]
			if surveying:
				button.modulate = Color(0.6, 1.0, 0.6) if known.get(category, false) and wants[category] == choice else Color.WHITE
			else:
				button.modulate = Color(1, 0.9, 0.4) if design[category] == choice else Color.WHITE
		summary += "%s %s   " % [CATEGORIES[category]["emoji"], wants[category] if known.get(category, false) else "❔"]
	learned.text = "She wants: " + summary
	_redraw()

func _choose(category: String, choice: String) -> void:
	if surveying:
		_ask(category, choice)
	else:
		PetalState.house_design_for_pet()[category] = choice
		PetalState.save_game()
		_refresh()

func _ask(category: String, choice: String) -> void:
	var wants := PetalState.house_wants_for_pet()
	if wants[category] == choice:
		PetalState.house_known_for_pet()[category] = true
		PetalState.save_game()
		speech.text = "YES! 😻 I love %s!" % choice
		PetCameo.jump_for_joy(pet)
	else:
		speech.text = ["Hmm, not really 😐", "Meh... 😾", "Nope! 🙅"].pick_random()
	_refresh()

func _show_her() -> void:
	var wants := PetalState.house_wants_for_pet()
	var design := PetalState.house_design_for_pet()
	var matches := 0
	var report := ""
	for category in CATEGORIES:
		var ok: bool = design[category] == wants[category]
		matches += 1 if ok else 0
		report += "%s%s " % [CATEGORIES[category]["emoji"], "✅" if ok else "❌"]
	PetalState.house_judged(matches)
	if matches == CATEGORIES.size():
		speech.text = "%s\nIt's my DREAM house!!! 😻🏡" % report
		Confetti.burst(self, pet.global_position + pet.size / 2.0, 40)
		PetCameo.jump_for_joy(pet)
	elif matches >= 2:
		speech.text = "%s\nIt's nice! 😸 Some parts aren't quite me." % report
		PetCameo.jump_for_joy(pet)
	else:
		speech.text = "%s\nHmm... 😿 Try asking me what I like!" % report

# --- The house --------------------------------------------------------------

func _box(color: Color, pos: Vector2, box_size: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.position = pos
	rect.size = box_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	house_view.add_child(rect)
	return rect

func _stamp(text: String, font_size: int, pos: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.position = pos
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	house_view.add_child(label)

func _redraw() -> void:
	if house_view == null:
		return
	for child in house_view.get_children():
		house_view.remove_child(child)
		child.queue_free()
	var design := PetalState.house_design_for_pet()
	var color: Color = COLORS[design["color"]]
	var tall: bool = design["height"] == "tall"
	var base := _base_y()
	pet.position = Vector2(size.x * 0.02, base - pet.size.y)

	var width := 220.0
	var height := 230.0 if tall else 140.0
	var x0 := size.x * 0.2
	var top := base - height
	_box(color, Vector2(x0, top), Vector2(width, height))

	if design["pattern"] == "stripes":
		var y := 0.0
		while y < height - 20.0:
			_box(color.darkened(0.15), Vector2(x0, top + y + 10.0), Vector2(width, 16.0))
			y += 40.0
	else:
		var rows := 3 if tall else 2
		for r in range(rows):
			for c in range(2):
				_stamp(PATTERN_EMOJI[design["pattern"]], 40, Vector2(x0 + 12.0 + c * 130.0, top + 12.0 + r * 55.0))

	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([Vector2(x0 - 22.0, top), Vector2(x0 + width + 22.0, top), Vector2(x0 + width / 2.0, top - 90.0)])
	roof.color = color.darkened(0.25)
	house_view.add_child(roof)
	_box(Color(0.25, 0.15, 0.2), Vector2(x0 + width / 2.0 - 35.0, base - 95.0), Vector2(70, 95))

	# Scratching post beside the house.
	var post: String = design["post"]
	var post_color: Color = POST_COLORS[post]
	var px := x0 + width + 70.0
	var pole := 260.0 if post == "tree" else 190.0
	_box(Color(0.5, 0.36, 0.25), Vector2(px - 38.0, base - 14.0), Vector2(76, 14))
	_box(post_color, Vector2(px - 14.0, base - pole), Vector2(28, pole))
	if post == "rope":
		var y := 6.0
		while y < pole:
			_box(post_color.darkened(0.3), Vector2(px - 14.0, base - pole + y), Vector2(28, 3))
			y += 14.0
	if post == "tree":
		_box(post_color.darkened(0.2), Vector2(px - 55.0, base - pole * 0.5), Vector2(55, 10))
	_box(post_color.darkened(0.2), Vector2(px - 42.0, base - pole - 10.0), Vector2(84, 12))
	_stamp(POST_TOP[post], 40, Vector2(px - 22.0, base - pole - 56.0))
