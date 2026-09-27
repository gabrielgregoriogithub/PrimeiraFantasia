class_name MountRules
extends RefCounted

## Montaria (Vestruz): montar/desmontar, fila de turnos da dupla, queda do cavaleiro e as habilidades da Vestruz.
## Extraido de autoload/game_state.gd: todas as funcoes sao estaticas e recebem o
## estado (`gs`) como 1o argumento. A API publica continua em GameState, via
## wrappers de uma linha (mesmos nomes e assinaturas).

static func _unit_named(gs: GameState, unit_name: String) -> Variant:
	if unit_name == "":
		return null
	for candidate in gs.units:
		if candidate["name"] == unit_name:
			return candidate
	return null


static func mount_of(gs: GameState, rider: Dictionary) -> Variant:
	return _unit_named(gs, String(rider.get("mountedOn", "")))


static func rider_of(gs: GameState, mount: Dictionary) -> Variant:
	return _unit_named(gs, String(mount.get("riderName", "")))


## Dono do turno: o cavaleiro quando `u` é uma montaria carregando alguém;
## `u` mesmo em qualquer outro caso.
static func turn_owner(gs: GameState, u: Dictionary) -> Dictionary:
	var rider = rider_of(gs, u) if u.get("riderName", "") != "" else null
	return rider if rider != null else u


static func can_mount(gs: GameState, rider: Dictionary, mount: Dictionary) -> bool:
	return rider != mount and rider["hp"] > 0 and mount["hp"] > 0 \
		and rider["team"] == mount["team"] and mount.get("isMount", false) and not rider.get("isMount", false) \
		and rider.get("mountedOn", "") == "" and mount.get("riderName", "") == "" \
		and not rider.get("caged", false) and not gs.is_large_unit(rider) \
		and not gs.is_rooted(rider) \
		and gs.manhattan(rider, mount) == 1


static func mount_candidates(gs: GameState, rider: Dictionary) -> Array:
	return gs.units.filter(func(m): return can_mount(gs, rider, m))


static func mount_unit(gs: GameState, rider: Dictionary, mount: Dictionary) -> bool:
	if not can_mount(gs, rider, mount):
		return false
	gs.set_facing_towards(rider, {"x": mount["x"], "y": mount["y"]})
	rider["x"] = mount["x"]
	rider["y"] = mount["y"]
	rider["mountedOn"] = mount["name"]
	mount["riderName"] = rider["name"]
	# Sprite "idle montado" da dupla: pasta/arte do herói que está montado.
	mount["riderSpriteKey"] = String(rider.get("spriteKey", ""))
	mount["facing"] = (rider["facing"] as Dictionary).duplicate()
	# Subir na montaria é o deslocamento do cavaleiro neste turno.
	rider["hasMoved"] = true
	sync_mounts(gs)
	gs._log("%s monta na %s! A dupla passa a agir no turno de %s." % [rider["name"], mount["name"], rider["name"]])
	return true


## Quadrados livres e válidos ao redor (8 vizinhos) onde o cavaleiro pode descer.
static func dismount_tiles(gs: GameState, rider: Dictionary) -> Array:
	var result: Array = []
	if rider.get("mountedOn", "") == "":
		return result
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var x: int = int(rider["x"]) + dx
			var y: int = int(rider["y"]) + dy
			if gs.in_bounds(x, y) and gs.structure_at(x, y) == null and gs._can_unit_anchor_at(rider, x, y):
				result.append({"x": x, "y": y})
	return result


static func dismount_unit(gs: GameState, rider: Dictionary, tile: Dictionary) -> bool:
	var mount = mount_of(gs, rider)
	if mount == null or not dismount_tiles(gs, rider).any(func(t): return t["x"] == tile["x"] and t["y"] == tile["y"]):
		return false
	gs.set_facing_towards(rider, tile)
	rider["x"] = tile["x"]
	rider["y"] = tile["y"]
	rider["mountedOn"] = ""
	mount["riderName"] = ""
	mount["riderSpriteKey"] = ""
	# A Vestruz volta a ter turno próprio, no mesmo ponto de CT do cavaleiro.
	mount["ct"] = int(rider["ct"])
	rider["hasMoved"] = true
	sync_mounts(gs)
	gs._log("%s desmonta da %s em (%d, %d)." % [rider["name"], mount["name"], tile["x"], tile["y"]])
	return true


