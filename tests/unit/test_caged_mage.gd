extends GutTest

## Maga presa no Campo: começa numa gaiola do lado inimigo, imóvel, imune a
## dano e fora da fila de turnos até um herói encerrar o turno numa das 4
## direções cardeais da gaiola (ver GameState._setup_caged_mage/
## _check_cage_release/_release_caged_mage, autoload/game_state.gd).

func _field_state() -> GameState:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.FIELD))
	return state

func test_field_scenario_starts_the_mage_caged_on_the_enemy_side_immobile() -> void:
	var state := _field_state()
	var maga := state.unit(GameState.CAGED_MAGE_KEY)
	assert_true(maga.get("caged", false))
	assert_eq(maga["x"], GameState.CAGED_MAGE_TILE["x"])
	assert_eq(maga["y"], GameState.CAGED_MAGE_TILE["y"])
	assert_eq(maga["team"], "player", "continua herói, só está presa")
	assert_true(maga["hasMoved"])
	assert_true(maga["hasActed"])
	assert_eq(maga["ct"], 0)

func test_other_scenarios_never_cage_the_mage() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER))
	# A Torre/Horda reconstroem units_by_key pelo "name" (capitalizado),
	# não pela chave de template minúscula usada por _build_units() — busca
	# por spriteKey pra não depender dessa reindexação.
	var maga = state.units.filter(func(u): return u.get("spriteKey", "") == "mago")[0]
	assert_false(maga.get("caged", false))

func test_caged_mage_never_accumulates_ct_or_becomes_ready() -> void:
	var state := _field_state()
	var maga := state.unit(GameState.CAGED_MAGE_KEY)
	for i in 20:
		var ready := state.advance_ct_until_ready()
		assert_ne(ready["name"], maga["name"], "a Maga presa nunca deve ficar pronta pra agir")
		ready["ct"] = 0 # libera a próxima iteração pra outro membro do elenco
	assert_eq(maga["ct"], 0, "CT da Maga presa nunca anda")

func test_attacking_the_caged_mage_deals_no_damage_and_logs_immunity() -> void:
	var state := _field_state()
	var maga := state.unit(GameState.CAGED_MAGE_KEY)
	var attacker := state.unit("goblin")
	var weapon: Dictionary = attacker["weapons"][0]
	var hp_before: int = maga["hp"]
	var hit := state.resolve_single_hit(attacker, maga, weapon)
	assert_false(hit)
	assert_eq(maga["hp"], hp_before, "imune a qualquer dano enquanto presa")
	assert_true(String(state.event_log[-1]).contains("imune"))

func test_caged_mage_is_never_a_valid_opposing_target() -> void:
	var state := _field_state()
	var goblin := state.unit("goblin")
	var opponents := state.opposing_team_of(goblin)
	assert_false(opponents.any(func(u): return u["name"] == state.unit(GameState.CAGED_MAGE_KEY)["name"]), "IA inimiga nunca deveria mirar na gaiola")

func test_ending_a_hero_turn_in_any_cardinal_direction_releases_the_mage() -> void:
	# advance_to_next_turn() encadeia pro próximo pronto (ver seu docstring em
	# game_state.gd) — depois de libertada com CT 80 e velocidade 10, a Maga
	# frequentemente já é ELA MESMA a próxima pronta (80+10+10=100), então o
	# CT dela some 80 quase na mesma chamada. Por isso o release em si (CT 80
	# exato) é checado chamando _check_cage_release() direto, isolado da
	# corrida de CT que vem depois — a corrida de CT já tem cobertura própria
	# em test_game_state_turns.gd.
	var offsets := [[1, 0], [-1, 0], [0, 1], [0, -1]]
	for offset in offsets:
		var state := _field_state()
		var maga := state.unit(GameState.CAGED_MAGE_KEY)
		var hero := state.unit("guerreiro")
		hero["x"] = maga["x"] + offset[0]
		hero["y"] = maga["y"] + offset[1]
		state._check_cage_release(hero)
		assert_false(maga.get("caged", false), "direção %s deveria libertar a Maga" % [offset])
		assert_eq(maga["ct"], 80)
		assert_eq(maga["hp"], maga["maxHp"])
		assert_eq(maga["mp"], maga["maxMp"])
		assert_eq(state.cage_release_events.size(), 1)
		assert_eq(state.cage_release_events[0]["name"], maga["name"])

func test_advance_to_next_turn_actually_releases_the_mage_when_a_hero_ends_beside_the_cage() -> void:
	var state := _field_state()
	var maga := state.unit(GameState.CAGED_MAGE_KEY)
	var hero := state.unit("guerreiro")
	hero["x"] = maga["x"] + 1
	hero["y"] = maga["y"]
	hero["hasMoved"] = false
	hero["hasActed"] = false
	state.current_actor = hero
	state.advance_to_next_turn()
	assert_false(maga.get("caged", false), "o fluxo público de fim de turno também deve libertar")
	assert_eq(maga["hp"], maga["maxHp"])
	assert_eq(maga["mp"], maga["maxMp"])
	assert_gte(maga["ct"], 80, "CT nunca cai abaixo dos 80 da libertação")

func test_ending_a_hero_turn_diagonally_or_far_away_does_not_release_the_mage() -> void:
	for offset in [[1, 1], [-1, -1], [3, 0], [0, 5]]:
		var state := _field_state()
		var maga := state.unit(GameState.CAGED_MAGE_KEY)
		var hero := state.unit("guerreiro")
		hero["x"] = maga["x"] + offset[0]
		hero["y"] = maga["y"] + offset[1]
		hero["hasMoved"] = false
		hero["hasActed"] = false
		state.current_actor = hero
		state.advance_to_next_turn()
		assert_true(maga.get("caged", false), "offset %s não é cardeal, não deveria libertar" % [offset])
		assert_true(state.cage_release_events.is_empty())

func test_ending_an_enemy_turn_beside_the_cage_does_not_release_the_mage() -> void:
	var state := _field_state()
	var maga := state.unit(GameState.CAGED_MAGE_KEY)
	var goblin := state.unit("goblin")
	goblin["x"] = maga["x"] + 1
	goblin["y"] = maga["y"]
	goblin["hasMoved"] = false
	goblin["hasActed"] = false
	state.current_actor = goblin
	state.advance_to_next_turn()
	assert_true(maga.get("caged", false), "só um herói ('team' player) liberta a Maga")

func test_check_battle_outcome_ignores_the_caged_mage_for_player_alive() -> void:
	var state := _field_state()
	for hero_key in ["guerreiro", "arqueiro", "ladino", "quimico"]:
		state.unit(hero_key)["hp"] = 0
	assert_true(state.check_battle_outcome())
	assert_true(String(state.event_log[-1]).contains("Derrota"), "a Maga presa não deveria manter o time 'vivo'")
