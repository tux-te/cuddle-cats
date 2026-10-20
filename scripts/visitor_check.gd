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

# Called by PetalState.save_game; writes nothing unless a grown-up said yes.
static func export_if_allowed(slot: int, texts: Array, schedule) -> void:
	if not sharing_allowed():
		return
	var file := FileAccess.open("user://shared_with_maker_%d.json" % slot, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"texts": texts, "schedule": schedule}, "\t"))

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
