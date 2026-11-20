extends Node
## Autoload singleton "MoBBoNetwork". Port of MoBBoLibrary_WIFI.MoBBoUdpServer:
## owns the UDP socket, the device registration handshake, and dispatches
## incoming packets to the right MoBBoDeviceUDP.

const MAX_NO_OF_DEVS := 15
const RETX_MSG_COUNT := 5

# MoBoCommands: MSB 4 bits = command, LSB 4 bits = parameter.
const CMD_SET_ID := 0x00
const CMD_STREAM_OFF := 0x10
const CMD_STREAM_ON := 0x11
const CMD_LED_OFF := 0x20
const CMD_LED_ON := 0x21
const CMD_VIBRATE_OFF := 0x30
const CMD_VIBRATE_ON := 0x31
const CMD_RESET_TIMER := 0x40
const CMD_GET_STATUS := 0x50
const CMD_REGISTER := 0x80

var local_port: int = 23001
var remote_port: int = 23000

var mobbo_devs: Array = []        # size MAX_NO_OF_DEVS, MoBBoDeviceUDP or null
var _available_id: Array = []     # size MAX_NO_OF_DEVS, bool
var _ip_id_map: Dictionary = {}   # ip -> int id

var _socket: PacketPeerUDP
var _elapsed_ms_start: int = 0
var _log_detail: MoBBoDataLogger = null

var is_logging: bool:
	get: return _log_detail != null

func _ready() -> void:
	mobbo_devs.resize(MAX_NO_OF_DEVS)
	_available_id.resize(MAX_NO_OF_DEVS)
	for i in range(MAX_NO_OF_DEVS):
		_available_id[i] = true
	_elapsed_ms_start = Time.get_ticks_msec()

func start(p_local_port: int = local_port, p_remote_port: int = remote_port) -> bool:
	local_port = p_local_port
	remote_port = p_remote_port
	_socket = PacketPeerUDP.new()
	var err := _socket.bind(local_port)
	if err != OK:
		push_error("MoBBoNetwork: failed to bind UDP port %d (%s)" % [local_port, err])
		return false
	_socket.set_broadcast_enabled(true)
	set_process(true)
	return true

func stop() -> void:
	set_process(false)
	if _socket != null:
		_socket.close()
		_socket = null

func _process(_delta: float) -> void:
	if _socket == null:
		return
	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet()
		var sender_ip := _socket.get_packet_ip()
		_handle_received_message(packet, sender_ip)

## -- Outgoing commands ------------------------------------------------

func broadcast(msg: PackedByteArray) -> void:
	if msg.is_empty():
		return
	_socket.set_dest_address("255.255.255.255", remote_port)
	_socket.put_packet(msg)

func call_for_registration() -> void:
	broadcast(PackedByteArray([CMD_REGISTER]))

func reset_timers() -> void:
	broadcast(PackedByteArray([CMD_RESET_TIMER]))
	log_message("ResetTime")

func get_status() -> void:
	broadcast(PackedByteArray([CMD_GET_STATUS]))

func start_all() -> void:
	broadcast(PackedByteArray([CMD_STREAM_ON]))
	log_message("StartAll")

func stop_all() -> void:
	broadcast(PackedByteArray([CMD_STREAM_OFF]))
	log_message("StopAll")

func reset_ids() -> void:
	broadcast(PackedByteArray([CMD_SET_ID]))
	log_message("ResetID")

func send_to_ip(ip: String, port: int, msg: PackedByteArray) -> void:
	if msg.is_empty():
		return
	_socket.set_dest_address(ip, port)
	_socket.put_packet(msg)

func send_to_id(id: int, msg: PackedByteArray) -> void:
	if id <= 0 or msg.is_empty():
		return
	var dev: MoBBoDeviceUDP = mobbo_devs[id - 1]
	if dev != null:
		send_to_ip(dev.ip, dev.port, msg)

