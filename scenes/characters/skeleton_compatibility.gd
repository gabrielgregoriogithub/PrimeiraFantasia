class_name SkeletonCompatibility
extends RefCounted

static func validate(skeleton: Skeleton3D, profile: Character3DProfile) -> Dictionary:
	var missing_required: Array[String] = []
	var missing_optional: Array[String] = []
	for bone in profile.required_bones:
		if skeleton == null or skeleton.find_bone(bone) < 0: missing_required.append(bone)
	for socket in profile.socket_map.values():
		if skeleton == null or skeleton.find_bone(String(socket)) < 0: missing_optional.append(String(socket))
	return {"valid":missing_required.is_empty(),"missing_required":missing_required,"missing_optional":missing_optional}
