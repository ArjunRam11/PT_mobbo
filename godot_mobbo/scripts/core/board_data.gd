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
## - Both boards currently use the supplied calibration measurements; each
##   board can be given its own calibration through the override slots below.
## - RIGHT_BOARD_OFFSET assumes the right board sits directly beside the
##   left board along +x, edge-to-edge, with zero gap between them. If the
##   real rig has a gap or a different arrangement, change this constant.

## Supplied zero ADC and signed slope in counts/kg for load cells 1–4.
const ZERO_ADC := [-753740.63, 51659.20, 703002.81, -222166.91]
const SLOPE := [-61959.52, -60519.76, -41301.70, -57799.64]
const GAIN := [1.0 / SLOPE[0], 1.0 / SLOPE[1], 1.0 / SLOPE[2], 1.0 / SLOPE[3]]
const OFF := [ZERO_ADC[0] / SLOPE[0], ZERO_ADC[1] / SLOPE[1], ZERO_ADC[2] / SLOPE[2], ZERO_ADC[3] / SLOPE[3]]

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
## Session tare is the mean unloaded ADC reading for each sensor.
var left_tare_adc: Array = []
var right_tare_adc: Array = []

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
	var tare: Array = left_tare_adc if side == "left" else right_tare_adc
	var forces := []
	for i in range(4):
		# Subtracting the force at tare cancels the calibration intercept.
		forces.append((raw_adc[i] - tare[i]) * gain[i] if tare.size() == 4 else raw_adc[i] * gain[i] - off[i])
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
## One row per board packet (~85 Hz per board), written as it arrives by
## SerialLink calling log_packet() -- not once per screen frame, which
## duplicated some samples and dropped others. The first 11 columns are
## Unity's MoBBoDeviceUDP.DataHeader with "ID" -> "side" (left/right):
##   systime  wall-clock time of the row
##   devtime  ms since the trial started
##   f1..f4   per-sensor force, kg (tared)
##   x, y     that board's own COP, cm, from its centre (+x right, +y front);
##            0,0 when the board carries <= COP_LOG_MIN_WEIGHT
##   F        that board's total weight, kg
## Added after Unity's columns, so old readers keep working:
##   gcop_x, gcop_y  combined COP of both boards, cm, left-board-centre frame
##   W_total         both boards' weight, kg
##   adc1..adc4      the raw HX711 counts, so the data can be recalibrated
##                   later with different numbers (see session_info.csv)

const TRIAL_DATA_HEADER := "side,systime,devtime,f1,f2,f3,f4,x,y,F,annotation,gcop_x,gcop_y,W_total,adc1,adc2,adc3,adc4\n"
const COP_LOG_MIN_WEIGHT := 1.0  # kg

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
	if _trial_logger != null:
		stop_trial_log()  # never leave a previous file open
	var fname := "%s-%d.csv" % [base_path, trial]
	_trial_logger = MoBBoDataLogger.new(fname, TRIAL_DATA_HEADER)
	_trial_start_ms = Time.get_ticks_msec()
	SessionPaths.log_event("raw log started: %s | left %s right %s | left tare %s | right tare %s" % [
		fname, SerialLink.left_port, SerialLink.right_port, str(left_tare_adc), str(right_tare_adc)
	])
	return fname

## Called by SerialLink for every accepted packet from either board.
func log_packet(side: String, adc: Array) -> void:
	if _trial_logger == null or adc.size() != 4:
		return
	var forces := forces_from_raw(adc, side)
	var w := total_weight(forces)
	var cop = board_cop(forces) if w > COP_LOG_MIN_WEIGHT else null
	var cx: float = 0.0 if cop == null else cop.x
	var cy: float = 0.0 if cop == null else cop.y
	var lf := SerialLink.left_forces()
	var rf := SerialLink.right_forces()
	var w_total := total_weight(lf) + total_weight(rf)
	var g = combined_cop(lf, rf) if w_total > COP_LOG_MIN_WEIGHT else null
	var gx: float = 0.0 if g == null else g.x
	var gy: float = 0.0 if g == null else g.y
	_trial_logger.log_data("%s,%s,%d,%.4f,%.4f,%.4f,%.4f,%.3f,%.3f,%.4f,%s,%.3f,%.3f,%.4f,%d,%d,%d,%d\n" % [
		side, Time.get_datetime_string_from_system(), Time.get_ticks_msec() - _trial_start_ms,
		forces[0], forces[1], forces[2], forces[3], cx, cy, w, annotation,
		gx, gy, w_total, adc[0], adc[1], adc[2], adc[3],
	])

## Kept so older callers don't break; logging is now per packet.
func log_trial_frame(_left_adc: Array, _right_adc: Array) -> void:
	pass

func stop_trial_log() -> void:
	if _trial_logger == null:
		return
	var fname := _trial_logger.curr_fname
	var rows := _trial_logger.rows_written
	_trial_logger.stop_data_log(true)
	_trial_logger = null
	SessionPaths.log_event("raw log saved: %s (%d rows)" % [fname, rows])

## Closing the window mid-trial still closes the file cleanly.
func _exit_tree() -> void:
	stop_trial_log()
