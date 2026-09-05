extends GutTest

const FIREBALL_VFX_TEST_SCENE := preload("res://scenes/vfx/fireball_vfx.tscn")
const CHARACTER_VISUAL_CONTROLLER_TEST := preload("res://scenes/character_visual_controller.gd")

## Fase 6 (fumaça de cena): instancia a cena jogável de verdade (Main.tscn)
## e exercita o fluxo de clique chamando os métodos diretamente — sem mouse
## de verdade (headless), só pra garantir que a fiação entre tabuleiro,
## menu de ações e GameState não quebrou. Regra de gameplay em si já está
## coberta pelos outros arquivos de teste; aqui é só "a cena liga certo".

var main_scene

## Este arquivo inteiro assume o roster/estruturas do Campo (Castelo,
## Montanha, Maga presa na gaiola, arma cardinalOnly do Mago etc.) — força o
## Campo aqui em vez de confiar no cenário padrão do app (`ScenarioManager.
## active_id`), que agora abre na Vila a pedido do usuário (ver
## "quero começar pela Vila"). Troca direta (set_active + _start_new_game),
## sem passar pelo fade de _switch_scenario — testes não precisam da
## animação, só do estado final.
func before_each() -> void:
	main_scene = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main_scene)
	await wait_process_frames(1)
	if main_scene.scenario_manager.active_id != ScenarioManager.FIELD:
		main_scene.scenario_manager.set_active(ScenarioManager.FIELD)
		main_scene._start_new_game()
		await wait_process_frames(1)

func test_fireball_vfx_has_composite_nodes_and_cleans_itself_after_impact() -> void:
	var fireball = FIREBALL_VFX_TEST_SCENE.instantiate()
	add_child_autofree(fireball)
	assert_true(fireball.get_node("AnimatedSprite2D") is AnimatedSprite2D)
	assert_true(fireball.get_node("FlameParticles") is GPUParticles2D)
	assert_true(fireball.get_node("SparkParticles") is GPUParticles2D)
	assert_true(fireball.get_node("SmokeParticles") is GPUParticles2D)
	assert_true(fireball.get_node("PointLight2D") is PointLight2D)
	assert_true(fireball.get_node("AnimationPlayer") is AnimationPlayer)
	var impacts := [0]
	fireball.impacted.connect(func(_at: Vector2, _direction: Vector2): impacts[0] += 1)
	fireball.launch(Vector2.ZERO, Vector2(66, 0), 330.0, 1.0)
	await wait_seconds(0.34)
	assert_eq(impacts[0], 1, "impacto deve ser emitido exatamente quando termina o voo")
	await wait_seconds(0.80)
	assert_false(is_instance_valid(fireball), "projétil e emissores residuais devem ser liberados")

func test_magic_visual_base_supports_cast_light_arc_shockwave_and_ground_decal() -> void:
	var before: int = main_scene.effects_layer.get_child_count()
	main_scene.effects_layer.play_magic_cast(Vector2(80, 80), Vector2(102, 70), {"color": Color("ff9a32"), "duration": 0.24, "element": "fire"})
	assert_gt(main_scene.effects_layer.get_child_count(), before + 5, "cast cria luz e partículas convergentes")
	assert_true(main_scene.effects_layer.get_children().any(func(child): return child is PointLight2D))
	before = main_scene.effects_layer.get_child_count()
	main_scene.effects_layer.spawn_shockwave(Vector2(140, 90), Color("ffb34d"))
	main_scene.effects_layer.spawn_temporary_ground_decal(Vector2(140, 90), Color("24120d"), 0.20)
	assert_gte(main_scene.effects_layer.get_child_count(), before + 2)
	var fireball = FIREBALL_VFX_TEST_SCENE.instantiate()
	add_child_autofree(fireball)
	fireball.launch(Vector2.ZERO, Vector2(66, 0), 330.0, 1.0)
	var peak_arc_height := 0.0
	for sample in range(5):
		await wait_seconds(0.025)
		peak_arc_height = minf(peak_arc_height, fireball.position.y)
	assert_lt(peak_arc_height, -4.0, "altura em arco existe só na representação visual")

func test_ice_and_lightning_have_distinct_layered_visual_profiles() -> void:
	var before: int = main_scene.effects_layer.get_child_count()
	main_scene.effects_layer.spawn_ice_impact(Vector2(120, 80), 1.0)
	assert_gt(main_scene.effects_layer.get_child_count(), before + 8, "gelo cria cristais, luz, onda e decal")
	assert_true(main_scene.effects_layer.get_children().any(func(child): return child.z_index < 0), "há resíduos no plano do chão")
	assert_true(main_scene.effects_layer.get_children().any(func(child): return child.z_index >= 12), "há fragmentos no plano frontal")
	before = main_scene.effects_layer.get_child_count()
	main_scene.effects_layer.spawn_lightning_connection([Vector2(40, 40), Vector2(130, 70), Vector2(190, 45)], Color("d7f6ff"), 1.0)
	await wait_seconds(0.07)
	assert_gt(main_scene.effects_layer.get_child_count(), before + 5, "raio aceita múltiplos trechos e ramificações")
	var target = main_scene.state.units[0]
	var token := main_scene.unit_tokens[target["name"]] as UnitToken
	target["statusEffects"] = [{"type": "paralyzed", "turnsLeft": 1}]
	token.refresh()
	assert_eq(token._procedural_status_vfx, "frozen", "Congelamento mantém cristais sem ocultar o personagem")

func test_field_environment_depth_occlusion_and_surface_profiles_are_visual_only() -> void:
	await wait_process_frames(2)
	assert_gt(main_scene.board_view._environment_props.size(), main_scene.state.structures.size(), "Campo cria árvores e estruturas altas como visuais ordenáveis")
	var tree = main_scene.board_view._environment_props.filter(func(prop): return prop.kind == "tree")[0]
	assert_eq(tree.z_index, roundi(tree.position.y), "objeto alto ordena pela base")
	assert_gt(tree.visual_height, BoardView.TILE_SIZE, "copa possui altura visual além do tile")
	var token := main_scene.unit_tokens.values()[0] as UnitToken
	var logical_tile := Vector2i(token.unit["x"], token.unit["y"])
	var original_position := token.position
	assert_eq(token._ui_root.z_index, 3900, "HP e MP permanecem acima da oclusão")
	token.position = tree.position + Vector2(0, -50)
	await wait_seconds(0.14)
	assert_lt(tree.modulate.a, 0.90, "copa fica contextualmente translúcida quando esconde uma unidade")
	token.position = original_position
	assert_eq(Vector2i(token.unit["x"], token.unit["y"]), logical_tile, "oclusão não altera o grid")
	var before: int = main_scene.effects_layer.get_child_count()
	main_scene.effects_layer.spawn_surface_step(Vector2(80, 80), "grass", false)
	main_scene.effects_layer.spawn_surface_step(Vector2(120, 80), "dirt", false)
	main_scene.effects_layer.spawn_surface_step(Vector2(160, 80), "water", false)
	assert_gt(main_scene.effects_layer.get_child_count(), before + 5, "grama, terra e água possuem respostas visuais distintas")

func test_field_structure_occupants_render_above_castle_and_mountain_assets() -> void:
	await wait_process_frames(2)
	for sample in [["guerreiro", Vector2i(1, 1), "castle"], ["orc", Vector2i(11, 1), "mountain"]]:
		var unit: Dictionary = main_scene.state.unit(sample[0])
		unit["x"] = sample[1].x
		unit["y"] = sample[1].y
		var token := main_scene.unit_tokens[unit["name"]] as UnitToken
		token.refresh()
		var prop = main_scene.board_view._environment_props.filter(func(item): return item.kind == sample[2])[0]
		assert_gt(token.z_index, prop.z_index, "%s deve ficar visivel acima da estrutura" % unit["name"])

