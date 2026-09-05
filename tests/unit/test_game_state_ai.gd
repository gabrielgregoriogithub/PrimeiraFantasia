extends GutTest

## Fase 4 (IA): porte de pickNearestTarget/pickWeaponForDistance/
## pickBestHealAoeSpot/pickResurrectTarget/pickBestSafeAoeDirection/
## pickBestBlastSpot/getAttackOptions/enemyAttackThenAdvance/enemyAct e das
## execuções performMove/performAttack/performRangedAttackWithObstruction
## (game.js:5653-5735, 6295-6321, 7664-7687, 8620-8646, 9783-10476).

var state: GameState

func before_each() -> void:
	state = GameState.new()
	state.clear_units()
	state.clear_terrain_and_structures()

func _weapon(overrides: Dictionary) -> Dictionary:
	var w := {"name": "arma-teste", "ctCost": 50, "damageMin": 5, "damageMax": 5, "critMultiplier": 2, "critChance": 0.0, "hitChance": 1.0, "minRange": 1, "maxRange": 1}
	for k in overrides.keys():
		w[k] = overrides[k]
	return w

func _spell(overrides: Dictionary) -> Dictionary:
	var s := {"name": "magia-teste", "ctCost": 50, "mpCost": 5, "hitChance": 1.0, "critChance": 0.0, "critMultiplier": 1, "minRange": 1, "maxRange": 5}
	for k in overrides.keys():
		s[k] = overrides[k]
	return s

# --- team_units / opposing_team_of -------------------------------------------

func test_opposing_team_of_returns_the_other_team() -> void:
	var hero := state.spawn_unit("hero", {"team": "player"})
	state.spawn_unit("foe1", {"team": "enemy"})
	state.spawn_unit("foe2", {"team": "enemy"})
	assert_eq(state.opposing_team_of(hero).size(), 2)

# --- perform_move / perform_attack / perform_ranged_attack_with_obstruction --

func test_perform_move_pays_ct_and_updates_position() -> void:
	var u := state.spawn_unit("u", {"x": 0, "y": 0, "moveRange": 4, "ct": 100})
	state.compute_reachable(u)
	state.perform_move(u, {"x": 2, "y": 0})
	assert_eq(u["x"], 2)
	assert_true(u["hasMoved"])
	assert_eq(u["ct"], 100 - state.move_ct_cost(u, 2))

func test_perform_attack_resolves_hit_and_finalizes() -> void:
	var attacker := state.spawn_unit("attacker", {"x": 0, "y": 0, "ct": 100})
	var defender := state.spawn_unit("defender", {"x": 0, "y": 1, "hp": 20, "maxHp": 20})
	state.perform_attack(attacker, defender, _weapon({"damageMin": 4, "damageMax": 4}))
	assert_eq(defender["hp"], 16)
	assert_true(attacker["hasActed"])

func test_perform_ranged_attack_with_obstruction_hits_blocker_instead_of_target() -> void:
	var attacker := state.spawn_unit("attacker", {"x": 0, "y": 0, "ct": 100})
	var target := state.spawn_unit("target", {"x": 3, "y": 0, "hp": 20, "maxHp": 20})
	var blocker := state.spawn_unit("blocker", {"x": 1, "y": 0, "hp": 20, "maxHp": 20})
	var weapon := _weapon({"minRange": 1, "maxRange": 4, "damageMin": 3, "damageMax": 3, "requiresClearPath": true})
	state.perform_ranged_attack_with_obstruction(attacker, target, weapon)
	assert_eq(blocker["hp"], 17)
	assert_eq(target["hp"], 20)

# --- pick_nearest_target ----------------------------------------------------

func test_pick_nearest_target_ignores_invisible_and_picks_closest() -> void:
	var seeker := state.spawn_unit("seeker", {"x": 0, "y": 0, "team": "player"})
	state.spawn_unit("close_but_hidden", {"x": 1, "y": 0, "team": "enemy", "hp": 10, "statusEffects": [{"type": "invisible", "turnsLeft": 2}]})
	var visible_far := state.spawn_unit("visible_far", {"x": 5, "y": 0, "team": "enemy", "hp": 10, "statusEffects": []})
	assert_eq(state.pick_nearest_target(seeker), visible_far)

func test_pick_nearest_target_returns_null_when_everyone_is_invisible() -> void:
	var seeker := state.spawn_unit("seeker", {"x": 0, "y": 0, "team": "player"})
	state.spawn_unit("hidden", {"x": 1, "y": 0, "team": "enemy", "hp": 10, "statusEffects": [{"type": "invisible", "turnsLeft": 2}]})
	assert_null(state.pick_nearest_target(seeker))

