extends GutTest

func _positions(state: GameState, team: String) -> Array:
	return state.team_units(team).map(func(unit: Dictionary): return Vector2i(unit["x"], unit["y"]))

func test_pvp_spawn_order_changes_between_consecutive_battles() -> void:
	var state := GameState.new()
	state.rng.seed = 12345
	var heroes := ["guerreiro", "arqueiro", "mago", "ladino", "quimico"]
	var monsters := ["goblin", "orc", "troll", "fada", "xama"]
	var scenario := ScenarioManager.definition(ScenarioManager.TOWER)
	state.apply_pvp_scenario(scenario, heroes, monsters)
	var first_players := _positions(state, "player")
	var first_enemies := _positions(state, "enemy")
	state.apply_pvp_scenario(scenario, heroes, monsters)
	assert_ne(_positions(state, "player"), first_players)
	assert_ne(_positions(state, "enemy"), first_enemies)

func test_field_pvp_spawns_start_on_the_fourth_row() -> void:
	var state := GameState.new()
	state.rng.seed = 54321
	state.apply_pvp_scenario(
		ScenarioManager.definition(ScenarioManager.FIELD),
		["guerreiro", "arqueiro", "mago", "ladino", "quimico"],
		["goblin", "orc", "troll", "fada", "xama"]
	)
	for unit in state.units:
		assert_gte(int(unit["y"]), 3, "%s deve nascer da quarta linha em diante" % unit["name"])
