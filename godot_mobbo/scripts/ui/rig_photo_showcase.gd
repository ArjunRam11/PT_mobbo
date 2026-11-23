class_name RigPhotoShowcase
extends RigShowcase
## Main-screen illustration built from the rendered art (sprites/rig_hero_cut.png,
## made from art_src/rig_hero.png by tools/prepare_art.py): the person on
## the two wooden boards, animated in code --
##   * the person leans front/back (and a little side to side) from the
##     ankles: the image is drawn as a mesh and only the body above the
##     feet is sheared, so feet and boards stay put;
##   * the whole rig wobbles gently;
##   * load-cell glows (sprites/sensor_glow_strip.png, additive) at the 8
##     board corners light up with the load, with kg numbers, per-board
##     weights, total, COP trail and a centre-of-mass plumb line.
## Numbers are simulated from the pose (RigShowcase._simulate), not live.
##
## Orientation in the picture: the person faces the lower-right, so the
## board on the image's LEFT is under his RIGHT foot (patient's right
## board) and the image-right board is the patient's LEFT board.
## All anchor coordinates below are pixels in rig_hero_cut.png (615x768).

const IMG_SIZE := Vector2(615, 768)
const PIVOT := Vector2(288, 546)          # between the ankles
const COM := Vector2(300, 300)            # belt buckle ~ centre of mass
const LEAN_PX_PER_RAD := 1.15             # shear per px of height per rad
# Board top corners (patient frame): back-left, back-right, front-right, front-left.
const RIGHT_BOARD := [Vector2(236, 511), Vector2(61, 579), Vector2(220, 695), Vector2(395, 627)]
const LEFT_BOARD := [Vector2(380, 482), Vector2(262, 515), Vector2(397, 620), Vector2(554, 557)]
# Corners whose numbers are readable (not hidden behind the legs): indices.
const RIGHT_LABELS := [1, 2, 3]
const LEFT_LABELS := [0, 3]  # front-right sits next to the other board's front-left
const MESH_COLS := 36
const MESH_ROWS := 48
const GLOW_FRAMES := 7

# -- Sway sprite sheet (sprites/person_sway_strip.png + rig_base.png) -------------
# Made by tools/prepare_art.py sway_sheet() from art_src/person_sway_sheet.jpg:
# 12 frames, each SWAY_FRAME px, scaled to the hero, front-foot bottom at
# SWAY_ANCHOR; drawn so that point lands on HERO_FOOT (the hero's front foot).
const SWAY_FRAMES := 12
const SWAY_FRAME := Vector2(300, 640)
const SWAY_ANCHOR := Vector2(90, 620)
const HERO_FOOT := Vector2(264.6, 603.0)
const BACK_FOOT := Vector2(355.0, 560.0)       # for the contact shadow
const PERSON_H := 561.0
# Measured lean of each frame (-1 = full back .. +1 = full forward), printed
# by prepare_art.py: frames 1/6/7/12 upright, 2-4 forward, 8-10 back.
const SWAY_LEAN := [0.01, 0.32, 0.57, 1.0, 0.64, 0.02, -0.01, -0.11, -0.51, -1.0, -0.24, -0.19]
const SWAY_HEAD_PX := 50.0                     # head travel at |lean| = 1, image px
const SWAY_SWITCH := 0.05                      # hysteresis between similar frames
# Frames 11-12 show the body turned toward the camera (generator drift), which
# reads as twisting, not leaning -- leave them out; the residual bend covers it.
const SWAY_USE := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
const SIM_LEAN_PEAK := 0.85                    # RigShowcase's sway peaks at ~85% of LEAN_DEG

var _hero: Texture2D
var _glow: Texture2D
var _img_scale := 1.0
var _img_pos := Vector2.ZERO
var _wobble := Transform2D.IDENTITY
var _fwd := Vector2.ZERO        # screen px per cm, patient forward (in image px)
var _right := Vector2.ZERO      # screen px per cm, patient right (in image px)
var _mid := Vector2.ZERO        # between the two board centres (image px)
var _glow_layer: Control
var _indices := PackedInt32Array()
var _uvs := PackedVector2Array()
var _colors := PackedColorArray()
var _base: Texture2D
var _sway_tex: Texture2D
var _frame := 0
var _lean_norm := 0.0
var _f_indices := PackedInt32Array()
var _f_grid := PackedVector2Array()   # frame-local px of the frame mesh vertices
var _f_colors := PackedColorArray()

static func available() -> bool:
	return GameArena.tex("rig_hero_cut") != null

