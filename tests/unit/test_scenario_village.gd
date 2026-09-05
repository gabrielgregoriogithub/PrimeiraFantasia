extends GutTest

func test_village_definition_has_requested_layout() -> void:
	var village := ScenarioManager.definition(ScenarioManager.VILLAGE)
	assert_eq(village["name"], "VILA")
	assert_gt(village["dirt"].size(), 20)
	assert_gt(village["water"].size(), 0)
	assert_gte(village["buildings"].filter(func(b): return b["kind"] == "village-house").size(), 3)
	assert_eq(village["buildings"].filter(func(b): return b["kind"] == "village-mill").size(), 1)
	assert_eq(village["archer_reinforcement"], {"turn":4,"x":6,"y":2,"ct":80})
	assert_eq(village["goblin_reinforcement"], {"turn":6,"x":9,"y":8,"ct":80})

## O Arqueiro já nasce em campo (caído perto da casa em chamas — ver
## GameState._setup_village) em vez de aparecer do nada no turno 4; por
## isso a contagem já inclui ele desde o início. team_units() não filtra por
## hp (ver GameState.team_units), então ele já aparece no time do jogador
## ali — a diferença de "ainda não é um herói vivo" mora em alive_units()/
## hp, testado abaixo.
func test_village_starts_with_warrior_one_troll_and_a_downed_archer() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.VILLAGE))
	assert_eq(state.units.size(), 3)
	assert_eq(state.team_units("player").map(func(u): return u["name"]), ["Guerreiro", "Arqueiro"])
	assert_eq(state.alive_units().map(func(u): return u["name"]), ["Guerreiro", "Troll"], "Arqueiro caído não conta como vivo ainda")
	assert_eq(state.team_units("enemy").size(), 1)
	assert_true(state.units_by_key.has("troll_1"))
	var archer: Dictionary = state.unit("arqueiro")
	assert_eq(archer["hp"], 0)
	assert_true(archer.get("scriptedRevive", false))
	assert_eq(Vector2i(archer["x"], archer["y"]), Vector2i(6, 2))

## Regressão: finalize_death_if_needed() roda pra QUALQUER unidade com hp<=0
## e sem "turnsSinceDeath" (é assim que um cadáver normal recém-morto ganha
## o contador de decomposição) — sem a trava "_deathHandled" pré-marcada em
## _setup_village(), o Arqueiro caído cairia nesse mesmo caminho no primeiro
## _sync_visuals() e viraria uma alma (ver IMMEDIATE_SOUL_SPRITE_KEYS/
## apply_corpse_decay_tick) bem antes do turno 4 do reforço.
func test_downed_archer_never_gets_turnsSinceDeath_before_reviving() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.VILLAGE))
	var archer: Dictionary = state.unit("arqueiro")
	for u in state.units:
		state.finalize_death_if_needed(u)
	assert_false(archer.has("turnsSinceDeath"), "Arqueiro caído não deve virar cadáver decaível")
	for round in range(5):
		state.advance_corpse_decay_for_round()
	assert_eq(archer["hp"], 0, "continua caído, não virou alma nem foi removido")
	assert_eq(state.occupant_at(6, 2)["name"], "Arqueiro")

func test_archer_revives_once_on_turn_four_with_full_hp_mp_and_80_ct() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.VILLAGE))
	var archer: Dictionary = state.unit("arqueiro")
	var unit_count := state.units.size()
	for turn in range(1, 4):
		state.global_turn_count = turn
		state.maybe_revive_village_archer()
		assert_eq(archer["hp"], 0, "turno %d ainda não é o turno do reforço" % turn)
	state.global_turn_count = 4
	state.maybe_revive_village_archer()
	assert_eq(state.units.size(), unit_count, "revive a unidade existente, não cria outra")
	assert_eq(archer["hp"], archer["maxHp"])
	assert_eq(archer["mp"], archer["maxMp"])
	assert_eq(archer["ct"], 80)
	assert_false(archer.has("scriptedRevive"))
	var hp_after_revive: int = archer["hp"]
	state.maybe_revive_village_archer()
	assert_eq(archer["hp"], hp_after_revive, "não reaplica o reforço de novo")

func test_village_water_and_buildings_are_functional_terrain() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.VILLAGE))
	assert_eq(state.terrain_at(11, 0)["type"], "water")
	assert_eq(state.terrain_at(1, 1)["type"], "village-building")
	assert_true(BoardLayout.BLOCKING_TERRAIN_TYPES.has("village-building"))
	assert_eq(state.occupant_at(6, 2)["name"], "Arqueiro", "corpo do Arqueiro já ocupa a entrada desde o início")

func test_goblin_reinforcement_arrives_alone_on_turn_six() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.VILLAGE))
	for turn in range(1, 6):
		state.global_turn_count = turn
		state.maybe_spawn_village_goblin()
		assert_false(state.units_by_key.has("goblin_2"))
	state.global_turn_count = 6
	state.maybe_spawn_village_goblin()
	assert_true(state.units_by_key.has("goblin_2"))
	var goblin: Dictionary = state.unit("goblin_2")
	assert_eq(Vector2i(goblin["x"], goblin["y"]), Vector2i(9, 8))
	assert_eq(goblin["ct"], 80)
	var enemy_names := state.team_units("enemy").map(func(u): return u["name"])
	assert_true(enemy_names.has("Goblin"))
	assert_false(enemy_names.has("Rato da Vila"), "não traz mais Rato na Vila")
	assert_false(enemy_names.has("Cobra da Vila"), "não traz mais Cobra na Vila")
	assert_eq(enemy_names.size(), 2, "inimigos da Vila são apenas Troll e Goblin")
	var count := state.units.size()
	state.maybe_spawn_village_goblin()
	assert_eq(state.units.size(), count, "não spawna de novo")

func test_phase_order_puts_village_first_and_forest_right_after() -> void:
	var manager = autofree(ScenarioManager.new())
	assert_eq(manager.next_id(ScenarioManager.TOWER), ScenarioManager.TOWER_FLOOR_2)
	assert_eq(manager.next_id(ScenarioManager.TOWER_FLOOR_2), ScenarioManager.TOWER_FLOOR_3)
	assert_eq(manager.next_id(ScenarioManager.TOWER_FLOOR_3), ScenarioManager.TOWER_FLOOR_4)
	assert_eq(manager.next_id(ScenarioManager.VILLAGE), ScenarioManager.FOREST)

