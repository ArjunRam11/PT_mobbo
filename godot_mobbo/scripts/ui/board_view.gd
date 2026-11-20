class_name BoardView
extends Control
## Reusable to-scale 2D visualization of one physical board: its outline,
## each of its 4 corner sensors (force text, font/dot size scaled by load --
## port of force.cs's font-size-by-force behavior), and the board's live
## center-of-pressure marker. Used by the Force Display screen; written as
## its own reusable class since any later game needing a board picture
## (stepper, weight shifting) can reuse it instead of redrawing one.

const MIN_FORCE := 0.0
const MAX_FORCE := 150.0  # kg; same calibration range force.cs used
const MIN_FONT_SIZE := 14
const MAX_FONT_SIZE := 28
const MIN_DOT_RADIUS := 5.0
const MAX_DOT_RADIUS := 16.0
const COP_DOT_RADIUS := 9.0

var forces: Array = [0.0, 0.0, 0.0, 0.0]
var cop: Variant = null  # Vector2 (cm, board-local) or null if no load

func set_data(p_forces: Array, p_cop: Variant) -> void:
	forces = p_forces
	cop = p_cop
	queue_redraw()

func _cm_to_px(cm: Vector2) -> Vector2:
	var scale_x := size.x / (2.0 * BoardData.L_HALF)
	var scale_y := size.y / (2.0 * BoardData.B_HALF)
	var center := size * 0.5
	# +y is "front" in BoardData's convention; screen y grows downward, so
	# flip it to keep "front" at the top of the drawn board.
	return center + Vector2(cm.x * scale_x, -cm.y * scale_y)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.COLOR_SURFACE, true)
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.COLOR_BORDER, false, 2.0)

	var font := get_theme_default_font()
	for i in range(4):
		var f: float = forces[i] if i < forces.size() else 0.0
		var norm: float = clamp((f - MIN_FORCE) / (MAX_FORCE - MIN_FORCE), 0.0, 1.0)
		var pos := _cm_to_px(BoardData.SENSOR_POS[i])
		var radius: float = lerp(MIN_DOT_RADIUS, MAX_DOT_RADIUS, norm)
		var color := UiTheme.COLOR_BORDER.lerp(UiTheme.COLOR_PRIMARY, norm)
		draw_circle(pos, radius, color)
		var font_size: int = int(lerp(float(MIN_FONT_SIZE), float(MAX_FONT_SIZE), norm))
		var label := "%.1f" % f
		var text_pos := pos + Vector2(-16, -radius - 6)
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, 48, font_size, UiTheme.COLOR_TEXT)

	if cop != null:
		var cop_px := _cm_to_px(cop)
		draw_circle(cop_px, COP_DOT_RADIUS, UiTheme.COLOR_DESTRUCTIVE)
