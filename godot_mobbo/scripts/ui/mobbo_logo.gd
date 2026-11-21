class_name MobboLogo
extends Control
## Animated MoBBo logo (login + hub headers), built from the generated logo
## art split by tools/prepare_ui_art.py: sprites/logo/board_l, board_r, arc
## (same canvas, so they line up), wordmark, glow_sheet; geometry (arc
## circle, dot, sensor dots, board centres) comes from UiArtMeta.DATA.logo.
##
## Intro (~2.6 s): boards slide in and tip into place, the four sensor dots
## light up one by one, the arc draws outward from the middle, the yellow
## centre-of-pressure dot drops onto the arc, rolls back and forth and
## settles at the top with a glow burst, then the wordmark wipes in.
## Idle: the boards rock gently, the dot keeps balancing along the arc, the
## sensors on the side it leans toward glow brighter, a soft glow breathes.

const DOT_COLOR := Color("ffb51f")
const INTRO_END := 2.6

@export var show_wordmark := true
@export var play_intro := true
@export var intro_sounds := true

var t := 0.0
var _geo: Dictionary
var _board_l: Texture2D
var _board_r: Texture2D
var _arc: Texture2D
var _word: Texture2D
var _glow_sheet: Texture2D
var _soft: GradientTexture2D
var _sensor_hit := [false, false, false, false]
var _settled := false
var _burst_t := -1.0

static func available() -> bool:
	return UiArtMeta.DATA.has("logo") and GameArena.tex("logo/board_l") != null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_geo = UiArtMeta.DATA.get("logo", {})
	_board_l = GameArena.tex("logo/board_l")
	_board_r = GameArena.tex("logo/board_r")
	_arc = GameArena.tex("logo/arc")
	_word = GameArena.tex("logo/wordmark")
	_glow_sheet = GameArena.tex("logo/glow_sheet")
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_soft = GradientTexture2D.new()
	_soft.gradient = g
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5, 0.5)
	_soft.fill_to = Vector2(1.0, 0.5)
	if not play_intro:
		t = INTRO_END + 0.5
		_settled = true
		_sensor_hit = [true, true, true, true]

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

# -- Geometry helpers ---------------------------------------------------------------------

func _v(a: Array) -> Vector2:
	return Vector2(a[0], a[1])

func _canvas() -> Vector2:
	return _v(_geo.size)

func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

func _ease_back(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var c1 := 1.6
	return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)

## Angle (on the arc circle) of the dot: intro roll, then idle balancing.
func _dot_angle(theta_top: float, theta_left: float) -> float:
	var t0 := 1.35
	if t < t0:
		return theta_left
	var settle := theta_top + (theta_left - theta_top) * exp(-(t - t0) * 2.0) * cos((t - t0) * 5.2)
	var idle := 0.13 * sin((t - t0) * 1.25) + 0.04 * sin((t - t0) * 3.1)
	return settle + idle * smoothstep(t0 + 0.4, INTRO_END + 0.6, t)

# -- Drawing -----------------------------------------------------------------------------------

