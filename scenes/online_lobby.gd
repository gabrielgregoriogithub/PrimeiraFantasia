class_name OnlineLobby
extends Control

signal match_ready(payload: Dictionary)
signal closed

const ART_DIRECTION := preload("res://data/art_direction_config.gd")
var _mode := "create"
var _room_edit: LineEdit
var _room_label: Label
var _status_label: Label
var _players_label: Label
var _link_edit: LineEdit
var _ready_button: Button
var _roster_box: VBoxContainer
var _roster_grid: GridContainer
var _selected_roster: Array = []
var _roster_built := false

func _ready() -> void:
	size = get_viewport_rect().size
	theme = ART_DIRECTION.make_ui_theme()
	OnlineEndpoint.connection_changed.connect(_on_connection)
	OnlineEndpoint.lobby_updated.connect(_on_lobby)
	OnlineEndpoint.match_started.connect(func(payload): match_ready.emit(payload))
	OnlineEndpoint.server_error.connect(_on_error)
	_build_ui()

func begin(mode: String, room_from_link: String = "") -> void:
	_mode = mode
	OnlineEndpoint.connect_to_server()
	if mode == "join" and not room_from_link.is_empty():
		_room_edit.text = room_from_link
		OnlineEndpoint.join_room(room_from_link)
	elif mode == "create":
		OnlineEndpoint.create_room()
	_update_mode()

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("0c0f16")
	backdrop.size = size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.position = Vector2(70, 140)
	panel.size = Vector2(size.x - 140, 620)
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
	box.add_child(_status_label)
	_room_label = Label.new()
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_label.add_theme_font_size_override("font_size", 24)
	box.add_child(_room_label)
	var row := HBoxContainer.new()
	box.add_child(row)
	_room_edit = LineEdit.new()
	_room_edit.placeholder_text = "Código da sala (ABC123)"
	_room_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_edit.max_length = OnlineConfig.DEFAULT_ROOM_LENGTH
	row.add_child(_room_edit)
	var join := Button.new()
	join.text = "Entrar pelo código"
	join.pressed.connect(func(): OnlineEndpoint.join_room(_room_edit.text))
	row.add_child(join)
	_link_edit = LineEdit.new()
	_link_edit.editable = false
	_link_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_link_edit)
	var copy := Button.new()
	copy.text = "Copiar link de convite"
	copy.pressed.connect(func(): OnlineConfig.copy_to_clipboard(_link_edit.text); _status_label.text = "Link copiado. Envie para o segundo jogador.")
	box.add_child(copy)
	_players_label = Label.new()
	_players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_players_label.custom_minimum_size.y = 100
	box.add_child(_players_label)
	_roster_box = VBoxContainer.new()
	_roster_box.add_theme_constant_override("separation", 6)
	box.add_child(_roster_box)
	_ready_button = Button.new()
	_ready_button.text = "Estou pronto"
	_ready_button.pressed.connect(_on_ready)
	box.add_child(_ready_button)
	var close := Button.new()
	close.text = "Voltar"
	close.pressed.connect(closed.emit)
	box.add_child(close)

func _update_mode() -> void:
	_room_label.text = "Conectando…"
	_ready_button.disabled = true
	if _mode == "join": _status_label.text = "Entre na sala pelo link ou pelo código."

func _on_connection(connected: bool, text: String) -> void:
	_status_label.text = text

func _on_lobby(payload: Dictionary) -> void:
	var room := String(payload.get("room", ""))
	_room_label.text = "SALA %s" % room
	_room_edit.text = room
	_link_edit.text = OnlineConfig.invite_url(room)
	var players: Array = payload.get("players", [])
	if not _roster_built and OnlineEndpoint.slot() > 0:
		_build_roster()
	var connected := 0
	var ready := 0
	for player in players:
		if player.get("connected", false): connected += 1
		if player.get("ready", false): ready += 1
	_players_label.text = "Jogadores conectados: %d/2\nProntos: %d/2\nA partida inicia quando os dois estiverem prontos." % [connected, ready]
	_ready_button.disabled = players.size() < 1

func _on_ready() -> void:
	if _selected_roster.size() != 5:
		_status_label.text = "Escolha exatamente 5 personagens antes de ficar pronto."
		return
	var heroes: Array = _selected_roster if OnlineEndpoint.slot() == 1 else []
	var monsters: Array = _selected_roster if OnlineEndpoint.slot() == 2 else []
	OnlineEndpoint.submit_roster(heroes, monsters, ScenarioManager.FIELD)
	OnlineEndpoint.set_ready(true)
	_ready_button.disabled = true
	_status_label.text = "Pronto. Aguardando o adversário…"

func _on_error(reason: String) -> void:
	_status_label.text = reason

func _build_roster() -> void:
	_roster_built = true
	var title := Label.new()
	title.text = "Escolha 5 heróis" if OnlineEndpoint.slot() == 1 else "Escolha 5 monstros"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_roster_box.add_child(title)
	_roster_grid = GridContainer.new()
	_roster_grid.columns = 5
	_roster_grid.add_theme_constant_override("h_separation", 6)
	_roster_grid.add_theme_constant_override("v_separation", 6)
	_roster_box.add_child(_roster_grid)
	var keys: Array = Units.player_team_keys() if OnlineEndpoint.slot() == 1 else Units.enemy_team_keys()
	_selected_roster = keys.slice(0, 5)
	for key in keys:
		var button := CheckButton.new()
		button.text = String(key).capitalize()
		button.button_pressed = _selected_roster.has(key)
		button.toggled.connect(func(pressed: bool):
			if pressed:
				if _selected_roster.size() < 5: _selected_roster.append(key)
				else: button.button_pressed = false
			else:
				_selected_roster.erase(key)
		)
		_roster_grid.add_child(button)
