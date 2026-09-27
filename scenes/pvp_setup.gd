class_name PvpSetup
extends Control

## Assistente de configuração do Modo PVP (pedido do usuário): escolher 5
## monstros (dentre todos os criados até agora: os 5 do time inimigo base +
## os 6 exclusivos das masmorras da Torre + os 5 do Vale da Lua) e depois 1
## dos 7 cenários jogáveis como arena. A escolha de heróis NÃO mora mais
## aqui — pedido do usuário foi pra reaproveitar literalmente o mesmo quadro
## "5 de 6" com retrato e "Ver personagem" já usado nos andares 3º/4º da
## Torre (ver
## Main._show_party_selection/_build_party_selection_panel); main.gd mostra
## aquele painel primeiro e só então instancia este assistente via begin(),
## já com os heróis escolhidos prontos. Emite `battle_configured` com as 3
## escolhas; main.gd é quem de fato monta a partida (ver
## Main._on_pvp_battle_configured/GameState.apply_pvp_scenario).
##
## Pedido do usuário: a seleção de monstros precisa ser "por cartão e
## descrição, assim como é a dos heróis" — mesmo padrão então: retrato +
## nome no cartão, e um botão "Ver monstro" que abre uma ficha (atributos +
## armas + habilidades) antes de decidir. Como este Control já é dono da sua
## própria CanvasLayer (ver Main._show_pvp_monster_and_scenario_setup), a
## ficha mora aqui dentro mesmo (_info_panel, por cima do grid) em vez de
## pedir pro _unit_info_panel do main.gd, que vive numa camada mais baixa e
## ficaria escondido atrás desta tela.

signal battle_configured(hero_keys: Array, monster_keys: Array, scenario_id: String)

const ART_DIRECTION := preload("res://data/art_direction_config.gd")

## Pedido do usuário: time inimigo também fixo em 5 (mesma contagem dos
## heróis, ver Main._show_party_selection) — deixou de ser "de 5 a 10".
const MIN_MONSTERS := 5
const MAX_MONSTERS := 5

## Pedido do usuário: tamanhos padronizados pra todo cartão de seleção
## (herói, monstro, cenário) — mesmo molde do cartão de herói já usado em
## Main._show_party_selection (VBox 215x250, retrato 205x180).
const CARD_SIZE := Vector2(215, 250)
const CARD_PICTURE_SIZE := Vector2(205, 180)

## Nomes/ícones dos 6 monstros exclusivos das masmorras (ver
## GameState.dungeon_monster_data) — os 5 do time inimigo base (Goblin, Orc,
## Xamã, Fada, Troll) já trazem "name"/"icon" prontos em Units.build().
const DUNGEON_MONSTER_INFO := {
	"zombie": {"name": "Zumbi", "icon": "🧟"},
	"ghost": {"name": "Fantasma", "icon": "👻"},
	"skeleton": {"name": "Esqueleto", "icon": "💀"},
	"living_fire": {"name": "Fogo Vivo", "icon": "🔥"},
	"lava_human": {"name": "Lava Humana", "icon": "🌋"},
	"salamander": {"name": "Salamandra", "icon": "🦎"},
	"flame_demon": {"name": "Demônio das Chamas", "icon": "👹"},
	"vampire": {"name": "Vampiro", "icon": "🧛"},
	"lich": {"name": "Lich", "icon": "💀"},
	"dragon": {"name": "Dragão Vermelho", "icon": "🐉"},
}
const DUNGEON_MONSTER_KEYS := ["zombie", "ghost", "skeleton", "living_fire", "lava_human", "salamander", "flame_demon", "vampire", "lich", "dragon"]

## Cada kind de masmorra usa o retrato do respectivo tower_*/chave própria no
## catálogo animal (ver data/animal_sprite_catalog.gd) — chave curta aqui,
## chave do catálogo lá.
const DUNGEON_CATALOG_KEY := {
	"zombie": "tower_zombie", "ghost": "tower_ghost", "skeleton": "tower_skeleton",
	"living_fire": "tower_living_fire", "lava_human": "tower_lava_human", "salamander": "tower_salamander",
	"flame_demon": "flame_demon", "vampire": "vampire", "lich": "lich", "dragon": "dragon",
}

