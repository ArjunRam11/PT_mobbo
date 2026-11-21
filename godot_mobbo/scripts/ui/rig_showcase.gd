class_name RigShowcase
extends Control
## Animated illustration of what MoBBo does, for the main (login) screen:
## two wooden force boards on load-cell feet, a person standing with one
## foot on each, swaying front/back (and a little left/right) like in a
## balance session, while the numbers the boards would measure update live:
## kg per board, kg on each of the 8 load cells, total weight, and the
## centre of pressure (COP) with its trail. The whole rig wobbles gently.
##
## Drawn in code from a tiny 3D model (cm) through a fixed 3/4 projection,
## so the lean and wobble have real perspective. Purely decorative: it does
## NOT read the real boards -- the numbers are simulated from the pose.
##
## World axes: x = left -> right, y = back -> front (toward the viewer),
## z = up. Camera is front-right-above.

const BOARD_W := 48.0        # x
const BOARD_D := 56.0        # y
const BOARD_T := 5.0         # wood thickness
const FOOT_H := 3.5          # load-cell feet under the board
const GAP := 6.0             # between the boards
const TOP_Z := FOOT_H + BOARD_T
const BODY_KG := 68.4
const LEAN_DEG := 7.0        # front/back sway amplitude
const SWAY_DEG := 2.6        # left/right sway amplitude
const COM_Z := 95.0          # centre of mass height
const TRAIL_LEN := 70

# Palette.
const SKIN := Color("e8b48f")
const SKIN_DARK := Color("c98f6b")
const HAIR := Color("3b2618")
const SHIRT := Color("1fb5a8")
const SHIRT_DARK := Color("12857c")
const SHIRT_LIGHT := Color("5fdccf")
const PANTS := Color("2c3e78")
const PANTS_DARK := Color("1d2a55")
const SHOE := Color("f4f4f6")
const SHOE_ACCENT := Color("ff5a5f")
const WOOD_FRONT := Color("a8692f")
const WOOD_SIDE := Color("7e4a1e")
const STEEL := Color("9aa3ad")

var t := 0.0
var _scale := 1.0
var _origin := Vector2.ZERO
var _rig_basis := Basis.IDENTITY   # whole-setup wobble
var _lean := 0.0                   # rad, + = forward
var _sway := 0.0                   # rad, + = to the right
var _wood: Texture2D
var _trail: Array[Vector3] = []
var _trail_timer := 0.0

# Simulated measurements (updated each frame).
var w_left := 0.0
var w_right := 0.0
var corners_left: Array[float] = [0.0, 0.0, 0.0, 0.0]   # back-left, back-right, front-right, front-left
var corners_right: Array[float] = [0.0, 0.0, 0.0, 0.0]
var cop := Vector3.ZERO  # combined, on the board surface

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wood = GameArena.tex("wood_top")
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(380, 440)

func _process(delta: float) -> void:
	t += delta
	# Front/back: slow, slightly irregular (two sines) like real sway.
	_lean = deg_to_rad(LEAN_DEG) * (0.8 * sin(t * 0.85) + 0.2 * sin(t * 2.1 + 1.3))
	_sway = deg_to_rad(SWAY_DEG) * sin(t * 0.47 + 0.6)
	_rig_basis = Basis(Vector3.RIGHT, deg_to_rad(1.6) * sin(t * 1.05 + 0.4)) \
		* Basis(Vector3(0, 1, 0), deg_to_rad(1.3) * sin(t * 0.77 + 1.9))  # roll about the AP axis
	_simulate()
	_trail_timer += delta
	if _trail_timer >= 0.05:
		_trail_timer = 0.0
		_trail.append(cop)
		if _trail.size() > TRAIL_LEN:
			_trail.pop_front()
	queue_redraw()

# -- Simulation of what the boards measure ------------------------------------------

func _simulate() -> void:
	# COP follows the centre of mass (inverted pendulum) plus a little
	# "ankle torque" overshoot, as real COP traces do.
	var cop_y := COM_Z * sin(_lean) * 1.25
	var cop_x := COM_Z * sin(_sway) * 1.6
	var foot_x := BOARD_W * 0.5 + GAP * 0.5
	var frac_right := clampf(0.5 + cop_x / (2.0 * foot_x), 0.05, 0.95)
	var jitter := 0.15 * sin(t * 13.0) + 0.1 * sin(t * 7.3)
	var total := BODY_KG + jitter
	w_right = total * frac_right
	w_left = total - w_right
	var local_y := clampf(cop_y, -BOARD_D * 0.4, BOARD_D * 0.4)
	cop = Vector3(cop_x, local_y, TOP_Z)
	# Per board: bilinear split over its 4 corners from a local COP near the foot.
	var lx := cop_x * 0.35
	_split(corners_left, w_left, lx, local_y)
	_split(corners_right, w_right, lx, local_y)

