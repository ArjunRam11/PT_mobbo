extends Node
## Autoload singleton "SerialLink". Reads both MoBBo boards directly over USB
## serial with the gdserial GDExtension (res://addons/gdserial) -- no Python
## bridge. Owns the latest raw ADC reading from each board, so every scene
## reads one shared live data source. Mirrors how Unity's
## AppData_WIFI.Start()/MoBBoServer run once and every game scene just polls
## the resulting statics each frame.
##
## Wire format (s_mobbo/s_mobbo.ino, 115200 baud):
##   "adc1,adc2,adc3,adc4,boardno\r\n"   boardno 0 = left, 1 = right
##   "#..."                               diagnostic line from the firmware

signal status_changed(text: String)
signal error(text: String)
signal ports_updated(ports: Array)
signal board_updated(side: String)  # "left" or "right"
## Result of auto_connect(): ok = both boards found; ports are "" when missing.
signal auto_connect_finished(ok: bool, left_port: String, right_port: String)

const BAUD := 115200  # matches Serial.begin(115200) in s_mobbo.ino
const READ_TIMEOUT_MS := 50
const TARE_SAMPLES := 20
const MAX_LINE_BYTES := 256  # a valid packet is ~45 bytes
const NO_DATA_WARN_MS := 3000
const ADC_MIN := -8388608
const ADC_MAX := 8388607
const LC1_ZERO_RUN_WARN := 20
const SETTLE_MS := 250  # ignore packets this soon after opening a port
const AUTO_DETECT_MS := 2500  # how long auto_connect() listens before deciding

## True while at least one board's serial port is open.
var connected := false

## Latest raw ADC readings (4 signed ints, HX711 #1-4 order). Empty until
## the first packet for that side arrives.
var left_adc: Array = []
var right_adc: Array = []
var left_received_ms: int = 0
var right_received_ms: int = 0
## COM port currently feeding each side ("" until its boardno has been seen).
var left_port := ""
var right_port := ""

var _manager: RefCounted = null  # GdSerialManager
## port name -> per-port state
##   buffer: PackedByteArray, fallback_side: String, boardno: int,
##   last_line_ms: int, opened_ms: int, warned: bool
var _ports: Dictionary = {}
var _duplicate_warned := false
var _auto_deadline_ms := 0  # > 0 while auto_connect() is scanning
var _unknown_id := 0
var _left_tare_sum := [0.0, 0.0, 0.0, 0.0]
var _right_tare_sum := [0.0, 0.0, 0.0, 0.0]
var _left_tare_count := 0
var _right_tare_count := 0

func _ready() -> void:
	# Instantiate through ClassDB so this script still parses (and reports a
	# clear error) if the extension failed to load.
	if ClassDB.class_exists("GdSerialManager"):
		_manager = ClassDB.instantiate("GdSerialManager")
	if _manager == null:
		push_error("SerialLink: GdSerialManager not found. Is res://addons/gdserial installed?")
		call_deferred("emit_signal", "error", "gdserial extension not loaded. Check res://addons/gdserial and restart Godot.")
		set_process(false)
		return
	call_deferred("request_ports")

func _process(_delta: float) -> void:
	if _manager == null or _ports.is_empty():
		return
	for event in _manager.poll_events():
		var port := str(event.get("port", ""))
		if not _ports.has(port):
			continue
		if event.get("disconnected", false):
			_on_port_lost(port)
		else:
			_consume(port, event.get("data", PackedByteArray()))
	if _auto_deadline_ms > 0:
		_check_auto_connect()
	else:
		_check_silent_ports()

func _notification(what: int) -> void:
	# Stop the reader threads cleanly when the app closes.
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_close_all()

## -- Line assembly / parsing ---------------------------------------------

func _consume(port: String, data: PackedByteArray) -> void:
	var state: Dictionary = _ports[port]
	var buf: PackedByteArray = state.buffer
	buf.append_array(data)
	var start := 0
	var nl := buf.find(10, start)  # '\n'
	while nl != -1:
		var raw := buf.slice(start, nl)
		if _is_ascii(raw):  # skip ESP8266 boot-ROM noise (printed at 74880 baud)
			_handle_line(port, raw.get_string_from_ascii().strip_edges())
		start = nl + 1
		nl = buf.find(10, start)
	buf = buf.slice(start)
	if buf.size() > MAX_LINE_BYTES:
		buf.clear()  # garbage / wrong baud rate -- resync on the next newline
	state.buffer = buf

