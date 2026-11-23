extends Control
## MoBBo Setup: the rig settings that every other screen uses.
##   Board layout tab -- Left/Right (default) or Top/Bottom, plus the gap
##     between the boards. Saved per PC (BoardData.save_rig_config) and
##     applied immediately; a live preview shows the combined COP so the
##     choice can be checked by leaning.
##   Calibration tab  -- zero the boards, place a known weight at several
##     places on one board, capture each, and apply the computed per-sensor
##     factors (see Calibration for the maths).

const HUB_SCENE := "res://scenes/hub/hub.tscn"
const CAPTURE_SECONDS := 1.5
const POSITIONS := ["Centre", "Front-left corner", "Front-right corner", "Back-right corner", "Back-left corner", "Other"]

var connection_label: Label
var auto_button: Button
var _layout_page: Control
var _calib_page: Control

# Layout tab
var _lr_box: CheckBox
var _tb_box: CheckBox
var _gap_spin: SpinBox
var _layout_status: Label
var _preview: DualBoardView

# Calibration tab
var _board_pick: OptionButton
var _weight_spin: SpinBox
var _pos_pick: OptionButton
var _capture_button: Button
var _live_label: Label
var _points_list: ItemList
var _result_box: VBoxContainer
var _calib_status: Label
var _apply_button: Button
var _points: Array = []         # {"known", "d", "pos"} for the selected board
var _solution: Dictionary = {}
var _capturing := false
var _cap_sum := [0.0, 0.0, 0.0, 0.0]
var _cap_n := 0
var _cap_until_ms := 0

func _ready() -> void:
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

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)
	_build_header(root)

	_layout_page = _build_layout_page()
	root.add_child(_layout_page)
	_calib_page = _build_calibration_page()
	_calib_page.visible = false
	root.add_child(_calib_page)

	SerialLink.board_updated.connect(_on_board_updated)
	SerialLink.status_changed.connect(func(t): UiTheme.set_status(connection_label, t, "neutral"))
	SerialLink.error.connect(func(t): UiTheme.set_status(connection_label, t, "error"))
	SerialLink.auto_connect_finished.connect(func(_ok, _l, _r):
		auto_button.disabled = false
		auto_button.text = "Auto connect"
		_refresh_names())
	_refresh_names()

## -- Header / tabs -------------------------------------------------------

func _build_header(root: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(titles)
	titles.add_child(UiTheme.make_eyebrow("Hardware  ·  rig layout & calibration"))
	var title := UiTheme.make_heading("MoBBo Setup")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	titles.add_child(title)
	connection_label = UiTheme.make_field_label(_connection_text())
	connection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(connection_label)

	var group := ButtonGroup.new()
	for tab in [["Board layout", false], ["Calibration", true]]:
		var b := UiTheme.make_secondary_button(tab[0])
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = not tab[1]
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_theme_stylebox_override("pressed", _tab_pressed_box())
		b.add_theme_color_override("font_pressed_color", UiTheme.COLOR_YELLOW)
		b.pressed.connect(func():
			_layout_page.visible = not tab[1]
			_calib_page.visible = tab[1])
		row.add_child(b)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(12, 0)
	row.add_child(spacer)

	auto_button = UiTheme.make_accent_button("Auto connect")
	auto_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	auto_button.pressed.connect(func():
		auto_button.disabled = true
		auto_button.text = "Scanning..."
		SerialLink.auto_connect())
	row.add_child(auto_button)
	var back := UiTheme.make_secondary_button("Back to Hub")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): get_tree().change_scene_to_file(HUB_SCENE))
	row.add_child(back)

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

func _connection_text() -> String:
	if SerialLink.left_port != "" or SerialLink.right_port != "":
		return "%s: %s   ·   %s: %s" % [
			BoardData.board_title("left"), SerialLink.left_port if SerialLink.left_port != "" else "not found",
			BoardData.board_title("right"), SerialLink.right_port if SerialLink.right_port != "" else "not found",
		]
	return "Boards not connected. Press Auto connect with both boards empty."

