class_name CombatFeelManager
extends Node

const DURATIONS := {&"light":0.055,&"medium":0.075,&"heavy":0.095,&"critical":0.115,&"death":0.08}

func local_hit_stop(player: AnimationPlayer, profile: StringName, speed_scale := 1.0) -> void:
	if player == null: return
	var previous := player.speed_scale
	player.speed_scale = 0.0
	get_tree().create_timer(DURATIONS.get(profile,0.055),true,false,true).timeout.connect(func():
		if is_instance_valid(player): player.speed_scale = previous * speed_scale)

func camera_impulse(camera: Camera3D, profile: StringName) -> void:
	if camera == null: return
	var strength: float = {&"light":0.035,&"medium":0.055,&"heavy":0.075,&"critical":0.09,&"death":0.06}.get(profile,0.0)
	var origin := camera.position
	var tween := camera.create_tween(); tween.tween_property(camera,"position",origin+Vector3(strength,-strength*0.5,0),0.04)
	tween.tween_property(camera,"position",origin,0.08)
