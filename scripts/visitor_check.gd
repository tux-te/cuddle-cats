class_name VisitorCheck
extends Control

# Shown after Start: "I am a bot" / "I am not a bot", with a running tally of
# each kept on this device, then the game opens as normal. A grown-up can also
# switch on sharing: while it is on, each save also writes a copy of the texts
# and calendar to user://shared_with_maker_<slot>.json. It is off until
# someone taps it, and nothing is ever sent over the internet by the game.

signal done

const STATS_PATH := "user://visitors.cfg"

static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(STATS_PATH)
	return cfg

static func count(kind: String) -> int:
	return int(_load().get_value("visitors", kind, 0))

static func record(kind: String) -> void:
	var cfg := _load()
	cfg.set_value("visitors", kind, count(kind) + 1)
	cfg.save(STATS_PATH)

static func sharing_allowed() -> bool:
	return bool(_load().get_value("sharing", "allowed", false))

static func set_sharing(allowed: bool) -> void:
	var cfg := _load()
	cfg.set_value("sharing", "allowed", allowed)
	cfg.save(STATS_PATH)

# Where the "Send to maker" email goes. Empty = just save the file (set a
# real address here to also open a pre-filled email).
const MAKER_EMAIL := ""
const SEND_FILE := "cuddle_cats_for_maker.json"

# The share question is only asked the first time the game opens on a device.
static func share_asked() -> bool:
	return bool(_load().get_value("sharing", "asked", false))

static func set_share_answer(allowed: bool) -> void:
	var cfg := _load()
	cfg.set_value("sharing", "allowed", allowed)
	cfg.set_value("sharing", "asked", true)
	cfg.save(STATS_PATH)

# What gets shared: the texts, the weekly plan (with where each thing is) and the My Home design with its address.
static func payload(texts: Array, schedule, home := {}) -> Dictionary:
	var shared_home := home.duplicate()
	# A drawn house goes as one text line per pixel row (. empty, # outline, a-l colours).
	if shared_home.get("pixels") is PackedByteArray:
		var rows: Array[String] = []
		var pixels: PackedByteArray = shared_home["pixels"]
		for y in range(PetalState.HOME_PIX_H):
			var line := ""
			for x in range(PetalState.HOME_PIX_W):
				var value := pixels[y * PetalState.HOME_PIX_W + x] if pixels.size() > y * PetalState.HOME_PIX_W + x else 0
				line += "." if value == 0 else ("#" if value == 1 else char(95 + value))
			rows.append(line)
		shared_home["pixels"] = rows if not pixels.is_empty() else []
	return {"texts": texts, "schedule": schedule, "home": shared_home}

# Called by PetalState.save_game; writes nothing unless a grown-up said yes.
static func export_if_allowed(slot: int, texts: Array, schedule, home := {}) -> void:
	if not sharing_allowed():
		return
	var file := FileAccess.open("user://shared_with_maker_%d.json" % slot, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload(texts, schedule, home), "\t"))

static func open(parent: Node) -> VisitorCheck:
	var check := VisitorCheck.new()
	check.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(check)
	check._build()
	return check

func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.23, 0.16, 0.16, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.96, 0.98, 1)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var heading := Label.new()
	heading.text = "Quick question! 🐾"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color(0.72, 0.31, 0.47, 1))
	box.add_child(heading)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	row.add_child(_choice("🤖 I am a bot", "bots"))
	row.add_child(_choice("🧒 I am not a bot", "humans"))

	var tally := Label.new()
	tally.text = "On this device so far:  🤖 %d bots   🧒 %d real people" % [count("bots"), count("humans")]
	tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally.add_theme_font_size_override("font_size", 18)
	box.add_child(tally)

	var grownup := Label.new()
	grownup.text = "Grown-ups: may we keep a copy of the texts and weekly\nschedule for the game's maker? It is off unless you tap it."
	grownup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grownup.add_theme_font_size_override("font_size", 16)
	box.add_child(grownup)
	var share := Button.new()
	share.toggle_mode = true
	share.button_pressed = sharing_allowed()
	share.custom_minimum_size = Vector2(0, 52)
	share.add_theme_font_size_override("font_size", 20)
	share.text = _share_text(share.button_pressed)
	share.toggled.connect(func(on: bool) -> void:
		set_sharing(on)
		share.text = _share_text(on))
	box.add_child(share)

func _share_text(on: bool) -> String:
	return "☑ Sharing texts & schedule: ON" if on else "☐ Share texts & schedule with the maker"

func _choice(text: String, kind: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(250, 80)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(func() -> void:
		record(kind)
		done.emit()
		queue_free())
	return button

# --- One-time share question and the Send to maker button --------------------

var message: Label
var box: VBoxContainer

static func open_share_question(parent: Node) -> VisitorCheck:
	var check := VisitorCheck.new()
	check.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(check)
	check._build_panel("Grown-ups, quick question 🐾")
	check._say("May the game's maker see this player's texts, weekly plan and home address? Nothing is sent automatically - a grown-up chooses when to send them with the 📤 Send to maker button, and you can see exactly what is in the file.")
	var yes := check._button("✅ Yes, I may send them", func() -> void:
		set_share_answer(true)
		check._finish())
	var no := check._button("No thanks", func() -> void:
		set_share_answer(false)
		check._finish())
	check.box.add_child(yes)
	check.box.add_child(no)
	return check

# The header's Send button: explains what is in the file, then saves it.
static func open_send(parent: Node) -> VisitorCheck:
	var check := VisitorCheck.new()
	check.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(check)
	check._build_panel("📤 Send to the maker")
	check._say("This saves a file with this player's texts and weekly plan (with where things are) and My Home address. A grown-up can then email it to the maker.")
	check.box.add_child(check._button("💾 Save the file", check._save_for_maker))
	check.box.add_child(check._button("Cancel", check._finish))
	return check

func _build_panel(title: String) -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.23, 0.16, 0.16, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.96, 0.98, 1)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color(0.72, 0.31, 0.47, 1))
	box.add_child(heading)
	message = Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 18)
	message.add_theme_color_override("font_color", Color.BLACK)
	box.add_child(message)

func _say(text: String) -> void:
	message.text = text

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 22)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, Color.BLACK)
	button.pressed.connect(action)
	return button

func _finish() -> void:
	done.emit()
	queue_free()

func _save_for_maker() -> void:
	var text := JSON.stringify(payload(PetalState.chat_log, PetalState.schedule, PetalState.my_home), "\t")
	for child in box.get_children():
		if child is Button:
			child.queue_free()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), SEND_FILE, "application/json")
		_say("✅ Saved to your downloads as %s. Please email that file to the maker." % SEND_FILE)
	else:
		var file := FileAccess.open("user://" + SEND_FILE, FileAccess.WRITE)
		if file == null:
			_say("Oops, the file could not be saved.")
		else:
			file.store_string(text)
			file.close()
			OS.shell_show_in_file_manager(ProjectSettings.globalize_path("user://" + SEND_FILE))
			_say("✅ Saved as %s - the folder is open. Please email that file to the maker." % SEND_FILE)
	if MAKER_EMAIL != "":
		OS.shell_open("mailto:%s?subject=%s&body=%s" % [MAKER_EMAIL, "Cuddle Cats texts".uri_encode(), "The file is attached.".uri_encode()])
	box.add_child(_button("Close", _finish))
