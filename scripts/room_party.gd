extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const PartyFilm = preload("res://scripts/party_film.gd")
const PartyVideo = preload("res://scripts/party_video.gd")

@onready var celebrate_button: Button = %CelebrateButton
@onready var dance_button: Button = %DanceButton

var is_dancing := false

func _ready() -> void:
	%Background.texture = load(PetalState.room_bg("party", "res://Sprites/backgrounds/party_room.jpg"))
	PetCameo.spawn(%Petal)
	celebrate_button.pressed.connect(_on_celebrate)
	dance_button.pressed.connect(_on_dance)
	_setup_karaoke()

func _on_celebrate() -> void:
	PetalState.celebrate_party()
	PetCameo.jump_for_joy(%Petal)
	for offset in [Vector2(-60, -30), Vector2(60, -60), Vector2(0, -90), Vector2(-100, -80)]:
		Feedback.pop(self, ["🎈", "🎊", "🎉", "✨"].pick_random(), celebrate_button.global_position + offset)

func _on_dance() -> void:
	if is_dancing:
		return
	is_dancing = true
	dance_button.disabled = true
	PetalState.celebrate_party()
	Feedback.pop(self, "💃 dance party!", dance_button.global_position)
	await PetCameo.dance(%Petal)
	if not is_instance_valid(self):
		return
	dance_button.disabled = false
	is_dancing = false

# --- Karaoke ----------------------------------------------------------------
# Records the player's song from the microphone, plays it back, then the pet
# rates it. The pet is a very loyal fan: the rating is always 4 or 5 stars.
# The mic feeds a recording bus that is routed into a silent bus, so there is
# no feedback squeal while singing.
const REC_BUS := "KaraokeRec"
const MUTE_BUS := "KaraokeMute"
const MAX_SING_SECONDS := 30.0
# Whole words only (so "class" or "assess" never trip it). Browsers often
# star out swear words in their transcripts, so those count too.
const BAD_WORDS := ["damn", "hell", "crap", "shit", "fuck", "fucking", "bitch", "ass", "asshole",
	"bastard", "piss", "dick", "stupid", "idiot", "shut up", "sh*t", "f***", "f*** ", "b****", "a**"]

var karaoke_panel: PanelContainer
var film_studio: PanelContainer
var video_studio: PanelContainer
var karaoke_label: Label
var karaoke_stop: Button
var mic_player: AudioStreamPlayer
var playback_player: AudioStreamPlayer
var singing := false
var karaoke_busy := false
var sing_time := 0.0
var loud_time := 0.0
var strong_time := 0.0
var level_bar: ProgressBar
var name_heard := false
var bad_heard := false
var speech_supported := false

# Each song style has its own lyric cards, background tint and cheers. {pet}
# is replaced with the pet's name.
const LYRIC_SECONDS := 4.5
const STYLES := {
	"lullaby": {
		"label": "🌙 Lullaby", "tint": Color(0.7, 0.75, 1.0), "intro": "🌙 Sing a soft lullaby for %s!",
		"lyrics": ["Sleepy sleepy {pet}, close your eyes", "Twinkle twinkle in the sky", "Soft little paws and a cozy bed", "Dream of fish and butterflies", "Goodnight {pet}, sweet dreams"],
		"good": "That was so soothing. A little more voice and it's perfect!",
		"best": "So dreamy and sweet. I'm yawning with happiness!",
	},
	"rock": {
		"label": "🎸 Rock Star", "tint": Color(1.0, 0.65, 0.75), "intro": "🎸 Rock out for %s!",
		"lyrics": ["{pet} is the rock star of the world", "Shake it shake it, jump up high", "Meow meow, hear me roar", "Turn it up, we want more", "Yeah yeah yeah, {pet} rocks"],
		"good": "That rocked! A bit more power and it's perfect!",
		"best": "ROCK STAR! My fur is standing on end!",
	},
	"opera": {
		"label": "🎭 Opera", "tint": Color(1.0, 0.9, 0.6), "intro": "🎭 Sing a grand opera for %s!",
		"lyrics": ["Ooooh {pet}, my darling {pet}", "La la laaaa, la la laaaa", "Fish and cuddles, hear my song", "Ahhh, ahhh, a high note now", "Bravo bravo, {pet}, bravo"],
		"good": "Lovely! Hold the big notes a bit louder!",
		"best": "BRAVISSIMO! You hit the high notes!",
	},
	"rap": {
		"label": "🎤 Rap", "tint": Color(0.7, 1.0, 0.8), "intro": "🎤 Drop a rap about %s!",
		"lyrics": ["Yo, I'm {pet}, I'm a cool little cat", "Got my paws up, wearing a hat", "Snacks and naps, that's how I roll", "Beat goes boom, I'm in control", "Mic drop, {pet}, that's a wrap"],
		"good": "Nice flow! A bit more voice and it's perfect!",
		"best": "Mic drop! That beat was fire!",
	},
}
var style_row: HBoxContainer
var lyric_label: Label
var style_key := ""
var lyric_index := 0
var lyric_time := 0.0
var shown_lyrics := ""
var lyrics_heard := 0
var pet_mic: TextureRect

