extends Control
## Sit Assessment + Force Display in one screen.
##
## Left column: live per-sensor force and centre of pressure for both boards
## (port of force.cs -- corner dot/text scaled by load, COP marker) plus the
## live left/right weight split. Right column: the Limits-of-Stability
## assessment from TestScene_handler.cs.
##
## Ported from TestScene_handler.cs: the medial-lateral (left/right) reach
## capture -- find_Min_max_ML_reach / button_min_max_ml / write_csv_min_max_ml --
## and the timed trial raw-data logging (assess_btnStrtStpLogging_Click /
## StartLoggingProcess / TimedLogging). The anterior-posterior reach variant
## was not ported: this rig is strictly two side-by-side boards, so AP reach
## isn't physically meaningful here the way it was in Unity's NxM board grid.
##
## Lean-detection thresholds below are this port's own choice, not Unity's:
## Unity's (COP.x < 55 / > 60) were tuned to its own multi-board grid frame.
## These use board geometry instead (comfortably past the boards' shared
## edge, well into each board's own half) -- confirm/tune against hardware.

const HUB_SCENE := "res://scenes/hub/hub.tscn"
## A COP (per board or combined) is only drawn above this load, so sensor
## noise on an empty board doesn't throw the marker around.
const COP_MIN_WEIGHT := 1.0  # kg
## Board/total weights are only displayed above this; below it they read 0.
const WEIGHT_DISPLAY_MIN := 0.5  # kg

## CSV columns match Unity's write_csv_min_max_ml() header exactly, with
## Unity's COP_player1/COP_player2 (this rig's per-board local COP) and
## W_player1/W_player2 (this rig's left/right board weight) substituted in.
const ML_CSV_HEADER := "min_x,min_%,min_left%,min_cop_x,min_cop_y,min_gcop_x,min_gcop_y,left_weight, max_x,max_right%,max_left%,max_cop_x,max_cop_y,max_gcop_x,max_gcop_y,right_weight\n"

const NO_LOAD_WEIGHT := 2.0  # kg, matches Unity's ">2f" significant-load check

## Set in _ready() -- these depend on BoardData.right_board_offset, which is
## a var (an adjustable rig-arrangement assumption), not a compile-time const.
var _lean_left_threshold_x: float
var _lean_right_threshold_x: float

# Connection
var connection_label: Label
var auto_button: Button

# Force display
var board_view: DualBoardView
var combined_label: Label

# Weight
var weight_chart: WeightBarChart
var total_label: Label

# ML reach
var ml_button: Button
var ml_result_label: Label
var got_min := false
var got_max := false
var min_row := ""
var max_row := ""

# Timed trial
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
	var bg := UiTheme.make_background()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 20)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	# Fills the screen; only scrolls if the window is smaller than the content.
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	_build_header(root)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	# Left: boards on top, reach + trial cards underneath.
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 18)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 2.4
	columns.add_child(left_col)
	_build_force_section(left_col)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 18)
	left_col.add_child(bottom_row)
	_build_ml_section(bottom_row)
	_build_trial_section(bottom_row)

	# Right: full-height weight bar chart.
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_col)
	_build_weight_section(right_col)

	SerialLink.board_updated.connect(func(_side): _refresh_live())
	SerialLink.status_changed.connect(func(t): UiTheme.set_status(connection_label, t, "neutral"))
	SerialLink.error.connect(func(t): UiTheme.set_status(connection_label, t, "error"))
	SerialLink.auto_connect_finished.connect(_on_auto_connect_finished)
	_refresh_live()
	set_process(true)

## -- Layout -------------------------------------------------------------------

func _build_header(root: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(titles)
	titles.add_child(UiTheme.make_eyebrow("Sit assessment  ·  live force & centre of pressure"))
	var title := UiTheme.make_heading("Assessment")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	titles.add_child(title)
	connection_label = UiTheme.make_field_label(_connection_text())
	connection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(connection_label)

	auto_button = UiTheme.make_accent_button("Auto connect")
	auto_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	auto_button.pressed.connect(_on_auto_connect_pressed)
	row.add_child(auto_button)

	var back := UiTheme.make_secondary_button("Back to Hub")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_go_back)
	row.add_child(back)

