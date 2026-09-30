extends GutTest

## Kobold (pedido do usuário): Goblinoide 1x1 com Adaga Envenenada/Lança,
## metade das habilidades do Goblin e as passivas Escamas Protetoras (-1 em
## dano físico, mínimo 1) e Sangue Dracônico (-25% de dano de fogo).

# Pés Ágeis foi transferida e depois devolvida ao Goblin (pedido do usuário);
# Emboscada Goblin foi renomeada para Emboscada Kobold.
const TRANSFERRED := ["Golpe Baixo", "Poção Venenosa", "Bater e Correr", "Emboscada Kobold"]
const KEPT_BY_GOBLIN := ["Agilidade", "Pés Ágeis", "Evasiva", "Areia nos Olhos", "Barril Roubado", "Fingir de Morto"]

var state: GameState

func before_each() -> void:
	state = GameState.new()
	state.clear_units()
	state.clear_terrain_and_structures()
	state.scenario_id = ScenarioManager.TOWER

func _kobold(x: int = 5, y: int = 5) -> Dictionary:
	var data: Dictionary = (Units.build()["kobold"] as Dictionary).duplicate(true)
	data["x"] = x
	data["y"] = y
	return state.spawn_unit("Kobold", data)

func _hero(x: int, y: int, team: String = "player") -> Dictionary:
	return state.spawn_unit("alvo_%d_%d" % [x, y], {"x": x, "y": y, "hp": 100, "maxHp": 100, "team": team, "statusEffects": []})

func _names(items: Array) -> Array:
	return items.map(func(i): return i["name"])

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

func _has_poison(u: Dictionary) -> bool:
	return (u["statusEffects"] as Array).any(func(e): return e["type"] == "poison")

# --- Cadastro -------------------------------------------------------------------

func test_kobold_stats_and_team() -> void:
	var k: Dictionary = Units.build()["kobold"]
	assert_eq(k["name"], "Kobold")
	assert_eq(k["team"], "enemy")
	assert_eq([k["maxHp"], k["hp"], k["maxMp"], k["mp"], k["speed"], k["moveRange"]], [20, 20, 10, 10, 12, 4])
	assert_false(state.is_large_unit(k), "ocupa 1x1")
	assert_true(PvpSetup.MONSTER_GROUPS["goblinoides"]["monsters"].has("kobold"), "aparece na seleção dos Goblinoides")
	assert_true(Units.enemy_team_keys().has("kobold"))

func test_kobold_joins_the_goblinoid_pvp_side() -> void:
	state.apply_pvp_scenario(ScenarioManager.definition(ScenarioManager.FIELD), ["guerreiro"], ["goblin", "kobold"])
	var kobold = state.units.filter(func(u): return u.get("spriteKey", "") == "kobold")
	assert_eq(kobold.size(), 1)
	assert_eq(kobold[0]["team"], "enemy")
	assert_eq(kobold[0]["maxHp"], 20)

func test_kobold_has_sprites_and_portrait() -> void:
	var spec := AnimalSpriteCatalog.spec("kobold")
	for action in ["walk_down", "walk_up", "walk_left", "walk_right"]:
		assert_eq((spec["anims"][action][0] as Array).size(), 2, "%s alterna 2 quadros" % action)
	for action in ["attack", "hit", "death", "walk_down", "walk_up", "walk_left", "walk_right"]:
		for path in spec["anims"][action][0]:
			assert_true(ResourceLoader.exists(path), path)
	assert_eq((spec["anims"]["attack"][0] as Array).size(), 2, "preparação + execução")
	assert_true(ResourceLoader.exists(spec["portrait"]))

# --- Ataques básicos --------------------------------------------------------------

