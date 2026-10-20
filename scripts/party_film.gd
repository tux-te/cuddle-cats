extends PanelContainer

# "Film your pet": the player makes the pet do silly things (by tapping the
# buttons, or by saying the word in the web build) while the camera rolls.
# What gets saved is a replayable movie - the list of tricks and the pauses
# between them - which is played back with the pet's own animations, so it
# works the same on every platform and costs almost nothing to keep.
# Movies live only for this session (like the Photo Book). Each movie remembers
# the backdrop it was shot on, opens with a title card, plays in letterbox
# bars, shows the pet's sounds in comic speech bubbles and ends with credits.

signal closed

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const Sfx = preload("res://scripts/sfx.gd")

const MAX_MOVIES := 5

# action id -> button label. "speak" / "sound2" are the pet's own noises
# (see SOUNDS - their button labels are refreshed for the active pet).
const ACTIONS := {
	"speak": "💬 Speak",
	"sound2": "💬 Purr",
	"sleep": "😴 Sleep",
	"dance": "💃 Dance",
	"jump": "🤸 Jump",
	"wave": "🖐️ Wave",
	"sit": "🐾 Sit",
	"come": "👋 Come",
	"sing": "🎵 Sing",
}

# What each kind of pet says: [main noise, second noise].
const SOUNDS := {
	"cat": ["Meow!", "Purr..."],
	"dog": ["Woof!", "Arf arf!"],
	"bird": ["Tweet!", "Chirp!"],
	"gerbil": ["Squeak!", "Eek!"],
	"bunny": ["Squeak!", "Eek!"],
}

# The kid-safe emoji the pet is allowed to "say", and the word that says each.
const APPROVED_EMOJIS := ["😀", "😍", "🥰", "😂", "😴", "🎉", "💖", "⭐", "🌈", "🌸", "🎵", "🐾"]
const EMOJI_WORDS := {
	"smile": "😀", "happy": "😀", "love": "😍", "heart": "💖", "kiss": "🥰", "laugh": "😂", "funny": "😂",
	"tired": "😴", "party": "🎉", "star": "⭐", "rainbow": "🌈", "flower": "🌸", "music": "🎵", "paw": "🐾",
}

# Spoken word -> action.
const VOICE := {
	"meow": "speak", "woof": "speak", "bark": "speak", "tweet": "speak", "squeak": "speak",
	"speak": "speak", "talk": "speak",
	"purr": "sound2", "arf": "sound2", "chirp": "sound2", "eek": "sound2",
	"sleep": "sleep", "nap": "sleep", "night": "sleep", "bed": "sleep",
	"dance": "dance", "boogie": "dance",
	"jump": "jump", "hop": "jump",
	"wave": "wave", "hello": "wave", "hi": "wave",
	"sit": "sit",
	"come": "come",
	"sing": "sing",
}

# Backdrops to shoot on: id -> [button label, room id (for per-pet pictures), default picture].
const BACKDROPS := {
	"party": ["🎉 Party", "party", "res://Sprites/backgrounds/party_room.jpg"],
	"garden": ["🌷 Garden", "garden", "res://Sprites/backgrounds/garden_sunny.jpg"],
	"living": ["🛋️ Living", "living", "res://Sprites/backgrounds/living_room.jpg"],
	"bedroom": ["🛏️ Bedroom", "bedroom", "res://Sprites/backgrounds/bedroom.jpg"],
	"pool": ["🏊 Pool", "swim", "res://Sprites/backgrounds/swim_pool.jpg"],
	"dressup": ["👑 Dress-up", "dressup", "res://Sprites/backgrounds/dress_up_room.jpg"],
	"spa": ["💆 Spa", "spa", "res://Sprites/backgrounds/spa.jpg"],
	"bath": ["🛁 Bath", "bath", "res://Sprites/backgrounds/bath_room.jpg"],
}
const BAR_HEIGHT := 64.0
const GOLD := Color(1.0, 0.85, 0.4)

# Kept for the whole session so movies survive leaving the Party room.
static var movies: Array = []

enum Mode { IDLE, RECORDING, PLAYING }

var host: Control
var pet: TextureRect
var mode := Mode.IDLE
var voice_on := false
var clock := 0.0
var last_end := 0.0
var steps: Array = []
var queue: Array = []
var running := false
var cancel_playback := false
var poll := 0.0