## Mantém cavaleiro e montaria no mesmo quadrado/direção e limpa vínculos órfãos.
static func sync_mounts(gs: GameState) -> void:
	for mount in gs.units:
		if mount.get("riderName", "") == "":
			continue
		var rider = rider_of(gs, mount)
		if rider == null or rider["hp"] <= 0:
			mount["riderName"] = ""
			mount["riderSpriteKey"] = ""
			if rider != null:
				rider["mountedOn"] = ""
			continue
		rider["x"] = mount["x"]
		rider["y"] = mount["y"]
		rider["facing"] = (mount["facing"] as Dictionary).duplicate()


## Quadrado livre e válido MAIS PRÓXIMO de `origin` (adjacentes primeiro, depois
## anéis maiores), nunca o próprio `origin` nem um ocupado.
static func _nearest_fall_tile(gs: GameState, rider: Dictionary, origin: Dictionary) -> Variant:
	for radius in range(1, maxi(gs.board_width, gs.board_height)):
		var ring: Array = []
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) == radius:
					ring.append({"x": int(origin["x"]) + dx, "y": int(origin["y"]) + dy, "d": absi(dx) + absi(dy)})
		ring.sort_custom(func(a, b): return a["d"] < b["d"])
		for tile in ring:
			if gs.in_bounds(tile["x"], tile["y"]) and gs.structure_at(tile["x"], tile["y"]) == null and gs._can_unit_anchor_at(rider, tile["x"], tile["y"]):
				return {"x": tile["x"], "y": tile["y"]}
	return null


## A montaria morreu com alguém montado: o cavaleiro cai no quadrado livre
## mais próximo, sofre 2-5 de dano de queda e volta a agir sozinho.
static func _release_rider_on_mount_death(gs: GameState, mount: Dictionary) -> void:
	var rider = rider_of(gs, mount)
	mount["riderName"] = ""
	mount["riderSpriteKey"] = ""
	if rider == null:
		return
	rider["mountedOn"] = ""
	var spot = _nearest_fall_tile(gs, rider, {"x": mount["x"], "y": mount["y"]})
	if spot != null:
		rider["x"] = spot["x"]
		rider["y"] = spot["y"]
	var fall_damage: int = gs.rng.randi_range(gs.MOUNT_FALL_DAMAGE_MIN, gs.MOUNT_FALL_DAMAGE_MAX)
	rider["hp"] = maxi(0, int(rider["hp"]) - fall_damage)
	gs._log("%s cai da %s e sofre %d de dano de queda!" % [rider["name"], mount["name"], fall_damage])
	if rider["hp"] <= 0:
		gs._log("%s foi derrotado!" % rider["name"])


## Disparada (Vestruz): destinos possíveis — até `reach` quadrados em linha
## reta cardeal por espaços livres (pára em qualquer ocupante/corpo, terreno
## bloqueante ou estrutura).
static func compute_vestruz_dash_tiles(gs: GameState, u: Dictionary, item: Dictionary) -> Array:
	var tiles: Array = []
	var owner_unit := turn_owner(gs, u)
	if gs.is_rooted(owner_unit) or owner_unit.get("cannotMoveThisTurn", false):
		return tiles
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		for dist in range(1, int(item.get("reach", 4)) + 1):
			var x: int = int(u["x"]) + d[0] * dist
			var y: int = int(u["y"]) + d[1] * dist
			if not gs.in_bounds(x, y) or gs.occupant_at(x, y) != null:
				break
			if gs._terrain_blocks_transit(gs.terrain_at(x, y), u) or gs.structure_at(x, y) != null:
				break
			if gs._can_unit_anchor_at(u, x, y):
				tiles.append({"x": x, "y": y})
	return tiles


