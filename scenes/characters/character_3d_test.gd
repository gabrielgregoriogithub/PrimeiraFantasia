extends Node3D

@export var profile: Character3DProfile
@onready var visual: CharacterVisual3D = $CharacterVisual3D
var animation_names: Array[StringName] = []
var animation_index := 0

func _ready() -> void:
	visual.profile = profile
	await get_tree().process_frame
	visual.validate_profile()
	animation_names.assign(visual._resolved_actions.keys())
	animation_names.sort()
	print("Character3DTest: Left/Right choose animation, Space plays; 1/5/10/20 spawns are available through final validator.")

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or animation_names.is_empty(): return
	if event.keycode == KEY_LEFT: animation_index=posmod(animation_index-1,animation_names.size())
	elif event.keycode == KEY_RIGHT: animation_index=posmod(animation_index+1,animation_names.size())
	elif event.keycode == KEY_SPACE: visual._travel(animation_names[animation_index], animation_names[animation_index] not in [&"Idle",&"Walk",&"Run"])
	print("Animation: ",animation_names[animation_index])
