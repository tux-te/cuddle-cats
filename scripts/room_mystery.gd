extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const Confetti = preload("res://scripts/confetti.gd")

const SUSPECT_ART := {
	"mimi": "field_mouse", "rusty": "puppy", "snowy": "bunny", "woolly": "lamb", "leo": "lion_guardian",
	"tilly": "turtle", "sid": "snail", "fox": "fox", "pip": "chick", "henny": "chick", "bruno": "panda",
	"hop": "capybara", "axel": "axolotl", "fawny": "fawn", "marmie": "marmot", "batty": "bat", "pom": "pomeranian",
	"frenchie": "french_bulldog", "fenny": "fennec", "daisy": "cow", "clover": "bull",
}

const PET_SIZE := Vector2(130, 120)

# Each case: something goes missing, 4 suspects, and clues that rule suspects
# out one by one. Nobody can win by tapping at random - the accuse button only
# unlocks after every clue is found, and a wrong guess is explained by the
# clue that proves that suspect innocent.
const CASES := [
	{
		"id": "biscuit", "emoji": "🐮", "title": "Where is Biscuit the Cow?", "prize": 15,
		"bg": "res://Sprites/backgrounds/garden_sunny.jpg",
		"story": "Oh no! Biscuit the cow is MISSING from the barn! Everyone says they were somewhere else that night. Explore the farm for clues. Whose story is NOT true?",
		"suspects": [
			{"id": "woolly", "emoji": "🐑", "name": "Woolly", "says": "I was fast asleep up in the barn loft all night."},
			{"id": "pom", "emoji": "🐕", "name": "Pom", "says": "I was rolling in the mud puddle by the pond."},
			{"id": "fox", "emoji": "🦊", "name": "Fox", "says": "I was across the river, digging for worms."},
			{"id": "mimi", "emoji": "🐭", "name": "Mimi", "says": "I was hiding in the hay because of the storm."},
		],
		"clues": [
			{"emoji": "🪜", "at": Vector2(0.14, 0.4), "text": "A loud SNORE is coming from the loft. Woolly really was asleep up there!"},
			{"emoji": "🐾", "at": Vector2(0.38, 0.75), "text": "Wet fox prints and fresh worm holes on the far side of the river. Fox's story is TRUE!"},
			{"emoji": "🌾", "at": Vector2(0.62, 0.45), "text": "A tiny mouse nest with a cosy blanket in the hay. Mimi's story is TRUE!"},
			{"emoji": "💧", "at": Vector2(0.86, 0.78), "text": "The mud puddle is bone DRY! Nobody was rolling in it. Pom's story is NOT true!"},
		],
		"culprit": "pom",
		"alibis": {
			"woolly": "Woolly's story is TRUE. The snoring is coming from the loft!",
			"fox": "Fox's story is TRUE. The fox prints are across the river!",
			"mimi": "Mimi's story is TRUE. Her nest is in the hay!",
		},
		"confession": "Woof... Biscuit and I went to the big mud spa behind the barn. I forgot to tell anyone! Biscuit is safe. 🐮",
	},
	{
		"id": "coins", "emoji": "🪙", "title": "The Missing Treat Coins", "prize": 15,
		"bg": "res://Sprites/backgrounds/living_room.jpg",
		"story": "Oh no! The Treat Coin jar is EMPTY! Everyone says where they were all day. Explore the house for clues. Whose story is NOT true?",
		"suspects": [
			{"id": "leo", "emoji": "🦁", "name": "Leo", "says": "I was snoozing on the cushion in the sunny window."},
			{"id": "fenny", "emoji": "🦊", "name": "Fenny", "says": "I was swinging on the garden swing all day."},
			{"id": "frenchie", "emoji": "🐶", "name": "Frenchie", "says": "I was sliding around on the ice pond."},
			{"id": "tilly", "emoji": "🐢", "name": "Tilly", "says": "I was slowly walking to the kitchen for lunch."},
		],
		"clues": [
			{"emoji": "☀️", "at": Vector2(0.16, 0.35), "text": "Golden mane hairs on the warm cushion, and a snore! Leo's story is TRUE!"},
			{"emoji": "🧊", "at": Vector2(0.4, 0.78), "text": "Paw-slide marks all over the ice. Frenchie's story is TRUE!"},
			{"emoji": "👣", "at": Vector2(0.64, 0.6), "text": "A slow, slow trail of turtle footprints toward the kitchen. Tilly's story is TRUE!"},
			{"emoji": "🕸️", "at": Vector2(0.88, 0.3), "text": "Cobwebs all over the swing! Nobody has swung on it. Fenny's story is NOT true!"},
		],
		"culprit": "fenny",
		"alibis": {
			"leo": "Leo's story is TRUE. His mane hairs are on the cushion!",
			"frenchie": "Frenchie's story is TRUE. The slide marks are on the ice!",
			"tilly": "Tilly's story is TRUE. Her footprints go to the kitchen!",
		},
		"confession": "Yip yip... I wanted coins to buy lots of snacks. I'll put them back!",
	},
	{
		"id": "cookies", "emoji": "🍪", "title": "The Missing Cookies",
		"story": "🫙 Oh no! The cookie jar is EMPTY! Who took the cookies?",
		"suspects": [
			{"id": "mimi", "emoji": "🐭", "name": "Mimi", "icons": "tiny • long tail"},
			{"id": "bruno", "emoji": "🐻", "name": "Bruno", "icons": "big • big feet"},
			{"id": "pip", "emoji": "🐦", "name": "Pip", "icons": "feathers • wings"},
			{"id": "hop", "emoji": "🦫", "name": "Cappy", "icons": "brown • no tail"},
		],
		"clues": [
			{"emoji": "👣", "pic": "👣 🤏", "text": "The footprints are TINY. The thief has small feet!"},
			{"emoji": "🪟", "pic": "🪟🔒 ➡️ 🚫🪽", "text": "The window was shut tight. The thief has NO wings!"},
			{"emoji": "🍪", "pic": "🍪 〰️", "text": "A long tail swept the crumbs. The thief has a TAIL!"},
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
		"story": "🧸 Oh no! Teddy is gone from the toy shelf! Who took him?",
		"suspects": [
			{"id": "henny", "emoji": "🐥", "name": "Henny", "icons": "yellow • feathers"},
			{"id": "axel", "emoji": "🦎", "name": "Axel", "icons": "pink • smooth skin"},
			{"id": "snowy", "emoji": "🐰", "name": "Snowy", "icons": "white • fur"},
			{"id": "rusty", "emoji": "🐶", "name": "Rusty", "icons": "brown • fur • wet nose"},
		],
		"clues": [
			{"emoji": "📦", "pic": "📦 🧶", "text": "Soft FUR is stuck to the toy box. The thief has fur!"},
			{"emoji": "🧹", "pic": "🧹 🟤", "text": "The hairs on the floor are BROWN, not white."},
			{"emoji": "🪟", "pic": "🪟 👃💦", "text": "A wet nose smudge is on the window."},
		],
		"culprit": "rusty",
		"alibis": {
			"henny": "Henny has feathers, but the toy box has fur on it!",
			"axel": "Axel has smooth skin, but the toy box has fur on it!",
			"snowy": "Snowy is white, but the hairs are brown!",
		},
		"confession": "Woof... I just wanted a cuddle buddy. Sorry!",
	},
	{
		"id": "paint", "emoji": "🎨", "title": "The Paint Splash",
		"story": "🎨 Oh no! Someone splashed paint all over the barn wall!",
		"suspects": [
			{"id": "sid", "emoji": "🐌", "name": "Sid", "icons": "slimy • no legs"},
			{"id": "daisy", "emoji": "🐮", "name": "Daisy", "icons": "black & white • hooves"},
			{"id": "woolly", "emoji": "🐑", "name": "Woolly", "icons": "white • hooves • says baa"},
			{"id": "fawny", "emoji": "🦌", "name": "Fawny", "icons": "brown • hooves • white spots"},
		],
		"clues": [
			{"emoji": "🐾", "pic": "🐾 🦶", "text": "Hoof prints! The thief has HOOVES."},
			{"emoji": "🧱", "pic": "🧱 🟤", "text": "Brown smudges on the wall. The thief is BROWN!"},
			{"emoji": "🖌️", "pic": "🖌️ ⚪", "text": "White SPOTS on the paintbrush. The thief has spots!"},
		],
		"culprit": "fawny",
		"alibis": {
			"sid": "Snails have no legs, so no hoof prints from Sid!",
			"daisy": "Daisy is black and white, but the smudges are brown!",
			"woolly": "Woolly is white, but the smudges are brown!",
		},
		"confession": "Eep! I wanted to paint the barn brown like me. Oops!",
	},
	{
		"id": "cake", "emoji": "🎂", "title": "The Birthday Cake",
		"story": "🎂 Oh no! The birthday cake was on the high shelf and it's GONE!",
		"suspects": [
			{"id": "leo", "emoji": "🦁", "name": "Leo", "icons": "huge • big mane"},
			{"id": "bruno", "emoji": "🐼", "name": "Bruno", "icons": "huge • black & white"},
			{"id": "pip", "emoji": "🐥", "name": "Pip", "icons": "small • feathers"},
			{"id": "marmie", "emoji": "🐿️", "name": "Marmie", "icons": "small • fur • loves nuts"},
		],
		"clues": [
			{"emoji": "🪟", "pic": "🪟 🤏", "text": "The open window is tiny. Only a SMALL friend fits through."},
			{"emoji": "🎂", "pic": "🎂 🧶", "text": "Soft FUR tufts are stuck on the shelf. The thief has fur!"},
			{"emoji": "🌰", "pic": "🌰 👀", "text": "Nutshells on the floor! The thief loves NUTS."},
		],
		"culprit": "marmie",
		"alibis": {
			"leo": "Leo is much too big for the tiny window!",
			"bruno": "Bruno is much too big for the tiny window!",
			"pip": "Pip has feathers, but fur was stuck on the shelf!",
		},
		"confession": "Squeak! The cake smelled like nuts. Sorry!",
	},
	{
		"id": "crown", "emoji": "👑", "title": "The Sparkly Crown",
		"story": "👑 Oh no! The sparkly crown vanished in a flash!",
		"suspects": [
			{"id": "tilly", "emoji": "🐢", "name": "Tilly", "icons": "a slow, slow turtle"},
			{"id": "sid", "emoji": "🐌", "name": "Sid", "icons": "an even slower snail"},
			{"id": "clover", "emoji": "🐂", "name": "Clover", "icons": "eats grass • no wings"},
			{"id": "batty", "emoji": "🦇", "name": "Batty", "icons": "fast • wings • loves shiny things"},
		],
		"clues": [
			{"emoji": "⚡", "pic": "⚡ 🏃", "text": "Gone in a flash! The thief is FAST."},
			{"emoji": "🪽", "pic": "🪽 🪟", "text": "Wing marks on the windowsill. The thief has WINGS!"},
			{"emoji": "🪺", "pic": "🪺 ✨", "text": "A cosy nook up high is full of shiny things."},
		],
		"culprit": "batty",
		"alibis": {
			"tilly": "Tilly is far too slow to be gone in a flash!",
			"sid": "Sid is much too slow. It would take him a whole week!",
			"clover": "Bulls have no wings, but wing marks were on the sill!",
		},
		"confession": "Squeak! It was so SHINY. I'll give it back!",
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
var scene_panel: Control
var who_label: Label
var clue_buttons: Array[Button] = []
var suspect_buttons := {}

func _ready() -> void:
	var paper := ColorRect.new()
	paper.color = Color(0.85, 0.88, 1.0)
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(paper)
	_build()
	PetCameo.spawn(petal)
	_start_case(_first_unsolved())

# Everything sits in a scroll box (so nothing can end up hidden behind the
# bottom bar), with the pet and her speech bubble at the top.
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
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	var pet_slot := Control.new()
	pet_slot.custom_minimum_size = PET_SIZE
	top.add_child(pet_slot)
	petal = TextureRect.new()
	petal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	petal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	petal.size = PET_SIZE
	petal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pet_slot.add_child(petal)
	var talk := VBoxContainer.new()
	talk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	talk.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(talk)
	title_label = _label(30, Color(0.25, 0.2, 0.55))
	talk.add_child(title_label)
	story_label = _label(20, Color(0.2, 0.2, 0.3))
	talk.add_child(story_label)
	bubble = _label(20, Color(0.25, 0.2, 0.55))
	talk.add_child(bubble)

	box.add_child(_label(16, Color(0.4, 0.4, 0.6), "🔍 Tap the pictures to look for clues"))
	clue_row = HBoxContainer.new()
	clue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	clue_row.add_theme_constant_override("separation", 14)
	box.add_child(clue_row)

	scene_panel = Control.new()
	scene_panel.custom_minimum_size = Vector2(0, 280)
	scene_panel.clip_contents = true
	scene_panel.visible = false
	box.add_child(scene_panel)

	notebook_label = _label(18, Color(0.2, 0.2, 0.3))
	notebook_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(notebook_label)

	who_label = _label(16, Color(0.4, 0.4, 0.6))
	box.add_child(who_label)
	suspect_row = HBoxContainer.new()
	suspect_row.alignment = BoxContainer.ALIGNMENT_CENTER
	suspect_row.add_theme_constant_override("separation", 10)
	box.add_child(suspect_row)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	accuse_button = Button.new()
	accuse_button.custom_minimum_size = Vector2(340, 48)
	accuse_button.add_theme_font_size_override("font_size", 20)
	accuse_button.pressed.connect(_on_accuse)
	buttons.add_child(accuse_button)
	next_button = Button.new()
	next_button.text = "➡️ Next mystery"
	next_button.custom_minimum_size = Vector2(220, 48)
	next_button.add_theme_font_size_override("font_size", 20)
	next_button.pressed.connect(_on_next)
	buttons.add_child(next_button)

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
	for child in scene_panel.get_children():
		child.queue_free()
	clue_buttons.clear()
	var has_scene := case_data.has("bg")
	scene_panel.visible = has_scene
	clue_row.visible = not has_scene
	if has_scene:
		var backdrop := TextureRect.new()
		backdrop.texture = load(String(case_data["bg"]))
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		scene_panel.add_child(backdrop)
	var clues: Array = case_data["clues"]
	for i in range(clues.size()):
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 56)
		button.add_theme_font_size_override("font_size", 32)
		button.pressed.connect(_on_clue.bind(i))
		if has_scene:
			var at: Vector2 = clues[i]["at"]
			button.anchor_left = at.x
			button.anchor_right = at.x
			button.anchor_top = at.y
			button.anchor_bottom = at.y
			button.offset_left = -45
			button.offset_right = 45
			button.offset_top = -30
			button.offset_bottom = 30
			button.custom_minimum_size = Vector2(90, 60)
			scene_panel.add_child(button)
		else:
			clue_row.add_child(button)
		clue_buttons.append(button)
	who_label.text = "🗣️ Everyone told a story. Which story do the clues show is NOT true?" if case_data.has("bg") else "🕵️ Who did it? Think about the clues, then tap a suspect"

	for child in suspect_row.get_children():
		child.queue_free()
	suspect_buttons.clear()
	for suspect in case_data["suspects"]:
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(230, 200 if suspect.has("says") else 150)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 18)
		var detail := "“%s”" % suspect["says"] if suspect.has("says") else String(suspect["icons"])
		button.text = "%s\n%s\n%s" % [suspect["emoji"], suspect["name"], detail]
		var art := String(suspect.get("art", ""))
		if art == "" and SUSPECT_ART.has(suspect["id"]):
			art = "res://Sprites/mystery/%s.png" % SUSPECT_ART[suspect["id"]]
		if art != "":
			button.icon = load(art)
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.add_theme_constant_override("icon_max_width", 56)
		button.pressed.connect(_on_suspect.bind(String(suspect["id"])))
		suspect_row.add_child(button)
		suspect_buttons[suspect["id"]] = button

	next_button.visible = false
	_say("%s the detective is on the case! Tap a picture to look for clues." % PetalState.pet_name)
	_refresh()

func _say(text: String) -> void:
	bubble.text = "💬 " + text

func _refresh() -> void:
	var clues: Array = case_data["clues"]
	for i in range(clues.size()):
		var done := found.has(i)
		clue_buttons[i].text = "%s%s" % [clues[i]["emoji"], " ✅" if done else ""]
	var lines: Array[String] = ["📓 Clues:"]
	for i in found:
		lines.append("%s %s" % [clues[i]["emoji"], clues[i]["text"]])
	notebook_label.text = "\n".join(lines)
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
	_say("%s %s" % [clue["emoji"], clue["text"]])
	_refresh()
	if found.size() == case_data["clues"].size():
		_say("%s %s Now think: who fits ALL the clues?" % [clue["emoji"], clue["text"]])

func _on_suspect(id: String) -> void:
	picked = id
	for suspect in case_data["suspects"]:
		if suspect["id"] == id and suspect.has("says"):
			_say("%s says: “%s”" % [suspect["name"], suspect["says"]])
	_refresh()

func _on_accuse() -> void:
	if picked == "":
		_say("Tap the suspect you think did it first!")
		return
	if picked == case_data["culprit"]:
		_solve()
		return
	var suspect_name := ""
	for suspect in case_data["suspects"]:
		if suspect["id"] == picked:
			suspect_name = suspect["name"]
	_say("Hmm, not %s! %s" % [suspect_name, case_data["alibis"][picked]])
	suspect_buttons[picked].disabled = true
	picked = ""
	_refresh()

func _solve() -> void:
	solved_now = true
	PetalState.solve_case(String(case_data["id"]), int(case_data.get("prize", 5)))
	_say("🎉 %s You solved it!" % case_data["confession"])
	_refresh()
	next_button.visible = true
	var at := petal.global_position + petal.size / 2.0
	Confetti.burst(self, at, 24)
	Feedback.pop(self, "🎉 Case solved!", at)
	PetCameo.jump_for_joy(petal)

func _on_next() -> void:
	var index := CASES.find(case_data)
	_start_case((index + 1) % CASES.size())