func test_basic_attacks_match_spec() -> void:
	var k := _kobold()
	assert_eq(_names(k["weapons"]), ["Adaga Envenenada", "Lança"])
	var dagger := _item(k, "Adaga Envenenada")
	var spear := _item(k, "Lança")
	var blowgun: Dictionary = Units.build()["xama"]["weapons"][0]
	for w in [dagger, spear]:
		assert_eq([w["damageMin"], w["damageMax"], w["critChance"]], [3, 6, 0.15])
		assert_false(w.has("mpCost"), "%s não custa MP" % w["name"])
	assert_eq(dagger["hitChance"], 0.9)
	assert_eq(spear["hitChance"], 0.8)
	var goblin_dagger: Dictionary = Weapons.build()["dagger"]
	assert_eq([dagger["minRange"], dagger["maxRange"]], [goblin_dagger["minRange"], goblin_dagger["maxRange"]], "alcance de adaga")
	assert_eq([spear["minRange"], spear["maxRange"], spear["requiresClearPath"]], [blowgun["minRange"], blowgun["maxRange"], blowgun["requiresClearPath"]], "mesmo alcance/linha limpa da Zarabatana")
	assert_eq(dagger["appliesPoison"], blowgun["appliesPoison"], "mesmo Envenenado já existente")

func test_poisoned_dagger_poisons_only_on_hit() -> void:
	var k := _kobold()
	var target := _hero(6, 5)
	assert_false(state.resolve_single_hit(k, target, _certain(_item(k, "Adaga Envenenada"), -5.0)))
	assert_eq(target["hp"], 100, "erro causa 0 de dano")
	assert_false(_has_poison(target), "erro não envenena")
	assert_true(state.resolve_single_hit(k, target, _certain(_item(k, "Adaga Envenenada"))))
	assert_lt(int(target["hp"]), 100)
	assert_true(_has_poison(target), "acerto envenena")
	var turns: int = target["statusEffects"].filter(func(e): return e["type"] == "poison")[0]["turnsLeft"]
	state.resolve_single_hit(k, target, _certain(_item(k, "Adaga Envenenada")))
	assert_eq(target["statusEffects"].filter(func(e): return e["type"] == "poison")[0]["turnsLeft"], turns * 2, "reaplicação soma turnos, como o veneno existente")

func test_spear_is_a_ranged_attack_blocked_like_the_blowgun() -> void:
	var k := _kobold(2, 5)
	var target := _hero(5, 5)
	var spear := _certain(_item(k, "Lança"))
	assert_true(state.compute_range_tiles(k, spear).has({"x": 5, "y": 5}))
	var blocker := _hero(3, 5)
	state.perform_ranged_attack_with_obstruction(k, target, spear)
	assert_lt(int(blocker["hp"]), 100, "quem está no caminho leva o golpe")
	assert_eq(target["hp"], 100)

# --- Habilidades transferidas ---------------------------------------------------------

func test_half_of_goblin_skills_moved_to_kobold() -> void:
	var goblin: Dictionary = Units.build()["goblin"]
	var kobold: Dictionary = Units.build()["kobold"]
	assert_eq(_names(kobold["spells"]), TRANSFERRED)
	assert_eq(_names(goblin["spells"]), KEPT_BY_GOBLIN)
	for s in kobold["spells"]:
		assert_false(_names(goblin["spells"]).has(s["name"]), "%s saiu do Goblin" % s["name"])
	var catalog := Spells.build()
	for key in ["lowBlow", "poisonPotion", "hitAndRun", "goblinAmbush"]:
		var original: Dictionary = catalog[key]
		var moved: Dictionary = kobold["spells"].filter(func(s): return s["name"] == original["name"])[0]
		for field in ["kind", "mpCost", "ctCost", "targetMode", "damageBonus", "critBonus", "sfx"]:
			assert_eq(moved.get(field), original.get(field), "%s.%s preservado" % [original["name"], field])

