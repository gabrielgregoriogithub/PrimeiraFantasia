extends GutTest

func test_reset_shuffles_each_team_only_within_its_original_slots() -> void:
	var state := GameState.new()
	var original_slots := {}
	for u in state.units:
		if not original_slots.has(u["team"]):
			original_slots[u["team"]] = []
		original_slots[u["team"]].append("%d,%d" % [u["x"], u["y"]])
	for team in original_slots.keys():
		original_slots[team].sort()

	state.rng.seed = 123456
	state.reset()
	var shuffled_slots := {}
	for u in state.units:
		if not shuffled_slots.has(u["team"]):
			shuffled_slots[u["team"]] = []
		shuffled_slots[u["team"]].append("%d,%d" % [u["x"], u["y"]])
	for team in shuffled_slots.keys():
		shuffled_slots[team].sort()
		assert_eq(shuffled_slots[team], original_slots[team], "embaralhar preserva os cinco slots do time")

	# Com esta semente fixa, pelo menos um personagem precisa trocar de slot;
	# isso protege contra reset() voltar a montar sempre a mesma formação.
	var template_units := Units.build()
	var changed := false
	for key in template_units.keys():
		var expected: Dictionary = template_units[key]
		var actual: Dictionary = state.unit(key)
		if actual["x"] != expected["x"] or actual["y"] != expected["y"]:
			changed = true
			break
	assert_true(changed, "reset deve redistribuir personagens entre os slots do próprio time")

## Fase 2 (grade/consultas): porte de tileKey/inBounds/terrainAt/structureAt/
## elevationAt/unitAt/occupantAt/structureOccupant (game.js:4472-4926).

var state: GameState

func before_each() -> void:
	state = GameState.new()

func test_tile_key_format() -> void:
	assert_eq(state.tile_key(3, 7), "3,7")

func test_in_bounds() -> void:
	assert_true(state.in_bounds(0, 0))
	assert_true(state.in_bounds(12, 12))
	assert_false(state.in_bounds(-1, 0))
	assert_false(state.in_bounds(0, 13))
	assert_false(state.in_bounds(13, 0))

func test_terrain_at_matches_water_layout() -> void:
	var terrain = state.terrain_at(6, 0)
	assert_not_null(terrain)
	assert_eq(terrain["type"], "water")
	assert_null(state.terrain_at(3, 5), "tile aberto não deve ter terreno")

func test_structure_at_castle_and_mountain() -> void:
	var castle = state.structure_at(1, 1)
	assert_not_null(castle)
	assert_eq(castle["type"], "castle")
	assert_eq(castle["team"], "player")

	var mountain = state.structure_at(11, 1)
	assert_not_null(mountain)
	assert_eq(mountain["type"], "mountain")
	assert_eq(mountain["team"], "enemy")

	assert_null(state.structure_at(6, 6), "meio do tabuleiro não é estrutura")

func test_elevation_at_castle_mountain_water_and_open() -> void:
	assert_eq(state.elevation_at(1, 1), GameConstants.CASTLE_ELEVATION)
	assert_eq(state.elevation_at(11, 1), GameConstants.MOUNTAIN_ELEVATION)
	assert_eq(state.elevation_at(6, 0), -1, "água fica num vale (-1)")
	assert_eq(state.elevation_at(9, 6), 0, "terreno aberto é nível 0")

func test_unit_at_only_returns_alive_unit_on_exact_tile() -> void:
	var u := state.unit("guerreiro")
	u["x"] = 4
	u["y"] = 4
	assert_eq(state.unit_at(4, 4), u)
	assert_null(state.unit_at(4, 5))

	u["hp"] = 0
	assert_null(state.unit_at(4, 4), "unidade morta não conta como unit_at")

func test_dead_unit_at_requires_turns_since_death_field() -> void:
	var u := state.unit("goblin")
	u["x"] = 2
	u["y"] = 2
	u["hp"] = 0
	assert_null(state.dead_unit_at(2, 2), "sem turnsSinceDeath ainda não é cadáver rastreável")

	u["turnsSinceDeath"] = 0
	assert_eq(state.dead_unit_at(2, 2), u)

func test_occupant_at_includes_dead_unit_with_turns_since_death() -> void:
	var u := state.unit("orc")
	u["x"] = 7
	u["y"] = 7
	u["hp"] = 0
	u["turnsSinceDeath"] = 1
	assert_null(state.unit_at(7, 7))
	assert_eq(state.occupant_at(7, 7), u)

func test_structure_occupant_returns_unit_standing_in_any_of_the_nine_tiles() -> void:
	var castle = state.structure_at(1, 1)
	assert_null(state.structure_occupant(castle), "castelo vazio não tem ocupante")

	var u := state.unit("guerreiro")
	u["x"] = 2
	u["y"] = 0
	assert_eq(state.structure_occupant(castle), u)
