extends GutTest

## Fase 2 (combate + status effects): porte de getHitChance/getCritChance/
## getAttackAngle/getEffectiveHitChance/resolveSingleHit/finalizeAction/
## addStatusEffect/applyStatusEffectsAtTurnStart (game.js:1054-1256,
## 4984-5417, 7272-7646, 8582-8619). Itens de teste são sintéticos (hitChance
## e critChance forçados em 0/1) pra evitar depender do RNG sempre que
## possível, igual o espírito de `Math.random = () => 0.01` nos testes JS.

var state: GameState

func before_each() -> void:
	state = GameState.new()
	state.clear_units()
	state.clear_terrain_and_structures()

func _weapon(overrides: Dictionary) -> Dictionary:
	var w := {
		"name": "arma-teste", "ctCost": 50, "damageMin": 5, "damageMax": 5,
		"critMultiplier": 2, "critChance": 0.0, "hitChance": 1.0,
		"minRange": 1, "maxRange": 1,
	}
	for k in overrides.keys():
		w[k] = overrides[k]
	return w

# --- get_hit_chance / get_crit_chance / get_attack_angle -------------------

func test_get_hit_chance_reads_flat_value() -> void:
	assert_eq(state.get_hit_chance(_weapon({"hitChance": 0.7}), 1), 0.7)

func test_get_crit_chance_defaults_and_by_angle() -> void:
	assert_eq(state.get_crit_chance(_weapon({})), 0.0)
	var no_crit_field := {"name": "x"}
	assert_eq(state.get_crit_chance(no_crit_field), GameConstants.CRIT_CHANCE)
	var dirk := {"critChanceByAngle": {"front": 0.15, "side": 0.2, "back": 0.25}}
	assert_eq(state.get_crit_chance(dirk, "back"), 0.25)
	assert_eq(state.get_crit_chance(dirk, "side"), 0.2)

func test_get_crit_chance_invisible_overrides_by_angle_at_flat_20_percent() -> void:
	var dirk := {"critChanceByAngle": {"front": 0.15, "side": 0.2, "back": 0.25}, "invisibleCritChance": 0.20}
	var visible_attacker := {"statusEffects": []}
	var invisible_attacker := {"statusEffects": [{"type": "invisible", "turnsLeft": 2}]}
	assert_eq(state.get_crit_chance(dirk, "back", visible_attacker), 0.25, "visível: continua por ângulo")
	assert_eq(state.get_crit_chance(dirk, "front", invisible_attacker), 0.20, "invisível: 20% mesmo de frente")
	assert_eq(state.get_crit_chance(dirk, "back", invisible_attacker), 0.20, "invisível: 20% também pelas costas, não soma com o de ângulo")

func test_get_attack_angle_front_side_back() -> void:
	var defender := {"x": 5, "y": 5, "facing": {"dx": 1, "dy": 0}}
	assert_eq(state.get_attack_angle({"x": 6, "y": 5}, defender), "front")
	assert_eq(state.get_attack_angle({"x": 4, "y": 5}, defender), "back")
	assert_eq(state.get_attack_angle({"x": 5, "y": 4}, defender), "side")

# --- get_effective_hit_chance ------------------------------------------------

func test_effective_hit_chance_angle_bonus_and_status_penalties() -> void:
	var attacker := state.spawn_unit("att", {"x": 4, "y": 5})
	var defender := state.spawn_unit("def", {"x": 5, "y": 5, "facing": {"dx": 1, "dy": 0}})
	var item := _weapon({"hitChance": 0.5})
	# Ataque vindo de trás: +0.2.
	assert_almost_eq(state.get_effective_hit_chance(attacker, defender, item, 1), 0.7, 0.001)

	attacker["statusEffects"] = [{"type": "blinded", "turnsLeft": 1}]
	assert_almost_eq(state.get_effective_hit_chance(attacker, defender, item, 1), 0.6, 0.001)

