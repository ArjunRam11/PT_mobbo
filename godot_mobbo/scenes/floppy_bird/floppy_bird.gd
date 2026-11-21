extends Control
## Port of BirdScript.cs + PipeSpawnScript.cs/PipeMoveScript.cs/HeartSystem.cs.
## The bird's vertical position is driven by weight (board lean), not a
## flap/jump input: it tracks a moving-average-smoothed combined COP.y,
## scaled across the patient's anterior-posterior reach from the Sit
## Assessment AP capture (min_max_dist_ap.csv), so their full forward/back
## lean spans the full arena height. (Unity instead reused the ML
## assessment's min_gcop_y plus a fixed 15 cm FootLength band.) The
## smoothing window (10 samples) matches Unity.

const HUB_SCENE := "res://scenes/hub/hub.tscn"
const ARENA_SIZE := Vector2(560, 380)
const SMOOTH_WINDOW := 10
const MAX_LEVEL := 10
const MIN_LIVES := 5
const PIPE_GAP_HALF := 80.0

var arena: FlappyArena
var timer_label: Label
var level_label: Label
var score_label: Label
var lives_label: Label
var status_label: Label
var start_button: Button

var bird_y: float = ARENA_SIZE.y * 0.5
var cop_y_history: Array[float] = []

var pipes: Array = []  # {"x": float, "gap_center_y": float, "gap_half": float, "scored": bool}
var level := 0
var spawn_rate := 5.0      # seconds; matches maxSpawnRate
var min_spawn_rate := 1.0
var max_spawn_rate := 5.0
var pipe_speed := 2.0 * 40.0   # Unity units -> px/s, scaled for screen size
var pipe_speed_min := 2.0 * 40.0
var pipe_speed_max := 9.5 * 40.0

var score := 0
var lives := MIN_LIVES
var trial_active := false
var trial_count := 0
var trial_remaining := 0.0
var _spawn_timer := 0.0
## Unity's columns first; then lives, the smoothed AP COP and the reach
## limits it was scaled across (cm), and the arena size in px.
const GAME_DATA_HEADER := "Time,bird_x,bird_y,Gamelevel,pipe_spawnrate,pipespeed,heightOffsetpipe,score,lives,cop_y_cm,ap_back_cm,ap_front_cm,arena_w,arena_h\n"
var recorder := GameRecorder.new()
var _elapsed := 0.0
var _next_row_s := 0.0

