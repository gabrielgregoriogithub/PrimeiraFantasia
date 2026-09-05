extends GutTest

## Fase 2 (turnos/CT): porte de advanceCTUntilReady/beginTurnFor/
## advanceToNextTurn/checkGlobalTurnLimit/checkBattleOutcome/
## noteUnitActedThisRound/applyCorpseDecayTick (game.js:5429-5440,
## 6226-6321, 9422-9781).

var state: GameState

func before_each() -> void:
	state = GameState.new()
	state.clear_units()
	state.clear_terrain_and_structures()

# --- advance_ct_until_ready / move_ct_cost -----------------------------------

func test_advance_ct_until_ready_returns_fastest_unit_first() -> void:
	var slow := state.spawn_unit("slow", {"ct": 0, "speed": 10})
	var fast := state.spawn_unit("fast", {"ct": 0, "speed": 34})
	var ready := state.advance_ct_until_ready()
	assert_eq(ready, fast)

func test_advance_ct_until_ready_tie_break_by_ct_then_speed() -> void:
	var a := state.spawn_unit("a", {"ct": 90, "speed": 5})
	var b := state.spawn_unit("b", {"ct": 100, "speed": 1})
	assert_eq(state.advance_ct_until_ready(), b, "CT maior ganha mesmo com agilidade menor")

	state.clear_units()
	var c := state.spawn_unit("c", {"ct": 100, "speed": 5})
	var d := state.spawn_unit("d", {"ct": 100, "speed": 20})
	assert_eq(state.advance_ct_until_ready(), d, "CT empatado: maior agilidade desempata")

func test_advance_ct_until_ready_ignores_dead_units() -> void:
	state.spawn_unit("corpse", {"ct": 999, "speed": 999, "hp": 0})
	var alive := state.spawn_unit("alive", {"ct": 0, "speed": 50})
	assert_eq(state.advance_ct_until_ready(), alive)

func test_move_ct_cost_scales_with_distance_over_move_range() -> void:
	var u := {"moveRange": 4}
	assert_eq(state.move_ct_cost(u, 4), GameConstants.MOVE_MAX_COST)
	assert_eq(state.move_ct_cost(u, 2), 25)
	assert_eq(state.move_ct_cost(u, 0), 0)

# --- tick_structure_regen / total_team_hp ------------------------------------

func test_tick_structure_regen_heals_hp_and_mp_of_owner_team_occupant() -> void:
	state.structures = [{"type": "castle", "team": "player", "tiles": [{"x": 0, "y": 0}], "hp": 50, "maxHp": 100, "destroyed": false}]
	var hero := state.spawn_unit("hero", {"team": "player", "x": 0, "y": 0, "hp": 10, "maxHp": 20, "mp": 5, "maxMp": 10})
	state.tick_structure_regen()
	assert_eq(hero["hp"], 11)
	assert_eq(hero["mp"], 6)

func test_tick_structure_regen_skips_wrong_team_occupant() -> void:
	state.structures = [{"type": "mountain", "team": "enemy", "tiles": [{"x": 0, "y": 0}], "hp": 50, "maxHp": 100, "destroyed": false}]
	var hero := state.spawn_unit("hero", {"team": "player", "x": 0, "y": 0, "hp": 10, "maxHp": 20})
	state.tick_structure_regen()
	assert_eq(hero["hp"], 10, "time errado não regenera na estrutura do outro time")

func test_total_team_hp_sums_alive_units_and_structure_hp() -> void:
	state.structures = [{"type": "castle", "team": "player", "tiles": [], "hp": 30, "maxHp": 100, "destroyed": false}]
	state.spawn_unit("a", {"team": "player", "hp": 10})
	state.spawn_unit("b", {"team": "player", "hp": 5})
	state.spawn_unit("dead", {"team": "player", "hp": 0})
	assert_eq(state.total_team_hp("player", "castle"), 45)

# --- check_global_turn_limit / check_battle_outcome --------------------------

func test_check_global_turn_limit_declares_winner_by_total_hp() -> void:
	state.spawn_unit("p", {"team": "player", "hp": 50})
	state.spawn_unit("e", {"team": "enemy", "hp": 10})
	state.global_turn_count = GameConstants.MAX_GLOBAL_TURNS
	assert_true(state.check_global_turn_limit())
	assert_true(state.battle_ended)
	assert_true((state.event_log[-1] as String).contains("Guerreiro vence"))

func test_check_global_turn_limit_does_nothing_before_the_limit() -> void:
	state.spawn_unit("p", {"team": "player", "hp": 50})
	state.spawn_unit("e", {"team": "enemy", "hp": 10})
	state.global_turn_count = GameConstants.MAX_GLOBAL_TURNS - 1
	assert_false(state.check_global_turn_limit())
	assert_false(state.battle_ended)

