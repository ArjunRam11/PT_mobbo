class_name AnimatedBackdrop
extends Control
## The moving layer inside UiTheme.make_background(), so every screen gets
## it for free: three soft colour glows (green / blue / mango) drifting
## slowly, a faint dot grid, and a few rising motes. Kept dim and slow on
## purpose -- it's a clinical tool, the background must never compete with
## the live data or the game.
##
## It also plays the screen's entrance animation once: the scene content
## (the background's siblings) fades/slides in, and the first row/column of
## items in it (buttons, cards) staggers in one after another.

const GLOWS := [
	{"color": Color(0.24, 0.86, 0.52, 0.10), "r": 0.55, "speed": Vector2(0.050, 0.037), "phase": 0.0},
	{"color": Color(0.30, 0.62, 1.00, 0.10), "r": 0.60, "speed": Vector2(0.031, 0.047), "phase": 2.1},
	{"color": Color(1.00, 0.75, 0.04, 0.06), "r": 0.45, "speed": Vector2(0.043, 0.029), "phase": 4.2},
]
const MOTES := 26
const GRID_STEP := 36.0

var t := 0.0
## Optional photo backdrop (e.g. sprites/bg_main.png), drawn under everything
## with a very slow drift/zoom; the procedural glows are toned down over it.
var image: Texture2D
var _glow_tex: GradientTexture2D
var _motes: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 0.35))
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = g
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 256
	_glow_tex.height = 256
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in MOTES:
		_motes.append({"x": rng.randf(), "y": rng.randf(), "s": rng.randf_range(0.6, 1.0),
			"v": rng.randf_range(0.008, 0.025), "ph": rng.randf() * TAU})
	_play_entrance.call_deferred()

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var dim := maxf(size.x, size.y)
	var glow_k := 1.0
	if image != null:
		# Cover the screen (aspect fill) with 8% headroom for the slow pan.
		var isz := image.get_size()
		var cover := maxf(size.x / isz.x, size.y / isz.y) * (1.08 + 0.02 * sin(t * 0.05))
		var dsz := isz * cover
		var pan := Vector2(sin(t * 0.031), cos(t * 0.023)) * (dsz - size) * 0.45
		draw_texture_rect(image, Rect2((size - dsz) * 0.5 + pan, dsz), false, Color(1, 1, 1, 0.95))
		glow_k = 0.45
	# Drifting glows.
	for g in GLOWS:
		var c := Vector2(
			0.5 + 0.38 * sin(t * g.speed.x * TAU + g.phase),
			0.5 + 0.36 * cos(t * g.speed.y * TAU + g.phase * 1.3)) * size
		var r: float = dim * g.r
		draw_texture_rect(_glow_tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(g.color, g.color.a * glow_k))
	# Dot grid, very faint, drifting diagonally.
	var off := Vector2(fmod(t * 4.0, GRID_STEP), fmod(t * 2.5, GRID_STEP))
	var dot := Color(1, 1, 1, 0.045)
	var y := -GRID_STEP + off.y
	while y < size.y + GRID_STEP:
		var x := -GRID_STEP + off.x
		while x < size.x + GRID_STEP:
			draw_rect(Rect2(Vector2(x, y), Vector2(2, 2)), dot, true)
			x += GRID_STEP
		y += GRID_STEP
	# Rising motes.
	for m in _motes:
		var my := fposmod(m.y - t * m.v, 1.0)
		var mx: float = m.x + 0.01 * sin(t * 0.7 + m.ph)
		var a: float = 0.10 * m.s * sin(my * PI)  # fade at top and bottom
		draw_circle(Vector2(mx, my) * size, 1.5 + 1.5 * m.s, Color(1, 1, 1, a))

# -- Entrance animation ----------------------------------------------------------

func _play_entrance() -> void:
	var bg := get_parent()
	if bg == null or bg.get_parent() == null:
		return
	var staggered := false
	for node in bg.get_parent().get_children():
		if node == bg or not (node is Control):
			continue
		var c := node as Control
		UiTheme.fade_in(c, 0.0, 18.0)
		if not staggered:
			var group := _find_stagger_group(c, 0)
			if group != null:
				var i := 0
				for child in group.get_children():
					if child is Control and child.visible:
						UiTheme.fade_in(child, 0.08 + 0.045 * i, 0.0)
						i += 1
				staggered = true

## First container (breadth-first, a few levels deep) holding 3+ visible
## controls -- usually the screen's main column or button grid.
func _find_stagger_group(root: Node, depth: int) -> Node:
	var queue: Array = [root]
	var levels := 0
	while not queue.is_empty() and levels < 5:
		var next: Array = []
		for n in queue:
			if n is Container and not (n is ScrollContainer):
				var count := 0
				for ch in n.get_children():
					if ch is Control and ch.visible:
						count += 1
				if count >= 3:
					return n
			for ch in n.get_children():
				next.append(ch)
		queue = next
		levels += 1
	return null