## Pedido do usuário: os bichos do Vale da Lua (Rato/Slime/Cobra/Gnoll) e o
## Slime Negro (chefe da 1ª sala da Torre, ver GameState.black_slime_boss_data)
## também precisam aparecer como opção escolhível no time inimigo do PVP —
## mesmo padrão dos 6 exclusivos de masmorra acima, só que a fonte dos dados é
## GameState.lua_monster_data (ver _monster_template) em vez de
## GameState.dungeon_monster_data.
const LUA_MONSTER_KEYS := ["rat", "slime", "snake", "gnoll", "goo"]

## Chave curta aqui, chave "spd_*" no catálogo animal (ver
## data/animal_sprite_catalog.gd).
const LUA_CATALOG_KEY := {
	"rat": "spd_rat", "slime": "spd_slime", "snake": "spd_snake", "gnoll": "spd_gnoll", "goo": "spd_goo",
}

## Os 33 Guardians (ver data/guardian_monsters.gd) — lista literal espelhando
## GuardianMonsters.keys(), mesmo padrão de DUNGEON_MONSTER_KEYS/
## LUA_MONSTER_KEYS acima (const não pode chamar função em GDScript). Ao
## contrário dos outros dois grupos, não precisa de um *_CATALOG_KEY próprio:
## o spriteKey de cada Guardian já É a chave do SPRITE_MANIFEST (ver
## data/sprite_manifest.gd), então _monster_portrait_texture resolve direto.
const GUARDIAN_MONSTER_KEYS := [
	"fordin", "stegofor", "brachifor", "kroki", "krokivip", "leviadile",
	"devidin", "devidra", "deviraptor", "aerodin", "aerodeer", "aerostag",
	"weastoat", "mooty", "camoon", "moopard", "wuppy", "earog", "deemog",
	"dradder", "driper", "spreye", "buttereye", "duggot", "breem",
	"marvillar", "marvantis", "palmpot", "bonsot", "erimat", "erichief",
	"eggatch", "owlock",
]

## Pedido do usuário: agrupar a seleção de monstros do PVP por categoria em
## vez de mostrar os ~15 de uma vez. Puramente organização de dados — cada
## chave aqui é a MESMA usada por Units.enemy_team_keys()/DUNGEON_MONSTER_KEYS/
## LUA_MONSTER_KEYS (_monster_template já sabe resolver qualquer uma delas),
## então a tela de monstros existente só precisa filtrar por esta lista, sem
## nenhum "if monstro == x" espalhado pela UI. Fácil de expandir: um novo
## monstro só entra numa lista aqui (e nos catálogos de origem, se for novo).
const MONSTER_GROUPS := {
	"goblinoides": {"label": "Goblinoides", "icon": "🪓", "monsters": ["orc", "troll", "fada", "xama", "goblin"]},
	"criaturas": {"label": "Criaturas", "icon": "🐾", "monsters": ["rat", "snake", "gnoll", "goo", "slime"]},
	"undead": {"label": "Mortos-Vivos", "icon": "💀", "monsters": ["vampire", "lich", "skeleton", "zombie", "ghost"]},
	"fire": {"label": "Elementais do Fogo", "icon": "🔥", "monsters": ["living_fire", "lava_human", "salamander", "dragon", "flame_demon"]},
	"guardians": {"label": "Guardiões", "icon": "🐲", "monsters": GUARDIAN_MONSTER_KEYS},
}
const MONSTER_GROUP_ORDER := ["goblinoides", "criaturas", "undead", "fire", "guardians"]

## Pedido do usuário: TOWER_FLOOR_4 (8º cenário do ScenarioManager) também
## escolhível no PVP — antes ficava de fora por ser sala de chefe única (1
## inimigo fixo, Salamandra) sem "enemy_spawns" próprio pra roster livre, mas
## ScenarioManager._tower_floor_4_definition() já ganhou os 5 spawns (ver
## comentário lá) igual 2º/3º Andar receberam antes. 8 cenários escolhíveis.
## PORTO/DESFILADEIRO/ESTRADA_INVERNO (cenários independentes, fora de
## PHASE_ORDER) — apply_pvp_scenario() já é genérico o bastante (monta o
## terreno via apply_scenario() e só troca o elenco), nenhuma mudança extra
## precisou ser feita neles. Pedido do usuário: os 3 cenários novos vão
## PRIMEIRO na lista (mais visíveis, topo da grade de seleção) em vez de
## no fim.
const SCENARIO_IDS := [
	ScenarioManager.CEMITERIO, ScenarioManager.TEMPLO,
	ScenarioManager.PORTO, ScenarioManager.DESFILADEIRO, ScenarioManager.ESTRADA_INVERNO,
	ScenarioManager.VILLAGE, ScenarioManager.FOREST, ScenarioManager.FIELD,
	ScenarioManager.LUA_VALLEY, ScenarioManager.TOWER, ScenarioManager.TOWER_FLOOR_2,
	ScenarioManager.TOWER_FLOOR_3, ScenarioManager.TOWER_FLOOR_4,
]