func test_check_battle_outcome_mountain_destroyed_is_instant_win() -> void:
	state.structures = [{"type": "mountain", "team": "enemy", "tiles": [], "hp": 0, "maxHp": 100, "destroyed": true}]
	state.spawn_unit("p", {"team": "player", "hp": 10})
	state.spawn_unit("e", {"team": "enemy", "hp": 10})
	assert_true(state.check_battle_outcome())
	assert_true((state.event_log[-1] as String).contains("Vitória"))

func test_check_battle_outcome_castle_destroyed_is_instant_loss() -> void:
	state.structures = [{"type": "castle", "team": "player", "tiles": [], "hp": 0, "maxHp": 100, "destroyed": true}]
	state.spawn_unit("p", {"team": "player", "hp": 10})
	state.spawn_unit("e", {"team": "enemy", "hp": 10})
	assert_true(state.check_battle_outcome())
	assert_true((state.event_log[-1] as String).contains("Derrota"))

func test_check_battle_outcome_enemy_team_wiped_is_win() -> void:
	state.spawn_unit("p", {"team": "player", "hp": 10})
	state.spawn_unit("e", {"team": "enemy", "hp": 0})
	assert_true(state.check_battle_outcome())

func test_check_battle_outcome_returns_false_while_both_teams_alive() -> void:
	state.spawn_unit("p", {"team": "player", "hp": 10})
	state.spawn_unit("e", {"team": "enemy", "hp": 10})
	assert_false(state.check_battle_outcome())
	assert_false(state.battle_ended)

# --- note_unit_acted_this_round / decaimento de cadáver ----------------------

func test_note_unit_acted_this_round_advances_corpse_decay_once_round_completes() -> void:
	var alive := state.spawn_unit("alive", {"team": "player", "hp": 20})
	var corpse := state.spawn_unit("corpse", {"team": "player", "hp": 0, "x": 3, "y": 3, "turnsSinceDeath": 0})
	state.note_unit_acted_this_round(alive)
	assert_eq(corpse["turnsSinceDeath"], 1)

func test_apply_corpse_decay_tick_becomes_soul_after_the_4th_round() -> void:
	var corpse := state.spawn_unit("corpse", {"hp": 0, "x": 5, "y": 5, "turnsSinceDeath": 3})
	state.apply_corpse_decay_tick(corpse)
	assert_false(corpse.has("turnsSinceDeath"))
	assert_eq(state.souls.size(), 1)
	assert_eq(state.souls[0], {"x": 5, "y": 5, "hpAmount": 10, "mpAmount": 5})

## Bichos do SPD (rato/cobra/gnoll/slime/slime negro) não deixam cadáver
## ressuscitável: a morte já vira alma na hora, com metade da cura de uma
## alma normal (5 HP / 2 MP em vez de 10/5) — ver GameState.IMMEDIATE_SOUL_SPRITE_KEYS.
func test_finalize_death_routes_spd_mobs_straight_to_a_smaller_soul() -> void:
	var rat := state.spawn_unit("rat", {"team": "enemy", "hp": 0, "x": 4, "y": 4, "spriteKey": "spd_rat"})
	state.finalize_death_if_needed(rat)
	assert_false(rat.has("turnsSinceDeath"), "não vira cadáver ressuscitável")
	assert_eq(state.souls.size(), 1)
	assert_eq(state.souls[0], {"x": 4, "y": 4, "hpAmount": 5, "mpAmount": 2})

func test_finalize_death_keeps_normal_corpse_window_for_non_spd_units() -> void:
	var hero := state.spawn_unit("hero", {"team": "player", "hp": 0, "x": 2, "y": 2})
	state.finalize_death_if_needed(hero)
	assert_eq(hero["turnsSinceDeath"], 0)
	assert_true(state.souls.is_empty())

func test_finalize_death_only_runs_once_per_death() -> void:
	var rat := state.spawn_unit("rat", {"team": "enemy", "hp": 0, "x": 1, "y": 1, "spriteKey": "spd_rat"})
	state.finalize_death_if_needed(rat)
	state.finalize_death_if_needed(rat)
	assert_eq(state.souls.size(), 1, "não duplica a alma se chamado de novo antes de ressuscitar")