## expand_v: the card (and its last child) grows to fill the column height.
func _make_card(parent: Control, eyebrow: String, title: String, expand_v := false) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if expand_v:
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(UiTheme.make_eyebrow(eyebrow))
	var t := UiTheme.make_subheading(title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(t)
	return box

func _build_force_section(parent: VBoxContainer) -> void:
	var box := _make_card(parent, "Force display", "Per-sensor force (kg) and centre of pressure", true)

	board_view = DualBoardView.new()
	board_view.custom_minimum_size = Vector2(560, 170)
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(board_view)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 18)
	box.add_child(footer)
	combined_label = UiTheme.make_field_label("Combined COP: waiting for data")
	combined_label.add_theme_color_override("font_color", UiTheme.COLOR_YELLOW)
	combined_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(combined_label)
	footer.add_child(_legend_item(UiTheme.COLOR_DESTRUCTIVE, "Board COP"))
	footer.add_child(_legend_item(UiTheme.COLOR_YELLOW, "Combined COP"))
	footer.add_child(UiTheme.make_field_label("COP shown above %.0f kg" % COP_MIN_WEIGHT))

func _legend_item(color: Color, text: String) -> Label:
	var l := UiTheme.make_field_label("●  " + text)
	l.add_theme_color_override("font_color", color)
	return l

func _build_weight_section(parent: VBoxContainer) -> void:
	var box := _make_card(parent, "Weight", "Board and total weight", true)

	var total_row := HBoxContainer.new()
	total_row.add_theme_constant_override("separation", 10)
	box.add_child(total_row)
	total_label = UiTheme.make_value_label("-- kg")
	total_row.add_child(total_label)
	var cap := UiTheme.make_field_label("total")
	cap.size_flags_vertical = Control.SIZE_SHRINK_END
	total_row.add_child(cap)

	weight_chart = WeightBarChart.new()
	weight_chart.custom_minimum_size = Vector2(260, 220)
	weight_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(weight_chart)

func _build_ml_section(parent: Control) -> void:
	var box := _make_card(parent, "Limits of stability", "Medial-lateral reach")
	var hint := UiTheme.make_field_label("Lean left and capture the minimum, then lean right and capture the maximum.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	ml_button = UiTheme.make_primary_button("Capture min (lean left)")
	ml_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ml_button.pressed.connect(_on_ml_button_pressed)
	box.add_child(ml_button)

	ml_result_label = UiTheme.make_field_label("")
	ml_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(ml_result_label)

func _build_trial_section(parent: Control) -> void:
	var box := _make_card(parent, "Raw data logging", "Timed trial")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)

	timer_label = UiTheme.make_value_label(_format_timer(SessionPaths.trial_duration))
	row.add_child(timer_label)

	var info_col := VBoxContainer.new()
	info_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info_col)
	trial_label = UiTheme.make_field_label("Trial: 0")
	info_col.add_child(trial_label)
	trial_logging_status = UiTheme.make_field_label("Not started")
	info_col.add_child(trial_logging_status)

	trial_button = UiTheme.make_accent_button("Start trial")
	trial_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	trial_button.pressed.connect(_on_trial_button_pressed)
	box.add_child(trial_button)

## -- Connection -------------------------------------------------------------

func _connection_text() -> String:
	if SerialLink.left_port != "" or SerialLink.right_port != "":
		return "Left: %s   ·   Right: %s" % [
			SerialLink.left_port if SerialLink.left_port != "" else "not found",
			SerialLink.right_port if SerialLink.right_port != "" else "not found",
		]
	return "Boards not connected. Press Auto connect with both boards unloaded."

