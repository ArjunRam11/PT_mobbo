class_name CopPlot
extends Control
## On-screen COP path plot for the Analysis tab.
##   mode "rig":  both boards to scale, left/right/combined COP paths and
##                their 95% ellipses (combined frame, front at the top).
##   mode "zoom": combined COP only, auto-zoomed, cm grid, 95% ellipse.

const C_LEFT := UiTheme.COLOR_BLUE
const C_RIGHT := UiTheme.COLOR_GREEN
const C_COMBINED := UiTheme.COLOR_YELLOW

var mode := "rig"
var result: Dictionary = {}

func set_result(r: Dictionary) -> void:
	result = r
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.COLOR_SURFACE_RAISED, true)
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.COLOR_BORDER, false, 1.0)
	var font: Font = UiTheme.font_regular
	if result.is_empty():
		draw_string(font, Vector2(0, size.y * 0.5), "Select a recording to analyse", HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, UiTheme.COLOR_MUTED_TEXT)
		return
	if mode == "rig":
		_draw_rig()
	else:
		_draw_zoom(font)

## World cm (+y front) -> local px, aspect kept, centred.
func _mapper(box: Rect2, wmin: Vector2, wmax: Vector2) -> Callable:
	var span := wmax - wmin
	var s := minf(box.size.x / span.x, box.size.y / span.y)
	var origin := box.position + (box.size - span * s) * 0.5
	return func(p: Vector2) -> Vector2:
		return Vector2(origin.x + (p.x - wmin.x) * s, origin.y + (wmax.y - p.y) * s)

func _mapped(m: Callable, pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var step := maxi(1, pts.size() / 3000)
	for i in range(0, pts.size(), step):
		out.append(m.call(pts[i]))
	return out

func _draw_rig() -> void:
	var L := BoardData.L_HALF
	var B := BoardData.B_HALF
	var off: Vector2 = BoardData.right_board_offset
	var m := _mapper(Rect2(Vector2(10, 10), size - Vector2(20, 20)), Vector2(-L - 2, -B - 2), Vector2(off.x + L + 2, B + 2))
	var axis := Color(UiTheme.COLOR_MUTED_TEXT, 0.25)
	for centre in [Vector2.ZERO, off]:
		var tl: Vector2 = m.call(centre + Vector2(-L, B))
		var br: Vector2 = m.call(centre + Vector2(L, -B))
		draw_rect(Rect2(tl, br - tl), UiTheme.COLOR_SURFACE, true)
		draw_rect(Rect2(tl, br - tl), UiTheme.COLOR_BORDER, false, 1.0)
		draw_dashed_line(m.call(centre + Vector2(0, B)), m.call(centre + Vector2(0, -B)), axis, 1.0, 4.0)
		draw_dashed_line(m.call(centre + Vector2(-L, 0)), m.call(centre + Vector2(L, 0)), axis, 1.0, 4.0)
	var keys := ["left", "right", "combined"]
	var cols := [C_LEFT, C_RIGHT, C_COMBINED]
	for i in 3:
		var s: Dictionary = result.series[keys[i]]
		var pts := _mapped(m, s.plot_pts)
		if pts.size() >= 2:
			draw_polyline(pts, Color(cols[i], 0.7), 1.0)
		if s.n >= 3:
			var e: Dictionary = s.ellipse.duplicate()
			if keys[i] == "right":
				e.cx += off.x
				e.cy += off.y
			draw_polyline(_mapped(m, CopAnalysis.ellipse_points(e)), cols[i], 2.0, true)

func _draw_zoom(font: Font) -> void:
	var s: Dictionary = result.series.combined
	if s.n < 3:
		draw_string(font, Vector2(0, size.y * 0.5), "Not enough loaded samples for the combined COP", HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, UiTheme.COLOR_MUTED_TEXT)
		return
	var e: Dictionary = s.ellipse
	var centre := Vector2(e.cx, e.cy)
	var aspect := size.x / maxf(size.y, 1.0)
	var half := maxf(maxf(e.a, s.range_ml * 0.5), maxf(s.range_ap * 0.5, 1.0)) * 1.15
	var step := CopReport._nice_step(half * 2.0 / 6.0)
	half = ceilf(half / step) * step
	var hw := Vector2(half * maxf(aspect, 1.0), half * maxf(1.0 / aspect, 1.0))
	var wmin := centre - hw
	var wmax := centre + hw
	var pad := Vector2(40, 38)  # room for y labels, x labels and the caption
	var m := _mapper(Rect2(Vector2(pad.x, 8), size - Vector2(pad.x + 8, pad.y + 8)), wmin, wmax)
	var grid := Color(UiTheme.COLOR_MUTED_TEXT, 0.15)
	var v := ceilf(wmin.x / step) * step
	while v <= wmax.x + 0.0001:
		draw_line(m.call(Vector2(v, wmin.y)), m.call(Vector2(v, wmax.y)), grid, 1.0)
		var p: Vector2 = m.call(Vector2(v, wmin.y))
		draw_string(font, p + Vector2(-30, 16), CopReport._f(v, 1 if step < 1.0 else 0), HORIZONTAL_ALIGNMENT_CENTER, 60, 11, UiTheme.COLOR_MUTED_TEXT)
		v += step
	v = ceilf(wmin.y / step) * step
	while v <= wmax.y + 0.0001:
		draw_line(m.call(Vector2(wmin.x, v)), m.call(Vector2(wmax.x, v)), grid, 1.0)
		var p: Vector2 = m.call(Vector2(wmin.x, v))
		draw_string(font, p + Vector2(-38, 4), CopReport._f(v, 1 if step < 1.0 else 0), HORIZONTAL_ALIGNMENT_RIGHT, 34, 11, UiTheme.COLOR_MUTED_TEXT)
		v += step
	var pts := _mapped(m, s.plot_pts)
	if pts.size() >= 2:
		draw_polyline(pts, Color(C_COMBINED, 0.75), 1.0)
	draw_polyline(_mapped(m, CopAnalysis.ellipse_points(e)), UiTheme.COLOR_TEXT, 2.0, true)
	var c: Vector2 = m.call(centre)
	draw_line(c - Vector2(6, 0), c + Vector2(6, 0), UiTheme.COLOR_TEXT, 2.0)
	draw_line(c - Vector2(0, 6), c + Vector2(0, 6), UiTheme.COLOR_TEXT, 2.0)
	draw_string(font, Vector2(pad.x, size.y - 4), "ML x (cm)  ·  AP y (cm), front up  ·  white = 95% ellipse", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiTheme.COLOR_MUTED_TEXT)
