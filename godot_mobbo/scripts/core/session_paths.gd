extends Node
## Autoload singleton "SessionPaths". Port of login_handlr.cs's static
## path/session-folder bookkeeping and the MOBBO_MASTERLIST.csv patient
## lookup. UI (login/signup popups, scene switching) is NOT handled here --
## that belongs to the login scene's own script, which should call into
## this autoload the way login_handlr's button handlers did.

## All data lives in <Documents>/MoBBo_Data on whatever PC runs the build:
## easy to find and back up, survives reinstalling the app, and needs no
## admin rights. (Earlier builds used the hidden user:// folder; its data is
## copied across once, on first run, see _migrate_old_data().)
const DATA_DIR_NAME := "MoBBo_Data"
var file_path_root: String = _resolve_root()

static func _resolve_root() -> String:
	# Optional override, e.g. a shared/backed-up drive: set MOBBO_DATA_DIR.
	var override := OS.get_environment("MOBBO_DATA_DIR")
	if not override.is_empty():
		return override
	var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if docs.is_empty():
		return ProjectSettings.globalize_path("user://")
	return docs.path_join(DATA_DIR_NAME)

var mobbo_masterlist: String:
	get: return file_path_root.path_join("data/MOBBO_MASTERLIST.csv")
var new_path_signin: String:
	get: return file_path_root.path_join("data/Trail_data")

# Current session's folder layout (set by create_session_folders()).
var session_folder: String = ""
var gamedata_folder: String = ""
var rawdata_folder: String = ""
var boardset_up_folder: String = ""
var assess_folder: String = ""

var pingpong_rawdata: String = ""
var pingpong_gamedata: String = ""
var floppybird_rawdata: String = ""
var floppybird_gamedata: String = ""
var ball_roller_rawdata: String = ""
var ball_roller_gamedata: String = ""
var space_rawdata: String = ""
var space_gamedata: String = ""
var stepper_rawdata: String = ""
var stepper_gamedata: String = ""
var coin_rawdata: String = ""
var coin_gamedata: String = ""

# Patient/session identity captured at login, read by game scripts.
var open_folder_name: String = ""
var session_starter_name: String = ""
var age: String = ""
var gender: String = ""
var condition: String = ""
var hosp_num: String = ""
var amp_side: String = ""
var amp_type: String = ""
var trial_duration: int = 0

func _ready() -> void:
	_migrate_old_data()
	DirAccess.make_dir_recursive_absolute(file_path_root.path_join("data"))
	if not FileAccess.file_exists(mobbo_masterlist):
		var f := FileAccess.open(mobbo_masterlist, FileAccess.WRITE)
		if f:
			f.store_line("hosp_no,name,gender,age,diagnosis,amp_side,amp_type")
			f.close()

## Builds this session's folder tree under new_path_signin/<hosp_num>/Session<timestamp>/...
## Mirrors login_handlr.create_session_folders(); call after a successful login.
func create_session_folders(p_hosp_num: String) -> void:
	hosp_num = p_hosp_num
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_T")
	session_folder = new_path_signin.path_join(hosp_num).path_join("SessionD%s" % timestamp)
	gamedata_folder = session_folder.path_join("Gamedata")
	rawdata_folder = session_folder.path_join("Rawdata")
	boardset_up_folder = session_folder.path_join("Board_setup")
	assess_folder = session_folder.path_join("assessment")

	pingpong_rawdata = rawdata_folder.path_join("pingpong.rawdata")
	pingpong_gamedata = gamedata_folder.path_join("pingpong.gamedata")
	floppybird_rawdata = rawdata_folder.path_join("Floppybird.rawdata")
	floppybird_gamedata = gamedata_folder.path_join("Floppybird.gamedata")
	ball_roller_rawdata = rawdata_folder.path_join("ball_roller.rawdata")
	ball_roller_gamedata = gamedata_folder.path_join("ball_roller.gamedata")
	space_rawdata = rawdata_folder.path_join("Space.rawdata")
	space_gamedata = gamedata_folder.path_join("Space.gamedata")
	stepper_rawdata = rawdata_folder.path_join("stepper.rawdata")
	stepper_gamedata = gamedata_folder.path_join("stepper.gamedata")
	coin_rawdata = rawdata_folder.path_join("coin_collector.rawdata")
	coin_gamedata = gamedata_folder.path_join("coin_collector.gamedata")

	for dir in [session_folder, gamedata_folder, rawdata_folder, boardset_up_folder, assess_folder]:
		DirAccess.make_dir_recursive_absolute(dir)
	_write_session_info()
	log_event("session started for %s" % hosp_num)

