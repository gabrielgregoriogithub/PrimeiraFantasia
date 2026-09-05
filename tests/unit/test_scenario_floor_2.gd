extends GutTest

func test_floor_2_is_a_distinct_modular_dungeon_definition() -> void:
	var floor := ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_2)
	assert_eq(floor["name"], "2º ANDAR")
	assert_eq(floor["floor_number"], 2)
	assert_eq(floor["theme"], "sewers")
	assert_eq(floor["entrance_tile"], {"x":1,"y":11})
	assert_eq(floor["exit_tile"], {"x":11,"y":11})
	assert_eq(floor["next_floor_id"], "tower_floor_3", "estrutura preparada sem criar o 3º Andar")
	assert_gt(floor["walls"].size(), 50)
	# Reforma pedida pelo usuário: menos paredes internas, salas maiores —
	# 2 salas grandes conectadas por uma parede com 4 portas, mesmo número
	# de portas do 1º Andar (mesma linguagem visual/mecânica), em vez do
	# labirinto de salas pequenas de antes (que tinha 8).
	assert_gte(floor["doors"].size(), 4)

func test_floor_2_entrance_connects_to_exit_through_walkable_rooms_and_doors() -> void:
	var state := GameState.new()
	var floor := ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_2)
	state.apply_scenario(floor)
	var hero: Dictionary = state.team_units("player")[0]
	state.units = [hero]
	hero["x"] = floor["entrance_tile"]["x"]
	hero["y"] = floor["entrance_tile"]["y"]
	hero["moveRange"] = 100
	var reachable := state.compute_reachable(hero)
	assert_true(reachable.any(func(tile): return tile["x"] == floor["exit_tile"]["x"] and tile["y"] == floor["exit_tile"]["y"]), "entrada e saída pertencem à mesma rede de salas/corredores")

func test_floor_2_spawns_both_teams_only_on_walkable_unique_tiles() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_2))
	assert_eq(state.team_units("player").size(), 6)
	assert_eq(state.team_units("enemy").size(), 5, "pedido do usuário: 1 Zumbi, 1 Esqueleto, 1 Fantasma, 1 Lich, 1 Vampiro")
	var occupied := {}
	for unit in state.units:
		var key := state.tile_key(unit["x"], unit["y"])
		assert_false(occupied.has(key), "spawn não sobrepõe outra unidade")
		occupied[key] = true
		var terrain = state.terrain_at(unit["x"], unit["y"])
		assert_true(terrain == null or not BoardLayout.BLOCKING_TERRAIN_TYPES.has(terrain.get("type", "")))

func test_progression_places_floor_2_after_floor_1() -> void:
	var manager: Node = autofree(ScenarioManager.new())
	assert_eq(manager.next_id(ScenarioManager.TOWER), ScenarioManager.TOWER_FLOOR_2)
	assert_eq(manager.next_id(ScenarioManager.TOWER_FLOOR_2), ScenarioManager.TOWER_FLOOR_3)
