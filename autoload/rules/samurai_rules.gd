class_name SamuraiRules
extends RefCounted

## Samurai: Saque Rapido, Postura da Garca, Corte Iaijutsu, Corte Crescente e requisitos de uso de habilidades.
## Extraido de autoload/game_state.gd: todas as funcoes sao estaticas e recebem o
## estado (`gs`) como 1o argumento. A API publica continua em GameState, via
## wrappers de uma linha (mesmos nomes e assinaturas).

## Postura da Garça (Samurai): +25% de esquiva (entra em
## get_effective_hit_chance_breakdown) até o começo do PRÓXIMO turno do
## Samurai (turnsLeft 1, mesmo idioma do Foco/Pés Ágeis). Consome a ação do
## turno (ctCost 40, finalize_action).
static func cast_heron_stance(gs: GameState, caster: Dictionary, item: Dictionary) -> void:
	gs._replace_timed_status(caster, {
		"type": "heronStance", "turnsLeft": int(item.get("turns", 1)),
		"evasion": float(item.get("evasionBonus", 0.25)),
		"counterMin": int(item.get("counterMin", 5)), "counterMax": int(item.get("counterMax", 8)),
	})
	gs._log("%s assume a Postura da Garça: +%d%% de esquiva até o próximo turno e contra-ataca quem errar o golpe corpo a corpo." % [caster["name"], roundi(float(item.get("evasionBonus", 0.25)) * 100.0)])
	gs.finalize_action(caster, item)


## Contra-ataque da Postura da Garça. Só conta como ESQUIVA o erro que o bônus
## da postura causou: a mesma rolagem teria acertado sem ele (hit_roll caiu
## entre a chance com a postura e a chance sem ela). Só contra ataque corpo a
## corpo (alcance 1), nunca em cima de um contra-ataque, e o revide sempre
## acerta (a habilidade promete 5-8 de dano ao esquivar) sem poder ser crítico.
static func _try_heron_counter(gs: GameState, attacker: Dictionary, defender: Dictionary, item: Dictionary, hit_chance: Variant, hit_roll: float, is_counter_attack: bool) -> void:
	if is_counter_attack or hit_chance == null or gs.is_ranged_attack(item):
		return
	if int(defender.get("hp", 0)) <= 0 or int(attacker.get("hp", 0)) <= 0 or attacker["name"] == defender["name"]:
		return
	var stance = null
	for e in defender.get("statusEffects", []):
		if e.get("type", "") == "heronStance":
			stance = e
			break
	if stance == null or hit_roll >= float(hit_chance) + float(stance.get("evasion", 0.0)):
		return
	gs._log("%s esquiva do ataque de %s com a Postura da Garça e contra-ataca!" % [defender["name"], attacker["name"]])
	var counter := {
		"name": "Contra-ataque da Garça", "ctCost": 0,
		"damageMin": int(stance.get("counterMin", 5)), "damageMax": int(stance.get("counterMax", 8)),
		"critMultiplier": 1, "critChance": 0.0, "hitChance": 1.0,
		"minRange": 1, "maxRange": 1, "damageType": "physical", "swing": "slash",
	}
	gs.resolve_single_hit(defender, attacker, counter, true)


## Requisitos de uso de um golpe/habilidade (hoje só "requiresHpBelowRatio":
## Última Determinação exige HP abaixo de 40% do máximo, ou seja, 15 HP ou
## menos com HP 40). Única fonte da regra: a UI (main._spell_is_available) e
## o próprio perform_attack consultam esta função.
static func item_requirements_met(gs: GameState, u: Dictionary, item: Dictionary) -> bool:
	if item.has("requiresHpBelowRatio"):
		var limit: float = float(u.get("maxHp", 0)) * float(item["requiresHpBelowRatio"])
		if not (float(u.get("hp", 0)) < limit - 0.000001):
			return false
	return true


## Saque Rápido (Samurai): mesmo efeito do Tiro Certeiro (cast_true_shot) — o
## próximo ataque tem 100% de acerto e +crítico — mas exclusivo da espada (ver
## o bloco `quickDrawNextSword` em resolve_single_hit). O custo de MP/CT é o
## do próprio Tiro Certeiro (copiado em Spells.build()), então é ação livre.
static func cast_quick_draw(gs: GameState, caster: Dictionary, item: Dictionary) -> void:
	caster["quickDrawNextSword"] = true
	caster["quickDrawCritBonus"] = float(item.get("critBonus", 0.0))
	gs._log("%s usa %s: o próximo golpe de espada tem 100%% de acerto e +%d%% de crítico!" % [caster["name"], item["name"], roundi(float(item.get("critBonus", 0.0)) * 100.0)])
	if int(item.get("ctCost", 0)) > 0:
		gs.finalize_action(caster, item)
	else:
		gs.finish_free_self_action(caster, item)


