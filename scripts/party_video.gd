extends PanelContainer

# "Video for your pet": film yourself with the camera, then send it to the
# pet, who comes to watch it and loves it. Godot can't record video itself,
# so this runs on the browser's camera + MediaRecorder and only works in the
# web build. The video stays in the browser (a local blob URL) - nothing is
# uploaded - and it is dropped when the panel closes. The camera is switched
# off as soon as filming stops.

signal closed

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const Sfx = preload("res://scripts/sfx.gd")

const WATCH_TIMEOUT := 20.0

enum Mode { STARTING, READY, RECORDING, SAVING, RECORDED, WATCHING, ERROR }

var host: Control
var pet: TextureRect
var mode := Mode.STARTING
var clock := 0.0
var poll := 0.0
var watch_time := 0.0
var loved := false

var status_label: Label
var record_button: Button
var send_button: Button
var retake_button: Button

func setup(host_node: Control, pet_node: TextureRect) -> void:
	host = host_node
	pet = pet_node
	visible = false
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	# Offsets, not position: setup runs after this panel is in the tree, where
	# `position` would be taken as absolute and land off-screen.
	offset_left = -290.0
	offset_right = 290.0
	offset_top = 70.0
	custom_minimum_size = Vector2(580, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH

	var box := VBoxContainer.new()
	add_child(box)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)

	record_button = _make_button(box, _on_record_pressed)
	send_button = _make_button(box, _send)
	retake_button = _make_button(box, _retake)
	retake_button.text = "🔁 Film it again"
	var close := _make_button(box, close_studio)
	close.text = "✖ Close"

func _make_button(box: Control, callback: Callable) -> Button:
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(callback)
	box.add_child(b)
	return b

func open_studio() -> void:
	visible = true
	loved = false
	if not OS.has_feature("web"):
		_set_mode(Mode.ERROR)
		status_label.text = "📹 Video messages work in the web version of the game!"
		await get_tree().create_timer(3.0).timeout
		if is_instance_valid(self) and visible:
			close_studio()
		return
	_start_camera()

func close_studio() -> void:
	_drop_video()
	visible = false
	mode = Mode.ERROR
	closed.emit()

func _exit_tree() -> void:
	_drop_video()

# Every state change goes through here so the buttons and label always match.
func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	record_button.visible = mode in [Mode.READY, Mode.RECORDING]
	send_button.visible = mode in [Mode.RECORDED, Mode.WATCHING]
	send_button.disabled = mode == Mode.WATCHING
	retake_button.visible = mode == Mode.RECORDED
	match mode:
		Mode.STARTING:
			status_label.text = "📹 Turning the camera on... say yes if it asks!"
		Mode.READY:
			status_label.text = "📹 The camera is on! Say hi to %s!" % PetalState.pet_name
			record_button.text = "🔴 Start filming"
		Mode.RECORDING:
			record_button.text = "⏹ End recording"
		Mode.SAVING:
			status_label.text = "💾 Saving your video..."
		Mode.RECORDED:
			status_label.text = "🎞 Your video is ready!"
			send_button.text = "📺 Show to %s" % PetalState.pet_name

func _process(delta: float) -> void:
	if not visible or not OS.has_feature("web"):
		return
	match mode:
		Mode.RECORDING:
			clock += delta
			status_label.text = "🔴 Filming  %d:%02d  (smile and wave!)" % [int(clock) / 60, int(clock) % 60]
		Mode.WATCHING:
			watch_time += delta
			if watch_time >= WATCH_TIMEOUT:
				_finish_watching()
	if mode in [Mode.STARTING, Mode.SAVING, Mode.WATCHING]:
		poll += delta
		if poll >= 0.2:
			poll = 0.0
			_check_js_state()

func _check_js_state() -> void:
	var state := String(JavaScriptBridge.eval("(window.__vm && window.__vm.state) || ''", true))
	var playing: bool = JavaScriptBridge.eval("!!(window.__vm && window.__vm.playing)", true) == true
	match mode:
		Mode.STARTING:
			if state == "ready":
				_set_mode(Mode.READY)
			elif state == "error":
				_set_mode(Mode.ERROR)
				status_label.text = "📹 Ask a grown-up to let the game use the camera!"
				await get_tree().create_timer(3.0).timeout
				if is_instance_valid(self) and visible:
					close_studio()
		Mode.SAVING:
			if state == "recorded":
				_set_mode(Mode.RECORDED)
		Mode.WATCHING:
			if not playing and watch_time > 0.5:
				_finish_watching()

# --- Filming ------------------------------------------------------------------

func _on_record_pressed() -> void:
	if mode == Mode.READY:
		clock = 0.0
		JavaScriptBridge.eval(RECORD_JS, true)
		_set_mode(Mode.RECORDING)
	elif mode == Mode.RECORDING:
		_stop_filming()