## "groups" | "monsters" | "scenario"
var _step := "groups"
var _hero_keys: Array = []
var _selected_monsters: Array = []
var _selected_scenario: String = ""
## Grupo aberto no momento (vazio só na tela de grupos em si). Guardado só
## pra "Voltar" reabrir o mesmo grupo. Pedido do usuário (revisado): times
## inimigos não podem mais misturar categorias — ver _locked_monster_group(),
## que bloqueia as outras capas na tela de grupos assim que o 1º monstro é
## escolhido, até a seleção esvaziar de novo.
var _current_group := ""

## Portraits pequenos dos monstros já escolhidos, mostrados na tela de
## grupos (pedido do usuário) — reconstruído a cada _refresh_groups_ui().
var _selected_preview_row: HBoxContainer

var _title_label: Label
var _counter_label: Label
var _grid: GridContainer
var _confirm_button: Button
var _back_button: Button
var _card_buttons: Dictionary = {}

var _info_panel: PanelContainer
var _info_title: Label
var _info_content: VBoxContainer

func _ready() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = viewport_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = ART_DIRECTION.make_ui_theme()

	var backdrop := ColorRect.new()
	backdrop.color = Color("0c0f16")
	backdrop.position = Vector2.ZERO
	backdrop.size = viewport_size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.position = Vector2(60, 60)
	panel.size = Vector2(viewport_size.x - 120, viewport_size.y - 120)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111522")
	style.border_color = Color("d6a94b")
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	panel.add_child(outer)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", Color("ffe29a"))
	outer.add_child(_title_label)

	_counter_label = Label.new()
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter_label.add_theme_font_size_override("font_size", 17)
	_counter_label.add_theme_color_override("font_color", Color.WHITE)
	outer.add_child(_counter_label)

	# Pedido do usuário: portraits pequenos dos monstros já escolhidos,
	# visíveis na tela de grupos (só populada/mostrada nesse passo — ver
	# _refresh_groups_ui) pra acompanhar a composição sem precisar reabrir
	# cada categoria.
	_selected_preview_row = HBoxContainer.new()
	_selected_preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_selected_preview_row.add_theme_constant_override("separation", 8)
	outer.add_child(_selected_preview_row)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(viewport_size.x - 160, viewport_size.y - 320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_grid)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 24)
	outer.add_child(footer)
	_back_button = Button.new()
	_back_button.text = "◀ Voltar"
	_back_button.custom_minimum_size = Vector2(160, 48)
	_back_button.pressed.connect(_on_back_pressed)
	footer.add_child(_back_button)
	_confirm_button = Button.new()
	_confirm_button.custom_minimum_size = Vector2(220, 48)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	footer.add_child(_confirm_button)

	_build_info_panel()

## Chamado por main.gd logo após instanciar, já com os 5 heróis escolhidos
## no quadro nativo (ver Main._show_party_selection). Começa na tela de
## categorias (pedido do usuário) em vez de listar todos os monstros juntos.
func begin(hero_keys: Array) -> void:
	_hero_keys = hero_keys
	_show_step_groups()

func _clear_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_card_buttons.clear()

# --- Passo: grupos de monstros ---------------------------------------------

func _show_step_groups() -> void:
	_step = "groups"
	_current_group = ""
	_back_button.visible = false
	_title_label.text = "Escolha um grupo de monstros"
	_confirm_button.text = "Confirmar monstros ▶"
	_clear_grid()
	_grid.columns = 2
	for key in MONSTER_GROUP_ORDER:
		_add_group_card(key)
	_refresh_groups_ui()

