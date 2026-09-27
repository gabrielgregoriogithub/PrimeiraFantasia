extends Node2D

const ART_DIRECTION := preload("res://data/art_direction_config.gd")

## Composição da cena jogável (Fase 6): instancia um GameState, desenha o
## tabuleiro/tokens e liga clique do jogador + turnos automáticos da IA na
## camada de regras já pronta (equivalente simplificado do
## onTileClick()/openActionMenu()/enemyAct() do protótipo JS). Magias de área
## pedem confirmação em 2 cliques (ver AOE_CONFIRM_MODES/openAoeConfirmation
## no JS original); ataques básicos e as demais magias ainda resolvem direto
## no clique, simplificação deliberada mantida por enquanto.

## targetMode das magias de área que exigem 2 cliques: o primeiro só acende
## a prévia (aoe_preview_tiles); o segundo, no MESMO tile, abre o popup de
## confirmação. Mesmo conjunto do `if` de onTileClick no JS original.
## Duração do voo do Chute do Dragão até o alvo (pedido do usuário: ~2 s).
const DRAGON_KICK_FLIGHT_SECONDS := 2.0

const AOE_CONFIRM_MODES := [
	"point-aoe", "line-aoe", "creeping-line", "flame-creeping-line", "cardinal-blast", "pierce-line",
	"cone-poison", "cure-aoe", "heal-aoe", "regen-aoe", "mana-aoe", "trap", "freeze-aoe", "cone-windstorm", "cone-ice",
	"inflict-wounds", "arrow-rain", "cone-fire", "self-aoe", "crescent-arc",
	"dust-square", "heal-cross",
]

## Cor cosmética do flash de invocação (_resolve_spell, targetMode "summon")
## por `kind` da magia — não afeta a regra (a lógica real mora em cada
## cast_summon_*, ver game_state.gd/_cast_summon_unit).
const SUMMON_VFX_KIND := {
	"summon-living-fire": "fireball",
	"summon-vampire-bat": "arcane",
	"summon-skeleton": "poison",
	"summon-zombie": "poison",
}
const WARRIOR_SLASH_SCENE := preload("res://effects/slash.tscn")
const COMBAT_FEEDBACK_MANAGER := preload("res://scenes/combat_feedback_manager.gd")
const BATTLE_PRESENTATION_CONTROLLER := preload("res://scenes/battle_presentation_controller.gd")
const CLASS_VISUAL_PROFILES := preload("res://data/class_visual_profiles.gd")

var state: GameState
## Janela de tela FIXA dedicada ao tabuleiro (ver _board_clip logo abaixo) e
## base de toda a HUD que se ancora "ao lado"/"abaixo" dela (botões, fila de
## turnos, painéis). De propósito NÃO multiplica por BoardView.TILE_SIZE:
## desde que os tiles ficaram 50% maiores (pedido do usuário), o tabuleiro
## lógico (13x13 * 96px = 1248px) não cabe mais inteiro na tela — zoom/
## arrasto (ver board_view.gd:_update_camera/set_view_zoom/pan_view_by)
## mostram esse mapa maior DENTRO desta mesma janela de tela, que continua
## do tamanho de sempre. Mudar TILE_SIZE de novo no futuro não deve mexer
## aqui — é uma constante de LAYOUT DE TELA, não do mundo do jogo.
const BOARD_DISPLAY_PX := 832.0
## Envolve board_view com clip_contents=true pra cortar fisicamente qualquer
## tile fora da janela fixa de tela (BOARD_DISPLAY_PXxBOARD_DISPLAY_PX) —
## necessário pra Horda, cujo mapa real (26x22) é maior que essa janela e
## vazaria tiles extras se dependesse só do enquadramento da Camera2D (ver
## board_view.gd:_update_camera), e agora também serve de área visível pro
## zoom/arrasto do resto dos cenários (Campo/Torre/Vila).
var _board_clip: Control
var board_view: BoardView
var unit_tokens: Dictionary = {}
var effects_layer: EffectsLayer
var combat_feedback
var battle_presentation: BattlePresentationController
## ETAPA 17: só traduz decisões que GameState.enemy_act já tomou em
## apresentação (stance, alvo, reação a morte de aliado); nunca decide nada.
var enemy_visual_behavior := EnemyVisualBehaviorController.new()
var _hud_layer: CanvasLayer

## Controle de cada time: true = jogador humano decide pelo clique, false =
## a IA (state.enemy_act) joga sozinha por esse time — dá pra assistir IA
## vs IA ou jogar os dois lados, alternando pelos botões da HUD.
var player_is_human: bool = true
var enemy_is_human: bool = false
var _ai_sequence_running: bool = false
var _ai_sequence_id: int = 0
const AI_TURN_INTRO_DELAY := 0.75
const AI_TURN_RESULT_DELAY := 1.35
## Pedido do usuário: dá pra acompanhar quem andou/atacou/quem tomou dano —
## a IA anda mais devagar que o jogador (o jogador continua em 1.0, ver
## UnitToken.animate_path) e pausa entre "terminou de mover" e "ataca" (ver
## _run_ai_until_player_turn). Puramente apresentação; GameState resolve a
## ação inteira antes de qualquer animação tocar, então isto não muda regra.
const AI_MOVE_SPEED_SCALE := 1.4
const AI_ATTACK_PAUSE := 0.22
## Pedido do usuário: revide (Orc/Troll) precisa terminar de tocar (golpe +
## popup "CONTRA-ATAQUE!" + reação de acerto de quem revidou) antes do turno
## liberar de novo — ver _show_combat_changes (contador começa em
## `delay + 0.55`, a reação do atacante original em `+0.30` depois disso) e
## os dois pontos em _resolve_attack que esperam `popup_delay/0 + este valor`
## antes de chamar _after_action(). Mantido como constante única pra não
## dessincronizar os dois lados se um for ajustado sem o outro.
const COUNTER_RESOLVE_EXTRA_WAIT := 1.3

## "idle": clique no próprio token abre o menu; clique num tile azul move;
## clique num alvo vermelho ataca com a melhor arma automática.
## "attack": clique num alvo vermelho ataca com a arma/magia escolhida no menu.
## "spell": clique num tile roxo lança a magia/habilidade escolhida no menu.
var mode: String = "idle"
@export var warrior_ab_test := false
var pending_item: Dictionary = {}

var reachable_tiles: Array = []
var attackable_units: Array = []
var attack_range_tiles: Array = []
## Quando o herói montado escolhe um golpe/habilidade da Vestruz, quem executa
## é a Vestruz (pending_caster); o turno continua sendo do cavaleiro.
var pending_caster: Variant = null
var spell_tiles: Array = []

## Prévia de 2 cliques pra magia de área (equivalente a aoePreviewTarget/
## aoePreviewTiles no JS): null enquanto nenhum alvo foi pré-selecionado.
var aoe_preview_target: Variant = null
var aoe_preview_tiles: Array = []

## Callable chamado ao confirmar o popup de área (equivalente a
## pendingConfirmation.onConfirm no JS); Callable() (inválido) = sem popup aberto.
var pending_confirm_action: Callable = Callable()

var _turn_label: Label
var _status_label: Label
var _log_label: Label
var _end_turn_button: Button
var _music_mute_button: Button
var _music_muted: bool = false
var _restart_button: Button
## Pedido do usuário: botão separado de "Reiniciar Partida" (_restart_button,
## refaz a MESMA batalha) — este descarta tudo e volta pra tela de abertura/
## seleção de modo (ver _return_to_main_menu).
var _return_to_menu_button: Button
var _player_control_button: Button
var _enemy_control_button: Button
var _action_menu_panel: PanelContainer
var _action_menu_vbox: VBoxContainer
var _end_screen: PanelContainer
var _end_screen_title: Label
## true entre uma vitória e o avanço automático de fase (ver
## _start_victory_phase_advance) — evita disparar a fanfarra/troca de cenário
## mais de uma vez enquanto battle_ended segue true chamando _refresh_hud().
var _phase_advance_pending: bool = false
var _confirm_panel: PanelContainer
var _confirm_title_label: Label
var _confirm_body_label: Label
var _confirm_ok_button: Button
var _confirm_cancel_button: Button
var _facing_panel: Control
var _facing_pending_unit: Dictionary = {}
var _facing_confirm_button: Button
var _facing_back_button: Button
var _facing_title_label: Label
var _facing_direction_buttons: Array[Button] = []
var _facing_button_group := ButtonGroup.new()
## Direção de antes de abrir o seletor (pedido do usuário: "Voltar" desiste
## de encerrar o turno) — clicar numa seta já vira o personagem na hora, pra
## pré-visualizar; sem isso, desistir deixaria a direção trocada mesmo sem
## ter confirmado nada.
var _facing_original_direction: Dictionary = {}
var _waiting_for_projectile_turn_end := false
var _area_sequence_active := false

## --- Arrastar o tabuleiro com o botão esquerdo (pedido do usuário) --------
## Decide clique-vs-arrasto SÓ na soltura do botão: pressionar apenas guarda
## a posição inicial (não seleciona/move/ataca ainda); se o ponteiro andar
## mais que DRAG_PAN_THRESHOLD_PX antes de soltar, vira arrasto (pan contínuo
## via board_view.pan_view_by) e a soltura NÃO dispara clique nenhum. Sem
## arrasto de verdade, a soltura chama exatamente a mesma lógica de clique
## que existia antes (ver _handle_board_click_at).
const DRAG_PAN_THRESHOLD_PX := 6.0
var _drag_pointer_down := false
var _drag_start_pos := Vector2.ZERO
var _drag_last_pos := Vector2.ZERO
var _drag_is_panning := false
var _unit_info_panel: PanelContainer
var _unit_info_title: Label
var _unit_info_content: VBoxContainer
var _turn_queue_panel: PanelContainer
var _turn_queue_hbox: HBoxContainer
var scenario_manager: ScenarioManager
var _field_button: Button
var _tower_button: Button
var _floor2_button: Button
var _floor3_button: Button
var _floor4_button: Button
var _lua_button: Button
var _village_button: Button
var _forest_button: Button
var _porto_button: Button
var _desfiladeiro_button: Button
var _estrada_inverno_button: Button
var _templo_button: Button
var _cemiterio_button: Button
var _scenario_fade: ColorRect
var _scenario_banner: Label
const CAMPAIGN_SAVE_PATH := "user://campaign_progress.cfg"
const MAX_ACTIVE_HEROES := 5
var bardo_unlocked := false
var selected_party_keys: Array = []
## Definido pelo assistente do Modo PVP (PvpSetup) ao confirmar a 3ª etapa:
## {"heroes": Array[String], "monsters": Array[String]}. null = partida
## normal (campanha). Ver _start_new_game()/GameState.apply_pvp_scenario.
var _active_pvp_battle: Variant = null
var _online_mode := false
var _online_slot := 0
var _online_lobby_layer: CanvasLayer
## true enquanto o quadro nativo de seleção de heróis (_show_party_selection)
## está sendo usado pela ETAPA 1 do Modo PVP, não pelo gate normal de
## campanha (_scenario_requires_party_selection) — faz _available_hero_keys()
## sempre oferecer os 6 heróis e _confirm_party_selection() seguir pro
## assistente de monstros/cenário em vez de iniciar a partida direto.
var _pvp_mode_active := false
var _party_selection_panel: PanelContainer
var _party_selection_grid: GridContainer
var _party_selection_counter: Label
var _party_selection_confirm: Button
var _party_card_buttons: Dictionary = {}
var _party_selection_confirmed_for_start := false
var _party_selection_hidden_for_info := false

## Cutscene de abertura ("A Vila em Chamas") — pedido do usuário: ao abrir o
## jogo, mostra esse filme antes de entrar na Vila. A primeira versão abria
## uma página HTML própria no navegador padrão do sistema via OS.shell_open,
## mas isso depende da associação de arquivo .html do Windows do usuário, que
## falhou silenciosamente numa máquina (nenhum navegador abria, sem erro
## nenhum do lado do Godot pra detectar) — pedido do usuário pra rodar dentro
## do próprio jogo. Reimplementada nativa em scenes/intro_cutscene.gd
## (IntroCutscene: mesmas 3 imagens/falas, TextureRect+Tween em vez de
## HTML/CSS) — roda dentro da janela do jogo, sem processo externo. Como a
## sequência toda roda aqui dentro, o sinal `finished` dispara no momento
## exato em que acaba (não precisa mais estimar uma duração fixa).
func _ready() -> void:
	scenario_manager = ScenarioManager.new()
	add_child(scenario_manager)
	# Redimensionar a janela muda quanto do mapa cabe na tela (ver
	# board_view.gd:_display_area_size) — recalcula câmera e barras de
	# rolagem pro novo tamanho, senão o alcance de arrasto ficaria
	# desatualizado até a próxima interação.
	get_viewport().size_changed.connect(func():
		# set_view_zoom (API pública) já chama _update_camera() por dentro —
		# reatribuir o mesmo valor só força o recálculo pro novo tamanho de
		# janela, sem duplicar a lógica de câmera aqui.
		if board_view != null: board_view.set_view_zoom(board_view.view_zoom)
		_sync_board_scroll()
	)
	# Testes (GUT) não têm ninguém esperando a cutscene — pula direto pro
	# boot normal, senão todo teste que instancia Main.tscn ficaria preso
	# esperando ela terminar. DisplayServer.get_name() não serve de sinal
	# aqui: mesmo a invocação de teste real (godot -s addons/gut/gut_cmdln.gd
	# ...) roda com display "Windows", não "headless" — só falta mesmo a
	# flag --headless no próprio comando. O sinal confiável é a própria
	# invocação via gut_cmdln.gd nos argumentos de linha de comando.
	if _is_running_under_gut():
		_build_hud()
		_start_new_game()
		return
	_load_campaign_progress()
	_show_boot_flow()

func _is_running_under_gut() -> bool:
	for arg in OS.get_cmdline_args():
		if "gut_cmdln" in arg:
			return true
	return false

## Fluxo de abertura pedido pelo usuário: logo (SplashScreen, 4s) -> menu
## principal (MainMenu, Modo Historia / Modo PVP) -> ou a cutscene de sempre
## (Modo Historia, sem nenhuma mudanca no que ja existia) ou o assistente de
## configuracao do PVP (PvpSetup: herois -> monstros -> cenario).
func _show_boot_flow() -> void:
	# Pedido do usuário: a mesma música da Torre também toca na abertura do
	# jogo (splash -> menu -> cutscene), não só depois de entrar num cenário
	# de batalha — sem isso, esse trecho tocava a trilha ambiente sintetizada
	# (ver AudioEngine._process), já que set_scenario_music só era chamado ao
	# confirmar uma partida.
	AudioEngine.set_scenario_music("boot")
	var splash_layer := CanvasLayer.new()
	splash_layer.layer = 100
	add_child(splash_layer)
	var splash := SplashScreen.new()
	splash_layer.add_child(splash)
	splash.finished.connect(func():
		splash_layer.queue_free()
		_show_main_menu()
	)
	splash.play()

func _show_main_menu() -> void:
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 100
	add_child(menu_layer)
	var menu := MainMenu.new()
	menu_layer.add_child(menu)
	menu.story_selected.connect(func():
		menu_layer.queue_free()
		_play_intro_cutscene()
	)
	menu.pvp_selected.connect(func():
		menu_layer.queue_free()
		_show_pvp_setup()
	)
	menu.online_selected.connect(func(mode: String):
		menu_layer.queue_free()
		_show_online_lobby(mode)
	)

func _show_online_lobby(mode: String) -> void:
	_online_lobby_layer = CanvasLayer.new()
	_online_lobby_layer.layer = 100
	add_child(_online_lobby_layer)
	var lobby := OnlineLobby.new()
	_online_lobby_layer.add_child(lobby)
	lobby.closed.connect(func():
		_online_lobby_layer.queue_free()
		_online_lobby_layer = null
		_show_main_menu()
	)
	lobby.match_ready.connect(func(payload: Dictionary):
		_online_lobby_layer.queue_free()
		_online_lobby_layer = null
		_start_online_battle(payload)
	)
	lobby.begin(mode, OnlineConfig.room_from_url())
	OnlineEndpoint.snapshot_received.connect(_on_online_snapshot)
	OnlineEndpoint.action_rejected.connect(func(reason): _show_scenario_banner("ONLINE: %s" % reason))

func _start_online_battle(payload: Dictionary) -> void:
	_online_mode = true
	_online_slot = int(payload.get("slot", OnlineEndpoint.slot()))
	player_is_human = _online_slot == 1
	enemy_is_human = _online_slot == 2
	_active_pvp_battle = {"heroes": payload.get("heroes", Units.player_team_keys().slice(0, 5)), "monsters": payload.get("monsters", Units.enemy_team_keys().slice(0, 5))}
	scenario_manager.set_active(String(payload.get("scenario", ScenarioManager.FIELD)))
	if _hud_layer == null: _build_hud()
	_start_new_game()
	_on_online_snapshot(payload.get("snapshot", {}))

func _on_online_snapshot(snapshot: Dictionary) -> void:
	if not _online_mode or state == null or snapshot.is_empty(): return
	var by_name := {}
	for remote_unit in snapshot.get("units", []): by_name[String(remote_unit.get("name", ""))] = remote_unit
	for local_unit in state.units:
		var remote = by_name.get(String(local_unit.get("name", "")), null)
		if remote != null:
			local_unit.clear()
			local_unit.merge(remote, true)
	state.terrain_map = snapshot.get("terrain_map", {}).duplicate(true)
	state.structures = snapshot.get("structures", []).duplicate(true)
	state.elevation_map = snapshot.get("elevation_map", {}).duplicate(true)
	state.traps = snapshot.get("traps", []).duplicate(true)
	state.souls = snapshot.get("souls", []).duplicate(true)
	state.turn_token = int(snapshot.get("turn_token", state.turn_token))
	state.global_turn_count = int(snapshot.get("global_turn_count", state.global_turn_count))
	state.battle_ended = bool(snapshot.get("battle_ended", state.battle_ended))
	state.battle_won = bool(snapshot.get("battle_won", state.battle_won))
	state.event_log = snapshot.get("event_log", []).duplicate(true)
	state.last_action_vfx = snapshot.get("last_action_vfx", {}).duplicate(true)
	var actor_name := String(snapshot.get("current_actor", ""))
	state.current_actor = state.units.filter(func(u): return String(u.get("name", "")) == actor_name)[0] if state.units.any(func(u): return String(u.get("name", "")) == actor_name) else null
	_sync_visuals()

## Etapa 1 do Modo PVP (pedido do usuário): heróis primeiro, no MESMO quadro
## "5 de 6" com retrato e "Ver personagem" já usado nos andares 3º/4º da
## Torre (_show_party_selection/_build_party_selection_panel) — não um
## quadro próprio do PvpSetup. _pvp_mode_active faz _available_hero_keys()
## oferecer os 6 heróis sempre, ignorando bardo_unlocked (o Bardo não deveria
## ficar bloqueado numa batalha PVP customizada). A confirmação continua em
## _confirm_party_selection(), que desvia pro PVP em vez do fluxo de campanha
## quando essa flag está ligada (ver mais abaixo).
func _show_pvp_setup() -> void:
	_pvp_mode_active = true
	selected_party_keys = []
	if _hud_layer == null:
		_build_hud()
	_show_party_selection()

## Etapas 2 e 3 (monstros, cenário) do PvpSetup, já com os heróis prontos.
func _show_pvp_monster_and_scenario_setup(hero_keys: Array) -> void:
	var setup_layer := CanvasLayer.new()
	setup_layer.layer = 100
	add_child(setup_layer)
	var setup := PvpSetup.new()
	setup_layer.add_child(setup)
	setup.battle_configured.connect(func(_unused_hero_keys: Array, monster_keys: Array, scenario_id: String):
		setup_layer.queue_free()
		_on_pvp_battle_configured(hero_keys, monster_keys, scenario_id)
	)
	setup.begin(hero_keys)

func _on_pvp_battle_configured(hero_keys: Array, monster_keys: Array, scenario_id: String) -> void:
	_active_pvp_battle = {"heroes": hero_keys, "monsters": monster_keys}
	scenario_manager.set_active(scenario_id)
	AudioEngine.set_scenario_music(scenario_id)
	_start_new_game()

func _play_intro_cutscene() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var cutscene := IntroCutscene.new()
	layer.add_child(cutscene)
	cutscene.finished.connect(func():
		layer.queue_free()
		_build_hud()
		_start_new_game()
	)
	cutscene.play()

## (Re)começa uma partida do zero: descarta o GameState e os tokens
## anteriores (se houver — ver "Reiniciar Partida") e monta tudo de novo.
func _start_new_game() -> void:
	var scenario_id := scenario_manager.active_id
	if _active_pvp_battle == null and _scenario_requires_party_selection(scenario_id) and not _party_selection_confirmed_for_start:
		_show_party_selection()
		return
	_party_selection_confirmed_for_start = false
	_ai_sequence_id += 1
	_area_sequence_active = false
	_waiting_for_projectile_turn_end = false
	if effects_layer != null:
		for effect in effects_layer.get_children():
			if effect.get_script() == EffectsLayer.AREA_SEQUENCE: effect.queue_free()
	_ai_sequence_running = false
	enemy_visual_behavior.reset()
	for token in unit_tokens.values():
		(token as UnitToken).queue_free()
	unit_tokens.clear()
	if board_view != null:
		board_view.queue_free()
	if battle_presentation != null:
		battle_presentation.queue_free()
		battle_presentation = null

	mode = "idle"
	pending_item = {}
	reachable_tiles = []
	attackable_units = []
	attack_range_tiles = []
	spell_tiles = []
	_clear_aoe_preview()
	_close_confirm_panel()
	if _unit_info_panel != null: _close_unit_info()

	state = GameState.new()
	var scenario := scenario_manager.active_definition()
	if _active_pvp_battle != null:
		state.apply_pvp_scenario(scenario, _active_pvp_battle["heroes"], _active_pvp_battle["monsters"])
	else:
		state.configure_campaign(bardo_unlocked, selected_party_keys)
		state.apply_scenario(scenario)

	if _board_clip == null:
		_board_clip = Control.new()
		_board_clip.position = Vector2(24, 64)
		_board_clip.size = Vector2.ONE * BOARD_DISPLAY_PX
		_board_clip.clip_contents = true
		_board_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_board_clip)

	board_view = BoardView.new()
	_board_clip.add_child(board_view)
	board_view.position = Vector2.ZERO
	board_view.set_state(state)
	board_view.set_scenario(scenario)
	_update_board_zoom_label()
	_sync_board_scroll()

	for u in state.units:
		var token := UnitToken.new()
		board_view.add_child(token)
		token.z_index = 10
		token.setup(u)
		unit_tokens[u["name"]] = token

	effects_layer = EffectsLayer.new()
	board_view.add_child(effects_layer)
	effects_layer.z_index = 2000
	combat_feedback = COMBAT_FEEDBACK_MANAGER.new()
	board_view.add_child(combat_feedback)
	combat_feedback.setup(board_view, effects_layer)
	battle_presentation = BATTLE_PRESENTATION_CONTROLLER.new()
	add_child(battle_presentation)
	battle_presentation.setup(board_view, _hud_layer)
	battle_presentation.presentation_finished.connect(_on_battle_intro_finished)
	battle_presentation.outcome_finished.connect(_on_battle_outcome_presentation_finished)
	if scenario.get("id", ScenarioManager.FIELD) == ScenarioManager.TOWER:
		_build_tower_atmosphere(scenario)

	_end_screen.visible = false
	_phase_advance_pending = false

	state.begin_turn_for(state.advance_ct_until_ready())
	_refresh_scenario_buttons()
	if _is_running_under_gut():
		battle_presentation.phase = BattlePresentationController.Phase.COMBAT
		_run_ai_until_player_turn()
	else:
		var hero_tokens: Array = []
		var enemy_tokens: Array = []
		var objective_tokens: Array = []
		for token in unit_tokens.values():
			var unit_token := token as UnitToken
			if unit_token.unit.get("team", "") == "player": hero_tokens.append(unit_token)
			else: enemy_tokens.append(unit_token)
			if unit_token.unit.get("caged", false): objective_tokens.append(unit_token)
		battle_presentation.play_intro(scenario, hero_tokens, enemy_tokens, objective_tokens)

## Pedido do usuário: botão "Reiniciar Jogo" (ver _build_hud) — descarta a
## partida em andamento (mesma limpeza de tokens/board_view/
## battle_presentation que _start_new_game já faz) e também a própria HUD,
## voltando pro MESMO fluxo de abertura de _show_boot_flow() (SplashScreen ->
## MainMenu), como se o jogo tivesse acabado de ser aberto. Não mexe no save
## de campanha (bardo_unlocked/campaign_bardo_unlocked) — só navega de volta,
## não reseta progresso.
func _return_to_main_menu() -> void:
	_pvp_mode_active = false
	_active_pvp_battle = null
	selected_party_keys = []
	_party_selection_confirmed_for_start = false
	enemy_visual_behavior.reset()
	for token in unit_tokens.values():
		(token as UnitToken).queue_free()
	unit_tokens.clear()
	if board_view != null:
		board_view.queue_free()
		board_view = null
	if battle_presentation != null:
		battle_presentation.queue_free()
		battle_presentation = null
	if _board_clip != null:
		_board_clip.queue_free()
		_board_clip = null
	if _hud_layer != null:
		_hud_layer.queue_free()
		_hud_layer = null
	# _scenario_fade vive numa CanvasLayer própria, IRMÃ de _hud_layer (não
	# filha — ver comentário em _build_scenario_controls), então o queue_free
	# do _hud_layer acima não a alcança; sem isso, cada "Reiniciar Jogo"
	# empilhava mais uma camada de fade preta esquecida por trás do menu.
	if _scenario_fade != null:
		_scenario_fade.get_parent().queue_free()
		_scenario_fade = null
	_show_boot_flow()

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	add_child(_hud_layer)
	var layer := _hud_layer
	_build_scenario_controls(layer)

	_turn_label = Label.new()
	_turn_label.position = Vector2(410, 70)
	_turn_label.add_theme_font_size_override("font_size", 16)
	_turn_label.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(_turn_label)

	_status_label = Label.new()
	_status_label.position = Vector2(410, 50)
	_status_label.size = Vector2(220, 20)
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	layer.add_child(_status_label)

	_end_turn_button = Button.new()
	_end_turn_button.text = "Encerrar Turno"
	_end_turn_button.position = Vector2(BOARD_DISPLAY_PX - 120, 16)
	_end_turn_button.size = Vector2(140, 32)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	layer.add_child(_end_turn_button)

	_music_mute_button = Button.new()
	_music_mute_button.text = "🔊 Música"
	_music_mute_button.position = Vector2(BOARD_DISPLAY_PX - 120, 54)
	_music_mute_button.size = Vector2(140, 28)
	_music_mute_button.pressed.connect(_on_music_mute_pressed)
	layer.add_child(_music_mute_button)

	_restart_button = Button.new()
	_restart_button.text = "🔄 Reiniciar Partida"
	_restart_button.position = Vector2(BOARD_DISPLAY_PX - 270, 16)
	_restart_button.size = Vector2(140, 32)
	_restart_button.pressed.connect(_start_new_game)
	layer.add_child(_restart_button)

	# Pedido do usuário: botão no topo pra "reiniciar o jogo" de verdade —
	# volta pra abertura (SplashScreen) e seleção de modo (MainMenu), não só
	# refaz a MESMA batalha como o "Reiniciar Partida" acima. Posicionado no
	# vão livre entre os botões de cenário (terminam por volta de x=392) e o
	# cluster de botões da direita (começa em x=BOARD_SIZE*TILE_SIZE-270).
	_return_to_menu_button = Button.new()
	_return_to_menu_button.text = "🏠 Reiniciar Jogo"
	_return_to_menu_button.position = Vector2(410, 16)
	_return_to_menu_button.size = Vector2(150, 32)
	_return_to_menu_button.pressed.connect(_return_to_main_menu)
	layer.add_child(_return_to_menu_button)

	_player_control_button = Button.new()
	_player_control_button.position = Vector2(BOARD_DISPLAY_PX - 270, 54)
	_player_control_button.size = Vector2(140, 28)
	_player_control_button.pressed.connect(func(): _on_toggle_control_pressed(true))
	layer.add_child(_player_control_button)

	_enemy_control_button = Button.new()
	_enemy_control_button.position = Vector2(BOARD_DISPLAY_PX - 270, 92)
	_enemy_control_button.size = Vector2(140, 28)
	_enemy_control_button.pressed.connect(func(): _on_toggle_control_pressed(false))
	layer.add_child(_enemy_control_button)
	_refresh_control_buttons()

	_action_menu_panel = PanelContainer.new()
	_action_menu_panel.position = Vector2(BOARD_DISPLAY_PX - 210, 130)
	_action_menu_panel.custom_minimum_size = Vector2(210, 0)
	_action_menu_panel.visible = false
	var parchment := StyleBoxFlat.new()
	parchment.bg_color = Color("e8d3a3")
	parchment.border_color = Color("76502c")
	parchment.set_border_width_all(3)
	parchment.corner_radius_top_left = 9
	parchment.corner_radius_top_right = 9
	parchment.corner_radius_bottom_left = 9
	parchment.corner_radius_bottom_right = 9
	parchment.content_margin_left = 10
	parchment.content_margin_right = 10
	parchment.content_margin_top = 10
	parchment.content_margin_bottom = 10
	_action_menu_panel.add_theme_stylebox_override("panel", parchment)
	layer.add_child(_action_menu_panel)
	_action_menu_vbox = VBoxContainer.new()
	_action_menu_panel.add_child(_action_menu_vbox)

	_build_facing_panel(layer)
	_build_turn_queue(layer)
	_build_board_zoom_controls(layer)
	_build_board_scrollbars(layer)

	_log_label = Label.new()
	_log_label.position = Vector2(24, BOARD_DISPLAY_PX + 178)
	_log_label.size = Vector2(BOARD_DISPLAY_PX, 220)
	_log_label.add_theme_font_size_override("font_size", 13)
	_log_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	layer.add_child(_log_label)

	_build_end_screen(layer)
	_build_confirm_panel(layer)
	_build_unit_info_panel(layer)
	_build_party_selection_panel(layer)
	_apply_global_ui_theme()

func _apply_global_ui_theme() -> void:
	# Uma família de botões para HUD, combate, seleção e menus. Overrides
	# específicos (pergaminho/objetivo) continuam vencendo o tema global.
	var art_theme := ART_DIRECTION.make_ui_theme()
	for child in _hud_layer.get_children():
		if child is Control: (child as Control).theme = art_theme

