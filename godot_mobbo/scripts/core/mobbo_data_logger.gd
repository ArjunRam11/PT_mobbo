class_name MoBBoDataLogger
extends RefCounted
## CSV logger that streams to disk. Unity's DataLogger kept the whole file in
## memory and wrote it once on stop, so a crash, a closed window or leaving
## the screen mid-trial lost the entire trial. This opens the file at start,
## writes every line straight away and flushes at least once a second, so at
## most ~1 s of data can be lost even if the app is killed.

const FLUSH_INTERVAL_MS := 1000

var curr_fname: String
var _file: FileAccess = null
var _last_flush_ms := 0
var _rows := 0

var still_logging: bool:
	get: return _file != null

var rows_written: int:
	get: return _rows

## Creates the folder and file and writes the header. An existing file is
## appended to (no second header).
func _init(filename: String, header: String) -> void:
	curr_fname = filename
	if filename.is_empty():
		push_error("MoBBoDataLogger: empty file name, nothing will be logged.")
		return
	DirAccess.make_dir_recursive_absolute(filename.get_base_dir())
	var exists := FileAccess.file_exists(filename)
	_file = FileAccess.open(filename, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if _file == null:
		push_error("MoBBoDataLogger: cannot open '%s' (%s)" % [filename, error_string(FileAccess.get_open_error())])
		return
	if exists:
		_file.seek_end()
	else:
		_file.store_string(header if header.ends_with("\n") else header + "\n")
	_file.flush()
	_last_flush_ms = Time.get_ticks_msec()

## data: one or more complete lines, each ending in "\n".
func log_data(data: String) -> void:
	if _file == null:
		return
	_file.store_string(data)
	_rows += 1
	var now := Time.get_ticks_msec()
	if now - _last_flush_ms >= FLUSH_INTERVAL_MS:
		_file.flush()
		_last_flush_ms = now

## Flushes and closes. (The argument is kept for older callers; data is
## already on disk, so there is nothing to discard.)
func stop_data_log(_write_to_disk: bool = true) -> void:
	if _file != null:
		_file.flush()
		_file.close()
		_file = null
