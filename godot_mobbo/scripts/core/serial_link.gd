extends Node
## Autoload singleton "SerialLink". Owns the single TCP connection to
## serial_bridge.py and the latest raw ADC reading from each board, so every
## scene reads one shared live data source instead of each owning its own
## socket. Mirrors how Unity's AppData_WIFI.Start()/MoBBoServer run once (at
## app/session start) and every game scene just polls the resulting statics
## each frame, rather than each scene managing its own connection.

signal status_changed(text: String)
signal error(text: String)
signal ports_updated(ports: Array)
signal board_updated(side: String)  # "left" or "right"

const HOST := "127.0.0.1"
const PORT := 23051

var tcp := StreamPeerTCP.new()
var connected := false

## Latest raw ADC readings (4 signed ints, HX711 #1-4 order). Empty until
## the first packet for that side arrives.
var left_adc: Array = []
var right_adc: Array = []

var _buffer := ""

func _ready() -> void:
	set_process(true)
	tcp.connect_to_host(HOST, PORT)

func _process(_delta: float) -> void:
	tcp.poll()
	var state := tcp.get_status()
	if state == StreamPeerTCP.STATUS_CONNECTED and not connected:
		connected = true
		status_changed.emit("Bridge connected.")
		request_ports()
	elif connected and state != StreamPeerTCP.STATUS_CONNECTED:
		connected = false
		status_changed.emit("Bridge disconnected. Restart serial_bridge.py and reopen the app.")
	if state != StreamPeerTCP.STATUS_CONNECTED:
		return
	var available := tcp.get_available_bytes()
	if available > 0:
		var received := tcp.get_data(available)
		if received[0] == OK:
			_buffer += received[1].get_string_from_utf8()
	while _buffer.contains("\n"):
		var end := _buffer.find("\n")
		var line := _buffer.substr(0, end)
		_buffer = _buffer.substr(end + 1)
		var msg = JSON.parse_string(line)
		if msg is Dictionary:
			_handle(msg)

func _handle(msg: Dictionary) -> void:
	match msg.get("type", ""):
		"ports":
			ports_updated.emit(msg.get("ports", []))
		"status":
			status_changed.emit(str(msg.get("message", "")))
		"error":
			error.emit(str(msg.get("message", "")))
		"data":
			var side := str(msg.get("side", ""))
			var adc: Array = msg.get("adc", [])
			if adc.size() != 4:
				return
			if side == "left":
				left_adc = adc
			else:
				right_adc = adc
			board_updated.emit(side)

func _send(message: Dictionary) -> void:
	if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		tcp.put_data((JSON.stringify(message) + "\n").to_utf8_buffer())
	else:
		error.emit("Bridge unavailable. Start serial_bridge.py and reopen the app.")

func request_ports() -> void:
	_send({"cmd": "ports"})

func connect_boards(port_a: String, port_b: String) -> void:
	_send({"cmd": "connect", "left": port_a, "right": port_b})

func disconnect_boards() -> void:
	_send({"cmd": "disconnect"})
	left_adc = []
	right_adc = []

func has_left_data() -> bool:
	return left_adc.size() == 4

func has_right_data() -> bool:
	return right_adc.size() == 4

func left_forces() -> Array:
	return BoardData.forces_from_raw(left_adc, "left") if has_left_data() else [0.0, 0.0, 0.0, 0.0]

func right_forces() -> Array:
	return BoardData.forces_from_raw(right_adc, "right") if has_right_data() else [0.0, 0.0, 0.0, 0.0]