func test_environment_reaction_presets_affect_props_water_projectiles_and_corpses_only_visually() -> void:
	await wait_process_frames(2)
	var tree = main_scene.board_view._environment_props.filter(func(prop): return prop.kind == "tree")[0]
	var before: int = main_scene.effects_layer.get_child_count()
	main_scene.effects_layer.emit_environment_reaction("explosion", tree.position + Vector2(-40, 0), Vector2.RIGHT, "heavy", "fire")
	await wait_seconds(0.09)
	assert_false(is_zero_approx(tree.rotation), "árvore inclina na direção oposta ao impacto")
	assert_false(main_scene.board_view._grass_reactions.is_empty(), "shockwave visual alcança a grama")
	assert_gt(main_scene.effects_layer.get_child_count(), before, "reação usa orçamento limitado de folhas")
	main_scene.effects_layer.visual_quality = "low"
	assert_eq(main_scene.effects_layer.IMPACT_INTENSITY.size(), 5, "presets LIGHT/MEDIUM/HEAVY/SIGNATURE/EPIC permanecem configuráveis")
	var projectile: Node2D = main_scene.effects_layer.spawn_projectile_visual(Vector2(40, 40), Vector2(220, 220), Color.WHITE, 0.12, Callable(), 8.0, "arrow", "straight")
	assert_false(projectile.z_as_relative, "núcleo do projétil participa da profundidade do mundo")
	assert_lt(projectile.z_index, main_scene.effects_layer.z_index, "projétil não fica forçado acima de toda copa")
	var victim: Dictionary = main_scene.state.units.filter(func(unit): return unit.get("hp", 0) > 0)[0]
	var token := main_scene.unit_tokens[victim["name"]] as UnitToken
	var logical_tile := Vector2i(victim["x"], victim["y"])
	token._last_hp = victim["hp"]
	victim["hp"] = 0
	victim["turnsSinceDeath"] = 0
	token.refresh()
	await wait_seconds(0.24)
	assert_lt(token._shadow.scale.y, 0.75, "sombra do cadáver acompanha a pose caída")
	assert_eq(Vector2i(victim["x"], victim["y"]), logical_tile)

func test_enemy_fire_abilities_create_visible_vfx() -> void:
	var caster := {"name":"Inimigo de Fogo","x":5,"y":5,"facing":{"dx":1,"dy":0}}
	var before: int = main_scene.effects_layer.get_child_count()
	main_scene._play_recorded_enemy_fire_vfx({"kind":"fire-area","caster":caster,"tiles":[{"x":6,"y":5},{"x":6,"y":6}]})
	assert_gt(main_scene.effects_layer.get_child_count(), before, "explosão da Salamandra/Lava Humana cria carga e fogo visíveis")
	before = main_scene.effects_layer.get_child_count()
	main_scene._play_recorded_enemy_fire_vfx({"kind":"fire-cone","caster":caster,"tiles":[{"x":6,"y":5},{"x":7,"y":5},{"x":7,"y":6}]})
	assert_gt(main_scene.effects_layer.get_child_count(), before, "cone da Lava Humana cria VFX")

func test_scene_starts_a_battle_with_someone_ready_to_act() -> void:
	assert_not_null(main_scene.state)
	assert_not_null(main_scene.state.current_actor)

func test_scenario_selector_is_left_aligned_in_requested_order() -> void:
	assert_eq(main_scene._village_button.text, "VILA")
	assert_eq(main_scene._forest_button.text, "FLORESTA")
	assert_eq(main_scene._field_button.text, "CAMPO")
	assert_eq(main_scene._lua_button.text, "HORDA")
	assert_eq(main_scene._tower_button.text, "TORRE")
	assert_lt(main_scene._village_button.position.x, main_scene._forest_button.position.x)
	assert_lt(main_scene._forest_button.position.x, main_scene._field_button.position.x)
	assert_lt(main_scene._field_button.position.x, main_scene._lua_button.position.x)
	assert_lt(main_scene._lua_button.position.y, main_scene._tower_button.position.y)
	assert_lte(main_scene._village_button.position.x, 20.0)
	assert_eq(main_scene._tower_button.position, Vector2(16, 54))
	assert_lt(main_scene._tower_button.position.x, main_scene._floor2_button.position.x)
	assert_lt(main_scene._floor2_button.position.x, main_scene._floor3_button.position.x)
	assert_lt(main_scene._floor3_button.position.x, main_scene._floor4_button.position.x)
	assert_lte(main_scene._floor4_button.position.x + main_scene._floor4_button.size.x, 400.0)
	assert_eq(main_scene.unit_tokens.size(), 10, "o Bardo ainda bloqueado não participa do Campo")
	var current_token = main_scene.unit_tokens[main_scene.state.current_actor["name"]] as UnitToken
	assert_not_null(current_token._hp_bar)
	assert_not_null(current_token._mp_bar)
	assert_true(current_token._hp_bar.visible)
	assert_eq(current_token._hp_bar.current_value, main_scene.state.current_actor["hp"])
	assert_eq(current_token._hp_bar.maximum_value, main_scene.state.current_actor["maxHp"])
	assert_eq(current_token._mp_bar.current_value, main_scene.state.current_actor["mp"])
	assert_eq(current_token._mp_bar.maximum_value, main_scene.state.current_actor["maxMp"])
	assert_eq(current_token._hp_bar._value_label.text, "%d / %d" % [main_scene.state.current_actor["hp"], main_scene.state.current_actor["maxHp"]])

func test_tower_hud_displays_150_turn_limit() -> void:
	main_scene._switch_scenario(ScenarioManager.TOWER)
	await wait_seconds(0.30) # _switch_scenario troca o estado após o fade de 0,20 s
	main_scene._refresh_hud()
	assert_true(main_scene._turn_label.text.ends_with("/150"))

func test_resource_bars_refresh_from_real_unit_state() -> void:
	var unit = main_scene.state.current_actor
	var token = main_scene.unit_tokens[unit["name"]] as UnitToken
	unit["hp"] = 7
	unit["maxHp"] = 31
	unit["mp"] = 3
	unit["maxMp"] = 17
	token.refresh()
	assert_eq(token._hp_bar.current_value, 7)
	assert_eq(token._hp_bar.maximum_value, 31)
	assert_eq(token._hp_bar._value_label.text, "7 / 31")
	assert_eq(token._mp_bar.current_value, 3)
	assert_eq(token._mp_bar.maximum_value, 17)
	assert_eq(token._mp_bar._value_label.text, "3 / 17")

func test_turn_queue_uses_portraits_and_keeps_current_actor_first() -> void:
	var queue = main_scene._predicted_turn_queue()
	assert_false(queue.is_empty())
	assert_eq(queue[0], main_scene.state.current_actor)
	main_scene._refresh_turn_queue()
	await wait_process_frames(1)
	assert_not_null(main_scene._turn_queue_panel)
	var queue_eligible: Array = main_scene.state.alive_units().filter(func(unit): return not unit.get("caged", false))
	assert_eq(main_scene._turn_queue_hbox.get_child_count(), mini(queue_eligible.size(), 11))
	var first_frame = main_scene._turn_queue_hbox.get_child(0)
	var portrait = first_frame.get_child(0).get_child(0) as TextureRect
	assert_not_null(portrait.texture, "o primeiro da fila usa o portrait do personagem")

func test_each_bard_song_success_spawns_its_own_non_interactive_notes_on_target() -> void:
	var token: UnitToken = main_scene.unit_tokens[main_scene.state.current_actor["name"]]
	var spawned: Array = []
	for song_kind in ["heal", "inspiration", "distraction", "pain"]:
		var notes := token.spawn_bard_song_notes(song_kind)
		assert_not_null(notes)
		assert_eq(notes.texture.resource_path, UnitToken.BARD_SONG_NOTE_PATHS[song_kind])
		assert_eq(notes.z_index, 90)
		spawned.append(notes)
	assert_eq(spawned.size(), 4)
	assert_eq(spawned.map(func(notes): return notes.get_instance_id()).duplicate().size(), 4, "efeitos simultâneos não se substituem")
	for notes in spawned: assert_true(notes.get_parent() == token._overhead_fx)

func test_warrior_visual_prototype_has_reusable_visual_hierarchy_and_ground_shadow() -> void:
	var warrior: Dictionary = main_scene.state.unit("guerreiro")
	var token: UnitToken = main_scene.unit_tokens[warrior["name"]]
	assert_eq(token._visual_root.name, "VisualRoot")
	assert_eq(token._sprite.get_parent(), token._visual_root)
	assert_eq(token._sprite.name, "CharacterSprite")
	assert_eq(token._shadow.get_parent(), token, "soft shadow permanece no plano lógico do chão")
	assert_eq(token._weapon_fx.get_parent(), token._visual_root)
	assert_eq(token._status_fx_root.get_parent(), token._visual_root)
	assert_eq(token._overhead_fx.get_parent(), token._visual_root)
	assert_eq(token._ui_root.get_parent(), token)
	assert_not_null(token._animation_player)
	assert_true(token._shadow.visible)
	assert_not_null(main_scene.board_view.camera_shake)

