class_name TherapySession
extends RefCounted
## Slim port of TherapySession_WIFI.cs. Every call site in the original only
## ever checked "does a session exist, else start a dummy one" -- none of
## them read activity codes/levels/AROM-PROM data back out, so this keeps
## just the observable behavior that matters: a per-session folder and a
## human-readable session log file on disk.

var start_time: float
var directory: String
var sess_file_name: String

func _init(subj_hosp_num: String) -> void:
	start_time = Time.get_unix_time_from_system()
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "T")
	directory = SubjectData.get_subj_session_file_dir(subj_hosp_num).path_join("D%s" % timestamp)
	DirAccess.make_dir_recursive_absolute(directory)
	sess_file_name = directory.path_join("sessfile.sfl")
	write_session_info("Subj %s, Session started." % subj_hosp_num)

func close_session_file() -> void:
	write_session_info("Session closed.")

func write_session_info(info: String) -> void:
	var f: FileAccess
	if FileAccess.file_exists(sess_file_name):
		f = FileAccess.open(sess_file_name, FileAccess.READ_WRITE)
		if f:
			f.seek_end()
	else:
		f = FileAccess.open(sess_file_name, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("%s, %s" % [Time.get_datetime_string_from_system(), info])
	f.close()