static func cast_vestruz_dash(gs: GameState, caster: Dictionary, item: Dictionary, dest: Dictionary) -> bool:
	if not compute_vestruz_dash_tiles(gs, caster, item).any(func(t): return t["x"] == dest["x"] and t["y"] == dest["y"]):
		gs._log("%s não consegue correr até lá." % caster["name"])
		return false
	var dx: int = gs._signi(int(dest["x"]) - int(caster["x"]))
	var dy: int = gs._signi(int(dest["y"]) - int(caster["y"]))
	var steps: int = maxi(absi(int(dest["x"]) - int(caster["x"])), absi(int(dest["y"]) - int(caster["y"])))
	var path: Array = []
	for step in range(1, steps + 1):
		path.append({"x": int(caster["x"]) + dx * step, "y": int(caster["y"]) + dy * step})
	var dash_owner := turn_owner(gs, caster)
	dash_owner["hasMoved"] = true
	caster["x"] = dest["x"]
	caster["y"] = dest["y"]
	caster["facing"] = {"dx": dx, "dy": dy}
	sync_mounts(gs)
	gs.apply_trap_crossings(caster, path)
	gs._log("%s dispara %d quadrado(s)%s!" % [caster["name"], steps, " levando %s junto" % caster["riderName"] if caster.get("riderName", "") != "" else ""])
	# Trombada: o inimigo adjacente da frente tem prioridade; senão, qualquer outro adjacente.
	var bump_target = null
	var ahead = gs.unit_at(int(dest["x"]) + dx, int(dest["y"]) + dy)
	if ahead != null and ahead["team"] != caster["team"] and ahead["hp"] > 0:
		bump_target = ahead
	else:
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var neighbor = gs.unit_at(int(dest["x"]) + d[0], int(dest["y"]) + d[1])
			if neighbor != null and neighbor["team"] != caster["team"] and neighbor["hp"] > 0:
				bump_target = neighbor
				break
	if bump_target != null:
		gs._log("%s dá uma trombada em %s!" % [caster["name"], bump_target["name"]])
		gs.set_facing_towards(caster, bump_target)
		gs.resolve_single_hit(caster, bump_target, item)
	gs.finalize_action(caster, item)
	return true


## Nuvem de Poeira (Vestruz): área 3x3 centrada nela; todo inimigo atingido
## perde 20 p.p. de acerto por 1 turno (status dustBlind, ver breakdown).
static func cast_dust_cloud(gs: GameState, caster: Dictionary, item: Dictionary) -> void:
	gs.record_area_action(caster, item, {"x": caster["x"], "y": caster["y"]})
	var tiles = gs.compute_aoe_area_tiles(caster, item, {"x": caster["x"], "y": caster["y"]})
	var hit_units: Array = gs.units_in_tiles(tiles).filter(func(t): return t["team"] != caster["team"] and t["hp"] > 0)
	gs._log("%s levanta uma Nuvem de Poeira 3x3." % caster["name"])
	if hit_units.is_empty():
		gs._log("Não havia nenhum inimigo na nuvem.")
	for target in hit_units:
		gs._replace_timed_status(target, {"type": "dustBlind", "turnsLeft": 1, "amount": float(item.get("accuracyDown", 0.2))})
		gs._log("%s fica com poeira nos olhos: -%d pontos percentuais de acerto por 1 turno!" % [target["name"], roundi(float(item.get("accuracyDown", 0.2)) * 100.0)])
	gs.finalize_action(caster, item)


## Cura da Vestruz: o MESMO efeito da Poção de Cura do Químico (resolve_heal),
## só nela (e no cavaleiro montado) e nos aliados dos 4 cardeais adjacentes.
static func cast_vestruz_heal(gs: GameState, caster: Dictionary, item: Dictionary) -> void:
	gs.record_area_action(caster, item, {"x": caster["x"], "y": caster["y"]})
	var tiles = gs.compute_aoe_area_tiles(caster, item, {"x": caster["x"], "y": caster["y"]})
	var targets: Array = gs.units_in_tiles(tiles).filter(func(t): return t["team"] == caster["team"] and t["hp"] > 0)
	var rider = rider_of(gs, caster) if caster.get("riderName", "") != "" else null
	if rider != null and not targets.has(rider):
		targets.append(rider)
	for target in targets:
		gs.resolve_heal(caster, target, item)
	gs.finalize_action(caster, item)
