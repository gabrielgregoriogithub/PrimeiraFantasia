extends Node3D

const OUTPUT = "res://assets/characters/warrior_v3/previews/godot_static/"
var visual: Node3D
var skeleton: Skeleton3D
var poses: Dictionary
var equipment_nodes: Array[Node3D] = []
var grip_poses: Dictionary = {}
var current_pose_name: String = "REST_TPOSE"

func _ready() -> void:
	visual = Node3D.new()
	visual.name = "VisualRoot"
	add_child(visual)
	var document = GLTFDocument.new()
	var state = GLTFState.new()
	var rig_path = "res://assets/characters/warrior_v3/rigged/Warrior_V3_RIGGED.glb"
	if not "--capture-v3" in OS.get_cmdline_user_args() and FileAccess.file_exists("res://assets/characters/warrior_v3/rigged/Warrior_V3_RIGGED_EQUIPPABLE.glb"):
		rig_path = "res://assets/characters/warrior_v3/rigged/Warrior_V3_RIGGED_EQUIPPABLE.glb"
	var error = document.append_from_file(rig_path,state)
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
	if "--capture-equipment" in OS.get_cmdline_user_args():
		attach_equipment()
		await capture_equipment()
		get_tree().quit()
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
	current_pose_name = pose_name
	skeleton.reset_bone_poses()
	var axes = {"X":Vector3.RIGHT,"Y":Vector3.FORWARD,"Z":Vector3.UP}
	var changes = poses[pose_name].duplicate(true)
	if not equipment_nodes.is_empty():
		for bone_name in grip_poses: changes[bone_name.trim_prefix("mixamorig:")] = grip_poses[bone_name]
		changes["LeftHand"] = ["Y",-60.0]
		if pose_name == "COMBAT_STANCE": changes["LeftForeArm"] = ["X",95.0]
	for suffix in changes:
		var id = skeleton.find_bone("mixamorig:"+suffix)
		if id < 0: id = skeleton.find_bone("mixamorig_"+suffix)
		if id < 0: push_error("Missing bone "+suffix); continue
		var entry = changes[suffix]
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
		KEY_7:
			if equipment_nodes.is_empty():
				attach_equipment()
				set_pose(current_pose_name)
			else:
				for node in equipment_nodes: node.visible = not node.visible

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

func attach_equipment() -> void:
	var socket_audit = {}
	grip_poses = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/warrior_v3/rigged/work/GRIP_POSE.json"))
	var configs = [
		["RightHand","WeaponSocket_R","WarriorSword",Basis(Vector3(0,0,1),Vector3(1,0,0),Vector3(0,1,0)),Vector3(0.034,0.699,0.409)],
		["LeftHand","OffhandSocket_L","WarriorShield",Basis(Vector3(1,0,0),Vector3(0,0,1),Vector3(0,-1,0)),Vector3(0.0,0.699,-0.409)]
	]
	for config in configs:
		var id = skeleton.find_bone("mixamorig:"+config[0])
		if id < 0: id = skeleton.find_bone("mixamorig_"+config[0])
		var attachment = BoneAttachment3D.new()
		attachment.name = config[0]+"Attachment"
		skeleton.add_child(attachment)
		attachment.bone_idx = id
		var socket = Node3D.new()
		socket.name = config[1]
		attachment.add_child(socket)
		var desired = Transform3D(config[3],config[4])
		socket.transform = (skeleton.global_transform * skeleton.get_bone_global_rest(id)).affine_inverse() * visual.global_transform * desired
		socket_audit[config[1]] = {"bone":skeleton.get_bone_name(id),"bone_index":id,"local_transform":str(socket.transform),"rest_model_transform":str(desired),"asset":config[2]+".glb","skinned":false}
		var doc = GLTFDocument.new()
		var state = GLTFState.new()
		var result = doc.append_from_file("res://assets/characters/warrior_v3/equipment/"+config[2]+".glb",state)
		if result != OK: push_error("Equipment load failed"); continue
		var equipment = doc.generate_scene(state)
		socket.add_child(equipment)
		equipment_nodes.append(equipment)
	var audit_file = FileAccess.open("res://assets/characters/warrior_v3/equipment/work/SOCKET_CONFIG.json",FileAccess.WRITE)
	if audit_file: audit_file.store_string(JSON.stringify(socket_audit,"\t"))

func capture_equipment() -> void:
	var output = "res://assets/characters/warrior_v3/previews/godot_equipment/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var shots = {"north_equipped":[0,"REST_TPOSE"],"east_equipped":[1,"REST_TPOSE"],"south_equipped":[2,"REST_TPOSE"],"west_equipped":[3,"REST_TPOSE"],"combat_stance_equipped":[2,"COMBAT_STANCE"],"right_arm_forward":[2,"RIGHT_ARM_FORWARD"],"left_arm_forward":[2,"LEFT_ARM_FORWARD"],"isometric_equipped":[2,"COMBAT_STANCE"],"both_arms_down":[2,"BOTH_ARMS_DOWN"],"torso_twist_left":[2,"TORSO_TWIST_LEFT"],"torso_twist_right":[2,"TORSO_TWIST_RIGHT"]}
	for label in shots:
		set_direction(shots[label][0])
		set_pose(shots[label][1])
		for frame in range(6): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output+label+".png")
		print(label," shield_normal_model=",visual.global_basis.inverse()*equipment_nodes[1].global_basis.z)
	print("V3_EQUIPMENT_CAPTURE_COMPLETE")
