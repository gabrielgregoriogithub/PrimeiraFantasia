extends GutTest

## Lich: novo inimigo (pedido do usuário). Cobre stats, Raio de Decaimento
## (-1 AGI/-1 MOV/-30 CT, só cardeal), Invocar Esqueleto/Zumbi (mesmas
## unidades da Torre), Decaimento (mesma área da Bola de Fogo, centrada no
## Lich, dano+Sangrando+Envenenado em vivos / cura em mortos-vivos),
## Reanimação (= Ressurreição só pra undead, sem destruir Zumbi em
## contagem) e Infligir Ferimentos (= Cura invertida: cura undead, fere vivo).

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

func _lich(overrides: Dictionary = {}) -> Dictionary:
	var data := GameState.dungeon_monster_data("lich", 1, {"x": 5, "y": 5})
	for k in overrides.keys():
		data[k] = overrides[k]
	return state.spawn_unit(String(data["name"]), data)

func _spell(lich: Dictionary, kind: String) -> Dictionary:
	return (lich["spells"] as Array).filter(func(s): return s.get("kind", "") == kind)[0]

func test_stats_match_spec() -> void:
	var data := GameState.dungeon_monster_data("lich")
	assert_eq(data["maxHp"], 25)
	assert_eq(data["maxMp"], 20)
	assert_eq(data["speed"], 10)
	assert_eq(data["moveRange"], 3)
	assert_true(data["undead"])

# --- Raio de Decaimento ----------------------------------------------------

func test_decay_ray_deals_3_to_6_costs_50_ct_range_4_cardinal_only() -> void:
	var lich := _lich()
	var ray: Dictionary = lich["weapons"][0]
	assert_eq(ray["name"], "Raio de Decaimento")
	assert_eq(ray["damageMin"], 3)
	assert_eq(ray["damageMax"], 6)
	assert_eq(ray["ctCost"], 50)
	assert_eq(ray["maxRange"], 4)
	assert_true(ray["cardinalOnly"])

func test_decay_ray_diagonal_target_is_excluded_from_attack_options() -> void:
	var lich := _lich({"x": 5, "y": 5})
	var diagonal := state.spawn_unit("diagonal", {"x": 7, "y": 7, "team": "player"})
	var options := state.get_attack_options_against(lich, diagonal)
	assert_false(options.any(func(i): return i["name"] == "Raio de Decaimento"))

func test_decay_ray_applies_minus_1_agi_minus_1_mov_and_minus_30_ct_on_hit() -> void:
	var lich := _lich({"x": 5, "y": 5})
	var target := state.spawn_unit("alvo", {"x": 5, "y": 8, "hp": 30, "maxHp": 30, "team": "player", "speed": 10, "moveRange": 4, "ct": 80})
	state.resolve_single_hit(lich, target, _certain(lich["weapons"][0]))
	assert_eq(target["speed"], 9, "-1 AGI")
	assert_eq(target["moveRange"], 3, "-1 MOV")
	assert_eq(target["ct"], 50, "-30 CT")

# --- Invocar Esqueleto / Invocar Zumbi -------------------------------------

func test_summon_skeleton_costs_15_mp_50_ct_range_2_and_is_the_exact_tower_skeleton() -> void:
	var lich := _lich({"ct": 100})
	var spell := _spell(lich, "summon-skeleton")
	assert_eq(spell["mpCost"], 15)
	assert_eq(spell["ctCost"], 50)
	assert_eq(spell["maxRange"], 2)
	var reference: Dictionary = GameState.dungeon_monster_data("skeleton")
	state.cast_summon_skeleton(lich, spell, {"x": 6, "y": 6})
	var spawned = state.unit_at(6, 6)
	assert_not_null(spawned)
	assert_eq(spawned["spriteKey"], "tower_skeleton")
	assert_eq([spawned["hp"], spawned["maxHp"]], [reference["hp"], reference["maxHp"]])
	assert_eq(lich["mp"], 5)
	assert_eq(lich["ct"], 50)

