extends GutTest

## Fluxo de entrada na sala online: abrir o link de convite deve entrar na
## sala (mesmo clicando em "Criar partida online") e o join_room não pode ser
## enviado duas vezes quando pedido antes da conexão abrir (o segundo voltava
## "Esta sala já tem dois jogadores." e parecia que a entrada tinha falhado).

const ENDPOINT_SCRIPT := preload("res://online/online_endpoint.gd")
const TEAM_A := ["guerreiro", "orc", "vampire", "rat", "mago"]
const TEAM_B := ["guerreiro", "goblin", "lich", "slime", "monge"]

func _endpoint() -> Node:
	var endpoint: Node = ENDPOINT_SCRIPT.new()
	add_child_autofree(endpoint)
	return endpoint

func test_join_before_connection_is_not_queued_twice() -> void:
	var endpoint := _endpoint()
	endpoint.join_room("abc123")
	assert_eq(endpoint.room_code(), "ABC123")
	# _on_peer_connected já envia join_room quando _room_code está definido;
	# uma cópia na fila de pendentes geraria um segundo join.
	assert_eq(endpoint._pending_messages.size(), 0)

func test_create_before_connection_is_still_queued() -> void:
	var endpoint := _endpoint()
	endpoint.create_room(TEAM_A, ScenarioManager.FIELD)
	assert_eq(endpoint._pending_messages.size(), 1)
	assert_eq(endpoint._pending_messages[0]["type"], "create_room")
	assert_eq(endpoint._pending_messages[0]["team"], TEAM_A)

func test_invite_link_forces_join_mode() -> void:
	assert_eq(OnlineLobby.resolve_mode("create", "ABC123"), "join")
	assert_eq(OnlineLobby.resolve_mode("join", "ABC123"), "join")

func test_without_invite_link_mode_is_kept() -> void:
	assert_eq(OnlineLobby.resolve_mode("create", ""), "create")
	assert_eq(OnlineLobby.resolve_mode("join", ""), "join")

## Servidor não encerra o turno sozinho depois de mover+agir: o jogador ainda
## escolhe a direção de fim de turno (ação "facing").
func _started_room(endpoint: Node) -> GameState:
	var state := GameState.new()
	state.apply_pvp_scenario(ScenarioManager.definition(ScenarioManager.FIELD), Units.player_team_keys().slice(0, 5), Units.enemy_team_keys().slice(0, 5))
	state.begin_turn_for(state.advance_ct_until_ready())
	endpoint._server_mode = true
	var slot := 1 if state.current_actor["team"] == "player" else 2
	endpoint._rooms["SALA01"] = {"players": {7: {"slot": slot, "connected": true, "ready": true}}, "state": state, "started": true}
	endpoint._peer_rooms[7] = "SALA01"
	return state

func test_server_keeps_turn_after_move_and_act_until_facing() -> void:
	var endpoint := _endpoint()
	var state := _started_room(endpoint)
	var actor: Dictionary = state.current_actor
	actor["hasActed"] = true
	var tile: Dictionary = state.compute_reachable(actor)[0]
	endpoint._server_action(7, {"action": "move", "actor": actor["name"], "x": tile["x"], "y": tile["y"]})
	assert_eq(state.current_actor, actor, "turno continua até o jogador escolher a direção")
	var turn_before := state.global_turn_count
	endpoint._server_action(7, {"action": "facing", "actor": actor["name"], "x": actor["x"], "y": actor["y"] - 1})
	assert_eq(actor["facing"], {"dx": 0, "dy": -1})
	assert_gt(state.global_turn_count, turn_before, "direção escolhida encerra o turno")

## Snapshots (~50 KB) vão comprimidos; mensagens pequenas seguem como estão.
func test_large_server_messages_are_compressed_and_restored() -> void:
	var endpoint := _endpoint()
	var big := {"type": "snapshot", "snapshot": {"event_log": range(3000).map(func(i): return "linha %d" % i)}}
	var packed: Dictionary = endpoint._pack_message(big)
	assert_true(packed.has("z"), "mensagem grande vai comprimida")
	assert_lt(var_to_bytes(packed).size(), var_to_bytes(big).size() / 3)
	assert_eq(endpoint._unpack_message(packed), big)
	var small := {"type": "error", "reason": "x"}
	assert_eq(endpoint._pack_message(small), small, "mensagem pequena não muda")
	assert_eq(endpoint._unpack_message(small), small)

