extends Control
## Sit Assessment + Force Display in one screen.
##
## Left column: live per-sensor force and centre of pressure for both boards
## (port of force.cs -- corner dot/text scaled by load, COP marker) plus the
## live left/right weight split. Right column: the Limits-of-Stability
## assessment from TestScene_handler.cs.
##
## Ported from TestScene_handler.cs: the medial-lateral (left/right) reach
## capture (same min_max_dist_ml.csv layout as write_csv_min_max_ml) and the
## timed trial raw-data logging. Added: an anterior-posterior (front/back)
## reach capture writing min_max_dist_ap.csv, used by Floppy Bird. Both
## captures record the furthest combined COP reached while recording,
## instead of Unity's press-at-the-extreme with fixed lean thresholds.

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

## AP file is new (Unity had no AP capture for this rig). Combined-COP frame,
## cm; y = front(+)/back(-). Floppy Bird reads min_gcop_y / max_gcop_y.
const AP_CSV_HEADER := "min_gcop_x,min_gcop_y,min_weight,max_gcop_x,max_gcop_y,max_weight,range_y\n"

const NO_LOAD_WEIGHT := 2.0  # kg, matches Unity's ">2f" significant-load check
const MIN_REACH_RANGE := 2.0  # cm; a smaller range is almost certainly no lean at all
const DEFAULT_TRIAL_SECONDS := 60
var _reach_log_axis := ""  # which reach capture owns the current raw log

# Connection
var connection_label: Label
var auto_button: Button

# Force display
var board_view: DualBoardView
var combined_label: Label

# Weight
var weight_chart: WeightBarChart
var total_label: Label

# Reach capture, per axis ("ml", "ap"): active, min/max snapshots, widgets.
var _reach := {}

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
	_live_view = columns

	# Second tab: whole-file analysis + PDF report (hidden until selected).
	_analysis_view = AnalysisView.new()
	_analysis_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_analysis_view.visible = false
	root.add_child(_analysis_view)

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
	_build_reach_section(bottom_row, "ml")
	_build_reach_section(bottom_row, "ap")
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

## -- Tabs ---------------------------------------------------------------------

var _live_view: Control
var _analysis_view: AnalysisView

func _show_tab(analysis: bool) -> void:
	_live_view.visible = not analysis
	_analysis_view.visible = analysis
	if analysis:
		_analysis_view.refresh_list()  # pick up recordings made in this visit

func _tab_pressed_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTheme.COLOR_YELLOW, 0.12)
	sb.border_color = UiTheme.COLOR_YELLOW
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(UiTheme.CORNER_RADIUS)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

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

	# Tabs: live assessment / analysis & report.
	var group := ButtonGroup.new()
	for tab in [["Live assessment", false], ["Analysis & report", true]]:
		var b := UiTheme.make_secondary_button(tab[0])
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = not tab[1]
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(_show_tab.bind(tab[1]))
		b.add_theme_stylebox_override("pressed", _tab_pressed_box())
		b.add_theme_color_override("font_pressed_color", UiTheme.COLOR_YELLOW)
		row.add_child(b)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(12, 0)
	row.add_child(spacer)

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

## One limits-of-stability card per axis ("ml" = left/right, "ap" =
## back/front); state lives in _reach[axis].
func _build_reach_section(parent: Control, axis: String) -> void:
	var ml := axis == "ml"
	var box := _make_card(parent, "Limits of stability",
		"Medial-lateral reach" if ml else "Anterior-posterior reach")
	var hint := UiTheme.make_field_label(
		"Start, lean fully left then right, then Stop & save." if ml
		else "Start, lean fully forward then back, then Stop & save.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	var start_text := "Start ML capture" if ml else "Start AP capture"
	var button := UiTheme.make_primary_button(start_text)
	button.pressed.connect(_on_reach_pressed.bind(axis))
	box.add_child(button)

	var readout := UiTheme.make_field_label("Left -- · Right --" if ml else "Back -- · Front --")
	readout.add_theme_color_override("font_color", UiTheme.COLOR_YELLOW)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # never widen the card
	box.add_child(readout)

	var status := UiTheme.make_field_label("")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)

	_reach[axis] = {
		"active": false, "min": null, "max": null,
		"button": button, "start_text": start_text, "readout": readout, "status": status,
	}

