extends GutTest

## Ajustes de conteúdo pedidos pelo usuário depois da sessão de polimento
## visual: Cone de Gelo (Mago), Punhal envenenado + crítico invisível 40%
## (Ladino), Bomba renomeada pra "Bomba de Fogo" (Químico).

var state: GameState

func before_each() -> void:
	state = GameState.new()
	state.clear_units()
	state.clear_terrain_and_structures()

func _weapon(overrides: Dictionary) -> Dictionary:
	var w := {
		"name": "arma-teste", "ctCost": 50, "damageMin": 5, "damageMax": 5,
		"critMultiplier": 2, "critChance": 0.0, "hitChance": 1.0,
		"minRange": 1, "maxRange": 1,
	}
	for k in overrides.keys(): w[k] = overrides[k]
	return w

# --- Cone de Gelo (Mago) -----------------------------------------------------

func test_mage_has_ice_cone_in_its_spell_list() -> void:
	var mage: Dictionary = Units.build()["mago"]
	var ice_cone = (mage["spells"] as Array).filter(func(s): return s.get("name", "") == "Cone de Gelo")
	assert_eq(ice_cone.size(), 1)
	var spell: Dictionary = ice_cone[0]
	assert_eq(spell["mpCost"], 10)
	assert_eq(spell["ctCost"], 50)
	assert_eq(spell["damageMin"], 5)
	assert_eq(spell["damageMax"], 10)
	assert_eq(spell["hitChance"], 0.8)
	assert_eq(spell["critChance"], 0)
	assert_eq(spell["maxRange"], Spells.build()["poisonCone"]["maxRange"], "mesma área do Envenenamento do Xamã")
	assert_eq(spell["minRange"], Spells.build()["poisonCone"]["minRange"])

func test_ice_cone_area_matches_poison_cone_shape() -> void:
	var caster := state.spawn_unit("caster", {"x": 5, "y": 5})
	var spell: Dictionary = Spells.build()["iceCone"]
	var poison_spell: Dictionary = Spells.build()["poisonCone"]
	var ice_area = state.compute_aoe_area_tiles(caster, spell, {"x": 7, "y": 5})
	var poison_area = state.compute_aoe_area_tiles(caster, poison_spell, {"x": 7, "y": 5})
	assert_eq(ice_area, poison_area, "mesmo cone reto do Envenenamento")

func test_ice_cone_damages_and_slows_anyone_in_the_area_including_allies() -> void:
	var spell: Dictionary = Spells.build()["iceCone"].duplicate(true)
	spell["hitChance"] = 1.0
	var caster := state.spawn_unit("caster", {"x": 5, "y": 5, "team": "player"})
	var enemy := state.spawn_unit("enemy", {"x": 6, "y": 5, "team": "enemy", "hp": 30, "maxHp": 30, "speed": 10})
	var ally := state.spawn_unit("ally", {"x": 7, "y": 5, "team": "player", "hp": 30, "maxHp": 30, "speed": 10})
	var tiles = state.compute_aoe_area_tiles(caster, spell, {"x": 6, "y": 5})
	state.cast_ice_cone(caster, spell, tiles)
	assert_lt(enemy["hp"], 30, "inimigo no cone sofre dano")
	assert_eq(enemy["speed"], 9, "inimigo tem agilidade reduzida em 1")
	assert_lt(ally["hp"], 30, "Cone de Gelo acerta qualquer um na área, igual o Envenenamento (mesmo comportamento assumido pelo usuário)")
	assert_eq(ally["speed"], 9, "aliado no cone também é desacelerado")

func test_ice_cone_slow_status_lasts_two_turns() -> void:
	var spell: Dictionary = Spells.build()["iceCone"].duplicate(true)
	spell["hitChance"] = 1.0
	var caster := state.spawn_unit("caster", {"x": 5, "y": 5})
	var target := state.spawn_unit("target", {"x": 6, "y": 5, "team": "enemy", "hp": 30, "maxHp": 30})
	state.cast_ice_cone(caster, spell, state.compute_aoe_area_tiles(caster, spell, {"x": 6, "y": 5}))
	var slowed = (target["statusEffects"] as Array).filter(func(e): return e.get("type", "") == "slowed")
	assert_eq(slowed.size(), 1)
	assert_eq(slowed[0]["turnsLeft"], 2)

# --- Punhal do Ladino ---------------------------------------------------------

func test_rogue_dagger_now_poisons_on_hit() -> void:
	var dirk: Dictionary = Weapons.build()["dirk"]
	assert_true(dirk.has("appliesPoison"), "Punhal precisa envenenar ao acertar")
	assert_eq(dirk["appliesPoison"]["damageMin"], 1)
	assert_eq(dirk["appliesPoison"]["damageMax"], 3)

func test_rogue_dagger_invisible_crit_chance_is_40_percent() -> void:
	var dirk: Dictionary = Weapons.build()["dirk"]
	assert_eq(dirk["invisibleCritChance"], 0.40)
	var invisible_attacker := {"statusEffects": [{"type": "invisible", "turnsLeft": 2}]}
	assert_eq(state.get_crit_chance(dirk, "front", invisible_attacker), 0.40)