# --- salas: criar, listar, entrar rápido, limpar -----------------------------

func _server() -> Node:
	var endpoint := _endpoint()
	endpoint._server_mode = true
	return endpoint

func test_create_room_stores_team_and_scenario_and_lists_it() -> void:
	var endpoint := _server()
	endpoint._server_create_room(11, TEAM_A, ScenarioManager.CEMITERIO)
	var rooms: Array = endpoint._open_rooms()
	assert_eq(rooms.size(), 1)
	assert_eq(rooms[0]["scenario"], ScenarioManager.CEMITERIO)
	assert_eq(rooms[0]["team"], TEAM_A)

func test_invalid_team_or_scenario_does_not_create_room() -> void:
	var endpoint := _server()
	endpoint._server_create_room(11, ["guerreiro"], ScenarioManager.FIELD)
	endpoint._server_create_room(12, ["guerreiro", "guerreiro", "orc", "rat", "mago"], ScenarioManager.FIELD)
	endpoint._server_create_room(13, ["hacker", "orc", "vampire", "rat", "mago"], ScenarioManager.FIELD)
	endpoint._server_create_room(14, TEAM_A, "nao_existe")
	assert_eq(endpoint._rooms.size(), 0)

func test_second_player_joining_starts_the_match_with_both_teams() -> void:
	var endpoint := _server()
	endpoint._server_create_room(11, TEAM_A, ScenarioManager.FIELD)
	var code: String = endpoint._open_rooms()[0]["room"]
	endpoint._server_join_room(22, code, TEAM_B)
	var data: Dictionary = endpoint._rooms[code]
	assert_true(data["started"], "partida começa sem etapa de 'pronto'")
	var state: GameState = data["state"]
	assert_eq(state.team_units("player").size(), 5)
	assert_eq(state.team_units("enemy").size(), 5)
	assert_true(state.units.any(func(u): return u["name"] == "Guerreiro 🔵"))
	assert_true(state.units.any(func(u): return u["name"] == "Guerreiro 🔴"))
	assert_eq(endpoint._open_rooms().size(), 0, "sala cheia sai da lista")

func test_join_any_enters_the_oldest_open_room() -> void:
	var endpoint := _server()
	endpoint._server_create_room(11, TEAM_A, ScenarioManager.FIELD)
	endpoint._server_create_room(12, TEAM_A, ScenarioManager.TEMPLO)
	var oldest: String = endpoint._open_rooms()[0]["room"]
	endpoint._server_join_any(33, TEAM_B)
	assert_true(endpoint._rooms[oldest]["started"])
	assert_eq(endpoint._open_rooms().size(), 1)

func test_join_any_without_rooms_does_not_crash() -> void:
	var endpoint := _server()
	endpoint._server_join_any(33, TEAM_B)
	assert_eq(endpoint._rooms.size(), 0)

func test_room_is_removed_when_everyone_leaves() -> void:
	var endpoint := _server()
	endpoint._server_create_room(11, TEAM_A, ScenarioManager.FIELD)
	endpoint._on_server_peer_disconnected(11)
	assert_eq(endpoint._rooms.size(), 0)

func test_player_reconnecting_mid_match_gets_the_same_slot() -> void:
	var endpoint := _server()
	endpoint._server_create_room(11, TEAM_A, ScenarioManager.FIELD)
	var code: String = endpoint._open_rooms()[0]["room"]
	endpoint._server_join_room(22, code, TEAM_B)
	endpoint._on_server_peer_disconnected(22)
	endpoint._server_join_room(44, code, [])
	var players: Dictionary = endpoint._rooms[code]["players"]
	assert_true(players.has(44))
	assert_eq(players[44]["slot"], 2)
	assert_true(players[44]["connected"])
