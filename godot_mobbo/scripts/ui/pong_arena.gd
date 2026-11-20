class_name PongArena
extends Control
## Draws the pong court: player paddle (bottom, weight-controlled), computer
## paddle (top, AI), and the ball. Pure view -- ping_pong.gd owns the
## physics/AI and calls set_state() each frame.

const PADDLE_SIZE := Vector2(70, 14)
const BALL_RADIUS := 8.0

var player_x: float = 0.0
var computer_x: float = 0.0
var ball_pos: Vector2 = Vector2.ZERO

func set_state(p_player_x: float, p_computer_x: float, p_ball_pos: Vector2) -> void:
	player_x = p_player_x
	computer_x = p_computer_x
	ball_pos = p_ball_pos
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.COLOR_SURFACE, true)
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.COLOR_BORDER, false, 2.0)
	draw_line(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5), UiTheme.COLOR_BORDER, 1.0)

	var paddle_y_bottom := size.y - 20.0
	var paddle_y_top := 20.0
	draw_rect(Rect2(Vector2(player_x - PADDLE_SIZE.x * 0.5, paddle_y_bottom - PADDLE_SIZE.y * 0.5), PADDLE_SIZE), UiTheme.COLOR_PRIMARY, true)
	draw_rect(Rect2(Vector2(computer_x - PADDLE_SIZE.x * 0.5, paddle_y_top - PADDLE_SIZE.y * 0.5), PADDLE_SIZE), UiTheme.COLOR_DESTRUCTIVE, true)
	draw_circle(ball_pos, BALL_RADIUS, UiTheme.COLOR_TEXT)