func _ready() -> void:
	super._ready()
	_hero = GameArena.tex("rig_hero_cut")
	_glow = GameArena.tex("sensor_glow_strip")
	_base = GameArena.tex("rig_base")
	_sway_tex = GameArena.tex("person_sway_strip")
	if _base != null and _sway_tex != null:
		_build_frame_mesh()
	var rc := _centre(RIGHT_BOARD)
	var lc := _centre(LEFT_BOARD)
	_mid = (rc + lc) * 0.5
	_right = (rc - lc) / 54.0                       # board centres are 54 cm apart
	_fwd = ((RIGHT_BOARD[3] - RIGHT_BOARD[0]) + (LEFT_BOARD[3] - LEFT_BOARD[0])) * 0.5 / 56.0
	_build_mesh()
	# Glows go on a child with additive blending (their sheet is on black).
	_glow_layer = Control.new()
	_glow_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_layer.material = mat
	_glow_layer.draw.connect(_draw_glows)
	add_child(_glow_layer)
	# Numbers/labels above the glows.
	var labels := Control.new()
	labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.draw.connect(_draw_numbers.bind(labels))
	add_child(labels)
	set_meta("labels", labels)

func _centre(c: Array) -> Vector2:
	return (c[0] + c[1] + c[2] + c[3]) * 0.25

func _build_mesh() -> void:
	for j in MESH_ROWS + 1:
		for i in MESH_COLS + 1:
			_uvs.append(Vector2(float(i) / MESH_COLS, float(j) / MESH_ROWS))
			_colors.append(Color.WHITE)
	for j in MESH_ROWS:
		for i in MESH_COLS:
			var a := j * (MESH_COLS + 1) + i
			var b := a + 1
			var c := a + MESH_COLS + 1
			var d := c + 1
			_indices.append_array([a, b, d, a, d, c])

func _build_frame_mesh() -> void:
	var cols := 10
	var rows := 28
	for j in rows + 1:
		for i in cols + 1:
			_f_grid.append(Vector2(SWAY_FRAME.x * i / cols, SWAY_FRAME.y * j / rows))
			_f_colors.append(Color.WHITE)
	for j in rows:
		for i in cols:
			var a := j * (cols + 1) + i
			var c := a + cols + 1
			_f_indices.append_array([a, a + 1, c + 1, a, c + 1, c])

## Sprite mode: pick the sheet frame whose measured lean is closest to the
## simulated one (so pose and COP numbers agree), with hysteresis.
func _pick_frame() -> void:
	_lean_norm = clampf(_lean / deg_to_rad(LEAN_DEG) / SIM_LEAN_PEAK, -1.0, 1.0)
	var best := _frame
	var best_d := absf(SWAY_LEAN[_frame] - _lean_norm) - SWAY_SWITCH
	for k in SWAY_USE:
		var d := absf(SWAY_LEAN[k] - _lean_norm)
		if d < best_d:
			best = k
			best_d = d
	_frame = best

func _process(delta: float) -> void:
	super._process(delta)
	if _sway_tex != null:
		_pick_frame()
	_glow_layer.queue_redraw()
	(get_meta("labels") as Control).queue_redraw()

# -- Pose -> image deformation ----------------------------------------------------------

## Where image pixel `p` ends up after the lean (still in image px).
func _deform(p: Vector2) -> Vector2:
	var h := PIVOT.y - p.y                      # height above the ankles
	if h <= 0.0:
		return p
	# Only the person moves: a column around the body, narrower down at the
	# feet so the electronics box, cables and board edges stay still.
	var left_edge := lerpf(196.0, 226.0, smoothstep(440.0, 480.0, p.y))
	var right_edge := 410.0
	var m := smoothstep(left_edge - 14.0, left_edge, p.x) * (1.0 - smoothstep(right_edge, right_edge + 14.0, p.x))
	var w := smoothstep(0.0, 70.0, h) * m
	var fwd_dir := _fwd.normalized()
	var right_dir := _right.normalized()
	var d := fwd_dir * sin(_lean) * LEAN_PX_PER_RAD + right_dir * sin(_sway) * 0.9
	return p + d * h * w

func _to_screen(p_img: Vector2) -> Vector2:
	return _wobble * (_img_pos + p_img * _img_scale)

func _layout() -> void:
	_img_scale = minf(size.y * 0.9 / IMG_SIZE.y, size.x * 0.78 / IMG_SIZE.x)
	var img_px := IMG_SIZE * _img_scale
	_img_pos = Vector2((size.x - img_px.x) * 0.45, size.y * 0.1)
	# Gentle whole-rig wobble about the middle of the boards.
	var pivot := _img_pos + _mid * _img_scale
	var ang := deg_to_rad(0.9) * sin(t * 1.05 + 0.4) + deg_to_rad(0.4) * sin(t * 2.3)
	var bob := 1.0 + 0.006 * sin(t * 0.77 + 1.9)
	_wobble = Transform2D(0.0, pivot) * Transform2D(ang, Vector2(1.0, bob), 0.0, Vector2.ZERO) * Transform2D(0.0, -pivot)

