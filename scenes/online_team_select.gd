class_name OnlineTeamSelect
extends PvpSetup

## Montagem do time do online (pedido do usuário): mesma tela de cartões do
## PVP — retrato, nome e ficha "Ver" —, mas com heróis e todos os grupos de
## monstros juntos numa lista só, podendo misturar à vontade. Quem cria a
## sala escolhe também o cenário (passo reaproveitado do PvpSetup).

signal team_confirmed(team: Array, scenario_id: String)
signal cancelled

var _needs_scenario := false

func begin_online(needs_scenario: bool) -> void:
	_needs_scenario = needs_scenario
	_show_step_team()

func _show_step_team() -> void:
	_step = "team"
	_back_button.visible = true
	_back_button.text = "◀ Voltar"
	_title_label.text = "Monte seu time — escolha %d personagens" % MAX_MONSTERS
	_confirm_button.text = "Escolher cenário ▶" if _needs_scenario else "Confirmar time ▶"
	_clear_grid()
	_grid.columns = 3
	_add_section("⚔️ Heróis", Units.player_team_keys())
	for group_key in MONSTER_GROUP_ORDER:
		var group: Dictionary = MONSTER_GROUPS[group_key]
		_add_section("%s %s" % [group["icon"], group["label"]], group["monsters"])
	_refresh_monsters_ui()

## Título de seção ocupando a linha inteira do grid de 3 colunas.
func _add_section(title: String, keys: Array) -> void:
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color("7fc8ff"))
	header.custom_minimum_size = Vector2(CARD_SIZE.x, 40)
	header.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_grid.add_child(header)
	for i in _grid.columns - 1:
		_grid.add_child(Control.new())
	for key in keys:
		_add_character_card(String(key))
	var remainder := keys.size() % _grid.columns
	if remainder != 0:
		for i in _grid.columns - remainder:
			_grid.add_child(Control.new())

func _add_character_card(key: String) -> void:
	var character := _monster_template(key)
	var card := VBoxContainer.new()
	card.custom_minimum_size = CARD_SIZE
	_grid.add_child(card)
	var portrait_button := Button.new()
	portrait_button.custom_minimum_size = CARD_PICTURE_SIZE
	portrait_button.expand_icon = true
	portrait_button.icon = _monster_portrait_texture(key)
	portrait_button.tooltip_text = "Selecionar/desmarcar %s" % character.get("name", key)
	portrait_button.pressed.connect(_toggle_monster.bind(key))
	card.add_child(portrait_button)
	_card_buttons[key] = portrait_button
	var name_label := Label.new()
	name_label.text = String(character.get("name", key))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color("ffe29a"))
	card.add_child(name_label)
	var view_button := Button.new()
	view_button.text = "Ver ficha"
	view_button.pressed.connect(_show_monster_info.bind(key))
	card.add_child(view_button)

## Sem a trava de grupo do PVP local: qualquer combinação de 5.
func _toggle_monster(key: String) -> void:
	if _selected_monsters.has(key):
		_selected_monsters.erase(key)
	elif _selected_monsters.size() < MAX_MONSTERS:
		_selected_monsters.append(key)
	_refresh_monsters_ui()

func _refresh_monsters_ui() -> void:
	super._refresh_monsters_ui()
	_selected_preview_row.visible = true
	for child in _selected_preview_row.get_children():
		child.queue_free()
	for key in _selected_monsters:
		var mini := TextureRect.new()
		mini.custom_minimum_size = Vector2(44, 44)
		mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mini.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mini.texture = _monster_portrait_texture(key)
		mini.tooltip_text = String(_monster_template(key).get("name", key))
		_selected_preview_row.add_child(mini)

func _on_back_pressed() -> void:
	if _step == "scenario":
		_show_step_team()
	else:
		cancelled.emit()

func _on_confirm_pressed() -> void:
	if _step == "team" and _selected_monsters.size() == MAX_MONSTERS:
		if _needs_scenario:
			_show_step_scenario()
			_selected_preview_row.visible = true
			_confirm_button.text = "Criar sala ▶"
		else:
			team_confirmed.emit(_selected_monsters.duplicate(), "")
	elif _step == "scenario" and _selected_scenario != "":
		team_confirmed.emit(_selected_monsters.duplicate(), _selected_scenario)
