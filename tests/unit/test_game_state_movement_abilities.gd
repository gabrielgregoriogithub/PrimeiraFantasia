extends GutTest

## Fase 3 (interação de movimento com terreno/estrutura): porte de
## computeChargeTargets/castCharge/castTrample/castGrowthAttack e do desvio
## de cadáver findCorpseSafeSideTile/separateLivingUnitFromCorpse
## (game.js:4345-4373, 4887-4924, 8285-8308, 9318-9420).

var state: GameState

func before_each() -> void:
	state = GameState.new()
	state.clear_units()
	state.clear_terrain_and_structures()

func _spell(overrides: Dictionary) -> Dictionary:
	var s := {"name": "habilidade-teste", "ctCost": 60, "mpCost": 3, "hitChance": 1.0, "critChance": 0.0, "critMultiplier": 1, "minRange": 1, "maxRange": 4}
	for k in overrides.keys():
		s[k] = overrides[k]
	return s

# --- compute_charge_targets --------------------------------------------------

func test_compute_charge_targets_finds_first_enemy_in_each_cardinal_direction() -> void:
	var orc := state.spawn_unit("orc", {"x": 5, "y": 5, "team": "enemy", "moveRange": 3})
	state.spawn_unit("near_enemy", {"x": 7, "y": 5, "team": "player", "hp": 10})
	state.spawn_unit("far_enemy_same_line", {"x": 9, "y": 5, "team": "player", "hp": 10})
	var targets := _tile_set(state.compute_charge_targets(orc))
	assert_true(targets.has(state.tile_key(7, 5)), "primeiro inimigo na linha")
	assert_false(targets.has(state.tile_key(9, 5)), "o segundo nunca é alcançado, o primeiro já bloqueia")

func test_compute_charge_targets_ally_in_the_way_blocks_without_becoming_a_target() -> void:
	var orc := state.spawn_unit("orc", {"x": 5, "y": 5, "team": "enemy", "moveRange": 3})
	state.spawn_unit("ally", {"x": 6, "y": 5, "team": "enemy", "hp": 10})
	var targets := _tile_set(state.compute_charge_targets(orc))
	assert_false(targets.has(state.tile_key(6, 5)))

func _tile_set(tiles: Array) -> Dictionary:
	var set := {}
	for t in tiles:
		set[state.tile_key(t["x"], t["y"])] = true
	return set

# --- cast_charge ---------------------------------------------------------------

func test_cast_charge_moves_adjacent_to_target_and_attacks() -> void:
	var orc := state.spawn_unit("orc", {"x": 0, "y": 0, "team": "enemy", "ct": 100, "mp": 10, "hasMoved": false})
	var target := state.spawn_unit("target", {"x": 5, "y": 0, "team": "player", "hp": 30, "maxHp": 30})
	var charge := _spell({"damageMin": 4, "damageMax": 4})
	var ok := state.cast_charge(orc, target, charge)
	assert_true(ok)
	assert_eq(orc["x"], 4)
	assert_eq(orc["y"], 0)
	assert_true(orc["hasMoved"])
	assert_true(orc["hasActed"])
	assert_eq(target["hp"], 26)

func test_cast_charge_fails_when_the_landing_spot_is_occupied() -> void:
	var orc := state.spawn_unit("orc", {"x": 0, "y": 0, "team": "enemy", "ct": 100, "mp": 10})
	state.spawn_unit("blocker", {"x": 4, "y": 0, "team": "enemy", "hp": 10})
	var target := state.spawn_unit("target", {"x": 5, "y": 0, "team": "player", "hp": 30, "maxHp": 30})
	var charge := _spell({"damageMin": 4, "damageMax": 4})
	var ok := state.cast_charge(orc, target, charge)
	assert_false(ok)
	assert_eq(orc["x"], 0, "não se move quando o ponto de parada está ocupado")
	assert_eq(target["hp"], 30, "e não ataca")

