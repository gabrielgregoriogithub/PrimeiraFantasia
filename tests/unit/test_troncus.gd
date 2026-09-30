extends GutTest

## Troncus (pedido do usuário): guardião-árvore 2x2 dos Goblinoides.

var state: GameState

func before_each() -> void:
	state = GameState.new()
	state.clear_units()
	state.clear_terrain_and_structures()
	state.scenario_id = ScenarioManager.TOWER

func _troncus(x: int = 2, y: int = 5) -> Dictionary:
	var data: Dictionary = (Units.build()["troncus"] as Dictionary).duplicate(true)
	data["x"] = x
	data["y"] = y
	return state.spawn_unit("Troncus", data)

func _unit(unit_name: String, x: int, y: int, team: String = "player", extra: Dictionary = {}) -> Dictionary:
	return state.spawn_unit(unit_name, DataUtil.merge({"x": x, "y": y, "hp": 100, "maxHp": 100, "mp": 5, "maxMp": 10, "moveRange": 4, "team": team, "statusEffects": []}, extra))

func _item(u: Dictionary, item_name: String) -> Dictionary:
	for item in (u["weapons"] as Array) + (u["spells"] as Array):
		if item["name"] == item_name:
			return item
	fail_test("%s não tem %s" % [u["name"], item_name])
	return {}

func _certain(item: Dictionary, hit: float = 1.0) -> Dictionary:
	var copy: Dictionary = item.duplicate(true)
	copy["hitChance"] = hit
	copy["critChance"] = 0.0
	return copy

func _fixed_hit(damage: int, extra: Dictionary = {}) -> Dictionary:
	return DataUtil.merge({"name": "Golpe de teste", "damageMin": damage, "damageMax": damage, "critMultiplier": 1, "critChance": 0.0, "hitChance": 1.0, "minRange": 1, "maxRange": 1}, extra)

func _status(u: Dictionary, type: String) -> Array:
	return (u["statusEffects"] as Array).filter(func(e): return e["type"] == type)

func _names(items: Array) -> Array:
	return items.map(func(i): return i["name"])

# --- Cadastro ---------------------------------------------------------------------

func test_troncus_stats_team_and_kit() -> void:
	var t: Dictionary = Units.build()["troncus"]
	assert_eq(t["name"], "Troncus")
	assert_eq(t["team"], "enemy")
	assert_eq([t["maxHp"], t["maxMp"], t["speed"], t["moveRange"]], [45, 15, 7, 3])
	assert_true(state.is_large_unit(t))
	assert_eq([state.footprint_width(t), state.footprint_height(t)], [2, 2])
	assert_true(PvpSetup.MONSTER_GROUPS["goblinoides"]["monsters"].has("troncus"))
	assert_eq(_names(t["weapons"]), ["Punho de Tronco", "Chicote de Cipó"])
	assert_eq(_names(t["spells"]), ["Raízes Aprisionadoras", "Varredura de Galhos", "Casca Fortificada", "Seiva Restauradora"])
	assert_eq(_names(t["passives"]), ["Casca Espessa", "Corpo Vegetal", "Madeira Inflamável", "Raízes Regeneradoras"])
	for w in t["weapons"]:
		assert_false(w.has("mpCost"), "%s sem custo de MP" % w["name"])
	var punch := _item(t, "Punho de Tronco")
	assert_eq([punch["damageMin"], punch["damageMax"], punch["hitChance"], punch["critChance"], punch["maxRange"]], [6, 12, 0.85, 0.1, 1])
	var whip := _item(t, "Chicote de Cipó")
	assert_eq([whip["damageMin"], whip["damageMax"], whip["hitChance"], whip["critChance"], whip["maxRange"]], [3, 5, 0.9, 0.05, 2])
	var mp_costs := {"Raízes Aprisionadoras": 4, "Varredura de Galhos": 5, "Casca Fortificada": 3, "Seiva Restauradora": 4}
	for spell_name in mp_costs:
		assert_eq(_item(t, spell_name)["mpCost"], mp_costs[spell_name])

func test_field_story_battle_spawns_goblinoids_without_overlap() -> void:
	for attempt in 12:
		state.reset()
		var alive: Array = state.units.filter(func(u): return u["hp"] > 0 and u["team"] == "enemy")
		assert_true(alive.any(func(u): return u["name"] == "Troncus"))
		for i in alive.size():
			for j in range(i + 1, alive.size()):
				var overlap := false
				for tile in state.footprint_tiles(alive[i]):
					if state.unit_contains_tile(alive[j], tile["x"], tile["y"]): overlap = true
				assert_false(overlap, "%s e %s não se sobrepõem" % [alive[i]["name"], alive[j]["name"]])