func test_effective_hit_chance_clamped_between_0_and_1() -> void:
	var attacker := state.spawn_unit("att", {"x": 4, "y": 5, "statusEffects": [{"type": "blinded", "turnsLeft": 1}, {"type": "dazed", "turnsLeft": 1}]})
	var defender := state.spawn_unit("def", {"x": 5, "y": 5, "facing": {"dx": -1, "dy": 0}, "innateEvasion": 0.9})
	var item := _weapon({"hitChance": 0.1})
	assert_eq(state.get_effective_hit_chance(attacker, defender, item, 1), 0.0)

func test_effective_hit_chance_ranged_melee_penalty() -> void:
	var attacker := state.spawn_unit("att", {"x": 4, "y": 5})
	var defender := state.spawn_unit("def", {"x": 5, "y": 5, "facing": {"dx": 1, "dy": 0}})
	var bow := _weapon({"hitChance": 0.8, "minRange": 2, "maxRange": 5})
	# distância 1 (queima-roupa) com arma de alcance > 1: -10pp, além do
	# bônus de ângulo de trás (+20pp) => 0.8 + 0.2 - 0.1 = 0.9.
	assert_almost_eq(state.get_effective_hit_chance(attacker, defender, bow, 1), 0.9, 0.001)

# --- resolve_single_hit ------------------------------------------------------

func test_resolve_single_hit_guaranteed_hit_deals_exact_damage() -> void:
	var attacker := state.spawn_unit("att", {"x": 1, "y": 1})
	var defender := state.spawn_unit("def", {"x": 1, "y": 2, "hp": 20, "maxHp": 20})
	var item := _weapon({"damageMin": 5, "damageMax": 5})
	var hit := state.resolve_single_hit(attacker, defender, item)
	assert_true(hit)
	assert_eq(defender["hp"], 15)

func test_resolve_single_hit_zero_hit_chance_always_misses() -> void:
	# Ataque vindo de FRENTE (facing padrão {dx:1,dy:0} do defensor, atacante
	# no eixo +x dele): sem bônus de ângulo, então a chance efetiva fica
	# exatamente em 0, não só "baixa" — garante que o teste não seja flaky.
	var attacker := state.spawn_unit("att", {"x": 2, "y": 1})
	var defender := state.spawn_unit("def", {"x": 1, "y": 1, "hp": 20, "maxHp": 20})
	var item := _weapon({"hitChance": 0.0})
	var hit := state.resolve_single_hit(attacker, defender, item)
	assert_false(hit)
	assert_eq(defender["hp"], 20)

func test_resolve_single_hit_invisible_defender_blocks_weapon_attack() -> void:
	var attacker := state.spawn_unit("att", {"x": 1, "y": 1})
	var defender := state.spawn_unit("def", {"x": 1, "y": 2, "hp": 20, "statusEffects": [{"type": "invisible", "turnsLeft": 2}]})
	var item := _weapon({})
	var hit := state.resolve_single_hit(attacker, defender, item)
	assert_false(hit)
	assert_eq(defender["hp"], 20)

func test_resolve_single_hit_aoe_spell_bypasses_invisibility() -> void:
	var attacker := state.spawn_unit("att", {"x": 1, "y": 1})
	var defender := state.spawn_unit("def", {"x": 1, "y": 2, "hp": 20, "statusEffects": [{"type": "invisible", "turnsLeft": 2}]})
	var fireball := _weapon({"mpCost": 10, "targetMode": "point-aoe", "damageMin": 3, "damageMax": 3})
	var hit := state.resolve_single_hit(attacker, defender, fireball)
	assert_true(hit)
	assert_eq(defender["hp"], 17)

func test_resolve_single_hit_flying_defender_immune_to_melee_but_not_ranged() -> void:
	var attacker := state.spawn_unit("att", {"x": 1, "y": 1})
	var defender := state.spawn_unit("def", {"x": 1, "y": 2, "hp": 20, "flying": true})
	var melee := _weapon({})
	assert_false(state.resolve_single_hit(attacker, defender, melee))
	assert_eq(defender["hp"], 20)

	var ranged := _weapon({"minRange": 1, "maxRange": 3, "damageMin": 4, "damageMax": 4})
	assert_true(state.resolve_single_hit(attacker, defender, ranged))
	assert_eq(defender["hp"], 16)