var backdrop := "party"
var play_id := 0
var background: TextureRect
var original_texture: Texture2D
var top_bar: ColorRect
var bottom_bar: ColorRect
var rec_label: Label
var card: Control
var tricks_title: Label
var backdrop_title: Label
var backdrop_box: HFlowContainer
var backdrop_buttons := {}

var status_label: Label
var action_box: HFlowContainer
var action_buttons := {}
var record_button: Button
var movie_box: HFlowContainer

func setup(host_node: Control, pet_node: TextureRect) -> void:
	host = host_node
	pet = pet_node
	visible = false
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	# Offsets, not position: setup runs after this panel is in the tree, where
	# `position` would be taken as absolute and land off-screen.
	offset_left = -330.0
	offset_right = 330.0
	offset_top = 70.0
	custom_minimum_size = Vector2(660, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH

	var look := StyleBoxFlat.new()
	look.bg_color = Color(0.09, 0.07, 0.14, 0.9)
	look.border_color = GOLD
	look.set_border_width_all(3)
	look.set_corner_radius_all(22)
	look.set_content_margin_all(14)
	add_theme_stylebox_override("panel", look)
	background = host.get_node("%Background")
	_build_bars()

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)

	backdrop_title = _section_label("🖼 Backdrop")
	box.add_child(backdrop_title)
	backdrop_box = HFlowContainer.new()
	backdrop_box.alignment = FlowContainer.ALIGNMENT_CENTER
	box.add_child(backdrop_box)
	for id in BACKDROPS:
		var pick := Button.new()
		pick.text = BACKDROPS[id][0]
		pick.add_theme_font_size_override("font_size", 17)
		pick.pressed.connect(_pick_backdrop.bind(id))
		backdrop_box.add_child(pick)
		backdrop_buttons[id] = pick

	tricks_title = _section_label("🎭 Tricks")
	box.add_child(tricks_title)
	action_box = HFlowContainer.new()
	action_box.alignment = FlowContainer.ALIGNMENT_CENTER
	box.add_child(action_box)
	for id in ACTIONS:
		var b := Button.new()
		b.text = ACTIONS[id]
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_request.bind(id))
		action_box.add_child(b)
		action_buttons[id] = b
	for emoji in APPROVED_EMOJIS:
		var e := Button.new()
		e.text = emoji
		e.add_theme_font_size_override("font_size", 24)
		e.pressed.connect(_request.bind("emoji:" + emoji))
		action_box.add_child(e)

	record_button = Button.new()
	record_button.add_theme_font_size_override("font_size", 22)
	record_button.pressed.connect(_on_record_pressed)
	box.add_child(record_button)

	movie_box = HFlowContainer.new()
	movie_box.alignment = FlowContainer.ALIGNMENT_CENTER
	box.add_child(movie_box)

	var close := Button.new()
	close.text = "✖ Close"
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(close_studio)
	box.add_child(close)

func open_studio() -> void:
	visible = true
	original_texture = background.texture
	_pick_backdrop(backdrop)
	var sounds := _sounds()
	action_buttons["speak"].text = "💬 " + String(sounds[0]).trim_suffix("!")
	action_buttons["sound2"].text = "💬 " + String(sounds[1]).trim_suffix("!").trim_suffix("...")
	_show_idle()

func close_studio() -> void:
	cancel_playback = true
	play_id += 1
	_clear_card()
	_bars(false)
	if original_texture:
		background.texture = original_texture
	queue.clear()
	mode = Mode.IDLE
	_stop_voice()
	visible = false
	closed.emit()

func _exit_tree() -> void:
	cancel_playback = true
	play_id += 1
	_stop_voice()

func _show_idle() -> void:
	mode = Mode.IDLE
	status_label.text = "🎬 Pick a backdrop, then film %s!" % PetalState.pet_name
	record_button.text = "🎬 Action!"
	record_button.disabled = false
	_set_action_buttons(false)
	_set_panels(true)
	_set_backdrop_enabled(true)
	_refresh_movies()

func _set_action_buttons(enabled: bool) -> void:
	for b in action_box.get_children():
		b.disabled = not enabled

