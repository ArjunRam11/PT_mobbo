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
	t.set_stylebox("disabled", theme_type, s.get("disabled", _flat_box(COLOR_DISABLED_BG, COLOR_BORDER, 1)))
	t.set_stylebox("focus", theme_type, _focus_ring_box())
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		t.set_color(key, theme_type, s[key])
	t.set_color("font_focus_color", theme_type, s.font_color)
	t.set_color("font_hover_pressed_color", theme_type, s.font_pressed_color)
	t.set_color("font_disabled_color", theme_type, COLOR_DISABLED_TEXT)
	# Icons follow the text colour (white line icons get tinted to match).
	t.set_color("icon_normal_color", theme_type, s.font_color)
	t.set_color("icon_hover_color", theme_type, s.font_hover_color)
	t.set_color("icon_pressed_color", theme_type, s.font_pressed_color)
	t.set_color("icon_focus_color", theme_type, s.font_color)
	t.set_color("icon_hover_pressed_color", theme_type, s.font_pressed_color)
	t.set_color("icon_disabled_color", theme_type, COLOR_DISABLED_TEXT)
	t.set_font("font", theme_type, font_medium)
	t.set_font_size("font_size", theme_type, FONT_SIZE_BUTTON)
	t.set_constant("outline_size", theme_type, 0)

func _apply_styles_to_button(b: Button, s: Dictionary) -> void:
	for key in ["normal", "hover", "pressed", "disabled"]:
		if s.has(key):
			b.add_theme_stylebox_override(key, s[key])
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(key, s[key])
	b.add_theme_color_override("font_focus_color", s.font_color)
	b.add_theme_color_override("font_hover_pressed_color", s.font_pressed_color)
	b.add_theme_color_override("icon_normal_color", s.font_color)
	b.add_theme_color_override("icon_hover_color", s.font_hover_color)
	b.add_theme_color_override("icon_pressed_color", s.font_pressed_color)
	b.add_theme_color_override("icon_focus_color", s.font_color)
	b.add_theme_color_override("icon_hover_pressed_color", s.font_pressed_color)

## -- Generated art (sprites/ui, sprites/game_ui + UiArtMeta) -------------------
## Buttons, cards and fields use the generated textures as nine-slice styles
## when present; every helper falls back to the flat look when they're not.

func has_art(key: String) -> bool:
	return UiArtMeta.DATA.has(key) and GameArena.tex(key) != null

## Nine-slice StyleBoxTexture. `content` = text padding (left, top, right, bottom).
func tex_box(key: String, content: Vector4 = Vector4(16, 6, 16, 6)) -> StyleBoxTexture:
	var m: Dictionary = UiArtMeta.DATA[key]
	var sb := StyleBoxTexture.new()
	sb.texture = GameArena.tex(key)
	sb.texture_margin_left = m.margin[0]
	sb.texture_margin_top = m.margin[1]
	sb.texture_margin_right = m.margin[2]
	sb.texture_margin_bottom = m.margin[3]
	sb.expand_margin_left = m.expand[0]
	sb.expand_margin_top = m.expand[1]
	sb.expand_margin_right = m.expand[2]
	sb.expand_margin_bottom = m.expand[3]
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb

## {} when the art for `prefix` (e.g. "ui/btn_accent") isn't there.
func _tex_button_styles(prefix: String, on_color: Color, hover_color: Color = Color(0, 0, 0, 0),
		content: Vector4 = Vector4(16, 6, 16, 6)) -> Dictionary:
	if not has_art(prefix + "_normal"):
		return {}
	var hc := on_color if hover_color.a == 0.0 else hover_color
	var s := {
		"normal": tex_box(prefix + "_normal", content), "hover": tex_box(prefix + "_hover", content),
		"pressed": tex_box(prefix + "_pressed", content),
		"font_color": on_color, "font_hover_color": hc, "font_pressed_color": hc,
	}
	if has_art(prefix + "_disabled"):
		s["disabled"] = tex_box(prefix + "_disabled", content)
	return s

