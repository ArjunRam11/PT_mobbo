class_name MoBBoDataLogger
extends RefCounted
## Port of MoBBoLibrary_WIFI.DataLogger: accumulates CSV text in memory and
## flushes it to disk once, on stop, rather than writing every line.

var curr_fname: String
var _filedata: String = ""

var still_logging: bool:
	get: return not _filedata.is_empty() or not curr_fname.is_empty()

func _init(filename: String, header: String) -> void:
	curr_fname = filename
	_filedata = header

func log_data(data: String) -> void:
	_filedata += data

func stop_data_log(write_to_disk: bool = true) -> void:
	if write_to_disk:
		if curr_fname.is_empty():
			push_warning("MoBBoDataLogger: log file name is empty, skipping file write.")
			return
		var dir := curr_fname.get_base_dir()
		if not dir.is_empty():
			DirAccess.make_dir_recursive_absolute(dir)
		var file: FileAccess
		if FileAccess.file_exists(curr_fname):
			file = FileAccess.open(curr_fname, FileAccess.READ_WRITE)
			if file:
				file.seek_end()
		else:
			file = FileAccess.open(curr_fname, FileAccess.WRITE)
		if file == null:
			push_error("MoBBoDataLogger: failed to write log file '%s'" % curr_fname)
			return
		file.store_string(_filedata)
		file.close()
	curr_fname = ""
