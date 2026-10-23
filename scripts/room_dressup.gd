extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const CrownFx = preload("res://scripts/crown_fx.gd")

const Confetti = preload("res://scripts/confetti.gd")

# Fashion show: she struts across the stage while the judges clap.
const STAGE_LEFT_X := 24.0
const STAGE_RIGHT_X := 1000.0
const JUDGE_LINES := ["Gorgeous!", "So stylish!", "I love it!", "Wow, fabulous!", "Look at that!"]
const SPARKLES := ["✨", "⭐", "💖", "🌟"]

@onready var background: TextureRect = %Background

var buttons := {}
var is_picking_makeup := false
var show_running := false
var surprise_button: Button
var show_button: Button

func _ready() -> void:
	background.texture = load(PetalState.room_bg("dressup", "res://Sprites/backgrounds/dress_up_room.jpg"))
	PetCameo.spawn(%Petal)

	if PetalState.active_pet == "petal":
		_setup_petal_wardrobe()
	else:
		_setup_collar_wardrobe()
	_build_fun_buttons()

func _build_fun_buttons() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -240.0
	box.offset_right = -20.0
	box.offset_top = 20.0
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	surprise_button = _fun_button("🎲 Surprise outfit", Color(1.0, 0.55, 0.78))
	surprise_button.pressed.connect(_on_surprise_outfit)
	box.add_child(surprise_button)
	show_button = _fun_button("💃 Fashion show", Color(0.7, 0.5, 1.0))
	show_button.pressed.connect(_on_fashion_show)
	box.add_child(show_button)

func _fun_button(text: String, colour: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 60)
	b.add_theme_font_size_override("font_size", 20)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = colour.lightened(0.15) if state == "hover" else colour
		box.set_corner_radius_all(16)
		box.set_content_margin_all(8)
		b.add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(state, Color.WHITE)
	return b

# Sparkles burst around her whenever something goes on.
func _sparkle() -> void:
	var petal: Control = %Petal
	var centre := petal.global_position + petal.size / 2.0
	for _i in range(8):
		var l := Label.new()
		l.text = SPARKLES[randi() % SPARKLES.size()]
		l.add_theme_font_size_override("font_size", randi_range(26, 44))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.position = centre + Vector2(randf_range(-70, 70), randf_range(-90, 40))
		l.z_index = 12
		add_child(l)
		var t := create_tween().set_parallel(true)
		t.tween_property(l, "position:y", l.position.y - randf_range(40, 100), 0.9)
		t.tween_property(l, "modulate:a", 0.0, 0.9)
		t.chain().tween_callback(l.queue_free)

func _refresh_pressed() -> void:
	for id in buttons:
		if buttons[id] is Button and PetalState.accessories.has(id):
			buttons[id].set_pressed_no_signal(PetalState.accessories[id])

# Everything comes off, then a random handful of the unlocked things go on.
func _on_surprise_outfit() -> void:
	if show_running:
		return
	var ids: Array = []
	for id in PetalState.accessories:
		if PetalState.is_accessory_unlocked(id):
			ids.append(id)
	if ids.is_empty():
		return
	for id in ids:
		PetalState.accessories[id] = false
	ids.shuffle()
	var how_many := randi_range(1, mini(3, ids.size()))
	for i in range(how_many):
		PetalState.toggle_accessory(ids[i])
	PetalState.accessories_changed.emit()
	_refresh_pressed()
	_sparkle()
	Feedback.pop(self, "🎲 ta-da!", surprise_button.global_position)
	PetCameo.jump_for_joy(%Petal)

func _worn_count() -> int:
	var n := 0
	for id in PetalState.accessories:
		if PetalState.accessories[id]:
			n += 1
	return n

func _on_fashion_show() -> void:
	if show_running:
		return
	var worn := _worn_count()
	if worn == 0:
		Feedback.pop(self, "👗 put something on first!", show_button.global_position)
		return
	show_running = true
	show_button.disabled = true
	surprise_button.disabled = true

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.15, 0.05, 0.25, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	move_child(dim, %Petal.get_index())
	var crowd := Label.new()
	crowd.text = "👏  🎤  👏  📸  👏"
	crowd.add_theme_font_size_override("font_size", 44)
	crowd.set_anchors_preset(Control.PRESET_CENTER_TOP)
	crowd.offset_left = -300.0
	crowd.offset_right = 300.0
	crowd.offset_top = 80.0
	crowd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crowd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crowd)

	var petal: TextureRect = %Petal
	var start_x := petal.position.x
	await _strut(petal, STAGE_RIGHT_X)
	if not is_instance_valid(self):
		return
	# Pose at the end of the runway.
	_sparkle()
	PetCameo.jump_for_joy(petal)
	Confetti.burst(self, petal.global_position + petal.size / 2.0, 24)
	var stars := mini(5, 3 + worn)
	Feedback.pop(self, "%s  %s" % ["⭐".repeat(stars), JUDGE_LINES[randi() % JUDGE_LINES.size()]], petal.global_position + Vector2(0, -60))
	await get_tree().create_timer(1.3).timeout
	if not is_instance_valid(self):
		return
	await _strut(petal, start_x)
	if not is_instance_valid(self):
		return

	dim.queue_free()
	crowd.queue_free()
	PetalState.fashion_show(worn)
	Feedback.pop(self, "🏆 %d stars! +%d 🪙" % [stars, mini(worn, 3) + 2], show_button.global_position)
	show_button.disabled = false
	surprise_button.disabled = false
	show_running = false

