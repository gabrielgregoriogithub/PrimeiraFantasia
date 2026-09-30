class_name EnemyAI
extends RefCounted

## IA dos inimigos e de herois controlados pela IA (heuristicas de alvo/magia e o turno da IA).
## Extraido de autoload/game_state.gd: todas as funcoes sao estaticas e recebem o
## estado (`gs`) como 1o argumento. A API publica continua em GameState, via
## wrappers de uma linha (mesmos nomes e assinaturas).

static func _find_spell(gs: GameState, u: Dictionary, predicate: Callable) -> Variant:
	for s in u.get("spells", []):
		if predicate.call(s):
			return s
	return null


static func _find_weapon(gs: GameState, u: Dictionary, predicate: Callable) -> Variant:
	for w in u.get("weapons", []):
		if predicate.call(w):
			return w
	return null


## BFS (4 direções, sem custo/alcance) a partir de (target_x, target_y) sobre
## todo o tabuleiro, respeitando só bloqueio de verdade (BoardLayout.
## BLOCKING_TERRAIN_TYPES) — água NÃO bloqueia aqui (só custa mais caro pra
## andar, ver water_step_cost), só decide se dá pra CHEGAR. Usado como
## critério de progresso pro fallback de movimento da IA em vez de distância
## Manhattan em linha reta, que não enxerga paredes: um monstro só com saída
## por um corredor/escada específico pode ter Manhattan MENOR ficando parado
## contra a parede errada do que desviando até o corredor certo. Com `u`,
## usa o bloqueio de terreno DESSA unidade (unidade 2x2 atravessa props, ver
## GameState._terrain_blocks_unit).
static func _walkable_path_distance_map(gs: GameState, target_x: int, target_y: int, u: Dictionary = {}) -> Dictionary:
	var dist := {}
	var start_key := gs.tile_key(target_x, target_y)
	dist[start_key] = 0
	var queue: Array = [{"x": target_x, "y": target_y}]
	var head := 0
	while head < queue.size():
		var cur: Dictionary = queue[head]
		head += 1
		var cur_dist: int = dist[gs.tile_key(cur["x"], cur["y"])]
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = cur["x"] + d[0]
			var ny: int = cur["y"] + d[1]
			if not gs.in_bounds(nx, ny):
				continue
			var nk := gs.tile_key(nx, ny)
			if dist.has(nk):
				continue
			var terrain = gs.terrain_at(nx, ny)
			if gs._terrain_blocks_transit(terrain, u):
				continue
			dist[nk] = cur_dist + 1
			queue.append({"x": nx, "y": ny})
	return dist


## Alvo mais próximo do time adversário — nunca mira em quem está invisível
## (o golpe sempre erraria), mesmo que seja o único adversário restante.
static func pick_nearest_target(gs: GameState, u: Dictionary) -> Variant:
	# "caged" (ver resolve_single_hit) é imune a qualquer dano — sem esse
	# filtro a IA mirava na Maga presa sempre que ela fosse o oponente mais
	# próximo, gastando o turno inteiro atacando alguém que nunca pode ser
	# ferido em vez de um alvo de verdade.
	var opponents: Array = gs.opposing_team_of(u).filter(func(o): return o["hp"] > 0 and not o.get("caged", false))
	if opponents.is_empty():
		return null
	var visible: Array = opponents.filter(func(o): return not gs.is_invisible(o))
	if visible.is_empty():
		return null
	visible.sort_custom(func(a, b): return gs.manhattan(u, a) < gs.manhattan(u, b))
	return visible[0]


## Entre as armas em alcance pra `distance`, escolhe a de maior chance de
## acerto. Se `target` voa, descarta de cara qualquer arma corpo a corpo
## comum (sempre erra contra voadores).
static func pick_weapon_for_distance(gs: GameState, weapons: Array, distance: int, target) -> Variant:
	var candidates: Array = weapons.filter(func(w): return gs.is_in_weapon_range(w, distance))
	if target != null and target.get("flying", false):
		candidates = candidates.filter(func(w): return not (not w.has("mpCost") and w["maxRange"] == 1 and not w.get("aerial", false)))
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a, b): return float(gs.get_hit_chance(a, distance)) > float(gs.get_hit_chance(b, distance)))
	return candidates[0]


## Cura em Área (Xamã/Fada): escolhe como centro um aliado ferido dentro do
## alcance, preferindo o spot que cura mais gente ferida sem pegar inimigo.
static func pick_best_heal_aoe_spot(gs: GameState, caster: Dictionary, spell: Dictionary) -> Variant:
	var allies: Array = gs.team_units(caster["team"]).filter(func(u): return u["hp"] > 0)
	var enemies: Array = gs.opposing_team_of(caster).filter(func(u): return u["hp"] > 0)
	var candidates: Array = allies.filter(func(u): return u["hp"] < u["maxHp"] * 0.5 and gs.manhattan(caster, u) <= spell["maxRange"] and gs.manhattan(caster, u) >= spell["minRange"])
	if candidates.is_empty():
		return null
	var spots: Array = []
	for c in candidates:
		spots.append({"x": c["x"], "y": c["y"]})
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var spot := {"x": c["x"] + d[0], "y": c["y"] + d[1]}
			if gs.in_bounds(spot["x"], spot["y"]) and gs.manhattan(caster, spot) <= spell["maxRange"] and gs.manhattan(caster, spot) >= spell["minRange"]:
				spots.append(spot)
	var best = null
	var best_score: float = -INF
	for spot in spots:
		var wounded_nearby := 0
		for u in allies:
			if u["hp"] < u["maxHp"] and gs.manhattan(u, spot) <= spell["areaRadius"]:
				wounded_nearby += 1
		var enemies_caught := 0
		for u in enemies:
			if gs.manhattan(u, spot) <= spell["areaRadius"]:
				enemies_caught += 1
		var score: float = wounded_nearby - enemies_caught * 10
		if score > best_score:
			best_score = score
			best = spot
	return best


## Melhor alvo pra Ressurreição: cadáver aliado no alcance com MENOS turnos
## restantes (mais perto de virar alma).
## `require_undead` (Reanimação do Lich): mesmo critério de sempre, só
## acrescentando o filtro `undead` — reutilizado em vez de duplicado, já
## que Ressurreição/Reanimação só diferem nisso (a diferença de COMO
## reviver, cast_resurrect vs cast_reanimate, já está isolada à parte).
static func pick_resurrect_target(gs: GameState, caster: Dictionary, spell: Dictionary, require_undead: bool = false) -> Variant:
	var dead_allies: Array = []
	for u in gs.units:
		if u["team"] != caster["team"] or u["hp"] > 0 or not u.has("turnsSinceDeath"):
			continue
		if require_undead and not u.get("undead", false):
			continue
		if gs.manhattan(caster, u) > spell["maxRange"] or gs.manhattan(caster, u) < spell["minRange"]:
			continue
		dead_allies.append(u)
	if dead_allies.is_empty():
		return null
	dead_allies.sort_custom(func(a, b): return a["turnsSinceDeath"] > b["turnsSinceDeath"])
	return dead_allies[0]


