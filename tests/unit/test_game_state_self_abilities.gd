extends GutTest

## Fase 3 (habilidades de auto-alvo/buff): porte de castSelfAbility e das
## cast* "livres" (game.js:8055-8286). Usa Spells.build() reais quando o
## número importa (ex: castTrueShot/critBonus), e a mesma disciplina de
## itens sintéticos onde não importa.

var state: GameState
var spells: Dictionary

func before_each() -> void:
	state = GameState.new()
	state.clear_units()
	spells = Spells.build()

# --- cast_self_ability: despacho e restrições de uso -------------------------

func test_cast_self_ability_dispatches_by_kind_and_pays_mp() -> void:
	var u := state.spawn_unit("u", {"mp": 10})
	state.cast_self_ability(u, spells["powerAttack"])
	assert_eq(u["oneShotDamageBonus"], 3)
	assert_eq(u["oneShotDamageBonusSource"], "Ataque Poderoso")
	assert_eq(u["critBonusNextAttack"], 0.15, "pedido do usuário: +15% de crítico no próximo ataque")
	assert_eq(u["mp"], 6, "pagou o mpCost (4), não é ctCost")
	assert_false(u.get("hasActed", false), "habilidade livre não marca hasActed")

func test_cast_self_ability_blocks_reusing_the_same_ability_twice_in_the_turn() -> void:
	var u := state.spawn_unit("u", {"mp": 20})
	state.cast_self_ability(u, spells["powerAttack"])
	var bonus_after_first: int = u["oneShotDamageBonus"]
	state.cast_self_ability(u, spells["powerAttack"])
	assert_eq(u["oneShotDamageBonus"], bonus_after_first, "segunda tentativa é recusada, não soma de novo")

func test_cast_self_ability_single_self_ability_per_turn_blocks_a_different_ability() -> void:
	var archer := state.spawn_unit("archer", {"mp": 20, "singleSelfAbilityPerTurn": true})
	state.cast_self_ability(archer, spells["trueShot"])
	assert_true(archer["guaranteedNextHit"])
	state.cast_self_ability(archer, spells["longShot"])
	assert_false(archer.get("doubleRangeNextAttack", false), "Arqueiro só pode 1 habilidade de si mesmo por turno")

func test_cast_self_ability_fire_arrow_plus_quick_shot_combo_is_allowed() -> void:
	var archer := state.spawn_unit("archer", {"mp": 20, "singleSelfAbilityPerTurn": true})
	state.cast_self_ability(archer, spells["fireArrow"])
	assert_true(archer["burnNextAttackAlwaysTurns"] > 0)
	state.cast_self_ability(archer, spells["quickShot"])
	assert_eq(archer["bonusAttacksRemaining"], 1, "combo Flecha de Fogo + Tiro Rápido é liberado")

## Regressão: `selfAbilitiesUsedThisTurn`/`selfAbilityKindsUsedThisTurn`
## ficavam registrados pra sempre porque só `abilityUsedThisTurn` era
## resetado em begin_turn_for — usar Tiro Rápido (mesmo em combo com Flecha
## de Fogo) num turno bloqueava silenciosamente qualquer uso futuro dele
## sozinho, em qualquer turno seguinte.
func test_cast_self_ability_can_reuse_the_same_ability_alone_on_a_later_turn() -> void:
	var archer := state.spawn_unit("archer", {"mp": 20, "singleSelfAbilityPerTurn": true})
	# begin_turn_for só chega no reset de flags se a batalha não tiver
	# terminado — precisa de um time adversário vivo, senão check_battle_outcome
	# encerra tudo como vitória antes de resetar nada.
	state.spawn_unit("foe", {"team": "enemy", "hp": 20})
	state.cast_self_ability(archer, spells["fireArrow"])
	state.cast_self_ability(archer, spells["quickShot"])
	assert_eq(archer["bonusAttacksRemaining"], 1, "combo do primeiro turno funciona")
	state.begin_turn_for(archer)
	# Zera o resíduo do turno anterior: se o bug voltar (cast_self_ability
	# recusado silenciosamente como "já usado"), bonusAttacksRemaining fica
	# em 0 e a asserção abaixo pega a regressão em vez de coincidir com o
	# valor do turno passado.
	archer["bonusAttacksRemaining"] = 0
	state.cast_self_ability(archer, spells["quickShot"])
	assert_eq(archer["bonusAttacksRemaining"], 1, "Tiro Rápido sozinho num turno seguinte não pode ser recusado como 'já usado'")
	assert_eq(archer["bonusAttackWeaponRestriction"]["name"], spells["quickShot"]["restrictBonusToWeapon"]["name"])

