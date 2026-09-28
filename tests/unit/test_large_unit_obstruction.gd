extends GutTest

## Pedido do usuário: unidades de 4 casas (footprint 2x2) são obstruídas por
## props/árvores/tendas como qualquer outra — não atravessam nem param em cima.

var state: GameState

func before_each() -> void:
	state = GameState.new()
	state.clear_units()
	state.clear_terrain_and_structures()

func _troll(x: int, y: int) -> Dictionary:
	return state.spawn_unit("troll", {"x": x, "y": y, "team": "enemy", "moveRange": 4, "footprintWidth": 2, "footprintHeight": 2, "footprintSize": 2})

func _reaches(u: Dictionary, x: int, y: int) -> bool:
	return state.compute_reachable(u).any(func(t): return t["x"] == x and t["y"] == y)

func test_large_unit_cannot_stop_with_body_over_blocking_props() -> void:
	for prop_type in ["scenery-prop", "tree", "tent", "tower-bookshelf", "tower-vase"]:
		state.clear_terrain_and_structures()
		var troll := _troll(2, 2)
		state.terrain_map[state.tile_key(5, 3)] = {"type": prop_type}
		assert_false(_reaches(troll, 4, 2), "%s sob o corpo 2x2 impede parar ali" % prop_type)
		assert_false(_reaches(troll, 5, 3), "%s na âncora impede parar ali" % prop_type)
		state.clear_units()

func test_large_unit_cannot_walk_through_a_wall_of_props() -> void:
	var troll := _troll(2, 2)
	for y in range(0, GameConstants.BOARD_SIZE):
		state.terrain_map[state.tile_key(5, y)] = {"type": "scenery-prop"}
	assert_false(_reaches(troll, 6, 2), "parede de props bloqueia a passagem")

func test_small_unit_rule_is_unchanged() -> void:
	var goblin := state.spawn_unit("goblin", {"x": 2, "y": 2, "team": "enemy", "moveRange": 4})
	state.terrain_map[state.tile_key(3, 2)] = {"type": "scenery-prop"}
	assert_false(_reaches(goblin, 3, 2))
	assert_true(_reaches(goblin, 4, 2), "contorna o prop")