func test_character_25d_volume_profiles_anchor_shadows_lighting_and_ui_are_visual_only() -> void:
	var warrior: Dictionary = main_scene.state.unit("guerreiro")
	var archer: Dictionary = main_scene.state.unit("arqueiro")
	var rogue: Dictionary = main_scene.state.unit("ladino")
	var troll: Dictionary = main_scene.state.unit("troll")
	var warrior_token: UnitToken = main_scene.unit_tokens[warrior["name"]]
	var archer_token: UnitToken = main_scene.unit_tokens[archer["name"]]
	var rogue_token: UnitToken = main_scene.unit_tokens[rogue["name"]]
	var troll_token: UnitToken = main_scene.unit_tokens[troll["name"]]
	assert_eq(warrior_token._character_visual.body_weight(), "heavy")
	assert_eq(archer_token._character_visual.body_weight(), "medium")
	assert_eq(rogue_token._character_visual.body_weight(), "light")
	assert_eq(troll_token._character_visual.body_weight(), "heavy")
	assert_eq(CHARACTER_VISUAL_CONTROLLER_TEST.profile_for_unit({"spriteKey": "salamandra", "footprintSize": 2}), "giant")
	assert_eq(warrior_token._character_visual.contact_shadow.get_parent(), warrior_token)
	assert_eq(warrior_token._shadow.get_parent(), warrior_token)
	assert_eq(warrior_token._ui_root.get_parent(), warrior_token)
	assert_true(warrior_token._sprite.material is ShaderMaterial)
	assert_eq((warrior_token._sprite.material as ShaderMaterial).shader, (archer_token._sprite.material as ShaderMaterial).shader, "shader leve é compartilhado")
	var logical_position := warrior_token.position
	var logical_tile := Vector2i(warrior["x"], warrior["y"])
	var ui_position := warrior_token._ui_root.position
	warrior_token._character_visual.update_pose(PI * 0.5, true, Vector2.RIGHT, false, true)
	var anchored_foot_y: float = warrior_token._visual_root.position.y + warrior_token._visual_root.scale.y * warrior_token._character_visual.foot_anchor_y
	assert_almost_eq(anchored_foot_y, warrior_token._character_visual.foot_anchor_y + warrior_token._character_visual.visual_height, 0.01)
	assert_eq(warrior_token.position, logical_position)
	assert_eq(Vector2i(warrior["x"], warrior["y"]), logical_tile)
	assert_eq(warrior_token._ui_root.position, ui_position)
	var ground_shadow_position := warrior_token._shadow.position
	warrior_token._character_visual.set_visual_height(-12.0)
	assert_eq(warrior_token._shadow.position, ground_shadow_position)
	assert_lt(warrior_token._shadow.color.a, 0.30)
	warrior_token.play_magic_body_light("fire", 1.0, 0.08)
	assert_gt(float((warrior_token._sprite.material as ShaderMaterial).get_shader_parameter("magic_strength")), 0.0)

func test_combat_feedback_manager_ranges_path_reticle_turn_bar_and_smooth_resources_are_visual_only() -> void:
	assert_not_null(main_scene.combat_feedback)
	assert_eq(main_scene.combat_feedback.board, main_scene.board_view)
	var actor: Dictionary = main_scene.state.current_actor
	var enemy: Dictionary = main_scene.state.alive_units().filter(func(unit): return unit["team"] != actor["team"])[0]
	main_scene.combat_feedback.transition_turn(actor)
	assert_true(actor["name"].to_upper() in main_scene.combat_feedback._banner.text)
	main_scene.combat_feedback.set_targets([enemy], enemy)
	assert_eq(main_scene.combat_feedback._targets, [enemy])
	var logical_tile := Vector2i(actor["x"], actor["y"])
	var candidate: Dictionary = main_scene.reachable_tiles[0]
	var official_path: Array = main_scene.state.reconstruct_path(candidate["x"], candidate["y"]).duplicate(true)
	main_scene.board_view.set_interaction_preview(candidate, official_path, candidate, "move")
	assert_eq(main_scene.board_view.preview_path, official_path)
	assert_eq(main_scene.board_view.preview_destination, candidate)
	assert_eq(Vector2i(actor["x"], actor["y"]), logical_tile)
	main_scene.board_view.fade_action_feedback()
	assert_true(main_scene.board_view._highlight_fading)
	var token: UnitToken = main_scene.unit_tokens[actor["name"]]
	var bar := token._hp_bar
	var old_display: float = bar.displayed_value
	bar.set_values(maxi(0, bar.current_value - 3), bar.maximum_value)
	assert_lt(bar.current_value, int(old_display))
	assert_gte(bar.lag_value, bar.displayed_value)
	await wait_seconds(0.52)
	assert_almost_eq(bar.displayed_value, float(bar.current_value), 0.05)
	assert_almost_eq(bar.lag_value, float(bar.current_value), 0.05)
	main_scene.combat_feedback.reduced_motion = true
	var camera_offset: Vector2 = main_scene.board_view.camera.offset
	main_scene.combat_feedback.action_focus(Vector2.ZERO, Vector2.RIGHT * 100.0, "epic")
	assert_eq(main_scene.board_view.camera.offset, camera_offset, "reduced motion desativa pan/zoom decorativo")

func test_warrior_weighted_attack_moves_only_visual_root_not_logical_token() -> void:
	var warrior: Dictionary = main_scene.state.unit("guerreiro")
	var token: UnitToken = main_scene.unit_tokens[warrior["name"]]
	var logical_position := token.position
	var logical_tile := Vector2i(warrior["x"], warrior["y"])
	assert_true(token.play_weighted_attack(token.position + Vector2.RIGHT * BoardView.TILE_SIZE))
	var peak_visual_displacement := 0.0
	for sample in range(8):
		await wait_seconds(0.04)
		peak_visual_displacement = maxf(peak_visual_displacement, absf(token._visual_root.position.x))
	assert_eq(token.position, logical_position)
	assert_eq(Vector2i(warrior["x"], warrior["y"]), logical_tile)
	assert_gt(peak_visual_displacement, 2.0)
	# Pedido do usuário: ataques mais lentos/pesados — UnitToken.ATTACK_WEIGHT_SCALE
	# e HIT_STOP_WEIGHT_SCALE esticaram a duração total do tween, então a
	# espera pro visual assentar de volta em zero também precisa crescer.
	await wait_seconds(0.75)
	assert_almost_eq(token._visual_root.position.x, 0.0, 0.2)

func test_hit_reaction_recoils_away_without_changing_logical_position() -> void:
	var target: Dictionary = main_scene.state.unit("arqueiro")
	var token: UnitToken = main_scene.unit_tokens[target["name"]]
	var logical_position := token.position
	var logical_tile := Vector2i(target["x"], target["y"])
	token.play_weighted_hit_reaction(token.position - Vector2.RIGHT * 64.0, true)
	await wait_seconds(0.05)
	assert_gt(token._visual_root.position.x, 0.0)
	assert_eq(token.position, logical_position)
	assert_eq(Vector2i(target["x"], target["y"]), logical_tile)
	await wait_seconds(0.55)
	assert_almost_eq(token._visual_root.position.x, 0.0, 0.2)

func test_camera_shake_uses_attack_axis_and_returns_to_origin() -> void:
	main_scene.board_view.shake_camera(Vector2.DOWN, 2.0, 0.12, false)
	await wait_seconds(0.025)
	assert_gt(absf(main_scene.board_view.camera.offset.y), absf(main_scene.board_view.camera.offset.x))
	await wait_seconds(0.14)
	assert_almost_eq(main_scene.board_view.camera.offset.length(), 0.0, 0.1)

func test_reusable_dust_hit_and_slash_effect_scenes_exist() -> void:
	for path in ["res://effects/dust.tscn", "res://effects/hit_spark.tscn", "res://effects/slash.tscn"]:
		assert_true(ResourceLoader.exists(path))
		var effect = load(path).instantiate()
		add_child_autofree(effect)
		assert_not_null(effect)

