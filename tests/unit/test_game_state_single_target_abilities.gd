extends GutTest

## Fase 3 (alvo único): porte de resolveHeal/resolveRegen/resolveManaRestore/
## castSupplyItem/castResurrect/castRootSpell e da geometria de mira
## bresenhamLine/hasLineOfSight/resolveObstructedTarget (game.js:4406-4462,
## 7778-8008, 8459-8485).

var state: GameState

func before_each() -> void:
	state = GameState.new()
	state.clear_units()
	state.clear_terrain_and_structures()

func _spell(overrides: Dictionary) -> Dictionary:
	var s := {"name": "magia-teste", "ctCost": 50, "mpCost": 5, "hitChance": 1.0, "minRange": 1, "maxRange": 3}
	for k in overrides.keys():
		s[k] = overrides[k]
	return s

# --- geometria de mira --------------------------------------------------------

func test_bresenham_line_straight_horizontal() -> void:
	var path := state.bresenham_line(0, 0, 3, 0)
	assert_eq(path, [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}, {"x": 3, "y": 0}])

func test_bresenham_line_diagonal() -> void:
	var path := state.bresenham_line(0, 0, 2, 2)
	assert_eq(path, [{"x": 0, "y": 0}, {"x": 1, "y": 1}, {"x": 2, "y": 2}])

func test_has_line_of_sight_blocked_by_higher_ground_in_between() -> void:
	assert_true(state.has_line_of_sight(0, 0, 2, 0), "sem obstrução, linha livre")
	state.elevation_map[state.tile_key(1, 0)] = 3
	assert_false(state.has_line_of_sight(0, 0, 2, 0), "tile do meio mais alto que os dois lados bloqueia")

## Míssil Mágico do catálogo real: dano igual à Varinha de Míssil Mágico de
## referência sem upgrade (min=2+lvl, max=8+2*lvl com lvl=0 — ver
## WandOfMagicMissile.java) e mira que ignora bloqueio de elevação, igual o
## Arco (tooltipNote já prometia isso, mas a flag nunca tinha sido setada —
## na prática a magia era bloqueada por elevação apesar do texto).
func test_magic_missile_from_the_real_catalog_matches_the_reference_wand() -> void:
	var spells := Spells.build()
	var missile: Dictionary = spells["missile"]
	assert_eq(missile["damageMin"], 2)
	assert_eq(missile["damageMax"], 8)
	assert_true(missile.get("ignoresTerrainLineOfSight", false))
	var mage := state.spawn_unit("mage", {"x": 0, "y": 0})
	state.elevation_map[state.tile_key(1, 0)] = 3
	var set := {}
	for t in state.compute_range_tiles(mage, missile):
		set[state.tile_key(t["x"], t["y"])] = true
	assert_true(set.has(state.tile_key(2, 0)), "tile atrás do bloqueio de elevação continua mirável")

func test_resolve_obstructed_target_returns_final_tile_when_clear() -> void:
	var caster := state.spawn_unit("caster", {"x": 0, "y": 0})
	var impact := state.resolve_obstructed_target(caster, {"x": 3, "y": 0})
	assert_eq(impact, {"x": 3, "y": 0})

func test_resolve_obstructed_target_returns_first_occupant_in_the_way() -> void:
	var caster := state.spawn_unit("caster", {"x": 0, "y": 0})
	state.spawn_unit("blocker", {"x": 1, "y": 0, "hp": 10})
	var impact := state.resolve_obstructed_target(caster, {"x": 3, "y": 0})
	assert_eq(impact, {"x": 1, "y": 0})

# --- resolve_heal / resolve_regen / resolve_mana_restore --------------------

func test_resolve_heal_caps_at_max_hp_and_can_miss() -> void:
	var caster := state.spawn_unit("caster", {})
	var target := state.spawn_unit("target", {"hp": 18, "maxHp": 20})
	state.resolve_heal(caster, target, _spell({"healMin": 10, "healMax": 10}))
	assert_eq(target["hp"], 20)

	target["hp"] = 5
	state.resolve_heal(caster, target, _spell({"healMin": 10, "healMax": 10, "hitChance": 0.0}))
	assert_eq(target["hp"], 5, "hitChance 0 nunca acerta")

func test_resolve_regen_applies_status_instead_of_healing_now() -> void:
	var caster := state.spawn_unit("caster", {})
	var target := state.spawn_unit("target", {"hp": 5, "maxHp": 20, "statusEffects": []})
	state.resolve_regen(caster, target, _spell({"healMin": 2, "healMax": 4, "regenTurns": 3}))
	assert_eq(target["hp"], 5, "não cura na hora")
	var regen := (target["statusEffects"] as Array).filter(func(e): return e["type"] == "regen")
	assert_eq(regen.size(), 1)
	assert_eq(regen[0]["turnsLeft"], 3)

func test_resolve_mana_restore_caps_at_max_mp_and_ignores_unit_without_mp() -> void:
	var caster := state.spawn_unit("caster", {})
	var mage := state.spawn_unit("mage", {"mp": 8, "maxMp": 10})
	state.resolve_mana_restore(caster, mage, _spell({"manaMin": 5, "manaMax": 5}))
	assert_eq(mage["mp"], 10)

	var brute := state.spawn_unit("brute", {})
	brute.erase("maxMp")
	brute.erase("mp")
	state.resolve_mana_restore(caster, brute, _spell({"manaMin": 5, "manaMax": 5}))
	assert_false(brute.has("maxMp"), "unidade sem maxMp não é afetada pela poção")
	assert_false(brute.has("mp"), "mp não é criado do nada")