func _refresh_movies() -> void:
	for c in movie_box.get_children():
		c.queue_free()
	for i in range(movies.size()):
		var b := Button.new()
		b.text = "▶ %s" % movies[i]["title"]
		b.add_theme_font_size_override("font_size", 18)
		b.disabled = mode != Mode.IDLE
		b.pressed.connect(_play_movie.bind(i))
		movie_box.add_child(b)

# --- Recording ----------------------------------------------------------------

func _on_record_pressed() -> void:
	if mode == Mode.IDLE:
		_start_recording()
	elif mode == Mode.RECORDING:
		_cut()
	elif mode == Mode.PLAYING:
		_stop_playback()

func _start_recording() -> void:
	mode = Mode.RECORDING
	steps.clear()
	queue.clear()
	clock = 0.0
	last_end = 0.0
	record_button.text = "⏹ Cut!"
	_set_action_buttons(true)
	_set_backdrop_enabled(false)
	_bars(true)
	_refresh_movies()
	voice_on = _start_voice()
	_update_rec_label()

func _update_rec_label() -> void:
	var hint := "say a trick or tap it" if voice_on else "tap a trick"
	status_label.text = "Tap a trick!" if not voice_on else "Say a trick or tap it!"
	rec_label.text = "● REC  %d:%02d" % [int(clock) / 60, int(clock) % 60]
	rec_label.modulate.a = 1.0 if int(clock * 2.0) % 2 == 0 else 0.35

func _process(delta: float) -> void:
	if mode != Mode.RECORDING:
		return
	clock += delta
	_update_rec_label()
	if voice_on:
		poll += delta
		if poll >= 0.3:
			poll = 0.0
			_heard(_take_heard_words())

func _request(action: String) -> void:
	if mode != Mode.RECORDING:
		return
	queue.append(action)
	if not running:
		_run_queue()

func _run_queue() -> void:
	running = true
	while not queue.is_empty() and mode == Mode.RECORDING:
		var action: String = queue.pop_front()
		steps.append({"gap": maxf(0.0, clock - last_end), "action": action})
		await _perform(action)
		if not is_instance_valid(self):
			return
		last_end = clock
	running = false

func _cut() -> void:
	if mode != Mode.RECORDING:
		return
	mode = Mode.IDLE
	queue.clear()
	_stop_voice()
	_set_action_buttons(false)
	record_button.disabled = true
	while running:
		await get_tree().process_frame
		if not is_instance_valid(self):
			return
	if steps.is_empty():
		status_label.text = "🎬 Nothing filmed! Try some tricks."
		_bars(false)
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(self) and visible:
			_show_idle()
		return
	if movies.size() >= MAX_MOVIES:
		movies.pop_front()
	var n := movies.size() + 1
	movies.append({"title": "Movie %d 🎬" % n, "steps": steps.duplicate(true), "backdrop": backdrop})
	PetalState.award_sticker("party")
	_play_movie(movies.size() - 1)

# --- Playback -----------------------------------------------------------------

func _play_movie(index: int) -> void:
	if mode == Mode.PLAYING or index >= movies.size():
		return
	mode = Mode.PLAYING
	cancel_playback = false
	play_id += 1
	var mine := play_id
	var movie: Dictionary = movies[index]
	_set_action_buttons(false)
	_set_panels(false)
	record_button.text = "⏹ Stop movie"
	record_button.disabled = false
	_bars(true)
	rec_label.modulate.a = 1.0
	rec_label.text = "▶ %s" % movie["title"]
	_set_background(String(movie.get("backdrop", "party")))
	status_label.text = ""
	await _card(["%s" % movie["title"], "starring %s" % PetalState.pet_name], 2.0, 48)
	for step in movie["steps"]:
		await get_tree().create_timer(minf(float(step["gap"]), 2.0)).timeout
		if mine != play_id or not is_instance_valid(self):
			return
		await _perform(step["action"])
		if mine != play_id or not is_instance_valid(self):
			return
	Sfx.fanfare(host)
	var director := PetalState.player_name if PetalState.player_name != "" else "a friend"
	await _card(["THE END", "Starring %s" % PetalState.pet_name, "Directed by %s" % director], 2.8, 56)
	if mine == play_id and is_instance_valid(self):
		_stop_playback()

