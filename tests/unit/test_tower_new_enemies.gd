extends GutTest

func _floor_state(id: String) -> GameState:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(id))
	return state

func _first_with_sprite(state: GameState, sprite: String) -> Dictionary:
	for unit in state.units:
		if unit.get("spriteKey", "") == sprite: return unit
	return {}

func _certain_item(item: Dictionary, damage: int = -1) -> Dictionary:
	var copy := item.duplicate(true)
	copy["hitChance"] = 1.0
	copy["critChance"] = 0.0
	if damage >= 0:
		copy["damageMin"] = damage
		copy["damageMax"] = damage
	return copy

## Pedido do usuário: elenco do 2º Andar trocado pra 1 de cada — Zumbi,
## Esqueleto, Fantasma, Lich e Vampiro.
func test_floor_2_has_exact_requested_population() -> void:
	var state := _floor_state(ScenarioManager.TOWER_FLOOR_2)
	var counts := {"tower_zombie":0,"tower_ghost":0,"tower_skeleton":0,"lich":0,"vampire":0}
	for unit in state.team_units("enemy"): counts[unit["spriteKey"]] += 1
	assert_eq(counts, {"tower_zombie":1,"tower_ghost":1,"tower_skeleton":1,"lich":1,"vampire":1})

## Pedido do usuário: elenco do 3º Andar trocado pra 1 Dragão, 1 Lava
## Humana, 2 Fogo Vivo e 1 Demônio das Chamas.
func test_floor_3_has_exact_requested_population() -> void:
	var state := _floor_state(ScenarioManager.TOWER_FLOOR_3)
	var counts := {"tower_lava_human":0,"tower_living_fire":0,"dragon":0,"flame_demon":0}
	for unit in state.team_units("enemy"): counts[unit["spriteKey"]] += 1
	assert_eq(counts, {"tower_lava_human":1,"tower_living_fire":2,"dragon":1,"flame_demon":1})

## Pedido do usuário: inimigos nascem em posições aleatórias a cada início de
## partida — mesma composição e mesmo conjunto de tiles curados do andar,
## só muda quem nasce em qual, e duas seeds diferentes produzem arranjos
## diferentes (prova de que é realmente aleatório, não sempre a mesma ordem).
func test_floor_2_enemy_positions_are_shuffled_among_the_curated_tiles() -> void:
	var authored: Array = ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_2)["enemy_roster"]
	var authored_tiles := {}
	for entry in authored: authored_tiles["%d,%d" % [entry["x"], entry["y"]]] = true
	var arrangement_a := {}
	var state_a := GameState.new()
	state_a.rng.seed = 1
	state_a.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_2))
	for u in state_a.team_units("enemy"):
		arrangement_a[state_a.tile_key(u["x"], u["y"])] = u["spriteKey"]
	assert_eq(arrangement_a.keys().size(), authored.size(), "todos os tiles curados seguem ocupados, um por inimigo")
	for key in arrangement_a.keys():
		assert_true(authored_tiles.has(key), "ninguém nasce fora dos tiles curados do andar")
	var state_b := GameState.new()
	state_b.rng.seed = 2
	state_b.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_2))
	var arrangement_b := {}
	for u in state_b.team_units("enemy"):
		arrangement_b[state_b.tile_key(u["x"], u["y"])] = u["spriteKey"]
	assert_ne(arrangement_a, arrangement_b, "seeds diferentes embaralham quem nasce em qual tile")

## A Salamandra (footprint 2x2) fica de fora do embaralhamento — seu tile foi
## escolhido a dedo pra caber o corpo grande no 4º andar.
func test_floor_4_salamander_position_is_never_shuffled() -> void:
	for seed_value in [1, 2, 3]:
		var state := GameState.new()
		state.rng.seed = seed_value
		state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_4))
		var salamander := _first_with_sprite(state, "tower_salamander")
		assert_eq([salamander["x"], salamander["y"]], [8, 9])

func test_ghost_and_living_fire_reuse_fairy_flying_attribute() -> void:
	var floor_2 := _floor_state(ScenarioManager.TOWER_FLOOR_2)
	var floor_3 := _floor_state(ScenarioManager.TOWER_FLOOR_3)
	assert_true(_first_with_sprite(floor_2, "tower_ghost").get("flying", false))
	assert_true(_first_with_sprite(floor_3, "tower_living_fire").get("flying", false))

