extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const Confetti = preload("res://scripts/confetti.gd")
const Sfx = preload("res://scripts/sfx.gd")

const IDLE_REACTION_SECONDS := 9.0

const ROOMS := {
	"bedroom": preload("res://scenes/rooms/bedroom.tscn"),
	"living": preload("res://scenes/rooms/living_room.tscn"),
	"dressup": preload("res://scenes/rooms/dress_up_room.tscn"),
	"grooming": preload("res://scenes/rooms/grooming_room.tscn"),
	"bath": preload("res://scenes/rooms/bath_room.tscn"),
	"obstacle": preload("res://scenes/rooms/obstacle_course.tscn"),
	"garden": preload("res://scenes/rooms/garden.tscn"),
	"fishing": preload("res://scenes/rooms/fishing_pond.tscn"),
	"spa": preload("res://scenes/rooms/spa.tscn"),
	"vet": preload("res://scenes/rooms/vet.tscn"),
	"swimpool": preload("res://scenes/rooms/swim_pool.tscn"),
	"photo": preload("res://scenes/rooms/photo_booth.tscn"),
	"photobook": preload("res://scenes/rooms/photo_book.tscn"),
	"party": preload("res://scenes/rooms/party.tscn"),
	"cathouse": preload("res://scenes/rooms/cat_house.tscn"),
	"week": preload("res://scenes/rooms/schedule.tscn"),
	"mystery": preload("res://scenes/rooms/mystery.tscn"),
	"petset": preload("res://scenes/rooms/pet_set.tscn"),
	"stickers": preload("res://scenes/rooms/sticker_book.tscn"),
	"myhome": preload("res://scenes/rooms/my_home.tscn"),
}

const OWNER_WALK_FRAME_COUNT := 5

# Princess Petal's owner is the "classic" girl with her own walk cycle.
# The other pets belong to Lucy, who only has a single standing portrait
# so far - she still slides in beside them, just without frame-by-frame
# walking (same fallback style used elsewhere for pets with no walk art).
const LUCY_OWNER := "res://Sprites/lucy_cutout.png"
const LUCY_OWNER_PETS := ["pompom", "sheila", "kiwi", "gerbil"]

@onready var room_slot: Control = %RoomSlot
@onready var name_label: Label = %NameLabel
@onready var mood_label: Label = %MoodLabel
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var happiness_bar: ProgressBar = %HappinessBar
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var clean_bar: ProgressBar = %CleanBar
@onready var pets_button: Button = %PetsButton
@onready var pet_picker: Control = %PetPicker
@onready var pet_list: VBoxContainer = %PetList
@onready var coins_label: Label = %CoinsLabel

var current_room: Control = null
var current_room_id := "bedroom"
var room_petal: TextureRect = null
var room_owner: TextureRect = null
var accessory_nodes := {}
var is_playing := false
var seconds_since_interaction := 0.0

func _ready() -> void:
	name_label.text = PetalState.pet_name
	# Tap the pet's name to give her a nickname (emoji welcome).
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	name_label.gui_input.connect(_on_name_label_input)
	PetalState.names_changed.connect(_refresh_names)
	_refresh_food_labels()

	PetalState.stats_changed.connect(_refresh_stats)
	PetalState.accessories_changed.connect(_refresh_accessories)
	PetalState.play_animation_requested.connect(_play_toy_animation)
	PetalState.bell_animation_requested.connect(_play_bell_animation)
	PetalState.navigate_to_room.connect(_show_room)
	PetalState.pet_changed.connect(_on_pet_changed)
	PetalState.coins_changed.connect(_refresh_coins)
	PetalState.sticker_earned.connect(_on_sticker_earned)
	PetalState.milestone_reached.connect(_on_milestone_reached)
	_refresh_stats()
	_refresh_coins()

	%BedroomButton.pressed.connect(_enter_bedroom)
	%EnterButton.pressed.connect(_on_gerbil_door_enter)
	_refresh_bedroom_button()
	%LivingButton.pressed.connect(_show_room.bind("living"))
	%DressUpButton.pressed.connect(_show_room.bind("dressup"))
	%GroomingButton.pressed.connect(_show_room.bind("grooming"))
	%ObstacleButton.pressed.connect(_show_room.bind("obstacle"))
	%GardenButton.pressed.connect(_show_room.bind("garden"))
	%VetButton.pressed.connect(_show_room.bind("vet"))
	%PhotoButton.pressed.connect(_show_room.bind("photo"))
	%PartyButton.pressed.connect(_show_room.bind("party"))
	%WeekButton.pressed.connect(_show_room.bind("week"))
	%StickersButton.pressed.connect(_show_room.bind("stickers"))

	pets_button.pressed.connect(_open_pet_picker)
	_add_surprise_button()
	_build_drawers()
	_add_header_button("❓ Help", func() -> void: HowToPlay.open(self))
	_add_header_button("📤 Send to maker", func() -> void: VisitorCheck.open_send(self))
	_add_header_button("🏠 My Home", _show_room.bind("myhome"))
	_add_header_button("🕵️ Mystery", _show_room.bind("mystery"))
	_add_header_button("🛏️ Pet Set", _show_room.bind("petset"))
	_add_header_button("👤 Switch", _switch_player)
	%ClosePetPickerButton.pressed.connect(_close_pet_picker)

	_enter_bedroom()

	var idle_timer := Timer.new()
	idle_timer.wait_time = 1.0
	idle_timer.autostart = true
	idle_timer.timeout.connect(_on_idle_tick)
	add_child(idle_timer)

