extends GutTest

## Dragão Vermelho: novo inimigo (pedido do usuário). Cobre stats, Garra
## (sangramento), Cauda (empurrão de golpe direto via campo genérico
## `knockback` + appliesCtDrain, ambos já existentes/generalizados em
## resolve_single_hit), Cone de Fogo (idêntico ao da Lava Humana) e
## afinidade elemental (imune a fogo/Queimando, fraqueza ×2 a gelo).

var state: GameState

func before_each() -> void:
	state = GameState.new()
	state.clear_units()
	state.clear_terrain_and_structures()

func _certain(item: Dictionary) -> Dictionary:
	var copy: Dictionary = item.duplicate(true)
	copy["hitChance"] = 1.0
	copy["critChance"] = 0.0
	return copy

func _dragon(overrides: Dictionary = {}) -> Dictionary:
	var data := GameState.dungeon_monster_data("dragon", 1, {"x": 5, "y": 5})
	for k in overrides.keys():
		data[k] = overrides[k]
	return state.spawn_unit(String(data["name"]), data)

func test_stats_match_spec() -> void:
	var data := GameState.dungeon_monster_data("dragon")
	assert_eq(data["maxHp"], 100, "pedido do usuário: ajustado de 50 para 100")
	assert_eq(data["maxMp"], 10)
	assert_eq(data["speed"], 9)
	assert_eq(data["moveRange"], 4)

# --- Garra -----------------------------------------------------------------

func test_claw_deals_5_to_10_costs_50_ct_15_percent_crit_and_bleeds() -> void:
	var dragon := _dragon()
	var claw: Dictionary = dragon["weapons"][0]
	assert_eq(claw["name"], "Garra")
	assert_eq(claw["damageMin"], 5)
	assert_eq(claw["damageMax"], 10)
	assert_eq(claw["ctCost"], 50)
	assert_almost_eq(claw["critChance"], 0.15, 0.001)
	assert_almost_eq(claw["hitChance"], 0.8, 0.001)
	var target := state.spawn_unit("alvo", {"x": 6, "y": 5, "hp": 30, "maxHp": 30, "team": "player", "statusEffects": []})
	state.resolve_single_hit(dragon, target, _certain(claw))
	var has_bleed := false
	for e in target["statusEffects"]:
		if e["type"] == "bleed": has_bleed = true
	assert_true(has_bleed)

# --- Cauda -------------------------------------------------------------------

func test_tail_deals_4_to_8_costs_60_ct_15_percent_crit() -> void:
	var dragon := _dragon()
	var tail: Dictionary = dragon["weapons"][1]
	assert_eq(tail["name"], "Cauda")
	assert_eq(tail["damageMin"], 4)
	assert_eq(tail["damageMax"], 8)
	assert_eq(tail["ctCost"], 60)
	assert_almost_eq(tail["critChance"], 0.15, 0.001)

func test_tail_pushes_2_tiles_when_the_path_is_clear() -> void:
	var dragon := _dragon({"x": 5, "y": 5})
	var target := state.spawn_unit("alvo", {"x": 6, "y": 5, "hp": 30, "maxHp": 30, "team": "player", "ct": 80})
	state.resolve_single_hit(dragon, target, _certain(dragon["weapons"][1]))
	assert_eq([target["x"], target["y"]], [8, 5])
	assert_eq(target["ct"], 50, "-30 CT mesmo empurrando")

func test_tail_pushes_only_1_tile_when_only_1_tile_is_free() -> void:
	var dragon := _dragon({"x": 5, "y": 5})
	var target := state.spawn_unit("alvo", {"x": 6, "y": 5, "hp": 30, "maxHp": 30, "team": "player", "ct": 80})
	state.spawn_unit("bloqueador", {"x": 8, "y": 5, "hp": 10, "maxHp": 10, "team": "player"})
	state.resolve_single_hit(dragon, target, _certain(dragon["weapons"][1]))
	assert_eq([target["x"], target["y"]], [7, 5])
	assert_eq(target["ct"], 50)

