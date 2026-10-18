class_name NameEditor
extends Control

# A full-screen popup for typing a name with a tap-to-add emoji grid, so kids
# never need a system emoji keyboard (unreliable in web exports). Used for the
# player's name on the title screen and for pet nicknames in the game.

signal submitted(text: String)
signal cancelled

const MAX_CHARS := 14
const COLUMNS := 8
const PER_PAGE := 24
# Every allowed emoji, flipped through PER_PAGE at a time. Keep these and
# BLOCKED disjoint.
const EMOJI := [
	"🌸", "🐱", "🐶", "🐰", "🦄", "🌈", "⭐", "💖",
	"🎀", "👑", "🍓", "🦋", "🐾", "🐟", "🧁", "🌟",
	"🐹", "🐦", "🍭", "🎈", "🐻", "🦊", "🌙", "🍀",
	"🧸", "🐼", "🐸", "🦁", "🐯", "🐮", "🐷", "🐵",
	"🐙", "🐬", "🐢", "🦉", "🐧", "🐥", "🐞", "🐝",
	"🐲", "🧚", "🧜", "🍕", "🍩", "🍦", "🎂", "🍪",
	"🍉", "🍌", "🍒", "🍑", "🌻", "🌷", "⛄", "🎁",
	"🎵", "🎨", "⚽", "🚀", "🌍", "☀️", "☁️", "❤️",
	"🧡", "💛", "💚", "💙", "💜", "😍", "🥰", "😂",
	"😎", "😺", "🤩", "🥳", "😴", "🤗", "🤪",
	"🤖", "🦖", "🎃", "👀", "🧙",
	"😜", "🙈", "🙉", "🙊",
]

# Kid-safe: the picker only offers friendly emoji, and anything violent typed
# in from a device emoji keyboard is stripped back out.
const BLOCKED := [
	"🤢", "🤡", "👽", "🦷", "👅", "💩",
	"🔫", "🔪", "🗡", "⚔", "🩸", "💣", "🧨", "🪓", "🏹", "⛓", "🔥", "💀", "☠",
	"👻", "🧟", "😈", "👿", "🖕", "🪦", "⚰", "💥", "🩻", "🧛", "🔞", "💉", "🚬",
	"🍆", "💋", "😡", "🤬", "🍺", "🍻", "🍷", "🥃", "🍸", "🍹", "🍾", "💊", "🪚", "🔨", "⛏", "🔱", "🛡",
]

var line: LineEdit
var grid: GridContainer
var page_label: Label
var page := 0

static func open(parent: Node, title: String, initial: String, cancel_text: String = "Skip") -> NameEditor:
	var editor := NameEditor.new()
	editor.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(editor)
	editor._build(title, initial, cancel_text)
	return editor

func _build(title: String, initial: String, cancel_text: String) -> void:
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
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color(0.72, 0.31, 0.47, 1))
	box.add_child(heading)

	line = LineEdit.new()
	line.text = initial
	line.max_length = MAX_CHARS
	line.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.custom_minimum_size = Vector2(440, 64)
	line.add_theme_font_size_override("font_size", 32)
	line.text_changed.connect(_strip_blocked)
	line.text_submitted.connect(func(_t: String) -> void: _finish())
	box.add_child(line)

	grid = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)

	var pager := HBoxContainer.new()
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	pager.add_theme_constant_override("separation", 16)
	box.add_child(pager)
	var prev := Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(72, 48)
	prev.add_theme_font_size_override("font_size", 24)
	prev.pressed.connect(_flip.bind(-1))
	pager.add_child(prev)
	page_label = Label.new()
	page_label.custom_minimum_size = Vector2(90, 0)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.add_theme_font_size_override("font_size", 24)
	page_label.add_theme_color_override("font_color", Color(0.23, 0.16, 0.16, 1))
	pager.add_child(page_label)
	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(72, 48)
	next.add_theme_font_size_override("font_size", 24)
	next.pressed.connect(_flip.bind(1))
	pager.add_child(next)
	_show_page()

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	var back := Button.new()
	back.text = "⌫"
	back.custom_minimum_size = Vector2(72, 56)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(_backspace)
	row.add_child(back)

	var skip := Button.new()
	skip.text = cancel_text
	skip.custom_minimum_size = Vector2(110, 56)
	skip.add_theme_font_size_override("font_size", 24)
	skip.pressed.connect(_cancel)
	row.add_child(skip)

	var done := Button.new()
	done.text = "Done ✅"
	done.custom_minimum_size = Vector2(150, 56)
	done.add_theme_font_size_override("font_size", 26)
	done.pressed.connect(_finish)
	row.add_child(done)

	line.grab_focus()
	line.caret_column = line.text.length()

func _page_count() -> int:
	return ceili(float(EMOJI.size()) / PER_PAGE)

# Wraps around, so a kid can keep tapping the arrow to loop through every page.
func _flip(step: int) -> void:
	page = posmod(page + step, _page_count())
	_show_page()

func _show_page() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var start := page * PER_PAGE
	for i in range(start, mini(start + PER_PAGE, EMOJI.size())):
		var emoji: String = EMOJI[i]
		var button := Button.new()
		button.text = emoji
		button.custom_minimum_size = Vector2(56, 56)
		button.add_theme_font_size_override("font_size", 28)
		button.pressed.connect(_add_emoji.bind(emoji))
		grid.add_child(button)
	page_label.text = "%d / %d" % [page + 1, _page_count()]

func _strip_blocked(text: String) -> void:
	var clean := _clean(text)
	if clean != text:
		line.text = clean
		line.caret_column = clean.length()

static func _clean(text: String) -> String:
	for bad in BLOCKED:
		text = text.replace(bad, "")
	return text

func _add_emoji(emoji: String) -> void:
	if line.text.length() + emoji.length() > MAX_CHARS:
		return
	line.insert_text_at_caret(emoji)

func _backspace() -> void:
	var text := line.text
	if text.is_empty():
		return
	# Emoji like ❤️ carry an invisible variation selector - drop it with the glyph.
	if text.ends_with("\ufe0f"):
		text = text.substr(0, text.length() - 1)
	line.text = text.substr(0, text.length() - 1)
	line.caret_column = line.text.length()

func _finish() -> void:
	submitted.emit(_clean(line.text).strip_edges())
	queue_free()

func _cancel() -> void:
	cancelled.emit()
	queue_free()
