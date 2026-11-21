extends Node
## Debug aid: prints which sway-sheet frame RigPhotoShowcase picks over time.
##   Godot --headless --path . res://tests/sway_frame_probe.tscn
func _ready() -> void:
	var s := RigPhotoShowcase.new()
	add_child(s)
	for i in 70:
		s._process(0.1)
		print("t=%.1f cop_y=%+.1f lean=%+.2f frame=%d (frame lean %+.2f)" % [s.t, s.cop.y, s._lean_norm, s._frame + 1, s.SWAY_LEAN[s._frame]])
	get_tree().quit()
