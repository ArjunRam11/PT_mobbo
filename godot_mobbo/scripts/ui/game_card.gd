class_name GameCard
extends Button
## Hub tile: the generated cover art (sprites/cards/<card>.png) with the
## title written over the card's dark bottom band. Lifts and glows on hover,
## squashes on press (UiTheme button motion); disabled = dimmed + "COMING SOON".
## Falls back to a plain dark tile if the art is missing.

const ART_ASPECT := 640.0 / 357.0

var title := ""
var card_name := ""
var _tex: Texture2D
var _hover := 0.0

static func create(p_title: String, p_card: String, width: float) -> GameCard:
	var c := GameCard.new()
	c.title = p_title
	c.card_name = p_card
	c.text = ""
	c.tooltip_text = p_title
	c.custom_minimum_size = Vector2(width, width / ART_ASPECT)
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.focus_mode = Control.FOCUS_ALL
	for k in ["normal", "hover", "pressed", "disabled", "focus"]:
		c.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	return c

func _ready() -> void:
	_tex = GameArena.tex("cards/" + card_name)
	if _tex != null:
		custom_minimum_size.y = custom_minimum_size.x * _tex.get_height() / float(_tex.get_width())
	UiTheme._add_button_motion(self)

func _process(delta: float) -> void:
	var target := 1.0 if (is_hovered() or has_focus()) and not disabled else 0.0
	_hover = move_toward(_hover, target, delta * 6.0)
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if _hover > 0.0:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_corner_radius_all(int(size.y * 0.12))
		sb.shadow_color = Color(UiTheme.COLOR_YELLOW, 0.45 * _hover)
		sb.shadow_size = int(14 * _hover)
		draw_style_box(sb, r.grow(-size.y * 0.03))
	var mod := Color(1, 1, 1) if not disabled else Color(0.55, 0.55, 0.6)
	if _tex != null:
		draw_texture_rect(_tex, r, false, mod)
	else:
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color = UiTheme.COLOR_SURFACE_RAISED
		sb2.set_corner_radius_all(12)
		sb2.border_color = UiTheme.COLOR_BORDER
		sb2.set_border_width_all(1)
		draw_style_box(sb2, r)
	# Title on the art's dark bottom band.
	var fs := int(clampf(size.y * 0.11, 13, 26))
	var font := UiTheme.font_heading
	var ty := size.y * 0.86
	draw_string_outline(font, Vector2(0, ty), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 6, Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(0, ty), title, HORIZONTAL_ALIGNMENT_CENTER, size.x,
		fs, UiTheme.COLOR_TEXT if not disabled else Color(0.75, 0.75, 0.8))
	if disabled:
		var tag := "COMING SOON"
		var tfs := int(clampf(size.y * 0.07, 10, 14))
		var tw := UiTheme.font_eyebrow.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x + 18.0
		var tr := Rect2(Vector2(size.x - tw - size.x * 0.06, size.y * 0.08), Vector2(tw, tfs + 12.0))
		var sb3 := StyleBoxFlat.new()
		sb3.bg_color = Color(0, 0, 0, 0.65)
		sb3.set_corner_radius_all(8)
		draw_style_box(sb3, tr)
		draw_string(UiTheme.font_eyebrow, tr.position + Vector2(9, tfs + 4), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, UiTheme.COLOR_YELLOW)
