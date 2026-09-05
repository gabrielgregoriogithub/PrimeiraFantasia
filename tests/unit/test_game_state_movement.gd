extends GutTest

## Fase 2 (movimento): porte de stepCost/trapStepCost/waterStepCost/
## computeReachable (Dijkstra)/reconstructPath/applyTrapCrossings
## (game.js:5442-5648).

var state: GameState

func before_each() -> void:
	state = GameState.new()
	state.clear_units()

func _tile_set(tiles: Array) -> Dictionary:
	var set := {}
	for t in tiles:
		set[state.tile_key(t["x"], t["y"])] = true
	return set

func test_compute_reachable_open_board_matches_manhattan_diamond() -> void:
	state.clear_terrain_and_structures()
	var u := state.spawn_unit("mover", {"x": 6, "y": 6, "moveRange": 3})
	var reachable := state.compute_reachable(u)
	# Fórmula do "diamante" de Manhattan (raio R, sem o centro): 2*R*(R+1).
	assert_eq(reachable.size(), 2 * 3 * 4)
	for t in reachable:
		assert_true(abs(t["x"] - 6) + abs(t["y"] - 6) <= 3)
		assert_true(state.in_bounds(t["x"], t["y"]))
	var origin_present := reachable.any(func(t): return t["x"] == 6 and t["y"] == 6)
	assert_false(origin_present, "o próprio tile de origem nunca é um destino")

func test_compute_reachable_blocked_by_tree() -> void:
	state.clear_terrain_and_structures()
	state.terrain_map[state.tile_key(6, 5)] = {"type": "tree"}
	var u := state.spawn_unit("mover", {"x": 5, "y": 5, "moveRange": 1})
	var reachable := _tile_set(state.compute_reachable(u))
	assert_false(reachable.has(state.tile_key(6, 5)), "árvore bloqueia mesmo adjacente")
	assert_true(reachable.has(state.tile_key(4, 5)))
	assert_true(reachable.has(state.tile_key(5, 4)))
	assert_true(reachable.has(state.tile_key(5, 6)))
	assert_eq(reachable.size(), 3)

func test_compute_reachable_ally_passable_but_not_a_destination() -> void:
	state.clear_terrain_and_structures()
	state.spawn_unit("ally", {"team": "player", "x": 6, "y": 5, "hp": 10})
	var u := state.spawn_unit("mover", {"team": "player", "x": 5, "y": 5, "moveRange": 3})
	var reachable := _tile_set(state.compute_reachable(u))
	assert_false(reachable.has(state.tile_key(6, 5)), "aliado nunca é destino válido")
	assert_true(reachable.has(state.tile_key(7, 5)), "aliado nunca bloqueia passagem")

func test_compute_reachable_enemy_blocks_passage_unless_flying() -> void:
	state.clear_terrain_and_structures()
	state.spawn_unit("blocker", {"team": "enemy", "x": 6, "y": 5, "hp": 10})
	var grounded := state.spawn_unit("mover", {"team": "player", "x": 5, "y": 5, "moveRange": 3, "flying": false})
	var reachable_grounded := _tile_set(state.compute_reachable(grounded))
	assert_false(reachable_grounded.has(state.tile_key(6, 5)))
	assert_false(reachable_grounded.has(state.tile_key(7, 5)), "inimigo bloqueia passagem sem voar")

	var flyer := state.spawn_unit("flyer", {"team": "player", "x": 5, "y": 5, "moveRange": 3, "flying": true})
	var reachable_flyer := _tile_set(state.compute_reachable(flyer))
	assert_false(reachable_flyer.has(state.tile_key(6, 5)), "mesmo voando não pode ATERRISSAR no inimigo")
	assert_true(reachable_flyer.has(state.tile_key(7, 5)), "voando atravessa o inimigo")

func test_compute_reachable_structure_exclusive_to_owner_team() -> void:
	var player_unit := state.spawn_unit("p", {"team": "player", "x": 3, "y": 0, "moveRange": 3})
	var reachable_player := _tile_set(state.compute_reachable(player_unit))
	assert_true(reachable_player.has(state.tile_key(2, 0)), "jogador pode entrar no próprio castelo")

	var enemy_unit := state.spawn_unit("e", {"team": "enemy", "x": 3, "y": 0, "moveRange": 3})
	var reachable_enemy := _tile_set(state.compute_reachable(enemy_unit))
	assert_false(reachable_enemy.has(state.tile_key(2, 0)), "inimigo nunca entra no castelo do jogador")

