extends Control
## Port of coin.cs/collector.cs/silvercoin.cs/genrator.cs: a weight-controlled
## collector catches falling coins (+1 score) while avoiding falling bombs
## ("silvercoin" in Unity -- despite the name it ends the game on catch, it
## is not a bonus pickup). Unity had no logging for this game; this port
## records it like the others (GameRecorder: raw board data + game rows).

const HUB_SCENE := "res://scenes/hub/hub.tscn"
const ARENA_SIZE := Vector2(560, 380)
const SPAWN_INTERVAL := 2.0  # matches genrator.cs's `timer = 2.0f`
const BOMB_CHANCE := 0.2     # matches genrator.cs's `chance <= 20`
const FALL_SPEED := 160.0

var arena: CoinArena
var score_label: Label
var status_label: Label
var start_button: Button

var collector_x: float
var items: Array = []  # {"pos": Vector2, "is_bomb": bool}
var score := 0
var game_active := false
var _spawn_timer := 0.0

## event = "" on the regular 10 Hz rows, "coin"/"bomb"/"spawn_coin"/
## "spawn_bomb" on the frame it happened. x positions in px; cop_x in cm.
const GAME_DATA_HEADER := "Time,collector_x,cop_x_cm,ml_left_cm,ml_right_cm,score,items_on_screen,event,arena_w,arena_h\n"
var recorder := GameRecorder.new()
var trial_count := 0
var _elapsed := 0.0
var _next_row_s := 0.0
var _cop_x := 0.0
var _limits := {"left": 0.0, "right": 0.0}

func _record(event: String) -> void:
	recorder.row("%.2f,%.1f,%.3f,%.3f,%.3f,%d,%d,%s,%.0f,%.0f" % [
		_elapsed, collector_x, _cop_x, _limits.left, _limits.right, score, items.size(), event,
		_area().x, _area().y
	])

func _exit_tree() -> void:
	recorder.stop("left early" if game_active else "finished")

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

	root.add_child(UiTheme.make_heading("Coin Collector"))
	root.add_child(UiTheme.make_muted_label("Shift weight left/right to catch coins. Avoid the red bombs."))

	score_label = UiTheme.make_subheading("Score: 0")
	root.add_child(score_label)

	arena = CoinArena.new()
	arena.custom_minimum_size = ARENA_SIZE
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL  # fill the screen
	root.add_child(arena)

	status_label = UiTheme.make_subheading("")
	root.add_child(status_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	root.add_child(button_row)
	start_button = UiTheme.make_accent_button("Start Game")
	start_button.pressed.connect(_on_start_pressed)
	button_row.add_child(start_button)
	var back := UiTheme.make_secondary_button("Back to Hub")
	back.pressed.connect(func(): get_tree().change_scene_to_file(HUB_SCENE))
	button_row.add_child(back)

	collector_x = _area().x * 0.5
	arena.set_state(collector_x, items)
	set_process(true)

func _on_start_pressed() -> void:
	score = 0
	score_label.text = "Score: 0"
	status_label.text = ""
	items.clear()
	_spawn_timer = 0.0
	_elapsed = 0.0
	_next_row_s = 0.0
	trial_count += 1
	recorder.start("coin_collector", "coin_rawdata", "coin_gamedata", GAME_DATA_HEADER, trial_count)
	game_active = true
	start_button.text = "Restart"

func _process(delta: float) -> void:
	var limits := SessionPaths.get_ml_limits()
	_limits = limits
	var cop = BoardData.combined_cop(SerialLink.left_forces(), SerialLink.right_forces())
	if cop != null:
		_cop_x = cop.x
	if cop != null and limits.right > limits.left:
		var t: float = (cop.x - limits.left) / (limits.right - limits.left)
		collector_x = clamp(t, 0.0, 1.0) * _area().x

	if game_active:
		_elapsed += delta
		if _elapsed >= _next_row_s:
			_next_row_s += 0.1
			_record("")
		_spawn_timer += delta
		if _spawn_timer >= SPAWN_INTERVAL:
			_spawn_timer = 0.0
			_spawn_item()

		var collector_y := _area().y - 18.0
		var i := items.size() - 1
		while i >= 0:
			var item = items[i]
			var new_pos: Vector2 = item.pos + Vector2(0, FALL_SPEED * delta)
			item.pos = new_pos
			var caught: bool = abs(new_pos.x - collector_x) <= CoinArena.COLLECTOR_SIZE.x * 0.5 and new_pos.y >= collector_y - CoinArena.COLLECTOR_SIZE.y * 0.5
			if caught:
				if item.is_bomb:
					_record("bomb")
					_game_over()
					break  # _game_over() cleared items; nothing left to update
				else:
					score += 1
					score_label.text = "Score: %d" % score
					_record("coin")
				items.remove_at(i)
			elif item.pos.y > _area().y:
				items.remove_at(i)
			i -= 1

	arena.set_state(collector_x, items)

func _spawn_item() -> void:
	var is_bomb := randf() * 100.0 <= BOMB_CHANCE * 100.0
	items.append({"pos": Vector2(randf_range(10, _area().x - 10), 0.0), "is_bomb": is_bomb})
	_record("spawn_bomb" if is_bomb else "spawn_coin")

func _game_over() -> void:
	game_active = false
	items.clear()
	UiTheme.set_status(status_label, "you hit a bomb. Final score: %d. Data saved." % score, "error")
	recorder.stop("finished, score %d" % score)

## The arena's real on-screen size (it stretches to fill the window);
## ARENA_SIZE is only its minimum / pre-layout fallback.
func _area() -> Vector2:
	return arena.size if arena != null and arena.size.x > 1.0 else ARENA_SIZE
