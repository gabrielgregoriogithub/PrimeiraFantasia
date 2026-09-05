extends GutTest

## ETAPA 17 — vida visual de inimigos/chefes. Cobre as duas pontas:
## 1) GameState.perform_attack/perform_ranged_attack_with_obstruction agora
##    registram um breadcrumb "weapon-attack" em last_action_vfx (sem isso,
##    Main não tinha como saber o que animar depois que a IA já resolveu
##    tudo sozinha) — e continuam sem alterar hit/dano/regras.
## 2) EnemyVisualBehaviorController só traduz resultados já aplicados
##    (nunca decide nada) e respeita orçamento/cooldown de reação.

var state: GameState

func before_each() -> void:
	state = GameState.new()
	state.clear_units()
	state.clear_terrain_and_structures()

func _weapon(overrides: Dictionary) -> Dictionary:
	var w := {
		"name": "arma-teste", "ctCost": 50, "damageMin": 5, "damageMax": 5,
		"critMultiplier": 2, "critChance": 0.0, "hitChance": 1.0,
		"minRange": 1, "maxRange": 1,
	}
	for k in overrides.keys(): w[k] = overrides[k]
	return w

func test_perform_attack_records_weapon_attack_breadcrumb_without_changing_the_hit() -> void:
	var attacker := state.spawn_unit("att", {"x": 1, "y": 1})
	var defender := state.spawn_unit("def", {"x": 1, "y": 2, "hp": 20, "maxHp": 20})
	var item := _weapon({"damageMin": 5, "damageMax": 5})
	state.perform_attack(attacker, defender, item)
	assert_eq(defender["hp"], 15, "dano continua exatamente o mesmo")
	assert_eq(state.last_action_vfx.get("kind", ""), "weapon-attack")
	assert_eq(state.last_action_vfx.get("caster", {}).get("name", ""), "att")
	assert_eq(state.last_action_vfx.get("target", {}), {"x": 1, "y": 2})
	assert_true(state.last_action_vfx.get("hit", false))
	assert_false(state.last_action_vfx.get("critical", true), "critMultiplier zerado não deveria acusar crítico")

func test_perform_attack_keeps_the_existing_fire_strike_kind_instead_of_overriding_it() -> void:
	var attacker := state.spawn_unit("att", {"x": 1, "y": 1})
	var defender := state.spawn_unit("def", {"x": 1, "y": 2, "hp": 20, "maxHp": 20})
	var item := _weapon({"damageType": "fire"})
	state.perform_attack(attacker, defender, item)
	assert_eq(state.last_action_vfx.get("kind", ""), "fire-strike", "fogo continua com o presenter dedicado que já existia")

func test_perform_attack_records_a_miss_as_a_miss() -> void:
	var attacker := state.spawn_unit("att", {"x": 2, "y": 1})
	var defender := state.spawn_unit("def", {"x": 1, "y": 1, "hp": 20, "maxHp": 20})
	var item := _weapon({"hitChance": 0.0})
	state.perform_attack(attacker, defender, item)
	assert_eq(defender["hp"], 20)
	assert_eq(state.last_action_vfx.get("kind", ""), "weapon-attack")
	assert_false(state.last_action_vfx.get("hit", true))

func test_perform_attack_records_a_guaranteed_critical() -> void:
	var attacker := state.spawn_unit("att", {"x": 1, "y": 1})
	var defender := state.spawn_unit("def", {"x": 1, "y": 2, "hp": 40, "maxHp": 40})
	var item := _weapon({"critChance": 1.0, "critMultiplier": 2})
	state.perform_attack(attacker, defender, item)
	assert_true(state.last_action_vfx.get("critical", false))

func test_perform_ranged_attack_with_obstruction_records_weapon_attack_breadcrumb() -> void:
	var caster := state.spawn_unit("caster", {"x": 0, "y": 0})
	var target := state.spawn_unit("target", {"x": 3, "y": 0, "hp": 20, "maxHp": 20})
	var weapon := _weapon({"minRange": 1, "maxRange": 5, "damageMin": 4, "damageMax": 4})
	state.perform_ranged_attack_with_obstruction(caster, target, weapon)
	assert_eq(target["hp"], 16)
	assert_eq(state.last_action_vfx.get("kind", ""), "weapon-attack")
	assert_eq(state.last_action_vfx.get("target", {}), {"x": 3, "y": 0})

