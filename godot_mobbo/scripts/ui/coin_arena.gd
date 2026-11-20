class_name CoinArena
extends Control
## Draws the collector paddle and falling coins/bombs. Pure view --
## coin_collector.gd owns spawning/physics and calls set_state() each frame.

const COLLECTOR_SIZE := Vector2(80, 16)
const ITEM_RADIUS := 10.0

var collector_x: float = 0.0
var items: Array = []  # Array of {"pos": Vector2, "is_bomb": bool}

func set_state(p_collector_x: float, p_items: Array) -> void:
	collector_x = p_collector_x
	items = p_items
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.COLOR_SURFACE, true)
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.COLOR_BORDER, false, 2.0)

	var collector_y := size.y - 18.0
	draw_rect(Rect2(Vector2(collector_x - COLLECTOR_SIZE.x * 0.5, collector_y - COLLECTOR_SIZE.y * 0.5), COLLECTOR_SIZE), UiTheme.COLOR_PRIMARY, true)

	for item in items:
		var color: Color = UiTheme.COLOR_DESTRUCTIVE if item.is_bomb else UiTheme.COLOR_ACCENT
		draw_circle(item.pos, ITEM_RADIUS, color)