# -- Drawing ---------------------------------------------------------------------------------

## Sprite mode: where frame-local px `q` lands in the hero image. The small
## residual bend covers the gap between the frame's lean and the simulated
## one (plus the side-to-side sway), pivoting at the feet.
func _frame_point(q: Vector2) -> Vector2:
	var p := HERO_FOOT + (q - SWAY_ANCHOR)
	var h := SWAY_ANCHOR.y - q.y
	if h > 0.0:
		var w := smoothstep(0.0, 60.0, h)
		var residual: float = _lean_norm - SWAY_LEAN[_frame]
		var d := Vector2(residual * SWAY_HEAD_PX / PERSON_H, 0.0) + _right.normalized() * sin(_sway) * 0.9
		p += d * h * w
	return p

func _com_img() -> Vector2:
	if _sway_tex != null and _base != null:
		return HERO_FOOT + Vector2(36.0 + _lean_norm * SWAY_HEAD_PX * 0.54, -303.0)
	return _deform(COM)

func _draw() -> void:
	if _hero == null:
		super._draw()
		return
	_layout()
	if _base != null and _sway_tex != null:
		_draw_sprite_mode()
		return
	var pts := PackedVector2Array()
	pts.resize(_uvs.size())
	for k in _uvs.size():
		pts[k] = _img_pos + _deform(_uvs[k] * IMG_SIZE) * _img_scale
	draw_set_transform_matrix(_wobble)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _indices, pts, _colors, _uvs,
		PackedInt32Array(), PackedFloat32Array(), _hero.get_rid())
	_draw_overlays()

func _draw_sprite_mode() -> void:
	draw_set_transform_matrix(_wobble)
	draw_texture_rect(_base, Rect2(_img_pos, IMG_SIZE * _img_scale), false)
	# Soft contact shadows under both feet (the base has none after removal).
	for f in [HERO_FOOT + Vector2(-2, -4), BACK_FOOT]:
		var c: Vector2 = _img_pos + f * _img_scale
		for r in [26.0, 18.0, 11.0]:
			draw_set_transform_matrix(_wobble * Transform2D(-0.55, Vector2(1.0, 0.42), 0.0, c))
			draw_circle(Vector2.ZERO, r * _img_scale, Color(0, 0, 0, 0.16))
	draw_set_transform_matrix(_wobble)
	# The person: current sheet frame as a small mesh (residual bend).
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	pts.resize(_f_grid.size())
	uvs.resize(_f_grid.size())
	var strip_w := SWAY_FRAME.x * SWAY_FRAMES
	for k in _f_grid.size():
		var q := _f_grid[k]
		pts[k] = _img_pos + _frame_point(q) * _img_scale
		uvs[k] = Vector2((_frame * SWAY_FRAME.x + q.x) / strip_w, q.y / SWAY_FRAME.y)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _f_indices, pts, _f_colors, uvs,
		PackedInt32Array(), PackedFloat32Array(), _sway_tex.get_rid())
	_draw_overlays()

func _draw_overlays() -> void:
	draw_set_transform_matrix(_wobble)
	# COP trail on the boards, then the plumb line from the centre of mass.
	for i in _trail.size():
		var k := float(i + 1) / _trail.size()
		draw_circle(_cop_img_to_local(_trail[i]), (1.0 + 2.5 * k) * _img_scale * 1.4, Color(1.0, 0.75, 0.04, 0.5 * k))
	var com := _img_pos + _com_img() * _img_scale
	var c := _cop_img_to_local(cop)
	var n := 16
	for i in n:
		if i % 2 == 0:
			draw_line(com.lerp(c, float(i) / n), com.lerp(c, float(i + 1) / n), Color(1.0, 0.75, 0.04, 0.85), 2.0, true)
	draw_circle(com, 6.0, Color(1.0, 0.75, 0.04, 0.9))
	draw_circle(com, 2.6, Color.WHITE)
	var pulse := 1.0 + 0.15 * sin(t * 5.0)
	draw_circle(c, 12.0 * pulse, Color(1.0, 0.75, 0.04, 0.3))
	draw_circle(c, 5.5, Color("ffbe0b"))
	draw_circle(c, 2.2, Color.WHITE)
	draw_set_transform_matrix(Transform2D.IDENTITY)

## COP (cm, RigShowcase frame: x = patient right, y = forward) -> local px (pre-wobble).
func _cop_img_to_local(v: Vector3) -> Vector2:
	return _img_pos + (_mid + _right * v.x + _fwd * v.y) * _img_scale

func _corner_point(board: Array, i: int) -> Vector2:
	# Sensor sits a little in from the corner, toward the board centre.
	return (board[i] as Vector2).lerp(_centre(board), 0.13)

