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
const PIPE_GAP_HALF := 105.0  # widened with the bigger bird (BIRD_RADIUS 24)

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

	var hud := GameHud.build(self, "Floppy Bird",
		"Lean forward/back within your measured range to fly through the gaps. Up/Down keys change level.",
		"music_bird")

	var timer_chip := HudChip.create("Time: --", "", false)
	timer_label = timer_chip.label
	hud.chips.add_child(timer_chip)
	var level_chip := HudChip.create("Level: 0")
	level_label = level_chip.label
	hud.chips.add_child(level_chip)
	var score_chip := HudChip.create("Score: 0", "bird_mid")
	score_label = score_chip.label
	hud.chips.add_child(score_chip)
	var lives_chip := HudChip.create("Lives: %d" % MIN_LIVES, "heart")
	lives_label = lives_chip.label
	hud.chips.add_child(lives_chip)

	arena = FlappyArena.new()
	arena.custom_minimum_size = ARENA_SIZE
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL  # fill the screen
	arena.max_lives = MIN_LIVES
	hud.arena_slot.add_child(arena)

	status_label = GameHud.make_status_label()
	hud.status.add_child(status_label)

	start_button = UiTheme.make_accent_button("Start Trial")
	start_button.pressed.connect(_on_start_pressed)
	hud.buttons.add_child(start_button)
	var back := UiTheme.make_secondary_button("Back to Hub")
	back.pressed.connect(func(): get_tree().change_scene_to_file(HUB_SCENE))
	hud.buttons.add_child(back)

	arena.set_state(bird_y, pipes)
	arena.show_banner("Floppy Bird", "Press Start Trial")
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
	_apply_level()
	Sfx.play("level_up")

func _decrement_level() -> void:
	if level <= 0:
		return
	level -= 1
	_apply_level()
	Sfx.play("level_down")

## Spawn interval and pillar speed are a function of the level alone, so
## going up then down returns exactly to where you were. (Before, up used
## 0.5*level and down 0.75*(level-1) for speed, and the spawn interval
## stepped +-0.5 from wherever its clamp had left it.) Level 0 = 5 s / 80
## px/s; each level -0.5 s (floor 1 s) and +20 px/s.
func _apply_level() -> void:
	spawn_rate = clamp(max_spawn_rate - 0.5 * level, min_spawn_rate, max_spawn_rate)
	pipe_speed = clamp(2.0 * 40.0 + 0.5 * 40.0 * level, pipe_speed_min, pipe_speed_max)
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
	arena.hide_banner()
	arena.next_bird()  # cosmetic: a different bird each trial
	Sfx.play("start")

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

	arena.recording = trial_active
	arena.lives = lives if trial_active else -1
	arena.scroll_speed = pipe_speed if trial_active else 0.0
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
			"hit": false,
		})

	# Collision uses the bird's body (BIRD_RADIUS) against the pillar's full
	# width, for the whole time they overlap -- not just the bird's centre
	# at the single frame the pillar's centre passed it. Touching a pillar
	# costs one life (once per pillar); clearing it untouched scores.
	var bird_x := _area().x * 0.25
	var r := FlappyArena.BIRD_RADIUS
	var reach_x := FlappyArena.PIPE_WIDTH * 0.5 + r
	var i := pipes.size() - 1
	while i >= 0:
		var pipe = pipes[i]
		var new_x: float = pipe.x - pipe_speed * delta
		pipe.x = new_x
		var overlapping: bool = abs(new_x - bird_x) <= reach_x
		var outside_gap: bool = abs(bird_y - pipe.gap_center_y) > pipe.gap_half - r
		if overlapping and outside_gap and not pipe.hit:
			pipe.hit = true
			arena.fx_hit()
			_lose_life()
			if not trial_active:
				return  # out of lives: trial already ended and saved
		if not pipe.scored and new_x + reach_x < bird_x:
			pipe.scored = true
			if not pipe.hit:
				score += 1
				score_label.text = "Score: %d" % score
				arena.fx_score()
		if new_x < -FlappyArena.PIPE_WIDTH:
			pipes.remove_at(i)
		i -= 1

func _lose_life() -> void:
	lives -= 1
	lives_label.text = "Lives: %d" % max(lives, 0)
	if lives <= 0:
		_end_trial()

func _end_trial() -> void:
	if not trial_active:
		return  # lives and time can run out on the same frame
	trial_active = false
	start_button.text = "Start Trial"
	UiTheme.set_status(status_label, "trial ended. Score: %d. Data saved." % score, "neutral")
	recorder.stop("finished, score %d" % score)
	var badge := "" if lives <= 0 else ("gold" if score >= 10 else ("silver" if score >= 5 else ("bronze" if score >= 1 else "")))
	arena.show_banner("Trial ended", "Score %d  -  press Start Trial" % score, badge)
	Sfx.play("game_over" if lives <= 0 else "win")

## The arena's real on-screen size (it stretches to fill the window);
## ARENA_SIZE is only its minimum / pre-layout fallback.
func _area() -> Vector2:
	return arena.size if arena != null and arena.size.x > 1.0 else ARENA_SIZE