func _setup_karaoke() -> void:
	karaoke_panel = PanelContainer.new()
	karaoke_panel.visible = false
	karaoke_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	karaoke_panel.position = Vector2(-260, 80)
	karaoke_panel.custom_minimum_size = Vector2(520, 0)
	karaoke_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	karaoke_panel.add_child(box)
	karaoke_label = Label.new()
	karaoke_label.add_theme_font_size_override("font_size", 26)
	karaoke_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	karaoke_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(karaoke_label)
	style_row = HBoxContainer.new()
	style_row.alignment = BoxContainer.ALIGNMENT_CENTER
	style_row.visible = false
	for key in STYLES:
		var b := Button.new()
		b.text = STYLES[key]["label"]
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(_begin_singing.bind(key))
		style_row.add_child(b)
	box.add_child(style_row)
	lyric_label = Label.new()
	lyric_label.add_theme_font_size_override("font_size", 30)
	lyric_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lyric_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lyric_label.visible = false
	box.add_child(lyric_label)
	level_bar = ProgressBar.new()
	level_bar.min_value = -50.0
	level_bar.max_value = -5.0
	level_bar.show_percentage = false
	level_bar.custom_minimum_size = Vector2(0, 24)
	level_bar.visible = false
	box.add_child(level_bar)
	karaoke_stop = Button.new()
	karaoke_stop.text = "⏹ Done singing!"
	karaoke_stop.add_theme_font_size_override("font_size", 22)
	karaoke_stop.pressed.connect(_stop_karaoke)
	box.add_child(karaoke_stop)
	add_child(karaoke_panel)

	playback_player = AudioStreamPlayer.new()
	add_child(playback_player)
	%KaraokeButton.pressed.connect(_on_karaoke)

	film_studio = PartyFilm.new()
	add_child(film_studio)
	film_studio.setup(self, %Petal)
	film_studio.closed.connect(_on_film_closed)
	%FilmButton.pressed.connect(_on_film)

	video_studio = PartyVideo.new()
	add_child(video_studio)
	video_studio.setup(self, %Petal)
	video_studio.closed.connect(_on_video_closed)
	%VideoButton.pressed.connect(_on_video)

func _on_video() -> void:
	if karaoke_busy:
		return
	_set_extras_disabled(true)
	video_studio.open_studio()

func _on_video_closed() -> void:
	_set_extras_disabled(false)

# Karaoke, Film and Video each take over the top of the screen, so only one
# can be open at a time.
func _set_extras_disabled(disabled: bool) -> void:
	%KaraokeButton.disabled = disabled
	%FilmButton.disabled = disabled
	%VideoButton.disabled = disabled

func _on_film() -> void:
	if karaoke_busy:
		return
	_set_extras_disabled(true)
	film_studio.open_studio()

func _on_film_closed() -> void:
	_set_extras_disabled(false)

func _ensure_karaoke_buses() -> void:
	if AudioServer.get_bus_index(MUTE_BUS) == -1:
		AudioServer.add_bus()
		var mute_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(mute_idx, MUTE_BUS)
		AudioServer.set_bus_volume_db(mute_idx, -80.0)
	if AudioServer.get_bus_index(REC_BUS) == -1:
		AudioServer.add_bus()
		var rec_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(rec_idx, REC_BUS)
		AudioServer.set_bus_send(rec_idx, MUTE_BUS)
		AudioServer.add_bus_effect(rec_idx, AudioEffectRecord.new())

func _record_effect() -> AudioEffectRecord:
	return AudioServer.get_bus_effect(AudioServer.get_bus_index(REC_BUS), 0) as AudioEffectRecord

func _on_karaoke() -> void:
	if karaoke_busy:
		return
	karaoke_busy = true
	_set_extras_disabled(true)
	%Background.texture = load("res://Sprites/backgrounds/karaoke.jpg")
	karaoke_panel.visible = true
	karaoke_stop.visible = false
	OS.request_permission("RECORD_AUDIO")
	if AudioServer.get_input_device_list().is_empty():
		karaoke_label.text = "🎤 Ask a grown-up to turn on the microphone!"
		await get_tree().create_timer(3.0).timeout
		_end_karaoke()
		return
	karaoke_label.text = "🎶 Pick a song style!"
	style_row.visible = true