## Direção que acerta MAIS inimigos SEM acertar NENHUM aliado — "0 aliados
## atingidos" é obrigatório, mesmo abrindo mão de acertar mais inimigos numa
## direção que pegasse 1 aliado. `compute_tiles_for_dir` recebe (dx,dy) e
## devolve os tiles daquela direção (cone ou faixa, conforme a habilidade).
static func pick_best_safe_aoe_direction(gs: GameState, caster: Dictionary, compute_tiles_for_dir: Callable) -> Variant:
	var dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]]
	var best = null
	for d in dirs:
		var tiles = compute_tiles_for_dir.call(d[0], d[1])
		if tiles == null or (tiles as Array).is_empty():
			continue
		var enemy_count := 0
		var ally_hit := false
		for t in tiles:
			var u = gs.unit_at(t["x"], t["y"])
			if u == null:
				continue
			if u["team"] == caster["team"]:
				ally_hit = true
				break
			enemy_count += 1
		if ally_hit or enemy_count == 0:
			continue
		if best == null or enemy_count > best["enemyCount"]:
			best = {"dx": d[0], "dy": d[1], "tiles": tiles, "enemyCount": enemy_count}
	return best


static func pick_best_cone_direction(gs: GameState, caster: Dictionary, spell: Dictionary) -> Variant:
	var dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]]
	var best = null
	var best_count := 0
	for d in dirs:
		var tiles := gs.compute_cone_tiles_for_dir(caster, d[0], d[1], spell["maxRange"])
		var count := 0
		for t in tiles:
			var u = gs.unit_at(t["x"], t["y"])
			if u != null and u["team"] != caster["team"]:
				count += 1
		if count > best_count:
			best_count = count
			best = tiles
	return best


## Congelamento (Fada): mira o inimigo cujo losango ao redor pega mais
## gente; ignora quem já está paralisado.
static func pick_best_freeze_target(gs: GameState, caster: Dictionary, spell: Dictionary) -> Variant:
	var candidates: Array = []
	for u in gs.opposing_team_of(caster):
		if u["hp"] > 0 and gs.manhattan(caster, u) <= spell["maxRange"] and not gs.is_paralyzed(u):
			candidates.append(u)
	if candidates.is_empty():
		return null
	var best = candidates[0]
	var best_count := -1
	for c in candidates:
		var count := 0
		for u in gs.alive_units():
			if u["team"] != caster["team"] and gs.manhattan(u, c) <= spell["areaRadius"]:
				count += 1
		if count > best_count:
			best_count = count
			best = c
	return {"x": best["x"], "y": best["y"]}


## Melhor ponto de impacto pra explosão em área ofensiva: maximiza quantos
## inimigos a área pega, mas NUNCA escolhe um ponto que também pegue um
## aliado (a mira da IA é seletiva; o efeito em si continua acertando todo
## mundo dentro se de fato lançado ali).
static func pick_best_blast_spot(gs: GameState, caster: Dictionary, spell: Dictionary) -> Variant:
	var enemies: Array = gs.opposing_team_of(caster).filter(func(u): return u["hp"] > 0)
	var allies: Array = gs.team_units(caster["team"]).filter(func(u): return u["hp"] > 0)
	var candidates: Array = enemies.filter(func(u): return gs.manhattan(caster, u) <= spell["maxRange"] and gs.manhattan(caster, u) >= spell["minRange"])
	if candidates.is_empty():
		return null
	var best = null
	var best_count := 0
	for c in candidates:
		var spot := {"x": c["x"], "y": c["y"]}
		var friendly_caught := false
		for u in allies:
			if gs.manhattan(u, spot) <= spell["areaRadius"]:
				friendly_caught = true
				break
		if friendly_caught:
			continue
		var enemies_caught := 0
		for u in enemies:
			if gs.manhattan(u, spot) <= spell["areaRadius"]:
				enemies_caught += 1
		if enemies_caught > best_count:
			best_count = enemies_caught
			best = spot
	return best


## Executa um ataque e, se sobrar ataque bônus (Agilidade — hasActed
## continua false depois do golpe), tenta atacar de novo antes de passar o
## turno.
static func enemy_attack_then_advance(gs: GameState, u: Dictionary, target: Dictionary, weapon_item: Dictionary) -> void:
	if weapon_item.get("requiresClearPath", false):
		gs.perform_ranged_attack_with_obstruction(u, target, weapon_item)
	else:
		gs.perform_attack(u, target, weapon_item)
	if not u.get("hasActed", false) and u["hp"] > 0 and target["hp"] > 0:
		var next_weapon = pick_weapon_for_distance(gs, gs.get_attack_options_against(u, target), gs.manhattan(u, target), target)
		if next_weapon != null:
			enemy_attack_then_advance(gs, u, target, next_weapon)
			return
	gs.advance_to_next_turn()


## Prioridade absoluta da IA na Horda: monstros que estão no platô superior
## (y < 3) ou já entraram na escada não param para atacar/conjurar. Eles
## avançam pelo caminho real até o primeiro tile do piso inferior (11,7),
## garantindo que saiam do morro para participar da luta.
static func _try_prioritize_lua_valley_ladder_descent(gs: GameState, u: Dictionary) -> bool:
	if gs.scenario_id != ScenarioManager.LUA_VALLEY or u.get("team", "") != "enemy":
		return false
	var terrain = gs.terrain_at(int(u["x"]), int(u["y"]))
	var on_ladder: bool = terrain != null and terrain.get("type", "") == "lua-ladder"
	if int(u["y"]) >= 3 and not on_ladder:
		return false
	if gs.is_rooted(u):
		return false
	var lower_floor := {"x": 11, "y": 7}
	var path_dist := _walkable_path_distance_map(gs, lower_floor["x"], lower_floor["y"])
	var start_dist: int = int(path_dist.get(gs.tile_key(u["x"], u["y"]), 1_000_000))
	var best = null
	var best_dist := start_dist
	for tile in gs.compute_reachable(u):
		var distance: int = int(path_dist.get(gs.tile_key(tile["x"], tile["y"]), 1_000_000))
		if distance < best_dist:
			best_dist = distance
			best = tile
	if best == null:
		return false
	gs.perform_move(u, best)
	gs._log("%s prioriza descer a escada para entrar na luta!" % u["name"])
	gs.advance_to_next_turn()
	return true