func test_enemy_visual_behavior_reacts_to_a_nearby_ally_death_but_not_far_ones_or_enemies() -> void:
	var controller := EnemyVisualBehaviorController.new()
	var dying: Dictionary = Units.build()["goblin"].duplicate(true)
	dying["name"] = "goblin_dying"; dying["x"] = 5; dying["y"] = 5; dying["hp"] = 0
	var near_ally: Dictionary = Units.build()["orc"].duplicate(true)
	near_ally["name"] = "orc_near"; near_ally["x"] = 6; near_ally["y"] = 5; near_ally["hp"] = near_ally["maxHp"]
	var far_ally: Dictionary = Units.build()["troll"].duplicate(true)
	far_ally["name"] = "troll_far"; far_ally["x"] = 20; far_ally["y"] = 20; far_ally["hp"] = far_ally["maxHp"]
	var opposing_hero: Dictionary = Units.build()["guerreiro"].duplicate(true)
	opposing_hero["name"] = "guerreiro_hero"; opposing_hero["x"] = 5; opposing_hero["y"] = 6; opposing_hero["hp"] = opposing_hero["maxHp"]

	var near_token := UnitToken.new(); add_child_autofree(near_token); near_token.setup(near_ally)
	var far_token := UnitToken.new(); add_child_autofree(far_token); far_token.setup(far_ally)
	var hero_token := UnitToken.new(); add_child_autofree(hero_token); hero_token.setup(opposing_hero)
	var unit_tokens := {"orc_near": near_token, "troll_far": far_token, "guerreiro_hero": hero_token}

	var contact_before = near_token._character_visual.contact_shadow.scale
	controller.on_ally_died([dying, near_ally, far_ally, opposing_hero], dying, unit_tokens)
	assert_true(controller._ally_death_last_reaction_ms.has("orc_near"), "aliado próximo e vivo reage")
	assert_false(controller._ally_death_last_reaction_ms.has("troll_far"), "aliado longe demais não reage")
	assert_false(controller._ally_death_last_reaction_ms.has("guerreiro_hero"), "time oposto não reage à morte de um inimigo")
	await wait_seconds(0.06)
	assert_ne(near_token._character_visual.contact_shadow.scale, contact_before, "reação realmente mexeu na sombra de contato")

func test_enemy_visual_behavior_ally_death_reaction_respects_cooldown() -> void:
	var controller := EnemyVisualBehaviorController.new()
	var dying: Dictionary = {"name": "x1", "team": "enemy", "x": 0, "y": 0}
	var ally: Dictionary = Units.build()["goblin"].duplicate(true)
	ally["name"] = "goblin_ally"; ally["x"] = 1; ally["y"] = 0; ally["team"] = "enemy"; ally["hp"] = ally["maxHp"]
	var token := UnitToken.new(); add_child_autofree(token); token.setup(ally)
	var unit_tokens := {"goblin_ally": token}
	controller.on_ally_died([dying, ally], dying, unit_tokens)
	var first_reaction: int = controller._ally_death_last_reaction_ms["goblin_ally"]
	controller.on_ally_died([dying, ally], dying, unit_tokens)
	assert_eq(controller._ally_death_last_reaction_ms["goblin_ally"], first_reaction, "cooldown impede reagir de novo na mesma janela")

func test_low_hp_visual_state_changes_idle_pose_without_touching_real_hp() -> void:
	var host := Node2D.new(); add_child_autofree(host)
	var body := Node2D.new(); host.add_child(body)
	var sprite := Sprite2D.new(); body.add_child(sprite)
	var shadow := Polygon2D.new(); host.add_child(shadow)
	var visual := CharacterVisualController.new()
	visual.configure(host, body, sprite, shadow, {"spriteKey": "orc"})
	visual.update_pose(1.4, false, Vector2.RIGHT, false, true, false)
	var normal_height := visual.visual_height
	visual.update_pose(1.4, false, Vector2.RIGHT, false, true, true)
	var low_hp_height := visual.visual_height
	assert_ne(normal_height, low_hp_height, "postura muda visualmente em low_hp")

func test_ai_turn_animates_a_real_weapon_attack_end_to_end() -> void:
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main_scene)
	await wait_process_frames(1)
	if main_scene.scenario_manager.active_id != ScenarioManager.FIELD:
		main_scene.scenario_manager.set_active(ScenarioManager.FIELD)
		main_scene._start_new_game()
		await wait_process_frames(1)
	var goblin = main_scene.state.units.filter(func(u): return u.get("spriteKey", "") == "goblin")[0]
	var hero = main_scene.state.team_units("player")[0]
	goblin["x"] = hero["x"] + 1
	goblin["y"] = hero["y"]
	goblin["hasMoved"] = true
	goblin["hasActed"] = false
	goblin["mp"] = 0
	# Acerto garantido: sem isso o teste é flaky (miss não gera VFX nenhum,
	# ver ramo `else` de _play_attack_vfx — comportamento correto, só não
	# determinístico), mesmo espírito de hitChance forçado em 1.0 já usado
	# em test_game_state_combat.gd.
	for w in (goblin["weapons"] as Array): w["hitChance"] = 1.0
	main_scene.state.current_actor = goblin
	var before: int = main_scene.effects_layer.get_child_count()
	await main_scene._run_ai_until_player_turn()
	assert_true(goblin["hasActed"] or goblin.get("hp", 1) <= 0)
	# Golpe corpo a corpo agenda o impacto (_play_warrior_melee_impact) num
	# timer real (não passa por _wait_for_ai_presentation, que só existe pra
	# pausas "de apresentação" e é pulado em headless) — espera esse timer
	# disparar antes de checar o VFX.
	await wait_seconds(0.4)
	assert_gt(main_scene.effects_layer.get_child_count(), before, "o ataque da Goblin agora gera VFX de verdade, não só a pose genérica")