func test_poison_potion_and_low_blow_work_with_kobold_weapons() -> void:
	var k := _kobold()
	var target := _hero(6, 5)
	k["mp"] = 10
	state.cast_self_ability(k, _item(k, "Golpe Baixo"))
	state.resolve_single_hit(k, target, _certain(_item(k, "Lança")))
	assert_true((target["statusEffects"] as Array).any(func(e): return e["type"] == "accuracyPenalty"), "Golpe Baixo aplica -20% de acerto")
	var other := _hero(5, 6)
	k["hasActed"] = false
	state.cast_self_ability(k, _item(k, "Poção Venenosa"))
	state.resolve_single_hit(k, other, _certain(_item(k, "Lança")))
	assert_true(_has_poison(other), "Poção Venenosa envenena pela Lança")

func test_ambush_works_for_kobold_and_swift_feet_is_back_with_goblin() -> void:
	var k := _kobold()
	assert_false(_names(k["spells"]).has("Pés Ágeis"))
	assert_true(_names(Units.build()["goblin"]["spells"]).has("Pés Ágeis"))
	var k2 := state.spawn_unit("Kobold 2", DataUtil.merge((Units.build()["kobold"] as Dictionary).duplicate(true), {"x": 1, "y": 1}))
	state.cast_self_ability(k2, _item(k2, "Emboscada Kobold"))
	assert_eq(k2.get("oneShotDamageBonus", 0), 2, "Emboscada: +2 no próximo ataque")

# --- Passivas -------------------------------------------------------------------------

func test_protective_scales_reduce_physical_hits_by_one_with_minimum_one() -> void:
	var attacker := _hero(4, 5)
	var k := _kobold()
	state.resolve_single_hit(attacker, k, _fixed_hit(5))
	assert_eq(k["hp"], 16, "5 físico -> 4")
	state.resolve_single_hit(attacker, k, _fixed_hit(1))
	assert_eq(k["hp"], 15, "1 físico continua 1")
	state.resolve_single_hit(attacker, k, _fixed_hit(5, {"hitChance": -5.0}))
	assert_eq(k["hp"], 15, "erro continua 0")

func test_protective_scales_ignore_magic_and_status_damage() -> void:
	var attacker := _hero(4, 5)
	var k := _kobold()
	state.resolve_single_hit(attacker, k, _fixed_hit(5, {"mpCost": 3}))
	assert_eq(k["hp"], 15, "dano mágico não é reduzido")
	k["hp"] = 20
	state.add_status_effect(k, {"type": "poison", "damageMin": 2, "damageMax": 2, "turnsLeft": 2})
	state.apply_status_effects_at_turn_end(k)
	assert_eq(k["hp"], 18, "dano por turno de status não é reduzido")

func test_draconic_blood_reduces_fire_by_25_percent() -> void:
	var attacker := _hero(4, 5)
	var k := _kobold()
	state.resolve_single_hit(attacker, k, _fixed_hit(8, {"damageType": "fire"}))
	assert_eq(k["hp"], 14, "8 de fogo -> 6 (sem Escamas: não é físico)")
	k["hp"] = 20
	state.resolve_single_hit(attacker, k, _fixed_hit(6, {"damageType": "fire"}))
	assert_eq(k["hp"], 15, "6 de fogo -> round(4.5) = 5, mesmo arredondamento das afinidades")

func test_physical_and_fire_hit_applies_both_passives_in_order() -> void:
	var attacker := _hero(4, 5)
	var k := _kobold()
	# Disparo físico que conta como fogo (mesmo mecanismo do Tiro Explosivo).
	attacker["burnNextAttackTurns"] = 1
	state.resolve_single_hit(attacker, k, _fixed_hit(8))
	assert_eq(k["hp"], 15, "8 -> Escamas 7 -> ×0.75 = round(5.25) = 5")

func test_passives_are_listed_by_name() -> void:
	var k: Dictionary = Units.build()["kobold"]
	assert_eq(_names(k["passives"]), ["Escamas Protetoras", "Sangue Dracônico"])