func _stop_playback() -> void:
	play_id += 1
	cancel_playback = true
	_clear_card()
	_bars(false)
	_set_background(backdrop)
	if visible:
		_show_idle()

# --- Look: backdrops, letterbox bars, title cards, bubbles --------------------

func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", GOLD)
	return label

func _set_panels(on: bool) -> void:
	for node in [backdrop_title, backdrop_box, tricks_title, action_box, movie_box]:
		node.visible = on

func _set_backdrop_enabled(on: bool) -> void:
	for id in backdrop_buttons:
		backdrop_buttons[id].disabled = not on

func _set_background(id: String) -> void:
	var info: Array = BACKDROPS.get(id, BACKDROPS["party"])
	background.texture = load(PetalState.room_bg(info[1], info[2]))

func _pick_backdrop(id: String) -> void:
	backdrop = id
	_set_background(id)
	for key in backdrop_buttons:
		backdrop_buttons[key].modulate = GOLD if key == id else Color.WHITE

func _build_bars() -> void:
	top_bar = ColorRect.new()
	top_bar.color = Color.BLACK
	top_bar.anchor_right = 1.0
	top_bar.offset_bottom = 0.0
	top_bar.z_index = 20
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(top_bar)
	bottom_bar = ColorRect.new()
	bottom_bar.color = Color.BLACK
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_top = 0.0
	bottom_bar.z_index = 20
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(bottom_bar)
	rec_label = Label.new()
	rec_label.add_theme_font_size_override("font_size", 26)
	rec_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	rec_label.position = Vector2(24, 14)
	top_bar.add_child(rec_label)

# Slides the cinema bars in (filming and playback) or away again.
func _bars(on: bool) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(top_bar, "offset_bottom", BAR_HEIGHT if on else 0.0, 0.35)
	tween.tween_property(bottom_bar, "offset_top", -BAR_HEIGHT if on else 0.0, 0.35)
	if not on:
		rec_label.text = ""

func _clear_card() -> void:
	if is_instance_valid(card):
		card.queue_free()
	card = null

# A black title/credits card that fades in and out over the whole room.
func _card(lines: Array, seconds: float, font_size: int) -> void:
	_clear_card()
	var cover := ColorRect.new()
	cover.color = Color.BLACK
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.z_index = 40
	cover.modulate.a = 0.0
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(cover)
	card = cover
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	cover.add_child(column)
	for i in range(lines.size()):
		var label := Label.new()
		label.text = String(lines[i])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", font_size if i == 0 else int(font_size * 0.5))
		label.add_theme_color_override("font_color", GOLD if i == 0 else Color(0.9, 0.9, 0.95))
		column.add_child(label)
	var tween := create_tween()
	tween.tween_property(cover, "modulate:a", 1.0, 0.35)
	await get_tree().create_timer(seconds).timeout
	if not is_instance_valid(self) or card != cover:
		return
	var fade := create_tween()
	fade.tween_property(cover, "modulate:a", 0.0, 0.4)
	await fade.finished
	if is_instance_valid(cover):
		cover.queue_free()
	if card == cover:
		card = null

# A comic speech bubble above her head, with a tail pointing down at her.
func _speech_bubble(text: String, font_size: int = 30, seconds: float = 1.6) -> void:
	var bubble := PanelContainer.new()
	bubble.z_index = 30
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = Color(0.15, 0.1, 0.2)
	style.set_border_width_all(4)
	style.set_corner_radius_all(26)
	style.set_content_margin_all(14)
	bubble.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.2))
	bubble.add_child(label)
	host.add_child(bubble)
	await get_tree().process_frame
	if not is_instance_valid(bubble):
		return
	var w := bubble.size.x
	var h := bubble.size.y
	var tail_outline := Polygon2D.new()
	tail_outline.polygon = PackedVector2Array([Vector2(w * 0.5 - 20, h - 4), Vector2(w * 0.5 + 24, h - 4), Vector2(w * 0.5 + 6, h + 28)])
	tail_outline.color = Color(0.15, 0.1, 0.2)
	bubble.add_child(tail_outline)
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(w * 0.5 - 14, h - 8), Vector2(w * 0.5 + 18, h - 8), Vector2(w * 0.5 + 6, h + 18)])
	tail.color = Color.WHITE
	bubble.add_child(tail)
	var head := pet.global_position - host.global_position + Vector2(pet.size.x * 0.5, 0)
	bubble.position = head - Vector2(w * 0.5, h + 34.0)
	bubble.pivot_offset = Vector2(w * 0.5, h + 28.0)
	bubble.scale = Vector2(0.6, 0.6)
	bubble.modulate.a = 0.0
	var tween := bubble.create_tween()
	tween.tween_property(bubble, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bubble, "modulate:a", 1.0, 0.15)
	tween.tween_interval(seconds)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tween.tween_callback(bubble.queue_free)