func _build_trial_section(parent: Control) -> void:
	var box := _make_card(parent, "Raw data logging", "Timed trial")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)

	timer_label = UiTheme.make_value_label(_format_timer(_trial_seconds()))
	row.add_child(timer_label)

	var info_col := VBoxContainer.new()
	info_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # gives the wrapping label a width
	row.add_child(info_col)
	trial_label = UiTheme.make_field_label("Trial: 0")
	info_col.add_child(trial_label)
	trial_logging_status = UiTheme.make_field_label("Not started")
	# Status messages wrap instead of widening the card, which pushed the
	# Weight column off the right edge of the screen during a trial.
	trial_logging_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

	_sample_reach(lf, rf, has_l, has_r)
	weight_chart.set_values(left_w, right_w, has_l, has_r)
	total_label.text = "%.1f kg" % total_w if (has_l or has_r) else "-- kg"

	if not connection_label.text.begins_with("Error") and not connection_label.text.begins_with("Auto"):
		connection_label.text = _connection_text()

func _shown_weight(w: float) -> float:
	return w if w > WEIGHT_DISPLAY_MIN else 0.0

## -- Reach capture (ML + AP) ---------------------------------------------
## Press Start, the patient leans as far as they can both ways, press Stop &
## save. While recording, every sample with real load updates the furthest
## combined COP reached in each direction, so no lean threshold has to be
## hit at the exact moment a button is pressed (the old press-at-the-extreme
## flow kept rejecting genuine leans).

func _sample_reach(lf: Array, rf: Array, has_l: bool, has_r: bool) -> void:
	if not (_reach.ml.active or _reach.ap.active):
		return
	var zero := [0.0, 0.0, 0.0, 0.0]
	var l := lf if has_l else zero
	var r := rf if has_r else zero
	var lw := BoardData.total_weight(l)
	var rw := BoardData.total_weight(r)
	if lw + rw <= NO_LOAD_WEIGHT:
		return
	var c = BoardData.combined_cop(l, r)
	if c == null:
		return
	var snap := {"cop": c, "lf": l.duplicate(), "rf": r.duplicate(), "lw": lw, "rw": rw}
	for axis in ["ml", "ap"]:
		var st: Dictionary = _reach[axis]
		if not st.active:
			continue
		var v: float = c.x if axis == "ml" else c.y
		if st.min == null or v < _axis_value(st.min, axis):
			st.min = snap
		if st.max == null or v > _axis_value(st.max, axis):
			st.max = snap
		_update_reach_readout(axis)

func _axis_value(snap: Dictionary, axis: String) -> float:
	return snap.cop.x if axis == "ml" else snap.cop.y

func _update_reach_readout(axis: String) -> void:
	var st: Dictionary = _reach[axis]
	if st.min == null:
		st.readout.text = "Waiting for load on the boards..."
		return
	var lo := _axis_value(st.min, axis)
	var hi := _axis_value(st.max, axis)
	var names := ["Left", "Right"] if axis == "ml" else ["Back", "Front"]
	st.readout.text = "%s %.1f cm   ·   %s %.1f cm   ·   Range %.1f cm" % [names[0], lo, names[1], hi, hi - lo]

func _on_reach_pressed(axis: String) -> void:
	var st: Dictionary = _reach[axis]
	if not st.active:
		if not (SerialLink.has_left_data() or SerialLink.has_right_data()):
			UiTheme.set_status(st.status, "no board data. Press Auto connect first.", "error")
			return
		st.active = true
		st.min = null
		st.max = null
		st.button.text = "Stop & save"
		_update_reach_readout(axis)
		_start_reach_raw_log(axis)
		var how := "left and right" if axis == "ml" else "forward and back"
		UiTheme.set_status(st.status, "recording: lean as far %s as you can." % how, "neutral")
		return
	st.active = false
	st.button.text = st.start_text
	if _reach_log_axis == axis:
		_stop_reach_raw_log()
	if st.min == null or _axis_value(st.max, axis) - _axis_value(st.min, axis) < MIN_REACH_RANGE:
		UiTheme.set_status(st.status, "range under %.0f cm, not saved. Lean further and try again." % MIN_REACH_RANGE, "error")
		return
	var ok: bool = _write_ml_csv(st.min, st.max) if axis == "ml" else _write_ap_csv(st.min, st.max)
	if ok:
		UiTheme.set_status(st.status, "saved; games use this range.", "success")
		SessionPaths.log_event("%s reach saved: %.1f to %.1f cm" % [
			axis.to_upper(), _axis_value(st.min, axis), _axis_value(st.max, axis)])
	else:
		UiTheme.set_status(st.status, "could not write the assessment CSV.", "error")