# The extra header buttons and the room buttons live in two slide-out drawers
# so the screen stays calm; a small tab opens each one, and picking something
# (or pressing the tab again) slides it shut.
const TOP_DRAWER_HEIGHT := 56.0
const BOTTOM_DRAWER_HEIGHT := 60.0
var top_menu: HBoxContainer
var top_drawer: Control
var bottom_drawer: Control
var top_tab: Button
var bottom_tab: Button

func _build_drawers() -> void:
	var root: VBoxContainer = $Root
	top_menu = HBoxContainer.new()
	top_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	top_menu.add_theme_constant_override("separation", 8)
	top_drawer = _make_drawer(top_menu, TOP_DRAWER_HEIGHT)
	root.add_child(top_drawer)
	root.move_child(top_drawer, $Root/Header.get_index() + 1)

	top_tab = _make_tab("☰ Menu ▾")
	top_tab.pressed.connect(_toggle_drawer.bind(top_drawer, top_tab, "☰ Menu"))
	$Root/Header.add_child(top_tab)

	var nav: Control = $Root/NavBar
	var nav_index := nav.get_index()
	root.remove_child(nav)
	bottom_drawer = _make_drawer(nav, BOTTOM_DRAWER_HEIGHT)
	root.add_child(bottom_drawer)
	root.move_child(bottom_drawer, nav_index)
	# Moving the bar cleared its scene owner, which the %UniqueName lookups
	# (%BedroomButton etc.) depend on.
	nav.owner = self
	for child in nav.get_children():
		child.owner = self
	for child in nav.get_children():
		if child is Button:
			child.pressed.connect(_close_drawers)

	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_tab = _make_tab("🚪 Rooms ▴")
	bottom_tab.pressed.connect(_toggle_drawer.bind(bottom_drawer, bottom_tab, "🚪 Rooms"))
	tab_row.add_child(bottom_tab)
	root.add_child(tab_row)
	root.move_child(tab_row, bottom_drawer.get_index())

func _make_tab(text: String) -> Button:
	var tab := Button.new()
	tab.text = text
	tab.custom_minimum_size = Vector2(150, 36)
	tab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tab.add_theme_font_size_override("font_size", 16)
	return tab

# A clipped box that starts closed; `bar` sits inside at its full height.
func _make_drawer(bar: Control, height: float) -> Control:
	var drawer := Control.new()
	drawer.clip_contents = true
	drawer.set_meta("height", height)
	drawer.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 0.0
	bar.offset_right = 0.0
	bar.offset_top = 0.0
	bar.offset_bottom = height
	bar.modulate.a = 0.0
	return drawer

func _toggle_drawer(drawer: Control, tab: Button, name_text: String) -> void:
	var open: bool = not drawer.get_meta("open", false)
	_slide_drawer(drawer, open)
	tab.text = "%s %s" % [name_text, "▴" if (drawer == top_drawer) == open else "▾"]

