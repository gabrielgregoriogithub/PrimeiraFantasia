extends GutTest

## Bug relatado pelo usuário: com todos os inimigos do 2º Andar a 0 HP —
## Zumbis ainda em contagem regressiva de auto-ressurreição (têm
## `resurrection`+`turnsSinceDeath`), Fantasma/Esqueleto já mortos de vez —
## a vitória não era declarada, porque check_battle_outcome() tratava um
## cadáver auto-revivível em contagem como "time ainda vivo". Um cadáver
## pendente de ressuscitar não deve mais segurar a vitória.
func test_check_battle_outcome_is_a_win_even_with_a_self_reviving_corpse_mid_countdown() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_2))
	for enemy in state.team_units("enemy"):
		enemy["hp"] = 0
		state.finalize_death_if_needed(enemy)
	var zombie: Dictionary = state.team_units("enemy").filter(func(u): return u["spriteKey"] == "tower_zombie")[0]
	assert_true(zombie.has("turnsSinceDeath"), "pré-condição: zumbi está em contagem regressiva, não perdeu o cadáver ainda")
	assert_true(state.check_battle_outcome())
	assert_true(state.battle_won, "todo o time inimigo a 0 HP já é vitória, mesmo com zumbi pendente de auto-ressuscitar")

func test_tower_definition_has_required_tactical_landmarks() -> void:
	var tower := ScenarioManager.definition(ScenarioManager.TOWER)
	assert_eq(tower["name"], "TORRE — 1º ANDAR")
	assert_eq(tower["player_spawns"].size(), 5)
	assert_eq(tower["enemy_spawns"].size(), 5)
	assert_eq(tower["torches"].size(), 6)
	assert_true(tower["walls"].size() > 40)
	assert_true(tower["pillars"].size() >= 4)
	assert_true(tower["doors"].size() >= 4)
	assert_true(tower["decorations"].any(func(item): return item["kind"] == "stairs"))
	assert_true(tower["decorations"].any(func(item): return item["kind"] == "entrance"))

func test_curated_props_are_explicitly_decorative_and_non_blocking() -> void:
	for scenario_id: String in [ScenarioManager.FIELD, ScenarioManager.TOWER]:
		var scenario := ScenarioManager.definition(scenario_id)
		var curated := (scenario.get("decorations", []) as Array).filter(func(item):
			var kind := String(item.get("kind", ""))
			return kind.begins_with("field-") or kind.begins_with("tower-crate") or kind == "tower-barrel"
		)
		assert_gt(curated.size(), 0, "%s possui props curados" % scenario_id)
		for item in curated:
			assert_true(item.get("decorative", false))
			assert_false(item.get("blocking", true))

func test_tower_spawns_are_unique_passable_and_not_on_stairs() -> void:
	var tower := ScenarioManager.definition(ScenarioManager.TOWER)
	var invalid := {}
	for tile in tower["walls"] + tower["pillars"]:
		invalid["%d,%d" % [tile["x"], tile["y"]]] = true
	for item in tower["decorations"]:
		if item["kind"] == "stairs": invalid["%d,%d" % [item["x"], item["y"]]] = true
	var seen := {}
	for tile in tower["player_spawns"] + tower["enemy_spawns"]:
		var key: String = "%d,%d" % [tile["x"], tile["y"]]
		assert_false(invalid.has(key), "spawn inválido em " + key)
		assert_false(seen.has(key), "spawn duplicado em " + key)
		seen[key] = true

## Ordem de progressão automática de fase depois de uma vitória (ver
## main.gd:_start_victory_phase_advance) — mesma ordem visual dos botões do
## topo (VILA, FLORESTA, CAMPO, HORDA, TORRE, 2º ANDAR), cíclica.
func test_scenario_manager_next_id_cycles_through_both_tower_floors() -> void:
	var manager = autofree(ScenarioManager.new())
	assert_eq(manager.next_id(ScenarioManager.VILLAGE), ScenarioManager.FOREST)
	assert_eq(manager.next_id(ScenarioManager.FOREST), ScenarioManager.FIELD)
	assert_eq(manager.next_id(ScenarioManager.FIELD), ScenarioManager.LUA_VALLEY)
	assert_eq(manager.next_id(ScenarioManager.LUA_VALLEY), ScenarioManager.TOWER)
	assert_eq(manager.next_id(ScenarioManager.TOWER), ScenarioManager.TOWER_FLOOR_2)
	assert_eq(manager.next_id(ScenarioManager.TOWER_FLOOR_2), ScenarioManager.TOWER_FLOOR_3)
	assert_eq(manager.next_id(ScenarioManager.TOWER_FLOOR_3), ScenarioManager.TOWER_FLOOR_4)

