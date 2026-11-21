class_name AnalysisView
extends HBoxContainer
## "Analysis & report" tab of the Sit Assessment screen.
## Left: this patient's recordings (all sessions; assessment trials, reach
## captures and game raw files) + Browse for any raw CSV (e.g. copied from
## another PC). Middle: COP path plots. Right: whole-file measures and the
## PDF / CSV export.

var _list: ItemList
var _paths: Array[String] = []
var _patient_label: Label
var _rig_plot: CopPlot
var _zoom_plot: CopPlot
var _tables: VBoxContainer
var _status: Label
var _export_button: Button
var _file_dialog: FileDialog
var _result: Dictionary = {}
var _current_path := ""

func _ready() -> void:
	add_theme_constant_override("separation", 18)

	# -- Recordings list
	var left := _card("Recordings", "Choose a raw data file")
	left.get_parent().custom_minimum_size = Vector2(300, 0)
	_patient_label = UiTheme.make_field_label("")
	left.add_child(_patient_label)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_size_override("font_size", 13)
	_list.item_selected.connect(func(i): _analyze(_paths[i]))
	left.add_child(_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	left.add_child(row)
	var refresh := UiTheme.make_secondary_button("Refresh")
	refresh.pressed.connect(refresh_list)
	row.add_child(refresh)
	var browse := UiTheme.make_secondary_button("Browse file...")
	browse.pressed.connect(func(): _file_dialog.popup_centered_ratio(0.7))
	row.add_child(browse)

	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray(["*.csv ; MoBBo raw data"])
	_file_dialog.current_dir = SessionPaths.new_path_signin
	_file_dialog.file_selected.connect(_analyze)
	add_child(_file_dialog)

	# -- Plots
	var mid := _card("COP path", "Left (blue), right (green), combined (yellow)", true)
	mid.get_parent().size_flags_stretch_ratio = 1.3
	_rig_plot = CopPlot.new()
	_rig_plot.mode = "rig"
	_rig_plot.custom_minimum_size = Vector2(0, 170)
	mid.add_child(_rig_plot)
	mid.add_child(UiTheme.make_eyebrow("Combined COP · 95% confidence ellipse"))
	_zoom_plot = CopPlot.new()
	_zoom_plot.mode = "zoom"
	_zoom_plot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_zoom_plot.custom_minimum_size = Vector2(0, 220)
	mid.add_child(_zoom_plot)

	# -- Measures + export
	var right := _card("Measures", "Whole file: mean, median, SD", true)
	right.get_parent().size_flags_stretch_ratio = 1.4
	var export_row := HBoxContainer.new()
	export_row.add_theme_constant_override("separation", 10)
	right.add_child(export_row)
	_export_button = UiTheme.make_accent_button("Export PDF report")
	_export_button.disabled = true
	_export_button.pressed.connect(_export)
	export_row.add_child(_export_button)
	_status = UiTheme.make_field_label("")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_row.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	_tables = VBoxContainer.new()
	_tables.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tables.add_theme_constant_override("separation", 6)
	scroll.add_child(_tables)

	refresh_list()

func _card(eyebrow: String, title: String, expand := false) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if expand:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UiTheme.make_eyebrow(eyebrow))
	var t := UiTheme.make_subheading(title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(t)
	return box

## -- Recordings ------------------------------------------------------------

func _patient() -> String:
	return SessionPaths.hosp_num if not SessionPaths.hosp_num.is_empty() else "guest"

func refresh_list() -> void:
	_list.clear()
	_paths.clear()
	var patient_dir := SessionPaths.new_path_signin.path_join(_patient())
	_patient_label.text = "Patient: %s" % _patient()
	var sessions := Array(DirAccess.get_directories_at(patient_dir))
	sessions.sort()
	sessions.reverse()  # newest first
	for s in sessions:
		var found: Array[String] = []
		_collect_csv(patient_dir.path_join(s), found)
		found.sort()
		found.reverse()
		for p in found:
			_paths.append(p)
			_list.add_item("%s  ·  %s" % [_session_label(s), _kind(p)])
			_list.set_item_tooltip(_list.item_count - 1, p)
	if _paths.is_empty():
		_list.add_item("No recordings yet for this patient.")
		_list.set_item_disabled(0, true)
		_paths.append("")

func _collect_csv(dir: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		if sub == "Gamedata":
			continue  # game-state files, not board data
		_collect_csv(dir.path_join(sub), out)
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".csv"):
			continue
		if f.begins_with("min_max_dist") or f.ends_with("_summary.csv") or f.begins_with("session_"):
			continue
		out.append(dir.path_join(f))

static func _session_label(s: String) -> String:
	# SessionD2026-11-21T13-48-38 -> 2026-11-21 13:48
	var t := s.trim_prefix("SessionD")
	if t.length() >= 16:
		return "%s %s:%s" % [t.substr(0, 10), t.substr(11, 2), t.substr(14, 2)]
	return s

static func _kind(path: String) -> String:
	var f := path.get_file()
	if f.begins_with("ML_reach"):
		return "ML reach"
	if f.begins_with("AP_reach"):
		return "AP reach"
	if path.contains("/assessment/"):
		return "Timed trial " + f.get_basename().get_slice("-", 1)
	var game := path.get_base_dir().get_file().get_basename()  # pingpong.rawdata -> pingpong
	return "Game: %s" % game

## -- Analysis --------------------------------------------------------------

func _analyze(path: String) -> void:
	if path.is_empty():
		return
	_status.text = "Analysing..."
	_result = CopAnalysis.analyze_file(path)
	_current_path = path
	if _result.has("error"):
		UiTheme.set_status(_status, _result.error, "error")
		_export_button.disabled = true
		_result = {}
	else:
		_status.text = path.get_file()
		_export_button.disabled = false
	_rig_plot.set_result(_result)
	_zoom_plot.set_result(_result)
	_fill_tables()

func _meta() -> Dictionary:
	var parts := _current_path.split("/")
	var session := ""
	var patient := ""
	for i in parts.size():
		if parts[i].begins_with("SessionD"):
			session = parts[i]
			patient = parts[i - 1] if i > 0 else ""
	return {"patient": patient, "session": session, "file": _current_path.get_file()}

func _fill_tables() -> void:
	for c in _tables.get_children():
		c.queue_free()
	if _result.is_empty():
		return
	var info := []
	for r in CopReport.info_rows(_result, _meta()):
		info.append([r[0], str(r[1])])
	_add_table("Recording", [], info, [1.6, 2.4])
	_add_table("Weight distribution", ["", "Mean", "Median", "SD"], CopReport.weight_table(_result), [2.6, 1, 1, 1])
	_add_table("COP measures", ["", "Combined", "Left", "Right"], CopReport.cop_table(_result), [2.6, 1.1, 1.1, 1.1])
	_add_table("Forces (kg)", ["", "L mean", "L med", "L SD", "R mean", "R med", "R SD"], CopReport.force_table(_result), [2.6, 1, 1, 1, 1, 1, 1])
	var note := UiTheme.make_field_label("Board COP: relative to that board's centre. Combined COP: relative to the left board's centre. COP only while > 1 kg load. COP low-pass filtered at 10 Hz (zero-phase); forces unfiltered.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tables.add_child(note)

func _add_table(title: String, header: Array, rows: Array, ratios: Array) -> void:
	var t := UiTheme.make_eyebrow(title)
	_tables.add_child(t)
	var all := rows.duplicate()
	if not header.is_empty():
		all.push_front(header)
	for ri in all.size():
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		_tables.add_child(line)
		var row: Array = all[ri]
		for ci in row.size():
			var l := Label.new()
			l.text = str(row[ci])
			l.add_theme_font_size_override("font_size", 13)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.size_flags_stretch_ratio = ratios[ci]
			l.clip_text = true
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			if ci > 0:
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			var is_header := ri == 0 and not header.is_empty()
			l.add_theme_color_override("font_color", UiTheme.COLOR_MUTED_TEXT if (is_header or ci == 0) else UiTheme.COLOR_TEXT)
			line.add_child(l)

## -- Export ----------------------------------------------------------------

func _export() -> void:
	if _result.is_empty():
		return
	var base := _current_path.get_basename()
	var pdf_path := base + "_report.pdf"
	var csv_path := base + "_summary.csv"
	var meta := _meta()
	var ok_pdf := CopReport.write_pdf(_result, meta, pdf_path)
	var ok_csv := CopReport.write_csv(_result, meta, csv_path)
	if ok_pdf and ok_csv:
		UiTheme.set_status(_status, "saved %s and %s next to the data file." % [pdf_path.get_file(), csv_path.get_file()], "success")
		SessionPaths.log_event("analysis report exported: %s" % pdf_path)
		OS.shell_open(pdf_path)
	else:
		UiTheme.set_status(_status, "could not write the report (is the PDF open in another program?).", "error")
