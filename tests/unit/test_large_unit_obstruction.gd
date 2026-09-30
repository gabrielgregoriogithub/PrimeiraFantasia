extends GutTest

## Pedido do usuário: unidades de 4 casas (footprint 2x2: Troll, Goo, Dragão,
## Salamandra) ignoram props do cenário — atravessam, param em cima e atacam
## através deles. Outras unidades (aliadas ou inimigas) continuam bloqueando
## o corpo 2x2 inteiro; props continuam bloqueando unidades de 1 casa.

const PROP_TERRAINS := [
	{"type": "scenery-prop"}, {"type": "tree"}, {"type": "tent"},
	{"type": "tower-bookshelf"}, {"type": "tower-vase"},
	{"type": "village-building"}, {"type": "porto-blocked"},
	{"type": "desfiladeiro-blocked", "prop": true}, {"type": "estrada-inverno-blocked", "prop": true},
]
const NON_PROP_TERRAINS := [
	{"type": "tower-wall"}, {"type": "tower-pillar"}, {"type": "scenery-wall"}, {"type": "lua-mountain"},
	{"type": "desfiladeiro-blocked"}, {"type": "estrada-inverno-cliff"}, {"type": "porto-water"},
]
const LARGE_KINDS := ["troll", "goo", "dragon", "salamander"]

var state: GameState

func before_each() -> void:
	state = GameState.new()
	state.clear_units()
	state.clear_terrain_and_structures()
	# Fora do Campo (onde árvore nunca bloqueia rota, pra ninguém).
	state.scenario_id = ScenarioManager.TOWER

func _large(kind: String, x: int, y: int) -> Dictionary:
	var data: Dictionary
	match kind:
		"troll": data = (Units.build()["troll"] as Dictionary).duplicate(true)
		"goo": data = GameState.black_slime_boss_data({"x": x, "y": y})
		_: data = GameState.dungeon_monster_data(kind, 1, {"x": x, "y": y})
	data["x"] = x
	data["y"] = y
	data["team"] = "enemy"
	var u := state.spawn_unit(kind, data)
	assert_true(state.is_large_unit(u), "%s ocupa 2x2" % kind)
	return u

func _hero(name: String, x: int, y: int, team: String = "player") -> Dictionary:
	return state.spawn_unit(name, {"x": x, "y": y, "hp": 100, "maxHp": 100, "team": team, "moveRange": 4, "statusEffects": []})

func _certain(item: Dictionary) -> Dictionary:
	var copy: Dictionary = item.duplicate(true)
	copy["hitChance"] = 1.0
	copy["critChance"] = 0.0
	return copy

func _item(u: Dictionary, item_name: String) -> Dictionary:
	for item in (u.get("weapons", []) as Array) + (u.get("spells", []) as Array):
		if item["name"] == item_name:
			return item
	fail_test("%s não tem %s" % [u["name"], item_name])
	return {}

func _reaches(u: Dictionary, x: int, y: int) -> bool:
	return state.compute_reachable(u).any(func(t): return t["x"] == x and t["y"] == y)

func _prop_at(x: int, y: int, terrain: Dictionary = {"type": "scenery-prop"}) -> void:
	state.terrain_map[state.tile_key(x, y)] = terrain.duplicate(true)

func _prop_column(x: int, terrain: Dictionary = {"type": "scenery-prop"}) -> void:
	for y in range(GameConstants.BOARD_SIZE):
		_prop_at(x, y, terrain)

# --- Movimento -----------------------------------------------------------------

func test_large_units_cross_a_wall_of_every_prop_kind() -> void:
	for kind in LARGE_KINDS:
		for terrain in PROP_TERRAINS:
			state.clear_units()
			state.clear_terrain_and_structures()
			var u := _large(kind, 3, 5)
			_prop_column(5, terrain)
			assert_true(_reaches(u, 6, 5), "%s atravessa uma parede de %s" % [kind, terrain])

func test_large_units_stop_with_body_partially_or_fully_over_props() -> void:
	for kind in LARGE_KINDS:
		state.clear_units()
		state.clear_terrain_and_structures()
		var u := _large(kind, 2, 5)
		_prop_at(4, 5); _prop_at(5, 5); _prop_at(4, 6); _prop_at(5, 6)
		assert_true(_reaches(u, 3, 5), "%s para com metade do corpo sobre props" % kind)
		assert_true(_reaches(u, 4, 5), "%s para com as 4 casas sobre props" % kind)

func test_large_units_can_start_over_props_and_leave() -> void:
	for kind in LARGE_KINDS:
		state.clear_units()
		state.clear_terrain_and_structures()
		for tile in [[3, 5], [4, 5], [3, 6], [4, 6]]:
			_prop_at(tile[0], tile[1], {"type": "tree"})
		var u := _large(kind, 3, 5)
		assert_true(_reaches(u, 1, 5), "%s sai de cima dos props" % kind)