func _draw() -> void:
	if _geo.is_empty() or _board_l == null:
		return
	var cv := _canvas()
	var mark_h := size.y * 0.94
	var s := mark_h / cv.y
	var mark_w := cv.x * s
	var word_h := size.y * 0.6
	var word_w := 0.0
	if show_wordmark and _word != null:
		word_w = word_h * _word.get_width() / float(_word.get_height())
	var gap := size.y * 0.08 if word_w > 0.0 else 0.0
	var total := mark_w + gap + word_w
	var origin := Vector2((size.x - total) * 0.5, (size.y - mark_h) * 0.5)
	var base := Transform2D(0.0, Vector2(s, s), 0.0, origin)   # canvas px -> local

	# Breathing glow behind the mark.
	var breathe := 0.22 + 0.08 * sin(t * 1.6)
	var gc := base * Vector2(cv.x * 0.5, cv.y * 0.55)
	var gr := mark_h * 0.75
	draw_texture_rect(_soft, Rect2(gc - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false,
		Color(0.24, 0.86, 0.52, breathe * smoothstep(0.0, 1.0, t)))

	# Boards: slide in from the sides, tip, settle; then rock gently.
	var bp := _ease_back(t / 0.75)
	var appear := clampf(t / 0.3, 0.0, 1.0)
	var settle := 0.14 * exp(-maxf(0.0, t - 0.75) * 4.0) * sin(maxf(0.0, t - 0.75) * 13.0) if t > 0.75 else 0.0
	var rock := 0.03 * sin(t * 1.25) * smoothstep(INTRO_END - 0.4, INTRO_END + 0.8, t)
	var centres := [_v(_geo.boards[0]), _v(_geo.boards[1])]
	var xf_l := _board_xf(centres[0], Vector2(-cv.x * 0.7 * (1.0 - bp), 0), -0.7 * (1.0 - bp) + settle + rock)
	var xf_r := _board_xf(centres[1], Vector2(cv.x * 0.7 * (1.0 - bp), 0), 0.7 * (1.0 - bp) - settle - rock)
	if intro_sounds and t > 0.62 and t - get_process_delta_time() <= 0.62:
		Sfx.play("bump", -10.0)
	draw_set_transform_matrix(base * xf_l)
	draw_texture_rect(_board_l, Rect2(Vector2.ZERO, cv), false, Color(1, 1, 1, appear))
	draw_set_transform_matrix(base * xf_r)
	draw_texture_rect(_board_r, Rect2(Vector2.ZERO, cv), false, Color(1, 1, 1, appear))
	draw_set_transform_matrix(Transform2D.IDENTITY)

	# Arc geometry.
	var c := _v(_geo.arc_center)
	var R: float = _geo.arc_radius
	var dot_rest := Vector2(_geo.dot[0], _geo.dot[1])
	var dot_r: float = _geo.dot[2]
	var d := dot_rest.distance_to(c)
	var theta_top := atan2(dot_rest.y - c.y, dot_rest.x - c.x)
	var theta_left := -acos(clampf((float(_geo.arc_x[0]) + dot_r * 0.6 - c.x) / R, -1.0, 1.0))
	var theta := _dot_angle(theta_top, theta_left)

	# Sensors: light up one by one, then glow toward the side the dot leans.
	var lean := clampf((theta - theta_top) / 0.25, -1.0, 1.0)   # + = right
	for i in _geo.sensors.size():
		var sp := _v(_geo.sensors[i])
		var on_left := sp.x < cv.x * 0.5
		var xf: Transform2D = xf_l if on_left else xf_r
		var light_t: float = 0.55 + 0.11 * float(i)
		if t >= light_t and not _sensor_hit[i]:
			_sensor_hit[i] = true
			if intro_sounds:
				Sfx.play("wall", -12.0, 1.0 + 0.08 * i, 0)
		if t < light_t:
			continue
		var flash := exp(-(t - light_t) * 5.0)
		var side := (0.5 - 0.5 * lean) if on_left else (0.5 + 0.5 * lean)
		var idle := 0.35 + 0.65 * side * smoothstep(INTRO_END - 0.5, INTRO_END + 0.5, t)
		var k := maxf(flash, idle * smoothstep(light_t, light_t + 0.3, t))
		var p := base * (xf * sp)
		var col := Color(0.55, 0.85, 1.0) if on_left else Color(0.55, 1.0, 0.75)
		var rr := mark_h * (0.05 + 0.05 * k)
		draw_texture_rect(_soft, Rect2(p - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Color(col, 0.75 * k))
		draw_circle(p, mark_h * 0.012 * (1.0 + 0.5 * flash), Color(1, 1, 1, 0.9))

	# Arc: draws outward from its middle.
	if _arc != null:
		var ak := _ease_out((t - 0.85) / 0.45)
		if ak > 0.0:
			var x0: float = _geo.arc_x[0] - 12.0
			var x1: float = _geo.arc_x[1] + 12.0
			var mid := (x0 + x1) * 0.5
			var half := (x1 - x0) * 0.5 * ak
			var src := Rect2(mid - half, 0.0, half * 2.0, cv.y)
			draw_set_transform_matrix(base)
			draw_texture_rect_region(_arc, src, src)
			draw_set_transform_matrix(Transform2D.IDENTITY)

	# Dot: drops onto the left end, rolls, settles at the top.
	if t > 1.15:
		var pos := c + d * Vector2(cos(theta), sin(theta))
		if t < 1.35:
			var f := (t - 1.15) / 0.2
			pos.y -= (1.0 - f * f) * cv.y * 0.35
		var dp := base * pos
		var drs := dot_r * s
		draw_circle(dp + Vector2(0, drs * 0.15), drs * 1.02, Color(0, 0, 0, 0.25))
		draw_circle(dp, drs, DOT_COLOR)
		var spin := (theta - theta_top) * d / dot_r
		draw_circle(dp + Vector2(cos(spin - 2.2), sin(spin - 2.2)) * drs * 0.45, drs * 0.22, Color(1, 1, 1, 0.55))
		if not _settled and t >= INTRO_END:
			_settled = true
			_burst_t = t
			if intro_sounds:
				Sfx.play("score", -6.0)
		if _burst_t >= 0.0 and _glow_sheet != null and t - _burst_t < 0.6:
			var fw := _glow_sheet.get_width() / 8.0
			var f := clampi(int((t - _burst_t) / 0.6 * 8.0), 0, 7)
			var bs := drs * 7.0
			draw_texture_rect_region(_glow_sheet, Rect2(dp - Vector2(bs, bs) * 0.5, Vector2(bs, bs)),
				Rect2(f * fw, 0, fw, _glow_sheet.get_height()))

	# Wordmark: wipes in left to right with a soft leading edge.
	if word_w > 0.0:
		var wk := _ease_out((t - 1.7) / 0.9)
		if wk > 0.0:
			var wpos := Vector2(origin.x + mark_w + gap, (size.y - word_h) * 0.5 + (1.0 - wk) * 8.0)
			var tw := float(_word.get_width())
			var th := float(_word.get_height())
			var cut := tw * wk
			draw_texture_rect_region(_word, Rect2(wpos, Vector2(word_w * wk, word_h)), Rect2(0, 0, cut, th))
			if wk < 1.0:
				var ex := wpos.x + word_w * wk
				draw_rect(Rect2(Vector2(ex - 2.0, wpos.y), Vector2(3.0, word_h)), Color(1.0, 0.85, 0.3, 0.6 * (1.0 - wk)))

func _board_xf(centre: Vector2, offset: Vector2, rot: float) -> Transform2D:
	return Transform2D(0.0, centre + offset) * Transform2D(rot, Vector2.ZERO) * Transform2D(0.0, -centre)