func test_zombie_stats_poison_and_three_turn_full_revive() -> void:
	var state := _floor_state(ScenarioManager.TOWER_FLOOR_2)
	var zombie := _first_with_sprite(state, "tower_zombie")
	assert_eq([zombie["maxHp"],zombie["maxMp"],zombie["speed"]], [20,5,9])
	var hero: Dictionary = state.team_units("player")[0]
	state.resolve_single_hit(zombie, hero, _certain_item(zombie["weapons"][0]))
	assert_true(hero["statusEffects"].any(func(e): return e["type"] == "poison"))
	zombie["hp"] = 0
	state.finalize_death_if_needed(zombie)
	assert_true(zombie.has("turnsSinceDeath"))
	assert_eq(state.souls.size(), 0)
	state.apply_corpse_decay_tick(zombie)
	state.apply_corpse_decay_tick(zombie)
	assert_eq(zombie["hp"], 0)
	state.apply_corpse_decay_tick(zombie)
	assert_eq([zombie["hp"],zombie["mp"]], [20,5])

## Pedido do usuário: Zumbi/Esqueleto/Fantasma são mortos-vivos — cura e
## regeneração os ferem em vez de curar (mesmo tropo clássico de RPG).
func test_heal_and_regen_damage_the_undead_instead_of_healing() -> void:
	var state := _floor_state(ScenarioManager.TOWER_FLOOR_2)
	var caster: Dictionary = state.team_units("player")[0]
	for sprite in ["tower_zombie", "tower_ghost", "tower_skeleton"]:
		var undead := _first_with_sprite(state, sprite)
		undead["hp"] = 15
		state.resolve_heal(caster, undead, {"name":"Cura","healMin":6,"healMax":6,"hitChance":1.0})
		assert_eq(undead["hp"], 9, "%s: cura instantânea deve ferir, não curar" % sprite)
		state.resolve_regen(caster, undead, {"name":"Regeneração","healMin":4,"healMax":4,"hitChance":1.0,"regenTurns":2})
		state.apply_status_effects_at_turn_end(undead)
		assert_eq(undead["hp"], 5, "%s: tique de regeneração também deve ferir" % sprite)

## Pedido do usuário: Zumbi/Esqueleto/Fantasma são mortos-vivos — imunes ao
## sangramento do Golpe Debilitante (mas ainda sofrem a lentidão normalmente).
func test_undead_are_immune_to_weakening_strike_bleed() -> void:
	var state := _floor_state(ScenarioManager.TOWER_FLOOR_2)
	var attacker: Dictionary = state.team_units("player")[0]
	var physical := {"name":"Golpe","damageMin":1,"damageMax":1,"hitChance":1.0,"critChance":0.0,"critMultiplier":1,"minRange":1,"maxRange":1,"damageType":"physical"}
	var magic := physical.duplicate(true); magic["damageType"] = "magic"; magic["mpCost"] = 0
	for entry in [["tower_zombie", physical], ["tower_ghost", magic], ["tower_skeleton", physical]]:
		var undead := _first_with_sprite(state, entry[0])
		var before_move_range: int = undead["moveRange"]
		attacker["weakeningStrikeNextAttack"] = true
		state.resolve_single_hit(attacker, undead, entry[1])
		assert_false(undead["statusEffects"].any(func(e): return e["type"] == "bleed"), "%s: morto-vivo não deve sangrar" % entry[0])
		assert_true(undead["statusEffects"].any(func(e): return e["type"] == "weakened"), "%s: lentidão ainda deve aplicar" % entry[0])
		assert_eq(undead["moveRange"], before_move_range - 1, "%s: deslocamento ainda deve reduzir" % entry[0])

## Forçar ressurreição num Zumbi que já
## está na própria contagem regressiva de auto-ressuscitar atrapalha o
## processo e mata ele de vez, virando alma em vez de reviver.
func test_resurrect_spell_on_self_reviving_corpse_mid_countdown_kills_it_into_a_soul() -> void:
	var state := _floor_state(ScenarioManager.TOWER_FLOOR_2)
	var caster: Dictionary = state.team_units("enemy")[1]
	var zombie := _first_with_sprite(state, "tower_zombie")
	zombie["hp"] = 0
	state.finalize_death_if_needed(zombie)
	state.apply_corpse_decay_tick(zombie) # 1 de 3 — ainda em contagem, não ressuscitou
	assert_true(zombie.has("turnsSinceDeath"))
	assert_eq(state.souls.size(), 0)
	state.cast_resurrect(caster, zombie, {"name":"Ressurreição","hitChance":1.0,"ctCost":0,"mpCost":0})
	assert_eq(zombie["hp"], 0, "não revive mais")
	assert_false(zombie.has("turnsSinceDeath"), "não continua em contagem — está morto de vez")
	assert_eq(state.souls.size(), 1, "vira uma alma no lugar")
	# Sem turnsSinceDeath, advance_corpse_decay_for_round nem chega a chamar
	# apply_corpse_decay_tick de novo nele — fica morto de vez.
	state.advance_corpse_decay_for_round()
	assert_eq(zombie["hp"], 0)
	assert_false(zombie.has("turnsSinceDeath"))