func _slide_drawer(drawer: Control, open: bool) -> void:
	if drawer.has_meta("open") and drawer.get_meta("open") == open:
		return
	drawer.set_meta("open", open)
	var bar: Control = drawer.get_child(0)
	var tween := drawer.create_tween().set_parallel(true)
	tween.tween_property(drawer, "custom_minimum_size:y", float(drawer.get_meta("height")) if open else 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(bar, "modulate:a", 1.0 if open else 0.0, 0.2)

func _close_drawers() -> void:
	if top_drawer == null:
		return
	_slide_drawer(top_drawer, false)
	_slide_drawer(bottom_drawer, false)
	top_tab.text = "☰ Menu ▾"
	bottom_tab.text = "🚪 Rooms ▴"

func _add_header_button(label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(120, 50)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(action)
	button.pressed.connect(_close_drawers)
	top_menu.add_child(button)

# Rooms the Surprise button can pick, with the name shown in the pop-up.
# Reading-heavy screens (mystery, week plan, My Home...) are left out.
const SURPRISE_ROOMS := {
	"living": "🛋️ Living Room", "dressup": "👑 Dress-Up", "grooming": "🧴 Grooming",
	"bath": "🛁 Bath", "obstacle": "🏃 Course", "garden": "🌷 Garden",
	"fishing": "🎣 Fishing Pond", "spa": "💆 Spa", "vet": "🩺 Vet", "swimpool": "🏊 Pool",
	"photo": "📸 Photo Booth", "party": "🎉 Party", "cathouse": "🏠 Cat House",
}
# Shuffled like a deck of cards so every room turns up before any repeats.
var surprise_deck: Array = []

# Big pink button that jumps to a random activity, so nobody has to decide.
func _add_surprise_button() -> void:
	var button := Button.new()
	button.text = "🎲 Surprise me!"
	button.custom_minimum_size = Vector2(210, 58)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1.0, 0.45, 0.7) if state != "hover" else Color(1.0, 0.55, 0.78)
		box.set_corner_radius_all(18)
		box.set_content_margin_all(8)
		button.add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.pressed.connect(_on_surprise)
	pets_button.get_parent().add_child(button)

func _on_surprise() -> void:
	var id := _next_surprise()
	Sfx.chime(self)
	_show_room(id)
	var at := get_viewport_rect().size / 2.0 + Vector2(-140, -120)
	Confetti.burst(self, at + Vector2(140, 120), 16)
	Feedback.pop(self, "🎲 Surprise! %s" % SURPRISE_ROOMS[id], at)

func _next_surprise() -> String:
	if surprise_deck.is_empty():
		surprise_deck = SURPRISE_ROOMS.keys()
		surprise_deck.shuffle()
		# Never open the room you are already in as the first pick.
		if surprise_deck.back() == current_room_id:
			surprise_deck.reverse()
	return String(surprise_deck.pop_back())

# Back to the title screen, whose slot picker lets another kid take over.
func _switch_player() -> void:
	PetalState.save_game()
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _refresh_coins() -> void:
	coins_label.text = "🪙 %d Treat Coin%s" % [PetalState.coins, "" if PetalState.coins == 1 else "s"]

func _on_sticker_earned(_id: String) -> void:
	Sfx.chime(self)
	if room_petal and is_instance_valid(room_petal):
		Confetti.burst(current_room, room_petal.global_position + room_petal.size / 2.0, 14)

func _on_milestone_reached(total: int) -> void:
	Sfx.fanfare(self)
	var at: Vector2 = room_petal.global_position + room_petal.size / 2.0 if room_petal and is_instance_valid(room_petal) else get_viewport_rect().size / 2.0
	Confetti.burst(self, at, 30)
	Feedback.pop(self, "🪙 %d Treat Coins! Yay!" % total, at + Vector2(-60, -60))

# A little life in the room: if nobody has interacted for a while, the
# pet gives a small cute reaction so the screen never feels frozen.
# Resets whenever petting happens (see _on_room_pet_input).
func _on_idle_tick() -> void:
	seconds_since_interaction += 1.0
	if seconds_since_interaction < IDLE_REACTION_SECONDS:
		return
	seconds_since_interaction = 0.0
	if not room_petal or not is_instance_valid(room_petal) or is_playing:
		return
	_bounce_pet()
	Feedback.pop(self, PetalState.idle_reactions().pick_random(), room_petal.global_position + Vector2(60, 0))

func _show_room(id: String) -> void:
	current_room_id = id
	if current_room:
		current_room.queue_free()
	room_petal = null
	room_owner = null
	accessory_nodes.clear()
	current_room = ROOMS[id].instantiate()
	room_slot.add_child(current_room)
	_wire_room_pet()

# Labels and buttons that show the active pet's own animal and food.
func _refresh_food_labels() -> void:
	%HungerLabel.text = "%s Hunger" % PetalState.food_emoji()
	pets_button.text = "%s Pets" % PetalState.pet_emoji()

# Pets are listed under tappable headers - Cats, Dogs, Other Pets - that
# open and close like drawers, one at a time. The active pet's drawer starts open.
const PET_GROUPS := [
	{"title": "🐱 Cats", "species": ["cat"]},
	{"title": "🐶 Dogs", "species": ["dog"]},
	{"title": "🐰 Bunnies", "species": ["bunny"]},
	{"title": "🐾 Other Pets", "species": []},
]

func _pet_group_index(species: String) -> int:
	for i in range(PET_GROUPS.size()):
		if species in PET_GROUPS[i]["species"]:
			return i
	return PET_GROUPS.size() - 1

func _open_pet_picker() -> void:
	for child in pet_list.get_children():
		child.queue_free()
	var rows: Array[HBoxContainer] = []
	var headers: Array[Button] = []
	for g in PET_GROUPS:
		var header := Button.new()
		header.custom_minimum_size = Vector2(0, 52)
		header.add_theme_font_size_override("font_size", 24)
		headers.append(header)
		pet_list.add_child(header)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 20)
		row.visible = false
		rows.append(row)
		pet_list.add_child(row)
	var counts := []
	counts.resize(PET_GROUPS.size())
	counts.fill(0)
	for id in PetalState.available_pet_ids():
		var gi := _pet_group_index(String(PetalState.PETS[id].get("species", "cat")))
		counts[gi] += 1
		var btn := TextureButton.new()
		btn.texture_normal = load(String(PetalState.PETS[id]["cutout"]))
		PetalState.apply_tint(btn, id)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(150, 210)
		btn.pressed.connect(_on_pet_picked.bind(id))
		if PetalState.is_custom(id):
			rows[gi].add_child(_custom_pet_card(id, btn))
		else:
			rows[gi].add_child(btn)
	# The + at the end of the Cats row makes a new cat (up to CUSTOM_MAX per save).
	var add_button := Button.new()
	add_button.text = "＋\nNew cat" if PetalState.can_make_custom_pet() else "Cat\nlimit"
	add_button.disabled = not PetalState.can_make_custom_pet()
	add_button.add_theme_font_size_override("font_size", 28)
	add_button.custom_minimum_size = Vector2(150, 210)
	add_button.pressed.connect(_on_add_pet)
	rows[0].add_child(add_button)
	var open_group := _pet_group_index(String(PetalState.PETS[PetalState.active_pet].get("species", "cat")))
	for i in range(PET_GROUPS.size()):
		headers[i].visible = counts[i] > 0
		headers[i].pressed.connect(_toggle_pet_group.bind(i, rows, headers))
		rows[i].visible = i == open_group
		_update_pet_header(headers[i], i, rows[i].visible, counts[i])
	pet_picker.visible = true

