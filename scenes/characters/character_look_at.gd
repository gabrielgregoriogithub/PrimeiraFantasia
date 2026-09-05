class_name CharacterLookAt
extends RefCounted

var enabled := true
var yaw_limit := deg_to_rad(35.0)
var pitch_limit := deg_to_rad(15.0)

func compatible(skeleton: Skeleton3D, profile: Character3DProfile) -> bool:
	return enabled and skeleton != null and skeleton.find_bone(profile.bone_map.get("head","Head")) >= 0

func clamped_angles(local_direction: Vector3) -> Vector2:
	var yaw := clampf(atan2(-local_direction.x,-local_direction.z),-yaw_limit,yaw_limit)
	var pitch := clampf(atan2(local_direction.y,Vector2(local_direction.x,local_direction.z).length()),-pitch_limit,pitch_limit)
	return Vector2(yaw,pitch)
