extends Control

# The active pet runs a little obstacle course: walk, hurdle, walk, hurdle,
# walk, hurdle, then celebrate at the finish flag. She stops in front of each
# hurdle and waits for the player to tap to help her jump it (no timing, no
# way to fail - she just waits as long as it takes). Reuses her existing walk
# and jump sprite sheets - no new art needed.

const Feedback = preload("res://scripts/room_feedback.gd")

const WALK_SEGMENTS := [[60.0, 300.0], [380.0, 580.0], [660.0, 860.0], [940.0, 1120.0]]
const JUMP_SEGMENTS := [[300.0, 380.0], [580.0, 660.0], [860.0, 940.0]]
const BASE_Y := 280.0
const JUMP_HEIGHT := 45.0

@onready var runner: TextureRect = %Runner
@onready var go_button: Button = %GoButton

var walk_frames: Array[Texture2D] = []
var jump_frames: Array[Texture2D] = []
var is_running := false
var waiting_for_jump := false
var jump_prompt: Label = null

signal jump_requested

func _ready() -> void:
	walk_frames = PetalState.anim_frames("walk")
	jump_frames = PetalState.anim_frames("jump")
	runner.texture = load(PetalState.cutout_path())
	PetalState.apply_tint(runner)
	go_button.pressed.connect(_on_go)

# Any tap or click while she's waiting at a hurdle makes her jump; the Go
# button doubles as a big "Jump!" button for the same moment.
func _input(event: InputEvent) -> void:
	if not waiting_for_jump:
		return
	var is_click: bool = event is InputEventMouseButton and event.pressed
	var is_touch: bool = event is InputEventScreenTouch and event.pressed
	if is_click or is_touch:
		_request_jump()

func _request_jump() -> void:
	if waiting_for_jump:
		waiting_for_jump = false
		jump_requested.emit()

func _on_go() -> void:
	if is_running:
		_request_jump()
		return
	is_running = true
	go_button.disabled = true

	for i in range(JUMP_SEGMENTS.size()):
		await _run_walk(WALK_SEGMENTS[i][0], WALK_SEGMENTS[i][1])
		if not is_instance_valid(self):
			return
		await _wait_for_jump()
		if not is_instance_valid(self):
			return
		await _run_jump(JUMP_SEGMENTS[i][0], JUMP_SEGMENTS[i][1])
	await _run_walk(WALK_SEGMENTS[3][0], WALK_SEGMENTS[3][1])

	if not is_instance_valid(self):
		return
	PetalState.obstacle_course()
	Feedback.pop(self, "🏆 She did it!", runner.global_position + Vector2(0, -20))
	await _celebrate()

	if not is_instance_valid(self):
		return
	runner.position = Vector2(WALK_SEGMENTS[0][0], BASE_Y)
	go_button.text = "🏁 Go!"
	go_button.disabled = false
	is_running = false

# She stops in front of the hurdle, bouncing in place, until the player taps.
func _wait_for_jump() -> void:
	runner.texture = load(PetalState.cutout_path())
	jump_prompt = Label.new()
	jump_prompt.text = "👆 Tap to jump!"
	jump_prompt.add_theme_font_size_override("font_size", 30)
	jump_prompt.position = runner.position + Vector2(-10.0, -50.0)
	jump_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(jump_prompt)
	go_button.text = "⬆️ Jump!"
	go_button.disabled = false

	var bounce := create_tween().set_loops()
	bounce.tween_property(runner, "position:y", BASE_Y - 12.0, 0.25)
	bounce.tween_property(runner, "position:y", BASE_Y, 0.25)

	waiting_for_jump = true
	await jump_requested

	bounce.kill()
	runner.position.y = BASE_Y
	go_button.disabled = true
	if is_instance_valid(jump_prompt):
		jump_prompt.queue_free()
	jump_prompt = null

func _run_walk(from_x: float, to_x: float) -> void:
	var steps := 10
	runner.position.y = BASE_Y
	for i in range(steps):
		if not walk_frames.is_empty():
			runner.texture = walk_frames[i % walk_frames.size()]
		runner.position.x = lerp(from_x, to_x, float(i + 1) / float(steps))
		await get_tree().create_timer(0.06).timeout
		if not is_instance_valid(self):
			return

func _run_jump(from_x: float, to_x: float) -> void:
	var steps := jump_frames.size() if not jump_frames.is_empty() else 8
	for i in range(steps):
		if not jump_frames.is_empty():
			runner.texture = jump_frames[i]
		var t := float(i + 1) / float(steps)
		runner.position.x = lerp(from_x, to_x, t)
		runner.position.y = BASE_Y - JUMP_HEIGHT * sin(PI * t)
		await get_tree().create_timer(0.09).timeout
		if not is_instance_valid(self):
			return
	runner.position.y = BASE_Y

func _celebrate() -> void:
	if jump_frames.is_empty():
		await get_tree().create_timer(0.5).timeout
	else:
		for i in range(jump_frames.size()):
			runner.texture = jump_frames[i]
			await get_tree().create_timer(0.1).timeout
			if not is_instance_valid(self):
				return
	if is_instance_valid(self):
		runner.texture = load(PetalState.cutout_path())