func _split(out: Array[float], w: float, cx: float, cy: float) -> void:
	var fx := clampf(0.5 + cx / BOARD_W, 0.0, 1.0)   # share on the right edge
	var fy := clampf(0.5 + cy / BOARD_D, 0.0, 1.0)   # share on the front edge
	out[0] = w * (1.0 - fx) * (1.0 - fy)
	out[1] = w * fx * (1.0 - fy)
	out[2] = w * fx * fy
	out[3] = w * (1.0 - fx) * fy

# -- Projection -------------------------------------------------------------------------

func _p(v: Vector3) -> Vector2:
	var q := _rig_basis * v
	return _origin + Vector2(q.x - q.y * 0.6, q.x * 0.18 + q.y * 0.45 - q.z * 0.95) * _scale

## The person's pose: rotate about the ankles (inverted pendulum).
func _body(v: Vector3) -> Vector3:
	var pivot := Vector3(0, 0, TOP_Z + 3.0)
	var r := v - pivot
	var y := r.y * cos(_lean) + r.z * sin(_lean)
	var z := -r.y * sin(_lean) + r.z * cos(_lean)
	var x := r.x * cos(_sway) + z * sin(_sway)
	var z2 := -r.x * sin(_sway) + z * cos(_sway)
	return Vector3(x, y, z2) + pivot

func _pb(v: Vector3) -> Vector2:
	return _p(_body(v))

# -- Drawing ------------------------------------------------------------------------------

func _draw() -> void:
	_scale = minf(size.x / 190.0, size.y / 255.0)
	_origin = Vector2(size.x * 0.47, size.y * 0.5 + 80.0 * _scale)

	_draw_floor()
	_draw_device()
	var lx0 := -GAP * 0.5 - BOARD_W
	var rx0 := GAP * 0.5
	_draw_board(lx0, corners_left)
	_draw_board(rx0, corners_right)
	_draw_cop_trail()
	_draw_person()
	_draw_com_line()
	_draw_labels(lx0, rx0)

func _draw_floor() -> void:
	# Soft coloured mat + contact shadow.
	for i in 6:
		var k := 1.0 - i / 6.0
		_ellipse(Vector3(0, 0, 0), 95.0 * (0.5 + 0.5 * k), 70.0 * (0.5 + 0.5 * k), Color(0.25, 0.75, 0.9, 0.05))
	_ellipse(Vector3(2, -2, 0), 58.0, 36.0, Color(0, 0, 0, 0.32))

func _ellipse(c: Vector3, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(_p(c + Vector3(cos(a) * rx, sin(a) * ry, 0)))
	draw_colored_polygon(pts, col)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, col2: Color = Color(0, 0, 0, 0)) -> void:
	var pts := PackedVector2Array([_p(a), _p(b), _p(c), _p(d)])
	if col2.a > 0.0:
		draw_polygon(pts, PackedColorArray([col, col, col2, col2]))
	else:
		draw_colored_polygon(pts, col)

## Axis-aligned box: draws the faces this camera sees (top, front y+, right x+).
func _box(mn: Vector3, mx: Vector3, top: Color, front: Color, side: Color) -> void:
	_quad(Vector3(mx.x, mn.y, mx.z), Vector3(mx.x, mx.y, mx.z), Vector3(mx.x, mx.y, mn.z), Vector3(mx.x, mn.y, mn.z), side, side.darkened(0.25))
	_quad(Vector3(mn.x, mx.y, mx.z), Vector3(mx.x, mx.y, mx.z), Vector3(mx.x, mx.y, mn.z), Vector3(mn.x, mx.y, mn.z), front, front.darkened(0.2))
	_quad(Vector3(mn.x, mn.y, mx.z), Vector3(mx.x, mn.y, mx.z), Vector3(mx.x, mx.y, mx.z), Vector3(mn.x, mx.y, mx.z), top)

