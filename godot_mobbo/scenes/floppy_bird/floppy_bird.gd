extends Control
## Port of BirdScript.cs + PipeSpawnScript.cs/PipeMoveScript.cs/HeartSystem.cs.
## The bird's vertical position is driven by weight (board lean), not a
## flap/jump input: it tracks a moving-average-smoothed combined COP.y,
## scaled across a narrow lean band read from the ML assessment CSV --
## ported as-is from BirdScript.Update(), including its odd choice of
## reusing the medial-lateral assessment's min_gcop_y (not an AP assessment)
## as the vertical baseline. FootLength (15cm) and the smoothing window (10
## samples) match the Unity constants.

const HUB_SCENE := "res://scenes/hub/hub.tscn"
const ARENA_SIZE := Vector2(560, 380)
const FOOT_LENGTH := 15.0  # cm, matches BirdScript.FootLength
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
var game_data: Array[String] = []
var _elapsed := 0.0

func _ready() -> void:
	if AppData.session == null:
		AppData.start_dummy_session()
	if not SessionPaths.floppybird_rawdata.is_empty():
		DirAccess.make_dir_recursive_absolute(SessionPaths.floppybird_rawdata)
		DirAccess.make_dir_recursive_absolute(SessionPaths.floppybird_gamedata)

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
	game_data.clear()
	_spawn_timer = 0.0
	_elapsed = 0.0
	trial_count += 1
	trial_remaining = float(SessionPaths.trial_duration)
	trial_active = true
	start_button.text = "Restart"

	var folder := SessionPaths.floppybird_rawdata.path_join(
		"%s%s" % [SessionPaths.hosp_num, Time.get_datetime_string_from_system().replace(":", "-")]
	)
	DirAccess.make_dir_recursive_absolute(folder)
	BoardData.start_trial_log(folder.path_join("Trial"), trial_count)

func _process(delta: float) -> void:
	var limits := SessionPaths.get_ml_limits()
	var baseline: float = limits.left  # port of BirdScript's min_gcop_y_ml reuse
	var top_limit := baseline + FOOT_LENGTH * 0.5
	var bottom_limit := baseline

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
	bird_y = ARENA_SIZE.y * (1.0 - t)

	if trial_active:
		trial_remaining = max(0.0, trial_remaining - delta)
		timer_label.text = "Time: %d" % int(ceil(trial_remaining))
		if BoardData.is_trial_logging:
			BoardData.log_trial_frame(SerialLink.left_adc, SerialLink.right_adc)
		_update_pipes(delta)
		_elapsed += delta
		if fmod(_elapsed, 0.1) < delta:
			game_data.append("%.2f,%.1f,%.1f,%d,%.2f,%.1f,0,%d" % [
				_elapsed, ARENA_SIZE.x * 0.25, bird_y, level, spawn_rate, pipe_speed, score
			])
		if trial_remaining <= 0.0:
			_end_trial()

	arena.set_state(bird_y, pipes)

func _update_pipes(delta: float) -> void:
	_spawn_timer += delta
	if _spawn_timer >= spawn_rate or pipes.is_empty():
		_spawn_timer = 0.0
		pipes.append({
			"x": ARENA_SIZE.x + FlappyArena.PIPE_WIDTH,
			"gap_center_y": randf_range(PIPE_GAP_HALF + 10, ARENA_SIZE.y - PIPE_GAP_HALF - 10),
			"gap_half": PIPE_GAP_HALF,
			"scored": false,
		})

	var bird_x := ARENA_SIZE.x * 0.25
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
	BoardData.stop_trial_log()
	start_button.text = "Start Trial"
	UiTheme.set_status(status_label, "trial ended. Score: %d" % score, "neutral")
	_save_game_data()

func _save_game_data() -> void:
	var path := SessionPaths.floppybird_gamedata.path_join(
		"Trial_%d_Data_%s.csv" % [trial_count, Time.get_datetime_string_from_system().replace(":", "-")]
	)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("Time,bird_x,bird_y,Gamelevel,pipe_spawnrate,pipespeed,heightOffsetpipe,score")
	for row in game_data:
		f.store_line(row)
	f.close()
