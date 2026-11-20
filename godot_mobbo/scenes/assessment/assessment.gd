extends Control
## Port of the Limits-of-Stability assessment logic in TestScene_handler.cs
## (the parts of that 1500-line file actually reachable at runtime -- its
## board-setup grid/line-renderer code and the commented-out info_update()
## guided-standing-instructions path were left out, see CLAUDE.md).
##
## Ported: the medial-lateral (left/right) reach capture -- find_Min_max_ML_
## reach / button_min_max_ml / write_csv_min_max_ml -- and the timed trial
## raw-data logging (assess_btnStrtStpLogging_Click / StartLoggingProcess /
## TimedLogging). The anterior-posterior (front/back) reach variant was not
## ported: it assumes a front-back board pair, but this rig is strictly two
## side-by-side boards (left/right), so AP reach isn't physically meaningful
## here the way it was in Unity's variable NxM board grid.
##
## Lean-detection thresholds below are this port's own choice, not Unity's:
## Unity's (COP.x < 55 / > 60) were tuned to its own multi-board grid
## coordinate frame, which doesn't carry over to this two-board, left-board-
## origin frame. These use board geometry instead (comfortably past the
## boards' shared edge, well into each board's own half) -- confirm/tune
## against real hardware.

const HUB_SCENE := "res://scenes/hub/hub.tscn"

## CSV columns match Unity's write_csv_min_max_ml() header exactly, with
## Unity's COP_player1/COP_player2 (this rig's per-board local COP) and
## W_player1/W_player2 (this rig's left/right board weight) substituted in.
const ML_CSV_HEADER := "min_x,min_%,min_left%,min_cop_x,min_cop_y,min_gcop_x,min_gcop_y,left_weight, max_x,max_right%,max_left%,max_cop_x,max_cop_y,max_gcop_x,max_gcop_y,right_weight\n"

const NO_LOAD_WEIGHT := 2.0  # kg, matches Unity's ">2f" significant-load check

## Set in _ready() -- these depend on BoardData.right_board_offset, which is
## a var (an adjustable rig-arrangement assumption), not a compile-time
## constant, so they can't be GDScript `const`s themselves.
var _lean_left_threshold_x: float
var _lean_right_threshold_x: float

var left_bar: ProgressBar
var right_bar: ProgressBar
var left_pct_label: Label
var right_pct_label: Label

var ml_button: Button
var ml_result_label: Label
var got_min := false
var got_max := false
var min_row := ""
var max_row := ""

var trial_button: Button
var timer_label: Label
var trial_label: Label
var trial_logging_status: Label
var trial_count := 0
var trial_remaining := 0.0
var trial_active := false

func _ready() -> void:
	if AppData.session == null:
		AppData.start_dummy_session()

	_lean_left_threshold_x = -BoardData.L_HALF * 0.3
	_lean_right_threshold_x = BoardData.right_board_offset.x + BoardData.L_HALF * 0.3

	theme = UiTheme.theme
	var bg := ColorRect.new()
	bg.color = UiTheme.COLOR_BACKGROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 28)
	add_child(margin)

	var scroll := ScrollContainer.new()
	margin.add_child(scroll)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	root.add_child(UiTheme.make_heading("Assessment"))
	root.add_child(UiTheme.make_muted_label("Limits-of-stability reach test and timed trial logging."))

	_build_weight_section(root)
	_build_ml_section(root)
	_build_trial_section(root)

	var back := UiTheme.make_secondary_button("Back to Hub")
	back.pressed.connect(func(): get_tree().change_scene_to_file(HUB_SCENE))
	root.add_child(back)

	SerialLink.board_updated.connect(func(_side): _refresh_live_readout())
	set_process(true)

