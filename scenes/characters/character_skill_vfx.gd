class_name CharacterSkillVFX
extends Node3D

func play(profile: String, position: Vector3, result := "HIT") -> void:
	if result == "MISS" and profile not in ["throw", "whirlwind"]: return
	var mesh := MeshInstance3D.new()
	var shape := SphereMesh.new(); shape.radius = 0.13 if profile != "whirlwind" else 0.42; shape.height = shape.radius * 2.0
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_color = Color(0.92,0.85,0.58,0.72 if result != "MISS" else 0.25)
	shape.material = mat; mesh.mesh = shape; mesh.global_position = position; add_child(mesh)
	var tween := mesh.create_tween(); tween.tween_property(mesh,"scale",Vector3.ONE*(3.2 if profile=="whirlwind" else 1.8),0.18)
	tween.parallel().tween_property(mat,"albedo_color:a",0.0,0.18); tween.tween_callback(mesh.queue_free)

func clear_all() -> void:
	for child in get_children(): child.queue_free()