func test_apply_corpse_decay_tick_heals_occupant_instead_of_leaving_a_soul() -> void:
	var corpse := state.spawn_unit("corpse", {"hp": 0, "x": 5, "y": 5, "turnsSinceDeath": 3})
	var occupant := state.spawn_unit("occ", {"team": "player", "hp": 5, "maxHp": 20, "mp": 2, "maxMp": 10, "x": 5, "y": 5})
	state.apply_corpse_decay_tick(corpse)
	assert_eq(occupant["hp"], 15)
	assert_eq(occupant["mp"], 7)
	assert_eq(state.souls.size(), 0)

func test_soul_is_collected_when_path_crosses_its_tile_and_restores_hp_mp() -> void:
	var hero := state.spawn_unit("hero", {"hp": 4, "maxHp": 30, "mp": 1, "maxMp": 20})
	state.souls = [{"x": 2, "y": 1}]
	state.apply_soul_pickups(hero, [{"x": 1, "y": 1}, {"x": 2, "y": 1}, {"x": 3, "y": 1}])
	assert_eq(hero["hp"], 14)
	assert_eq(hero["mp"], 6)
	assert_true(state.souls.is_empty(), "a alma atravessada precisa desaparecer")

func test_soul_pickup_respects_hp_and_mp_limits() -> void:
	var hero := state.spawn_unit("hero", {"hp": 27, "maxHp": 30, "mp": 18, "maxMp": 20})
	state.souls = [{"x": 1, "y": 1}]
	state.apply_soul_pickups(hero, [{"x": 1, "y": 1}])
	assert_eq(hero["hp"], 30)
	assert_eq(hero["mp"], 20)

# --- begin_turn_for -----------------------------------------------------------

func test_begin_turn_for_sets_current_actor_regens_mp_and_resets_action_flags() -> void:
	var hero := state.spawn_unit("hero", {"team": "player", "hp": 20, "maxHp": 20, "mp": 5, "maxMp": 10, "hasMoved": true, "hasActed": true, "ct": 100, "speed": 10})
	state.spawn_unit("foe", {"team": "enemy", "hp": 20, "ct": 0, "speed": 5})
	state.begin_turn_for(hero)
	assert_eq(state.current_actor, hero)
	assert_eq(state.global_turn_count, 1)
	assert_false(hero["hasMoved"])
	assert_false(hero["hasActed"])
	assert_eq(hero["mp"], 6, "+1 MP passivo de início de turno")

func test_begin_turn_for_paralyzed_unit_loses_the_turn_and_chains_to_next_ready() -> void:
	var para := state.spawn_unit("para", {"team": "player", "hp": 20, "ct": 100, "speed": 5, "statusEffects": [{"type": "paralyzed", "turnsLeft": 1}]})
	var other := state.spawn_unit("other", {"team": "player", "hp": 20, "ct": 90, "speed": 20})
	state.spawn_unit("foe", {"team": "enemy", "hp": 20, "ct": 0, "speed": 1})
	state.begin_turn_for(para)
	# 100 - WAIT_COST(60) = 40, +5 de agilidade da própria `para` (ainda viva,
	# continua correndo a corrida de CT) durante o único tick que o
	# encadeamento (advance_ct_until_ready) precisa pra `other` ficar pronta.
	assert_eq(para["ct"], 45)
	assert_true((para["statusEffects"] as Array).is_empty(), "paralisia consumida (turnsLeft chegou a 0)")
	assert_eq(state.current_actor, other, "encadeou pro próximo pronto")
	assert_eq(state.global_turn_count, 2, "begin_turn_for rodou 2x: para (perdeu vez) + other")

## Pedido do usuário: dano por turno (veneno/sangramento/queimadura/raízes/
## fúria/regeneração) resolve no FIM do turno de quem tem o status, não no
## início — ver apply_status_effects_at_turn_end.
func test_advance_to_next_turn_unit_killed_by_own_status_at_turn_end_chains_to_next_ready() -> void:
	var doomed := state.spawn_unit("doomed", {"team": "player", "hp": 2, "maxHp": 20, "hasMoved": true, "hasActed": true, "ct": 40, "speed": 5, "statusEffects": [{"type": "poison", "damageMin": 5, "damageMax": 5, "turnsLeft": 1}]})
	var other := state.spawn_unit("other", {"team": "player", "hp": 20, "ct": 90, "speed": 20})
	state.spawn_unit("foe", {"team": "enemy", "hp": 20, "ct": 0, "speed": 1})
	state.current_actor = doomed
	state.advance_to_next_turn()
	assert_eq(doomed["hp"], 0)
	assert_eq(state.current_actor, other)

# --- advance_to_next_turn -----------------------------------------------------

