extends GutTest

## Fase 3 (área/linha/cone): porte da geometria de mira (computeAoeAreaTiles/
## computeCardinalRectTiles/computeConeTilesForDir/computeRangeTiles),
## destruição de terreno/estrutura, e dos cast* de área (game.js:4182-4406,
## 4738-4870, 7876-7948, 8317-8578, 9097-9316).

var state: GameState

func before_each() -> void:
	state = GameState.new()
	state.clear_units()
	state.clear_terrain_and_structures()

func _spell(overrides: Dictionary) -> Dictionary:
	var s := {"name": "magia-teste", "ctCost": 60, "mpCost": 8, "hitChance": 1.0, "critChance": 0.0, "critMultiplier": 1, "minRange": 1, "maxRange": 6}
	for k in overrides.keys():
		s[k] = overrides[k]
	return s

func _tile_set(tiles: Array) -> Dictionary:
	var set := {}
	for t in tiles:
		set[state.tile_key(t["x"], t["y"])] = true
	return set

# --- geometria -----------------------------------------------------------------

func test_compute_cardinal_rect_tiles_forms_a_band_in_front_of_caster() -> void:
	var caster := {"x": 5, "y": 5}
	var tiles := state.compute_cardinal_rect_tiles(caster, {"x": 6, "y": 5}, 2, 3)
	var set := _tile_set(tiles)
	# direção +x, comprimento 2, largura 3 (offsets -1,0,1 no eixo y).
	assert_true(set.has(state.tile_key(6, 4)))
	assert_true(set.has(state.tile_key(6, 5)))
	assert_true(set.has(state.tile_key(6, 6)))
	assert_true(set.has(state.tile_key(7, 4)))
	assert_false(set.has(state.tile_key(5, 5)), "não inclui o próprio conjurador")
	assert_eq(tiles.size(), 6)

func test_compute_cone_tiles_for_dir_widens_with_depth() -> void:
	var tiles := state.compute_cone_tiles_for_dir({"x": 6, "y": 6}, 1, 0, 3)
	var set := _tile_set(tiles)
	assert_true(set.has(state.tile_key(7, 6)), "profundidade 1, largura 1")
	assert_true(set.has(state.tile_key(9, 6)) and set.has(state.tile_key(9, 5)) and set.has(state.tile_key(9, 7)), "profundidade 3, largura 3")
	assert_eq(tiles.size(), 1 + 3 + 5)

func test_compute_aoe_area_tiles_point_aoe_redirects_on_obstruction() -> void:
	var caster := state.spawn_unit("caster", {"x": 0, "y": 0})
	state.spawn_unit("blocker", {"x": 2, "y": 0, "hp": 10})
	var tiles: Array = state.compute_aoe_area_tiles(caster, _spell({"targetMode": "point-aoe", "areaRadius": 1}), {"x": 5, "y": 0})
	var set := _tile_set(tiles)
	assert_true(set.has(state.tile_key(2, 0)), "detona no bloqueador, não no alvo clicado")
	assert_false(set.has(state.tile_key(5, 0)))

func test_compute_aoe_area_tiles_cone_poison_picks_the_direction_containing_the_click() -> void:
	var caster := {"x": 6, "y": 6}
	var tiles = state.compute_aoe_area_tiles(caster, _spell({"targetMode": "cone-poison", "maxRange": 3}), {"x": 6, "y": 5})
	var set := _tile_set(tiles)
	assert_true(set.has(state.tile_key(6, 4)), "cone inteiro na direção -y, não só o tile clicado")
	assert_false(set.has(state.tile_key(7, 6)), "outra direção não faz parte")

