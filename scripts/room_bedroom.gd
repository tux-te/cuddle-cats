extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const CrownFx = preload("res://scripts/crown_fx.gd")
const Sfx = preload("res://scripts/sfx.gd")

@onready var background: TextureRect = %Background

var perch_busy := false
var fallen_crown: TextureRect = null
var crown_head := Vector2.ZERO
var crown_id := ""
# Called once a fallen crown is back on (puts the sleeper's picture right again).
var crown_restore := Callable()

func _ready() -> void:
	_refresh_background()
	_place_pet_for_habitat()
	_build_perch_toggles()
	_build_habitat_action_buttons()
	PetCameo.spawn(%Petal)
	%CuddleButton.pressed.connect(_on_cuddle)
	%NapButton.pressed.connect(_on_nap)
	%PhotoBookButton.pressed.connect(_on_photo_book)
	_refresh_friend()

func _refresh_background() -> void:
	if not PetalState.perch_items().is_empty():
		background.texture = load(PetalState.perch_background_path())
	else:
		background.texture = load(PetalState.room_bg("bedroom", "res://Sprites/backgrounds/bedroom.jpg"))

# Small "on/off" buttons for each perch decoration (bed/toy/feeder), built
# dynamically since this scene is shared by every pet and most have none.
func _build_perch_toggles() -> void:
	var items := PetalState.perch_items()
	if items.is_empty():
		return
	var labels := {"bed": "🛏️ Bed", "toy": "🔔 Toy", "feeder": "🏠 Feeder"}
	var row := HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.offset_left = -180.0
	row.offset_right = 180.0
	row.offset_top = 66.0
	row.offset_bottom = 106.0
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	var decor: Dictionary = PetalState.perch_decor()
	for id in items:
		var btn := Button.new()
		btn.text = String(labels.get(id, id))
		btn.toggle_mode = true
		btn.button_pressed = decor.get(id, true)
		btn.custom_minimum_size = Vector2(110, 40)
		btn.pressed.connect(_on_perch_toggle.bind(id))
		row.add_child(btn)

func _on_perch_toggle(id: String) -> void:
	PetalState.toggle_perch_item(id)
	_refresh_background()

# Every other room just sits the pet in a generic corner box, but Kiwi's
# perch art has actual branches to land on, so she (and any visiting friend)
# get moved onto them instead of floating in the usual bottom-left corner.
# Boxes are fractions of the room's canvas, hand-picked against the perch
# artwork: Kiwi on the swing seat, her friend on the lower ladder branch.
const PERCH_PETAL_BOX := Rect2(0.582, 0.279, 0.085, 0.112)
const PERCH_FRIEND_BOX := Rect2(0.364, 0.456, 0.078, 0.063)
const PERCH_FEEDER_BOX := Rect2(0.688, 0.382, 0.157, 0.200)
const PERCH_TOY_BOX := Rect2(0.585, 0.554, 0.095, 0.251)
const PERCH_BED_BOX := Rect2(0.268, 0.247, 0.203, 0.400)

# Pumpkin's burrow has no separate hand-painted feeder/bed/toy spots like
# Kiwi's perch, just one hole in the ground art she pops in and out of for
# every action - may need nudging once someone's actually looked at the art.
const BURROW_PETAL_BOX := Rect2(0.38, 0.50, 0.24, 0.32)

func _has_habitat() -> bool:
	return not PetalState.perch_items().is_empty() or PetalState.active_pet == "gerbil"

func _place_pet_for_habitat() -> void:
	if not PetalState.perch_items().is_empty():
		_apply_perch_box(%Petal, PERCH_PETAL_BOX)
		_apply_perch_box(%Friend, PERCH_FRIEND_BOX)
	elif PetalState.active_pet == "gerbil":
		_apply_perch_box(%Petal, BURROW_PETAL_BOX)

