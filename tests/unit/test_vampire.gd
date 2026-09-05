extends GutTest

## Vampiro: novo inimigo (pedido do usuário). Cobre stats, Mordida/Toque
## Vampírico (lifesteal genérico baseado no dano REAL causado), Virar
## Morcego (ação livre, MOV dobrado, Voo temporário igual à Fada, lifesteal
## 100%, expira no início do PRÓPRIO próximo turno do Vampiro), Invocar
## Morcegos (variação da Cobra com Voo permanente + lifesteal 50%), e a
## classificação undead (fraqueza a gelo ×0.5, sem sangramento).

var state: GameState

func before_each() -> void:
	state = GameState.new()
	state.clear_units()
	state.clear_terrain_and_structures()

func _certain(item: Dictionary) -> Dictionary:
	var copy: Dictionary = item.duplicate(true)
	copy["hitChance"] = 1.0
	copy["critChance"] = 0.0
	return copy

func _vampire(overrides: Dictionary = {}) -> Dictionary:
	var data := GameState.dungeon_monster_data("vampire", 1, {"x": 5, "y": 5})
	for k in overrides.keys():
		data[k] = overrides[k]
	return state.spawn_unit(String(data["name"]), data)

func test_stats_match_spec() -> void:
	var data := GameState.dungeon_monster_data("vampire")
	assert_eq(data["maxHp"], 35)
	assert_eq(data["maxMp"], 15)
	assert_eq(data["speed"], 10)
	assert_eq(data["moveRange"], 3)
	assert_true(data["undead"])

# --- Mordida / Toque Vampírico -------------------------------------------

func test_bite_deals_4_to_8_costs_50_ct_melee_and_heals_half_actual_damage() -> void:
	var vamp := _vampire({"hp": 20, "maxHp": 35})
	var bite: Dictionary = vamp["weapons"][0]
	assert_eq(bite["name"], "Mordida")
	assert_eq(bite["damageMin"], 4)
	assert_eq(bite["damageMax"], 8)
	assert_eq(bite["ctCost"], 50)
	assert_eq(bite["maxRange"], 1)
	var item := _certain(bite)
	item["damageMin"] = 6; item["damageMax"] = 6
	var target := state.spawn_unit("alvo", {"x": 6, "y": 5, "hp": 30, "maxHp": 30, "team": "player"})
	state.resolve_single_hit(vamp, target, item)
	assert_eq(target["hp"], 24, "6 de dano")
	assert_eq(vamp["hp"], 23, "cura floor(6*0.5)=3: 20+3=23")

func test_vampiric_touch_deals_3_to_6_costs_50_ct_range_3() -> void:
	var vamp := _vampire()
	var touch: Dictionary = vamp["weapons"][1]
	assert_eq(touch["name"], "Toque Vampírico")
	assert_eq(touch["damageMin"], 3)
	assert_eq(touch["damageMax"], 6)
	assert_eq(touch["ctCost"], 50)
	assert_eq(touch["minRange"], 1)
	assert_eq(touch["maxRange"], 3)

func test_lifesteal_uses_actual_damage_removed_not_the_raw_roll() -> void:
	var vamp := _vampire({"hp": 10, "maxHp": 35})
	var item := _certain(vamp["weapons"][0])
	item["damageMin"] = 6; item["damageMax"] = 6
	var target := state.spawn_unit("alvo-fraco", {"x": 6, "y": 5, "hp": 2, "maxHp": 30, "team": "player"})
	state.resolve_single_hit(vamp, target, item)
	assert_eq(target["hp"], 0, "só tinha 2 HP, morre")
	assert_eq(vamp["hp"], 11, "cura floor(2*0.5)=1 (dano REAL removido, não os 6 sorteados): 10+1=11")

func test_lifesteal_never_exceeds_max_hp() -> void:
	var vamp := _vampire({"hp": 34, "maxHp": 35})
	var item := _certain(vamp["weapons"][0])
	item["damageMin"] = 6; item["damageMax"] = 6
	var target := state.spawn_unit("alvo", {"x": 6, "y": 5, "hp": 30, "maxHp": 30, "team": "player"})
	state.resolve_single_hit(vamp, target, item)
	assert_eq(vamp["hp"], 35)