func _set_device_id(id: int) -> void:
	var dev: MoBBoDeviceUDP = mobbo_devs[id - 1]
	var msg := CMD_SET_ID | id
	send_to_ip(dev.ip, dev.port, PackedByteArray([msg]))

## -- Incoming handling -------------------------------------------------

func _handle_received_message(packet: PackedByteArray, sender_ip: String) -> void:
	if packet.is_empty():
		return
	var first_byte := packet[0]
	if is_registered_id(first_byte):
		var dev: MoBBoDeviceUDP = mobbo_devs[first_byte - 1]
		dev.add_packet(packet, Time.get_datetime_string_from_system(), _elapsed_ms())
	elif packet.size() > 1 and packet[1] == CMD_REGISTER:
		var id := get_id_for_ip(sender_ip)
		if id == 0:
			push_warning("MoBBoNetwork: can't register device from %s (no free IDs)" % sender_ip)
		elif mobbo_devs[id - 1] == null:
			mobbo_devs[id - 1] = MoBBoDeviceUDP.new(id, sender_ip, remote_port)
			for i in range(RETX_MSG_COUNT):
				_set_device_id(id)

func _elapsed_ms() -> int:
	return Time.get_ticks_msec() - _elapsed_ms_start

## -- Device ID bookkeeping ---------------------------------------------

func get_new_id() -> int:
	for i in range(_available_id.size()):
		if _available_id[i]:
			_available_id[i] = false
			return i + 1
	return 0

func get_id_for_ip(ip: String, new_id: bool = true) -> int:
	if not _ip_id_map.has(ip):
		if not new_id:
			return 0
		_ip_id_map[ip] = get_new_id()
	return _ip_id_map[ip]

func is_registered_id(id: int) -> bool:
	if id <= 0 or id >= MAX_NO_OF_DEVS:
		return false
	return not _available_id[id - 1]

func get_number_of_registered_devices() -> int:
	var cnt := 0
	for available in _available_id:
		if not available:
			cnt += 1
	return cnt

func get_registered_ids() -> Array:
	var ids: Array = []
	for i in range(_available_id.size()):
		if not _available_id[i]:
			ids.append(mobbo_devs[i].id)
	return ids

func clear_all_devices() -> void:
	for i in range(MAX_NO_OF_DEVS):
		_available_id[i] = true
		mobbo_devs[i] = null
	_ip_id_map.clear()

## -- Logging ------------------------------------------------------------

func log_message(msg: String) -> void:
	if _log_detail != null:
		_log_detail.log_data("%s %d\n" % [msg, _elapsed_ms()])

func start_logging(fname: String) -> void:
	_log_detail = MoBBoDataLogger.new("%s-logdetials.ldt" % fname, "Raw data logging details\n")
	for dev in mobbo_devs:
		if dev != null:
			_log_detail.log_data("DevID %d %s\n" % [dev.id, dev.start_logger(fname)])
	_log_detail.log_data("LogStart %s %d\n" % [Time.get_datetime_string_from_system(), _elapsed_ms()])

func start_logging_trial(fname: String, trial: int) -> void:
	_log_detail = MoBBoDataLogger.new("%s-logdetials.ldt" % fname, "Raw data logging details\n")
	for dev in mobbo_devs:
		if dev != null:
			_log_detail.log_data("DevID %d %s\n" % [dev.id, dev.start_logger_trial(fname, trial)])
	_log_detail.log_data("LogStart %s %d\n" % [Time.get_datetime_string_from_system(), _elapsed_ms()])

func stop_logging() -> void:
	if _log_detail == null:
		push_warning("MoBBoNetwork: no active logging session to stop.")
		return
	for dev in mobbo_devs:
		if dev != null:
			dev.stop_logger()
	_log_detail.log_data("LogStop %s %d\n" % [Time.get_datetime_string_from_system(), _elapsed_ms()])
	_log_detail.stop_data_log(true)
	_log_detail = null
