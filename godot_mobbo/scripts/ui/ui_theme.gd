extends Node
## Autoload singleton "UiTheme". Builds one shared Theme in code (rather than
## a hand-authored .tres) so it's easy to review and adjust here directly.
##
## Design system: "RGB on black" -- near-black background, slightly lifted
## dark cards, white text, grey captions, and three signal colours:
##   green = primary / positive / section eyebrows / Y-series
##   red   = destructive / errors / X-series
##   blue  = secondary accent
##   mango yellow = highlights: live values, totals, combined COP, focus ring
## Compact controls (34px high), 6px corners, no glow. Body text stays well
## above 7:1 contrast on the background.
##
## Fonts (SIL OFL, res://fonts/): Space Grotesk for headings and eyebrows,
## Inter for body text. Both are variable fonts; weights are picked with
## FontVariation. Falls back to system sans if the files are missing.

## -- Palette ------------------------------------------------------------------
const COLOR_BACKGROUND := Color("0b0b0d")
const COLOR_SURFACE := Color("141416")          # cards, arenas, inputs
const COLOR_SURFACE_RAISED := Color("1c1c20")   # secondary buttons, hover rows
const COLOR_TEXT := Color("f2f2f4")
const COLOR_MUTED_TEXT := Color("a1a1aa")
const COLOR_BORDER := Color("2c2c32")

const COLOR_GREEN := Color("3ddc84")
const COLOR_RED := Color("ff5a5f")
const COLOR_BLUE := Color("4c9dff")
const COLOR_YELLOW := Color("ffbe0b")        # mango yellow: live values, totals, combined COP
const COLOR_AMBER := COLOR_YELLOW               # kept for older callers

const COLOR_PRIMARY := COLOR_GREEN
const COLOR_PRIMARY_HOVER := Color("6be9a3")
const COLOR_PRIMARY_PRESSED := Color("2fb56b")
const COLOR_ON_PRIMARY := COLOR_BACKGROUND

const COLOR_ACCENT := COLOR_BLUE                # confirm / start actions
const COLOR_ACCENT_HOVER := Color("7ab6ff")
const COLOR_ON_ACCENT := COLOR_BACKGROUND

const COLOR_DESTRUCTIVE := COLOR_RED            # logout / exit / errors
const COLOR_DESTRUCTIVE_HOVER := Color("ff8589")
const COLOR_ON_DESTRUCTIVE := COLOR_BACKGROUND

const COLOR_DISABLED_BG := Color("17171a")
const COLOR_DISABLED_TEXT := Color("55555e")

const COLOR_FOCUS_RING := COLOR_YELLOW

## Four-series palette (e.g. load cells LC1-LC4).
const SERIES_COLORS := [COLOR_RED, COLOR_GREEN, COLOR_BLUE, COLOR_AMBER]

const FONT_SIZE_BASE := 16
const FONT_SIZE_SMALL := 14
const FONT_SIZE_BUTTON := 15
const FONT_SIZE_EYEBROW := 13
const FONT_SIZE_HEADING := 34
const FONT_SIZE_TITLE := 72  # app name on login/hub
const FONT_SIZE_SUBHEADING := 18

## Compact control size. Width 0 = size to the label.
const MIN_TOUCH_SIZE := Vector2(0, 34)
const FOCUS_RING_WIDTH := 2
const CORNER_RADIUS := 6

const FONT_HEADING_PATH := "res://fonts/SpaceGrotesk.ttf"
const FONT_BODY_PATH := "res://fonts/Inter.ttf"

var theme: Theme
var font_regular: Font     # Inter 400
var font_medium: Font      # Inter 600
var font_heading: Font     # Space Grotesk 500
var font_eyebrow: Font     # Space Grotesk 700, letter-spaced
## Kept for older callers; same as font_medium.
var font_bold: Font

func _ready() -> void:
	var body := _load_font(FONT_BODY_PATH)
	var display := _load_font(FONT_HEADING_PATH)
	font_regular = _variant(body, 400)
	font_medium = _variant(body, 600)
	font_bold = font_medium
	font_heading = _variant(display, 500)
	font_eyebrow = _variant(display, 700, 2)
	theme = _build_theme()

## F11 toggles fullscreen (the app starts fullscreen, see project.godot).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()

func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var f = load(path)
		if f is Font:
			return f
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Inter", "Segoe UI", "Helvetica", "Arial", "sans-serif"])
	return sys

func _variant(base: Font, weight: int, letter_spacing: int = 0) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = base
	# Axis keys must be OpenType tags (ints); "wght" as a String is ignored.
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	fv.spacing_glyph = letter_spacing
	return fv

## -- Style boxes -------------------------------------------------------------