# A made-up cat in the picker: its picture, name and profile, with a remove button.
func _custom_pet_card(id: String, picture: TextureButton) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.add_child(picture)
	var caption := Label.new()
	caption.text = PetalState.pet_display_name(id)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 18)
	card.add_child(caption)
	var remove := Button.new()
	remove.text = "🗑 Remove"
	remove.pressed.connect(func() -> void:
		if remove.text == "🗑 Remove":
			remove.text = "Really?"
			return
		PetalState.delete_custom_pet(id)
		_open_pet_picker())
	card.add_child(remove)
	return card

func _on_add_pet() -> void:
	_close_pet_picker()
	var creator := PetCreator.open(self)
	creator.created.connect(PetalState.switch_pet)

func _toggle_pet_group(index: int, rows: Array[HBoxContainer], headers: Array[Button]) -> void:
	var opening := not rows[index].visible
	for i in range(rows.size()):
		rows[i].visible = opening and i == index
		_update_pet_header(headers[i], i, rows[i].visible, rows[i].get_child_count())

func _update_pet_header(header: Button, index: int, is_open: bool, count: int) -> void:
	header.text = "%s %s (%d)" % ["▼" if is_open else "▶", PET_GROUPS[index]["title"], count]

func _close_pet_picker() -> void:
	pet_picker.visible = false

