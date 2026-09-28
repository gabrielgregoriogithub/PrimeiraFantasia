extends GutTest

## Online: cada jogador monta 5 personagens de qualquer grupo (heróis e
## monstros misturados). O time do criador joga como "player" e o do
## adversário como "enemy"; o mesmo personagem nos dois lados ganha 🔵/🔴
## no nome para ficar distinguível (e os nomes continuam únicos).

func _build(slot1: Array, slot2: Array) -> GameState:
	var state := GameState.new()
	state.apply_pvp_scenario(ScenarioManager.definition(ScenarioManager.FIELD), slot1, slot2)
	return state

func test_mixed_rosters_play_on_their_owner_side() -> void:
	var state := _build(["guerreiro", "orc", "vampire", "rat", "mago"], ["arqueiro", "goblin", "lich", "slime", "monge"])
	assert_eq(state.team_units("player").size(), 5)
	assert_eq(state.team_units("enemy").size(), 5)
	var orc: Dictionary = state.units.filter(func(u): return u["name"] == "Orc")[0] if state.units.any(func(u): return u["name"] == "Orc") else {}
	assert_false(orc.is_empty(), "monstro escolhido pelo criador entra na partida")
	assert_eq(orc.get("team"), "player", "monstro do criador joga no lado dele")
	var archer: Dictionary = state.units.filter(func(u): return String(u["name"]).begins_with("Arqueiro"))[0]
	assert_eq(archer["team"], "enemy", "herói do adversário joga no lado dele")

func test_same_character_on_both_sides_gets_blue_and_red_markers() -> void:
	var state := _build(["guerreiro", "vampire", "rat", "orc", "mago"], ["guerreiro", "vampire", "rat", "goblin", "monge"])
	var names: Array = state.units.map(func(u): return u["name"])
	for base in ["Guerreiro", "Vampiro", "Rato"]:
		assert_true(names.has("%s 🔵" % base), "%s do criador marcado com 🔵" % base)
		assert_true(names.has("%s 🔴" % base), "%s do adversário marcado com 🔴" % base)
	assert_true(names.has("Orc"), "personagem sem repetição mantém o nome")
	var unique := {}
	for n in names: unique[n] = true
	assert_eq(unique.size(), names.size(), "nomes continuam únicos")
	for u in state.units:
		if String(u["name"]).ends_with("🔵"): assert_eq(u["team"], "player")
		if String(u["name"]).ends_with("🔴"): assert_eq(u["team"], "enemy")

func test_classic_local_pvp_is_unchanged() -> void:
	var state := _build(Units.player_team_keys().slice(0, 5), Units.enemy_team_keys().slice(0, 5))
	for u in state.units:
		assert_false(String(u["name"]).contains("🔵") or String(u["name"]).contains("🔴"))
	assert_eq(state.team_units("player").size(), 5)
	assert_eq(state.team_units("enemy").size(), 5)