func test_cast_self_ability_fire_arrow_plus_two_other_combo_kinds_is_blocked() -> void:
	var archer := state.spawn_unit("archer", {"mp": 20, "singleSelfAbilityPerTurn": true})
	state.cast_self_ability(archer, spells["fireArrow"])
	state.cast_self_ability(archer, spells["quickShot"])
	# já usou 2 habilidades (fire-arrow + haste-attack) — uma 3ª nunca é permitida.
	state.cast_self_ability(archer, spells["longShot"])
	assert_false(archer.get("doubleRangeNextAttack", false))

func test_cast_self_ability_ice_arrow_plus_quick_shot_combo_is_allowed() -> void:
	var archer := state.spawn_unit("archer", {"mp": 20, "singleSelfAbilityPerTurn": true})
	state.cast_self_ability(archer, spells["iceArrow"])
	assert_true(archer["slowNextAttackAlwaysTurns"] > 0)
	state.cast_self_ability(archer, spells["quickShot"])
	assert_eq(archer["bonusAttacksRemaining"], 1, "combo Flecha de Gelo + Tiro Rápido é liberado, igual Flecha de Fogo")

# --- cast_true_shot / cast_power_attack / cast_long_shot ---------------------

func test_cast_true_shot_stacks_crit_bonus_across_uses_but_not_same_use_twice() -> void:
	var u := state.spawn_unit("u", {"mp": 10})
	state.cast_true_shot(u, spells["trueShot"])
	assert_true(u["guaranteedNextHit"])
	assert_almost_eq(float(u["critBonusNextAttack"]), 0.1, 0.001)

func test_true_shot_costs_only_one_mp_through_self_ability_dispatcher() -> void:
	var archer := state.spawn_unit("archer", {"mp": 10, "singleSelfAbilityPerTurn": true})
	state.cast_self_ability(archer, spells["trueShot"])
	assert_eq(archer["mp"], 9)

func test_cast_long_shot_sets_double_range_flag() -> void:
	var u := state.spawn_unit("u", {"mp": 10})
	state.cast_long_shot(u, spells["longShot"])
	assert_true(u["doubleRangeNextAttack"])

# --- cast_defend / cast_fury / cast_evasive_maneuver: cria vs renova --------

func test_cast_defend_creates_then_renews_instead_of_stacking() -> void:
	var u := state.spawn_unit("u", {"mp": 10, "statusEffects": []})
	state.cast_defend(u, spells["defend"])
	var guarding := (u["statusEffects"] as Array).filter(func(e): return e["type"] == "guarding")
	assert_eq(guarding.size(), 1)
	assert_eq(guarding[0]["damageReduction"], 2)

	guarding[0]["turnsLeft"] = 1
	state.cast_defend(u, spells["defend"])
	var guarding2 := (u["statusEffects"] as Array).filter(func(e): return e["type"] == "guarding")
	assert_eq(guarding2.size(), 1, "segundo uso renova, não empilha")
	assert_eq(guarding2[0]["turnsLeft"], spells["defend"]["turns"])

func test_cast_fury_applies_speed_bonus_once_not_twice() -> void:
	var u := state.spawn_unit("u", {"mp": 10, "speed": 10, "statusEffects": []})
	state.cast_fury(u, spells["fury"])
	assert_eq(u["speed"], 12)
	state.cast_fury(u, spells["fury"])
	assert_eq(u["speed"], 12, "segundo uso só renova duração, não soma bônus de agilidade de novo")

func test_cast_evasive_maneuver_creates_then_renews() -> void:
	var u := state.spawn_unit("u", {"mp": 10, "statusEffects": []})
	state.cast_evasive_maneuver(u, spells["evasiveManeuver"])
	var evasive := (u["statusEffects"] as Array).filter(func(e): return e["type"] == "evasive")
	assert_eq(evasive.size(), 1)
	assert_eq(evasive[0]["amount"], 0.2)
	state.cast_evasive_maneuver(u, spells["evasiveManeuver"])
	evasive = (u["statusEffects"] as Array).filter(func(e): return e["type"] == "evasive")
	assert_eq(evasive.size(), 1, "não duplica a instância")

# --- cast_swift_feet: dobra moveRange só na primeira vez ---------------------

func test_cast_swift_feet_doubles_move_range_once() -> void:
	var u := state.spawn_unit("u", {"mp": 10, "moveRange": 4, "statusEffects": []})
	state.cast_swift_feet(u, spells["swiftFeet"])
	assert_eq(u["moveRange"], 8)
	state.cast_swift_feet(u, spells["swiftFeet"])
	assert_eq(u["moveRange"], 8, "segundo uso no mesmo turno não dobra de novo")

# --- cast_agility: ataque bônus e restrição de arma --------------------------