func test_resolve_single_hit_aerial_weapon_can_hit_flying_at_melee_range() -> void:
	var attacker := state.spawn_unit("att", {"x": 1, "y": 1})
	var defender := state.spawn_unit("def", {"x": 1, "y": 2, "hp": 20, "flying": true})
	var crossbow := _weapon({"aerial": true, "damageMin": 4, "damageMax": 4})
	assert_true(state.resolve_single_hit(attacker, defender, crossbow))
	assert_eq(defender["hp"], 16)

func test_resolve_single_hit_applies_poison_on_hit() -> void:
	var attacker := state.spawn_unit("att", {"x": 1, "y": 1})
	var defender := state.spawn_unit("def", {"x": 1, "y": 2, "hp": 20})
	var item := _weapon({"appliesPoison": {"damageMin": 1, "damageMax": 3, "turns": 3, "ctDrainPerTurn": 10}})
	state.resolve_single_hit(attacker, defender, item)
	var poison = null
	for e in defender["statusEffects"]:
		if e["type"] == "poison":
			poison = e
	assert_not_null(poison)
	assert_eq(poison["turnsLeft"], 3)
	assert_eq(poison["ctDrainPerTurn"], 10)

func test_resolve_single_hit_applies_ct_drain_with_confirm_chance() -> void:
	var attacker := state.spawn_unit("att", {"x": 1, "y": 1})
	var defender := state.spawn_unit("def", {"x": 1, "y": 2, "hp": 20, "ct": 50})
	var always := _weapon({"appliesCtDrain": 10})
	state.resolve_single_hit(attacker, defender, always)
	assert_eq(defender["ct"], 40)

	defender["ct"] = 50
	defender["hp"] = 20
	var never := _weapon({"appliesCtDrain": 10, "ctDrainConfirmChance": 0.0})
	state.resolve_single_hit(attacker, defender, never)
	assert_eq(defender["ct"], 50, "confirmChance 0 nunca confirma o roubo de CT")

func test_resolve_single_hit_backstab_bonus_applies_from_side_and_back_not_front() -> void:
	var defender := state.spawn_unit("def", {"x": 5, "y": 5, "hp": 100, "facing": {"dx": 1, "dy": 0}})
	var item := _weapon({"damageMin": 5, "damageMax": 5})
	var backstab := {"side": [1, 1], "back": [2, 2], "invisible": [3, 3]}

	var back_attacker := state.spawn_unit("back", {"x": 4, "y": 5, "backstabBonus": backstab})
	state.resolve_single_hit(back_attacker, defender, item)
	assert_eq(defender["hp"], 93, "5 de dano + 2 de furtivo pelas costas")

	defender["hp"] = 100
	var front_attacker := state.spawn_unit("front", {"x": 6, "y": 5, "backstabBonus": backstab})
	state.resolve_single_hit(front_attacker, defender, item)
	assert_eq(defender["hp"], 95, "sem bônus furtivo atacando de frente")

	defender["hp"] = 100
	var side_attacker := state.spawn_unit("side", {"x": 5, "y": 4, "backstabBonus": backstab})
	state.resolve_single_hit(side_attacker, defender, item)
	assert_eq(defender["hp"], 94, "5 de dano + 1 de furtivo pelo lado")

	defender["hp"] = 100
	front_attacker["statusEffects"] = [{"type": "invisible", "turnsLeft": 2}]
	state.resolve_single_hit(front_attacker, defender, item)
	assert_eq(defender["hp"], 92, "invisível vale o bônus mais forte mesmo atacando de frente, não soma com ângulo")