# --- cast_supply_item ----------------------------------------------------------

func test_cast_supply_item_heals_the_intended_target_when_path_is_clear() -> void:
	var chemist := state.spawn_unit("chemist", {"x": 0, "y": 0, "ct": 100, "mp": 20})
	var ally := state.spawn_unit("ally", {"x": 3, "y": 0, "hp": 10, "maxHp": 20})
	state.cast_supply_item(chemist, ally, _spell({"healMin": 5, "healMax": 5}))
	assert_eq(ally["hp"], 15)
	assert_true(chemist["hasActed"])

func test_cast_supply_item_hits_whoever_blocks_the_path_instead() -> void:
	var chemist := state.spawn_unit("chemist", {"x": 0, "y": 0, "ct": 100, "mp": 20})
	var ally := state.spawn_unit("ally", {"x": 3, "y": 0, "hp": 10, "maxHp": 20})
	var blocker := state.spawn_unit("blocker", {"x": 1, "y": 0, "hp": 10, "maxHp": 20})
	state.cast_supply_item(chemist, ally, _spell({"healMin": 5, "healMax": 5}))
	assert_eq(blocker["hp"], 15, "quem bloqueou o caminho é afetado no lugar")
	assert_eq(ally["hp"], 10, "alvo pretendido não foi alcançado")

func test_cast_supply_item_mana_variant_uses_resolve_mana_restore() -> void:
	var chemist := state.spawn_unit("chemist", {"x": 0, "y": 0, "ct": 100, "mp": 20})
	var mage := state.spawn_unit("mage", {"x": 2, "y": 0, "mp": 5, "maxMp": 20})
	state.cast_supply_item(chemist, mage, _spell({"manaMin": 5, "manaMax": 5}))
	assert_eq(mage["mp"], 10)

# --- cast_resurrect -------------------------------------------------------------

func test_cast_resurrect_revives_with_half_max_hp_zero_ct_and_clears_status() -> void:
	var caster := state.spawn_unit("caster", {"x": 0, "y": 0, "ct": 100, "mp": 20})
	var corpse := state.spawn_unit("corpse", {"x": 1, "y": 0, "hp": 0, "maxHp": 40, "ct": 50, "speed": 10, "moveRange": 4, "turnsSinceDeath": 1, "statusEffects": [{"type": "weakened", "turnsLeft": 2, "moveReduction": 1}]})
	state.cast_resurrect(caster, corpse, _spell({"hitChance": 1.0}))
	assert_eq(corpse["hp"], 20)
	assert_eq(corpse["ct"], 0)
	assert_false(corpse.has("turnsSinceDeath"))
	assert_true((corpse["statusEffects"] as Array).is_empty())
	assert_eq(corpse["moveRange"], 5, "weakened devolve o moveReduction antes de zerar status effects")

func test_cast_resurrect_undoes_fury_speed_bonus_before_clearing() -> void:
	var caster := state.spawn_unit("caster", {"ct": 100, "mp": 20})
	var corpse := state.spawn_unit("corpse", {"hp": 0, "maxHp": 20, "speed": 14, "statusEffects": [{"type": "fury", "speedBonus": 4, "turnsLeft": 2}]})
	state.cast_resurrect(caster, corpse, _spell({"hitChance": 1.0}))
	assert_eq(corpse["speed"], 10)

func test_cast_resurrect_failed_roll_keeps_target_dead_but_still_finalizes() -> void:
	var caster := state.spawn_unit("caster", {"ct": 100, "mp": 20, "hasActed": false})
	var corpse := state.spawn_unit("corpse", {"hp": 0, "maxHp": 20, "turnsSinceDeath": 1})
	state.cast_resurrect(caster, corpse, _spell({"hitChance": 0.0}))
	assert_eq(corpse["hp"], 0)
	assert_true(corpse.has("turnsSinceDeath"), "falhou: continua morto, decayCorpses segue contando")
	assert_true(caster["hasActed"], "a tentativa ainda consome a ação")

# --- cast_root_spell -------------------------------------------------------------

func test_cast_root_spell_applies_root_status_on_hit() -> void:
	var caster := state.spawn_unit("caster", {"x": 0, "y": 0, "ct": 100, "mp": 20})
	var target := state.spawn_unit("target", {"x": 1, "y": 0, "statusEffects": []})
	state.cast_root_spell(caster, target, _spell({"hitChance": 1.0, "damageMin": 1, "damageMax": 2, "turns": 2}))
	assert_true(state.is_rooted(target))

func test_cast_root_spell_blocked_by_invisibility() -> void:
	var caster := state.spawn_unit("caster", {"x": 0, "y": 0, "ct": 100, "mp": 20})
	var target := state.spawn_unit("target", {"x": 1, "y": 0, "statusEffects": [{"type": "invisible", "turnsLeft": 2}]})
	state.cast_root_spell(caster, target, _spell({"hitChance": 1.0, "damageMin": 1, "damageMax": 2, "turns": 2, "targetMode": "root"}))
	assert_false(state.is_rooted(target))