func test_compute_range_tiles_extended_by_elevated_terrain_and_double_range_buff() -> void:
	var archer := state.spawn_unit("archer", {"x": 0, "y": 0})
	var bow := _spell({"minRange": 2, "maxRange": 5})
	var base_set := _tile_set(state.compute_range_tiles(archer, bow))
	assert_false(base_set.has(state.tile_key(6, 0)), "fora do alcance normal")

	state.terrain_map[state.tile_key(0, 0)] = {"type": "house"}
	var elevated_set := _tile_set(state.compute_range_tiles(archer, bow))
	assert_true(elevated_set.has(state.tile_key(6, 0)), "casa dá +1 de alcance")

	archer["doubleRangeNextAttack"] = true
	var doubled_set := _tile_set(state.compute_range_tiles(archer, bow))
	assert_true(doubled_set.has(state.tile_key(11, 0)), "Tiro Longo dobra o maxRange antes do +1 de elevação")
	assert_eq(bow["maxRange"], 5, "o item original nunca é mutado")

## Regressão: compute_range_tiles já dobrava o alcance certinho, mas
## main.gd::_select_attack_item ainda checava is_in_weapon_range com o item
## CRU pra decidir attackable_units — um alvo só alcançável com o Tiro Longo
## aparecia destacado (attack_range_tiles) só não ficava clicável. O motor
## agora expõe o mesmo item efetivo pra quem for montar a lista de alvos.
func test_effective_weapon_item_matches_what_compute_range_tiles_actually_uses() -> void:
	var archer := state.spawn_unit("archer", {"x": 0, "y": 0})
	var bow := _spell({"minRange": 2, "maxRange": 5})
	assert_eq(state.effective_weapon_item(archer, bow)["maxRange"], 5, "sem buff, item efetivo = item original")
	archer["doubleRangeNextAttack"] = true
	assert_eq(state.effective_weapon_item(archer, bow)["maxRange"], 10, "Tiro Longo dobra o maxRange efetivo")
	assert_eq(bow["maxRange"], 5, "o item original nunca é mutado")

## Tiro Penetrante do catálogo real (data/spells.gd) não tem mais um teto de
## alcance próprio — quem limita é a borda do tabuleiro, de qualquer
## posição/direção.
func test_pierce_shot_from_the_real_catalog_reaches_the_board_edge_in_every_cardinal_direction() -> void:
	var spells := Spells.build()
	var pierce: Dictionary = spells["pierceShot"]
	var archer := state.spawn_unit("archer", {"x": 6, "y": 6})
	var set := _tile_set(state.compute_line_target_tiles(archer, pierce, true))
	assert_true(set.has(state.tile_key(12, 6)), "alcança a borda direita")
	assert_true(set.has(state.tile_key(0, 6)), "alcança a borda esquerda")
	assert_true(set.has(state.tile_key(6, 12)), "alcança a borda inferior")
	assert_true(set.has(state.tile_key(6, 0)), "alcança a borda superior")
	assert_false(set.has(state.tile_key(7, 7)), "continua só nas 4 direções cardeais, nunca na diagonal")

## Bomba do catálogo real ignora bloqueio de linha de visão na hora de
## ESCOLHER o alvo (igual o Arco) — a lista de tiles clicáveis nunca teve
## esse gargalo.
func test_bomb_from_the_real_catalog_targets_any_tile_in_range_ignoring_los_blockers() -> void:
	var spells := Spells.build()
	var bomb: Dictionary = spells["bomb"]
	assert_true(bomb.get("ignoresTerrainLineOfSight", false))
	var chemist := state.spawn_unit("chemist", {"x": 0, "y": 0})
	# has_line_of_sight bloqueia por ELEVAÇÃO (elevation_at), não por tipo de
	# terreno — precisa mesmo de um degrau de elevação no meio do caminho pra
	# testar de verdade se ignoresTerrainLineOfSight está furando o bloqueio.
	state.elevation_map[state.tile_key(1, 0)] = 2
	var set := _tile_set(state.compute_range_tiles(chemist, bomb))
	assert_true(set.has(state.tile_key(3, 0)), "tile atrás do bloqueio de elevação continua selecionável")

