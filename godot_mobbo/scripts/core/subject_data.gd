class_name SubjectData
extends RefCounted
## Slim port of MoBBoDataStructures_WIFI.SubjectData -- just the directory
## layout, which is the only part any call site actually used. The original
## also read/wrote a per-subject profile.csv and AROM/PROM assessment files
## through PlaeboRobotData/ActiveRangeOfMotion/PassiveRangeOfMotion; that
## whole chain was dead code (unused by every shipped game) and was not
## ported -- see MoBBoDataStructures_WIFI.cs if it's ever needed back.

var hospnum: String

func _init(hnum: String) -> void:
	hospnum = hnum

static func get_subj_dir(hnum: String) -> String:
	return AppConfig.subjs_dir.path_join(hnum)

static func get_subj_session_file_dir(hnum: String) -> String:
	return get_subj_dir(hnum).path_join("session_files")

static func get_subj_setup_file_dir(hnum: String) -> String:
	return get_subj_dir(hnum).path_join("setup_files")

static func get_subj_rawdata_dir(hnum: String) -> String:
	return get_subj_dir(hnum).path_join("rawdata_files")

static func get_subj_assessment_dir(hnum: String) -> String:
	return get_subj_dir(hnum).path_join("assessment_files")

static func get_subj_gameperf_dir(hnum: String) -> String:
	return get_subj_dir(hnum).path_join("gameperf_files")