## Compartilhado por toda IA de invocação (Fogo Vivo do Demônio das Chamas,
## Morcegos do Vampiro, Esqueleto/Zumbi do Lich): só considera invocar
## quando há utilidade tática real — não gasta MP automaticamente. Evita
## invocar com um inimigo já adjacente (prioriza lutar) e só invoca quando o
## próprio time está em desvantagem numérica (menos aliados vivos que
## inimigos vivos).
static func _wants_to_summon_reinforcement(gs: GameState, u: Dictionary) -> bool:
	var nearest = pick_nearest_target(gs, u)
	if nearest != null and gs.manhattan(u, nearest) <= 1:
		return false
	var allies_alive: int = gs.team_units(u["team"]).filter(func(o): return o["hp"] > 0).size()
	var enemies_alive: int = gs.opposing_team_of(u).filter(func(o): return o["hp"] > 0).size()
	return allies_alive < enemies_alive


## Tile válido pra qualquer invocação de alcance N: mesma checagem de
## terreno/ocupação de _cast_summon_unit, varrendo todo o losango de alcance
## em vez de expandir a partir de uma origem fixa (a unidade pode preferir
## qualquer tile dentro do alcance, não só o mais próximo — ver
## _first_free_tile_near pro caso "mais próximo de um ponto").
static func _summon_spot_in_range(gs: GameState, u: Dictionary, spell: Dictionary) -> Variant:
	var max_range: int = int(spell["maxRange"])
	var candidates: Array = []
	for dx in range(-max_range, max_range + 1):
		for dy in range(-max_range, max_range + 1):
			if absi(dx) + absi(dy) > max_range or (dx == 0 and dy == 0):
				continue
			var x: int = int(u["x"]) + dx
			var y: int = int(u["y"]) + dy
			if not gs.in_bounds(x, y):
				continue
			var terrain = gs.terrain_at(x, y)
			var open_ground: bool = terrain == null or terrain.get("walkable", false)
			if open_ground and gs.occupant_at(x, y) == null and gs.structure_at(x, y) == null:
				candidates.append({"x": x, "y": y})
	if candidates.is_empty():
		return null
	return candidates[gs.rng.randi_range(0, candidates.size() - 1)]


## Vampiro: Virar Morcego é uma PREPARAÇÃO (não a jogada principal do
## turno) — só vale quando traz vantagem real, nunca automática só por ter
## MP sobrando (pedido do usuário). Já transformado, nunca reconsidera (a
## renovação de duração já é responsabilidade de quem usar a habilidade de
## novo, não desta checagem). Dois motivos táticos: (1) alcançar um alvo que
## só o MOV dobrado (ou o Voo, atravessando terreno) resolve, (2) HP abaixo
## de 50% aproveitando o lifesteal de 100% da forma de morcego.
static func _vampire_wants_bat_form(gs: GameState, u: Dictionary, target) -> bool:
	if gs._has_status(u, "batForm"):
		return false
	if target == null:
		return false
	var distance: int = gs.manhattan(u, target)
	var reachable_now: bool = gs.compute_reachable(u).any(func(t): return gs.manhattan(t, target) <= 1)
	var needs_reach: bool = not reachable_now and distance <= u["moveRange"] * 2
	var wants_lifesteal_boost: bool = u["hp"] < u["maxHp"] * 0.5 and distance <= u["moveRange"] * 2 + 1
	return needs_reach or wants_lifesteal_boost


## Lich, Infligir Ferimentos usada como cura: mesmo critério de
## pick_best_heal_aoe_spot (prioriza quem está mais ferido, em fração de
## HP), só filtrando por `undead` — Infligir Ferimentos SÓ cura morto-vivo
## (ver resolve_harm).
static func _pick_inflict_wounds_heal_target(gs: GameState, caster: Dictionary, spell: Dictionary) -> Variant:
	var candidates: Array = gs.team_units(caster["team"]).filter(func(u):
		var in_range: bool = gs.manhattan(caster, u) <= spell["maxRange"] and gs.manhattan(caster, u) >= spell["minRange"]
		return u["hp"] > 0 and u.get("undead", false) and u["hp"] < u["maxHp"] * 0.5 and in_range
	)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a, b): return float(a["hp"]) / float(a["maxHp"]) < float(b["hp"]) / float(b["maxHp"]))
	return candidates[0]


## Lich, Decaimento: quantos alvos de VALOR real a área centrada na posição
## ATUAL do Lich pegaria agora — inimigo vivo (sempre vale, sofre dano) ou
## aliado morto-vivo abaixo do HP máximo (só vale se há o que curar). Usado
## pra só priorizar a magia quando há 2+ alvos, mesmo limiar já usado por
## outras habilidades de área desta IA (ex: Crescimento do Troll).
static func _decay_pulse_value(gs: GameState, u: Dictionary, spell: Dictionary) -> int:
	var value := 0
	for target in gs.alive_units():
		if gs.manhattan(u, target) > spell["areaRadius"]:
			continue
		if target.get("undead", false):
			if target["hp"] < target["maxHp"]:
				value += 1
		else:
			value += 1
	return value


## Decide e executa o turno inteiro de uma unidade controlada por IA
## (game.js:10032-10476). Ordem de prioridade: habilidades livres (Fúria,
## Pés Ágeis, Agilidade, Evasiva, Regeneração) primeiro; depois Ressurreição
## > Cura em Área > Regeneração em Área; depois a prioridade especial de
## Ventania/Destruição Rastejante quando pegam 2+ inimigos sem nenhum
## aliado; depois (com um alvo escolhido) Prisão de Vinhas > explosão em
## área segura > Congelamento > Ventania > Crescimento (2+ adjacentes) >
## Envenenamento > Investida > Atropelar; por fim ataque normal ou
## aproximação (com desvio por alma/sobrevivência/Montanha). Termina
## chamando advance_to_next_turn() (ou, em cadeia, enemy_attack_then_advance)
## — não dispara a IA da próxima unidade sozinho.
static func _enemy_creature_attack_and_end(gs: GameState, u: Dictionary, target: Dictionary, item: Dictionary) -> void:
	if item == null or int(u.get("mp", 0)) < int(item.get("mpCost", 0)):
		return
	gs.perform_attack(u, target, item)
	if u.get("hp", 0) > 0:
		gs.advance_to_next_turn()