# --- Virar Morcego ----------------------------------------------------------

func _bat_spell(vamp: Dictionary) -> Dictionary:
	return (vamp["spells"] as Array).filter(func(s): return s.get("kind", "") == "vampire-bat-form")[0]

func test_bat_form_is_free_doubles_move_grants_flying_and_full_lifesteal() -> void:
	var vamp := _vampire({"mp": 15, "ct": 42})
	var base_move: int = vamp["moveRange"]
	state.cast_vampire_bat_form(vamp, _bat_spell(vamp))
	assert_eq(vamp["mp"], 10, "só desconta os 5 MP")
	assert_eq(vamp["ct"], 42, "não desconta CT nenhum")
	assert_eq(vamp["moveRange"], base_move * 2)
	assert_true(vamp["flying"])
	assert_false(vamp["hasActed"], "ação livre: não consome o turno")

func test_bat_form_does_not_end_the_turn_and_allows_further_actions() -> void:
	var vamp := _vampire({"mp": 15, "hasActed": false})
	state.cast_vampire_bat_form(vamp, _bat_spell(vamp))
	assert_false(vamp["hasActed"])
	var target := state.spawn_unit("alvo", {"x": 6, "y": 5, "hp": 30, "maxHp": 30, "team": "player"})
	state.resolve_single_hit(vamp, target, _certain(vamp["weapons"][0]))
	state.finalize_action(vamp, vamp["weapons"][0])
	assert_true(vamp["hasActed"], "ainda pode atacar normalmente depois de transformar")

func test_bat_form_lifesteal_heals_100_percent_of_actual_damage() -> void:
	var vamp := _vampire({"mp": 15, "hp": 10, "maxHp": 35})
	state.cast_vampire_bat_form(vamp, _bat_spell(vamp))
	var item := _certain(vamp["weapons"][0])
	item["damageMin"] = 7; item["damageMax"] = 7
	var target := state.spawn_unit("alvo", {"x": 6, "y": 5, "hp": 30, "maxHp": 30, "team": "player"})
	state.resolve_single_hit(vamp, target, item)
	assert_eq(vamp["hp"], 17, "cura 100% dos 7 de dano: 10+7=17")

func test_bat_form_reverts_at_the_start_of_the_vampires_own_next_turn() -> void:
	var vamp := _vampire({"mp": 15})
	var base_move: int = vamp["moveRange"]
	state.cast_vampire_bat_form(vamp, _bat_spell(vamp))
	assert_eq(vamp["moveRange"], base_move * 2)
	assert_true(vamp["flying"])
	# Turno de outra unidade não deve derrubar a transformação.
	var other := state.spawn_unit("outro", {"x": 1, "y": 1, "team": "player", "statusEffects": []})
	state.apply_status_effects_at_turn_start(other)
	assert_eq(vamp["moveRange"], base_move * 2, "só o PRÓPRIO próximo turno do Vampiro encerra a forma")
	assert_true(vamp["flying"])
	# Início do próximo turno DO PRÓPRIO Vampiro: reverte tudo.
	state.apply_status_effects_at_turn_start(vamp)
	assert_eq(vamp["moveRange"], base_move)
	assert_false(vamp["flying"])
	var has_bat_form := false
	for e in vamp["statusEffects"]:
		if e["type"] == "batForm": has_bat_form = true
	assert_false(has_bat_form)

func test_using_bat_form_twice_in_the_same_turn_does_not_double_the_move_bonus() -> void:
	var vamp := _vampire({"mp": 15})
	var base_move: int = vamp["moveRange"]
	var spell := _bat_spell(vamp)
	state.cast_vampire_bat_form(vamp, spell)
	state.cast_vampire_bat_form(vamp, spell)
	assert_eq(vamp["moveRange"], base_move * 2, "reusar não exploits: não dobra de novo")

# --- Invocar Morcegos --------------------------------------------------------

func _summon_spell(vamp: Dictionary) -> Dictionary:
	return (vamp["spells"] as Array).filter(func(s): return s.get("kind", "") == "summon-vampire-bat")[0]

