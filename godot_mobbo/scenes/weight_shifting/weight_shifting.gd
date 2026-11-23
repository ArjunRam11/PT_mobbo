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

## Recording (raw board data + 10 Hz game rows) runs between Start and Stop;
## leaving the screen stops and saves it. Ball position is px from the
## board centre; weights kg.
const GAME_DATA_HEADER := "Time,level,left_w,right_w,tilt_deg,ball_x,ball_y,arena_w,arena_h\n"
var record_button: Button
var recorder := GameRecorder.new()
var trial_count := 0
var _rec_elapsed := 0.0
var _next_row_s := 0.0

func _on_record_pressed() -> void:
	if recorder.active:
		recorder.stop("finished")
		record_button.text = "Start recording"
		Sfx.play("rec_stop")
		return
	trial_count += 1
	_rec_elapsed = 0.0
	_next_row_s = 0.0
	recorder.start("ball_roller", "ball_roller_rawdata", "ball_roller_gamedata", GAME_DATA_HEADER, trial_count)
	record_button.text = "Stop & save"
	Sfx.play("rec_start")

func _exit_tree() -> void:
	recorder.stop("left screen")

func _ready() -> void:
	if AppData.session == null:
		AppData.start_dummy_session()

	var hud := GameHud.build(self, "Weight Shifting",
		"Shift your weight left/right to tilt the plank and roll the marble.", "music_tilt")

	var level_chip := HudChip.create("Level: 0", "marble")
	level_label = level_chip.label
	hud.chips.add_child(level_chip)
	var tilt_chip := HudChip.create("Tilt: 0.0 deg", "", false)  # changes every frame -> no pop
	tilt_label = tilt_chip.label
	tilt_chip.custom_minimum_size.x = 130
	hud.chips.add_child(tilt_chip)

	# Same size as before (min 500x320, full width, no vertical expand): the
	# ball's bounds come from arena.size, so the slot only centres it.
	arena = TiltArena.new()
	arena.custom_minimum_size = Vector2(500, 320)
	hud.arena_slot.add_child(arena)

	record_button = UiTheme.make_accent_button("Start recording")
	record_button.pressed.connect(_on_record_pressed)
	hud.buttons.add_child(record_button)
	var down_btn := UiTheme.make_secondary_button("Level Down")
	down_btn.pressed.connect(_decrement_level)
	hud.buttons.add_child(down_btn)
	var up_btn := UiTheme.make_primary_button("Level Up")
	up_btn.pressed.connect(_increment_level)
	hud.buttons.add_child(up_btn)

	var back := UiTheme.make_secondary_button("Back to Hub")
	back.pressed.connect(func(): get_tree().change_scene_to_file(HUB_SCENE))
	hud.buttons.add_child(back)

	set_process(true)

func _increment_level() -> void:
	level = min(level + 1, MAX_LEVEL)
	level_label.text = "Level: %d" % level
	Sfx.play("level_up")

func _decrement_level() -> void:
	level = max(level - 1, 0)
	level_label.text = "Level: %d" % level
	Sfx.play("level_down")

func _process(delta: float) -> void:
	var lf := SerialLink.left_forces()
	var rf := SerialLink.right_forces()
	var left_w := BoardData.total_weight(lf)
	var right_w := BoardData.total_weight(rf)
	if BoardData.is_top_bottom():
		# No left/right board in this layout: use the left-side sensors
		# (1 front-left, 4 back-left) vs right-side sensors (2, 3) of both.
		left_w = lf[0] + lf[3] + rf[0] + rf[3]
		right_w = lf[1] + lf[2] + rf[1] + rf[2]
	var diff: float = clamp(right_w - left_w, -100.0, 100.0)
	var target_tilt_deg: float = (diff / 100.0) * MAX_TILT_DEG
	# Frame-rate independent smoothing (the old lerp weight delta*6 overshot
	# on a slow frame, delta > 1/6 s, and tilted faster on fast PCs).
	current_tilt_deg = lerp(current_tilt_deg, target_tilt_deg, 1.0 - exp(-TILT_LERP_SPEED * delta))
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

	arena.recording = recorder.active
	arena.set_state(tilt_rad, ball_pos)

	if recorder.active:
		_rec_elapsed += delta
		if _rec_elapsed >= _next_row_s:
			_next_row_s += 0.1
			recorder.row("%.2f,%d,%.3f,%.3f,%.2f,%.1f,%.1f,%.0f,%.0f" % [
				_rec_elapsed, level, left_w, right_w, current_tilt_deg, ball_pos.x, ball_pos.y,
				arena.size.x, arena.size.y
			])