func _stop_filming() -> void:
	JavaScriptBridge.eval("try { window.__vm.rec.stop(); } catch (x) {}", true)
	_set_mode(Mode.SAVING)

func _retake() -> void:
	_start_camera()

func _start_camera() -> void:
	_set_mode(Mode.STARTING)
	JavaScriptBridge.eval(CAMERA_JS, true)

# --- Sending it to the pet ----------------------------------------------------

func _send() -> void:
	if mode != Mode.RECORDED:
		return
	_set_mode(Mode.WATCHING)
	watch_time = 0.0
	status_label.text = "💌 Sent! %s is watching your video..." % PetalState.pet_name
	Sfx.chime(host)
	Feedback.pop(host, "💌", pet.global_position + Vector2(pet.size.x * 0.5, -10))
	JavaScriptBridge.eval(PLAY_JS, true)

func _finish_watching() -> void:
	if mode != Mode.WATCHING:
		return
	_set_mode(Mode.RECORDED)
	status_label.text = "🥰 %s loves your video!" % PetalState.pet_name
	Sfx.fanfare(host)
	PetalState.celebrate_party()
	PetCameo.jump_for_joy(pet)
	for offset in [Vector2(-40, -30), Vector2(50, -60), Vector2(0, -90)]:
		Feedback.pop(host, ["💖", "💕", "🥰"].pick_random(), pet.global_position + Vector2(pet.size.x * 0.4, 0) + offset)

func _drop_video() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(CLEANUP_JS, true)

# --- Browser side -------------------------------------------------------------
# window.__vm.state: starting -> ready -> recording -> recorded (or error).
# The little video window in the corner shows the live camera, then the clip.

const CAMERA_JS := """
(function(){
	var old = window.__vm;
	if (old) {
		if (old.stream) old.stream.getTracks().forEach(function(t){ t.stop(); });
		if (old.url) URL.revokeObjectURL(old.url);
	}
	var vm = window.__vm = { state: "starting", stream: null, url: "", playing: false };
	var v = document.getElementById("cc-vm");
	if (!v) {
		v = document.createElement("video");
		v.id = "cc-vm";
		v.playsInline = true;
		v.style.cssText = "position:fixed;top:16px;right:16px;width:260px;height:195px;object-fit:cover;" +
			"border-radius:16px;border:4px solid #fff;box-shadow:0 4px 16px rgba(0,0,0,.4);z-index:9999;background:#222;";
		document.body.appendChild(v);
	}
	v.removeAttribute("src"); v.srcObject = null; v.muted = true; v.loop = false;
	v.style.transform = "scaleX(-1)";
	if (!navigator.mediaDevices || !window.MediaRecorder) { vm.state = "error"; return; }
	navigator.mediaDevices.getUserMedia({ video: true, audio: true }).then(function(s){
		vm.stream = s; v.srcObject = s; v.play(); vm.state = "ready";
	}).catch(function(){ vm.state = "error"; });
})()
"""

const RECORD_JS := """
(function(){
	var vm = window.__vm;
	if (!vm || !vm.stream) return;
	var chunks = [];
	var r = new MediaRecorder(vm.stream);
	vm.rec = r;
	r.ondataavailable = function(e){ if (e.data && e.data.size) chunks.push(e.data); };
	r.onstop = function(){
		var b = new Blob(chunks, { type: r.mimeType || "video/webm" });
		vm.url = URL.createObjectURL(b);
		vm.stream.getTracks().forEach(function(t){ t.stop(); });
		vm.stream = null;
		var v = document.getElementById("cc-vm");
		if (!v) { URL.revokeObjectURL(vm.url); return; }
		v.srcObject = null; v.src = vm.url; v.style.transform = "none"; v.muted = false; v.pause();
		vm.state = "recorded";
	};
	r.start(1000);
	vm.state = "recording";
})()
"""

const PLAY_JS := """
(function(){
	var vm = window.__vm, v = document.getElementById("cc-vm");
	if (!vm || !v) return;
	v.currentTime = 0; v.muted = false; vm.playing = true;
	v.onended = function(){ vm.playing = false; };
	var p = v.play();
	if (p && p.catch) p.catch(function(){ vm.playing = false; });
})()
"""

const CLEANUP_JS := """
(function(){
	var vm = window.__vm;
	if (vm) {
		try { if (vm.rec && vm.rec.state === "recording") vm.rec.stop(); } catch (x) {}
		if (vm.stream) vm.stream.getTracks().forEach(function(t){ t.stop(); });
		if (vm.url) URL.revokeObjectURL(vm.url);
	}
	window.__vm = null;
	var v = document.getElementById("cc-vm");
	if (v) { v.pause(); v.removeAttribute("src"); v.srcObject = null; v.remove(); }
})()
"""
