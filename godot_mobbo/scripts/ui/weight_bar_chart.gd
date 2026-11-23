class_name WeightBarChart
extends Control
## Vertical bar chart of left-board, right-board and total weight (kg).
## Left/right bars also show their share of the total. The y axis rescales
## in 20 kg steps so the total bar always fits.

const MIN_Y_MAX := 20.0
const BAR_COLORS := [UiTheme.COLOR_BLUE, UiTheme.COLOR_GREEN, UiTheme.COLOR_YELLOW]
## Board names follow the rig layout (Left/Right or Top/Bottom).
func _names() -> Array:
	return [BoardData.board_name("left").capitalize(), BoardData.board_name("right").capitalize(), "Total"]

var _values := [0.0, 0.0, 0.0]
var _has := [false, false, false]

func set_values(left_w: float, right_w: float, has_left: bool, has_right: bool) -> void:
	_values = [left_w, right_w, (left_w if has_left else 0.0) + (right_w if has_right else 0.0)]
	_has = [has_left, has_right, has_left or has_right]
	queue_redraw()

func _y_max() -> float:
	var top := 0.0
	for i in range(3):
		if _has[i]:
			top = maxf(top, _values[i])
	# Multiple of 20 so the 4 grid steps land on whole 5 kg values.
	return maxf(MIN_Y_MAX, ceilf(top * 1.15 / 20.0) * 20.0)

func _draw() -> void:
	var font: Font = UiTheme.font_regular
	var value_font: Font = UiTheme.font_heading
	var k := clampf(size.y / 320.0, 0.85, 1.8)
	var small := int(13 * k)
	var value_size := int(17 * k)
	var plot := Rect2(Vector2(48 * k, maxf(value_size + 14, small * 2.0 + 8)), Vector2.ZERO)
	plot.end = Vector2(size.x - 8, size.y - (small * 2 + 22))
	if plot.size.x <= 10 or plot.size.y <= 10:
		return

	# Grid + y labels.
	var y_max := _y_max()
	for i in range(5):
		var v := y_max * i / 4.0
		var y := plot.end.y - plot.size.y * i / 4.0
		var c := UiTheme.COLOR_BORDER if i > 0 else Color(UiTheme.COLOR_MUTED_TEXT, 0.5)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), c, 1.0)
		draw_string(font, Vector2(0, y + small * 0.35), "%d" % int(v), HORIZONTAL_ALIGNMENT_RIGHT,
			plot.position.x - 8, small, UiTheme.COLOR_MUTED_TEXT)
	draw_string(font, Vector2(0, small), "kg", HORIZONTAL_ALIGNMENT_RIGHT,
		plot.position.x - 8, small, UiTheme.COLOR_MUTED_TEXT)

	# Bars.
	var slot := plot.size.x / 3.0
	var bar_w := minf(slot * 0.55, 120.0 * k)
	var total: float = _values[2]
	for i in range(3):
		var cx := plot.position.x + slot * (i + 0.5)
		var v: float = _values[i]
		var h := plot.size.y * clampf(v / y_max, 0.0, 1.0) if _has[i] else 0.0
		if h > 0.0:
			var sb := StyleBoxFlat.new()
			sb.bg_color = BAR_COLORS[i]
			sb.corner_radius_top_left = 4
			sb.corner_radius_top_right = 4
			draw_style_box(sb, Rect2(cx - bar_w * 0.5, plot.end.y - h, bar_w, h))
		var value_text := "%.1f" % v if _has[i] else "--"
		draw_string(value_font, Vector2(cx - slot * 0.5, plot.end.y - h - 8), value_text,
			HORIZONTAL_ALIGNMENT_CENTER, slot, value_size, BAR_COLORS[i] if _has[i] else UiTheme.COLOR_MUTED_TEXT)
		# Category + share of total under the axis.
		draw_string(font, Vector2(cx - slot * 0.5, plot.end.y + small + 8), _names()[i],
			HORIZONTAL_ALIGNMENT_CENTER, slot, small, UiTheme.COLOR_TEXT)
		var sub := ""
		if i < 2 and _has[i] and total > 0.5:
			sub = "%.0f%%" % (v / total * 100.0)
		elif i == 2:
			sub = "T + B" if BoardData.is_top_bottom() else "L + R"
		draw_string(font, Vector2(cx - slot * 0.5, plot.end.y + small * 2 + 14), sub,
			HORIZONTAL_ALIGNMENT_CENTER, slot, small, UiTheme.COLOR_MUTED_TEXT)