# --- The tricks ---------------------------------------------------------------

func _sounds() -> Array:
	var species := String(PetalState.PETS[PetalState.active_pet].get("species", "cat"))
	return SOUNDS.get(species, SOUNDS["cat"])

func _perform(action: String) -> void:
	var at := pet.global_position + Vector2(pet.size.x * 0.6, -10)
	match action:
		"speak":
			Sfx.pop(host)
			_speech_bubble(_sounds()[0])
			await PetCameo.jump_for_joy(pet)
		"sound2":
			Sfx.chime(host)
			_speech_bubble(_sounds()[1])
			await PetCameo.jump_for_joy(pet)
		"sleep":
			_speech_bubble("💤 zzz...", 30, 2.2)
			await PetCameo.sleep(pet)
			await get_tree().create_timer(1.5).timeout
			PetCameo.wake(pet)
		"dance":
			await PetCameo.dance(pet, 1)
		"jump":
			await PetCameo.jump_for_joy(pet)
		"sing":
			if PetalState.has_anim("trick_sing"):
				_speech_bubble("🎵 la la la", 30, 2.0)
				await PetCameo.perform_trick(pet, "sing")
			else:
				_speech_bubble("🎵 la la la", 30, 2.0)
				await PetCameo.dance(pet, 1)
		_:
			if action.begins_with("emoji:"):
				await _say_emoji(action.trim_prefix("emoji:"), at)
			else:
				await PetCameo.perform_trick(pet, action)

# The pet "says" an approved emoji with a happy hop. Anything not on the
# approved list (e.g. from an old or edited movie) is ignored.
func _say_emoji(emoji: String, at: Vector2) -> void:
	if not APPROVED_EMOJIS.has(emoji):
		return
	Sfx.pop(host)
	_speech_bubble(emoji, 44)
	await PetCameo.jump_for_joy(pet)

# --- Voice commands -----------------------------------------------------------
# Web build only, via the browser's speech recognition (Chrome sends the
# audio to the browser vendor to transcribe it). Elsewhere the buttons do
# the same job.

func _start_voice() -> bool:
	if not OS.has_feature("web"):
		return false
	var ok = JavaScriptBridge.eval("""
		(function(){
			var SR = window.SpeechRecognition || window.webkitSpeechRecognition;
			window.__filmWords = "";
			if (!SR) return false;
			var r = new SR();
			r.continuous = true; r.interimResults = false; r.lang = "en-US";
			r.onresult = function(e){
				for (var i = e.resultIndex; i < e.results.length; i++)
					if (e.results[i].isFinal) window.__filmWords += " " + e.results[i][0].transcript;
			};
			r.onend = function(){ if (window.__filmRun) { try { r.start(); } catch (x) {} } };
			window.__filmRec = r; window.__filmRun = true;
			try { r.start(); } catch (x) { return false; }
			return true;
		})()
	""", true)
	return ok == true

func _stop_voice() -> void:
	if voice_on:
		JavaScriptBridge.eval("window.__filmRun = false; try { window.__filmRec.stop(); } catch (x) {}", true)
	voice_on = false

func _take_heard_words() -> String:
	return String(JavaScriptBridge.eval("(function(){var w=window.__filmWords||'';window.__filmWords='';return w;})()", true))

func _heard(text: String) -> void:
	for token in text.to_lower().split(" ", false):
		var word := ""
		for ch in token:
			if ch >= "a" and ch <= "z":
				word += ch
		if VOICE.has(word):
			_request(VOICE[word])
		elif EMOJI_WORDS.has(word):
			_request("emoji:" + EMOJI_WORDS[word])