## Diferente de Bola de Fogo/Explosão Sonora (mesmo resolvedor cast_fireball):
## a Bomba tem "ignoresUnitObstruction": true (pedido do usuário — ela é
## arremessada em arco, não um projétil reto) e por isso NUNCA detona antes
## do alvo por causa de alguém no meio do caminho, ao contrário das outras
## duas magias que reaproveitam o mesmo resolvedor.
func test_bomb_always_lands_on_the_clicked_tile_even_with_a_unit_in_the_way() -> void:
	var spells := Spells.build()
	var bomb: Dictionary = spells["bomb"]
	assert_true(bomb.get("ignoresUnitObstruction", false))
	var chemist := state.spawn_unit("chemist", {"team": "player", "x": 0, "y": 6})
	var blocker := state.spawn_unit("blocker", {"team": "enemy", "x": 2, "y": 6, "hp": 20, "maxHp": 20})
	var far_target := state.spawn_unit("far_target", {"team": "enemy", "x": 4, "y": 6, "hp": 20, "maxHp": 20})
	state.cast_fireball(chemist, bomb, {"x": 4, "y": 6})
	assert_lt(far_target["hp"], 20, "estoura no quadrado mirado — quem está lá leva o dano")
	assert_eq(blocker["hp"], 20, "quem só está NO CAMINHO não é atingido — a Bomba não detona antes")

## Bola de Fogo/Explosão Sonora continuam detonando antes do alvo quando algo
## bloqueia o caminho (comportamento inalterado) — só a Bomba ganhou o
## comportamento novo acima.
func test_fireball_still_detonates_early_when_something_blocks_the_path() -> void:
	var spells := Spells.build()
	var fireball: Dictionary = spells["fireball"]
	assert_false(fireball.get("ignoresUnitObstruction", false))
	var mage := state.spawn_unit("mage", {"team": "player", "x": 0, "y": 6})
	var blocker := state.spawn_unit("blocker", {"team": "enemy", "x": 2, "y": 6, "hp": 20, "maxHp": 20})
	# Longe o bastante do bloqueio (distância 5) pra ficar FORA do raio 3 da
	# explosão mesmo se ela detonasse ali — só assim "hp inalterado" prova
	# que a Bola de Fogo nunca chegou lá, e não é coincidência de raio.
	var far_target := state.spawn_unit("far_target", {"team": "enemy", "x": 7, "y": 6, "hp": 20, "maxHp": 20})
	state.cast_fireball(mage, fireball, {"x": 7, "y": 6})
	assert_lt(blocker["hp"], 20, "detona no primeiro obstáculo do caminho")
	assert_eq(far_target["hp"], 20, "alvo original nunca chega a ser atingido")

## O anel de alcance (minRange..maxRange) da Bomba tem a mesma largura do
## Arco (2-5, ver weapons.gd:"bow") — o alcance original (2-3) era estreito
## demais pra mirar "em qualquer lugar" com folga tática, mesmo já sem
## bloqueio de linha de visão (ver teste acima).
## Pedido do usuário: Bomba de Gelo idêntica à Bomba (custo, dano, alcance,
## área, arremesso em arco sem obstrução), só trocando o efeito — reduz
## agilidade (igual ao Raio de Gelo) em vez de queimar.
func test_ice_bomb_is_identical_to_bomb_except_it_slows_instead_of_burning() -> void:
	var spells := Spells.build()
	var bomb: Dictionary = spells["bomb"]
	var ice_bomb: Dictionary = spells["iceBomb"]
	for key in ["ctCost", "mpCost", "damageMin", "damageMax", "minRange", "maxRange", "areaRadius", "hitChance", "targetMode", "projectileKind", "ignoresTerrainLineOfSight", "ignoresUnitObstruction"]:
		assert_eq(ice_bomb[key], bomb[key], "campo %s deveria ser igual ao da Bomba" % key)
	assert_eq(ice_bomb["damageType"], "ice")
	assert_false(ice_bomb.has("appliesBurn"))
	var chemist := state.spawn_unit("chemist", {"team": "player", "x": 0, "y": 6})
	var target := state.spawn_unit("target", {"team": "enemy", "x": 2, "y": 6, "hp": 20, "maxHp": 20, "moveRange": 4})
	state.cast_fireball(chemist, ice_bomb, {"x": 2, "y": 6})
	assert_lt(target["hp"], 20, "ainda causa o mesmo dano de impacto")
	assert_false(target["statusEffects"].any(func(e): return e["type"] == "burned"), "não deve queimar")
	assert_true(target["statusEffects"].any(func(e): return e["type"] == "slowed"), "deve reduzir agilidade, igual ao Raio de Gelo")
	assert_eq(target["moveRange"], 4, "Bomba de Gelo reduz agilidade (speed), não deslocamento")

