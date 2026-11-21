class_name GameRecorder
extends RefCounted
## One game round's recording, shared by every game:
##   Rawdata/<game>.rawdata/<game>_<time>-<trial>.csv   per-packet board data
##                                                      (BoardData.TRIAL_DATA_HEADER)
##   Gamedata/<game>.gamedata/<game>_<time>-<trial>.csv game state rows (game's header)
## plus "started"/"saved" lines in the session's session_log.csv.
## Both files are streamed (see MoBBoDataLogger), so stopping early, going
## back to the hub or closing the window keeps everything recorded so far.
## Call stop() from the game's end AND its _exit_tree().

var game_name: String
var _game_log: MoBBoDataLogger = null
var _start_ms := 0

var active: bool:
	get: return _game_log != null

## Seconds since start().
var elapsed: float:
	get: return (Time.get_ticks_msec() - _start_ms) / 1000.0

## raw_prop / game_prop: SessionPaths property names of this game's
## folders, e.g. "pingpong_rawdata" / "pingpong_gamedata".
func start(p_game_name: String, raw_prop: String, game_prop: String, header: String, trial: int) -> void:
	stop("restarted")
	game_name = p_game_name
	SessionPaths.ensure_session()
	var stamp := SessionPaths.file_stamp()
	var raw_dir: String = SessionPaths.get(raw_prop)
	var game_dir: String = SessionPaths.get(game_prop)
	BoardData.start_trial_log(raw_dir.path_join("%s_%s" % [game_name, stamp]), trial)
	_game_log = MoBBoDataLogger.new(game_dir.path_join("%s_%s-%d.csv" % [game_name, stamp, trial]), header)
	_start_ms = Time.get_ticks_msec()
	SessionPaths.log_event("%s trial %d started" % [game_name, trial])

## One game-state line (no trailing newline needed).
func row(line: String) -> void:
	if _game_log != null:
		_game_log.log_data(line + "\n")

## Safe to call when not recording.
func stop(reason: String = "finished") -> void:
	if _game_log == null:
		return
	var fname := _game_log.curr_fname
	_game_log.stop_data_log()
	_game_log = null
	BoardData.stop_trial_log()
	SessionPaths.log_event("%s %s, game data saved: %s" % [game_name, reason, fname])
