extends Node3D

@onready var warrior: Warrior3DVisual = $Warrior3D
@onready var dummy: MeshInstance3D = $TargetDummy

var _movement_running := false


func _ready() -> void:
	warrior.attack_impact.connect(_on_attack_impact)
	print("Warrior3DTest: 1 Idle, 2 Walk path, 3 Light, 4 Heavy, 5 Block, 6 Hit, 7 Death, 8 Victory")
	warrior.validate_identity_and_skills()
	print("Skills: P=PowerAttack, T=ThrowSword, G=Whirlwind, D=Defend; Shift simulates CRITICAL")


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_1: warrior.play_idle()
		KEY_2: _test_path()
		KEY_3: _attack(false)
		KEY_4: _attack(true)
		KEY_5: warrior.play_block()
		KEY_6: warrior.play_hit()
		KEY_7: warrior.play_death()
		KEY_8: warrior.play_victory()
		KEY_P: warrior.play_skill_visual("powerAttack", "CRITICAL" if event.shift_pressed else "HIT")
		KEY_T: warrior.play_skill_visual("throwSword", "CRITICAL" if event.shift_pressed else "HIT", dummy.global_position)
		KEY_G: warrior.play_skill_visual("spinAttack", "CRITICAL" if event.shift_pressed else "HIT")
		KEY_D: warrior.play_skill_visual("defend")
		KEY_9: warrior.debug_slash()
		KEY_0: warrior.debug_hit()
		KEY_F1: warrior.toggle_toon()
		KEY_F2: warrior.toggle_outline()
		KEY_F3: warrior.toggle_shadow()
		KEY_F4: warrior.toggle_vfx()


func _attack(heavy: bool) -> void:
	warrior.face_world_position(dummy.global_position)
	if heavy: warrior.play_attack_heavy()
	else: warrior.play_attack_light()


func _on_attack_impact() -> void:
	print("ATTACK IMPACT")
	var tween := create_tween()
	tween.tween_property(dummy, "scale", Vector3(1.2, 0.72, 1.2), 0.07)
	tween.tween_property(dummy, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK)


func _test_path() -> void:
	if _movement_running or warrior.is_dead: return
	_movement_running = true
	warrior.play_walk()
	var path := [Vector3(-1.5, 0, 0), Vector3(-1.5, 0, -1.5), Vector3(0, 0, -1.5), Vector3.ZERO]
	var tween := create_tween()
	for point in path:
		tween.tween_callback(warrior.face_world_position.bind(point, true))
		tween.tween_property(warrior, "position", point, 0.65).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func():
		warrior.play_idle()
		warrior.movement_animation_finished.emit()
		_movement_running = false
	)