func _draw_device() -> void:
	# Little NodeMCU box behind the boards, with cables and a blinking LED.
	var mn := Vector3(-7, -48, 0)
	var mx := Vector3(7, -38, 4)
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 13:
			var k := i / 12.0
			var a := Vector3(side * 5.0, -38.0, 1.0)
			var b := Vector3(side * (GAP * 0.5 + BOARD_W * 0.5), -BOARD_D * 0.5, FOOT_H + 1.0)
			var v := a.lerp(b, k) + Vector3(side * 6.0 * sin(k * PI), 0, 2.0 * sin(k * PI))
			pts.append(_p(v))
		draw_polyline(pts, Color("1a1a1f"), maxf(1.5, 0.9 * _scale), true)
	_box(mn, mx, Color("2b3a4a"), Color("1f2b38"), Color("17212b"))
	var led_on := fmod(t, 0.5) < 0.25
	var led := _p(Vector3(4, -40, 4))
	if led_on:
		draw_circle(led, 3.5 * _scale, Color(0.3, 0.7, 1.0, 0.35))
	draw_circle(led, 1.1 * _scale, Color("4c9dff") if led_on else Color("223348"))

func _draw_board(x0: float, corners: Array[float]) -> void:
	var y0 := -BOARD_D * 0.5
	var y1 := BOARD_D * 0.5
	var x1 := x0 + BOARD_W
	# Load-cell feet (steel), back ones first.
	for c in [Vector2(x0 + 3, y0 + 3), Vector2(x1 - 7, y0 + 3), Vector2(x0 + 3, y1 - 7), Vector2(x1 - 7, y1 - 7)]:
		_box(Vector3(c.x, c.y, 0), Vector3(c.x + 4, c.y + 4, FOOT_H), STEEL.lightened(0.2), STEEL, STEEL.darkened(0.3))
	# Wood slab: sides, then textured top.
	_quad(Vector3(x1, y0, TOP_Z), Vector3(x1, y1, TOP_Z), Vector3(x1, y1, FOOT_H), Vector3(x1, y0, FOOT_H), WOOD_SIDE, WOOD_SIDE.darkened(0.3))
	_quad(Vector3(x0, y1, TOP_Z), Vector3(x1, y1, TOP_Z), Vector3(x1, y1, FOOT_H), Vector3(x0, y1, FOOT_H), WOOD_FRONT, WOOD_FRONT.darkened(0.25))
	var top := PackedVector2Array([_p(Vector3(x0, y0, TOP_Z)), _p(Vector3(x1, y0, TOP_Z)), _p(Vector3(x1, y1, TOP_Z)), _p(Vector3(x0, y1, TOP_Z))])
	if _wood != null:
		draw_polygon(top, PackedColorArray([Color.WHITE]), PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), _wood)
	else:
		draw_colored_polygon(top, Color("d09257"))
	# Bevel highlight on the front-top edge.
	draw_line(_p(Vector3(x0, y1, TOP_Z)), _p(Vector3(x1, y1, TOP_Z)), Color(1, 0.9, 0.75, 0.7), maxf(1.0, 0.5 * _scale))
	draw_line(_p(Vector3(x1, y0, TOP_Z)), _p(Vector3(x1, y1, TOP_Z)), Color(1, 0.9, 0.75, 0.45), maxf(1.0, 0.4 * _scale))
	# Sensor glow at each corner: brighter/warmer with more load.
	var cs := [Vector3(x0 + 5, y0 + 5, TOP_Z), Vector3(x1 - 5, y0 + 5, TOP_Z), Vector3(x1 - 5, y1 - 5, TOP_Z), Vector3(x0 + 5, y1 - 5, TOP_Z)]
	for i in 4:
		var k := clampf(corners[i] / 18.0, 0.0, 1.0)
		var col := Color("4c9dff").lerp(Color("ff5a5f"), k)
		var pulse := 1.0 + 0.08 * sin(t * 6.0 + i)
		_ellipse(cs[i], 4.5 * (0.6 + 0.6 * k) * pulse, 4.5 * (0.6 + 0.6 * k) * pulse, Color(col, 0.28))
		_ellipse(cs[i], 1.6, 1.6, col.lightened(0.3))

