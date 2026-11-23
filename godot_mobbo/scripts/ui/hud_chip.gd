class_name HudChip
extends PanelContainer
## Score / time / level readout for the game screens.
##
## The scene keeps writing to `label.text` exactly as before (e.g.
## "Score: 3"); the chip shows that as a small caption ("SCORE") over a big
## mango-yellow value ("3"), with an optional sprite icon, and pops when the
## value changes. `label` itself stays hidden -- it's the scene's handle.

var label: Label
var pop_on_change := true
var _caption: Label
var _value: Label
var _last := ""
var _tween: Tween

static func create(text: String, icon_name: String = "", pop: bool = true) -> HudChip:
	var chip := HudChip.new()
	chip.pop_on_change = pop
	chip._build(text, icon_name)
	return chip

## Icons for chips whose scene passed none, picked by caption.
const _CAPTION_ICONS := {"time": "game_ui/icon_clock", "level": "game_ui/icon_level",
	"computer": "game_ui/icon_trophy", "tilt": "game_ui/icon_level", "score": "game_ui/icon_star_gold"}

func _build(text: String, icon_name: String) -> void:
	if UiTheme.has_art("game_ui/chip_gold"):
		# Gold-rimmed game chip (generated art), nine-slice.
		add_theme_stylebox_override("panel", UiTheme.tex_box("game_ui/chip_gold", Vector4(26, 8, 30, 10)))
		custom_minimum_size = Vector2(124, 58)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiTheme.COLOR_SURFACE
		sb.border_color = UiTheme.COLOR_BORDER
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 14
		sb.content_margin_right = 16
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		add_theme_stylebox_override("panel", sb)
		custom_minimum_size = Vector2(96, 0)
	if icon_name == "":
		var cap := text.get_slice(":", 0).strip_edges().to_lower()
		icon_name = _CAPTION_ICONS.get(cap, "")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var tx := GameArena.tex(icon_name) if icon_name != "" else null
	if tx != null:
		var icon := TextureRect.new()
		icon.texture = tx
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(30, 30)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	row.add_child(col)
	_caption = Label.new()
	_caption.uppercase = true
	_caption.add_theme_font_override("font", UiTheme.font_eyebrow)
	_caption.add_theme_font_size_override("font_size", 11)
	_caption.add_theme_color_override("font_color", UiTheme.COLOR_MUTED_TEXT)
	col.add_child(_caption)
	_value = Label.new()
	_value.add_theme_font_override("font", UiTheme.font_heading)
	_value.add_theme_font_size_override("font_size", 26)
	_value.add_theme_color_override("font_color", UiTheme.COLOR_YELLOW)
	col.add_child(_value)

	label = Label.new()
	label.visible = false
	label.text = text
	col.add_child(label)
	_sync(false)

func _process(_delta: float) -> void:
	if label.text != _last:
		_sync(pop_on_change)

func _sync(animate: bool) -> void:
	_last = label.text
	var idx := _last.find(":")
	if idx >= 0:
		_caption.text = _last.left(idx)
		_value.text = _last.substr(idx + 1).strip_edges()
	else:
		_caption.text = ""
		_value.text = _last
	if animate and is_inside_tree():
		pivot_offset = size * 0.5
		if _tween != null:
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(self, "scale", Vector2(1.14, 1.14), 0.07)
		_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_value.add_theme_color_override("font_color", Color.WHITE)
		_tween.parallel().tween_callback(func(): _value.add_theme_color_override("font_color", UiTheme.COLOR_YELLOW)).set_delay(0.12)