func _on_pet_picked(id: String) -> void:
	PetalState.switch_pet(id)
	_close_pet_picker()

func _refresh_names() -> void:
	name_label.text = PetalState.pet_name
	_refresh_stats()

func _on_name_label_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed or is_instance_valid(get_node_or_null("NameEditor")):
		return
	var id := PetalState.active_pet
	var editor := NameEditor.open(self, "Nickname for %s ✏️" % String(PetalState.PETS[id]["name"]), String(PetalState.nicknames.get(id, "")), "Cancel")
	editor.name = "NameEditor"
	editor.submitted.connect(func(text: String) -> void: PetalState.set_nickname(id, text))

func _on_pet_changed() -> void:
	name_label.text = PetalState.pet_name
	_refresh_food_labels()
	_refresh_bedroom_button()
	if current_room_id == "bedroom":
		_enter_bedroom()
	else:
		_show_room(current_room_id)

# Kiwi's bedroom is a decorated perch, Pumpkin's is a burrow - both get a
# themed label instead of the generic bed text (no icon anymore now that
# each has its own full "door" screen instead - see _enter_bedroom).
const HABITAT_DOOR_ART := {
	"kiwi": "res://Sprites/backgrounds/kiwi_perch_door.jpg",
	"gerbil": "res://Sprites/backgrounds/gerbil_house_door.jpg",
}

func _refresh_bedroom_button() -> void:
	if not PetalState.perch_items().is_empty():
		%BedroomButton.text = "🪺 Perch"
	elif PetalState.active_pet == "gerbil":
		%BedroomButton.text = "🕳️ Burrow"
	else:
		%BedroomButton.text = "🛏️ Bedroom"
	%BedroomButton.icon = null
	%BedroomButton.expand_icon = true
	%BedroomButton.add_theme_constant_override("icon_max_width", 32)

# Kiwi and Pumpkin are reached through a real "door" screen (their own
# illustrated entrance) rather than jumping straight in like every other
# room - Lucy is shown standing outside it, since she can't fit through.
func _enter_bedroom() -> void:
	var door_art: String = HABITAT_DOOR_ART.get(PetalState.active_pet, "")
	if door_art != "":
		%DoorArt.texture = load(door_art)
		%GerbilDoorScreen.visible = true
	else:
		_show_room("bedroom")

func _on_gerbil_door_enter() -> void:
	%GerbilDoorScreen.visible = false
	_show_room("bedroom")

# Rooms that show Petal (all but the Obstacle Course and Sticker Book)
# expose her via a unique "Petal" TextureRect - that's the one cat in
# the room. We hook petting, her accessories, and the owner cameo onto
# that same node instead of keeping a separate header portrait.
func _wire_room_pet() -> void:
	room_petal = current_room.get_node_or_null("%Petal")
	if not room_petal:
		return

	room_petal.mouse_filter = Control.MOUSE_FILTER_STOP
	PetalState.apply_tint(room_petal)
	room_petal.gui_input.connect(_on_room_pet_input)

	_build_accessory_overlays()
	_refresh_accessories()
	# The perch and burrow doors are pet-sized - Lucy waits outside instead
	# of squeezing through, unlike every other room where she tags along.
	var lucy_locked_out := current_room_id == "bedroom" and HABITAT_DOOR_ART.has(PetalState.active_pet)
	if not lucy_locked_out:
		_spawn_owner_beside(room_petal)

func _build_accessory_overlays() -> void:
	var pet_accessories: Dictionary = PetalState.PETS[PetalState.active_pet]["accessories"]
	for id in pet_accessories:
		var icon := TextureRect.new()
		icon.name = "Accessory_%s" % id
		icon.texture = load(String(pet_accessories[id]["icon"]))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		var a: Dictionary = pet_accessories[id]["anchor"]
		icon.anchor_left = a["l"]
		icon.anchor_top = a["t"]
		icon.anchor_right = a["r"]
		icon.anchor_bottom = a["b"]
		room_petal.add_child(icon)
		accessory_nodes[id] = icon