## Line icon for a button, picked from its label (first match wins).
const _ICON_RULES := [
	["log out", "logout"], ["logout", "logout"], ["log in", "login"], ["login", "login"],
	["sign up", "signup"], ["exit", "power"], ["back", "back"], ["auto connect", "usb"],
	["disconnect", "plug"], ["connect", "plug"], ["diagnostic", "diagnostics"], ["refresh", "refresh"],
	["restart", "refresh"], ["start rec", "record"], ["stop", "stop"], ["start", "play"],
	["save", "save"], ["level up", "level_up"], ["level down", "level_down"],
	["sound", "sound_on"], ["music", "music_on"], ["analysis", "chart"], ["report", "report"],
	["live", "assessment"], ["browse", "folder"], ["capture", "target"], ["trial", "timer"],
]

func _auto_icon(b: Button) -> void:
	var low := b.text.to_lower()
	for r in _ICON_RULES:
		if low.contains(r[0]):
			var tx := GameArena.tex("ui/icon_" + r[1])
			if tx != null:
				b.icon = tx
			return

## Game-screen buttons: chunky glossy pills (sprites/game_ui/btn_<colour>_*),
## white bold label, full-colour game icon. colour "" = from the button's
## variant (accent/primary -> green, secondary -> blue, danger -> red).
const _GAME_ICON_RULES := [
	["restart", "restart"], ["start rec", "play"], ["start", "play"], ["stop", "pause"],
	["back", "home"], ["sound", "sound_on"], ["music", "music"], ["level", "level"],
]

func style_game_button(b: Button, colour: String = "") -> void:
	if colour == "":
		colour = {"accent": "green", "primary": "green", "secondary": "blue", "danger": "red"}.get(b.get_meta("variant", "primary"), "blue")
	var s := _tex_button_styles("game_ui/btn_" + colour, Color.WHITE, Color.WHITE, Vector4(22, 6, 24, 10))
	if s.is_empty():
		return
	_apply_styles_to_button(b, s)
	for key in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(key, Color.WHITE)
	b.add_theme_font_override("font", font_heading)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_constant_override("icon_max_width", 26)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 54.0)
	var low := b.text.to_lower()
	for r in _GAME_ICON_RULES:
		if low.contains(r[0]):
			var tx := GameArena.tex("game_ui/icon_" + r[1])
			if tx != null:
				b.icon = tx
			break

func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_regular
	t.default_font_size = FONT_SIZE_BASE

	# Primary (default) buttons: green (textured when the art is present).
	var prim := _tex_button_styles("ui/btn_primary", COLOR_ON_PRIMARY)
	_apply_styles_to_theme(t, "Button", prim if not prim.is_empty() else _solid_styles(COLOR_PRIMARY, COLOR_PRIMARY_HOVER, COLOR_PRIMARY_PRESSED, COLOR_ON_PRIMARY))
	t.set_constant("icon_max_width", "Button", 18)
	t.set_constant("h_separation", "Button", 8)
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
	var card: StyleBox
	if has_art("ui/card_plain"):
		card = tex_box("ui/card_plain", Vector4(20, 16, 20, 16))
	else:
		card = _flat_box(COLOR_SURFACE, COLOR_BORDER, 1)
		card.content_margin_left = 20
		card.content_margin_right = 20
		card.content_margin_top = 16
		card.content_margin_bottom = 16
	t.set_stylebox("panel", "PanelContainer", card)
	t.set_stylebox("panel", "Panel", card)

	if has_art("ui/field_normal"):
		t.set_stylebox("normal", "LineEdit", tex_box("ui/field_normal", Vector4(12, 6, 12, 6)))
		t.set_stylebox("focus", "LineEdit", tex_box("ui/field_focus", Vector4(12, 6, 12, 6)))
	else:
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

	t.set_stylebox("panel", "ItemList", _flat_box(COLOR_BACKGROUND, COLOR_BORDER, 1))
	t.set_stylebox("focus", "ItemList", _flat_box(Color.TRANSPARENT))
	t.set_stylebox("selected", "ItemList", _flat_box(Color(COLOR_YELLOW, 0.18)))
	t.set_stylebox("selected_focus", "ItemList", _flat_box(Color(COLOR_YELLOW, 0.18), COLOR_YELLOW, 1))
	t.set_stylebox("hovered", "ItemList", _flat_box(COLOR_SURFACE_RAISED))
	t.set_stylebox("cursor", "ItemList", _flat_box(Color.TRANSPARENT))
	t.set_stylebox("cursor_unfocused", "ItemList", _flat_box(Color.TRANSPARENT))
	t.set_color("font_color", "ItemList", COLOR_MUTED_TEXT)
	t.set_color("font_hovered_color", "ItemList", COLOR_TEXT)
	t.set_color("font_selected_color", "ItemList", COLOR_YELLOW)
	t.set_constant("v_separation", "ItemList", 6)

	t.set_stylebox("panel", "TooltipPanel", _flat_box(COLOR_SURFACE_RAISED, COLOR_BORDER, 1))
	t.set_color("font_color", "TooltipLabel", COLOR_TEXT)
	t.set_font_size("font_size", "TooltipLabel", FONT_SIZE_SMALL)

	return t

