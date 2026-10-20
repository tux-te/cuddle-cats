class_name HowToPlay
extends Control

# Full-screen popup explaining the game in a few short, emoji-led lines.

signal closed

const TIPS := [
	"🐾  Tap 🐾 Pets to pick who you play with",
	"✏️  Tap your pet's name to give them a nickname",
	"🍓  Feed, 🛁 wash and 🛏 put your pet to bed to keep them happy",
	"🎾  Play games to earn 🪙 Treat Coins",
	"👗  Spend coins on bows, hats and fun things in Dress Up",
	"📸  Take photos and collect ⭐ stickers",
	"👤  Tap Switch to let a friend play on their own save",
]

static func open(parent: Node) -> HowToPlay:
	var popup := HowToPlay.new()
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(popup)
	popup._build()
	return popup

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
	heading.text = "How to play 🌈"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", Color(0.72, 0.31, 0.47, 1))
	box.add_child(heading)

	for tip in TIPS:
		var label := Label.new()
		label.text = tip
		label.custom_minimum_size = Vector2(620, 0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color(0.23, 0.16, 0.16, 1))
		box.add_child(label)

	var done := Button.new()
	done.text = "Got it! ✅"
	done.custom_minimum_size = Vector2(180, 60)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.add_theme_font_size_override("font_size", 26)
	done.pressed.connect(_close)
	box.add_child(done)

func _close() -> void:
	closed.emit()
	queue_free()
