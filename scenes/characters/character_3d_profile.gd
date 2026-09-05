class_name Character3DProfile
extends Resource

@export var character_id := ""
@export var archetype := "Humanoid_Melee"
@export var model: PackedScene
@export var model_scale := 1.0
@export var visual_offset := Vector3.ZERO
@export var tile_footprint := Vector2i.ONE
@export var forward_axis := Vector3(0, 0, -1)
@export var rotation_speed := 12.0
@export var animation_speed := 1.0
@export var animations: Dictionary = {}
@export var basic_attack_variations: Array[String] = []
@export var animation_events: Dictionary = {}
@export var skill_visuals: Dictionary = {}
@export var capabilities: Dictionary = {}
@export var bone_map: Dictionary = {}
@export var socket_map: Dictionary = {}
@export var weapon: Dictionary = {}
@export var equipment: Dictionary = {}
@export var mesh_scale_overrides: Dictionary = {}
@export var required_bones: Array[String] = ["Root","Hips","Spine","Chest","Head","Hand_R","Foot_L","Foot_R"]
@export var required_animations: Array[StringName] = [&"Idle",&"Walk",&"Hit",&"Death"]
@export var outline_width := 0.008
@export var outline_color := Color(0.01,0.015,0.025,0.85)
@export var shadow_size := Vector2(0.68,0.42)
@export var shadow_opacity := 0.34
@export var low_hp_threshold := 0.25
@export var audio_profile: Dictionary = {}

func capability(name: StringName) -> bool: return bool(capabilities.get(name, false))
func animation_candidates(logical_name: StringName) -> Array:
	var value = animations.get(logical_name, [])
	return value if value is Array else [value]

func skill_id_for(item: Dictionary) -> String:
	for skill_id in skill_visuals:
		var match_data: Dictionary = skill_visuals[skill_id].get("match", {})
		var matched := not match_data.is_empty()
		for key in match_data:
			if item.get(key) != match_data[key]: matched = false; break
		if matched: return skill_id
	return ""