func _spawn_owner_beside(petal_node: TextureRect) -> void:
	var owner_node := TextureRect.new()
	owner_node.name = "Owner"
	owner_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	owner_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	owner_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Lucy always stands in the room's bottom-left corner, regardless of
	# where the pet herself ends up (e.g. Kiwi's perch room moves %Petal up
	# onto a branch - Lucy shouldn't follow her up there).
	owner_node.anchor_left = 0.0
	owner_node.anchor_top = 1.0
	owner_node.anchor_right = 0.0
	owner_node.anchor_bottom = 1.0
	owner_node.offset_left = 218.0
	owner_node.offset_right = 358.0
	owner_node.offset_top = -186.0
	owner_node.offset_bottom = -16.0
	owner_node.grow_vertical = Control.GROW_DIRECTION_BEGIN
	petal_node.get_parent().add_child(owner_node)
	# Keep the owner drawn behind the cat, since her walk-in path
	# crosses through Petal's box and would otherwise cover her.
	petal_node.get_parent().move_child(owner_node, petal_node.get_index())
	room_owner = owner_node
	_walk_in_owner(owner_node)

func _owner_texture_path() -> String:
	return LUCY_OWNER if LUCY_OWNER_PETS.has(PetalState.active_pet) else "res://Sprites/owner.png"

func _walk_in_owner(owner_node: TextureRect) -> void:
	var use_lucy := LUCY_OWNER_PETS.has(PetalState.active_pet)
	var owner_texture: Texture2D = load(_owner_texture_path())
	var walk_frames: Array[Texture2D] = []
	if not use_lucy:
		for i in range(OWNER_WALK_FRAME_COUNT):
			walk_frames.append(load("res://Sprites/owner_walk/frame_%02d.png" % i))

	owner_node.texture = owner_texture
	owner_node.pivot_offset = owner_node.size / 2.0
	var target_x := owner_node.position.x
	var start_x := target_x - 140.0
	owner_node.position.x = start_x

	var steps := 12
	for i in range(steps):
		if not is_instance_valid(owner_node):
			return
		if not walk_frames.is_empty():
			owner_node.texture = walk_frames[i % walk_frames.size()]
		owner_node.position.x = lerp(start_x, target_x, float(i + 1) / float(steps))
		await get_tree().create_timer(0.06).timeout

	if not is_instance_valid(owner_node):
		return
	owner_node.texture = owner_texture
	owner_node.position.x = target_x

func _on_room_pet_input(event: InputEvent) -> void:
	var is_click: bool = event is InputEventMouseButton and event.pressed
	var is_touch: bool = event is InputEventScreenTouch and event.pressed
	if is_click or is_touch:
		seconds_since_interaction = 0.0
		PetalState.pet_her()
		Sfx.pop(self)
		Feedback.pop(self, PetalState.pet_reactions().pick_random(), room_petal.global_position + Vector2(60, 20))
		_bounce_pet()
		_show_pet_still()

# Pets with a drawn "being petted" picture (e.g. Stardust with PJ) swap to it
# for a moment. PJ is in the picture, so her usual cameo steps out meanwhile.
func _show_pet_still() -> void:
	if not PetalState.has_anim("pet_still") or is_playing:
		return
	is_playing = true
	for id in accessory_nodes:
		accessory_nodes[id].visible = false
	var owner_was_visible := is_instance_valid(room_owner) and room_owner.visible
	if is_instance_valid(room_owner):
		room_owner.visible = false
	room_petal.texture = load(PetalState.static_pose("pet_still"))
	await get_tree().create_timer(1.2).timeout
	is_playing = false
	if is_instance_valid(room_owner):
		room_owner.visible = owner_was_visible
	if is_instance_valid(room_petal):
		room_petal.texture = load(PetalState.cutout_path())
		_refresh_accessories()

func _bounce_pet() -> void:
	room_petal.pivot_offset = room_petal.size / 2.0
	var tween := create_tween()
	tween.tween_property(room_petal, "scale", Vector2(1.12, 0.9), 0.08)
	tween.tween_property(room_petal, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_ELASTIC)

func _play_toy_animation() -> void:
	await _play_named_animation("play", "play_still")

func _play_bell_animation() -> void:
	await _play_named_animation("toy_bell", "")

