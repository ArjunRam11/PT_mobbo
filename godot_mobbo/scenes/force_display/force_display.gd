extends Control
## Port of force.cs: shows each board's 4 corner forces (font/dot size
## scaled by load) and live COP, both per-board and combined. Unity's
## version also let the operator draw a to-scale rectangle overlay from
## typed length/breadth input and tinted a board MeshRenderer's corner
## colors by force -- both were cosmetic extras on top of the same
## underlying force/COP data and weren't ported; the BoardView drawing here
## (corner dot + text scaled by force, COP marker) covers the same role of
## "see the force distribution at a glance."

const HUB_SCENE := "res://scenes/hub/hub.tscn"
const BOARD_SIZE := Vector2(320, 158)  # matches BoardData's ~2.04:1 board aspect ratio

var left_view: BoardView
var right_view: BoardView
var left_weight_label: Label
var right_weight_label: Label
var combined_label: Label

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
		margin.add_theme_constant_override("margin_%s" % side, 28)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)

	root.add_child(UiTheme.make_heading("Force Display"))
	root.add_child(UiTheme.make_muted_label("Live per-sensor force (kg) and center of pressure."))

	var boards_row := HBoxContainer.new()
	boards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	boards_row.add_theme_constant_override("separation", 24)
	root.add_child(boards_row)

	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 8)
	boards_row.add_child(left_col)
	left_col.add_child(UiTheme.make_subheading("Left Board"))
	left_view = BoardView.new()
	left_view.custom_minimum_size = BOARD_SIZE
	left_col.add_child(left_view)
	left_weight_label = UiTheme.make_field_label("W = -- kg")
	left_col.add_child(left_weight_label)

	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 8)
	boards_row.add_child(right_col)
	right_col.add_child(UiTheme.make_subheading("Right Board"))
	right_view = BoardView.new()
	right_view.custom_minimum_size = BOARD_SIZE
	right_col.add_child(right_view)
	right_weight_label = UiTheme.make_field_label("W = -- kg")
	right_col.add_child(right_weight_label)

	combined_label = UiTheme.make_subheading("Combined COP: waiting for data")
	root.add_child(combined_label)

	var back := UiTheme.make_secondary_button("Back to Hub")
	back.pressed.connect(func(): get_tree().change_scene_to_file(HUB_SCENE))
	root.add_child(back)

	SerialLink.board_updated.connect(func(_side): _refresh())
	_refresh()

func _refresh() -> void:
	var lf := SerialLink.left_forces()
	var rf := SerialLink.right_forces()

	left_view.set_data(lf, BoardData.board_cop(lf))
	right_view.set_data(rf, BoardData.board_cop(rf))

	left_weight_label.text = "W = %.2f kg" % BoardData.total_weight(lf) if SerialLink.has_left_data() else "W = -- kg"
	right_weight_label.text = "W = %.2f kg" % BoardData.total_weight(rf) if SerialLink.has_right_data() else "W = -- kg"

	if SerialLink.has_left_data() and SerialLink.has_right_data():
		var cop = BoardData.combined_cop(lf, rf)
		combined_label.text = "Combined COP: (%.1f, %.1f) cm" % [cop.x, cop.y] if cop != null else "Combined COP: no load"
	else:
		combined_label.text = "Combined COP: waiting for data"