func test_ghost_rejects_physical_accepts_magic_and_drops_immediate_soul() -> void:
	var state := _floor_state(ScenarioManager.TOWER_FLOOR_2)
	var ghost := _first_with_sprite(state, "tower_ghost")
	var attacker: Dictionary = state.team_units("player")[0]
	var hp_before: int = ghost["hp"]
	var physical := {"name":"Golpe","damageMin":5,"damageMax":5,"hitChance":1.0,"critChance":0.0,"critMultiplier":1,"minRange":1,"maxRange":1,"damageType":"physical"}
	assert_false(state.resolve_single_hit(attacker, ghost, physical))
	assert_eq(ghost["hp"], hp_before)
	var magic := physical.duplicate(true); magic["damageType"] = "magic"; magic["mpCost"] = 0
	assert_true(state.resolve_single_hit(attacker, ghost, magic))
	assert_eq(ghost["hp"], hp_before - 5)
	ghost["hp"] = 0
	state.finalize_death_if_needed(ghost)
	assert_eq(state.souls[-1]["hpAmount"], 10)
	assert_eq(state.souls[-1]["mpAmount"], 5)

func test_ghost_bite_drains_ct_and_freezing_ray_costs_mp_and_paralyzes() -> void:
	var state := _floor_state(ScenarioManager.TOWER_FLOOR_2)
	var ghost := _first_with_sprite(state, "tower_ghost")
	var hero: Dictionary = state.team_units("player")[0]
	hero["ct"] = 65
	state.resolve_single_hit(ghost, hero, _certain_item(ghost["weapons"][0]))
	assert_eq(hero["ct"], 45)
	var ray := _certain_item(ghost["spells"][0])
	state.perform_attack(ghost, hero, ray)
	assert_eq(ghost["mp"], 5)
	assert_true(state.is_paralyzed(hero))

func test_element_affinity_heals_from_fire_and_doubles_ice() -> void:
	for sprite in ["tower_living_fire", "tower_lava_human"]:
		var state := _floor_state(ScenarioManager.TOWER_FLOOR_3)
		var enemy := _first_with_sprite(state, sprite)
		var attacker: Dictionary = state.team_units("player")[0]
		enemy["hp"] = 10
		var fire := {"name":"Fogo","damageMin":6,"damageMax":6,"hitChance":1.0,"critChance":0.0,"critMultiplier":1,"minRange":1,"maxRange":1,"mpCost":0,"damageType":"fire"}
		state.resolve_single_hit(attacker, enemy, fire)
		assert_eq(enemy["hp"], 16)
		var ice := fire.duplicate(true); ice["name"] = "Gelo"; ice["damageType"] = "ice"
		state.resolve_single_hit(attacker, enemy, ice)
		assert_eq(enemy["hp"], 4)

## Pedido do usuário: todo morto-vivo (campo genérico `undead`) sofre só
## metade do dano de gelo, arredondado pra baixo — independe de nome de
## unidade/habilidade, só do campo `undead` (Zumbi/Fantasma/Esqueleto já o
## tinham; Vampiro/Lich também passam a ter).
func test_undead_units_take_half_ice_damage_rounded_down() -> void:
	var state := _floor_state(ScenarioManager.TOWER_FLOOR_2)
	var zombie := _first_with_sprite(state, "tower_zombie")
	var attacker: Dictionary = state.team_units("player")[0]
	zombie["hp"] = 20
	var ice := {"name":"Gelo","damageMin":5,"damageMax":5,"hitChance":1.0,"critChance":0.0,"critMultiplier":1,"minRange":1,"maxRange":1,"mpCost":0,"damageType":"ice"}
	state.resolve_single_hit(attacker, zombie, ice)
	assert_eq(zombie["hp"], 18, "5 de gelo vira 2 (floor(5*0.5)) contra morto-vivo: 20 - 2 = 18")
	var living := state.team_units("player")[1] if state.team_units("player").size() > 1 else state.spawn_unit("vivo-teste", {"team":"player","x":zombie["x"]+1,"y":zombie["y"],"hp":20,"maxHp":20})
	living["hp"] = 20
	state.resolve_single_hit(attacker, living, ice)
	assert_eq(living["hp"], 15, "criatura viva continua recebendo o dano cheio de gelo")

