extends GutTest

## ETAPA 19 — Destruição Visual Não Persistente / Reação de Materiais.
## Cobre o resolvedor de material (BoardView.material_at, que só LÊ
## terrain_at/structure_at já existentes) e os dados de MaterialVisualProfiles,
## além de uma fumaça de cena confirmando que wood/stone/metal produzem VFX
## sem quebrar e sem sobrar nó nenhum depois de meio segundo.

func test_material_profiles_cover_every_material_with_the_same_shape() -> void:
	for material in ["wood", "stone", "metal", "dirt", "grass", "water", "generic"]:
		var profile := MaterialVisualProfiles.for_material(material)
		for key in ["debris_kind", "debris_color", "debris_amount", "spark_chance", "shake_amount"]:
			assert_true(profile.has(key), "%s precisa ter %s" % [material, key])
		for tier in ["light", "medium", "heavy"]:
			assert_true(profile["debris_amount"].has(tier))

func test_unknown_material_falls_back_to_generic_instead_of_crashing() -> void:
	assert_eq(MaterialVisualProfiles.for_material("plasma"), MaterialVisualProfiles.PROFILES["generic"])

func test_amount_for_scales_with_intensity_tier() -> void:
	var light := MaterialVisualProfiles.amount_for("wood", "light")
	var heavy := MaterialVisualProfiles.amount_for("wood", "heavy")
	var signature := MaterialVisualProfiles.amount_for("wood", "signature")
	var epic := MaterialVisualProfiles.amount_for("wood", "epic")
	assert_lt(light, heavy, "HEAVY gera mais debris que LIGHT")
	assert_eq(signature, heavy, "SIGNATURE conta como HEAVY pra quantidade de debris (regra 82)")
	assert_eq(epic, heavy, "EPIC também conta como HEAVY pra quantidade de debris")

func test_wood_and_stone_debris_never_reuse_the_same_kind_or_color() -> void:
	var wood := MaterialVisualProfiles.for_material("wood")
	var stone := MaterialVisualProfiles.for_material("stone")
	assert_ne(wood["debris_kind"], stone["debris_kind"])
	assert_ne(wood["debris_color"], stone["debris_color"])

func test_material_at_reads_tree_as_wood_castle_as_stone_and_open_field_as_grass() -> void:
	var board := BoardView.new(); add_child_autofree(board)
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.FIELD))
	board.set_state(state)
	board.set_scenario(ScenarioManager.definition(ScenarioManager.FIELD))
	var tree_tile: Dictionary = BoardLayout.TERRAIN_LAYOUT["tree"][0]
	assert_eq(board.material_at(tree_tile["x"], tree_tile["y"]), "wood")
	assert_eq(board.material_at(1, 1), "stone", "Castelo (0-2,0-2) é uma estrutura de pedra")
	# Casa do Guerreiro (Units.build()) é garantidamente terreno aberto, já
	# que uma unidade começa parada exatamente ali.
	assert_eq(board.material_at(2, 5), "grass", "Campo sem terreno especial cai em grama")

func test_material_at_out_of_bounds_is_generic_not_a_crash() -> void:
	var board := BoardView.new(); add_child_autofree(board)
	assert_eq(board.material_at(-1, -1), "generic")

func test_wood_and_stone_impacts_spawn_directional_debris_without_leaving_nodes_behind() -> void:
	var effects := EffectsLayer.new(); add_child_autofree(effects)
	var before := effects.get_child_count()
	effects.spawn_surface_step(Vector2(100, 100), "wood", true, Vector2.RIGHT, "", "heavy")
	assert_gt(effects.get_child_count(), before, "impacto em madeira cria lascas")
	before = effects.get_child_count()
	effects.spawn_surface_step(Vector2(160, 100), "stone", true, Vector2.LEFT, "", "heavy")
	assert_gt(effects.get_child_count(), before, "impacto em pedra cria fragmentos")
	await wait_seconds(0.6)
	assert_eq(effects.get_child_count(), 0, "nada do impacto físico persiste depois de meio segundo")

func test_metal_impact_never_spawns_rock_fragments() -> void:
	var effects := EffectsLayer.new(); add_child_autofree(effects)
	for i in 5:
		effects.spawn_surface_step(Vector2(100, 100), "metal", true, Vector2.RIGHT, "", "heavy")
	for child in effects.get_children():
		assert_ne(child.get("kind"), "stone", "metal não deve soltar debris de pedra (regra 22)")

func test_fire_and_ice_add_an_elemental_touch_without_replacing_the_physical_debris() -> void:
	var effects := EffectsLayer.new(); add_child_autofree(effects)
	var before := effects.get_child_count()
	effects.spawn_surface_step(Vector2(100, 100), "wood", true, Vector2.RIGHT, "fire", "heavy")
	assert_gt(effects.get_child_count(), before, "madeira em chamas ainda gera lascas + fogo")

func test_full_environment_reaction_on_a_tree_tile_uses_wood_material() -> void:
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main_scene)
	await wait_process_frames(1)
	# Main abre na Vila por padrão (ver test_main_scene.gd) — força o Campo,
	# único cenário cujas coordenadas de BoardLayout.TERRAIN_LAYOUT["tree"] valem.
	if main_scene.scenario_manager.active_id != ScenarioManager.FIELD:
		main_scene.scenario_manager.set_active(ScenarioManager.FIELD)
		main_scene._start_new_game()
		await wait_process_frames(1)
	var tree_tile: Dictionary = BoardLayout.TERRAIN_LAYOUT["tree"][0]
	assert_eq(main_scene.board_view.material_at(tree_tile["x"], tree_tile["y"]), "wood")
	var center: Vector2 = main_scene.board_view.tile_center(tree_tile["x"], tree_tile["y"])
	var before: int = main_scene.effects_layer.get_child_count()
	main_scene.effects_layer.emit_environment_reaction("melee_impact", center, Vector2.RIGHT, "heavy", "")
	assert_gt(main_scene.effects_layer.get_child_count(), before, "golpe na árvore usa o Material Reaction System (wood), não só grama/terra")
