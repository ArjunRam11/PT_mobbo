class_name CoinArena
extends GameArena
## Draws the collector basket and falling coins/bombs over a night-sky
## meadow. Pure view -- coin_collector.gd owns spawning/physics and calls
## set_state() each frame, plus fx_catch()/fx_bomb() on catches (each
## fx_* also plays its sound via Sfx).
##
## COLLECTOR_SIZE / ITEM_RADIUS are the game's hitboxes (coin_collector.gd
## reads them) -- the sprites are sized around them, never the other way.

## Sizes are also the collision sizes (coin_collector.gd reads them).
const COLLECTOR_SIZE := Vector2(150, 28)
const ITEM_RADIUS := 22.0
## Basket centre height above the arena bottom (catch line = this + half its height).
const COLLECTOR_BOTTOM := 52.0

var collector_x: float = 0.0
var items: Array = []  # Array of {"pos": Vector2, "is_bomb": bool}

var _lean := 0.0       # basket tilt from its own motion (cosmetic)
var _stars: Array = []

func set_state(p_collector_x: float, p_items: Array) -> void:
	var target_lean := clampf((p_collector_x - collector_x) * 0.03, -0.22, 0.22)
	_lean = lerpf(_lean, target_lean, 0.25)
	collector_x = p_collector_x
	items = p_items
	queue_redraw()

func fx_catch(pos: Vector2) -> void:
	Sfx.play("coin", 0.0, _rng.randf_range(0.95, 1.08))
	sparkle_burst(pos, 8, 70.0, "sparkle_sheet")
	burst(pos, UiTheme.COLOR_YELLOW, 10, 200.0, 320.0, 3.5)
	float_text(pos - Vector2(0, 24), "+1")

func fx_bomb(pos: Vector2) -> void:
	Sfx.play("bomb", 2.0)
	if not play_anim("explosion_sheet", 4, 3, pos - Vector2(0, 30), 170.0, 0.9):
		burst(pos, Color(0.35, 0.35, 0.4), 16, 120.0, -60.0, 9.0, 1.2)
	burst(pos, Color("ff9f1c"), 24, 340.0, 120.0, 5.0, 0.8)
	burst(pos, Color("ff5a5f"), 12, 240.0, 60.0, 4.0, 0.7)
	shake(1.0)
	flash(UiTheme.COLOR_RED)

