extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const Confetti = preload("res://scripts/confetti.gd")

const SUSPECT_ART := {
	"mimi": "field_mouse", "rusty": "puppy", "snowy": "bunny", "woolly": "lamb", "leo": "lion_guardian",
	"tilly": "turtle", "sid": "snail", "fox": "fox", "pip": "chick", "henny": "chick", "bruno": "panda",
	"hop": "capybara", "axel": "axolotl", "fawny": "fawn", "marmie": "marmot", "batty": "bat", "pom": "pomeranian",
	"frenchie": "french_bulldog", "hoofy": "horse", "fossy": "fossa", "fenny": "fennec", "daisy": "cow", "clover": "bull",
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
			{"id": "hoofy", "emoji": "🐴", "name": "Hoofy", "says": "I was galloping round the far field."},
		],
		"clues": [
			{"emoji": "🪜", "at": Vector2(0.12, 0.4), "text": "A rumbling snore echoes down from the loft, and wool is caught on the ladder."},
			{"emoji": "🐾", "at": Vector2(0.32, 0.78), "text": "A fallen log makes a bridge over the river. It is covered in fox prints, and the far bank is full of worm holes."},
			{"emoji": "🌊", "at": Vector2(0.22, 0.6), "text": "The river is deep and wide tonight. Nobody could wade across it."},
			{"emoji": "🌾", "at": Vector2(0.52, 0.42), "text": "There is a tiny nest in the hay, made with a cosy blanket."},
			{"emoji": "🌳", "at": Vector2(0.72, 0.3), "text": "Deep hoof prints dot the far field, all the way to the fence."},
			{"emoji": "💧", "at": Vector2(0.88, 0.78), "text": "The puddle by the pond has a crust of cracked, dry earth."},
		],
		"culprit": "pom",
		"alibis": {
			"woolly": "Woolly's story is TRUE. The snoring is coming from the loft!",
			"fox": "Fox's story is TRUE. The fox prints are across the river!",
			"mimi": "Mimi's story is TRUE. Her nest is in the hay!",
			"hoofy": "Hoofy's story is TRUE. The hoof prints are in the far field!",
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
			{"id": "fossy", "emoji": "🐆", "name": "Fossy", "says": "I was having a nap up in the attic."},
		],
		"clues": [
			{"emoji": "☀️", "at": Vector2(0.12, 0.35), "text": "The cushion by the window is warm, with golden hairs and a round dent, even with the curtains shut."},
			{"emoji": "🪟", "at": Vector2(0.06, 0.55), "text": "The curtains over the window were closed all afternoon."},
			{"emoji": "🧊", "at": Vector2(0.3, 0.78), "text": "The ice pond is covered in skid marks and paw prints."},
			{"emoji": "👣", "at": Vector2(0.5, 0.6), "text": "A slow trail of tiny footprints leads to the kitchen."},
			{"emoji": "🔼", "at": Vector2(0.7, 0.2), "text": "A sleepy purr comes from the attic, above a nest of blankets."},
			{"emoji": "🕸️", "at": Vector2(0.88, 0.4), "text": "The swing is wrapped in cobwebs and covered in dust."},
		],
		"culprit": "fenny",
		"alibis": {
			"leo": "Leo's story is TRUE. His hairs are on the cushion!",
			"frenchie": "Frenchie's story is TRUE. The skid marks are on the ice!",
			"tilly": "Tilly's story is TRUE. Her footprints go to the kitchen!",
			"fossy": "Fossy's story is TRUE. The purr is coming from the attic!",
		},
		"confession": "Yip yip... I wanted coins to buy lots of snacks. I'll put them back!",
	},
	{
		"id": "cookies", "emoji": "🍪", "title": "The Missing Cookies",
		"bg": "res://Sprites/mystery/bg_cookie_kitchen.jpg",
		"story": "🫙 Oh no! The cookie jar is EMPTY! Who took the cookies? Careful: one clue is not enough!",
		"suspects": [
			{"id": "mimi", "emoji": "🐭", "name": "Mimi", "icons": "tiny • grey fur • long tail", "says": "I was snuggled in my mouse hole all night. I never went to the kitchen!"},
			{"id": "fenny", "emoji": "🦊", "name": "Fenny", "icons": "small • sandy fur • bushy tail", "says": "I was out digging in the sand dunes all night."},
			{"id": "pip", "emoji": "🐥", "name": "Pip", "icons": "small • yellow • wings", "says": "I was flapping around outside in the garden."},
			{"id": "hop", "emoji": "🦫", "name": "Cappy", "icons": "big • brown • no tail", "says": "I was splashing in the pond all night."},
			{"id": "rusty", "emoji": "🐶", "name": "Rusty", "icons": "medium • grey fur • fluffy tail", "says": "I was chasing my tail in the yard."},
			{"id": "bruno", "emoji": "🐼", "name": "Bruno", "icons": "huge • black & white", "says": "I was munching bamboo in my bed."},
		],
		"clues": [
			{"emoji": "👣", "at": Vector2(0.14, 0.55), "text": "The footprints in the flour are each as small as a button."},
			{"emoji": "🪟", "at": Vector2(0.38, 0.78), "text": "The window was shut tight all night, so nobody flew in."},
			{"emoji": "🫙", "at": Vector2(0.62, 0.42), "text": "Grey hairs were left stuck to the lid of the jar."},
			{"emoji": "📻", "at": Vector2(0.86, 0.7), "text": "The radio was playing music in the next room."},
		],
		"culprit": "mimi",
		"alibis": {
			"bruno": "Bruno is huge, but the footprints are tiny!",
			"hop": "Cappy is big, but the footprints are tiny!",
			"rusty": "Rusty is too big to leave button-sized footprints!",
			"pip": "The window was shut, so Pip could not fly in!",
			"fenny": "Fenny has sandy fur, but the hairs on the lid are grey!",
		},
		"confession": "Squeak! It was me. I was SO hungry. I'm sorry!",
	},
	{
		"id": "teddy", "emoji": "🧸", "title": "The Missing Teddy",
		"bg": "res://Sprites/mystery/bg_teddy.jpg",
		"story": "🧸 Oh no! Teddy is gone from the toy shelf! Who took him? Careful: one clue is not enough!",
		"suspects": [
			{"id": "henny", "emoji": "🐥", "name": "Henny", "icons": "yellow • feathers", "says": "I was sitting on my nest all night."},
			{"id": "axel", "emoji": "🦎", "name": "Axel", "icons": "pink • smooth skin", "says": "I was swimming in my tank. Glub glub!"},
			{"id": "snowy", "emoji": "🐰", "name": "Snowy", "icons": "white • fur • soft paws", "says": "I was hopping about in the garden."},
			{"id": "rusty", "emoji": "🐶", "name": "Rusty", "icons": "brown • fur • paws with claws", "says": "I was digging a hole in the yard."},
			{"id": "fawny", "emoji": "🦌", "name": "Fawny", "icons": "brown • fur • hooves", "says": "I was fast asleep in the forest."},
			{"id": "pom", "emoji": "🐕", "name": "Pom", "icons": "cream • fluffy fur • paws with claws", "says": "I was getting my fur brushed all evening."},
		],
		"clues": [
			{"emoji": "📦", "at": Vector2(0.14, 0.55), "text": "Soft tufts of hair are caught on the toy box."},
			{"emoji": "🐾", "at": Vector2(0.38, 0.78), "text": "Round prints with little claw marks lead out the door."},
			{"emoji": "🧹", "at": Vector2(0.62, 0.42), "text": "The hairs on the floor are the colour of chocolate."},
			{"emoji": "🌧️", "at": Vector2(0.86, 0.7), "text": "It was raining outside last night."},
		],
		"culprit": "rusty",
		"alibis": {
			"henny": "Henny has feathers, but the toy box has hair on it!",
			"axel": "Axel has smooth skin, but the toy box has hair on it!",
			"snowy": "Snowy has soft paws with no claws, and white fur!",
			"fawny": "Fawny has hooves, but the prints have claw marks!",
			"pom": "Pom is cream coloured, but the hairs are brown like chocolate!",
		},
		"confession": "Woof... I just wanted a cuddle buddy. Sorry!",
	},
	{
		"id": "paint", "emoji": "🎨", "title": "The Paint Splash",
		"bg": "res://Sprites/backgrounds/garden_sunny.jpg",
		"story": "🎨 Oh no! Someone splashed paint all over the barn wall! Careful: one clue is not enough!",
		"suspects": [
			{"id": "sid", "emoji": "🐌", "name": "Sid", "icons": "slimy • brown shell • no legs", "says": "I was slowly sliming along the garden path."},
			{"id": "daisy", "emoji": "🐮", "name": "Daisy", "icons": "black & white • hooves", "says": "I was eating grass in the field."},
			{"id": "woolly", "emoji": "🐑", "name": "Woolly", "icons": "white • hooves • says baa", "says": "I was counting sheep. Baa!"},
			{"id": "fawny", "emoji": "🦌", "name": "Fawny", "icons": "brown • hooves • white spots", "says": "I was hiding in the bushes."},
			{"id": "hoofy", "emoji": "🐴", "name": "Hoofy", "icons": "brown • hooves • no spots", "says": "I was racing round the track."},
			{"id": "fox", "emoji": "🦊", "name": "Fox", "icons": "orange • four paws", "says": "I was sneaking around the hen house."},
		],
		"clues": [
			{"emoji": "🐾", "at": Vector2(0.14, 0.55), "text": "Four footprints lead away from the wall."},
			{"emoji": "🦶", "at": Vector2(0.38, 0.78), "text": "The prints are hoof-shaped, not paw-shaped."},
			{"emoji": "🧱", "at": Vector2(0.62, 0.42), "text": "The smudges on the wall are the colour of toast."},
			{"emoji": "🖌️", "at": Vector2(0.86, 0.7), "text": "Tiny white dots are scattered along the paint streaks."},
		],
		"culprit": "fawny",
		"alibis": {
			"sid": "Snails have no legs, so no footprints from Sid!",
			"fox": "Fox has paws, but the prints are hoof-shaped!",
			"daisy": "Daisy is black and white, but the smudges are brown!",
			"woolly": "Woolly is white, but the smudges are brown!",
			"hoofy": "Hoofy has no spots, but there are white dots in the paint!",
		},
		"confession": "Eep! I wanted to paint the barn brown like me. Oops!",
	},
	{
		"id": "cake", "emoji": "🎂", "title": "The Birthday Cake",
		"bg": "res://Sprites/mystery/bg_kitchen.jpg",
		"story": "🎂 Oh no! The birthday cake was on the high shelf and it's GONE! Careful: one clue is not enough!",
		"suspects": [
			{"id": "leo", "emoji": "🦁", "name": "Leo", "icons": "huge • golden mane", "says": "I was napping in the sun."},
			{"id": "bruno", "emoji": "🐼", "name": "Bruno", "icons": "huge • black & white", "says": "I was eating bamboo."},
			{"id": "pip", "emoji": "🐥", "name": "Pip", "icons": "small • yellow feathers", "says": "I was pecking seeds outside."},
			{"id": "marmie", "emoji": "🐿️", "name": "Marmie", "icons": "small • fur • eats nuts", "says": "I was gathering acorns."},
			{"id": "fenny", "emoji": "🦊", "name": "Fenny", "icons": "small • fur • eats bugs", "says": "I was catching bugs in the dunes."},
			{"id": "mimi", "emoji": "🐭", "name": "Mimi", "icons": "tiny • fur • loves cheese and nuts", "says": "I was nibbling cheese downstairs."},
		],
		"clues": [
			{"emoji": "🪟", "at": Vector2(0.14, 0.55), "text": "The only open window is tiny. Only a small friend fits through."},
			{"emoji": "🎂", "at": Vector2(0.38, 0.78), "text": "Soft tufts of hair are stuck on the shelf."},
			{"emoji": "🌰", "at": Vector2(0.62, 0.42), "text": "Cracked-open nutshells are on the floor."},
			{"emoji": "🧀", "at": Vector2(0.86, 0.7), "text": "A big block of cheese on the same shelf was not touched."},
		],
		"culprit": "marmie",
		"alibis": {
			"leo": "Leo is much too big for the tiny window!",
			"bruno": "Bruno is much too big for the tiny window!",
			"pip": "Pip has feathers, but hair was stuck on the shelf!",
			"fenny": "Fenny eats bugs, but only nutshells were found!",
			"mimi": "Mimi loves cheese, but the cheese was left alone!",
		},
		"confession": "Squeak! The cake smelled like nuts. Sorry!",
	},
	{
		"id": "crown", "emoji": "👑", "title": "The Sparkly Crown",
		"bg": "res://Sprites/mystery/bg_library.jpg",
		"story": "👑 Oh no! The sparkly crown vanished in a flash! Careful: one clue is not enough!",
		"suspects": [
			{"id": "tilly", "emoji": "🐢", "name": "Tilly", "icons": "a slow, slow turtle", "says": "I was crawling to the tower. I'll get there soon!"},
			{"id": "sid", "emoji": "🐌", "name": "Sid", "icons": "an even slower snail", "says": "I left home yesterday and I'm nearly at the gate."},
			{"id": "clover", "emoji": "🐂", "name": "Clover", "icons": "eats grass • stays on the ground", "says": "I was chewing grass in the meadow."},
			{"id": "hoofy", "emoji": "🐴", "name": "Hoofy", "icons": "very fast • stays on the ground", "says": "I was racing round the track."},
			{"id": "batty", "emoji": "🦇", "name": "Batty", "icons": "very fast • flies • loves shiny things", "says": "I was hanging upside-down in my cave, fast asleep."},
			{"id": "fossy", "emoji": "🐆", "name": "Fossy", "icons": "very fast • sharp claws • climbs", "says": "I was climbing about in the trees."},
		],
		"clues": [
			{"emoji": "⚡", "at": Vector2(0.14, 0.55), "text": "The crown was gone before the clock could tick twice."},
			{"emoji": "🗼", "at": Vector2(0.38, 0.78), "text": "It was taken from a window high up on the tower."},
			{"emoji": "🧱", "at": Vector2(0.62, 0.42), "text": "The tower wall below has no scratch marks at all."},
			{"emoji": "🎀", "at": Vector2(0.86, 0.7), "text": "The curtains are blue."},
		],
		"culprit": "batty",
		"alibis": {
			"tilly": "Tilly is far too slow to be gone in a flash!",
			"sid": "Sid is much too slow. It would take him a whole week!",
			"clover": "Clover stays on the ground, but the window is high up!",
			"hoofy": "Hoofy stays on the ground, but the window is high up!",
			"fossy": "Fossy climbs with sharp claws, but the wall has no scratches!",
		},
		"confession": "Squeak! It was so SHINY. I'll give it back!",
	},
]

