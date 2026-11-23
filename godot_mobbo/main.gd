extends Control
## Board Diagnostics screen. All live-data plumbing (direct USB serial via the
## gdserial addon, latest raw ADC per board) lives in the SerialLink
## autoload now, shared by every scene -- this screen just displays it and
## lets the operator auto-detect or pick/connect the two serial ports.

var left: OptionButton
var right: OptionButton
var status: Label
var left_data: Label
var right_data: Label
var left_adc_labels: Array[Label] = []
var right_adc_labels: Array[Label] = []
var adc_status: Label
var auto_button: Button
var ADC_COLORS: Array = UiTheme.SERIES_COLORS  # LC1-LC4: red, green, blue, amber

func _ready() -> void:
    theme = UiTheme.theme
    var bg := UiTheme.make_background()
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
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    margin.add_child(scroll)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(panel)

    var eyebrow := UiTheme.make_eyebrow("Hardware  ·  serial link")
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    panel.add_child(eyebrow)
    panel.add_child(UiTheme.make_heading("Board Diagnostics"))
    status = UiTheme.make_muted_label("Press Auto connect, or pick the two ports and press Connect.")
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(status)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    panel.add_child(row)
    left = OptionButton.new()
    left.custom_minimum_size = UiTheme.MIN_TOUCH_SIZE
    right = OptionButton.new()
    right.custom_minimum_size = UiTheme.MIN_TOUCH_SIZE
    row.add_child(UiTheme.make_field_label("Board A (%s)" % BoardData.board_name("left")))
    row.add_child(left)
    row.add_child(UiTheme.make_field_label("Board B (%s)" % BoardData.board_name("right")))
    row.add_child(right)

    var action_row := HBoxContainer.new()
    action_row.add_theme_constant_override("separation", 12)
    panel.add_child(action_row)
    auto_button = UiTheme.make_accent_button("Auto connect")
    auto_button.pressed.connect(_on_auto_connect_pressed)
    action_row.add_child(auto_button)
    var refresh := UiTheme.make_secondary_button("Refresh ports")
    refresh.pressed.connect(func(): SerialLink.request_ports())
    action_row.add_child(refresh)
    var connect_button := UiTheme.make_primary_button("Connect selected")
    connect_button.pressed.connect(_connect_boards)
    action_row.add_child(connect_button)
    var disconnect_button := UiTheme.make_destructive_button("Disconnect")
    disconnect_button.pressed.connect(func(): SerialLink.disconnect_boards())
    action_row.add_child(disconnect_button)

    left_data = UiTheme.make_subheading("%s: waiting for data" % BoardData.board_title("left"))
    right_data = UiTheme.make_subheading("%s: waiting for data" % BoardData.board_title("right"))
    panel.add_child(left_data)
    panel.add_child(right_data)
    var tare_hint := UiTheme.make_field_label("Keep both boards unloaded while connecting: the first 20 samples per board are used for tare. Values are in kg.")
    tare_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(tare_hint)

    panel.add_child(UiTheme.make_subheading("Raw ADC readings (counts)"))
    adc_status = UiTheme.make_field_label("Waiting for board data")
    panel.add_child(adc_status)
    panel.add_child(UiTheme.make_field_label(BoardData.board_title("left")))
    panel.add_child(_make_adc_row(left_adc_labels))
    panel.add_child(UiTheme.make_field_label(BoardData.board_title("right")))
    panel.add_child(_make_adc_row(right_adc_labels))

    var back := UiTheme.make_secondary_button("Back to Hub")
    back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
    panel.add_child(back)

    SerialLink.status_changed.connect(func(text): UiTheme.set_status(status, text, "neutral"))
    SerialLink.error.connect(func(text): UiTheme.set_status(status, text, "error"))
    SerialLink.ports_updated.connect(_on_ports_updated)
    SerialLink.board_updated.connect(_on_board_updated)
    SerialLink.auto_connect_finished.connect(_on_auto_connect_finished)
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
    if old_right == "" and right.item_count > 1:
        right.select(1)

func _on_board_updated(_side: String) -> void:
    _refresh_readouts()

func _refresh_readouts() -> void:
    left_data.text = _board_line(BoardData.board_name("left").capitalize(), SerialLink.left_forces()) if SerialLink.has_left_data() else "%s: waiting for data" % BoardData.board_title("left")
    right_data.text = _board_line(BoardData.board_name("right").capitalize(), SerialLink.right_forces()) if SerialLink.has_right_data() else "%s: waiting for data" % BoardData.board_title("right")
    _update_adc_row(left_adc_labels, SerialLink.left_adc)
    _update_adc_row(right_adc_labels, SerialLink.right_adc)

func _make_adc_row(labels: Array[Label]) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    for i in range(4):
        var cell := PanelContainer.new()
        cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var style := StyleBoxFlat.new()
        style.bg_color = Color(ADC_COLORS[i], 0.05)
        style.set_border_width_all(1)
        style.set_corner_radius_all(UiTheme.CORNER_RADIUS)
        style.border_color = ADC_COLORS[i]
        style.content_margin_left = 12
        style.content_margin_right = 12
        style.content_margin_top = 10
        style.content_margin_bottom = 10
        cell.add_theme_stylebox_override("panel", style)
        var value := Label.new()
        value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        value.add_theme_color_override("font_color", ADC_COLORS[i])
        value.add_theme_font_override("font", UiTheme.font_bold)
        value.text = "LC%d: --" % (i + 1)
        cell.add_child(value)
        labels.append(value)
        row.add_child(cell)
    return row

func _update_adc_row(labels: Array[Label], adc: Array) -> void:
    for i in range(4):
        labels[i].text = "LC%d: %s" % [i + 1, str(adc[i]) if adc.size() == 4 else "--"]

func _process(_delta: float) -> void:
    adc_status.text = "Left: %s   |   Right: %s" % [_adc_age(SerialLink.left_received_ms), _adc_age(SerialLink.right_received_ms)]

func _adc_age(last_ms: int) -> String:
    if not SerialLink.connected:
        return "ports not open"
    if last_ms == 0:
        return "waiting for data"
    var age := (Time.get_ticks_msec() - last_ms) / 1000.0
    return "receiving" if age < 2.0 else "last packet %.1f s ago" % age

func _board_line(label: String, forces: Array) -> String:
    return "%s board: LC1 = %.2f, LC2 = %.2f, LC3 = %.2f, LC4 = %.2f kg" % [label, forces[0], forces[1], forces[2], forces[3]]

func _on_auto_connect_pressed() -> void:
    auto_button.disabled = true
    auto_button.text = "Scanning..."
    SerialLink.auto_connect()

## Reflect the detected ports in the dropdowns (Board A = left, Board B = right).
func _on_auto_connect_finished(_ok: bool, left_port: String, right_port: String) -> void:
    auto_button.disabled = false
    auto_button.text = "Auto connect"
    SerialLink.request_ports()
    for i in left.item_count:
        if left.get_item_text(i) == left_port: left.select(i)
        if right.get_item_text(i) == right_port: right.select(i)