## Every screen that records data calls this first. If nobody logged in
## (e.g. a scene opened straight from the editor), a "guest" session is
## created so files still land in a proper session folder, never in a
## relative path next to the executable.
func ensure_session() -> void:
	if session_folder.is_empty():
		create_session_folders("guest")

## Session metadata needed to reprocess the data later on any PC:
## who/when, and the calibration + geometry used to turn ADC into kg/cm.
func _write_session_info() -> void:
	var f := FileAccess.open(session_folder.path_join("session_info.csv"), FileAccess.WRITE)
	if f == null:
		push_error("SessionPaths: cannot write session_info.csv in %s" % session_folder)
		return
	f.store_line("key,value")
	f.store_line("hosp_no,%s" % hosp_num)
	f.store_line("session_start,%s" % Time.get_datetime_string_from_system())
	f.store_line("utc_offset_min,%d" % Time.get_time_zone_from_system().get("bias", 0))
	f.store_line("trial_duration_s,%d" % trial_duration)
	f.store_line("computer,%s" % OS.get_name())
	f.store_line("app,%s" % ProjectSettings.get_setting("application/config/name", "MoBBo"))
	f.store_line("zero_adc,\"%s\"" % ",".join(BoardData.ZERO_ADC.map(func(v): return "%.2f" % v)))
	f.store_line("slope_counts_per_kg,\"%s\"" % ",".join(BoardData.SLOPE.map(func(v): return "%.2f" % v)))
	f.store_line("board_half_lr_cm,%.2f" % BoardData.L_HALF)
	f.store_line("board_half_fb_cm,%.2f" % BoardData.B_HALF)
	f.store_line("right_board_offset_cm,\"%.2f,%.2f\"" % [BoardData.right_board_offset.x, BoardData.right_board_offset.y])
	f.close()

## Appends "time,event" to the session's session_log.csv (what was run,
## which file it wrote, tare values, ...). Quotes are stripped from text.
func log_event(text: String) -> void:
	if session_folder.is_empty():
		return
	var path := session_folder.path_join("session_log.csv")
	var is_new := not FileAccess.file_exists(path)
	var f := FileAccess.open(path, FileAccess.WRITE if is_new else FileAccess.READ_WRITE)
	if f == null:
		return
	if is_new:
		f.store_line("time,event")
	else:
		f.seek_end()
	# Paths relative to the session folder, so the log still makes sense
	# after the folder is copied to another PC.
	text = text.replace(session_folder + "/", "").replace("\"", "'")
	f.store_line("%s,\"%s\"" % [Time.get_datetime_string_from_system(), text])
	f.close()

## Timestamp safe for file names on every OS (no ':').
func file_stamp() -> String:
	return Time.get_datetime_string_from_system().replace(":", "-")

## One-time copy of data written by earlier builds to user://data into the
## new Documents folder. Never overwrites or deletes anything.
func _migrate_old_data() -> void:
	var old_root := ProjectSettings.globalize_path("user://").path_join("data")
	var new_root := file_path_root.path_join("data")
	if old_root == new_root or not DirAccess.dir_exists_absolute(old_root):
		return
	if FileAccess.file_exists(new_root.path_join("MOBBO_MASTERLIST.csv")):
		return  # already set up here
	_copy_tree(old_root, new_root)