func test_large_units_are_still_blocked_by_allies_and_enemies() -> void:
	for kind in LARGE_KINDS:
		for team in ["enemy", "player"]:
			state.clear_units()
			state.clear_terrain_and_structures()
			var u := _large(kind, 2, 5)
			for y in range(GameConstants.BOARD_SIZE):
				_hero("parede_%d" % y, 5, y, team)
			var label := "aliados" if team == "enemy" else "inimigos"
			var reachable := state.compute_reachable(u)
			assert_false(reachable.any(func(t): return t["x"] >= 4), "%s não passa nem para sobre %s" % [kind, label])

func test_unit_over_a_prop_still_blocks_the_large_body() -> void:
	for kind in LARGE_KINDS:
		state.clear_units()
		state.clear_terrain_and_structures()
		var u := _large(kind, 2, 5)
		_prop_at(5, 5)
		_hero("aliado", 5, 5, "enemy")
		for anchor in [[4, 4], [5, 4], [4, 5], [5, 5]]:
			assert_false(_reaches(u, anchor[0], anchor[1]), "%s não termina com o corpo sobre o aliado em (5,5)" % kind)

func test_large_units_are_still_blocked_by_non_prop_terrain() -> void:
	for kind in LARGE_KINDS:
		for terrain in NON_PROP_TERRAINS:
			state.clear_units()
			state.clear_terrain_and_structures()
			var u := _large(kind, 3, 5)
			_prop_column(5, terrain)
			assert_false(_reaches(u, 6, 5), "%s continua barrado por %s" % [kind, terrain])
			assert_false(_reaches(u, 4, 5), "%s não para sobre %s" % [kind, terrain])

func test_movement_range_and_board_limits_are_kept() -> void:
	var troll := _large("troll", 0, 5)
	_prop_column(1)
	assert_false(_reaches(troll, 5, 5), "alcance 4 continua valendo sobre props")
	assert_true(_reaches(troll, 4, 5))
	var edge := GameConstants.BOARD_SIZE - 1
	assert_false(state.compute_reachable(troll).any(func(t): return t["x"] >= edge or t["y"] >= edge), "corpo 2x2 nunca sai do mapa")

func test_small_unit_is_still_blocked_by_props() -> void:
	for terrain in PROP_TERRAINS:
		state.clear_units()
		state.clear_terrain_and_structures()
		var goblin := _hero("goblin", 3, 5, "enemy")
		_prop_column(5, terrain)
		assert_false(_reaches(goblin, 5, 5), "1x1 não para sobre %s" % [terrain])
		assert_false(_reaches(goblin, 6, 5), "1x1 não atravessa %s" % [terrain])

func test_ai_path_distance_ignores_props_only_for_large_units() -> void:
	var troll := _large("troll", 2, 5)
	_prop_column(5)
	var for_troll := state._walkable_path_distance_map(8, 5, troll)
	var generic := state._walkable_path_distance_map(8, 5)
	assert_true(for_troll.has(state.tile_key(2, 5)), "Troll enxerga o caminho através dos props")
	assert_false(generic.has(state.tile_key(2, 5)), "sem unidade, a parede de props continua fechando o caminho")

# --- Ataques -------------------------------------------------------------------

func _surround_with_props(u: Dictionary) -> void:
	for tile in state.footprint_tiles(u):
		_prop_at(tile["x"], tile["y"], {"type": "tree", "hp": 99, "maxHp": 99})
	_prop_column(4, {"type": "tent", "hp": 99, "maxHp": 99})

func test_range_preview_is_not_blocked_by_props() -> void:
	for kind in LARGE_KINDS:
		state.clear_units()
		state.clear_terrain_and_structures()
		var u := _large(kind, 2, 5)
		var before := {}
		for item in (u["weapons"] as Array) + (u["spells"] as Array):
			if item.has("maxRange"): before[item["name"]] = state.compute_range_tiles(u, item)
		_surround_with_props(u)
		for item_name in before.keys():
			assert_eq(state.compute_range_tiles(u, _item(u, item_name)), before[item_name], "%s/%s: props não reduzem o alcance" % [kind, item_name])

func test_troll_attacks_through_props() -> void:
	var troll := _large("troll", 2, 5)
	_surround_with_props(troll)
	var target := _hero("alvo", 5, 5)
	assert_true(state.compute_aoe_area_tiles(troll, _item(troll, "Tronco"), {"x": 5, "y": 5}).has({"x": 5, "y": 5}), "Tronco alcança o alvo atrás dos props")
	state.cast_throw_log(troll, _certain(_item(troll, "Tacar Tronco")), state.body_probe_tile(troll, 1, 0))
	assert_lt(int(target["hp"]), 100, "Tacar Tronco acerta através dos props")

