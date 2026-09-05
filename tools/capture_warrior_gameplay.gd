extends Node

const MAIN := preload("res://scenes/Main.tscn")
const OUTPUT := "res://artifacts/warrior_polish"
var _token: UnitToken

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var main = MAIN.instantiate()
	main.warrior_ab_test = true
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	# Entra diretamente numa batalha PVP reproduzível, sem alterar o fluxo do
	# jogo de produção nem depender das telas de splash/seleção.
	for child in main.get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer >= 100: child.queue_free()
	await get_tree().process_frame
	main._active_pvp_battle = {"heroes":["guerreiro"], "monsters":["goblin"]}
	if main._hud_layer == null: main._build_hud()
	main._start_new_game()
	for _frame in 20: await get_tree().process_frame
	if main.battle_presentation != null and main.battle_presentation.is_blocking_input():
		main.battle_presentation.skip()
	await get_tree().create_timer(0.6).timeout
	var token: UnitToken = _find_warrior_token(main) as UnitToken
	if token == null:
		push_error("Warrior gameplay token not found")
		get_tree().quit(1)
		return
	_token = token
	var warrior: CharacterVisual3D = token.warrior_3d_visual()
	warrior.vfx_enabled = false
	warrior.camera_impulse_enabled = false
	warrior.attack_variations_enabled = false
	for facing_name in ["north", "east", "south", "west"]:
		var facing_direction: Dictionary = {
			"north": Vector3(0, 0, -1), "east": Vector3(1, 0, 0),
			"south": Vector3(0, 0, 1), "west": Vector3(-1, 0, 0),
		}
		warrior.face_direction(facing_direction[facing_name], false)
		await _capture("world_ui_" + facing_name, 0.12)
	await _capture("idle", 0.20)
	warrior.play_walk(); await _capture("walk_contact", 0.02); await _capture("walk_passing", 0.22)
	warrior.play_idle(); await _capture("walk_end_idle", 0.18)
	warrior.play_basic_attack(warrior.global_position + Vector3(0, 0, -1), "MISS")
	await _capture("attack_miss_preparation", 0.12); await _capture("attack_miss_impact", 0.22); await _capture("attack_miss_finish", 0.16); await _capture("attack_miss_recovery", 0.18)
	await get_tree().create_timer(0.35).timeout
	warrior.play_basic_attack(warrior.global_position + Vector3(0, 0, -1), "HIT")
	await _capture("attack_hit_preparation", 0.12); await _capture("attack_hit_impact", 0.22); await _capture("attack_hit_finish", 0.17); await _capture("attack_hit_recovery", 0.20)
	await get_tree().create_timer(0.40).timeout
	warrior.play_skill_visual("defend", "HIT")
	await _capture("skill_defend_preparation", 0.18); await _capture("skill_defend_finish", 0.22); await _capture("skill_defend_recovery", 0.35)
	await get_tree().create_timer(0.35).timeout
	warrior.play_hit(); await _capture("hit_reaction", 0.17); await _capture("hit_recovery", 0.28)
	await get_tree().create_timer(0.30).timeout
	warrior.play_death(); await _capture("death_collapse", 0.70); await _capture("death_contact", 0.75); await _capture("death_final", 0.45)
	print("WARRIOR_GAMEPLAY_CAPTURES=", ProjectSettings.globalize_path(OUTPUT))
	get_tree().quit()

func _find_warrior_token(node: Node):
	if node is UnitToken and String(node.unit.get("spriteKey", "")) == "guerreiro" and node.is_using_warrior_3d(): return node
	for child in node.get_children():
		var found = _find_warrior_token(child)
		if found != null: return found
	return null

func _capture(label: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [OUTPUT, label])
	if _token != null and is_instance_valid(_token._warrior_viewport):
		var model_image := _token._warrior_viewport.get_texture().get_image()
		if model_image != null: model_image.save_png("%s/%s_model.png" % [OUTPUT, label])
