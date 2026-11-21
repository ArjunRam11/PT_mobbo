class_name FlappyArena
extends Control
## Draws the bird and scrolling pipes (each pipe = a vertical gap the bird
## must stay within). Pure view -- floppy_bird.gd owns the game state and
## calls set_state() each frame.

const BIRD_RADIUS := 12.0
const PIPE_WIDTH := 36.0

var bird_y: float = 0.0
var pipes: Array = []  # {"x": float, "gap_center_y": float, "gap_half": float}

func set_state(p_bird_y: float, p_pipes: Array) -> void:
	bird_y = p_bird_y
	pipes = p_pipes
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.COLOR_SURFACE, true)
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.COLOR_BORDER, false, 2.0)

	for pipe in pipes:
		var x: float = pipe.x
		var gap_top: float = pipe.gap_center_y - pipe.gap_half
		var gap_bottom: float = pipe.gap_center_y + pipe.gap_half
		draw_rect(Rect2(Vector2(x - PIPE_WIDTH * 0.5, 0), Vector2(PIPE_WIDTH, gap_top)), UiTheme.COLOR_PRIMARY_PRESSED, true)
		draw_rect(Rect2(Vector2(x - PIPE_WIDTH * 0.5, gap_bottom), Vector2(PIPE_WIDTH, size.y - gap_bottom)), UiTheme.COLOR_PRIMARY_PRESSED, true)

	var bird_x := size.x * 0.25
	draw_circle(Vector2(bird_x, bird_y), BIRD_RADIUS, UiTheme.COLOR_ACCENT)
