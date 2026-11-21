class_name GameArena
extends Control
## Shared, purely cosmetic layer for the minigame arenas (CoinArena,
## FlappyArena, PongArena, TiltArena): an animation clock, particle bursts,
## floating "+1" texts, screen shake, a colour flash, a centred banner card
## (start / game-over) and a blinking REC dot while data is being recorded.
##
## Nothing here feeds back into game state or the recorded data: the game
## scene still owns all logic and only *tells* the arena about events
## (fx_* calls) so it can animate them. Positions are this Control's local px,
## same as set_state(). Subclasses draw their world in _draw_game() and,
## optionally, fixed overlays (hearts etc.) in _draw_overlay().
##
## Sprites are SVGs in res://sprites/ (see tex()); if one is missing the
## arenas fall back to plain shapes so a game never breaks over art.

const SPRITE_DIR := "res://sprites/"

var t := 0.0              ## seconds since the arena entered the tree
var recording := false    ## set by the scene: shows the REC indicator

var _rng := RandomNumberGenerator.new()  # own RNG: never disturbs the game's randf()
var _particles: Array = []
var _anims: Array = []      # one-shot sprite-sheet animations (explosions)
var _floaters: Array = []
var _shake := 0.0
var _shake_offset := Vector2.ZERO
var _flash := 0.0
var _flash_color := Color.WHITE
var _banner_title := ""
var _banner_sub := ""
var _banner_alpha := 0.0
var _banner_target := 0.0
var _banner_badge := ""        # "", "bronze", "silver", "gold"
var _banner_shown_t := 0.0
var _confetti: Array = []      # confetti bursts drawn over the banner
var _xf := Transform2D.IDENTITY

static var _tex_cache := {}

## Loads res://sprites/<name>.png if present, else <name>.svg -- so dropping
## in a PNG (e.g. generated art) replaces the hand-made SVG of the same name.
static func tex(sprite_name: String) -> Texture2D:
	if not _tex_cache.has(sprite_name):
		var found: Texture2D = null
		for ext in [".png", ".svg"]:
			var path: String = SPRITE_DIR + sprite_name + ext
			if ResourceLoader.exists(path):
				found = load(path)
				break
		_tex_cache[sprite_name] = found
	return _tex_cache[sprite_name]

func _ready() -> void:
	_rng.randomize()
	clip_contents = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # for draw_tiled()

func _process(delta: float) -> void:
	t += delta
	for p in _particles:
		p.life -= delta
		p.vel.y += p.gravity * delta
		p.vel *= maxf(0.0, 1.0 - p.drag * delta)
		p.pos += p.vel * delta
	_particles = _particles.filter(func(p): return p.life > 0.0)
	for f in _floaters:
		f.life -= delta
		f.pos.y -= 46.0 * delta
	_floaters = _floaters.filter(func(f): return f.life > 0.0)
	for c in _confetti:
		c.age += delta
	_confetti = _confetti.filter(func(c): return c.age < 1.6)
	for an in _anims:
		an.age += delta
	_anims = _anims.filter(func(an): return an.age < an.duration)
	_shake = maxf(0.0, _shake - delta * 2.2)
	_shake_offset = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 12.0 * _shake * _shake
	_flash = maxf(0.0, _flash - delta * 2.4)
	_banner_alpha = move_toward(_banner_alpha, _banner_target, delta * 4.0)
	queue_redraw()

# -- Effects API (called by the game scenes) ----------------------------------

func burst(pos: Vector2, color: Color, count: int = 12, speed: float = 180.0,
		gravity: float = 260.0, radius: float = 4.0, life: float = 0.7) -> void:
	for i in count:
		var ang := _rng.randf_range(0.0, TAU)
		var spd := _rng.randf_range(0.35, 1.0) * speed
		var l := _rng.randf_range(0.6, 1.0) * life
		_particles.append({
			"pos": pos, "vel": Vector2(cos(ang), sin(ang)) * spd, "life": l, "max_life": l,
			"color": color, "radius": _rng.randf_range(0.6, 1.0) * radius,
			"gravity": gravity, "drag": 1.5,
		})

