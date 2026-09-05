extends GutTest

## Demônio das Chamas: novo inimigo (pedido do usuário). Cobre stats, Garra
## (sangramento), Raio de Fogo (mesma mecânica do Raio de Gelo + queimadura),
## Bola de Fogo (mesma magia do Mago), Flecha de Fogo Penetrante (Tiro
## Penetrante + queimadura, MP próprio), Invocar Fogo Vivo (mesma unidade da
## Torre), afinidade elemental (fogo cura, gelo dobra) e imunidade a
## Queimando — mais a generalização de cardinalOnly em get_attack_options_against.

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

func _demon(overrides: Dictionary = {}) -> Dictionary:
	var data := GameState.dungeon_monster_data("flame_demon", 1, {"x": 5, "y": 5})
	for k in overrides.keys():
		data[k] = overrides[k]
	return state.spawn_unit(String(data["name"]), data)

# --- stats -------------------------------------------------------------

func test_stats_match_spec() -> void:
	var data := GameState.dungeon_monster_data("flame_demon")
	assert_eq(data["maxHp"], 25)
	assert_eq(data["maxMp"], 20)
	assert_eq(data["speed"], 10)
	assert_eq(data["moveRange"], 3)

# --- Garra (sangramento) -------------------------------------------------

func test_claw_deals_4_to_8_costs_50_ct_and_applies_bleed() -> void:
	var demon := _demon()
	var claw: Dictionary = demon["weapons"][0]
	assert_eq(claw["name"], "Garra")
	assert_eq(claw["damageMin"], 4)
	assert_eq(claw["damageMax"], 8)
	assert_eq(claw["ctCost"], 50)
	assert_almost_eq(claw["hitChance"], 0.8, 0.001)
	var target := state.spawn_unit("alvo", {"x": 6, "y": 5, "hp": 30, "maxHp": 30, "team": "player"})
	state.resolve_single_hit(demon, target, _certain(claw))
	var bleed = null
	for e in target["statusEffects"]:
		if e["type"] == "bleed": bleed = e
	assert_not_null(bleed, "Garra aplica o status bleed já existente")
	assert_eq(bleed["turnsLeft"], 3)

func test_claw_does_not_bleed_undead_targets() -> void:
	var demon := _demon()
	var claw: Dictionary = demon["weapons"][0]
	var zombie := state.spawn_unit("zumbi-teste", {"x": 6, "y": 5, "hp": 30, "maxHp": 30, "team": "player", "undead": true, "statusEffects": []})
	state.resolve_single_hit(demon, zombie, _certain(claw))
	assert_eq((zombie["statusEffects"] as Array).size(), 0, "morto-vivo não sangra, mesma regra do Golpe Debilitante")

# --- Raio de Fogo (= Raio de Gelo, tema fogo) ----------------------------

func test_fire_ray_mirrors_ice_ray_mechanics() -> void:
	var ice_ray: Dictionary = Weapons.build()["iceRay"]
	var demon := _demon()
	var fire_ray: Dictionary = demon["weapons"][1]
	assert_eq(fire_ray["name"], "Raio de Fogo")
	assert_eq(fire_ray["ctCost"], ice_ray["ctCost"])
	assert_eq(fire_ray["damageMin"], ice_ray["damageMin"])
	assert_eq(fire_ray["damageMax"], ice_ray["damageMax"])
	assert_eq(fire_ray["hitChance"], ice_ray["hitChance"])
	assert_eq(fire_ray["maxRange"], ice_ray["maxRange"])
	assert_true(fire_ray["cardinalOnly"])
	assert_true(fire_ray["requiresClearPath"])
	assert_eq(state.damage_type_of(fire_ray), "fire")

func test_fire_ray_applies_burn_on_hit() -> void:
	var demon := _demon()
	var fire_ray: Dictionary = demon["weapons"][1]
	var target := state.spawn_unit("alvo", {"x": 5, "y": 8, "hp": 30, "maxHp": 30, "team": "player"})
	state.resolve_single_hit(demon, target, _certain(fire_ray))
	var burned = null
	for e in target["statusEffects"]:
		if e["type"] == "burned": burned = e
	assert_not_null(burned, "Raio de Fogo incendeia o alvo")

# --- Bola de Fogo (mesma magia do Mago) ----------------------------------

func test_fireball_is_the_same_spell_as_the_mage() -> void:
	var mage_fireball: Dictionary = Spells.build()["fireball"]
	var demon := _demon()
	var demon_fireball: Dictionary = demon["spells"][0]
	assert_eq(demon_fireball, mage_fireball, "não é uma recriação: mesmos campos, byte a byte")

