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
## Cap on the ball's sideways speed. Each paddle hit adds "english" from
## where the ball struck the paddle; uncapped, long rallies made the ball
## ever faster sideways until it was unplayable.
const MAX_BALL_VX := BALL_SPEED * 1.5
## Unity's columns first; then scores and the arena size in px (positions
## are px, and the arena size depends on the screen, so divide by it to
## compare sessions recorded on different PCs).
const GAME_DATA_HEADER := "Time,ball_x,ball_y,player_paddle_x,player_paddle_y,comp_paddle_x,comp_paddle_y,player_score,computer_score,arena_w,arena_h\n"

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
var recorder := GameRecorder.new()
var trial_count := 0
var _elapsed := 0.0
var _next_row_s := 0.0

func _ready() -> void:
	if AppData.session == null:
		AppData.start_dummy_session()

	var hud := GameHud.build(self, "Ping Pong",
		"Shift weight left/right to move your paddle (bottom). First to %d wins." % WIN_SCORE, "music_pong")

	var player_chip := HudChip.create("You: 0", "ball")
	player_score_label = player_chip.label
	hud.chips.add_child(player_chip)
	var computer_chip := HudChip.create("Computer: 0")
	computer_score_label = computer_chip.label
	hud.chips.add_child(computer_chip)

	arena = PongArena.new()
	arena.custom_minimum_size = ARENA_SIZE
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL  # fill the screen
	hud.arena_slot.add_child(arena)

	result_label = GameHud.make_status_label(true)
	hud.status.add_child(result_label)
	status_label = GameHud.make_status_label()
	hud.status.add_child(status_label)

	start_button = UiTheme.make_accent_button("Start Game")
	start_button.pressed.connect(_on_start_pressed)
	hud.buttons.add_child(start_button)
	var back := UiTheme.make_secondary_button("Back to Hub")
	back.pressed.connect(func(): get_tree().change_scene_to_file(HUB_SCENE))
	hud.buttons.add_child(back)
	arena.show_banner("Ping Pong", "Press Start Game")

	player_x = _area().x * 0.5
	computer_x = _area().x * 0.5
	_reset_ball()
	arena.set_state(player_x, computer_x, ball_pos)

	set_process(true)

func _exit_tree() -> void:
	recorder.stop("left early" if game_active else "finished")

func _reset_ball() -> void:
	ball_pos = _area() * 0.5
	var dir := 1.0 if randf() < 0.5 else -1.0
	ball_vel = Vector2(dir * BALL_SPEED * 0.5, (1.0 if randf() < 0.5 else -1.0) * BALL_SPEED)

func _on_start_pressed() -> void:
	player_score = 0
	computer_score = 0
	player_score_label.text = "You: 0"
	computer_score_label.text = "Computer: 0"
	result_label.text = ""
	_reset_ball()
	trial_count += 1
	recorder.start("pingpong", "pingpong_rawdata", "pingpong_gamedata", GAME_DATA_HEADER, trial_count)
	_elapsed = 0.0
	_next_row_s = 0.0
	game_active = true
	start_button.text = "Restart"
	UiTheme.set_status(status_label, "game on.", "success")
	arena.hide_banner()
	Sfx.play("start")

