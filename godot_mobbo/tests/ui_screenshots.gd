extends Node
## Visual smoke test for the game screens -- no boards needed.
##
## For each game it: shows the start banner, presses Start, feeds fake board
## data (both boards swaying left/right and front/back), fires a few cosmetic
## effects, and saves screenshots to res://tests/screenshots/.
##
## Run (windowed -- headless has no renderer, so no screenshots):
##   set MOBBO_DATA_DIR=<project>\tests\test_data   (keeps test recordings out
##                                                   of the real MoBBo_Data)
##   Godot_v4.6.2-stable_win64_console.exe --path . --windowed --resolution 1280x720 res://tests/ui_screenshots.tscn
## or just run tests/run_ui_screenshots.bat.
##
## Fake data path: tare = 0 and SerialLink.left_adc/right_adc are written
## directly, so BoardData's real force/COP math runs on them.

const OUT_DIR := "res://tests/screenshots/"
const GAMES := [
	{"name": "coin_collector", "scene": "res://scenes/coin_collector/coin_collector.tscn", "start": "_on_start_pressed"},
	{"name": "floppy_bird", "scene": "res://scenes/floppy_bird/floppy_bird.tscn", "start": "_on_start_pressed"},
	{"name": "ping_pong", "scene": "res://scenes/ping_pong/ping_pong.tscn", "start": "_on_start_pressed"},
	{"name": "weight_shifting", "scene": "res://scenes/weight_shifting/weight_shifting.tscn", "start": "_on_record_pressed"},
	{"name": "hub", "scene": "res://scenes/hub/hub.tscn", "start": ""},
	{"name": "login", "scene": "res://scenes/login/login.tscn", "start": "", "extra_frames": 3},
	{"name": "assessment", "scene": "res://scenes/assessment/assessment.tscn", "start": ""},
	{"name": "diagnostics", "scene": "res://main.tscn", "start": ""},
]

var _t := 0.0
var _errors := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	BoardData.left_tare_adc = [0, 0, 0, 0]
	BoardData.right_tare_adc = [0, 0, 0, 0]
	_run.call_deferred()

func _process(delta: float) -> void:
	_t += delta
	_feed_fake_boards()

## ~60 kg total, shifting between boards (ML) and front/back sensors (AP).
func _feed_fake_boards() -> void:
	var ml := sin(_t * 1.3)            # -1 = all left, +1 = all right
	var ap := sin(_t * 0.9 + 1.0) * 0.6
	var left_kg := 30.0 * (1.0 - 0.8 * ml)
	var right_kg := 30.0 * (1.0 + 0.8 * ml)
	SerialLink.left_adc = _adc_for(left_kg, ap)
	SerialLink.right_adc = _adc_for(right_kg, ap)

func _adc_for(kg: float, ap: float) -> Array:
	# Sensors 0/1 one edge, 2/3 the other; exact layout doesn't matter here.
	var shares := [0.25 * (1.0 + ap), 0.25 * (1.0 + ap), 0.25 * (1.0 - ap), 0.25 * (1.0 - ap)]
	var adc := []
	for i in 4:
		adc.append(int(kg * shares[i] / BoardData.GAIN[i]))
	return adc

func _run() -> void:
	for g in GAMES:
		var scene: Node = load(g.scene).instantiate()
		get_tree().root.add_child(scene)
		await _wait(0.25)
		await _shot("%s_0_entrance" % g.name)  # mid entrance animation
		await _wait(0.75)
		await _shot("%s_1_idle" % g.name)
		for k in g.get("extra_frames", 0):  # animated screens: a few moments of the cycle
			await _wait(1.8)
			await _shot("%s_1_idle_%d" % [g.name, k + 2])
		if g.start == "":
			scene.queue_free()
			await get_tree().process_frame
			continue
		scene.call(g.start)
		await _wait(4.5)
		await _shot("%s_2_playing" % g.name)
		_fire_fx(g.name, scene)
		await _wait(0.18)
		await _shot("%s_3_effects" % g.name)
		await _wait(1.5)
		if _show_result(g.name, scene):
			await _wait(0.9)
			await _shot("%s_4_result" % g.name)
		scene.queue_free()
		await get_tree().process_frame
	print("UI_SCREENSHOTS_DONE errors=%d -> %s" % [_errors, ProjectSettings.globalize_path(OUT_DIR)])
	get_tree().quit(1 if _errors > 0 else 0)

func _fire_fx(game: String, scene: Node) -> void:
	var a: GameArena = scene.arena
	match game:
		"coin_collector":
			a.fx_catch(Vector2(a.size.x * 0.3, a.size.y - 40))
			a.fx_bomb(Vector2(a.size.x * 0.7, a.size.y - 40))
		"floppy_bird":
			a.fx_score()
		"ping_pong":
			a.fx_paddle(Vector2(a.size.x * 0.5, a.size.y - 28), true)
			a.fx_point(true)
		"weight_shifting":
			a.burst(a.size * 0.5, UiTheme.COLOR_YELLOW, 20)

## Result banner (medal + confetti) as the game would show it at the end.
func _show_result(game: String, scene: Node) -> bool:
	var a: GameArena = scene.arena
	match game:
		"coin_collector":
			a.show_banner("Game over", "Final score 9  -  press Restart", "silver")
		"floppy_bird":
			a.show_banner("Trial ended", "Score 12  -  press Start Trial", "gold")
		"ping_pong":
			a.show_banner("You win!", "5 - 3  -  press Restart", "gold")
		_:
			return false
	return true

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR + file_name + ".png")
	var err := img.save_png(path)
	if err != OK:
		_errors += 1
		push_error("could not save %s (%d)" % [path, err])
	else:
		print("saved ", path)
