class_name CharacterSelectionVisual
extends MeshInstance3D

var _pulse: Tween
func set_selected(value: bool) -> void:
	visible=value
	if _pulse != null: _pulse.kill()
	if value:
		_pulse=create_tween().set_loops(); _pulse.tween_property(self,"scale",Vector3.ONE*1.07,0.5); _pulse.tween_property(self,"scale",Vector3.ONE,0.5)

func set_hovered(value: bool) -> void: scale=Vector3.ONE*(1.08 if value else 1.0)
