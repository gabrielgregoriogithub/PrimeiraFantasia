extends Node3D

const OUTPUT = "res://assets/characters/warrior_v3/previews/godot_static/"
var visual: Node3D
var skeleton: Skeleton3D
var poses: Dictionary

func _ready() -> void:
	visual = Node3D.new()
	visual.name = "VisualRoot"
	add_child(visual)
	var document = GLTFDocument.new()
	var state = GLTFState.new()
	var error = document.append_from_file("res://assets/characters/warrior_v3/rigged/Warrior_V3_RIGGED.glb",state)
	if error != OK:
		push_error("Cannot load approved rig GLB: "+str(error))
		get_tree().quit(1)
		return
	var model = document.generate_scene(state)
	visual.add_child(model)
	model.scale = Vector3.ONE
	skeleton = find_skeleton(model)
	poses = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/warrior_v3/rigged/work/TEST_POSES.json"))
	# Copy the production character camera and lighting, without gameplay scripts.
	var reference = load("res://scenes/characters/CharacterVisual3D.tscn").instantiate()
	for child_name in ["PreviewCamera", "KeyLight", "FillLight"]:
		var source = reference.get_node(child_name)
		var copy = source.duplicate()
		add_child(copy)
		if copy is Camera3D:
			copy.current = true
			copy.environment = copy.environment.duplicate()
			copy.environment.background_color = Color(0.19,0.21,0.19)
	reference.free()
	var ground = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(6,6)
	ground.mesh = plane
	ground.position.y = -0.005
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25,0.30,0.19)
	mat.roughness = 1.0
	ground.material_override = mat
	add_child(ground)
	set_direction(3)
	set_pose("REST_TPOSE")
	if "--capture-v3" in OS.get_cmdline_user_args():
		await capture_all()
		get_tree().quit()

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var result = find_skeleton(child)
		if result != null: return result
	return null

func set_direction(index: int) -> void:
	# Imported GLB faces +X. Rotate only VisualRoot.
	visual.rotation.y = [PI/2.0,0.0,-PI/2.0,PI][index]

func set_pose(pose_name: String) -> void:
	skeleton.reset_bone_poses()
	var axes = {"X":Vector3.RIGHT,"Y":Vector3.FORWARD,"Z":Vector3.UP}
	for suffix in poses[pose_name]:
		var id = skeleton.find_bone("mixamorig:"+suffix)
		if id < 0: id = skeleton.find_bone("mixamorig_"+suffix)
		if id < 0: push_error("Missing bone "+suffix); continue
		var entry = poses[pose_name][suffix]
		var model_axis = visual.global_basis.inverse() * skeleton.global_basis
		var axis = (model_axis * skeleton.get_bone_global_rest(id).basis).inverse() * axes[entry[0]]
		var rest_rotation = skeleton.get_bone_rest(id).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(id, rest_rotation * Quaternion(axis.normalized(),deg_to_rad(entry[1])))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_1: set_direction(0)
		KEY_2: set_direction(1)
		KEY_3: set_direction(2)
		KEY_4: set_direction(3)
		KEY_5: set_pose("REST_TPOSE")
		KEY_6: set_pose("COMBAT_STANCE")

func capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var names = ["north","east","south","west","isometric"]
	for i in range(5):
		set_direction(i if i < 4 else 2)
		set_pose("REST_TPOSE" if i < 4 else "COMBAT_STANCE")
		for frame in range(6): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUTPUT+names[i]+".png")
	print("V3_STATIC_CAPTURE_COMPLETE bones=",skeleton.get_bone_count())