func test_sprites_use_walk_frames_as_idle_for_troncus_and_kobold() -> void:
	for key in ["troncus", "kobold"]:
		var anims: Dictionary = AnimalSpriteCatalog.spec(key)["anims"]
		for dir in ["down", "up", "left", "right"]:
			assert_eq(anims["idle_" + dir][0], anims["walk_" + dir][0], "%s idle_%s = walk_%s" % [key, dir, dir])
			assert_eq((anims["walk_" + dir][0] as Array).size(), 2)
		for action in ["attack", "hit", "death"]:
			for path in anims[action][0]:
				assert_true(ResourceLoader.exists(path), path)
	assert_true(ResourceLoader.exists(AnimalSpriteCatalog.spec("troncus")["portrait"]))

func test_troncus_ignores_props_but_not_units() -> void:
	var t := _troncus(2, 5)
	for y in range(GameConstants.BOARD_SIZE):
		state.terrain_map[state.tile_key(4, y)] = {"type": "scenery-prop"}
	assert_true(state.compute_reachable(t).any(func(r): return r["x"] == 5 and r["y"] == 5), "atravessa props (MOV 3)")
	state.terrain_map = {}
	for y in range(GameConstants.BOARD_SIZE):
		_unit("parede_%d" % y, 4, y)
	assert_false(state.compute_reachable(t).any(func(r): return r["x"] >= 3), "unidades continuam bloqueando o corpo 2x2")

# --- Ataques básicos ------------------------------------------------------------------

func test_punch_reaches_from_any_body_tile_and_pushes_straight() -> void:
	var t := _troncus(2, 5)
	var target := _unit("alvo", 4, 6)
	assert_eq(state.manhattan(t, target), 1, "adjacente à casa inferior direita do corpo")
	state.resolve_single_hit(t, target, _certain(_item(t, "Punho de Tronco")))
	assert_lt(int(target["hp"]), 100)
	assert_eq([target["x"], target["y"]], [5, 6], "empurrado 1 casa em linha reta, sem diagonal")

func test_punch_does_not_push_off_map_or_onto_units() -> void:
	var t := _troncus(10, 5)
	var at_edge := _unit("borda", 12, 5)
	state.resolve_single_hit(t, at_edge, _certain(_item(t, "Punho de Tronco")))
	assert_lt(int(at_edge["hp"]), 100, "dano normal")
	assert_eq([at_edge["x"], at_edge["y"]], [12, 5], "não sai do mapa")
	var t2 := _troncus(2, 1)
	var target := _unit("alvo", 4, 1)
	_unit("atras", 5, 1)
	state.resolve_single_hit(t2, target, _certain(_item(t2, "Punho de Tronco")))
	assert_lt(int(target["hp"]), 100)
	assert_eq([target["x"], target["y"]], [4, 1], "destino ocupado: sem deslocamento")

func test_large_units_are_not_pushed_but_still_take_the_hit() -> void:
	var t := _troncus(2, 5)
	var troll := state.spawn_unit("troll", {"x": 4, "y": 5, "hp": 100, "maxHp": 100, "team": "player", "footprintWidth": 2, "footprintHeight": 2, "statusEffects": []})
	state.resolve_single_hit(t, troll, _certain(_item(t, "Punho de Tronco")))
	assert_lt(int(troll["hp"]), 100, "dano normal")
	assert_eq([troll["x"], troll["y"]], [4, 5], "2x2 não é empurrado")
	assert_false(state.push_unit(troll, 1, 0, 2))
	assert_false(state.push_unit(t, -1, 0, 1), "o próprio Troncus também não")
	var hp_before := int(troll["hp"])
	state.apply_point_blast_knockback(troll, {"x": 3, "y": 5}, {"distance": 1, "blockedExtraDamage": 1})
	assert_eq(int(troll["hp"]), hp_before, "sem dano extra de 'bloqueado'")

func test_vine_whip_reaches_two_tiles_from_body_and_slows_for_one_turn() -> void:
	var t := _troncus(2, 5)
	var target := _unit("alvo", 5, 6)
	var whip := _certain(_item(t, "Chicote de Cipó"))
	assert_true(state.compute_range_tiles(t, whip).has({"x": 5, "y": 6}), "alcance 2 a partir da borda do corpo")
	state.resolve_single_hit(t, target, whip)
	assert_eq(target["moveRange"], 3)
	state.resolve_single_hit(t, target, whip)
	assert_eq(target["moveRange"], 3, "não acumula")
	assert_eq(_status(target, "vineSlow").size(), 1)
	assert_eq(_status(target, "vineSlow")[0]["turnsLeft"], 1, "reaplicar renova")
	assert_false(state.compute_reachable(target).any(func(r): return state.manhattan(target, r) == 4), "no próprio turno anda só 3")
	state.apply_status_effects_at_turn_end(target)
	assert_eq(target["moveRange"], 4, "restaurado no fim do turno do alvo")
	assert_true(_status(target, "vineSlow").is_empty())