# --- pick_weapon_for_distance ------------------------------------------------

func test_pick_weapon_for_distance_prefers_higher_hit_chance_in_range() -> void:
	var sword := _weapon({"name": "espada", "hitChance": 0.8, "minRange": 1, "maxRange": 1})
	var sling := _weapon({"name": "funda", "hitChance": 0.6, "minRange": 1, "maxRange": 4})
	var picked = state.pick_weapon_for_distance([sword, sling], 1, null)
	assert_eq(picked["name"], "espada")

func test_pick_weapon_for_distance_discards_plain_melee_against_flying_target() -> void:
	var sword := _weapon({"name": "espada", "minRange": 1, "maxRange": 1})
	var flying_target := {"flying": true}
	assert_null(state.pick_weapon_for_distance([sword], 1, flying_target))

	var crossbow := _weapon({"name": "besta", "minRange": 1, "maxRange": 1, "aerial": true})
	assert_eq(state.pick_weapon_for_distance([sword, crossbow], 1, flying_target)["name"], "besta")

# --- pick_best_heal_aoe_spot -------------------------------------------------

func test_pick_best_heal_aoe_spot_prefers_covering_more_wounded_allies() -> void:
	var healer := state.spawn_unit("healer", {"x": 5, "y": 5, "team": "enemy"})
	state.spawn_unit("w1", {"x": 5, "y": 6, "team": "enemy", "hp": 5, "maxHp": 20})
	state.spawn_unit("w2", {"x": 5, "y": 7, "team": "enemy", "hp": 5, "maxHp": 20})
	var cure := _spell({"minRange": 0, "maxRange": 4, "areaRadius": 1})
	var spot = state.pick_best_heal_aoe_spot(healer, cure)
	assert_not_null(spot)
	assert_eq(spot, {"x": 5, "y": 6}, "meio do caminho entre os dois feridos, dentro do raio dos dois")

func test_pick_best_heal_aoe_spot_returns_null_when_nobody_is_wounded_enough() -> void:
	var healer := state.spawn_unit("healer", {"x": 5, "y": 5, "team": "enemy"})
	state.spawn_unit("almost_full", {"x": 5, "y": 6, "team": "enemy", "hp": 19, "maxHp": 20})
	var cure := _spell({"minRange": 0, "maxRange": 4, "areaRadius": 1})
	assert_null(state.pick_best_heal_aoe_spot(healer, cure))

# --- pick_resurrect_target ----------------------------------------------------

func test_pick_resurrect_target_prioritizes_fewest_turns_remaining() -> void:
	var caster := state.spawn_unit("caster", {"x": 0, "y": 0, "team": "player"})
	state.spawn_unit("fresh_corpse", {"x": 1, "y": 0, "hp": 0, "team": "player", "turnsSinceDeath": 0})
	var about_to_expire := state.spawn_unit("about_to_expire", {"x": 2, "y": 0, "hp": 0, "team": "player", "turnsSinceDeath": 3})
	var spell := _spell({"minRange": 0, "maxRange": 5})
	assert_eq(state.pick_resurrect_target(caster, spell), about_to_expire)

func test_pick_resurrect_target_ignores_enemy_corpses() -> void:
	var caster := state.spawn_unit("caster", {"x": 0, "y": 0, "team": "player"})
	state.spawn_unit("enemy_corpse", {"x": 1, "y": 0, "hp": 0, "team": "enemy", "turnsSinceDeath": 1})
	var spell := _spell({"minRange": 0, "maxRange": 5})
	assert_null(state.pick_resurrect_target(caster, spell))

# --- pick_best_safe_aoe_direction --------------------------------------------

func test_pick_best_safe_aoe_direction_rejects_ally_hit_direction_and_picks_the_safe_one_with_most_enemies() -> void:
	var caster := state.spawn_unit("caster", {"x": 5, "y": 5, "team": "enemy"})
	# Leste: só 1 inimigo, mas seguro (sem aliado).
	state.spawn_unit("foe_east", {"x": 6, "y": 5, "team": "player", "hp": 10})
	# Oeste: um aliado bem na frente (profundidade 1) barra a direção inteira
	# antes mesmo de contar os inimigos mais além dela.
	state.spawn_unit("ally_west", {"x": 4, "y": 5, "team": "enemy", "hp": 10})
	state.spawn_unit("foe_west_1", {"x": 3, "y": 5, "team": "player", "hp": 10})
	state.spawn_unit("foe_west_2", {"x": 2, "y": 5, "team": "player", "hp": 10})
	var best = state.pick_best_safe_aoe_direction(caster, func(dx, dy): return state.compute_cone_tiles_for_dir(caster, dx, dy, 4))
	assert_not_null(best)
	assert_eq(best["dx"], 1, "oeste tem aliado na frente e é rejeitada por completo — leste é a única direção segura")
	assert_eq(best["enemyCount"], 1)

