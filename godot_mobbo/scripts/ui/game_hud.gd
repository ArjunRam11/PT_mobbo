class_name GameHud
extends RefCounted
## Shared layout for the minigame screens, so every game looks the same:
##
##   [ title / hint ]                         [chip] [chip] [chip]
##   [                  arena (fills)                            ]
##   [ status text ]                          [buttons ...       ]
##
## Pure layout: the scene still creates its own labels/buttons/arena and
## keeps every connection; this only decides where they sit.

## Builds the skeleton under `host` (and starts `music`, faded out again when
## the screen closes) and returns
## {"chips": HBoxContainer, "arena_slot": VBoxContainer,
##  "status": VBoxContainer, "buttons": HBoxContainer}.
static func build(host: Control, title: String, hint: String, music: String = "", eyebrow: String = "MoBBo game") -> Dictionary:
	host.theme = UiTheme.theme
	var bg := UiTheme.make_background()
	bg.color = UiTheme.COLOR_BACKGROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 20)
	host.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# Top bar: title block left, stat chips right.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_box)
	title_box.add_child(UiTheme.make_eyebrow(eyebrow))
	var heading := UiTheme.make_heading(title)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_box.add_child(heading)
	var hint_label := UiTheme.make_muted_label(hint)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(hint_label)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 10)
	chips.alignment = BoxContainer.ALIGNMENT_END
	chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(chips)

	var arena_slot := VBoxContainer.new()
	arena_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(arena_slot)

	# Bottom bar: status messages left, buttons right.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)
	var status := VBoxContainer.new()
	status.add_theme_constant_override("separation", 2)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(status)
	bottom.add_child(UiTheme.make_sound_toggles(true))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	bottom.add_child(buttons)
	# Every button the scene adds here gets the chunky game style + game icon.
	buttons.child_entered_tree.connect(func(n: Node):
		if n is Button:
			UiTheme.style_game_button(n))

	if music != "":
		Sfx.play_music(music)
		host.tree_exiting.connect(Sfx.stop_music)

	return {"chips": chips, "arena_slot": arena_slot, "status": status, "buttons": buttons}

## A left-aligned status line for the bottom bar (works with UiTheme.set_status).
static func make_status_label(big: bool = false) -> Label:
	var l := UiTheme.make_subheading("") if big else UiTheme.make_muted_label("")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
