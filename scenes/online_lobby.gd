class_name OnlineLobby
extends Control

## Sala online depois do time montado (OnlineTeamSelect). Três modos:
## - "create": cria a sala com o time + cenário e mostra código/link;
## - "join": entra pelo código (ou direto pelo link de convite ?sala=);
## - "browse": lista as salas esperando adversário, com entrada rápida.
## A partida começa sozinha quando o segundo jogador entra.

signal match_ready(payload: Dictionary)
signal closed

const ART_DIRECTION := preload("res://data/art_direction_config.gd")
const ROOM_LIST_REFRESH_SECONDS := 3.0
var _mode := "create"
var _team: Array = []
var _room_edit: LineEdit
var _room_label: Label
var _status_label: Label
var _players_label: Label
var _link_edit: LineEdit
var _join_row: HBoxContainer
var _invite_box: VBoxContainer
var _browse_box: VBoxContainer
var _room_list: VBoxContainer
var _refresh_timer: Timer
var _card_helper: PvpSetup
var _my_team_row: HBoxContainer

func _ready() -> void:
	size = get_viewport_rect().size
	theme = ART_DIRECTION.make_ui_theme()
	# Só para reaproveitar nomes/retratos dos cartões do PVP (nunca entra na árvore).
	_card_helper = PvpSetup.new()
	OnlineEndpoint.connection_changed.connect(_on_connection)
	OnlineEndpoint.lobby_updated.connect(_on_lobby)
	OnlineEndpoint.match_started.connect(_on_match_started)
	OnlineEndpoint.server_error.connect(_on_error)
	OnlineEndpoint.room_list_received.connect(_on_room_list)
	_build_ui()

func _exit_tree() -> void:
	if _card_helper != null: _card_helper.free()
	OnlineEndpoint.connection_changed.disconnect(_on_connection)
	OnlineEndpoint.lobby_updated.disconnect(_on_lobby)
	OnlineEndpoint.match_started.disconnect(_on_match_started)
	OnlineEndpoint.server_error.disconnect(_on_error)
	OnlineEndpoint.room_list_received.disconnect(_on_room_list)

## Quem abriu o link de convite (?sala=) entra na sala do link, mesmo que
## tenha clicado em outra opção online — senão cada um fica numa sala.
static func resolve_mode(mode: String, room_from_link: String) -> String:
	return "join" if not room_from_link.is_empty() else mode

func begin(mode: String, room_from_link: String, team: Array, scenario_id: String) -> void:
	_mode = resolve_mode(mode, room_from_link)
	_team = team.duplicate()
	_fill_portraits(_my_team_row, _team, 48)
	OnlineEndpoint.connect_to_server()
	_invite_box.visible = _mode == "create"
	_join_row.visible = _mode == "join"
	_browse_box.visible = _mode == "browse"
	match _mode:
		"create":
			_room_label.text = "Criando sala…"
			OnlineEndpoint.create_room(_team, scenario_id)
		"join":
			_room_label.text = "Entrar numa sala"
			_status_label.text = "Digite o código da sala."
			if not room_from_link.is_empty():
				_room_edit.text = room_from_link
				OnlineEndpoint.join_room(room_from_link, _team)
		"browse":
			_room_label.text = "Salas esperando adversário"
			_status_label.text = "Procurando salas…"
			OnlineEndpoint.list_rooms()
			_refresh_timer.start()

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("0c0f16")
	backdrop.size = size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.position = Vector2(60, 100)
	panel.size = Vector2(size.x - 120, size.y - 200)
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111522")
	style.border_color = Color("d6a94b")
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := Label.new()
	title.text = "COMBATE ONLINE · 2 JOGADORES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("ffe29a"))
	box.add_child(title)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status_label)
	_room_label = Label.new()
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_label.add_theme_font_size_override("font_size", 24)
	box.add_child(_room_label)
	_my_team_row = HBoxContainer.new()
	_my_team_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_my_team_row.add_theme_constant_override("separation", 6)
	box.add_child(_my_team_row)

	# Criar: código + link de convite.
	_invite_box = VBoxContainer.new()
	_invite_box.add_theme_constant_override("separation", 10)
	box.add_child(_invite_box)
	_link_edit = LineEdit.new()
	_link_edit.editable = false
	_invite_box.add_child(_link_edit)
	var copy := Button.new()
	copy.text = "Copiar link de convite"
	copy.pressed.connect(func(): OnlineConfig.copy_to_clipboard(_link_edit.text); _status_label.text = "Link copiado. Envie para o segundo jogador.")
	_invite_box.add_child(copy)
	_players_label = Label.new()
	_players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_invite_box.add_child(_players_label)

	# Entrar pelo código.
	_join_row = HBoxContainer.new()
	box.add_child(_join_row)
	_room_edit = LineEdit.new()
	_room_edit.placeholder_text = "Código da sala (ABC123)"
	_room_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_edit.max_length = OnlineConfig.DEFAULT_ROOM_LENGTH
	_join_row.add_child(_room_edit)
	var join := Button.new()
	join.text = "Entrar pelo código"
	join.pressed.connect(func():
		_status_label.text = "Entrando na sala…"
		OnlineEndpoint.join_room(_room_edit.text, _team)
	)
	_join_row.add_child(join)

	# Procurar salas.
	_browse_box = VBoxContainer.new()
	_browse_box.add_theme_constant_override("separation", 10)
	_browse_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_browse_box)
	var quick := Button.new()
	quick.text = "⚡ Entrar na primeira sala disponível"
	quick.custom_minimum_size = Vector2(0, 52)
	quick.pressed.connect(func():
		_status_label.text = "Entrando na primeira sala disponível…"
		OnlineEndpoint.join_any(_team)
	)
	_browse_box.add_child(quick)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 420)
	_browse_box.add_child(scroll)
	_room_list = VBoxContainer.new()
	_room_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_room_list)
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = ROOM_LIST_REFRESH_SECONDS
	_refresh_timer.timeout.connect(OnlineEndpoint.list_rooms)
	add_child(_refresh_timer)

	var close := Button.new()
	close.text = "Voltar"
	close.pressed.connect(func():
		OnlineEndpoint.disconnect_from_server()
		closed.emit()
	)
	box.add_child(close)