func test_cast_charge_triggers_enemy_trap_crossed_on_the_way() -> void:
	var orc := state.spawn_unit("orc", {"x": 0, "y": 0, "team": "enemy", "ct": 100, "mp": 10, "hp": 20, "maxHp": 20})
	var target := state.spawn_unit("target", {"x": 5, "y": 0, "team": "player", "hp": 30, "maxHp": 30})
	state.traps = [{"tiles": [{"x": 2, "y": 0}], "ownerTeam": "player", "triggered": false, "turnsLeft": null}]
	state.cast_charge(orc, target, _spell({"damageMin": 4, "damageMax": 4}))
	assert_lt(orc["hp"], 20, "Investida sofre o efeito da armadilha atravessada")
	assert_true(state.traps[0]["triggered"])

# --- cast_trample ---------------------------------------------------------------

func test_cast_trample_hits_every_enemy_in_the_path_and_stops_at_the_board_edge() -> void:
	var troll := state.spawn_unit("troll", {"x": 0, "y": 0, "team": "enemy", "ct": 100, "mp": 5, "hasMoved": false})
	var e1 := state.spawn_unit("e1", {"x": 2, "y": 0, "team": "player", "hp": 20, "maxHp": 20})
	var e2 := state.spawn_unit("e2", {"x": 4, "y": 0, "team": "player", "hp": 20, "maxHp": 20})
	var trample := _spell({"maxRange": 12, "damageMin": 5, "damageMax": 5})
	state.cast_trample(troll, trample, {"x": 12, "y": 0})
	assert_eq(e1["hp"], 15, "atropela por cima, não pára no primeiro")
	assert_eq(e2["hp"], 15)
	assert_eq(troll["x"], 12, "vai até a borda do tabuleiro")
	assert_true(troll["hasMoved"])

func test_cast_trample_stops_at_an_ally_without_hitting_it() -> void:
	var troll := state.spawn_unit("troll", {"x": 0, "y": 0, "team": "enemy", "ct": 100, "mp": 5})
	var ally := state.spawn_unit("ally", {"x": 3, "y": 0, "team": "enemy", "hp": 20, "maxHp": 20})
	var trample := _spell({"maxRange": 12, "damageMin": 5, "damageMax": 5})
	state.cast_trample(troll, trample, {"x": 12, "y": 0})
	assert_eq(ally["hp"], 20, "aliado nunca é atingido")
	assert_eq(troll["x"], 2, "pára antes do aliado")

func test_cast_trample_triggers_enemy_trap_crossed_on_the_way() -> void:
	var troll := state.spawn_unit("troll", {"x": 0, "y": 0, "team": "enemy", "ct": 100, "mp": 5, "hp": 30, "maxHp": 30})
	state.traps = [{"tiles": [{"x": 3, "y": 0}], "ownerTeam": "player", "triggered": false, "turnsLeft": null}]
	state.cast_trample(troll, _spell({"maxRange": 6, "damageMin": 5, "damageMax": 5}), {"x": 6, "y": 0})
	assert_lt(troll["hp"], 30, "Atropelar sofre o efeito da armadilha atravessada")
	assert_true(state.traps[0]["triggered"])

func test_cast_trample_bumps_into_enemy_structure_and_hits_both_defender_and_structure() -> void:
	var troll := state.spawn_unit("troll", {"x": 0, "y": 0, "team": "enemy", "ct": 100, "mp": 5})
	state.structures = [{"type": "castle", "team": "player", "tiles": [{"x": 3, "y": 0}], "hp": 100, "maxHp": 100, "destroyed": false}]
	var hero := state.spawn_unit("hero", {"x": 3, "y": 0, "team": "player", "hp": 20, "maxHp": 20})
	var trample := _spell({"maxRange": 12, "damageMin": 5, "damageMax": 5})
	state.cast_trample(troll, trample, {"x": 12, "y": 0})
	assert_eq(hero["hp"], 15, "quem está dentro da estrutura inimiga também é atingido")
	assert_eq(state.structures[0]["hp"], 100 - trample["damageMin"], "e a estrutura leva o dano do golpe, sem multiplicador de área")
	assert_eq(troll["x"], 2, "pára antes da estrutura, não entra nela")