## Card grande de categoria — mesmo molde de _add_scenario_card (VBox:
## botão-retrato de tamanho fixo + Label do nome embaixo), só maior. Pedido
## do usuário: as 4 capas de verdade vêm de assets/enemies/capas/ — nome de
## arquivo real tem um typo ("globinoides.png", não "goblinoides.png"),
## preservado literalmente igual outros nomes de arquivo já reaproveitados
## como estão no projeto (ex.: "wlak_right_2.png" da Lava Humana). Sem o
## arquivo, cai num ícone emoji grande sobre um painel colorido — sempre
## renderizável mesmo sem asset externo.
const GROUP_CARD_SIZE := Vector2(320, 300)
const GROUP_PICTURE_SIZE := Vector2(300, 220)
const MONSTER_GROUP_COVER_FILE := {
	"goblinoides": "globinoides.png",
	"criaturas": "criaturas.png",
	"undead": "mortos-vivos.png",
	"fire": "elementais do fogo.png",
}

## Pedido do usuário: as capas de verdade (fotos grandes, proporção própria)
## ficavam distorcidas com Button.icon/expand_icon (que só sabe esticar pra
## preencher o botão inteiro, sem noção de aspect ratio — mesmo estilo já
## usado por _add_monster_card/_add_scenario_card, que funciona bem pros
## ícones/telas pequenas de lá, mas não pra foto grande de capa). Um
## TextureButton com STRETCH_KEEP_ASPECT_COVERED preenche a moldura sem
## esticar (corta o excedente mantendo a proporção, como capa de disco),
## dentro de um Control com clip_contents pra nunca vazar da moldura fixa.
## Pedido do usuário: times inimigos do PVP não podem mais misturar
## categorias — depois de escolher o 1º monstro, só a categoria dele
## continua aberta; as outras ficam bloqueadas até a seleção esvaziar de
## novo (desmarcar todos os monstros escolhidos).
func _locked_monster_group() -> String:
	for key in _selected_monsters:
		return _group_of_monster(key)
	return ""

func _group_of_monster(key: String) -> String:
	for group_key in MONSTER_GROUP_ORDER:
		if (MONSTER_GROUPS[group_key]["monsters"] as Array).has(key):
			return group_key
	return ""

