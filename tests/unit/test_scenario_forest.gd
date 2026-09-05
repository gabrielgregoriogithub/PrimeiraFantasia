extends GutTest

func test_forest_definition_has_a_3_wide_path_crossing_bottom_to_top() -> void:
	var forest := ScenarioManager.definition(ScenarioManager.FOREST)
	assert_eq(forest["name"], "FLORESTA")
	var path: Array = forest["path"]
	assert_eq(path.size(), 13 * 3, "trilha de 3 colunas x 13 linhas")
	for tile in path:
		assert_true(int(tile["x"]) in [5, 6, 7], "trilha fica só nas colunas 5-7")
	# A trilha cobre as 13 linhas inteiras, de baixo (y=12) pra cima (y=0).
	var rows_covered := {}
	for tile in path:
		rows_covered[int(tile["y"])] = true
	assert_eq(rows_covered.size(), 13)
	assert_eq(forest["chemist_reinforcement"], {"turn":8,"x":6,"y":12,"ct":80})
	assert_eq(forest["shaman_reinforcement"], {"turn":10,"x":6,"y":6,"ct":80})

func test_forest_trees_fill_the_sides_but_never_the_path_columns() -> void:
	var forest := ScenarioManager.definition(ScenarioManager.FOREST)
	var trees: Array = forest["trees"]
	assert_gt(trees.size(), 100, "cheio de árvores dos dois lados")
	var allowed_arts := ["tree1.png", "tree2.png", "tree3.png", "tree4.png", "tree5.png"]
	for tree in trees:
		assert_false(int(tree["x"]) in [5, 6, 7], "árvore não pode nascer em cima da trilha")
		assert_true(String(tree["art"]) in allowed_arts, "arte precisa ser a mesma árvore usada no Campo")

func test_forest_starts_with_ladino_at_the_bottom_and_orc_at_the_top() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.FOREST))
	assert_eq(state.units.size(), 2)
	assert_eq(state.team_units("player").map(func(u): return u["name"]), ["Ladino"])
	assert_eq(state.team_units("enemy").map(func(u): return u["name"]), ["Orc"])
	var ladino: Dictionary = state.unit("ladino")
	var orc: Dictionary = state.unit("orc")
	assert_eq(Vector2i(ladino["x"], ladino["y"]), Vector2i(6, 11))
	assert_eq(Vector2i(orc["x"], orc["y"]), Vector2i(6, 1))
	assert_true(ladino["y"] > orc["y"], "Ladino fica na parte de baixo, Orc na parte de cima")

func test_forest_trees_are_real_blocking_destructible_terrain() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.FOREST))
	# (0,0) não é trilha e passa pela fórmula de clareira determinística —
	# confere se pelo menos um desses dois é uma árvore de verdade.
	var sample_tile := {"x":0, "y":1}
	var terrain = state.terrain_at(sample_tile["x"], sample_tile["y"])
	assert_not_null(terrain, "coluna fora da trilha deveria ter árvore")
	assert_eq(terrain["type"], "tree")
	assert_true(BoardLayout.BLOCKING_TERRAIN_TYPES.has("tree"))
	assert_eq(terrain["hp"], GameConstants.TREE_MAX_HP)
	# Trilha (coluna 6) sempre livre de terreno.
	assert_null(state.terrain_at(6, 5))

func test_chemist_arrives_once_on_turn_eight_at_the_bottom_with_80_ct() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.FOREST))
	for turn in range(1, 8):
		state.global_turn_count = turn
		state.maybe_spawn_forest_chemist()
		assert_false(state.units_by_key.has("quimico"))
	state.global_turn_count = 8
	state.maybe_spawn_forest_chemist()
	assert_true(state.units_by_key.has("quimico"))
	var chemist: Dictionary = state.unit("quimico")
	assert_eq(Vector2i(chemist["x"], chemist["y"]), Vector2i(6, 12), "entra pela parte de baixo, perto do Ladino")
	assert_eq(chemist["ct"], 80)
	assert_eq(chemist["hp"], chemist["maxHp"], "chega com status completos")
	assert_eq(chemist["mp"], chemist["maxMp"], "chega com status completos")
	var count := state.units.size()
	state.maybe_spawn_forest_chemist()
	assert_eq(state.units.size(), count, "não spawna de novo")

func test_shaman_arrives_alone_on_turn_ten_on_the_trail() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.FOREST))
	for turn in range(1, 10):
		state.global_turn_count = turn
		state.maybe_spawn_forest_shaman()
		assert_false(state.units_by_key.has("xama"))
	state.global_turn_count = 10
	state.maybe_spawn_forest_shaman()
	assert_true(state.units_by_key.has("xama"))
	var shaman: Dictionary = state.unit("xama")
	assert_eq(Vector2i(shaman["x"], shaman["y"]), Vector2i(6, 6), "surge no meio da trilha")
	assert_true(shaman["x"] in [5, 6, 7], "surge em cima da trilha, como se tivesse saído do meio das árvores")
	assert_eq(shaman["ct"], 80)
	assert_eq(shaman["hp"], shaman["maxHp"], "chega com status completos")
	assert_eq(shaman["mp"], shaman["maxMp"], "chega com status completos")
	var enemy_names := state.team_units("enemy").map(func(u): return u["name"])
	assert_false(enemy_names.has("Slime da Floresta"), "não traz mais Slime na Floresta")
	assert_false(enemy_names.has("Gnoll da Floresta"), "não traz mais Gnoll na Floresta")
	assert_eq(enemy_names.size(), 2, "inimigos da Floresta são apenas Orc e Xamã")
	var count := state.units.size()
	state.maybe_spawn_forest_shaman()
	assert_eq(state.units.size(), count, "não spawna de novo")