func _on_auto_connect_pressed() -> void:
	auto_button.disabled = true
	auto_button.text = "Scanning..."
	SerialLink.auto_connect()

func _on_auto_connect_finished(_ok: bool, _left_port: String, _right_port: String) -> void:
	auto_button.disabled = false
	auto_button.text = "Auto connect"

func _go_back() -> void:
	if trial_active:
		_stop_trial()
	get_tree().change_scene_to_file(HUB_SCENE)

## -- Per-frame ----------------------------------------------------------------

func _process(delta: float) -> void:
	if trial_active:
		trial_remaining = max(0.0, trial_remaining - delta)
		timer_label.text = _format_timer(trial_remaining)
		timer_label.add_theme_color_override(
			"font_color", UiTheme.COLOR_DESTRUCTIVE if trial_remaining <= 5.0 else UiTheme.COLOR_YELLOW
		)
		if SerialLink.has_left_data() or SerialLink.has_right_data():
			BoardData.log_trial_frame(SerialLink.left_adc, SerialLink.right_adc)
		if trial_remaining <= 0.0:
			_stop_trial()

func _format_timer(seconds: float) -> String:
	return "%d s" % int(ceil(seconds))

## -- Live force / COP / weight split -------------------------------------------

func _refresh_live() -> void:
	var lf := SerialLink.left_forces()
	var rf := SerialLink.right_forces()
	var has_l := SerialLink.has_left_data()
	var has_r := SerialLink.has_right_data()
	# Weights at or below the display threshold read as 0 (sensor noise).
	var left_w := _shown_weight(BoardData.total_weight(lf))
	var right_w := _shown_weight(BoardData.total_weight(rf))

	# Per-board COP only above the load threshold.
	var l_cop = BoardData.board_cop(lf) if has_l and left_w > COP_MIN_WEIGHT else null
	var r_cop = BoardData.board_cop(rf) if has_r and right_w > COP_MIN_WEIGHT else null

	# Combined COP over whichever boards are streaming; a missing board
	# counts as unloaded.
	var zero := [0.0, 0.0, 0.0, 0.0]
	var total_w := (left_w if has_l else 0.0) + (right_w if has_r else 0.0)
	var c_cop = null
	if (has_l or has_r) and total_w > COP_MIN_WEIGHT:
		c_cop = BoardData.combined_cop(lf if has_l else zero, rf if has_r else zero)

	board_view.set_data(lf, l_cop, rf, r_cop, c_cop,
		"W = %.2f kg" % left_w if has_l else "W = -- kg",
		"W = %.2f kg" % right_w if has_r else "W = -- kg")

	if not (has_l or has_r):
		combined_label.text = "Combined COP: waiting for data"
	elif c_cop == null:
		combined_label.text = "Combined COP: below %.0f kg" % COP_MIN_WEIGHT
	else:
		combined_label.text = "Combined COP (left-board origin): (%.1f, %.1f) cm" % [c_cop.x, c_cop.y]

	weight_chart.set_values(left_w, right_w, has_l, has_r)
	total_label.text = "%.1f kg" % total_w if (has_l or has_r) else "-- kg"

	if not connection_label.text.begins_with("Error") and not connection_label.text.begins_with("Auto"):
		connection_label.text = _connection_text()

func _shown_weight(w: float) -> float:
	return w if w > WEIGHT_DISPLAY_MIN else 0.0

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
	ml_button.text = "Capture max (lean right)"
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
	ml_button.text = "Capture min (lean left)"

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

	trial_button.text = "Stop trial"
	UiTheme.set_status(trial_logging_status, "assessment trial started.", "success")

func _stop_trial() -> void:
	trial_active = false
	BoardData.stop_trial_log()
	trial_button.text = "Start trial"
	timer_label.text = _format_timer(SessionPaths.trial_duration)
	timer_label.add_theme_color_override("font_color", UiTheme.COLOR_YELLOW)
	UiTheme.set_status(trial_logging_status, "assessment data recorded.", "success")
