extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const Confetti = preload("res://scripts/confetti.gd")

const PET_SIZE := Vector2(220, 200)

# Each case: something goes missing, 4 suspects, and clues that rule suspects
# out one by one. Nobody can win by tapping at random - the accuse button only
# unlocks after every clue is found, and a wrong guess is explained by the
# clue that proves that suspect innocent.
const CASES := [
	{
		"id": "cookies", "emoji": "🍪", "title": "The Missing Cookies",
		"story": "🫙🍪 ➡️ 😱",
		"suspects": [
			{"id": "mimi", "emoji": "🐭", "name": "Mimi", "icons": "🤏 〰️"},
			{"id": "bruno", "emoji": "🐻", "name": "Bruno", "icons": "🏔️ 🐾"},
			{"id": "pip", "emoji": "🐦", "name": "Pip", "icons": "🪶 🪽"},
			{"id": "hop", "emoji": "🐸", "name": "Hop", "icons": "🟢 🦵"},
		],
		"clues": [
			{"emoji": "👣", "pic": "👣 🤏", "text": "Tiny footprints, no bigger than a button!"},
			{"emoji": "🪟", "pic": "🪟🔒 ➡️ 🚫🪽", "text": "The window is shut tight. Nobody flew in!"},
			{"emoji": "🍪", "pic": "🍪 〰️", "text": "A long skinny tail swept through the crumbs."},
		],
		"culprit": "mimi",
		"alibis": {
			"bruno": "Bruno has BIG feet, but the footprints are tiny!",
			"pip": "The window was shut, so Pip could not fly in!",
			"hop": "Frogs have no tail, but a long tail swept the crumbs!",
		},
		"confession": "Squeak! It was me. I was SO hungry. I'm sorry!",
	},
	{
		"id": "teddy", "emoji": "🧸", "title": "The Missing Teddy",
		"story": "🧸 ➡️ 💨 😱",
		"suspects": [
			{"id": "dilly", "emoji": "🦆", "name": "Dilly", "icons": "🪶 🟡"},
			{"id": "henny", "emoji": "🐔", "name": "Henny", "icons": "🪶 🔴"},
			{"id": "snowy", "emoji": "🐰", "name": "Snowy", "icons": "🧶 ⚪"},
			{"id": "rusty", "emoji": "🐶", "name": "Rusty", "icons": "🧶 🟤 👃"},
		],
		"clues": [
			{"emoji": "📦", "pic": "📦 🧶", "text": "Soft fur is stuck to the lid."},
			{"emoji": "🧹", "pic": "🧹 🟤", "text": "There are brown hairs on the floor. Not white ones!"},
			{"emoji": "🪟", "pic": "🪟 👃💦", "text": "A big wet nose smudge is on the glass."},
		],
		"culprit": "rusty",
		"alibis": {
			"dilly": "Ducks have feathers, but the toy box has fur on it!",
			"henny": "Hens have feathers, but the toy box has fur on it!",
			"snowy": "Snowy is white, but the hairs are brown!",
		},
		"confession": "Woof... I just wanted a cuddle buddy. Sorry!",
	},
	{
		"id": "paint", "emoji": "🎨", "title": "The Paint Splash",
		"story": "🎨 💦 🧱 😱",
		"suspects": [
			{"id": "finn", "emoji": "🐟", "name": "Finn", "icons": "🌊 🚫🦶"},
			{"id": "rosie", "emoji": "🐷", "name": "Rosie", "icons": "🦶 🩷 🐽"},
			{"id": "daisy", "emoji": "🐮", "name": "Daisy", "icons": "🦶 ⚫⚪", "art": "res://Sprites/mystery/cow.png"},
			{"id": "woolly", "emoji": "🐑", "name": "Woolly", "icons": "🦶 ⚪ ☁️"},
		],
		"clues": [
			{"emoji": "🐾", "pic": "🐾🐾🐾🐾 🦶", "text": "Four little hoof prints walked away."},
			{"emoji": "🧱", "pic": "🧱 🩷", "text": "There are PINK smudges where someone rubbed the wall."},
			{"emoji": "👂", "pic": "🐽 👀", "text": "Somebody heard a happy OINK!"},
		],
		"culprit": "rosie",
		"alibis": {
			"finn": "Fish have no legs, so no hoof prints from Finn!",
			"daisy": "Daisy is black and white, but the smudges are pink!",
			"woolly": "Woolly is white and says baa, but someone said oink!",
		},
		"confession": "Oink! I thought the wall needed to be pink. Oops!",
	},
	{
		"id": "cake", "emoji": "🎂", "title": "The Birthday Cake",
		"story": "🎂 ⬆️ ➡️ 💨 😱",
		"suspects": [
			{"id": "leo", "emoji": "🦁", "name": "Leo", "icons": "🏔️ 🦁"},
			{"id": "coco", "emoji": "🐵", "name": "Coco", "icons": "🤏 🖐️ 🍌"},
			{"id": "ella", "emoji": "🐘", "name": "Ella", "icons": "🏔️ 🐘"},
			{"id": "percy", "emoji": "🐧", "name": "Percy", "icons": "🤏 🚫🖐️"},
		],
		"clues": [
			{"emoji": "🖐️", "pic": "🖐️ ✨", "text": "Sticky FINGERprints are on the plate."},
			{"emoji": "🪟", "pic": "🪟 🤏", "text": "The open window is tiny. Only a small friend fits through."},
			{"emoji": "🍌", "pic": "🍌 👀", "text": "There is a banana peel by the shelf."},
		],
		"culprit": "coco",
		"alibis": {
			"leo": "Leo is much too big for the tiny window!",
			"ella": "Ella is much too big for the tiny window!",
			"percy": "Penguins have flippers, so they can't leave fingerprints!",
		},
		"confession": "Ooh ooh! The cake smelled like bananas. Sorry!",
	},
	{
		"id": "crown", "emoji": "👑", "title": "The Sparkly Crown",
		"story": "👑 ✨ ➡️ 💨 😱",
		"suspects": [
			{"id": "tilly", "emoji": "🐢", "name": "Tilly", "icons": "⏳ 🐢"},
			{"id": "sid", "emoji": "🐌", "name": "Sid", "icons": "⏳ 🐌"},
			{"id": "clover", "emoji": "🐂", "name": "Clover", "icons": "🌿 🚫🪶", "art": "res://Sprites/mystery/bull.png"},
			{"id": "maggie", "emoji": "🐦", "name": "Maggie", "icons": "⚡ 🪶 ✨"},
		],
		"clues": [
			{"emoji": "⚡", "pic": "⚡ 🏃", "text": "It was gone in a FLASH. The thief is fast!"},
			{"emoji": "🪶", "pic": "🪶 🪟", "text": "Black and white feathers are on the sill."},
			{"emoji": "🪺", "pic": "🪺 ✨", "text": "A nest up high is full of shiny things."},
		],
		"culprit": "maggie",
		"alibis": {
			"tilly": "Tilly is far too slow to be gone in a flash!",
			"sid": "Sid is much too slow. It would take him a whole week!",
			"clover": "Bulls have no feathers, but feathers were on the sill!",
		},
		"confession": "Squawk! It was so SHINY. I'll give it back!",
	},
]