func test_scenario_manager_next_id_defaults_to_active_id() -> void:
	var manager = autofree(ScenarioManager.new())
	manager.set_active(ScenarioManager.LUA_VALLEY)
	assert_eq(manager.next_id(), ScenarioManager.TOWER)

func test_apply_tower_restarts_units_on_scenario_spawns() -> void:
	var state := GameState.new()
	var tower := ScenarioManager.definition(ScenarioManager.TOWER)
	state.apply_scenario(tower)
	assert_eq(state.scenario_id, ScenarioManager.TOWER)
	for unit in state.units:
		assert_false(BoardLayout.BLOCKING_TERRAIN_TYPES.has(state.terrain_at(unit["x"], unit["y"])))
		assert_null(state.structure_at(unit["x"], unit["y"]))
	for enemy in state.team_units("enemy"):
		assert_eq(enemy["facing"], {"dx":0,"dy":1}, "inimigos da Torre começam virados para baixo")

func test_tower_random_features_have_requested_counts_and_visible_trap_kinds() -> void:
	var state := GameState.new()
	state.rng.seed = 12345
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER))
	var counts := {}
	for terrain in state.terrain_map.values():
		var type := String(terrain.get("type", ""))
		counts[type] = int(counts.get(type, 0)) + 1
	assert_eq(counts.get("tower-bookshelf", 0), 5)
	assert_eq(counts.get("tower-grass", 0), 0)
	assert_eq(counts.get("tower-vase", 0), 3)
	assert_eq(state.terrain_map.values().filter(func(t): return t.get("towerPuddle", false)).size(), 6)
	for terrain in state.terrain_map.values():
		if terrain.get("type", "") == "tower-vase": assert_eq(terrain["hp"], 5)
	for y in range(4, 9):
		assert_eq(state.terrain_at(11, y).get("type", ""), "tower-bookshelf", "biblioteca fica na parede direita da sala central")
	assert_eq(state.traps.size(), 4)
	var kinds := state.traps.map(func(trap): return trap["kind"])
	for expected in ["poison-arrow", "corrosive-gas", "poison-gas", "fire"]:
		assert_has(kinds, expected)
	for trap in state.traps: assert_true(trap["visible"])

func test_tower_library_and_vase_create_their_configured_pickups() -> void:
	var state := GameState.new()
	state.rng.seed = 77
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER))
	var drop_shelf_key := ""
	var vase_key := ""
	for key in state.terrain_map:
		var terrain: Dictionary = state.terrain_map[key]
		if terrain.get("type", "") == "tower-bookshelf" and terrain.get("dropMana", false): drop_shelf_key = key
		if terrain.get("type", "") == "tower-vase" and vase_key == "": vase_key = key
	var shelf_parts := drop_shelf_key.split(",")
	state.damage_tree(int(shelf_parts[0]), int(shelf_parts[1]), 999, 999)
	assert_eq(state.tower_pickups[-1]["kind"], "hp")
	assert_eq(state.tower_pickups[-1]["amount"], 10)
	var vase_parts := vase_key.split(",")
	state.damage_tree(int(vase_parts[0]), int(vase_parts[1]), 999, 999)
	assert_eq(state.tower_pickups[-1]["amount"], 10)
	assert_true(state.tower_pickups[-1]["kind"] in ["hp", "mp"])

func test_tower_creature_spawn_table_uses_requested_stats() -> void:
	var state := GameState.new()
	var templates := state._tower_creature_templates()
	assert_eq(templates["rat"]["hp"], 5)
	assert_eq(templates["rat"]["speed"], 9)
	assert_eq(templates["slime"]["weapons"][0]["damageMax"], 4)
	assert_eq(templates["snake"]["innateEvasion"], 0.1)
	assert_eq(templates["snake"]["weapons"][0]["appliesPoison"]["turns"], 3)
	assert_eq(templates["gnoll"]["weapons"].size(), 2)
	assert_eq(templates["gnoll"]["weapons"][1]["hitChance"], 0.7)