## Sprite-sheet sparkles (sprites/<sheet>.png, 8 frames in a row) that pop
## and fade where they land. Falls back to dots if the sheet is missing.
func sparkle_burst(pos: Vector2, count: int = 8, spread: float = 70.0, sheet: String = "sparkle_sheet",
		px: float = 34.0, life: float = 0.6) -> void:
	if tex(sheet) == null:
		burst(pos, UiTheme.COLOR_YELLOW, count, spread * 2.5, 0.0, 3.0, life)
		return
	for i in count:
		var ang := _rng.randf_range(0.0, TAU)
		var l := _rng.randf_range(0.7, 1.0) * life
		_particles.append({
			"pos": pos + Vector2(cos(ang), sin(ang)) * _rng.randf_range(4.0, spread * 0.3),
			"vel": Vector2(cos(ang), sin(ang)) * _rng.randf_range(0.4, 1.0) * spread * 1.6,
			"life": l, "max_life": l, "color": Color.WHITE, "radius": px * _rng.randf_range(0.6, 1.1),
			"gravity": 0.0, "drag": 3.0, "sheet": sheet,
		})

## One-shot sheet animation, e.g. play_anim("explosion_sheet", 4, 3, pos, 150, 0.8).
func play_anim(sheet: String, cols: int, rows: int, pos: Vector2, px: float, duration: float) -> bool:
	if tex(sheet) == null:
		return false
	_anims.append({"sheet": sheet, "cols": cols, "rows": rows, "pos": pos, "px": px, "duration": duration, "age": 0.0})
	return true

func float_text(pos: Vector2, text: String, color: Color = UiTheme.COLOR_YELLOW, font_size: int = 26) -> void:
	_floaters.append({"pos": pos, "text": text, "color": color, "life": 0.9, "max_life": 0.9, "size": font_size})

func shake(amount: float = 1.0) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 1.2)

func flash(color: Color, amount: float = 1.0) -> void:
	_flash_color = color
	_flash = maxf(_flash, amount)

## badge: "" / "bronze" / "silver" / "gold" -- a result medal on the panel,
## with a confetti burst (game-over / win screens).
func show_banner(title: String, subtitle: String = "", badge: String = "") -> void:
	_banner_title = title
	_banner_sub = subtitle
	_banner_target = 1.0
	_banner_badge = badge
	_banner_shown_t = t
	if badge != "" and tex("game_ui/confetti_sheet") != null:
		for k in 2:
			_confetti.append({"pos": Vector2(size.x * (0.27 + 0.46 * k), size.y * 0.42), "age": -0.3 * k})

func hide_banner() -> void:
	_banner_target = 0.0

# -- Drawing --------------------------------------------------------------------

func _draw() -> void:
	set_xf(Transform2D(0.0, _shake_offset))
	_draw_game()
	_draw_particles()
	set_xf(Transform2D.IDENTITY)
	_draw_overlay()
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(_flash_color, _flash * 0.3), true)
	if recording:
		_draw_rec()
	_draw_banner()
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.COLOR_BORDER, false, 2.0)

## Override: the game world (shaken with the screen).
func _draw_game() -> void:
	pass

## Override: fixed HUD drawn over the world (not shaken).
func _draw_overlay() -> void:
	pass

func _draw_particles() -> void:
	for an in _anims:
		var n: int = an.cols * an.rows
		var f := mini(int(an.age / an.duration * n), n - 1)
		draw_frame(an.sheet, an.cols, an.rows, f, an.pos, Vector2.ONE * an.px)
	for p in _particles:
		var k: float = p.life / p.max_life
		if p.has("sheet"):
			# play the 8-frame sparkle once over the particle's life
			var f := clampi(int((1.0 - k) * 8.0), 0, 7)
			draw_frame(p.sheet, 8, 1, f, p.pos, Vector2.ONE * p.radius, Color(1, 1, 1, minf(1.0, k * 2.0)))
			continue
		draw_circle(p.pos, maxf(0.5, p.radius * (0.4 + 0.6 * k)), Color(p.color, k))
	var font := UiTheme.font_heading
	for f in _floaters:
		var k: float = f.life / f.max_life
		var w := 200.0
		var pos: Vector2 = f.pos - Vector2(w * 0.5, 0)
		draw_string_outline(font, pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, w, f.size, 6, Color(0, 0, 0, 0.6 * k))
		draw_string(font, pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, w, f.size, Color(f.color, k))