func _card(parent: Control, eyebrow: String, title: String, expand_h := true) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if expand_h:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(UiTheme.make_eyebrow(eyebrow))
	var t := UiTheme.make_subheading(title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(t)
	return box

func _wrap_label(text: String) -> Label:
	var l := UiTheme.make_field_label(text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## -- Board layout tab ----------------------------------------------------

func _build_layout_page() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var box := _card(page, "Board layout", "How are the two boards placed?")
	box.get_parent().size_flags_stretch_ratio = 0.8
	var group := ButtonGroup.new()
	_lr_box = CheckBox.new()
	_lr_box.text = "Left / Right  (default)"
	_lr_box.button_group = group
	box.add_child(_lr_box)
	box.add_child(_wrap_label("Side by side. Board 0 = LEFT, board 1 = RIGHT. Combined COP origin = left board centre; the boards extend along x."))
	_tb_box = CheckBox.new()
	_tb_box.text = "Top / Bottom"
	_tb_box.button_group = group
	box.add_child(_tb_box)
	box.add_child(_wrap_label("One behind the other. Board 0 = TOP (front), board 1 = BOTTOM (behind). Combined COP origin = top board centre; x stays the same, the AP (y) range doubles."))
	(_tb_box if BoardData.is_top_bottom() else _lr_box).button_pressed = true
	_lr_box.toggled.connect(_on_layout_toggled)
	_tb_box.toggled.connect(_on_layout_toggled)

	var gap_row := HBoxContainer.new()
	gap_row.add_theme_constant_override("separation", 10)
	box.add_child(gap_row)
	gap_row.add_child(UiTheme.make_field_label("Gap between the boards (cm)"))
	_gap_spin = SpinBox.new()
	_gap_spin.min_value = 0.0
	_gap_spin.max_value = 60.0
	_gap_spin.step = 0.5
	_gap_spin.value = BoardData.board_gap_cm
	_gap_spin.value_changed.connect(func(_v): _apply_layout())
	gap_row.add_child(_gap_spin)

	_layout_status = _wrap_label("")
	box.add_child(_layout_status)
	box.add_child(_wrap_label("Games and the Sit Assessment scale to the reach captured in the current layout. After switching layout, capture ML and AP reach again in Sit Assessment. Recordings made in either layout are analysed with the layout they were recorded in."))

	var prev := _card(page, "Live preview", "Lean to check: the yellow dot is the combined COP")
	_preview = DualBoardView.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(400, 260)
	prev.add_child(_preview)
	_show_layout_status()
	return page

func _on_layout_toggled(on: bool) -> void:
	if on:
		_apply_layout()

func _apply_layout() -> void:
	BoardData.set_layout("tb" if _tb_box.button_pressed else "lr", _gap_spin.value)
	SessionPaths.log_event("rig layout set: %s, gap %.1f cm" % [BoardData.layout, BoardData.board_gap_cm])
	_show_layout_status()
	_refresh_names()

func _show_layout_status() -> void:
	var off := BoardData.right_board_offset
	UiTheme.set_status(_layout_status, "saved: %s; %s board centre at x %+.1f, y %+.1f cm from the %s board centre." % [
		"top / bottom" if BoardData.is_top_bottom() else "left / right",
		BoardData.board_name("right"), off.x, off.y, BoardData.board_name("left")], "success")

## Names follow the layout everywhere on this screen.
func _refresh_names() -> void:
	connection_label.text = _connection_text()
	if _board_pick != null:
		var sel := maxi(_board_pick.selected, 0)
		_board_pick.clear()
		_board_pick.add_item("Board 0 - %s" % BoardData.board_name("left"))
		_board_pick.add_item("Board 1 - %s" % BoardData.board_name("right"))
		_board_pick.select(sel)

## -- Calibration tab -----------------------------------------------------

func _build_calibration_page() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var box := _card(page, "Calibration", "Known weight at several places")
	box.add_child(_wrap_label("1. Empty both boards and press Zero.   2. Choose the board and enter the known weight.   3. Place the weight, wait until it is still, press Capture. Repeat near each corner and at the centre (5+ points).   4. Check the result and press Apply."))

	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 10)
	box.add_child(r1)
	var zero := UiTheme.make_secondary_button("Zero (boards empty)")
	zero.pressed.connect(func():
		SerialLink.retare()
		UiTheme.set_status(_calib_status, "zeroing... keep both boards empty for a moment.", "neutral"))
	r1.add_child(zero)
	_board_pick = OptionButton.new()
	_board_pick.custom_minimum_size = UiTheme.MIN_TOUCH_SIZE
	_board_pick.item_selected.connect(func(_i): _clear_points())
	r1.add_child(_board_pick)

	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 10)
	box.add_child(r2)
	r2.add_child(UiTheme.make_field_label("Known weight (kg)"))
	_weight_spin = SpinBox.new()
	_weight_spin.min_value = 0.5
	_weight_spin.max_value = 200.0
	_weight_spin.step = 0.01
	_weight_spin.value = 20.0
	r2.add_child(_weight_spin)
	r2.add_child(UiTheme.make_field_label("Placed at"))
	_pos_pick = OptionButton.new()
	_pos_pick.custom_minimum_size = UiTheme.MIN_TOUCH_SIZE
	for p in POSITIONS:
		_pos_pick.add_item(p)
	r2.add_child(_pos_pick)

	var r3 := HBoxContainer.new()
	r3.add_theme_constant_override("separation", 10)
	box.add_child(r3)
	_capture_button = UiTheme.make_primary_button("Capture point")
	_capture_button.pressed.connect(_start_capture)
	r3.add_child(_capture_button)
	var undo := UiTheme.make_secondary_button("Remove last")
	undo.pressed.connect(func():
		if not _points.is_empty():
			_points.pop_back()
			_update_points())
	r3.add_child(undo)
	var clear := UiTheme.make_destructive_button("Clear points")
	clear.pressed.connect(_clear_points)
	r3.add_child(clear)

	_live_label = UiTheme.make_value_label("-- kg")
	box.add_child(_live_label)
	box.add_child(UiTheme.make_field_label("Selected board now reads (current calibration)"))
	_points_list = ItemList.new()
	_points_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_points_list.custom_minimum_size = Vector2(0, 120)
	_points_list.add_theme_font_size_override("font_size", 13)
	box.add_child(_points_list)

	var res := _card(page, "Result", "Calibration factors for this board")
	_result_box = VBoxContainer.new()
	_result_box.add_theme_constant_override("separation", 6)
	_result_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	res.add_child(_result_box)
	var r4 := HBoxContainer.new()
	r4.add_theme_constant_override("separation", 10)
	res.add_child(r4)
	_apply_button = UiTheme.make_accent_button("Apply & save")
	_apply_button.disabled = true
	_apply_button.pressed.connect(_apply_calibration)
	r4.add_child(_apply_button)
	var reset := UiTheme.make_destructive_button("Reset board to factory")
	reset.pressed.connect(_reset_calibration)
	r4.add_child(reset)
	_calib_status = _wrap_label("")
	res.add_child(_calib_status)
	_update_points()
	return page