func test_compute_reachable_structure_single_occupant_slot() -> void:
	state.spawn_unit("inside", {"team": "player", "x": 1, "y": 1, "hp": 10})
	var mover := state.spawn_unit("p", {"team": "player", "x": 3, "y": 0, "moveRange": 3})
	var reachable := _tile_set(state.compute_reachable(mover))
	assert_false(reachable.has(state.tile_key(2, 0)), "castelo já ocupado pelo próprio time: vaga única")

func test_water_costs_double_and_flying_ignores_it() -> void:
	state.clear_terrain_and_structures()
	state.terrain_map[state.tile_key(6, 5)] = {"type": "water"}
	var grounded := state.spawn_unit("mover", {"x": 5, "y": 5, "moveRange": 2, "flying": false})
	var reachable_grounded := _tile_set(state.compute_reachable(grounded))
	assert_true(reachable_grounded.has(state.tile_key(6, 5)), "água custa 2, ainda cabe no orçamento de 2")
	assert_false(reachable_grounded.has(state.tile_key(7, 5)), "não sobra orçamento pra passar da água")

	var flyer := state.spawn_unit("flyer", {"x": 5, "y": 5, "moveRange": 2, "flying": true})
	var reachable_flyer := _tile_set(state.compute_reachable(flyer))
	assert_true(reachable_flyer.has(state.tile_key(7, 5)), "voando não paga o custo extra da água")

func test_reconstruct_path_is_connected_and_matches_cost() -> void:
	state.clear_terrain_and_structures()
	var u := state.spawn_unit("mover", {"x": 0, "y": 0, "moveRange": 4})
	state.compute_reachable(u)
	var dest_key := state.tile_key(2, 1)
	var expected_cost: int = state.last_reachable_costs[dest_key]
	var path := state.reconstruct_path(2, 1)

	assert_eq(path.size(), expected_cost)
	assert_eq(path[path.size() - 1], {"x": 2, "y": 1})
	var prev := {"x": 0, "y": 0}
	for step in path:
		assert_eq(abs(step["x"] - prev["x"]) + abs(step["y"] - prev["y"]), 1, "cada passo é adjacente ao anterior")
		prev = step

func test_apply_trap_crossings_damages_once_and_reveals() -> void:
	var mover := state.spawn_unit("mover", {"team": "player", "hp": 20, "maxHp": 20})
	state.traps = [{
		"ownerTeam": "enemy",
		"tiles": [{"x": 1, "y": 0}, {"x": 2, "y": 0}],
		"triggered": false,
		"turnsLeft": 0,
	}]
	state.apply_trap_crossings(mover, [{"x": 1, "y": 0}, {"x": 2, "y": 0}])

	var damage: int = 20 - mover["hp"]
	assert_true(damage >= 1 and damage <= 3, "1 armadilha = 1 rolagem de dano só, mesmo cruzando 2 dos tiles dela")
	assert_true(state.traps[0]["triggered"])
	assert_eq(state.traps[0]["turnsLeft"], 3)

func test_apply_trap_crossings_ignores_ally_owned_trap() -> void:
	var mover := state.spawn_unit("mover", {"team": "player", "hp": 20, "maxHp": 20})
	state.traps = [{
		"ownerTeam": "player",
		"tiles": [{"x": 1, "y": 0}],
		"triggered": false,
		"turnsLeft": 0,
	}]
	state.apply_trap_crossings(mover, [{"x": 1, "y": 0}])
	assert_eq(mover["hp"], 20, "armadilha do próprio time não causa dano")
	assert_false(state.traps[0]["triggered"])

func test_apply_trap_crossings_does_not_trigger_an_already_activated_trap_again() -> void:
	var mover := state.spawn_unit("mover", {"x": 0, "y": 0, "team": "enemy", "hp": 20, "maxHp": 20})
	state.traps = [{"tiles": [{"x": 1, "y": 0}], "ownerTeam": "player", "triggered": true, "turnsLeft": 3}]
	state.apply_trap_crossings(mover, [{"x": 1, "y": 0}])
	assert_eq(mover["hp"], 20, "armadilha ativada não causa seu efeito novamente")

func test_apply_trap_crossings_flying_unit_is_immune() -> void:
	var mover := state.spawn_unit("mover", {"team": "player", "hp": 20, "maxHp": 20, "flying": true})
	state.traps = [{
		"ownerTeam": "enemy",
		"tiles": [{"x": 1, "y": 0}],
		"triggered": false,
		"turnsLeft": 0,
	}]
	state.apply_trap_crossings(mover, [{"x": 1, "y": 0}])
	assert_eq(mover["hp"], 20, "voando nunca aciona armadilha")
	assert_false(state.traps[0]["triggered"])