## Pedido do usuário: a Arma de Fogo do Químico é uma pistola comum (dano
## físico) — só o Tiro Explosivo faz o disparo contar como dano de fogo pra
## fins de afinidade elemental.
func test_chemist_firearm_is_physical_and_only_explosive_shot_counts_as_fire() -> void:
	for sprite in ["tower_living_fire", "tower_lava_human"]:
		var state := _floor_state(ScenarioManager.TOWER_FLOOR_3)
		var enemy := _first_with_sprite(state, sprite)
		var chemist: Dictionary = state.spawn_unit("Químico Teste", DataUtil.merge(Units.build()["quimico"], {"team":"player","x":enemy["x"]-1,"y":enemy["y"]}))
		var firearm: Dictionary = _certain_item(Weapons.build()["firearm"], 6)
		enemy["hp"] = 10
		chemist["guaranteedNextHit"] = true
		state.resolve_single_hit(chemist, enemy, firearm)
		assert_eq(enemy["hp"], 4, "%s: tiro comum deve causar dano normal, não curar" % sprite)
		enemy["hp"] = 10
		chemist["guaranteedNextHit"] = true
		chemist["burnNextAttackTurns"] = 3
		state.resolve_single_hit(chemist, enemy, firearm)
		assert_eq(enemy["hp"], 16, "%s: com Tiro Explosivo ativo, o disparo cura como dano de fogo" % sprite)

func test_skeleton_throw_is_cardinal_and_death_explodes_only_adjacent() -> void:
	var state := _floor_state(ScenarioManager.TOWER_FLOOR_2)
	var skeleton := _first_with_sprite(state, "tower_skeleton")
	var throw_item: Dictionary = skeleton["weapons"][1]
	assert_true(throw_item["cardinalOnly"])
	var adjacent := state.spawn_unit("adjacent", {"team":"player","x":5,"y":5,"hp":20,"maxHp":20})
	var far := state.spawn_unit("far", {"team":"player","x":7,"y":5,"hp":20,"maxHp":20})
	skeleton["x"] = 4; skeleton["y"] = 5; skeleton["hp"] = 0
	state.finalize_death_if_needed(skeleton)
	assert_lt(adjacent["hp"], 20)
	assert_eq(far["hp"], 20)

func test_lava_human_does_not_revive_and_becomes_a_soul_after_decay() -> void:
	var state := _floor_state(ScenarioManager.TOWER_FLOOR_3)
	var lava_human := _first_with_sprite(state, "tower_lava_human")
	assert_eq([lava_human["hp"], lava_human["maxHp"]], [80, 80])
	assert_false(lava_human.has("resurrection"))
	lava_human["hp"] = 0
	state.finalize_death_if_needed(lava_human)
	assert_true(lava_human.has("turnsSinceDeath"))
	for i in 4: state.apply_corpse_decay_tick(lava_human)
	assert_eq(lava_human["hp"], 0)
	assert_false(lava_human.has("turnsSinceDeath"))
	assert_eq(state.souls.size(), 1)

func test_special_fire_area_has_exact_twelve_tiles_and_self_destruct_kills_caster() -> void:
	var state := _floor_state(ScenarioManager.TOWER_FLOOR_3)
	var living_fire := _first_with_sprite(state, "tower_living_fire")
	living_fire["x"] = 6; living_fire["y"] = 6
	assert_eq(state.special_fire_area_tiles(living_fire).size(), 12)
	var victim := state.spawn_unit("victim", {"team":"player","x":7,"y":6,"hp":50,"maxHp":50})
	var skill: Dictionary = living_fire["spells"][0].duplicate(true); skill["hitChance"] = 1.0
	state.cast_living_fire_self_destruct(living_fire, skill)
	assert_eq(living_fire["hp"], 0)
	assert_lt(victim["hp"], 50)

func test_living_fire_ai_probability_bands_do_not_accumulate() -> void:
	var state := GameState.new()
	assert_eq(state.living_fire_self_destruct_chance(20), 0.05)
	assert_eq(state.living_fire_self_destruct_chance(10), 0.30)
	assert_eq(state.living_fire_self_destruct_chance(6), 0.30)
	assert_eq(state.living_fire_self_destruct_chance(5), 0.70)
