class_name BoardView
extends Control
## Reusable to-scale 2D visualization of one physical board: its outline,
## each of its 4 corner sensors (force text, font/dot size scaled by load --
## port of force.cs's font-size-by-force behavior), and the board's live
## center-of-pressure marker. Text and dots scale with the drawn size, so the
## view can be any size (DualBoardView sizes it to fill its card).

const MIN_FORCE := 0.0
const MAX_FORCE := 150.0  # kg; same calibration range force.cs used
const MIN_FONT_SIZE := 14.0
const MAX_FONT_SIZE := 28.0
const MIN_DOT_RADIUS := 5.0
const MAX_DOT_RADIUS := 16.0
const COP_DOT_RADIUS := 9.0
const REFERENCE_WIDTH := 280.0  # sizes above are tuned for this board width

var forces: Array = [0.0, 0.0, 0.0, 0.0]
var cop: Variant = null  # Vector2 (cm, board-local) or null = don't draw
var cop_color: Color = UiTheme.COLOR_DESTRUCTIVE

func set_data(p_forces: Array, p_cop: Variant) -> void:
	forces = p_forces
	cop = p_cop
	queue_redraw()

## Board-local cm -> this control's pixels.
func cm_to_px(cm: Vector2) -> Vector2:
	var scale_x := size.x / (2.0 * BoardData.L_HALF)
	var scale_y := size.y / (2.0 * BoardData.B_HALF)
	var center := size * 0.5
	# +y is "front" in BoardData's convention; screen y grows downward, so
	# flip it to keep "front" at the top of the drawn board.
	return center + Vector2(cm.x * scale_x, -cm.y * scale_y)

func _draw() -> void:
	var k := clampf(size.x / REFERENCE_WIDTH, 0.8, 2.2)
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.COLOR_SURFACE_RAISED, true)
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.COLOR_BORDER, false, 1.0)
	# Faint centre axes (board-local x = 0, y = 0), like a chart grid.
	var axis := Color(UiTheme.COLOR_MUTED_TEXT, 0.18)
	draw_dashed_line(Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, size.y), axis, 1.0, 4.0)
	draw_dashed_line(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5), axis, 1.0, 4.0)

	var font := get_theme_default_font()
	for i in range(4):
		var f: float = forces[i] if i < forces.size() else 0.0
		var norm: float = clamp((f - MIN_FORCE) / (MAX_FORCE - MIN_FORCE), 0.0, 1.0)
		var pos := cm_to_px(BoardData.SENSOR_POS[i])
		var radius: float = lerp(MIN_DOT_RADIUS, MAX_DOT_RADIUS, norm) * k
		var color := Color("3a3a42").lerp(UiTheme.COLOR_PRIMARY, norm)
		draw_circle(pos, radius, color)
		var font_size := int(lerp(MIN_FONT_SIZE, MAX_FONT_SIZE, norm) * k)
		var label := "%.1f" % (f if absf(f) >= 0.05 else 0.0)  # no "-0.0"
		# Value sits inside the board, diagonally in from its corner, so the
		# labels of two boards drawn side by side never collide.
		var inward := (size * 0.5 - pos).sign()
		var text_center := pos + inward * Vector2(MAX_DOT_RADIUS + 26, MAX_DOT_RADIUS + 8) * k
		var text_w := 80.0 * k
		draw_string(font, text_center + Vector2(-text_w * 0.5, font_size * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, text_w, font_size, UiTheme.COLOR_TEXT)

	if cop != null:
		var cop_px := cm_to_px(cop)
		draw_circle(cop_px, COP_DOT_RADIUS * k, cop_color)
