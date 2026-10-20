extends PanelContainer

# "Film your pet": the player makes the pet do silly things (by tapping the
# buttons, or by saying the word in the web build) while the camera rolls.
# What gets saved is a replayable movie - the list of tricks and the pauses
# between them - which is played back with the pet's own animations, so it
# works the same on every platform and costs almost nothing to keep.
# Movies live only for this session (like the Photo Book).

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

	var box := VBoxContainer.new()
	add_child(box)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)

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
	var sounds := _sounds()
	action_buttons["speak"].text = "💬 " + String(sounds[0]).trim_suffix("!")
	action_buttons["sound2"].text = "💬 " + String(sounds[1]).trim_suffix("!").trim_suffix("...")
	_show_idle()

func close_studio() -> void:
	cancel_playback = true
	queue.clear()
	mode = Mode.IDLE
	_stop_voice()
	visible = false
	closed.emit()

func _exit_tree() -> void:
	cancel_playback = true
	_stop_voice()

func _show_idle() -> void:
	mode = Mode.IDLE
	status_label.text = "🎬 Film %s doing silly things!" % PetalState.pet_name
	record_button.text = "🔴 Start filming"
	record_button.disabled = false
	_set_action_buttons(false)
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

func _start_recording() -> void:
	mode = Mode.RECORDING
	steps.clear()
	queue.clear()
	clock = 0.0
	last_end = 0.0
	record_button.text = "⏹ Cut!"
	_set_action_buttons(true)
	_refresh_movies()
	voice_on = _start_voice()
	_update_rec_label()

func _update_rec_label() -> void:
	var hint := "say a trick or tap it" if voice_on else "tap a trick"
	status_label.text = "🔴 REC  %d:%02d   (%s)" % [int(clock) / 60, int(clock) % 60, hint]

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
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(self) and visible:
			_show_idle()
		return
	if movies.size() >= MAX_MOVIES:
		movies.pop_front()
	var n := movies.size() + 1
	movies.append({"title": "Movie %d 🎬" % n, "steps": steps.duplicate(true)})
	PetalState.award_sticker("party")
	_play_movie(movies.size() - 1)

# --- Playback -----------------------------------------------------------------

func _play_movie(index: int) -> void:
	if mode == Mode.PLAYING or index >= movies.size():
		return
	mode = Mode.PLAYING
	cancel_playback = false
	record_button.disabled = true
	_set_action_buttons(false)
	_refresh_movies()
	status_label.text = "🍿 Now showing: %s" % movies[index]["title"]
	for step in movies[index]["steps"]:
		await get_tree().create_timer(minf(float(step["gap"]), 2.0)).timeout
		if cancel_playback or not is_instance_valid(self):
			return
		await _perform(step["action"])
		if cancel_playback or not is_instance_valid(self):
			return
	status_label.text = "👏 The End!"
	Sfx.fanfare(host)
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(self) and not cancel_playback:
		_show_idle()

# --- The tricks ---------------------------------------------------------------

func _sounds() -> Array:
	var species := String(PetalState.PETS[PetalState.active_pet].get("species", "cat"))
	return SOUNDS.get(species, SOUNDS["cat"])

func _perform(action: String) -> void:
	var at := pet.global_position + Vector2(pet.size.x * 0.6, -10)
	match action:
		"speak":
			Sfx.pop(host)
			Feedback.pop(host, _sounds()[0], at)
			await PetCameo.jump_for_joy(pet)
		"sound2":
			Sfx.chime(host)
			Feedback.pop(host, _sounds()[1], at)
			await PetCameo.jump_for_joy(pet)
		"sleep":
			Feedback.pop(host, "💤 zzz...", at)
			await PetCameo.sleep(pet)
			await get_tree().create_timer(1.5).timeout
			PetCameo.wake(pet)
		"dance":
			await PetCameo.dance(pet, 1)
		"jump":
			await PetCameo.jump_for_joy(pet)
		"sing":
			if PetalState.has_anim("trick_sing"):
				Feedback.pop(host, "🎵", at)
				await PetCameo.perform_trick(pet, "sing")
			else:
				Feedback.pop(host, "🎵 la la la", at)
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
	for offset in [Vector2(0, -50), Vector2(-45, -20), Vector2(45, -20)]:
		Feedback.pop(host, emoji, at + offset)
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