## -- Helpers scenes call when building nodes in code ---------------------------

## Full-screen near-black backdrop with the slow animated layer
## (AnimatedBackdrop: drifting glows, dot grid, motes) and the screen's
## entrance animation. Callers still set color/anchors as before.
## image_name: optional sprite (res://sprites/<name>.png) used as a photo
## backdrop under the animated layer, e.g. "bg_main" on the main screen.
func make_background(image_name: String = "") -> ColorRect:
	var bg := ColorRect.new()
	bg.color = COLOR_BACKGROUND
	var fx := AnimatedBackdrop.new()
	if image_name != "":
		fx.image = GameArena.tex(image_name)
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fx)
	return bg

## -- Motion helpers ---------------------------------------------------------------

## Fade a control in (and slide it up by `slide` px if it isn't laid out by
## a container -- containers would overwrite the position).
func fade_in(c: Control, delay: float = 0.0, slide: float = 0.0, time: float = 0.4) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, time).set_delay(delay)
	if slide != 0.0 and not (c.get_parent() is Container):
		var target := c.position
		c.position = target + Vector2(0, slide)
		tw.parallel().tween_property(c, "position", target, time + 0.1).set_delay(delay)

## Show a control with a small scale pop (for panels that toggle visible).
func pop_in(c: Control) -> void:
	c.visible = true
	c.pivot_offset = c.size * 0.5
	c.modulate.a = 0.0
	c.scale = Vector2(0.96, 0.96)
	var tw := c.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.22)
	tw.tween_property(c, "scale", Vector2.ONE, 0.3)

func _tween_scale(b: Control, s: float) -> void:
	if b is BaseButton and b.disabled and s > 1.0:
		return
	b.pivot_offset = b.size * 0.5
	var old: Tween = b.get_meta("_scale_tween") if b.has_meta("_scale_tween") else null
	if old != null and old.is_valid():
		old.kill()
	var tw := b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2(s, s), 0.14)
	b.set_meta("_scale_tween", tw)

## Hover lift, press squash, click sound -- applied to every themed button.
func _add_button_motion(b: Button) -> void:
	b.mouse_entered.connect(func(): _tween_scale(b, 1.04))
	b.mouse_exited.connect(func(): _tween_scale(b, 1.0))
	b.button_down.connect(func(): _tween_scale(b, 0.95))
	b.button_up.connect(func(): _tween_scale(b, 1.04 if b.is_hovered() else 1.0))
	b.pressed.connect(func(): Sfx.play("ui_click", -2.0))

