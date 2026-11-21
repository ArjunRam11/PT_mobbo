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

	var hud := GameHud.build(self, "Coin Collector", "Shift weight left/right to catch coins. Avoid the bombs.", "music_coin")

	var score_chip := HudChip.create("Score: 0", "coin")
	score_label = score_chip.label
	hud.chips.add_child(score_chip)

	arena = CoinArena.new()
	arena.custom_minimum_size = ARENA_SIZE
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL  # fill the screen
	hud.arena_slot.add_child(arena)

	status_label = GameHud.make_status_label()
	hud.status.add_child(status_label)

	start_button = UiTheme.make_accent_button("Start Game")
	start_button.pressed.connect(_on_start_pressed)
	hud.buttons.add_child(start_button)
	var back := UiTheme.make_secondary_button("Back to Hub")
	back.pressed.connect(func(): get_tree().change_scene_to_file(HUB_SCENE))
	hud.buttons.add_child(back)

	collector_x = _area().x * 0.5
	arena.set_state(collector_x, items)
	arena.show_banner("Coin Collector", "Press Start Game")
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
	arena.hide_banner()
	Sfx.play("start")

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

		var collector_y := _area().y - CoinArena.COLLECTOR_BOTTOM
		var rim_y := collector_y - CoinArena.COLLECTOR_SIZE.y * 0.5
		var i := items.size() - 1
		while i >= 0:
			var item = items[i]
			var old_y: float = item.pos.y
			var new_pos: Vector2 = item.pos + Vector2(0, FALL_SPEED * delta)
			item.pos = new_pos
			# Caught only on the frame the item's bottom crosses the basket rim
			# while over the basket (edge-on counts by half a radius). Before,
			# anything already below the rim was caught too, so an item that
			# had fallen past could still be scooped up by sliding under it.
			var r := CoinArena.ITEM_RADIUS
			var crossed_rim: bool = old_y + r < rim_y and new_pos.y + r >= rim_y
			var over_basket: bool = abs(new_pos.x - collector_x) <= CoinArena.COLLECTOR_SIZE.x * 0.5 + r * 0.5
			var caught: bool = crossed_rim and over_basket
			if caught:
				if item.is_bomb:
					_record("bomb")
					arena.fx_bomb(new_pos)
					_game_over()
					break  # _game_over() cleared items; nothing left to update
				else:
					score += 1
					score_label.text = "Score: %d" % score
					_record("coin")
					arena.fx_catch(new_pos)
				items.remove_at(i)
			elif item.pos.y > _area().y:
				items.remove_at(i)
			i -= 1

	arena.recording = game_active
	arena.set_state(collector_x, items)

func _spawn_item() -> void:
	var is_bomb := randf() * 100.0 <= BOMB_CHANCE * 100.0
	items.append({"pos": Vector2(randf_range(10, _area().x - 10), 0.0), "is_bomb": is_bomb})
	_record("spawn_bomb" if is_bomb else "spawn_coin")
	if is_bomb:
		Sfx.play("fuse", -6.0)  # audible warning: a bomb is coming

func _game_over() -> void:
	game_active = false
	items.clear()
	UiTheme.set_status(status_label, "you hit a bomb. Final score: %d. Data saved." % score, "error")
	recorder.stop("finished, score %d" % score)
	arena.show_banner("Game over", "Final score %d  -  press Restart" % score, _badge_for(score, 3, 8, 15))
	Sfx.play("game_over")

## Cosmetic medal for the end banner: bronze/silver/gold at these scores.
func _badge_for(value: int, bronze: int, silver: int, gold: int) -> String:
	return "gold" if value >= gold else ("silver" if value >= silver else ("bronze" if value >= bronze else ""))

## The arena's real on-screen size (it stretches to fill the window);
## ARENA_SIZE is only its minimum / pre-layout fallback.
func _area() -> Vector2:
	return arena.size if arena != null and arena.size.x > 1.0 else ARENA_SIZE
