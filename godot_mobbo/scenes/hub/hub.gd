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
## "card" = cover art in sprites/cards/; "row" 0 = big game cards, 1 = smaller.
const GAME_ENTRIES := [
	{"label": "Ping Pong", "card": "ping_pong", "row": 0, "scene": "res://scenes/ping_pong/ping_pong.tscn"},
	{"label": "Floppy Bird", "card": "floppy_bird", "row": 0, "scene": "res://scenes/floppy_bird/floppy_bird.tscn"},
	{"label": "Coin Collector", "card": "coin_collector", "row": 0, "scene": "res://scenes/coin_collector/coin_collector.tscn"},
	{"label": "Weight Shifting", "card": "weight_shifting", "row": 0, "scene": "res://scenes/weight_shifting/weight_shifting.tscn"},
	{"label": "Sit Assessment", "card": "sit_assessment", "row": 1, "scene": "res://scenes/assessment/assessment.tscn"},
	{"label": "Stepper", "card": "stepper", "row": 1, "scene": ""},
	# Unity's sensory_assess.cs was an empty stub -- nothing to port yet.
	{"label": "Sensory Integration", "card": "locked", "row": 1, "scene": ""},
	{"label": "Board Setup / Test", "card": "locked", "row": 1, "scene": ""},
	{"label": "User Info", "card": "locked", "row": 1, "scene": ""},
]
const CARD_W := [272.0, 206.0]

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
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	# Header: animated logo left, patient + connection status right.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	root.add_child(header)
	var logo := UiTheme.make_app_title(104.0)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(logo)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var status := VBoxContainer.new()
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(status)
	patient_label = UiTheme.make_subheading(
		"Patient: %s" % (SessionPaths.hosp_num if SessionPaths.hosp_num != "" else "(none)")
	)
	patient_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(patient_label)
	connection_label = UiTheme.make_muted_label(_connection_text())
	connection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	connection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	connection_label.custom_minimum_size.x = 420
	status.add_child(connection_label)

	# Game cards: the four games big, then assessment + not-yet-ported smaller.
	var section := UiTheme.make_eyebrow("Games")
	root.add_child(section)
	var rows := [HBoxContainer.new(), HBoxContainer.new()]
	for i in 2:
		rows[i].alignment = BoxContainer.ALIGNMENT_CENTER
		rows[i].add_theme_constant_override("separation", 16)
	root.add_child(rows[0])
	root.add_child(UiTheme.make_eyebrow("Assessment & more"))
	root.add_child(rows[1])
	for entry in GAME_ENTRIES:
		var card := GameCard.create(entry.label, entry.card, CARD_W[entry.row])
		if entry.scene == "":
			card.disabled = true
			card.tooltip_text = "%s -- coming soon." % entry.label
		else:
			card.pressed.connect(func(): get_tree().change_scene_to_file(entry.scene))
		rows[entry.row].add_child(card)

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

	utility_row.add_child(UiTheme.make_sound_toggles())

	var logout_btn := UiTheme.make_destructive_button("Logout")
	logout_btn.pressed.connect(_logout)
	utility_row.add_child(logout_btn)

	Sfx.stop_music()  # back from a game: its music fades out

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
