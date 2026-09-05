extends SceneTree

const MODEL := preload("res://assets/characters/warrior/warrior_animated_v4.glb")
const ACTIONS := [
	"Idle_A", "Walk", "Attack_Light_A", "Attack_Light_B", "Attack_Light_C",
	"Attack_Heavy", "Block", "Hit", "Hit_Front", "Hit_Left", "Hit_Right",
	"Hit_Heavy", "Death", "Skill_Defend"
]

func _initialize() -> void:
	var model := MODEL.instantiate()
	root.add_child(model)
	await process_frame
	var player := _find_type(model, "AnimationPlayer") as AnimationPlayer
	var skeleton := _find_type(model, "Skeleton3D") as Skeleton3D
	print("=== WARRIOR ASSET AUDIT ===")
	print("model_transform=", model.transform)
	print("skeleton=", skeleton.get_path(), " transform=", skeleton.transform, " bones=", skeleton.get_bone_count())
	var bounds := _model_bounds(model)
	print("model_aabb_min=", bounds.position, " max=", bounds.end, " lowest_y=", bounds.position.y)
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		print("mesh=", mesh_instance.name, " path=", mesh_instance.get_path(), " aabb=", mesh_instance.get_aabb())
	for bone_name in ["Root", "Hips", "Foot_L", "Foot_R", "WeaponSocket_R"]:
		var index := skeleton.find_bone(bone_name)
		print("bone_rest ", bone_name, " index=", index, " rest=", skeleton.get_bone_global_rest(index) if index >= 0 else Transform3D.IDENTITY)
	for action_name in ACTIONS:
		var actual := _find_animation(player, action_name)
		if actual == &"":
			print(action_name, ": MISSING")
			continue
		var animation := player.get_animation(actual)
		print("-- ", action_name, " actual=", actual, " length=", animation.length, " loop=", animation.loop_mode)
		for track_index in animation.get_track_count():
			var path := String(animation.track_get_path(track_index))
			if path.contains("Root") or path.contains("Hips"):
				var first = animation.track_get_key_value(track_index, 0) if animation.track_get_key_count(track_index) > 0 else null
				var last = animation.track_get_key_value(track_index, animation.track_get_key_count(track_index) - 1) if animation.track_get_key_count(track_index) > 0 else null
				print("  track=", path, " keys=", animation.track_get_key_count(track_index), " first=", first, " last=", last)
		for ratio in [0.0, 0.25, 0.5, 0.75, 1.0]:
			player.play(actual)
			player.seek(animation.length * ratio, true)
			skeleton.force_update_all_bone_transforms()
			var left := skeleton.get_bone_global_pose(skeleton.find_bone("Foot_L")).origin.y
			var right := skeleton.get_bone_global_pose(skeleton.find_bone("Foot_R")).origin.y
			print("  sample=%.2f foot_l=%.5f foot_r=%.5f" % [ratio, left, right])
	print("=== END WARRIOR ASSET AUDIT ===")
	quit()

func _find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name): return node
	for child in node.get_children():
		var found := _find_type(child, type_name)
		if found != null: return found
	return null

func _find_animation(player: AnimationPlayer, wanted: String) -> StringName:
	for actual in player.get_animation_list():
		if String(actual).get_file().to_lower() == wanted.to_lower(): return actual
	return &""

func _model_bounds(model: Node3D) -> AABB:
	var result := AABB()
	var has_bounds := false
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var local := model.global_transform.affine_inverse() * mesh_instance.global_transform
		var transformed := local * mesh_instance.get_aabb()
		result = result.merge(transformed) if has_bounds else transformed
		has_bounds = true
	return result