func _draw_game() -> void:
	var ground_y := size.y - 10.0
	if draw_cover("bg_coin_sky"):
		# Painted night sky + a few twinkling sparkle sprites, hills, grass.
		if _stars.is_empty():
			var r := RandomNumberGenerator.new()
			r.seed = 7
			for i in 14:
				_stars.append({"p": Vector2(r.randf(), r.randf() * 0.6), "ph": r.randf() * 8.0, "s": r.randf_range(0.6, 1.0)})
		for st in _stars:
			var f := int(fposmod(t * 6.0 + st.ph * 8.0, 16.0))
			if f < 8:
				draw_frame("star_sparkle_sheet", 8, 1, f, st.p * size, Vector2.ONE * 26.0 * st.s)
		draw_band("bg_coin_hills", ground_y - 18.0, minf(size.y * 0.3, 190.0), t * 3.0)
		draw_band("bg_coin_grass", size.y + 6.0, 58.0)
	else:
		_draw_procedural_sky(ground_y)

	# Falling items.
	for item in items:
		var p: Vector2 = item.pos
		if item.is_bomb:
			var rot := sin(t * 6.0 + p.x * 0.1) * 0.15
			var bf := int(fposmod(t * 12.0 + p.x * 0.05, 6.0))
			if draw_frame("bomb_sheet", 6, 1, bf, p, frame_size("bomb_sheet", 6, 1, ITEM_RADIUS * 3.0), Color.WHITE, rot):
				continue
			var sz := Vector2.ONE * ITEM_RADIUS * 2.9
			if not draw_sprite("bomb", p, sz, Color.WHITE, rot):
				draw_circle(p, ITEM_RADIUS, UiTheme.COLOR_DESTRUCTIVE)
				continue
			var tip := (Vector2(52, 10) - Vector2(32, 32)) / 64.0 * sz.x
			tip = p + tip.rotated(rot)
			var flick := 0.6 + 0.4 * sin(t * 40.0 + p.x)
			draw_glow(tip, 10.0 * flick, Color(1.0, 0.7, 0.2, 0.9))
			draw_circle(tip, 2.5 + 1.5 * flick, Color("fff3a0"))
		else:
			draw_glow(p, ITEM_RADIUS * 2.0, Color(1.0, 0.8, 0.2, 0.35), 3)
			var cf := int(fposmod(t * 14.0 + p.x * 0.05, 8.0))
			if draw_frame("coin_sheet", 8, 1, cf, p, frame_size("coin_sheet", 8, 1, ITEM_RADIUS * 2.5)):
				continue
			var spin := absf(cos(t * 4.5 + p.x * 0.05))
			if not draw_sprite("coin", p, Vector2(maxf(0.18, spin), 1.0) * ITEM_RADIUS * 2.5):
				draw_circle(p, ITEM_RADIUS, UiTheme.COLOR_ACCENT)

	# Collector basket: rim top sits on the catch line (hitbox top).
	var collector_y := size.y - COLLECTOR_BOTTOM
	var rim_y := collector_y - COLLECTOR_SIZE.y * 0.5
	var bw := COLLECTOR_SIZE.x * 1.15
	var btx := tex("basket")
	var bh := bw * btx.get_height() / float(btx.get_width()) if btx != null else 34.0
	var basket_sz := Vector2(bw, bh)
	var center := Vector2(collector_x, rim_y + basket_sz.y * 0.5 - 2.0)
	draw_rect(Rect2(Vector2(collector_x - basket_sz.x * 0.45, size.y - 6.0), Vector2(basket_sz.x * 0.9, 5.0)), Color(0, 0, 0, 0.3), true)
	if not draw_sprite("basket", center, basket_sz, Color.WHITE, _lean):
		draw_rect(Rect2(Vector2(collector_x - COLLECTOR_SIZE.x * 0.5, rim_y), COLLECTOR_SIZE), UiTheme.COLOR_PRIMARY, true)

## Fallback scenery when the painted backgrounds aren't there.
func _draw_procedural_sky(ground_y: float) -> void:
	draw_vgradient(Rect2(Vector2.ZERO, size), Color("10153a"), Color("43306e"))
	if _stars.is_empty():
		var r := RandomNumberGenerator.new()
		r.seed = 7
		for i in 60:
			_stars.append({"p": Vector2(r.randf(), r.randf() * 0.7), "ph": r.randf() * TAU, "s": r.randf_range(0.8, 2.0)})
	for st in _stars:
		draw_circle(st.p * size, st.s * 2.0, Color(1, 1, 1, 0.35 + 0.65 * absf(sin(t * 1.3 + st.ph))))
	var moon := Vector2(size.x * 0.86, minf(70.0, size.y * 0.15))
	draw_glow(moon, 60.0, Color(1.0, 0.95, 0.75, 0.6))
	draw_circle(moon, 26.0, Color("fdf3c8"))
	_draw_hills(ground_y - 30.0, 26.0, 0.006, Color("2a2350"), 0.0)
	_draw_hills(ground_y - 8.0, 14.0, 0.011, Color("1f4a33"), 1.7)
	draw_rect(Rect2(0, ground_y, size.x, size.y - ground_y), Color("2f7a45"), true)
	draw_line(Vector2(0, ground_y), Vector2(size.x, ground_y), Color("5fd47a"), 2.0)

func _draw_hills(base_y: float, amp: float, freq: float, color: Color, phase: float) -> void:
	var pts := PackedVector2Array()
	var step := 24.0
	var x := 0.0
	while x <= size.x + step:
		pts.append(Vector2(x, base_y - amp * (0.5 + 0.5 * sin(x * freq + phase))))
		x += step
	pts.append(Vector2(size.x + step, size.y))
	pts.append(Vector2(0, size.y))
	draw_colored_polygon(pts, color)
