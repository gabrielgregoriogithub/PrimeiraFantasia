extends GutTest

## Lobo dos Goblinoides (pedido do usuário).

var state: GameState

func before_each() -> void:
	state = GameState.new()
	state.clear_units()
	state.clear_terrain_and_structures()
	state.scenario_id = ScenarioManager.TOWER

func _template(key: String, x: int, y: int, overrides: Dictionary = {}) -> Dictionary:
	var data: Dictionary = (Units.build()[key] as Dictionary).duplicate(true)
	data["x"] = x
	data["y"] = y
	for k in overrides: data[k] = overrides[k]
	return state.spawn_unit(String(overrides.get("name", data["name"])), data)

func _wolf(x: int = 2, y: int = 5, overrides: Dictionary = {}) -> Dictionary:
	return _template("lobo", x, y, overrides)

func _unit(unit_name: String, x: int, y: int, team: String = "player", extra: Dictionary = {}) -> Dictionary:
	return state.spawn_unit(unit_name, DataUtil.merge({"x": x, "y": y, "hp": 100, "maxHp": 100, "speed": 10, "moveRange": 4, "team": team, "statusEffects": []}, extra))

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

func test_wolf_stats_kit_and_team() -> void:
	var w: Dictionary = Units.build()["lobo"]
	assert_eq([w["maxHp"], w["maxMp"], w["speed"], w["moveRange"]], [25, 10, 13, 5])
	assert_eq(w["team"], "enemy")
	assert_false(state.is_large_unit(w))
	assert_true(PvpSetup.MONSTER_GROUPS["goblinoides"]["monsters"].has("lobo"))
	assert_true(w.get("isMount", false))
	assert_eq(_names(w["weapons"]), ["Mordida"])
	assert_eq(_names(w["spells"]), ["Bote Selvagem", "Dilacerar", "Uivo de Caça"])
	assert_eq(_names(w["passives"]), ["Instinto de Matilha", "Contra-ataque de Mordida", "Montaria dos Goblinoides"])
	var bite := _item(w, "Mordida")
	assert_eq([bite["damageMin"], bite["damageMax"], bite["ctCost"], bite["maxRange"]], [4, 8, 50, 1])
	assert_false(bite.has("mpCost"))
	var pounce := _item(w, "Bote Selvagem")
	assert_eq([pounce["mpCost"], pounce["damageMin"], pounce["damageMax"], pounce["maxRange"]], [3, 5, 9, 3])
	var rend := _item(w, "Dilacerar")
	assert_eq([rend["mpCost"], rend["damageMin"], rend["damageMax"], rend["maxRange"]], [3, 5, 11, 1])
	var howl := _item(w, "Uivo de Caça")
	assert_eq([howl["mpCost"], howl["ctCost"], howl["speedBonus"], howl["turns"]], [4, 0, 2, 2])

func test_wolf_assets_walk_and_idle_share_textures() -> void:
	var anims: Dictionary = AnimalSpriteCatalog.spec("lobo")["anims"]
	for dir in ["down", "up", "left", "right"]:
		var walk: Array = anims["walk_" + dir][0]
		assert_eq(walk.size(), 2, "2 poses alternadas na caminhada")
		assert_eq(anims["idle_" + dir][0], [walk[0]], "idle = uma das poses de walk")
	for action in ["attack", "hit", "death", "walk_down", "walk_up", "walk_left", "walk_right"]:
		for path in anims[action][0]:
			assert_true(ResourceLoader.exists(path), path)
	assert_true(ResourceLoader.exists(AnimalSpriteCatalog.spec("lobo")["portrait"]))

# --- Mordida ------------------------------------------------------------------------------

func test_bite_heals_1_to_2_capped_at_max_hp() -> void:
	var wolf := _wolf()
	var target := _unit("alvo", 3, 5)
	wolf["hp"] = 10
	state.resolve_single_hit(wolf, target, _certain(_item(wolf, "Mordida")))
	assert_between(int(wolf["hp"]), 11, 12)
	wolf["hp"] = 24
	state.resolve_single_hit(wolf, target, _certain(_item(wolf, "Mordida")))
	assert_eq(wolf["hp"], 25, "não passa do máximo")
	wolf["hp"] = 10
	state.resolve_single_hit(wolf, target, _certain(_item(wolf, "Mordida"), -5.0))
	assert_eq(wolf["hp"], 10, "errou: sem cura")

# --- Bote Selvagem -------------------------------------------------------------------------

func test_pounce_needs_a_clear_straight_path() -> void:
	var wolf := _wolf(2, 5)
	_unit("alvo", 5, 5)
	var pounce := _item(wolf, "Bote Selvagem")
	assert_true(state.compute_charge_targets(wolf, pounce).has({"x": 5, "y": 5}))
	_unit("longe", 2, 9)
	assert_false(state.compute_charge_targets(wolf, pounce).has({"x": 2, "y": 9}), "além de 3 casas")
	state.terrain_map[state.tile_key(3, 5)] = {"type": "scenery-prop"}
	assert_false(state.compute_charge_targets(wolf, pounce).has({"x": 5, "y": 5}), "obstáculo no caminho")