func test_tower_reinforcement_only_rolls_from_turn_15_every_five_turns() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER))
	for turn in [14, 16, 17, 18, 19]:
		state.global_turn_count = turn
		assert_null(state.maybe_spawn_tower_creature(0.0, 0.0), "turno %d não deve tentar reforço" % turn)
	state.global_turn_count = 15
	assert_not_null(state.maybe_spawn_tower_creature(0.0, 0.0), "turno 15 inaugura as tentativas")
	state.global_turn_count = 20
	assert_not_null(state.maybe_spawn_tower_creature(0.0, 0.0), "turno 20: próxima tentativa, 5 turnos depois")

func test_tower_reinforcement_uses_25_percent_chance_and_stairs_tile() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER))
	state.global_turn_count = 15
	assert_null(state.maybe_spawn_tower_creature(0.25, 0.0), "25% ou mais falha a rolagem")
	var spawned = state.maybe_spawn_tower_creature(0.2499, 0.0)
	assert_not_null(spawned)
	assert_eq({"x": spawned["x"], "y": spawned["y"]}, state._tower_stairs_tile())
	assert_true((state.event_log[-1] as String).contains("escada"))

## Se a escada estiver bloqueada (ex: cadáver de um inimigo morto em cima
## dela), o reforço não pode simplesmente desistir — precisa nascer no
## primeiro espaço livre mais próximo em vez de sumir a tentativa inteira.
func test_tower_reinforcement_spawns_near_stairs_when_stairs_tile_is_blocked() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER))
	state.global_turn_count = 15
	var stairs: Dictionary = state._tower_stairs_tile()
	state.spawn_unit("corpse_on_stairs", {"team": "enemy", "hp": 0, "x": stairs["x"], "y": stairs["y"], "turnsSinceDeath": 1})
	var spawned = state.maybe_spawn_tower_creature(0.0, 0.0)
	assert_not_null(spawned, "não desiste só porque a escada está ocupada")
	assert_ne({"x": spawned["x"], "y": spawned["y"]}, {"x": stairs["x"], "y": stairs["y"]})
	assert_eq(state.manhattan({"x": spawned["x"], "y": spawned["y"]}, stairs), 1, "nasce no espaço livre mais próximo, não em qualquer lugar do mapa")

func test_tower_reinforcement_enters_with_80_ct_instead_of_zero() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER))
	state.global_turn_count = 15
	var spawned = state.maybe_spawn_tower_creature(0.0, 0.0)
	assert_eq(spawned["ct"], 80)

func test_tower_reinforcement_distribution_boundaries_are_50_30_15_5() -> void:
	var state := GameState.new()
	assert_eq(state._tower_spawn_kind_for_roll(0.00), "rat")
	assert_eq(state._tower_spawn_kind_for_roll(0.4999), "rat")
	assert_eq(state._tower_spawn_kind_for_roll(0.50), "slime")
	assert_eq(state._tower_spawn_kind_for_roll(0.7999), "slime")
	assert_eq(state._tower_spawn_kind_for_roll(0.80), "snake")
	assert_eq(state._tower_spawn_kind_for_roll(0.9499), "snake")
	assert_eq(state._tower_spawn_kind_for_roll(0.95), "gnoll")
	assert_eq(state._tower_spawn_kind_for_roll(0.9999), "gnoll")

func test_tower_battle_turn_limit_is_150() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER))
	assert_eq(state.max_global_turns(), 150)
	state.global_turn_count = 149
	assert_false(state.check_global_turn_limit())
	assert_false(state.battle_ended)
	state.global_turn_count = 150
	assert_true(state.check_global_turn_limit())
	assert_true(state.battle_ended)
	assert_true((state.event_log[-1] as String).contains("Limite de 150 turnos"))

func test_begin_turn_calls_tower_reinforcement_rule() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER))
	var actor: Dictionary = state.team_units("player")[0]
	state.global_turn_count = 13
	state.rng.seed = 7
	# Garante uma chamada real no turno elegível sem depender da chance: o
	# método direto acima cobre o resultado; aqui protegemos a conexão no fluxo.
	state.begin_turn_for(actor)
	assert_eq(state.global_turn_count, 14)
	state.begin_turn_for(actor)
	assert_eq(state.global_turn_count, 15)
	assert_true(state.event_log.any(func(line): return "Turno:" in String(line)))