func test_clicking_turn_queue_portrait_opens_full_unit_info_popup() -> void:
	main_scene._refresh_turn_queue()
	var queued_unit: Dictionary = main_scene._predicted_turn_queue()[0]
	var first_frame = main_scene._turn_queue_hbox.get_child(0)
	var portrait = first_frame.get_child(0).get_child(0) as TextureRect
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	portrait.gui_input.emit(click)
	assert_true(main_scene._unit_info_panel.visible)
	assert_true(main_scene._unit_info_title.text.contains(queued_unit["name"]))
	assert_true(main_scene._unit_info_content.get_child_count() > 8, "retrato abre o mesmo cartão completo do tabuleiro")
	main_scene._close_unit_info()

func test_resurrectable_corpse_stays_in_turn_queue_with_death_countdown() -> void:
	var corpse: Dictionary = main_scene.state.units[1]
	corpse["hp"] = 0
	corpse["turnsSinceDeath"] = 1
	main_scene._refresh_turn_queue()
	var queue = main_scene._predicted_turn_queue()
	assert_true(queue.has(corpse), "cadáver ressuscitável permanece na previsão")
	var corpse_index: int = queue.find(corpse)
	assert_gte(corpse_index, 0, "cadáver aparece no marcador de fechamento da rodada")
	var corpse_frame = main_scene._turn_queue_hbox.get_child(corpse_index)
	var portrait = corpse_frame.get_child(0).get_child(0)
	var countdown = portrait.get_node("DeathCountdown") as Label
	assert_not_null(countdown)
	assert_eq(countdown.text, "💀 2")

func test_corpse_portrait_advances_toward_round_decay_marker() -> void:
	var corpse: Dictionary = main_scene.state.units[1]
	corpse["hp"] = 0
	corpse["turnsSinceDeath"] = 1
	main_scene.state.round_acted_units = []
	for living in main_scene.state.alive_units():
		if living != main_scene.state.current_actor:
			main_scene.state.round_acted_units.append(living["name"])
	main_scene._refresh_turn_queue()
	var queue = main_scene._predicted_turn_queue()
	assert_eq(queue[0], main_scene.state.current_actor)
	assert_eq(queue[1], corpse, "retrato morto avança até logo após o último vivo pendente da rodada")
	var portrait = main_scene._turn_queue_hbox.get_child(1).get_child(0).get_child(0)
	assert_eq((portrait.get_node("DeathCountdown") as Label).text, "💀 2")

func test_ai_turns_run_automatically_until_a_player_unit_is_up() -> void:
	assert_false(main_scene.state.battle_ended)
	assert_eq(main_scene.state.current_actor["team"], "player", "a fiação inicial já deixou a IA jogar sozinha até sobrar vez de herói")

func test_clicking_own_token_opens_the_action_menu_with_weapons_and_spells() -> void:
	var u = main_scene.state.current_actor
	main_scene._handle_tile_click(u["x"], u["y"])
	assert_true(main_scene._action_menu_panel.visible)
	var button_count: int = main_scene._action_menu_vbox.get_child_count()
	assert_true((main_scene._action_menu_vbox.get_child(0) as Button).text.contains("Mover"), "Mover aparece primeiro na lista de ações")
	# pelo menos as armas + "Cancelar".
	assert_true(button_count >= (u["weapons"] as Array).size() + 1)

	main_scene._handle_tile_click(u["x"], u["y"])
	assert_false(main_scene._action_menu_panel.visible, "clicar de novo no próprio token fecha o menu")

## A confirmação "ainda há ações disponíveis" foi removida a pedido do
## usuário — Encerrar Turno agora sempre encerra na hora, mesmo com
## movimento/ataque ainda disponíveis (sem popup pedindo "tem certeza?").
func test_ending_turn_early_skips_the_confirmation_popup() -> void:
	var actor = main_scene.state.current_actor
	actor["hasMoved"] = false
	actor["hasActed"] = false
	main_scene._on_end_turn_pressed()
	assert_false(main_scene._confirm_panel.visible, "não deve mais pedir confirmação de 'ações disponíveis'")

func test_touching_a_unit_outside_its_turn_opens_read_only_info_card() -> void:
	var current = main_scene.state.current_actor
	var inspected = main_scene.state.units.filter(func(u): return u != current and u["hp"] > 0)[0]
	var state_before := [inspected["hp"], inspected["ct"], inspected["mp"]]
	assert_true(main_scene._try_open_unit_inspection_at(inspected["x"], inspected["y"]))
	assert_true(main_scene._unit_info_panel.visible)
	assert_true(main_scene._unit_info_title.text.contains(inspected["name"]))
	assert_true(main_scene._unit_info_content.get_child_count() > 8, "cartão inclui atributos, passivas, status, armas e habilidades")
	assert_eq([inspected["hp"], inspected["ct"], inspected["mp"]], state_before, "inspeção não altera o combate")
	main_scene._close_unit_info()
	assert_false(main_scene._unit_info_panel.visible)

## Ver main.gd:_try_open_terrain_info_at/_open_structure_info (porte de
## openStructureInfoModal, game.js:4096-4109) — clicar no Castelo (0-2,0-2),
## vazio por padrão no início da partida, mostra o popup com HP ao vivo e as
## regras completas (dano dobrado em área, derrota do time dono ao destruir).
func test_clicking_the_castle_shows_its_info_popup_with_live_hp_and_full_rules() -> void:
	assert_true(main_scene._try_open_terrain_info_at(1, 1))
	assert_true(main_scene._unit_info_panel.visible)
	assert_true(main_scene._unit_info_title.text.contains("Castelo"))
	assert_true(main_scene._unit_info_title.text.contains("100/100"), "HP atual/máximo, ver GameConstants.STRUCTURE_MAX_HP")
	var body: String = (main_scene._unit_info_content.get_child(0) as Label).text
	assert_true(body.contains("DOBRO"), "ataque em área causa o dobro de dano na estrutura")
	assert_true(body.contains("1 HP e 1 MP"), "regeneração do ocupante por turno")
	assert_true(body.contains("vence a partida"), "destruir o Castelo decide a batalha")

## Estrutura destruída: mesmo popup, mas com o texto de escombros em vez das
## regras de quando estava de pé (porte do ramo `structure.destroyed` de
## openStructureInfoModal).
func test_clicking_a_destroyed_castle_shows_the_rubble_variant() -> void:
	for s in main_scene.state.structures:
		if s["type"] == "castle":
			s["destroyed"] = true
			s["hp"] = 0
	assert_true(main_scene._try_open_terrain_info_at(1, 1))
	assert_true(main_scene._unit_info_title.text.contains("destruído"))
	var body: String = (main_scene._unit_info_content.get_child(0) as Label).text
	assert_true(body.contains("Só decoração"))

## Porte de openTerrainInfoModal (game.js:4071-4080) — mesmo popup, agora pra
## terreno destrutível, com o HP do tile específico entre parênteses.
func test_clicking_a_tree_shows_terrain_info_with_its_own_hp() -> void:
	var tree_tile: Dictionary = BoardLayout.TERRAIN_LAYOUT["tree"][0]
	assert_true(main_scene._try_open_terrain_info_at(tree_tile["x"], tree_tile["y"]))
	assert_true(main_scene._unit_info_title.text.contains("Árvore"))
	assert_true(main_scene._unit_info_title.text.contains("/10"), "GameConstants.TREE_MAX_HP")

## Mesma prioridade do onTileClick original: um tile que hoje é destino de
## movimento válido continua movendo pra lá — o popup só aparece FORA de um
## clique de movimento (senão nunca daria pra entrar no Castelo clicando nele).
func test_terrain_info_does_not_steal_a_valid_movement_click_into_the_castle() -> void:
	var hero = main_scene.state.unit("guerreiro")
	hero["x"] = 3
	hero["y"] = 1
	hero["hasMoved"] = false
	hero["hasActed"] = false
	main_scene.state.current_actor = hero
	main_scene.mode = "idle"
	main_scene._compute_current_targets()
	# (2,1) é a borda do Castelo, adjacente a terreno aberto — o interior
	# (ex: 1,1) não é alcançável num pulo só (compute_reachable trata a
	# estrutura como "pode parar, não atravessa" mesmo entre tiles dela).
	assert_true(main_scene._tile_in_list(main_scene.reachable_tiles, 2, 1), "herói adjacente alcança a borda do Castelo")
	assert_false(main_scene._try_open_terrain_info_at(2, 1), "destino de movimento válido não deve abrir o popup")