func test_pounce_lands_adjacent_and_roots_until_the_wolfs_next_turn() -> void:
	var wolf := _wolf(2, 5)
	var target := _unit("alvo", 5, 5)
	var bystander := _unit("outro", 10, 10, "enemy")
	assert_true(state.cast_charge(wolf, target, _certain(_item(wolf, "Bote Selvagem"))))
	assert_eq([wolf["x"], wolf["y"]], [4, 5], "pára na casa livre ao lado do alvo")
	assert_lt(int(target["hp"]), 100)
	assert_true(state.is_rooted(target))
	state.apply_status_effects_at_turn_end(target)
	state.apply_status_effects_at_turn_end(target)
	assert_true(state.is_rooted(target), "a contagem do alvo não encerra o efeito")
	state.begin_turn_for(target)
	assert_true(state.is_rooted(target), "no turno do alvo continua imobilizado")
	assert_true(state.compute_reachable(target).is_empty() or state.is_rooted(target), "imobilizado: não se move")
	state.begin_turn_for(bystander)
	assert_true(state.is_rooted(target))
	state.begin_turn_for(wolf)
	assert_false(state.is_rooted(target), "expira no início do próximo turno do Lobo")

func test_pounce_on_adjacent_target_stays_in_place() -> void:
	var wolf := _wolf(2, 5)
	var target := _unit("alvo", 3, 5)
	assert_true(state.cast_charge(wolf, target, _certain(_item(wolf, "Bote Selvagem"))))
	assert_eq([wolf["x"], wolf["y"]], [2, 5])
	assert_true(state.is_rooted(target))

func test_pounce_and_rend_do_not_give_the_wolf_an_endless_turn() -> void:
	var wolf := _wolf(2, 5)
	var target := _unit("alvo", 5, 5)
	wolf["ct"] = 100
	state.cast_charge(wolf, target, _certain(_item(wolf, "Bote Selvagem")))
	assert_lt(int(wolf["ct"]), GameConstants.CT_THRESHOLD, "Bote consome CT")

# --- Dilacerar -----------------------------------------------------------------------------

func test_rend_bleeds_2_per_turn_for_2_turns_and_refreshes() -> void:
	var wolf := _wolf()
	var target := _unit("alvo", 3, 5)
	state.resolve_single_hit(wolf, target, _certain(_item(wolf, "Dilacerar")))
	var hp_after_hit := int(target["hp"])
	assert_between(100 - hp_after_hit, 5, 11)
	assert_eq(_status(target, "bleed").size(), 1)
	state.apply_status_effects_at_turn_end(target)
	assert_eq(int(target["hp"]), hp_after_hit - 2)
	state.resolve_single_hit(wolf, target, _certain(_item(wolf, "Dilacerar")))
	assert_eq(_status(target, "bleed").size(), 1, "não acumula")
	assert_eq(_status(target, "bleed")[0]["turnsLeft"], 2, "renova a duração")

# --- Uivo de Caça ---------------------------------------------------------------------------

func test_howl_buffs_every_living_ally_on_the_board_once() -> void:
	var wolf := _wolf(2, 5)
	var far_ally := _unit("aliado", 12, 12, "enemy", {"speed": 9})
	var dead_ally := _unit("morto", 11, 0, "enemy", {"hp": 0, "speed": 9})
	var foe := _unit("inimigo", 3, 5, "player", {"speed": 9})
	var howl := _item(wolf, "Uivo de Caça")
	state.cast_hunt_howl(wolf, howl)
	assert_eq(wolf["speed"], 15, "o próprio Lobo")
	assert_eq(far_ally["speed"], 11, "sem limite de distância")
	assert_eq(dead_ally["speed"], 9, "só aliados vivos")
	assert_eq(foe["speed"], 9, "inimigos não")
	assert_eq(state.hunt_howl_events.size(), 1, "evento visual/sonoro do uivo")
	state.cast_hunt_howl(wolf, howl)
	assert_eq(far_ally["speed"], 11, "não acumula")
	assert_eq(_status(far_ally, "huntHowl")[0]["turnsLeft"], 2, "renova")
	state.apply_status_effects_at_turn_start(far_ally)
	assert_eq(far_ally["speed"], 11)
	state.apply_status_effects_at_turn_start(far_ally)
	assert_eq(far_ally["speed"], 9, "expira em 2 turnos e restaura")

# --- Passivas -----------------------------------------------------------------------------------

func test_pack_instinct_adds_2_once_when_a_goblinoid_ally_is_next_to_the_target() -> void:
	var wolf := _wolf(2, 5)
	var target := _unit("alvo", 3, 5)
	state.resolve_single_hit(wolf, target, _fixed_hit(5))
	assert_eq(target["hp"], 95, "sem aliado: sem bônus")
	_template("goblin", 4, 5, {"name": "Goblin"})
	_template("kobold", 3, 6, {"name": "Kobold"})
	target["hp"] = 100
	state.resolve_single_hit(wolf, target, _fixed_hit(5))
	assert_eq(target["hp"], 93, "+2 uma única vez, mesmo com 2 aliados")
	target["hp"] = 100
	state.resolve_single_hit(wolf, target, _fixed_hit(5, {"mpCost": 1}))
	assert_eq(target["hp"], 95, "só dano físico")