# Feed/Rest/Play buttons instead of the generic Cuddle/Nap this scene
# normally offers - those don't make sense for a bird on a perch or a
# gerbil in a burrow.
func _build_habitat_action_buttons() -> void:
	if not _has_habitat():
		return
	%CuddleButton.visible = false
	%NapButton.visible = false
	var container := %CuddleButton.get_parent()

	var feed_btn := Button.new()
	feed_btn.text = "🍽️ Feed"
	feed_btn.custom_minimum_size = Vector2(160, 90)
	feed_btn.add_theme_font_size_override("font_size", 22)
	feed_btn.pressed.connect(_on_habitat_feed)
	container.add_child(feed_btn)
	container.move_child(feed_btn, %CuddleButton.get_index())

	var rest_btn := Button.new()
	rest_btn.text = "💤 Rest"
	rest_btn.custom_minimum_size = Vector2(160, 90)
	rest_btn.add_theme_font_size_override("font_size", 22)
	rest_btn.pressed.connect(_on_habitat_rest)
	container.add_child(rest_btn)
	container.move_child(rest_btn, feed_btn.get_index() + 1)

	var play_btn := Button.new()
	play_btn.text = "%s Play" % PetalState.toy_emoji()
	play_btn.custom_minimum_size = Vector2(160, 90)
	play_btn.add_theme_font_size_override("font_size", 22)
	play_btn.pressed.connect(_on_habitat_play)
	container.add_child(play_btn)
	container.move_child(play_btn, rest_btn.get_index() + 1)

func _on_habitat_feed() -> void:
	if perch_busy:
		return
	perch_busy = true
	PetalState.feed()
	Feedback.pop(self, "😋 yum!", %Petal.global_position)
	var is_perch := not PetalState.perch_items().is_empty()
	if is_perch:
		_apply_perch_box(%Petal, PERCH_FEEDER_BOX)
	if PetalState.has_anim("eat"):
		var frames := PetalState.anim_frames("eat")
		for frame in frames:
			if not is_instance_valid(%Petal):
				perch_busy = false
				return
			%Petal.texture = frame
			await get_tree().create_timer(0.35).timeout
	else:
		await get_tree().create_timer(1.4).timeout
	if is_instance_valid(%Petal):
		%Petal.texture = load(PetalState.cutout_path())
		if is_perch:
			_apply_perch_box(%Petal, PERCH_PETAL_BOX)
	perch_busy = false

func _on_habitat_rest() -> void:
	if perch_busy:
		return
	perch_busy = true
	PetalState.nap()
	Feedback.pop(self, "💤 zzz", %Petal.global_position)
	var is_perch := not PetalState.perch_items().is_empty()
	if is_perch:
		_apply_perch_box(%Petal, PERCH_BED_BOX)
	await PetCameo.sleep(%Petal)
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(%Petal):
		PetCameo.wake(%Petal)
		if is_perch:
			_apply_perch_box(%Petal, PERCH_PETAL_BOX)
	perch_busy = false

func _on_habitat_play() -> void:
	if perch_busy:
		return
	perch_busy = true
	if not PetalState.perch_items().is_empty():
		PetalState.ring_bell_locally()
		Feedback.pop(self, "🔔 jingle jingle!", %Petal.global_position)
		_apply_perch_box(%Petal, PERCH_TOY_BOX)
		if PetalState.has_anim("toy_bell"):
			var frames := PetalState.anim_frames("toy_bell")
			for frame in frames:
				if not is_instance_valid(%Petal):
					perch_busy = false
					return
				%Petal.texture = frame
				await get_tree().create_timer(0.35).timeout
		else:
			await get_tree().create_timer(1.0).timeout
		if is_instance_valid(%Petal):
			%Petal.texture = load(PetalState.cutout_path())
			_apply_perch_box(%Petal, PERCH_PETAL_BOX)
	elif PetalState.has_anim("dig"):
		PetalState.play()
		Feedback.pop(self, "⛏️ digging!", %Petal.global_position)
		var frames := PetalState.anim_frames("dig")
		for frame in frames:
			if not is_instance_valid(%Petal):
				perch_busy = false
				return
			%Petal.texture = frame
			await get_tree().create_timer(0.2).timeout
		if is_instance_valid(%Petal):
			%Petal.texture = load(PetalState.cutout_path())
	else:
		PetalState.play()
		Feedback.pop(self, "🥎 having fun!", %Petal.global_position)
		await PetCameo.jump_for_joy(%Petal)
	perch_busy = false