func _flat_box(bg: Color, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(CORNER_RADIUS)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	if border_width > 0:
		sb.set_border_width_all(border_width)
		sb.border_color = border
	sb.anti_aliasing = true
	return sb

func _focus_ring_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_corner_radius_all(CORNER_RADIUS + 2)
	sb.set_border_width_all(FOCUS_RING_WIDTH)
	sb.border_color = COLOR_FOCUS_RING
	sb.expand_margin_left = 3
	sb.expand_margin_right = 3
	sb.expand_margin_top = 3
	sb.expand_margin_bottom = 3
	return sb

func _zero_margins(sb: StyleBoxFlat) -> StyleBoxFlat:
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb

## Solid button: coloured fill, dark text.
func _solid_styles(base: Color, hover: Color, pressed: Color, on_color: Color) -> Dictionary:
	return {
		"normal": _flat_box(base), "hover": _flat_box(hover), "pressed": _flat_box(pressed),
		"font_color": on_color, "font_hover_color": on_color, "font_pressed_color": on_color,
	}

## Outline button: dark fill, coloured 1px border and text.
func _outline_styles(base: Color, hover: Color) -> Dictionary:
	return {
		"normal": _flat_box(COLOR_SURFACE, Color(base, 0.55), 1),
		"hover": _flat_box(Color(base, 0.12), hover, 1),
		"pressed": _flat_box(Color(base, 0.22), hover, 1),
		"font_color": base, "font_hover_color": hover, "font_pressed_color": hover,
	}

func _apply_styles_to_theme(t: Theme, theme_type: String, s: Dictionary) -> void:
	for key in ["normal", "hover", "pressed"]:
		t.set_stylebox(key, theme_type, s[key])
	t.set_stylebox("disabled", theme_type, _flat_box(COLOR_DISABLED_BG, COLOR_BORDER, 1))
	t.set_stylebox("focus", theme_type, _focus_ring_box())
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		t.set_color(key, theme_type, s[key])
	t.set_color("font_focus_color", theme_type, s.font_color)
	t.set_color("font_hover_pressed_color", theme_type, s.font_pressed_color)
	t.set_color("font_disabled_color", theme_type, COLOR_DISABLED_TEXT)
	t.set_font("font", theme_type, font_medium)
	t.set_font_size("font_size", theme_type, FONT_SIZE_BUTTON)
	t.set_constant("outline_size", theme_type, 0)

func _apply_styles_to_button(b: Button, s: Dictionary) -> void:
	for key in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(key, s[key])
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(key, s[key])
	b.add_theme_color_override("font_focus_color", s.font_color)
	b.add_theme_color_override("font_hover_pressed_color", s.font_pressed_color)

func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_regular
	t.default_font_size = FONT_SIZE_BASE

	# Primary (default) buttons: solid green.
	_apply_styles_to_theme(t, "Button", _solid_styles(COLOR_PRIMARY, COLOR_PRIMARY_HOVER, COLOR_PRIMARY_PRESSED, COLOR_ON_PRIMARY))
	# Dropdowns / checkboxes: quiet dark controls.
	var quiet := _outline_styles(COLOR_TEXT, COLOR_TEXT)
	quiet.normal = _flat_box(COLOR_SURFACE_RAISED, COLOR_BORDER, 1)
	_apply_styles_to_theme(t, "OptionButton", quiet)
	_apply_styles_to_theme(t, "CheckBox", quiet)

	t.set_stylebox("panel", "PopupMenu", _flat_box(COLOR_SURFACE_RAISED, COLOR_BORDER, 1))
	t.set_stylebox("hover", "PopupMenu", _flat_box(Color(COLOR_PRIMARY, 0.15)))
	t.set_color("font_color", "PopupMenu", COLOR_TEXT)
	t.set_color("font_hover_color", "PopupMenu", COLOR_TEXT)
	t.set_font_size("font_size", "PopupMenu", FONT_SIZE_BUTTON)

	t.set_color("font_color", "Label", COLOR_TEXT)
	t.set_font_size("font_size", "Label", FONT_SIZE_BASE)

	# Cards: lifted dark surface, hairline border (like the chart panel).
	var card := _flat_box(COLOR_SURFACE, COLOR_BORDER, 1)
	card.content_margin_left = 20
	card.content_margin_right = 20
	card.content_margin_top = 16
	card.content_margin_bottom = 16
	t.set_stylebox("panel", "PanelContainer", card)
	t.set_stylebox("panel", "Panel", card)

	t.set_stylebox("normal", "LineEdit", _flat_box(COLOR_SURFACE, COLOR_BORDER, 1))
	t.set_stylebox("focus", "LineEdit", _flat_box(COLOR_SURFACE, COLOR_FOCUS_RING, FOCUS_RING_WIDTH))
	t.set_color("font_color", "LineEdit", COLOR_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", COLOR_MUTED_TEXT)
	t.set_color("caret_color", "LineEdit", COLOR_TEXT)
	t.set_color("selection_color", "LineEdit", Color(COLOR_BLUE, 0.35))
	t.set_font_size("font_size", "LineEdit", FONT_SIZE_BASE)

	t.set_stylebox("background", "ProgressBar", _zero_margins(_flat_box(COLOR_SURFACE_RAISED, COLOR_BORDER, 1)))
	t.set_stylebox("fill", "ProgressBar", _zero_margins(_flat_box(COLOR_PRIMARY)))
	t.set_color("font_color", "ProgressBar", COLOR_TEXT)
	t.set_font_size("font_size", "ProgressBar", FONT_SIZE_SMALL)

	t.set_stylebox("slider", "HSlider", _zero_margins(_flat_box(COLOR_SURFACE_RAISED, COLOR_BORDER, 1)))
	t.set_stylebox("grabber_area", "HSlider", _zero_margins(_flat_box(COLOR_PRIMARY)))
	t.set_stylebox("grabber_area_highlight", "HSlider", _zero_margins(_flat_box(COLOR_PRIMARY_HOVER)))
	t.set_stylebox("scroll", "VScrollBar", _zero_margins(_flat_box(Color.TRANSPARENT)))
	t.set_stylebox("grabber", "VScrollBar", _zero_margins(_flat_box(COLOR_BORDER)))
	t.set_stylebox("grabber_highlight", "VScrollBar", _zero_margins(_flat_box(COLOR_MUTED_TEXT)))
	t.set_stylebox("grabber_pressed", "VScrollBar", _zero_margins(_flat_box(COLOR_MUTED_TEXT)))
	var sep := StyleBoxLine.new()
	sep.color = COLOR_BORDER
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)

	t.set_stylebox("panel", "TooltipPanel", _flat_box(COLOR_SURFACE_RAISED, COLOR_BORDER, 1))
	t.set_color("font_color", "TooltipLabel", COLOR_TEXT)
	t.set_font_size("font_size", "TooltipLabel", FONT_SIZE_SMALL)

	return t

## -- Helpers scenes call when building nodes in code ---------------------------

## Full-screen plain black backdrop.
func make_background() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = COLOR_BACKGROUND
	return bg

func make_primary_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = MIN_TOUCH_SIZE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Size to the label instead of stretching across a VBox / screen.
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b

func make_accent_button(text: String) -> Button:
	var b := make_primary_button(text)
	_apply_styles_to_button(b, _solid_styles(COLOR_ACCENT, COLOR_ACCENT_HOVER, COLOR_ACCENT, COLOR_ON_ACCENT))
	return b

func make_destructive_button(text: String) -> Button:
	var b := make_primary_button(text)
	_apply_styles_to_button(b, _outline_styles(COLOR_DESTRUCTIVE, COLOR_DESTRUCTIVE_HOVER))
	return b

## Visually subordinate to make_primary_button -- for Cancel/Back, never for
## a screen's main action.
func make_secondary_button(text: String) -> Button:
	var b := make_primary_button(text)
	var s := _outline_styles(COLOR_TEXT, COLOR_TEXT)
	s.normal = _flat_box(COLOR_SURFACE_RAISED, COLOR_BORDER, 1)
	s.hover = _flat_box(Color("26262b"), Color("3a3a42"), 1)
	s.pressed = _flat_box(Color("2e2e34"), Color("3a3a42"), 1)
	_apply_styles_to_button(b, s)
	return b

func make_line_edit(placeholder: String = "") -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.custom_minimum_size = Vector2(0, 38)
	return le

## Small green uppercase letter-spaced label above a title or card.
func make_eyebrow(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.uppercase = true
	l.add_theme_font_override("font", font_eyebrow)
	l.add_theme_font_size_override("font_size", FONT_SIZE_EYEBROW)
	l.add_theme_color_override("font_color", COLOR_GREEN)
	return l

## Screen title: Space Grotesk, white.
func make_heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_heading)
	l.add_theme_font_size_override("font_size", FONT_SIZE_HEADING)
	l.add_theme_color_override("font_color", COLOR_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## App title block for login/hub: big "MoBBo" with "Modular Balance Board"
## under it.
func make_app_title() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var name_label := make_heading("MoBBo")
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	box.add_child(name_label)
	var sub := make_heading("Modular Balance Board")
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", COLOR_YELLOW)
	box.add_child(sub)
	return box

## Card titles / live readouts: Space Grotesk, white.
func make_subheading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_heading)
	l.add_theme_font_size_override("font_size", FONT_SIZE_SUBHEADING)
	l.add_theme_color_override("font_color", COLOR_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## Big live number in mango yellow (timers, totals).
func make_value_label(text: String) -> Label:
	var l := make_heading(text)
	l.add_theme_color_override("font_color", COLOR_YELLOW)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l

## Small grey caption.
func make_field_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	l.add_theme_color_override("font_color", COLOR_MUTED_TEXT)
	return l

## One shared status-message convention for every scene: colour never carries
## the meaning alone, the text itself is also prefixed ("Error:"/"Success:").
func set_status(label: Label, message: String, kind: String = "neutral") -> void:
	match kind:
		"error":
			label.text = "Error: %s" % message
			label.add_theme_color_override("font_color", COLOR_DESTRUCTIVE)
		"success":
			label.text = "Success: %s" % message
			label.add_theme_color_override("font_color", COLOR_GREEN)
		_:
			label.text = message
			label.add_theme_color_override("font_color", COLOR_MUTED_TEXT)

func make_muted_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	l.add_theme_color_override("font_color", COLOR_MUTED_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
