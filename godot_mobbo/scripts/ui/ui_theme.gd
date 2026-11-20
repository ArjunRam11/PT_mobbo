extends Node
## Autoload singleton "UiTheme". Builds one shared Theme in code (rather than
## a hand-authored .tres) so it's easy to review and adjust here directly.
##
## Design system: WCAG "accessible-and-ethical" style (healthcare/government-
## grade accessibility) rather than the softer neumorphism the design-system
## search first suggested -- this app's actual users include clinicians and
## patients (some elderly/post-amputation) in a clinical setting, where low-
## contrast soft shadows are a real risk, not just an aesthetic tradeoff.
## Palette keeps the clinical cyan/health-green hue from that search, pushed
## to meet a 7:1 text-contrast target. Touch targets are 44px+, focus rings
## are 3px and always visible, and nothing below 16px body text is used.
##
## Font: ships with Godot's built-in default font for now. Atkinson
## Hyperlegible (the accessibility-oriented pairing the search recommended)
## would be a drop-in upgrade -- add the .ttf under a fonts/ folder and wire
## it into _build_font() -- but isn't bundled since this environment can't
## fetch font files.

const COLOR_BACKGROUND := Color("f5fafb")
const COLOR_SURFACE := Color("ffffff")
const COLOR_TEXT := Color("0b2530")
const COLOR_MUTED_TEXT := Color("3f5a66")
const COLOR_BORDER := Color("a5d8e6")

const COLOR_PRIMARY := Color("0e7490")
const COLOR_PRIMARY_HOVER := Color("0b5a73")
const COLOR_PRIMARY_PRESSED := Color("084756")
const COLOR_ON_PRIMARY := Color("ffffff")

const COLOR_ACCENT := Color("047857")       # confirm / success actions
const COLOR_ACCENT_HOVER := Color("035c45")
const COLOR_ON_ACCENT := Color("ffffff")

const COLOR_DESTRUCTIVE := Color("b91c1c")  # logout / exit / destructive
const COLOR_DESTRUCTIVE_HOVER := Color("991b1b")
const COLOR_ON_DESTRUCTIVE := Color("ffffff")

const COLOR_DISABLED_BG := Color("dbe7ea")
const COLOR_DISABLED_TEXT := Color("7c8b90")

const COLOR_FOCUS_RING := Color("0e7490")

const FONT_SIZE_BASE := 18
const FONT_SIZE_SMALL := 16
const FONT_SIZE_HEADING := 30
const FONT_SIZE_SUBHEADING := 22

## Minimum touch/click target (WCAG 2.2 AA + mobile 44pt guidance).
const MIN_TOUCH_SIZE := Vector2(132, 48)
const FOCUS_RING_WIDTH := 3
const CORNER_RADIUS := 10

var theme: Theme

func _ready() -> void:
	theme = _build_theme()

