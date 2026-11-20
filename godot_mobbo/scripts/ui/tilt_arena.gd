class_name TiltArena
extends Control
## Draws a board that rotates by tilt_angle (radians) and a ball at
## ball_pos (both in this Control's local pixel space). Pure view -- the
## owning game script does the physics and calls set_state() each frame.
## Used by the Weight Shifting screen.

var tilt_angle: float = 0.0
var ball_pos: Vector2 = Vector2.ZERO
var ball_radius: float = 10.0

func set_state(p_tilt_angle: float, p_ball_pos: Vector2) -> void:
	tilt_angle = p_tilt_angle
	ball_pos = p_ball_pos
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var board_half := size * 0.42

	draw_set_transform(center, tilt_angle, Vector2.ONE)
	draw_rect(Rect2(-board_half, board_half * 2.0), UiTheme.COLOR_SURFACE, true)
	draw_rect(Rect2(-board_half, board_half * 2.0), UiTheme.COLOR_BORDER, false, 2.0)
	# Center line, so the tilt is visible even with the ball near center.
	draw_line(Vector2(-board_half.x, 0), Vector2(board_half.x, 0), UiTheme.COLOR_BORDER, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_circle(center + ball_pos, ball_radius, UiTheme.COLOR_PRIMARY)