static func _enemy_use_creature_action(gs: GameState, u: Dictionary, target: Dictionary) -> bool:
	var kind := String(u.get("spriteKey", ""))
	var distance := gs.manhattan(u, target)
	if kind == "spd_rat":
		var call: Variant = _find_spell(gs, u, func(s): return s.get("kind", "") == "rat-pack-call")
		var nearby_rats := gs.units.filter(func(other): return other.get("spriteKey", "") == "spd_rat" and other["hp"] > 0 and gs.manhattan(u, other) <= 3)
		if call != null and u["mp"] >= call["mpCost"] and nearby_rats.size() >= 1:
			gs.cast_self_ability(u, call)
			gs.advance_to_next_turn()
			return true
		var charge: Variant = _find_spell(gs, u, func(s): return s.get("kind", "") == "creature-charge")
		if charge != null and u["mp"] >= charge["mpCost"] and gs.compute_charge_targets(u, charge).any(func(tile): return tile["x"] == target["x"] and tile["y"] == target["y"]):
			gs.cast_charge(u, target, charge)
			gs.advance_to_next_turn()
			return true
	if kind == "spd_snake":
		var skin: Variant = _find_spell(gs, u, func(s): return s.get("kind", "") == "snake-skin")
		if skin != null and u["mp"] >= skin["mpCost"] and (u["hp"] < u["maxHp"] or not gs._has_status(u, "evasive")):
			gs.cast_self_ability(u, skin)
			gs.advance_to_next_turn()
			return true
		var bite: Variant = _find_spell(gs, u, func(s): return s.get("kind", "") == "creature-poison-bite")
		if bite != null and distance <= bite["maxRange"] and u["mp"] >= bite["mpCost"] and not gs._has_status(target, "poison"):
			_enemy_creature_attack_and_end(gs, u, target, bite)
			return true
		var constrict: Variant = _find_spell(gs, u, func(s): return s.get("kind", "") == "snake-constrict")
		if constrict != null and distance <= 1 and u["mp"] >= constrict["mpCost"] and not gs._has_status(target, "root"):
			_enemy_creature_attack_and_end(gs, u, target, constrict)
			return true
	if kind == "spd_gnoll":
		var howl: Variant = _find_spell(gs, u, func(s): return s.get("kind", "") == "gnoll-war-howl")
		var nearby_allies := gs.units.filter(func(other): return other["team"] == u["team"] and other["hp"] > 0 and gs.manhattan(u, other) <= 3)
		if howl != null and u["mp"] >= howl["mpCost"] and nearby_allies.size() >= 1 and not gs._has_status(u, "warHowl"):
			gs.cast_self_ability(u, howl)
			gs.advance_to_next_turn()
			return true
		var hunt: Variant = _find_spell(gs, u, func(s): return s.get("kind", "") == "gnoll-hunt-charge")
		if hunt != null and u["mp"] >= hunt["mpCost"] and gs.compute_charge_targets(u, hunt).any(func(tile): return tile["x"] == target["x"] and tile["y"] == target["y"]):
			gs.cast_charge(u, target, hunt)
			gs.advance_to_next_turn()
			return true
	if kind == "spd_slime":
		var acid: Variant = _find_spell(gs, u, func(s): return s.get("kind", "") == "slime-acid-spit")
		if acid != null and distance <= acid["maxRange"] and u["mp"] >= acid["mpCost"] and not gs._has_status(target, "defenseDown"):
			_enemy_creature_attack_and_end(gs, u, target, acid)
			return true
		var jump: Variant = _find_spell(gs, u, func(s): return s.get("kind", "") == "slime-jump")
		if jump != null and u["mp"] >= jump["mpCost"]:
			for tile in gs.compute_slime_jump_targets(u, jump):
				var hit_count := 0
				for other in gs.opposing_team_of(u):
					if absi(other["x"] - tile["x"]) + absi(other["y"] - tile["y"]) == 1: hit_count += 1
				if hit_count >= 2:
					gs.cast_slime_jump(u, jump, tile)
					gs.advance_to_next_turn()
					return true
	return false