## Ver GameState._setup_caged_mage: no Campo (cenário padrão desta suíte), a
## Maga começa presa numa gaiola — clicar nela mostra uma dica em vez do
## cartão de inspeção completo.
func test_touching_the_caged_mage_shows_a_hint_instead_of_the_full_info_card() -> void:
	var maga = main_scene.state.unit(GameState.CAGED_MAGE_KEY)
	assert_true(main_scene._try_open_unit_inspection_at(maga["x"], maga["y"]))
	assert_false(main_scene._unit_info_panel.visible, "gaiola não abre o cartão completo")
	assert_true(main_scene._scenario_banner.text.contains("presa"))

## Ver UnitToken._cage_sprite/GameState._release_caged_mage: o asset real da
## gaiola (assets/props/cage.png) some do token assim que um herói termina o
## turno do lado dela.
func test_caged_mage_cage_sprite_disappears_after_being_released() -> void:
	var maga = main_scene.state.unit(GameState.CAGED_MAGE_KEY)
	var token = main_scene.unit_tokens[maga["name"]] as UnitToken
	assert_true(token._cage_sprite.visible, "gaiola visível enquanto presa")
	var hero = main_scene.state.unit("guerreiro")
	hero["x"] = maga["x"] + 1
	hero["y"] = maga["y"]
	main_scene.state.current_actor = hero
	main_scene.state.advance_to_next_turn()
	main_scene._sync_visuals()
	assert_false(maga.get("caged", false))
	assert_false(token._cage_sprite.visible, "gaiola deveria sumir ao libertar a Maga")

## Ver main.gd:_start_victory_phase_advance — vencer não mostra mais a tela
## com "Reiniciar Partida" (ver _show_end_screen); em vez disso toca a
## fanfarra e encadeia a mesma animação de fade+reconstrução dos botões do
## topo pra avançar automaticamente CAMPO → HORDA (ScenarioManager.next_id).
## _wait_for_ai_presentation pula a espera real de 3s em execução headless.
func test_winning_a_battle_skips_the_restart_screen_and_advances_to_the_next_phase() -> void:
	assert_eq(main_scene.scenario_manager.active_id, ScenarioManager.FIELD)
	for enemy in main_scene.state.team_units("enemy"):
		enemy["hp"] = 0
	main_scene.state.check_battle_outcome()
	main_scene._refresh_hud()
	assert_false(main_scene._end_screen.visible, "vitória não deve mais oferecer 'Reiniciar Partida'")
	await wait_seconds(0.75)
	assert_eq(main_scene.scenario_manager.active_id, ScenarioManager.LUA_VALLEY, "CAMPO vencido deveria avançar pra HORDA")
	assert_false(main_scene._phase_advance_pending)
	assert_false(main_scene._end_screen.visible)

func test_losing_a_battle_still_shows_the_restart_screen() -> void:
	for hero in main_scene.state.team_units("player"):
		hero["hp"] = 0
	main_scene.state.check_battle_outcome()
	main_scene._refresh_hud()
	assert_true(main_scene._end_screen.visible)
	assert_eq(main_scene._end_screen_title.text, "VOCÊ PERDEU!")
	assert_eq(main_scene.scenario_manager.active_id, ScenarioManager.FIELD, "derrota não avança de fase")

func test_inspection_does_not_steal_clicks_while_targeting_an_attack() -> void:
	var current = main_scene.state.current_actor
	var inspected = main_scene.state.units.filter(func(u): return u != current and u["hp"] > 0)[0]
	main_scene.mode = "attack"
	assert_false(main_scene._try_open_unit_inspection_at(inspected["x"], inspected["y"]))
	assert_false(main_scene._unit_info_panel.visible)

## Regressão: na última linha do tabuleiro, o botão Confirmar (que normalmente
## fica abaixo do personagem) ia parar em cima da fila de turnos/log — agora
## sobe pra cima do personagem nesse caso.
func test_facing_confirm_button_moves_above_the_character_on_the_last_row() -> void:
	var u = main_scene.state.current_actor
	u["y"] = GameConstants.BOARD_SIZE - 1
	main_scene._open_facing_picker(u)
	if main_scene._facing_panel.visible:
		var center = main_scene.board_view.global_position + main_scene.board_view.tile_center(u["x"], u["y"])
		assert_true(main_scene._facing_confirm_button.position.y < center.y, "confirmar fica acima do personagem na última linha")

func test_horde_visible_bottom_row_places_facing_confirm_above_and_clickable() -> void:
	var definition := ScenarioManager.definition(ScenarioManager.LUA_VALLEY)
	main_scene.state.apply_scenario(definition)
	main_scene.board_view.set_state(main_scene.state)
	main_scene.board_view.set_scenario(definition)
	await wait_process_frames(1)
	var u: Dictionary = main_scene.state.team_units("player")[0]
	u["x"] = 6
	u["y"] = 12 # última linha do recorte visível 13x13, não do mapa 26x22
	main_scene.state.current_actor = u
	main_scene._open_facing_picker(u)
	if main_scene._facing_panel.visible:
		var center: Vector2 = main_scene._board_to_screen(main_scene.board_view.tile_center(u["x"], u["y"]))
		var board_bottom: float = main_scene._board_clip.global_position.y + main_scene._board_clip.size.y
		assert_true(main_scene._facing_confirm_button.position.y < center.y, "na borda visível da Horda o botão sobe")
		assert_lte(main_scene._facing_confirm_button.position.y + main_scene._facing_confirm_button.size.y, board_bottom - 4.0, "botão inteiro permanece dentro da área clicável")

func test_facing_picker_has_a_visible_confirm_button() -> void:
	var u = main_scene.state.current_actor
	main_scene._open_facing_picker(u)
	if main_scene._facing_panel.visible:
		assert_not_null(main_scene._facing_confirm_button)
		assert_true(main_scene._facing_confirm_button.visible)
		assert_true(main_scene._facing_confirm_button.size.y >= 40.0)
		assert_eq(main_scene._facing_direction_buttons.size(), 4)
		var center = main_scene.board_view.global_position + main_scene.board_view.tile_center(u["x"], u["y"])
		for button in main_scene._facing_direction_buttons:
			assert_true(button.position.distance_to(center) < 110.0, "setas ficam ao redor do personagem")
			var circle = button.get_theme_stylebox("normal") as StyleBoxFlat
			assert_true(circle.corner_radius_top_left >= 20, "botão de direção é circular")

func test_ranged_projectiles_use_half_speed_and_create_visible_vfx() -> void:
	assert_eq(main_scene._projectile_duration_for_kind("arrow"), 0.22)
	# Pedido do usuário: flecha viajando devagar o bastante pra ler como fase
	# separada do disparo, não instantânea — ver _projectile_travel_duration.
	assert_almost_eq(main_scene._projectile_travel_duration("arrow", Vector2.ZERO, Vector2.RIGHT * BoardView.TILE_SIZE), 0.28, 0.001)
	assert_almost_eq(main_scene._projectile_travel_duration("arrow", Vector2.ZERO, Vector2.RIGHT * BoardView.TILE_SIZE * 8.0), 0.55, 0.001)
	assert_eq(main_scene._projectile_duration_for_kind("blade"), 1.10)
	var before: int = main_scene.effects_layer.get_child_count()
	main_scene.effects_layer.spawn_projectile(Vector2(20, 20), Vector2(200, 20), Color.WHITE, 1.04, Callable(), 8.0, "arrow")
	assert_true(main_scene.effects_layer.get_child_count() >= before + 4, "flecha e três partes do rastro foram criadas")