func _draw_cop_trail() -> void:
	for i in _trail.size():
		var k := float(i + 1) / _trail.size()
		draw_circle(_p(_trail[i]), (0.5 + 1.2 * k) * _scale * 0.6, Color(1.0, 0.75, 0.04, 0.55 * k))

func _limb(a: Vector3, b: Vector3, w_cm: float, col: Color, col_dark: Color) -> void:
	var pa := _pb(a)
	var pb := _pb(b)
	var w := w_cm * _scale
	draw_line(pa, pb, col_dark, w, true)
	draw_circle(pa, w * 0.5, col_dark)
	draw_circle(pb, w * 0.5, col_dark)
	var off := Vector2(-w * 0.14, -w * 0.08)
	draw_line(pa + off, pb + off, col, w * 0.62, true)
	draw_circle(pa + off, w * 0.31, col)
	draw_circle(pb + off, w * 0.31, col)

func _draw_shoe(x: float) -> void:
	var heel := Vector3(x, -7, TOP_Z + 2.5)
	var toe := Vector3(x, 13, TOP_Z + 2.2)
	_limb(heel, toe, 8.5, SHOE, Color("c9ccd4"))
	_limb(heel + Vector3(0, 2, -1.6), toe + Vector3(0, 0, -1.6), 5.0, SHOE_ACCENT, SHOE_ACCENT.darkened(0.3))

func _draw_person() -> void:
	# Counter-balancing arms: they drift opposite the lean.
	var arm_y := -sin(_lean) * 40.0
	# Joints.
	var l_ankle := Vector3(-27, 0, TOP_Z + 4)
	var r_ankle := Vector3(27, 0, TOP_Z + 4)
	var l_knee := Vector3(-23, 3, 52)
	var r_knee := Vector3(23, 3, 52)
	var l_hip := Vector3(-11, 0, 93)
	var r_hip := Vector3(11, 0, 93)
	var l_sh := Vector3(-20, 0, 144)
	var r_sh := Vector3(20, 0, 144)
	var l_el := Vector3(-27, 2 + arm_y * 0.5, 119)
	var r_el := Vector3(27, 2 + arm_y * 0.5, 119)
	var l_hand := Vector3(-29, 7 + arm_y, 96)
	var r_hand := Vector3(29, 7 + arm_y, 96)

	# Far (left) side first.
	_draw_shoe(-27)
	_limb(l_ankle, l_knee, 10.5, PANTS, PANTS_DARK)
	_limb(l_knee, l_hip, 13.5, PANTS, PANTS_DARK)
	draw_circle(_pb(l_sh), 4.6 * _scale, SHIRT_DARK)
	_limb(l_sh, l_el, 8.5, SHIRT, SHIRT_DARK)
	_limb(l_el, l_hand, 6.5, SKIN, SKIN_DARK)
	draw_circle(_pb(l_hand), 3.6 * _scale, SKIN_DARK)
	_draw_shoe(27)
	_limb(r_ankle, r_knee, 10.5, PANTS, PANTS_DARK)
	_limb(r_knee, r_hip, 13.5, PANTS, PANTS_DARK)

	# Torso as a tapered box: right side, top (shoulders), front.
	var b := func(v: Vector3) -> Vector2: return _pb(v)
	var tf := [Vector3(-19, 8, 146), Vector3(19, 8, 146), Vector3(15, 8, 97), Vector3(-15, 8, 97)]
	var tr := [Vector3(19, -8, 146), Vector3(19, 8, 146), Vector3(15, 8, 97), Vector3(15, -8, 97)]
	var tt := [Vector3(-19, -8, 146), Vector3(19, -8, 146), Vector3(19, 8, 146), Vector3(-19, 8, 146)]
	draw_polygon(PackedVector2Array(tr.map(b)), PackedColorArray([SHIRT_DARK, SHIRT_DARK, SHIRT_DARK.darkened(0.25), SHIRT_DARK.darkened(0.25)]))
	draw_colored_polygon(PackedVector2Array(tt.map(b)), SHIRT_LIGHT)
	draw_polygon(PackedVector2Array(tf.map(b)), PackedColorArray([SHIRT_LIGHT, SHIRT, SHIRT.darkened(0.15), SHIRT]))
	# Shirt stripe + belt.
	_limb(Vector3(-18, 8.5, 128), Vector3(18, 8.5, 128), 3.0, Color("ffbe0b"), Color("e0a200"))
	_limb(Vector3(-15, 8.6, 98), Vector3(15, 8.6, 98), 3.4, Color("3a2a1e"), Color("2a1d14"))
	# Neck + head.
	_limb(Vector3(0, 1, 147), Vector3(0, 2, 155), 7.5, SKIN, SKIN_DARK)
	_draw_head(Vector3(0, 2, 165))
	# Near (right) arm last.
	draw_circle(_pb(r_sh), 5.5 * _scale, SHIRT_LIGHT)
	_limb(r_sh, r_el, 8.5, SHIRT_LIGHT, SHIRT)
	_limb(r_el, r_hand, 6.5, SKIN, SKIN_DARK)
	draw_circle(_pb(r_hand), 3.6 * _scale, SKIN)

