class_name PongArena
extends GameArena
## Draws the pong court: player paddle (bottom, weight-controlled), computer
## paddle (top, AI), and the ball with a motion trail. Pure view --
## ping_pong.gd owns the physics/AI and calls set_state() each frame, plus
## fx_paddle()/fx_wall()/fx_point() on events.
##
## PADDLE_SIZE / BALL_RADIUS are the game's hitboxes (ping_pong.gd reads them).

## Sizes are also the collision sizes (ping_pong.gd reads them).
const PADDLE_SIZE := Vector2(130, 22)
const BALL_RADIUS := 14.0
const TRAIL_LEN := 12

var player_x: float = 0.0
var computer_x: float = 0.0
var ball_pos: Vector2 = Vector2.ZERO

var _trail: Array[Vector2] = []
var _hit_player := 0.0
var _hit_cpu := 0.0

func set_state(p_player_x: float, p_computer_x: float, p_ball_pos: Vector2) -> void:
	if p_ball_pos.distance_to(ball_pos) > 60.0:
		_trail.clear()  # ball was reset -- don't smear a trail across the court
	if p_ball_pos != ball_pos:
		_trail.append(p_ball_pos)
		if _trail.size() > TRAIL_LEN:
			_trail.pop_front()
	player_x = p_player_x
	computer_x = p_computer_x
	ball_pos = p_ball_pos
	queue_redraw()

func fx_paddle(pos: Vector2, is_player: bool) -> void:
	Sfx.play("paddle" if is_player else "paddle_cpu", 0.0, _rng.randf_range(0.95, 1.05))
	var c := UiTheme.COLOR_PRIMARY if is_player else UiTheme.COLOR_DESTRUCTIVE
	burst(pos, c, 10, 180.0, 0.0, 3.5, 0.45)
	sparkle_burst(pos, 4, 50.0, "star_sparkle_sheet", 26.0, 0.4)
	if is_player:
		_hit_player = 1.0
	else:
		_hit_cpu = 1.0

func fx_wall(pos: Vector2) -> void:
	Sfx.play("wall", -4.0)
	burst(pos, Color(1, 1, 1, 0.8), 6, 110.0, 0.0, 2.5, 0.35)

func fx_point(player_scored: bool) -> void:
	Sfx.play("point_win" if player_scored else "point_lose")
	var c := UiTheme.COLOR_PRIMARY if player_scored else UiTheme.COLOR_DESTRUCTIVE
	flash(c, 0.8)
	shake(0.5)
	float_text(size * 0.5 + Vector2(0, 10), "POINT - YOU" if player_scored else "POINT - CPU", c, 34)

func _process(delta: float) -> void:
	_hit_player = maxf(0.0, _hit_player - delta * 4.0)
	_hit_cpu = maxf(0.0, _hit_cpu - delta * 4.0)
	super._process(delta)

func _draw_game() -> void:
	var full := Rect2(Vector2.ZERO, size)
	var mid := size.y * 0.5
	# Painted court, stretched so its border/centre line follow the arena edges.
	if not draw_cover("bg_pong_court", true):
		draw_vgradient(full, Color("0c2240"), Color("0f3358"))
		var line := Color(1, 1, 1, 0.22)
		draw_rect(full.grow(-10.0), line, false, 2.0)
		var x := 14.0
		while x < size.x - 14.0:
			draw_line(Vector2(x, mid), Vector2(minf(x + 14.0, size.x - 14.0), mid), Color(1, 1, 1, 0.35), 3.0)
			x += 26.0
		draw_arc(size * 0.5, minf(size.x, size.y) * 0.12, 0.0, TAU, 48, line, 2.0)

	# Side labels.
	var f := UiTheme.font_eyebrow
	var lx := 18.0 if tex("bg_pong_court") == null else size.x * 0.045  # inside the painted border
	draw_string(f, Vector2(lx, mid - 12), "CPU", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UiTheme.COLOR_RED, 0.8))
	draw_string(f, Vector2(lx, mid + 24), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UiTheme.COLOR_GREEN, 0.8))

	var paddle_y_bottom := size.y - 20.0
	var paddle_y_top := 20.0
	_draw_paddle(Vector2(player_x, paddle_y_bottom), UiTheme.COLOR_PRIMARY, _hit_player)
	_draw_paddle(Vector2(computer_x, paddle_y_top), UiTheme.COLOR_DESTRUCTIVE, _hit_cpu)

	# Trail, then ball.
	for i in _trail.size():
		var k := float(i + 1) / (_trail.size() + 1)
		draw_circle(_trail[i], BALL_RADIUS * (0.3 + 0.6 * k), Color(1.0, 0.85, 0.6, 0.35 * k))
	draw_glow(ball_pos, BALL_RADIUS * 3.0, Color(1.0, 0.9, 0.7, 0.5), 3)
	if not draw_sprite("ball", ball_pos, Vector2.ONE * BALL_RADIUS * 2.3, Color.WHITE, t * 6.0):
		draw_circle(ball_pos, BALL_RADIUS, UiTheme.COLOR_TEXT)

func _draw_paddle(center: Vector2, color: Color, hit: float) -> void:
	# Squash-and-stretch on hit; glow underneath.
	var sz := PADDLE_SIZE * Vector2(1.0 + 0.12 * hit, 1.25 - 0.25 * hit)
	draw_glow(center, PADDLE_SIZE.x * 0.75, Color(color, 0.35 + 0.4 * hit), 4)
	if not draw_sprite("paddle", center, sz, color.lerp(Color.WHITE, 0.15 + 0.5 * hit)):
		draw_rect(Rect2(center - PADDLE_SIZE * 0.5, PADDLE_SIZE), color, true)
