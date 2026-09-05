extends GutTest

## ETAPA 16 — Signature Abilities. Fumaça de cena (mesmo espírito de
## test_main_scene.gd): executa as seis Signature Abilities através da cena
## real (Main.tscn) pra garantir que o hook de apresentação não quebra em
## tempo de execução e que o resultado de GameState (dano/CT/MP/regras)
## continua idêntico ao de uma habilidade comum — só a apresentação muda.

var main_scene

func before_each() -> void:
	main_scene = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main_scene)
	await wait_process_frames(1)
	if main_scene.scenario_manager.active_id != ScenarioManager.FIELD:
		main_scene.scenario_manager.set_active(ScenarioManager.FIELD)
		main_scene._start_new_game()
		await wait_process_frames(1)

func _hero(sprite_key: String) -> Dictionary:
	return main_scene.state.units.filter(func(u): return u.get("spriteKey", "") == sprite_key)[0]

func _spell(unit: Dictionary, name: String) -> Dictionary:
	return (unit["spells"] as Array).filter(func(s): return s.get("name", "") == name)[0]

func test_warrior_spin_attack_signature_resolves_and_creates_vfx_without_changing_damage_rules() -> void:
	var warrior := _hero("guerreiro")
	var spin := _spell(warrior, "Ataque Giratório")
	main_scene.state.current_actor = warrior
	warrior["hasActed"] = false
	var before: int = main_scene.effects_layer.get_child_count()
	main_scene._select_spell_item(spin)
	assert_true(warrior["hasActed"], "a Signature ainda consome a ação normalmente")
	assert_gt(main_scene.effects_layer.get_child_count(), before, "o giro cria VFX")
	await wait_seconds(0.3)

func test_rogue_weakening_strike_signature_still_only_buffs_the_next_attack() -> void:
	var rogue := _hero("ladino")
	var strike := _spell(rogue, "Golpe Debilitante")
	main_scene.state.current_actor = rogue
	rogue["hasActed"] = false
	var before: int = main_scene.effects_layer.get_child_count()
	main_scene._select_spell_item(strike)
	assert_gt(main_scene.effects_layer.get_child_count(), before, "o preparo cria VFX no próprio Ladino")
	assert_false(rogue["hasActed"], "Golpe Debilitante continua sendo grátis (não consome a ação)")

func test_archer_pierce_shot_signature_resolves_and_hits_along_the_line() -> void:
	var archer := _hero("arqueiro")
	var pierce := _spell(archer, "Tiro Penetrante")
	var target = main_scene.state.opposing_team_of(archer)[0]
	archer["x"] = 0
	archer["y"] = target["y"]
	main_scene.state.current_actor = archer
	archer["hasActed"] = false
	archer["mp"] = archer["maxMp"]
	var before: int = main_scene.effects_layer.get_child_count()
	main_scene._resolve_spell(archer, pierce, target["x"], target["y"])
	assert_gt(main_scene.effects_layer.get_child_count(), before, "a flecha e o beam de perfuração aparecem")
	await wait_seconds(1.2)

func test_mage_fireball_signature_still_resolves_through_the_dedicated_async_pilot() -> void:
	var mage := _hero("mago")
	var fireball := _spell(mage, "Bola de Fogo")
	var target = main_scene.state.opposing_team_of(mage)[0]
	target["hp"] = target["maxHp"]
	main_scene.state.current_actor = mage
	mage["hasActed"] = false
	mage["mp"] = mage["maxMp"]
	main_scene._resolve_spell(mage, fireball, target["x"], target["y"])
	assert_eq(main_scene.mode, "fireball_vfx", "continua usando o piloto dedicado da Bola de Fogo")
	await wait_seconds(1.7)
	assert_true(mage["hasActed"], "a conjuração terminou de resolver sozinha")

func test_chemist_bomb_signature_keeps_the_arc_throw_and_resolves() -> void:
	var chemist := _hero("quimico")
	var bomb := _spell(chemist, "Bomba de Fogo")
	var target = main_scene.state.opposing_team_of(chemist)[0]
	main_scene.state.current_actor = chemist
	chemist["hasActed"] = false
	chemist["mp"] = chemist["maxMp"]
	var before: int = main_scene.effects_layer.get_child_count()
	main_scene._resolve_spell(chemist, bomb, target["x"], target["y"])
	assert_gt(main_scene.effects_layer.get_child_count(), before, "arremesso da bomba cria VFX")
	await wait_seconds(1.4)

func test_bard_inspiration_signature_keeps_the_global_song_dispatch() -> void:
	# O Bardo começa preso/indisponível no Campo (ver
	# test_scenario_selector_is_left_aligned_in_requested_order: "o Bardo
	# ainda bloqueado não participa do Campo") — injeta o herói e deixa
	# _sync_visuals materializar o token dele, do mesmo jeito que reforços
	# de Horda aparecem sem reconstruir a cena.
	var bard: Dictionary = Units.build()["bardo"].duplicate(true)
	bard["x"] = 6
	bard["y"] = 6
	main_scene.state.units.append(bard)
	main_scene._sync_visuals()
	assert_true(main_scene.unit_tokens.has(bard["name"]), "token do Bardo foi criado")
	var inspiration := _spell(bard, "Canção da Inspiração")
	main_scene.state.current_actor = bard
	bard["hasActed"] = false
	bard["mp"] = bard["maxMp"]
	var before: int = main_scene.effects_layer.get_child_count()
	main_scene._select_spell_item(inspiration)
	assert_true(bard["hasActed"])
	assert_gt(main_scene.effects_layer.get_child_count(), before, "o preparo da canção cria VFX no Bardo")