func _is_ascii(bytes: PackedByteArray) -> bool:
	for b in bytes:
		if b > 127:
			return false
	return true

func _handle_line(port: String, line: String) -> void:
	if line.is_empty():
		return
	var state: Dictionary = _ports[port]
	state.last_line_ms = Time.get_ticks_msec()
	if line.begins_with("#"):
		_handle_diagnostic(port, line)
		return
	var parts := line.split(",")
	if parts.size() != 5:
		return
	var adc := []
	for i in range(4):
		var p := parts[i].strip_edges()
		if not p.is_valid_int():
			return
		var v := p.to_int()
		if v < ADC_MIN or v > ADC_MAX:
			return
		adc.append(v)
	var bn := parts[4].strip_edges()
	if bn != "0" and bn != "1":
		return
	state.boardno = bn.to_int()
	# Readings in flight while the port was opening can carry the DTR glitch
	# (LC1 = 0); keep them out of the tare.
	if state.last_line_ms - state.opened_ms < SETTLE_MS:
		return
	_check_lc1_clamp(port, adc[0])
	var side := _side_for(port)
	if side == "left":
		left_adc = adc
		left_received_ms = state.last_line_ms
		left_port = port
	else:
		right_adc = adc
		right_received_ms = state.last_line_ms
		right_port = port
	_collect_tare(side, adc)
	board_updated.emit(side)

## LC1's SCK is on D3 = GPIO0, which the NodeMCU's USB auto-program circuit
## pulls low whenever DTR is asserted without RTS. HX711 #1 then never gets
## clocked and reads exactly 0. A real 24-bit reading is essentially never 0
## many times in a row, so flag it.
func _check_lc1_clamp(port: String, lc1: int) -> void:
	var state: Dictionary = _ports[port]
	state.lc1_zero_run = state.lc1_zero_run + 1 if lc1 == 0 else 0
	if state.lc1_zero_run == LC1_ZERO_RUN_WARN and not state.lc1_warned:
		state.lc1_warned = true
		error.emit("%s: LC1 reads exactly 0 -- GPIO0 (D3, LC1 clock) is being held low by DTR. %s" % [
			port,
			"Install the patched gdserial DLL (see addons/gdserial/MOBBO_PATCH.md)." if not _can_drive_lines() else "Unplug and replug the board."
		])

func _can_drive_lines() -> bool:
	return _manager != null and _manager.has_method("set_dtr") and _manager.has_method("set_rts")

func _handle_diagnostic(port: String, line: String) -> void:
	# "#WAIT,<mask>,<boardno>" -> some HX711s never became ready.
	var parts := line.substr(1).split(",")
	if parts.size() >= 2 and parts[0] == "WAIT":
		var mask := parts[1].to_int()
		var missing := []
		for i in range(4):
			if mask & (1 << i):
				missing.append("LC%d" % (i + 1))
		error.emit("%s: load cell(s) %s not responding -- check HX711 wiring/power." % [port, ", ".join(missing)])
	elif parts.size() >= 1 and parts[0] == "MOBBO":
		status_changed.emit("%s: firmware started (%s)." % [port, line])

## Which board a line belongs to comes from its own boardno field, not from
## the port it arrived on -- unless both boards were flashed with the SAME
## boardno, in which case fall back to the port order the operator chose
## (Board A = left, Board B = right) so neither side is starved of data.
func _side_for(port: String) -> String:
	var state: Dictionary = _ports[port]
	for other in _ports:
		if other != port and _ports[other].boardno == state.boardno:
			if not _duplicate_warned:
				_duplicate_warned = true
				error.emit("Both boards report boardno %d. Using port order (Board A = left, Board B = right). Reflash one board with Boardno \"%d\"." % [state.boardno, 1 - state.boardno])
			return state.fallback_side
	return "left" if state.boardno == 0 else "right"

