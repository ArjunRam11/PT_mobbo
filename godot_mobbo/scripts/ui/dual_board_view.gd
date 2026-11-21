class_name DualBoardView
extends Control
## Both boards side by side, scaled to fill whatever space this control gets
## (keeping the real board aspect ratio), with each board's own COP in red
## and the combined COP of both boards in mango yellow drawn on top.
## Titles above and "W = x kg" below each board are drawn here too, so they
## stay aligned with the boards at any size.

const GAP := 18.0
const TITLE_H := 30.0
const WEIGHT_H := 40.0
const COMBINED_COP_RADIUS := 11.0

var left_view: BoardView
var right_view: BoardView
var _overlay: Control

var left_weight_text := "W = -- kg"
var right_weight_text := "W = -- kg"
var combined_cop: Variant = null  # Vector2 in BoardData.combined_cop's frame, or null

func _init() -> void:
	left_view = BoardView.new()
	right_view = BoardView.new()
	add_child(left_view)
	add_child(right_view)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	resized.connect(_layout)

## Pass null for a COP to hide it.
func set_data(lf: Array, l_cop: Variant, rf: Array, r_cop: Variant, p_combined: Variant, l_text: String, r_text: String) -> void:
	left_view.set_data(lf, l_cop)
	right_view.set_data(rf, r_cop)
	combined_cop = p_combined
	left_weight_text = l_text
	right_weight_text = r_text
	_overlay.queue_redraw()

func _layout() -> void:
	var aspect := BoardData.L_HALF / BoardData.B_HALF
	var avail_h := maxf(size.y - TITLE_H - WEIGHT_H, 40.0)
	var board_w := minf((size.x - GAP) * 0.5, avail_h * aspect)
	var board_h := board_w / aspect
	var x0 := (size.x - (2.0 * board_w + GAP)) * 0.5
	var y0 := TITLE_H + (avail_h - board_h) * 0.5
	left_view.position = Vector2(x0, y0)
	left_view.size = Vector2(board_w, board_h)
	right_view.position = Vector2(x0 + board_w + GAP, y0)
	right_view.size = Vector2(board_w, board_h)
	_overlay.position = Vector2.ZERO
	_overlay.size = size
	_overlay.queue_redraw()

## Combined-frame cm (origin = left board centre) -> this control's pixels.
## The right board's half uses its own drawn rect, so the on-screen gap
## between the boards doesn't shift the marker.
func _combined_to_px(c: Vector2) -> Vector2:
	var split := BoardData.right_board_offset.x * 0.5
	if c.x <= split:
		return left_view.position + left_view.cm_to_px(c)
	return right_view.position + right_view.cm_to_px(c - BoardData.right_board_offset)

func _draw_overlay() -> void:
	var title_font: Font = UiTheme.font_regular
	var weight_font: Font = UiTheme.font_heading
	var k := clampf(left_view.size.x / BoardView.REFERENCE_WIDTH, 0.8, 2.0)
	var title_size := int(14 * k)
	var weight_size := int(18 * k)
	for pair in [[left_view, "Left board", left_weight_text], [right_view, "Right board", right_weight_text]]:
		var v: BoardView = pair[0]
		_overlay.draw_string(title_font, Vector2(v.position.x, v.position.y - 10), pair[1],
			HORIZONTAL_ALIGNMENT_CENTER, v.size.x, title_size, UiTheme.COLOR_MUTED_TEXT)
		_overlay.draw_string(weight_font, Vector2(v.position.x, v.position.y + v.size.y + 10 + weight_size), pair[2],
			HORIZONTAL_ALIGNMENT_CENTER, v.size.x, weight_size, UiTheme.COLOR_TEXT)

	if combined_cop != null:
		var p := _combined_to_px(combined_cop)
		var r := COMBINED_COP_RADIUS * k
		# Crosshair + ring + dot so it reads apart from the red per-board COPs.
		var line := Color(UiTheme.COLOR_YELLOW, 0.55)
		_overlay.draw_line(p - Vector2(r * 2.0, 0), p + Vector2(r * 2.0, 0), line, 1.5)
		_overlay.draw_line(p - Vector2(0, r * 2.0), p + Vector2(0, r * 2.0), line, 1.5)
		_overlay.draw_circle(p, r, UiTheme.COLOR_YELLOW)
		_overlay.draw_arc(p, r + 3.0, 0, TAU, 32, UiTheme.COLOR_BACKGROUND, 2.0, true)