func _fill_portraits(row: HBoxContainer, keys: Array, portrait_size: int) -> void:
	for child in row.get_children(): child.queue_free()
	for key in keys:
		var mini := TextureRect.new()
		mini.custom_minimum_size = Vector2(portrait_size, portrait_size)
		mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mini.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mini.texture = _card_helper._monster_portrait_texture(String(key))
		mini.tooltip_text = String(_card_helper._monster_template(String(key)).get("name", key))
		row.add_child(mini)

func _on_connection(_connected: bool, text: String) -> void:
	_status_label.text = text

func _on_lobby(payload: Dictionary) -> void:
	var room := String(payload.get("room", ""))
	if room.is_empty(): return
	_room_label.text = "SALA %s" % room
	_link_edit.text = OnlineConfig.invite_url(room)
	var connected := 0
	for player in payload.get("players", []):
		if player.get("connected", false): connected += 1
	if connected > 0:
		_players_label.text = "Jogadores conectados: %d/2" % connected
		_status_label.text = "Aguardando adversário… a partida começa quando ele entrar." if connected < 2 else "Adversário encontrado!"

func _on_match_started(payload: Dictionary) -> void:
	_refresh_timer.stop()
	match_ready.emit(payload)

func _on_error(reason: String) -> void:
	_status_label.text = reason

func _on_room_list(rooms: Array) -> void:
	if _mode != "browse": return
	for child in _room_list.get_children(): child.queue_free()
	_status_label.text = "%d sala(s) esperando adversário." % rooms.size() if not rooms.is_empty() else "Nenhuma sala esperando adversário. A lista atualiza sozinha."
	for room in rooms:
		_room_list.add_child(_room_row(room))

func _room_row(room: Dictionary) -> PanelContainer:
	var row_panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a2033")
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	row_panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row_panel.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var label := Label.new()
	label.text = "🗺️ %s · Sala %s" % [ScenarioManager.definition(String(room.get("scenario", ""))).get("name", room.get("scenario", "")), room.get("room", "")]
	info.add_child(label)
	var portraits := HBoxContainer.new()
	portraits.add_theme_constant_override("separation", 4)
	_fill_portraits(portraits, room.get("team", []), 36)
	info.add_child(portraits)
	var enter := Button.new()
	enter.text = "Entrar"
	enter.custom_minimum_size = Vector2(110, 0)
	var code := String(room.get("room", ""))
	enter.pressed.connect(func():
		_status_label.text = "Entrando na sala %s…" % code
		OnlineEndpoint.join_room(code, _team)
	)
	row.add_child(enter)
	return row_panel
