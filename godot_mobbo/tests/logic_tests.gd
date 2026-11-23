extends Node
## Regression tests for the game-logic fixes (no boards needed, headless OK):
##   run tests/run_logic_tests.bat   (or)
##   Godot_v4.6.2-stable_win64_console.exe --headless --path . res://tests/logic_tests.tscn
## Each game scene is instantiated with _process disabled and stepped by
## hand with fixed deltas and hand-placed positions. No board data -> COP is
## null, so player-controlled positions only change when the test sets them.
## Exit code = number of failed checks. Recordings go to MOBBO_DATA_DIR
## (the .bat points it at tests/test_data).

const DT := 1.0 / 60.0
var _fails := 0
var _checks := 0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  PASS  ", what)
	else:
		_fails += 1
		print("  FAIL  ", what)

func _spawn(path: String) -> Node:
	var s: Node = load(path).instantiate()
	add_child(s)
	s.set_process(false)
	return s

func _run() -> void:
	await get_tree().process_frame
	await _coin_tests()
	await _floppy_tests()
	await _pong_tests()
	await _tilt_tests()
	print("LOGIC_TESTS_DONE %d/%d passed" % [_checks - _fails, _checks])
	get_tree().quit(_fails)

func _coin_tests() -> void:
	print("Coin Collector")
	var s := _spawn("res://scenes/coin_collector/coin_collector.tscn")
	await get_tree().process_frame
	s._on_start_pressed()
	s._spawn_timer = -1000.0  # no random spawns during the test
	var area: Vector2 = s._area()
	var rim: float = area.y - CoinArena.COLLECTOR_BOTTOM - CoinArena.COLLECTOR_SIZE.y * 0.5
	var r := CoinArena.ITEM_RADIUS

	# 1. Coin falling onto the basket is caught.
	s.collector_x = area.x * 0.5
	s.items.append({"pos": Vector2(s.collector_x, rim - r - 20.0), "is_bomb": false})
	for i in 30:
		s._process(DT)
	check(s.score == 1, "coin falling into basket is caught (score %d)" % s.score)

	# 2. Coin already below the rim, beside the basket; basket slides under it -> not caught.
	s.collector_x = area.x * 0.2
	s.items.append({"pos": Vector2(area.x * 0.5, rim - r + 4.0), "is_bomb": false})
	s._process(DT)
	s.collector_x = area.x * 0.5  # slide under the falling coin
	for i in 60:  # long enough to fall from the rim off the bottom
		s._process(DT)
	check(s.score == 1, "coin that already fell past the rim can't be scooped up (score %d)" % s.score)
	check(s.items.is_empty(), "missed coin leaves the screen")

	# 3. Bomb into the basket ends the game.
	s.items.append({"pos": Vector2(s.collector_x, rim - r - 10.0), "is_bomb": true})
	for i in 20:
		s._process(DT)
	check(not s.game_active, "catching a bomb ends the game")
	s.queue_free()
	await get_tree().process_frame

func _floppy_tests() -> void:
	print("Floppy Bird")
	var s := _spawn("res://scenes/floppy_bird/floppy_bird.tscn")
	await get_tree().process_frame

	# 1. Levels are symmetric.
	for i in 10:
		s._increment_level()
	var top_rate: float = s.spawn_rate
	var top_speed: float = s.pipe_speed
	for i in 10:
		s._decrement_level()
	check(is_equal_approx(s.spawn_rate, 5.0) and is_equal_approx(s.pipe_speed, 80.0),
		"level 10 -> 0 returns to 5 s / 80 px/s (got %.2f / %.1f; top %.2f / %.1f)" % [s.spawn_rate, s.pipe_speed, top_rate, top_speed])
	for i in 3:
		s._increment_level()
	var up3 := Vector2(s.spawn_rate, s.pipe_speed)
	s._increment_level()
	s._decrement_level()
	check(up3.is_equal_approx(Vector2(s.spawn_rate, s.pipe_speed)), "up then down returns to the same level settings")
	for i in 3:
		s._decrement_level()

	s._on_start_pressed()
	s._process(DT)  # computes bird_y
	var bird_x: float = s._area().x * 0.25
	var by: float = s.bird_y
	var r := FlappyArena.BIRD_RADIUS
	s._spawn_timer = -1000.0

	# 2. Bird's edge clips the pillar (centre inside the gap) -> loses a life, once.
	s.pipes.clear()
	s.pipes.append({"x": bird_x + 40.0, "gap_center_y": by + (80.0 - r * 0.5), "gap_half": 80.0, "scored": false, "hit": false})
	var lives_before: int = s.lives
	for i in 90:
		s._process(DT)
	check(s.lives == lives_before - 1, "bird body clipping a pillar costs exactly one life (%d -> %d)" % [lives_before, s.lives])
	check(s.score == 0, "a clipped pillar does not score")

	# 3. Clean pass through the middle of the gap scores.
	s.pipes.clear()
	s.pipes.append({"x": bird_x + 40.0, "gap_center_y": by, "gap_half": 80.0, "scored": false, "hit": false})
	for i in 90:
		s._process(DT)
	check(s.score == 1, "clean pass through the gap scores (score %d)" % s.score)

	# 4. Running out of lives ends the trial once.
	s.lives = 1
	s.pipes.clear()
	s.pipes.append({"x": bird_x + 20.0, "gap_center_y": by + 200.0 if by < 200.0 else by - 200.0, "gap_half": 80.0, "scored": false, "hit": false})
	for i in 60:
		s._process(DT)
	check(not s.trial_active and s.lives == 0, "last life lost ends the trial")
	s.queue_free()
	await get_tree().process_frame