func test_summon_vampire_bat_costs_10_mp_and_is_a_snake_variant_with_flying_and_lifesteal() -> void:
	var vamp := _vampire({"ct": 100})
	var spell: Dictionary = _summon_spell(vamp)
	assert_eq(spell["mpCost"], 10)
	var snake: Dictionary = GameState.lua_monster_data("snake")
	var mp_before: int = vamp["mp"]
	state.cast_summon_vampire_bat(vamp, spell, {"x": 6, "y": 6})
	assert_eq(vamp["mp"], mp_before - 10)
	var bat = state.unit_at(6, 6)
	assert_not_null(bat)
	assert_eq(bat["name"], "Morcego Vampiro 1")
	assert_eq([bat["hp"], bat["maxHp"]], [snake["hp"], snake["maxHp"]], "mesmos HP da Cobra")
	assert_eq(bat["speed"], snake["speed"])
	assert_eq(bat["moveRange"], snake["moveRange"])
	assert_true(bat["flying"], "Voo permanente, diferente da Cobra")
	assert_eq(bat["weapons"][0]["lifesteal"], 0.5)
	assert_eq(bat["weapons"][0]["damageMin"], snake["weapons"][0]["damageMin"], "mesmo ataque (Picada) da Cobra, só com lifesteal a mais")

func test_summon_vampire_bat_refuses_occupied_tile() -> void:
	var vamp := _vampire({"ct": 100})
	state.spawn_unit("bloqueador", {"x": 6, "y": 6, "hp": 10, "maxHp": 10, "team": "player"})
	var mp_before: int = vamp["mp"]
	state.cast_summon_vampire_bat(vamp, _summon_spell(vamp), {"x": 6, "y": 6})
	assert_eq(vamp["mp"], mp_before, "tile ocupado: nada é invocado, custo não é descontado")

func test_summoned_bat_is_a_different_unit_from_the_vampires_own_transformation() -> void:
	var vamp := _vampire({"ct": 100, "mp": 15})
	state.cast_vampire_bat_form(vamp, _bat_spell(vamp))
	state.cast_summon_vampire_bat(vamp, _summon_spell(vamp), {"x": 6, "y": 6})
	var summoned = state.unit_at(6, 6)
	assert_ne(summoned["name"], vamp["name"], "unidade nova e independente, não o Vampiro transformado")
	assert_eq(state.units.filter(func(u): return u["hp"] > 0).size(), 2, "Vampiro + Morcego invocado, sem duplicar nada")

# --- undead: fraqueza a gelo, sem sangramento -----------------------------

func test_vampire_is_undead_takes_half_ice_damage_and_does_not_bleed() -> void:
	var vamp := _vampire({"hp": 35, "maxHp": 35})
	var attacker := state.spawn_unit("atacante", {"x": 5, "y": 6, "team": "player"})
	# maxRange:1 (não 3) de propósito: um item de alcance >1 usado a queima-
	# roupa (distância 1) sofre a penalidade de -10pp de get_effective_hit_
	# chance (RANGED_MELEE_HIT_PENALTY), o que tornaria hitChance:1.0 do item
	# não-determinístico aqui — ver mesma pegadinha corrigida em test_flame_demon.gd.
	var ice_item := _certain({"name": "gelo-teste", "damageMin": 6, "damageMax": 6, "critMultiplier": 1, "maxRange": 1, "damageType": "ice"})
	state.resolve_single_hit(attacker, vamp, ice_item)
	assert_eq(vamp["hp"], 32, "6 de gelo vira 3 (floor(6*0.5)) contra morto-vivo")
	var bleed_item := _certain({"name": "sangra-teste", "damageMin": 1, "damageMax": 1, "critMultiplier": 1, "maxRange": 1, "appliesBleed": {"damageMin": 1, "damageMax": 1, "turns": 3}})
	state.resolve_single_hit(attacker, vamp, bleed_item)
	for e in vamp["statusEffects"]:
		assert_ne(e["type"], "bleed", "morto-vivo não sangra")
