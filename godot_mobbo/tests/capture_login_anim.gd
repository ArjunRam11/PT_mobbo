extends Node
## Records the main (login) screen's animation as frames for a GIF:
##   tests/run_capture_login_anim.bat
## Frames -> tests/screenshots/login_anim/frame_###.png (half size), then
## tools/make_gif.py turns them into tests/screenshots/login_animation.gif.

const OUT := "res://tests/screenshots/login_anim/"
const FRAMES := 60
const STEP := 0.1  # s between frames -> 6 s clip at 10 fps

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()

func _run() -> void:
	var scene: Node = load("res://scenes/login/login.tscn").instantiate()
	get_tree().root.add_child(scene)
	await get_tree().create_timer(0.1).timeout  # start early: capture the logo intro too
	for i in FRAMES:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
		img.save_png(ProjectSettings.globalize_path(OUT + "frame_%03d.png" % i))
		await get_tree().create_timer(STEP).timeout
	print("CAPTURE_DONE %d frames" % FRAMES)
	get_tree().quit()