var case_data: Dictionary = {}
var found: Array = []
var picked := ""
var solved_now := false
var wrong_guesses := 0
var heard: Array = []

var title_label: Label
var story_label: Label
var clue_row: HBoxContainer
var notebook_label: Label
var suspect_row: HFlowContainer
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

	box.add_child(_label(16, Color(0.4, 0.4, 0.6), "🔍 Tap the spots for clues. Tap the animals to hear their stories!"))
	clue_row = HBoxContainer.new()
	clue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	clue_row.add_theme_constant_override("separation", 14)
	box.add_child(clue_row)

	scene_panel = Control.new()
	scene_panel.custom_minimum_size = Vector2(0, 430)
	scene_panel.clip_contents = true
	scene_panel.visible = false
	box.add_child(scene_panel)

	notebook_label = _label(18, Color(0.2, 0.2, 0.3))
	notebook_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(notebook_label)

	who_label = _label(16, Color(0.4, 0.4, 0.6))
	box.add_child(who_label)
	suspect_row = HFlowContainer.new()
	suspect_row.alignment = FlowContainer.ALIGNMENT_CENTER
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
	wrong_guesses = 0
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
			at.y *= 0.6
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
	heard = []
	suspect_row.visible = not has_scene
	var lineup: HBoxContainer = null
	if has_scene:
		lineup = HBoxContainer.new()
		lineup.anchor_right = 1.0
		lineup.anchor_top = 1.0
		lineup.anchor_bottom = 1.0
		lineup.offset_top = -150
		lineup.offset_bottom = -6
		lineup.alignment = BoxContainer.ALIGNMENT_CENTER
		lineup.add_theme_constant_override("separation", 8)
		scene_panel.add_child(lineup)
	for suspect in case_data["suspects"]:
		var button := Button.new()
		button.toggle_mode = true
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var traits := String(suspect.get("icons", ""))
		if has_scene:
			button.custom_minimum_size = Vector2(176, 144)
			button.add_theme_font_size_override("font_size", 14)
			button.text = "%s\n%s" % [suspect["name"], traits] if traits != "" else String(suspect["name"])
		else:
			button.custom_minimum_size = Vector2(200, 200 if suspect.has("says") else 150)
			button.add_theme_font_size_override("font_size", 18)
			button.text = "%s\n%s\n%s" % [suspect["emoji"], suspect["name"], traits if traits != "" else "“%s”" % suspect["says"]]
		var art := String(suspect.get("art", ""))
		if art == "" and SUSPECT_ART.has(suspect["id"]):
			art = "res://Sprites/mystery/%s.png" % SUSPECT_ART[suspect["id"]]
		if art != "":
			button.icon = load(art)
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.add_theme_constant_override("icon_max_width", 70 if has_scene else 56)
		button.pressed.connect(_on_suspect.bind(String(suspect["id"])))
		if has_scene:
			lineup.add_child(button)
		else:
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
	if not heard.is_empty():
		lines.append("🗣️ Stories:")
		for suspect in case_data["suspects"]:
			if heard.has(suspect["id"]):
				lines.append("%s %s: “%s”" % [suspect["emoji"], suspect["name"], suspect["says"]])
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
			if not heard.has(id):
				heard.append(id)
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
	wrong_guesses += 1
	if wrong_guesses < 2:
		_say("Hmm, not %s! Read ALL the clues again. Guessing costs coins!" % suspect_name)
	else:
		_say("Not %s! Hint: %s" % [suspect_name, case_data["alibis"][picked]])
	picked = ""
	_refresh()

func _solve() -> void:
	solved_now = true
	PetalState.solve_case(String(case_data["id"]), maxi(1, int(case_data.get("prize", 5)) - 2 * wrong_guesses))
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