func test_archer_ranged_visual_has_release_origin_trajectory_and_distinct_miss() -> void:
	var archer = main_scene.state.units.filter(func(u): return u.get("spriteKey", "") == "arqueiro")[0]
	var token := main_scene.unit_tokens[archer["name"]] as UnitToken
	var target := token.position + Vector2.RIGHT * 180.0
	var origin := token.projectile_visual_origin(target, "arrow")
	assert_gt(origin.x, token.position.x, "flecha nasce à frente do VisualRoot")
	assert_lt(origin.y, token.position.y, "flecha nasce na altura visual do arco")
	assert_eq(main_scene._ranged_release_delay(archer, "huntress-arrow-spd"), 0.30)
	var arrival_state := [false]
	var projectile: Node2D = main_scene.effects_layer.spawn_projectile_visual(origin, target, Color("dec58f"), 0.08, func(): arrival_state[0] = true, 8.0, "arrow", "straight")
	assert_not_null(projectile)
	await wait_seconds(0.16)
	assert_true(arrival_state[0])
	var before: int = main_scene.effects_layer.get_child_count()
	main_scene.effects_layer.play_projectile_impact(target + Vector2(20, 12), Vector2.RIGHT, "arrow", Color("dec58f"), false)
	assert_gt(main_scene.effects_layer.get_child_count(), before, "erro cria contato pequeno fora do alvo")

func test_special_projectile_variants_and_status_aura_are_available() -> void:
	assert_eq(main_scene._projectile_duration_for_kind("fire-arrow"), 0.22)
	assert_eq(main_scene._projectile_duration_for_kind("bullet-explosive"), 0.56)
	var token = main_scene.unit_tokens.values()[0] as UnitToken
	token.unit["statusEffects"] = [{"type":"poison", "turnsLeft":2}]
	token.refresh()
	assert_eq(token._procedural_status_vfx, "poison")

func test_spd_wand_projectiles_use_distinct_particle_profiles() -> void:
	var spells := Spells.build()
	var weapons := Weapons.build()
	assert_eq(spells["missile"]["projectile"], "magic-missile-spd")
	assert_eq(spells["missile"]["sfx"], "magicMissileZapSpd")
	assert_eq(weapons["iceRay"]["projectile"], "frost-wand-spd")
	assert_eq(weapons["iceRay"]["sfx"], "frostWandZapSpd")
	var before: int = main_scene.effects_layer.get_child_count()
	main_scene.effects_layer.spawn_projectile(Vector2(20, 20), Vector2(220, 20), Color.WHITE, 1.0, Callable(), 5.0, "magic-missile-spd")
	assert_true(main_scene.effects_layer.get_child_count() >= before + 10, "míssil SPD cria núcleo e rastro denso de partículas brancas")
	before = main_scene.effects_layer.get_child_count()
	main_scene.effects_layer.spawn_projectile(Vector2(20, 50), Vector2(220, 50), Color("88ccff"), 1.0, Callable(), 5.0, "frost-wand-spd")
	assert_eq(main_scene.effects_layer.get_child_count(), before + 1, "gelo SPD começa somente com o emissor, sem núcleo sólido inventado")
	assert_eq(Vector2(20, 50).distance_to(Vector2(220, 50)) / EffectsLayer.SPD_FROST_WORLD_SPEED, 0.25)
	await wait_seconds(0.04)
	assert_true(main_scene.effects_layer.get_children().any(func(child): return child is EffectsLayer.SpdFrostParticle), "emissor cria MagicParticle azul a cada 0,01 s")

func test_selecting_bow_paints_every_valid_range_tile_red() -> void:
	var archer = main_scene.state.units.filter(func(u): return u.get("spriteKey", "") == "arqueiro")[0]
	var bow = archer["weapons"].filter(func(w): return w.get("projectile", "") == "arrow")[0]
	main_scene.state.current_actor = archer
	archer["hasActed"] = false
	main_scene._select_attack_item(bow)
	assert_true(main_scene.attack_range_tiles.size() > main_scene.attackable_units.size(), "alcance inclui casas vazias, não só inimigos")
	assert_eq(main_scene.board_view.highlight_attack_range, main_scene.attack_range_tiles)

## Regressão: Tiro Longo pintava attack_range_tiles com o alcance dobrado
## (compute_range_tiles já aplicava o bônus) mas attackable_units continuava
## checando o maxRange cru do Arco — um inimigo só alcançável COM o bônus
## aparecia destacado, porém clicar nele não fazia nada.
func test_long_shot_lets_you_actually_click_a_target_only_in_range_with_the_buff() -> void:
	var archer = main_scene.state.units.filter(func(u): return u.get("spriteKey", "") == "arqueiro")[0]
	var bow = archer["weapons"].filter(func(w): return w.get("projectile", "") == "arrow")[0]
	var long_shot = archer["spells"].filter(func(s): return s.get("name", "") == "Tiro Longo")[0]
	var target = main_scene.state.opposing_team_of(archer)[0]
	main_scene.state.current_actor = archer
	archer["x"] = 0
	archer["y"] = 6
	archer["hasActed"] = false
	target["x"] = 7 # distância 7: além do maxRange 5 do Arco, dentro do dobro (10)
	target["y"] = 6
	target["hp"] = target["maxHp"]

	main_scene.state.cast_long_shot(archer, long_shot)
	main_scene._select_attack_item(bow)
	assert_true(main_scene.attack_range_tiles.any(func(t): return t["x"] == 7 and t["y"] == 6), "alcance pintado já incluía o tile do alvo")
	assert_true(main_scene.attackable_units.has(target), "alvo precisa estar clicável, não só destacado")

	main_scene._resolve_attack(archer, target, bow)
	# resolve_single_hit loga exatamente "...e errou!" no miss (ver game_state.gd)
	# — o antigo "erra" aqui embaixo nunca batia com esse texto (só "errou"
	# contém as duas primeiras letras, não as quatro), então todo miss (~20%
	# de chance com hitChance 0.8 do Arco) fazia esse teste falhar à toa.
	var last_log: String = (main_scene.state.event_log[-1] as String).to_lower()
	assert_true(target["hp"] < target["maxHp"] or last_log.contains("errou") or last_log.contains("não acerta"), "o disparo realmente resolveu (acertou ou errou), não foi ignorado")

func test_clicking_a_reachable_tile_moves_the_current_actor() -> void:
	var u = main_scene.state.current_actor
	assert_false(u.get("hasMoved", false))
	assert_true(main_scene.reachable_tiles.size() > 0, "unidade recém-começou o turno, deve ter tiles alcançáveis")
	var dest = main_scene.reachable_tiles[0]
	main_scene._handle_tile_click(dest["x"], dest["y"])
	assert_eq(u["x"], dest["x"])
	assert_eq(u["y"], dest["y"])
	assert_true(u["hasMoved"])
	var token = main_scene.unit_tokens[u["name"]] as UnitToken
	assert_true(token._path_animating or token.position == main_scene.board_view.tile_center(dest["x"], dest["y"]), "token percorre o caminho calculado até o destino")

func test_action_menu_uses_parchment_background() -> void:
	var parchment = main_scene._action_menu_panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(parchment)
	assert_true(parchment.bg_color.r > parchment.bg_color.b, "fundo do menu é bege quente, como papiro")

## Pedido do usuário: a Poção de Mana passou a ter a mesma área de efeito da
## Poção de Cura/Regeneração em Área (mana-aoe agora está em AOE_CONFIRM_MODES,
## igual heal-aoe/regen-aoe) — precisa dos mesmos 2 cliques de confirmação.
func test_chemist_can_throw_mana_potion_on_self() -> void:
	var chemist = main_scene.state.units.filter(func(u): return u.get("spriteKey", "") == "quimico")[0]
	var potion = chemist["spells"].filter(func(s): return s.get("name", "") == "Poção de Mana")[0]
	main_scene.state.current_actor = chemist
	chemist["mp"] = 5
	chemist["maxMp"] = 20
	chemist["hasActed"] = false
	main_scene._select_spell_item(potion)
	assert_true(main_scene.spell_tiles.any(func(t): return t["x"] == chemist["x"] and t["y"] == chemist["y"]), "a própria casa precisa ser um alvo válido")
	main_scene._handle_tile_click(chemist["x"], chemist["y"])
	main_scene._handle_tile_click(chemist["x"], chemist["y"])
	main_scene._on_confirm_ok_pressed()
	assert_true(chemist["mp"] > 5, "a poção recupera mais MP do que seu custo e não apenas cancela a mira")
	assert_true(chemist["hasActed"])