func _slot() -> String:
	return "left" if _board_pick.selected <= 0 else "right"

func _clear_points() -> void:
	_points.clear()
	_update_points()

func _start_capture() -> void:
	var has: bool = SerialLink.has_left_data() if _slot() == "left" else SerialLink.has_right_data()
	if not has:
		UiTheme.set_status(_calib_status, "no zeroed data from this board yet. Connect, then press Zero with the boards empty.", "error")
		return
	_capturing = true
	_cap_sum = [0.0, 0.0, 0.0, 0.0]
	_cap_n = 0
	_cap_until_ms = Time.get_ticks_msec() + int(CAPTURE_SECONDS * 1000.0)
	_capture_button.disabled = true
	_capture_button.text = "Hold still..."

func _on_board_updated(side: String) -> void:
	if _calib_page == null:
		return
	var slot := _slot()
	if side == slot:
		var has: bool = SerialLink.has_left_data() if slot == "left" else SerialLink.has_right_data()
		var f: Array = SerialLink.left_forces() if slot == "left" else SerialLink.right_forces()
		_live_label.text = "%.2f kg" % BoardData.total_weight(f) if has else "-- kg"
		if _capturing:
			var adc: Array = SerialLink.left_adc if slot == "left" else SerialLink.right_adc
			var tare: Array = BoardData.left_tare_adc if slot == "left" else BoardData.right_tare_adc
			if tare.size() == 4:
				for i in 4:
					_cap_sum[i] += float(adc[i]) - tare[i]
				_cap_n += 1
			if Time.get_ticks_msec() >= _cap_until_ms:
				_finish_capture()
	if _preview != null and _layout_page.visible:
		_refresh_preview()

func _finish_capture() -> void:
	_capturing = false
	_capture_button.disabled = false
	_capture_button.text = "Capture point"
	if _cap_n < 10:
		UiTheme.set_status(_calib_status, "too few readings during capture (%d). Check the connection and try again." % _cap_n, "error")
		return
	var d := []
	for i in 4:
		d.append(_cap_sum[i] / _cap_n)
	_points.append({"known": _weight_spin.value, "d": d, "pos": _pos_pick.get_item_text(_pos_pick.selected)})
	# Suggest the next position.
	_pos_pick.select(mini(_pos_pick.selected + 1, POSITIONS.size() - 1))
	_update_points()

