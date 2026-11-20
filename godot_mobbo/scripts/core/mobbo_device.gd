class_name MoBBoDeviceUDP
extends RefCounted
## Port of MoBBoLibrary_WIFI.MoBBoDeviceUDP. Decodes one board's raw UDP
## packets and keeps a short rolling history of its latest readings.

const PACKET_SIZE := 32  # bytes; 8 little-endian floats

static var annotation: String = "0"
static var _headernames := ["ID", "systime", "devtime", "f1", "f2", "f3", "f4", "x", "y", "F", "annotation"]
static var data_header: String = ",".join(_headernames) + "\n"

var id: int
var ip: String
var port: int
var active: bool = true
var data_rate: float = 0.0

var raw_bytes: FixedSizeQueue
var raw_data: FixedSizeQueue  # Array[float], 8 entries per packet

var _curr_time_ms: int = 0
var _prev_time_ms: int = 0
var _logger: MoBBoDataLogger = null

func _init(p_id: int, p_ip: String, p_port: int) -> void:
	id = p_id
	ip = p_ip
	port = p_port
	raw_bytes = FixedSizeQueue.new(5)
	raw_data = FixedSizeQueue.new(5)

func _last_bytes() -> PackedByteArray:
	return raw_bytes.last if raw_bytes.size > 0 else PackedByteArray()

func _last_floats() -> Array:
	return raw_data.last if raw_data.size > 0 else [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

var reserved_byte_1: int:
	get:
		var b := _last_bytes()
		return b[1] if b.size() > 1 else 0
var reserved_byte_2: int:
	get:
		var b := _last_bytes()
		return b[2] if b.size() > 2 else 0
var reserved_byte_3: int:
	get:
		var b := _last_bytes()
		return b[3] if b.size() > 3 else 0

var time: float:
	get: return _last_floats()[1]
var f1: float:
	get: return _last_floats()[2]
var f2: float:
	get: return _last_floats()[3]
var f3: float:
	get: return _last_floats()[4]
var f4: float:
	get: return _last_floats()[5]
var f: float:
	get:
		var v := _last_floats()
		return v[2] + v[3] + v[4] + v[5]
var x: float:
	get: return _last_floats()[6]
var y: float:
	get: return _last_floats()[7]

var led_on: bool:
	get: return (reserved_byte_1 & 0x80) == 0x80
var vibrate_on: bool:
	get: return (reserved_byte_1 & 0x40) == 0x40
var streaming: bool:
	get: return (reserved_byte_1 & 0x20) == 0x20
var is_logging: bool:
	get: return _logger != null

func start_logger(fname: String) -> String:
	if _logger == null:
		_logger = MoBBoDataLogger.new("%s-%d.csv" % [fname, id], data_header)
	return _logger.curr_fname

func start_logger_trial(fname: String, trial: int) -> String:
	_logger = MoBBoDataLogger.new("%s-%d-%d.csv" % [fname, trial, id], data_header)
	return _logger.curr_fname

func stop_logger() -> void:
	if _logger != null:
		_logger.stop_data_log(true)

## `packet` is the raw UDP payload (ID byte + reserved bytes + 7 floats,
## little-endian, PACKET_SIZE bytes total). `systime` is a formatted
## timestamp string; `millis` is the server's elapsed-ms clock.
func add_packet(packet: PackedByteArray, systime: String, millis: int) -> void:
	_curr_time_ms = millis
	var bytes := packet.slice(0, PACKET_SIZE)
	var floats: Array = []
	for i in range(PACKET_SIZE / 4):
		floats.append(bytes.decode_float(i * 4))
	raw_bytes.enqueue(bytes)
	raw_data.enqueue(floats)

	var dt := 0.001 * (_curr_time_ms - _prev_time_ms)
	_update_data_rate(dt)
	_prev_time_ms = _curr_time_ms

	if _logger != null:
		_logger.log_data(get_formatted_packet(systime, id, floats))

static func get_formatted_packet(curr_time: String, dev_id: int, floats: Array) -> String:
	var vals := []
	vals.append(str(dev_id))
	vals.append(curr_time)
	for i in range(2, 9):
		vals.append("%.10f" % floats[i - 1])
	var total_f: float = floats[2] + floats[3] + floats[4] + floats[5]
	vals.append("%.10f" % total_f)
	vals.append(annotation)
	return ", ".join(vals) + "\n"

func _update_data_rate(dt: float) -> void:
	if is_inf(data_rate):
		data_rate = -1.0
	elif dt != 0.0:
		data_rate = 0.7 * data_rate + 0.3 / dt