func _check_silent_ports() -> void:
	var now := Time.get_ticks_msec()
	for port in _ports:
		var state: Dictionary = _ports[port]
		var since: int = state.last_line_ms if state.last_line_ms > 0 else state.opened_ms
		if not state.warned and now - since > NO_DATA_WARN_MS:
			state.warned = true
			error.emit("%s: no data for %d s. Check the board is flashed with s_mobbo.ino, the baud rate is %d, and no other program (Arduino serial monitor, serial_bridge.py) has the port open." % [port, int(NO_DATA_WARN_MS / 1000.0), BAUD])
		elif state.warned and state.last_line_ms > 0 and now - state.last_line_ms < NO_DATA_WARN_MS:
			state.warned = false

## -- Tare ------------------------------------------------------------------

func _collect_tare(side: String, adc: Array) -> void:
	var count := _left_tare_count if side == "left" else _right_tare_count
	if count >= TARE_SAMPLES:
		return
	var sums := _left_tare_sum if side == "left" else _right_tare_sum
	for i in range(4):
		sums[i] += float(adc[i])
	count += 1
	if side == "left":
		_left_tare_count = count
	else:
		_right_tare_count = count
	if count == TARE_SAMPLES:
		var tare := []
		for value in sums:
			tare.append(value / TARE_SAMPLES)
		if side == "left":
			BoardData.left_tare_adc = tare
		else:
			BoardData.right_tare_adc = tare
		status_changed.emit("Tare complete for %s board; keep both boards unloaded until both are ready." % side)

func _reset_boards() -> void:
	left_adc = []
	right_adc = []
	left_received_ms = 0
	right_received_ms = 0
	_left_tare_sum = [0.0, 0.0, 0.0, 0.0]
	_right_tare_sum = [0.0, 0.0, 0.0, 0.0]
	_left_tare_count = 0
	_right_tare_count = 0
	_duplicate_warned = false
	BoardData.left_tare_adc = []
	BoardData.right_tare_adc = []

## -- Port management ---------------------------------------------------------

func _open_port(port: String, fallback_side: String) -> bool:
	# RAW mode: gdserial's line-buffered mode flushes partial lines on every
	# read timeout, so lines are assembled here instead.
	if not _manager.open(port, BAUD, READ_TIMEOUT_MS, 0):
		return false
	# DTR and RTS both deasserted: neither resets the ESP8266 (RTS -> EN) nor
	# clamps GPIO0 = LC1's SCK (DTR -> GPIO0). Needs the patched gdserial.
	if _can_drive_lines():
		_manager.set_dtr(port, false)
		_manager.set_rts(port, false)
	var now := Time.get_ticks_msec()
	_ports[port] = {
		"buffer": PackedByteArray(),
		"fallback_side": fallback_side,
		"boardno": _next_unknown_id(),  # negative + unique until the board reports one
		"last_line_ms": 0,
		"opened_ms": now,
		"warned": false,
		"lc1_zero_run": 0,
		"lc1_warned": false,
	}
	return true

func _close_all() -> void:
	if _manager != null:
		for port in _ports.keys():
			_manager.close(port)
	_ports.clear()
	connected = false
	left_port = ""
	right_port = ""
	_auto_deadline_ms = 0

func _next_unknown_id() -> int:
	_unknown_id -= 1
	return _unknown_id

## -- Auto connect --------------------------------------------------------------

## Opens every USB serial port, listens for AUTO_DETECT_MS, and keeps the
## ports whose lines carry boardno 0 (left) or 1 (right). Everything else is
## closed again. Finishes early once both boards have been seen. Result comes
## back through auto_connect_finished (plus status_changed / error).
func auto_connect() -> void:
	if _manager == null:
		error.emit("gdserial extension not loaded.")
		auto_connect_finished.emit(false, "", "")
		return
	_close_all()
	_reset_boards()
	board_updated.emit("left")
	board_updated.emit("right")
	var candidates := []
	var info: Dictionary = _manager.list_ports()
	for key in info:
		var entry: Dictionary = info[key]
		# USB only: opening Bluetooth/virtual COM ports can stall for seconds.
		if str(entry.get("port_type", "")).begins_with("USB"):
			candidates.append(str(entry.get("port_name", "")))
	candidates.sort()
	if candidates.is_empty():
		error.emit("Auto connect: no USB serial ports found. Plug in the boards.")
		auto_connect_finished.emit(false, "", "")
		return
	var opened := 0
	for i in candidates.size():
		# Fallback side only matters if both boards report the same boardno.
		if _open_port(candidates[i], "left" if i % 2 == 0 else "right"):
			opened += 1
	connected = opened > 0
	if opened == 0:
		error.emit("Auto connect: could not open %s (in use by another program?)." % ", ".join(candidates))
		auto_connect_finished.emit(false, "", "")
		return
	_auto_deadline_ms = Time.get_ticks_msec() + AUTO_DETECT_MS
	status_changed.emit("Auto connect: listening on %s..." % ", ".join(candidates))