## Casa por onde o Corte Iaijutsu pode passar: dentro do mapa, sem terreno
## bloqueante, sem ravina (a não ser voando), sem Castelo/Montanha e sem
## degrau de altura maior que o que o jogo já permite escalar.
static func _iaijutsu_step_open(gs: GameState, u: Dictionary, from_tile: Dictionary, x: int, y: int) -> bool:
	if not gs.in_bounds(x, y):
		return false
	var terrain = gs.terrain_at(x, y)
	if gs._terrain_blocks_unit(u, terrain):
		return false
	if terrain != null and terrain.get("type", "") == "desfiladeiro-chasm" and not u.get("flying", false):
		return false
	if gs.structure_at(x, y) != null:
		return false
	return absi(gs.elevation_at(x, y) - gs.elevation_at(int(from_tile["x"]), int(from_tile["y"]))) <= GameConstants.MAX_CLIMB_HEIGHT


## Alvos do Corte Iaijutsu: primeiro inimigo em cada uma das 4 direções, a até
## maxRange casas (avança até advanceMax = maxRange - 1 e corta colado). A
## corrida pára em obstáculo, em quem estiver na frente (aliado, inimigo que
## não seja o alvo, corpo) e em terreno/altura intransponíveis. Enraizado ou
## depois de Fingir de Morto só alcança quem já está colado.
static func compute_iaijutsu_targets(gs: GameState, u: Dictionary, item: Dictionary) -> Array:
	var max_dist: int = int(item.get("reach", item.get("maxRange", 3)))
	if gs.is_rooted(u) or u.get("cannotMoveThisTurn", false):
		max_dist = 1
	var targets: Array = []
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		var previous := {"x": int(u["x"]), "y": int(u["y"])}
		for dist in range(1, max_dist + 1):
			var x: int = int(u["x"]) + d[0] * dist
			var y: int = int(u["y"]) + d[1] * dist
			if not gs.in_bounds(x, y):
				break
			var occupant = gs.occupant_at(x, y)
			if occupant != null:
				if int(occupant.get("hp", 0)) > 0 and occupant["team"] != u["team"] and not gs.is_invisible(occupant):
					targets.append({"x": x, "y": y})
				break
			if not _iaijutsu_step_open(gs, u, previous, x, y):
				break
			previous = {"x": x, "y": y}
	return targets


## Todas as casas que o Corte Iaijutsu alcança (para MOSTRAR o alcance ao
## selecionar a habilidade, mesmo sem inimigo na linha): as casas por onde a
## corrida passa e, no fim de cada direção, o primeiro ocupante (alvo ou
## obstáculo). Mesma regra de parada de compute_iaijutsu_targets.
static func compute_iaijutsu_range_tiles(gs: GameState, u: Dictionary, item: Dictionary) -> Array:
	var max_dist: int = int(item.get("reach", item.get("maxRange", 3)))
	if gs.is_rooted(u) or u.get("cannotMoveThisTurn", false):
		max_dist = 1
	var tiles: Array = []
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		var previous := {"x": int(u["x"]), "y": int(u["y"])}
		for dist in range(1, max_dist + 1):
			var x: int = int(u["x"]) + d[0] * dist
			var y: int = int(u["y"]) + d[1] * dist
			if not gs.in_bounds(x, y):
				break
			if gs.occupant_at(x, y) != null:
				tiles.append({"x": x, "y": y})
				break
			if not _iaijutsu_step_open(gs, u, previous, x, y):
				break
			tiles.append({"x": x, "y": y})
			previous = {"x": x, "y": y}
	return tiles