func _build_scenario_controls(layer: CanvasLayer) -> void:
	# Seletor compacto em duas linhas, inteiramente ancorado à esquerda.
	# Cenários externos ficam na primeira; Torre e seus andares, na segunda.
	_village_button = Button.new()
	_village_button.text = "VILA"
	_village_button.toggle_mode = true
	_village_button.position = Vector2(16, 16)
	_village_button.size = Vector2(70, 32)
	_village_button.pressed.connect(func(): _switch_scenario(ScenarioManager.VILLAGE))
	layer.add_child(_village_button)
	_forest_button = Button.new()
	_forest_button.text = "FLORESTA"
	_forest_button.toggle_mode = true
	_forest_button.position = Vector2(88, 16)
	_forest_button.size = Vector2(90, 32)
	_forest_button.pressed.connect(func(): _switch_scenario(ScenarioManager.FOREST))
	layer.add_child(_forest_button)
	_porto_button = Button.new()
	_porto_button.text = "PORTO"
	_porto_button.toggle_mode = true
	_porto_button.position = Vector2(16, 50)
	_porto_button.size = Vector2(78, 32)
	_porto_button.pressed.connect(func(): _switch_scenario(ScenarioManager.PORTO))
	layer.add_child(_porto_button)
	_desfiladeiro_button = Button.new()
	_desfiladeiro_button.text = "DESFILADEIRO"
	_desfiladeiro_button.toggle_mode = true
	_desfiladeiro_button.position = Vector2(98, 50)
	_desfiladeiro_button.size = Vector2(126, 32)
	_desfiladeiro_button.pressed.connect(func(): _switch_scenario(ScenarioManager.DESFILADEIRO))
	layer.add_child(_desfiladeiro_button)
	_estrada_inverno_button = Button.new()
	_estrada_inverno_button.text = "ESTRADA INVERNO"
	_estrada_inverno_button.toggle_mode = true
	_estrada_inverno_button.position = Vector2(230, 50)
	_estrada_inverno_button.size = Vector2(150, 32)
	_estrada_inverno_button.pressed.connect(func(): _switch_scenario(ScenarioManager.ESTRADA_INVERNO))
	layer.add_child(_estrada_inverno_button)
	_templo_button = Button.new()
	_templo_button.text = "TEMPLO"
	_templo_button.toggle_mode = true
	_templo_button.position = Vector2(16, 116)
	_templo_button.size = Vector2(84, 28)
	_templo_button.pressed.connect(func(): _switch_scenario(ScenarioManager.TEMPLO))
	layer.add_child(_templo_button)
	_cemiterio_button = Button.new()
	_cemiterio_button.text = "CEMITÉRIO"
	_cemiterio_button.toggle_mode = true
	_cemiterio_button.position = Vector2(104, 116)
	_cemiterio_button.size = Vector2(112, 28)
	_cemiterio_button.pressed.connect(func(): _switch_scenario(ScenarioManager.CEMITERIO))
	layer.add_child(_cemiterio_button)
	_field_button = Button.new()
	_field_button.text = "CAMPO"
	_field_button.toggle_mode = true
	_field_button.position = Vector2(180, 16)
	_field_button.size = Vector2(70, 32)
	_field_button.pressed.connect(func(): _switch_scenario(ScenarioManager.FIELD))
	layer.add_child(_field_button)
	_lua_button = Button.new()
	_lua_button.text = "HORDA"
	_lua_button.toggle_mode = true
	_lua_button.position = Vector2(252, 16)
	_lua_button.size = Vector2(108, 32)
	_lua_button.pressed.connect(func(): _switch_scenario(ScenarioManager.LUA_VALLEY))
	layer.add_child(_lua_button)
	_tower_button = Button.new()
	_tower_button.text = "TORRE"
	_tower_button.toggle_mode = true
	_tower_button.position = Vector2(16, 84)
	_tower_button.size = Vector2(70, 32)
	_tower_button.pressed.connect(func(): _switch_scenario(ScenarioManager.TOWER))
	layer.add_child(_tower_button)
	_floor2_button = Button.new()
	_floor2_button.text = "2º ANDAR"
	_floor2_button.toggle_mode = true
	_floor2_button.position = Vector2(88, 84)
	_floor2_button.size = Vector2(100, 28)
	_floor2_button.pressed.connect(func(): _switch_scenario(ScenarioManager.TOWER_FLOOR_2))
	layer.add_child(_floor2_button)
	_floor3_button = Button.new()
	_floor3_button.text = "3º ANDAR"
	_floor3_button.toggle_mode = true
	_floor3_button.position = Vector2(190, 84)
	_floor3_button.size = Vector2(100, 28)
	_floor3_button.pressed.connect(func(): _switch_scenario(ScenarioManager.TOWER_FLOOR_3))
	layer.add_child(_floor3_button)
	_floor4_button = Button.new()
	_floor4_button.text = "4º ANDAR"
	_floor4_button.toggle_mode = true
	_floor4_button.position = Vector2(292, 84)
	_floor4_button.size = Vector2(100, 28)
	_floor4_button.pressed.connect(func(): _switch_scenario(ScenarioManager.TOWER_FLOOR_4))
	layer.add_child(_floor4_button)
	_scenario_banner = Label.new()
	_scenario_banner.position = Vector2(410, 112)
	_scenario_banner.size = Vector2(220, 42)
	_scenario_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scenario_banner.add_theme_font_size_override("font_size", 24)
	_scenario_banner.add_theme_color_override("font_color", Color("fff0c2"))
	_scenario_banner.add_theme_color_override("font_shadow_color", Color.BLACK)
	_scenario_banner.add_theme_constant_override("shadow_offset_x", 2)
	_scenario_banner.add_theme_constant_override("shadow_offset_y", 2)
	_scenario_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scenario_banner.modulate.a = 0.0
	layer.add_child(_scenario_banner)
	# CanvasLayer própria (não filho de `layer`/_hud_layer): BattlePresentationController
	# ._set_hud_alpha() percorre TODOS os filhos de hud_layer e sobe o alpha
	# deles pra 1.0 ao revelar a HUD após a intro — incluindo, por engano,
	# este ColorRect preto opaco (achado depurando a tela preta ao entrar em
	# combate). Isolado na própria camada, ele fica de fora dessa varredura e
	# só é animado pelo tween explícito de _switch_scenario.
	var scenario_fade_layer := CanvasLayer.new()
	scenario_fade_layer.layer = 60
	add_child(scenario_fade_layer)
	_scenario_fade = ColorRect.new()
	_scenario_fade.color = Color.BLACK
	_scenario_fade.position = Vector2.ZERO
	_scenario_fade.size = Vector2(920, 1200)
	_scenario_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scenario_fade.modulate.a = 0.0
	scenario_fade_layer.add_child(_scenario_fade)

func _switch_scenario(id: String) -> void:
	if scenario_manager.active_id == id: return
	_field_button.disabled = true
	_tower_button.disabled = true
	_floor2_button.disabled = true
	_floor3_button.disabled = true
	_floor4_button.disabled = true
	_lua_button.disabled = true
	_village_button.disabled = true
	_forest_button.disabled = true
	_porto_button.disabled = true
	_desfiladeiro_button.disabled = true
	_estrada_inverno_button.disabled = true
	_templo_button.disabled = true
	_cemiterio_button.disabled = true
	var fade := create_tween()
	fade.tween_property(_scenario_fade, "modulate:a", 1.0, 0.20)
	fade.tween_callback(func():
		# Bug relatado pelo usuário: bardo_unlocked é persistido em disco
		# (user://campaign_progress.cfg) pra continuar liberado nos andares
		# SEGUINTES depois de libertado (3º/4º andar). Mas isso vazava pro
		# 2º andar em si — entrar nele de novo (clique direto ou reinício)
		# mostrava o Bardo já solto, igual encontrar a Maga já solta no
		# Campo. O 2º andar precisa sempre recomeçar com ele preso.
		if id == ScenarioManager.TOWER_FLOOR_2:
			bardo_unlocked = false
		# Simétrico ao reset acima: acessar o 3º/4º andar direto pelo botão
		# pressupõe que o 2º andar (onde o Bardo é libertado) já ficou pra
		# trás — sem isso, só 5 heróis ficavam disponíveis e a tela de
		# escolha "5 de 6" nunca aparecia.
		elif id == ScenarioManager.TOWER_FLOOR_3 or id == ScenarioManager.TOWER_FLOOR_4:
			bardo_unlocked = true
		scenario_manager.set_active(id)
		AudioEngine.set_scenario_music(id)
		_start_new_game()
	)
	fade.tween_property(_scenario_fade, "modulate:a", 0.0, 0.24)
	fade.tween_callback(func():
		_field_button.disabled = false
		_tower_button.disabled = false
		_floor2_button.disabled = false
		_floor3_button.disabled = false
		_floor4_button.disabled = false
		_lua_button.disabled = false
		_village_button.disabled = false
		_forest_button.disabled = false
		_porto_button.disabled = false
		_desfiladeiro_button.disabled = false
		_estrada_inverno_button.disabled = false
		_templo_button.disabled = false
		_cemiterio_button.disabled = false
	)

func _refresh_scenario_buttons() -> void:
	if _field_button == null: return
	_field_button.button_pressed = scenario_manager.active_id == ScenarioManager.FIELD
	_tower_button.button_pressed = scenario_manager.active_id == ScenarioManager.TOWER
	_floor2_button.button_pressed = scenario_manager.active_id == ScenarioManager.TOWER_FLOOR_2
	_floor3_button.button_pressed = scenario_manager.active_id == ScenarioManager.TOWER_FLOOR_3
	_floor4_button.button_pressed = scenario_manager.active_id == ScenarioManager.TOWER_FLOOR_4
	_lua_button.button_pressed = scenario_manager.active_id == ScenarioManager.LUA_VALLEY
	_village_button.button_pressed = scenario_manager.active_id == ScenarioManager.VILLAGE
	_forest_button.button_pressed = scenario_manager.active_id == ScenarioManager.FOREST
	_porto_button.button_pressed = scenario_manager.active_id == ScenarioManager.PORTO
	_desfiladeiro_button.button_pressed = scenario_manager.active_id == ScenarioManager.DESFILADEIRO
	_estrada_inverno_button.button_pressed = scenario_manager.active_id == ScenarioManager.ESTRADA_INVERNO
	_templo_button.button_pressed = scenario_manager.active_id == ScenarioManager.TEMPLO
	_cemiterio_button.button_pressed = scenario_manager.active_id == ScenarioManager.CEMITERIO
	_field_button.modulate = Color("ffd86b") if _field_button.button_pressed else Color.WHITE
	_tower_button.modulate = Color("ffd86b") if _tower_button.button_pressed else Color.WHITE
	_floor2_button.modulate = Color("ffd86b") if _floor2_button.button_pressed else Color.WHITE
	_floor3_button.modulate = Color("ffd86b") if _floor3_button.button_pressed else Color.WHITE
	_floor4_button.modulate = Color("ffd86b") if _floor4_button.button_pressed else Color.WHITE
	_lua_button.modulate = Color("ffd86b") if _lua_button.button_pressed else Color.WHITE
	_village_button.modulate = Color("ffd86b") if _village_button.button_pressed else Color.WHITE
	_forest_button.modulate = Color("ffd86b") if _forest_button.button_pressed else Color.WHITE
	_porto_button.modulate = Color("ffd86b") if _porto_button.button_pressed else Color.WHITE
	_desfiladeiro_button.modulate = Color("ffd86b") if _desfiladeiro_button.button_pressed else Color.WHITE
	_estrada_inverno_button.modulate = Color("ffd86b") if _estrada_inverno_button.button_pressed else Color.WHITE
	_templo_button.modulate = Color("ffd86b") if _templo_button.button_pressed else Color.WHITE
	_cemiterio_button.modulate = Color("ffd86b") if _cemiterio_button.button_pressed else Color.WHITE

func _show_scenario_banner(text: String) -> void:
	if _scenario_banner == null: return
	_scenario_banner.text = text
	_scenario_banner.modulate.a = 0.0
	var banner := create_tween()
	banner.tween_property(_scenario_banner, "modulate:a", 1.0, 0.20)
	banner.tween_interval(1.15)
	banner.tween_property(_scenario_banner, "modulate:a", 0.0, 0.32)
	# Bug relatado pelo usuário: a frase de vitória ("🏆 VITÓRIA! Avançando de
	# fase...") às vezes ficava presa na tela até o cenário seguinte, quando
	# a troca de cenário interrompia a tween acima antes dela terminar de
	# sumir. Timer isolado, independente dessa tween, garante um teto rígido
	# de 3s pra qualquer frase — só limpa se ainda for a MESMA frase (não
	# apaga uma frase mais nova mostrada nesse meio-tempo).
	var shown_text := text
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(_scenario_banner) and _scenario_banner.text == shown_text:
			_scenario_banner.modulate.a = 0.0
			_scenario_banner.text = ""
	)

func _build_tower_atmosphere(definition: Dictionary) -> void:
	# O grading da Torre agora pertence ao perfil do bioma no BoardView; um
	# CanvasModulate isolado também escurecia personagens e cores funcionais.
	var dust := GPUParticles2D.new()
	dust.name = "TowerDust"
	dust.position = Vector2(GameConstants.BOARD_SIZE * BoardView.TILE_SIZE * 0.5, GameConstants.BOARD_SIZE * BoardView.TILE_SIZE * 0.5)
	dust.amount = 18
	dust.lifetime = 7.0
	dust.randomness = 0.85
	dust.z_index = 2
	var dust_material := ParticleProcessMaterial.new()
	dust_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_material.emission_box_extents = Vector3(390, 390, 1)
	dust_material.direction = Vector3(0.18, -1.0, 0.0)
	dust_material.spread = 20.0
	dust_material.initial_velocity_min = 2.0
	dust_material.initial_velocity_max = 6.0
	dust_material.gravity = Vector3.ZERO
	dust_material.scale_min = 0.7
	dust_material.scale_max = 1.5
	dust_material.color = Color(0.82, 0.76, 0.60, 0.18)
	dust.process_material = dust_material
	var dust_texture := GradientTexture2D.new()
	dust_texture.width = 3
	dust_texture.height = 3
	dust.texture = dust_texture
	board_view.add_child(dust)
	for tile in definition.get("torches", []):
		var torch := TowerTorch.new()
		torch.position = board_view.tile_center(tile["x"], tile["y"]) + Vector2(0, -18)
		board_view.add_child(torch)

func _build_turn_queue(layer: CanvasLayer) -> void:
	var board_px := BOARD_DISPLAY_PX
	_turn_queue_panel = PanelContainer.new()
	_turn_queue_panel.position = Vector2(24, 64 + board_px + 8)
	# Altura maior que antes (96->128): agora cada cartão também mostra HP/MP
	# (ver _refresh_turn_queue) — as barras de HP/MP saíram do tabuleiro e só
	# aparecem aqui, a pedido do usuário, pra não competir com o sprite do
	# personagem (que voltou ao tamanho original, maior que o tile).
	_turn_queue_panel.custom_minimum_size = Vector2(board_px, 128)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.06, 0.10, 0.96)
	panel_style.border_color = Color(0.30, 0.34, 0.48, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 4
	panel_style.content_margin_bottom = 4
	_turn_queue_panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(_turn_queue_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_turn_queue_panel.add_child(column)
	var title := Label.new()
	title.text = "PRÓXIMOS TURNOS"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("bfc9ee"))
	column.add_child(title)
	_turn_queue_hbox = HBoxContainer.new()
	_turn_queue_hbox.add_theme_constant_override("separation", 6)
	column.add_child(_turn_queue_hbox)

## Botões fixos de zoom do tabuleiro (+/−/100%, pedido do usuário) — ficam no
## canto inferior direito da janela do tabuleiro (_board_clip), FORA da
## camada que o zoom escala (board_view), então não crescem/encolhem junto
## com o mapa. Cada botão só chama board_view.change_view_zoom/reset_view
## (fonte única de verdade, ver board_view.gd) e devolve o foco pro board
## logo depois, pra um clique aqui nunca ser interpretado como clique no
## tabuleiro por baixo.
var _board_zoom_label: Label

func _build_board_zoom_controls(layer: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(24 + BOARD_DISPLAY_PX - 130, 64 + BOARD_DISPLAY_PX - 44)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.14, 0.88)
	style.border_color = Color(0.42, 0.46, 0.62, 0.9)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)

	var zoom_out := Button.new()
	zoom_out.text = "−"
	zoom_out.custom_minimum_size = Vector2(28, 28)
	zoom_out.pressed.connect(func():
		board_view.change_view_zoom(-1)
		_update_board_zoom_label()
		_sync_board_scroll()
	)
	row.add_child(zoom_out)

	_board_zoom_label = Label.new()
	_board_zoom_label.text = "60%"
	_board_zoom_label.custom_minimum_size = Vector2(44, 28)
	_board_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_board_zoom_label.add_theme_color_override("font_color", Color("d8dcf2"))
	row.add_child(_board_zoom_label)

	var zoom_in := Button.new()
	zoom_in.text = "+"
	zoom_in.custom_minimum_size = Vector2(28, 28)
	zoom_in.pressed.connect(func():
		board_view.change_view_zoom(1)
		_update_board_zoom_label()
		_sync_board_scroll()
	)
	row.add_child(zoom_in)

	var zoom_reset := Button.new()
	zoom_reset.text = "100%"
	zoom_reset.custom_minimum_size = Vector2(0, 28)
	zoom_reset.pressed.connect(func():
		board_view.reset_view()
		_update_board_zoom_label()
		_sync_board_scroll()
	)
	row.add_child(zoom_reset)

func _update_board_zoom_label() -> void:
	if _board_zoom_label != null and board_view != null:
		_board_zoom_label.text = "%d%%" % roundi(board_view.view_zoom * 100.0)

## Barras de rolagem horizontal/vertical — mesma fonte única de verdade que
## o arrasto (board_view.view_pan), só outro jeito de escrever nela (ver
## _on_board_hscroll/_on_board_vscroll). Ficam FORA de _board_clip (não são
## escaladas pelo zoom do mapa, ver pedido do usuário "não escale os
## botões"), na borda direita/inferior da janela do tabuleiro.
var _board_hscroll: HScrollBar
var _board_vscroll: VScrollBar
var _syncing_board_scroll := false

func _build_board_scrollbars(layer: CanvasLayer) -> void:
	_board_hscroll = HScrollBar.new()
	_board_hscroll.position = Vector2(24, 64 + BOARD_DISPLAY_PX + 2)
	_board_hscroll.size = Vector2(BOARD_DISPLAY_PX, 14)
	_board_hscroll.value_changed.connect(_on_board_hscroll_changed)
	layer.add_child(_board_hscroll)

	_board_vscroll = VScrollBar.new()
	_board_vscroll.position = Vector2(24 + BOARD_DISPLAY_PX + 2, 64)
	_board_vscroll.size = Vector2(14, BOARD_DISPLAY_PX)
	_board_vscroll.value_changed.connect(_on_board_vscroll_changed)
	layer.add_child(_board_vscroll)
	_sync_board_scroll()

func _on_board_hscroll_changed(value: float) -> void:
	if _syncing_board_scroll or board_view == null: return
	board_view.set_view_pan(Vector2(value, board_view.view_pan.y))
	_sync_board_scroll()

func _on_board_vscroll_changed(value: float) -> void:
	if _syncing_board_scroll or board_view == null: return
	board_view.set_view_pan(Vector2(board_view.view_pan.x, value))
	_sync_board_scroll()

## Chamada depois de QUALQUER mudança de zoom/arrasto/reset (botões, drag,
## reset_view, troca de cenário) — recalcula alcance/página das duas barras
## a partir de board_view.pan_range()/visible_world_size() e reflete
## view_pan atual nelas, sem disparar value_changed de volta (guard
## _syncing_board_scroll evita o ciclo arrasto->scrollbar->arrasto).
func _sync_board_scroll() -> void:
	if _board_hscroll == null or _board_vscroll == null or board_view == null: return
	_syncing_board_scroll = true
	var range: Vector2 = board_view.pan_range()
	var page: Vector2 = board_view.visible_world_size()
	var pan: Vector2 = board_view.view_pan
	# Range.value máximo alcançável por arrasto do thumb é (max_value - page),
	# não max_value — soma `page` de volta pra que o valor de verdade
	# alcançável bata com +range.x/y (ver docs de Range/ScrollBar).
	_board_hscroll.visible = range.x > 0.0
	_board_hscroll.min_value = -range.x
	_board_hscroll.page = page.x
	_board_hscroll.max_value = range.x + page.x
	_board_hscroll.value = clampf(pan.x, -range.x, range.x)
	_board_vscroll.visible = range.y > 0.0
	_board_vscroll.min_value = -range.y
	_board_vscroll.page = page.y
	_board_vscroll.max_value = range.y + page.y
	_board_vscroll.value = clampf(pan.y, -range.y, range.y)
	_syncing_board_scroll = false

func _predicted_turn_queue() -> Array:
	var result: Array = []
	if state == null:
		return result
	if state.current_actor != null and state.current_actor.get("hp", 0) > 0:
		result.append(state.current_actor)
	var candidates: Array = []
	for unit in state.alive_units():
		if unit.get("caged", false) or unit.get("riderName", "") != "":
			continue
		if state.current_actor != null and unit == state.current_actor:
			continue
		candidates.append(unit)
	candidates.sort_custom(func(a, b):
		var ticks_a := ceili(float(maxi(0, GameConstants.CT_THRESHOLD - int(a["ct"]))) / maxf(1.0, float(a["speed"])))
		var ticks_b := ceili(float(maxi(0, GameConstants.CT_THRESHOLD - int(b["ct"]))) / maxf(1.0, float(b["speed"])))
		if ticks_a != ticks_b: return ticks_a < ticks_b
		if a["ct"] != b["ct"]: return a["ct"] > b["ct"]
		return a["speed"] > b["speed"]
	)
	result.append_array(candidates)
	# O contador dos cadáveres avança quando todos os vivos agiram ao menos
	# uma vez na rodada. Por isso o retrato morto entra logo depois do último
	# vivo que AINDA precisa agir, em vez de ficar permanentemente na cauda.
	# Conforme round_acted_units cresce, esse marcador caminha para a esquerda
	# e mostra visualmente quando ocorrerá a próxima redução do contador.
	var corpses: Array = []
	for unit in state.units:
		if unit.get("hp", 0) <= 0 and unit.has("turnsSinceDeath"):
			corpses.append(unit)
	corpses.sort_custom(func(a, b):
		if a["turnsSinceDeath"] != b["turnsSinceDeath"]: return a["turnsSinceDeath"] > b["turnsSinceDeath"]
		return String(a["name"]) < String(b["name"])
	)
	var decay_marker_index := 0
	for index in range(result.size()):
		var queued_unit: Dictionary = result[index]
		if not state.round_acted_units.has(queued_unit["name"]):
			decay_marker_index = index + 1
	for corpse in corpses:
		result.insert(decay_marker_index, corpse)
		decay_marker_index += 1
	return result

func _refresh_turn_queue() -> void:
	if _turn_queue_hbox == null:
		return
	for child in _turn_queue_hbox.get_children():
		_turn_queue_hbox.remove_child(child)
		child.free()
	var queue := _predicted_turn_queue()
	for index in range(mini(queue.size(), 11)):
		var unit: Dictionary = queue[index]
		var frame := PanelContainer.new()
		# +14px de altura (era 68/65) pra caber a fileira de ícones de status
		# abaixo do nome (ver bloco depois de name_label — HP/MP saíram daqui
		# a pedido do usuário, status ficou no lugar deles).
		frame.custom_minimum_size = Vector2(74, 82) if index == 0 and unit == state.current_actor else Vector2(68, 79)
		var style := StyleBoxFlat.new()
		var is_current: bool = index == 0 and unit == state.current_actor
		var is_corpse: bool = int(unit.get("hp", 0)) <= 0 and unit.has("turnsSinceDeath")
		style.bg_color = Color(0.18, 0.15, 0.08, 1.0) if is_current else (Color(0.14, 0.035, 0.045, 0.98) if is_corpse else Color(0.08, 0.09, 0.14, 0.95))
		style.border_color = Color("ffd45c") if is_current else (Color("dc2638") if is_corpse else (Color("5fa8ff") if unit["team"] == "player" else (Color("b57bff") if unit["team"] == "neutral" else Color("ef6666"))))
		style.set_border_width_all(3 if is_current else 1)
		style.corner_radius_top_left = 5
		style.corner_radius_top_right = 5
		style.corner_radius_bottom_left = 5
		style.corner_radius_bottom_right = 5
		frame.add_theme_stylebox_override("panel", style)
		_turn_queue_hbox.add_child(frame)
		frame.modulate.a = 0.0
		frame.position.y = 7.0
		var queue_entry := create_tween().set_parallel(true)
		queue_entry.tween_interval(float(index) * 0.018)
		queue_entry.tween_property(frame, "modulate:a", 1.0, 0.16)
		queue_entry.tween_property(frame, "position:y", 0.0, 0.20).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 0)
		frame.add_child(slot)
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(62, 45)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_STOP
		portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		portrait.gui_input.connect(_on_turn_queue_portrait_gui_input.bind(unit))
		var portrait_path := "%s/%s_portrait.png" % [SpriteManifest.SPRITE_MANIFEST.get(unit.get("spriteKey", ""), ""), unit.get("spriteKey", "")]
		if ResourceLoader.exists(portrait_path): portrait.texture = load(portrait_path)
		var animal_spec: Dictionary = AnimalSpriteCatalog.spec(unit.get("spriteKey", ""))
		if animal_spec.has("portrait"):
			# Humanoides da Torre (tower_*): PNG de retrato dedicado, entregue
			# junto com os quadros de animação em pasta própria.
			var portrait_texture_path: String = animal_spec["portrait"]
			if ResourceLoader.exists(portrait_texture_path): portrait.texture = load(portrait_texture_path)
		elif not animal_spec.is_empty():
			var idle_key := "idle_down"
			var idle_anim: Array = animal_spec["anims"][idle_key]
			var rect: Array = idle_anim[0][0]
			var animal_portrait := AtlasTexture.new()
			animal_portrait.atlas = load(AnimalSpriteCatalog.SHEET_ROOT + animal_spec["sheet"])
			animal_portrait.region = Rect2(rect[0],rect[1],rect[2],rect[3])
			portrait.texture = animal_portrait
		portrait.modulate = Color(0.42, 0.42, 0.46, 0.72) if is_corpse else Color.WHITE
		if is_corpse:
			var rounds_left := maxi(0, 3 - int(unit.get("turnsSinceDeath", 0)))
			portrait.tooltip_text = "%s — morto(a), %d rodada(s) para virar alma" % [unit["name"], rounds_left]
			var death_mark := Label.new()
			death_mark.text = "✕"
			death_mark.position = Vector2(2, -7)
			death_mark.size = Vector2(64, 48)
			death_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			death_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			death_mark.add_theme_font_size_override("font_size", 38)
			death_mark.add_theme_color_override("font_color", Color("ff263e"))
			death_mark.add_theme_color_override("font_shadow_color", Color.BLACK)
			death_mark.add_theme_constant_override("shadow_offset_x", 2)
			death_mark.add_theme_constant_override("shadow_offset_y", 2)
			death_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait.add_child(death_mark)
			var death_count := Label.new()
			death_count.name = "DeathCountdown"
			death_count.text = "💀 %d" % rounds_left
			death_count.position = Vector2(27, 21)
			death_count.size = Vector2(39, 23)
			death_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			death_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			death_count.add_theme_font_size_override("font_size", 14)
			death_count.add_theme_color_override("font_color", Color("fff3d2"))
			death_count.add_theme_color_override("font_shadow_color", Color("61000f"))
			death_count.add_theme_constant_override("shadow_offset_x", 2)
			death_count.add_theme_constant_override("shadow_offset_y", 2)
			death_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait.add_child(death_count)
		else:
			portrait.tooltip_text = "%s — CT %d, Agilidade %d" % [unit["name"], unit["ct"], unit["speed"]]
			var queue_mount = state.mount_of(unit)
			if queue_mount != null:
				portrait.tooltip_text += "\nMontado na %s — HP %d/%d, MP %d/%d (a dupla age neste turno; os golpes recebidos ferem a montaria)" % [queue_mount["name"], queue_mount["hp"], queue_mount["maxHp"], queue_mount["mp"], queue_mount["maxMp"]]
		slot.add_child(portrait)
		var name_label := Label.new()
		name_label.text = (("☠ " if is_corpse else "▶ ") if is_current or is_corpse else "%d. " % (index + 1)) + String(unit["name"]) + (" 🐦" if unit.get("mountedOn", "") != "" else "")
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_font_size_override("font_size", 9)
		name_label.add_theme_color_override("font_color", Color("ff7d87") if is_corpse else (Color("ffe895") if is_current else Color.WHITE))
		slot.add_child(name_label)

		# HP/MP moraram aqui antes (ver histórico) — pedido do usuário: tiradas
		# também da fila de turnos (não sobra nenhum lugar com barra de HP/MP
		# fora dos cartões de combate). No lugar delas, um ícone por status
		# ativo (queimando/envenenado/congelado/etc.), com nome + turnos
		# restantes no tooltip — mesmo espírito do badge que já existia no
		# tile do tabuleiro.
		var active_statuses: Array = unit.get("statusEffects", [])
		if not is_corpse and active_statuses.size() > 0:
			var status_row := HBoxContainer.new()
			status_row.alignment = BoxContainer.ALIGNMENT_CENTER
			status_row.add_theme_constant_override("separation", 1)
			slot.add_child(status_row)
			for effect in active_statuses:
				var effect_type := String(effect.get("type", ""))
				var icon_label := Label.new()
				icon_label.text = _turn_queue_status_icon(effect_type)
				icon_label.add_theme_font_size_override("font_size", 12)
				icon_label.mouse_filter = Control.MOUSE_FILTER_STOP
				var turns_left = effect.get("turnsLeft")
				var turns_text := " — %d turno(s)" % int(turns_left) if turns_left != null else ""
				icon_label.tooltip_text = _turn_queue_status_label(effect_type) + turns_text
				status_row.add_child(icon_label)

## Ícone compacto por tipo de status — mesmo conjunto usado em add_status_effect
## (GameState), coberto aqui só pra exibição na fila de turnos. Tipo
## desconhecido cai no ❔ genérico em vez de travar/ficar em branco.
static func _turn_queue_status_icon(effect_type: String) -> String:
	match effect_type:
		"poison": return "☠️"
		"root": return "🌿"
		"invisible": return "👻"
		"blinded": return "🙈"
		# "paralyzed" também é o congelamento (sem tipo "frozen" separado no
		# projeto) — o ícone precisa comunicar isso sozinho.
		"paralyzed": return "❄️"
		"fury": return "😡"
		"regenBoost": return "🌱"
		"swiftFeet": return "🦶"
		"bleed": return "🩸"
		"burned": return "🔥"
		"regen": return "💚"
		"dazed": return "😵‍💫"
		"evasive": return "🍃"
		"weakened": return "⛓️"
		"slowed": return "🐌"
		"guarding": return "🛡️"
		"focus": return "🧘"
		"heronStance": return "🦢"
		"guardBroken": return "💥"
		"dustBlind": return "🌫️"
		"batForm": return "🦇"
		"bardInspiration": return "🎵"
		"reincarnation": return "♻️"
		_: return "❔"

## Nome legível de cada status pro tooltip do ícone acima (mesmo texto que
## apareceria num badge de status, só que sem depender de um por unidade).
static func _turn_queue_status_label(effect_type: String) -> String:
	match effect_type:
		"poison": return "Veneno"
		"root": return "Raízes"
		"invisible": return "Invisibilidade"
		"blinded": return "Ofuscado"
		"paralyzed": return "Paralisado (Congelado)"
		"fury": return "Fúria"
		"regenBoost": return "Regeneração aumentada"
		"swiftFeet": return "Pés Ágeis"
		"bleed": return "Sangramento"
		"burned": return "Queimando"
		"regen": return "Regenerando"
		"dazed": return "Atordoado(a)"
		"evasive": return "Evasiva"
		"weakened": return "Debilitado"
		"slowed": return "Lento"
		"guarding": return "Defendendo"
		"focus": return "Foco (bloqueia ataque físico, metade do dano mágico)"
		"heronStance": return "Postura da Garça (+25% de esquiva e contra-ataque)"
		"guardBroken": return "Guarda Quebrada (+1 de dano recebido por ataque)"
		"dustBlind": return "Poeira nos olhos (-20% de acerto nos próprios ataques)"
		"batForm": return "Forma de Morcego"
		"bardInspiration": return "Inspiração do Bardo"
		"reincarnation": return "Selo de Reencarnação"
		_: return effect_type