func _copy_tree(src: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(dst)
	var d := DirAccess.open(src)
	if d == null:
		return
	for sub in d.get_directories():
		_copy_tree(src.path_join(sub), dst.path_join(sub))
	for file in d.get_files():
		if not FileAccess.file_exists(dst.path_join(file)):
			DirAccess.copy_absolute(src.path_join(file), dst.path_join(file))

## Returns true and populates the identity fields if hosp_no is found in the
## master list. Mirrors login_handlr.Lookforexistinguser(), minus the scene
## load -- the login screen's own script should do that on a true result.
func look_for_existing_user(hosp_no: String) -> bool:
	if not FileAccess.file_exists(mobbo_masterlist):
		push_error("SessionPaths: master list CSV does not exist at %s" % mobbo_masterlist)
		return false
	var f := FileAccess.open(mobbo_masterlist, FileAccess.READ)
	if f == null:
		return false
	f.get_line()  # header
	var found := false
	while not f.eof_reached():
		var line := f.get_line()
		if line.is_empty():
			continue
		var values := line.split(",")
		if values.size() > 0 and values[0] == hosp_no:
			open_folder_name = hosp_no
			session_starter_name = hosp_no
			hosp_num = hosp_no
			if values.size() > 2:
				gender = values[2]
			if values.size() > 3:
				age = values[3]
			if values.size() > 4:
				condition = values[4]
			if values.size() > 5:
				amp_side = values[5]
			if values.size() > 6:
				amp_type = values[6]
			found = true
			break
	f.close()
	return found

## Reads the most recent ML (left/right) reach limits written by the
## assessment scene (min_max_dist_ml.csv), for games that scale a weight-
## controlled paddle/collector across the patient's own measured reach --
## port of the left_limit/right_limit lookup in BirdScript.cs/ping.cs/
## collector.cs. Falls back to BoardData's physical combined-COP range if
## no assessment has been recorded yet. Deviation from Unity: those scripts
## all read the FIRST row of this accumulating CSV (csvData[0]) -- for a
## file meant to grow one row per assessment, always using the very first
## one ever recorded looks like an oversight, not an intended "baseline"
## design. This reads the LAST (most recent) row instead.
func get_ml_limits() -> Dictionary:
	var fallback := {"left": -BoardData.L_HALF, "right": BoardData.right_board_offset.x + BoardData.L_HALF}
	var v := _last_row_pair("min_max_dist_ml.csv", "min_gcop_x", "max_gcop_x")
	if v.is_empty():
		return fallback
	return {"left": v[0], "right": v[1]}

## Most recent anterior-posterior (back/front) reach limits, combined-COP y
## in cm, from min_max_dist_ap.csv (written by the assessment scene). Used
## by Floppy Bird. Falls back to the boards' physical front-back span.
func get_ap_limits() -> Dictionary:
	var fallback := {"back": -BoardData.B_HALF, "front": BoardData.B_HALF}
	var v := _last_row_pair("min_max_dist_ap.csv", "min_gcop_y", "max_gcop_y")
	if v.is_empty():
		return fallback
	return {"back": v[0], "front": v[1]}

## [min, max] from the newest assessment of this patient: the current
## session's file first, else the most recent earlier session that has one
## (so games keep the patient's own range across sessions). [] if none.
## Games ask every frame, so results are cached until the session changes
## or the assessment saves a new range (invalidate_limits()).
var _limits_cache := {}

func invalidate_limits() -> void:
	_limits_cache.clear()

func _last_row_pair(file_name: String, min_col: String, max_col: String) -> Array:
	var key := "%s|%s|%s|%s" % [assess_folder, file_name, min_col, max_col]
	if not _limits_cache.has(key):
		_limits_cache[key] = _find_last_pair(file_name, min_col, max_col)
	return _limits_cache[key]

func _find_last_pair(file_name: String, min_col: String, max_col: String) -> Array:
	if not assess_folder.is_empty():
		var v := _read_pair(assess_folder.path_join(file_name), min_col, max_col)
		if not v.is_empty():
			return v
	if hosp_num.is_empty():
		return []
	var patient_dir := new_path_signin.path_join(hosp_num)
	var sessions := DirAccess.get_directories_at(patient_dir)
	# "SessionD<ISO time>" names sort chronologically; newest first.
	var names := Array(sessions)
	names.sort()
	names.reverse()
	for s in names:
		var v := _read_pair(patient_dir.path_join(s).path_join("assessment").path_join(file_name), min_col, max_col)
		if not v.is_empty():
			return v
	return []

func _read_pair(path: String, min_col: String, max_col: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var header := f.get_csv_line()
	for i in header.size():
		header[i] = header[i].strip_edges()  # Unity's ML header has a ", max_x" space
	var min_idx := header.find(min_col)
	var max_idx := header.find(max_col)
	var last_row: PackedStringArray = PackedStringArray()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() > 1:
			last_row = row
	f.close()
	if min_idx == -1 or max_idx == -1 or last_row.size() <= max(min_idx, max_idx):
		return []
	var lo := last_row[min_idx].strip_edges().to_float()
	var hi := last_row[max_idx].strip_edges().to_float()
	return [lo, hi] if hi > lo else []

## Appends a new patient row to the master list. Mirrors
## login_handlr.writetoMOBBO_userlist().
func write_to_mobbo_userlist(hosp_no: String, name: String, gender_: String, age_: String,
		diagnosis: String, amp_side_: String, amp_type_: String) -> void:
	var f := FileAccess.open(mobbo_masterlist, FileAccess.READ_WRITE)
	if f == null:
		push_error("SessionPaths: failed to open master list for writing.")
		return
	f.seek_end()
	f.store_line("%s,%s,%s,%s,%s,%s,%s" % [hosp_no, name, gender_, age_, diagnosis, amp_side_, amp_type_])
	f.close()

	DirAccess.make_dir_recursive_absolute(new_path_signin.path_join(hosp_no))
