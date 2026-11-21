class_name TiltArena
extends GameArena
## Draws a seesaw plank that tilts by tilt_angle (radians) with a marble
## rolling along it. Pure view -- the owning game script does the physics
## and calls set_state() each frame. Used by the Weight Shifting screen.
##
## Display mapping (view only -- the game's numbers are untouched): the game
## keeps ball_pos in an unrotated board frame of half-size arena.size * 0.42,
## where its gravity rests the ball at y = -bound.y. Drawn literally, that
## board is too big to rotate inside the arena (its ends leave the screen),
## and the old view drew the ball unrotated along the top edge. Here the
## plank pivots at the centre, is sized so the full +-MAX_TILT_DEG swing
## always fits, and the marble sits on it at ball_pos.x / bound.x of the
## plank's half-length (lifted off it if the game's y leaves the floor).
## ball_radius is the game's collision radius (weight_shifting.gd reads it).

const MAX_TILT_DEG := 25.0  # weight_shifting.gd's MAX_TILT_DEG, for sizing only
const PLANK_H := 16.0
const END_STOP_H := 34.0

var tilt_angle: float = 0.0
var ball_pos: Vector2 = Vector2.ZERO
var ball_radius: float = 20.0

var _roll := 0.0
var _prev_vx := 0.0
var _speed := 0.0  # px/s, smoothed, drives the rolling sound

func set_state(p_tilt_angle: float, p_ball_pos: Vector2) -> void:
	var dx := p_ball_pos.x - ball_pos.x
	_roll += dx / ball_radius
	var dt := maxf(get_process_delta_time(), 0.001)
	_speed = lerpf(_speed, absf(dx) / dt, 0.15)
	Sfx.set_loop("roll", _speed / 350.0, -8.0)
	# Wall bump: horizontal direction flipped near a side wall.
	var bound_x := _game_bound().x
	if absf(dx) > 0.01 and signf(dx) != signf(_prev_vx) and absf(p_ball_pos.x) > bound_x - 2.0 and absf(_prev_vx) > 1.0:
		var half := _plank_half()
		Sfx.play("bump", -2.0, 1.0, 120)
		burst(_plank_to_screen(Vector2(signf(p_ball_pos.x) * half, -ball_radius)),
			Color("e6c08a"), 8, 120.0, 200.0, 3.0, 0.5)
	if absf(dx) > 0.01:
		_prev_vx = dx
	tilt_angle = p_tilt_angle
	ball_pos = p_ball_pos
	queue_redraw()

func _exit_tree() -> void:
	Sfx.stop_loop("roll")

## The game's clamp bounds (same formula as weight_shifting.gd).
func _game_bound() -> Vector2:
	return size * 0.42 - Vector2.ONE * ball_radius

## Half-length of the drawn plank: as long as fits at the max tilt.
func _plank_half() -> float:
	var room := size.y * 0.5 - PLANK_H - 12.0
	return clampf(room / sin(deg_to_rad(MAX_TILT_DEG)), 60.0, size.x * 0.44)

func _pivot() -> Vector2:
	return size * 0.5 + Vector2(0, 8)

## Plank frame: x along the plank's top surface, y up = negative.
func _plank_to_screen(p: Vector2) -> Vector2:
	return Transform2D(tilt_angle, _pivot()) * p

func _marble_plank_pos() -> Vector2:
	var half := _plank_half()
	var bound := _game_bound()
	var u := clampf(ball_pos.x / bound.x, -1.0, 1.0) if bound.x > 0.0 else 0.0
	var off_floor := maxf(0.0, ball_pos.y + bound.y)  # >0 when the game's ball left its floor
	return Vector2(u * (half - ball_radius - 6.0), -ball_radius - off_floor * 0.5)