func _strut(petal: TextureRect, to_x: float) -> void:
	var from_x := petal.position.x
	var frames := PetalState.anim_frames("walk")
	var steps := 24
	petal.scale.x = -1.0 if to_x < from_x else 1.0
	for i in range(steps):
		if not frames.is_empty():
			petal.texture = frames[i % frames.size()]
		petal.position.x = lerpf(from_x, to_x, float(i + 1) / float(steps))
		await get_tree().create_timer(0.05).timeout
		if not is_instance_valid(self):
			return
	petal.scale.x = 1.0
	petal.texture = load(PetalState.cutout_path())

func _setup_petal_wardrobe() -> void:
	%Buttons.visible = true
	%CollarButtons.visible = false

	buttons = {
		"bow": %BowButton,
		"flower": %FlowerButton,
		"sunglasses": %SunglassesButton,
		"scarf": %ScarfButton,
	}
	for id in buttons:
		var btn: Button = buttons[id]
		btn.icon = load("res://Sprites/%s.png" % id)
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", 48)
		btn.set_pressed_no_signal(PetalState.accessories[id])
		btn.pressed.connect(_on_toggle.bind(id))

	buttons["blush"] = %BlushBrushButton
	buttons["mascara"] = %MascaraBrushButton
	buttons["lipstick"] = %LipstickBrushButton
	_refresh_lock_visuals()

	%MakeupButton.pressed.connect(_on_makeup_pressed)
	%BlushBrushButton.pressed.connect(_on_brush_chosen.bind("blush"))
	%MascaraBrushButton.pressed.connect(_on_brush_chosen.bind("mascara"))
	%LipstickBrushButton.pressed.connect(_on_brush_chosen.bind("lipstick"))
	%RemoverButton.pressed.connect(_on_remover_chosen)

func _setup_collar_wardrobe() -> void:
	%Buttons.visible = false
	%CollarButtons.visible = true

	var pet_accessories: Dictionary = PetalState.PETS[PetalState.active_pet]["accessories"]
	for id in pet_accessories:
		var btn := TextureButton.new()
		btn.texture_normal = load(String(pet_accessories[id]["icon"]))
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(150, 90)
		btn.pressed.connect(_on_toggle.bind(id))
		%CollarButtons.add_child(btn)
		buttons[id] = btn
	_refresh_lock_visuals()

func _on_toggle(id: String) -> void:
	if not PetalState.is_accessory_unlocked(id):
		if buttons[id] is Button:
			buttons[id].set_pressed_no_signal(false)
		_try_purchase(id)
		return
	PetalState.toggle_accessory(id)
	if buttons[id] is Button:
		buttons[id].set_pressed_no_signal(PetalState.accessories[id])
	var text := "✨ pretty!" if PetalState.accessories[id] else "took it off"
	Feedback.pop(self, text, buttons[id].global_position)
	if PetalState.accessories[id]:
		_sparkle()
	_crown_reaction(id)

# Spends Treat Coins to unlock a locked accessory, then equips it right
# away so buying feels rewarding instead of taking a second click.
func _try_purchase(id: String) -> void:
	var still_short := PetalState.accessory_cost(id) - PetalState.coins
	if not PetalState.try_unlock_accessory(id):
		Feedback.pop(self, "🔒 need %d more coins" % still_short, buttons[id].global_position)
		return
	_refresh_lock_visuals()
	PetalState.toggle_accessory(id)
	if buttons[id] is Button:
		buttons[id].set_pressed_no_signal(PetalState.accessories[id])
	Feedback.pop(self, "🔓 unlocked! ✨", buttons[id].global_position)
	_crown_reaction(id)

# Crowns get their own little celebration over her head when put on.
func _crown_reaction(id: String) -> void:
	if id.begins_with("crown_") and PetalState.accessories.get(id, false):
		var petal: Control = %Petal
		CrownFx.play(self, petal.global_position + Vector2(petal.size.x * 0.48, petal.size.y * 0.14), id)

# Darkens locked buttons and labels them with their coin price so kids can
# see at a glance what's still to earn.
func _refresh_lock_visuals() -> void:
	for id in buttons:
		var btn: BaseButton = buttons[id]
		var unlocked := PetalState.is_accessory_unlocked(id)
		btn.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.55, 0.55, 0.55, 1)
		btn.tooltip_text = "" if unlocked else "🔒 %d coins to unlock" % PetalState.accessory_cost(id)

func _on_makeup_pressed() -> void:
	is_picking_makeup = not is_picking_makeup
	%BrushPicker.visible = is_picking_makeup

func _on_brush_chosen(id: String) -> void:
	if not PetalState.is_accessory_unlocked(id):
		var still_short := PetalState.accessory_cost(id) - PetalState.coins
		if not PetalState.try_unlock_accessory(id):
			Feedback.pop(self, "🔒 need %d more coins" % still_short, %MakeupButton.global_position)
			%BrushPicker.visible = false
			is_picking_makeup = false
			return
		_refresh_lock_visuals()
	PetalState.toggle_accessory(id)
	var text := "💄 so pretty!" if PetalState.accessories[id] else "wiped it off"
	Feedback.pop(self, text, %MakeupButton.global_position)
	%BrushPicker.visible = false
	is_picking_makeup = false

func _on_remover_chosen() -> void:
	PetalState.remove_all_makeup()
	Feedback.pop(self, "🧴 clean face!", %MakeupButton.global_position)
	%BrushPicker.visible = false
	is_picking_makeup = false