## Unity's ML row layout: COP x, right %, left %, the leaning board's local
## COP, combined COP, the leaning board's weight -- for the min, then the max.
func _ml_fields(s: Dictionary, lean_side: String) -> String:
	var total: float = s.lw + s.rw
	var forces: Array = s.lf if lean_side == "left" else s.rf
	var local = BoardData.board_cop(forces)
	var lx: float = 0.0 if local == null else local.x
	var ly: float = 0.0 if local == null else local.y
	return "%.3f,%.1f,%.1f,%.3f,%.3f,%.3f,%.3f,%.3f" % [
		s.cop.x, s.rw / total * 100.0, s.lw / total * 100.0, lx, ly, s.cop.x, s.cop.y,
		s.lw if lean_side == "left" else s.rw,
	]

func _write_ml_csv(mn: Dictionary, mx: Dictionary) -> bool:
	return _append_csv("min_max_dist_ml.csv", ML_CSV_HEADER,
		"%s, %s" % [_ml_fields(mn, "left"), _ml_fields(mx, "right")])

func _write_ap_csv(mn: Dictionary, mx: Dictionary) -> bool:
	var row := "%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f" % [
		mn.cop.x, mn.cop.y, mn.lw + mn.rw, mx.cop.x, mx.cop.y, mx.lw + mx.rw, mx.cop.y - mn.cop.y
	]
	return _append_csv("min_max_dist_ap.csv", AP_CSV_HEADER, row)

func _append_csv(file_name: String, header: String, row: String) -> bool:
	SessionPaths.ensure_session()
	DirAccess.make_dir_recursive_absolute(SessionPaths.assess_folder)
	var path := SessionPaths.assess_folder.path_join(file_name)
	var is_new := not FileAccess.file_exists(path)
	var f := FileAccess.open(path, FileAccess.WRITE if is_new else FileAccess.READ_WRITE)
	if f == null:
		return false
	if is_new:
		f.store_string(header)
	else:
		f.seek_end()
	f.store_line(row)
	f.close()
	SessionPaths.invalidate_limits()  # games pick up the new range immediately
	return true

## -- Timed trial raw logging ----------------------------------------------

func _on_trial_button_pressed() -> void:
	if trial_active:
		_stop_trial()
	else:
		_start_trial()

func _start_trial() -> void:
	trial_count += 1
	trial_label.text = "Trial: %d" % trial_count
	trial_remaining = float(_trial_seconds())
	trial_active = true
	_stop_reach_raw_log()  # one raw file at a time; the trial takes over

	SessionPaths.ensure_session()
	var folder := SessionPaths.assess_folder.path_join(
		"%s%s" % [SessionPaths.hosp_num, SessionPaths.file_stamp()]
	)
	BoardData.start_trial_log(folder.path_join("Trial"), trial_count)
	SessionPaths.log_event("sit assessment trial %d started (%d s)" % [trial_count, _trial_seconds()])

	trial_button.text = "Stop trial"
	UiTheme.set_status(trial_logging_status, "recording.", "success")

func _stop_trial() -> void:
	trial_active = false
	BoardData.stop_trial_log()
	trial_button.text = "Start trial"
	timer_label.text = _format_timer(_trial_seconds())
	timer_label.add_theme_color_override("font_color", UiTheme.COLOR_YELLOW)
	UiTheme.set_status(trial_logging_status, "trial saved.", "success")

## Login sets the trial length; opened without login it would be 0 s.
func _trial_seconds() -> int:
	return SessionPaths.trial_duration if SessionPaths.trial_duration > 0 else DEFAULT_TRIAL_SECONDS

## Reach captures also record the full raw trajectory (Rawdata-style file
## in assessment/), unless a timed trial is already recording.
func _start_reach_raw_log(axis: String) -> void:
	if trial_active or BoardData.is_trial_logging:
		return
	SessionPaths.ensure_session()
	var path := SessionPaths.assess_folder.path_join("%s_reach_%s" % [axis.to_upper(), SessionPaths.file_stamp()])
	BoardData.start_trial_log(path, 1)
	_reach_log_axis = axis

func _stop_reach_raw_log() -> void:
	if _reach_log_axis != "":
		BoardData.stop_trial_log()
		_reach_log_axis = ""

func _exit_tree() -> void:
	_stop_reach_raw_log()
	if trial_active:
		trial_active = false
		BoardData.stop_trial_log()