func test_resolve_single_hit_passive_counter_attack_triggers_when_guaranteed() -> void:
	var attacker := state.spawn_unit("att", {"x": 1, "y": 1, "hp": 100})
	var counter_weapon := _weapon({"name": "revide", "damageMin": 3, "damageMax": 3})
	var defender := state.spawn_unit("def", {"x": 1, "y": 2, "hp": 100, "counterAttackChance": 1.0, "counterWeapon": counter_weapon})
	var item := _weapon({"damageMin": 2, "damageMax": 2})
	state.resolve_single_hit(attacker, defender, item)
	assert_eq(defender["hp"], 98, "levou o golpe original")
	assert_eq(attacker["hp"], 97, "e revidou de volta")

func test_resolve_single_hit_defend_and_passive_reduction_stack() -> void:
	var attacker := state.spawn_unit("att", {"x": 1, "y": 1})
	var defender := state.spawn_unit("def", {"x": 1, "y": 2, "hp": 100, "passiveDamageReduction": 1, "statusEffects": [{"type": "guarding", "turnsLeft": 2, "damageReduction": 2}]})
	var item := _weapon({"damageMin": 10, "damageMax": 10})
	state.resolve_single_hit(attacker, defender, item)
	assert_eq(defender["hp"], 93, "10 de dano - 2 (Defender) - 1 (passiva) = 7")

# --- antagonismo elemental: gelo apaga queimadura, fogo apaga lentidão -------
# Pedido do usuário: ser atingido por um ataque de gelo cancela o "queimando"
# vigente, e ser atingido por um ataque de fogo cancela a "lentidão" (Raio de
# Gelo/Flecha de Gelo/Bomba de Gelo/Cone de Gelo).

func test_resolve_single_hit_ice_attack_cancels_burned_status() -> void:
	var attacker := state.spawn_unit("att", {"x": 1, "y": 1})
	var defender := state.spawn_unit("def", {"x": 1, "y": 2, "hp": 100, "statusEffects": [{"type": "burned", "turnsLeft": 2, "damageMin": 1, "damageMax": 1}]})
	var ice_item := _weapon({"damageMin": 3, "damageMax": 3, "damageType": "ice"})
	state.resolve_single_hit(attacker, defender, ice_item)
	assert_false((defender["statusEffects"] as Array).any(func(e): return e["type"] == "burned"), "acerto de gelo apaga a queimadura")

func test_resolve_single_hit_fire_attack_cancels_slowed_status_and_restores_speed() -> void:
	var attacker := state.spawn_unit("att", {"x": 1, "y": 1})
	var defender := state.spawn_unit("def", {"x": 1, "y": 2, "hp": 100, "speed": 8, "statusEffects": [{"type": "slowed", "turnsLeft": 2, "speedReduction": 1}]})
	var fire_item := _weapon({"damageMin": 3, "damageMax": 3, "damageType": "fire"})
	state.resolve_single_hit(attacker, defender, fire_item)
	assert_false((defender["statusEffects"] as Array).any(func(e): return e["type"] == "slowed"), "acerto de fogo apaga a lentidão")
	assert_eq(defender["speed"], 9, "desfaz a redução de agilidade ao remover o status")

# --- finalize_action ----------------------------------------------------------

func test_finalize_action_pays_ct_and_mp_and_marks_acted() -> void:
	var u := state.spawn_unit("u", {"ct": 100, "mp": 10, "hasActed": false})
	state.finalize_action(u, _weapon({"ctCost": 50, "mpCost": 3}))
	assert_eq(u["ct"], 50)
	assert_eq(u["mp"], 7)
	assert_true(u["hasActed"])

func test_finalize_action_bonus_attack_consumes_without_marking_acted() -> void:
	var u := state.spawn_unit("u", {"ct": 100, "mp": 10, "hasActed": false, "bonusAttacksRemaining": 1})
	state.finalize_action(u, _weapon({}))
	assert_eq(u["bonusAttacksRemaining"], 0)
	assert_false(u["hasActed"], "ainda sobra o ataque bônus pra usar neste turno")