func _build_weight_section(root: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	box.add_child(UiTheme.make_subheading("Live Weight Distribution"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)

	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left_col)
	left_col.add_child(UiTheme.make_field_label("Left board"))
	left_bar = ProgressBar.new()
	left_bar.min_value = 0
	left_bar.max_value = 100
	left_bar.show_percentage = false
	left_bar.custom_minimum_size = Vector2(0, 28)
	left_col.add_child(left_bar)
	left_pct_label = UiTheme.make_field_label("--")
	left_col.add_child(left_pct_label)

	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right_col)
	right_col.add_child(UiTheme.make_field_label("Right board"))
	right_bar = ProgressBar.new()
	right_bar.min_value = 0
	right_bar.max_value = 100
	right_bar.show_percentage = false
	right_bar.custom_minimum_size = Vector2(0, 28)
	right_col.add_child(right_bar)
	right_pct_label = UiTheme.make_field_label("--")
	right_col.add_child(right_pct_label)

func _build_ml_section(root: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	box.add_child(UiTheme.make_subheading("Medial-Lateral (Left/Right) Reach"))
	box.add_child(UiTheme.make_field_label("Lean left, capture the minimum; then lean right, capture the maximum."))

	ml_button = UiTheme.make_primary_button("Capture Min (Lean Left)")
	ml_button.pressed.connect(_on_ml_button_pressed)
	box.add_child(ml_button)

	ml_result_label = UiTheme.make_field_label("")
	box.add_child(ml_result_label)

func _build_trial_section(root: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	box.add_child(UiTheme.make_subheading("Timed Trial (Raw Data Logging)"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)

	timer_label = UiTheme.make_heading(_format_timer(SessionPaths.trial_duration))
	row.add_child(timer_label)

	var info_col := VBoxContainer.new()
	row.add_child(info_col)
	trial_label = UiTheme.make_field_label("Trial: 0")
	info_col.add_child(trial_label)
	trial_logging_status = UiTheme.make_field_label("Not started")
	info_col.add_child(trial_logging_status)

	trial_button = UiTheme.make_accent_button("Start Assessment Trial")
	trial_button.pressed.connect(_on_trial_button_pressed)
	box.add_child(trial_button)

func _process(delta: float) -> void:
	if trial_active:
		trial_remaining = max(0.0, trial_remaining - delta)
		timer_label.text = _format_timer(trial_remaining)
		timer_label.add_theme_color_override(
			"font_color", UiTheme.COLOR_DESTRUCTIVE if trial_remaining <= 5.0 else UiTheme.COLOR_TEXT
		)
		if SerialLink.has_left_data() or SerialLink.has_right_data():
			BoardData.log_trial_frame(SerialLink.left_adc, SerialLink.right_adc)
		if trial_remaining <= 0.0:
			_stop_trial()

func _format_timer(seconds: float) -> String:
	return "%d" % int(ceil(seconds))

## -- Live weight readout -------------------------------------------------

func _refresh_live_readout() -> void:
	var left_forces := SerialLink.left_forces()
	var right_forces := SerialLink.right_forces()
	var left_w := BoardData.total_weight(left_forces)
	var right_w := BoardData.total_weight(right_forces)
	if left_w > NO_LOAD_WEIGHT or right_w > NO_LOAD_WEIGHT:
		var total := left_w + right_w
		var left_pct := (left_w / total) * 100.0 if total > 0.0 else 0.0
		var right_pct := 100.0 - left_pct
		left_bar.value = left_pct
		right_bar.value = right_pct
		left_pct_label.text = "%.0f%% (%.1f kg)" % [left_pct, left_w]
		right_pct_label.text = "%.0f%% (%.1f kg)" % [right_pct, right_w]
	else:
		left_bar.value = 0
		right_bar.value = 0
		left_pct_label.text = "--"
		right_pct_label.text = "--"

## -- ML reach capture -----------------------------------------------------

func _on_ml_button_pressed() -> void:
	if not got_min:
		_try_capture_min()
	else:
		_try_capture_max()

func _try_capture_min() -> void:
	var left_forces := SerialLink.left_forces()
	var right_forces := SerialLink.right_forces()
	var left_w := BoardData.total_weight(left_forces)
	var right_w := BoardData.total_weight(right_forces)
	var cop = BoardData.combined_cop(left_forces, right_forces)
	if cop == null or left_w <= right_w or cop.x >= _lean_left_threshold_x:
		UiTheme.set_status(ml_result_label, "lean further left, then press again to capture the minimum.", "error")
		return
	var total_w := left_w + right_w
	var local_cop = BoardData.board_cop(left_forces)
	var lx: float = 0.0 if local_cop == null else local_cop.x
	var ly: float = 0.0 if local_cop == null else local_cop.y
	min_row = "%.3f,%.1f,%.1f,%.3f,%.3f,%.3f,%.3f,%.3f" % [
		cop.x, (right_w / total_w) * 100.0, (left_w / total_w) * 100.0, lx, ly, cop.x, cop.y, left_w
	]
	got_min = true
	ml_button.text = "Capture Max (Lean Right)"
	UiTheme.set_status(ml_result_label, "minimum captured (COP x = %.1f cm). Now lean right." % cop.x, "success")

func _try_capture_max() -> void:
	var left_forces := SerialLink.left_forces()
	var right_forces := SerialLink.right_forces()
	var left_w := BoardData.total_weight(left_forces)
	var right_w := BoardData.total_weight(right_forces)
	var cop = BoardData.combined_cop(left_forces, right_forces)
	if cop == null or right_w <= left_w or cop.x <= _lean_right_threshold_x:
		UiTheme.set_status(ml_result_label, "lean further right, then press again to capture the maximum.", "error")
		return
	var total_w := left_w + right_w
	var local_cop = BoardData.board_cop(right_forces)
	var rx: float = 0.0 if local_cop == null else local_cop.x
	var ry: float = 0.0 if local_cop == null else local_cop.y
	max_row = "%.3f,%.1f,%.1f,%.3f,%.3f,%.3f,%.3f,%.3f" % [
		cop.x, (right_w / total_w) * 100.0, (left_w / total_w) * 100.0, rx, ry, cop.x, cop.y, right_w
	]
	got_max = true
	_write_ml_csv()

func _write_ml_csv() -> void:
	var path := SessionPaths.assess_folder.path_join("min_max_dist_ml.csv")
	var is_new := not FileAccess.file_exists(path)
	var f: FileAccess
	if is_new:
		f = FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(ML_CSV_HEADER)
	else:
		f = FileAccess.open(path, FileAccess.READ_WRITE)
		if f:
			f.seek_end()
	if f == null:
		UiTheme.set_status(ml_result_label, "could not write assessment CSV.", "error")
		return
	f.store_line("%s, %s" % [min_row, max_row])
	f.close()

	UiTheme.set_status(ml_result_label, "ML reach recorded and saved.", "success")
	got_min = false
	got_max = false
	min_row = ""
	max_row = ""
	ml_button.text = "Capture Min (Lean Left)"

## -- Timed trial raw logging ----------------------------------------------

func _on_trial_button_pressed() -> void:
	if trial_active:
		_stop_trial()
	else:
		_start_trial()

func _start_trial() -> void:
	trial_count += 1
	trial_label.text = "Trial: %d" % trial_count
	trial_remaining = float(SessionPaths.trial_duration)
	trial_active = true

	var folder := SessionPaths.assess_folder.path_join(
		"%s%s" % [SessionPaths.hosp_num, Time.get_datetime_string_from_system().replace(":", "-")]
	)
	DirAccess.make_dir_recursive_absolute(folder)
	BoardData.start_trial_log(folder.path_join("Trial"), trial_count)

	trial_button.text = "Stop Trial"
	UiTheme.set_status(trial_logging_status, "assessment trial started.", "success")

func _stop_trial() -> void:
	trial_active = false
	BoardData.stop_trial_log()
	trial_button.text = "Start Assessment Trial"
	timer_label.text = _format_timer(SessionPaths.trial_duration)
	timer_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	UiTheme.set_status(trial_logging_status, "assessment data recorded.", "success")
