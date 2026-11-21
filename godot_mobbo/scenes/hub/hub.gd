extends Control
## Port of the "2mb" hub scene: the menu every game's "Go Back" button
## returns to. Entries for games not yet ported in Godot are disabled
## placeholders rather than omitted, so this list stays the map of what's
## left (see CLAUDE.md's conversion status).

const LOGIN_SCENE := "res://scenes/login/login.tscn"
const BOARD_MONITOR_SCENE := "res://main.tscn"

## scene_path = "" means "not ported yet" -> button stays disabled.
## Crashy Racing and Space Shooter (vendored third-party asset-store kits in
## the Unity app) are out of scope for this conversion and deliberately not
## listed here at all, per instruction -- not just left disabled.
const GAME_ENTRIES := [
	{"label": "Ping Pong", "scene": "res://scenes/ping_pong/ping_pong.tscn"},
	{"label": "Floppy Bird", "scene": "res://scenes/floppy_bird/floppy_bird.tscn"},
	{"label": "Coin Collector", "scene": "res://scenes/coin_collector/coin_collector.tscn"},
	{"label": "Stepper", "scene": ""},
	{"label": "Weight Shifting", "scene": "res://scenes/weight_shifting/weight_shifting.tscn"},
	{"label": "Sit Assessment", "scene": "res://scenes/assessment/assessment.tscn"},
	# Unity's sensory_assess.cs was an empty stub -- nothing to port yet.
	{"label": "Sensory Integration Test", "scene": ""},
	{"label": "Board Setup / Test", "scene": ""},
	{"label": "User Info", "scene": ""},
]

var patient_label: Label
var connection_label: Label
var auto_button: Button

func _ready() -> void:
	theme = UiTheme.theme
	var bg := UiTheme.make_background()
	bg.color = UiTheme.COLOR_BACKGROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 32)
	add_child(margin)

	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)

	root.add_child(UiTheme.make_app_title())

	patient_label = UiTheme.make_muted_label(
		"Patient: %s" % (SessionPaths.hosp_num if SessionPaths.hosp_num != "" else "(none)")
	)
	root.add_child(patient_label)

	connection_label = UiTheme.make_muted_label(_connection_text())
	connection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(connection_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(grid)
	for entry in GAME_ENTRIES:
		var btn: Button
		if entry.scene == "":
			# Greyed out = coming soon (tooltip says so); no "(soon)" suffix so
			# the long names don't widen every column.
			btn = UiTheme.make_secondary_button(entry.label)
			btn.disabled = true
			btn.tooltip_text = "Coming soon."
		else:
			btn = UiTheme.make_primary_button(entry.label)
			btn.pressed.connect(func(): get_tree().change_scene_to_file(entry.scene))
		btn.custom_minimum_size = Vector2(230, UiTheme.MIN_TOUCH_SIZE.y)
		btn.size_flags_horizontal = Control.SIZE_FILL
		grid.add_child(btn)

	var utility_row := HBoxContainer.new()
	utility_row.alignment = BoxContainer.ALIGNMENT_CENTER
	utility_row.add_theme_constant_override("separation", 16)
	root.add_child(utility_row)

	auto_button = UiTheme.make_accent_button("Auto connect")
	auto_button.pressed.connect(_on_auto_connect_pressed)
	utility_row.add_child(auto_button)

	var monitor_btn := UiTheme.make_secondary_button("Board Diagnostics")
	monitor_btn.pressed.connect(func(): get_tree().change_scene_to_file(BOARD_MONITOR_SCENE))
	utility_row.add_child(monitor_btn)

	var logout_btn := UiTheme.make_destructive_button("Logout")
	logout_btn.pressed.connect(_logout)
	utility_row.add_child(logout_btn)

	SerialLink.status_changed.connect(func(t): UiTheme.set_status(connection_label, t, "neutral"))
	SerialLink.error.connect(func(t): UiTheme.set_status(connection_label, t, "error"))
	SerialLink.auto_connect_finished.connect(func(_ok, _l, _r):
		auto_button.disabled = false
		auto_button.text = "Auto connect")

func _connection_text() -> String:
	if SerialLink.left_port != "" or SerialLink.right_port != "":
		return "Left board: %s   ·   Right board: %s" % [
			SerialLink.left_port if SerialLink.left_port != "" else "not found",
			SerialLink.right_port if SerialLink.right_port != "" else "not found",
		]
	return "Boards not connected. Press Auto connect."

func _on_auto_connect_pressed() -> void:
	auto_button.disabled = true
	auto_button.text = "Scanning..."
	SerialLink.auto_connect()

func _logout() -> void:
	AppData.stop_session()
	get_tree().change_scene_to_file(LOGIN_SCENE)
