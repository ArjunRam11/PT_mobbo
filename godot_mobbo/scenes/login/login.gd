extends Control
## Port of login_handlr.cs + the login_mobbo.unity scene: a hospital number
## ("hosp no") identifies a patient. Login looks it up in the master list and
## starts a session; Sign Up adds a new patient to the master list.
##
## Deviation from the original: Unity's Update() also triggered login on any
## Return keypress anywhere in the scene (in addition to the login button
## doing the same two calls) -- that looked like a leftover debugging hook,
## not an intended second way to log in, so it wasn't carried over. Only the
## button (and Enter inside the hosp-no field, which is standard LineEdit
## behavior) submits login here.

const HUB_SCENE := "res://scenes/hub/hub.tscn"

var message_label: Label

var login_panel: PanelContainer
var login_hospno: LineEdit
var login_trial_duration: LineEdit

var signup_panel: PanelContainer
var signup_hospno: LineEdit
var signup_name: LineEdit
var signup_gender: OptionButton
var signup_age: LineEdit
var signup_diagnosis: LineEdit
var signup_amp_side: OptionButton
var signup_amp_type: OptionButton

func _ready() -> void:
	theme = UiTheme.theme
	var bg := UiTheme.make_background()
	bg.color = UiTheme.COLOR_BACKGROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 20)
	add_child(root)

	root.add_child(UiTheme.make_app_title())
	root.add_child(UiTheme.make_muted_label("Balance-board rehab sessions"))

	message_label = UiTheme.make_muted_label("")
	root.add_child(message_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	root.add_child(buttons)

	var login_btn := UiTheme.make_primary_button("Login")
	login_btn.pressed.connect(_show_login)
	buttons.add_child(login_btn)

	var signup_btn := UiTheme.make_secondary_button("Sign Up")
	signup_btn.pressed.connect(_show_signup)
	buttons.add_child(signup_btn)

	var exit_btn := UiTheme.make_destructive_button("Exit")
	exit_btn.pressed.connect(func(): get_tree().quit())
	buttons.add_child(exit_btn)

	_build_login_panel(root)
	_build_signup_panel(root)

func _build_login_panel(root: VBoxContainer) -> void:
	login_panel = PanelContainer.new()
	login_panel.visible = false
	login_panel.custom_minimum_size = Vector2(420, 0)
	login_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(login_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	login_panel.add_child(box)

	box.add_child(UiTheme.make_field_label("Hospital No."))
	login_hospno = UiTheme.make_line_edit("e.g. 000123")
	login_hospno.text_submitted.connect(func(_t): _do_login())
	box.add_child(login_hospno)

	box.add_child(UiTheme.make_field_label("Trial Duration (seconds)"))
	login_trial_duration = UiTheme.make_line_edit()
	login_trial_duration.text = "60"
	box.add_child(login_trial_duration)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	box.add_child(button_row)

	var cancel := UiTheme.make_secondary_button("Cancel")
	cancel.pressed.connect(func(): login_panel.visible = false)
	button_row.add_child(cancel)

	var submit := UiTheme.make_primary_button("Submit")
	submit.pressed.connect(_do_login)
	button_row.add_child(submit)

func _build_signup_panel(root: VBoxContainer) -> void:
	signup_panel = PanelContainer.new()
	signup_panel.visible = false
	signup_panel.custom_minimum_size = Vector2(420, 0)
	signup_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(signup_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	signup_panel.add_child(box)

	box.add_child(UiTheme.make_field_label("Hospital No."))
	signup_hospno = UiTheme.make_line_edit()
	box.add_child(signup_hospno)

	box.add_child(UiTheme.make_field_label("Name"))
	signup_name = UiTheme.make_line_edit()
	box.add_child(signup_name)

	box.add_child(UiTheme.make_field_label("Gender"))
	signup_gender = _option_button(["Male", "Female", "Other"])
	box.add_child(signup_gender)

	box.add_child(UiTheme.make_field_label("Age"))
	signup_age = UiTheme.make_line_edit()
	box.add_child(signup_age)

	box.add_child(UiTheme.make_field_label("Diagnosis"))
	signup_diagnosis = UiTheme.make_line_edit()
	box.add_child(signup_diagnosis)

	box.add_child(UiTheme.make_field_label("Amputation Side"))
	signup_amp_side = _option_button(["Left", "Right", "N/A"])
	box.add_child(signup_amp_side)

	box.add_child(UiTheme.make_field_label("Amputation Type"))
	signup_amp_type = _option_button(["Transtibial", "Transfemoral", "N/A"])
	box.add_child(signup_amp_type)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	box.add_child(button_row)

	var cancel := UiTheme.make_secondary_button("Cancel")
	cancel.pressed.connect(func(): signup_panel.visible = false)
	button_row.add_child(cancel)

	var submit := UiTheme.make_primary_button("Submit")
	submit.pressed.connect(_do_signup)
	button_row.add_child(submit)

func _option_button(options: Array) -> OptionButton:
	var ob := OptionButton.new()
	ob.custom_minimum_size = UiTheme.MIN_TOUCH_SIZE
	for opt in options:
		ob.add_item(opt)
	return ob

func _show_login() -> void:
	signup_panel.visible = false
	login_panel.visible = true
	login_hospno.grab_focus()

func _show_signup() -> void:
	login_panel.visible = false
	signup_panel.visible = true
	signup_hospno.grab_focus()

func _do_login() -> void:
	var hosp_no := login_hospno.text.strip_edges()
	if hosp_no.is_empty():
		UiTheme.set_status(message_label, "enter a hospital number.", "error")
		return
	if not SessionPaths.look_for_existing_user(hosp_no):
		UiTheme.set_status(message_label, "hospital number not found. Sign up first.", "error")
		return
	SessionPaths.trial_duration = int(login_trial_duration.text) if login_trial_duration.text.is_valid_int() else 60
	SessionPaths.create_session_folders(hosp_no)
	AppData.start_session(hosp_no)
	UiTheme.set_status(message_label, "logged in.", "success")
	get_tree().change_scene_to_file(HUB_SCENE)

func _do_signup() -> void:
	var hosp_no := signup_hospno.text.strip_edges()
	if hosp_no.is_empty():
		UiTheme.set_status(message_label, "enter a hospital number.", "error")
		return
	SessionPaths.write_to_mobbo_userlist(
		hosp_no,
		signup_name.text,
		signup_gender.get_item_text(signup_gender.selected),
		signup_age.text,
		signup_diagnosis.text,
		signup_amp_side.get_item_text(signup_amp_side.selected),
		signup_amp_type.get_item_text(signup_amp_type.selected)
	)
	UiTheme.set_status(message_label, "sign up complete. You can log in now.", "success")
	signup_panel.visible = false
