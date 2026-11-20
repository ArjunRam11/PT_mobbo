class_name MoBBoGrid
extends RefCounted
## Port of MoBBoGrid_WIFI.cs's data model: maps a physical grid of board
## positions to device IDs. The original also drew a TextMesh label per
## cell directly from this class; that's view code and belongs in whichever
## scene renders the board-setup grid (e.g. a GridContainer/Label per cell
## driven by `values`), not here.

var width: int
var height: int
var values: Array = []  # Array[Array[int]], [row][col], -1 = unassigned

var _value_opts: Array = []
var _value_opts_available: Array = []

func _init(w: int, h: int, valopts: Array) -> void:
	width = w
	height = h
	values.resize(h)
	for i in range(h):
		var row := []
		row.resize(w)
		row.fill(-1)
		values[i] = row
	_value_opts = valopts.duplicate()
	_value_opts_available = []
	_value_opts_available.resize(_value_opts.size())
	_value_opts_available.fill(true)

func clear() -> void:
	for i in range(height):
		for j in range(width):
			values[i][j] = -1

func all_grid_values_assigned() -> bool:
	for i in range(height):
		for j in range(width):
			if values[i][j] == -1:
				return false
	return true

## Returns [x, y] grid cell for a world position, given the cell size and
## the grid's world origin (both supplied by the caller/view, since this
## class no longer owns rendering transform state).
func get_grid_pos(world_pos: Vector2, origin: Vector2, cell_width: float, cell_height: float) -> Vector2i:
	var gx := int((world_pos.x - origin.x) / cell_width)
	var gy := int(-(world_pos.y - origin.y) / cell_height)
	return Vector2i(gx, gy)

func set_next_available_value(grid_pos: Vector2i) -> void:
	var gx := grid_pos.x
	var gy := grid_pos.y
	if gx >= 0 and gx < width and gy >= 0 and gy < height:
		var next_val := _get_next_available_value(values[gy][gx])
		if next_val != -1:
			_make_value_available(values[gy][gx])
			values[gy][gx] = next_val
			_make_value_unavailable(next_val)

func clear_cell_value(grid_pos: Vector2i) -> void:
	var gx := grid_pos.x
	var gy := grid_pos.y
	if gx >= 0 and gx < width and gy >= 0 and gy < height:
		_make_value_available(values[gy][gx])
		values[gy][gx] = -1

func _get_value_index(val: int) -> int:
	for i in range(_value_opts.size()):
		if _value_opts[i] == val:
			return i
	return -2

func _make_value_available(val: int) -> void:
	var idx := _get_value_index(val)
	if idx >= 0:
		_value_opts_available[idx] = true

func _make_value_unavailable(val: int) -> void:
	var idx := _get_value_index(val)
	if idx >= 0:
		_value_opts_available[idx] = false

func _get_next_available_value(val: int) -> int:
	var idx := -1 if val == -1 else _get_value_index(val)
	if idx == -2:
		return -1
	var cnt := 0
	while cnt < _value_opts.size():
		idx = (idx + 1) % _value_opts.size()
		if _value_opts_available[idx]:
			return _value_opts[idx]
		cnt += 1
	return -1