func _draw_head(c: Vector3) -> void:
	var r := 11.0 * _scale
	# Ear (right side, visible), skull, face, hair.
	draw_circle(_pb(c + Vector3(10.5, 0, 0)), 2.8 * _scale, SKIN_DARK)
	draw_circle(_pb(c), r, SKIN_DARK)
	draw_circle(_pb(c + Vector3(2.5, -4.5, -1.0)), r * 0.88, HAIR)  # back of the head
	draw_circle(_pb(c + Vector3(-0.8, 1.2, 0.6)), r * 0.93, SKIN)
	# Hair: cap over the top and back.
	var hair_pts := PackedVector2Array()
	var hc := _pb(c + Vector3(0, -1.5, 1.5))
	for i in 25:
		var a := PI - 0.2 + (PI + 0.4) * i / 24.0  # upper half + a bit (screen space), convex
		hair_pts.append(hc + Vector2(cos(a), sin(a)) * r * 1.04)
	draw_colored_polygon(hair_pts, HAIR)
	draw_circle(hc + Vector2(r * 0.35, -r * 0.55), r * 0.25, HAIR.lightened(0.15))  # shine
	# Face toward the front (y+).
	var eye_l := _pb(c + Vector3(-4.0, 10.0, 1.0))
	var eye_r := _pb(c + Vector3(4.0, 10.0, 1.0))
	draw_circle(eye_l, 1.15 * _scale, Color("1d1d22"))
	draw_circle(eye_r, 1.15 * _scale, Color("1d1d22"))
	draw_circle(eye_l + Vector2(-0.3, -0.4) * _scale, 0.4 * _scale, Color.WHITE)
	draw_circle(eye_r + Vector2(-0.3, -0.4) * _scale, 0.4 * _scale, Color.WHITE)
	var smile := PackedVector2Array()
	for i in 7:
		var k := i / 6.0
		smile.append(_pb(c + Vector3(lerpf(-2.6, 2.4, k), 10.2, -4.4 - 1.1 * sin(k * PI))))
	draw_polyline(smile, Color("9c4a3a"), maxf(1.0, 0.7 * _scale), true)
	draw_circle(_pb(c + Vector3(-6.5, 9.2, -2.5)), 1.8 * _scale, Color(1.0, 0.45, 0.45, 0.25))
	draw_circle(_pb(c + Vector3(6.5, 9.2, -2.5)), 1.8 * _scale, Color(1.0, 0.45, 0.45, 0.25))

func _draw_com_line() -> void:
	# Plumb line from the centre of mass down to the COP on the boards.
	var com := _pb(Vector3(0, 0, COM_Z))
	var c := _p(cop)
	var n := 14
	for i in n:
		if i % 2 == 0:
			draw_line(com.lerp(c, float(i) / n), com.lerp(c, float(i + 1) / n), Color(1.0, 0.75, 0.04, 0.8), maxf(1.0, 0.45 * _scale))
	draw_circle(com, 2.2 * _scale, Color(1.0, 0.75, 0.04, 0.9))
	draw_circle(com, 1.0 * _scale, Color.WHITE)
	var pulse := 1.0 + 0.15 * sin(t * 5.0)
	draw_circle(c, 4.0 * _scale * pulse, Color(1.0, 0.75, 0.04, 0.3))
	draw_circle(c, 1.8 * _scale, Color("ffbe0b"))
	draw_circle(c, 0.8 * _scale, Color.WHITE)

# -- Numbers --------------------------------------------------------------------------------