func _begin_singing(key: String) -> void:
	style_key = key
	style_row.visible = false
	%Background.modulate = STYLES[key]["tint"]
	_ensure_karaoke_buses()
	mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = REC_BUS
	add_child(mic_player)
	mic_player.play()
	_record_effect().set_recording_active(true)
	singing = true
	sing_time = 0.0
	loud_time = 0.0
	strong_time = 0.0
	name_heard = false
	bad_heard = false
	speech_supported = _start_speech()
	level_bar.visible = true
	karaoke_label.text = STYLES[key]["intro"] % PetalState.pet_name
	lyric_index = 0
	lyric_time = 0.0
	shown_lyrics = ""
	lyrics_heard = 0
	lyric_label.visible = true
	_show_lyric()
	karaoke_stop.visible = true
	_hold_mic()
	_sing_along()

# The pet bobs along for as long as the player is singing.
func _sing_along() -> void:
	while singing and is_instance_valid(self):
		if PetalState.has_anim("trick_sing"):
			await PetCameo.perform_trick(%Petal, "sing")
		else:
			await PetCameo.dance(%Petal, 1)

func _process(delta: float) -> void:
	if not singing:
		return
	sing_time += delta
	lyric_time += delta
	if lyric_time >= LYRIC_SECONDS:
		lyric_time = 0.0
		lyric_index += 1
		_show_lyric()
	var rec_idx := AudioServer.get_bus_index(REC_BUS)
	var db := AudioServer.get_bus_peak_volume_left_db(rec_idx, 0)
	level_bar.value = lerpf(level_bar.value, db, 0.4)
	if db > -40.0:
		loud_time += delta
	if db > -20.0:
		strong_time += delta
	if sing_time >= MAX_SING_SECONDS:
		_stop_karaoke()

# The mic is a child of the pet, so it hops and dances along with her. The
# spot is a rough guess at where a paw is on the pose art.
func _hold_mic() -> void:
	if pet_mic == null:
		pet_mic = TextureRect.new()
		pet_mic.texture = load("res://Sprites/karaoke_mic.png")
		pet_mic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pet_mic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pet_mic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pet_mic.size = Vector2(30, 64)
		%Petal.add_child(pet_mic)
	pet_mic.position = Vector2(%Petal.size.x * 0.62, %Petal.size.y * 0.3)
	pet_mic.visible = true

func _show_lyric() -> void:
	var lines: Array = STYLES[style_key]["lyrics"]
	var line: String = lines[lyric_index % lines.size()].replace("{pet}", PetalState.pet_name)
	lyric_label.text = "♪ %s ♪" % line
	shown_lyrics += " " + _letters_only(line) + " "

# Counts distinct lyric words (4+ letters) that the speech recogniser heard.
func _lyric_words_heard(heard: String) -> int:
	var seen := {}
	for w in shown_lyrics.split(" ", false):
		if w.length() >= 4 and not seen.has(w) and (" " + heard + " ").contains(" " + w + " "):
			seen[w] = true
	return seen.size()

func _stop_karaoke() -> void:
	if not singing:
		return
	singing = false
	lyric_label.visible = false
	if pet_mic != null:
		pet_mic.visible = false
	_stop_speech()
	karaoke_stop.visible = false
	level_bar.visible = false
	var effect := _record_effect()
	effect.set_recording_active(false)
	var recording := effect.get_recording()
	mic_player.stop()
	mic_player.queue_free()
	mic_player = null
	if recording != null and sing_time > 1.0:
		karaoke_label.text = "🎧 Listen to your song!"
		playback_player.stream = recording
		playback_player.play()
		PetCameo.dance(%Petal, 2)
		await playback_player.finished
		if not is_instance_valid(self):
			return
	# Feedback only comes after the song: give the speech recogniser a
	# moment to finish, then the pet says what they heard.
	karaoke_label.text = "🤔 %s is thinking about your song..." % PetalState.pet_name
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(self):
		return
	_name_check()
	_rate_song()