func _check_auto_connect() -> void:
	var by_boardno := {}
	for port in _ports:
		var bn: int = _ports[port].boardno
		if bn >= 0:
			by_boardno[bn] = by_boardno.get(bn, []) + [port]
	var both_seen := by_boardno.has(0) and by_boardno.has(1)
	if not both_seen and Time.get_ticks_msec() < _auto_deadline_ms:
		return
	_auto_deadline_ms = 0
	# Close ports that never identified as a board.
	for port in _ports.keys():
		if _ports[port].boardno < 0:
			_manager.close(port)
			_ports.erase(port)
	connected = not _ports.is_empty()
	var lp: String = by_boardno[0][0] if by_boardno.has(0) else ""
	var rp: String = by_boardno[1][0] if by_boardno.has(1) else ""
	if by_boardno.get(0, []).size() > 1 or by_boardno.get(1, []).size() > 1:
		error.emit("Auto connect: two boards report the same boardno. Reflash one so left = 0 and right = 1.")
		auto_connect_finished.emit(false, lp, rp)
	elif lp != "" and rp != "":
		status_changed.emit("Auto connected: left board on %s, right board on %s. Keep both unloaded for tare." % [lp, rp])
		auto_connect_finished.emit(true, lp, rp)
	else:
		var missing := []
		if lp == "": missing.append("left (boardno 0)")
		if rp == "": missing.append("right (boardno 1)")
		error.emit("Auto connect: %s board not found. Check its USB cable and firmware." % " and ".join(missing))
		auto_connect_finished.emit(false, lp, rp)

func _on_port_lost(port: String) -> void:
	_ports.erase(port)
	connected = not _ports.is_empty()
	error.emit("%s disconnected (cable unplugged or board reset)." % port)
	_reset_boards()
	board_updated.emit("left")
	board_updated.emit("right")

func request_ports() -> void:
	if _manager == null:
		error.emit("gdserial extension not loaded.")
		return
	var names := []
	var info: Dictionary = _manager.list_ports()
	for key in info:
		names.append(str(info[key].get("port_name", "")))
	names.sort()
	ports_updated.emit(names)
	if names.is_empty():
		status_changed.emit("No serial ports found. Plug in the boards and press Refresh.")

func connect_boards(port_a: String, port_b: String) -> void:
	if _manager == null:
		error.emit("gdserial extension not loaded.")
		return
	_close_all()
	_reset_boards()
	board_updated.emit("left")
	board_updated.emit("right")
	var failed := []
	if not _open_port(port_a, "left"):
		failed.append(port_a)
	if not _open_port(port_b, "right"):
		failed.append(port_b)
	connected = not _ports.is_empty()
	if failed.is_empty():
		status_changed.emit("Connected: %s, %s. Waiting for data." % [port_a, port_b])
	else:
		error.emit("Could not open %s (in use by another program, or unplugged?)." % ", ".join(failed))

func disconnect_boards() -> void:
	_close_all()
	_reset_boards()
	board_updated.emit("left")
	board_updated.emit("right")
	status_changed.emit("Boards disconnected.")

func has_left_data() -> bool:
	return left_adc.size() == 4 and BoardData.left_tare_adc.size() == 4

func has_right_data() -> bool:
	return right_adc.size() == 4 and BoardData.right_tare_adc.size() == 4

func left_forces() -> Array:
	return BoardData.forces_from_raw(left_adc, "left") if has_left_data() else [0.0, 0.0, 0.0, 0.0]

func right_forces() -> Array:
	return BoardData.forces_from_raw(right_adc, "right") if has_right_data() else [0.0, 0.0, 0.0, 0.0]