func test_main_switches_to_tower_without_reloading_application() -> void:
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main_scene)
	await wait_process_frames(1)
	main_scene._switch_scenario(ScenarioManager.TOWER)
	await wait_seconds(0.75)
	assert_eq(main_scene.state.scenario_id, ScenarioManager.TOWER)
	assert_true(main_scene._tower_button.button_pressed)
	assert_false(main_scene._field_button.button_pressed)
	assert_eq(main_scene.board_view.scenario_definition["id"], ScenarioManager.TOWER)
	assert_eq(main_scene.board_view.get_children().filter(func(child): return child is TowerTorch).size(), 6)

func test_lua_valley_has_requested_roster_and_no_water_spawns() -> void:
	var state := GameState.new()
	state.rng.seed = 55
	var waterfall := ScenarioManager.definition(ScenarioManager.LUA_VALLEY)
	assert_eq(waterfall["name"], "HORDA — SOBREVIVÊNCIA")
	state.apply_scenario(waterfall)
	var counts := {"spd_rat":0,"spd_snake":0,"spd_slime":0,"spd_gnoll":0}
	for enemy in state.team_units("enemy"):
		counts[enemy["spriteKey"]] += 1
		var terrain = state.terrain_at(enemy["x"],enemy["y"])
		assert_true(terrain == null or terrain.get("type","") != "water")
		assert_true(terrain == null or terrain.get("type","") != "lua-mountain")
		assert_eq(enemy["ct"], 0, "o elenco inicial começa com CT 0, só reforços entram com 80")
	assert_eq(counts, {"spd_rat":4,"spd_snake":3,"spd_slime":2,"spd_gnoll":1})

func test_lua_valley_reinforcement_enters_with_80_ct_instead_of_zero() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.LUA_VALLEY))
	state.global_turn_count = 10
	var spawned = state.maybe_spawn_lua_creature(0.0, 0.0)
	assert_eq(spawned["ct"], 80)
	# O layout agora é o tileset real do Legend of Lua (ver
	# data/lua_valley_layout.gd) — só "lua-mountain" (parede/pedra grande) e
	# "water" (lago/queda) e "lua-ladder" viram entradas em terrain_map; a antiga
	# decoração "tower-grass" (flores do Campo sorteadas por cima) foi
	# removida porque a variação de grama já vem dos tiles reais.
	var terrain_types: Array = state.terrain_map.values().map(func(t): return t.get("type",""))
	for t in terrain_types:
		assert_true(t in ["lua-mountain", "water", "lua-ladder"], "tipo de terreno inesperado no Vale de Lua: %s" % t)

func test_lua_valley_ladder_is_walkable_from_upper_plateau_to_lower_floor() -> void:
	var state := GameState.new()
	var waterfall := ScenarioManager.definition(ScenarioManager.LUA_VALLEY)
	state.apply_scenario(waterfall)
	assert_eq(waterfall["ladders"], [
		{"x":11,"y":3}, {"x":11,"y":4}, {"x":11,"y":5}, {"x":11,"y":6},
	])
	for tile in waterfall["ladders"]:
		assert_eq(state.terrain_at(tile["x"], tile["y"])["type"], "lua-ladder")
		assert_false(BoardLayout.BLOCKING_TERRAIN_TYPES.has("lua-ladder"))
	# Isola um monstro no platô para comprovar a travessia completa da IA.
	var monster: Dictionary = state.team_units("enemy")[0]
	state.units = [monster]
	monster["x"] = 11
	monster["y"] = 2
	monster["moveRange"] = 6
	var reachable := state.compute_reachable(monster)
	assert_true(reachable.any(func(tile): return tile["x"] == 11 and tile["y"] == 7), "monstro deve conseguir descer a escada até o piso inferior")