# --- Flecha de Fogo Penetrante (Tiro Penetrante + Flecha de Fogo) --------

func test_fire_arrow_pierce_costs_7_mp_and_reuses_pierce_line_targeting() -> void:
	var demon := _demon()
	var pierce: Dictionary = demon["spells"][1]
	assert_eq(pierce["mpCost"], 7)
	assert_eq(pierce["targetMode"], "pierce-line")
	assert_eq(pierce["damageMin"], Spells.build()["pierceShot"]["damageMin"])
	assert_eq(pierce["damageMax"], Spells.build()["pierceShot"]["damageMax"])

func test_fire_arrow_pierce_hits_every_aligned_enemy_and_burns_them() -> void:
	var demon := _demon({"x": 5, "y": 5})
	var pierce: Dictionary = _certain(demon["spells"][1])
	var near := state.spawn_unit("perto", {"x": 7, "y": 5, "hp": 30, "maxHp": 30, "team": "player"})
	var far := state.spawn_unit("longe", {"x": 9, "y": 5, "hp": 30, "maxHp": 30, "team": "player"})
	state.cast_pierce_shot(demon, pierce, {"x": 12, "y": 5})
	assert_lt(near["hp"], 30, "perfura o primeiro alvo alinhado")
	assert_lt(far["hp"], 30, "perfura também o segundo alvo alinhado, mais longe")
	var near_burned := false
	for e in near["statusEffects"]:
		if e["type"] == "burned": near_burned = true
	assert_true(near_burned, "cada alvo perfurado pega fogo")

# --- Invocar Fogo Vivo ----------------------------------------------------

func test_summon_living_fire_spawns_the_same_tower_unit_and_pays_costs() -> void:
	var demon := _demon()
	var summon: Dictionary = demon["spells"][2]
	assert_eq(summon["mpCost"], 20)
	assert_eq(summon["ctCost"], 70)
	demon["ct"] = 100
	var mp_before: int = demon["mp"]
	var ct_before: int = demon["ct"]
	var units_before: int = state.units.size()
	state.cast_summon_living_fire(demon, summon, {"x": 6, "y": 6})
	assert_eq(state.units.size(), units_before + 1)
	var spawned = state.unit_at(6, 6)
	assert_not_null(spawned)
	assert_eq(spawned["spriteKey"], "tower_living_fire")
	assert_eq(spawned["team"], "enemy")
	assert_eq(demon["mp"], mp_before - 20)
	assert_eq(demon["ct"], ct_before - 70)

func test_summon_living_fire_refuses_occupied_tile() -> void:
	var demon := _demon()
	var summon: Dictionary = demon["spells"][2]
	state.spawn_unit("bloqueador", {"x": 6, "y": 6, "hp": 10, "maxHp": 10, "team": "player"})
	demon["ct"] = 100
	var mp_before: int = demon["mp"]
	var units_before: int = state.units.size()
	state.cast_summon_living_fire(demon, summon, {"x": 6, "y": 6})
	assert_eq(state.units.size(), units_before, "tile ocupado: nenhum Fogo Vivo nasce")
	assert_eq(demon["mp"], mp_before, "custo não é descontado se a invocação falha")

# --- afinidade elemental: fogo cura, gelo dobra, resto normal ------------

func test_fire_damage_heals_the_demon_instead_of_hurting() -> void:
	var demon := _demon({"hp": 20, "maxHp": 25})
	var fire_item := _certain({"name": "bola-de-fogo-teste", "damageMin": 5, "damageMax": 5, "critMultiplier": 1, "maxRange": 1, "damageType": "fire"})
	var caster := state.spawn_unit("atacante", {"x": 5, "y": 6, "team": "player"})
	state.resolve_single_hit(caster, demon, fire_item)
	assert_eq(demon["hp"], 25, "5 de fogo cura em vez de ferir, respeitando o HP máximo")

func test_fire_heal_never_exceeds_max_hp() -> void:
	var demon := _demon({"hp": 24, "maxHp": 25})
	var fire_item := _certain({"name": "bola-de-fogo-teste", "damageMin": 5, "damageMax": 5, "critMultiplier": 1, "maxRange": 1, "damageType": "fire"})
	var caster := state.spawn_unit("atacante", {"x": 5, "y": 6, "team": "player"})
	state.resolve_single_hit(caster, demon, fire_item)
	assert_eq(demon["hp"], 25)