func _pong_tests() -> void:
	print("Ping Pong")
	var s := _spawn("res://scenes/ping_pong/ping_pong.tscn")
	await get_tree().process_frame
	s._on_start_pressed()
	var area: Vector2 = s._area()
	var half := PongArena.PADDLE_SIZE * 0.5
	var player_y: float = area.y - 20.0
	var br := PongArena.BALL_RADIUS

	# 1. Repeated off-centre hits can't push sideways speed past the cap.
	var max_vx := 0.0
	for k in 20:
		s.player_x = area.x * 0.5
		s.ball_pos = Vector2(s.player_x + half.x * 0.9, player_y - half.y - br - 2.0)
		s.ball_vel = Vector2(s.ball_vel.x, 220.0)
		s._process(DT)
		max_vx = maxf(max_vx, absf(s.ball_vel.x))
	check(max_vx <= s.MAX_BALL_VX + 0.01, "sideways speed capped at %.0f (max seen %.0f)" % [s.MAX_BALL_VX, max_vx])

	# 2. Ball already past the paddle can't be hit back from behind.
	# Centre just past the paddle's face (still inside the court, so no point is scored).
	s.ball_pos = Vector2(area.x * 0.5, player_y + half.y + 1.0)
	s.ball_vel = Vector2(0.0, 220.0)
	s.player_x = area.x * 0.5
	s._process(DT)
	check(s.ball_vel.y > 0.0, "ball behind the paddle keeps going (vy %.0f)" % s.ball_vel.y)

	# 3. Ball edge hitting the paddle corner bounces (radius counts).
	s.ball_pos = Vector2(s.player_x + half.x + br * 0.8, player_y - half.y - br + 1.0)
	s.ball_vel = Vector2(0.0, 220.0)
	s._process(DT)
	check(s.ball_vel.y < 0.0, "ball edge on the paddle corner bounces")

	# 4. Side walls bounce at the ball's edge.
	s.ball_pos = Vector2(br + 1.0, area.y * 0.5)
	s.ball_vel = Vector2(-200.0, 50.0)
	s._process(DT)
	check(s.ball_vel.x > 0.0 and s.ball_pos.x >= br, "left wall bounces at the ball's edge")
	s.queue_free()
	await get_tree().process_frame

func _tilt_tests() -> void:
	print("Weight Shifting")
	var s := _spawn("res://scenes/weight_shifting/weight_shifting.tscn")
	await get_tree().process_frame
	# No load -> target tilt 0. From 20 deg, one long 0.5 s frame must not overshoot past 0.
	s.current_tilt_deg = 20.0
	s._process(0.5)
	check(s.current_tilt_deg >= 0.0 and s.current_tilt_deg < 20.0, "tilt smoothing doesn't overshoot on a slow frame (%.2f)" % s.current_tilt_deg)
	# Same total time in small vs large steps ends at about the same tilt.
	s.current_tilt_deg = 20.0
	for i in 30:
		s._process(1.0 / 60.0)
	var fine: float = s.current_tilt_deg
	s.current_tilt_deg = 20.0
	for i in 5:
		s._process(0.1)
	check(absf(fine - s.current_tilt_deg) < 0.05, "tilt smoothing is frame-rate independent (%.3f vs %.3f)" % [fine, s.current_tilt_deg])
	s.queue_free()
	await get_tree().process_frame
