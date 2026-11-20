extends Node
## Autoload singleton "SessionPaths". Port of login_handlr.cs's static
## path/session-folder bookkeeping and the MOBBO_MASTERLIST.csv patient
## lookup. UI (login/signup popups, scene switching) is NOT handled here --
## that belongs to the login scene's own script, which should call into
## this autoload the way login_handlr's button handlers did.

## Unity used Application.dataPath (writable in-editor). Godot's equivalent
## writable, per-user location is user://; this still lands outside the
## project/res:// tree the way the original kept data outside Assets/.
var file_path_root: String = ProjectSettings.globalize_path("user://")

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

	for dir in [session_folder, gamedata_folder, rawdata_folder, boardset_up_folder, assess_folder]:
		DirAccess.make_dir_recursive_absolute(dir)

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
	var path := assess_folder.path_join("min_max_dist_ml.csv")
	if assess_folder.is_empty() or not FileAccess.file_exists(path):
		return fallback
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return fallback
	var header := f.get_csv_line()
	var left_idx := header.find("min_gcop_x")
	var right_idx := header.find("max_gcop_x")
	var last_row: PackedStringArray = PackedStringArray()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() > 1:
			last_row = row
	f.close()
	if left_idx == -1 or right_idx == -1 or last_row.size() <= max(left_idx, right_idx):
		return fallback
	return {"left": last_row[left_idx].to_float(), "right": last_row[right_idx].to_float()}

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