func test_ice_damage_is_doubled() -> void:
	var demon := _demon({"hp": 25, "maxHp": 25})
	# maxRange:1 (não um item "de alcance" de verdade) de propósito: usado a
	# distância 1, um item com maxRange>1 sofreria a penalidade de -10pp de
	# get_effective_hit_chance (RANGED_MELEE_HIT_PENALTY), tornando
	# hitChance:1.0 não-determinístico.
	var ice_item := _certain({"name": "gelo-teste", "damageMin": 6, "damageMax": 6, "critMultiplier": 1, "maxRange": 1, "damageType": "ice"})
	var caster := state.spawn_unit("atacante", {"x": 5, "y": 6, "team": "player"})
	state.resolve_single_hit(caster, demon, ice_item)
	assert_eq(demon["hp"], 13, "6 de gelo vira 12 de dano (25 - 12 = 13)")

func test_physical_damage_is_normal() -> void:
	var demon := _demon({"hp": 25, "maxHp": 25})
	var phys_item := _certain({"name": "fisico-teste", "damageMin": 5, "damageMax": 5, "critMultiplier": 1, "maxRange": 1, "damageType": "physical"})
	var caster := state.spawn_unit("atacante", {"x": 5, "y": 6, "team": "player"})
	state.resolve_single_hit(caster, demon, phys_item)
	assert_eq(demon["hp"], 20)

# --- imunidade a Queimando (genérica, por dados) -------------------------

func test_demon_is_immune_to_burned_but_not_to_bleed() -> void:
	var demon := _demon()
	state.add_status_effect(demon, {"type": "burned", "damageMin": 1, "damageMax": 1, "turnsLeft": 3})
	for e in demon["statusEffects"]:
		assert_ne(e["type"], "burned", "Demônio das Chamas é imune a Queimando")
	state.add_status_effect(demon, {"type": "bleed", "damageMin": 1, "damageMax": 1, "turnsLeft": 3})
	var has_bleed := false
	for e in demon["statusEffects"]:
		if e["type"] == "bleed": has_bleed = true
	assert_true(has_bleed, "a imunidade é só a Queimando, não a todo status")

# --- generalização de cardinalOnly em get_attack_options_against --------

func test_cardinal_only_item_is_excluded_against_an_off_axis_target() -> void:
	var demon := _demon({"x": 5, "y": 5})
	var aligned := state.spawn_unit("alinhado", {"x": 5, "y": 8, "team": "player"})
	var diagonal := state.spawn_unit("diagonal", {"x": 7, "y": 7, "team": "player"})
	var options_aligned := state.get_attack_options_against(demon, aligned)
	var options_diagonal := state.get_attack_options_against(demon, diagonal)
	var has_fire_ray_aligned := options_aligned.any(func(i): return i["name"] == "Raio de Fogo")
	var has_fire_ray_diagonal := options_diagonal.any(func(i): return i["name"] == "Raio de Fogo")
	assert_true(has_fire_ray_aligned, "alvo alinhado: Raio de Fogo continua disponível")
	assert_false(has_fire_ray_diagonal, "alvo fora da linha/coluna: Raio de Fogo (cardinalOnly) some das opções")

# --- decisão de invocar (evita gasto automático) -------------------------

func test_flame_demon_avoids_summoning_when_enemy_is_adjacent() -> void:
	var demon := _demon({"x": 5, "y": 5})
	state.spawn_unit("perto", {"x": 6, "y": 5, "team": "player", "hp": 10, "maxHp": 10})
	assert_false(state._wants_to_summon_reinforcement(demon))

func test_flame_demon_wants_to_summon_when_outnumbered_and_no_adjacent_enemy() -> void:
	var demon := _demon({"x": 5, "y": 5})
	state.spawn_unit("ajudante", {"x": 4, "y": 5, "team": "enemy", "hp": 10, "maxHp": 10})
	state.spawn_unit("inimigo1", {"x": 9, "y": 5, "team": "player", "hp": 10, "maxHp": 10})
	state.spawn_unit("inimigo2", {"x": 9, "y": 9, "team": "player", "hp": 10, "maxHp": 10})
	state.spawn_unit("inimigo3", {"x": 2, "y": 9, "team": "player", "hp": 10, "maxHp": 10})
	assert_true(state._wants_to_summon_reinforcement(demon), "2 aliados vivos contra 3 inimigos vivos: desvantagem numérica")
