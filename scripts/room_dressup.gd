extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")

@onready var background: TextureRect = %Background

var buttons := {}
var is_picking_makeup := false

func _ready() -> void:
	background.texture = load(PetalState.room_bg("dressup", "res://Sprites/backgrounds/dress_up_room.jpg"))
	PetCameo.spawn(%Petal)

	if PetalState.active_pet == "petal":
		_setup_petal_wardrobe()
	else:
		_setup_collar_wardrobe()

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