func test_bomb_range_matches_the_bow_so_it_can_target_anywhere_within_reach() -> void:
	var spells := Spells.build()
	var weapons := Weapons.build()
	var bomb: Dictionary = spells["bomb"]
	var bow: Dictionary = weapons["bow"]
	assert_eq(bomb["minRange"], bow["minRange"])
	assert_eq(bomb["maxRange"], bow["maxRange"])
	var chemist := state.spawn_unit("chemist", {"x": 6, "y": 6})
	var set := _tile_set(state.compute_range_tiles(chemist, bomb))
	assert_true(set.has(state.tile_key(6, 8)), "distância mínima (2) segue mirável")
	assert_true(set.has(state.tile_key(6, 11)), "distância máxima (5) agora é mirável")
	assert_false(set.has(state.tile_key(6, 12)), "além do maxRange continua fora de alcance")

# --- destruição de terreno/estrutura --------------------------------------------

func test_damage_tree_destroys_into_rubble_and_drops_occupant() -> void:
	state.terrain_map[state.tile_key(3, 3)] = {"type": "tree", "hp": 2, "maxHp": 10}
	var perched := state.spawn_unit("perched", {"x": 3, "y": 3, "hp": 20})
	state.damage_tree(3, 3, 10, 10)
	assert_eq(state.terrain_map[state.tile_key(3, 3)]["type"], "stump")
	assert_eq(perched["hp"], 20 - GameConstants.FALL_DAMAGE)

func test_damage_structures_in_tiles_applies_area_multiplier_once_per_structure() -> void:
	state.structures = [{"type": "castle", "team": "player", "tiles": [{"x": 0, "y": 0}, {"x": 1, "y": 0}], "hp": 100, "maxHp": 100, "destroyed": false}]
	state.damage_structures_in_tiles([{"x": 0, "y": 0}, {"x": 1, "y": 0}], 5, 5)
	assert_eq(state.structures[0]["hp"], 100 - 5 * GameConstants.AREA_STRUCTURE_DAMAGE_MULTIPLIER, "só uma aplicação, mesmo com 2 tiles atingidos")

# --- cast_fireball ---------------------------------------------------------------

func test_cast_fireball_hits_everyone_in_radius_including_allies() -> void:
	var mage := state.spawn_unit("mage", {"x": 0, "y": 0, "team": "player", "ct": 100, "mp": 20})
	var ally := state.spawn_unit("ally", {"x": 1, "y": 0, "team": "player", "hp": 20, "maxHp": 20})
	var foe := state.spawn_unit("foe", {"x": 2, "y": 0, "team": "enemy", "hp": 20, "maxHp": 20})
	var fireball := _spell({"areaRadius": 3, "damageMin": 4, "damageMax": 4})
	state.cast_fireball(mage, fireball, {"x": 2, "y": 0})
	assert_eq(ally["hp"], 16, "explosão em área acerta o próprio time também")
	assert_eq(foe["hp"], 16)