## Corte Iaijutsu (Samurai): variação da Investida (cast_charge) — avança em
## linha reta até ficar colado no alvo e corta com a espada. Se o alvo ainda
## NÃO agiu nesta rodada (round_acted_units), o golpe ganha +20 pontos
## percentuais de crítico (critBonusNextAttack, consumido por
## resolve_single_hit). Conta como mover E atacar quando houve avanço.
static func cast_iaijutsu(gs: GameState, caster: Dictionary, target: Dictionary, item: Dictionary) -> bool:
	var dx: int = gs._signi(int(target["x"]) - int(caster["x"]))
	var dy: int = gs._signi(int(target["y"]) - int(caster["y"]))
	var previous_tile := {"x": caster["x"], "y": caster["y"]}
	var landing := {"x": int(target["x"]) - dx, "y": int(target["y"]) - dy}
	var advance: int = maxi(absi(int(landing["x"]) - int(caster["x"])), absi(int(landing["y"]) - int(caster["y"])))
	if advance > int(item.get("advanceMax", 2)):
		gs._log("%s está longe demais para o Corte Iaijutsu." % caster["name"])
		return false
	if advance > 0:
		if gs.occupant_at(landing["x"], landing["y"]) != null:
			gs._log("%s não pode executar o Corte Iaijutsu: o ponto de parada está ocupado." % caster["name"])
			return false
		var path: Array = []
		for step in range(1, advance + 1):
			path.append({"x": int(caster["x"]) + dx * step, "y": int(caster["y"]) + dy * step})
		caster["x"] = landing["x"]
		caster["y"] = landing["y"]
		caster["hasMoved"] = true
		gs.separate_living_unit_from_corpse(caster, previous_tile, dy, -dx)
		gs.apply_trap_crossings(caster, path)
		gs._log("%s avança %d quadrado(s) num Corte Iaijutsu contra %s!" % [caster["name"], advance, target["name"]])
	gs.set_facing_towards(caster, target)
	if caster["hp"] <= 0:
		return true
	if not gs.round_acted_units.has(target["name"]):
		caster["critBonusNextAttack"] = float(caster.get("critBonusNextAttack", 0.0)) + float(item.get("firstStrikeCritBonus", 0.0))
		gs._log("%s ainda não agiu nesta rodada: +%d pontos percentuais de crítico no golpe!" % [target["name"], roundi(float(item.get("firstStrikeCritBonus", 0.0)) * 100.0)])
	gs.resolve_single_hit(caster, target, item)
	gs.finalize_action(caster, item)
	return true


## Casas adjacentes (frente nas 4 direções) onde o jogador clica para escolher
## a direção do Corte Crescente.
static func compute_crescent_anchor_tiles(gs: GameState, u: Dictionary) -> Array:
	var result: Array = []
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		for lane in gs.body_lane_origins(u, d[0], d[1]):
			var x: int = int(lane["x"]) + d[0]
			var y: int = int(lane["y"]) + d[1]
			if gs.in_bounds(x, y):
				result.append({"x": x, "y": y})
	return result


## Arco do Corte Crescente: a casa da frente mais as duas ao lado dela
## (perpendiculares) — 3 quadrados, dentro do mapa.
static func compute_crescent_tiles_for_dir(gs: GameState, u: Dictionary, dx: int, dy: int) -> Array:
	var result: Array = []
	var seen := {}
	for lane in gs.body_lane_origins(u, dx, dy):
		var fx: int = int(lane["x"]) + dx
		var fy: int = int(lane["y"]) + dy
		for offset in [0, -1, 1]:
			var x: int = fx + (-dy * offset)
			var y: int = fy + (dx * offset)
			if gs.in_bounds(x, y) and not seen.has(gs.tile_key(x, y)):
				seen[gs.tile_key(x, y)] = true
				result.append({"x": x, "y": y})
	return result


## Corte Crescente (Samurai): golpe em arco que atinge até 3 inimigos nas
## casas à frente (cada um rola acerto/crítico/dano próprios). Aliados na
## área não são atingidos.
static func cast_crescent_slash(gs: GameState, caster: Dictionary, item: Dictionary, target_tile: Dictionary) -> void:
	gs.record_area_action(caster, item, target_tile)
	gs.set_facing_towards(caster, target_tile)
	var tiles = gs.compute_aoe_area_tiles(caster, item, target_tile)
	if tiles == null:
		tiles = []
	var hits: Array = gs.units_in_tiles(tiles).filter(func(t): return t["team"] != caster["team"] and int(t.get("hp", 0)) > 0)
	gs._log("%s desfere um %s em arco, cobrindo %d quadrado(s) à frente." % [caster["name"], item["name"], tiles.size()])
	if hits.is_empty():
		gs._log("Não havia nenhum inimigo no arco do %s." % item["name"])
	for target in hits:
		gs.resolve_single_hit(caster, target, item)
	gs.finalize_action(caster, item)

# --- Montaria (Vestruz) ------------------------------------------------------
# Modelo: quem monta ganha `mountedOn` (nome da montaria) e a montaria ganha
# `riderName`. Os dois ficam no MESMO quadrado (sync_mounts). Enquanto montado:
# o cavaleiro é o dono do turno (a montaria não entra na fila de CT), unit_at
# devolve a montaria, todo golpe recebido é redirecionado pra ela e o
# deslocamento usa o MOV/voo dela (compute_reachable/perform_move).