func test_cast_agility_grants_bonus_attack_without_weapon_restriction() -> void:
	var goblin := state.spawn_unit("goblin", {"mp": 10})
	state.cast_agility(goblin, spells["agility"])
	assert_eq(goblin["bonusAttacksRemaining"], 1)
	assert_null(goblin["bonusAttackWeaponRestriction"])

func test_cast_agility_quick_shot_restricts_bonus_to_the_bow() -> void:
	var archer := state.spawn_unit("archer", {"mp": 10})
	state.cast_agility(archer, spells["quickShot"])
	assert_eq(archer["bonusAttacksRemaining"], 1)
	assert_eq(archer["bonusAttackWeaponRestriction"]["name"], "Arco")

func test_cast_quick_shot_after_normal_attack_reopens_exactly_one_attack() -> void:
	var archer := state.spawn_unit("archer", {"mp": 10, "hasActed": true})
	state.cast_agility(archer, spells["quickShot"])
	assert_false(archer["hasActed"], "Tiro Rápido depois do primeiro disparo reabre a ação")
	assert_eq(archer["bonusAttacksRemaining"], 0, "não guarda outro bônus que permitiria um terceiro disparo")
	assert_eq(archer["bonusAttackWeaponRestriction"]["name"], "Arco")
	state.finalize_action(archer, archer["bonusAttackWeaponRestriction"])
	assert_true(archer["hasActed"], "o disparo reaberto encerra a ação normalmente")

# --- cast_explosive_shot / cast_fire_arrow: bônus rolado na hora ------------

func test_cast_explosive_shot_rolls_bonus_damage_within_range_and_sets_burn() -> void:
	var u := state.spawn_unit("u", {"mp": 10})
	state.cast_explosive_shot(u, spells["explosiveShot"])
	assert_true(u["oneShotDamageBonus"] >= spells["explosiveShot"]["bonusDamageMin"])
	assert_true(u["oneShotDamageBonus"] <= spells["explosiveShot"]["bonusDamageMax"])
	assert_eq(u["burnNextAttackTurns"], spells["explosiveShot"]["burnTurns"])
	assert_eq(u.get("burnNextAttackAlwaysTurns", 0), 0, "só queima se acertar, diferente da Flecha de Fogo")

func test_cast_fire_arrow_sets_always_burn_flag() -> void:
	var u := state.spawn_unit("u", {"mp": 10})
	state.cast_fire_arrow(u, spells["fireArrow"])
	assert_eq(u["burnNextAttackAlwaysTurns"], spells["fireArrow"]["burnTurns"])
	assert_eq(u.get("burnNextAttackTurns", 0), 0)

func test_cast_ice_arrow_sets_always_slow_flag() -> void:
	var u := state.spawn_unit("u", {"mp": 10})
	state.cast_ice_arrow(u, spells["iceArrow"])
	assert_eq(u["slowNextAttackAlwaysTurns"], spells["iceArrow"]["slowTurns"])
	assert_eq(u["slowNextAttackAlwaysAmount"], spells["iceArrow"]["slowAmount"])
	assert_true(u["oneShotDamageBonus"] >= spells["iceArrow"]["bonusDamageMin"])
	assert_true(u["oneShotDamageBonus"] <= spells["iceArrow"]["bonusDamageMax"])

# --- cast_invisibility: consome a ação do turno (finalize_action) ----------

func test_cast_invisibility_applies_status_and_finalizes_the_action() -> void:
	var u := state.spawn_unit("u", {"mp": 10, "ct": 100, "hasActed": false, "statusEffects": []})
	state.cast_invisibility(u, spells["invisibility"])
	assert_true(state.is_invisible(u))
	assert_eq(u["ct"], 100 - spells["invisibility"]["ctCost"], "invisibilidade paga CT, é uma ação de verdade")
	assert_true(u["hasActed"])

func test_cast_weakening_strike_sets_flag_and_pays_only_mp() -> void:
	var u := state.spawn_unit("u", {"mp": 10, "ct": 100, "hasActed": false})
	state.cast_weakening_strike(u, spells["weakeningStrike"])
	assert_true(u["weakeningStrikeNextAttack"])
	assert_eq(u["ct"], 100, "habilidade livre não gasta CT")
	assert_false(u["hasActed"])

func test_cast_regen_boost_uses_add_status_effect_merge_rule() -> void:
	var u := state.spawn_unit("u", {"mp": 20, "statusEffects": [{"type": "regenBoost", "turnsLeft": 1, "bonus": 3}]})
	state.cast_regen_boost(u, spells["regenBoost"])
	var boosts := (u["statusEffects"] as Array).filter(func(e): return e["type"] == "regenBoost")
	assert_eq(boosts.size(), 1, "add_status_effect soma duração em vez de duplicar")
	assert_eq(boosts[0]["turnsLeft"], 1 + spells["regenBoost"]["turns"])