func test_cast_fireball_detonates_early_when_something_blocks_the_path() -> void:
	var mage := state.spawn_unit("mage", {"x": 0, "y": 0, "team": "player", "ct": 100, "mp": 20})
	var blocker := state.spawn_unit("blocker", {"x": 1, "y": 0, "team": "enemy", "hp": 20, "maxHp": 20})
	var faraway := state.spawn_unit("faraway", {"x": 5, "y": 0, "team": "enemy", "hp": 20, "maxHp": 20})
	var fireball := _spell({"areaRadius": 1, "damageMin": 4, "damageMax": 4})
	state.cast_fireball(mage, fireball, {"x": 5, "y": 0})
	assert_eq(blocker["hp"], 16)
	assert_eq(faraway["hp"], 20, "longe demais do impacto redirecionado")

# --- cast_lightning --------------------------------------------------------------

func test_cast_lightning_hits_everyone_on_the_line_and_damages_trees() -> void:
	var caster := state.spawn_unit("caster", {"x": 0, "y": 0, "team": "player", "ct": 100, "mp": 20})
	var mid := state.spawn_unit("mid", {"x": 2, "y": 0, "team": "enemy", "hp": 20, "maxHp": 20})
	var far := state.spawn_unit("far", {"x": 4, "y": 0, "team": "enemy", "hp": 20, "maxHp": 20})
	state.terrain_map[state.tile_key(1, 0)] = {"type": "tree", "hp": 3, "maxHp": 10}
	var bolt := _spell({"maxRange": 12, "damageMin": 5, "damageMax": 5})
	state.cast_lightning(caster, bolt, {"x": 4, "y": 0})
	assert_eq(mid["hp"], 15)
	assert_eq(far["hp"], 15)
	assert_eq(state.terrain_map[state.tile_key(1, 0)]["type"], "stump", "árvore no caminho também toma dano em área")

# --- cast_freeze_aoe ---------------------------------------------------------------

func test_cast_freeze_aoe_paralyzes_hit_targets_including_invisible_ones() -> void:
	# freeze-aoe está em AOE_TARGET_MODES: magia de área "cobre o terreno" o
	# bastante pra achar quem está invisível (só arma/magia de alvo único
	# erra automaticamente nele — ver blocked_by_invisibility).
	var caster := state.spawn_unit("caster", {"x": 5, "y": 5, "team": "enemy", "ct": 100, "mp": 20})
	var visible := state.spawn_unit("visible", {"x": 5, "y": 6, "team": "player", "statusEffects": []})
	var hidden := state.spawn_unit("hidden", {"x": 6, "y": 5, "team": "player", "statusEffects": [{"type": "invisible", "turnsLeft": 2}]})
	var freeze := _spell({"targetMode": "freeze-aoe", "areaRadius": 1, "damageMin": 1, "damageMax": 1})
	state.cast_freeze_aoe(caster, freeze, {"x": 5, "y": 5})
	assert_true(state.is_paralyzed(visible))
	assert_true(state.is_paralyzed(hidden), "área bypassa invisibilidade")

# --- cast_windstorm ---------------------------------------------------------------

func test_cast_windstorm_pushes_hit_targets_away_from_caster() -> void:
	var caster := state.spawn_unit("caster", {"x": 5, "y": 5, "team": "enemy", "ct": 100, "mp": 20})
	var target := state.spawn_unit("target", {"x": 6, "y": 5, "team": "player", "hp": 30, "maxHp": 30})
	var cone := state.compute_cone_tiles_for_dir(caster, 1, 0, 5)
	var windstorm := _spell({"damageMin": 4, "damageMax": 4, "critMultiplier": 2})
	state.cast_windstorm(caster, windstorm, cone)
	assert_eq(target["hp"], 26)
	assert_true(target["x"] > 6, "empurrado pra longe do conjurador")

# --- cast_poison_cone ---------------------------------------------------------------