func test_vine_whip_keeps_minimum_zero_move() -> void:
	var t := _troncus(2, 5)
	var target := _unit("preso", 4, 5, "player", {"moveRange": 0})
	state.resolve_single_hit(t, target, _certain(_item(t, "Chicote de Cipó")))
	assert_eq(target["moveRange"], 0)
	state.apply_status_effects_at_turn_end(target)
	assert_eq(target["moveRange"], 0, "restaura exatamente o que tirou")

# --- Habilidades ---------------------------------------------------------------------------

func test_roots_hold_an_enemy_for_two_of_its_turns_and_refresh() -> void:
	var t := _troncus(2, 5)
	var target := _unit("alvo", 7, 5)
	var roots := _certain(_item(t, "Raízes Aprisionadoras"))
	assert_eq(_item(t, "Raízes Aprisionadoras")["hitChance"], 0.8)
	assert_true(state.compute_range_tiles(t, roots).has({"x": 6, "y": 5}), "até 3 casas da borda do corpo")
	target["x"] = 6
	state.cast_root_spell(t, target, roots)
	assert_true(state.is_rooted(target))
	state.cast_root_spell(t, target, roots)
	assert_eq(_status(target, "root")[0]["turnsLeft"], 2, "reaplicar renova, não soma")
	state.apply_status_effects_at_turn_end(target)
	assert_true(state.is_rooted(target), "ainda preso no 2º turno dele")
	state.apply_status_effects_at_turn_end(target)
	assert_false(state.is_rooted(target), "livre depois de 2 turnos")

func test_roots_skip_allies_and_misses() -> void:
	var t := _troncus(2, 5)
	var ally := _unit("aliado", 5, 5, "enemy")
	state.cast_root_spell(t, ally, _certain(_item(t, "Raízes Aprisionadoras")))
	assert_false(state.is_rooted(ally))
	var foe := _unit("inimigo", 5, 6)
	# Bônus de acerto (ângulo/tamanho) podem somar sobre 0% — força o erro.
	state.cast_root_spell(t, foe, _certain(_item(t, "Raízes Aprisionadoras"), -5.0))
	assert_false(state.is_rooted(foe), "errou: sem raízes")

func test_branch_sweep_hits_each_enemy_once_and_spares_allies() -> void:
	var t := _troncus(2, 5)
	var troll := state.spawn_unit("troll", {"x": 4, "y": 5, "hp": 100, "maxHp": 100, "team": "player", "footprintWidth": 2, "footprintHeight": 2, "statusEffects": []})
	var ally := _unit("aliado", 6, 4, "enemy")
	var outside := _unit("fora", 8, 5)
	var sweep := _certain(_item(t, "Varredura de Galhos"))
	var area: Array = state.compute_aoe_area_tiles(t, sweep, state.body_probe_tile(t, 1, 0))
	assert_true(area.has({"x": 6, "y": 4}), "prévia da área cobre a faixa à frente")
	state.cast_branch_sweep(t, sweep, state.body_probe_tile(t, 1, 0))
	var taken: int = 100 - int(troll["hp"])
	assert_between(taken, 4, 7, "uma única ocorrência de dano, mesmo ocupando 4 casas da área")
	assert_eq(ally["hp"], 100, "aliado não é atingido")
	assert_eq(outside["hp"], 100, "fora da área")

func test_bark_armor_reduces_physical_by_25_percent_without_stacking() -> void:
	var t := _troncus(2, 5)
	var attacker := _unit("atacante", 4, 5)
	state.cast_self_ability(t, _item(t, "Casca Fortificada"))
	state.cast_self_ability(t, _item(t, "Casca Fortificada"))
	assert_eq(_status(t, "barkArmor").size(), 1, "não acumula")
	assert_eq(_status(t, "barkArmor")[0]["turnsLeft"], 2)
	state.resolve_single_hit(attacker, t, _fixed_hit(8))
	assert_eq(t["hp"], 40, "8 -> Casca Espessa 7 -> ×0.75 = round(5.25) = 5")
	t["hp"] = 45
	state.resolve_single_hit(attacker, t, _fixed_hit(8, {"mpCost": 2}))
	assert_eq(t["hp"], 37, "dano mágico não é reduzido")