func test_dirk_poison_actually_applies_through_a_real_hit() -> void:
	var dirk: Dictionary = Weapons.build()["dirk"].duplicate(true)
	dirk["hitChance"] = 1.0
	var attacker := state.spawn_unit("ladino", {"x": 1, "y": 1})
	var defender := state.spawn_unit("alvo", {"x": 1, "y": 2}, )
	state.resolve_single_hit(attacker, defender, dirk)
	var poisoned = (defender["statusEffects"] as Array).filter(func(e): return e.get("type", "") == "poison")
	assert_eq(poisoned.size(), 1)

# --- Bomba de Fogo (Químico) ---------------------------------------------------

func test_chemist_bomb_was_renamed_to_bomba_de_fogo() -> void:
	assert_eq(Spells.build()["bomb"]["name"], "Bomba de Fogo")
	var chemist: Dictionary = Units.build()["quimico"]
	var renamed = (chemist["spells"] as Array).filter(func(s): return s.get("name", "") == "Bomba de Fogo")
	assert_eq(renamed.size(), 1)

# --- Salamandra/Slime Negro no Modo PVP (pedido do usuário: HP menor que a campanha) ---

func test_pvp_monster_stat_overrides_table_has_the_requested_values() -> void:
	assert_eq(GameState.PVP_MONSTER_STAT_OVERRIDES["salamander"], {"hp": 80, "maxHp": 80})
	assert_false(GameState.PVP_MONSTER_STAT_OVERRIDES.has("goo"), "correção do usuário: Slime Negro fica igual ao Modo História também no PVP")

func test_apply_pvp_scenario_gives_salamander_80_hp_but_keeps_goo_like_story_mode() -> void:
	var hero_keys: Array = Units.player_team_keys().slice(0, 5)
	var monster_keys := ["salamander", "goo", "zombie", "ghost", "skeleton"]
	state.apply_pvp_scenario(ScenarioManager.definition(ScenarioManager.FIELD), hero_keys, monster_keys)
	var enemies := state.team_units("enemy")
	var salamander = enemies.filter(func(u): return u["spriteKey"] == "tower_salamander")[0]
	var goo = enemies.filter(func(u): return u["spriteKey"] == "spd_goo")[0]
	assert_eq([salamander["hp"], salamander["maxHp"]], [80, 80], "Salamandra no PVP tem 80 HP, não os 300 da campanha")
	assert_eq([goo["hp"], goo["maxHp"]], [200, 200], "Slime Negro no PVP continua com 200 HP, igual ao Modo História")

func test_black_slime_split_thresholds_are_the_same_in_pvp_and_story_mode() -> void:
	var boss := state.spawn_unit("Slime Negro PVP", {
		"team": "enemy", "x": 5, "y": 5, "hp": 140, "maxHp": 200, "speed": 20, "mp": 10, "maxMp": 10,
		"statusEffects": [], "facing": {"dx": 0, "dy": 1}, "spriteKey": "spd_goo",
		"footprintWidth": 2, "footprintHeight": 2, "footprintSize": 2, "slimeStage": 0,
		"weapons": [], "spells": [],
	})
	state._check_black_slime_split(boss)
	var stage1 := state.team_units("enemy").filter(func(u): return u.get("slimeStage", -1) == 1)
	assert_eq(stage1.size(), 2)
	for child in stage1:
		assert_eq([child["hp"], child["maxHp"]], [70, 70])

# --- Campo no Modo PVP (pedido do usuário: inimigo não pode nascer em cima da Montanha) ---

func test_field_enemy_spawns_never_land_on_the_mountain_structure() -> void:
	var mountain_tiles: Array = []
	for structure in BoardLayout.STRUCTURES_LAYOUT:
		if structure["type"] == "mountain":
			mountain_tiles = structure["tiles"]
	assert_false(mountain_tiles.is_empty(), "sanity check: a Montanha existe em BoardLayout")
	var field_spawns: Array = ScenarioManager.definition(ScenarioManager.FIELD)["enemy_spawns"]
	for spawn in field_spawns:
		var on_mountain := mountain_tiles.any(func(t): return t["x"] == spawn["x"] and t["y"] == spawn["y"])
		assert_false(on_mountain, "spawn (%d,%d) não pode cair dentro do bloco 3x3 da Montanha" % [spawn["x"], spawn["y"]])

func test_apply_pvp_scenario_on_field_never_places_an_enemy_on_the_mountain() -> void:
	var hero_keys: Array = Units.player_team_keys().slice(0, 5)
	var monster_keys := ["goblin", "orc", "xama", "fada", "troll"]
	state.apply_pvp_scenario(ScenarioManager.definition(ScenarioManager.FIELD), hero_keys, monster_keys)
	var mountain_tiles: Array = []
	for structure in BoardLayout.STRUCTURES_LAYOUT:
		if structure["type"] == "mountain":
			mountain_tiles = structure["tiles"]
	for enemy in state.team_units("enemy"):
		var on_mountain := mountain_tiles.any(func(t): return t["x"] == enemy["x"] and t["y"] == enemy["y"])
		assert_false(on_mountain, "%s não pode nascer em cima da Montanha" % enemy["name"])