## Regressão (pedido do usuário): um monstro nascido dentro do "bolso" da
## montanha — sem estar já alinhado com a coluna da escada (x=11) — ficava
## parado pra sempre. O fallback de movimento da IA usava distância Manhattan
## em linha reta, que enxerga qualquer desvio até a escada como "afastando do
## alvo" (mesmo sendo o único jeito de chegar lá), então nunca comprometia o
## desvio. GameState._walkable_path_distance_map (BFS respeitando paredes)
## corrige isso.
func test_lua_valley_monster_trapped_in_the_mountain_pocket_finds_its_way_to_the_ladder() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.LUA_VALLEY))
	state.units = state.team_units("player").duplicate(true)
	state.units_by_key = {}
	for hero in state.units:
		state.units_by_key[hero["name"]] = hero
	var monster: Dictionary = state.spawn_unit("trapped_rat", {
		"x": 7, "y": 2, "team": "enemy", "hp": 5, "maxHp": 5, "mp": 0,
		"moveRange": 3, "speed": 5, "ct": 100, "statusEffects": [],
		"weapons": [{"name":"Mordida","icon":"x","ctCost":50,"damageMin":1,"damageMax":1,"critMultiplier":1,"critChance":0.0,"hitChance":0.9,"minRange":1,"maxRange":1}],
		"spells": [],
	})
	var reached_lower_floor := false
	for turn in range(10):
		state.current_actor = monster
		monster["hasMoved"] = false
		monster["hasActed"] = false
		state.enemy_act(monster)
		if monster["y"] >= 7:
			reached_lower_floor = true
			break
	assert_true(reached_lower_floor, "monstro preso no bolso da montanha deve desviar até a escada e descer, não ficar parado")

func test_lua_valley_monster_on_upper_plateau_prioritizes_ladder_over_attacking() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.LUA_VALLEY))
	state.units = []
	state.units_by_key = {}
	var monster: Dictionary = state.spawn_unit("upper_monster", {
		"x": 11, "y": 2, "team": "enemy", "hp": 10, "maxHp": 10, "mp": 0,
		"moveRange": 2, "speed": 5, "ct": 100, "statusEffects": [],
		"weapons": [{"name":"Tiro distante","icon":"x","ctCost":50,"damageMin":5,"damageMax":5,"critMultiplier":1,"critChance":0.0,"hitChance":1.0,"minRange":1,"maxRange":20}],
		"spells": [],
	})
	var hero: Dictionary = state.spawn_unit("hero_below", {"x": 11, "y": 8, "team": "player", "hp": 20, "maxHp": 20, "speed": 1, "ct": 0})
	state.current_actor = monster
	state.enemy_act(monster)
	assert_true(monster["y"] > 2, "desce pela escada imediatamente")
	assert_eq(hero["hp"], 20, "não ataca enquanto ainda precisa sair do alto do morro")
	assert_true(state.event_log.any(func(line): return String(line).contains("prioriza descer a escada")))

## Reforço garantido da Horda a cada 7 turnos globais corridos, em vez do
## gatilho "todo herói
## vivo já agiu", que segurava o reforço indefinidamente e nunca deixava uma
## janela estável de "sem inimigos" pra vencer por eliminação (ver
## GameState.battle_won).
func test_tower_floor3_has_no_living_fire_reinforcement_by_turn() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_3))
	var initial_living_fire_count: int = state.team_units("enemy").filter(func(u): return u["spriteKey"] == "tower_living_fire").size()
	assert_false(state.has_method("maybe_spawn_tower_floor3_living_fire_by_turn"))
	for turn in [20, 40, 60]:
		state.global_turn_count = turn
		assert_eq(state.team_units("enemy").filter(func(u): return u["spriteKey"] == "tower_living_fire").size(), initial_living_fire_count)

## Pedido do usuário: no 4º Andar, um Fogo Vivo garantido a cada 10 turnos
## globais corridos (10, 20, 30...) — mesma lógica determinística do Vale da
## Lua (ver test_lua_valley_reinforcement_spawns_every_7_global_turns), só
## trocando o período e a criatura.
func test_tower_floor4_living_fire_reinforcement_spawns_every_10_global_turns() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_4))
	var initial_count: int = state.team_units("enemy").filter(func(u): return u["spriteKey"] == "tower_living_fire").size()
	for turn in [1, 5, 9]:
		state.global_turn_count = turn
		state.maybe_spawn_tower_floor4_living_fire_by_turn()
		assert_eq(state.team_units("enemy").filter(func(u): return u["spriteKey"] == "tower_living_fire").size(), initial_count, "turno %d não é múltiplo de 10, nenhum reforço" % turn)
	state.global_turn_count = 10
	state.maybe_spawn_tower_floor4_living_fire_by_turn()
	assert_eq(state.team_units("enemy").filter(func(u): return u["spriteKey"] == "tower_living_fire").size(), initial_count + 1, "turno 10: reforço garantido")
	state.global_turn_count = 20
	state.maybe_spawn_tower_floor4_living_fire_by_turn()
	assert_eq(state.team_units("enemy").filter(func(u): return u["spriteKey"] == "tower_living_fire").size(), initial_count + 2, "turno 20: outro reforço garantido")

