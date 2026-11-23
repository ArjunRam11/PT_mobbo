extends Node
## Screenshots of the login screen with each form open (layout check):
## tests/screenshots/login_form_signup.png, login_form_login.png.
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node = load("res://scenes/login/login.tscn").instantiate()
	get_tree().root.add_child(scene)
	await get_tree().create_timer(0.5).timeout
	for form in ["signup", "login"]:
		scene.call("_show_" + form)
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://tests/screenshots/login_form_%s.png" % form))
	print("FORMS_DONE")
	get_tree().quit()
