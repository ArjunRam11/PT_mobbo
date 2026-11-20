extends Node
## Autoload singleton "AppConfig". Port of AppConfig_WIFI.cs: static config
## shared across scenes (board grid layout options, physical board
## dimensions, file paths). PLAEBO/AROM/PROM-only constants from the
## original were not ported -- that subsystem is dead code, referenced
## nowhere outside its own definition file.

## [noBoards, rows, cols] options, same table as AppConfig_WIFI.AllGridOptions.
const ALL_GRID_OPTIONS := [
	[1, 1, 1],
	[2, 1, 2], [2, 2, 1],
	[3, 1, 3], [3, 3, 1],
	[4, 1, 4], [4, 2, 2], [4, 4, 1],
	[5, 1, 5], [5, 5, 1],
	[6, 1, 6], [6, 2, 3], [6, 3, 2], [6, 6, 1],
	[7, 1, 7], [7, 7, 1],
	[8, 1, 8], [8, 2, 4], [8, 4, 2], [8, 8, 1],
	[9, 1, 9], [9, 3, 3], [9, 9, 1],
	[10, 1, 10], [10, 2, 5], [10, 5, 2], [10, 10, 1],
	[11, 1, 11], [11, 11, 1],
	[12, 1, 12], [12, 2, 6], [12, 3, 4], [12, 4, 3], [12, 6, 2], [12, 12, 1],
]

const REAL_BOARD_WIDTH := 57.0     # cm
const REAL_BOARD_HEIGHT := 27.5    # cm

const BOARD_WIDTH := 18
const BOARD_HEIGHT := 9
const GRID_ORIGIN := Vector2(-35, 10)

const BOARD_WIDTH_TEST_SCN := int(2.1 * BOARD_WIDTH)
const BOARD_HEIGHT_TEST_SCN := int(2.1 * BOARD_HEIGHT)
const GRID_ORIGIN_TEST_SCN := Vector2(-110, 24)

const BOARD_PING_WIDTH := int(2.6 * BOARD_WIDTH)
const BOARD_PING_HEIGHT := int(8 * BOARD_HEIGHT)
const GRID_ORIGIN_TEST_SCNN := Vector2(-135, 28)

var subjs_dir: String:
	get: return SessionPaths.file_path_root.path_join("data/subjects")

func get_subjects_list() -> Array:
	var subjlist: Array = []
	if not DirAccess.dir_exists_absolute(subjs_dir):
		return subjlist
	var dir := DirAccess.open(subjs_dir)
	if dir == null:
		return subjlist
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and name != "config" and name != "." and name != "..":
			subjlist.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	return subjlist

func does_subject_exist(subj: String) -> bool:
	return get_subjects_list().has(subj)

func get_grid_options(no_boards: int) -> Array:
	var opts: Array = []
	for row in ALL_GRID_OPTIONS:
		if row[0] == no_boards:
			opts.append([row[1], row[2]])
	return opts