func test_tower_floor4_living_fire_reinforcement_by_turn_only_applies_to_floor_4() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_3))
	state.global_turn_count = 10
	var before: int = state.units.size()
	state.maybe_spawn_tower_floor4_living_fire_by_turn()
	assert_eq(state.units.size(), before, "não deve fazer nada fora do 4º Andar")

func test_lua_valley_reinforcement_spawns_every_7_global_turns() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.LUA_VALLEY))
	var initial_enemy_count: int = state.team_units("enemy").size()
	for turn in [1, 2, 3, 4, 5, 6]:
		state.global_turn_count = turn
		state.maybe_spawn_lua_reinforcement_by_turn()
		assert_eq(state.team_units("enemy").size(), initial_enemy_count, "turno %d não é múltiplo de 7, nenhum reforço" % turn)
	state.global_turn_count = 7
	state.maybe_spawn_lua_reinforcement_by_turn()
	assert_eq(state.team_units("enemy").size(), initial_enemy_count + 1, "turno 7: reforço garantido")
	for turn in [8, 9, 10, 11, 12, 13]:
		state.global_turn_count = turn
		state.maybe_spawn_lua_reinforcement_by_turn()
		assert_eq(state.team_units("enemy").size(), initial_enemy_count + 1, "turno %d ainda não é múltiplo de 7" % turn)
	state.global_turn_count = 14
	state.maybe_spawn_lua_reinforcement_by_turn()
	assert_eq(state.team_units("enemy").size(), initial_enemy_count + 2, "turno 14: outro reforço garantido")

func test_lua_valley_reinforcement_by_turn_only_applies_to_lua_valley() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER))
	state.global_turn_count = 7
	var before: int = state.units.size()
	state.maybe_spawn_lua_reinforcement_by_turn()
	assert_eq(state.units.size(), before, "não deve fazer nada fora da Horda")

func test_lua_valley_reinforcements_are_guaranteed_and_use_tower_distribution() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.LUA_VALLEY))
	state.global_turn_count = 10
	var expected := [
		[0.00, "spd_rat"], [0.50, "spd_slime"],
		[0.80, "spd_snake"], [0.95, "spd_gnoll"],
	]
	for entry in expected:
		# Libera o ponto de entrada removendo apenas o reforço da iteração
		# anterior; o elenco inicial permanece intacto.
		# O primeiro argumento é deliberadamente alto: na Horda a chance
		# agora é 100%, então nenhuma rolagem pode cancelar o surgimento.
		var spawned = state.maybe_spawn_lua_creature(0.9999, entry[0])
		assert_not_null(spawned)
		assert_eq(spawned["spriteKey"], entry[1])
		state.units.erase(spawned)
		state.units_by_key.erase(spawned["name"])

## Bug relatado pelo usuário: derrotar todo o elenco da Horda estava
## contando como DERROTA. Causa raiz: main.gd:_show_end_screen lia só a
## última linha do log pra decidir vitória/derrota, e finalize_death_if_needed
## loga "se desfaz numa alma" pros bichos da Horda (todos em
## IMMEDIATE_SOUL_SPRITE_KEYS) DEPOIS da mensagem "Vitória!", dentro do mesmo
## _sync_visuals() — então a UI achava que a última linha era o resultado
## errado. GameState.battle_won existe exatamente pra não depender de qual é
## a última linha do log.
func test_lua_valley_clearing_all_enemies_is_a_victory_even_after_the_immediate_soul_log_line() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.LUA_VALLEY))
	var enemies := state.team_units("enemy")
	for enemy in enemies:
		enemy["hp"] = 0
	assert_true(state.check_battle_outcome())
	assert_true(state.battle_won, "eliminar todo o elenco da Horda deve ser vitória")
	assert_true(String(state.event_log[-1]).contains("Vitória"))
	# Mesma ordem de main.gd: _after_action() chama check_battle_outcome()
	# (já feito acima) e só DEPOIS _sync_visuals() roda finalize_death_if_needed
	# pra cada unidade — isso é o que produz a linha de log posterior.
	for enemy in enemies:
		state.finalize_death_if_needed(enemy)
	assert_true(String(state.event_log[-1]).contains("se desfaz numa alma"), "confirma que a última linha do log MUDOU depois da vitória")
	assert_true(state.battle_won, "battle_won não pode ser afetado por logs que vêm depois do resultado")