func test_quick_shot_keeps_bow_selected_for_second_attack() -> void:
	var archer = main_scene.state.units.filter(func(u): return u.get("spriteKey", "") == "arqueiro")[0]
	var bow = archer["weapons"].filter(func(w): return w.get("projectile", "") == "arrow")[0]
	var quick_shot = archer["spells"].filter(func(s): return s.get("name", "") == "Tiro Rápido")[0]
	var target = main_scene.state.opposing_team_of(archer)[0]
	main_scene.state.current_actor = archer
	archer["x"] = target["x"] - 2 if target["x"] >= 2 else target["x"] + 2
	archer["y"] = target["y"]
	archer["mp"] = archer["maxMp"]
	archer["hasActed"] = false
	main_scene.state.cast_agility(archer, quick_shot)
	main_scene._resolve_attack(archer, target, bow)
	assert_false(archer["hasActed"], "primeiro tiro deixa o segundo ataque disponível")
	assert_eq(main_scene.mode, "attack")
	assert_eq(main_scene.pending_item["name"], bow["name"], "o arco continua selecionado automaticamente")

func test_quick_shot_after_move_allows_two_shots_and_waits_second_projectile_for_facing() -> void:
	var archer = main_scene.state.units.filter(func(u): return u.get("spriteKey", "") == "arqueiro")[0]
	var bow = archer["weapons"].filter(func(w): return w.get("projectile", "") == "arrow")[0]
	var quick_shot = archer["spells"].filter(func(s): return s.get("name", "") == "Tiro Rápido")[0]
	var targets = main_scene.state.opposing_team_of(archer)
	var target = targets[0]
	main_scene.state.current_actor = archer
	archer["x"] = target["x"] - 2 if target["x"] >= 2 else target["x"] + 2
	archer["y"] = target["y"]
	archer["mp"] = archer["maxMp"]
	archer["hasMoved"] = true
	archer["hasActed"] = false
	target["hp"] = 999
	target["maxHp"] = 999
	main_scene._select_spell_item(quick_shot)
	assert_eq(main_scene.mode, "attack", "Tiro Rápido entra imediatamente na mira do Arco")
	assert_eq(main_scene.pending_item["name"], bow["name"])

	main_scene._resolve_attack(archer, target, bow)
	assert_false(archer["hasActed"], "primeiro tiro não encerra a ação")
	assert_eq(main_scene.mode, "attack", "primeiro tiro mantém a mira do arco")
	assert_false(main_scene._waiting_for_projectile_turn_end, "primeiro projétil não bloqueia o segundo tiro")

	main_scene._resolve_attack(archer, target, bow)
	assert_true(archer["hasActed"], "segundo tiro consome a ação")
	assert_true(main_scene._waiting_for_projectile_turn_end, "aguarda a chegada do segundo projétil")
	assert_false(main_scene._facing_panel.visible, "orientação ainda não aparece durante o voo")
	# Pedido do usuário: flecha mais lenta — usa a duração real por distância
	# (_projectile_travel_duration), não mais o fallback fixo de
	# _projectile_duration_for_kind, que ficava perto demais do tempo real de
	# voo pra servir de margem confiável depois que o voo ficou mais longo.
	var second_shot_origin: Vector2 = main_scene.board_view.tile_center(archer["x"], archer["y"])
	var second_shot_impact: Vector2 = main_scene.board_view.tile_center(target["x"], target["y"])
	var second_shot_travel: float = main_scene._projectile_travel_duration("arrow", second_shot_origin, second_shot_impact)
	await wait_seconds(main_scene._ranged_release_delay(archer, "huntress-arrow-spd") + second_shot_travel + 0.60)
	assert_false(main_scene._waiting_for_projectile_turn_end)
	assert_true(main_scene._facing_panel.visible, "orientação aparece depois do impacto do segundo tiro")

## Pedido do usuário: Tiro Explosivo (Químico) não deve mais parar no menu
## depois de conjurado — deve entrar direto na mira da própria arma, igual o
## atalho de Tiro Rápido do Arqueiro (ver _select_spell_item, main.gd).
func test_explosive_shot_jumps_straight_into_weapon_aim() -> void:
	var chemist = main_scene.state.units.filter(func(u): return u.get("spriteKey", "") == "quimico")[0]
	var firearm: Dictionary = chemist["weapons"][0]
	var explosive_shot: Dictionary = chemist["spells"].filter(func(s): return s.get("kind", "") == "explosive-shot")[0]
	main_scene.state.current_actor = chemist
	chemist["mp"] = chemist["maxMp"]
	chemist["hasMoved"] = false
	chemist["hasActed"] = false
	main_scene._select_spell_item(explosive_shot)
	assert_eq(main_scene.mode, "attack", "Tiro Explosivo entra imediatamente na mira da Arma de Fogo")
	assert_eq(main_scene.pending_item["name"], firearm["name"])
	assert_gt(chemist.get("oneShotDamageBonus", 0), 0, "o próprio cast_explosive_shot já aplicou o bônus de dano")
	assert_false(chemist["hasActed"], "conjurar a habilidade livre não consome a ação")

func test_quick_shot_selected_after_first_attack_opens_one_more_bow_shot() -> void:
	var archer = main_scene.state.units.filter(func(u): return u.get("spriteKey", "") == "arqueiro")[0]
	var bow = archer["weapons"].filter(func(w): return w.get("projectile", "") == "arrow")[0]
	var quick_shot = archer["spells"].filter(func(s): return s.get("name", "") == "Tiro Rápido")[0]
	var target = main_scene.state.opposing_team_of(archer)[0]
	main_scene.state.current_actor = archer
	archer["x"] = target["x"] - 2 if target["x"] >= 2 else target["x"] + 2
	archer["y"] = target["y"]
	archer["mp"] = archer["maxMp"]
	archer["hasMoved"] = false
	archer["hasActed"] = true # simula o primeiro disparo já concluído

	main_scene._select_spell_item(quick_shot)
	assert_false(archer["hasActed"])
	assert_eq(main_scene.mode, "attack", "a habilidade deve voltar direto para a mira do Arco")
	assert_eq(main_scene.pending_item["name"], bow["name"])
	assert_true(main_scene.attackable_units.has(target))

	main_scene._resolve_attack(archer, target, bow)
	assert_true(archer["hasActed"], "o segundo disparo encerra a ação e não concede um terceiro")
	assert_eq(archer.get("bonusAttacksRemaining", 0), 0)

## Clicar num alvo válido não resolve mais na hora — abre o popup de
## confirmação (chance de acerto + dano esperado); só confirmar de fato
## resolve o ataque (pedido do usuário).
func test_selecting_a_weapon_from_the_menu_opens_a_confirmation_popup_before_resolving() -> void:
	var u = main_scene.state.current_actor
	# Planta um inimigo bem do lado pra garantir alcance de arma corpo a corpo.
	var target = main_scene.state.opposing_team_of(u)[0]
	target["x"] = u["x"] + 1
	target["y"] = u["y"]
	target["hp"] = target["maxHp"]

	var weapon = (u["weapons"] as Array)[0]
	main_scene._select_attack_item(weapon)
	assert_eq(main_scene.mode, "attack")
	assert_true(main_scene.attackable_units.has(target))

	var hp_before: int = target["hp"]
	main_scene._handle_tile_click(target["x"], target["y"])
	assert_true(main_scene._confirm_panel.visible, "clicar no alvo abre a confirmação em vez de atacar na hora")
	assert_true(main_scene._confirm_body_label.text.contains("%"), "corpo do popup mostra a chance de acerto")
	assert_eq(target["hp"], hp_before, "nada foi resolvido ainda, só a prévia")

	main_scene._on_confirm_ok_pressed()
	assert_false(main_scene._confirm_panel.visible)
	assert_eq(main_scene.mode, "idle", "resolveu e voltou pro modo ocioso")

## Pedido do usuário: dá pra atacar o Castelo/Montanha num alvo único
## mesmo sem ninguém em cima do tile (antes só dano em área alcançava a
## estrutura vazia) — clicando no tile vazio (atalho de modo ocioso), abre
## a mesma confirmação e o clique em "Atacar" de fato causa dano nela.
func test_attacking_an_empty_structure_tile_opens_confirmation_and_damages_it() -> void:
	var mountain = null
	for s in main_scene.state.structures:
		if s["type"] == "mountain":
			mountain = s
	assert_not_null(mountain, "Campo precisa ter a Montanha do inimigo")
	var hero = main_scene.state.team_units("player")[0]
	hero["hasMoved"] = false
	hero["hasActed"] = false
	var mountain_tile: Dictionary = mountain["tiles"][0]
	hero["x"] = mountain_tile["x"] + 1
	hero["y"] = mountain_tile["y"]
	main_scene.state.current_actor = hero
	main_scene._compute_current_targets()

	assert_null(main_scene.state.unit_at(mountain_tile["x"], mountain_tile["y"]), "tile precisa estar vazio")
	var hp_before: int = mountain["hp"]
	main_scene._handle_tile_click(mountain_tile["x"], mountain_tile["y"])
	assert_true(main_scene._confirm_panel.visible, "clicar na Montanha vazia abre a confirmação")
	assert_eq(mountain["hp"], hp_before, "nada foi resolvido ainda, só a prévia")

	main_scene._on_confirm_ok_pressed()
	assert_false(main_scene._confirm_panel.visible)
	assert_lt(mountain["hp"], hp_before, "a Montanha levou dano mesmo sem ninguém em cima dela")
	assert_true(hero["hasActed"], "atacar a estrutura consome a ação")