func test_pack_instinct_ignores_non_goblinoids_and_enemies() -> void:
	var wolf := _wolf(2, 5)
	var target := _unit("alvo", 3, 5)
	_unit("humano", 4, 5, "enemy", {"spriteKey": "guerreiro"})
	_template("goblin", 3, 4, {"name": "Goblin inimigo", "team": "player"})
	state.resolve_single_hit(wolf, target, _fixed_hit(5))
	assert_eq(target["hp"], 95)

func test_bite_counter_only_on_melee_hits_and_never_chains() -> void:
	var wolf := _wolf(2, 5, {"counterAttackChance": 1.0})
	wolf["counterWeapon"] = _certain(wolf["counterWeapon"])
	var attacker := _unit("atacante", 3, 5, "player", {"counterAttackChance": 1.0, "counterWeapon": _fixed_hit(1)})
	state.resolve_single_hit(attacker, wolf, _fixed_hit(3))
	assert_lt(int(attacker["hp"]), 100, "revida o golpe corpo a corpo com uma Mordida")
	var counters := state.event_log.filter(func(line): return "revida" in String(line)).size()
	assert_eq(counters, 1, "o revide não gera outro revide")
	attacker["hp"] = 100
	state.resolve_single_hit(attacker, wolf, _fixed_hit(3, {"hitChance": -5.0}))
	assert_eq(attacker["hp"], 100, "golpe que erra não dispara revide")
	var archer := _unit("arqueiro", 2, 3)
	state.resolve_single_hit(archer, wolf, _fixed_hit(3, {"minRange": 1, "maxRange": 4}))
	assert_eq(archer["hp"], 100, "ataque à distância não dispara a Mordida")

func test_bite_counter_needs_a_living_attacker() -> void:
	var wolf := _wolf(2, 5, {"counterAttackChance": 1.0})
	var attacker := _unit("atacante", 3, 5, "player", {"hp": 0})
	state.resolve_single_hit(attacker, wolf, _fixed_hit(3))
	assert_eq(attacker["hp"], 0)

# --- Montaria -----------------------------------------------------------------------------------

func test_only_one_tile_goblinoids_can_mount_the_wolf() -> void:
	var wolf := _wolf(5, 5)
	for key in ["goblin", "kobold", "orc", "xama", "fada"]:
		var rider := _template(key, 4, 5, {"name": "cavaleiro_" + key})
		assert_true(state.can_mount(rider, wolf), "%s pode montar" % key)
		state.units.erase(rider)
	for key in ["troll", "troncus"]:
		var big := _template(key, 3, 5, {"name": "grande_" + key})
		assert_false(state.can_mount(big, wolf), "%s (2x2) não pode" % key)
		state.units.erase(big)
	var hero := _template("guerreiro", 4, 5, {"team": "enemy"})
	assert_false(state.can_mount(hero, wolf), "outra categoria não pode")
	state.units.erase(hero)
	var other_wolf := _wolf(4, 5, {"name": "Lobo 2"})
	assert_false(state.can_mount(other_wolf, wolf), "montaria não monta montaria")
	var vestruz := _template("vestruz", 8, 8)
	var warrior := _template("guerreiro", 8, 7, {"name": "Guerreiro 2"})
	assert_true(state.can_mount(warrior, vestruz), "a Vestruz continua aceitando heróis")

func test_mounted_goblin_rides_on_top_and_follows_the_wolf() -> void:
	var wolf := _wolf(5, 5)
	var goblin := _template("goblin", 4, 5, {"name": "Goblin"})
	assert_true(state.mount_unit(goblin, wolf))
	assert_eq([goblin["x"], goblin["y"]], [5, 5])
	assert_true(goblin.get("ridingOverlay", false), "desenhado por cima do lobo")
	wolf["facing"] = {"dx": 0, "dy": 1}
	state.push_unit(wolf, 1, 0, 1)
	assert_eq([goblin["x"], goblin["y"]], [6, 5], "acompanha a montaria")
	assert_eq(goblin["facing"], {"dx": 0, "dy": 1}, "mesma direção da montaria")
	assert_true(state.dismount_unit(goblin, {"x": 6, "y": 6}))
	assert_false(goblin.get("ridingOverlay", false))

func test_every_small_goblinoid_has_wolf_mounted_art_in_four_directions() -> void:
	for rider in ["goblin", "kobold", "orc", "xama", "fada"]:
		for dir in ["down", "up", "left", "right"]:
			assert_ne(UnitToken.mounted_art_path(rider, "lobo", dir), "", "%s montado no lobo (%s)" % [rider, dir])
	assert_eq(UnitToken.mounted_art_path("guerreiro", "lobo", "down"), "", "sem arte: cai no desenho do cavaleiro por cima")
	assert_eq(UnitToken.mounted_art_path("goblin", "vestruz", "down"), "", "arte do lobo não vaza pra Vestruz")
	assert_ne(UnitToken.mounted_art_path("guerreiro", "vestruz", "down"), "", "Vestruz continua com a arte dos heróis")