## side: 0 = centred on `at`, -1 = ends at `at` (sits left of it), +1 = starts at `at`.
func _pill(at: Vector2, caption: String, value: String, accent: Color, side: int = 0) -> void:
	var fs_cap := int(clampf(10.0 * _scale / 2.4, 10, 14))
	var fs_val := int(clampf(17.0 * _scale / 2.4, 15, 24))
	var w := maxf(UiTheme.font_heading.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_val).x,
		UiTheme.font_eyebrow.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_cap).x) + 24.0
	var h := fs_cap + fs_val + 16.0
	var x := at.x - w * 0.5 if side == 0 else (at.x - w if side < 0 else at.x)
	x = clampf(x, 4.0, size.x - w - 4.0)
	var r := Rect2(Vector2(x, at.y - h * 0.5), Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.82)
	sb.border_color = Color(accent, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	draw_style_box(sb, r)
	draw_string(UiTheme.font_eyebrow, r.position + Vector2(12, 6 + fs_cap), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_cap, accent)
	draw_string(UiTheme.font_heading, r.position + Vector2(12, 8 + fs_cap + fs_val), value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_val, Color.WHITE)

func _draw_labels(lx0: float, rx0: float) -> void:
	var y1 := BOARD_D * 0.5
	# Per-board weights, out to the side of each board.
	_pill(_p(Vector3(lx0 - 4, 0, TOP_Z)) - Vector2(16, 0), "LEFT BOARD", "%.1f kg" % w_left, UiTheme.COLOR_BLUE, -1)
	_pill(_p(Vector3(rx0 + BOARD_W + 4, 0, TOP_Z)) + Vector2(16, 0), "RIGHT BOARD", "%.1f kg" % w_right, UiTheme.COLOR_GREEN, 1)
	# Load-cell readings next to the visible front corners.
	var fs := int(clampf(9.0 * _scale / 2.4, 10, 13))
	var cell_txt := Color(1, 1, 1, 0.85)
	# [corner on the board, its load, text offset in px (outward from the board)]
	var spots := [
		[Vector3(lx0 + 5, y1 - 5, FOOT_H), corners_left[3], Vector2(-34, 18)],
		[Vector3(lx0 + BOARD_W - 5, y1 - 5, FOOT_H), corners_left[2], Vector2(-12, 26)],
		[Vector3(rx0 + 5, y1 - 5, FOOT_H), corners_right[3], Vector2(-14, 26)],
		[Vector3(rx0 + BOARD_W - 5, y1 - 5, FOOT_H), corners_right[2], Vector2(8, 22)],
		[Vector3(rx0 + BOARD_W - 5, -y1 + 5, TOP_Z), corners_right[1], Vector2(10, 4)],
	]
	for s in spots:
		var p: Vector2 = _p(s[0]) + s[2]
		draw_string_outline(UiTheme.font_medium, p, "%.1f" % s[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7))
		draw_string(UiTheme.font_medium, p, "%.1f" % s[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cell_txt)
	# Total + COP readout, top corners.
	var top_y := 30.0 * (_scale / 2.4) + 20.0
	_pill(Vector2(size.x * 0.2, top_y), "TOTAL", "%.1f kg" % (w_left + w_right), UiTheme.COLOR_YELLOW)
	var dir := "forward" if cop.y > 1.0 else ("back" if cop.y < -1.0 else "centred")
	_pill(Vector2(size.x * 0.8, top_y), "COP  %s" % dir.to_upper(), "%+.1f cm" % cop.y, UiTheme.COLOR_YELLOW)
	# Front/back lean gauge on the right edge.
	var gx := minf(_origin.x + 92.0 * _scale, size.x - 24.0)
	var g0 := _p(Vector3(0, 0, 150)).y
	var g1 := _p(Vector3(0, 0, 60)).y
	draw_line(Vector2(gx, g0), Vector2(gx, g1), Color(1, 1, 1, 0.2), 4.0, true)
	draw_string(UiTheme.font_eyebrow, Vector2(gx - 30, g0 - 8), "FRONT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.5))
	draw_string(UiTheme.font_eyebrow, Vector2(gx - 26, g1 + 18), "BACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.5))
	var k := clampf(0.5 - cop.y / (BOARD_D * 0.8), 0.0, 1.0)
	var gy := lerpf(g0, g1, k)
	draw_circle(Vector2(gx, gy), 7.0, Color(1.0, 0.75, 0.04, 0.35))
	draw_circle(Vector2(gx, gy), 4.0, Color("ffbe0b"))