func _add_group_card(group_key: String) -> void:
	var group: Dictionary = MONSTER_GROUPS[group_key]
	var locked_group := _locked_monster_group()
	var is_locked_out: bool = locked_group != "" and locked_group != group_key
	var card := VBoxContainer.new()
	card.custom_minimum_size = GROUP_CARD_SIZE
	card.modulate = Color(1, 1, 1, 0.4) if is_locked_out else Color.WHITE
	_grid.add_child(card)
	var lock_tooltip := "Time já composto só de %s — desmarque os monstros escolhidos pra trocar de categoria." % String(MONSTER_GROUPS[locked_group]["label"]) if is_locked_out else ""
	var cover_path := "res://assets/enemies/capas/%s" % MONSTER_GROUP_COVER_FILE.get(group_key, "")
	var picture_frame := Control.new()
	picture_frame.custom_minimum_size = GROUP_PICTURE_SIZE
	picture_frame.clip_contents = true
	card.add_child(picture_frame)
	if ResourceLoader.exists(cover_path):
		var texture_button := TextureButton.new()
		texture_button.texture_normal = load(cover_path)
		texture_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		texture_button.set_anchors_preset(Control.PRESET_FULL_RECT)
		texture_button.tooltip_text = lock_tooltip if is_locked_out else "Abrir %s" % group["label"]
		texture_button.disabled = is_locked_out
		if not is_locked_out:
			texture_button.pressed.connect(_open_monster_group.bind(group_key))
		picture_frame.add_child(texture_button)
	else:
		var fallback_button := Button.new()
		fallback_button.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback_button.text = String(group["icon"])
		fallback_button.add_theme_font_size_override("font_size", 96)
		fallback_button.tooltip_text = lock_tooltip if is_locked_out else "Abrir %s" % group["label"]
		fallback_button.disabled = is_locked_out
		if not is_locked_out:
			fallback_button.pressed.connect(_open_monster_group.bind(group_key))
		picture_frame.add_child(fallback_button)
	var name_label := Label.new()
	name_label.text = String(group["label"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color("ffe29a"))
	card.add_child(name_label)

## Clicar numa capa só ABRE o grupo — não seleciona nenhum monstro sozinho
## (pedido explícito do usuário).
func _open_monster_group(group_key: String) -> void:
	_show_step_monsters(group_key)

func _refresh_groups_ui() -> void:
	_counter_label.text = "Selecionados: %d de %d" % [_selected_monsters.size(), MAX_MONSTERS]
	_confirm_button.disabled = _selected_monsters.size() < MIN_MONSTERS or _selected_monsters.size() > MAX_MONSTERS
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

# --- Passo: monstros -----------------------------------------------------

## `group_key` filtra quais monstros aparecem (pedido do usuário: escolher
## categoria primeiro); vazio ("") mostra todos, mantido só por segurança —
## na prática este passo só é alcançado vindo de um card de grupo agora.
func _show_step_monsters(group_key: String = "") -> void:
	_step = "monsters"
	_current_group = group_key
	_back_button.visible = true
	var group_label: String = String(MONSTER_GROUPS[group_key]["label"]) if MONSTER_GROUPS.has(group_key) else ""
	_title_label.text = "%s — escolha até %d monstros" % [group_label, MAX_MONSTERS] if group_label != "" else "Escolha %d monstros" % MAX_MONSTERS
	_confirm_button.text = "Confirmar monstros ▶"
	_selected_preview_row.visible = false
	_clear_grid()
	_grid.columns = 3
	var pool: Array = MONSTER_GROUPS[group_key]["monsters"] if MONSTER_GROUPS.has(group_key) else (Units.enemy_team_keys() + DUNGEON_MONSTER_KEYS + LUA_MONSTER_KEYS)
	var templates := Units.build()
	for key in pool:
		var monster: Dictionary = templates[key] if templates.has(key) else _monster_template(key)
		_add_monster_card(key, monster)
	_refresh_monsters_ui()

func _add_monster_card(key: String, monster: Dictionary) -> void:
	var display_name := String(monster.get("name", key))
	var card := VBoxContainer.new()
	card.custom_minimum_size = CARD_SIZE
	_grid.add_child(card)
	var portrait_button := Button.new()
	portrait_button.custom_minimum_size = CARD_PICTURE_SIZE
	portrait_button.expand_icon = true
	portrait_button.icon = _monster_portrait_texture(key)
	portrait_button.tooltip_text = "Selecionar/desmarcar %s" % display_name
	portrait_button.pressed.connect(_toggle_monster.bind(key))
	card.add_child(portrait_button)
	_card_buttons[key] = portrait_button
	var name_label := Label.new()
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color("ffe29a"))
	card.add_child(name_label)
	var view_button := Button.new()
	view_button.text = "Ver monstro"
	view_button.pressed.connect(_show_monster_info.bind(key))
	card.add_child(view_button)

func _toggle_monster(key: String) -> void:
	if _selected_monsters.has(key):
		_selected_monsters.erase(key)
	elif _selected_monsters.size() < MAX_MONSTERS:
		# Pedido do usuário: time inimigo não pode misturar categorias — a
		# regra de verdade vive aqui (não só nos botões desabilitados da tela
		# de grupos, ver _add_group_card), então nem uma chamada direta
		# consegue furar o bloqueio.
		var locked_group := _locked_monster_group()
		if locked_group != "" and _group_of_monster(key) != locked_group:
			return
		_selected_monsters.append(key)
	_refresh_monsters_ui()

func _refresh_monsters_ui() -> void:
	_counter_label.text = "Selecionados: %d de %d" % [_selected_monsters.size(), MAX_MONSTERS]
	_confirm_button.disabled = _selected_monsters.size() < MIN_MONSTERS or _selected_monsters.size() > MAX_MONSTERS
	for key in _card_buttons:
		var button: Button = _card_buttons[key]
		button.modulate = Color("ffb0a0") if _selected_monsters.has(key) else Color.WHITE

# --- Passo: cenário --------------------------------------------------

func _show_step_scenario() -> void:
	_step = "scenario"
	_back_button.visible = true
	_title_label.text = "Escolha o cenário da batalha"
	_confirm_button.text = "Começar batalha ▶"
	_clear_grid()
	_selected_scenario = ""
	for id in SCENARIO_IDS:
		_add_scenario_card(id)
	_refresh_scenario_ui()

