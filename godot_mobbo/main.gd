extends Control
## Board Diagnostics screen. All live-data plumbing (the TCP connection to
## serial_bridge.py, latest raw ADC per board) lives in the SerialLink
## autoload now, shared by every scene -- this screen just displays it and
## lets the operator pick/connect the two serial ports.

var left: OptionButton
var right: OptionButton
var status: Label
var left_data: Label
var right_data: Label
var combined_data: Label

func _ready() -> void:
    theme = UiTheme.theme
    var bg := ColorRect.new()
    bg.color = UiTheme.COLOR_BACKGROUND
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_%s" % side, 24)
    add_child(margin)

    var panel := VBoxContainer.new()
    panel.add_theme_constant_override("separation", 16)
    margin.add_child(panel)

    panel.add_child(UiTheme.make_heading("Board Diagnostics"))
    status = UiTheme.make_muted_label("Connecting to local serial bridge...")
    panel.add_child(status)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    panel.add_child(row)
    left = OptionButton.new()
    left.custom_minimum_size = UiTheme.MIN_TOUCH_SIZE
    right = OptionButton.new()
    right.custom_minimum_size = UiTheme.MIN_TOUCH_SIZE
    row.add_child(UiTheme.make_field_label("Board A port"))
    row.add_child(left)
    row.add_child(UiTheme.make_field_label("Board B port"))
    row.add_child(right)

    var action_row := HBoxContainer.new()
    action_row.add_theme_constant_override("separation", 12)
    panel.add_child(action_row)
    var refresh := UiTheme.make_primary_button("Refresh ports")
    refresh.pressed.connect(func(): SerialLink.request_ports())
    action_row.add_child(refresh)
    var connect_button := UiTheme.make_accent_button("Connect boards")
    connect_button.pressed.connect(_connect_boards)
    action_row.add_child(connect_button)
    var disconnect_button := UiTheme.make_destructive_button("Disconnect")
    disconnect_button.pressed.connect(func(): SerialLink.disconnect_boards())
    action_row.add_child(disconnect_button)

    left_data = UiTheme.make_subheading("Left board: waiting for data")
    right_data = UiTheme.make_subheading("Right board: waiting for data")
    combined_data = UiTheme.make_subheading("Combined COP: waiting for data")
    panel.add_child(left_data)
    panel.add_child(right_data)
    panel.add_child(combined_data)
    panel.add_child(UiTheme.make_field_label("Weight in kg, COP in cm. Board origin = each board's own center; combined COP uses the left board's center as origin."))

    var back := UiTheme.make_secondary_button("Back to Hub")
    back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
    panel.add_child(back)

    SerialLink.status_changed.connect(func(text): UiTheme.set_status(status, text, "neutral"))
    SerialLink.error.connect(func(text): UiTheme.set_status(status, text, "error"))
    SerialLink.ports_updated.connect(_on_ports_updated)
    SerialLink.board_updated.connect(_on_board_updated)
    if SerialLink.connected:
        SerialLink.request_ports()
    _refresh_readouts()

func _connect_boards() -> void:
    if left.item_count == 0 or right.item_count == 0:
        UiTheme.set_status(status, "refresh and select two available ports.", "error")
        return
    var lp := left.get_item_text(left.selected)
    var rp := right.get_item_text(right.selected)
    if lp == rp:
        UiTheme.set_status(status, "choose different ports for Board A and Board B.", "error")
        return
    SerialLink.connect_boards(lp, rp)

func _on_ports_updated(ports: Array) -> void:
    var old_left := left.get_item_text(left.selected) if left.selected >= 0 else ""
    var old_right := right.get_item_text(right.selected) if right.selected >= 0 else ""
    left.clear()
    right.clear()
    for port in ports:
        left.add_item(port)
        right.add_item(port)
        if port == old_left: left.select(left.item_count - 1)
        if port == old_right: right.select(right.item_count - 1)

func _on_board_updated(_side: String) -> void:
    _refresh_readouts()

func _refresh_readouts() -> void:
    left_data.text = _board_line("Left", SerialLink.left_forces()) if SerialLink.has_left_data() else "Left board: waiting for data"
    right_data.text = _board_line("Right", SerialLink.right_forces()) if SerialLink.has_right_data() else "Right board: waiting for data"
    if SerialLink.has_left_data() and SerialLink.has_right_data():
        var cop = BoardData.combined_cop(SerialLink.left_forces(), SerialLink.right_forces())
        combined_data.text = "Combined (left-board origin): COP = (%.1f, %.1f) cm" % [cop.x, cop.y] if cop != null else "Combined COP: no load"
    else:
        combined_data.text = "Combined COP: waiting for data"

func _board_line(label: String, forces: Array) -> String:
    var w: float = BoardData.total_weight(forces)
    var cop = BoardData.board_cop(forces)
    var cop_str := "no load" if cop == null else "(%.1f, %.1f) cm" % [cop.x, cop.y]
    return "%s board: W = %.2f kg, COP = %s" % [label, w, cop_str]