# --- pick_best_blast_spot -----------------------------------------------------

func test_pick_best_blast_spot_never_catches_an_ally() -> void:
	var mage := state.spawn_unit("mage", {"x": 0, "y": 0, "team": "player"})
	var foe := state.spawn_unit("foe", {"x": 3, "y": 0, "team": "enemy", "hp": 10})
	state.spawn_unit("ally_nearby", {"x": 4, "y": 0, "team": "player", "hp": 10})
	var blast := _spell({"targetMode": "point-aoe", "minRange": 1, "maxRange": 6, "areaRadius": 1})
	assert_null(state.pick_best_blast_spot(mage, blast), "único inimigo alcançável tem aliado colado, nenhum spot é seguro")

func test_pick_best_blast_spot_picks_spot_with_most_enemies_caught() -> void:
	var mage := state.spawn_unit("mage", {"x": 0, "y": 0, "team": "player"})
	var e1 := state.spawn_unit("e1", {"x": 3, "y": 0, "team": "enemy", "hp": 10})
	state.spawn_unit("e2", {"x": 3, "y": 1, "team": "enemy", "hp": 10})
	var blast := _spell({"targetMode": "point-aoe", "minRange": 1, "maxRange": 6, "areaRadius": 1})
	assert_eq(state.pick_best_blast_spot(mage, blast), {"x": e1["x"], "y": e1["y"]})

# --- get_attack_options / enemy_attack_then_advance --------------------------

func test_get_attack_options_includes_affordable_single_target_spells() -> void:
	var u := state.spawn_unit("u", {"mp": 3})
	var sword := _weapon({})
	var affordable_spell := _spell({"targetMode": "enemy", "mpCost": 3})
	var too_expensive_spell := _spell({"targetMode": "enemy", "mpCost": 10})
	u["weapons"] = [sword]
	u["spells"] = [affordable_spell, too_expensive_spell]
	var options := state.get_attack_options(u)
	assert_true(options.has(sword))
	assert_true(options.has(affordable_spell))
	assert_false(options.has(too_expensive_spell))

func test_enemy_attack_then_advance_uses_the_bonus_attack_before_ending_turn() -> void:
	var goblin := state.spawn_unit("goblin", {"x": 0, "y": 0, "team": "enemy", "ct": 100, "hasActed": false, "bonusAttacksRemaining": 1})
	var target := state.spawn_unit("target", {"x": 0, "y": 1, "team": "player", "hp": 50, "maxHp": 50})
	# Já pronta (ct=100) — assim que o encadeamento final (advance_to_next_turn)
	# rodar, ela é escolhida sem nenhum tick de CT, sem risco do turno voltar
	# pro próprio goblin e resetar hasActed antes da asserção abaixo.
	state.spawn_unit("filler", {"x": 10, "y": 10, "team": "enemy", "ct": 100})
	state.current_actor = goblin
	var weapon := _weapon({"damageMin": 3, "damageMax": 3})
	goblin["weapons"] = [weapon]
	state.enemy_attack_then_advance(goblin, target, weapon)
	assert_eq(target["hp"], 44, "atacou 2 vezes: o ataque normal + o bônus")
	assert_true(goblin["hasActed"])

# --- enemy_act: ramos de prioridade -------------------------------------------

func test_enemy_act_auto_casts_fury_before_deciding_the_rest_of_the_turn() -> void:
	var orc := state.spawn_unit("orc", {"x": 0, "y": 0, "team": "enemy", "hp": 40, "maxHp": 40, "mp": 20, "moveRange": 3, "ct": 100, "speed": 5, "statusEffects": []})
	orc["spells"] = [_spell({"kind": "fury", "ctCost": 0, "mpCost": 3, "damageBonus": 2, "speedBonus": 2, "hpDrainPerTurn": 1, "turns": 3, "targetMode": "self"})]
	orc["weapons"] = []
	state.spawn_unit("far_enemy", {"x": 10, "y": 10, "team": "player", "hp": 30, "maxHp": 30, "ct": 0})
	state.current_actor = orc
	state.enemy_act(orc)
	var fury := (orc["statusEffects"] as Array).filter(func(e): return e["type"] == "fury")
	assert_eq(fury.size(), 1, "Fúria é ativada automaticamente antes de qualquer outra decisão")