func _apply_perch_box(node: TextureRect, box: Rect2) -> void:
	node.anchor_left = box.position.x
	node.anchor_top = box.position.y
	node.anchor_right = box.position.x + box.size.x
	node.anchor_bottom = box.position.y + box.size.y
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0
	node.grow_horizontal = Control.GROW_DIRECTION_BOTH
	node.grow_vertical = Control.GROW_DIRECTION_BOTH

# Whoever's visiting (see room_living.gd) rests here too, alongside the pet -
# just a quiet presence to pet, no walk-in/play minigame like the living room.
func _refresh_friend() -> void:
	var visiting: String = PetalState.visiting_friend
	if visiting == "":
		%Friend.visible = false
		return
	%Friend.texture = load(PetalState.FRIENDS[visiting]["cutout"])
	%Friend.visible = true
	%Friend.mouse_filter = Control.MOUSE_FILTER_STOP
	if not %Friend.gui_input.is_connected(_on_friend_input):
		%Friend.gui_input.connect(_on_friend_input)

func _on_friend_input(event: InputEvent) -> void:
	var is_click: bool = event is InputEventMouseButton and event.pressed
	var is_touch: bool = event is InputEventScreenTouch and event.pressed
	if not (is_click or is_touch):
		return
	PetalState.pet_friend()
	Feedback.pop(self, PetalState.friend_reactions(PetalState.visiting_friend).pick_random(), %Friend.global_position + Vector2(60, 20))
	_bounce_friend()

func _bounce_friend() -> void:
	%Friend.pivot_offset = %Friend.size / 2.0
	var tween := create_tween()
	tween.tween_property(%Friend, "scale", Vector2(1.12, 0.9), 0.08)
	tween.tween_property(%Friend, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_ELASTIC)

func _on_cuddle() -> void:
	PetalState.cuddle()
	PetCameo.cuddle(%Petal)
	Feedback.pop(self, "🥰 +hugs", %CuddleButton.global_position)

func _on_nap() -> void:
	PetalState.nap()
	Feedback.pop(self, "💤 zzz", %NapButton.global_position)
	_friend_nap()
	await PetCameo.sleep(%Petal)
	_drop_crown()

# The id of a crown she is wearing right now ("" if none).
func _worn_crown() -> String:
	for id in PetalState.accessories:
		if String(id).begins_with("crown_") and PetalState.accessories[id]:
			return String(id)
	return ""