func test_tower_no_longer_has_grass() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER))
	assert_eq(state.terrain_map.values().filter(func(t): return t.get("type","") == "tower-grass").size(), 0)

func test_each_tower_door_starts_closed_and_opens_when_crossed() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER))
	var actor: Dictionary = state.team_units("player")[0]
	for door_tile in ScenarioManager.definition(ScenarioManager.TOWER)["doors"]:
		var door: Dictionary = state.terrain_at(door_tile["x"], door_tile["y"])
		assert_false(door["opened"])
		state._apply_tower_path_features(actor, [door_tile])
		assert_true(door["opened"])

func test_tower_uses_black_slime_boss_and_split_progression() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER))
	var enemies := state.team_units("enemy")
	assert_eq(enemies.size(), 1)
	var boss: Dictionary = enemies[0]
	assert_eq(boss["spriteKey"], "spd_goo")
	assert_eq(boss["hp"], 200)
	assert_eq(boss["maxHp"], 200)
	assert_eq(boss["speed"], 20)
	assert_eq([boss["footprintSize"], state.footprint_width(boss), state.footprint_height(boss)], [2, 2, 2])
	for occupied_tile in state.footprint_tiles(boss):
		assert_eq(state.unit_at(occupied_tile["x"], occupied_tile["y"]), boss, "a forma inicial ocupa os quatro quadrados")
	var tangent_tiles := [
		{"x":boss["x"],"y":boss["y"]-1}, {"x":boss["x"]+1,"y":boss["y"]+2},
		{"x":boss["x"]-1,"y":boss["y"]}, {"x":boss["x"]+2,"y":boss["y"]+1},
	]
	for tile in tangent_tiles:
		assert_eq(state.manhattan(tile, boss), 1, "cada casa cardeal tangente alcança o corpo 2x2")
	assert_eq(boss["counterAttackChance"], 0.10, "qualquer forma reage 10% das vezes a um golpe corpo a corpo")
	assert_eq(boss.get("innateEvasion", 0.0), 0.0, "forma inicial de 200 HP não tem esquiva bônus")
	boss["statusEffects"] = [{"type":"burned","turnsLeft":3}]
	boss["hp"] = 140
	state._check_black_slime_split(boss)
	enemies = state.team_units("enemy")
	assert_eq(enemies.size(), 2)
	for child in enemies:
		assert_eq(child["footprintSize"], 1, "as formas divididas voltam a ocupar uma casa")
		assert_eq(child["hp"], 70)
		assert_eq(child["maxHp"], 70)
		assert_eq(child["speed"], 25)
		assert_eq(child["statusEffects"], [{"type":"burned","turnsLeft":3}], "a divisão mantém os status que o pai já tinha")
		assert_eq(child["counterAttackChance"], 0.10)
		assert_eq(child["innateEvasion"], 0.10, "forma de 70 HP fica 10% mais difícil de acertar")
	# Um status novo aplicado só num filho não pode vazar pro outro (cada um
	# tem sua própria cópia do array herdado, não a mesma referência).
	enemies[0]["statusEffects"].append({"type":"poison","turnsLeft":2})
	assert_eq(enemies[1]["statusEffects"].size(), 1, "status novo num filho não afeta o outro")
	var first_child: Dictionary = enemies[0]
	first_child["hp"] = 40
	state._check_black_slime_split(first_child)
	var final_slimes := state.team_units("enemy").filter(func(unit): return unit.get("slimeStage",0) == 2)
	assert_eq(final_slimes.size(), 2)
	for final_slime in final_slimes:
		assert_eq(final_slime["hp"], 20)
		assert_eq(final_slime["speed"], 30)
		assert_eq(final_slime["innateEvasion"], 0.20, "forma de 20 HP fica 20% mais difícil de acertar")
		assert_eq(final_slime["counterAttackChance"], 0.10)
		assert_eq(final_slime["statusEffects"], first_child["statusEffects"], "a 2ª divisão também mantém os status do pai (queimadura + veneno)")