func _process(delta: float) -> void:
	var limits := SessionPaths.get_ml_limits()
	var cop = BoardData.combined_cop(SerialLink.left_forces(), SerialLink.right_forces())
	if cop != null and limits.right > limits.left:
		var t: float = (cop.x - limits.left) / (limits.right - limits.left)
		player_x = clamp(t, 0.0, 1.0) * _area().x

	arena.recording = game_active
	if not game_active:
		arena.set_state(player_x, computer_x, ball_pos)
		return

	# Computer AI: chase the ball's x only while it's headed toward the top.
	if ball_vel.y < 0.0:
		computer_x = move_toward(computer_x, ball_pos.x, PADDLE_SPEED * delta)
	computer_x = clamp(computer_x, 0.0, _area().x)

	ball_pos += ball_vel * delta
	# Side walls bounce at the ball's edge, not its centre (it used to sink
	# half into the wall). Only flip when moving into the wall, so a ball
	# clamped to the edge can't flip back and forth.
	var br := PongArena.BALL_RADIUS
	if (ball_pos.x <= br and ball_vel.x < 0.0) or (ball_pos.x >= _area().x - br and ball_vel.x > 0.0):
		ball_pos.x = clamp(ball_pos.x, br, _area().x - br)
		ball_vel.x *= -1.0
		arena.fx_wall(ball_pos)

	# Paddle hits use the ball's radius, and only count while the ball is
	# still at the paddle's face: a ball that has already gone past a
	# paddle can no longer be "hit" back from behind it by sliding the
	# paddle underneath (it used to be).
	var paddle_half := PongArena.PADDLE_SIZE * 0.5
	var player_y := _area().y - 20.0
	var computer_y := 20.0
	if ball_vel.y > 0.0 and ball_pos.y + br >= player_y - paddle_half.y and ball_pos.y <= player_y + paddle_half.y 			and abs(ball_pos.x - player_x) <= paddle_half.x + br:
		ball_vel.y = -abs(ball_vel.y)
		ball_vel.x = clamp(ball_vel.x + (ball_pos.x - player_x) * 2.0, -MAX_BALL_VX, MAX_BALL_VX)
		ball_pos.y = player_y - paddle_half.y - br  # out of the paddle
		arena.fx_paddle(ball_pos, true)
	elif ball_vel.y < 0.0 and ball_pos.y - br <= computer_y + paddle_half.y and ball_pos.y >= computer_y - paddle_half.y 			and abs(ball_pos.x - computer_x) <= paddle_half.x + br:
		ball_vel.y = abs(ball_vel.y)
		ball_vel.x = clamp(ball_vel.x + (ball_pos.x - computer_x) * 2.0, -MAX_BALL_VX, MAX_BALL_VX)
		ball_pos.y = computer_y + paddle_half.y + br
		arena.fx_paddle(ball_pos, false)

	if ball_pos.y < 0.0:
		player_score += 1
		player_score_label.text = "You: %d" % player_score
		arena.fx_point(true)
		_after_point()
	elif ball_pos.y > _area().y:
		computer_score += 1
		computer_score_label.text = "Computer: %d" % computer_score
		arena.fx_point(false)
		_after_point()

	# Game-state row every 0.1 s (10 Hz), as Unity did.
	_elapsed += delta
	if game_active and _elapsed >= _next_row_s:
		_next_row_s += 0.1
		recorder.row("%.2f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%d,%d,%.0f,%.0f" % [
			_elapsed, ball_pos.x, ball_pos.y, player_x, player_y, computer_x, computer_y,
			player_score, computer_score, _area().x, _area().y
		])

	arena.set_state(player_x, computer_x, ball_pos)

func _after_point() -> void:
	if player_score >= WIN_SCORE or computer_score >= WIN_SCORE:
		game_active = false
		result_label.text = "YOU WIN" if player_score >= WIN_SCORE else "COMPUTER WINS"
		UiTheme.set_status(status_label, "game over. Data saved.", "neutral")
		recorder.stop("finished %d-%d" % [player_score, computer_score])
		arena.show_banner("You win!" if player_score >= WIN_SCORE else "Computer wins",
			"%d - %d  -  press Restart" % [player_score, computer_score],
			"gold" if player_score >= WIN_SCORE else "")
		Sfx.play("win" if player_score >= WIN_SCORE else "game_over")
	else:
		_reset_ball()

## The arena's real on-screen size (it stretches to fill the window);
## ARENA_SIZE is only its minimum / pre-layout fallback.
func _area() -> Vector2:
	return arena.size if arena != null and arena.size.x > 1.0 else ARENA_SIZE