func test_cast_poison_cone_applies_poison_to_everyone_in_the_cone() -> void:
	var caster := state.spawn_unit("caster", {"x": 5, "y": 5, "team": "enemy", "ct": 100, "mp": 20})
	var ally := state.spawn_unit("ally", {"x": 5, "y": 4, "team": "enemy", "statusEffects": []})
	var foe := state.spawn_unit("foe", {"x": 5, "y": 3, "team": "player", "statusEffects": []})
	var cone := state.compute_cone_tiles_for_dir(caster, 0, -1, 5)
	var poison := _spell({"damageMin": 1, "damageMax": 3, "turns": 3})
	state.cast_poison_cone(caster, poison, cone)
	assert_true(state.is_poisoned(ally))
	assert_true(state.is_poisoned(foe))

# --- cast_creeping_destruction -----------------------------------------------------

func test_cast_creeping_destruction_drains_ct_and_roots_unconditionally() -> void:
	var caster := state.spawn_unit("caster", {"x": 0, "y": 0, "team": "enemy", "ct": 100, "mp": 20})
	var target := state.spawn_unit("target", {"x": 2, "y": 0, "team": "player", "ct": 20, "statusEffects": []})
	var spell := _spell({"targetMode": "creeping-line", "bandLength": GameConstants.BOARD_SIZE, "bandWidth": 3, "hitChance": 0.0, "damageMin": 5, "damageMax": 12})
	state.cast_creeping_destruction(caster, spell, {"x": 2, "y": 0})
	assert_eq(target["ct"], 5, "perde 15 de CT mesmo com hitChance 0 (incondicional)")
	assert_true(state.is_rooted(target), "fica imóvel mesmo errando o dano")

# --- cast_throw_log ---------------------------------------------------------------

func test_cast_throw_log_pushes_or_deals_blocked_extra_damage() -> void:
	var troll := state.spawn_unit("troll", {"x": 0, "y": 0, "team": "enemy", "ct": 100, "mp": 10})
	var target := state.spawn_unit("target", {"x": 1, "y": 0, "team": "player", "hp": 30, "maxHp": 30})
	var wall := state.spawn_unit("wall", {"x": 2, "y": 0, "team": "player", "hp": 30, "maxHp": 30})
	var log_spell := _spell({"targetMode": "cardinal-blast", "bandLength": 3, "bandWidth": 3, "damageMin": 6, "damageMax": 6, "knockback": {"distance": 1, "blockedExtraDamage": 1}})
	state.cast_throw_log(troll, log_spell, {"x": 1, "y": 0})
	assert_eq(target["hp"], 30 - 6 - 1, "bloqueado pelo `wall`: não empurra, leva +1 de dano extra")
	assert_eq(target["x"], 1, "não se moveu, ficou bloqueado")

# --- cast_pierce_shot ---------------------------------------------------------------

func test_cast_pierce_shot_hits_everyone_on_the_cardinal_line_up_to_max_range() -> void:
	var archer := state.spawn_unit("archer", {"x": 0, "y": 0, "team": "player", "ct": 100, "mp": 10})
	var e1 := state.spawn_unit("e1", {"x": 1, "y": 0, "team": "enemy", "hp": 20, "maxHp": 20})
	var e2 := state.spawn_unit("e2", {"x": 3, "y": 0, "team": "enemy", "hp": 20, "maxHp": 20})
	var pierce := _spell({"targetMode": "pierce-line", "maxRange": 5, "damageMin": 3, "damageMax": 3})
	state.cast_pierce_shot(archer, pierce, {"x": 3, "y": 0})
	assert_eq(e1["hp"], 17, "perfura, não pára no primeiro atingido")
	assert_eq(e2["hp"], 17)

# --- cast_heal_aoe / cast_regen_aoe / cast_antidote / cast_trap ----------------