func _rate_song() -> void:
	var pet := PetalState.pet_name
	if bad_heard:
		karaoke_label.text = "⭐\n%s says: Ooh, I don't like those words! Please sing a nicer song." % pet
		await get_tree().create_timer(4.0).timeout
		_end_karaoke()
		return
	var stars: int
	var lines: Array
	if loud_time < 0.5:
		stars = 1
		lines = ["%s says: Hmm, I couldn't hear you! Try singing into the mic." % pet]
	elif sing_time < 3.0 or loud_time < 2.0:
		stars = 2
		lines = ["%s says: That was really short and quiet. Sing a longer, louder song!" % pet]
	elif strong_time < 0.5:
		stars = 3
		lines = ["%s says: Nice and gentle, but I couldn't hear much. Louder please!" % pet]
	elif strong_time < 1.5:
		stars = 4
		lines = ["%s says: %s" % [pet, STYLES[style_key]["good"]]]
	else:
		stars = 5
		lines = ["%s says: %s" % [pet, STYLES[style_key]["best"]]]
	var line: String = lines.pick_random()
	if lyrics_heard >= 3 and stars >= 3:
		stars = mini(5, stars + 1)
		line += " You sang the words too!"
	if name_heard:
		stars = mini(5, stars + 1)
		line = "%s says: I heard my name! That song was about ME!" % pet
	elif speech_supported:
		line += " (Sing my name too!)"
	karaoke_label.text = "%s\n%s" % ["⭐".repeat(stars), line]
	PetalState.celebrate_party()
	PetCameo.jump_for_joy(%Petal)
	for offset in [Vector2(-60, -30), Vector2(60, -60), Vector2(0, -90)]:
		Feedback.pop(self, ["🎵", "🎶", "⭐", "✨"].pick_random(), %KaraokeButton.global_position + offset)
	await get_tree().create_timer(4.0).timeout
	_end_karaoke()

func _end_karaoke() -> void:
	if not is_instance_valid(self):
		return
	karaoke_panel.visible = false
	style_row.visible = false
	lyric_label.visible = false
	if pet_mic != null:
		pet_mic.visible = false
	%Background.modulate = Color.WHITE
	%Background.texture = load(PetalState.room_bg("party", "res://Sprites/backgrounds/party_room.jpg"))
	_set_extras_disabled(false)
	karaoke_busy = false

func _exit_tree() -> void:
	singing = false
	_stop_speech()
	if mic_player != null:
		mic_player.stop()
		if AudioServer.get_bus_index(REC_BUS) != -1:
			_record_effect().set_recording_active(false)

# --- Name listening ---------------------------------------------------------
# Godot has no speech recognition, so this uses the browser's own
# (Web Speech API) and only works in the web build. Elsewhere
# speech_supported stays false and the pet just rates the sound.
# Note: Chrome sends the audio to the browser vendor to transcribe it.

func _start_speech() -> bool:
	if not OS.has_feature("web"):
		return false
	var ok = JavaScriptBridge.eval("""
		(function(){
			var SR = window.SpeechRecognition || window.webkitSpeechRecognition;
			window.__karaokeHeard = "";
			if (!SR) return false;
			var r = new SR();
			r.continuous = true; r.interimResults = true; r.lang = "en-US";
			r.onresult = function(e){
				var t = "";
				for (var i = 0; i < e.results.length; i++) t += e.results[i][0].transcript + " ";
				window.__karaokeHeard = t.toLowerCase();
			};
			r.onend = function(){ if (window.__karaokeRun) { try { r.start(); } catch (x) {} } };
			window.__karaokeRec = r; window.__karaokeRun = true;
			try { r.start(); } catch (x) { return false; }
			return true;
		})()
	""", true)
	return ok == true

func _stop_speech() -> void:
	if speech_supported:
		JavaScriptBridge.eval("window.__karaokeRun = false; try { window.__karaokeRec.stop(); } catch (x) {}", true)

func _name_check() -> void:
	if not speech_supported:
		return
	var heard := String(JavaScriptBridge.eval("window.__karaokeHeard || ''", true)).to_lower()
	for word in BAD_WORDS:
		if heard.contains(" " + word + " ") or (" " + heard + " ").contains(" " + word + " "):
			bad_heard = true
	lyrics_heard = _lyric_words_heard(heard)
	if name_heard:
		return
	for candidate in [PetalState.pet_name, String(PetalState.PETS[PetalState.active_pet]["name"])]:
		var word := _letters_only(candidate)
		if word != "" and heard.contains(word):
			name_heard = true
			return

# Nicknames can hold emoji from the name picker - only match the letters.
func _letters_only(text: String) -> String:
	var out := ""
	for ch in text.to_lower():
		if ch >= "a" and ch <= "z" or ch == " " or ch == "'":
			out += ch
	return out.strip_edges()