# While she sleeps a worn crown slips off her head and tumbles to the floor;
# tapping it puts it back on.
func _drop_crown() -> void:
	if is_instance_valid(fallen_crown):
		return
	var id := _worn_crown()
	var worn := %Petal.get_node_or_null("Accessory_%s" % id) as TextureRect
	if id == "" or worn == null or not worn.visible:
		return
	crown_head = worn.global_position + worn.size / 2.0
	var crown := TextureRect.new()
	crown.texture = worn.texture
	crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crown.size = worn.size
	crown.pivot_offset = worn.size / 2.0
	crown.mouse_filter = Control.MOUSE_FILTER_STOP
	crown.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(crown)
	crown.global_position = worn.global_position
	worn.visible = false
	fallen_crown = crown
	crown_id = id
	crown_restore = func() -> void:
		var back_on := %Petal.get_node_or_null("Accessory_%s" % id) as TextureRect
		if back_on:
			back_on.visible = PetalState.accessories.get(id, false)
	var floor_spot: Vector2 = %Petal.global_position + Vector2(%Petal.size.x * 0.82, %Petal.size.y * 0.8) - worn.size / 2.0
	var fall := crown.create_tween()
	fall.set_parallel(true)
	fall.tween_property(crown, "global_position:x", floor_spot.x, 0.7)
	fall.tween_property(crown, "rotation_degrees", 70.0, 0.7)
	fall.tween_property(crown, "global_position:y", floor_spot.y, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await fall.finished
	if not is_instance_valid(crown):
		return
	Feedback.pop(self, "😮 Oh no! Her crown fell off! Tap it to put it back on 👑", floor_spot + Vector2(-120, -60))
	var wiggle := crown.create_tween().set_loops()
	wiggle.tween_property(crown, "scale", Vector2(1.15, 1.15), 0.5).set_trans(Tween.TRANS_SINE)
	wiggle.tween_property(crown, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	crown.gui_input.connect(_on_fallen_crown_input)

func _on_fallen_crown_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not tapped or not is_instance_valid(fallen_crown):
		return
	var crown := fallen_crown
	fallen_crown = null
	crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := crown.create_tween().set_parallel(true)
	back.tween_property(crown, "global_position", crown_head - crown.size / 2.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	back.tween_property(crown, "rotation_degrees", 0.0, 0.45)
	back.tween_property(crown, "scale", Vector2.ONE, 0.2)
	await back.finished
	if not is_instance_valid(self):
		return
	crown.queue_free()
	if crown_restore.is_valid():
		crown_restore.call()
	Sfx.chime(self)
	CrownFx.play(self, crown_head, crown_id)
	Feedback.pop(self, "👑 Back on! Sweet dreams 💤", crown_head + Vector2(-60, -50))

func _on_photo_book() -> void:
	PetalState.navigate_to_room.emit("photobook")

# A visiting friend with a painted-on crown (see FRIENDS "nap_crown") curls up
# when you nap, and her crown slips off just like the pet's.
func _friend_nap() -> void:
	var id: String = PetalState.visiting_friend
	if id == "" or is_instance_valid(fallen_crown) or not PetalState.FRIENDS[id].has("nap_crown"):
		return
	var info: Dictionary = PetalState.FRIENDS[id]["nap_crown"]
	var friend: TextureRect = %Friend
	var crown_tex: Texture2D = load(String(info["crown"]))
	var body_tex: Texture2D = load(String(info["body"]))
	# Where the crown sits on the screen (the picture is centred and kept in proportion).
	var shown := body_tex.get_size() * minf(friend.size.x / body_tex.get_size().x, friend.size.y / body_tex.get_size().y)
	var origin := friend.global_position + (friend.size - shown) / 2.0
	var box: Rect2 = info["box"]
	var rect := Rect2(origin + box.position * shown, box.size * shown)

	friend.texture = body_tex
	friend.pivot_offset = friend.size / 2.0
	var curl := friend.create_tween().set_parallel(true)
	curl.tween_property(friend, "rotation_degrees", -9.0, 0.6).set_trans(Tween.TRANS_SINE)
	curl.tween_property(friend, "scale", Vector2(1.04, 0.9), 0.6).set_trans(Tween.TRANS_SINE)
	Feedback.pop(self, "💤 zzz", friend.global_position + Vector2(40, -10))

	var crown := TextureRect.new()
	crown.texture = crown_tex
	crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crown.size = rect.size
	crown.pivot_offset = rect.size / 2.0
	crown.mouse_filter = Control.MOUSE_FILTER_STOP
	crown.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(crown)
	crown.global_position = rect.position
	fallen_crown = crown
	crown_id = String(info["effect"])
	crown_head = rect.get_center()
	crown_restore = func() -> void:
		if is_instance_valid(friend):
			friend.texture = load(PetalState.FRIENDS[id]["cutout"])
			var up := friend.create_tween().set_parallel(true)
			up.tween_property(friend, "rotation_degrees", 0.0, 0.3)
			up.tween_property(friend, "scale", Vector2.ONE, 0.3)

	await get_tree().create_timer(0.9).timeout
	if not is_instance_valid(crown):
		return
	var floor_spot := Vector2(friend.global_position.x - rect.size.x * 0.9, friend.global_position.y + friend.size.y - rect.size.y * 1.1)
	var fall := crown.create_tween().set_parallel(true)
	fall.tween_property(crown, "global_position:x", floor_spot.x, 0.7)
	fall.tween_property(crown, "rotation_degrees", -60.0, 0.7)
	fall.tween_property(crown, "global_position:y", floor_spot.y, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await fall.finished
	if not is_instance_valid(crown):
		return
	Feedback.pop(self, "😮 Oh no! %s's crown fell off! Tap it to put it back on 👑" % PetalState.FRIENDS[id]["name"], floor_spot + Vector2(-120, -60))
	var wiggle := crown.create_tween().set_loops()
	wiggle.tween_property(crown, "scale", Vector2(1.15, 1.15), 0.5).set_trans(Tween.TRANS_SINE)
	wiggle.tween_property(crown, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	crown.gui_input.connect(_on_fallen_crown_input)
