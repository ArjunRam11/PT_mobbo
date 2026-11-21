class_name FlappyArena
extends GameArena
## Draws the bird and scrolling stone pillars (each pillar pair = a vertical
## gap the bird must stay within) over a dusk sky with parallax hills and
## clouds. Pure view -- floppy_bird.gd owns the game state and calls
## set_state() each frame, plus fx_score()/fx_hit() and sets `lives`,
## `scroll_speed` for the HUD/background.
##
## BIRD_RADIUS / PIPE_WIDTH are game constants (floppy_bird.gd reads them);
## the sprites are sized around them.

## Sizes are also the collision sizes (floppy_bird.gd reads them).
const BIRD_RADIUS := 24.0
const PIPE_WIDTH := 60.0
const CAP_H := 22.0
const BIRD_FRAMES := ["bird_up", "bird_mid", "bird_down", "bird_mid"]

var bird_y: float = 0.0
var pipes: Array = []  # {"x": float, "gap_center_y": float, "gap_half": float}

var lives := -1          ## < 0 hides the hearts
var max_lives := 5
var scroll_speed := 0.0  ## px/s of the pillars, for background parallax

var _scroll := 0.0
var _bird_rot := 0.0
var _hurt := 0.0
var _clouds: Array = []
## Bird species (sprite sheets, 4 flap frames); next_bird() cycles them.
const BIRD_SHEETS := ["bird_sheet", "bird_robin_sheet", "bird_goldfinch_sheet"]
var _bird_idx := 0

func next_bird() -> void:
	for k in BIRD_SHEETS.size():
		_bird_idx = (_bird_idx + 1) % BIRD_SHEETS.size()
		if tex(BIRD_SHEETS[_bird_idx]) != null:
			return

func set_state(p_bird_y: float, p_pipes: Array) -> void:
	var dy := p_bird_y - bird_y
	_bird_rot = lerpf(_bird_rot, clampf(dy * 0.06, -0.45, 0.55), 0.2)
	bird_y = p_bird_y
	pipes = p_pipes
	queue_redraw()

func fx_score() -> void:
	Sfx.play("score")
	var p := _bird_pos()
	float_text(p - Vector2(0, 30), "+1")
	sparkle_burst(p, 7, 70.0, "star_sparkle_sheet")

func fx_hit() -> void:
	Sfx.play("hit")
	var p := _bird_pos()
	burst(p, Color("3fb7f0"), 14, 200.0, 200.0, 4.5, 0.9)
	burst(p, Color.WHITE, 8, 140.0, 120.0, 3.0, 0.7)
	shake(0.8)
	flash(UiTheme.COLOR_RED, 0.8)
	_hurt = 1.0

func _process(delta: float) -> void:
	_scroll += (scroll_speed + 12.0) * delta  # clouds always drift a little
	_hurt = maxf(0.0, _hurt - delta * 1.5)
	super._process(delta)

func _bird_pos() -> Vector2:
	return Vector2(size.x * 0.25, bird_y)