func _draw_game() -> void:
	var full := Rect2(Vector2.ZERO, size)
	draw_vgradient(full, Color("1d2238"), Color("0e1018"))
	var pivot := _pivot()
	var half := _plank_half()

	# Fixed level reference (does not tilt) so the angle reads at a glance.
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, pivot.y), Vector2(x + 10.0, pivot.y), Color(1, 1, 1, 0.12), 1.0)
		x += 20.0

	_draw_side_arrows(pivot, half)

	# Fulcrum (fixed).
	var tri := PackedVector2Array([pivot + Vector2(0, PLANK_H * 0.5), pivot + Vector2(-26, size.y), pivot + Vector2(26, size.y)])
	draw_colored_polygon(tri, Color("3a3f58"))
	draw_circle(pivot + Vector2(0, PLANK_H * 0.5), 7.0, Color("5a6080"))

	# Rotated plank frame (composed with the screen shake).
	set_xf(_xf * Transform2D(tilt_angle, pivot))
	var plank := Rect2(Vector2(-half, 0), Vector2(half * 2.0, PLANK_H))
	draw_rect(Rect2(plank.position + Vector2(0, 4), plank.size), Color(0, 0, 0, 0.35), true)
	var ptx := tex("plank")
	var plank_tile := PLANK_H * ptx.get_width() / float(ptx.get_height()) if ptx != null else 64.0
	if not draw_tiled("plank", plank, plank_tile):
		draw_rect(plank, Color("8f5a2c"), true)
	for side in [-1.0, 1.0]:
		var stop := Rect2(Vector2(-half if side < 0 else half - 10.0, -END_STOP_H), Vector2(10, END_STOP_H + PLANK_H))
		draw_rect(stop, Color("6e4220"), true)
		draw_rect(stop, Color("4a2a12"), false, 2.0)
	draw_line(Vector2(0, -6.0), Vector2(0, 0), Color(1, 1, 1, 0.45), 2.0)  # centre mark

	# Marble.
	var bp := _marble_plank_pos()
	draw_circle(Vector2(bp.x, -1.0), ball_radius * 0.8, Color(0, 0, 0, 0.3))
	if not draw_sprite("marble", bp, Vector2.ONE * ball_radius * 2.0, Color.WHITE, _roll):
		draw_circle(bp, ball_radius, UiTheme.COLOR_PRIMARY)
	set_xf(Transform2D(0.0, _shake_offset))

## Left/right chevrons that light up on the side currently pulled down.
func _draw_side_arrows(center: Vector2, half: float) -> void:
	var k := clampf(tilt_angle / deg_to_rad(20.0), -1.0, 1.0)
	for side in [-1.0, 1.0]:
		var strength := maxf(0.0, k * side)
		var col := Color(UiTheme.COLOR_YELLOW, 0.15 + 0.75 * strength)
		var ax: float = center.x + side * (half * 0.55)
		var ay := minf(48.0, size.y * 0.15)
		for i in 3:
			var ox: float = ax + side * i * 16.0
			var pts := PackedVector2Array([
				Vector2(ox, ay - 12), Vector2(ox + side * 12.0, ay), Vector2(ox, ay + 12)])
			draw_polyline(pts, Color(col, col.a * (1.0 - 0.25 * i)), 4.0)

func _draw_overlay() -> void:
	# Tilt gauge, top centre.
	var c := Vector2(size.x * 0.5, 58.0)
	var r := 40.0
	draw_arc(c, r, PI + 0.35, TAU - 0.35, 32, Color(1, 1, 1, 0.25), 4.0)
	for deg in [-20, -10, 0, 10, 20]:
		var a := -PI * 0.5 + deg_to_rad(deg) * 2.0
		draw_line(c + Vector2(cos(a), sin(a)) * (r - 6.0), c + Vector2(cos(a), sin(a)) * (r + 4.0), Color(1, 1, 1, 0.5), 2.0)
	var na := -PI * 0.5 + clampf(tilt_angle * 2.0, -PI * 0.5 + 0.35, PI * 0.5 - 0.35)
	draw_line(c, c + Vector2(cos(na), sin(na)) * (r - 4.0), UiTheme.COLOR_YELLOW, 3.0)
	draw_circle(c, 4.0, UiTheme.COLOR_YELLOW)
