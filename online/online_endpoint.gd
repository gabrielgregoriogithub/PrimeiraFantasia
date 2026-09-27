extends Node

signal connection_changed(connected: bool, text: String)
signal lobby_updated(payload: Dictionary)
signal match_started(payload: Dictionary)
signal snapshot_received(payload: Dictionary)
signal action_rejected(reason: String)
signal server_error(reason: String)

const PROTOCOL_VERSION := 1
var _server_mode := false
var _socket: WebSocketMultiplayerPeer
var _room_code := ""
var _slot := 0
var _connected := false
var _pending_messages: Array[Dictionary] = []
var _server_url := ""

func _ready() -> void:
	if not _server_mode:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func start_server(port: int = 9080) -> Error:
	_server_mode = true
	_socket = WebSocketMultiplayerPeer.new()
	var err := _socket.create_server(port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = _socket
	multiplayer.peer_connected.connect(_on_server_peer_connected)
	multiplayer.peer_disconnected.connect(_on_server_peer_disconnected)
	return OK

func connect_to_server(url: String = OnlineConfig.server_url()) -> Error:
	_server_mode = false
	_server_url = url
	_socket = WebSocketMultiplayerPeer.new()
	var err := _socket.create_client(url)
	if err != OK:
		connection_changed.emit(false, "Não foi possível conectar ao servidor.")
		return err
	multiplayer.multiplayer_peer = _socket
	connection_changed.emit(false, "Conectando ao servidor…")
	return OK

func create_room() -> void:
	_send({"type": "create_room", "protocol": PROTOCOL_VERSION})

func join_room(code: String) -> void:
	_room_code = code.strip_edges().to_upper()
	_send({"type": "join_room", "room": _room_code, "protocol": PROTOCOL_VERSION})

func submit_roster(hero_keys: Array, monster_keys: Array = [], scenario_id: String = "field") -> void:
	_send({"type": "roster", "room": _room_code, "heroes": hero_keys, "monsters": monster_keys, "scenario": scenario_id})

func set_ready(ready: bool) -> void:
	_send({"type": "ready", "room": _room_code, "ready": ready})

func send_action(action: Dictionary) -> void:
	var command := action.duplicate(true)
	command["type"] = "action"
	command["room"] = _room_code
	_send(command)

func room_code() -> String:
	return _room_code

func slot() -> int:
	return _slot

func is_connected_to_server() -> bool:
	return _connected

func _send(payload: Dictionary) -> void:
	if multiplayer.multiplayer_peer == null:
		server_error.emit("Transporte online não está conectado.")
		return
	if _server_mode:
		return
	if not _connected and payload.get("type", "") not in ["hello"]:
		_pending_messages.append(payload.duplicate(true))
		return
	_message.rpc_id(1, payload)

@rpc("any_peer", "call_remote", "reliable")
func _message(payload: Dictionary) -> void:
	if _server_mode:
		_server_message(multiplayer.get_remote_sender_id(), payload)
		return
	_client_message(payload)

func _on_peer_connected(peer_id: int) -> void:
	if peer_id == 1:
		_connected = true
		connection_changed.emit(true, "Conectado ao servidor.")
		_send({"type": "hello", "protocol": PROTOCOL_VERSION})
		if not _room_code.is_empty():
			_send({"type": "join_room", "room": _room_code, "protocol": PROTOCOL_VERSION})
		for pending in _pending_messages:
			_message.rpc_id(1, pending)
		_pending_messages.clear()

func _on_server_disconnected() -> void:
	_connected = false
	connection_changed.emit(false, "Conexão perdida. Tentando retornar…")
	if not _server_url.is_empty():
		get_tree().create_timer(2.0).timeout.connect(func():
			if not _connected: connect_to_server(_server_url)
		)

func _client_message(payload: Dictionary) -> void:
	match String(payload.get("type", "")):
		"room_created", "room_joined":
			_room_code = String(payload.get("room", ""))
			_slot = int(payload.get("slot", 0))
			lobby_updated.emit(payload)
		"lobby": lobby_updated.emit(payload)
		"match_started": match_started.emit(payload)
		"snapshot": snapshot_received.emit(payload)
		"action_rejected": action_rejected.emit(String(payload.get("reason", "Ação recusada.")))
		"error": server_error.emit(String(payload.get("reason", "Erro no servidor.")))

## Os métodos abaixo pertencem ao servidor, mas ficam no mesmo endpoint para
## manter o protocolo RPC idêntico no cliente Web e no processo headless.
var _rooms: Dictionary = {}
var _peer_rooms: Dictionary = {}
var _room_counter := 0
var _scenario_manager: ScenarioManager

func _on_server_peer_connected(peer_id: int) -> void:
	_peer_rooms[peer_id] = ""

func _on_server_peer_disconnected(peer_id: int) -> void:
	var room := String(_peer_rooms.get(peer_id, ""))
	if room.is_empty() or not _rooms.has(room):
		return
	var data: Dictionary = _rooms[room]
	if data["players"].has(peer_id):
		data["players"][peer_id]["connected"] = false
		data["players"][peer_id]["disconnected_at"] = Time.get_ticks_msec()
	_broadcast_lobby(room)

func _server_message(peer_id: int, payload: Dictionary) -> void:
	match String(payload.get("type", "")):
		"hello":
			_send_to(peer_id, {"type": "hello_ack", "protocol": PROTOCOL_VERSION})
		"create_room": _server_create_room(peer_id)
		"join_room": _server_join_room(peer_id, String(payload.get("room", "")))
		"roster": _server_roster(peer_id, payload)
		"ready": _server_ready(peer_id, bool(payload.get("ready", false)))
		"action": _server_action(peer_id, payload)

func _ensure_scenario_manager() -> ScenarioManager:
	if _scenario_manager == null:
		_scenario_manager = ScenarioManager.new()
		add_child(_scenario_manager)
	return _scenario_manager

func _server_create_room(peer_id: int) -> void:
	var code := _new_room_code()
	var players := {}
	players[peer_id] = {"slot": 1, "connected": true, "ready": false, "heroes": Units.player_team_keys().slice(0, 5), "monsters": [], "scenario": ScenarioManager.FIELD, "disconnected_at": 0}
	_rooms[code] = {"players": players, "state": null, "started": false}
	_peer_rooms[peer_id] = code
	_send_to(peer_id, {"type": "room_created", "room": code, "slot": 1})
	_broadcast_lobby(code)

func _server_join_room(peer_id: int, code: String) -> void:
	code = code.strip_edges().to_upper()
	if not _rooms.has(code):
		_send_to(peer_id, {"type": "error", "reason": "Sala não encontrada ou expirada."})
		return
	var data: Dictionary = _rooms[code]
	var reclaimed_slot := 0
	var reclaimed_peer := 0
	if data["players"].size() >= 2:
		for old_peer in data["players"]:
			if not data["players"][old_peer]["connected"]:
				reclaimed_slot = int(data["players"][old_peer]["slot"])
				reclaimed_peer = old_peer
				break
		if reclaimed_slot == 0:
			_send_to(peer_id, {"type": "error", "reason": "Esta sala já tem dois jogadores."})
			return
		data["players"].erase(reclaimed_peer)
	var slot := reclaimed_slot if reclaimed_slot > 0 else 2
	data["players"][peer_id] = {"slot": slot, "connected": true, "ready": false, "heroes": Units.player_team_keys().slice(0, 5) if slot == 1 else [], "monsters": [] if slot == 1 else Units.enemy_team_keys().slice(0, 5), "scenario": ScenarioManager.FIELD, "disconnected_at": 0}
	_peer_rooms[peer_id] = code
	_send_to(peer_id, {"type": "room_joined", "room": code, "slot": slot})
	_broadcast_lobby(code)

func _server_roster(peer_id: int, payload: Dictionary) -> void:
	var room := String(_peer_rooms.get(peer_id, ""))
	if room.is_empty() or not _rooms.has(room): return
	var player: Dictionary = _rooms[room]["players"].get(peer_id, {})
	if player.is_empty(): return
	if not payload.get("heroes", []).is_empty(): player["heroes"] = payload["heroes"].duplicate()
	if not payload.get("monsters", []).is_empty(): player["monsters"] = payload["monsters"].duplicate()
	player["scenario"] = String(payload.get("scenario", player.get("scenario", ScenarioManager.FIELD)))
	_broadcast_lobby(room)

func _server_ready(peer_id: int, ready: bool) -> void:
	var room := String(_peer_rooms.get(peer_id, ""))
	if room.is_empty() or not _rooms.has(room): return
	var player: Dictionary = _rooms[room]["players"].get(peer_id, {})
	if player.is_empty(): return
	player["ready"] = ready
	_broadcast_lobby(room)
	var players: Dictionary = _rooms[room]["players"]
	if players.size() == 2 and players.values().all(func(p): return p["ready"]):
		_start_room(room)

func _start_room(room: String) -> void:
	var data: Dictionary = _rooms[room]
	var by_slot := {}
	for player in data["players"].values(): by_slot[player["slot"]] = player
	var scenario_id := String(by_slot[1].get("scenario", ScenarioManager.FIELD))
	var definition := ScenarioManager.definition(scenario_id)
	var state := GameState.new()
	state.rng.seed = abs(hash(room))
	state.apply_pvp_scenario(definition, by_slot[1]["heroes"], by_slot[2]["monsters"])
	data["state"] = state
	data["started"] = true
	var snapshot := _snapshot(state)
	for peer_id in data["players"]:
		_send_to(peer_id, {"type": "match_started", "room": room, "slot": data["players"][peer_id]["slot"], "scenario": scenario_id, "heroes": by_slot[1]["heroes"], "monsters": by_slot[2]["monsters"], "snapshot": snapshot})

func _server_action(peer_id: int, payload: Dictionary) -> void:
	var room := String(_peer_rooms.get(peer_id, ""))
	if room.is_empty() or not _rooms.has(room): return
	var data: Dictionary = _rooms[room]
	if not data["started"] or data["state"] == null:
		_reject(peer_id, "A partida ainda não começou."); return
	var state: GameState = data["state"]
	var slot := int(data["players"][peer_id]["slot"])
	var actor: Dictionary = state.current_actor
	if actor == null or _slot_for_team(actor["team"]) != slot:
		_reject(peer_id, "Não é o seu turno."); return
	var ok := _resolve_action(state, payload)
	if not ok:
		_reject(peer_id, "Ação inválida ou não suportada neste estado."); return
	if state.check_battle_outcome(): pass
	else:
		var owner: Dictionary = state.current_actor
		if owner != null and (owner.get("hasMoved", false) or state.is_rooted(owner)) and owner.get("hasActed", false):
			state.advance_to_next_turn()
	for peer in data["players"]: _send_to(peer, {"type": "snapshot", "snapshot": _snapshot(state)})

func _resolve_action(state: GameState, payload: Dictionary) -> bool:
	var actor_name := String(payload.get("actor", ""))
	var actor = state.units_by_key.get(actor_name, null)
	if actor == null: actor = state.units.filter(func(u): return u.get("name", "") == actor_name)[0] if state.units.any(func(u): return u.get("name", "") == actor_name) else null
	if actor == null or actor != state.current_actor: return false
	var kind := String(payload.get("action", ""))
	var target := {"x": int(payload.get("x", -999)), "y": int(payload.get("y", -999))}
	match kind:
		"move":
			if not state.compute_reachable(actor).any(func(t): return t["x"] == target["x"] and t["y"] == target["y"]): return false
			state.perform_move(actor, target); return true
		"attack":
			var defender = state.unit_at(target["x"], target["y"])
			if defender == null or not _item_belongs_to_actor(state, actor, payload.get("item", {})): return false
			state.perform_attack(actor, defender, payload.get("item", {})); return true
		"mount":
			var mount = state.unit_at(target["x"], target["y"])
			return mount != null and state.mount_unit(actor, mount)
		"dismount": return state.dismount_unit(actor, target)
		"end_turn", "wait": state.advance_to_next_turn(); return true
		"facing": state.set_facing_towards(actor, target); state.advance_to_next_turn(); return true
		"spell":
			if not _item_belongs_to_actor(state, actor, payload.get("item", {})): return false
			return _resolve_spell(state, actor, payload.get("item", {}), target)
	return false

func _resolve_spell(state: GameState, actor: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	if item.is_empty(): return false
	var tm := String(item.get("targetMode", ""))
	match tm:
		"arrow-rain": state.cast_arrow_rain(actor, item, target)
		"self": state.cast_self_ability(actor, item)
		"self-attack": state.cast_growth_attack(actor, item)
		"cone-fire": state.cast_fire_cone(actor, item, state.compute_aoe_area_tiles(actor, item, target))
		"cure-aoe": state.cast_antidote(actor, item, state.compute_aoe_area_tiles(actor, item, target))
		"heal-aoe": state.cast_heal_aoe(actor, item, target)
		"regen-aoe": state.cast_regen_aoe(actor, item, target)
		"mana-aoe": state.cast_mana_aoe(actor, item, target)
		"point-aoe": state.cast_fireball(actor, item, target)
		"line-aoe": state.cast_lightning(actor, item, target)
		"freeze-aoe": state.cast_freeze_aoe(actor, item, target)
		"trap": state.cast_trap(actor, item, target)
		"cone-poison": state.cast_poison_cone(actor, item, state.compute_aoe_area_tiles(actor, item, target))
		"cone-windstorm": state.cast_windstorm(actor, item, state.compute_aoe_area_tiles(actor, item, target))
		"cone-ice": state.cast_ice_cone(actor, item, state.compute_aoe_area_tiles(actor, item, target))
		"pierce-line": state.cast_pierce_shot(actor, item, target)
		"creeping-line": state.cast_creeping_destruction(actor, item, target)
		"flame-creeping-line": state.cast_salamander_flame_wave(actor, item, target)
		"cardinal-blast": state.cast_throw_log(actor, item, target)
		"inflict-wounds": state.cast_inflict_wounds(actor, item, target)
		"reanimate":
			var reanimate_target = state.dead_unit_at(target["x"], target["y"])
			if reanimate_target == null: return false
			state.cast_reanimate(actor, reanimate_target, item)
		"root":
			var root_target = state.unit_at(target["x"], target["y"])
			if root_target == null: return false
			state.cast_root_spell(actor, root_target, item)
		"resurrect":
			var resurrect_target = state.dead_unit_at(target["x"], target["y"])
			if resurrect_target == null: return false
			state.cast_resurrect(actor, resurrect_target, item)
		"ally-clearpath":
			var ally_target = state.unit_at(target["x"], target["y"])
			if ally_target == null: return false
			state.cast_supply_item(actor, ally_target, item)
		"enemy":
			var enemy_target = state.unit_at(target["x"], target["y"])
			if enemy_target == null: return false
			state.perform_attack(actor, enemy_target, item)
		"reincarnation":
			var reincarnation_target = state.unit_at(target["x"], target["y"])
			if reincarnation_target == null: return false
			state.cast_reincarnation(actor, reincarnation_target, item)
		"summon":
			match String(item.get("kind", "")):
				"summon-living-fire": state.cast_summon_living_fire(actor, item, target)
				"summon-vampire-bat": state.cast_summon_vampire_bat(actor, item, target)
				"summon-skeleton": state.cast_summon_skeleton(actor, item, target)
				"summon-zombie": state.cast_summon_zombie(actor, item, target)
				_: return false
		"self-aoe":
			match String(item.get("kind", "")):
				"boss-poison": state.cast_black_slime_poison(actor)
				"decay-pulse": state.cast_decay_pulse(actor, item)
				_: return false
		"trample": state.cast_trample(actor, item, target)
		"charge":
			var charge_target = state.unit_at(target["x"], target["y"])
			if charge_target == null or not state.cast_charge(actor, charge_target, item): return false
		"slime-jump": state.cast_slime_jump(actor, item, target)
		"dust-square": state.cast_dust_cloud(actor, item)
		"heal-cross": state.cast_vestruz_heal(actor, item)
		"vestruz-dash":
			if not state.cast_vestruz_dash(actor, item, target): return false
		"iaijutsu":
			var iai_target = state.unit_at(target["x"], target["y"])
			if iai_target == null or not state.cast_iaijutsu(actor, iai_target, item): return false
		"crescent-arc": state.cast_crescent_slash(actor, item, target)
		"dragon-kick":
			if not state.cast_dragon_kick(actor, item, target): return false
		_:
			return false
	return true

func _item_belongs_to_actor(state: GameState, actor: Dictionary, item: Dictionary) -> bool:
	if item.is_empty(): return false
	var candidates: Array = []
	candidates.append_array(actor.get("weapons", []))
	candidates.append_array(actor.get("spells", []))
	var mount = state.mount_of(actor)
	if mount != null:
		candidates.append_array(mount.get("weapons", []))
		candidates.append_array(mount.get("spells", []))
	for candidate in candidates:
		if String(candidate.get("name", "")) == String(item.get("name", "")) and String(candidate.get("targetMode", "")) == String(item.get("targetMode", "")):
			return true
	return false

func _slot_for_team(team: String) -> int: return 1 if team == "player" else 2

func _new_room_code() -> String:
	var chars := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	while code.is_empty() or _rooms.has(code):
		code = ""
		for i in OnlineConfig.DEFAULT_ROOM_LENGTH: code += chars[randi() % chars.length()]
	return code

func _broadcast_lobby(room: String) -> void:
	var data: Dictionary = _rooms[room]
	var players := []
	for player in data["players"].values(): players.append({"slot": player["slot"], "connected": player["connected"], "ready": player["ready"]})
	for peer in data["players"]: _send_to(peer, {"type": "lobby", "room": room, "players": players, "started": data["started"]})

func _send_to(peer_id: int, payload: Dictionary) -> void: _message.rpc_id(peer_id, payload)
func _reject(peer_id: int, reason: String) -> void: _send_to(peer_id, {"type": "action_rejected", "reason": reason})

func _snapshot(state: GameState) -> Dictionary:
	return {"units": state.units.duplicate(true), "terrain_map": state.terrain_map.duplicate(true), "structures": state.structures.duplicate(true), "elevation_map": state.elevation_map.duplicate(true), "traps": state.traps.duplicate(true), "souls": state.souls.duplicate(true), "current_actor": state.current_actor.get("name", "") if state.current_actor != null else "", "turn_token": state.turn_token, "global_turn_count": state.global_turn_count, "battle_ended": state.battle_ended, "battle_won": state.battle_won, "event_log": state.event_log.duplicate(true), "scenario_id": state.scenario_id, "board_width": state.board_width, "board_height": state.board_height, "last_action_vfx": state.last_action_vfx.duplicate(true)}
