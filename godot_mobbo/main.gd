extends Control

var tcp := StreamPeerTCP.new()
var buffer := ""
var left: OptionButton
var right: OptionButton
var status: Label
var left_data: Label
var right_data: Label
var connected := false

func _ready() -> void:
    var panel := VBoxContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.add_theme_constant_override("separation", 14)
    add_child(panel)
    var heading := Label.new()
    heading.text = "MoBBo — two-board serial monitor"
    heading.add_theme_font_size_override("font_size", 26)
    panel.add_child(heading)
    status = Label.new()
    status.text = "Connecting to local serial bridge..."
    panel.add_child(status)
    var row := HBoxContainer.new()
    panel.add_child(row)
    left = OptionButton.new()
    right = OptionButton.new()
    row.add_child(_label("Left board: "))
    row.add_child(left)
    row.add_child(_label("   Right board: "))
    row.add_child(right)
    var refresh := Button.new()
    refresh.text = "Refresh ports"
    refresh.pressed.connect(func(): _send({"cmd":"ports"}))
    row.add_child(refresh)
    var connect_button := Button.new()
    connect_button.text = "Connect boards"
    connect_button.pressed.connect(_connect_boards)
    row.add_child(connect_button)
    var disconnect_button := Button.new()
    disconnect_button.text = "Disconnect"
    disconnect_button.pressed.connect(func(): _send({"cmd":"disconnect"}))
    row.add_child(disconnect_button)
    left_data = _label("Left: waiting for data")
    right_data = _label("Right: waiting for data")
    panel.add_child(left_data)
    panel.add_child(right_data)
    panel.add_child(_label("Raw signed ADC values: sensor 1, 2, 3, 4. No calibration or tare is applied."))
    tcp.connect_to_host("127.0.0.1", 23051)

func _label(value: String) -> Label:
    var result := Label.new()
    result.text = value
    return result

func _connect_boards() -> void:
    if left.item_count == 0 or right.item_count == 0:
        status.text = "Refresh and select two available ports."
        return
    var lp := left.get_item_text(left.selected)
    var rp := right.get_item_text(right.selected)
    if lp == rp:
        status.text = "Choose different ports for left and right."
        return
    _send({"cmd":"connect", "left":lp, "right":rp})

func _send(message: Dictionary) -> void:
    if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
        tcp.put_data((JSON.stringify(message) + "\n").to_utf8_buffer())
    else:
        status.text = "Bridge unavailable. Start serial_bridge.py and reopen this project."

func _process(_delta: float) -> void:
    tcp.poll()
    var state := tcp.get_status()
    if state == StreamPeerTCP.STATUS_CONNECTED and not connected:
        connected = true
        status.text = "Bridge connected. Select two ports."
        _send({"cmd":"ports"})
    elif connected and state != StreamPeerTCP.STATUS_CONNECTED:
        connected = false
        status.text = "Bridge disconnected. Restart the bridge and reopen the project."
    if state != StreamPeerTCP.STATUS_CONNECTED:
        return
    var available := tcp.get_available_bytes()
    if available > 0:
        var received := tcp.get_data(available)
        if received[0] == OK:
            buffer += received[1].get_string_from_utf8()
    while buffer.contains("\n"):
        var end := buffer.find("\n")
        var line := buffer.substr(0, end)
        buffer = buffer.substr(end + 1)
        var msg = JSON.parse_string(line)
        if msg is Dictionary:
            _handle(msg)

func _handle(msg: Dictionary) -> void:
    match msg.get("type", ""):
        "ports":
            var old_left := left.get_item_text(left.selected) if left.selected >= 0 else ""
            var old_right := right.get_item_text(right.selected) if right.selected >= 0 else ""
            left.clear()
            right.clear()
            for port in msg.get("ports", []):
                left.add_item(port)
                right.add_item(port)
                if port == old_left: left.select(left.item_count - 1)
                if port == old_right: right.select(right.item_count - 1)
        "status", "error":
            status.text = str(msg.get("message", ""))
        "data":
            var target := left_data if msg.get("side") == "left" else right_data
            target.text = str(msg.get("side", "")).capitalize() + ": " + str(msg.get("values", []))