func _update_points() -> void:
	var current: Array = BoardData.gains_for(_slot()) if _board_pick != null and _board_pick.item_count > 0 else BoardData.GAIN.duplicate()
	_solution = Calibration.solve(_points, current)
	_points_list.clear()
	for i in _points.size():
		var p: Dictionary = _points[i]
		var now := Calibration.reading(p.d, current)
		var after := Calibration.reading(p.d, _solution.gains)
		_points_list.add_item("#%d  %s  ·  known %.2f kg  ·  reads %.2f now  ->  %.2f after (%+.1f%%)" % [
			i + 1, p.pos, p.known, now, after, _solution.errors[i]])
	for c in _result_box.get_children():
		c.queue_free()
	if _points.is_empty():
		_result_box.add_child(_wrap_label("Capture points to see the factors."))
		_apply_button.disabled = true
		return
	_result_box.add_child(UiTheme.make_field_label("Method: %s" % _solution.method))
	_row(["Sensor", "Current (counts/kg)", "New (counts/kg)", "Change"], true)
	var names := ["1 front-left", "2 front-right", "3 back-right", "4 back-left"]
	for i in 4:
		var cur: float = 1.0 / current[i]
		var nw: float = 1.0 / _solution.gains[i]
		_row([names[i], "%.1f" % cur, "%.1f" % nw, "%+.2f%%" % ((nw / cur - 1.0) * 100.0)], false)
	_result_box.add_child(UiTheme.make_field_label("Largest error after calibration: %.2f %%" % _solution.max_err))
	if not _solution.warning.is_empty():
		var w := _wrap_label(_solution.warning)
		w.add_theme_color_override("font_color", UiTheme.COLOR_YELLOW)
		_result_box.add_child(w)
	_apply_button.disabled = _solution.method == "none"

func _row(cells: Array, header: bool) -> void:
	var line := HBoxContainer.new()
	_result_box.add_child(line)
	for i in cells.size():
		var l := Label.new()
		l.text = cells[i]
		l.add_theme_font_size_override("font_size", 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i > 0:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.add_theme_color_override("font_color", UiTheme.COLOR_MUTED_TEXT if header or i == 0 else UiTheme.COLOR_TEXT)
		line.add_child(l)

func _apply_calibration() -> void:
	if _solution.is_empty() or _solution.method == "none":
		return
	var slot := _slot()
	var info := "%s board: %s, %.2f kg, max error %.2f%%, %s" % [
		BoardData.board_name(slot), _solution.method, _weight_spin.value, _solution.max_err,
		Time.get_datetime_string_from_system()]
	BoardData.set_calibration(slot, _solution.gains, info)
	SessionPaths.log_event("calibration applied: " + info)
	UiTheme.set_status(_calib_status, "applied and saved for the %s board. All screens use it now." % BoardData.board_name(slot), "success")
	_clear_points()

func _reset_calibration() -> void:
	var slot := _slot()
	BoardData.set_calibration(slot, [], "factory default")
	SessionPaths.log_event("calibration reset to factory for the %s board" % BoardData.board_name(slot))
	UiTheme.set_status(_calib_status, "%s board back to the factory calibration." % BoardData.board_name(slot), "success")
	_update_points()

## -- Preview -------------------------------------------------------------

func _refresh_preview() -> void:
	var lf := SerialLink.left_forces()
	var rf := SerialLink.right_forces()
	var has_l := SerialLink.has_left_data()
	var has_r := SerialLink.has_right_data()
	var lw := BoardData.total_weight(lf)
	var rw := BoardData.total_weight(rf)
	var zero := [0.0, 0.0, 0.0, 0.0]
	var tw := (lw if has_l else 0.0) + (rw if has_r else 0.0)
	var c = BoardData.combined_cop(lf if has_l else zero, rf if has_r else zero) if tw > 1.0 else null
	_preview.set_data(lf, BoardData.board_cop(lf) if lw > 1.0 else null, rf, BoardData.board_cop(rf) if rw > 1.0 else null, c,
		"W = %.2f kg" % lw if has_l else "W = -- kg", "W = %.2f kg" % rw if has_r else "W = -- kg")
