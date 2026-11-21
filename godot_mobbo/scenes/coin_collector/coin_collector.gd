extends Control
## Port of coin.cs/collector.cs/silvercoin.cs/genrator.cs: a weight-controlled
## collector catches falling coins (+1 score) while avoiding falling bombs
## ("silvercoin" in Unity -- despite the name it ends the game on catch, it
## is not a bonus pickup). Unity had no CSV logging for this game (no
## login_handlr path, no StartLogging call anywhere in coin.cs/collector.cs/
## genrator.cs/main.cs), so none was added here either.

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

	collector_x = ARENA_SIZE.x * 0.5
	arena.set_state(collector_x, items)
	set_process(true)

func _on_start_pressed() -> void:
	score = 0
	score_label.text = "Score: 0"
	status_label.text = ""
	items.clear()
	_spawn_timer = 0.0
	game_active = true
	start_button.text = "Restart"

func _process(delta: float) -> void:
	var limits := SessionPaths.get_ml_limits()
	var cop = BoardData.combined_cop(SerialLink.left_forces(), SerialLink.right_forces())
	if cop != null and limits.right > limits.left:
		var t: float = (cop.x - limits.left) / (limits.right - limits.left)
		collector_x = clamp(t, 0.0, 1.0) * ARENA_SIZE.x

	if game_active:
		_spawn_timer += delta
		if _spawn_timer >= SPAWN_INTERVAL:
			_spawn_timer = 0.0
			_spawn_item()

		var collector_y := ARENA_SIZE.y - 18.0
		var i := items.size() - 1
		while i >= 0:
			var item = items[i]
			var new_pos: Vector2 = item.pos + Vector2(0, FALL_SPEED * delta)
			item.pos = new_pos
			var caught: bool = abs(new_pos.x - collector_x) <= CoinArena.COLLECTOR_SIZE.x * 0.5 and new_pos.y >= collector_y - CoinArena.COLLECTOR_SIZE.y * 0.5
			if caught:
				if item.is_bomb:
					_game_over()
				else:
					score += 1
					score_label.text = "Score: %d" % score
				items.remove_at(i)
			elif item.pos.y > ARENA_SIZE.y:
				items.remove_at(i)
			i -= 1

	arena.set_state(collector_x, items)

func _spawn_item() -> void:
	var is_bomb := randf() * 100.0 <= BOMB_CHANCE * 100.0
	items.append({"pos": Vector2(randf_range(10, ARENA_SIZE.x - 10), 0.0), "is_bomb": is_bomb})

func _game_over() -> void:
	game_active = false
	items.clear()
	UiTheme.set_status(status_label, "you hit a bomb. Final score: %d" % score, "error")
