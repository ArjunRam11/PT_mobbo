extends Control
## Port of BoardTiltController.cs: the board tilts by the left/right weight
## difference, and a ball rolls under gravity-along-the-slope. Unity's
## version read weightLeft/weightRight from MoBBoServer.W_player1/2 (the
## grid-column split of a variable NxM board); here that's simply this
## rig's two boards directly. Level up/down scales ball responsiveness and
## drag, same role as Unity's ballSpeed/paddle-width level knobs (paddle
## width had no meaning here -- there's no paddle in this game -- so only
## the speed/drag half of that was ported).

const HUB_SCENE := "res://scenes/hub/hub.tscn"
const MAX_TILT_DEG := 25.0  # Unity used 60; scaled down so the drawn board stays legible
const TILT_LERP_SPEED := 6.0
const GRAVITY_BASE := 260.0
const DRAG := 1.6
const MAX_LEVEL := 10

var arena: TiltArena
var level_label: Label
var tilt_label: Label

var current_tilt_deg: float = 0.0
var ball_pos: Vector2 = Vector2.ZERO
var ball_vel: Vector2 = Vector2.ZERO
var level: int = 0

func _ready() -> void:
	if AppData.session == null:
		AppData.start_dummy_session()
	if not SessionPaths.ball_roller_rawdata.is_empty():
		DirAccess.make_dir_recursive_absolute(SessionPaths.ball_roller_rawdata)
		DirAccess.make_dir_recursive_absolute(SessionPaths.ball_roller_gamedata)

	theme = UiTheme.theme
	var bg := UiTheme.make_background()
	bg.color = UiTheme.COLOR_BACKGROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 28)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	root.add_child(UiTheme.make_heading("Weight Shifting"))
	root.add_child(UiTheme.make_muted_label("Shift your weight left/right to roll the ball; keep it on the board."))

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 24)
	root.add_child(info_row)
	level_label = UiTheme.make_field_label("Level: 0")
	info_row.add_child(level_label)
	tilt_label = UiTheme.make_field_label("Tilt: 0.0 deg")
	info_row.add_child(tilt_label)

	arena = TiltArena.new()
	arena.custom_minimum_size = Vector2(500, 320)
	root.add_child(arena)

	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 12)
	root.add_child(level_row)
	var down_btn := UiTheme.make_secondary_button("Level Down")
	down_btn.pressed.connect(_decrement_level)
	level_row.add_child(down_btn)
	var up_btn := UiTheme.make_primary_button("Level Up")
	up_btn.pressed.connect(_increment_level)
	level_row.add_child(up_btn)

	var back := UiTheme.make_secondary_button("Back to Hub")
	back.pressed.connect(func(): get_tree().change_scene_to_file(HUB_SCENE))
	level_row.add_child(back)

	set_process(true)

func _increment_level() -> void:
	level = min(level + 1, MAX_LEVEL)
	level_label.text = "Level: %d" % level

func _decrement_level() -> void:
	level = max(level - 1, 0)
	level_label.text = "Level: %d" % level

func _process(delta: float) -> void:
	var left_w := BoardData.total_weight(SerialLink.left_forces())
	var right_w := BoardData.total_weight(SerialLink.right_forces())
	var diff: float = clamp(right_w - left_w, -100.0, 100.0)
	var target_tilt_deg: float = (diff / 100.0) * MAX_TILT_DEG
	current_tilt_deg = lerp(current_tilt_deg, target_tilt_deg, delta * TILT_LERP_SPEED)
	tilt_label.text = "Tilt: %.1f deg" % current_tilt_deg

	var tilt_rad := deg_to_rad(current_tilt_deg)
	var gravity := GRAVITY_BASE * (1.0 + 0.15 * level)
	var accel := Vector2(sin(tilt_rad), -cos(tilt_rad)) * gravity
	ball_vel += accel * delta
	ball_vel -= ball_vel * DRAG * delta
	ball_pos += ball_vel * delta

	var bound := arena.size * 0.42 - Vector2.ONE * arena.ball_radius
	if abs(ball_pos.x) > bound.x:
		ball_pos.x = clamp(ball_pos.x, -bound.x, bound.x)
		ball_vel.x *= -0.4
	if abs(ball_pos.y) > bound.y:
		ball_pos.y = clamp(ball_pos.y, -bound.y, bound.y)
		ball_vel.y *= -0.4

	arena.set_state(tilt_rad, ball_pos)
