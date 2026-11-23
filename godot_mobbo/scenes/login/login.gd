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

const LOGO_H_BIG := 190.0
const LOGO_H_SMALL := 104.0
var title_logo: Control
var tagline_label: Label

func _ready() -> void:
	theme = UiTheme.theme
	var bg := UiTheme.make_background("bg_main")
	bg.color = UiTheme.COLOR_BACKGROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Main screen: animated illustration of the rig (left) + login column (right).
	var split := HBoxContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	split.add_theme_constant_override("separation", 24)
	add_child(split)
	# Rendered art if it's there (sprites/rig_hero_cut.png), else the code-drawn rig.
	var showcase: RigShowcase = RigPhotoShowcase.new() if RigPhotoShowcase.available() else RigShowcase.new()
	showcase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	showcase.size_flags_stretch_ratio = 1.1
	split.add_child(showcase)

	# Right column scrolls if a form ever doesn't fit (small windows); it
	# stays vertically centred when everything fits.
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 20)
	scroll.add_child(root)

	title_logo = UiTheme.make_app_title(LOGO_H_BIG)
	root.add_child(title_logo)
	tagline_label = UiTheme.make_muted_label("Balance-board rehab sessions")
	root.add_child(tagline_label)

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
	cancel.pressed.connect(_hide_panels)
	button_row.add_child(cancel)

	var submit := UiTheme.make_primary_button("Submit")
	submit.pressed.connect(_do_login)
	button_row.add_child(submit)

func _build_signup_panel(root: VBoxContainer) -> void:
	signup_panel = PanelContainer.new()
	signup_panel.visible = false
	signup_panel.custom_minimum_size = Vector2(540, 0)
	signup_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(signup_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	signup_panel.add_child(box)

	# Two columns so the whole form fits on screen under the logo.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)

	signup_hospno = UiTheme.make_line_edit()
	_form_cell(grid, "Hospital No.", signup_hospno)
	signup_name = UiTheme.make_line_edit()
	_form_cell(grid, "Name", signup_name)
	signup_gender = _option_button(["Male", "Female", "Other"])
	_form_cell(grid, "Gender", signup_gender)
	signup_age = UiTheme.make_line_edit()
	_form_cell(grid, "Age", signup_age)
	signup_diagnosis = UiTheme.make_line_edit()
	_form_cell(grid, "Diagnosis", signup_diagnosis)
	signup_amp_side = _option_button(["Left", "Right", "N/A"])
	_form_cell(grid, "Amputation Side", signup_amp_side)
	signup_amp_type = _option_button(["Transtibial", "Transfemoral", "N/A"])
	_form_cell(grid, "Amputation Type", signup_amp_type)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	button_row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(button_row)

	var cancel := UiTheme.make_secondary_button("Cancel")
	cancel.pressed.connect(_hide_panels)
	button_row.add_child(cancel)

	var submit := UiTheme.make_primary_button("Submit")
	submit.pressed.connect(_do_signup)
	button_row.add_child(submit)

## One form field: caption above the control, half the grid's width.
func _form_cell(grid: GridContainer, caption: String, field: Control) -> void:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 4)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(UiTheme.make_field_label(caption))
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(field)
	grid.add_child(cell)

## Shrink the big logo (and hide the tagline) while a form is open, so the
## form has room; grow it back when the form closes.
func _set_compact(on: bool) -> void:
	tagline_label.visible = not on
	var h := LOGO_H_SMALL if on else LOGO_H_BIG
	var tw := title_logo.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(title_logo, "custom_minimum_size", Vector2(h * 3.15, h), 0.3)

func _hide_panels() -> void:
	login_panel.visible = false
	signup_panel.visible = false
	_set_compact(false)

func _option_button(options: Array) -> OptionButton:
	var ob := OptionButton.new()
	ob.custom_minimum_size = UiTheme.MIN_TOUCH_SIZE
	for opt in options:
		ob.add_item(opt)
	return ob

func _show_login() -> void:
	signup_panel.visible = false
	_set_compact(true)
	UiTheme.pop_in(login_panel)
	login_hospno.grab_focus()

func _show_signup() -> void:
	login_panel.visible = false
	_set_compact(true)
	UiTheme.pop_in(signup_panel)
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
	_hide_panels()