var case_data: Dictionary = {}
var found: Array = []
var picked := ""
var solved_now := false

var title_label: Label
var story_label: Label
var clue_row: HBoxContainer
var notebook_label: Label
var suspect_row: HBoxContainer
var accuse_button: Button
var next_button: Button
var bubble: Label
var petal: TextureRect
var clue_buttons: Array[Button] = []
var suspect_buttons := {}

func _ready() -> void:
	var paper := ColorRect.new()
	paper.color = Color(0.85, 0.88, 1.0)
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(paper)
	_build()
	petal = TextureRect.new()
	petal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	petal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	petal.size = PET_SIZE
	petal.position = Vector2(24, 560)
	petal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(petal)
	PetCameo.spawn(petal)
	_start_case(_first_unsolved())

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	title_label = _label(34, Color(0.25, 0.2, 0.55))
	box.add_child(title_label)
	story_label = _label(60, Color(0.2, 0.2, 0.3))
	box.add_child(story_label)

	box.add_child(_label(20, Color(0.4, 0.4, 0.6), "🔍 👆"))
	clue_row = HBoxContainer.new()
	clue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	clue_row.add_theme_constant_override("separation", 14)
	box.add_child(clue_row)

	notebook_label = _label(44, Color(0.2, 0.2, 0.3))
	notebook_label.custom_minimum_size = Vector2(0, 70)
	box.add_child(notebook_label)

	box.add_child(_label(20, Color(0.4, 0.4, 0.6), "🕵️ ❓ 👇"))
	suspect_row = HBoxContainer.new()
	suspect_row.alignment = BoxContainer.ALIGNMENT_CENTER
	suspect_row.add_theme_constant_override("separation", 14)
	box.add_child(suspect_row)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	accuse_button = Button.new()
	accuse_button.custom_minimum_size = Vector2(360, 56)
	accuse_button.add_theme_font_size_override("font_size", 22)
	accuse_button.pressed.connect(_on_accuse)
	buttons.add_child(accuse_button)
	next_button = Button.new()
	next_button.text = "➡️ Next mystery"
	next_button.custom_minimum_size = Vector2(240, 56)
	next_button.add_theme_font_size_override("font_size", 22)
	next_button.pressed.connect(_on_next)
	buttons.add_child(next_button)

	# The pet's speech bubble sits to the right of her corner.
	bubble = Label.new()
	bubble.position = Vector2(260, 590)
	bubble.custom_minimum_size = Vector2(760, 0)
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.add_theme_font_size_override("font_size", 24)
	bubble.add_theme_color_override("font_color", Color(0.25, 0.2, 0.55))
	add_child(bubble)