## Pedido do usuário: os cartões de cenário estavam "irregulares" (o Button
## com ícone+texto embutido deixa cada imagem se ajustar do seu jeito) — daí
## o mesmo molde exato dos cartões de herói/monstro (VBox: botão-retrato de
## tamanho FIXO, sem texto próprio, + Label do nome embaixo, tamanho fixo
## também), pra sair sempre do mesmo tamanho/proporção não importa o formato
## da imagem original.
func _add_scenario_card(id: String) -> void:
	var def := ScenarioManager.definition(id)
	var card := VBoxContainer.new()
	card.custom_minimum_size = CARD_SIZE
	_grid.add_child(card)
	var picture_button := Button.new()
	picture_button.custom_minimum_size = CARD_PICTURE_SIZE
	picture_button.expand_icon = true
	picture_button.icon = _scenario_preview_texture(id)
	picture_button.pressed.connect(_select_scenario.bind(id))
	card.add_child(picture_button)
	_card_buttons[id] = picture_button
	var name_label := Label.new()
	name_label.text = String(def.get("name", id))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color("ffe29a"))
	card.add_child(name_label)

## O id do cenário (ver ScenarioManager.VILLAGE/FOREST/FIELD/LUA_VALLEY/
## TOWER/TOWER_FLOOR_2/TOWER_FLOOR_3) já É o nome do arquivo — pedido do
## usuário deu as imagens numa pasta à parte (assets/ui/scenarios/) já
## renomeadas exatamente assim, sem precisar de tabela de tradução.
func _scenario_preview_texture(id: String) -> Texture2D:
	var path := "res://assets/ui/scenarios/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null

func _select_scenario(id: String) -> void:
	_selected_scenario = id
	_refresh_scenario_ui()

func _refresh_scenario_ui() -> void:
	_counter_label.text = "Cenário selecionado" if _selected_scenario != "" else "Escolha um cenário"
	_confirm_button.disabled = _selected_scenario == ""
	for id in _card_buttons:
		var button: Button = _card_buttons[id]
		button.modulate = Color("a0d4ff") if id == _selected_scenario else Color.WHITE

# --- ficha do monstro ("Ver monstro") -------------------------------------

## Espelha a fonte de dados dos heróis (Units.build()) — os 5 inimigos "de
## campo" também vêm de lá; os 6 exclusivos de masmorra vêm de
## GameState.dungeon_monster_data (extraída de _spawn_dungeon_enemy
## especificamente pra isto: montar a ficha sem precisar de uma partida
## rodando).
func _monster_template(key: String) -> Dictionary:
	var templates := Units.build()
	if templates.has(key):
		return (templates[key] as Dictionary).duplicate(true)
	var data: Dictionary
	if key in GUARDIAN_MONSTER_KEYS:
		data = GameState.guardian_monster_data(key)
	elif key in LUA_MONSTER_KEYS:
		data = GameState.lua_monster_data(key)
	else:
		data = GameState.dungeon_monster_data(key)
	# Pedido do usuário: a ficha de seleção do PVP mostra 1 exemplar de cada
	# vez — o índice "1" que dungeon_monster_data/lua_monster_data/
	# guardian_monster_data sempre numeram (útil quando várias cópias entram
	# na MESMA batalha) não faz sentido aqui. Só a EXIBIÇÃO muda;
	# _spawn_dungeon_enemy/_spawn_lua_monster/_spawn_guardian_monster
	# continuam numerando cada cópia normalmente na hora de montar a partida.
	var display_name := String(data.get("name", ""))
	if display_name.ends_with(" 1"):
		data["name"] = display_name.substr(0, display_name.length() - 2)
	return data

