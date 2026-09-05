extends GutTest

func test_floor_3_definition_is_modular_and_prepares_floor_4() -> void:
	var floor := ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_3)
	assert_eq(floor["name"], "3º ANDAR")
	assert_eq(floor["floor_number"], 3)
	assert_eq(floor["next_floor_id"], "tower_floor_4")
	assert_gt(floor["walls"].size(), 50)
	# Reforma pedida pelo usuário: mesmo número de portas do 1º Andar (4),
	# em vez do labirinto de salas pequenas de antes (que tinha 8).
	assert_gte(floor["doors"].size(), 4)
	assert_gt(floor["lava"].size(), 5)
	assert_lt(floor["lava"].size(), 30, "lava ocupa somente áreas estratégicas")

func test_floor_3_entrance_and_exit_are_connected() -> void:
	var state := GameState.new()
	var floor := ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_3)
	state.apply_scenario(floor)
	var hero: Dictionary = state.team_units("player")[0]
	state.units = [hero]
	hero["x"] = floor["entrance_tile"]["x"]
	hero["y"] = floor["entrance_tile"]["y"]
	hero["moveRange"] = 100
	var reachable := state.compute_reachable(hero)
	assert_true(reachable.any(func(tile): return tile["x"] == floor["exit_tile"]["x"] and tile["y"] == floor["exit_tile"]["y"]))

func test_lava_is_walkable_but_costs_three_movement() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_3))
	# Reforma pedida pelo usuário: lava agora em poças (DungeonFloor3Layout),
	# não mais um traçado fixo passando por (5,3) — (2,3) é canto do bloco
	# de 4 tiles perto da entrada.
	var lava = state.terrain_at(2, 3)
	assert_eq(lava["type"], "hazard")
	assert_eq(lava["hazard"], "lava")
	assert_false(BoardLayout.BLOCKING_TERRAIN_TYPES.has(lava["type"]))
	assert_eq(state.step_cost(state.team_units("player")[0], 2, 3), 3)

func test_each_crossed_lava_tile_deals_exactly_one_damage() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_3))
	var hero: Dictionary = state.team_units("player")[0]
	var hp_before: int = hero["hp"]
	state.apply_trap_crossings(hero, [{"x":2,"y":3},{"x":3,"y":3},{"x":3,"y":4}])
	assert_eq(hero["hp"], hp_before - 3)

func test_lava_damage_also_applies_to_flying_characters() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_3))
	var hero: Dictionary = state.team_units("player")[0]
	hero["flying"] = true
	var hp_before: int = hero["hp"]
	state.apply_trap_crossings(hero, [{"x":2,"y":3},{"x":3,"y":3}])
	assert_eq(hero["hp"], hp_before - 2)

func test_ending_turn_on_lava_reuses_burned_status() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_3))
	var hero: Dictionary = state.team_units("player")[0]
	hero["x"] = 2
	hero["y"] = 3
	state._apply_end_turn_tile_hazard(hero)
	assert_true(hero["statusEffects"].any(func(effect): return effect["type"] == "burned"))

## Pedido do usuário: personagem de fogo (corpo normal 1x1) que termina o
## turno sobre lava cura sempre exatamente 1 HP, sem variação nem escala por
## quantidade de lava sob o corpo (diferente da Salamandra, ver floor_4).
func test_fire_enemy_ending_turn_on_lava_always_heals_exactly_one_hp() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_3))
	var living_fire: Dictionary = state.team_units("enemy").filter(func(u): return u["spriteKey"] == "tower_living_fire")[0]
	living_fire["hp"] = 10
	living_fire["x"] = 2
	living_fire["y"] = 3
	state._apply_end_turn_tile_hazard(living_fire)
	assert_eq(living_fire["hp"], 11)
	assert_false(living_fire["statusEffects"].any(func(effect): return effect["type"] == "burned"))

func test_progression_runs_floor_2_floor_3_then_floor_4() -> void:
	var manager: Node = autofree(ScenarioManager.new())
	assert_eq(manager.next_id(ScenarioManager.TOWER_FLOOR_2), ScenarioManager.TOWER_FLOOR_3)
	assert_eq(manager.next_id(ScenarioManager.TOWER_FLOOR_3), ScenarioManager.TOWER_FLOOR_4)
