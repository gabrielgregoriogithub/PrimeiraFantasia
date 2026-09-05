extends GutTest

func _floor_state(unlocked: bool = false, party: Array = []) -> GameState:
	var state := GameState.new()
	state.configure_campaign(unlocked, party)
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_2))
	return state

func test_locked_bard_appears_caged_on_a_valid_reachable_random_floor_tile() -> void:
	var state := _floor_state()
	var bard: Dictionary = state.unit("bardo")
	assert_true(bard.get("caged", false))
	assert_eq(bard["ct"], 0)
	assert_false(state.advance_ct_until_ready() == bard, "a gaiola exclui o Bardo da fila e do combate")
	var floor := ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_2)
	var key := state.tile_key(bard["x"], bard["y"])
	assert_false(floor["player_spawns"].any(func(tile): return state.tile_key(tile["x"], tile["y"]) == key))
	assert_false(floor["doors"].any(func(tile): return state.tile_key(tile["x"], tile["y"]) == key))
	assert_ne(key, state.tile_key(floor["entrance_tile"]["x"], floor["entrance_tile"]["y"]))
	assert_ne(key, state.tile_key(floor["exit_tile"]["x"], floor["exit_tile"]["y"]))
	var terrain = state.terrain_at(bard["x"], bard["y"])
	assert_true(terrain == null or (not BoardLayout.BLOCKING_TERRAIN_TYPES.has(terrain.get("type", "")) and terrain.get("hazard", "") == ""))
	for enemy in state.team_units("enemy"):
		assert_false(enemy["x"] == bard["x"] and enemy["y"] == bard["y"])

func test_bard_cage_position_varies_between_campaign_seeds() -> void:
	var positions := {}
	for seed_value in range(1, 9):
		var state := GameState.new()
		state.rng.seed = seed_value
		state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_2))
		var bard := state.unit("bardo")
		positions[state.tile_key(bard["x"], bard["y"])] = true
	assert_gt(positions.size(), 1, "a posição não deve ficar fixa entre partidas")

func test_cardinal_end_turn_releases_bard_and_unlocks_him() -> void:
	var state := _floor_state()
	var bard := state.unit("bardo")
	var rescuer: Dictionary = state.team_units("player").filter(func(unit): return unit != bard)[0]
	var adjacent := []
	for delta in [[1,0],[-1,0],[0,1],[0,-1]]:
		var x: int = bard["x"] + delta[0]
		var y: int = bard["y"] + delta[1]
		if state.in_bounds(x, y) and state.occupant_at(x, y) == null:
			var terrain = state.terrain_at(x, y)
			if terrain == null or (not BoardLayout.BLOCKING_TERRAIN_TYPES.has(terrain.get("type", "")) and terrain.get("hazard", "") == ""):
				adjacent = [x, y]
				break
	assert_false(adjacent.is_empty(), "a gaiola sempre precisa ter acesso cardinal")
	rescuer["x"] = adjacent[0]
	rescuer["y"] = adjacent[1]
	state._check_cage_release(rescuer)
	assert_false(bard.get("caged", false))
	assert_true(state.campaign_bardo_unlocked)
	assert_eq(bard["ct"], 80)
	assert_eq(bard["hp"], bard["maxHp"])
	assert_eq(bard["mp"], bard["maxMp"])
	assert_eq(state.cage_release_events[-1]["message"], "Bardo entrou para o grupo!")
	assert_eq(state.team_units("player").size(), 6)

func test_unlocked_campaign_never_recreates_bard_cage_on_floor_two() -> void:
	var state := _floor_state(true)
	assert_false(state.unit("bardo").get("caged", false))
	assert_eq(state.team_units("player").size(), 6)

func test_future_floor_instantiates_only_the_five_selected_heroes() -> void:
	var selected := ["guerreiro", "arqueiro", "ladino", "quimico", "bardo"]
	var state := GameState.new()
	state.configure_campaign(true, selected)
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_3))
	var active_keys := state.team_units("player").map(func(unit): return unit.get("spriteKey", ""))
	assert_eq(active_keys.size(), 5)
	for key in selected: assert_true(active_keys.has(key))
	assert_false(active_keys.has("mago"))
	assert_false(state.units.any(func(unit): return unit.get("spriteKey", "") == "mago"), "não selecionado não existe no combate")

func test_bard_is_absent_before_unlock_outside_floor_two() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_3))
	assert_false(state.units.any(func(unit): return unit.get("spriteKey", "") == "bardo"))
	assert_eq(state.team_units("player").size(), 5)

func test_bard_never_appears_in_field_horde_or_first_tower_even_after_unlock() -> void:
	for scenario_id in [ScenarioManager.FIELD, ScenarioManager.LUA_VALLEY, ScenarioManager.TOWER]:
		var state := GameState.new()
		state.configure_campaign(true, ["guerreiro", "arqueiro", "mago", "ladino", "bardo"])
		state.apply_scenario(ScenarioManager.definition(scenario_id))
		assert_false(state.units.any(func(unit): return unit.get("spriteKey", "") == "bardo"), "%s não pode conter o Bardo" % scenario_id)

func test_campaign_progress_persists_unlock_and_party_selection() -> void:
	var save_path := "res://test_bard_campaign_progress.tmp.cfg"
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main)
	await wait_process_frames(1)
	main.bardo_unlocked = true
	main.selected_party_keys = ["guerreiro", "arqueiro", "ladino", "quimico", "bardo"]
	assert_eq(main._save_campaign_progress(save_path), OK)
	main.bardo_unlocked = false
	main.selected_party_keys = []
	main._load_campaign_progress(save_path)
	assert_true(main.bardo_unlocked)
	assert_eq(main.selected_party_keys.size(), 5)
	assert_true(main.selected_party_keys.has("bardo"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func test_party_selection_is_dynamic_requires_exactly_five_and_retains_inspection_state() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main)
	await wait_process_frames(1)
	main.bardo_unlocked = true
	main.selected_party_keys = []
	main._show_party_selection()
	assert_eq(main._party_card_buttons.size(), 6)
	assert_eq(main.selected_party_keys.size(), 5)
	assert_false(main._party_selection_confirm.disabled)
	var retained: Array = main.selected_party_keys.duplicate()
	main._toggle_party_hero(retained[0])
	assert_eq(main._party_selection_counter.text, "Selecionados: 4/5")
	assert_true(main._party_selection_confirm.disabled)
	main._toggle_party_hero(retained[0])
	main._view_party_hero("bardo")
	assert_false(main._party_selection_panel.visible)
	assert_true(main._unit_info_panel.visible)
	main._close_unit_info()
	assert_true(main._party_selection_panel.visible)
	assert_eq(main.selected_party_keys.size(), retained.size())
	for key in retained: assert_true(main.selected_party_keys.has(key))