static func enemy_act(gs: GameState, u: Dictionary) -> void:
	if _try_prioritize_lua_valley_ladder_descent(gs, u):
		return
	if u.get("spriteKey", "") == "bardo" and u.get("mp", 0) >= 10:
		var allies := gs._eligible_song_targets(u, true)
		var enemies := gs._eligible_song_targets(u, false)
		var critical_allies := allies.filter(func(a): return int(a["hp"]) * 100 <= int(a["maxHp"]) * 40)
		var chosen_song = null
		# Mantém a música atual; só troca por Cura diante de emergência real.
		if not gs.is_bard_singing(u) or not critical_allies.is_empty():
			if not critical_allies.is_empty():
				chosen_song = _find_spell(gs, u, func(s): return s.get("songKind", "") == "heal")
			elif allies.size() >= 2:
				chosen_song = _find_spell(gs, u, func(s): return s.get("songKind", "") == "inspiration")
			elif enemies.any(func(e): return int(e.get("ct", 0)) >= 30):
				chosen_song = _find_spell(gs, u, func(s): return s.get("songKind", "") == "distraction")
			else:
				chosen_song = _find_spell(gs, u, func(s): return s.get("songKind", "") == "pain")
		if chosen_song != null and (not gs.is_bard_singing(u) or chosen_song.get("songKind", "") != (u["activeBardSong"]["item"] as Dictionary).get("songKind", "")):
			gs.cast_bard_song(u, chosen_song)
			gs.advance_to_next_turn()
			return
	if u.get("spriteKey", "") == "spd_goo" and u.get("mp", 0) >= 5:
		for hero in gs.opposing_team_of(u):
			if gs.manhattan(u, hero) <= 2:
				gs.cast_black_slime_poison(u)
				gs.advance_to_next_turn()
				return
	if u.has("spells"):
		var fury_spell = _find_spell(gs, u, func(s): return s.get("kind") == "fury")
		if fury_spell != null and u["mp"] >= fury_spell["mpCost"] and not gs._has_status(u, "fury"):
			gs.cast_fury(u, fury_spell)
		var swift_spell = _find_spell(gs, u, func(s): return s.get("kind") == "swift-feet")
		var used_swift_feet := false
		if swift_spell != null and u["mp"] >= swift_spell["mpCost"] and not gs._has_status(u, "swiftFeet"):
			var nearest_for_swift = pick_nearest_target(gs, u)
			if nearest_for_swift != null and gs.manhattan(u, nearest_for_swift) > u["moveRange"]:
				gs.cast_swift_feet(u, swift_spell)
				used_swift_feet = true
		var agility_spell = _find_spell(gs, u, func(s): return s.get("kind") == "haste-attack")
		if agility_spell != null and not used_swift_feet and u["mp"] >= agility_spell["mpCost"] and u.get("bonusAttacksRemaining", 0) == 0:
			gs.cast_agility(u, agility_spell)
		var evasive_spell = _find_spell(gs, u, func(s): return s.get("kind") == "evasive")
		if evasive_spell != null and u["mp"] >= evasive_spell["mpCost"] and not gs._has_status(u, "evasive"):
			gs.cast_evasive_maneuver(u, evasive_spell)
		var regen_spell = _find_spell(gs, u, func(s): return s.get("kind") == "regen-boost")
		if regen_spell != null and u["mp"] >= regen_spell["mpCost"] and u["hp"] < u["maxHp"] * 0.5 and not gs._has_status(u, "regenBoost"):
			gs.cast_regen_boost(u, regen_spell)

	if u.has("spells"):
		var resurrect_spell = _find_spell(gs, u, func(s): return s.get("kind") == "resurrect")
		if resurrect_spell != null and u["mp"] >= resurrect_spell["mpCost"]:
			var target = pick_resurrect_target(gs, u, resurrect_spell)
			if target != null:
				gs.cast_resurrect(u, target, resurrect_spell)
				gs.advance_to_next_turn()
				return
		var heal_spell = _find_spell(gs, u, func(s): return s.get("kind") == "heal-aoe")
		if heal_spell != null and u["mp"] >= heal_spell["mpCost"]:
			var spot = pick_best_heal_aoe_spot(gs, u, heal_spell)
			if spot != null:
				gs.cast_heal_aoe(u, heal_spell, spot)
				gs.advance_to_next_turn()
				return
		var regen_aoe_spell = _find_spell(gs, u, func(s): return s.get("kind") == "regen-aoe")
		if regen_aoe_spell != null and u["mp"] >= regen_aoe_spell["mpCost"]:
			var spot = pick_best_heal_aoe_spot(gs, u, regen_aoe_spell)
			if spot != null:
				gs.cast_regen_aoe(u, regen_aoe_spell, spot)
				gs.advance_to_next_turn()
				return

	if u.has("spells"):
		if u.get("spriteKey") == "fada":
			var windstorm_spell = _find_spell(gs, u, func(s): return s.get("kind") == "windstorm")
			if windstorm_spell != null and u["mp"] >= windstorm_spell["mpCost"]:
				var best = pick_best_safe_aoe_direction(gs, u, func(dx, dy): return gs.compute_cone_tiles_for_dir(u, dx, dy, windstorm_spell["maxRange"]))
				if best != null and best["enemyCount"] >= 2:
					gs.cast_windstorm(u, windstorm_spell, best["tiles"])
					gs.advance_to_next_turn()
					return
		if u.get("spriteKey") == "xama":
			var creep_spell = _find_spell(gs, u, func(s): return s.get("kind") == "creeping-line")
			if creep_spell != null and u["mp"] >= creep_spell["mpCost"]:
				var best = pick_best_safe_aoe_direction(gs, u, func(dx, dy):
					var probe := gs.body_probe_tile(u, dx, dy)
					if not gs.in_bounds(probe["x"], probe["y"]):
						return []
					return gs.compute_cardinal_rect_tiles(u, probe, creep_spell["bandLength"], creep_spell["bandWidth"])
				)
				if best != null and best["enemyCount"] >= 2:
					var target_tile := gs.body_probe_tile(u, best["dx"], best["dy"])
					gs.cast_creeping_destruction(u, creep_spell, target_tile)
					gs.advance_to_next_turn()
					return

	var target = pick_nearest_target(gs, u)
	if target == null:
		gs.advance_to_next_turn()
		return
	if u.get("spriteKey", "") in ["spd_rat", "spd_snake", "spd_gnoll", "spd_slime"] and _enemy_use_creature_action(gs, u, target):
		return

	# Habilidades próprias dos habitantes dos novos andares.
	if u.get("spriteKey", "") == "tower_living_fire":
		var self_destruct = _find_spell(gs, u, func(s): return s.get("kind", "") == "living-fire-self-destruct")
		var chance := gs.living_fire_self_destruct_chance(int(u["hp"]))
		if self_destruct != null and gs._count_enemies_in_special_area(u) > 0 and gs.rng.randf() < chance:
			gs.cast_living_fire_self_destruct(u, self_destruct)
			gs.advance_to_next_turn()
			return
	if u.get("spriteKey", "") == "tower_salamander":
		var explosion = _find_spell(gs, u, func(s): return s.get("kind", "") == "growth-attack")
		var flame_wave = _find_spell(gs, u, func(s): return s.get("kind", "") == "salamander-flame-wave")
		var adjacent_count := 0
		for d in [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]]:
			var adjacent = gs.unit_at(int(u["x"]) + d[0], int(u["y"]) + d[1])
			if adjacent != null and adjacent["team"] != u["team"]: adjacent_count += 1
		var best_wave = null
		if flame_wave != null and u["mp"] >= flame_wave["mpCost"]:
			best_wave = pick_best_safe_aoe_direction(gs, u, func(dx, dy):
				var probe := gs.body_probe_tile(u, dx, dy)
				if not gs.in_bounds(probe["x"], probe["y"]): return []
				return gs.compute_cardinal_rect_tiles(u, probe, flame_wave["bandLength"], flame_wave["bandWidth"])
			)
		# A faixa vale 3 pontos por alvo; a explosão local, 2. Empates
		# favorecem a opção barata, conservando MP de forma intencional.
		var wave_count: int = int(best_wave.get("enemyCount", 0)) if best_wave != null else 0
		if wave_count > 0 and wave_count * 3 > adjacent_count * 2:
			var wave_target := gs.body_probe_tile(u, best_wave["dx"], best_wave["dy"])
			gs.cast_salamander_flame_wave(u, flame_wave, wave_target)
			gs.advance_to_next_turn()
			return
		if explosion != null and u["mp"] >= explosion["mpCost"] and adjacent_count > 0:
			gs.cast_growth_attack(u, explosion)
			gs.advance_to_next_turn()
			return
	if u.get("spriteKey", "") == "tower_lava_human":
		# Pancada de Fogo agora é arma (ver dungeon_monster_data:"lava_human"),
		# não magia — _find_weapon no lugar de _find_spell.
		var fire_area = _find_weapon(gs, u, func(s): return s.get("kind", "") == "fire-self-area")
		if fire_area != null and gs._count_enemies_in_special_area(u) > 0:
			gs.cast_fire_self_area(u, fire_area)
			gs.advance_to_next_turn()
			return
		var fire_cone = _find_spell(gs, u, func(s): return s.get("kind", "") == "cone-fire")
		if fire_cone != null and u["mp"] >= fire_cone["mpCost"]:
			var best_fire_cone = pick_best_cone_direction(gs, u, fire_cone)
			if best_fire_cone != null:
				gs.cast_fire_cone(u, fire_cone, best_fire_cone)
				gs.advance_to_next_turn()
				return
	if u.get("spriteKey", "") == "flame_demon":
		# Flecha de Fogo Penetrante: só prioriza quando pega 2+ inimigos
		# alinhados numa das 4 direções cardeais (pedido do usuário) — senão
		# cai pro fluxo genérico abaixo (Bola de Fogo em área/Garra/Raio de
		# Fogo via pick_weapon_for_distance).
		var pierce_spell = _find_spell(gs, u, func(s): return s.get("kind", "") == "fire-arrow-pierce")
		if pierce_spell != null and u["mp"] >= pierce_spell["mpCost"]:
			var best_pierce = pick_best_safe_aoe_direction(gs, u, func(dx, dy): return gs.compute_pierce_line_tiles(u, dx, dy, pierce_spell["maxRange"]))
			if best_pierce != null and best_pierce["enemyCount"] >= 2:
				var pierce_tile := gs.body_probe_tile(u, best_pierce["dx"], best_pierce["dy"])
				gs.cast_pierce_shot(u, pierce_spell, pierce_tile)
				gs.advance_to_next_turn()
				return
		var summon_spell = _find_spell(gs, u, func(s): return s.get("kind", "") == "summon-living-fire")
		if summon_spell != null and u["mp"] >= summon_spell["mpCost"] and _wants_to_summon_reinforcement(gs, u):
			var summon_spot = _summon_spot_in_range(gs, u, summon_spell)
			if summon_spot != null:
				gs.cast_summon_living_fire(u, summon_spell, summon_spot)
				gs.advance_to_next_turn()
				return
	# Vampiro: Virar Morcego é ação livre (não consome CT/turno, ver
	# cast_vampire_bat_form) — considerada uma PREPARAÇÃO antes da
	# ação/movimento normal, nunca a jogada principal do turno sozinha.
	# Rodar isso ANTES da checagem de Invocar Morcegos (abaixo) já implementa
	# "reservar MP pra transformação" de graça: o MP gasto aqui reduz o que
	# sobra pro summon_spell.get("mpCost") do bloco seguinte, sem precisar de
	# nenhuma lógica extra de orçamento. Mordida/Toque Vampírico não
	# precisam de bloco especial — são armas comuns, escolhidas por
	# pick_weapon_for_distance mais abaixo, igual qualquer outra unidade.
	if u.get("spriteKey", "") == "vampire":
		if _vampire_wants_bat_form(gs, u, target):
			var bat_spell = _find_spell(gs, u, func(s): return s.get("kind", "") == "vampire-bat-form")
			if bat_spell != null and u["mp"] >= bat_spell["mpCost"]:
				gs.cast_vampire_bat_form(u, bat_spell)
		var bat_summon_spell = _find_spell(gs, u, func(s): return s.get("kind", "") == "summon-vampire-bat")
		if bat_summon_spell != null and u["mp"] >= bat_summon_spell["mpCost"] and _wants_to_summon_reinforcement(gs, u):
			var bat_summon_spot = _summon_spot_in_range(gs, u, bat_summon_spell)
			if bat_summon_spot != null:
				gs.cast_summon_vampire_bat(u, bat_summon_spell, bat_summon_spot)
				gs.advance_to_next_turn()
				return

	# Lich: suporte/controle. Ordem de prioridade (pedido do usuário):
	# Reanimação (trazer de volta um aliado morto-vivo) > Infligir
	# Ferimentos como cura de emergência > Decaimento (quando pega 2+
	# alvos de valor) > Infligir Ferimentos como ataque > Invocar
	# Esqueleto/Zumbi (só se sobrar utilidade tática e MP) — Raio de
	# Decaimento nem precisa de bloco próprio, é só mais uma arma pra
	# pick_weapon_for_distance escolher no fluxo genérico logo abaixo.
	if u.get("spriteKey", "") == "lich":
		var reanimate_spell = _find_spell(gs, u, func(s): return s.get("kind", "") == "reanimate")
		if reanimate_spell != null and u["mp"] >= reanimate_spell["mpCost"]:
			var reanimate_target = pick_resurrect_target(gs, u, reanimate_spell, true)
			if reanimate_target != null:
				gs.cast_reanimate(u, reanimate_target, reanimate_spell)
				gs.advance_to_next_turn()
				return
		var wounds_spell = _find_spell(gs, u, func(s): return s.get("kind", "") == "inflict-wounds")
		if wounds_spell != null and u["mp"] >= wounds_spell["mpCost"]:
			var heal_target = _pick_inflict_wounds_heal_target(gs, u, wounds_spell)
			if heal_target != null:
				gs.cast_inflict_wounds(u, wounds_spell, {"x": heal_target["x"], "y": heal_target["y"]})
				gs.advance_to_next_turn()
				return
		var decay_spell = _find_spell(gs, u, func(s): return s.get("kind", "") == "decay-pulse")
		if decay_spell != null and u["mp"] >= decay_spell["mpCost"] and _decay_pulse_value(gs, u, decay_spell) >= 2:
			gs.cast_decay_pulse(u, decay_spell)
			gs.advance_to_next_turn()
			return
		if wounds_spell != null and u["mp"] >= wounds_spell["mpCost"]:
			var attack_spot = pick_best_blast_spot(gs, u, wounds_spell)
			if attack_spot != null:
				gs.cast_inflict_wounds(u, wounds_spell, attack_spot)
				gs.advance_to_next_turn()
				return
		var skeleton_spell = _find_spell(gs, u, func(s): return s.get("kind", "") == "summon-skeleton")
		var zombie_spell = _find_spell(gs, u, func(s): return s.get("kind", "") == "summon-zombie")
		var chosen_summon = skeleton_spell if (skeleton_spell != null and (zombie_spell == null or gs.rng.randf() < 0.5)) else zombie_spell
		if chosen_summon != null and u["mp"] >= chosen_summon["mpCost"] and _wants_to_summon_reinforcement(gs, u):
			var summon_spot3 = _summon_spot_in_range(gs, u, chosen_summon)
			if summon_spot3 != null:
				if chosen_summon["kind"] == "summon-skeleton":
					gs.cast_summon_skeleton(u, chosen_summon, summon_spot3)
				else:
					gs.cast_summon_zombie(u, chosen_summon, summon_spot3)
				gs.advance_to_next_turn()
				return

	# Dragão Vermelho: Cone de Fogo quando pega 2+ inimigos (mesma
	# pick_best_cone_direction já usada pela Lava Humana); Cauda em vez de
	# Garra quando o alvo adjacente está com CT alto (perto de agir — o
	# efeito -30 CT vale mais nesse momento, pedido do usuário). Sem essa
	# checagem explícita, pick_weapon_for_distance (mais abaixo) nunca
	# escolheria Cauda sozinha: Garra/Cauda têm a mesma chance de acerto
	# (80%) e Garra vem primeiro no array de armas.
	if u.get("spriteKey", "") == "dragon":
		var fire_cone_spell = _find_spell(gs, u, func(s): return s.get("kind", "") == "cone-fire")
		if fire_cone_spell != null and u["mp"] >= fire_cone_spell["mpCost"]:
			var best_cone = pick_best_cone_direction(gs, u, fire_cone_spell)
			if best_cone != null:
				var enemy_count_in_cone := 0
				for t in best_cone:
					var occ = gs.unit_at(t["x"], t["y"])
					if occ != null and occ["team"] != u["team"]:
						enemy_count_in_cone += 1
				if enemy_count_in_cone >= 2:
					gs.cast_fire_cone(u, fire_cone_spell, best_cone)
					gs.advance_to_next_turn()
					return
		if target != null and gs.manhattan(u, target) <= 1 and int(target.get("ct", 0)) >= 70:
			var tail_weapon = null
			for w in u["weapons"]:
				if w["name"] == "Cauda":
					tail_weapon = w
					break
			if tail_weapon != null:
				enemy_attack_then_advance(gs, u, target, tail_weapon)
				return

	if u.has("spells"):
		var root_spell = _find_spell(gs, u, func(s): return s.get("kind") == "root")
		if root_spell != null and u["mp"] >= root_spell["mpCost"] and not gs.is_rooted(target) and gs.is_in_weapon_range(root_spell, gs.manhattan(u, target)):
			gs.cast_root_spell(u, target, root_spell)
			gs.advance_to_next_turn()
			return

		var blast_spell = null
		for s in u["spells"]:
			if s.get("targetMode") == "point-aoe" and u["mp"] >= s["mpCost"]:
				blast_spell = s
				break
		if blast_spell != null:
			var spot = pick_best_blast_spot(gs, u, blast_spell)
			if spot != null:
				gs.cast_fireball(u, blast_spell, spot)
				gs.advance_to_next_turn()
				return

		var freeze_spell = _find_spell(gs, u, func(s): return s.get("kind") == "freeze-aoe")
		if freeze_spell != null and u["mp"] >= freeze_spell["mpCost"]:
			var spot = pick_best_freeze_target(gs, u, freeze_spell)
			if spot != null:
				gs.cast_freeze_aoe(u, freeze_spell, spot)
				gs.advance_to_next_turn()
				return

		var windstorm_spell2 = _find_spell(gs, u, func(s): return s.get("kind") == "windstorm")
		if windstorm_spell2 != null and u["mp"] >= windstorm_spell2["mpCost"]:
			# Corrigido: usava pick_best_cone_direction, que só conta quantos
			# INIMIGOS uma direção pega e ignora se ela também atravessa
			# aliados — diferente do bloco específico da Fada logo acima
			# (que usa pick_best_safe_aoe_direction). Esse era o caminho que
			# deixava a Ventania acertar o próprio time quando a direção
			# "limpa" de 2+ heróis não existia.
			var safe_windstorm = pick_best_safe_aoe_direction(gs, u, func(dx, dy): return gs.compute_cone_tiles_for_dir(u, dx, dy, windstorm_spell2["maxRange"]))
			var cone_tiles = safe_windstorm["tiles"] if safe_windstorm != null else null
			if cone_tiles != null:
				gs.cast_windstorm(u, windstorm_spell2, cone_tiles)
				gs.advance_to_next_turn()
				return

		var growth_spell = _find_spell(gs, u, func(s): return s.get("kind") == "growth-attack")
		if growth_spell != null and u["mp"] >= growth_spell["mpCost"]:
			var dirs8 = [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]
			var adjacent_enemy_count := 0
			for d in dirs8:
				var t := {"x": u["x"] + d[0], "y": u["y"] + d[1]}
				if not gs.in_bounds(t["x"], t["y"]):
					continue
				var occ = gs.unit_at(t["x"], t["y"])
				if occ != null and occ["team"] != u["team"]:
					adjacent_enemy_count += 1
			if adjacent_enemy_count >= 2:
				gs.cast_growth_attack(u, growth_spell)
				gs.advance_to_next_turn()
				return

		var cone_spell = _find_spell(gs, u, func(s): return s.get("kind") == "cone-poison")
		if cone_spell != null and u["mp"] >= cone_spell["mpCost"]:
			var cone_tiles = pick_best_cone_direction(gs, u, cone_spell)
			if cone_tiles != null:
				gs.cast_poison_cone(u, cone_spell, cone_tiles)
				gs.advance_to_next_turn()
				return

		var charge_spell = _find_spell(gs, u, func(s): return s.get("kind") == "charge")
		if charge_spell != null and u["mp"] >= charge_spell["mpCost"]:
			var charge_targets := gs.compute_charge_targets(u)
			if charge_targets.size() > 0:
				var chosen = charge_targets[0]
				for t in charge_targets:
					if gs.manhattan(t, target) < gs.manhattan(chosen, target):
						chosen = t
				var victim = gs.unit_at(chosen["x"], chosen["y"])
				gs.cast_charge(u, victim, charge_spell)
				gs.advance_to_next_turn()
				return

		var trample_spell = _find_spell(gs, u, func(s): return s.get("targetMode") == "trample")
		if trample_spell != null and u["mp"] >= trample_spell["mpCost"]:
			var dirs4 = [[1, 0], [-1, 0], [0, 1], [0, -1]]
			var best_dir = null
			var best_hits := 0
			for d in dirs4:
				var hits := 0
				for dist in range(1, trample_spell["maxRange"] + 1):
					var x: int = u["x"] + d[0] * dist
					var y: int = u["y"] + d[1] * dist
					if not gs.in_bounds(x, y):
						break
					var occ = gs.unit_at(x, y)
					if occ != null and occ["team"] == u["team"]:
						break
					if occ != null:
						hits += 1
				if hits > best_hits:
					best_hits = hits
					best_dir = d
			if best_dir != null:
				var tile := gs.body_probe_tile(u, best_dir[0], best_dir[1])
				gs.cast_trample(u, trample_spell, tile)
				gs.advance_to_next_turn()
				return

	var weapon_in_range = pick_weapon_for_distance(gs, gs.get_attack_options_against(u, target), gs.manhattan(u, target), target)

	var is_critically_hurt: bool = u["hp"] < u["maxHp"] * 0.5
	if is_critically_hurt and not gs.is_rooted(u):
		var reachable := gs.compute_reachable(u)
		var soul_tiles: Array = []
		for t in reachable:
			for s in gs.souls:
				if s["x"] == t["x"] and s["y"] == t["y"]:
					soul_tiles.append(t)
					break
		if soul_tiles.size() > 0:
			var soul_tile = null
			for t in soul_tiles:
				if pick_weapon_for_distance(gs, gs.get_attack_options_against(u, target), gs.manhattan(t, target), target) != null:
					soul_tile = t
					break
			if soul_tile == null:
				soul_tile = soul_tiles[0]
			gs.perform_move(u, soul_tile)
			var follow_up_weapon = pick_weapon_for_distance(gs, gs.get_attack_options_against(u, target), gs.manhattan(u, target), target)
			if follow_up_weapon != null and target["hp"] > 0:
				enemy_attack_then_advance(gs, u, target, follow_up_weapon)
			else:
				gs.advance_to_next_turn()
			return

	if weapon_in_range != null:
		enemy_attack_then_advance(gs, u, target, weapon_in_range)
		return

	if gs.is_rooted(u):
		gs._log("%s está preso pelas raízes e não pode se mover." % u["name"])
	else:
		var reachable := gs.compute_reachable(u)
		var wants_soul: bool = u["hp"] < u["maxHp"] or (u.has("maxMp") and u["mp"] < u["maxMp"])
		var soul_tile = null
		if wants_soul:
			var soul_tiles: Array = []
			for t in reachable:
				for s in gs.souls:
					if s["x"] == t["x"] and s["y"] == t["y"]:
						soul_tiles.append(t)
						break
			for t in soul_tiles:
				if pick_weapon_for_distance(gs, gs.get_attack_options(u), gs.manhattan(t, target), target) != null:
					soul_tile = t
					break
			if soul_tile == null and soul_tiles.size() > 0:
				soul_tile = soul_tiles[0]

		var survival_tile = null
		var own_team_alive_count: int = gs.team_units(u["team"]).filter(func(o): return o["hp"] > 0).size()
		if soul_tile == null and own_team_alive_count == 1:
			var home_structure = null
			for s in gs.structures:
				if s["team"] == u["team"] and not s["destroyed"]:
					home_structure = s
					break
			var already_home := false
			if home_structure != null:
				for t in (home_structure["tiles"] as Array):
					if t["x"] == u["x"] and t["y"] == u["y"]:
						already_home = true
						break
			if home_structure != null and not already_home:
				var occupant = gs.structure_occupant(home_structure)
				if occupant == null:
					var home_tiles: Array = []
					for t in reachable:
						for ht in (home_structure["tiles"] as Array):
							if ht["x"] == t["x"] and ht["y"] == t["y"]:
								home_tiles.append(t)
								break
					if home_tiles.size() > 0:
						for t in home_tiles:
							if pick_weapon_for_distance(gs, gs.get_attack_options(u), gs.manhattan(t, target), target) != null:
								survival_tile = t
								break
						if survival_tile == null:
							survival_tile = home_tiles[0]
					else:
						var tiles: Array = home_structure["tiles"]
						var anchor = tiles[4] if tiles.size() > 4 else tiles[0]
						var best_partial_dist: int = gs.manhattan(u, anchor)
						for t in reachable:
							var d: int = gs.manhattan(t, anchor)
							if d < best_partial_dist:
								best_partial_dist = d
								survival_tile = t

		var mountain_tile = null
		if soul_tile == null and survival_tile == null and (u.get("spriteKey") == "xama" or u.get("spriteKey") == "fada"):
			var mountain = null
			for s in gs.structures:
				if s["type"] == "mountain" and not s["destroyed"]:
					mountain = s
					break
			var already_in_mountain := false
			if mountain != null:
				for t in (mountain["tiles"] as Array):
					if t["x"] == u["x"] and t["y"] == u["y"]:
						already_in_mountain = true
						break
			if mountain != null and not already_in_mountain:
				var occupant = gs.structure_occupant(mountain)
				if occupant == null:
					var only_one_enemy_left: bool = gs.opposing_team_of(u).filter(func(o): return o["hp"] > 0).size() == 1
					var ally_low_hp := false
					for o in gs.team_units("enemy"):
						if o["name"] != u["name"] and o["hp"] > 0 and o["hp"] < o["maxHp"] * 0.4:
							ally_low_hp = true
							break
					var wants_mountain_often: bool = gs.rng.randf() < 0.35
					if only_one_enemy_left or ally_low_hp or wants_mountain_often:
						var mountain_tiles: Array = []
						for t in reachable:
							for mt in (mountain["tiles"] as Array):
								if mt["x"] == t["x"] and mt["y"] == t["y"]:
									mountain_tiles.append(t)
									break
						for t in mountain_tiles:
							if pick_weapon_for_distance(gs, gs.get_attack_options(u), gs.manhattan(t, target), target) != null:
								mountain_tile = t
								break
						if mountain_tile == null and mountain_tiles.size() > 0:
							mountain_tile = mountain_tiles[0]

		var best = soul_tile if soul_tile != null else (survival_tile if survival_tile != null else mountain_tile)
		if best == null:
			# Distância real de caminho (BFS ignorando parede/bloqueio) em vez de
			# Manhattan em linha reta — regressão da Horda: um monstro nascido
			# dentro do "bolso" da montanha, só com saída pela escada, tinha
			# Manhattan MENOR ficando parado perto da parede errada do que
			# desviando até a escada (que a princípio AUMENTA a distância em
			# linha reta), então nunca saía do lugar. BFS mede o desvio como
			# progresso de verdade.
			var path_dist := _walkable_path_distance_map(gs, target["x"], target["y"], u)
			var start_key := gs.tile_key(u["x"], u["y"])
			var best_dist: int = int(path_dist.get(start_key, gs.manhattan(u, target)))
			for t in reachable:
				var dist: int = int(path_dist.get(gs.tile_key(t["x"], t["y"]), gs.manhattan(t, target)))
				if dist < best_dist:
					best_dist = dist
					best = t

		if best != null:
			gs.perform_move(u, best)
		else:
			gs._log("%s não pôde se mover." % u["name"])

	var follow_up_weapon2 = pick_weapon_for_distance(gs, gs.get_attack_options(u), gs.manhattan(u, target), target)
	if follow_up_weapon2 != null and target["hp"] > 0:
		enemy_attack_then_advance(gs, u, target, follow_up_weapon2)
	else:
		gs.advance_to_next_turn()