func test_cast_trample_pushes_troll_aside_when_the_final_tile_is_occupied() -> void:
	var troll := state.spawn_unit("troll", {"x": 0, "y": 0, "team": "enemy", "ct": 100, "mp": 5})
	# Sozinho no caminho e mais rápido que o alcance do atropelo: o Troll
	# teria que "pousar" em cima dele — precisa ser empurrado pro lado.
	# facing de costas pro troll: o golpe vem de trás (+20pp de chance de
	# acerto), garantindo 100% mesmo com a penalidade de -10pp de "arma de
	# alcance >1 usada a queima-roupa" (item.maxRange=3 conta como ranged
	# pra essa regra, mesmo sendo usada aqui num bump corpo a corpo) — sem
	# isso o teste seria flaky (chance real ~90%, não 100%).
	var lone := state.spawn_unit("lone", {"x": 3, "y": 0, "team": "player", "hp": 20, "maxHp": 20, "facing": {"dx": -1, "dy": 0}})
	var trample := _spell({"maxRange": 3, "damageMin": 5, "damageMax": 5})
	state.cast_trample(troll, trample, {"x": 12, "y": 0})
	assert_eq(lone["hp"], 15, "ainda é atingido")
	assert_false(troll["x"] == lone["x"] and troll["y"] == lone["y"], "mas o Troll nunca fica em cima dele")

# --- cast_growth_attack (Ataque Giratório / Crescimento) --------------------

func test_cast_growth_attack_hits_all_8_surrounding_tiles_including_diagonals() -> void:
	var caster := state.spawn_unit("caster", {"x": 5, "y": 5, "team": "player", "ct": 100, "mp": 3})
	var orth := state.spawn_unit("orth", {"x": 5, "y": 4, "team": "enemy", "hp": 20, "maxHp": 20})
	var diag := state.spawn_unit("diag", {"x": 6, "y": 6, "team": "enemy", "hp": 20, "maxHp": 20})
	var far := state.spawn_unit("far", {"x": 5, "y": 3, "team": "enemy", "hp": 20, "maxHp": 20})
	var spin := _spell({"damageMin": 8, "damageMax": 8})
	state.cast_growth_attack(caster, spin)
	assert_eq(orth["hp"], 12)
	assert_eq(diag["hp"], 12, "diagonais também entram")
	assert_eq(far["hp"], 20, "fora do raio de 1 tile não é atingido")

func test_cast_growth_attack_also_damages_nearby_trees() -> void:
	var caster := state.spawn_unit("caster", {"x": 5, "y": 5, "team": "player", "ct": 100, "mp": 3})
	state.terrain_map[state.tile_key(6, 5)] = {"type": "tree", "hp": 2, "maxHp": 10}
	var spin := _spell({"damageMin": 8, "damageMax": 8})
	state.cast_growth_attack(caster, spin)
	assert_eq(state.terrain_map[state.tile_key(6, 5)]["type"], "stump")

# --- desvio de cadáver --------------------------------------------------------

func test_separate_living_unit_from_corpse_moves_to_a_free_adjacent_tile() -> void:
	var mover := state.spawn_unit("mover", {"x": 5, "y": 5, "hp": 10, "team": "player"})
	state.spawn_unit("corpse", {"x": 5, "y": 5, "hp": 0, "turnsSinceDeath": 1})
	var moved := state.separate_living_unit_from_corpse(mover, {"x": 4, "y": 5}, 1, 0)
	assert_true(moved)
	assert_false(mover["x"] == 5 and mover["y"] == 5, "não fica em cima do cadáver")

func test_cast_trample_never_leaves_troll_on_top_of_a_corpse_it_could_not_pass() -> void:
	var troll := state.spawn_unit("troll", {"x": 0, "y": 0, "team": "enemy", "ct": 100, "mp": 5})
	state.spawn_unit("corpse", {"x": 2, "y": 0, "hp": 0, "turnsSinceDeath": 1})
	var trample := _spell({"maxRange": 12, "damageMin": 5, "damageMax": 5})
	state.cast_trample(troll, trample, {"x": 12, "y": 0})
	assert_false(troll["x"] == 2 and troll["y"] == 0, "cadáver bloqueia o atropelo como parede")
