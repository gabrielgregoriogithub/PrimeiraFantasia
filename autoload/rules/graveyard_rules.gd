class_name GraveyardRules
extends RefCounted

## Cemiterio: mortos-vivos selvagens (terceiro time) e a mira do time neutro.
## Extraido de autoload/game_state.gd: todas as funcoes sao estaticas e recebem o
## estado (`gs`) como 1o argumento. A API publica continua em GameState, via
## wrappers de uma linha (mesmos nomes e assinaturas).

## A cada 10 turnos globais no Cemitério, 25% de chance de um morto-vivo
## aparecer num quadrado livre aleatório. Ele NÃO pertence a nenhum time
## (team "neutral"): ataca apenas o time mais próximo dele (ver
## opposing_team_of) e não segura vitória/derrota de ninguém. Os argumentos
## opcionais permitem testar sem RNG.
static func maybe_spawn_graveyard_undead(gs: GameState, chance_roll: float = -1.0, kind_roll: float = -1.0) -> Variant:
	if gs.scenario_id != ScenarioManager.CEMITERIO or gs.global_turn_count <= 0 or gs.global_turn_count % gs.GRAVEYARD_SPAWN_INTERVAL != 0:
		return null
	var rolled_chance := gs.rng.randf() if chance_roll < 0.0 else chance_roll
	if rolled_chance >= gs.GRAVEYARD_SPAWN_CHANCE:
		return null
	var kind := gs.graveyard_undead_kind_for_roll(gs.rng.randf() if kind_roll < 0.0 else kind_roll)
	var data: Dictionary = gs.dungeon_monster_data(kind, gs.graveyard_spawn_count + 1)
	var free_tiles: Array = []
	for y in gs.board_height:
		for x in gs.board_width:
			if gs.structure_at(x, y) == null and gs._can_unit_anchor_at(data, x, y):
				free_tiles.append({"x": x, "y": y})
	if free_tiles.is_empty():
		return null
	var tile: Dictionary = free_tiles[gs.rng.randi_range(0, free_tiles.size() - 1)]
	gs.graveyard_spawn_count += 1
	data["name"] = "%s do Cemitério %d" % [gs.GRAVEYARD_UNDEAD_NAMES[kind], gs.graveyard_spawn_count]
	data["team"] = "neutral"
	data["x"] = tile["x"]
	data["y"] = tile["y"]
	data["ct"] = gs.REINFORCEMENT_STARTING_CT
	var spawned := gs.spawn_unit(data["name"], data)
	gs._log("%s se ergue do cemitério, hostil a todos!" % spawned["name"])
	return spawned


## Alvos de uma unidade neutra: todos os vivos do time (jogador ou inimigo) da
## unidade viva mais próxima dela; o outro time nunca é atacado por ela.
static func _neutral_targets(gs: GameState, u: Dictionary) -> Array:
	var candidates: Array = gs.units.filter(func(o): return (o["team"] == "player" or o["team"] == "enemy") and o["hp"] > 0 and not o.get("caged", false) and o.get("mountedOn", "") == "")
	if candidates.is_empty():
		return []
	var nearest: Dictionary = candidates[0]
	for candidate in candidates:
		if gs.manhattan(u, candidate) < gs.manhattan(u, nearest):
			nearest = candidate
	return candidates.filter(func(o): return o["team"] == nearest["team"])
