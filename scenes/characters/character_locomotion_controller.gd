class_name CharacterLocomotionController
extends RefCounted

static func target_yaw(direction: Vector3, forward_offset := 0.0) -> float:
	direction.y = 0.0
	return forward_offset if direction.length_squared() < 0.00001 else atan2(-direction.x,-direction.z)+forward_offset

static func step_yaw(current: float, target: float, speed: float, delta: float) -> float:
	return lerp_angle(current,target,clampf(speed*delta,0.0,1.0))

static func movement_animation(profile: Character3DProfile, running: bool) -> StringName:
	if running and profile.capability(&"run"): return &"Run"
	return &"Walk"