func test_cast_heal_aoe_heals_everyone_in_the_diamond_area() -> void:
	var healer := state.spawn_unit("healer", {"x": 5, "y": 5, "team": "enemy", "ct": 100, "mp": 20})
	var ally := state.spawn_unit("ally", {"x": 5, "y": 4, "team": "enemy", "hp": 5, "maxHp": 20})
	var foe := state.spawn_unit("foe", {"x": 5, "y": 6, "team": "player", "hp": 5, "maxHp": 20})
	var cure := _spell({"targetMode": "heal-aoe", "areaRadius": 1, "healMin": 5, "healMax": 5})
	state.cast_heal_aoe(healer, cure, {"x": 5, "y": 5})
	assert_eq(ally["hp"], 10)
	assert_eq(foe["hp"], 10, "cura em área também acerta o time inimigo")

## Pedido do usuário: Poção de Mana com a mesma área da Cura/Regeneração em
## Área (mesma forma de losango, ver test_cast_heal_aoe_heals_everyone_in_the_diamond_area).
func test_cast_mana_aoe_restores_mp_for_everyone_in_the_diamond_area() -> void:
	var chemist := state.spawn_unit("chemist", {"x": 5, "y": 5, "team": "player", "ct": 100, "mp": 20})
	var ally := state.spawn_unit("ally", {"x": 5, "y": 4, "team": "player", "mp": 5, "maxMp": 20})
	var foe := state.spawn_unit("foe", {"x": 5, "y": 6, "team": "enemy", "mp": 5, "maxMp": 20})
	var potion := _spell({"targetMode": "mana-aoe", "areaRadius": 1, "manaMin": 5, "manaMax": 5, "hitChance": 1})
	state.cast_mana_aoe(chemist, potion, {"x": 5, "y": 5})
	assert_eq(ally["mp"], 10)
	assert_eq(foe["mp"], 10, "restaura mana em área também acerta o time inimigo")

func test_cast_antidote_cures_poison_and_paralysis_without_touching_other_status() -> void:
	var chemist := state.spawn_unit("chemist", {"x": 4, "y": 5, "team": "player", "ct": 100, "mp": 20})
	var patient := state.spawn_unit("patient", {"x": 5, "y": 5, "statusEffects": [
		{"type": "poison", "turnsLeft": 2, "damageMin": 1, "damageMax": 3},
		{"type": "paralyzed", "turnsLeft": 1},
		{"type": "regen", "turnsLeft": 2, "healMin": 1, "healMax": 2},
	]})
	var antidote := _spell({"areaRadius": 2, "noDamage": true})
	state.cast_antidote(chemist, antidote, [{"x": 5, "y": 5}])
	assert_false(state.is_poisoned(patient))
	assert_false(state.is_paralyzed(patient))
	var regen := (patient["statusEffects"] as Array).filter(func(e): return e["type"] == "regen")
	assert_eq(regen.size(), 1, "só remove veneno/paralisia, não outros status")

func test_cast_trap_refuses_to_install_on_top_of_a_unit() -> void:
	var rogue := state.spawn_unit("rogue", {"x": 0, "y": 0, "team": "player", "ct": 100, "mp": 10})
	state.spawn_unit("someone", {"x": 1, "y": 0, "hp": 10})
	var trap := _spell({"targetMode": "trap", "areaRadius": 0, "noDamage": true})
	state.cast_trap(rogue, trap, {"x": 1, "y": 0})
	assert_eq(state.traps.size(), 0)

func test_cast_trap_installs_when_area_is_clear() -> void:
	var rogue := state.spawn_unit("rogue", {"x": 0, "y": 0, "team": "player", "ct": 100, "mp": 10})
	var trap := _spell({"targetMode": "trap", "areaRadius": 0, "noDamage": true})
	state.cast_trap(rogue, trap, {"x": 3, "y": 0})
	assert_eq(state.traps.size(), 1)
	assert_eq(state.traps[0]["ownerTeam"], "player")
	assert_true(state.traps[0]["visible"], "pedido do usuário: armadilha fica visível assim que instalada")
