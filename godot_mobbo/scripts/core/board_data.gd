extends Node
## Autoload singleton "BoardData". Converts the raw ADC values streamed by
## s_mobbo.ino into per-sensor force (kg) and center-of-pressure (cm), and
## combines the two boards' COP into one frame centered on the left board.
##
## Calibration: Force_i = raw_adc_i * gain_i - off_i
## Geometry: sensor corners are fixed offsets from each board's own center
## (+x = toward the right-hand side of that board, +y = front).
##
## Open questions / assumptions (confirm and update if wrong):
## - GAIN/OFF below are the constants measured for the RIGHT board
##   (Boardno=1, see s_mobbo/s_mobbo.ino). The LEFT board reuses the same
##   values for now, per instruction, until it has its own calibration.
## - RIGHT_BOARD_OFFSET assumes the right board sits directly beside the
##   left board along +x, edge-to-edge, with zero gap between them. If the
##   real rig has a gap or a different arrangement, change this constant.

const GAIN := [1.0 / 72977.0, 1.0 / 75225.0, 1.0 / 72827.0, 1.0 / 71699.0]
const OFF := [24.05 / 72977.0, 220.38 / 75225.0, 53569.0 / 72827.0, 503.92 / 71699.0]

## Board half-dimensions, cm.
const L_HALF := 56.2 / 2.0  # left-right half-span
const B_HALF := 27.6 / 2.0  # front-back half-span

## Sensor local positions (cm), this board's own center = origin.
## Order matches HX711 #1-4 / GAIN / OFF: 1=front-left, 2=front-right,
## 3=back-right, 4=back-left.
const SENSOR_POS := [
	Vector2(-L_HALF, B_HALF),
	Vector2(L_HALF, B_HALF),
	Vector2(L_HALF, -B_HALF),
	Vector2(-L_HALF, -B_HALF),
]

## ASSUMPTION (see header) -- update once the real board spacing is known.
var right_board_offset: Vector2 = Vector2(2.0 * L_HALF, 0.0)

## Per-board calibration override slots, in case the left/right boards turn
## out to need different numbers later. null = "use the shared GAIN/OFF".
var left_gain: Array = []
var left_off: Array = []
var right_gain: Array = []
var right_off: Array = []

func _gain_for(side: String) -> Array:
	var g: Array = left_gain if side == "left" else right_gain
	return g if not g.is_empty() else GAIN

func _off_for(side: String) -> Array:
	var o: Array = left_off if side == "left" else right_off
	return o if not o.is_empty() else OFF

## raw_adc: Array of 4 signed ints, HX711 #1-4 order. Returns Array of 4 forces (kg).
func forces_from_raw(raw_adc: Array, side: String = "right") -> Array:
	var gain := _gain_for(side)
	var off := _off_for(side)
	var forces := []
	for i in range(4):
		forces.append(raw_adc[i] * gain[i] - off[i])
	return forces

func total_weight(forces: Array) -> float:
	return forces[0] + forces[1] + forces[2] + forces[3]

## COP (cm) relative to this board's own center. Returns null if there's no
## load on the board (avoids a divide-by-zero).
func board_cop(forces: Array) -> Variant:
	var w := total_weight(forces)
	if w <= 0.0:
		return null
	var x := 0.0
	var y := 0.0
	for i in range(4):
		x += forces[i] * SENSOR_POS[i].x
		y += forces[i] * SENSOR_POS[i].y
	return Vector2(x / w, y / w)

## Combined COP (cm) across both boards, in a frame centered on the LEFT
## board. Returns null if there's no load on either board.
func combined_cop(left_forces: Array, right_forces: Array) -> Variant:
	var total_w := total_weight(left_forces) + total_weight(right_forces)
	if total_w <= 0.0:
		return null
	var x := 0.0
	var y := 0.0
	for i in range(4):
		x += left_forces[i] * SENSOR_POS[i].x
		y += left_forces[i] * SENSOR_POS[i].y
		x += right_forces[i] * (SENSOR_POS[i].x + right_board_offset.x)
		y += right_forces[i] * (SENSOR_POS[i].y + right_board_offset.y)
	return Vector2(x / total_w, y / total_w)

## -- Per-trial raw data logging ----------------------------------------
## Mirrors MoBBoLibrary_WIFI.DataLogger/MoBBoDeviceUDP's pattern: rows are
## accumulated in memory and written to disk once, when the trial stops,
## not on every frame. Header/columns are the same shape as Unity's
## MoBBoDeviceUDP.DataHeader ("ID,systime,devtime,f1,f2,f3,f4,x,y,F,
## annotation") with "ID" replaced by "side" ("left"/"right"), since this
## rig is always exactly two boards rather than N arbitrary registered
## devices.

const TRIAL_DATA_HEADER := "side,systime,devtime,f1,f2,f3,f4,x,y,F,annotation\n"

## Static per Unity's MoBBoDeviceUDP.annotation -- nothing in the UI sets
## this yet (it wasn't wired up in the original either), kept for parity.
static var annotation: String = "0"

var _trial_logger: MoBBoDataLogger = null
var _trial_start_ms: int = 0

var is_trial_logging: bool:
	get: return _trial_logger != null

## base_path should already include the session/trial folder and patient
## id, matching how login_handlr's per-game path statics + a timestamp are
## combined in Unity (e.g. StepperGameManager's logFilePath). Returns the
## log file's path.
func start_trial_log(base_path: String, trial: int) -> String:
	var fname := "%s-%d.csv" % [base_path, trial]
	_trial_logger = MoBBoDataLogger.new(fname, TRIAL_DATA_HEADER)
	_trial_start_ms = Time.get_ticks_msec()
	return fname

## Call once per frame while a trial is active, with the latest raw ADC for
## each board. Writes one row per board (so a stepper/weight-shift reader
## can tell which board a row came from, the same way Unity's rows carried
## a device ID).
func log_trial_frame(left_adc: Array, right_adc: Array) -> void:
	if _trial_logger == null:
		return
	var systime := Time.get_datetime_string_from_system()
	var devtime := Time.get_ticks_msec() - _trial_start_ms
	_log_trial_row("left", left_adc, systime, devtime)
	_log_trial_row("right", right_adc, systime, devtime)

func _log_trial_row(side: String, adc: Array, systime: String, devtime: int) -> void:
	if adc.size() != 4:
		return
	var forces := forces_from_raw(adc, side)
	var cop = board_cop(forces)
	var cx: float = 0.0 if cop == null else cop.x
	var cy: float = 0.0 if cop == null else cop.y
	var w := total_weight(forces)
	_trial_logger.log_data("%s, %s, %d, %.10f, %.10f, %.10f, %.10f, %.10f, %.10f, %.10f, %s\n" % [
		side, systime, devtime, forces[0], forces[1], forces[2], forces[3], cx, cy, w, annotation
	])

func stop_trial_log() -> void:
	if _trial_logger == null:
		return
	_trial_logger.stop_data_log(true)
	_trial_logger = null
