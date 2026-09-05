extends GutTest

func test_floor_4_definition_and_progression() -> void:
	var floor := ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_4)
	assert_eq(floor["name"], "4º ANDAR")
	assert_eq(floor["floor_number"], 4)
	assert_eq(floor["theme"], "demon-halls")
	assert_eq(floor["next_floor_id"], "tower_floor_5")
	assert_eq(floor["doors"].size(), 4)
	assert_true(floor["doors"].any(func(door): return door["x"] == 1 and door["y"] == 4), "porta superior esquerda abre uma passagem livre na coluna 1")
	assert_false(floor["doors"].any(func(door): return door["x"] == 2 and door["y"] == 4), "porta não deve ficar diante do pilar em (2,5)")
	assert_lt(floor["walls"].size(), 60, "layout aberto, sem excesso de paredes")
	var manager: Node = autofree(ScenarioManager.new())
	assert_eq(manager.next_id(ScenarioManager.TOWER_FLOOR_3), ScenarioManager.TOWER_FLOOR_4)
	assert_eq(manager.next_id(ScenarioManager.TOWER_FLOOR_4), ScenarioManager.VILLAGE)

func test_central_lava_pool_is_exactly_four_by_four() -> void:
	var floor := ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_4)
	var lava_keys := {}
	for tile in floor["lava"]:
		lava_keys["%d,%d" % [tile["x"], tile["y"]]] = true
	for y in range(5, 9):
		for x in range(5, 9):
			assert_true(lava_keys.has("%d,%d" % [x, y]), "núcleo central deve preencher 4x4")
	var central_count := 0
	for tile in floor["lava"]:
		if int(tile["x"]) in range(5, 9) and int(tile["y"]) in range(5, 9):
			central_count += 1
	assert_eq(central_count, 16)
	assert_gt(floor["lava"].size(), 16, "deve haver poças secundárias separadas")

func test_floor_4_entrance_and_exit_are_connected() -> void:
	var state := GameState.new()
	var floor := ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_4)
	state.apply_scenario(floor)
	var hero: Dictionary = state.team_units("player")[0]
	state.units = [hero]
	hero["x"] = floor["entrance_tile"]["x"]
	hero["y"] = floor["entrance_tile"]["y"]
	hero["moveRange"] = 100
	var reachable := state.compute_reachable(hero)
	assert_true(reachable.any(func(tile): return tile["x"] == floor["exit_tile"]["x"] and tile["y"] == floor["exit_tile"]["y"]))

func test_floor_4_reuses_lava_damage_and_burn_rules() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_4))
	var hero: Dictionary = state.team_units("player")[0]
	var lava = state.terrain_at(5, 5)
	assert_eq(lava["type"], "hazard")
	assert_eq(lava["hazard"], "lava")
	assert_eq(state.step_cost(hero, 5, 5), 3)
	var hp_before: int = hero["hp"]
	state.apply_trap_crossings(hero, [{"x":5,"y":5},{"x":6,"y":5},{"x":7,"y":5}])
	assert_eq(hero["hp"], hp_before - 3)
	hero["x"] = 5
	hero["y"] = 5
	state._apply_end_turn_tile_hazard(hero)
	assert_true(hero["statusEffects"].any(func(effect): return effect["type"] == "burned"))

func test_floor_4_contains_one_salamander_on_walkable_tiles() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_4))
	var salamanders := state.team_units("enemy").filter(func(unit): return unit["spriteKey"] == "tower_salamander")
	assert_eq(salamanders.size(), 1)
	assert_eq(state.team_units("enemy").size(), 1, "deve existir apenas uma Salamandra no 4º Andar")
	var occupied := {}
	for unit in state.units:
		for tile in state.footprint_tiles(unit):
			var key := state.tile_key(tile["x"], tile["y"])
			assert_false(occupied.has(key), "footprints dos spawns do 4º Andar não podem se sobrepor")
			occupied[key] = true
			var terrain = state.terrain_at(tile["x"], tile["y"])
			assert_true(terrain == null or terrain.get("walkable", false), "%s ocupa apenas tiles transitáveis" % unit["name"])

func test_salamander_stats_and_ability_catalog() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_4))
	var salamander: Dictionary = state.team_units("enemy").filter(func(unit): return unit["spriteKey"] == "tower_salamander")[0]
	assert_eq([salamander["hp"], salamander["maxHp"], salamander["mp"], salamander["maxMp"]], [300, 300, 20, 20])
	assert_eq([salamander["speed"], salamander["moveRange"]], [11, 4])
	assert_eq([state.footprint_width(salamander), state.footprint_height(salamander)], [2, 2])
	for tile in state.footprint_tiles(salamander):
		assert_eq(state.unit_at(tile["x"], tile["y"]), salamander, "qualquer tile 2x2 resolve para a mesma Salamandra")
	assert_eq(salamander["elementAffinity"], {"fire":{"mode":"heal","multiplier":1.0},"ice":{"mode":"damage","multiplier":2.0}})
	var trident: Dictionary = salamander["weapons"][0]
	assert_eq([trident["damageMin"], trident["damageMax"], trident["hitChance"], trident["critChance"], trident["ctCost"], trident["maxRange"]], [6, 10, 0.8, 0.15, 50, 2])
	assert_eq(trident["damageType"], "fire")
	assert_true(trident.has("appliesBurn"))
	var explosion: Dictionary = salamander["spells"][0]
	assert_eq([explosion["damageMin"], explosion["damageMax"], explosion["hitChance"], explosion["critChance"], explosion["ctCost"], explosion["mpCost"]], [8, 12, 0.8, 0.0, 60, 5])
	assert_eq([explosion["kind"], explosion["targetMode"]], ["growth-attack", "self-attack"])
	var wave: Dictionary = salamander["spells"][1]
	assert_eq([wave["damageMin"], wave["damageMax"], wave["hitChance"], wave["critChance"], wave["ctCost"], wave["mpCost"]], [10, 15, 0.8, 0.0, 70, 10])
	assert_eq([wave["bandLength"], wave["bandWidth"]], [GameConstants.BOARD_SIZE, 3])