## "Sound: On" / "Music: On" toggle buttons (state lives in Sfx).
## game = true: chunky game-style buttons with the colourful game icons.
func make_sound_toggles(game: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var sound_btn := make_secondary_button("Sound")
	var music_btn := make_secondary_button("Music")
	if game:
		style_game_button(sound_btn, "blue")
		style_game_button(music_btn, "blue")
	sound_btn.tooltip_text = "All sounds on/off (M key)"
	music_btn.tooltip_text = "Background music on/off"
	var set_icon := func(b: Button, ui_name: String, game_name: String):
		var tx := GameArena.tex(("game_ui/icon_" + game_name) if game else ("ui/icon_" + ui_name))
		if tx != null:
			b.icon = tx
	var refresh := func():
		sound_btn.text = "Sound: %s" % ("On" if Sfx.sound_on else "Off")
		music_btn.text = "Music: %s" % ("On" if Sfx.music_on else "Off")
		music_btn.disabled = not Sfx.sound_on
		set_icon.call(sound_btn, "sound_on" if Sfx.sound_on else "sound_off", "sound_on" if Sfx.sound_on else "sound_off")
		set_icon.call(music_btn, "music_on" if Sfx.music_on else "music_off", "music")
	refresh.call()
	sound_btn.pressed.connect(func(): Sfx.set_sound_on(not Sfx.sound_on))
	music_btn.pressed.connect(func(): Sfx.set_music_on(not Sfx.music_on))
	Sfx.settings_changed.connect(refresh)
	# Disconnect when the buttons go away (Sfx outlives every scene).
	row.tree_exiting.connect(func():
		if Sfx.settings_changed.is_connected(refresh):
			Sfx.settings_changed.disconnect(refresh))
	row.add_child(sound_btn)
	row.add_child(music_btn)
	return row

func make_primary_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = MIN_TOUCH_SIZE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Size to the label instead of stretching across a VBox / screen.
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.set_meta("variant", "primary")
	_add_button_motion(b)
	_auto_icon(b)
	return b

func make_accent_button(text: String) -> Button:
	var b := make_primary_button(text)
	var s := _tex_button_styles("ui/btn_accent", COLOR_ON_ACCENT)
	_apply_styles_to_button(b, s if not s.is_empty() else _solid_styles(COLOR_ACCENT, COLOR_ACCENT_HOVER, COLOR_ACCENT, COLOR_ON_ACCENT))
	b.set_meta("variant", "accent")
	return b

func make_destructive_button(text: String) -> Button:
	var b := make_primary_button(text)
	var s := _tex_button_styles("ui/btn_danger", COLOR_DESTRUCTIVE, COLOR_DESTRUCTIVE_HOVER)
	_apply_styles_to_button(b, s if not s.is_empty() else _outline_styles(COLOR_DESTRUCTIVE, COLOR_DESTRUCTIVE_HOVER))
	b.set_meta("variant", "danger")
	return b

## Visually subordinate to make_primary_button -- for Cancel/Back, never for
## a screen's main action.
func make_secondary_button(text: String) -> Button:
	var b := make_primary_button(text)
	var s := _outline_styles(COLOR_TEXT, COLOR_TEXT)
	s.normal = _flat_box(COLOR_SURFACE_RAISED, COLOR_BORDER, 1)
	s.hover = _flat_box(Color("26262b"), Color("3a3a42"), 1)
	s.pressed = _flat_box(Color("2e2e34"), Color("3a3a42"), 1)
	var ts := _tex_button_styles("ui/btn_secondary", COLOR_TEXT)
	_apply_styles_to_button(b, ts if not ts.is_empty() else s)
	b.set_meta("variant", "secondary")
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

## App title block for login/hub: the animated logo (MobboLogo: mark +
## wordmark) when the logo art is present, else big "MoBBo" text with
## "Modular Balance Board" under it.
func make_app_title(logo_height: float = 190.0) -> Control:
	if MobboLogo.available():
		var logo := MobboLogo.new()
		logo.custom_minimum_size = Vector2(logo_height * 3.15, logo_height)
		logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		return logo
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