func _flat_box(bg: Color, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = CORNER_RADIUS
	sb.corner_radius_top_right = CORNER_RADIUS
	sb.corner_radius_bottom_left = CORNER_RADIUS
	sb.corner_radius_bottom_right = CORNER_RADIUS
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	if border_width > 0:
		sb.border_width_left = border_width
		sb.border_width_right = border_width
		sb.border_width_top = border_width
		sb.border_width_bottom = border_width
		sb.border_color = border
	return sb

func _focus_ring_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.corner_radius_top_left = CORNER_RADIUS
	sb.corner_radius_top_right = CORNER_RADIUS
	sb.corner_radius_bottom_left = CORNER_RADIUS
	sb.corner_radius_bottom_right = CORNER_RADIUS
	sb.border_width_left = FOCUS_RING_WIDTH
	sb.border_width_right = FOCUS_RING_WIDTH
	sb.border_width_top = FOCUS_RING_WIDTH
	sb.border_width_bottom = FOCUS_RING_WIDTH
	sb.border_color = COLOR_FOCUS_RING
	sb.expand_margin_left = 2
	sb.expand_margin_right = 2
	sb.expand_margin_top = 2
	sb.expand_margin_bottom = 2
	return sb

func _style_button(t: Theme, theme_type: String, base: Color, hover: Color, pressed: Color, on_color: Color) -> void:
	t.set_stylebox("normal", theme_type, _flat_box(base))
	t.set_stylebox("hover", theme_type, _flat_box(hover))
	t.set_stylebox("pressed", theme_type, _flat_box(pressed))
	t.set_stylebox("disabled", theme_type, _flat_box(COLOR_DISABLED_BG))
	t.set_stylebox("focus", theme_type, _focus_ring_box())
	t.set_color("font_color", theme_type, on_color)
	t.set_color("font_hover_color", theme_type, on_color)
	t.set_color("font_pressed_color", theme_type, on_color)
	t.set_color("font_disabled_color", theme_type, COLOR_DISABLED_TEXT)
	t.set_color("font_focus_color", theme_type, on_color)
	t.set_font_size("font_size", theme_type, FONT_SIZE_BASE)
	t.set_constant("outline_size", theme_type, 0)

func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_SIZE_BASE

	# Primary (default) buttons -- Login/Sign Up/Submit/game entries.
	_style_button(t, "Button", COLOR_PRIMARY, COLOR_PRIMARY_HOVER, COLOR_PRIMARY_PRESSED, COLOR_ON_PRIMARY)

	# OptionButton reuses Button's visuals (OptionButton extends Button).
	_style_button(t, "OptionButton", COLOR_PRIMARY, COLOR_PRIMARY_HOVER, COLOR_PRIMARY_PRESSED, COLOR_ON_PRIMARY)

	# Labels.
	t.set_color("font_color", "Label", COLOR_TEXT)
	t.set_font_size("font_size", "Label", FONT_SIZE_BASE)

	# Panels (popups, cards).
	var panel_box := _flat_box(COLOR_SURFACE, COLOR_BORDER, 1)
	panel_box.content_margin_left = 24
	panel_box.content_margin_right = 24
	panel_box.content_margin_top = 20
	panel_box.content_margin_bottom = 20
	t.set_stylebox("panel", "PanelContainer", panel_box)

	# Text inputs.
	var input_normal := _flat_box(COLOR_SURFACE, COLOR_BORDER, 1)
	var input_focus := _flat_box(COLOR_SURFACE, COLOR_PRIMARY, FOCUS_RING_WIDTH)
	t.set_stylebox("normal", "LineEdit", input_normal)
	t.set_stylebox("focus", "LineEdit", input_focus)
	t.set_color("font_color", "LineEdit", COLOR_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", COLOR_MUTED_TEXT)
	t.set_font_size("font_size", "LineEdit", FONT_SIZE_BASE)

	# Progress bars (live weight/COP readouts).
	var pb_bg := _flat_box(COLOR_DISABLED_BG)
	pb_bg.content_margin_left = 0
	pb_bg.content_margin_right = 0
	pb_bg.content_margin_top = 0
	pb_bg.content_margin_bottom = 0
	var pb_fill := _flat_box(COLOR_PRIMARY)
	pb_fill.content_margin_left = 0
	pb_fill.content_margin_right = 0
	pb_fill.content_margin_top = 0
	pb_fill.content_margin_bottom = 0
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	t.set_color("font_color", "ProgressBar", COLOR_TEXT)
	t.set_font_size("font_size", "ProgressBar", FONT_SIZE_SMALL)

	return t

## Convenience helpers scenes call when building nodes in code, so touch
## targets and semantic color intent stay consistent without repeating
## magic numbers everywhere.

func make_primary_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = MIN_TOUCH_SIZE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

func make_accent_button(text: String) -> Button:
	var b := make_primary_button(text)
	b.add_theme_stylebox_override("normal", _flat_box(COLOR_ACCENT))
	b.add_theme_stylebox_override("hover", _flat_box(COLOR_ACCENT_HOVER))
	b.add_theme_stylebox_override("pressed", _flat_box(COLOR_ACCENT_HOVER))
	b.add_theme_stylebox_override("focus", _focus_ring_box())
	b.add_theme_color_override("font_color", COLOR_ON_ACCENT)
	b.add_theme_color_override("font_hover_color", COLOR_ON_ACCENT)
	b.add_theme_color_override("font_pressed_color", COLOR_ON_ACCENT)
	return b

func make_destructive_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = MIN_TOUCH_SIZE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", _flat_box(COLOR_DESTRUCTIVE))
	b.add_theme_stylebox_override("hover", _flat_box(COLOR_DESTRUCTIVE_HOVER))
	b.add_theme_stylebox_override("pressed", _flat_box(COLOR_DESTRUCTIVE_HOVER))
	b.add_theme_stylebox_override("focus", _focus_ring_box())
	b.add_theme_color_override("font_color", COLOR_ON_DESTRUCTIVE)
	b.add_theme_color_override("font_hover_color", COLOR_ON_DESTRUCTIVE)
	b.add_theme_color_override("font_pressed_color", COLOR_ON_DESTRUCTIVE)
	return b

## Visually subordinate to make_primary_button -- for Cancel/Back, never for
## a screen's main action (each screen should have exactly one primary CTA).
func make_secondary_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = MIN_TOUCH_SIZE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", _flat_box(COLOR_SURFACE, COLOR_BORDER, 1))
	b.add_theme_stylebox_override("hover", _flat_box(COLOR_BACKGROUND, COLOR_PRIMARY, 1))
	b.add_theme_stylebox_override("pressed", _flat_box(COLOR_BACKGROUND, COLOR_PRIMARY_PRESSED, 1))
	b.add_theme_stylebox_override("disabled", _flat_box(COLOR_DISABLED_BG))
	b.add_theme_stylebox_override("focus", _focus_ring_box())
	b.add_theme_color_override("font_color", COLOR_PRIMARY)
	b.add_theme_color_override("font_hover_color", COLOR_PRIMARY_HOVER)
	b.add_theme_color_override("font_pressed_color", COLOR_PRIMARY_PRESSED)
	b.add_theme_color_override("font_disabled_color", COLOR_DISABLED_TEXT)
	return b

func make_line_edit(placeholder: String = "") -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.custom_minimum_size = Vector2(0, 44)
	return le

func make_heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_SIZE_HEADING)
	l.add_theme_color_override("font_color", COLOR_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func make_subheading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_SIZE_SUBHEADING)
	l.add_theme_color_override("font_color", COLOR_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func make_field_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	l.add_theme_color_override("font_color", COLOR_MUTED_TEXT)
	return l

## One shared status-message convention for every scene: color never carries
## the meaning alone, the text itself is also prefixed ("Error:"/"Success:"),
## per the color-not-only accessibility rule. Use this instead of each scene
## hand-rolling its own error/success coloring.
func set_status(label: Label, message: String, kind: String = "neutral") -> void:
	match kind:
		"error":
			label.text = "Error: %s" % message
			label.add_theme_color_override("font_color", COLOR_DESTRUCTIVE)
		"success":
			label.text = "Success: %s" % message
			label.add_theme_color_override("font_color", COLOR_ACCENT)
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