func test_finalize_action_bonus_attack_wrong_weapon_ends_round_immediately() -> void:
	var bow := _weapon({"name": "arco"})
	var dagger := _weapon({"name": "adaga"})
	var u := state.spawn_unit("u", {"ct": 100, "mp": 10, "hasActed": false, "bonusAttacksRemaining": 1, "bonusAttackWeaponRestriction": bow})
	state.finalize_action(u, dagger)
	assert_eq(u["bonusAttacksRemaining"], 0)
	assert_null(u["bonusAttackWeaponRestriction"])
	assert_true(u["hasActed"], "usar outra arma perde o disparo bônus e encerra a rodada")

# --- add_status_effect / apply_status_effects_at_turn_start ------------------

func test_add_status_effect_sums_duration_for_dot_types_instead_of_stacking() -> void:
	var u := state.spawn_unit("u", {"statusEffects": [{"type": "poison", "damageMin": 1, "damageMax": 3, "turnsLeft": 2}]})
	state.add_status_effect(u, {"type": "poison", "damageMin": 1, "damageMax": 3, "turnsLeft": 3})
	var poisons := (u["statusEffects"] as Array).filter(func(e): return e["type"] == "poison")
	assert_eq(poisons.size(), 1, "não duplica instância, soma duração")
	assert_eq(poisons[0]["turnsLeft"], 5)

func test_add_status_effect_sums_move_reduction_for_weakened() -> void:
	var u := state.spawn_unit("u", {"statusEffects": [{"type": "weakened", "turnsLeft": 1, "moveReduction": 1}]})
	state.add_status_effect(u, {"type": "weakened", "turnsLeft": 3, "moveReduction": 1})
	var weakened = (u["statusEffects"] as Array)[0]
	assert_eq(weakened["turnsLeft"], 4)
	assert_eq(weakened["moveReduction"], 2)

func test_apply_status_effects_poison_ticks_damage_and_ct_then_expires() -> void:
	# Dano por turno (poison/bleed/burned/root/fury/regen) só resolve no FIM
	# do turno de quem tem o status — pedido do usuário, ver
	# apply_status_effects_at_turn_end.
	var u := state.spawn_unit("u", {"hp": 20, "maxHp": 20, "ct": 20, "statusEffects": [{"type": "poison", "damageMin": 2, "damageMax": 2, "turnsLeft": 1, "ctDrainPerTurn": 5}]})
	state.apply_status_effects_at_turn_end(u)
	assert_eq(u["hp"], 18)
	assert_eq(u["ct"], 15)
	assert_true((u["statusEffects"] as Array).is_empty(), "expirou (turnsLeft chegou a 0)")

func test_apply_status_effects_fury_drains_hp_then_removes_speed_bonus_on_expiry() -> void:
	var u := state.spawn_unit("u", {"hp": 20, "maxHp": 20, "speed": 10, "statusEffects": [{"type": "fury", "hpDrainPerTurn": 1, "speedBonus": 2, "damageBonus": 2, "turnsLeft": 1}]})
	state.apply_status_effects_at_turn_end(u)
	assert_eq(u["hp"], 19)
	assert_eq(u["speed"], 8, "fúria expirou, devolve o bônus de agilidade")
	assert_true((u["statusEffects"] as Array).is_empty())

func test_apply_status_effects_weakened_restores_move_range_on_expiry() -> void:
	var u := state.spawn_unit("u", {"moveRange": 3, "statusEffects": [{"type": "weakened", "turnsLeft": 1, "moveReduction": 1}]})
	state.apply_status_effects_at_turn_start(u)
	assert_eq(u["moveRange"], 4)

func test_apply_status_effects_regen_heals_and_caps_at_max_hp() -> void:
	var u := state.spawn_unit("u", {"hp": 19, "maxHp": 20, "statusEffects": [{"type": "regen", "healMin": 5, "healMax": 5, "turnsLeft": 2}]})
	state.apply_status_effects_at_turn_end(u)
	assert_eq(u["hp"], 20, "cura mas não passa do maxHp")
	assert_eq((u["statusEffects"] as Array)[0]["turnsLeft"], 1)