func _draw_game() -> void:
	var painted := draw_cover("bg_bird_sky")
	if not painted:
		draw_vgradient(Rect2(0, 0, size.x, size.y * 0.6), Color("27306e"), Color("8a5aa0"))
		draw_vgradient(Rect2(0, size.y * 0.6, size.x, size.y * 0.4), Color("8a5aa0"), Color("f2a06b"))
		var sun := Vector2(size.x * 0.72, size.y * 0.8)
		draw_glow(sun, 140.0, Color(1.0, 0.75, 0.4, 0.5))
		draw_circle(sun, 46.0, Color("ffd28a"))

	# Clouds (parallax, wrap around).
	if _clouds.is_empty():
		var r := RandomNumberGenerator.new()
		r.seed = 11
		for i in 6:
			_clouds.append({"x": r.randf(), "y": r.randf_range(0.05, 0.5), "k": r.randf_range(0.15, 0.45), "s": r.randf_range(0.6, 1.3)})
	for c in _clouds:
		var span := size.x + 260.0
		var cx := fposmod(c.x * span - _scroll * c.k, span) - 130.0
		var ctx := tex("cloud")
		var caspect := ctx.get_height() / float(ctx.get_width()) if ctx != null else 0.5
		var csz: Vector2 = Vector2(150, 150 * caspect) * float(c.s)
		draw_sprite("cloud", Vector2(cx, c.y * size.y), csz, Color(1, 1, 1, 0.55 + 0.3 * c.k))

	# Parallax hills: the painted band twice (far = bigger, lighter, slower).
	var hills_done := false
	if painted and tex("bg_bird_hills") != null:
		draw_band("bg_bird_hills", size.y * 0.97, size.y * 0.3, _scroll * 0.25, Color(0.85, 0.8, 0.95))
		draw_band("bg_bird_hills", size.y * 1.06, size.y * 0.22, _scroll * 0.6 + 400.0, Color(0.55, 0.48, 0.68))
		hills_done = true
	if not hills_done:
		_draw_hills(size.y * 0.82, size.y * 0.1, 0.006, Color("4a3a7a"), _scroll * 0.2)
		_draw_hills(size.y * 0.92, size.y * 0.07, 0.011, Color("2b2552"), _scroll * 0.5)

	# Pillars.
	for pipe in pipes:
		var x: float = pipe.x
		var gap_top: float = pipe.gap_center_y - pipe.gap_half
		var gap_bottom: float = pipe.gap_center_y + pipe.gap_half
		var top_rect := Rect2(Vector2(x - PIPE_WIDTH * 0.5, 0), Vector2(PIPE_WIDTH, gap_top))
		var bot_rect := Rect2(Vector2(x - PIPE_WIDTH * 0.5, gap_bottom), Vector2(PIPE_WIDTH, size.y - gap_bottom))
		# Faint guide glow in the gap: where to aim.
		if not pipe.get("scored", false):
			draw_glow(Vector2(x, pipe.gap_center_y), pipe.gap_half * 0.6, Color(1.0, 0.9, 0.4, 0.25), 3)
		if not draw_tiled("pillar_body", top_rect, PIPE_WIDTH, Color.WHITE, Vector2(0, -gap_top)):
			draw_rect(top_rect, UiTheme.COLOR_PRIMARY_PRESSED, true)
			draw_rect(bot_rect, UiTheme.COLOR_PRIMARY_PRESSED, true)
			continue
		draw_tiled("pillar_body", bot_rect, PIPE_WIDTH)
		var cap := Vector2(PIPE_WIDTH + 10.0, CAP_H)
		draw_sprite("pillar_cap", Vector2(x, gap_top - CAP_H * 0.5), cap, Color.WHITE, 0.0, false, true)
		draw_sprite("pillar_cap", Vector2(x, gap_bottom + CAP_H * 0.5), cap)

	# Bird: flapping frames, nose follows vertical motion, blinks red when hurt.
	var bp := _bird_pos()
	var frame: String = BIRD_FRAMES[int(t * 10.0) % BIRD_FRAMES.size()]
	var tint := Color.WHITE.lerp(Color(1, 0.4, 0.4), _hurt) if fmod(t, 0.2) < 0.1 or _hurt <= 0.0 else Color.WHITE
	var sheet: String = BIRD_SHEETS[_bird_idx]
	var bf := int(t * 10.0) % 4   # up, level, down, level
	if not draw_frame(sheet, 4, 1, bf, bp, frame_size(sheet, 4, 1, BIRD_RADIUS * 2.9), tint, _bird_rot):
		var bsz := Vector2(BIRD_RADIUS * 3.4, BIRD_RADIUS * 2.55)
		if not draw_sprite(frame, bp, bsz, tint, _bird_rot):
			draw_circle(bp, BIRD_RADIUS, UiTheme.COLOR_ACCENT)

func _draw_overlay() -> void:
	if lives < 0:
		return
	var hs := 26.0
	var x0 := size.x - 14.0 - max_lives * (hs + 4.0)
	for i in max_lives:
		var c := Vector2(x0 + i * (hs + 4.0) + hs * 0.5, 22.0)
		var full := i < lives
		var beat := 1.0 + (0.08 * sin(t * 5.0) if full and lives == 1 else 0.0)
		draw_sprite("heart", c, Vector2.ONE * hs * beat, Color.WHITE if full else Color(0.2, 0.2, 0.25, 0.7))

func _draw_hills(base_y: float, amp: float, freq: float, color: Color, offset: float) -> void:
	var pts := PackedVector2Array()
	var step := 20.0
	var x := 0.0
	while x <= size.x + step:
		var u := x + offset
		pts.append(Vector2(x, base_y - amp * (0.5 + 0.35 * sin(u * freq) + 0.15 * sin(u * freq * 2.7))))
		x += step
	pts.append(Vector2(size.x + step, size.y))
	pts.append(Vector2(0, size.y))
	draw_colored_polygon(pts, color)