func test_large_unit_uses_edge_distance_and_aoe_only_lists_it_once() -> void:
	var state := GameState.new()
	var large := {"name":"Grande","team":"enemy","x":4,"y":4,"hp":100,"footprintWidth":2,"footprintHeight":2}
	var small := {"name":"Pequeno","team":"player","x":6,"y":5,"hp":10}
	state.units = [large, small]
	assert_eq(state.manhattan(large, small), 1, "alcance é medido entre as bordas dos corpos")
	assert_true(state.units_cardinally_aligned(large, small))
	assert_eq(state.units_in_tiles([{"x":4,"y":4},{"x":5,"y":4},{"x":4,"y":5},{"x":5,"y":5}]), [large], "AoE não duplica unidade grande")

func test_salamander_areas_reuse_growth_and_creeping_geometry_and_pay_once() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_4))
	var salamander: Dictionary = state.team_units("enemy").filter(func(unit): return unit["spriteKey"] == "tower_salamander")[0]
	state.units = [salamander]
	salamander["x"] = 6
	salamander["y"] = 6
	salamander["ct"] = 100
	var explosion: Dictionary = salamander["spells"][0]
	var mp_before: int = salamander["mp"]
	state.cast_growth_attack(salamander, explosion)
	assert_eq([salamander["mp"], salamander["ct"]], [mp_before - 5, 40])
	var wave: Dictionary = salamander["spells"][1]
	var shaman_shape := wave.duplicate(true)
	shaman_shape["targetMode"] = "creeping-line"
	var target := {"x": 7, "y": 6}
	assert_eq(state.compute_aoe_area_tiles(salamander, wave, target), state.compute_aoe_area_tiles(salamander, shaman_shape, target))
	salamander["ct"] = 100
	mp_before = salamander["mp"]
	state.cast_salamander_flame_wave(salamander, wave, target)
	assert_eq([salamander["mp"], salamander["ct"]], [mp_before - 10, 30])

func test_salamander_absorbs_fire_doubles_ice_and_heals_on_lava_end_turn() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_4))
	var salamander: Dictionary = state.team_units("enemy").filter(func(unit): return unit["spriteKey"] == "tower_salamander")[0]
	var attacker: Dictionary = state.team_units("player")[0]
	salamander["hp"] = 200
	var fire := {"name":"Fogo de Teste","damageMin":10,"damageMax":10,"hitChance":1.0,"critChance":0.0,"critMultiplier":1,"minRange":1,"maxRange":20,"damageType":"fire"}
	state.resolve_single_hit(attacker, salamander, fire)
	assert_eq(salamander["hp"], 210, "fogo cura pelo valor que causaria de dano")
	var ice := {"name":"Gelo de Teste","damageMin":10,"damageMax":10,"hitChance":1.0,"critChance":0.0,"critMultiplier":1,"minRange":1,"maxRange":20,"damageType":"ice"}
	state.resolve_single_hit(attacker, salamander, ice)
	assert_eq(salamander["hp"], 190, "gelo causa dano dobrado")
	salamander["x"] = 5
	salamander["y"] = 5
	var hp_before_lava: int = salamander["hp"]
	state._apply_end_turn_tile_hazard(salamander)
	assert_between(salamander["hp"] - hp_before_lava, 8, 16, "quatro quadrados de lava sob o corpo curam quatro rolagens, sem contar o resto da poça")
	assert_false(salamander["statusEffects"].any(func(effect): return effect["type"] == "burned"))

func test_salamander_lava_heal_counts_only_lava_tiles_under_its_footprint() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_4))
	var salamander: Dictionary = state.team_units("enemy")[0]
	salamander["hp"] = 200
	# (4,4) ocupa (4,4), (5,4), (4,5), (5,5): somente (5,5) é lava.
	salamander["x"] = 4
	salamander["y"] = 4
	state._apply_end_turn_tile_hazard(salamander)
	assert_between(salamander["hp"] - 200, 2, 4, "uma única casa de lava sob o 2x2 gera uma única cura")

func test_salamander_fire_explosion_never_heals_its_own_large_body() -> void:
	var state := GameState.new()
	state.apply_scenario(ScenarioManager.definition(ScenarioManager.TOWER_FLOOR_4))
	var salamander: Dictionary = state.team_units("enemy")[0]
	salamander["x"] = 5
	salamander["y"] = 5
	salamander["hp"] = 200
	var explosion: Dictionary = salamander["spells"][0].duplicate(true)
	explosion["hitChance"] = 1.0
	state.cast_growth_attack(salamander, explosion)
	assert_eq(salamander["hp"], 200, "o fogo da própria Salamandra não pode gerar autocura")