func test_summon_zombie_costs_15_mp_50_ct_range_2_and_keeps_its_own_revival() -> void:
	var lich := _lich({"ct": 100})
	var spell := _spell(lich, "summon-zombie")
	assert_eq(spell["mpCost"], 15)
	state.cast_summon_zombie(lich, spell, {"x": 6, "y": 6})
	var spawned = state.unit_at(6, 6)
	assert_not_null(spawned)
	assert_eq(spawned["spriteKey"], "tower_zombie")
	assert_true(spawned.has("resurrection"), "mantém a própria mecânica de ressurreição do Zumbi")

# --- Decaimento --------------------------------------------------------------

func test_decay_pulse_is_centered_on_the_lich_and_matches_fireball_area_radius() -> void:
	var lich := _lich()
	var spell := _spell(lich, "decay-pulse")
	assert_eq(spell["areaRadius"], Spells.build()["fireball"]["areaRadius"])
	assert_eq(spell["targetMode"], "self-aoe")

func test_decay_pulse_hits_living_with_damage_bleed_and_poison() -> void:
	var lich := _lich({"x": 5, "y": 5})
	var spell := _certain(_spell(lich, "decay-pulse"))
	var hero := state.spawn_unit("heroi", {"x": 6, "y": 5, "hp": 30, "maxHp": 30, "team": "player", "statusEffects": []})
	state.cast_decay_pulse(lich, spell)
	assert_true(hero["hp"] < 30)
	var has_bleed := false
	var has_poison := false
	for e in hero["statusEffects"]:
		if e["type"] == "bleed": has_bleed = true
		if e["type"] == "poison": has_poison = true
	assert_true(has_bleed, "Decaimento aplica Sangrando em vivos")
	assert_true(has_poison, "Decaimento aplica Envenenado em vivos")

func test_decay_pulse_heals_undead_allies_and_enemies_alike_without_bleed_or_poison() -> void:
	var lich := _lich({"x": 5, "y": 5})
	var spell := _spell(lich, "decay-pulse")
	spell["healMin"] = 4; spell["healMax"] = 4
	var skeleton_ally := state.spawn_unit("esqueleto-aliado", {"x": 6, "y": 5, "hp": 10, "maxHp": 20, "team": "enemy", "undead": true, "statusEffects": []})
	var skeleton_foe := state.spawn_unit("esqueleto-inimigo", {"x": 4, "y": 5, "hp": 10, "maxHp": 20, "team": "player", "undead": true, "statusEffects": []})
	state.cast_decay_pulse(lich, spell)
	assert_eq(skeleton_ally["hp"], 14, "morto-vivo aliado regenera, não sofre dano")
	assert_eq(skeleton_foe["hp"], 14, "morto-vivo inimigo TAMBÉM regenera — mesma área da Bola de Fogo, sem filtro de time")
	assert_true(skeleton_ally["statusEffects"].is_empty())

func test_decay_pulse_can_hit_the_lich_itself_since_it_is_undead_and_area_is_not_excluded() -> void:
	var lich := _lich({"x": 5, "y": 5, "hp": 15, "maxHp": 25})
	var spell := _spell(lich, "decay-pulse")
	spell["healMin"] = 3; spell["healMax"] = 3
	state.cast_decay_pulse(lich, spell)
	assert_eq(lich["hp"], 18, "o próprio Lich é morto-vivo e está na própria área — mesmo comportamento padrão de área que não exclui o caster")

# --- Reanimação ---------------------------------------------------------------