## Nos 3 testes abaixo, `foe` já nasce com ct=100 (pronta) — assim o
## encadeamento (advance_ct_until_ready) devolve `foe` no primeiríssimo
## check, sem nenhum tick de CT extra, e `hero` não sofre nenhuma mutação
## além da que advance_to_next_turn já aplica diretamente nela.

func test_advance_to_next_turn_full_rest_pays_wait_cost_and_grants_mp_and_hp() -> void:
	var hero := state.spawn_unit("hero", {"team": "player", "hp": 10, "maxHp": 20, "mp": 5, "maxMp": 10, "hasMoved": false, "hasActed": false, "ct": 50, "speed": 5})
	state.spawn_unit("foe", {"team": "enemy", "hp": 20, "ct": 100, "speed": 1})
	state.current_actor = hero
	state.advance_to_next_turn()
	assert_eq(hero["ct"], 50 - GameConstants.WAIT_COST)
	assert_eq(hero["mp"], 8)
	assert_eq(hero["hp"], 11)

func test_advance_to_next_turn_partial_action_grants_partial_mp_only() -> void:
	var hero := state.spawn_unit("hero", {"team": "player", "hp": 10, "maxHp": 20, "mp": 5, "maxMp": 10, "hasMoved": true, "hasActed": false, "ct": 50, "speed": 5})
	state.spawn_unit("foe", {"team": "enemy", "hp": 20, "ct": 100, "speed": 1})
	state.current_actor = hero
	state.advance_to_next_turn()
	assert_eq(hero["ct"], 50, "moveu, então não paga o custo de espera")
	assert_eq(hero["mp"], 7)
	assert_eq(hero["hp"], 10)

func test_advance_to_next_turn_regen_status_grants_bonus_ct() -> void:
	var hero := state.spawn_unit("hero", {"team": "player", "hp": 10, "maxHp": 20, "hasMoved": true, "hasActed": true, "ct": 50, "speed": 5, "statusEffects": [{"type": "regen", "healMin": 2, "healMax": 2, "turnsLeft": 2}]})
	state.spawn_unit("foe", {"team": "enemy", "hp": 20, "ct": 100, "speed": 1})
	state.current_actor = hero
	state.advance_to_next_turn()
	assert_eq(hero["ct"], 60)

func test_advance_to_next_turn_clears_one_shot_buffs() -> void:
	var hero := state.spawn_unit("hero", {"team": "player", "hp": 10, "maxHp": 20, "hasMoved": true, "hasActed": true, "ct": 50, "speed": 5, "oneShotDamageBonus": 5, "guaranteedNextHit": true, "critBonusNextAttack": 0.5, "bonusAttacksRemaining": 2})
	state.spawn_unit("foe", {"team": "enemy", "hp": 20, "ct": 0, "speed": 1})
	state.current_actor = hero
	state.advance_to_next_turn()
	assert_eq(hero["oneShotDamageBonus"], 0)
	assert_null(hero["oneShotDamageBonusSource"])
	assert_false(hero["guaranteedNextHit"])
	assert_eq(hero["critBonusNextAttack"], 0)
	assert_eq(hero["bonusAttacksRemaining"], 0)

func test_advance_to_next_turn_decrements_only_triggered_traps() -> void:
	var hero := state.spawn_unit("hero", {"team": "player", "hp": 10, "maxHp": 20, "hasMoved": true, "hasActed": true, "ct": 50, "speed": 5})
	state.spawn_unit("foe", {"team": "enemy", "hp": 20, "ct": 0, "speed": 1})
	state.current_actor = hero
	state.traps = [
		{"triggered": true, "turnsLeft": 1, "tiles": [], "ownerTeam": "player"},
		{"triggered": false, "turnsLeft": 5, "tiles": [], "ownerTeam": "player"},
	]
	state.advance_to_next_turn()
	assert_eq(state.traps.size(), 1, "a armadilha acionada com turnsLeft esgotado some")
	assert_false(state.traps[0]["triggered"])

func test_untriggered_rogue_trap_remains_until_activated_or_disarmed() -> void:
	var hero := state.spawn_unit("hero", {"team": "player", "hp": 10, "maxHp": 20, "hasMoved": true, "hasActed": true, "ct": 50, "speed": 5})
	state.spawn_unit("foe", {"team": "enemy", "hp": 20, "ct": 0, "speed": 1})
	state.current_actor = hero
	state.traps = [{"triggered": false, "turnsLeft": null, "tiles": [{"x": 3, "y": 3}], "ownerTeam": "player"}]
	for turn in range(10):
		state.advance_to_next_turn()
	assert_eq(state.traps.size(), 1, "armadilha não acionada não expira com o tempo")
	assert_false(state.traps[0]["triggered"])