func test_dragon_attacks_through_props() -> void:
	var dragon := _large("dragon", 2, 5)
	_surround_with_props(dragon)
	var far := _hero("longe", 6, 5)
	var cone := _certain(_item(dragon, "Cone de Fogo"))
	state.cast_fire_cone(dragon, cone, state.compute_aoe_area_tiles(dragon, cone, {"x": 6, "y": 5}))
	assert_lt(int(far["hp"]), 100, "Cone de Fogo atravessa os props")
	var near := _hero("perto", 2, 4)
	state.perform_attack(dragon, near, _certain(_item(dragon, "Garra")))
	assert_lt(int(near["hp"]), 100, "Garra acerta de cima dos props")

func test_salamander_attacks_through_props() -> void:
	var salamander := _large("salamander", 2, 5)
	_surround_with_props(salamander)
	var target := _hero("alvo", 5, 5)
	assert_eq(state.resolve_obstructed_target(salamander, {"x": 5, "y": 5}), {"x": 5, "y": 5}, "nem props nem o próprio corpo obstruem a linha")
	state.perform_ranged_attack_with_obstruction(salamander, target, _certain(_item(salamander, "Tridente")))
	assert_lt(int(target["hp"]), 100, "Tridente acerta através dos props")
	var far := _hero("longe", 6, 6)
	var wave := _certain(_item(salamander, "Labaredas de Chamas"))
	state.cast_salamander_flame_wave(salamander, wave, state.body_probe_tile(salamander, 1, 0))
	assert_lt(int(far["hp"]), 100, "Labaredas atravessam os props")

func test_goo_attacks_through_props() -> void:
	var goo := _large("goo", 2, 5)
	_surround_with_props(goo)
	var far := _hero("longe", 5, 5)
	state.cast_black_slime_poison(goo)
	assert_true((far["statusEffects"] as Array).any(func(e): return e["type"] == "poison"), "Nuvem Venenosa atravessa os props")
	var near := _hero("perto", 2, 4)
	state.perform_attack(goo, near, _certain(_item(goo, "Pancada")))
	assert_lt(int(near["hp"]), 100, "Pancada acerta de cima dos props")

func test_ranged_line_is_still_blocked_by_a_unit() -> void:
	var salamander := _large("salamander", 2, 5)
	_surround_with_props(salamander)
	_hero("bloqueio", 4, 5)
	_hero("alvo", 5, 5)
	assert_eq(state.resolve_obstructed_target(salamander, {"x": 5, "y": 5}), {"x": 4, "y": 5}, "unidade no caminho continua obstruindo")

# --- Cenários reais do modo história -------------------------------------------

func _apply(id: String) -> void:
	state.reset()
	state.apply_scenario(ScenarioManager.definition(id))

func test_village_trolls_cross_and_stop_over_houses() -> void:
	_apply(ScenarioManager.VILLAGE)
	var trolls := state.units.filter(func(u): return u["name"] == "Troll")
	assert_false(trolls.is_empty(), "a Vila tem Troll")
	for troll in trolls:
		var over_house := false
		for t in state.compute_reachable(troll):
			for tile in state.footprint_tiles(troll, t["x"], t["y"]):
				var terrain = state.terrain_at(tile["x"], tile["y"])
				if terrain != null and terrain["type"] == "village-building": over_house = true
		assert_true(over_house, "%s alcança casas da Vila" % troll["name"])
	var warrior: Dictionary = state.units_by_key["guerreiro"]
	var small_over_house := state.compute_reachable(warrior).any(func(t):
		var terrain = state.terrain_at(t["x"], t["y"])
		return terrain != null and terrain["type"] == "village-building")
	assert_false(small_over_house, "Guerreiro (1x1) continua barrado pelas casas")

func test_troll_passes_through_a_field_house() -> void:
	# Corredor de 2 linhas (y=5..6): o único caminho pra direita passa com a
	# âncora pela casa em (3,5) — "pode parar, não atravessa" pra 1x1.
	for x in range(GameConstants.BOARD_SIZE):
		_prop_at(x, 4, {"type": "tower-wall"})
		_prop_at(x, 7, {"type": "tower-wall"})
	_prop_at(3, 5, {"type": "house"})
	var troll := _large("troll", 1, 5)
	assert_true(_reaches(troll, 3, 5), "para sobre a casa")
	assert_true(_reaches(troll, 5, 5), "atravessa a casa")
	var goblin := _hero("goblin", 1, 5, "enemy")
	state.units.erase(troll)
	assert_false(_reaches(goblin, 4, 5), "1x1 continua sem atravessar a casa")
