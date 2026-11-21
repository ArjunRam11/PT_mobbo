extends Node
## Autoload singleton "AppData". Port of AppData_WIFI.cs's session/timer/grid
## state (the MoBBoServer force/COP aggregation lives in mobbo_server.gd,
## matching the original's split between the two classes).

var subjd: SubjectData = null
var subj_hosp_num: String = ""
var session: TherapySession = null

var is_logging: bool = false
var selected_grid_rows: int = 0
var selected_grid_columns: int = 0
var game_state: String = ""

## Performance variable counts for different games (Catcher, Crazy Pong).
var game_perf_var_count := [4, 5]
var next_game_level: int = 1

var m_grid: MoBBoGrid = null

var _stopwatch_start_usec: int = -1

var current_time: float:
	get:
		if _stopwatch_start_usec < 0:
			return 0.0
		return (Time.get_ticks_usec() - _stopwatch_start_usec) / 1_000_000.0

var is_timer_running: bool:
	get: return _stopwatch_start_usec >= 0

func start_timer() -> void:
	_stopwatch_start_usec = Time.get_ticks_usec()

## Used when a screen is opened without logging in: the data still goes to
## a proper "guest" session folder (see SessionPaths.ensure_session()).
func start_dummy_session() -> void:
	start_session("000000g")
	SessionPaths.ensure_session()

func start_session(hosp_no: String) -> void:
	subj_hosp_num = hosp_no
	subjd = SubjectData.new(hosp_no)
	session = TherapySession.new(hosp_no)

func stop_session() -> void:
	BoardData.stop_trial_log()
	SessionPaths.log_event("session ended")
	if session != null:
		session.close_session_file()
	session = null
	# Next login starts a fresh session folder.
	SessionPaths.session_folder = ""
	SessionPaths.hosp_num = ""