func test_sap_restores_hp_and_mp_after_paying_cost_and_cures_poison() -> void:
	var t := _troncus(2, 5)
	t["mp"] = 15
	t["hp"] = 20
	var sap := _item(t, "Seiva Restauradora")
	assert_true(state.cast_restoring_sap(t, t, sap))
	assert_between(int(t["mp"]), 12, 14, "paga 4 antes (15 -> 11) e recupera 1-3")
	assert_between(int(t["hp"]), 25, 30)
	var ally := _unit("aliado", 4, 6, "enemy", {"hp": 95, "mp": 9})
	state.add_status_effect(ally, {"type": "poison", "damageMin": 1, "damageMax": 3, "turnsLeft": 3})
	t["mp"] = 15
	t["hasActed"] = false
	assert_true(state.cast_restoring_sap(t, ally, sap))
	assert_eq(ally["hp"], 100, "não passa do HP máximo")
	assert_eq(ally["mp"], 10, "não passa do MP máximo")
	assert_true(_status(ally, "poison").is_empty(), "remove Envenenado")
	var far := _unit("longe", 6, 5, "enemy", {"hp": 50})
	var foe := _unit("inimigo", 4, 5, "player", {"hp": 50})
	t["mp"] = 15
	assert_false(state.cast_restoring_sap(t, far, sap), "aliado não adjacente")
	assert_false(state.cast_restoring_sap(t, foe, sap), "inimigo não")
	assert_eq(t["mp"], 15, "recusa não gasta MP")

# --- Passivas ----------------------------------------------------------------------------------

func test_thick_bark_immunity_and_fire_vulnerability() -> void:
	var t := _troncus(2, 5)
	var attacker := _unit("atacante", 4, 5)
	state.resolve_single_hit(attacker, t, _fixed_hit(1))
	assert_eq(t["hp"], 44, "físico 1 continua 1")
	# Alvo 2x2 é mais fácil de acertar (bônus de tamanho) — força o erro.
	state.resolve_single_hit(attacker, t, _fixed_hit(5, {"hitChance": -5.0}))
	assert_eq(t["hp"], 44, "erro = 0")
	t["hp"] = 45
	state.resolve_single_hit(attacker, t, _fixed_hit(8, {"damageType": "fire"}))
	assert_eq(t["hp"], 33, "fogo 8 ×1.5 = 12 (Casca Espessa não vale para fogo)")
	t["hp"] = 45
	attacker["burnNextAttackTurns"] = 1
	state.resolve_single_hit(attacker, t, _fixed_hit(8))
	assert_eq(t["hp"], 34, "físico+fogo: 8 -> 7 -> ×1.5 = round(10.5) = 11")
	state.resolve_single_hit(attacker, t, _fixed_hit(3, {"appliesPoison": {"damageMin": 1, "damageMax": 3, "turns": 3}}))
	assert_true(_status(t, "poison").is_empty(), "Corpo Vegetal: imune a Envenenado")

func _start_turn(t: Dictionary) -> void:
	state.begin_turn_for(t)
	assert_eq(state.current_actor, t)

func test_regen_heals_4_when_still_and_2_when_displaced_once_per_turn() -> void:
	var t := _troncus(2, 5)
	_unit("longe", 12, 12)
	t["hp"] = 30
	t["ct"] = 100
	_start_turn(t)
	t["hasActed"] = true
	state.advance_to_next_turn()
	assert_eq(t["hp"], 34, "ficou parado (atacou/virou, sem se deslocar): +4 uma vez")
	t["ct"] = 100
	_start_turn(t)
	state.compute_reachable(t)
	state.perform_move(t, {"x": 3, "y": 5})
	t["hasActed"] = true
	var hp_before := int(t["hp"])
	state.advance_to_next_turn()
	assert_eq(int(t["hp"]), hp_before + 2, "se deslocou: +2")
	t["ct"] = 100
	_start_turn(t)
	state.compute_reachable(t)
	state.perform_move(t, {"x": 2, "y": 5})
	t["hasActed"] = true
	hp_before = int(t["hp"])
	state.advance_to_next_turn()
	assert_eq(int(t["hp"]), hp_before + 2, "andou de volta pra (2,5): +2")

func test_regen_respects_max_hp_and_death() -> void:
	var t := _troncus(2, 5)
	_unit("longe", 12, 12)
	t["hp"] = 44
	t["ct"] = 100
	_start_turn(t)
	t["hasActed"] = true
	state.advance_to_next_turn()
	assert_eq(t["hp"], 45, "não passa do máximo")
	t["hp"] = 0
	state._apply_root_regen(t)
	assert_eq(t["hp"], 0, "não regenera morto")

func test_goblinoid_ai_uses_troncus_kit() -> void:
	var t := _troncus(2, 5)
	var foe := _unit("inimigo", 5, 5)
	var other := _unit("inimigo2", 5, 6)
	t["ct"] = 100
	_start_turn(t)
	t["mp"] = 15
	_item(t, "Varredura de Galhos")["hitChance"] = 1.0
	state.enemy_act(t)
	assert_true(_status(t, "barkArmor").size() == 1, "IA ativa a Casca com inimigo por perto")
	assert_true(int(foe["hp"]) < 100 or int(other["hp"]) < 100 or state.is_rooted(foe) or state.is_rooted(other), "IA age com varredura/raízes/ataque")