func test_enemy_act_prioritizes_resurrect_over_everything_else() -> void:
	var shaman := state.spawn_unit("shaman", {"x": 5, "y": 5, "team": "enemy", "hp": 25, "maxHp": 25, "mp": 20, "moveRange": 3, "ct": 100, "speed": 5, "statusEffects": []})
	var resurrect_spell := _spell({"kind": "resurrect", "ctCost": 90, "mpCost": 7, "hitChance": 1.0, "minRange": 0, "maxRange": 3, "targetMode": "resurrect"})
	var heal_spell := _spell({"kind": "heal-aoe", "ctCost": 45, "mpCost": 5, "healMin": 5, "healMax": 5, "minRange": 0, "maxRange": 3, "areaRadius": 1, "targetMode": "heal-aoe"})
	shaman["spells"] = [resurrect_spell, heal_spell]
	shaman["weapons"] = []
	var corpse := state.spawn_unit("corpse", {"x": 6, "y": 5, "team": "enemy", "hp": 0, "maxHp": 30, "turnsSinceDeath": 1})
	state.spawn_unit("wounded_ally", {"x": 5, "y": 6, "team": "enemy", "hp": 1, "maxHp": 30})
	state.spawn_unit("far_enemy", {"x": 10, "y": 10, "team": "player", "hp": 30, "maxHp": 30, "ct": 0})
	state.current_actor = shaman
	state.enemy_act(shaman)
	assert_true(corpse["hp"] > 0, "ressuscitou em vez de curar")

func test_enemy_act_growth_attack_when_two_or_more_adjacent_enemies() -> void:
	var troll := state.spawn_unit("troll", {"x": 5, "y": 5, "team": "enemy", "hp": 50, "maxHp": 50, "mp": 10, "moveRange": 4, "ct": 100, "speed": 5, "statusEffects": []})
	var growth := _spell({"kind": "growth-attack", "ctCost": 50, "mpCost": 3, "hitChance": 1.0, "critChance": 0.0, "damageMin": 8, "damageMax": 8, "targetMode": "self-attack"})
	troll["spells"] = [growth]
	troll["weapons"] = []
	var e1 := state.spawn_unit("e1", {"x": 6, "y": 5, "team": "player", "hp": 20, "maxHp": 20})
	var e2 := state.spawn_unit("e2", {"x": 5, "y": 6, "team": "player", "hp": 20, "maxHp": 20})
	state.current_actor = troll
	state.enemy_act(troll)
	assert_eq(e1["hp"], 12)
	assert_eq(e2["hp"], 12)

func test_enemy_act_falls_back_to_moving_towards_the_target_when_nothing_else_applies() -> void:
	var goblin := state.spawn_unit("goblin", {"x": 0, "y": 0, "team": "enemy", "hp": 30, "maxHp": 30, "mp": 0, "moveRange": 4, "ct": 100, "speed": 5, "statusEffects": []})
	goblin["spells"] = []
	goblin["weapons"] = [_weapon({"minRange": 1, "maxRange": 1})]
	state.spawn_unit("far_target", {"x": 10, "y": 0, "team": "player", "hp": 30, "maxHp": 30, "ct": 0})
	state.current_actor = goblin
	state.enemy_act(goblin)
	assert_true(goblin["x"] > 0, "andou em direção ao alvo, já que não alcançava ataque nenhum")
	assert_true(goblin["hasMoved"])

func test_enemy_act_attacks_immediately_when_a_target_is_already_in_weapon_range() -> void:
	var goblin := state.spawn_unit("goblin", {"x": 0, "y": 0, "team": "enemy", "hp": 30, "maxHp": 30, "mp": 0, "moveRange": 4, "ct": 100, "speed": 5, "statusEffects": []})
	goblin["spells"] = []
	goblin["weapons"] = [_weapon({"minRange": 1, "maxRange": 1, "damageMin": 4, "damageMax": 4})]
	var target := state.spawn_unit("target", {"x": 0, "y": 1, "team": "player", "hp": 30, "maxHp": 30, "ct": 0})
	state.current_actor = goblin
	state.enemy_act(goblin)
	assert_eq(target["hp"], 26)
	assert_false(goblin["hasMoved"], "já estava a distância de ataque, não precisou se mover")