func test_reanimate_target_must_be_undead() -> void:
	var lich := _lich({"mp": 20})
	var hero := state.spawn_unit("guerreiro-morto", {"x": 6, "y": 5, "hp": 0, "maxHp": 20, "team": "enemy", "turnsSinceDeath": 1})
	var skeleton := state.spawn_unit("esqueleto-morto", {"x": 6, "y": 6, "hp": 0, "maxHp": 20, "team": "enemy", "undead": true, "turnsSinceDeath": 1})
	var target = state.pick_resurrect_target(lich, _spell(lich, "reanimate"), true)
	assert_eq(target, skeleton, "só considera undead, ignora o herói morto")

func test_reanimate_revives_a_skeleton_to_half_max_hp() -> void:
	var lich := _lich({"mp": 20})
	var skeleton := state.spawn_unit("esqueleto-morto", {"x": 6, "y": 5, "hp": 0, "maxHp": 20, "team": "enemy", "undead": true, "turnsSinceDeath": 1, "statusEffects": []})
	state.cast_reanimate(lich, skeleton, _certain(_spell(lich, "reanimate")))
	assert_eq(skeleton["hp"], 10, "metade do HP máximo, igual Ressurreição")
	assert_false(skeleton.has("turnsSinceDeath"))

func test_reanimating_a_mid_countdown_zombie_revives_it_instead_of_turning_it_into_a_soul() -> void:
	var lich := _lich({"mp": 20})
	var zombie_data := GameState.dungeon_monster_data("zombie", 1, {"x": 6, "y": 5})
	var z := state.spawn_unit(String(zombie_data["name"]), zombie_data)
	z["team"] = "enemy"
	z["hp"] = 0
	state.finalize_death_if_needed(z)
	state.apply_corpse_decay_tick(z) # 1 de 3 — ainda em contagem, não ressuscitou sozinho
	assert_true(z.has("turnsSinceDeath"))
	assert_eq(state.souls.size(), 0)
	state.cast_reanimate(lich, z, _certain(_spell(lich, "reanimate")))
	assert_gt(z["hp"], 0, "Reanimação revive de verdade, não destrói em alma")
	assert_false(z.has("turnsSinceDeath"))
	assert_false(z.has("resurrectionTurns"), "contador de revival automático cancelado")
	assert_eq(state.souls.size(), 0, "não vira alma — diferente de cast_resurrect no mesmo cenário")
	# Sem resurrectionTurns, uma rodada normal de decaimento não tenta reviver de novo.
	z["hp"] = 0
	state.finalize_death_if_needed(z)
	assert_eq(state.souls.size(), 0)

# --- Infligir Ferimentos -------------------------------------------------------

func test_inflict_wounds_reuses_cure_cost_range_and_amount() -> void:
	var lich := _lich()
	var cure: Dictionary = Spells.build()["cure"]
	var wounds := _spell(lich, "inflict-wounds")
	assert_eq(wounds["ctCost"], cure["ctCost"])
	assert_eq(wounds["mpCost"], cure["mpCost"])
	assert_eq(wounds["healMin"], cure["healMin"])
	assert_eq(wounds["healMax"], cure["healMax"])
	assert_eq(wounds["areaRadius"], cure["areaRadius"])
	assert_eq(wounds["maxRange"], cure["maxRange"])

func test_inflict_wounds_heals_undead_and_damages_living_by_the_same_roll() -> void:
	var lich := _lich({"x": 5, "y": 5})
	var wounds := _spell(lich, "inflict-wounds")
	wounds["healMin"] = 6; wounds["healMax"] = 6; wounds["hitChance"] = 1.0
	var skeleton := state.spawn_unit("esqueleto", {"x": 6, "y": 6, "hp": 10, "maxHp": 20, "team": "enemy", "undead": true})
	state.resolve_harm(lich, skeleton, wounds)
	assert_eq(skeleton["hp"], 16, "morto-vivo: +6 HP")
	var warrior := state.spawn_unit("guerreiro", {"x": 6, "y": 6, "hp": 20, "maxHp": 20, "team": "player"})
	state.resolve_harm(lich, warrior, wounds)
	assert_eq(warrior["hp"], 14, "criatura viva: 6 de dano")