# Plays a pet's named frame-set (if she has one), else shows a single
# still pose with a happy bounce (if she has one, e.g. Kiwi's "play_still"
# portrait with Lucy), else just falls back to a generic Jump for Joy.
func _play_named_animation(anim_key: String, still_key: String) -> void:
	if not room_petal or is_playing:
		return
	is_playing = true
	for id in accessory_nodes:
		accessory_nodes[id].visible = false

	# Pets whose play frames are just the pet herself (no toy scene drawn
	# around her) stay in her corner box instead of filling the screen.
	if PetalState.has_anim(anim_key) and PetalState.PETS[PetalState.active_pet].get("inline_play", false):
		for frame in PetalState.anim_frames(anim_key):
			if not is_instance_valid(room_petal):
				is_playing = false
				return
			room_petal.texture = frame
			await get_tree().create_timer(0.15).timeout
		is_playing = false
		if is_instance_valid(room_petal):
			room_petal.texture = load(PetalState.cutout_path())
			_refresh_accessories()
		return

	if PetalState.has_anim(anim_key):
		# room_petal normally sits in a small corner box (see e.g.
		# living_room.tscn) that's easy for background furniture to crowd
		# or partly cover - blow her up to fill the screen for the
		# animation itself, same trick used for the bath comic, then put
		# her back in her corner box afterward.
		var orig_anchors := Vector4(room_petal.anchor_left, room_petal.anchor_top, room_petal.anchor_right, room_petal.anchor_bottom)
		var orig_offsets := Vector4(room_petal.offset_left, room_petal.offset_top, room_petal.offset_right, room_petal.offset_bottom)
		var orig_grow_v := room_petal.grow_vertical
		room_petal.anchor_left = 0.0
		room_petal.anchor_top = 0.0
		room_petal.anchor_right = 1.0
		room_petal.anchor_bottom = 1.0
		room_petal.offset_left = 0.0
		room_petal.offset_top = 0.0
		room_petal.offset_right = 0.0
		room_petal.offset_bottom = 0.0
		room_petal.grow_vertical = 1
		# Lucy normally stands tucked in behind the pet's corner box - once
		# that box covers the whole screen she'd otherwise be hidden behind
		# it for the whole animation, so just step her out until it's done.
		var owner_was_visible := is_instance_valid(room_owner) and room_owner.visible
		if is_instance_valid(room_owner):
			room_owner.visible = false

		var frames := PetalState.anim_frames(anim_key)
		for i in range(frames.size()):
			if not is_instance_valid(room_petal):
				is_playing = false
				return
			room_petal.texture = frames[i]
			var last := i == frames.size() - 1
			await get_tree().create_timer(1.1 if last else 0.35).timeout
		is_playing = false
		if is_instance_valid(room_petal):
			room_petal.anchor_left = orig_anchors.x
			room_petal.anchor_top = orig_anchors.y
			room_petal.anchor_right = orig_anchors.z
			room_petal.anchor_bottom = orig_anchors.w
			room_petal.offset_left = orig_offsets.x
			room_petal.offset_top = orig_offsets.y
			room_petal.offset_right = orig_offsets.z
			room_petal.offset_bottom = orig_offsets.w
			room_petal.grow_vertical = orig_grow_v
			room_petal.texture = load(PetalState.cutout_path())
			_refresh_accessories()
		if is_instance_valid(room_owner):
			room_owner.visible = owner_was_visible
		return

	if still_key != "" and PetalState.has_anim(still_key):
		room_petal.texture = load(PetalState.static_pose(still_key))
		_bounce_pet()
		await get_tree().create_timer(0.9).timeout
		is_playing = false
		if is_instance_valid(room_petal):
			room_petal.texture = load(PetalState.cutout_path())
			_refresh_accessories()
		return

	await PetCameo.jump_for_joy(room_petal)
	is_playing = false
	if is_instance_valid(room_petal):
		_refresh_accessories()

func _refresh_stats() -> void:
	hunger_bar.value = PetalState.hunger
	happiness_bar.value = PetalState.happiness
	energy_bar.value = PetalState.energy
	clean_bar.value = PetalState.cleanliness
	mood_label.text = "%s %s" % [PetalState.mood_emoji(), PetalState.mood()]
	mood_label.add_theme_color_override("font_color", PetalState.mood_color())

func _refresh_accessories() -> void:
	if not room_petal or not is_instance_valid(room_petal):
		return
	var acc := PetalState.accessories
	for id in accessory_nodes:
		accessory_nodes[id].visible = acc[id]