## Espelha Main._hero_portrait_texture: tenta o retrato do catálogo animal
## primeiro (ver data/animal_sprite_catalog.gd), cai pro padrão prefixado de
## SpriteManifest.SPRITE_MANIFEST em seguida.
func _monster_portrait_texture(key: String) -> Texture2D:
	var catalog_key: String = DUNGEON_CATALOG_KEY.get(key, LUA_CATALOG_KEY.get(key, key))
	var animal_spec := AnimalSpriteCatalog.spec(catalog_key)
	if animal_spec.has("portrait") and ResourceLoader.exists(animal_spec["portrait"]):
		return load(animal_spec["portrait"])
	if animal_spec.has("sheet"):
		return _spd_sheet_portrait_texture(animal_spec)
	var folder: String = SpriteManifest.SPRITE_MANIFEST.get(key, "")
	if folder != "":
		var standard := "%s/%s_portrait.png" % [folder, key]
		if ResourceLoader.exists(standard):
			return load(standard)
		var plain := "%s/portrait.png" % folder
		if ResourceLoader.exists(plain):
			return load(plain)
	return null

## Os 5 bichos spd_* (Rato/Slime/Cobra/Gnoll/Slime Negro) não têm um
## portrait.png dedicado — só a folha de sprites inteira (ver
## AnimalSpriteCatalog.build()). Recorta o 1º quadro de "idle_down" da
## própria folha como retrato, mesmo padrão AtlasTexture que UnitToken usa
## pra ler quadros dessas folhas em combate (ver
## UnitToken._animal_frame_texture).
func _spd_sheet_portrait_texture(animal_spec: Dictionary) -> Texture2D:
	var sheet_path := AnimalSpriteCatalog.SHEET_ROOT + String(animal_spec["sheet"])
	if not ResourceLoader.exists(sheet_path):
		return null
	var anims: Dictionary = animal_spec.get("anims", {})
	if not anims.has("idle_down"):
		return null
	var frames: Array = anims["idle_down"][0]
	if frames.is_empty():
		return null
	var rect: Array = frames[0]
	var atlas := AtlasTexture.new()
	atlas.atlas = load(sheet_path)
	atlas.region = Rect2(rect[0], rect[1], rect[2], rect[3])
	return atlas

func _build_info_panel() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	_info_panel = PanelContainer.new()
	_info_panel.position = Vector2(140, 100)
	_info_panel.size = Vector2(viewport_size.x - 280, viewport_size.y - 200)
	_info_panel.visible = false
	_info_panel.z_index = 50
	var style := StyleBoxFlat.new()
	style.bg_color = Color("161a2a")
	style.border_color = Color("7fc8ff")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	_info_panel.add_theme_stylebox_override("panel", style)
	add_child(_info_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_info_panel.add_child(outer)

	_info_title = Label.new()
	_info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_title.add_theme_font_size_override("font_size", 22)
	_info_title.add_theme_color_override("font_color", Color("ffe29a"))
	outer.add_child(_info_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, _info_panel.size.y - 120)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	_info_content = VBoxContainer.new()
	_info_content.add_theme_constant_override("separation", 6)
	_info_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_info_content)

	var close_button := Button.new()
	close_button.text = "Fechar"
	close_button.custom_minimum_size = Vector2(0, 44)
	close_button.pressed.connect(func(): _info_panel.visible = false)
	outer.add_child(close_button)

func _show_monster_info(key: String) -> void:
	var monster := _monster_template(key)
	for child in _info_content.get_children():
		child.queue_free()
	_info_title.text = String(monster.get("name", key))

	var portrait_texture := _monster_portrait_texture(key)
	if portrait_texture != null:
		var portrait := TextureRect.new()
		portrait.texture = portrait_texture
		portrait.custom_minimum_size = Vector2(128, 128)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var portrait_center := CenterContainer.new()
		portrait_center.add_child(portrait)
		_info_content.add_child(portrait_center)

	_add_info_text("❤️ HP %d    ✧ MP %d    🏃 Deslocamento %d    ⚡ Agilidade %d" % [
		int(monster.get("maxHp", 0)), int(monster.get("maxMp", 0)),
		int(monster.get("moveRange", 0)), int(monster.get("speed", 0)),
	])

	_add_info_heading("Armas")
	var weapons: Array = monster.get("weapons", [])
	if weapons.is_empty():
		_add_info_text("Nenhuma.", Color("aeb7c2"))
	else:
		for weapon in weapons:
			_add_info_text("• %s" % _item_summary(weapon), Color("d8e6ff"))

	_add_info_heading("Habilidades")
	var spells: Array = monster.get("spells", [])
	if spells.is_empty():
		_add_info_text("Nenhuma.", Color("aeb7c2"))
	else:
		for spell in spells:
			_add_info_text("• %s" % _item_summary(spell), Color("d8c7ff"))

	var affinities: Dictionary = monster.get("elementAffinity", {})
	var immunities: Array = monster.get("statusImmunities", [])
	if not affinities.is_empty() or not immunities.is_empty():
		_add_info_heading("Elemental")
		var element_labels := {"fire": "Fogo", "ice": "Gelo", "lightning": "Relâmpago"}
		for element in affinities:
			var aff: Dictionary = affinities[element]
			var label: String = element_labels.get(element, String(element).capitalize())
			var mult: float = float(aff.get("multiplier", 1.0))
			var aff_mode: String = aff.get("mode", "damage")
			var desc := "Absorve / Cura" if aff_mode == "heal" else ("Imune" if aff_mode == "immune" else "Fraqueza ×%s" % String.num(mult, 2).rstrip("0").rstrip("."))
			_add_info_text("• %s: %s" % [label, desc], Color("ffd27f"))
		var status_labels := {"burned": "Queimando", "poison": "Envenenado", "bleed": "Sangrando"}
		for status in immunities:
			_add_info_text("• %s: Imune" % status_labels.get(status, String(status).capitalize()), Color("ffd27f"))

	_info_panel.visible = true