## Os retratos da fila também servem como atalho de inspeção. Diferente do
## clique no tabuleiro, aqui o ator atual pode ser inspecionado: o clique é
## explicitamente numa peça de interface e não disputa espaço com o menu de
## ações do personagem.
func _on_turn_queue_portrait_gui_input(event: InputEvent, unit: Dictionary) -> void:
	var activated := false
	if event is InputEventMouseButton:
		activated = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	elif event is InputEventScreenTouch:
		activated = event.pressed
	if not activated:
		return
	if _confirm_panel.visible or _facing_panel.visible:
		return
	# Pedido do usuário: clicar no retrato centraliza a câmera no personagem
	# quando o zoom estiver acima do mínimo (60%) — no mínimo o tabuleiro
	# inteiro já cabe na tela, então centralizar não faria diferença.
	if board_view != null and board_view.view_zoom > 0.6:
		board_view.center_on_tile(int(unit.get("x", 0)), int(unit.get("y", 0)))
		_sync_board_scroll()
	_open_unit_info(unit)
	get_viewport().set_input_as_handled()

## Cartão de inspeção do protótipo Browser: somente leitura, disponível ao
## tocar em qualquer unidade que não seja o ator atual.
func _build_unit_info_panel(layer: CanvasLayer) -> void:
	_unit_info_panel = PanelContainer.new()
	var board_px := BOARD_DISPLAY_PX
	_unit_info_panel.position = Vector2(24 + board_px * 0.5 - 285, 72)
	_unit_info_panel.custom_minimum_size = Vector2(570, 690)
	_unit_info_panel.visible = false
	_unit_info_panel.z_index = 20
	layer.add_child(_unit_info_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_unit_info_panel.add_child(outer)
	_unit_info_title = Label.new()
	_unit_info_title.add_theme_font_size_override("font_size", 24)
	_unit_info_title.add_theme_color_override("font_color", Color("ffd978"))
	_unit_info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(_unit_info_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(550, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_unit_info_content = VBoxContainer.new()
	_unit_info_content.custom_minimum_size = Vector2(530, 0)
	_unit_info_content.add_theme_constant_override("separation", 7)
	scroll.add_child(_unit_info_content)
	var close_button := Button.new()
	close_button.text = "Fechar"
	close_button.custom_minimum_size = Vector2(0, 38)
	close_button.pressed.connect(_close_unit_info)
	outer.add_child(close_button)

func _close_unit_info() -> void:
	_unit_info_panel.visible = false
	if _party_selection_hidden_for_info and _party_selection_panel != null:
		_party_selection_hidden_for_info = false
		_party_selection_panel.visible = true

func _load_campaign_progress(path: String = CAMPAIGN_SAVE_PATH) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	bardo_unlocked = bool(config.get_value("campaign", "bardo_unlocked", false))
	selected_party_keys = Array(config.get_value("campaign", "selected_party", [])).duplicate()

func _save_campaign_progress(path: String = CAMPAIGN_SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value("campaign", "bardo_unlocked", bardo_unlocked)
	config.set_value("campaign", "selected_party", selected_party_keys)
	return config.save(path)

func _available_hero_keys() -> Array:
	if _pvp_mode_active:
		return Units.player_team_keys()
	return Units.player_team_keys().filter(func(key): return key != "bardo" or bardo_unlocked)

func _scenario_requires_party_selection(id: String) -> bool:
	return id in [ScenarioManager.TOWER_FLOOR_3, ScenarioManager.TOWER_FLOOR_4] and _available_hero_keys().size() > MAX_ACTIVE_HEROES

func _hero_portrait_texture(hero: Dictionary) -> Texture2D:
	var sprite_key: String = hero.get("spriteKey", "")
	var animal_spec := AnimalSpriteCatalog.spec(sprite_key)
	if animal_spec.has("portrait") and ResourceLoader.exists(animal_spec["portrait"]): return load(animal_spec["portrait"])
	var folder: String = SpriteManifest.SPRITE_MANIFEST.get(sprite_key, "")
	var standard := "%s/%s_portrait.png" % [folder, sprite_key]
	if ResourceLoader.exists(standard): return load(standard)
	var plain := "%s/portrait.png" % folder
	return load(plain) if ResourceLoader.exists(plain) else null

func _build_party_selection_panel(layer: CanvasLayer) -> void:
	_party_selection_panel = PanelContainer.new()
	_party_selection_panel.position = Vector2(90, 92)
	_party_selection_panel.custom_minimum_size = Vector2(740, 780)
	_party_selection_panel.visible = false
	_party_selection_panel.z_index = 80
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111522"); style.border_color = Color("d6a94b")
	style.set_border_width_all(4); style.set_corner_radius_all(12); style.set_content_margin_all(18)
	_party_selection_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(_party_selection_panel)
	var outer := VBoxContainer.new(); outer.add_theme_constant_override("separation", 12)
	_party_selection_panel.add_child(outer)
	var title := Label.new(); title.text = "Selecione 5 heróis para este cenário"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 25); title.add_theme_color_override("font_color", Color("ffe29a")); outer.add_child(title)
	_party_selection_counter = Label.new(); _party_selection_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _party_selection_counter.add_theme_font_size_override("font_size", 18); outer.add_child(_party_selection_counter)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(700, 610); outer.add_child(scroll)
	_party_selection_grid = GridContainer.new(); _party_selection_grid.columns = 3; _party_selection_grid.add_theme_constant_override("h_separation", 12); _party_selection_grid.add_theme_constant_override("v_separation", 12); scroll.add_child(_party_selection_grid)
	_party_selection_confirm = Button.new(); _party_selection_confirm.text = "Confirmar equipe"; _party_selection_confirm.custom_minimum_size = Vector2(0, 48); _party_selection_confirm.pressed.connect(_confirm_party_selection); outer.add_child(_party_selection_confirm)

func _show_party_selection() -> void:
	var available := _available_hero_keys()
	selected_party_keys = selected_party_keys.filter(func(key): return available.has(key))
	if selected_party_keys.size() != mini(MAX_ACTIVE_HEROES, available.size()): selected_party_keys = available.slice(0, mini(MAX_ACTIVE_HEROES, available.size()))
	for child in _party_selection_grid.get_children(): child.queue_free()
	_party_card_buttons.clear()
	var templates := Units.build()
	for key in available:
		var hero: Dictionary = templates[key]
		var card := VBoxContainer.new(); card.custom_minimum_size = Vector2(215, 250)
		_party_selection_grid.add_child(card)
		var portrait_button := Button.new(); portrait_button.custom_minimum_size = Vector2(205, 180); portrait_button.expand_icon = true; portrait_button.icon = _hero_portrait_texture(hero); portrait_button.text = hero["name"]; portrait_button.tooltip_text = "Selecionar/desmarcar %s" % hero["name"]; portrait_button.pressed.connect(_toggle_party_hero.bind(key)); card.add_child(portrait_button)
		_party_card_buttons[key] = portrait_button
		var view_button := Button.new(); view_button.text = "Ver personagem"; view_button.pressed.connect(_view_party_hero.bind(key)); card.add_child(view_button)
	_refresh_party_selection_ui()
	_party_selection_panel.visible = true

func _toggle_party_hero(key: String) -> void:
	if selected_party_keys.has(key): selected_party_keys.erase(key)
	elif selected_party_keys.size() < MAX_ACTIVE_HEROES: selected_party_keys.append(key)
	else: _show_scenario_banner("Desmarque um herói antes de selecionar outro.")
	_refresh_party_selection_ui()

func _refresh_party_selection_ui() -> void:
	_party_selection_counter.text = "Selecionados: %d/%d" % [selected_party_keys.size(), MAX_ACTIVE_HEROES]
	_party_selection_confirm.disabled = selected_party_keys.size() != MAX_ACTIVE_HEROES
	for key in _party_card_buttons:
		var button: Button = _party_card_buttons[key]
		var selected := selected_party_keys.has(key)
		button.text = "%s%s" % [String(Units.build()[key]["name"]), "  ✓" if selected else ""]
		button.modulate = Color("fff0a0") if selected else Color.WHITE

func _view_party_hero(key: String) -> void:
	_party_selection_panel.visible = false
	_party_selection_hidden_for_info = true
	_open_unit_info((Units.build()[key] as Dictionary).duplicate(true))

func _confirm_party_selection() -> void:
	if selected_party_keys.size() != MAX_ACTIVE_HEROES: return
	_party_selection_panel.visible = false
	if _pvp_mode_active:
		_show_pvp_monster_and_scenario_setup(selected_party_keys.duplicate())
		return
	_party_selection_confirmed_for_start = true
	_save_campaign_progress()
	_start_new_game()

func _add_info_heading(text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 17)
	heading.add_theme_color_override("font_color", Color("7fc8ff"))
	_unit_info_content.add_child(heading)
	var separator := HSeparator.new()
	_unit_info_content.add_child(separator)

func _add_info_text(text: String, color: Color = Color.WHITE, indent: int = 0) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(510 - indent, 0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	if indent > 0: label.position.x = indent
	_unit_info_content.add_child(label)

func _open_unit_info(unit: Dictionary) -> void:
	for child in _unit_info_content.get_children(): child.queue_free()
	var team_label := "Herói" if unit.get("team", "") == "player" else "Inimigo"
	_unit_info_title.text = "%s  ·  %s" % [unit.get("name", "Personagem"), team_label]
	var portrait_texture := _hero_portrait_texture(unit)
	if portrait_texture != null:
		var portrait := TextureRect.new()
		portrait.texture = portrait_texture
		portrait.custom_minimum_size = Vector2(128, 128)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_unit_info_content.add_child(portrait)
	_add_info_heading("Atributos atuais")
	_add_info_text("❤️ HP %d/%d    ✦ CT %d/100    ✧ MP %d/%d" % [maxi(unit.get("hp", 0), 0), unit.get("maxHp", 0), unit.get("ct", 0), unit.get("mp", 0), unit.get("maxMp", 0)])
	_add_info_text("🏃 Deslocamento %d    ⚡ Agilidade %d    ↔ Posição (%d, %d)" % [unit.get("moveRange", 0), unit.get("speed", 0), unit.get("x", 0), unit.get("y", 0)])
	var active_song: Dictionary = unit.get("activeBardSong", {})
	if not active_song.is_empty():
		_add_info_text("🎵 Música ativa: %s — %d aplicação(ões) futura(s)" % [active_song["item"]["name"], active_song["applicationsLeft"]], Color("ffd978"))
	_add_info_heading("Passivas")
	var passives := _unit_passive_texts(unit)
	if passives.is_empty():
		_add_info_text("Nenhuma passiva especial.", Color("aeb7c2"))
	else:
		for passive in passives: _add_info_text("• %s" % passive, Color("d8c7ff"))
	_add_info_heading("Status ativos")
	var effects: Array = unit.get("statusEffects", [])
	if effects.is_empty():
		_add_info_text("Nenhum status ativo.", Color("aeb7c2"))
	else:
		for effect in effects:
			_add_info_text(_status_card_text(effect), _status_card_color(effect.get("type", "")))
	_add_info_heading("Armas")
	_add_item_cards(unit.get("weapons", []))
	var spell_label := "Magias" if unit.get("spriteKey", "") in ["mago", "xama", "fada"] else "Habilidades"
	_add_info_heading(spell_label)
	_add_item_cards(unit.get("spells", []))
	_unit_info_panel.visible = true

func _unit_passive_texts(unit: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if unit.get("passiveDamageReduction", 0) > 0: result.append("Armadura: reduz %d de todo dano recebido." % unit["passiveDamageReduction"])
	if not (unit.get("backstabBonus", {}) as Dictionary).is_empty():
		var backstab: Dictionary = unit["backstabBonus"]
		result.append("Ataque Furtivo: +%d-%d de dano pelo lado, +%d-%d pelas costas; invisível, sempre +%d-%d." % [backstab["side"][0], backstab["side"][1], backstab["back"][0], backstab["back"][1], backstab["invisible"][0], backstab["invisible"][1]])
	if unit.get("hasOpportunityAttack", false): result.append("Ataque de oportunidade contra inimigos que se afastam.")
	if unit.get("magicEvasion", 0.0) > 0: result.append("Esquiva mágica: -%d%% na chance de magias acertarem." % roundi(unit["magicEvasion"] * 100.0))
	if unit.get("innateEvasion", 0.0) > 0: result.append("Esquiva inata: -%d%% na chance de ser atingido." % roundi(unit["innateEvasion"] * 100.0))
	if unit.get("counterAttackChance", 0.0) > 0: result.append("Contra-ataque: %d%% de chance de revidar ataques próximos." % roundi(unit["counterAttackChance"] * 100.0))
	if unit.get("flying", false): result.append("Voador: ignora terreno e só é atingido por ataques à distância ou magia.")
	if unit.get("hpRegenPerTurn", 0) > 0: result.append("Regeneração natural: recupera %d HP por turno." % unit["hpRegenPerTurn"])
	# Pedido do usuário (Demônio das Chamas): não existia UI nenhuma pra
	# afinidade elemental/imunidade a status — genérico por dados
	# (elementAffinity/statusImmunities, ver resolve_single_hit/
	# add_status_effect), então também aparece de graça pro Fogo Vivo/Lava
	# Humana/Salamandra, que já tinham o campo mas nunca foram mostrados.
	var affinities: Dictionary = unit.get("elementAffinity", {})
	if not affinities.is_empty():
		var element_labels := {"fire": "Fogo", "ice": "Gelo", "lightning": "Relâmpago", "physical": "Físico", "magic": "Mágico"}
		for element in affinities:
			var aff: Dictionary = affinities[element]
			var label: String = element_labels.get(element, String(element).capitalize())
			if aff.get("mode", "damage") == "heal":
				result.append("%s: absorve — dano desse elemento cura em vez de ferir." % label)
			elif aff.get("mode", "damage") == "immune":
				result.append("%s: imune — esse elemento não causa nenhum dano." % label)
			else:
				var mult: float = float(aff.get("multiplier", 1.0))
				if mult != 1.0:
					result.append("%s: fraqueza — recebe %sx de dano." % [label, String.num(mult, 2).rstrip("0").rstrip(".")])
	var immunities: Array = unit.get("statusImmunities", [])
	if not immunities.is_empty():
		var status_labels := {"burned": "Queimando", "poison": "Envenenado", "bleed": "Sangrando", "paralyzed": "Paralisado", "blinded": "Ofuscado", "root": "Enraizado"}
		for status in immunities:
			result.append("Imune a %s." % status_labels.get(status, String(status).capitalize()))
	return result

func _add_item_cards(items: Array) -> void:
	if items.is_empty():
		_add_info_text("Nenhuma.", Color("aeb7c2"))
		return
	for item in items:
		var costs: Array[String] = []
		if item.has("ctCost"): costs.append("CT %d" % item["ctCost"])
		if item.has("mpCost"): costs.append("MP %d" % item["mpCost"])
		if item.has("minRange") or item.has("maxRange"):
			costs.append("alcance %d–%d" % [item.get("minRange", 1), item.get("maxRange", 1)])
		var damage := ""
		if item.has("damageMin"):
			damage = " · dano %d–%d" % [item["damageMin"], item.get("damageMax", item["damageMin"])]
		var title := "• %s  [%s]%s" % [item.get("name", "Ação"), " | ".join(costs), damage]
		_add_info_text(title, Color("fff2c2"))
		var note := String(item.get("tooltipNote", "")).replace("<br>", "\n")
		if note != "": _add_info_text(note, Color("c9d2dc"), 16)

func _status_card_text(effect: Dictionary) -> String:
	var type: String = effect.get("type", "")
	var labels := {"poison":"☠ Envenenado", "bleed":"◆ Sangrando", "root":"⌘ Enraizado", "burned":"🔥 Queimando", "regen":"✚ Regeneração", "regenBoost":"✚ Regeneração ampliada", "weakened":"↓ Enfraquecido", "paralyzed":"⚡ Paralisado", "dazed":"✹ Atordoado", "blinded":"◉ Cego", "slowed":"↓ Lentidão", "guarding":"🛡 Protegido", "focus":"🧘 Foco — bloqueia ataque físico e reduz magia pela metade", "heronStance":"🦢 Postura da Garça — +25% de esquiva e contra-ataque", "guardBroken":"💥 Guarda Quebrada — +1 de dano por ataque recebido", "dustBlind":"🌫 Poeira nos olhos — -20% de acerto", "fury":"⚔ Fúria", "invisible":"◌ Invisível", "evasive":"↝ Evasivo", "swiftFeet":"» Pés Ágeis", "bardInspiration":"♫ Inspirado pelo Bardo", "batForm":"🦇 Forma de Morcego", "reincarnation":"♻️ Selo de Reencarnação"}
	var result: String = labels.get(type, type.capitalize())
	if effect.has("turnsLeft"): result += " — %d turno(s) restante(s)" % effect["turnsLeft"]
	var details: Array[String] = []
	if effect.has("damageMin"): details.append("dano %d–%d/turno" % [effect["damageMin"], effect.get("damageMax", effect["damageMin"])])
	if effect.has("damageReduction"): details.append("-%d dano recebido" % effect["damageReduction"])
	if effect.has("damageBonus"): details.append("+%d dano" % effect["damageBonus"])
	if effect.has("hitBonus"): details.append("+%d p.p. acerto" % roundi(float(effect["hitBonus"]) * 100.0))
	if effect.has("speedBonus"): details.append("+%d agilidade" % effect["speedBonus"])
	if effect.has("moveBonus"): details.append("deslocamento dobrado")
	if effect.has("moveReduction"): details.append("-%d deslocamento" % effect["moveReduction"])
	if effect.has("speedReduction"): details.append("-%d agilidade" % effect["speedReduction"])
	if effect.has("lifestealMultiplierOverride"): details.append("lifesteal %d%%" % roundi(float(effect["lifestealMultiplierOverride"]) * 100.0))
	if not details.is_empty(): result += "  (%s)" % ", ".join(details)
	return result

func _status_card_color(type: String) -> Color:
	return Color("8ee6a1") if type in ["regen", "regenBoost", "guarding", "focus", "heronStance", "fury", "invisible", "evasive", "swiftFeet", "bardInspiration"] else Color("ff9a8f")

func _build_end_screen(layer: CanvasLayer) -> void:
	_end_screen = PanelContainer.new()
	var board_px: float = BOARD_DISPLAY_PX
	_end_screen.position = Vector2(24 + board_px * 0.5 - 160, 64 + board_px * 0.5 - 70)
	_end_screen.custom_minimum_size = Vector2(320, 140)
	_end_screen.visible = false
	# Bug relatado pelo usuário: sem stylebox próprio, o PanelContainer caía
	# no estilo padrão do tema (quase transparente) — mesmo tratamento sólido
	# (fundo opaco + borda + sombra) já usado em _confirm_panel/
	# _action_menu_panel, só com tom mais sombrio pra combinar com "VOCÊ
	# PERDEU!".
	var end_screen_style := StyleBoxFlat.new()
	end_screen_style.bg_color = Color("241315")
	end_screen_style.border_color = Color("7a2c2c")
	end_screen_style.set_border_width_all(3)
	end_screen_style.set_corner_radius_all(10)
	end_screen_style.set_content_margin_all(16)
	end_screen_style.shadow_color = Color(0, 0, 0, 0.55)
	end_screen_style.shadow_size = 10
	_end_screen.add_theme_stylebox_override("panel", end_screen_style)
	layer.add_child(_end_screen)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_end_screen.add_child(vbox)

	_end_screen_title = Label.new()
	_end_screen_title.add_theme_font_size_override("font_size", 26)
	_end_screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_end_screen_title)

	var restart_button := Button.new()
	restart_button.text = "Reiniciar Partida"
	restart_button.custom_minimum_size = Vector2(0, 36)
	restart_button.pressed.connect(_start_new_game)
	vbox.add_child(restart_button)

## Popup de confirmação pra magia de área (equivalente ao #attack-confirm-modal
## do JS, reaproveitado ali só pra esse caso — ver AOE_CONFIRM_MODES). Fica
## escondido até o segundo clique no mesmo alvo abrir com _open_aoe_confirmation.
## Pedido do usuário: caixa de confirmação de ataque estilizada como
## pergaminho (fundo bege, borda grossa) em vez do painel genérico anterior,
## com a cor da borda mudando pelo elemento do ataque (ver
## _attack_accent_color) — fogo vermelho, veneno verde, congelamento azul
## gelo, relâmpago amarelo, etc. `_confirm_panel_style` fica guardado à parte
## pra _confirm_panel_set_accent trocar só a border_color sem reconstruir o
## StyleBox inteiro a cada confirmação.
var _confirm_panel_style: StyleBoxFlat

func _build_confirm_panel(layer: CanvasLayer) -> void:
	_confirm_panel = PanelContainer.new()
	var board_px: float = BOARD_DISPLAY_PX
	_confirm_panel.position = Vector2(24 + board_px * 0.5 - 190, 56)
	_confirm_panel.custom_minimum_size = Vector2(340, 0)
	_confirm_panel.visible = false
	layer.add_child(_confirm_panel)

	_confirm_panel_style = StyleBoxFlat.new()
	_confirm_panel_style.bg_color = Color("f2e6c9")
	_confirm_panel_style.border_color = Color("6b4a2b")
	_confirm_panel_style.set_border_width_all(3)
	_confirm_panel_style.set_corner_radius_all(10)
	_confirm_panel_style.set_content_margin_all(14)
	_confirm_panel_style.shadow_color = Color(0, 0, 0, 0.45)
	_confirm_panel_style.shadow_size = 8
	_confirm_panel.add_theme_stylebox_override("panel", _confirm_panel_style)

	var vbox := VBoxContainer.new()
	_confirm_panel.add_child(vbox)

	_confirm_title_label = Label.new()
	_confirm_title_label.add_theme_font_size_override("font_size", 16)
	_confirm_title_label.add_theme_color_override("font_color", Color("3a2a1a"))
	vbox.add_child(_confirm_title_label)

	_confirm_body_label = Label.new()
	_confirm_body_label.add_theme_font_size_override("font_size", 13)
	_confirm_body_label.add_theme_color_override("font_color", Color("3a2a1a"))
	_confirm_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	# Sem essa largura fixa, get_combined_minimum_size() de um Label com
	# autowrap devolve o mínimo ABSOLUTO (~1px de largura, quebrando uma
	# palavra por linha) em vez do mínimo NA LARGURA que ele realmente vai
	# ocupar — isso infla a altura mínima do PainelContainer pai pra bem
	# mais que o texto real ocupa (sobra vazia enorme embaixo dos botões).
	# 340 (largura do painel) - 14*2 (margem do StyleBox) = 312.
	_confirm_body_label.custom_minimum_size.x = 312.0
	vbox.add_child(_confirm_body_label)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)

	_confirm_ok_button = Button.new()
	_confirm_ok_button.text = "Confirmar"
	_confirm_ok_button.pressed.connect(_on_confirm_ok_pressed)
	buttons.add_child(_confirm_ok_button)

	_confirm_cancel_button = Button.new()
	_confirm_cancel_button.text = "Cancelar"
	_confirm_cancel_button.pressed.connect(_close_confirm_panel)
	buttons.add_child(_confirm_cancel_button)

## Escolha contextual de direção: quatro botões circulares ficam ao redor
## do token que está encerrando o turno, como no protótipo Browser.
func _build_facing_panel(layer: CanvasLayer) -> void:
	_facing_panel = Control.new()
	_facing_panel.position = Vector2.ZERO
	_facing_panel.size = Vector2(920, 1200)
	_facing_panel.visible = false
	_facing_panel.z_index = 12
	layer.add_child(_facing_panel)
	var modal_shade := ColorRect.new()
	modal_shade.color = Color(0.02, 0.02, 0.03, 0.16)
	modal_shade.size = _facing_panel.size
	modal_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_facing_panel.add_child(modal_shade)

	_facing_title_label = Label.new()
	_facing_title_label.text = "ESCOLHA A DIREÇÃO FINAL"
	_facing_title_label.size = Vector2(240, 30)
	_facing_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_facing_title_label.add_theme_font_size_override("font_size", 14)
	_facing_title_label.add_theme_color_override("font_color", Color("fff2a8"))
	_facing_title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_facing_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_facing_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_facing_panel.add_child(_facing_title_label)

	_add_facing_button("↑", {"dx": 0, "dy": -1})
	_add_facing_button("←", {"dx": -1, "dy": 0})
	_add_facing_button("→", {"dx": 1, "dy": 0})
	_add_facing_button("↓", {"dx": 0, "dy": 1})

	_facing_confirm_button = Button.new()
	_facing_confirm_button.text = "✓ CONFIRMAR"
	_facing_confirm_button.size = Vector2(156, 42)
	_facing_confirm_button.add_theme_font_size_override("font_size", 16)
	_facing_confirm_button.add_theme_color_override("font_color", Color("3a2608"))
	_facing_confirm_button.add_theme_color_override("font_hover_color", Color("201300"))
	var confirm_normal := StyleBoxFlat.new()
	confirm_normal.bg_color = Color("ffd34f")
	confirm_normal.border_color = Color("7c5410")
	confirm_normal.set_border_width_all(3)
	confirm_normal.corner_radius_top_left = 9
	confirm_normal.corner_radius_top_right = 9
	confirm_normal.corner_radius_bottom_left = 9
	confirm_normal.corner_radius_bottom_right = 9
	var confirm_hover := confirm_normal.duplicate() as StyleBoxFlat
	confirm_hover.bg_color = Color("ffe889")
	_facing_confirm_button.add_theme_stylebox_override("normal", confirm_normal)
	_facing_confirm_button.add_theme_stylebox_override("hover", confirm_hover)
	_facing_confirm_button.add_theme_stylebox_override("pressed", confirm_hover)
	_facing_confirm_button.tooltip_text = "Confirma a direção escolhida e encerra o turno"
	_facing_confirm_button.pressed.connect(_on_facing_confirm_pressed)
	_facing_panel.add_child(_facing_confirm_button)

	# Pedido do usuário: opção de voltar caso "Encerrar Turno" tenha sido
	# clicado por engano — desiste sem encerrar o turno (ver
	# _on_facing_back_pressed), restaurando a direção de antes de abrir.
	_facing_back_button = Button.new()
	_facing_back_button.text = "← Voltar"
	_facing_back_button.size = Vector2(110, 42)
	_facing_back_button.add_theme_font_size_override("font_size", 15)
	_facing_back_button.add_theme_color_override("font_color", Color("f0e6d0"))
	_facing_back_button.add_theme_color_override("font_hover_color", Color.WHITE)
	var back_normal := StyleBoxFlat.new()
	back_normal.bg_color = Color("5a4a38")
	back_normal.border_color = Color("2e2418")
	back_normal.set_border_width_all(3)
	back_normal.corner_radius_top_left = 9
	back_normal.corner_radius_top_right = 9
	back_normal.corner_radius_bottom_left = 9
	back_normal.corner_radius_bottom_right = 9
	var back_hover := back_normal.duplicate() as StyleBoxFlat
	back_hover.bg_color = Color("70604a")
	_facing_back_button.add_theme_stylebox_override("normal", back_normal)
	_facing_back_button.add_theme_stylebox_override("hover", back_hover)
	_facing_back_button.add_theme_stylebox_override("pressed", back_hover)
	_facing_back_button.tooltip_text = "Desiste de encerrar o turno"
	_facing_back_button.pressed.connect(_on_facing_back_pressed)
	_facing_panel.add_child(_facing_back_button)

func _add_facing_button(label: String, dir: Dictionary) -> void:
	var b := Button.new()
	b.text = label
	b.size = Vector2(48, 48)
	b.toggle_mode = true
	b.button_group = _facing_button_group
	b.set_meta("direction", dir)
	b.add_theme_font_size_override("font_size", 25)
	b.add_theme_color_override("font_color", Color("4a3005"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("f4c430")
	normal.border_color = Color("fff0a0")
	normal.set_border_width_all(3)
	normal.corner_radius_top_left = 24
	normal.corner_radius_top_right = 24
	normal.corner_radius_bottom_left = 24
	normal.corner_radius_bottom_right = 24
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("ffe36b")
	hover.border_color = Color.WHITE
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("fff19a")
	pressed.border_color = Color("8b5b00")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.tooltip_text = "Terminar olhando para %s" % label
	b.pressed.connect(func():
		if _facing_pending_unit.is_empty():
			return
		_facing_pending_unit["facing"] = dir
		var token = unit_tokens.get(_facing_pending_unit["name"])
		if token != null:
			(token as UnitToken).refresh()
	)
	_facing_panel.add_child(b)
	_facing_direction_buttons.append(b)

## Converte um ponto LOCAL de board_view (ex.: tile_center()) para pixel de
## tela — precisa passar pela canvas_transform do viewport porque a Câmera2D
## da Horda (mapa 26x22, enquadrado numa janela fixa de 13x13) desloca a
## posição; os controles de orientação vivem na CanvasLayer (`layer`), que
## ignora a câmera, então sem essa conversão eles ficariam desalinhados do
## personagem sempre que a câmera não estiver centrada na origem (Campo/Torre
## continuam sem deslocamento, então aqui não muda nada pra eles).
func _board_to_screen(local_board_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * board_view.to_global(local_board_pos)

func _position_facing_controls(u: Dictionary) -> void:
	var center: Vector2 = _board_to_screen(board_view.tile_center(u["x"], u["y"]))
	var offsets: Array[Vector2] = [Vector2(-24, -86), Vector2(-86, -24), Vector2(38, -24), Vector2(-24, 38)]
	for i in range(_facing_direction_buttons.size()):
		var desired: Vector2 = center + offsets[i]
		_facing_direction_buttons[i].position = Vector2(clampf(desired.x, 4, 868), clampf(desired.y, 4, 1148))
	_facing_title_label.position = Vector2(clampf(center.x - 120, 4, 676), clampf(center.y - 126, 4, 1166))
	# Decide pela borda VISÍVEL do recorte, não pela última linha lógica do
	# mapa. Isso é essencial na Horda: o mapa tem 22 linhas, mas a janela
	# mostra só 13; y=12 já é a borda inferior visível embora não seja y=21.
	var confirm_below_y: float = center.y + 94
	var confirm_above_y: float = center.y - 94 - _facing_confirm_button.size.y
	var board_bottom: float = _board_clip.global_position.y + _board_clip.size.y
	var must_place_above: bool = confirm_below_y + _facing_confirm_button.size.y > board_bottom - 4.0
	var confirm_y: float = confirm_above_y if must_place_above else confirm_below_y
	var max_confirm_y: float = board_bottom - _facing_confirm_button.size.y - 4.0
	_facing_confirm_button.position = Vector2(clampf(center.x - 78, 4, 760), clampf(confirm_y, 4, max_confirm_y))
	# "Voltar" fica logo abaixo do "Confirmar" (ou acima dele, se o confirmar
	# já teve que subir pra caber na borda visível do tabuleiro).
	var back_y: float = confirm_y + _facing_confirm_button.size.y + 8.0 if not must_place_above else confirm_y - _facing_back_button.size.y - 8.0
	var max_back_y: float = board_bottom - _facing_back_button.size.y - 4.0
	_facing_back_button.position = Vector2(clampf(center.x - 55, 4, 794), clampf(back_y, 4, max_back_y))

## true = esse time é jogado por clique humano (mostra menu/alvos e espera
## pela HUD); false = a IA (state.enemy_act) decide sozinha por ele.
func _team_is_human(team: String) -> bool:
	# Terceiro time (mortos-vivos selvagens do Cemitério): sempre pela IA.
	if team == "neutral": return false
	return player_is_human if team == "player" else enemy_is_human

func _on_toggle_control_pressed(is_player_button: bool) -> void:
	if is_player_button:
		player_is_human = not player_is_human
	else:
		enemy_is_human = not enemy_is_human
	_refresh_control_buttons()
	# Time que acabou de virar IA e é a vez dele agora: deixa a IA assumir na
	# hora, sem esperar o jogador clicar em nada.
	_run_ai_until_player_turn()

func _refresh_control_buttons() -> void:
	_player_control_button.text = "Herói: %s" % ("Humano" if player_is_human else "IA")
	_enemy_control_button.text = "Inimigo: %s" % ("Humano" if enemy_is_human else "IA")

## Tem arte de direção o bastante pra valer a pena perguntar (ver
## hasDirectionalArt no JS, game.js:9544) — sem isso, todo personagem olharia
## sempre pra frente/baixo de qualquer jeito, então pular a pergunta direto.
func _has_directional_art(u: Dictionary) -> bool:
	var sprite_key: String = u.get("spriteKey", "")
	# Personagens migrados pro catálogo animal (ver AnimalSpriteCatalog —
	# Bardo/Arqueiro/Maga/Químico) não têm mais os PNGs antigos prefixados
	# (<chave>_idle_<direção>_1.png) que este check original procurava —
	# checava só ResourceLoader.exists() no padrão antigo, então nunca via a
	# arte direcional definida ali dentro (ver
	## anims["idle_left"/"idle_right"/...]), mesmo quando ela existe (a
	# própria "bardo" já caía nisso desde antes, só nunca foi pega por
	# nenhum teste que exercitasse o seletor de orientação dele).
	var animal_spec := AnimalSpriteCatalog.spec(sprite_key)
	if not animal_spec.is_empty():
		var anims: Dictionary = animal_spec.get("anims", {})
		for suffix in ["idle_left", "idle_right", "idle_up", "idle_down"]:
			if anims.has(suffix):
				return true
		return false
	var folder: String = SpriteManifest.SPRITE_MANIFEST.get(sprite_key, "")
	if folder == "":
		return false
	for suffix in ["left", "right", "back", "front"]:
		if ResourceLoader.exists("%s/%s_idle_%s_1.png" % [folder, sprite_key, suffix]):
			return true
	return false

## Funil único de "fim de turno" pra unidade controlada por humano — usado
## tanto pelo botão "Encerrar Turno" quanto pelo fim automático em
## _after_action(), equivalente a endCurrentTurn no JS (game.js:9496).
func _end_current_turn() -> void:
	if state.battle_ended or state.current_actor == null:
		return
	var u: Dictionary = state.current_actor
	if _online_mode:
		OnlineEndpoint.send_action({"action": "end_turn", "actor": u["name"]})
		return
	if u["hp"] <= 0 or not _team_is_human(u["team"]):
		state.advance_to_next_turn()
		_run_ai_until_player_turn()
		return
	# O visual 3D já mantém a orientação física do personagem. O seletor de
	# direção é uma interação legada dos sprites direcionais; deixá-lo abrir
	# para o Guerreiro 3D fazia o botão parecer travado aguardando confirmação.
	# A direção lógica atual é preservada e o turno segue imediatamente.
	if _unit_uses_3d_visual(u):
		state.advance_to_next_turn()
		_run_ai_until_player_turn()
		return
	_open_facing_picker(u)

func _unit_uses_3d_visual(u: Dictionary) -> bool:
	var key := String(u.get("key", u.get("id", u.get("spriteKey", ""))))
	for token in unit_tokens.values():
		if token is UnitToken and token.unit == u and token.is_using_warrior_3d():
			return true
	# Fallback para chamadas de fim de turno durante a criação/refresh dos
	# tokens, quando a referência ainda não foi registrada no dicionário.
	return key == "guerreiro" and warrior_ab_test and CharacterVisualFactory.has_profile(key)

func _open_facing_picker(u: Dictionary) -> void:
	if not _has_directional_art(u):
		state.advance_to_next_turn()
		_run_ai_until_player_turn()
		return
	_close_action_menu()
	_facing_pending_unit = u
	_facing_original_direction = u.get("facing", {}).duplicate()
	_position_facing_controls(u)
	for button in _facing_direction_buttons:
		button.button_pressed = button.get_meta("direction") == u.get("facing", {})
	_facing_panel.visible = true

func _on_facing_confirm_pressed() -> void:
	_facing_panel.visible = false
	if not _facing_pending_unit.is_empty():
		var facing_mount = state.mount_of(_facing_pending_unit)
		if facing_mount != null: facing_mount["facing"] = (_facing_pending_unit["facing"] as Dictionary).duplicate()
	_facing_pending_unit = {}
	state.advance_to_next_turn()
	_run_ai_until_player_turn()

## Pedido do usuário: desiste de encerrar o turno a partir da escolha de
## direção — restaura a direção de antes de abrir o seletor (clicar numa
## seta já vira o personagem na hora, só pra pré-visualizar) e devolve o
## controle pro jogador sem avançar o turno.
func _on_facing_back_pressed() -> void:
	if not _facing_pending_unit.is_empty():
		_facing_pending_unit["facing"] = _facing_original_direction
		var token = unit_tokens.get(_facing_pending_unit["name"])
		if token != null: (token as UnitToken).refresh()
	_facing_panel.visible = false
	_facing_pending_unit = {}
	_compute_current_targets()
	_sync_visuals()

func _unhandled_input(event: InputEvent) -> void:
	if warrior_ab_test and OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_A, KEY_B]:
			var enable_3d: bool = event.keycode == KEY_B
			for token in unit_tokens.values():
				if token is UnitToken and CharacterVisualFactory.has_profile(String(token.unit.get("spriteKey", ""))): token.set_use_3d_visual(enable_3d)
			print("WARRIOR_AB_TEST: ", "B / 3D" if enable_3d else "A / SPRITE")
			get_viewport().set_input_as_handled()
			return
	if battle_presentation != null and battle_presentation.is_blocking_input():
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE, KEY_SPACE]:
			battle_presentation.skip()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			battle_presentation.skip()
		return
	if _waiting_for_projectile_turn_end:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			# Só guarda onde começou — decide clique-vs-arrasto na soltura
			# (ver _drag_is_panning), nunca aqui.
			_drag_pointer_down = true
			_drag_start_pos = mb.position
			_drag_last_pos = mb.position
			_drag_is_panning = false
			return
		if not _drag_pointer_down:
			return
		_drag_pointer_down = false
		var was_panning := _drag_is_panning
		_drag_is_panning = false
		if was_panning:
			# Arrastou de verdade: soltar não seleciona, move nem ataca.
			if board_view.can_pan(): Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			get_viewport().set_input_as_handled()
			return
		_handle_board_click_at_mouse()
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag_pointer_down:
			if not _drag_is_panning and mm.position.distance_to(_drag_start_pos) > DRAG_PAN_THRESHOLD_PX and board_view.can_pan():
				_drag_is_panning = true
				Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			if _drag_is_panning:
				# Continua acompanhando o gesto mesmo se o ponteiro sair da
				# área do tabuleiro — _unhandled_input recebe o movimento
				# global, não só o que acontece dentro de _board_clip.
				board_view.pan_view_by(mm.position - _drag_last_pos)
				_drag_last_pos = mm.position
				_sync_board_scroll()
				get_viewport().set_input_as_handled()
				return
		var hovered = board_view.tile_at_local_pos(board_view.get_local_mouse_position())
		_update_combat_hover(hovered)
		return

## Mesma lógica de clique que sempre existiu (seleção/inspeção/mover/atacar
## pelo tile sob o mouse) — extraída pra função própria só pra poder ser
## chamada exclusivamente na SOLTURA do botão (ver _unhandled_input), depois
## de já sabermos que não foi um arrasto.
func _handle_board_click_at_mouse() -> void:
	# Popup de confirmação de área ou painel de direção abertos: mesma trava
	# do overlay do modal no JS original — nenhum clique no tabuleiro conta
	# enquanto eles existirem.
	if _confirm_panel.visible or _facing_panel.visible or _unit_info_panel.visible:
		return
	var local: Vector2 = board_view.get_local_mouse_position()
	var tile = board_view.tile_at_local_pos(local)
	if tile == null:
		return
	# Inspeção tem prioridade apenas no modo neutro. Durante uma mira, tocar
	# num inimigo continua confirmando o ataque/magia normalmente.
	if _try_open_unit_inspection_at(tile["x"], tile["y"]):
		return
	if _try_open_terrain_info_at(tile["x"], tile["y"]):
		return
	if state.battle_ended or state.current_actor == null or not _team_is_human(state.current_actor["team"]):
		return
	_handle_tile_click(tile["x"], tile["y"])

func _update_combat_hover(tile) -> void:
	if board_view == null: return
	if tile == null or state == null or state.current_actor == null:
		board_view.set_interaction_preview(null)
		if combat_feedback != null: combat_feedback.clear_targets()
		return
	var valid := false
	var path: Array = []
	var profile := "move"
	if mode == "idle" and _tile_in_list(reachable_tiles, tile["x"], tile["y"]):
		valid = true
		path = state.reconstruct_path(tile["x"], tile["y"]).duplicate(true)
	elif mode == "attack" and _tile_in_list(attack_range_tiles, tile["x"], tile["y"]):
		valid = true; profile = "attack"
	elif mode == "spell" and _tile_in_list(spell_tiles, tile["x"], tile["y"]):
		valid = true
		profile = "heal" if pending_item.get("targetMode", "") in ["heal-aoe", "regen-aoe", "cure-aoe", "mana-aoe"] else "magic"
	board_view.set_interaction_preview(tile if valid else null, path, tile if valid else null, profile)
	if combat_feedback != null:
		var target = state.unit_at(tile["x"], tile["y"])
		if valid and target != null: combat_feedback.set_targets([target], target)
		else: combat_feedback.clear_targets()

func _try_open_unit_inspection_at(x: int, y: int) -> bool:
	if mode != "idle": return false
	var inspected = state.unit_at(x, y)
	if inspected == null: inspected = state.dead_unit_at(x, y)
	if inspected == null: return false
	if state.current_actor != null and inspected == state.current_actor: return false
	if inspected.get("caged", false):
		if inspected.get("spriteKey", "") == GameState.CAGED_BARDO_KEY:
			_show_scenario_banner("🔒 Bardo preso! Pare ao lado dele para libertá-lo.")
		else:
			_show_scenario_banner("🔒 Maga presa! Pare ao lado dela para libertá-la.")
		return true
	_open_unit_info(inspected)
	return true

## Popup de identificação de terreno/Castelo/Montanha (porte de
## openTerrainInfoModal/openStructureInfoModal, game.js:4071-4109) — clicar
## num tile vazio (sem unidade viva/morta) fora de mira ativa mostra o que é
## aquilo e a regra dele, reaproveitando o mesmo painel de _open_unit_info.
## Não intercepta um clique que hoje moveria o ator atual pra esse tile (ver
## reachable_tiles abaixo) — senão nunca daria pra entrar na água/subir na
## casa clicando nela.
func _try_open_terrain_info_at(x: int, y: int) -> bool:
	if mode != "idle": return false
	if state.unit_at(x, y) != null or state.dead_unit_at(x, y) != null: return false
	if _tile_in_list(reachable_tiles, x, y): return false
	var structure = state.structure_at(x, y)
	if structure == null: structure = state.destroyed_structure_at(x, y)
	if structure != null:
		_open_structure_info(structure)
		return true
	var terrain = state.terrain_at(x, y)
	if terrain != null:
		_open_terrain_info(terrain, x, y)
		return true
	if BoardLayout.FLOWER_LAYOUT.any(func(f): return f["x"] == x and f["y"] == y):
		_open_terrain_info({"type": "flower"}, x, y)
		return true
	return false

func _open_terrain_info(terrain: Dictionary, x: int, y: int) -> void:
	var is_waterfall: bool = x == BoardLayout.WATERFALL_TILE["x"] and y == BoardLayout.WATERFALL_TILE["y"] and terrain.get("type", "") == "water"
	var info_key: String = "waterfall" if is_waterfall else String(terrain.get("type", ""))
	var info: Dictionary = InfoText.TERRAIN_INFO.get(info_key, {})
	if info.is_empty(): return
	for child in _unit_info_content.get_children(): child.queue_free()
	var hp_note := ""
	if BoardLayout.destructible_tile_types().has(terrain.get("type", "")):
		hp_note = "  (HP: %d/%d)" % [maxi(int(terrain.get("hp", 0)), 0), int(terrain.get("maxHp", 0))]
	_unit_info_title.text = "%s %s%s" % [info.get("icon", ""), info.get("name", ""), hp_note]
	_add_info_text(String(info.get("desc", "")))
	_unit_info_panel.visible = true

func _open_structure_info(structure: Dictionary) -> void:
	var info: Dictionary = InfoText.STRUCTURE_INFO.get(structure.get("type", ""), {})
	if info.is_empty(): return
	for child in _unit_info_content.get_children(): child.queue_free()
	if structure.get("destroyed", false):
		var is_castle: bool = structure["type"] == "castle"
		var noun: String = "o Castelo" if is_castle else "a Montanha"
		var suffix: String = "o" if is_castle else "a"
		_unit_info_title.text = "%s %s (destruíd%s)" % [info.get("icon", ""), info.get("name", ""), suffix]
		_add_info_text("Restos d%s, destruíd%s em combate. Só decoração agora — não bloqueia mais movimento nem dá nenhum dos bônus de quando estava de pé." % [noun, suffix])
	else:
		_unit_info_title.text = "%s %s  (HP: %d/%d)" % [info.get("icon", ""), info.get("name", ""), structure["hp"], structure["maxHp"]]
		_add_info_text(String(info.get("desc", "")))
	_unit_info_panel.visible = true

## Executor da ação em andamento: a montaria (quando o item escolhido é dela)
## enquanto há mira ativa; senão, o dono do turno.
func _active_caster() -> Dictionary:
	if pending_caster != null and mode in ["attack", "spell"] and int(pending_caster.get("hp", 0)) > 0:
		return pending_caster
	return state.current_actor

## Item pertence à montaria do herói montado? Devolve ela; senão, o ator do turno.
func _caster_for_item(item: Dictionary) -> Dictionary:
	var actor: Dictionary = state.current_actor
	var carried = state.mount_of(actor)
	if carried != null:
		for key in ["weapons", "spells"]:
			for candidate in carried.get(key, []):
				if candidate == item:
					return carried
	return actor

## Itens do menu: os do ator + (montado) os da Vestruz, cada um com quem executa.
func _menu_items(u: Dictionary, key: String) -> Array:
	var entries: Array = []
	for candidate in u.get(key, []):
		entries.append({"item": candidate, "caster": u})
	var carried = state.mount_of(u)
	if carried != null:
		for candidate in carried.get(key, []):
			entries.append({"item": candidate, "caster": carried})
	return entries

func _handle_tile_click(x: int, y: int) -> void:
	var u: Dictionary = _active_caster()

	# Clicar no próprio token: cancela a mira em andamento, ou abre/fecha o
	# menu de ações se já estiver no modo "idle".
	if state.unit_contains_tile(u, x, y):
		# Habilidades de alvo com alcance mínimo 0 (Poção de Mana/Cura) podem
		# ser usadas no próprio conjurador. Antes este clique era consumido
		# como "cancelar mira" antes de chegar ao resolvedor da magia.
		if mode == "spell":
			for t in spell_tiles:
				if t["x"] == x and t["y"] == y:
					if AOE_CONFIRM_MODES.has(pending_item.get("targetMode", "")):
						_handle_aoe_tile_click(u, x, y)
					else:
						_resolve_spell(u, pending_item, x, y)
					return
		if mode != "idle":
			mode = "idle"
			_clear_aoe_preview()
			_close_confirm_panel()
			_compute_current_targets()
			_sync_visuals()
		else:
			_toggle_action_menu()
		return

	if mode == "attack":
		var clicked_target = state.unit_at(x, y)
		if clicked_target != null and attackable_units.has(clicked_target):
			_request_attack_confirmation(u, clicked_target, pending_item)
			return
		var terrain = state.terrain_at(x, y)
		if terrain != null and BoardLayout.SINGLE_TARGET_TERRAIN_TYPES.has(terrain.get("type", "")) and _tile_in_list(attack_range_tiles, x, y):
			_resolve_terrain_attack(u, {"x":x,"y":y}, pending_item)
			return
		var structure = _opposing_structure_target(u, x, y)
		if structure != null and _tile_in_list(attack_range_tiles, x, y):
			_request_structure_attack_confirmation(u, structure, {"x":x,"y":y}, pending_item)
			return
		if combat_feedback != null: combat_feedback.local_error(board_view.tile_center(x, y), "ALVO INVÁLIDO")
		return

	if mode == "spell":
		for t in spell_tiles:
			if t["x"] == x and t["y"] == y:
				if AOE_CONFIRM_MODES.has(pending_item.get("targetMode", "")):
					_handle_aoe_tile_click(u, x, y)
				else:
					_resolve_spell(u, pending_item, x, y)
				return
		if combat_feedback != null: combat_feedback.local_error(board_view.tile_center(x, y), "FORA DA ÁREA")
		return

	# Modo idle: tile azul move; alvo vermelho ataca com a melhor arma
	# disponível automaticamente (atalho sem precisar abrir o menu).
	if not u.get("hasMoved", false):
		var mount_here = state.unit_at(x, y)
		if mount_here != null and mount_here.get("isMount", false) and state.can_mount(u, mount_here):
			_request_mount_confirmation(u, mount_here)
			return
		for t in reachable_tiles:
			if t["x"] == x and t["y"] == y:
				_request_move_confirmation(u, x, y)
				return

	if not u.get("hasActed", false):
		var clicked_target = state.unit_at(x, y)
		if clicked_target != null and attackable_units.has(clicked_target):
			var weapon = state.pick_weapon_for_distance(state.get_attack_options(u), state.manhattan(u, clicked_target), clicked_target)
			if weapon != null:
				_request_attack_confirmation(u, clicked_target, weapon)
			return
		# Atalho do tile vermelho também vale pra atacar Castelo/Montanha vazios
		# (pedido do usuário) — mesma lógica de pick_weapon_for_distance de um
		# alvo comum, só que a "distância" é até o tile clicado, não até uma
		# unidade (estrutura não tem x/y própria, só a lista "tiles").
		var structure = _opposing_structure_target(u, x, y)
		if structure != null:
			var distance: int = state.manhattan(u, {"x": x, "y": y})
			var weapon = state.pick_weapon_for_distance(state.get_attack_options(u), distance, structure)
			if weapon != null:
				_request_structure_attack_confirmation(u, structure, {"x": x, "y": y}, weapon)
			return

func _handle_dungeon_stair_transition(u: Dictionary) -> bool:
	if u.get("team", "") != "player":
		return false
	if state.scenario_id == ScenarioManager.TOWER and int(u["x"]) == 6 and int(u["y"]) == 1:
		_show_scenario_banner("Descendo para o 2º Andar...")
		_switch_scenario(ScenarioManager.TOWER_FLOOR_2)
		return true
	if state.scenario_id == ScenarioManager.TOWER_FLOOR_2:
		var exit_tile: Dictionary = scenario_manager.active_definition().get("exit_tile", {})
		if not exit_tile.is_empty() and int(u["x"]) == int(exit_tile["x"]) and int(u["y"]) == int(exit_tile["y"]):
			_show_scenario_banner("Descendo para o 3º Andar...")
			_switch_scenario(ScenarioManager.TOWER_FLOOR_3)
			return true
	if state.scenario_id == ScenarioManager.TOWER_FLOOR_3:
		var floor3_exit: Dictionary = scenario_manager.active_definition().get("exit_tile", {})
		if not floor3_exit.is_empty() and int(u["x"]) == int(floor3_exit["x"]) and int(u["y"]) == int(floor3_exit["y"]):
			_show_scenario_banner("Descendo para o 4º Andar...")
			_switch_scenario(ScenarioManager.TOWER_FLOOR_4)
			return true
	if state.scenario_id == ScenarioManager.TOWER_FLOOR_4:
		var floor4_exit: Dictionary = scenario_manager.active_definition().get("exit_tile", {})
		if not floor4_exit.is_empty() and int(u["x"]) == int(floor4_exit["x"]) and int(u["y"]) == int(floor4_exit["y"]):
			_show_scenario_banner("A escada para o 5º Andar está pronta — em breve!")
	return false

func _play_collected_soul_effects(souls_before: Array) -> void:
	var collected_any := false
	for old_soul in souls_before:
		var still_exists := false
		for current_soul in state.souls:
			if current_soul["x"] == old_soul["x"] and current_soul["y"] == old_soul["y"]:
				still_exists = true
				break
		if not still_exists:
			collected_any = true
			if effects_layer != null:
				effects_layer.spawn_heal_absorb(board_view.tile_center(old_soul["x"], old_soul["y"]), Color("b8f7ff"))
	if collected_any:
		AudioEngine.play_sfx("soulPickup")

func _tile_in_list(tiles: Array, x: int, y: int) -> bool:
	for tile in tiles:
		if tile["x"] == x and tile["y"] == y: return true
	return false

func _resolve_terrain_attack(u: Dictionary, tile: Dictionary, item: Dictionary) -> void:
	state.perform_terrain_attack(u, tile, item)
	_play_attack_vfx(u, tile, item, true)
	mode = "idle"
	_after_action()

## Estrutura do time OPOSTO ao de "u" (Montanha pro herói, Castelo pro
## inimigo) que ainda está de pé no tile clicado — null se não houver
## estrutura ali, se já foi destruída, ou se for a estrutura do PRÓPRIO time
## (não dá pra "atacar" sua própria base).
func _opposing_structure_target(u: Dictionary, x: int, y: int) -> Variant:
	var s = state.structure_at(x, y)
	if s == null or s["destroyed"] or s["team"] == u["team"]:
		return null
	return s

func _resolve_structure_attack(u: Dictionary, structure: Dictionary, tile: Dictionary, item: Dictionary) -> void:
	state.perform_structure_attack(u, structure, tile, item)
	_play_attack_vfx(u, tile, item, true)
	mode = "idle"
	_after_action()

## Mesmo popup de confirmação dos ataques contra unidade, só que pra um tile
## vazio do Castelo/Montanha (pedido do usuário) — sem rolagem de acerto
## (estrutura não esquiva, ver GameState.damage_structure) nem bônus de
## crítico/furtividade, então o corpo do popup só mostra o dano.
func _request_structure_attack_confirmation(attacker: Dictionary, structure: Dictionary, tile: Dictionary, item: Dictionary) -> void:
	var label: String = "Castelo" if structure["type"] == "castle" else "Montanha"
	_confirm_title_label.text = "%s %s na %s?" % [item.get("icon", "⚔️"), item.get("name", "Ataque"), label]
	var lines: Array[String] = ["Este ataque sempre acerta."]
	if item.has("damageMin") and item.has("damageMax"):
		lines.append("Dano esperado: %d-%d" % [item["damageMin"], item["damageMax"]])
	_confirm_body_label.text = "\n".join(lines)
	_confirm_ok_button.text = "Atacar"
	_confirm_cancel_button.text = "Cancelar"
	pending_confirm_action = func(): _resolve_structure_attack(attacker, structure, tile, item)
	_confirm_panel_set_accent(_attack_accent_color(item))
	_position_confirm_panel_near_unit(attacker)

func _play_water_path_vfx(path_tiles: Array, speed_scale: float = 1.0) -> void:
	if effects_layer == null: return
	var water_step_index := 0
	for i in range(path_tiles.size()):
		var tile: Dictionary = path_tiles[i]
		var terrain = state.terrain_at(tile["x"], tile["y"])
		var profile := ""
		if terrain != null and terrain.get("type", "") == "water":
			profile = "water"
		elif scenario_manager.active_id == ScenarioManager.FIELD:
			profile = "grass"
		elif terrain != null and terrain.get("type", "") in ["road", "dirt", "path"]:
			profile = "dirt"
		if profile == "": continue
		var center := board_view.tile_center(tile["x"], tile["y"])
		var timer := get_tree().create_timer(0.15 * float(i + 1) * speed_scale)
		var strong := water_step_index == 0 if profile == "water" else i == 0
		timer.timeout.connect(func():
			effects_layer.spawn_surface_step(center, profile, strong)
			if profile == "water": AudioEngine.play_sfx("waterStep", AudioEngine.pan_for_x(tile["x"]))
		)
		if profile == "water": water_step_index += 1

func _play_new_tower_trap_effects() -> void:
	if effects_layer == null: return
	for trap in state.traps:
		if not trap.get("triggered", false) or trap.get("vfxPlayed", false): continue
		trap["vfxPlayed"] = true
		var tile: Dictionary = trap["tiles"][0]
		var center := board_view.tile_center(tile["x"], tile["y"])
		var kind := String(trap.get("kind", "basic"))
		var centers: Array = []
		for y in range(GameConstants.BOARD_SIZE):
			for x in range(GameConstants.BOARD_SIZE):
				if absi(x - tile["x"]) + absi(y - tile["y"]) <= 6: centers.append(board_view.tile_center(x, y))
		if kind == "poison-arrow":
			effects_layer.spawn_projectile(center + Vector2(-55, -20), center, Color("91c85a"), 0.38, Callable(), 8.0, "arrow")
		elif kind == "poison-gas":
			for gas_center in centers: effects_layer.spawn_toxic_gas(gas_center, true)
		elif kind == "corrosive-gas":
			for gas_center in centers: effects_layer.spawn_burst(gas_center, 24.0, Color("c7b64b"), 0.55, "poison")
		elif kind == "fire":
			effects_layer.spawn_fireblast_area(centers, center)
		AudioEngine.play_sfx("trapTrigger", AudioEngine.pan_for_x(tile["x"]))

# --- Menu de ações -------------------------------------------------------------

func _toggle_action_menu() -> void:
	if _action_menu_panel.visible:
		_close_action_menu()
	else:
		_open_action_menu()

func _open_action_menu() -> void:
	_render_menu_root()
	_action_menu_panel.visible = true

## Raiz do menu: 4 categorias (Atacar/Habilidade/Mover/Encerrar Turno) em vez
## da lista plana de armas+magias de antes — cada categoria some direto pra
## um submenu (attack/spell) ou já resolve a ação (mover só fecha o menu e
## deixa o clique no tile azul de sempre resolver; encerrar turno reusa o
## mesmo funil de _end_current_turn do botão da HUD).
func _render_menu_root() -> void:
	_clear_action_menu()
	var u: Dictionary = state.current_actor
	var has_acted: bool = u.get("hasActed", false)
	var can_move: bool = not u.get("hasMoved", false) and not u.get("cannotMoveThisTurn", false) and not state.is_rooted(u)
	var weapon_entries: Array = _menu_items(u, "weapons")
	var available_spells: Array = _menu_items(u, "spells").filter(func(e): return _spell_is_available(e["caster"], e["item"]))

	_add_menu_button("🏃 Mover", func(): _close_action_menu(), not can_move)
	_add_menu_button("🗡 Atacar", func(): _render_attack_submenu(), has_acted or weapon_entries.is_empty() or state.is_bard_singing(u))
	_add_menu_button("✨ Habilidade", func(): _render_spell_submenu(), available_spells.is_empty())
	# Montaria (Vestruz): ação visível de montar/desmontar.
	if state.mount_of(u) != null:
		var dismount_button := _add_menu_button("⬇ Desmontar da %s" % state.mount_of(u)["name"], func(): _start_dismount(), state.dismount_tiles(u).is_empty())
		dismount_button.tooltip_text = "Desce para um quadrado livre e válido ao redor."
	else:
		# Montar: aparece sempre que há uma montaria aliada adjacente (também
		# depois de o herói ter se movido até o lado dela).
		for candidate in state.units:
			if candidate.get("isMount", false) and candidate["team"] == u["team"] and candidate["hp"] > 0 and candidate != u and state.manhattan(u, candidate) == 1 and candidate.get("riderName", "") == "":
				var mount_ref: Dictionary = candidate
				var mount_button := _add_menu_button("🐦 Montar na %s" % candidate["name"], func(): _request_mount_confirmation(u, mount_ref), not state.can_mount(u, candidate))
				mount_button.tooltip_text = "Sobe na montaria adjacente. A dupla ocupa o mesmo quadrado, voa e age no turno do cavaleiro."
	_add_menu_button("🏁 Encerrar Turno", _on_menu_end_turn_pressed)
	_add_menu_button("Cancelar", func(): _close_action_menu())

func _mount_on(rider: Dictionary, mount: Dictionary) -> void:
	_close_action_menu()
	if _online_mode:
		OnlineEndpoint.send_action({"action": "mount", "actor": rider["name"], "x": mount["x"], "y": mount["y"]})
		return
	if not state.mount_unit(rider, mount):
		return
	if effects_layer != null:
		effects_layer.spawn_combat_popup(board_view.tile_center(mount["x"], mount["y"]), "MONTADO!", "buff", 0.0, 0)
		AudioEngine.play_event("wind", AudioEngine.pan_for_x(int(mount["x"])))
	_sync_visuals()
	_after_action()

func _start_dismount() -> void:
	_close_action_menu()
	_clear_aoe_preview()
	var u: Dictionary = state.current_actor
	mode = "spell"
	pending_item = {"name": "Desmontar", "icon": "⬇", "targetMode": "dismount"}
	pending_caster = null
	attackable_units = []
	attack_range_tiles = []
	spell_tiles = state.dismount_tiles(u)
	_sync_visuals()

func _on_menu_end_turn_pressed() -> void:
	_close_action_menu()
	_request_end_current_turn()

func _render_attack_submenu() -> void:
	_clear_action_menu()
	var u: Dictionary = state.current_actor
	for entry in _menu_items(u, "weapons"):
		var w: Dictionary = entry["item"]
		var weapon_caster: Dictionary = entry["caster"]
		# Pedido do usuário: cada arma usa o próprio ícone (já existia em
		# data/weapons.gd, mas o botão sempre mostrava "🗡" fixo, escondendo a
		# diferença entre ataques do mesmo personagem).
		# Rajada de Golpes (Monge) é o primeiro ataque do jogo que custa MP:
		# mostra o custo no botão e trava quando não dá pra pagar, mesma
		# regra que get_attack_options já aplica no atalho do tile vermelho.
		var mp_cost: int = int(w.get("mpCost", 0))
		var missing_mp: bool = mp_cost > 0 and int(weapon_caster.get("mp", 0)) < mp_cost
		var label := "%s %s" % [w.get("icon", "🗡"), w["name"]]
		if mp_cost > 0: label += " — %d MP" % mp_cost
		if weapon_caster != u: label += " (%s)" % weapon_caster["name"]
		var button := _add_menu_button(label, func(): _select_attack_item(w), missing_mp)
		button.tooltip_text = _combat_item_tooltip(w) + ("\nIndisponível: MP insuficiente." if missing_mp else "")
	_add_menu_button("← Voltar", func(): _render_menu_root())

## Pedido do usuário: toda habilidade/magia mostra o custo de MP/CT no próprio
## botão (não só no tooltip ao passar o mouse), igual já acontecia só com a
## Chuva de Flechas do Arqueiro (que tinha o texto "— 5 MP / CT 0" fixo no
## código). Generalizado pra ler mpCost/ctCost de cada magia em vez de
## números fixos, mantendo o aviso "ATIVA" da Chuva de Flechas quando ela já
## foi preparada neste turno.
func _spell_cost_label(s: Dictionary, u: Dictionary) -> String:
	var cost := " — %d MP / CT %d" % [s.get("mpCost", 0), s.get("ctCost", 0)]
	if s.get("kind", "") == "arrow-rain" and u.get("arrowRainPrepared", false):
		return " — ATIVA (%d MP / CT %d)" % [s.get("mpCost", 0), s.get("ctCost", 0)]
	return cost

func _render_spell_submenu() -> void:
	_clear_action_menu()
	var u: Dictionary = state.current_actor
	for spell_entry in _menu_items(u, "spells"):
		var s: Dictionary = spell_entry["item"]
		var spell_caster: Dictionary = spell_entry["caster"]
		var available := _spell_is_available(spell_caster, s)
		# Pedido do usuário: cada magia/habilidade usa o próprio ícone (idem
		# acima) em vez do "✨" fixo, pra distinguir de cara as magias da Maga,
		# por exemplo.
		var owner_note := " (%s)" % spell_caster["name"] if spell_caster != u else ""
		var button := _add_menu_button("%s %s%s%s" % [s.get("icon", "✨"), s["name"], _spell_cost_label(s, spell_caster), owner_note], func(): _select_spell_item(s), not available)
		var unavailable_reason := "MP insuficiente ou ação já utilizada."
		if not state.item_requirements_met(spell_caster, s):
			unavailable_reason = "só pode ser usada com menos de %d%% do HP máximo (%d HP ou menos)." % [roundi(float(s["requiresHpBelowRatio"]) * 100.0), int(ceil(float(spell_caster["maxHp"]) * float(s["requiresHpBelowRatio"]))) - 1]
		button.tooltip_text = _combat_item_tooltip(s) + ("\nIndisponível: %s" % unavailable_reason if not available else "")
	_add_menu_button("← Voltar", func(): _render_menu_root())

func _clear_action_menu() -> void:
	for c in _action_menu_vbox.get_children():
		c.queue_free()

func _close_action_menu() -> void:
	_action_menu_panel.visible = false

func _add_menu_button(label: String, callback: Callable, disabled: bool = false) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, 30)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color("3d2817"))
	b.add_theme_color_override("font_hover_color", Color("24150b"))
	b.add_theme_color_override("font_pressed_color", Color("fff0c8"))
	b.add_theme_color_override("font_disabled_color", Color("8f8068"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("d7ba7d")
	normal.border_color = Color("9b7040")
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("f0d99e")
	hover.border_color = Color("6e4525")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("80552e")
	var disabled_style := normal.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color("c7b58f")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled_style)
	if callback.is_valid() and not disabled:
		b.pressed.connect(callback)
	else:
		b.disabled = true
	b.mouse_entered.connect(func():
		if b.disabled: return
		var hover_tween := create_tween()
		hover_tween.tween_property(b, "scale", Vector2(1.025, 1.025), 0.10).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	)
	b.mouse_exited.connect(func():
		var exit_tween := create_tween()
		exit_tween.tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	)
	_action_menu_vbox.add_child(b)
	return b

func _combat_item_tooltip(item: Dictionary) -> String:
	var lines: Array[String] = [String(item.get("name", ""))]
	if item.has("tooltipNote"): lines.append(String(item["tooltipNote"]).replace("<br>", "\n"))
	if item.has("damageMin"): lines.append("Dano: %d-%d" % [item.get("damageMin", 0), item.get("damageMax", 0)])
	if item.has("healMin"): lines.append("Cura: %d-%d" % [item.get("healMin", 0), item.get("healMax", 0)])
	if item.has("mpCost"): lines.append("MP: %d" % item.get("mpCost", 0))
	if item.has("ctCost"): lines.append("CT: %d" % item.get("ctCost", 0))
	if item.has("reach"): lines.append("Alcance: %d (avança até %d)" % [item["reach"], item.get("advanceMax", 0)])
	elif item.has("range") or item.has("maxRange"): lines.append("Alcance: %d" % item.get("range", item.get("maxRange", 0)))
	elif item.get("targetMode", "") == "self": lines.append("Alcance: si mesmo")
	if item.has("hitChance"): lines.append("Acerto: %d%%" % roundi(float(item.get("hitChance", 0.0)) * 100.0))
	if item.has("critChance"): lines.append("Crítico: %d%%" % roundi(float(item.get("critChance", 0.0)) * 100.0))
	if item.has("turns"): lines.append("Duração: %d turno(s)" % item.get("turns", 0))
	return "\n".join(lines)

## Só filtra por MP e por já ter usado a ação do turno quando a habilidade
## custa CT de verdade — as "livres" (ctCost 0) ficam disponíveis até a
## própria cast_self_ability recusar (ex: já usada neste turno).
func _spell_is_available(u: Dictionary, s: Dictionary) -> bool:
	if s.get("kind", "") == "arrow-rain" and u.get("arrowRainPrepared", false): return false
	if u["mp"] < s.get("mpCost", 0):
		return false
	if s.get("ctCost", 0) > 0 and state.turn_owner(u).get("hasActed", false):
		return false
	# Última Determinação (Samurai): só com HP abaixo de 40% do máximo.
	if not state.item_requirements_met(u, s):
		return false
	return true

func _select_attack_item(item: Dictionary) -> void:
	if state.is_arrow_rain_attack(state.current_actor, item):
		_select_spell_item(state.arrow_rain_item(item))
		return
	if state.is_bard_singing(state.current_actor):
		_show_scenario_banner("🎵 O Bardo está cantando e não pode usar a Besta.")
		return
	# Armas de área usam exatamente o mesmo fluxo de mira, prévia e
	# confirmação das magias de área. Isso importa quando o time inimigo é
	# colocado sob controle humano: as duas armas do Troll (Tronco e Tacar
	# Tronco) têm targetMode de área e não podem ser reduzidas a um ataque
	# contra uma única unidade.
	if AOE_CONFIRM_MODES.has(item.get("targetMode", "")):
		_select_spell_item(item)
		return
	_close_action_menu()
	_clear_aoe_preview()
	var u: Dictionary = _caster_for_item(item)
	pending_caster = u if u != state.current_actor else null
	mode = "attack"
	pending_item = item
	attackable_units = []
	attack_range_tiles = []
	var cardinal_only: bool = item.get("cardinalOnly", false)
	attack_range_tiles = state.compute_line_target_tiles(u, item, true) if cardinal_only else state.compute_range_tiles(u, item)
	# Mesmo item efetivo usado pra pintar attack_range_tiles acima — sem
	# isso, Tiro Longo (e o bônus de elevação) pintava o alcance dobrado
	# mas recusava o clique, porque aqui ainda checava o maxRange cru.
	var effective_item: Dictionary = state.effective_weapon_item(u, item)
	for o in state.opposing_team_of(u):
		if o["hp"] <= 0:
			continue
		if cardinal_only and not state.units_cardinally_aligned(u, o):
			continue
		if state.is_in_weapon_range(effective_item, state.manhattan(u, o)):
			attackable_units.append(o)
	spell_tiles = []
	_sync_visuals()

func _select_spell_item(item: Dictionary) -> void:
	if _waiting_for_projectile_turn_end: return
	if item.get("targetMode", "") == "pierce-line" and state.is_arrow_rain_attack(state.current_actor, item): item = state.arrow_rain_item(item)
	_close_action_menu()
	_clear_aoe_preview()
	var u: Dictionary = _caster_for_item(item)
	pending_caster = u if u != state.current_actor else null
	var tm: String = item.get("targetMode", "")

	if tm == "self":
		if String(item.get("kind", "")).begins_with("bard-song"):
			_resolve_spell(u, item, u["x"], u["y"])
			return
		var self_token = unit_tokens.get(u["name"])
		if self_token != null: (self_token as UnitToken).play_warrior_skill_visual(item)
		_play_self_ability_vfx(u, item)
		state.cast_self_ability(u, item)
		# Tiro Rápido restringe os dois disparos ao Arco. Entrar direto na
		# mira dessa arma impede o atalho do tile vermelho de selecionar outra
		# arma por pontuação e cancelar acidentalmente o ataque bônus.
		var quick_shot_weapon = u.get("bonusAttackWeaponRestriction")
		if item.get("kind", "") == "haste-attack" and quick_shot_weapon != null and not u.get("hasActed", false):
			_select_attack_item(quick_shot_weapon)
			return
		# Tiro Explosivo (Químico) só bufa o próximo ataque com arma (dano
		# extra + queimadura, ver cast_explosive_shot) — pedido do usuário:
		# pula direto pra mira da própria arma em vez de fechar o menu e
		# esperar o jogador abrir Atacar > arma de novo.
		var caster_weapons: Array = u.get("weapons", [])
		if item.get("kind", "") == "explosive-shot" and not u.get("hasActed", false) and not caster_weapons.is_empty():
			_select_attack_item(caster_weapons[0])
			return
		# Saque Rápido (Samurai) só potencializa golpe de ESPADA: vai direto
		# pra mira da espada (1ª arma), sem obrigar Atacar > Espada.
		if item.get("kind", "") == "quick-draw" and not u.get("hasActed", false) and not caster_weapons.is_empty():
			_select_attack_item(caster_weapons[0])
			return
		_after_action()
		return
	if tm == "self-attack" or tm == "self-aoe":
		_resolve_spell(u, item, u["x"], u["y"])
		return

	mode = "spell"
	pending_item = item
	attackable_units = []
	attack_range_tiles = []
	spell_tiles = _compute_targetable_tiles(u, item, tm)
	# Corte Iaijutsu: mostra TODO o alcance da corrida (casas em azul-vermelho do
	# alcance), não só os inimigos clicáveis, mesmo sem ninguém na linha.
	if tm == "iaijutsu":
		attack_range_tiles = state.compute_iaijutsu_range_tiles(u, item)
	# Nuvem de Poeira / Cura da Vestruz: a área já aparece ao escolher; clicar na
	# própria Vestruz abre a confirmação.
	if tm == "dust-square" or tm == "heal-cross":
		aoe_preview_target = {"x": u["x"], "y": u["y"]}
		aoe_preview_tiles = state.compute_aoe_area_tiles(u, item, aoe_preview_target)
	_sync_visuals()

## Mesmo despacho por targetMode do onTileClick original (game.js:4130-4156)
## pra decidir QUE TILES mostrar como mira: itens "em linha" (Relâmpago,
## Perfurante, Atropelar, ou qualquer item com `cardinalOnly: true` como
## Arremessar Espada/Raio de Gelo) só podem mirar ao longo de uma reta/
## diagonal a partir de quem conjura, não o diamante inteiro de
## compute_range_tiles — sem isso, dava pra "jogar reto" uma magia de linha
## num alvo fora do eixo, ou usar Arremessar Espada na diagonal (a receita
## do item diz "só nas 4 direções cardeais").
func _compute_targetable_tiles(u: Dictionary, item: Dictionary, target_mode: String) -> Array:
	if item.get("rainBaseMode", "") == "pierce-line": return state.compute_line_target_tiles(u, item, true)
	if target_mode == "charge":
		return state.compute_charge_targets(u, item)
	if target_mode == "slime-jump":
		return state.compute_slime_jump_targets(u, item)
	if target_mode == "iaijutsu":
		return state.compute_iaijutsu_targets(u, item)
	if target_mode == "vestruz-dash":
		return state.compute_vestruz_dash_tiles(u, item)
	if target_mode == "dust-square" or target_mode == "heal-cross":
		return [{"x": u["x"], "y": u["y"]}]
	if target_mode == "dismount":
		return state.dismount_tiles(u)
	# Chute do Dragão: mesma mira do Relâmpago da Maga — só linhas retas (4
	# cardeais + 4 diagonais) até o alcance, sem exigir linha de visão.
	if target_mode == "dragon-kick":
		return state.compute_line_target_tiles(u, item)
	if target_mode == "crescent-arc":
		return state.compute_crescent_anchor_tiles(u)
	if target_mode == "line-aoe":
		return state.compute_line_target_tiles(u, item)
	if target_mode == "cardinal-blast" or target_mode == "creeping-line" or target_mode == "flame-creeping-line":
		return state.compute_cardinal_cross_tiles(u, item.get("bandLength", 1), item.get("bandWidth", 1))
	if target_mode == "pierce-line" or target_mode == "trample":
		return state.compute_line_target_tiles(u, item, true)
	if item.get("cardinalOnly", false):
		return state.compute_line_target_tiles(u, item, true)
	return state.compute_range_tiles(u, item)

## Popup de confirmação de movimento (pedido do usuário): mover só executa
## depois de confirmar, com Cancelar reabrindo a escolha de tile (reachable_
## tiles continua intacto até aqui, então cancelar não perde o alcance de
## movimento já calculado) — mesmo _confirm_panel genérico da confirmação de
## ataque, só trocando texto/callback.
func _request_move_confirmation(u: Dictionary, x: int, y: int) -> void:
	_confirm_title_label.text = "🏃 Mover"
	_confirm_body_label.text = "Mover %s para este local?" % u.get("name", "")
	_confirm_ok_button.text = "Mover"
	_confirm_cancel_button.text = "Cancelar"
	pending_confirm_action = func(): _perform_confirmed_move(u, x, y)
	_confirm_panel_set_accent(Color(ATTACK_ACCENT_DEFAULT))
	_position_confirm_panel_near_unit(u)

## Montar: o herói se move para cima da montaria adjacente; o clique nesse
## quadrado abre esta confirmação (mesmo painel do movimento comum).
func _request_mount_confirmation(u: Dictionary, mount: Dictionary) -> void:
	_confirm_title_label.text = "🐦 Montar"
	_confirm_body_label.text = "Mover %s para cima de %s e montar?
A dupla ocupa o mesmo quadrado, voa (MOV %d) e age no turno de %s." % [u.get("name", ""), mount["name"], int(mount["moveRange"]), u.get("name", "")]
	_confirm_ok_button.text = "Montar"
	_confirm_cancel_button.text = "Cancelar"
	pending_confirm_action = func(): _mount_on(u, mount)
	_confirm_panel_set_accent(Color(ATTACK_ACCENT_DEFAULT))
	_position_confirm_panel_near_unit(u)

func _perform_confirmed_move(u: Dictionary, x: int, y: int) -> void:
	if _online_mode:
		OnlineEndpoint.send_action({"action": "move", "actor": u["name"], "x": x, "y": y})
		_close_confirm_panel()
		return
	var movement_before := _capture_combat_snapshot()
	var movement_log_start := state.event_log.size()
	var souls_before: Array = state.souls.duplicate(true)
	var movement_path: Array = state.reconstruct_path(x, y).duplicate(true)
	state.perform_move(u, {"x": x, "y": y})
	var moving_token = unit_tokens.get(u["name"])
	if moving_token != null: (moving_token as UnitToken).animate_path(movement_path)
	var carrying_mount = state.mount_of(u)
	if carrying_mount != null:
		var mount_token = unit_tokens.get(carrying_mount["name"])
		if mount_token != null: (mount_token as UnitToken).animate_path(movement_path)
	_play_water_path_vfx(movement_path)
	_play_collected_soul_effects(souls_before)
	_play_new_tower_trap_effects()
	_show_combat_changes(movement_before, movement_log_start, 0.12)
	if _handle_dungeon_stair_transition(u):
		return
	_after_action()

## Popup de confirmação de ataque (pedido do usuário): mostra a chance de
## acerto detalhada (base + cada modificador que está valendo, ver
## GameState.get_effective_hit_chance_breakdown) e o dano esperado (+ efeitos
## como Fogo/Veneno) ANTES de resolver de verdade. Reaproveita o mesmo
## _confirm_panel genérico da confirmação de magia de área — só troca o
## texto/callback. A ação real só roda em _on_confirm_ok_pressed.
func _request_attack_confirmation(attacker: Dictionary, target: Dictionary, item: Dictionary) -> void:
	var preview: Dictionary = state.describe_attack_preview(attacker, target, item)
	_confirm_title_label.text = "%s %s em %s?" % [item.get("icon", "⚔️"), item.get("name", "Ataque"), target["name"]]
	var lines: Array[String] = [_format_hit_chance_line(preview)]
	lines.append_array(_format_expected_damage_lines(preview, item))
	_confirm_body_label.text = "\n".join(lines)
	_confirm_ok_button.text = "Atacar"
	_confirm_cancel_button.text = "Cancelar"
	pending_confirm_action = func(): _resolve_attack(attacker, target, item)
	_confirm_panel_set_accent(_attack_accent_color(item))
	_position_confirm_panel_near_unit(attacker)

## Cor de destaque da borda do pergaminho de confirmação por elemento do
## ataque (pedido do usuário) — lida do mesmo campo "sfx" já usado pelo
## catálogo de armas/magias (data/weapons.gd, data/spells.gd) pra escolher
## VFX, então cobre naturalmente qualquer arma/magia nova que seguir o
## mesmo padrão. Ataques físicos sem elemento (melee/ranged) ficam com a
## borda marrom neutra padrão do pergaminho.
const ATTACK_ACCENT_COLORS := {
	"fire": "c0392b",
	"poison": "27ae60",
	"freeze": "5dade2",
	"lightning": "f1c40f",
	"arcane": "9b59b6",
	"nature": "7cb342",
	"heal": "58d68d",
}
const ATTACK_ACCENT_DEFAULT := "6b4a2b"

func _attack_accent_color(item: Dictionary) -> Color:
	var sfx: String = String(item.get("sfx", ""))
	return Color(ATTACK_ACCENT_COLORS.get(sfx, ATTACK_ACCENT_DEFAULT))

func _confirm_panel_set_accent(color: Color) -> void:
	_confirm_panel_style.border_color = color

## Posiciona o pergaminho de confirmação ao lado do personagem que está
## agindo (pedido do usuário: "ao lado do personagem que está atacando e
## não no topo da tela") em vez do spot fixo no topo. Escolhe o lado
## (direita/esquerda do token) conforme a metade do tabuleiro em que ele
## está, pra minimizar o risco de estourar a borda da tela.
func _position_confirm_panel_near_unit(u: Dictionary) -> void:
	# Precisa ficar visível ANTES do reset_size(): um Control invisível não
	# passa pelo layout normal, então o Label de corpo (autowrap word) mede
	# a largura disponível como ~0 e "quebra" uma palavra por linha,
	# inflando a altura mínima pra muito mais do que o texto realmente
	# ocupa (sobra vazia gigante embaixo dos botões). Reset_size() só dá o
	# valor certo depois que o painel já está no layout com a largura real.
	_confirm_panel.visible = true
	_confirm_panel.reset_size()
	var anchor: Vector2 = _board_to_screen(board_view.tile_center(u["x"], u["y"]))
	var panel_width: float = _confirm_panel.size.x
	var to_the_right: bool = u["x"] < board_width_tiles() * 0.5
	var offset_x: float = 56.0 if to_the_right else -(56.0 + panel_width)
	var target := anchor + Vector2(offset_x, -70.0)
	var viewport_size: Vector2 = get_viewport_rect().size
	target.x = clampf(target.x, 8.0, viewport_size.x - panel_width - 8.0)
	target.y = clampf(target.y, 8.0, viewport_size.y - _confirm_panel.size.y - 8.0)
	_confirm_panel.position = target

## board_view guarda largura/altura reais do cenário ativo (a Horda é
## 26x22, os demais 13x13) — usa isso em vez de GameConstants.BOARD_SIZE
## fixo pra decidir o lado direito/esquerdo corretamente em qualquer mapa.
func board_width_tiles() -> int:
	return state.board_width if state != null else GameConstants.BOARD_SIZE

func _format_hit_chance_line(preview: Dictionary) -> String:
	if preview["hitChance"] == null:
		return "Este ataque sempre acerta."
	var breakdown: Array = preview["hitBreakdown"]
	var parts: Array[String] = []
	for i in range(breakdown.size()):
		var entry: Dictionary = breakdown[i]
		var pct: int = roundi(absf(float(entry["delta"])) * 100.0)
		if i == 0:
			parts.append("%s %d%%" % [entry["label"], pct])
		else:
			var sign: String = "+" if float(entry["delta"]) >= 0.0 else "-"
			parts.append("%s %d%% %s" % [sign, pct, entry["label"]])
	var total_pct: int = roundi(float(preview["hitChance"]) * 100.0)
	return "Chance de acerto: %d%% (%s)" % [total_pct, " ".join(parts)]

func _format_expected_damage_lines(preview: Dictionary, item: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if item.has("damageMin") and item.has("damageMax"):
		var line: String = "Dano esperado: %d-%d" % [preview["damageMin"], preview["damageMax"]]
		if float(preview["critChance"]) > 0.0:
			line += " (crítico %d%%: %d-%d)" % [roundi(float(preview["critChance"]) * 100.0), preview["critDamageMin"], preview["critDamageMax"]]
		lines.append(line)
	for effect in (preview["bonusEffects"] as Array):
		lines.append("+ %d-%d %s (%d turno(s))" % [effect["min"], effect["max"], effect["label"], effect["turns"]])
	return lines

func _resolve_attack(u: Dictionary, target: Dictionary, weapon: Dictionary) -> void:
	if _online_mode:
		OnlineEndpoint.send_action({"action": "attack", "actor": u["name"], "x": target["x"], "y": target["y"], "item": weapon})
		_close_confirm_panel()
		return
	if state.is_arrow_rain_attack(u, weapon):
		_resolve_spell(u, state.arrow_rain_item(weapon), target["x"], target["y"])
		return
	board_view.fade_action_feedback()
	if combat_feedback != null: combat_feedback.clear_targets()
	var combat_before := _capture_combat_snapshot()
	var log_start := state.event_log.size()
	# Calcula ANTES de chamar o motor, com a mesma função pura que
	# perform_ranged_attack_with_obstruction usa por dentro, só pra saber
	# onde mirar o VFX (arma sem obstrução: sempre acerta o tile do alvo).
	var vfx_tile: Dictionary = {"x": target["x"], "y": target["y"]}
	var vfx_hit: bool = true
	# Os buffs são consumidos dentro de resolve_single_hit; guarde a variante
	# visual antes para Flecha de Fogo/Tiro Explosivo chegarem ao VFX.
	var projectile_variant := String(weapon.get("projectile", ""))
	if projectile_variant == "arrow" and u.get("burnNextAttackAlwaysTurns", 0) > 0:
		projectile_variant = "fire-arrow"
	# Flecha de Gelo: pedido do usuário pra reaproveitar os feats e o som do
	# Raio de Gelo (weapons.gd:"iceRay") em vez de um VFX próprio.
	elif projectile_variant == "arrow" and u.get("slowNextAttackAlwaysTurns", 0) > 0:
		projectile_variant = "frost-wand-spd"
	elif projectile_variant == "arrow" and u.get("spriteKey", "") in ["arqueiro", "samurai"]:
		projectile_variant = "huntress-arrow-spd"
	elif projectile_variant == "bullet" and u.get("burnNextAttackTurns", 0) > 0:
		projectile_variant = "bullet-explosive"
	if weapon.get("requiresClearPath", false):
		vfx_tile = state.resolve_obstructed_target(u, {"x": target["x"], "y": target["y"]})
		vfx_hit = state.unit_at(vfx_tile["x"], vfx_tile["y"]) != null
		state.perform_ranged_attack_with_obstruction(u, target, weapon)
	else:
		state.perform_attack(u, target, weapon)
	var missile_damages: Array = state.last_action_vfx.get("missileDamages", []) if weapon.get("name", "") == "Míssil Mágico" else []
	var attack_log := "\n".join(state.event_log.slice(log_start)).to_lower()
	vfx_hit = vfx_hit and not ("errou" in attack_log or "não acerta" in attack_log or "só pode ser atingida" in attack_log)
	var vfx_critical := "crítico" in attack_log
	var acting_token = unit_tokens.get(u["name"])
	if acting_token is UnitToken and acting_token.is_using_warrior_3d() and not weapon.has("projectile") and vfx_hit:
		var struck_unit = state.unit_at(vfx_tile["x"], vfx_tile["y"])
		if struck_unit != null and struck_unit.get("hp", 0) > 0: struck_unit["deferHitVisual"] = true
	var counter_happened := _combat_has_counter(log_start)
	# Se este disparo consumir a última ação depois do movimento, o seletor
	# de direção só pode abrir quando o projétil realmente tocar o alvo.
	# Tiro Rápido não entra aqui no primeiro disparo, pois ainda deixa o
	# segundo ataque disponível com o mesmo arco.
	var turn_unit_of_attacker: Dictionary = state.turn_owner(u)
	var bonus_restriction = turn_unit_of_attacker.get("bonusAttackWeaponRestriction")
	var continues_quick_shot: bool = bonus_restriction != null and not turn_unit_of_attacker.get("hasActed", false) and bonus_restriction.get("name", "") == weapon.get("name", "")
	var moved_or_cannot_move: bool = turn_unit_of_attacker.get("hasMoved", false) or state.is_rooted(turn_unit_of_attacker)
	var turn_will_end: bool = moved_or_cannot_move and turn_unit_of_attacker.get("hasActed", false) and not continues_quick_shot
	var wait_for_projectile: bool = weapon.has("projectile") and turn_will_end
	# Durante qualquer revide a interface fica bloqueada, mesmo quando ainda
	# restaria movimento, para não permitir outra ação no meio da animação.
	var wait_for_counter: bool = counter_happened
	var after_projectile := Callable()
	if wait_for_projectile:
		_waiting_for_projectile_turn_end = true
		after_projectile = func():
			if counter_happened:
				# O revide visual começa pouco depois do impacto principal e só
				# então libera a orientação/fim do turno.
				var finish_timer := get_tree().create_timer(COUNTER_RESOLVE_EXTRA_WAIT)
				finish_timer.timeout.connect(func():
					_waiting_for_projectile_turn_end = false
					_after_action()
				)
			else:
				_waiting_for_projectile_turn_end = false
				_after_action()
	# Golpe múltiplo corpo a corpo (Rajada de Golpes): o atacante golpeia DUAS
	# vezes na tela, cada uma com a própria animação/impacto/popup.
	var multi_shots: Array = state.last_action_vfx.get("shotResults", []) if int(weapon.get("hits", 1)) > 1 and not weapon.has("projectile") else []
	if multi_shots.size() >= 1:
		_play_multi_strike(u, vfx_tile, weapon, multi_shots, counter_happened, target)
		return
	_play_attack_vfx(u, vfx_tile, weapon, vfx_hit, projectile_variant, after_projectile, vfx_critical)
	var popup_kind: String = projectile_variant if projectile_variant != "" else weapon.get("projectile", "")
	var popup_delay := _projectile_duration_for_kind(popup_kind) if weapon.has("projectile") else 0.10
	popup_delay += _ranged_release_delay(u, popup_kind)
	if acting_token is UnitToken and acting_token.is_using_warrior_3d() and not weapon.has("projectile"):
		popup_delay = acting_token.visual_3d_event_time("attack_light",0.305)
	if popup_kind == "frost-wand-spd":
		popup_delay = board_view.tile_center(u["x"], u["y"]).distance_to(board_view.tile_center(vfx_tile["x"], vfx_tile["y"])) / EffectsLayer.SPD_FROST_WORLD_SPEED
	if weapon.get("name", "") == "Míssil Mágico":
		_show_magic_missile_changes(missile_damages, target, u)
	else:
		_show_combat_changes(combat_before, log_start, popup_delay, target, u, target)
	# Tiro Rápido: o motor mantém a restrição ao Arco entre o primeiro e o
	# segundo disparo. Conserva a mesma arma selecionada e volta direto à
	# mira, sem obrigar o jogador a abrir Atacar > Arco novamente.
	if bonus_restriction != null and not u.get("hasActed", false) and bonus_restriction.get("name", "") == weapon.get("name", ""):
		if state.check_battle_outcome():
			mode = "idle"
			_after_action()
		else:
			_select_attack_item(weapon)
		return
	mode = "idle"
	if not wait_for_projectile:
		if wait_for_counter:
			_waiting_for_projectile_turn_end = true
			var finish_timer := get_tree().create_timer(popup_delay + COUNTER_RESOLVE_EXTRA_WAIT)
			finish_timer.timeout.connect(func():
				_waiting_for_projectile_turn_end = false
				_after_action()
			)
		else:
			_after_action()

## Intervalo entre os golpes de um ataque múltiplo (Rajada de Golpes).
const MULTI_STRIKE_INTERVAL := 0.6

## Executa na tela cada golpe de `shots` (resultado de perform_attack): pose de
## soco + impacto, popup próprio (dano/CRÍTICO/MISS) e reação do alvo, um a um.
## O turno só segue depois do último golpe (e de um eventual revide).
func _play_multi_strike(attacker: Dictionary, target_tile: Dictionary, weapon: Dictionary, shots: Array, counter_happened: bool, target: Dictionary) -> void:
	_waiting_for_projectile_turn_end = true
	mode = "idle"
	var visual_target = state.unit_at(target_tile["x"], target_tile["y"])
	var hit_token = unit_tokens.get(target.get("name", ""))
	for index in shots.size():
		var shot: Dictionary = shots[index]
		var strike_delay := float(index) * MULTI_STRIKE_INTERVAL
		var play_strike := func():
			if effects_layer == null or not is_instance_valid(effects_layer): return
			_play_attack_vfx(attacker, target_tile, weapon, bool(shot["hit"]), "", Callable(), bool(shot["critical"]))
			var center := board_view.tile_center(target_tile["x"], target_tile["y"])
			if hit_token != null and is_instance_valid(hit_token): center = (hit_token as UnitToken).visual_impact_point()
			var popup_delay := 0.30
			if bool(shot["hit"]):
				effects_layer.spawn_combat_popup(center, str(-int(shot["damage"])), "crit" if bool(shot["critical"]) else "damage", popup_delay, 0)
				if hit_token != null and is_instance_valid(hit_token):
					var origin := board_view.tile_center(attacker["x"], attacker["y"])
					var reaction_timer := get_tree().create_timer(popup_delay)
					reaction_timer.timeout.connect(func():
						if is_instance_valid(hit_token): (hit_token as UnitToken).play_weighted_hit_reaction(origin, bool(shot["critical"]))
					)
			else:
				effects_layer.spawn_combat_popup(center, "MISS", "miss", popup_delay, 0)
		if index == 0:
			play_strike.call()
		else:
			get_tree().create_timer(strike_delay).timeout.connect(play_strike)
	_sync_visuals()
	var total_wait := float(shots.size() - 1) * MULTI_STRIKE_INTERVAL + 0.6
	if counter_happened: total_wait += COUNTER_RESOLVE_EXTRA_WAIT
	get_tree().create_timer(total_wait).timeout.connect(func():
		_waiting_for_projectile_turn_end = false
		_after_action()
	)

func _combat_has_counter(log_start: int) -> bool:
	for line in state.event_log.slice(log_start):
		var text := String(line).to_lower()
		if "contra-ataca" in text or "contra-ataque" in text:
			return true
	return false

## Projétil genérico (se a arma/magia tiver `projectile`) ou flash de impacto
## corpo-a-corpo (por `swing`), colorido por _vfx_color_for_kind — cosmético,
## nunca lido de volta por regra nenhuma. `hit == false` só acontece em arma
## de obstrução que não achou ninguém no caminho (projétil viaja e some sem
## explosão).
func _play_attack_vfx(attacker: Dictionary, target_tile: Dictionary, item: Dictionary, hit: bool, projectile_variant: String = "", on_visual_complete: Callable = Callable(), critical: bool = false) -> void:
	if combat_feedback != null:
		combat_feedback.action_focus(board_view.tile_center(attacker["x"], attacker["y"]), board_view.tile_center(target_tile["x"], target_tile["y"]), "epic" if critical else "basic")
	var attacker_token = unit_tokens.get(attacker["name"])
	var profiled_melee: bool = attacker_token != null and not item.has("projectile")
	var projectile_kind := String(projectile_variant if projectile_variant != "" else item.get("projectile", "orb"))
	var release_delay := _ranged_release_delay(attacker, projectile_kind) if item.has("projectile") else 0.0
	var character_skill_visual := false
	if attacker_token != null:
		character_skill_visual = (attacker_token as UnitToken).play_warrior_skill_visual(
			item, board_view.tile_center(target_tile["x"], target_tile["y"]), "CRITICAL" if critical else ("HIT" if hit else "MISS"))
	if attacker_token != null and item.has("projectile") and release_delay > 0.0 and not character_skill_visual:
		(attacker_token as UnitToken).play_ranged_release(board_view.tile_center(target_tile["x"], target_tile["y"]), release_delay)
	elif attacker_token != null and not profiled_melee and not character_skill_visual:
		(attacker_token as UnitToken).play_attack(UnitToken.ATTACK_ACTION_DURATION, String(item.get("spriteAction", "attack")))
	# Som (equivalente a playAttackFx no JS: mesmo item.sfx do golpe, sem
	# distinguir acerto/erro da rolagem — mesma simplificação já usada pro
	# VFX, ver nota do STATUS.md) — toca mesmo sem effects_layer.
	var launch_key := String(item.get("sfx", "melee"))
	if item.has("projectile"):
		var launch_kind: String = projectile_variant if projectile_variant != "" else item.get("projectile", "")
		launch_key = {"arrow":"bowRelease","huntress-arrow-spd":"bowRelease","fire-arrow":"bowRelease","bolt":"crossbowRelease","bullet":"firearmRelease","bullet-explosive":"firearmRelease","bomb":"flaskThrow","magic-missile-spd":"magicMissileZapSpd","frost-wand-spd":"frostWandZapSpd"}.get(launch_kind, launch_key)
	elif launch_key == "melee":
		launch_key = "whoosh"
	if release_delay <= 0.0:
		AudioEngine.play_sfx(launch_key, AudioEngine.pan_for_x(attacker["x"]))
	if effects_layer == null:
		if on_visual_complete.is_valid(): on_visual_complete.call()
		return
	var to_pos: Vector2 = board_view.tile_center(target_tile["x"], target_tile["y"])
	if attacker_token != null and profiled_melee:
		(attacker_token as UnitToken).play_weighted_attack(to_pos, critical, String(item.get("spriteAction", "attack")))
	var visual_target = state.unit_at(target_tile["x"], target_tile["y"])
	if visual_target != null:
		var visual_target_token = unit_tokens.get(visual_target.get("name", ""))
		if visual_target_token != null: to_pos = (visual_target_token as UnitToken).visual_impact_point()
	if item.has("projectile"):
		if projectile_kind == "magic-missile-spd":
			_play_magic_missile_vfx(attacker, target_tile, item, hit, on_visual_complete)
			return
		var color := _vfx_color_for_kind(projectile_kind)
		var logical_origin := board_view.tile_center(attacker["x"], attacker["y"])
		var from_pos: Vector2 = (attacker_token as UnitToken).projectile_visual_origin(to_pos, projectile_kind) if attacker_token != null else logical_origin
		var direction := (to_pos - from_pos).normalized()
		var impact_pos := to_pos
		if not hit:
			var side := -1.0 if ((attacker["x"] + attacker["y"] + target_tile["x"] + target_tile["y"]) % 2 == 0) else 1.0
			impact_pos = to_pos + Vector2(-direction.y, direction.x) * 22.0 * side + direction * 25.0
		var travel_duration := _projectile_travel_duration(projectile_kind, from_pos, impact_pos)
		var launch_projectile := func():
			AudioEngine.play_sfx(launch_key, AudioEngine.pan_for_x(attacker["x"]))
			effects_layer.spawn_projectile_release(from_pos, direction, color)
			if projectile_kind in ["fire-arrow", "bullet-explosive"]:
				effects_layer.spawn_fire_weapon_launch(from_pos, direction, projectile_kind)
			var on_projectile_arrive := func():
				effects_layer.play_projectile_impact(impact_pos, direction, projectile_kind, color, hit, critical)
				if hit:
					board_view.shake_camera_at(impact_pos, direction, 1.45 if critical else 0.55, 0.16 if critical else 0.10, critical)
				AudioEngine.play_impact(projectile_kind, AudioEngine.pan_for_x(target_tile["x"]), hit)
				if on_visual_complete.is_valid(): on_visual_complete.call()
			if projectile_kind == "beam":
				effects_layer.spawn_cast_cue(from_pos, color, "ice")
				effects_layer.spawn_beam(from_pos, impact_pos, color, "ice", travel_duration)
				var beam_timer := get_tree().create_timer(travel_duration)
				beam_timer.timeout.connect(on_projectile_arrive)
			else:
				var trajectory := "arc" if projectile_kind in ["bomb", "stone", "flask"] else "straight"
				effects_layer.spawn_projectile_visual(from_pos, impact_pos, color, travel_duration, on_projectile_arrive, 8.0, projectile_kind, trajectory)
		if release_delay > 0.0:
			get_tree().create_timer(release_delay).timeout.connect(launch_projectile)
		else:
			launch_projectile.call()
	elif hit:
		if profiled_melee:
			var visual_profile := CLASS_VISUAL_PROFILES.for_unit(attacker)
			# UnitToken.ATTACK_WEIGHT_SCALE escala a mesma "anticipation" dentro
			# do tween de play_weighted_attack (unit_token.gd) — precisa entrar
			# aqui também, senão o impacto/som dispara antes do braço terminar
			# o giro (golpe pesado ficando fora de sincronia com o VFX/SFX).
			var weighted_anticipation := float(visual_profile.get("anticipation", 0.10)) * UnitToken.ATTACK_WEIGHT_SCALE
			var impact_delay := weighted_anticipation * 1.65 + maxf(0.055, weighted_anticipation * 0.78)
			var melee_impact_timer := get_tree().create_timer(impact_delay)
			melee_impact_timer.timeout.connect(_play_warrior_melee_impact.bind(attacker, target_tile, to_pos, item, critical, on_visual_complete))
			return
		var color := _vfx_color_for_kind(item.get("swing", ""))
		effects_layer.spawn_slash(to_pos, color, item.get("swing", "slash"))
		effects_layer.spawn_burst(to_pos, BoardView.TILE_SIZE * 0.22, color, 0.16, "physical")
		effects_layer.emit_environment_reaction("melee_impact", to_pos, (to_pos - board_view.tile_center(attacker["x"], attacker["y"])).normalized(), "medium" if item.get("damageMax", 0) >= 10 else "light")
		if item.get("damageType", "") == "fire":
			var from_pos := board_view.tile_center(attacker["x"], attacker["y"])
			effects_layer.spawn_fire_weapon_launch(from_pos, (to_pos - from_pos).normalized(), "fire-arrow")
			effects_layer.spawn_fire_arrow_impact(to_pos)
		var impact_event := "strong_hit" if item.get("damageMax",0) >= 10 else ("stab_hit" if item.get("swing","") == "stab" else ("crush_hit" if item.get("swing","") in ["blunt","crush"] else "slash_hit"))
		AudioEngine.play_event(impact_event, AudioEngine.pan_for_x(target_tile["x"]))
		if on_visual_complete.is_valid(): on_visual_complete.call()
	else:
		AudioEngine.play_event("miss", AudioEngine.pan_for_x(target_tile["x"]))
		if on_visual_complete.is_valid(): on_visual_complete.call()

func _play_magic_missile_vfx(attacker: Dictionary, target_tile: Dictionary, item: Dictionary, hit: bool, on_visual_complete: Callable) -> void:
	var attacker_token = unit_tokens.get(attacker["name"])
	var target_pos := board_view.tile_center(target_tile["x"], target_tile["y"])
	var visual_target = state.unit_at(target_tile["x"], target_tile["y"])
	if visual_target != null:
		var target_token = unit_tokens.get(visual_target.get("name", ""))
		if target_token != null: target_pos = (target_token as UnitToken).visual_impact_point()
	var origin := (attacker_token as UnitToken).projectile_visual_origin(target_pos, "magic-missile-spd") if attacker_token != null else board_view.tile_center(attacker["x"], attacker["y"])
	var missile_count := maxi(1, int(item.get("hits", 4)))
	var missile_spacing := 0.18
	var missile_duration := clampf(origin.distance_to(target_pos) / 780.0, 0.28, 0.62)
	var finished := false
	for index in missile_count:
		var launch_delay := float(index) * missile_spacing
		get_tree().create_timer(launch_delay).timeout.connect(func():
			var direction := (target_pos - origin).normalized()
			AudioEngine.play_sfx("magicMissileZapSpd", AudioEngine.pan_for_x(attacker["x"]))
			effects_layer.spawn_projectile_release(origin, direction, Color.WHITE)
			var arrive := func():
				effects_layer.play_projectile_impact(target_pos, direction, "magic-missile-spd", Color.WHITE, hit, false)
				AudioEngine.play_impact("magic-missile-spd", AudioEngine.pan_for_x(target_tile["x"]), hit)
				if index == missile_count - 1 and not finished:
					finished = true
					if on_visual_complete.is_valid(): on_visual_complete.call()
			effects_layer.spawn_projectile_visual(origin, target_pos, Color.WHITE, missile_duration, arrive, 5.0, "magic-missile-spd", "straight")
		)

func _show_magic_missile_changes(damages: Array, target_tile: Dictionary, attacker: Dictionary) -> void:
	if effects_layer == null: return
	var center := board_view.tile_center(target_tile["x"], target_tile["y"])
	var target = state.unit_at(target_tile["x"], target_tile["y"])
	if target != null:
		var target_token = unit_tokens.get(target.get("name", ""))
		if target_token != null: center = (target_token as UnitToken).visual_impact_point()
	var count := maxi(1, damages.size())
	for index in count:
		var damage := int(damages[index]) if index < damages.size() else 0
		var delay := 0.34 + float(index) * 0.18
		effects_layer.spawn_combat_popup(center, str(-damage), "damage", delay, 0)
		if target != null:
			var hit_token = unit_tokens.get(target.get("name", ""))
			if hit_token != null:
				var attack_origin := board_view.tile_center(attacker["x"], attacker["y"])
				var hit_timer := get_tree().create_timer(delay)
				hit_timer.timeout.connect((hit_token as UnitToken).play_weighted_hit_reaction.bind(attack_origin, false))

func _play_warrior_melee_impact(attacker: Dictionary, target_tile: Dictionary, to_pos: Vector2, item: Dictionary, critical: bool, on_visual_complete: Callable) -> void:
	if effects_layer == null: return
	var direction := (to_pos - board_view.tile_center(attacker["x"], attacker["y"])).normalized()
	var visual_profile := CLASS_VISUAL_PROFILES.for_unit(attacker)
	var trail_profile := String(visual_profile.get("trail_profile", "standard"))
	var camera_impulse := float(visual_profile.get("camera_impulse", 0.45))
	var slash = WARRIOR_SLASH_SCENE.instantiate()
	effects_layer.add_child(slash)
	slash.position = to_pos
	var trail_color := Color("d9e7ff") if trail_profile == "thin_fast" else (Color("bde9a5") if trail_profile == "organic" else Color("fff0b2"))
	slash.setup(direction, trail_color)
	slash.scale *= 0.72 if trail_profile == "thin_fast" else (1.18 if trail_profile in ["broad_slash", "heavy", "boss_heavy"] else 0.92)
	var color := _vfx_color_for_kind(item.get("swing", ""))
	effects_layer.spawn_burst(to_pos, BoardView.TILE_SIZE * 0.24, color, 0.18, "physical")
	board_view.shake_camera_at(to_pos, direction, camera_impulse * (1.65 if critical else 1.0), 0.20 if critical else 0.12, critical)
	effects_layer.emit_environment_reaction("melee_impact", to_pos, direction, "heavy" if camera_impulse >= 0.75 or critical else ("medium" if camera_impulse >= 0.35 else "light"))
	var impact_event := "strong_hit" if critical or item.get("damageMax", 0) >= 10 else "slash_hit"
	AudioEngine.play_event(impact_event, AudioEngine.pan_for_x(target_tile["x"]))
	if on_visual_complete.is_valid(): on_visual_complete.call()

func _projectile_duration_for_kind(kind: String) -> float:
	# Fallback sem origem/destino. O disparo real usa distância em
	# _projectile_travel_duration para permanecer legível sem ficar lento.
	match kind:
		"arrow": return 0.22
		"huntress-arrow-spd": return 0.22
		"fire-arrow": return 0.22
		"bolt": return 0.90
		"stone": return 1.16
		"bullet": return 0.56
		"bullet-explosive": return 0.56
		"spark": return 1.00
		"beam": return 0.72
		"missile": return 1.24
		"magic-missile-spd": return 1.24
		# Somente fallback para chamadas sem origem/destino; o disparo real usa
		# distância / 800 px/s, equivalendo aos 200 px/s do SPD em tiles 16 px.
		"frost-wand-spd": return BoardView.TILE_SIZE / EffectsLayer.SPD_FROST_WORLD_SPEED
		"fireball": return 1.36
		"bomb": return 1.20
		"blade": return 1.10
		"wind-blade": return 0.30
		"spit": return 0.40
		_: return 0.84

func _projectile_travel_duration(kind: String, from: Vector2, to: Vector2) -> float:
	if kind == "frost-wand-spd":
		return from.distance_to(to) / EffectsLayer.SPD_FROST_WORLD_SPEED
	if kind in ["arrow", "huntress-arrow-spd", "fire-arrow", "wind-blade"]:
		# Pedido do usuário: a flecha viajando rápido demais fazia o dano
		# parecer instantâneo/simultâneo ao disparo em vez de uma fase
		# separada — dobrado o tempo de voo pra ficar legível.
		var tiles := from.distance_to(to) / BoardView.TILE_SIZE
		return clampf(0.20 + tiles * 0.06, 0.28, 0.55)
	return _projectile_duration_for_kind(kind)

## Tempo de leitura antes do release. Começa pelo Arqueiro sem mudar os
## tempos das armas já existentes; novas unidades podem adotar a mesma base.
func _ranged_release_delay(attacker: Dictionary, projectile_kind: String) -> float:
	if attacker.get("spriteKey", "") in ["arqueiro", "samurai"] and projectile_kind in ["arrow", "huntress-arrow-spd", "fire-arrow", "frost-wand-spd"]:
		return 0.30
	if attacker.get("spriteKey", "") == "bardo" and projectile_kind == "bolt":
		return 0.16
	if attacker.get("spriteKey", "") == "quimico" and projectile_kind in ["bullet", "bullet-explosive", "bomb", "flask"]:
		return 0.17
	return 0.0

## Explosão genérica pra magia de área (equivalente bem mais simples a
## spawnAreaBurst/spawnConeSweep/spawnGroundCrackSweep etc. do JS, que têm
## uma animação dedicada por magia). Recalcula os tiles com a mesma função
## pura que os cast* já usaram (compute_aoe_area_tiles) só pra saber onde
## desenhar — nunca decide nem re-decide a regra em si.
func _play_aoe_vfx(u: Dictionary, item: Dictionary, x: int, y: int) -> void:
	AudioEngine.play_sfx(item.get("sfx", "arcane"), AudioEngine.pan_for_x(x))
	if effects_layer == null:
		return
	var mode: String = item.get("targetMode", "")
	if mode == "cone-poison" or item.get("kind", "") == "poison-potion":
		AudioEngine.play_sfx("toxicGasSpd", AudioEngine.pan_for_x(x))
	var color := _vfx_color_for_kind(item.get("burstKind", item.get("projectileKind", _default_vfx_kind_for_mode(mode))))
	var caster_token = unit_tokens.get(u["name"])
	if caster_token != null:
		var body_element := "heal" if mode in ["heal-aoe", "regen-aoe", "cure-aoe", "mana-aoe"] else ("ice" if mode == "freeze-aoe" else ("lightning" if mode == "line-aoe" else ("fire" if mode in ["cone-fire", "flame-creeping-line"] else "arcane")))
		(caster_token as UnitToken).play_magic_body_light(body_element, 1.0, 0.34)

	if mode == "point-aoe":
		var impact = {"x": x, "y": y} if item.get("ignoresUnitObstruction", false) else state.resolve_obstructed_target(u, {"x": x, "y": y})
		var proj_color := _vfx_color_for_kind(item.get("projectileKind", "fireball"))
		var from_pos: Vector2 = board_view.tile_center(u["x"], u["y"])
		var to_pos: Vector2 = board_view.tile_center(impact["x"], impact["y"])
		# ETAPA 16 — Signature Ability do Químico (Bomba): mesmo arremesso em
		# arco/explosão de sempre, só com impacto um pouco mais cheio e
		# reação de ambiente/câmera, sem tocar em dano/área/regras.
		var point_signature := SignatureVisualProfiles.for_item(u, item)
		var burst_radius: float = maxf(float(item.get("areaRadius", 1)), 0.5) * BoardView.TILE_SIZE * 0.85 * float(point_signature.get("impact_radius_mult", 1.0))
		var point_kind: String = item.get("projectileKind", "fireball")
		var on_arrive := func():
			effects_layer.spawn_burst(to_pos, burst_radius, color, 0.48, point_kind)
			if point_kind in ["bomb", "bullet-explosive"]:
				effects_layer.spawn_explosion(to_pos)
			AudioEngine.play_impact(point_kind, AudioEngine.pan_for_x(impact["x"]), true)
			if not point_signature.is_empty():
				var impact_dir := (to_pos - from_pos).normalized()
				board_view.shake_camera_at(to_pos, impact_dir, 1.4, 0.10, false)
				effects_layer.emit_environment_reaction("heavy_impact", to_pos, impact_dir, String(point_signature.get("environment_intensity", "signature")), String(point_signature.get("environment_element", "")))
		effects_layer.spawn_cast_cue(from_pos, proj_color, point_kind)
		effects_layer.spawn_projectile(from_pos, to_pos, proj_color, _projectile_duration_for_kind(point_kind), on_arrive, 11.0, point_kind)
		return

	if mode == "trap":
		effects_layer.spawn_burst(board_view.tile_center(x, y), BoardView.TILE_SIZE * 0.4, color, 0.3, "trap")
		return

	var area_tiles = state.compute_aoe_area_tiles(u, item, {"x": x, "y": y})
	if area_tiles == null:
		return
	var centers: Array = []
	for t in area_tiles:
		centers.append(board_view.tile_center(t["x"], t["y"]))
	var origin := board_view.tile_center(u["x"], u["y"])
	effects_layer.spawn_cast_cue(origin, color, _default_vfx_kind_for_mode(mode))
	if mode == "heal-aoe":
		for center in centers: effects_layer.spawn_heal_absorb(center)
	elif mode == "regen-aoe":
		for center in centers: effects_layer.spawn_regen_cue(center)
	elif mode == "cure-aoe":
		for center in centers: effects_layer.spawn_heal_absorb(center, Color("a8f5e8"))
	elif mode == "mana-aoe":
		for center in centers: effects_layer.spawn_heal_absorb(center, Color("8ec9ff"))
	elif mode == "freeze-aoe":
		var freeze_target := board_view.tile_center(x, y)
		effects_layer.play_magic_cast(origin, origin + (freeze_target - origin).normalized() * 22.0 + Vector2(0, -9), {"color": Color("9de9ff"), "duration": 0.26, "intensity": 0.9, "element": "frost"})
		var freeze_arrive := func():
			for center in centers:
				effects_layer.spawn_ice_impact(center, 1.0 if center.distance_to(freeze_target) < 2.0 else 0.58)
			board_view.shake_camera_at(freeze_target, (freeze_target - origin).normalized(), 0.72, 0.075, false)
		get_tree().create_timer(0.26).timeout.connect(func(): effects_layer.spawn_projectile_visual(origin + Vector2(0, -9), freeze_target, color, 0.32, freeze_arrive, 10.0, "frost", "straight"))
	elif mode == "line-aoe":
		var lightning_target := board_view.tile_center(x, y)
		effects_layer.play_magic_cast(origin, origin + (lightning_target - origin).normalized() * 22.0 + Vector2(0, -9), {"color": Color("d7f6ff"), "duration": 0.16, "intensity": 1.05, "element": "lightning"})
		get_tree().create_timer(0.16).timeout.connect(func():
			# Varinha de Relâmpago do Shattered Pixel Dungeon: o arco parte
			# do conjurador e salta pelos alvos/células atingidos, com faíscas
			# em cada ponto, em vez de ser apenas um raio único até o fim.
			var lightning_points: Array = [origin + Vector2(0, -9)]
			for center in centers:
				lightning_points.append(center)
			if lightning_points.size() == 1:
				lightning_points.append(lightning_target)
			effects_layer.spawn_lightning_connection(lightning_points, Color("d7f6ff"), 1.0)
			for center in centers: effects_layer.spawn_electric_sparks(center, Color("bdefff"))
			board_view.shake_camera_at(lightning_target, (lightning_target - origin).normalized(), 0.82, 0.055, false)
		)
	elif mode == "pierce-line":
		var pierce_target := board_view.tile_center(x, y)
		# ETAPA 16 — Signature Ability do Arqueiro (Tiro Penetrante): mesma
		# flecha em linha reta de sempre, só com trilha mais legível e um
		# beat de impacto no fim da linha (a flecha comum não tinha nenhum).
		var pierce_signature := SignatureVisualProfiles.for_item(u, item)
		var pierce_arrive := Callable()
		var beam_alpha := 0.35
		if not pierce_signature.is_empty():
			var pierce_dir := (pierce_target - origin).normalized()
			beam_alpha = clampf(0.35 * float(pierce_signature.get("impact_radius_mult", 1.0)), 0.0, 1.0)
			pierce_arrive = func():
				board_view.shake_camera_at(pierce_target, pierce_dir, 1.1, 0.07, false)
				effects_layer.emit_environment_reaction("projectile_impact", pierce_target, pierce_dir, String(pierce_signature.get("environment_intensity", "medium")), String(pierce_signature.get("environment_element", "")))
		effects_layer.spawn_projectile(origin, pierce_target, Color("dec58f"), 1.04, pierce_arrive, 8.0, "arrow")
		effects_layer.spawn_beam(origin, pierce_target, Color(Color("dec58f"), beam_alpha), "pierce", 1.04)
	elif mode == "cone-fire":
		# Pedido do usuário: mesmo impacto (Flame/Blast/Smoke) do
		# WandOfFireblast do Shattered Pixel Dungeon, já portado em
		# effects_layer.spawn_fireblast_area — só faltava ligar aqui.
		effects_layer.spawn_fireblast_area(centers, origin)
	elif mode == "flame-creeping-line":
		# Uma Bola de Fogo por faixa, em vez de uma por tile: o visual percorre
		# toda a mesma área da Destruição Rastejante com custo de três VFX.
		var endpoints := {}
		var horizontal: bool = x != int(u["x"])
		for t in area_tiles:
			var lane: int = int(t["y"] if horizontal else t["x"])
			var distance: int = abs(int(t["x"]) - int(u["x"])) + abs(int(t["y"]) - int(u["y"]))
			if not endpoints.has(lane) or distance > int(endpoints[lane]["distance"]):
				endpoints[lane] = {"tile": t, "distance": distance}
		for lane_data in endpoints.values():
			var end_tile: Dictionary = lane_data["tile"]
			var end_pos := board_view.tile_center(end_tile["x"], end_tile["y"])
			effects_layer.spawn_fireball(origin, end_pos, 330.0, func(impact_position, impact_direction): effects_layer.spawn_fireball_impact(impact_position, impact_direction), 0.72)
	elif mode == "cone-ice":
		# Pedido do usuário: Cone de Gelo ganha o mesmo efeito de impacto de
		# gelo (cristais + luz + decal) do Congelamento, em vez do burst
		# genérico que o "else" abaixo usaria — cone reto, então varre em
		# leque a partir da origem em vez de todo mundo junto.
		for i in centers.size():
			var center: Vector2 = centers[i]
			var delay := origin.distance_to(center) / 900.0
			var timer := get_tree().create_timer(delay)
			timer.timeout.connect(effects_layer.spawn_ice_impact.bind(center, 0.85))
	else:
		effects_layer.spawn_sweep(centers, color, _default_vfx_kind_for_mode(mode), origin)

func _play_self_ability_vfx(u: Dictionary, item: Dictionary) -> void:
	var token = unit_tokens.get(u["name"])
	if token != null:
		(token as UnitToken).play_cast()
	if effects_layer == null: return
	var kind: String = item.get("kind", "generic")
	var name_lower := String(item.get("name", "")).to_lower()
	var visual_kind := "nature" if kind in ["regen", "heal"] else kind
	if kind == "hit-and-run": visual_kind = "goblin-dash"
	elif kind in ["poison-potion", "sand-in-eyes", "low-blow"]: visual_kind = "poison" if kind == "poison-potion" else "goblin-sand"
	elif kind == "power-attack" and String(item.get("name", "")) == "Emboscada Goblin": visual_kind = "goblin-ambush"
	elif kind == "play-dead": visual_kind = "goblin-feign"
	if kind.begins_with("bard-song-"):
		visual_kind = "nature" if item.get("songKind", "") == "heal" else "arcane"
		AudioEngine.play_sfx(item.get("sfx", "arcane"), AudioEngine.pan_for_x(int(u["x"])))
	if "fogo" in name_lower: visual_kind = "fireball"
	elif "invis" in name_lower: visual_kind = "arcane"
	elif "defender" in name_lower or "evasiva" in name_lower: visual_kind = "frost"
	elif "fúria" in name_lower or "berserk" in name_lower: visual_kind = "fire"
	# Samurai: concentração de energia (Meditar), postura defensiva (Garça) e
	# saque rápido da lâmina — só apresentação, sobre o mesmo cast_cue de sempre.
	if kind == "monk-meditate": visual_kind = "nature"
	elif kind in ["heron-stance", "quick-draw"]: visual_kind = "wind"
	var center := board_view.tile_center(u["x"], u["y"])
	var color := _vfx_color_for_kind(visual_kind)
	if kind == "monk-meditate":
		effects_layer.spawn_regen_cue(center, color)
		effects_layer.spawn_temporary_light(center, color, 0.6, 0.7, 70.0)
		if token != null: (token as UnitToken).play_magic_body_light("heal", 0.9, 0.7)
	elif kind == "heron-stance":
		effects_layer.spawn_shockwave(center, Color(0.86, 0.96, 1.0), 60.0, 0.36)
		effects_layer.spawn_ground_crack(center, Color(0.86, 0.96, 1.0))
	elif kind == "quick-draw":
		effects_layer.spawn_slash(center + Vector2(16, -12), Color(0.92, 0.98, 1.0), "slash")
		effects_layer.spawn_gust(center, Color(0.85, 0.95, 1.0))
	effects_layer.spawn_cast_cue(center, color, visual_kind)
	# ETAPA 16 — Signature Ability do Ladino (Golpe Debilitante) e do Bardo
	# (Canção da Inspiração): mesmo cast_cue/burst de sempre, só com o burst
	# final um pouco mais cheio e (só quando a habilidade em si já é uma
	# magia, como a canção) um glow de corpo — Ladino não recebe glow, pois a
	# habilidade não tem nada de mágico.
	var self_signature := SignatureVisualProfiles.for_item(u, item)
	var burst_scale := float(self_signature.get("impact_radius_mult", 1.0))
	effects_layer.spawn_burst(center, BoardView.TILE_SIZE * 0.48 * burst_scale, color, 0.4, visual_kind)
	if not self_signature.is_empty():
		var body_light := float(self_signature.get("body_light", 0.0))
		if body_light > 0.0 and token != null:
			(token as UnitToken).play_magic_body_light(visual_kind, body_light, 0.4)

func _play_target_spell_vfx(caster: Dictionary, target: Dictionary, item: Dictionary, kind: String) -> void:
	if effects_layer == null: return
	var from_pos := board_view.tile_center(caster["x"], caster["y"])
	var to_pos := board_view.tile_center(target["x"], target["y"])
	var color := _vfx_color_for_kind(kind)
	effects_layer.spawn_cast_cue(from_pos, color, kind)
	if item.get("targetMode", "") == "resurrect":
		effects_layer.spawn_resurrection(from_pos, to_pos)
		return
	if kind == "nature":
		effects_layer.spawn_beam(from_pos, to_pos, color, "nature", 0.42)
		if item.get("targetMode", "") == "root":
			effects_layer.spawn_ground_crack(to_pos, color)
		else:
			effects_layer.spawn_heal_absorb(to_pos, color)
	else:
		effects_layer.spawn_projectile(from_pos, to_pos, color, 1.0, func(): effects_layer.spawn_burst(to_pos, BoardView.TILE_SIZE * 0.36, color, 0.38, kind), 8.0, kind)

## Kind-padrão por targetMode quando a magia não declara `burstKind`/
## `projectileKind` no catálogo (a maioria não declara — só Bola de Fogo/
## Explosão Sonora/Bomba têm kind explícito no JS original).
func _default_vfx_kind_for_mode(mode: String) -> String:
	match mode:
		"point-aoe":
			return "fireball"
		"line-aoe":
			return "lightning"
		"freeze-aoe":
			return "frost"
		"cure-aoe", "heal-aoe", "regen-aoe", "mana-aoe":
			return "nature"
		"inflict-wounds":
			return "poison"
		"cone-poison":
			return "poison"
		"cone-windstorm":
			return "wind"
		"cone-ice":
			return "frost"
		"creeping-line":
			return "ground"
		"cardinal-blast":
			return "log"
		"pierce-line":
			return "arcane"
		"trap":
			return "trap"
		_:
			return "generic"

## Cor por "kind" (mesmo vocabulário informal do JS: projectileKind/
## burstKind/projectile/swing) — só cosmético, sem relação com nenhuma regra.
func _vfx_color_for_kind(kind: String) -> Color:
	match kind:
		"goblin-dash": return Color(0.45, 0.95, 0.35)
		"goblin-ambush": return Color(0.85, 0.25, 0.18)
		"goblin-feign": return Color(0.55, 0.48, 0.38)
		"fireball", "fire", "bomb":
			return Color(1.0, 0.45, 0.15)
		"sound", "soundwave":
			return Color(0.55, 0.8, 1.0)
		"frost", "ice", "beam", "frost-wand-spd":
			return Color(0.6, 0.9, 1.0)
		"lightning":
			return Color(1.0, 0.95, 0.3)
		"poison":
			return Color(0.45, 0.85, 0.35)
		"goblin-poison-potion": return Color(0.35, 0.9, 0.25)
		"goblin-sand": return Color(0.82, 0.68, 0.32)
		"goblin-barrel": return Color(0.58, 0.34, 0.16)
		"nature":
			return Color(0.5, 0.9, 0.5)
		"wind":
			return Color(0.75, 0.95, 0.85)
		"ground":
			return Color(0.6, 0.45, 0.3)
		"log":
			return Color(0.55, 0.34, 0.16)
		"arcane", "missile", "spark", "magic-missile-spd":
			return Color(0.75, 0.5, 1.0)
		"wind-blade":
			return Color(0.66, 0.9, 1.0)
		"spit":
			return Color(0.86, 0.95, 0.55)
		"arrow", "bolt", "huntress-arrow-spd":
			return Color(0.6, 0.45, 0.25)
		"fire-arrow", "bullet-explosive":
			return Color("ff7a22")
		"stone":
			return Color(0.65, 0.65, 0.65)
		"bullet":
			return Color(0.9, 0.35, 0.25)
		"trap":
			return Color(0.35, 0.55, 0.35)
		"slash":
			return Color(0.95, 0.95, 0.95)
		"blunt":
			return Color(1.0, 0.7, 0.3)
		"stab":
			return Color(0.85, 0.85, 0.95)
		_:
			return Color(1.0, 1.0, 1.0)

## Despacha pro resolvedor certo conforme o targetMode do item — mesma
## tabela que onTileClick usava no JS original pra decidir qual cast*
## chamar, só que sem o preview de 2 cliques (aqui já resolve no clique).
func _resolve_spell(u: Dictionary, item: Dictionary, x: int, y: int) -> void:
	if _online_mode:
		var action_name := "dismount" if String(item.get("targetMode", "")) == "dismount" else "spell"
		OnlineEndpoint.send_action({"action": action_name, "actor": u["name"], "x": x, "y": y, "item": item})
		_close_confirm_panel()
		mode = "idle"
		return
	if _waiting_for_projectile_turn_end: return
	var tm: String = item.get("targetMode", "")
	if not AOE_CONFIRM_MODES.has(tm) and tm != "self-attack" and not String(item.get("kind", "")).begins_with("bard-song"):
		_apply_spell(u, item, x, y)
		return
	if state.turn_owner(u).get("hasActed", false) or u.get("mp", 0) < item.get("mpCost", 0): return
	var tiles = state.arrow_rain_tiles(u, item, {"x":x, "y":y}) if tm == "arrow-rain" else state.compute_aoe_area_tiles(u, item, {"x":x, "y":y})
	if tiles == null: tiles = []
	var centers: Array = []
	for tile in tiles: centers.append(board_view.tile_center(tile["x"], tile["y"]))
	var target := board_view.tile_center(x, y)
	if tm == "point-aoe" and not item.get("ignoresUnitObstruction", false):
		var obstructed: Dictionary = state.resolve_obstructed_target(u, {"x":x, "y":y})
		target = board_view.tile_center(obstructed["x"], obstructed["y"])
	_area_sequence_active = true
	_waiting_for_projectile_turn_end = true
	mode = "area_sequence"
	_close_action_menu()
	_clear_aoe_preview()
	var run_id := _ai_sequence_id
	var origin := board_view.tile_center(u["x"], u["y"])
	var token = unit_tokens.get(u["name"])
	if token != null:
		if tm == "arrow-rain": (token as UnitToken).play_weighted_attack(origin + Vector2(0, -120), true)
		elif tm == "self-attack": (token as UnitToken).play_warrior_skill_visual(item, target)
		elif tm == "crescent-arc": (token as UnitToken).play_attack(UnitToken.ATTACK_ACTION_DURATION, "attack")
		else: (token as UnitToken).play_cast()
	var sequence := effects_layer.spawn_area_sequence(item, centers, origin, target, BoardView.TILE_SIZE, u.get("burnNextAttackAlwaysTurns", 0) > 0)
	sequence.impact.connect(func():
		if run_id != _ai_sequence_id or not _area_sequence_active: return
		AudioEngine.play_sfx(item.get("sfx", "arcane"), AudioEngine.pan_for_x(x))
		if sequence.element in ["fire", "physical", "lightning"]:
			board_view.shake_camera_at(target, (target - origin).normalized(), 1.4, 0.12, false)
		_apply_spell(u, item, x, y)
	)
	sequence.completed.connect(func():
		if run_id != _ai_sequence_id: return
		_area_sequence_active = false
		_waiting_for_projectile_turn_end = false
		_after_action()
	)
	sequence.tree_exiting.connect(func():
		if run_id == _ai_sequence_id and _area_sequence_active:
			_area_sequence_active = false
			_waiting_for_projectile_turn_end = false
			_after_action()
	)

func _apply_spell(u: Dictionary, item: Dictionary, x: int, y: int) -> void:
	board_view.fade_action_feedback()
	var signature_profile := SignatureVisualProfiles.for_item(u, item)
	if combat_feedback != null:
		combat_feedback.clear_targets()
		var focus_importance := "normal"
		if not signature_profile.is_empty(): focus_importance = String(signature_profile.get("camera_importance", "signature"))
		elif item.get("damageMax", 0) >= 12: focus_importance = "epic"
		combat_feedback.action_focus(board_view.tile_center(u["x"], u["y"]), board_view.tile_center(x, y), focus_importance, float(signature_profile.get("camera_zoom", 0.0)))
	# Projeto-piloto dedicado: somente a Bola de Fogo do Mago usa a nova
	# sequência assíncrona. Explosão Sonora e Bomba continuam exatamente no
	# resolvedor point-aoe anterior.
	if _is_mage_fireball(item) and not _area_sequence_active:
		_resolve_mage_fireball(u, item, x, y)
		return
	var combat_before := _capture_combat_snapshot()
	var log_start := state.event_log.size()
	var tm: String = item.get("targetMode", "")
	# Chute do Dragão tem sequência própria (voadora + chute, ver o case
	# "dragon-kick" abaixo) — não usa a pose genérica de conjuração.
	if tm != "enemy" and tm != "dragon-kick":
		var caster_token = unit_tokens.get(u["name"])
		if caster_token != null:
			(caster_token as UnitToken).play_cast()
	if AOE_CONFIRM_MODES.has(tm) and not _area_sequence_active:
		_play_aoe_vfx(u, item, x, y)
	var kick_flight := 0.0
	match tm:
		"arrow-rain":
			state.cast_arrow_rain(u, item, {"x":x, "y":y})
		"self":
			state.cast_self_ability(u, item)
		"self-attack":
			state.cast_growth_attack(u, item)
		"cone-fire":
			state.cast_fire_cone(u, item, state.compute_aoe_area_tiles(u, item, {"x":x, "y":y}))
		"resurrect":
			var target = state.dead_unit_at(x, y)
			if target != null and target["team"] == u["team"]:
				_play_target_spell_vfx(u, target, item, "nature")
				state.cast_resurrect(u, target, item)
		"root":
			var target = state.unit_at(x, y)
			if target != null:
				_play_target_spell_vfx(u, target, item, "nature")
				state.cast_root_spell(u, target, item)
		"ally-clearpath":
			var target = state.unit_at(x, y)
			if target != null:
				var supply_kind := "nature" if "Cura" in String(item.get("name", "")) else "arcane"
				_play_target_spell_vfx(u, target, item, supply_kind)
				state.cast_supply_item(u, target, item)
		"reincarnation":
			var target = state.unit_at(x, y)
			if target != null:
				_play_target_spell_vfx(u, target, item, "nature")
				state.cast_reincarnation(u, target, item)
		"enemy":
			var target = state.unit_at(x, y)
			if target != null:
				_request_attack_confirmation(u, target, item)
				return
		"cure-aoe":
			var tiles = state.compute_aoe_area_tiles(u, item, {"x": x, "y": y})
			state.cast_antidote(u, item, tiles if tiles != null else [{"x": x, "y": y}])
		"heal-aoe":
			state.cast_heal_aoe(u, item, {"x": x, "y": y})
		"regen-aoe":
			state.cast_regen_aoe(u, item, {"x": x, "y": y})
		"mana-aoe":
			state.cast_mana_aoe(u, item, {"x": x, "y": y})
		"point-aoe":
			state.cast_fireball(u, item, {"x": x, "y": y})
		"line-aoe":
			state.cast_lightning(u, item, {"x": x, "y": y})
		"freeze-aoe":
			state.cast_freeze_aoe(u, item, {"x": x, "y": y})
		"trap":
			state.cast_trap(u, item, {"x": x, "y": y})
		"cone-poison":
			var tiles = state.compute_aoe_area_tiles(u, item, {"x": x, "y": y})
			state.cast_poison_cone(u, item, tiles if tiles != null else [])
		"cone-windstorm":
			var tiles = state.compute_aoe_area_tiles(u, item, {"x": x, "y": y})
			state.cast_windstorm(u, item, tiles if tiles != null else [])
		"cone-ice":
			var ice_tiles = state.compute_aoe_area_tiles(u, item, {"x": x, "y": y})
			state.cast_ice_cone(u, item, ice_tiles if ice_tiles != null else [])
		"creeping-line":
			state.cast_creeping_destruction(u, item, {"x": x, "y": y})
		"flame-creeping-line":
			state.cast_salamander_flame_wave(u, item, {"x": x, "y": y})
		"cardinal-blast":
			state.cast_throw_log(u, item, {"x": x, "y": y})
		"pierce-line":
			state.cast_pierce_shot(u, item, {"x": x, "y": y})
		"summon":
			# Toda magia de invocação (Fogo Vivo, Morcegos, e as do Lich mais
			# adiante) compartilha o mesmo targetMode "summon" — despacha pra
			# função de cast certa por `kind`, um único ponto de expansão em
			# vez de um targetMode novo por invocação. VFX genérico
			# (spawn_burst, mesma primitiva do impacto de Bola de Fogo) colorido
			# por SUMMON_VFX_KIND — cosmético, não afeta a regra.
			var summon_kind: String = item.get("kind", "")
			var summon_vfx_kind: String = SUMMON_VFX_KIND.get(summon_kind, "generic")
			if effects_layer != null:
				effects_layer.spawn_burst(board_view.tile_center(x, y), BoardView.TILE_SIZE * 0.55, _vfx_color_for_kind(summon_vfx_kind), 0.5, summon_vfx_kind)
			match summon_kind:
				"summon-living-fire":
					state.cast_summon_living_fire(u, item, {"x": x, "y": y})
				"summon-vampire-bat":
					state.cast_summon_vampire_bat(u, item, {"x": x, "y": y})
				"summon-skeleton":
					state.cast_summon_skeleton(u, item, {"x": x, "y": y})
				"summon-zombie":
					state.cast_summon_zombie(u, item, {"x": x, "y": y})
		"self-aoe":
			# Nuvem Venenosa (Slime Negro) e Decaimento (Lich) compartilham o
			# mesmo targetMode "self-aoe" (área centrada no próprio caster,
			# sem tile escolhido) — despacha por `kind`, mesmo idioma do
			# "summon" logo acima. Antes só cast_black_slime_poison era
			# chamada, e só pela IA — agora também funciona pelo clique do
			# jogador (ex.: time do Slime Negro sob controle humano no PVP).
			match item.get("kind", ""):
				"boss-poison":
					state.cast_black_slime_poison(u)
				"decay-pulse":
					if effects_layer != null:
						effects_layer.spawn_burst(board_view.tile_center(u["x"], u["y"]), BoardView.TILE_SIZE * (item.get("areaRadius", 1) + 0.5), _vfx_color_for_kind("poison"), 0.45, "poison")
					state.cast_decay_pulse(u, item)
		"inflict-wounds":
			state.cast_inflict_wounds(u, item, {"x": x, "y": y})
		"reanimate":
			var reanimate_target = state.dead_unit_at(x, y)
			if reanimate_target != null and reanimate_target["team"] == u["team"] and reanimate_target.get("undead", false):
				_play_target_spell_vfx(u, reanimate_target, item, "nature")
				state.cast_reanimate(u, reanimate_target, item)
		"trample":
			state.cast_trample(u, item, {"x": x, "y": y})
		"charge":
			var target = state.unit_at(x, y)
			if target != null:
				state.cast_charge(u, target, item)
		"slime-jump":
			state.cast_slime_jump(u, item, {"x": x, "y": y})
		"dismount":
			state.dismount_unit(u, {"x": x, "y": y})
		"dust-square":
			state.cast_dust_cloud(u, item)
		"heal-cross":
			state.cast_vestruz_heal(u, item)
		"vestruz-dash":
			var dash_from := board_view.tile_center(u["x"], u["y"])
			if state.cast_vestruz_dash(u, item, {"x": x, "y": y}) and effects_layer != null:
				var dash_to := board_view.tile_center(u["x"], u["y"])
				effects_layer.spawn_beam(dash_from, dash_to, Color(0.86, 0.72, 0.46), "beam", 0.4)
				effects_layer.spawn_burst(dash_from, BoardView.TILE_SIZE * 0.42, Color(0.82, 0.68, 0.44), 0.32, "physical")
				effects_layer.spawn_cloud(dash_to, Color(0.8, 0.66, 0.42))
				AudioEngine.play_sfx("whoosh", AudioEngine.pan_for_x(int(u["x"])))
		"iaijutsu":
			var iai_target = state.unit_at(x, y)
			if iai_target != null:
				var iai_origin := board_view.tile_center(u["x"], u["y"])
				if state.cast_iaijutsu(u, iai_target, item):
					_play_iaijutsu_vfx(u, iai_target, iai_origin)
		"crescent-arc":
			state.cast_crescent_slash(u, item, {"x": x, "y": y})
		"dragon-kick":
			# Voadora enquanto sobe/voa até o ponto escolhido e, logo depois
			# que o token pousa, a sequência de chute (ver "spriteAction" da
			# habilidade em data/spells.gd).
			var kick_token = unit_tokens.get(u["name"])
			if state.cast_dragon_kick(u, item, {"x": x, "y": y}) and kick_token != null:
				# Voo lento (DRAGON_KICK_FLIGHT_SECONDS) com a arte da voadora até o
				# ponto de pouso; o chute e o impacto só acontecem na chegada.
				kick_flight = DRAGON_KICK_FLIGHT_SECONDS
				var kick_strike := board_view.tile_center(x, y)
				(kick_token as UnitToken).play_flight(board_view.tile_center(u["x"], u["y"]), kick_flight)
				var kick_timer := get_tree().create_timer(kick_flight)
				kick_timer.timeout.connect(func():
					if not is_instance_valid(kick_token): return
					(kick_token as UnitToken).play_attack(0.34, String(item.get("spriteAction", "attack")))
					if effects_layer != null and is_instance_valid(effects_layer):
						effects_layer.spawn_slash(kick_strike, Color(1.0, 0.6, 0.25), "blunt")
						effects_layer.spawn_burst(kick_strike, BoardView.TILE_SIZE * 0.4, Color(1.0, 0.85, 0.5), 0.25, "physical")
						board_view.shake_camera_at(kick_strike, Vector2.RIGHT, 1.6, 0.16, true)
						AudioEngine.play_event("strong_hit", AudioEngine.pan_for_x(x))
				)
		_:
			pass
	var result_delay := 0.0 if _area_sequence_active else _projectile_duration_for_kind(item.get("projectileKind", "fireball")) if tm == "point-aoe" else (0.58 if tm == "freeze-aoe" else (0.16 if tm == "line-aoe" else 0.18))
	if kick_flight > 0.0: result_delay = kick_flight + 0.1
	_show_combat_changes(combat_before, log_start, result_delay, null, u, null, "ice" if tm == "freeze-aoe" else ("lightning" if tm == "line-aoe" else ""))
	mode = "idle"
	if kick_flight > 0.0:
		# Segura o fim do turno até o Monge pousar e chutar (o estado do jogo já
		# foi resolvido; só a apresentação leva ~2 s).
		_waiting_for_projectile_turn_end = true
		var kick_end := get_tree().create_timer(kick_flight + 0.45)
		kick_end.timeout.connect(func():
			_waiting_for_projectile_turn_end = false
			_after_action()
		)
		return
	_after_action()

## Corte Iaijutsu: rastro de vento do ponto de partida até onde o Samurai
## parou e, logo depois que o token chega, o corte (pose de ataque + arco de
## energia + impacto) no alvo. Só apresentação.
func _play_iaijutsu_vfx(u: Dictionary, target: Dictionary, origin: Vector2) -> void:
	if effects_layer == null: return
	var color := Color(0.75, 0.93, 1.0)
	var landing := board_view.tile_center(u["x"], u["y"])
	if origin.distance_to(landing) > 1.0:
		effects_layer.spawn_beam(origin, landing, color, "beam", 0.26)
		effects_layer.spawn_burst(origin, BoardView.TILE_SIZE * 0.32, color, 0.22, "wind")
	AudioEngine.play_sfx("whoosh", AudioEngine.pan_for_x(int(u["x"])))
	var strike_pos := board_view.tile_center(target["x"], target["y"])
	var token = unit_tokens.get(u["name"])
	var strike_timer := get_tree().create_timer(0.30)
	strike_timer.timeout.connect(func():
		if effects_layer == null or not is_instance_valid(effects_layer): return
		if token != null and is_instance_valid(token): (token as UnitToken).play_attack(UnitToken.ATTACK_ACTION_DURATION, "attack")
		effects_layer.spawn_slash(strike_pos, color, "slash")
		effects_layer.spawn_burst(strike_pos, BoardView.TILE_SIZE * 0.3, Color(1.0, 0.94, 0.7), 0.2, "physical")
		board_view.shake_camera_at(strike_pos, (strike_pos - landing).normalized(), 0.9, 0.12, false)
	)

func _is_mage_fireball(item: Dictionary) -> bool:
	return item.get("targetMode", "") == "point-aoe" and String(item.get("name", "")) == "Bola de Fogo"

func _resolve_mage_fireball(caster: Dictionary, item: Dictionary, x: int, y: int) -> void:
	if effects_layer == null:
		state.cast_fireball(caster, item, {"x": x, "y": y})
		mode = "idle"
		_after_action()
		return
	var target_tile := {"x": x, "y": y}
	var impact: Dictionary = state.resolve_obstructed_target(caster, target_tile)
	var combat_before := _capture_combat_snapshot()
	var log_start := state.event_log.size()
	var center_from := board_view.tile_center(caster["x"], caster["y"])
	var center_to := board_view.tile_center(impact["x"], impact["y"])
	var fire_area_tiles = state.compute_aoe_area_tiles(caster, item, target_tile)
	var fire_area_centers: Array = []
	if fire_area_tiles != null:
		for area_tile in fire_area_tiles:
			fire_area_centers.append(board_view.tile_center(area_tile["x"], area_tile["y"]))
	var direction := (center_to - center_from).normalized()
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	var muzzle := center_from + direction * 25.0 + Vector2(0, -9)
	mode = "fireball_vfx"
	_waiting_for_projectile_turn_end = true
	_close_action_menu()
	state.set_facing_towards(caster, target_tile)
	var caster_token = unit_tokens.get(caster["name"])
	if caster_token != null:
		(caster_token as UnitToken).play_cast()
		(caster_token as UnitToken).play_magic_body_light("fire", 1.25, 0.48)
		(caster_token as UnitToken).refresh()
	# O MP é pago no começo da conjuração; uma cópia com custo zero impede
	# finalize_action de cobrar novamente quando o projétil chegar.
	var resolved_item: Dictionary = item.duplicate(true)
	var mp_cost := int(item.get("mpCost", 0))
	caster["mp"] = maxi(int(caster.get("mp", 0)) - mp_cost, 0)
	resolved_item["mpCost"] = 0
	_sync_visuals()
	effects_layer.spawn_fireball_cast(center_from, direction)
	AudioEngine.play_sfx("fireballCastSpd", AudioEngine.pan_for_x(caster["x"]))
	var anticipation := get_tree().create_timer(0.24)
	anticipation.timeout.connect(func():
		if effects_layer == null or not is_instance_valid(effects_layer): return
		AudioEngine.play_sfx("fireballReleaseSpd", AudioEngine.pan_for_x(caster["x"]))
		effects_layer.spawn_fireball(muzzle, center_to, 330.0, func(impact_position: Vector2, impact_direction: Vector2):
			effects_layer.spawn_fireball_impact(impact_position, impact_direction)
			effects_layer.spawn_fireblast_area(fire_area_centers, impact_position)
			board_view.shake_camera_at(impact_position, impact_direction, 1.85, 0.13, false)
			# ETAPA 16 — Signature Ability do Mago (Bola de Fogo): o piloto já
			# tinha carga/liberação/impacto ricos; só faltava a reação de
			# ambiente (vegetação/água) que as outras magias de área já usam.
			effects_layer.emit_environment_reaction("heavy_impact", impact_position, impact_direction, "signature", "fire")
			AudioEngine.play_sfx("fireballImpactSpd", AudioEngine.pan_for_x(impact["x"]))
			# A única chamada ao motor de combate acontece na chegada: mantém
			# RNG/determinismo e sincroniza HP, popup e status com o impacto.
			state.cast_fireball(caster, resolved_item, target_tile)
			_show_combat_changes(combat_before, log_start, 0.055, null, caster, null, "fire")
			_waiting_for_projectile_turn_end = false
			mode = "idle"
			_after_action()
		, 1.0)
	)

func _capture_combat_snapshot() -> Dictionary:
	var snapshot := {}
	for unit in state.units:
		var effects: Array = []
		for effect in unit.get("statusEffects", []):
			effects.append(String(effect.get("type", "")))
		snapshot[unit["name"]] = {"hp": int(unit["hp"]), "effects": effects}
	return snapshot

func _show_combat_changes(before: Dictionary, log_start: int, delay: float = 0.0, fallback_target: Variant = null, primary_attacker: Variant = null, primary_target: Variant = null, impact_profile: String = "") -> void:
	if effects_layer == null:
		return
	var recent_log := "\n".join(state.event_log.slice(log_start))
	var counter_happened := _combat_has_counter(log_start) and primary_attacker != null and primary_target != null
	# Pedido do usuário: o revide deve ficar claramente separado do ataque
	# original, não emendado nele — espera o golpe principal (incluindo a
	# reação de acerto, ~HIT_ACTION_DURATION) terminar de verdade antes de
	# começar, e ganha um popup de texto próprio pra não passar despercebido.
	var counter_start_delay := delay + 0.55
	if counter_happened:
		var counter_center := board_view.tile_center(primary_target["x"], primary_target["y"])
		var attacked_center := board_view.tile_center(primary_attacker["x"], primary_attacker["y"])
		effects_layer.spawn_combat_popup(counter_center, "CONTRA-ATAQUE!", "counter", counter_start_delay, 0)
		var counter_timer := get_tree().create_timer(counter_start_delay)
		counter_timer.timeout.connect(func():
			var counter_token = unit_tokens.get(primary_target["name"])
			if counter_token != null: (counter_token as UnitToken).play_attack()
			effects_layer.spawn_cast_cue(counter_center, Color("ffd27a"), "physical")
			effects_layer.spawn_slash(attacked_center, Color("ffe0a0"), "slash")
			effects_layer.spawn_burst(attacked_center, BoardView.TILE_SIZE * 0.20, Color("ffbd72"), 0.18, "physical")
			AudioEngine.play_sfx("counter", AudioEngine.pan_for_x(primary_attacker["x"]))
		)
	var showed_any := false
	for unit in state.units:
		if not before.has(unit["name"]):
			continue
		var old: Dictionary = before[unit["name"]]
		var stack := 0
		var hp_change := int(unit["hp"]) - int(old["hp"])
		var center := board_view.tile_center(unit["x"], unit["y"])
		var unit_delay := counter_start_delay + 0.30 if counter_happened and unit["name"] == primary_attacker["name"] else delay
		if hp_change < 0:
			var critical := false
			for line in state.event_log.slice(log_start):
				if "CRÍTICO" in String(line) and unit["name"] in String(line):
					critical = true
					break
			var damage_kind := "crit" if critical else ("heavy" if abs(hp_change) >= 10 else "damage")
			var lower_log := recent_log.to_lower()
			if unit["name"].to_lower() in lower_log:
				if "veneno" in lower_log: damage_kind = "poison"
				elif "queimadura" in lower_log or "fogo" in lower_log: damage_kind = "fire"
				elif "sangramento" in lower_log: damage_kind = "bleed"
				elif "congelamento" in lower_log: damage_kind = "ice"
			var damage_text := "CRÍTICO! %d" % hp_change if critical else str(hp_change)
			effects_layer.spawn_combat_popup(center, damage_text, damage_kind, unit_delay, stack)
			var hit_token = unit_tokens.get(unit["name"])
			if hit_token != null and primary_attacker != null:
				var attack_origin := board_view.tile_center(primary_attacker["x"], primary_attacker["y"])
				var hit_timer := get_tree().create_timer(unit_delay)
				if impact_profile == "":
					hit_timer.timeout.connect((hit_token as UnitToken).play_weighted_hit_reaction.bind(attack_origin, critical))
				else:
					hit_timer.timeout.connect((hit_token as UnitToken).play_elemental_hit_reaction.bind(attack_origin, impact_profile, critical))
			stack += 1
			showed_any = true
		elif hp_change > 0:
			var heal_kind := "regen" if "regenera" in recent_log.to_lower() else "heal"
			effects_layer.spawn_combat_popup(center, "+%d" % hp_change, heal_kind, unit_delay, stack)
			stack += 1
			showed_any = true
		elif "causando 0 de dano" in recent_log.to_lower() and unit["name"].to_lower() in recent_log.to_lower() and unit.get("statusEffects", []).any(func(effect): return effect.get("type","") == "guarding"):
			effects_layer.spawn_combat_popup(center, "BLOCK", "block", unit_delay, stack)
			AudioEngine.play_event("parry", AudioEngine.pan_for_x(unit["x"]))
			stack += 1
			showed_any = true
		elif "esquiva do ataque de" in recent_log.to_lower() and unit["name"].to_lower() in recent_log.to_lower():
			effects_layer.spawn_combat_popup(center, "ESQUIVA!", "buff", unit_delay, stack)
			AudioEngine.play_event("wind", AudioEngine.pan_for_x(unit["x"]))
			stack += 1
			showed_any = true
		elif "está em foco e bloqueia" in recent_log.to_lower() and unit["name"].to_lower() in recent_log.to_lower():
			effects_layer.spawn_combat_popup(center, "FOCO", "block", unit_delay, stack)
			AudioEngine.play_event("parry", AudioEngine.pan_for_x(unit["x"]))
			stack += 1
			showed_any = true
		var old_effects: Array = old["effects"]
		for effect in unit.get("statusEffects", []):
			var type := String(effect.get("type", ""))
			if type != "" and not old_effects.has(type):
				effects_layer.spawn_combat_popup(center, _status_popup_name(type), _status_popup_kind(type), unit_delay + 0.12, stack)
				if type == "poison":
					var poison_timer := get_tree().create_timer(delay)
					poison_timer.timeout.connect(func():
						effects_layer.spawn_poison_application(center)
						AudioEngine.play_sfx("poison", AudioEngine.pan_for_x(unit["x"]))
					)
				elif type == "burned":
					var burned_unit: Dictionary = unit
					var burning_timer := get_tree().create_timer(unit_delay + 0.08)
					burning_timer.timeout.connect(func():
						var burned_token = unit_tokens.get(burned_unit["name"])
						if burned_token != null: (burned_token as UnitToken).play_burning_application()
						AudioEngine.play_sfx("burningSpd", AudioEngine.pan_for_x(burned_unit["x"]))
					)
				else:
					var status_event := _status_sfx_event(type)
					if status_event != "":
						var status_timer := get_tree().create_timer(unit_delay + 0.10)
						status_timer.timeout.connect(func(): AudioEngine.play_event(status_event, AudioEngine.pan_for_x(unit["x"])))
				stack += 1
				showed_any = true
		if unit["hp"] <= 0 and int(old["hp"]) > 0:
			effects_layer.spawn_combat_popup(center, "DERROTADO", "death", unit_delay + 0.16, stack)
			var death_reaction_timer := get_tree().create_timer(unit_delay + 0.12)
			death_reaction_timer.timeout.connect(func(): effects_layer.emit_environment_reaction("death", center, Vector2.DOWN, "medium"))
			var death_timer := get_tree().create_timer(unit_delay + 0.16)
			death_timer.timeout.connect(func(): AudioEngine.play_event("death", AudioEngine.pan_for_x(unit["x"])))
			showed_any = true
	if not showed_any and fallback_target != null:
		var missed := "errou" in recent_log.to_lower() or "não acerta" in recent_log.to_lower() or "só pode ser atingida" in recent_log.to_lower()
		if missed:
			effects_layer.spawn_combat_popup(board_view.tile_center(fallback_target["x"], fallback_target["y"]), "MISS", "miss", delay)

func _status_popup_name(type: String) -> String:
	match type:
		"poison": return "ENVENENADO!"
		"burned": return "QUEIMANDO!"
		"root": return "ENRAIZADO!"
		"paralyzed": return "PARALISADO!"
		"dazed": return "ATORDOADO!"
		"blinded": return "OFUSCADO!"
		"bleed": return "SANGRANDO!"
		"weakened": return "ENFRAQUECIDO!"
		"slowed": return "LENTIDÃO!"
		"regen", "regenBoost": return "REGENERAÇÃO!"
		"guarding": return "DEFENDENDO!"
		"focus": return "FOCO!"
		"heronStance": return "POSTURA DA GARÇA!"
		"guardBroken": return "GUARDA QUEBRADA!"
		"dustBlind": return "POEIRA NOS OLHOS!"
		"invisible": return "INVISÍVEL!"
		"fury": return "FÚRIA!"
		_: return type.to_upper() + "!"

func _status_popup_kind(type: String) -> String:
	match type:
		"burned": return "burned"
		"poison": return "poison"
		"paralyzed": return "paralyzed"
		"dazed": return "dazed"
		"bleed": return "bleed"
		"root": return "root"
		"slowed": return "ice"
		"guarding", "focus": return "block"
		"regen", "regenBoost": return "regen"
		"fury", "invisible", "evasive", "swiftFeet", "heronStance": return "buff"
		_: return "status"

func _status_sfx_event(type: String) -> String:
	match type:
		"paralyzed", "dazed", "blinded", "weakened", "slowed", "guardBroken", "dustBlind": return "debuff"
		"root": return "nature"
		"guarding", "focus": return "parry"
		"regen", "regenBoost": return "heal"
		"fury": return "charge"
		"invisible", "evasive", "heronStance": return "wind"
		_: return ""

func _on_end_turn_pressed() -> void:
	if _waiting_for_projectile_turn_end or _ai_sequence_running: return
	if state.battle_ended or state.current_actor == null or not _team_is_human(state.current_actor["team"]):
		return
	_close_action_menu()
	mode = "idle"
	_clear_aoe_preview()
	_close_confirm_panel()
	_request_end_current_turn()

func _request_end_current_turn() -> void:
	if _waiting_for_projectile_turn_end or _ai_sequence_running: return
	if state.current_actor == null: return
	_end_current_turn()

func _on_music_mute_pressed() -> void:
	_music_muted = not _music_muted
	AudioEngine.set_music_muted(_music_muted)
	_music_mute_button.text = "🔇 Música" if _music_muted else "🔊 Música"

## Depois de uma ação do jogador: se a batalha acabou, ou se a unidade não
## tem mais nada pra fazer neste turno (moveu/está presa E já agiu, ou
## morreu), encerra o turno sozinho — mesma regra de checkEndCurrentTurn no
## JS original. Senão, só recalcula o que ainda pode ser feito.
func _after_action() -> void:
	if _area_sequence_active:
		_sync_visuals()
		return
	mode = "idle"
	_clear_aoe_preview()
	if state.check_battle_outcome():
		reachable_tiles = []
		attackable_units = []
		attack_range_tiles = []
		spell_tiles = []
		_sync_visuals()
		return
	var u: Dictionary = state.current_actor
	var moved_or_cannot_move: bool = u.get("hasMoved", false) or state.is_rooted(u)
	if u["hp"] <= 0 or (moved_or_cannot_move and u.get("hasActed", false)):
		_end_current_turn()
	else:
		_compute_current_targets()
		_sync_visuals()

## Deixa a IA jogar sozinha enquanto o turno for de um time controlado por
## IA, parando assim que sobrar um turno de time humano (ou a batalha
## acabar) — cobre os dois lados, então também é o que faz a IA assumir na
## hora quando um time vira IA pelo botão da HUD (ver _on_toggle_control_pressed).
func _run_ai_until_player_turn() -> void:
	if battle_presentation != null and battle_presentation.is_blocking_input():
		return
	if _ai_sequence_running:
		return
	_ai_sequence_running = true
	var run_id := _ai_sequence_id
	while not state.battle_ended and state.current_actor != null and not _team_is_human(state.current_actor["team"]):
		# Mostra cada inimigo como ator atual antes de resolver qualquer coisa.
		# No protótipo anterior o while consumia todos os turnos no mesmo frame,
		# impedindo acompanhar a fila, HP e popups entre um inimigo e outro.
		mode = "idle"
		_compute_current_targets()
		_sync_visuals()
		# ETAPA 17 — "entrar em ação": pequeno pulso de postura no início do
		# turno do inimigo, dentro da MESMA janela de pausa que já existia
		# (AI_TURN_INTRO_DELAY não muda), então o ritmo do turno não muda.
		if state.current_actor != null:
			enemy_visual_behavior.on_turn_start(unit_tokens.get(state.current_actor["name"]))
		await _wait_for_ai_presentation(AI_TURN_INTRO_DELAY)
		if run_id != _ai_sequence_id:
			return
		if state.battle_ended or state.current_actor == null or _team_is_human(state.current_actor["team"]):
			break
		var combat_before := _capture_combat_snapshot()
		var log_start := state.event_log.size()
		var acting_unit: Dictionary = state.current_actor
		var origin := Vector2i(acting_unit["x"], acting_unit["y"])
		state.last_action_vfx = {}
		state.enemy_act(acting_unit)
		var action_vfx: Dictionary = state.last_action_vfx.duplicate(true)
		# GameState já resolveu a ação inteira (move + ataque) de forma síncrona
		# aqui em cima — só a ORDEM de apresentação visual muda a seguir: move
		# primeiro, pequena pausa, depois a pose de ataque (pedido do usuário,
		# pra dar pra acompanhar quem andou e quem atacou em vez de tudo junto).
		_play_new_tower_trap_effects()
		var acting_token = unit_tokens.get(acting_unit["name"])
		if origin != Vector2i(acting_unit["x"], acting_unit["y"]):
			var ai_path: Array = state.reconstruct_path(acting_unit["x"], acting_unit["y"]).duplicate(true)
			if acting_token != null: (acting_token as UnitToken).animate_path(ai_path, AI_MOVE_SPEED_SCALE)
			_play_water_path_vfx(ai_path, AI_MOVE_SPEED_SCALE)
			await _wait_for_ai_presentation(maxf(0.15, ai_path.size() * 0.15) * AI_MOVE_SPEED_SCALE)
			if run_id != _ai_sequence_id:
				return
		if acting_unit.get("hasActed", false):
			await _wait_for_ai_presentation(AI_ATTACK_PAUSE)
			if run_id != _ai_sequence_id:
				return
			if action_vfx.has("tiles"):
				var centers: Array = []
				for tile in action_vfx["tiles"]: centers.append(board_view.tile_center(tile["x"], tile["y"]))
				var visual_item: Dictionary = action_vfx.get("item", {})
				var target_tile: Dictionary = action_vfx.get("target", acting_unit)
				var sequence := effects_layer.spawn_area_sequence(visual_item, centers, board_view.tile_center(acting_unit["x"], acting_unit["y"]), board_view.tile_center(target_tile["x"], target_tile["y"]), BoardView.TILE_SIZE, action_vfx.get("rainFire", false))
				if acting_token != null: acting_token.play_cast()
				await _wait_for_ai_presentation(sequence.impact_time)
				if run_id != _ai_sequence_id: return
				AudioEngine.play_sfx(visual_item.get("sfx", "arcane"), AudioEngine.pan_for_x(acting_unit["x"]))
				_show_combat_changes(combat_before, log_start, 0.0)
				_sync_visuals()
				await _wait_for_ai_presentation(sequence.duration - sequence.impact_time)
				if run_id != _ai_sequence_id: return
			else:
				_play_recorded_enemy_action_vfx(action_vfx, acting_token)
		if not action_vfx.has("tiles"): _show_combat_changes(combat_before, log_start, 0.18)
		# ETAPA 17 — reação curta e limitada de aliados vivos e próximos a
		# quem morreu nesta ação (regra: nunca todos ao mesmo tempo, ver
		# EnemyVisualBehaviorController.on_ally_died). Detecta só comparando
		# o snapshot de antes com o HP atual, não recalcula nada da IA.
		for unit_name in combat_before:
			if int(combat_before[unit_name]["hp"]) <= 0:
				continue
			var maybe_dead = state.units.filter(func(candidate): return candidate["name"] == unit_name)
			if maybe_dead.is_empty() or int(maybe_dead[0]["hp"]) > 0:
				continue
			enemy_visual_behavior.on_ally_died(state.units, maybe_dead[0], unit_tokens)
		_sync_visuals()
		await _wait_for_ai_presentation(AI_TURN_RESULT_DELAY)
		if run_id != _ai_sequence_id:
			return
	_ai_sequence_running = false
	# Sininho de início de turno (equivalente a playSfx("turnStart") em
	# beginTurnFor no JS) — só pro turno humano, já que aqui é a única hora
	# que o áudio importa pra dar feedback ("sua vez"); o JS toca em TODO
	# turno (herói ou IA), simplificação deliberada.
	if not state.battle_ended and state.current_actor != null and _team_is_human(state.current_actor["team"]):
		AudioEngine.play_sfx("turnStart")
	_compute_current_targets()
	_sync_visuals()

## ETAPA 17 — despacha o que GameState já registrou em last_action_vfx pro
## presenter certo. "weapon-attack" (ver perform_attack/
## perform_ranged_attack_with_obstruction) reaproveita _play_attack_vfx, a
## MESMA apresentação rica que os heróis já usam (lunge pesado, projétil,
## câmera, crítico) — a IA nunca tinha esse tratamento antes, só a pose
## genérica play_attack(). Os kinds de fogo continuam no presenter que já
## existia.
func _play_recorded_enemy_action_vfx(event: Dictionary, acting_token: UnitToken) -> void:
	if event.get("kind", "") == "weapon-attack":
		var caster: Dictionary = event.get("caster", {})
		var target_tile: Dictionary = event.get("target", {})
		if caster.is_empty() or target_tile.is_empty():
			return
		_play_attack_vfx(caster, target_tile, event.get("item", {}), bool(event.get("hit", true)), "", Callable(), bool(event.get("critical", false)))
		return
	if acting_token != null: acting_token.play_attack()
	_play_recorded_enemy_fire_vfx(event)

func _play_recorded_enemy_fire_vfx(event: Dictionary) -> void:
	if event.is_empty() or effects_layer == null:
		return
	var caster: Dictionary = event.get("caster", {})
	if caster.is_empty(): return
	var origin := board_view.tile_center(int(caster["x"]), int(caster["y"]))
	var facing: Dictionary = caster.get("facing", {"dx":0,"dy":1})
	effects_layer.spawn_fireball_cast(origin, Vector2(facing.get("dx", 0), facing.get("dy", 1)))
	if event.get("kind", "") == "flame-wave":
		var target: Dictionary = event.get("target", {})
		if not target.is_empty(): _play_aoe_vfx(caster, event.get("item", {}), int(target["x"]), int(target["y"]))
	elif event.get("kind", "") == "fire-strike":
		var target: Dictionary = event.get("target", {})
		if not target.is_empty():
			var impact := board_view.tile_center(int(target["x"]), int(target["y"]))
			effects_layer.spawn_fire_weapon_launch(origin, (impact - origin).normalized(), "fire-arrow")
			effects_layer.spawn_fire_arrow_impact(impact)
	else:
		var centers: Array = []
		for tile in event.get("tiles", []): centers.append(board_view.tile_center(int(tile["x"]), int(tile["y"])))
		effects_layer.spawn_fireblast_area(centers, origin)
	AudioEngine.play_sfx("fire", AudioEngine.pan_for_x(int(caster["x"])))

## DESFILADEIRO — apresentação do vento gelado (GameState.
## maybe_trigger_desfiladeiro_wind já aplicou dano/status de forma síncrona;
## isto é só o "momento" visual pedido pelo usuário: pedido explícito pra
## ficar mais lento e mais claro (~5s de pausa cinemática em vez dos 3s de
## antes, reaproveitando BattlePresentationController.present_event — mesmo
## popup com letterbox já usado por reforços/eventos de campanha), mais um
## tremor de câmera curto (mesmo shake_camera já usado em impactos) e um
## overlay de gelo/vento na tela inteira (_play_icy_wind_screen_effect) pra
## deixar claro o que está acontecendo. Chamada sem `await` pelo call site
## (_sync_visuals), então nunca bloqueia turn order/CT/AI.
const DESFILADEIRO_WIND_EVENT_HOLD := 5.0

func _present_icy_wind_event(event: Dictionary) -> void:
	if battle_presentation == null:
		return
	var hit_count: int = (event.get("hit", []) as Array).size()
	var text := ("Uma rajada congelante varre o desfiladeiro — %d unidade(s) atingida(s)!" % hit_count) if hit_count > 0 else "Uma rajada congelante varre o desfiladeiro, mas ninguém é atingido."
	if board_view != null:
		board_view.shake_camera(Vector2.RIGHT, 0.6, 0.35, false)
	_play_icy_wind_screen_effect(DESFILADEIRO_WIND_EVENT_HOLD)
	await battle_presentation.present_event("VENTO GELADO", text, [], true, DESFILADEIRO_WIND_EVENT_HOLD)

## Overlay de tela inteira (tingimento azulado + rajadas diagonais brancas
## cruzando a tela) — CanvasLayer temporário próprio, abaixo do letterbox/
## card de texto (layer 80 em battle_presentation_controller.gd) pra não
## tapar a mensagem. Só visual, não lê nem altera nenhum estado de jogo;
## se autodestrói (`queue_free`) ao fim do fade-out.
func _play_icy_wind_screen_effect(duration: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 75
	add_child(layer)
	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.68, 0.86, 1.0, 0.0)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tint)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var streaks: Array[ColorRect] = []
	for i in 5:
		var streak := ColorRect.new()
		streak.color = Color(1, 1, 1, 0.0)
		streak.size = Vector2(220.0 + randf() * 80.0, 3.0)
		streak.rotation = deg_to_rad(-16)
		streak.position = Vector2(-260.0, randf() * viewport_size.y)
		streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(streak)
		streaks.append(streak)
	var tween := create_tween()
	tween.tween_property(tint, "color:a", 0.14, 0.6)
	for i in streaks.size():
		var streak: ColorRect = streaks[i]
		var streak_tween := create_tween()
		streak_tween.tween_property(streak, "color:a", 0.5, 0.2).set_delay(i * 0.15)
		streak_tween.tween_property(streak, "position:x", viewport_size.x + 260.0, duration - 0.3).set_trans(Tween.TRANS_LINEAR)
	await get_tree().create_timer(maxf(duration - 0.5, 0.0)).timeout
	var fade_out := create_tween()
	fade_out.tween_property(tint, "color:a", 0.0, 0.5)
	for streak in streaks:
		fade_out.parallel().tween_property(streak, "color:a", 0.0, 0.5)
	await fade_out.finished
	layer.queue_free()

func _wait_for_ai_presentation(seconds: float) -> void:
	# Testes headless continuam instantâneos; na janela do jogo a pausa deixa
	# cada turno inimigo, seus popups e mudanças no tabuleiro observáveis.
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().create_timer(seconds).timeout

func _on_battle_intro_finished() -> void:
	if state == null or state.battle_ended: return
	_compute_current_targets()
	_sync_visuals()
	_run_ai_until_player_turn()

func _on_battle_outcome_presentation_finished(victory: bool) -> void:
	if victory:
		_start_victory_phase_advance()
	else:
		_show_defeat_screen_now()

func _compute_current_targets() -> void:
	reachable_tiles = []
	attackable_units = []
	attack_range_tiles = []
	spell_tiles = []
	if state.battle_ended or state.current_actor == null:
		return
	var u: Dictionary = state.current_actor
	if not _team_is_human(u["team"]):
		return
	if not u.get("hasMoved", false) and not state.is_rooted(u):
		reachable_tiles = state.compute_reachable(u)
		# Montar = mover para o quadrado da Vestruz adjacente: ele aparece como
		# destino de movimento e o clique pede confirmação (ver _handle_tile_click).
		for mount_candidate in state.mount_candidates(u):
			reachable_tiles.append({"x": mount_candidate["x"], "y": mount_candidate["y"]})
	if not u.get("hasActed", false):
		for o in state.opposing_team_of(u):
			if o["hp"] <= 0:
				continue
			var distance: int = state.manhattan(u, o)
			if state.pick_weapon_for_distance(state.get_attack_options(u), distance, o) != null:
				attackable_units.append(o)

func _sync_visuals() -> void:
	# Roteia toda unidade que zerou o HP desde a última sincronização: bichos
	# do SPD viram alma na hora (GameState.IMMEDIATE_SOUL_SPRITE_KEYS), o
	# resto vira cadáver ressuscitável de 3 rodadas — precisa rodar ANTES do
	# refresh() dos tokens, que só lê o resultado (turnsSinceDeath ou não).
	for unit_data in state.units:
		state.finalize_death_if_needed(unit_data)
	# Criaturas ambientais podem surgir após o turno 15; materialize seus
	# tokens sem reconstruir a cena ou interromper a fila atual.
	var reinforcement_tokens: Array = []
	for unit_data in state.units:
		if unit_tokens.has(unit_data["name"]): continue
		var new_token := UnitToken.new()
		board_view.add_child(new_token)
		new_token.z_index = 10
		new_token.setup(unit_data)
		unit_tokens[unit_data["name"]] = new_token
		reinforcement_tokens.append(new_token)
	if not reinforcement_tokens.is_empty() and battle_presentation != null and battle_presentation.phase == BattlePresentationController.Phase.COMBAT:
		battle_presentation.present_reinforcements(reinforcement_tokens)
	for token_name in unit_tokens.keys().duplicate():
		if not state.units.any(func(unit_data): return unit_data["name"] == token_name):
			(unit_tokens[token_name] as UnitToken).queue_free()
			unit_tokens.erase(token_name)
	for token in unit_tokens.values():
		(token as UnitToken).refresh()
	if not state.bone_explosion_events.is_empty():
		for event in state.bone_explosion_events:
			var center := board_view.tile_center(int(event["x"]), int(event["y"]))
			effects_layer.spawn_bone_explosion(center)
			AudioEngine.play_sfx("impact", AudioEngine.pan_for_x(int(event["x"])))
		state.bone_explosion_events.clear()
	if not state.bard_song_vfx_events.is_empty():
		var song_events: Array = state.bard_song_vfx_events.duplicate(true)
		state.bard_song_vfx_events.clear()
		for event in song_events:
			var affected_token = unit_tokens.get(event.get("targetName", ""))
			if affected_token != null:
				(affected_token as UnitToken).spawn_bard_song_notes(event.get("songKind", ""))
	if not state.bard_song_feedback_events.is_empty():
		var feedback_events: Array = state.bard_song_feedback_events.duplicate(true)
		state.bard_song_feedback_events.clear()
		for event in feedback_events:
			if event.get("success", false): continue
			var failed_token = unit_tokens.get(event.get("targetName", ""))
			if failed_token != null:
				(failed_token as UnitToken).spawn_bard_song_failure(event.get("songKind", ""))
				var failed_unit: Dictionary = (failed_token as UnitToken).unit
				effects_layer.spawn_combat_popup(board_view.tile_center(failed_unit["x"], failed_unit["y"]), "FALHOU", "miss", 0.0, 1)
	# DESFILADEIRO — vento gelado (ver GameState.maybe_trigger_desfiladeiro_
	# wind): mesmo padrão de fila de eventos "puramente visual" já usado
	# acima por bone_explosion_events/bard_song_vfx_events. Os efeitos
	# (dano/status) já foram aplicados de forma síncrona por GameState — aqui
	# só entra a apresentação (pausa/rajada), sem afetar turn order/CT/AI.
	if not state.desfiladeiro_wind_events.is_empty():
		var wind_events: Array = state.desfiladeiro_wind_events.duplicate(true)
		state.desfiladeiro_wind_events.clear()
		for event in wind_events:
			_present_icy_wind_event(event)
	board_view.set_highlights(reachable_tiles, attackable_units, spell_tiles, aoe_preview_tiles, attack_range_tiles)
	if combat_feedback != null:
		if not aoe_preview_tiles.is_empty():
			var preview_targets: Array = []
			for unit in state.alive_units():
				if state.footprint_tiles(unit).any(func(tile): return _tile_in_list(aoe_preview_tiles, tile["x"], tile["y"])): preview_targets.append(unit)
			combat_feedback.set_targets(preview_targets)
		elif mode == "idle": combat_feedback.clear_targets()
	_refresh_hud()
	if not state.cage_release_events.is_empty():
		var released_events: Array = state.cage_release_events.duplicate()
		state.cage_release_events.clear()
		for released in released_events:
			_handle_cage_release(released)

## Reação de UI (popup + som) a uma libertação registrada por
## GameState._release_caged_mage() — lido e limpo daqui a cada
## _sync_visuals() pra não acoplar áudio/efeitos ao estado puro.
func _handle_cage_release(released: Dictionary) -> void:
	if released.get("bardoUnlocked", false):
		bardo_unlocked = true
		_save_campaign_progress()
	_show_scenario_banner("🔓 %s" % released.get("message", "Estou livre!"))
	AudioEngine.play_sfx("cageOpen", AudioEngine.pan_for_x(int(released.get("x", 0))))
	var center := board_view.tile_center(int(released.get("x", 0)), int(released.get("y", 0)))
	effects_layer.spawn_combat_popup(center, "Estou livre!", "heal", 0.0, 0)
	if battle_presentation != null:
		var released_token = unit_tokens.get(released.get("name", ""))
		battle_presentation.present_event("RESGATE", str(released.get("message", "Estou livre!")), [released_token] if released_token != null else [], false)

## Descarta a prévia de área em andamento (ver AOE_CONFIRM_MODES) — chamado
## sempre que a mira muda de alvo/item/turno, igual ao JS zerando
## aoePreviewTarget/aoePreviewTiles nos mesmos pontos.
func _clear_aoe_preview() -> void:
	aoe_preview_target = null
	aoe_preview_tiles = []

func _close_confirm_panel() -> void:
	_confirm_panel.visible = false
	pending_confirm_action = Callable()
	_confirm_ok_button.text = "Confirmar"
	_confirm_cancel_button.text = "Cancelar"

func _on_confirm_ok_pressed() -> void:
	var action := pending_confirm_action
	if not action.is_valid():
		return
	_close_confirm_panel()
	action.call()

## Primeiro clique num alvo válido de magia de área acende a prévia da área
## real de efeito; um segundo clique no MESMO alvo abre a confirmação —
## mesma regra de "isConfirming" do onTileClick original.
func _handle_aoe_tile_click(u: Dictionary, x: int, y: int) -> void:
	var is_confirming: bool = aoe_preview_target != null and aoe_preview_target["x"] == x and aoe_preview_target["y"] == y
	if is_confirming:
		_open_aoe_confirmation(u, pending_item, x, y)
		return
	var area_tiles = state.compute_aoe_area_tiles(u, pending_item, {"x": x, "y": y})
	aoe_preview_target = {"x": x, "y": y}
	aoe_preview_tiles = area_tiles if area_tiles != null else []
	_sync_visuals()

## Equivalente a openAoeConfirmation no JS: lista quem está de fato dentro
## da área antes de lançar a magia de verdade. Confirmar chama _resolve_spell
## (mesma tabela de cast* que o clique direto já usava).
func _open_aoe_confirmation(u: Dictionary, item: Dictionary, x: int, y: int) -> void:
	var info := _describe_aoe_outcome(u, item, x, y)
	_confirm_title_label.text = "%s %s" % [item.get("icon", ""), item.get("name", "")]
	_confirm_body_label.text = "\n".join(info)
	_confirm_ok_button.text = "Confirmar"
	_confirm_cancel_button.text = "Cancelar"
	_confirm_panel_set_accent(_attack_accent_color(item))
	_position_confirm_panel_near_unit(u)
	pending_confirm_action = func():
		_clear_aoe_preview()
		_resolve_spell(u, item, x, y)

## Monta as linhas de texto do popup de confirmação (equivalente ao corpo de
## openAoeConfirmation no JS): nota de efeito + 1 linha por alvo atingido,
## ou aviso de bloqueio/área ocupada pras magias sem alvo (Armadilha).
func _describe_aoe_outcome(u: Dictionary, item: Dictionary, x: int, y: int) -> Array:
	var mode: String = item.get("targetMode", "")
	var target_tile := {"x": x, "y": y}
	var area_tiles: Array = aoe_preview_tiles
	var lines: Array = []

	if mode == "point-aoe":
		var impact = target_tile if item.get("ignoresUnitObstruction", false) else state.resolve_obstructed_target(u, target_tile)
		if impact["x"] != x or impact["y"] != y:
			lines.append("Algo bloqueia o caminho — a explosão vai acontecer em (%d, %d) em vez do alvo escolhido!" % [impact["x"], impact["y"]])
		lines.append("Quadrado de efeito: (%d, %d), raio %d" % [impact["x"], impact["y"], item.get("areaRadius", 0)])
	elif mode == "line-aoe":
		var length: int = maxi(absi(x - u["x"]), absi(y - u["y"]))
		lines.append("Linha de %d quadrado(s) na direção escolhida" % length)
	elif mode == "creeping-line" or mode == "flame-creeping-line":
		lines.append("Linha até a borda do tabuleiro (%d quadrado(s)) na direção escolhida" % area_tiles.size())
	elif mode == "cardinal-blast":
		lines.append("Faixa de %d quadrado(s) (%dx%d) na direção escolhida" % [area_tiles.size(), item.get("bandLength", 0), item.get("bandWidth", 0)])
	elif mode == "cone-poison" or mode == "cone-windstorm" or mode == "cone-ice":
		lines.append("Cone com %d quadrado(s) de largura crescente" % area_tiles.size())
	elif mode == "cure-aoe" or mode == "heal-aoe" or mode == "regen-aoe" or mode == "mana-aoe" or mode == "freeze-aoe" or mode == "inflict-wounds":
		lines.append("Área de raio %d" % item.get("areaRadius", 0))
	elif mode == "pierce-line":
		lines.append("Linha reta fixa de %d quadrado(s) (perfura todo mundo no caminho)" % item.get("maxRange", 0))
	elif mode == "trap":
		lines.append("Área de raio %d — fica invisível até um inimigo passar por ela" % item.get("areaRadius", 0))
	elif mode == "crescent-arc":
		lines.append("Arco de %d quadrado(s) à frente — atinge só inimigos (até 3)" % area_tiles.size())
	elif mode == "dust-square":
		lines.append("Poeira em área 3x3 (%d quadrados) ao redor de %s — só inimigos" % [area_tiles.size(), u["name"]])
	elif mode == "heal-cross":
		lines.append("Cura em cruz (%d quadrados: o dela + 4 cardeais, sem diagonais) — só aliados" % area_tiles.size())

	if mode == "trap":
		var blockers: Array = []
		for t in area_tiles:
			var b = state.unit_at(t["x"], t["y"])
			if b != null:
				blockers.append(b)
		if blockers.is_empty():
			lines.append("Área livre — pronta para ser instalada.")
		else:
			var names: Array = []
			for b in blockers:
				names.append(str(b["name"]))
			lines.append("Não é possível instalar: %s está(ão) na área." % ", ".join(names))
		return lines

	var targets: Array = []
	for t in area_tiles:
		var target_unit = state.unit_at(t["x"], t["y"])
		if target_unit != null and not ((mode == "crescent-arc" or mode == "dust-square") and target_unit["team"] == u["team"]) and not (mode == "heal-cross" and target_unit["team"] != u["team"]):
			targets.append(target_unit)
	if mode == "heal-cross" and u.get("riderName", "") != "":
		var carried_rider = state.rider_of(u)
		if carried_rider != null and not targets.has(carried_rider): targets.append(carried_rider)
	if targets.is_empty():
		lines.append("Nenhum alvo dentro da área.")
		return lines

	for target_unit in targets:
		var team_note: String = "aliado" if target_unit["team"] == u["team"] else "inimigo"
		if mode == "cure-aoe":
			lines.append("%s (%s): remove veneno/paralisia na hora" % [target_unit["name"], team_note])
		elif mode == "heal-aoe":
			lines.append("%s (%s): cura %d-%d de vida" % [target_unit["name"], team_note, item.get("healMin", 0), item.get("healMax", 0)])
		elif mode == "regen-aoe":
			var regen_pct: int = roundi(float(item.get("hitChance", 0.0)) * 100.0)
			lines.append("%s (%s): %d%% de chance — se acertar, regenera %d-%d de vida por turno, por %d turno(s)" % [target_unit["name"], team_note, regen_pct, item.get("healMin", 0), item.get("healMax", 0), item.get("regenTurns", 0)])
		elif mode == "heal-cross":
			lines.append("%s (aliado): cura %d-%d de vida" % [target_unit["name"], item.get("healMin", 0), item.get("healMax", 0)])
		elif mode == "dust-square":
			lines.append("%s (inimigo): -%d pontos percentuais de acerto por 1 turno" % [target_unit["name"], roundi(float(item.get("accuracyDown", 0.2)) * 100.0)])
		elif mode == "mana-aoe":
			if target_unit.has("maxMp"):
				lines.append("%s (%s): restaura %d-%d de mana" % [target_unit["name"], team_note, item.get("manaMin", 0), item.get("manaMax", 0)])
			else:
				lines.append("%s (%s): não usa mana, não é afetado(a)" % [target_unit["name"], team_note])
		else:
			var chance = state.get_effective_hit_chance(u, target_unit, item, state.manhattan(u, target_unit))
			var hit_text: String = "%d%%" % roundi(float(chance) * 100.0) if chance != null else "—"
			var damage_text: String = "%d-%d" % [item.get("damageMin", 0), item.get("damageMax", 0)]
			if mode == "cone-poison":
				lines.append("%s (%s): %s de acerto — se acertar, envenena por %d turno(s)" % [target_unit["name"], team_note, hit_text, item.get("turns", 0)])
			elif mode == "freeze-aoe":
				lines.append("%s (%s): %s de acerto — se acertar, congela por 1 turno (1-3 de dano)" % [target_unit["name"], team_note, hit_text])
			elif mode == "cone-windstorm":
				lines.append("%s (%s): %s de acerto, dano %s — se acertar, tira 15 de CT e empurra 2-3 quadrados" % [target_unit["name"], team_note, hit_text, damage_text])
			elif mode == "cone-ice":
				lines.append("%s (%s): %s de acerto, dano %s — se acertar, agilidade -1 por 2 turnos" % [target_unit["name"], team_note, hit_text, damage_text])
			elif mode == "creeping-line":
				lines.append("%s (%s): perde 15 de CT e fica imóvel no próximo turno (sempre) — %s de acerto pra também causar %s de dano" % [target_unit["name"], team_note, hit_text, damage_text])
			else:
				lines.append("%s (%s): %s de acerto, dano %s" % [target_unit["name"], team_note, hit_text, damage_text])
	return lines

func _refresh_hud() -> void:
	_refresh_turn_queue()
	_turn_label.text = "Turno global: %d/%d" % [state.global_turn_count, state.max_global_turns()]
	if state.battle_ended:
		_status_label.text = "Batalha encerrada — veja o registro abaixo."
		_end_turn_button.disabled = true
		_show_end_screen()
	elif state.current_actor != null:
		var u: Dictionary = state.current_actor
		if combat_feedback != null: combat_feedback.transition_turn(u)
		if _team_is_human(u["team"]):
			if mode == "attack":
				_status_label.text = "%s: escolha um alvo (vermelho) pra %s, ou clique nela de novo pra cancelar." % [u["name"], pending_item.get("name", "")]
			elif mode == "spell":
				_status_label.text = "%s: escolha um tile (roxo) pra %s, ou clique nela de novo pra cancelar." % [u["name"], pending_item.get("name", "")]
			else:
				var song: Dictionary = u.get("activeBardSong", {})
				if not song.is_empty():
					_status_label.text = "🎵 %s canta %s (%d aplicação(ões) futura(s)); pode mover ou trocar de música, mas a Besta está bloqueada." % [u["name"], song["item"]["name"], song["applicationsLeft"]]
				else:
					_status_label.text = "Vez de %s — clique nela pra ver ações, tile azul move, vermelho ataca." % u["name"]
					var hud_mount = state.mount_of(u)
					if hud_mount != null:
						_status_label.text += "  🐦 %s: HP %d/%d  MP %d/%d" % [hud_mount["name"], hud_mount["hp"], hud_mount["maxHp"], hud_mount["mp"], hud_mount["maxMp"]]
		else:
			_status_label.text = ("Aguardando o adversário: vez de %s…" % u["name"]) if _online_mode else ("Vez de %s (IA)..." % u["name"])
		_end_turn_button.disabled = not _team_is_human(u["team"])
	var log_size: int = state.event_log.size()
	var start: int = maxi(0, log_size - 10)
	var lines: Array = state.event_log.slice(start, log_size)
	_log_label.text = "\n".join(lines) if not lines.is_empty() else "(sem eventos ainda)"

## Vitória/derrota decidida por state.battle_won (ver GameState.
## check_battle_outcome/check_global_turn_limit) — NUNCA pela última linha do
## log: finalize_death_if_needed pode logar "se desfaz numa alma" (bichos SPD
## da Torre/Horda) DEPOIS da mensagem de resultado, dentro do mesmo
## _sync_visuals() que chama esta função; ler só event_log[-1] detectava
## derrota por engano toda vez que o kill decisivo era um desses bichos —
## praticamente sempre na Horda, já que o elenco inteiro dela é assim.
## Derrota continua mostrando a tela com "Reiniciar Partida"; vitória não
## mostra mais essa tela — ver _start_victory_phase_advance.
func _show_end_screen() -> void:
	if _end_screen.visible or _phase_advance_pending:
		return
	if battle_presentation != null and not _is_running_under_gut():
		var survivors: Array = []
		var wanted_team := "player" if state.battle_won else "enemy"
		for unit_data in state.units:
			if unit_data.get("team", "") == wanted_team and unit_data.get("hp", 0) > 0:
				var token = unit_tokens.get(unit_data.get("name", ""))
				if token != null: survivors.append(token)
		battle_presentation.present_outcome(state.battle_won, survivors)
		return
	if state.battle_won:
		_start_victory_phase_advance()
		return
	_show_defeat_screen_now()

func _show_defeat_screen_now() -> void:
	_end_screen_title.text = "VOCÊ PERDEU!"
	_end_screen_title.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	# A apresentação de resultado esmaece TODA a HUD (20%) e este painel mora
	# na HUD: sem restaurar, o popup de opções aparecia transparente. Sólido.
	_end_screen.modulate = Color.WHITE
	_end_screen.visible = true
	AudioEngine.play_sfx("defeat")

## Vitória: sem opção de "Reiniciar Partida" — toca a fanfarra de comemoração
## (~3s, ver AudioEngine.play_sfx("victoryFanfare")) e, ao fim dela, encadeia
## a mesma animação de fade + reconstrução usada pelos botões CAMPO/HORDA/
## TORRE do topo (ver _switch_scenario) pra avançar automaticamente pra
## próxima fase (ScenarioManager.next_id — cíclico: Torre volta pro Campo).
## _wait_for_ai_presentation pula a espera real em testes headless (mesmo
## mecanismo já usado pro ritmo dos turnos de IA).
func _start_victory_phase_advance() -> void:
	_phase_advance_pending = true
	_show_scenario_banner("🏆 VITÓRIA! Avançando de fase...")
	AudioEngine.play_sfx("victoryFanfare")
	await _wait_for_ai_presentation(3.0)
	_phase_advance_pending = false
	_switch_scenario(scenario_manager.next_id())