func test_tail_does_not_push_when_blocked_but_still_deals_damage_and_ct_drain() -> void:
	var dragon := _dragon({"x": 5, "y": 5})
	var item := _certain(dragon["weapons"][1])
	item["damageMin"] = 5; item["damageMax"] = 5
	var target := state.spawn_unit("alvo", {"x": 6, "y": 5, "hp": 30, "maxHp": 30, "team": "player", "ct": 80})
	state.spawn_unit("bloqueador", {"x": 7, "y": 5, "hp": 10, "maxHp": 10, "team": "player"})
	state.resolve_single_hit(dragon, target, item)
	assert_eq([target["x"], target["y"]], [6, 5], "sem espaço: não empurra")
	assert_eq(target["hp"], 25, "dano continua valendo")
	assert_eq(target["ct"], 50, "-30 CT continua valendo")

# --- Cone de Fogo (= Lava Humana) --------------------------------------------

func test_fire_cone_is_identical_to_the_lava_humans_ability() -> void:
	var dragon := _dragon()
	var lava_human: Dictionary = GameState.dungeon_monster_data("lava_human")
	var lava_cone: Dictionary = (lava_human["spells"] as Array).filter(func(s): return s["name"] == "Cone de Fogo")[0]
	var dragon_cone: Dictionary = dragon["spells"][0]
	assert_eq(dragon_cone["damageMin"], lava_cone["damageMin"])
	assert_eq(dragon_cone["damageMax"], lava_cone["damageMax"])
	assert_eq(dragon_cone["ctCost"], lava_cone["ctCost"])
	assert_eq(dragon_cone["mpCost"], lava_cone["mpCost"])
	assert_eq(dragon_cone["maxRange"], lava_cone["maxRange"])
	assert_eq(dragon_cone["hitChance"], lava_cone["hitChance"])
	assert_eq(dragon_cone["appliesBurn"], lava_cone["appliesBurn"])

# --- afinidade elemental: imune a fogo/Queimando, fraqueza a gelo -----------

func test_fire_damage_and_burn_are_fully_ignored() -> void:
	var dragon := _dragon({"hp": 50, "maxHp": 50})
	var fire_item := _certain({"name": "fogo-teste", "damageMin": 10, "damageMax": 10, "critMultiplier": 1, "maxRange": 1, "damageType": "fire", "appliesBurn": {"damageMin": 2, "damageMax": 4, "turns": 3}})
	var caster := state.spawn_unit("atacante", {"x": 5, "y": 6, "team": "player", "statusEffects": []})
	dragon["statusEffects"] = []
	state.resolve_single_hit(caster, dragon, fire_item)
	assert_eq(dragon["hp"], 50, "0 de dano")
	for e in dragon["statusEffects"]:
		assert_ne(e["type"], "burned", "Queimando não é aplicado")

func test_ice_damage_is_doubled() -> void:
	var dragon := _dragon({"hp": 50, "maxHp": 50})
	var ice_item := _certain({"name": "gelo-teste", "damageMin": 7, "damageMax": 7, "critMultiplier": 1, "maxRange": 1, "damageType": "ice"})
	var caster := state.spawn_unit("atacante", {"x": 5, "y": 6, "team": "player"})
	state.resolve_single_hit(caster, dragon, ice_item)
	assert_eq(dragon["hp"], 36, "7 de gelo vira 14 (50-14=36)")

func test_physical_damage_is_normal() -> void:
	var dragon := _dragon({"hp": 50, "maxHp": 50})
	var phys_item := _certain({"name": "fisico-teste", "damageMin": 7, "damageMax": 7, "critMultiplier": 1, "maxRange": 1, "damageType": "physical"})
	var caster := state.spawn_unit("atacante", {"x": 5, "y": 6, "team": "player"})
	state.resolve_single_hit(caster, dragon, phys_item)
	assert_eq(dragon["hp"], 43)