func _label(size: int, color: Color, text := "") -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _first_unsolved() -> int:
	for i in range(CASES.size()):
		if not PetalState.solved_cases.has(CASES[i]["id"]):
			return i
	return randi() % CASES.size()

func _start_case(index: int) -> void:
	case_data = CASES[index]
	found = []
	picked = ""
	solved_now = false
	title_label.text = "%s  %s" % [case_data["emoji"], case_data["title"]]
	story_label.text = case_data["story"]

	for child in clue_row.get_children():
		child.queue_free()
	clue_buttons.clear()
	var clues: Array = case_data["clues"]
	for i in range(clues.size()):
		var button := Button.new()
		button.custom_minimum_size = Vector2(190, 84)
		button.add_theme_font_size_override("font_size", 44)
		button.pressed.connect(_on_clue.bind(i))
		clue_row.add_child(button)
		clue_buttons.append(button)

	for child in suspect_row.get_children():
		child.queue_free()
	suspect_buttons.clear()
	for suspect in case_data["suspects"]:
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(250, 200)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 30)
		button.text = "%s\n%s\n%s" % [suspect["emoji"], suspect["name"], suspect["icons"]]
		if suspect.has("art"):
			button.icon = load(String(suspect["art"]))
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.add_theme_constant_override("icon_max_width", 90)
		button.pressed.connect(_on_suspect.bind(String(suspect["id"])))
		suspect_row.add_child(button)
		suspect_buttons[suspect["id"]] = button

	next_button.visible = false
	_say("🕵️ 🔍 👇")
	_refresh()

func _say(text: String) -> void:
	bubble.text = "💬 " + text

func _refresh() -> void:
	var clues: Array = case_data["clues"]
	for i in range(clues.size()):
		var done := found.has(i)
		clue_buttons[i].text = "%s%s" % [clues[i]["emoji"], " ✅" if done else ""]
	var pics: Array[String] = []
	for i in found:
		pics.append(String(clues[i]["pic"]))
	notebook_label.text = "📓   " + "      ".join(pics)
	var ready := found.size() == clues.size()
	accuse_button.disabled = solved_now or not ready
	if solved_now:
		accuse_button.text = "🎉 Case closed!"
	elif ready:
		accuse_button.text = "🕵️ It was them!"
	else:
		accuse_button.text = "🔍 Find all clues first (%d/%d)" % [found.size(), clues.size()]
	for id in suspect_buttons:
		suspect_buttons[id].button_pressed = (id == picked)

func _on_clue(index: int) -> void:
	if solved_now:
		return
	if not found.has(index):
		found.append(index)
	var clue: Dictionary = case_data["clues"][index]
	_say(String(clue["pic"]))
	_refresh()
	if found.size() == case_data["clues"].size():
		_say("%s   🤔 ➡️ 🕵️ 👇" % clue["pic"])

func _on_suspect(id: String) -> void:
	picked = id
	_refresh()

func _on_accuse() -> void:
	if picked == "":
		_say("👆 🕵️ ❓")
		return
	if picked == case_data["culprit"]:
		_solve()
		return
	var suspect_name := ""
	for suspect in case_data["suspects"]:
		if suspect["id"] == picked:
			suspect_name = suspect["name"]
	_say("❌ %s   🤔 📓 👀   (%s)" % [suspect_name, case_data["alibis"][picked]])
	suspect_buttons[picked].disabled = true
	picked = ""
	_refresh()

func _solve() -> void:
	solved_now = true
	PetalState.solve_case(String(case_data["id"]))
	_say("🎉 ✅ 🕵️ %s" % case_data["confession"])
	_refresh()
	next_button.visible = true
	var at := petal.global_position + petal.size / 2.0
	Confetti.burst(self, at, 24)
	Feedback.pop(self, "🎉 Case solved!", at)
	PetCameo.jump_for_joy(petal)

func _on_next() -> void:
	var index := CASES.find(case_data)
	_start_case((index + 1) % CASES.size())
