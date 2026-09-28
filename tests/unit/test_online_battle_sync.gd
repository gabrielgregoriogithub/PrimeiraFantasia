extends GutTest

## Partida online: o servidor é a única fonte de verdade. A IA local não pode
## jogar os turnos do adversário (cada cliente jogava o outro time sozinho e
## as ações seguintes eram recusadas com "Não é o seu turno"), e o snapshot
## precisa trazer unidades novas (invocações) para o tabuleiro local.

var main_scene

func before_each() -> void:
	main_scene = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main_scene)
	await wait_process_frames(1)
	main_scene.scenario_manager.set_active(ScenarioManager.FIELD)
	main_scene._active_pvp_battle = {"heroes": Units.player_team_keys().slice(0, 5), "monsters": Units.enemy_team_keys().slice(0, 5)}
	main_scene._start_new_game()
	await wait_process_frames(1)
	main_scene.battle_presentation.phase = BattlePresentationController.Phase.COMBAT
	main_scene._online_mode = true
	main_scene.player_is_human = true
	main_scene.enemy_is_human = false

func after_each() -> void:
	var endpoint: Node = get_tree().root.get_node("OnlineEndpoint")
	endpoint.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	endpoint._pending_messages.clear()

func _snapshot_with_current(actor: Dictionary) -> Dictionary:
	return {"units": main_scene.state.units.duplicate(true), "current_actor": actor["name"], "turn_token": main_scene.state.turn_token}

func test_local_ai_does_not_play_opponent_turn_online() -> void:
	var opponent: Dictionary = main_scene.state.units.filter(func(u): return u["team"] == "enemy")[0]
	main_scene._on_online_snapshot(_snapshot_with_current(opponent))
	var before := Vector2i(opponent["x"], opponent["y"])
	main_scene._run_ai_until_player_turn()
	await wait_seconds(0.5)
	assert_false(main_scene._ai_sequence_running, "IA local não deve iniciar no modo online")
	assert_eq(main_scene.state.current_actor["name"], opponent["name"], "turno do adversário continua esperando o servidor")
	assert_eq(Vector2i(opponent["x"], opponent["y"]), before)

func test_snapshot_adds_units_created_on_server() -> void:
	var actor: Dictionary = main_scene.state.units[0]
	var snapshot := _snapshot_with_current(actor)
	var summon: Dictionary = actor.duplicate(true)
	summon["name"] = "Invocação de teste"
	snapshot["units"].append(summon)
	main_scene._on_online_snapshot(snapshot)
	assert_true(main_scene.state.units.any(func(u): return u["name"] == "Invocação de teste"))
	assert_true(main_scene.unit_tokens.has("Invocação de teste"), "token criado para a unidade nova")
	assert_same(main_scene.state.units[0], actor, "unidades existentes mantêm a mesma referência dos tokens")

func test_snapshot_message_from_server_updates_the_board() -> void:
	var actor: Dictionary = main_scene.state.units[0]
	var snapshot := _snapshot_with_current(actor)
	var moved: Dictionary = snapshot["units"][0]
	moved["x"] = 7
	moved["y"] = 8
	main_scene._on_online_snapshot_message({"type": "snapshot", "snapshot": snapshot})
	assert_eq(main_scene.state.units.size(), snapshot["units"].size(), "o tabuleiro não pode ser esvaziado")
	assert_eq(main_scene.state.current_actor, actor, "ator atual continua definido")
	assert_eq(Vector2i(actor["x"], actor["y"]), Vector2i(7, 8), "posição vinda do servidor aplicada")

## Captura o que seria enviado ao servidor: com o peer offline padrão e sem
## conexão, OnlineEndpoint._send enfileira a mensagem em _pending_messages.
func _capture_online_sends() -> Node:
	var endpoint: Node = get_tree().root.get_node("OnlineEndpoint")
	endpoint._connected = false
	endpoint._server_mode = false
	endpoint._pending_messages.clear()
	return endpoint

func _my_directional_unit() -> Dictionary:
	for u in main_scene.state.units:
		if u["team"] == "player" and main_scene._has_directional_art(u) and not main_scene._unit_uses_3d_visual(u):
			return u
	return {}

func test_online_end_turn_opens_facing_picker_and_sends_the_direction() -> void:
	var endpoint := _capture_online_sends()
	var u := _my_directional_unit()
	assert_false(u.is_empty(), "precisa de um herói com sprite direcional")
	main_scene._on_online_snapshot(_snapshot_with_current(u))
	main_scene._end_current_turn()
	assert_true(main_scene._facing_panel.visible, "seletor de direção aparece no online")
	assert_eq(endpoint._pending_messages.size(), 0, "turno só encerra depois da direção")
	u["facing"] = {"dx": 0, "dy": -1}
	main_scene._on_facing_confirm_pressed()
	assert_eq(endpoint._pending_messages.size(), 1)
	var sent: Dictionary = endpoint._pending_messages[0]
	assert_eq(sent["action"], "facing")
	assert_eq(Vector2i(sent["x"], sent["y"]), Vector2i(u["x"], u["y"] - 1))

func test_online_snapshot_after_move_and_act_opens_facing_picker() -> void:
	var endpoint := _capture_online_sends()
	var u := _my_directional_unit()
	var snapshot := _snapshot_with_current(u)
	for remote in snapshot["units"]:
		if remote["name"] == u["name"]:
			remote["hasMoved"] = true
			remote["hasActed"] = true
	main_scene._on_online_snapshot(snapshot)
	assert_true(main_scene._facing_panel.visible, "vez terminou: escolhe a direção")

func test_emoji_font_is_installed_as_fallback() -> void:
	var fallbacks: Array = ThemeDB.fallback_font.fallbacks
	assert_true(fallbacks.any(func(f): return f.has_char("🔥".unicode_at(0))), "fonte de emoji disponível no Web")
