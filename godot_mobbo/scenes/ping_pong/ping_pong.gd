extends Control
## Port of Gamescript_pong.cs + computer_paddle.cs, with the player paddle
## driven by weight (ping.cs's playerCOP()) instead of keyboard/mouse.
##
## Deviations from Unity's version, which was 3D Rigidbody physics underneath
## a 2D-looking game (an odd combination with several unresolved quirks --
## e.g. computer_paddle.cs and Gamescript_pong.move_paddle() both tried to
## move the same "player_2" object two different ways): this is a clean 2D
## reimplementation of the same mechanic (weight-controlled bottom paddle,
## ball-chasing AI top paddle, score to 5, bounce off side walls), not a
## bug-for-bug clone.

const HUB_SCENE := "res://scenes/hub/hub.tscn"
const ARENA_SIZE := Vector2(560, 420)
const BALL_SPEED := 220.0
const PADDLE_SPEED := 260.0
const WIN_SCORE := 5
const GAME_DATA_HEADER := "Time,ball_x,ball_y,player_paddle_x,player_paddle_y,comp_paddle_x,comp_paddle_y\n"

var arena: PongArena
var status_label: Label
var player_score_label: Label
var computer_score_label: Label
var result_label: Label
var start_button: Button

var player_score := 0
var computer_score := 0
var ball_pos: Vector2
var ball_vel: Vector2
var player_x: float
var computer_x: float
var game_active := false
var game_data: Array[String] = []
var _elapsed := 0.0

func _ready() -> void:
	if AppData.session == null:
		AppData.start_dummy_session()

	theme = UiTheme.theme
	var bg := ColorRect.new()
	bg.color = UiTheme.COLOR_BACKGROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	root.add_child(UiTheme.make_heading("Ping Pong"))
	root.add_child(UiTheme.make_muted_label("Shift weight left/right to move your paddle (bottom). First to 5 wins."))

	var score_row := HBoxContainer.new()
	score_row.add_theme_constant_override("separation", 24)
	root.add_child(score_row)
	player_score_label = UiTheme.make_subheading("You: 0")
	score_row.add_child(player_score_label)
	computer_score_label = UiTheme.make_subheading("Computer: 0")
	score_row.add_child(computer_score_label)

	arena = PongArena.new()
	arena.custom_minimum_size = ARENA_SIZE
	root.add_child(arena)

	status_label = UiTheme.make_muted_label("")
	root.add_child(status_label)
	result_label = UiTheme.make_subheading("")
	root.add_child(result_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	root.add_child(button_row)
	start_button = UiTheme.make_accent_button("Start Game")
	start_button.pressed.connect(_on_start_pressed)
	button_row.add_child(start_button)
	var back := UiTheme.make_secondary_button("Back to Hub")
	back.pressed.connect(func(): get_tree().change_scene_to_file(HUB_SCENE))
	button_row.add_child(back)

	player_x = ARENA_SIZE.x * 0.5
	computer_x = ARENA_SIZE.x * 0.5
	_reset_ball()
	arena.set_state(player_x, computer_x, ball_pos)

	if not SessionPaths.pingpong_rawdata.is_empty():
		DirAccess.make_dir_recursive_absolute(SessionPaths.pingpong_rawdata)
		DirAccess.make_dir_recursive_absolute(SessionPaths.pingpong_gamedata)
		BoardData.start_trial_log(SessionPaths.pingpong_rawdata.path_join("D%s" % Time.get_datetime_string_from_system().replace(":", "-")), 1)

	set_process(true)

func _exit_tree() -> void:
	if BoardData.is_trial_logging:
		BoardData.stop_trial_log()

func _reset_ball() -> void:
	ball_pos = ARENA_SIZE * 0.5
	var dir := 1.0 if randf() < 0.5 else -1.0
	ball_vel = Vector2(dir * BALL_SPEED * 0.5, (1.0 if randf() < 0.5 else -1.0) * BALL_SPEED)

func _on_start_pressed() -> void:
	player_score = 0
	computer_score = 0
	player_score_label.text = "You: 0"
	computer_score_label.text = "Computer: 0"
	result_label.text = ""
	game_data.clear()
	_reset_ball()
	game_active = true
	start_button.text = "Restart"
	UiTheme.set_status(status_label, "game on.", "success")

func _process(delta: float) -> void:
	var limits := SessionPaths.get_ml_limits()
	var cop = BoardData.combined_cop(SerialLink.left_forces(), SerialLink.right_forces())
	if cop != null and limits.right > limits.left:
		var t: float = (cop.x - limits.left) / (limits.right - limits.left)
		player_x = clamp(t, 0.0, 1.0) * ARENA_SIZE.x

	if not game_active:
		arena.set_state(player_x, computer_x, ball_pos)
		return

	# Computer AI: chase the ball's x only while it's headed toward the top.
	if ball_vel.y < 0.0:
		computer_x = move_toward(computer_x, ball_pos.x, PADDLE_SPEED * delta)
	computer_x = clamp(computer_x, 0.0, ARENA_SIZE.x)

	ball_pos += ball_vel * delta
	if ball_pos.x <= 0.0 or ball_pos.x >= ARENA_SIZE.x:
		ball_pos.x = clamp(ball_pos.x, 0.0, ARENA_SIZE.x)
		ball_vel.x *= -1.0

	var paddle_half := PongArena.PADDLE_SIZE * 0.5
	var player_y := ARENA_SIZE.y - 20.0
	var computer_y := 20.0
	if ball_vel.y > 0.0 and ball_pos.y >= player_y - paddle_half.y and abs(ball_pos.x - player_x) <= paddle_half.x:
		ball_vel.y = -abs(ball_vel.y)
		ball_vel.x += (ball_pos.x - player_x) * 2.0
	elif ball_vel.y < 0.0 and ball_pos.y <= computer_y + paddle_half.y and abs(ball_pos.x - computer_x) <= paddle_half.x:
		ball_vel.y = abs(ball_vel.y)
		ball_vel.x += (ball_pos.x - computer_x) * 2.0

	if ball_pos.y < 0.0:
		player_score += 1
		player_score_label.text = "You: %d" % player_score
		_after_point()
	elif ball_pos.y > ARENA_SIZE.y:
		computer_score += 1
		computer_score_label.text = "Computer: %d" % computer_score
		_after_point()

	_elapsed += delta
	if game_active and fmod(_elapsed, 0.1) < delta:
		game_data.append("%.2f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f" % [
			_elapsed, ball_pos.x, ball_pos.y, player_x, player_y, computer_x, computer_y
		])

	arena.set_state(player_x, computer_x, ball_pos)

func _after_point() -> void:
	if player_score >= WIN_SCORE or computer_score >= WIN_SCORE:
		game_active = false
		result_label.text = "YOU WIN" if player_score >= WIN_SCORE else "COMPUTER WINS"
		UiTheme.set_status(status_label, "game over.", "neutral")
		_save_game_data()
	else:
		_reset_ball()

func _save_game_data() -> void:
	var path := SessionPaths.pingpong_gamedata.path_join("ping_game_data_%s.csv" % Time.get_datetime_string_from_system().replace(":", "-"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(GAME_DATA_HEADER)
	for row in game_data:
		f.store_line(row)
	f.close()