func _draw_glows() -> void:
	if _glow == null or _hero == null:
		return
	_glow_layer.draw_set_transform_matrix(_wobble)
	var fw := _glow.get_width() / float(GLOW_FRAMES)
	var fh := float(_glow.get_height())
	for side in 2:
		var board: Array = RIGHT_BOARD if side == 0 else LEFT_BOARD
		var loads: Array[float] = corners_right if side == 0 else corners_left
		for i in 4:
			var k := clampf(loads[i] / 16.0, 0.0, 1.0)
			var frame := clampi(int(round(k * (GLOW_FRAMES - 1))), 0, GLOW_FRAMES - 1)
			var p := _img_pos + _corner_point(board, i) * _img_scale
			var sz := Vector2(fw, fh) * _img_scale * (0.3 + 0.04 * sin(t * 6.0 + i + side * 2))
			_glow_layer.draw_texture_rect_region(_glow, Rect2(p - sz * 0.5, sz), Rect2(frame * fw, 0, fw, fh),
				Color(1, 1, 1, 0.55 + 0.35 * k))

func _draw_numbers(layer: Control) -> void:
	if _hero == null:
		return
	var fs := int(clampf(13.0 * _img_scale, 11, 18))
	for side in 2:
		var board: Array = RIGHT_BOARD if side == 0 else LEFT_BOARD
		var loads: Array[float] = corners_right if side == 0 else corners_left
		var show: Array = RIGHT_LABELS if side == 0 else LEFT_LABELS
		for i in show:
			var p := _to_screen(_corner_point(board, i)) + Vector2(-14, 26) * _img_scale
			var txt := "%.1f" % loads[i]
			layer.draw_string_outline(UiTheme.font_medium, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.75))
			layer.draw_string(UiTheme.font_medium, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# Per-board weights beside each board, total + COP on top, front/back gauge.
	var rb := _to_screen(RIGHT_BOARD[1]) + Vector2(-10, -70) * _img_scale  # above-left of its corner light
	var lb := _to_screen(LEFT_BOARD[3]) + Vector2(12, 0)
	_pill_on(layer, rb, "RIGHT BOARD", "%.1f kg" % w_right, UiTheme.COLOR_GREEN, -1)
	_pill_on(layer, lb, "LEFT BOARD", "%.1f kg" % w_left, UiTheme.COLOR_BLUE, 1)
	var top_y := size.y * 0.06
	_pill_on(layer, Vector2(size.x * 0.22, top_y), "TOTAL", "%.1f kg" % (w_left + w_right), UiTheme.COLOR_YELLOW, 0)
	var dir := "FORWARD" if cop.y > 1.0 else ("BACK" if cop.y < -1.0 else "CENTRED")
	_pill_on(layer, Vector2(size.x * 0.78, top_y), "COP  " + dir, "%+.1f cm" % cop.y, UiTheme.COLOR_YELLOW, 0)
	var gx := minf(_to_screen(Vector2(560, 0)).x + 20.0, size.x - 24.0)
	var g0 := _to_screen(Vector2(0, 120)).y
	var g1 := _to_screen(Vector2(0, 420)).y
	layer.draw_line(Vector2(gx, g0), Vector2(gx, g1), Color(1, 1, 1, 0.22), 4.0, true)
	layer.draw_string(UiTheme.font_eyebrow, Vector2(gx - 22, g0 - 10), "FRONT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.55))
	layer.draw_string(UiTheme.font_eyebrow, Vector2(gx - 18, g1 + 20), "BACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.55))
	var gy := lerpf(g0, g1, clampf(0.5 - cop.y / (BOARD_D * 0.8), 0.0, 1.0))
	layer.draw_circle(Vector2(gx, gy), 9.0, Color(1.0, 0.75, 0.04, 0.35))
	layer.draw_circle(Vector2(gx, gy), 5.0, Color("ffbe0b"))

## RigShowcase._pill draws on self; this draws the same pill on another layer.
func _pill_on(layer: Control, at: Vector2, caption: String, value: String, accent: Color, side: int) -> void:
	var fs_cap := 12
	var fs_val := 22
	var w := maxf(UiTheme.font_heading.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_val).x,
		UiTheme.font_eyebrow.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_cap).x) + 26.0
	var h := fs_cap + fs_val + 18.0
	var x := at.x - w * 0.5 if side == 0 else (at.x - w if side < 0 else at.x)
	x = clampf(x, 4.0, size.x - w - 4.0)
	var r := Rect2(Vector2(x, at.y - h * 0.5), Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.85)
	sb.border_color = Color(accent, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	layer.draw_style_box(sb, r)
	layer.draw_string(UiTheme.font_eyebrow, r.position + Vector2(13, 7 + fs_cap), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_cap, accent)
	layer.draw_string(UiTheme.font_heading, r.position + Vector2(13, 9 + fs_cap + fs_val), value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_val, Color.WHITE)