## Pedido do usuário: descrição das armas/habilidades na tela de seleção do
## PVP era só o nome (+ "X-Y de dano" quando tinha) — nada de custo, alcance,
## acerto/crítico ou o que a habilidade REALMENTE faz. Agora monta uma linha
## de estatísticas (só com os campos que o item de fato tem) e reaproveita o
## tooltipNote já escrito à mão pra cada arma/magia (data/weapons.gd,
## data/spells.gd) — a mesma explicação que já aparece no jogo em si, só que
## agora também aqui, antes de escolher o monstro.
func _item_summary(item: Dictionary) -> String:
	var name_text := String(item.get("name", "?"))
	var stats: Array[String] = []
	if item.has("ctCost"): stats.append("CT %d" % int(item["ctCost"]))
	if item.has("mpCost"): stats.append("MP %d" % int(item["mpCost"]))
	if item.has("minRange") or item.has("maxRange"):
		stats.append("alcance %d–%d" % [int(item.get("minRange", 1)), int(item.get("maxRange", 1))])
	if item.has("damageMin") and item.has("damageMax"):
		stats.append("dano %d–%d" % [int(item["damageMin"]), int(item["damageMax"])])
	if item.has("healMin") and item.has("healMax"):
		stats.append("cura %d–%d" % [int(item["healMin"]), int(item["healMax"])])
	if item.has("hitChance"):
		stats.append("%d%% de acerto" % roundi(float(item["hitChance"]) * 100.0))
	if float(item.get("critChance", 0.0)) > 0.0:
		stats.append("%d%% de crítico" % roundi(float(item["critChance"]) * 100.0))
	var header := "%s (%s)" % [name_text, " · ".join(stats)] if not stats.is_empty() else name_text
	var note := String(item.get("tooltipNote", "")).replace("<br>", "\n   ")
	if note != "":
		return "%s\n   %s" % [header, note]
	return header

func _add_info_heading(text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color("7fc8ff"))
	_info_content.add_child(heading)

func _add_info_text(text: String, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", color)
	_info_content.add_child(label)

# --- comum ---------------------------------------------------------------

func _on_back_pressed() -> void:
	if _step == "scenario":
		_show_step_monsters(_current_group)
	elif _step == "monsters":
		# "Voltar aos grupos" (pedido do usuário): nunca mexe em
		# _selected_monsters — a composição sobrevive à troca de categoria.
		_show_step_groups()

func _on_confirm_pressed() -> void:
	if _step == "groups" and _selected_monsters.size() >= MIN_MONSTERS and _selected_monsters.size() <= MAX_MONSTERS:
		_show_step_scenario()
	elif _step == "monsters" and _selected_monsters.size() >= MIN_MONSTERS and _selected_monsters.size() <= MAX_MONSTERS:
		_show_step_scenario()
	elif _step == "scenario" and _selected_scenario != "":
		battle_configured.emit(_hero_keys.duplicate(), _selected_monsters.duplicate(), _selected_scenario)
