class_name CharacterBlobShadow
extends MeshInstance3D

@export var normal_scale := Vector3.ONE
@export var death_scale := Vector3(1.55,1.0,0.62)

func set_visual_state(state: StringName) -> void:
	var target := death_scale if state == &"Death" else normal_scale
	create_tween().tween_property(self,"scale",target,0.16)