## Acha um herói do time do jogador com alguma magia cujo targetMode exija
## confirmação em 2 cliques (AOE_CONFIRM_MODES) e o promove a current_actor,
## sem passar pelo fluxo normal de turno (só pra isolar o teste do popup).
func _find_aoe_caster_and_item() -> Array:
	for u in main_scene.state.units:
		if u["team"] != "player":
			continue
		for sp in (u["spells"] as Array):
			if main_scene.AOE_CONFIRM_MODES.has(sp.get("targetMode", "")):
				return [u, sp]
	return [null, null]

func test_selecting_an_area_spell_previews_before_a_second_click_confirms() -> void:
	var found := _find_aoe_caster_and_item()
	var caster: Dictionary = found[0]
	var item: Dictionary = found[1]
	assert_not_null(caster, "espera pelo menos um herói com magia de área (ex: Bola de Fogo do Mago)")

	caster["hasMoved"] = false
	caster["hasActed"] = false
	caster["mp"] = 99
	main_scene.state.current_actor = caster

	main_scene._select_spell_item(item)
	assert_eq(main_scene.mode, "spell")
	assert_true(main_scene.spell_tiles.size() > 0)

	var target_tile = main_scene.spell_tiles[0]
	var log_size_before: int = main_scene.state.event_log.size()

	main_scene._handle_tile_click(target_tile["x"], target_tile["y"])
	assert_not_null(main_scene.aoe_preview_target, "primeiro clique só acende a prévia da área")
	assert_false(main_scene._confirm_panel.visible, "ainda não abriu o popup de confirmação")
	assert_eq(main_scene.state.event_log.size(), log_size_before, "nada foi lançado só com a prévia")

	main_scene._handle_tile_click(target_tile["x"], target_tile["y"])
	assert_true(main_scene._confirm_panel.visible, "segundo clique no MESMO alvo abre a confirmação")
	assert_true(main_scene.pending_confirm_action.is_valid())

	main_scene._on_confirm_ok_pressed()
	assert_false(main_scene._confirm_panel.visible)
	assert_eq(main_scene.mode, "idle")
	assert_true(main_scene.state.event_log.size() > log_size_before, "confirmar de fato lança a magia")

func test_canceling_the_area_spell_confirmation_does_not_cast_it() -> void:
	var found := _find_aoe_caster_and_item()
	var caster: Dictionary = found[0]
	var item: Dictionary = found[1]
	caster["hasMoved"] = false
	caster["hasActed"] = false
	caster["mp"] = 99
	main_scene.state.current_actor = caster

	main_scene._select_spell_item(item)
	var target_tile = main_scene.spell_tiles[0]
	main_scene._handle_tile_click(target_tile["x"], target_tile["y"])
	main_scene._handle_tile_click(target_tile["x"], target_tile["y"])
	assert_true(main_scene._confirm_panel.visible)

	var log_size_before: int = main_scene.state.event_log.size()
	main_scene._close_confirm_panel()
	assert_false(main_scene._confirm_panel.visible)
	assert_eq(main_scene.state.event_log.size(), log_size_before, "cancelar não lança a magia")

## Acha, em qualquer unidade, uma arma OU magia com `cardinalOnly: true`
## (ex: Arremessar Espada do Guerreiro, Raio de Gelo do Mago) e devolve
## [unidade, item, "weapon"/"spell"].
func _find_cardinal_only_item() -> Array:
	for u in main_scene.state.units:
		for w in (u.get("weapons", []) as Array):
			if w.get("cardinalOnly", false):
				return [u, w, "weapon"]
		for s in (u.get("spells", []) as Array):
			if s.get("cardinalOnly", false) and s.get("targetMode", "") == "enemy":
				return [u, s, "spell"]
	return [null, null, ""]

## Regressão: a mira de um item `cardinalOnly` (ex: Arremessar Espada) não
## pode incluir tiles fora das 4 direções retas a partir de quem conjura —
## antes desta correção, o menu de magia usava o mesmo diamante de
## compute_range_tiles pra qualquer item, deixando mirar na diagonal um
## item cuja receita diz "só nas 4 direções cardeais".
func test_selecting_a_cardinal_only_spell_only_targets_straight_directions() -> void:
	var found := _find_cardinal_only_item()
	var caster: Dictionary = found[0]
	var item: Dictionary = found[1]
	var kind: String = found[2]
	assert_eq(kind, "spell", "espera achar um item cardinalOnly do tipo magia (ex: Arremessar Espada)")

	caster["hasMoved"] = false
	caster["hasActed"] = false
	caster["mp"] = 99
	main_scene.state.current_actor = caster

	main_scene._select_spell_item(item)
	assert_true(main_scene.spell_tiles.size() > 0)
	for t in main_scene.spell_tiles:
		var same_row: bool = t["x"] == caster["x"]
		var same_col: bool = t["y"] == caster["y"]
		assert_true(same_row or same_col, "tile (%d,%d) fora das 4 direções cardeais a partir de (%d,%d)" % [t["x"], t["y"], caster["x"], caster["y"]])

## Mesma regressão, mas pelo lado da arma (ex: Raio de Gelo do Mago,
## `targetMode` "enemy" implícito): um inimigo fora do eixo cardeal, mesmo
## dentro do alcance em distância Manhattan, não pode aparecer como alvo
## atacável.
func test_selecting_a_cardinal_only_weapon_excludes_diagonal_enemies() -> void:
	var caster = null
	var item: Dictionary = {}
	for u in main_scene.state.units:
		for w in (u.get("weapons", []) as Array):
			if w.get("cardinalOnly", false):
				caster = u
				item = w
				break
		if caster != null:
			break
	assert_not_null(caster, "espera achar uma arma cardinalOnly (ex: Raio de Gelo do Mago)")

	caster["hasMoved"] = false
	caster["hasActed"] = false
	main_scene.state.current_actor = caster

	var target = main_scene.state.opposing_team_of(caster)[0]
	target["hp"] = target["maxHp"]
	target["x"] = caster["x"] + 1
	target["y"] = caster["y"] + 1 # diagonal — fora do eixo cardeal

	main_scene._select_attack_item(item)
	assert_false(main_scene.attackable_units.has(target), "inimigo na diagonal não pode ser alvo de arma cardinalOnly")

	target["x"] = caster["x"]
	target["y"] = caster["y"] + 1 # mesma coluna — no eixo cardeal
	main_scene._select_attack_item(item)
	assert_true(main_scene.attackable_units.has(target), "inimigo na mesma linha/coluna deve continuar sendo alvo válido")

## Quando o time inimigo é humano, as armas de área do Troll precisam
## entrar no fluxo de dois cliques; o fluxo antigo as tratava como ataque
## básico e acertava somente a unidade clicada.
func test_selecting_troll_area_weapons_uses_area_targeting_flow() -> void:
	var troll: Dictionary = main_scene.state.unit("troll")
	troll["hasMoved"] = false
	troll["hasActed"] = false
	main_scene.state.current_actor = troll

	for weapon in (troll["weapons"] as Array):
		assert_true(main_scene.AOE_CONFIRM_MODES.has(weapon.get("targetMode", "")))
		main_scene._select_attack_item(weapon)
		assert_eq(main_scene.mode, "spell", "%s deve usar o modo de mira de área" % weapon["name"])
		assert_eq(main_scene.pending_item, weapon)
		assert_true(main_scene.spell_tiles.size() > 0, "%s deve oferecer tiles de mira" % weapon["name"])
		assert_true(main_scene.attackable_units.is_empty())