func _draw_rec() -> void:
	var on := fmod(t, 1.0) < 0.6
	var c := Vector2(20, 20)
	draw_rect(Rect2(Vector2(8, 8), Vector2(66, 24)), Color(0, 0, 0, 0.45), true)
	draw_circle(c, 6.0, Color(UiTheme.COLOR_RED, 1.0 if on else 0.3))
	draw_string(UiTheme.font_eyebrow, Vector2(32, 26), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.COLOR_TEXT)

func _draw_banner() -> void:
	if _banner_alpha <= 0.01:
		return
	var a := _banner_alpha
	var ea := ease(a, 0.4)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45 * a), true)
	var textured := UiTheme.has_art("game_ui/panel_ribbon")
	var badge_tex := tex("game_ui/badge_" + _banner_badge) if _banner_badge != "" else null
	var w := minf(size.x - 40.0, 600.0 if badge_tex != null else 540.0)
	var h := (210.0 if _banner_sub != "" else 170.0) if textured else (150.0 if _banner_sub != "" else 104.0)
	h = minf(h, size.y - 16.0)
	var pop := 0.9 + 0.1 * _ease_back(clampf((t - _banner_shown_t) / 0.45, 0.0, 1.0))
	var c := size * 0.5 + Vector2(0, (1.0 - ea) * 24.0)
	var r := Rect2(c - Vector2(w, h) * 0.5 * pop, Vector2(w, h) * pop)
	# Confetti bursts behind the panel, so the text stays readable.
	for cf in _confetti:
		if cf.age >= 0.0:
			var f := clampi(int(cf.age / 1.6 * 8.0), 0, 7)
			draw_frame("game_ui/confetti_sheet", 8, 1, f, cf.pos, Vector2.ONE * size.y * 0.75, Color(1, 1, 1, a))
	if textured:
		# Wooden ribbon panel (generated art); the ribbon sits on the top edge.
		var sb_t := UiTheme.tex_box("game_ui/panel_ribbon")
		sb_t.modulate_color = Color(1, 1, 1, a)
		draw_style_box(sb_t, r)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(UiTheme.COLOR_SURFACE, 0.94 * a)
		sb.border_color = Color(UiTheme.COLOR_YELLOW, 0.8 * a)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(16)
		sb.shadow_color = Color(0, 0, 0, 0.5 * a)
		sb.shadow_size = 18
		draw_style_box(sb, r)
	# Text area (right of the badge when there is one).
	var tx0 := r.position.x
	var tw := r.size.x
	if badge_tex != null:
		var bh := r.size.y * 0.62
		var bw := bh * badge_tex.get_width() / float(badge_tex.get_height())
		var wob := sin((t - _banner_shown_t) * 3.0) * 0.06 * exp(-(t - _banner_shown_t) * 1.2)
		var bc := Vector2(r.position.x + r.size.x * 0.06 + bw * 0.5 + 20.0, r.position.y + r.size.y * 0.58)
		draw_set_transform(bc, wob, Vector2.ONE)
		draw_texture_rect(badge_tex, Rect2(Vector2(-bw, -bh) * 0.5, Vector2(bw, bh)), false, Color(1, 1, 1, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		tx0 = bc.x + bw * 0.5 + 10.0
		tw = r.end.x - tx0 - 24.0
	var mid_y := r.position.y + r.size.y * (0.56 if textured else 0.5)
	var title_y := mid_y + (-6.0 if _banner_sub != "" else 14.0)
	var tfs := 40 if tw > 380.0 else 32
	draw_string_outline(UiTheme.font_heading, Vector2(tx0, title_y), _banner_title,
		HORIZONTAL_ALIGNMENT_CENTER, tw, tfs, 8, Color(0, 0, 0, 0.5 * a))
	draw_string(UiTheme.font_heading, Vector2(tx0, title_y), _banner_title,
		HORIZONTAL_ALIGNMENT_CENTER, tw, tfs, Color(UiTheme.COLOR_TEXT, a))
	if _banner_sub != "":
		var pulse := 0.75 + 0.25 * sin(t * 3.0)
		draw_string(UiTheme.font_medium, Vector2(tx0, title_y + 38.0), _banner_sub,
			HORIZONTAL_ALIGNMENT_CENTER, tw, 19, Color(UiTheme.COLOR_YELLOW, a * pulse))

func _ease_back(x: float) -> float:
	var c1 := 1.7
	return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)

# -- Drawing helpers for subclasses --------------------------------------------

## Sets the base transform that draw_sprite() composes with.
func set_xf(xf: Transform2D) -> void:
	_xf = xf
	draw_set_transform_matrix(xf)

## Draws a sprite centred at `center`, `sz` px, optionally rotated / mirrored.
## Returns false (and draws nothing) when the sprite file is missing.
func draw_sprite(sprite_name: String, center: Vector2, sz: Vector2, modulate_color: Color = Color.WHITE,
		rot: float = 0.0, flip_x: bool = false, flip_y: bool = false) -> bool:
	var tx := tex(sprite_name)
	if tx == null:
		return false
	var s := Vector2(-1.0 if flip_x else 1.0, -1.0 if flip_y else 1.0)
	draw_set_transform_matrix(_xf * Transform2D(rot, s, 0.0, center))
	draw_texture_rect(tx, Rect2(-sz * 0.5, sz), false, modulate_color)
	draw_set_transform_matrix(_xf)
	return true

## Fills `rect` by repeating a sprite, scaled so one tile is `tile_w` px wide.
func draw_tiled(sprite_name: String, rect: Rect2, tile_w: float, modulate_color: Color = Color.WHITE,
		scroll: Vector2 = Vector2.ZERO) -> bool:
	var tx := tex(sprite_name)
	if tx == null:
		return false
	var k := tx.get_width() / tile_w
	draw_texture_rect_region(tx, rect, Rect2(scroll * k, rect.size * k), modulate_color)
	return true

## One frame of a sprite sheet (cols x rows grid, index row-major), centred.
func draw_frame(sheet: String, cols: int, rows: int, index: int, center: Vector2, sz: Vector2,
		modulate_color: Color = Color.WHITE, rot: float = 0.0, flip_x: bool = false) -> bool:
	var tx := tex(sheet)
	if tx == null:
		return false
	var fw := tx.get_width() / float(cols)
	var fh := tx.get_height() / float(rows)
	var src := Rect2((index % cols) * fw, (index / cols) * fh, fw, fh)
	draw_set_transform_matrix(_xf * Transform2D(rot, Vector2(-1.0 if flip_x else 1.0, 1.0), 0.0, center))
	draw_texture_rect_region(tx, Rect2(-sz * 0.5, sz), src, modulate_color)
	draw_set_transform_matrix(_xf)
	return true

## Size of one frame of a sheet scaled so its height is `h` (keeps aspect).
func frame_size(sheet: String, cols: int, rows: int, h: float) -> Vector2:
	var tx := tex(sheet)
	if tx == null:
		return Vector2(h, h)
	var fw := tx.get_width() / float(cols)
	var fh := tx.get_height() / float(rows)
	return Vector2(h * fw / fh, h)

## Full-bleed backdrop image: cover the arena (aspect fill, centred).
## stretch = true fills exactly instead (for images whose edges matter, e.g. a court).
func draw_cover(name: String, stretch: bool = false) -> bool:
	var tx := tex(name)
	if tx == null:
		return false
	if stretch:
		draw_texture_rect(tx, Rect2(Vector2.ZERO, size), false)
		return true
	var isz := tx.get_size()
	var k := maxf(size.x / isz.x, size.y / isz.y)
	var dsz := isz * k
	draw_texture_rect(tx, Rect2((size - dsz) * 0.5, dsz), false)
	return true

## Horizontal band (hills, grass) whose bottom sits at `bottom`, `h` px
## tall, repeated across the width and scrolled left by `scroll` px.
func draw_band(name: String, bottom: float, h: float, scroll: float = 0.0, modulate_color: Color = Color.WHITE) -> bool:
	var tx := tex(name)
	if tx == null:
		return false
	var w := h * tx.get_width() / float(tx.get_height())
	var x := -fposmod(scroll, w)
	while x < size.x:
		draw_texture_rect(tx, Rect2(Vector2(x, bottom - h), Vector2(w + 1.0, h)), false, modulate_color)
		x += w
	return true

func draw_vgradient(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))

## Soft round glow (concentric translucent circles).
func draw_glow(center: Vector2, radius: float, color: Color, rings: int = 5) -> void:
	for i in rings:
		var k := 1.0 - float(i) / rings
		draw_circle(center, radius * (0.4 + 0.6 * k), Color(color, color.a * 0.18))