func _ready() -> void:
	if AppData.session == null:
		AppData.start_dummy_session()

	theme = UiTheme.theme
	var bg := UiTheme.make_background()
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

	root.add_child(UiTheme.make_heading("Floppy Bird"))
	root.add_child(UiTheme.make_muted_label("Lean forward/back within your measured range to keep the bird level."))

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 20)
	root.add_child(info_row)
	timer_label = UiTheme.make_field_label("Time: --")
	info_row.add_child(timer_label)
	level_label = UiTheme.make_field_label("Level: 0")
	info_row.add_child(level_label)
	score_label = UiTheme.make_field_label("Score: 0")
	info_row.add_child(score_label)
	lives_label = UiTheme.make_field_label("Lives: %d" % MIN_LIVES)
	info_row.add_child(lives_label)

	arena = FlappyArena.new()
	arena.custom_minimum_size = ARENA_SIZE
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL  # fill the screen
	root.add_child(arena)

	status_label = UiTheme.make_subheading("")
	root.add_child(status_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	root.add_child(button_row)
	start_button = UiTheme.make_accent_button("Start Trial")
	start_button.pressed.connect(_on_start_pressed)
	button_row.add_child(start_button)
	var back := UiTheme.make_secondary_button("Back to Hub")
	back.pressed.connect(func(): get_tree().change_scene_to_file(HUB_SCENE))
	button_row.add_child(back)

	arena.set_state(bird_y, pipes)
	set_process(true)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_UP:
			_increment_level()
		elif event.keycode == KEY_DOWN:
			_decrement_level()

func _increment_level() -> void:
	if level >= MAX_LEVEL:
		return
	level += 1
	spawn_rate = clamp(spawn_rate - 0.5, min_spawn_rate, max_spawn_rate)
	pipe_speed = clamp(2.0 * 40.0 + 0.5 * 40.0 * level, pipe_speed_min, pipe_speed_max)
	level_label.text = "Level: %d" % level

func _decrement_level() -> void:
	if level <= 0:
		return
	level -= 1
	spawn_rate = clamp(spawn_rate + 0.5, min_spawn_rate, max_spawn_rate)
	pipe_speed = clamp(2.0 * 40.0 + 0.75 * 40.0 * (level - 1), pipe_speed_min, pipe_speed_max)
	level_label.text = "Level: %d" % level

func _on_start_pressed() -> void:
	score = 0
	lives = MIN_LIVES
	score_label.text = "Score: 0"
	lives_label.text = "Lives: %d" % lives
	status_label.text = ""
	pipes.clear()
	_spawn_timer = 0.0
	_elapsed = 0.0
	_next_row_s = 0.0
	trial_count += 1
	# Login sets the trial length; without login it would be 0 s.
	trial_remaining = float(SessionPaths.trial_duration if SessionPaths.trial_duration > 0 else 60)
	trial_active = true
	start_button.text = "Restart"
	recorder.start("floppybird", "floppybird_rawdata", "floppybird_gamedata", GAME_DATA_HEADER, trial_count)

func _exit_tree() -> void:
	recorder.stop("left early" if trial_active else "finished")

func _process(delta: float) -> void:
	# Patient's own anterior-posterior reach (Sit Assessment AP capture):
	# leaning fully back = bottom of the arena, fully forward = top.
	var limits := SessionPaths.get_ap_limits()
	var top_limit: float = limits.front
	var bottom_limit: float = limits.back

	var cop = BoardData.combined_cop(SerialLink.left_forces(), SerialLink.right_forces())
	var cop_y: float = 0.0 if cop == null else cop.y
	cop_y_history.append(cop_y)
	if cop_y_history.size() > SMOOTH_WINDOW:
		cop_y_history.pop_front()
	var avg_cop_y := 0.0
	for v in cop_y_history:
		avg_cop_y += v
	avg_cop_y /= cop_y_history.size()

	var t := 0.0
	if top_limit > bottom_limit:
		t = clamp((avg_cop_y - bottom_limit) / (top_limit - bottom_limit), 0.0, 1.0)
	var r := FlappyArena.BIRD_RADIUS
	bird_y = r + (_area().y - 2.0 * r) * (1.0 - t)  # full lean = edge, bird stays inside

	if trial_active:
		trial_remaining = max(0.0, trial_remaining - delta)
		timer_label.text = "Time: %d" % int(ceil(trial_remaining))
		_update_pipes(delta)
		_elapsed += delta
		if _elapsed >= _next_row_s:  # 10 Hz game-state rows, as Unity did
			_next_row_s += 0.1
			recorder.row("%.2f,%.1f,%.1f,%d,%.2f,%.1f,0,%d,%d,%.3f,%.3f,%.3f,%.0f,%.0f" % [
				_elapsed, _area().x * 0.25, bird_y, level, spawn_rate, pipe_speed, score,
				lives, avg_cop_y, bottom_limit, top_limit, _area().x, _area().y
			])
		if trial_remaining <= 0.0:
			_end_trial()

	arena.set_state(bird_y, pipes)

func _update_pipes(delta: float) -> void:
	_spawn_timer += delta
	if _spawn_timer >= spawn_rate or pipes.is_empty():
		_spawn_timer = 0.0
		pipes.append({
			"x": _area().x + FlappyArena.PIPE_WIDTH,
			"gap_center_y": randf_range(PIPE_GAP_HALF + 10, _area().y - PIPE_GAP_HALF - 10),
			"gap_half": PIPE_GAP_HALF,
			"scored": false,
		})

	var bird_x := _area().x * 0.25
	var i := pipes.size() - 1
	while i >= 0:
		var pipe = pipes[i]
		var new_x: float = pipe.x - pipe_speed * delta
		pipe.x = new_x
		if not pipe.scored and new_x < bird_x:
			pipe.scored = true
			if abs(bird_y - pipe.gap_center_y) <= pipe.gap_half:
				score += 1
				score_label.text = "Score: %d" % score
			else:
				_lose_life()
		if new_x < -FlappyArena.PIPE_WIDTH:
			pipes.remove_at(i)
		i -= 1

func _lose_life() -> void:
	lives -= 1
	lives_label.text = "Lives: %d" % max(lives, 0)
	if lives <= 0:
		_end_trial()

func _end_trial() -> void:
	trial_active = false
	start_button.text = "Start Trial"
	UiTheme.set_status(status_label, "trial ended. Score: %d. Data saved." % score, "neutral")
	recorder.stop("finished, score %d" % score)

## The arena's real on-screen size (it stretches to fill the window);
## ARENA_SIZE is only its minimum / pre-layout fallback.
func _area() -> Vector2:
	return arena.size if arena != null and arena.size.x > 1.0 else ARENA_SIZE
