extends Node2D
class_name UnitToken

const VisualPolicy = preload("res://data/visual_policy.gd")

## Emitido quando animate_path() termina de verdade (fim do tween, não só
## "comecei a andar") — usado pelo CampaignDirector pra saber quando TODOS
## os heróis/monstros de uma leva de entrada/saída cinematográfica já
## chegaram, em vez de confiar num timer fixo.
signal walk_finished

class RpgResourceBar extends Control:
	var current_value := 0
	var maximum_value := 1
	var displayed_value := 0.0
	var lag_value := 0.0
	var main_color := Color.WHITE
	var top_color := Color.WHITE
	var _value_label: Label
	var _value_tween: Tween
	var _lag_tween: Tween

	func setup_bar(bar_size: Vector2, color: Color, light_color: Color, font_size: int) -> void:
		size = bar_size
		custom_minimum_size = bar_size
		main_color = color
		top_color = light_color
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_value_label = Label.new()
		_value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_value_label.add_theme_font_size_override("font_size", font_size)
		_value_label.add_theme_color_override("font_color", Color.WHITE)
		_value_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		_value_label.add_theme_constant_override("shadow_offset_x", 1)
		_value_label.add_theme_constant_override("shadow_offset_y", 1)
		_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_value_label)
		queue_redraw()

	func set_values(value: int, max_value: int) -> void:
		var first_value := maximum_value == 1 and current_value == 0 and displayed_value == 0.0
		var previous := displayed_value
		current_value = clampi(value, 0, maxi(0, max_value))
		maximum_value = maxi(1, max_value)
		if first_value or not is_inside_tree():
			displayed_value = float(current_value)
			lag_value = displayed_value
		else:
			if _value_tween != null and _value_tween.is_valid(): _value_tween.kill()
			if _lag_tween != null and _lag_tween.is_valid(): _lag_tween.kill()
			_value_tween = create_tween()
			_value_tween.tween_method(_set_displayed_value, previous, float(current_value), 0.18 if current_value < previous else 0.28).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			if current_value < previous:
				lag_value = maxf(lag_value, previous)
				_lag_tween = create_tween()
				_lag_tween.tween_interval(0.16)
				_lag_tween.tween_method(_set_lag_value, lag_value, float(current_value), 0.28).set_trans(Tween.TRANS_SINE)
			else:
				lag_value = float(current_value)
		if _value_label != null:
			_value_label.text = "%d / %d" % [current_value, maxi(0, max_value)]
		queue_redraw()

	func _set_displayed_value(value: float) -> void:
		displayed_value = value
		queue_redraw()

	func _set_lag_value(value: float) -> void:
		lag_value = value
		queue_redraw()

	func _draw() -> void:
		# Sombra externa curta, caixa vazia escura e borda clara de um pixel.
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color(0, 0, 0, 0.48)
		shadow.corner_radius_top_left = 3
		shadow.corner_radius_top_right = 3
		shadow.corner_radius_bottom_left = 3
		shadow.corner_radius_bottom_right = 3
		draw_style_box(shadow, Rect2(Vector2(1, 2), size))
		var background := StyleBoxFlat.new()
		background.bg_color = Color(0.035, 0.04, 0.055, 0.96)
		background.border_color = Color(0.72, 0.75, 0.80, 0.92)
		background.set_border_width_all(1)
		background.corner_radius_top_left = 3
		background.corner_radius_top_right = 3
		background.corner_radius_bottom_left = 3
		background.corner_radius_bottom_right = 3
		draw_style_box(background, Rect2(Vector2.ZERO, size))
		var ratio := clampf(displayed_value / float(maximum_value), 0.0, 1.0)
		var lag_ratio := clampf(lag_value / float(maximum_value), 0.0, 1.0)
		var lag_width: float = floorf((size.x - 4.0) * lag_ratio)
		if lag_width > 0.0 and lag_ratio > ratio:
			draw_rect(Rect2(Vector2(2, 2), Vector2(lag_width, size.y - 4)), Color("ffd27a", 0.78))
		var fill_width: float = floorf((size.x - 4.0) * ratio)
		if fill_width <= 0.0: return
		var fill_rect := Rect2(Vector2(2, 2), Vector2(fill_width, size.y - 4))
		draw_rect(fill_rect, main_color)
		# Faixa superior mais clara: gradiente discreto sem textura borrada.
		draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, maxf(1.0, fill_rect.size.y * 0.46))), top_color)
		draw_line(Vector2(3, size.y - 2), Vector2(1 + fill_width, size.y - 2), main_color.darkened(0.34), 1.0)

class WaterLegOverlay extends Node2D:
	var phase := 0.0
	func _process(delta: float) -> void:
		phase = fmod(phase + delta * 2.8, TAU)
		queue_redraw()
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(-25, 11), Vector2(25, 11), Vector2(23, 29), Vector2(-23, 29)]), Color(0.12, 0.42, 0.58, 0.62))
		draw_arc(Vector2(0, 14), 23.0 + sin(phase) * 2.0, PI, TAU, 24, Color(0.72, 0.94, 0.96, 0.72), 2.0, true)

## Representação visual de UMA unidade — lê o dicionário de estado (o mesmo
## formato de game.js: name/x/y/hp/maxHp/team/facing/spriteKey) e não decide
## nenhuma regra, só desenha. `refresh()` deve ser chamado depois de
## qualquer mudança de estado relevante (posição, HP, facing).

const DISPLAY_HEIGHT := 96.0
## _apply_texture escala cada frame só pela altura do PNG (DISPLAY_HEIGHT /
## texture.get_height()), assumindo que todo frame tem a mesma proporção de
## canvas. Os assets de heroes/enemies foram normalizados (canvas quadrado,
## mesmo tamanho), mas o CONTEÚDO não fica sempre do mesmo tamanho dentro
## desse canvas — poses de morte "deitadas" (Ladino/Fada/Guerreiro) ocupam bem
## menos altura de canvas que a pose de pé, então escalar só pela altura do
## PNG (igual pra todo frame) faz o cadáver renderizar bem menor na tela que o
## personagem de pé, mesmo com o mesmo scale_factor de canvas. Pedido do
## usuário: cadáveres "muito pequenos" comparados a andar/atacar/parado.
## `SPRITE_SCALE_OVERRIDE[caminho_completo] = multiplicador` corrige só esses
## quadros, aplicado em cima do auto-scale por altura — multiplicador escolhido
## pra igualar a ÁREA visual renderizada do cadáver à da pose de pé
## (idle/walk), mesmo cálculo do `frame_scale_files` de AnimalSpriteCatalog
## (ver data/animal_sprite_catalog.gd) usado pelos outros personagens.
const SPRITE_SCALE_OVERRIDE := {
	"res://assets/heroes/ladino/ladino_death_1.png": 1.52,
	"res://assets/enemies/fada/fada_death_1.png": 1.16,
	"res://assets/heroes/guerreiro/guerreiro_death_1.png": 1.13,
	"res://assets/heroes/guerreiro/guerreiro_death_2.png": 1.04,
}
const MOVE_DURATION := 0.22
const FLASH_DURATION := 0.09
const HIT_ACTION_DURATION := 0.58
const DEATH_ACTION_DURATION := 0.7
const ATTACK_ACTION_DURATION := 0.42
## Pedido do usuário: ataques mais lentos e com mais "peso". Multiplicadores
## aplicados em cima do timing por classe (ClassVisualProfiles) em vez de
## reescrever cada perfil individualmente — preserva a diferença relativa
## entre uma classe leve (Ladino) e uma pesada (Troll/Boss), só estica tudo
## proporcionalmente. Ver play_weighted_attack/play_weighted_hit_reaction.
const ATTACK_WEIGHT_SCALE := 1.45
const HIT_STOP_WEIGHT_SCALE := 1.8
## ETAPA 17 — abaixo desta fração de HP/maxHp, o combat idle fica levemente
## mais pesado (ver CharacterVisualController.update_pose). Puramente
## visual: nunca lido por dano/regras/IA.
const LOW_HP_VISUAL_RATIO := 0.3
const DUST_SCENE := preload("res://effects/dust.tscn")
const HIT_SPARK_SCENE := preload("res://effects/hit_spark.tscn")
const CHARACTER_VISUAL_CONTROLLER := preload("res://scenes/character_visual_controller.gd")
const PREMIUM_ANIMATION := preload("res://data/premium_animation_profiles.gd")

## Pedido do usuário: só o Guerreiro 2D (sprite) disponível por padrão.
## CharacterVisualFactory continua com o profile 3D registrado (pipeline e
## testes de test_character_3d_pipeline.gd inalterados) — só a exibição
## automática fica desligada aqui. set_use_3d_visual(true) ainda liga o 3D
## manualmente (ex.: warrior_ab_test em scenes/Main.tscn) se for religado.
@export var use_3d_visual := false
@export_range(0.45, 1.1, 0.01) var warrior_3d_scale := 0.72
## Screen-space offset for the 3D preview composite; keeps the feet on the tile.
@export var warrior_3d_screen_offset := Vector2(0, -33)

var unit: Dictionary
var _visual_root: Node2D
var _shadow: Polygon2D
var _weapon_fx: Node2D
var _status_fx_root: Node2D
var _overhead_fx: Node2D
var _ui_root: Node2D
var _animation_player: AnimationPlayer
var _sprite: Sprite2D
var _warrior_viewport: SubViewport
var _warrior_viewport_sprite: Sprite2D
var _warrior_3d: CharacterVisual3D
var _character_visual
var _status_sprite: AnimatedSprite2D
var _water_overlay: WaterLegOverlay
var _name_label: Label
var _hp_label: Label
var _corpse_badge: Label
var _cage_badge: Label
var _cage_sprite: Sprite2D
var _hp_bar: RpgResourceBar
var _mp_bar: RpgResourceBar
var _move_tween: Tween
var _flash_tween: Tween
var _last_hp: int = -1
var _action_token: int = 0
var _current_status_vfx := ""
var _procedural_status_vfx := ""
var _status_phase := 0.0
var _path_animating := false
var _burn_emit_time := 0.0
var _visual_phase := 0.0
var _visual_action_busy := false
var _visual_action_tween: Tween
var _visual_priority := PREMIUM_ANIMATION.Priority.IDLE
var _premium_ghosts: Array[Sprite2D] = []
var _visual_move_direction := Vector2.RIGHT
var _last_step_contact := -1
var _world_ui_bounds_refresh := 0.0
## Idle dos bichos do SPD (Rato/Cobra/Slime/Gnoll) respira em loop contínuo,
## diferente do resto do elenco (pose parada estática) — só ativo quando a
## unidade está viva, parada e fora de uma ação de golpe/morte.
var _spd_idle_running := false
var _spd_idle_frame_i := 0
var _spd_idle_elapsed := 0.0
## Última "foto" dos campos que refresh() realmente lê, tirada ao final da
## última chamada que fez trabalho de verdade. `null` força a primeira
## chamada a sempre rodar por inteiro. Evita refazer tween/áudio/texto/HP bar
## de TODA unidade do tabuleiro a cada ação de qualquer uma (ver
## main.gd:_sync_visuals(), que chama refresh() no elenco inteiro) — quando
## nada relevante mudou pra esta unidade específica desde a última chamada,
## o corpo inteiro é pulado (função idempotente: mesma entrada, mesma saída,
## então pular é seguro por definição).
var _last_sync_snapshot = null

const STATUS_STRIPS := {
	"paralyzed": ["stun_status_strip.png", 4, 2],
	"dazed": ["stun_status_strip.png", 4, 2],
	"root": ["root_status_strip.png", 5, 2],
	"burned": ["burn_status_strip.png", 4, 2],
	"blinded": ["blinded_status_strip.png", 4, 2],
	"bleed": ["bleed_status_strip.png", 4, 2],
	"guarding": ["guarding_status_strip.png", 4, 2],
	# Foco (Monge) reaproveita a faixa da postura defensiva do Guerreiro —
	# é a mesma ideia de "guarda levantada" na tela.
	"focus": ["guarding_status_strip.png", 4, 2],
	"heronStance": ["guarding_status_strip.png", 4, 2],
	"fury": ["fury_status_strip.png", 4, 2],
	"regen": ["regen_status_strip.png", 4, 2],
	"regenBoost": ["regen_status_strip.png", 4, 2],
	"invisible": ["invisible_status_strip.png", 4, 2],
}
const STATUS_PRIORITY := ["paralyzed", "root", "dazed", "burned", "poison", "bleed", "blinded", "slowed", "weakened", "focus", "heronStance", "guarding", "fury", "regen", "regenBoost", "invisible", "evasive", "swiftFeet"]
## Mantido vazio apenas para compatibilidade com o caminho visual genérico;
## os cinco inimigos agora são atendidos exclusivamente por ANIMAL_SPECS.
const SPD_MOB_SPECS := {}
static var ANIMAL_SPECS: Dictionary = AnimalSpriteCatalog.build()
## Sequências de frame REAIS portadas de RatSprite/SlimeSprite/SnakeSprite/
## GnollSprite.java (Shattered Pixel Dungeon, GPLv3+, ver ASSET_SOURCES.md) —
## índices, FPS e loop copiados exatamente dos construtores originais, não
## escolhidos "no olho". Todos os índices caem na linha 0 do atlas (frame
## width já é a largura de coluna real da spritesheet), então a leitura de
## frame é sempre `index * frame_w` na região.
const SPD_MOB_ANIMS := {
	"spd_rat": {
		"idle": {"frames": [0, 0, 0, 1], "fps": 2.0, "loop": true},
		"walk": {"frames": [6, 7, 8, 9, 10], "fps": 10.0, "loop": true},
		"attack": {"frames": [2, 3, 4, 5, 0], "fps": 15.0, "loop": false},
		"death": {"frames": [11, 12, 13, 14], "fps": 10.0, "loop": false},
	},
	"spd_slime": {
		"idle": {"frames": [0, 1, 1, 0], "fps": 3.0, "loop": true},
		"walk": {"frames": [0, 2, 3, 3, 2, 0], "fps": 10.0, "loop": true},
		"attack": {"frames": [2, 3, 4, 6, 5], "fps": 15.0, "loop": false},
		"death": {"frames": [0, 5, 6, 7], "fps": 10.0, "loop": false},
	},
	"spd_snake": {
		# SnakeSprite.java: muitos quadros parados propositalmente — corpo
		# quieto (0) por mais tempo, ereto (1) por mais tempo ainda, depois um
		# lampejo rápido de língua (2,3,2) antes de assentar de volta em 1.
		"idle": {"frames": [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 1,1,1,1,1,1,1,1,1,1, 2,3,2,1,1], "fps": 10.0, "loop": true},
		"walk": {"frames": [4, 5, 6, 7], "fps": 8.0, "loop": true},
		"attack": {"frames": [8, 9, 10, 9, 0], "fps": 15.0, "loop": false},
		"death": {"frames": [11, 12, 13], "fps": 10.0, "loop": false},
	},
	"spd_gnoll": {
		"idle": {"frames": [0, 0, 0, 1, 0, 0, 1, 1], "fps": 2.0, "loop": true},
		"walk": {"frames": [4, 5, 6, 7], "fps": 12.0, "loop": true},
		"attack": {"frames": [2, 3, 0], "fps": 12.0, "loop": false},
		"death": {"frames": [8, 9, 10], "fps": 12.0, "loop": false},
	},
}
## Rato e Gnoll têm 15px de altura nativa no SPD (mesma escala); Cobra (11px)
## e Slime (12px) são propositalmente mais baixos — preserva essa proporção
## real entre os quatro em vez de normalizar todos pra mesma altura, então o
## Gnoll efetivamente lê como o maior/mais robusto do grupo (sem deformar
## nenhum dos quatro com upscale fracionário: mesmo fator pra todos).
const SPD_MOB_SCALE_REFERENCE_HEIGHT := 15.0

## Gaiola da Maga presa (ver GameState._setup_caged_mage): asset real (não
## pixel art) por cima do token, exibido só enquanto unit.caged == true —
## some sozinho no refresh() seguinte à libertação. Fonte quadrada 1254x1254;
## a escala mantém a gaiola um pouco maior que o tile (64px) pra "envolver"
## o personagem em vez de recortá-lo.
const CAGE_TEXTURE_PATH := "res://assets/props/cage.png"
const CAGE_SOURCE_SIZE := 1254.0
const CAGE_DISPLAY_SIZE := 150.0
const BARD_SONG_NOTE_PATHS := {
	"heal": "res://assets/heroes/bardo/cancao/canção da cura.png",
	"inspiration": "res://assets/heroes/bardo/cancao/canção da inspiração.png",
	"distraction": "res://assets/heroes/bardo/cancao/canção da distração.png",
	"pain": "res://assets/heroes/bardo/cancao/canção da dor.png",
}
const BARD_SONG_NOTE_DISPLAY_WIDTH := 74.0
const BARD_SONG_NOTE_Y := -106.0
const BARD_SONG_WHITE_KEY_SHADER := "shader_type canvas_item;\nvoid fragment() {\n vec4 tex = texture(TEXTURE, UV);\n float ink = smoothstep(0.055, 0.20, 1.0 - min(min(tex.r, tex.g), tex.b));\n COLOR = vec4(tex.rgb, tex.a * ink) * COLOR;\n}"
static var _bard_song_material: ShaderMaterial

static func _shared_bard_song_material() -> ShaderMaterial:
	if _bard_song_material == null:
		var shader := Shader.new()
		shader.code = BARD_SONG_WHITE_KEY_SHADER
		_bard_song_material = ShaderMaterial.new()
		_bard_song_material.shader = shader
	return _bard_song_material

func _ready() -> void:
	# refresh() (chamado por setup() logo a seguir, ou no fim deste método)
	# decide o estado real via _sync_process_active() — sem motivo pra
	# começar ligado incondicionalmente.
	set_process(false)
	_visual_root = Node2D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)
	_shadow = Polygon2D.new()
	_shadow.name = "Shadow"
	var shadow_points := PackedVector2Array()
	for i in 24:
		var angle := TAU * float(i) / 24.0
		shadow_points.append(Vector2(cos(angle) * 25.0, sin(angle) * 8.0 + 25.0))
	_shadow.polygon = shadow_points
	_shadow.color = Color(0.02, 0.025, 0.04, 0.34)
	_shadow.z_index = -2
	_shadow.visible = false
	# Sombras pertencem ao plano do chão e nunca acompanham altura, tilt ou
	# squash do corpo.
	add_child(_shadow)
	_weapon_fx = Node2D.new()
	_weapon_fx.name = "WeaponFX"
	_visual_root.add_child(_weapon_fx)
	_status_fx_root = Node2D.new()
	_status_fx_root.name = "StatusFX"
	_visual_root.add_child(_status_fx_root)
	_overhead_fx = Node2D.new()
	_overhead_fx.name = "OverheadFX"
	_visual_root.add_child(_overhead_fx)
	_ui_root = Node2D.new()
	_ui_root.name = "UI"
	_ui_root.z_as_relative = false
	_ui_root.z_index = 3900
	add_child(_ui_root)
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)
	_sprite = Sprite2D.new()
	_sprite.name = "CharacterSprite"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_visual_root.add_child(_sprite)
	_setup_warrior_3d_visual()
	_character_visual = CHARACTER_VISUAL_CONTROLLER.new()
	_status_sprite = AnimatedSprite2D.new()
	_status_sprite.position = Vector2(0, -6)
	_status_sprite.z_index = 4
	_status_sprite.visible = false
	_status_fx_root.add_child(_status_sprite)
	_water_overlay = WaterLegOverlay.new()
	_water_overlay.z_index = 3
	_water_overlay.visible = false
	_visual_root.add_child(_water_overlay)
	_cage_sprite = Sprite2D.new()
	if ResourceLoader.exists(CAGE_TEXTURE_PATH):
		_cage_sprite.texture = load(CAGE_TEXTURE_PATH)
	_cage_sprite.scale = Vector2.ONE * (CAGE_DISPLAY_SIZE / CAGE_SOURCE_SIZE)
	_cage_sprite.position = Vector2(0, -8)
	_cage_sprite.z_index = 6
	_cage_sprite.visible = false
	_visual_root.add_child(_cage_sprite)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Corta com reticências em vez de quebrar linha ou estourar a largura do
	# tile (nome completo continua disponível no painel de inspeção da
	# unidade); mouse_filter=IGNORE pra clicar em cima do nome nunca "roubar"
	# o clique do tile por baixo dele (quem resolve seleção é sempre
	# board_view.tile_at_local_pos, a grade lógica).
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.position = Vector2(-BoardView.TILE_SIZE * 0.5, BoardView.TILE_SIZE * 0.5 - 15)
	_name_label.size = Vector2(BoardView.TILE_SIZE, 14)
	_ui_root.add_child(_name_label)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 11)
	_hp_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hp_label.add_theme_constant_override("shadow_offset_x", 1)
	_hp_label.add_theme_constant_override("shadow_offset_y", 1)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_label.position = Vector2(-BoardView.TILE_SIZE * 0.5, BoardView.TILE_SIZE * 0.5 + 9)
	_hp_label.size = Vector2(BoardView.TILE_SIZE, 14)
	_ui_root.add_child(_hp_label)
	_hp_bar = _make_resource_bar(Vector2(-36, 33), Vector2(72, 14), Color("bd2635"), Color("ed5360"), 9)
	_mp_bar = _make_resource_bar(Vector2(-34, 48), Vector2(68, 12), Color("2369c8"), Color("4fa6f5"), 8)
	# Pedido do usuário: HP/MP de volta no próprio personagem (também
	# continuam na fila de turnos, ver main.gd:_refresh_turn_queue()).
	# Visibilidade de verdade é decidida por refresh() (unit["hp"]>0), não
	# aqui — isto só evita um frame com a barra em branco antes do primeiro
	# refresh().
	_hp_bar.visible = true
	_mp_bar.visible = true
	_apply_warrior_3d_ui_layout()

	_corpse_badge = Label.new()
	_corpse_badge.z_index = 8
	_corpse_badge.add_theme_font_size_override("font_size", 22)
	_corpse_badge.add_theme_color_override("font_color", Color("fff0d0"))
	_corpse_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_corpse_badge.add_theme_constant_override("shadow_offset_x", 2)
	_corpse_badge.add_theme_constant_override("shadow_offset_y", 2)
	_corpse_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corpse_badge.position = Vector2(-32, -53)
	_corpse_badge.size = Vector2(64, 30)
	_corpse_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_corpse_badge)

	_cage_badge = Label.new()
	_cage_badge.z_index = 8
	_cage_badge.add_theme_font_size_override("font_size", 20)
	_cage_badge.add_theme_color_override("font_color", Color("ffd978"))
	_cage_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_cage_badge.add_theme_constant_override("shadow_offset_x", 2)
	_cage_badge.add_theme_constant_override("shadow_offset_y", 2)
	_cage_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cage_badge.position = Vector2(-40, -53)
	_cage_badge.size = Vector2(80, 30)
	_cage_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cage_badge.visible = false
	_ui_root.add_child(_cage_badge)

func _apply_warrior_3d_ui_layout() -> void:
	if not _uses_warrior_3d(): return
	var projected := _warrior_3d.projected_model_bounds()
	if projected.size == Vector2.ZERO: return
	var texture_center_y := float(_warrior_viewport.size.y) * 0.5
	var character_top := _warrior_viewport_sprite.position.y + (projected.position.y - texture_center_y) * _warrior_viewport_sprite.scale.y
	# 8 px correspondem a aproximadamente 10–20% da cabeça projetada nesta
	# câmera. A ordem, de baixo para cima, é MP fino, HP principal e nome.
	var clearance := 8.0
	var mp_y := character_top - clearance - 6.0
	var hp_y := mp_y - 13.0
	var name_y := hp_y - 15.0
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.position = Vector2(-45, name_y)
	_name_label.size = Vector2(90, 13)
	_hp_label.position = Vector2(-45, hp_y)
	_hp_label.size = Vector2(90, 10)
	_hp_bar.custom_minimum_size = Vector2(68, 10)
	_hp_bar.size = Vector2(68, 10)
	_hp_bar.position = Vector2(-34, hp_y)
	_mp_bar.custom_minimum_size = Vector2(56, 6)
	_mp_bar.size = Vector2(56, 6)
	_mp_bar.position = Vector2(-28, mp_y)

	refresh()

func _process(delta: float) -> void:
	_status_phase = fmod(_status_phase + delta * 2.4, TAU)
	_visual_phase = fmod(_visual_phase + delta * (10.0 if _path_animating else 2.25), TAU)
	_update_weighted_visual_pose()
	if _uses_warrior_3d():
		_world_ui_bounds_refresh -= delta
		if _world_ui_bounds_refresh <= 0.0:
			_world_ui_bounds_refresh = 0.10
			_apply_warrior_3d_ui_layout()
	if _has_status("burned") and unit.get("hp", 0) > 0:
		_burn_emit_time -= delta
		if _burn_emit_time <= 0.0:
			_emit_spd_flame(false)
			# CharSprite.State.BURNING: burning.pour(..., 0.06f).
			_burn_emit_time = 0.06
	else:
		_burn_emit_time = 0.0
	if _spd_idle_running:
		_advance_spd_idle(delta)
	queue_redraw()

func _begin_premium_action(priority: int) -> bool:
	if priority < _visual_priority: return false
	if _visual_action_tween != null and _visual_action_tween.is_valid(): _visual_action_tween.kill()
	_visual_priority = priority
	_visual_action_busy = priority >= PREMIUM_ANIMATION.Priority.ATTACK
	_action_token += 1
	_cleanup_premium_ghosts()
	if _visual_root != null:
		_visual_root.position = Vector2.ZERO
		_visual_root.rotation = 0.0
		_visual_root.scale = Vector2.ONE
	return true

func _finish_premium_action(priority: int) -> void:
	if priority != _visual_priority: return
	_visual_priority = PREMIUM_ANIMATION.Priority.IDLE
	_visual_action_busy = false
	if _visual_root != null:
		_visual_root.position = Vector2.ZERO
		_visual_root.rotation = 0.0
		_visual_root.scale = Vector2.ONE
	_cleanup_premium_ghosts()

func _cleanup_premium_ghosts() -> void:
	for ghost in _premium_ghosts:
		if is_instance_valid(ghost): ghost.queue_free()
	_premium_ghosts.clear()

func _exit_tree() -> void:
	_action_token += 1
	if _visual_action_tween != null and _visual_action_tween.is_valid(): _visual_action_tween.kill()
	if _move_tween != null and _move_tween.is_valid(): _move_tween.kill()
	if _flash_tween != null and _flash_tween.is_valid(): _flash_tween.kill()
	_cleanup_premium_ghosts()
	if _character_visual != null: _character_visual.cancel_temporary_visuals()

func _spawn_premium_smear(direction: Vector2, afterimage := false) -> Sprite2D:
	if VisualPolicy.quality == VisualPolicy.QUALITY_LOW or _sprite == null: return null
	var weight: String = _character_visual.body_weight() if _character_visual != null else "medium"
	var timing: Dictionary = PREMIUM_ANIMATION.for_weight(weight)
	if float(timing["smear"]) <= 0.0: return null
	var ghost := Sprite2D.new()
	ghost.texture = _sprite.texture
	ghost.region_enabled = _sprite.region_enabled
	ghost.region_rect = _sprite.region_rect
	ghost.hframes = _sprite.hframes; ghost.vframes = _sprite.vframes; ghost.frame = _sprite.frame
	ghost.flip_h = _sprite.flip_h; ghost.centered = _sprite.centered; ghost.offset = _sprite.offset
	ghost.scale = _sprite.scale * (Vector2(1.10, 0.92) if absf(direction.x) >= absf(direction.y) else Vector2(0.94, 1.10))
	ghost.position = -direction * (5.0 if afterimage else 2.0)
	ghost.modulate = Color(0.70, 0.84, 1.0, 0.28 if afterimage else 0.20)
	ghost.z_index = _sprite.z_index - 1
	_visual_root.add_child(ghost)
	_premium_ghosts.append(ghost)
	var fade := ghost.create_tween().set_parallel(true)
	fade.tween_property(ghost, "position", ghost.position - direction * 7.0, float(timing["smear"]))
	fade.tween_property(ghost, "modulate:a", 0.0, float(timing["smear"]))
	fade.set_parallel(false).tween_callback(func(): _premium_ghosts.erase(ghost); ghost.queue_free())
	return ghost

func _uses_weighted_visuals() -> bool:
	return _character_visual != null

func _update_weighted_visual_pose() -> void:
	if not _uses_weighted_visuals() or _visual_root == null: return
	_shadow.visible = unit.get("hp", 0) > 0
	# O CharacterVisual3D já anima skeleton, peso, contato dos pés e recovery.
	# Aplicar também o bob/squash do controlador de sprites deslocava o modelo
	# inteiro e duplicava a biomecânica do ataque. No caminho 3D o nó lógico e
	# o composite ficam estáveis; somente o rig move o corpo.
	if _uses_warrior_3d():
		_visual_root.position = Vector2.ZERO
		_visual_root.rotation = 0.0
		_visual_root.scale = Vector2.ONE
		return
	# ETAPA 17 — sinal puramente visual (respiração mais pesada/postura mais
	# baixa em combat idle); LOW_HP_VISUAL_RATIO não é lido por nenhuma regra.
	var hp := int(unit.get("hp", 0))
	var max_hp := int(unit.get("maxHp", 1))
	var low_hp := hp > 0 and max_hp > 0 and float(hp) / float(max_hp) <= LOW_HP_VISUAL_RATIO
	_character_visual.update_pose(_visual_phase, _path_animating, _visual_move_direction, _visual_action_busy, hp > 0, low_hp)
	# OverheadFX acompanha a altura, mas cancela squash/stretch para manter
	# notas e ícones perfeitamente legíveis. UI continua fora do VisualRoot.
	if _overhead_fx != null:
		_overhead_fx.scale = Vector2(1.0 / maxf(0.01, _visual_root.scale.x), 1.0 / maxf(0.01, _visual_root.scale.y))
	if _path_animating:
		var contact: int = floori(_visual_phase / PI)
		if contact != _last_step_contact:
			_last_step_contact = contact
			if contact % 2 == 0: on_visual_footstep()

func on_visual_footstep() -> void:
	if _character_visual == null: return
	var intensity := float(_character_visual.visual_value("footstep_intensity", 0.75))
	_character_visual.pulse_contact(intensity)
	if intensity >= 1.0:
		_spawn_ground_effect(DUST_SCENE)
		var board := get_parent() as BoardView
		if board != null:
			board.react_environment(position + Vector2(0, 25), clampf(0.42 + intensity * 0.22, 0.45, 0.90), _visual_move_direction, 0.12 + intensity * 0.08, "")

## Feedback individual de uma aplicação bem-sucedida das Canções. Como o
## Sprite2D é filho do token, acompanha inclusive animate_path() enquanto
## sobe, balança e pulsa. As imagens fornecidas têm fundo branco opaco; o
## shader remove somente esse branco e preserva a cor própria de cada asset.
func spawn_bard_song_notes(song_kind: String) -> Sprite2D:
	var texture_path: String = BARD_SONG_NOTE_PATHS.get(song_kind, "")
	if texture_path == "" or not ResourceLoader.exists(texture_path):
		return null
	var notes := Sprite2D.new()
	notes.name = "BardSongNotesVFX"
	notes.texture = load(texture_path)
	notes.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var overhead_y := float(_character_visual.visual_value("overhead_y", BARD_SONG_NOTE_Y)) if _character_visual != null else BARD_SONG_NOTE_Y
	notes.position = Vector2(0, overhead_y)
	var display_scale: float = BARD_SONG_NOTE_DISPLAY_WIDTH / maxf(1.0, float(notes.texture.get_width()))
	notes.scale = Vector2.ONE * display_scale * 0.8
	notes.modulate.a = 0.0
	notes.z_index = VisualPolicy.Z_OVERHEAD_EFFECT
	notes.material = _shared_bard_song_material()
	(_overhead_fx if _overhead_fx != null else self).add_child(notes)

	var motion := notes.create_tween()
	motion.tween_property(notes, "position", Vector2(-5, overhead_y - 4), 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(notes, "position", Vector2(6, overhead_y - 9), 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(notes, "position", Vector2(-5, overhead_y - 14), 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(notes, "position", Vector2(4, overhead_y - 19), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_interval(0.25)
	motion.tween_callback(notes.queue_free)

	var appearance := notes.create_tween()
	appearance.set_parallel(true)
	appearance.tween_property(notes, "modulate:a", 1.0, 0.15)
	appearance.tween_property(notes, "scale", Vector2.ONE * display_scale * 1.05, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	appearance.chain().tween_property(notes, "scale", Vector2.ONE * display_scale, 0.25).set_trans(Tween.TRANS_SINE)
	appearance.chain().tween_interval(1.10)
	appearance.chain().tween_property(notes, "modulate:a", 0.0, 0.30)
	return notes

func spawn_bard_song_failure(song_kind: String) -> Sprite2D:
	var notes := spawn_bard_song_notes(song_kind)
	if notes == null: return null
	notes.name = "BardSongFailedVFX"
	notes.modulate = Color(0.58, 0.62, 0.70, notes.modulate.a)
	notes.rotation = -0.08
	var dissipate := notes.create_tween()
	dissipate.tween_interval(0.24)
	dissipate.tween_property(notes, "position:x", notes.position.x + 18.0, 0.42).set_trans(Tween.TRANS_SINE)
	dissipate.parallel().tween_property(notes, "rotation", 0.18, 0.42)
	return notes

## Avança o frame de idle do bicho do SPD conforme o FPS real de
## RatSprite/SlimeSprite/SnakeSprite/GnollSprite (SPD_MOB_ANIMS) — mantém o
## frame corrente entre chamadas de refresh() em vez de reiniciar a
## respiração toda vez que o estado muda.
func _advance_spd_idle(delta: float) -> void:
	var sprite_key: String = _visual_sprite_key()
	if ANIMAL_SPECS.has(sprite_key):
		if unit.get("riderSpriteKey", "") != "": return
		var key := _animal_directional_key("idle", _facing_direction())
		var animal_anim: Array = ANIMAL_SPECS[sprite_key]["anims"].get(key, [])
		if animal_anim.is_empty(): return
		var animal_frames: Array = animal_anim[0]
		var animal_step: float = 1.0 / float(animal_anim[1])
		_spd_idle_elapsed += delta
		if _spd_idle_elapsed >= animal_step:
			_spd_idle_elapsed = fmod(_spd_idle_elapsed, animal_step)
			_spd_idle_frame_i = (_spd_idle_frame_i + 1) % animal_frames.size()
			_apply_animal_frame(sprite_key, animal_frames[_spd_idle_frame_i], _animal_should_flip(key))
		return
	var anim: Dictionary = SPD_MOB_ANIMS.get(sprite_key, {}).get("idle", {})
	if anim.is_empty(): return
	var frames: Array = anim["frames"]
	var step: float = 1.0 / float(anim["fps"])
	_spd_idle_elapsed += delta
	if _spd_idle_elapsed >= step:
		_spd_idle_elapsed = fmod(_spd_idle_elapsed, step)
		_spd_idle_frame_i = (_spd_idle_frame_i + 1) % frames.size()
		_apply_texture(_spd_frame_texture(sprite_key, frames[_spd_idle_frame_i]), unit.get("facing", {}).get("dx", 0) < 0)

func _has_status(type: String) -> bool:
	for effect in unit.get("statusEffects", []):
		if effect.get("type", "") == type: return true
	return false

## Chave de sprite EFETIVA pra renderização (pedido do usuário: Virar
## Morcego troca a aparência do Vampiro sem criar uma unidade nova). Fica
## igual a unit["spriteKey"] na quase totalidade dos casos — só troca pra
## "vampire_bat" enquanto o status "batForm" estiver ativo. spriteKey em si
## NUNCA muda (GameState.enemy_act reconhece o Vampiro por ele, ver bloco
## `if u.get("spriteKey", "") == "vampire":`) — só a aparência é temporária.
func _visual_sprite_key() -> String:
	var base_key: String = unit.get("spriteKey", "")
	if base_key == "vampire" and _has_status("batForm"):
		return "vampire_bat"
	return base_key

func _emit_spd_flame(burst: bool = false) -> void:
	# O SPD liga o emissor, sem rajada artificial na aplicação.
	var amount := 1
	for i in amount:
		var flame := SpdFireParticles.ExactFlame.new()
		flame.position = Vector2(randf_range(-19.0, 19.0), randf_range(-3.0, 25.0))
		add_child(flame)

func play_burning_application() -> void:
	_emit_spd_flame(true)

## Reação puramente visual: não altera x/y nem o tile lógico da unidade.
func play_impact_recoil(direction: Vector2, distance: float = 4.0) -> void:
	if _sprite == null or not is_instance_valid(_sprite): return
	var start := _sprite.position
	var recoil_direction := direction.normalized()
	if recoil_direction == Vector2.ZERO: recoil_direction = Vector2.RIGHT
	var tween := create_tween()
	tween.tween_property(_sprite, "position", start + recoil_direction * distance, 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "position", start, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func play_elemental_hit_reaction(attack_origin: Vector2, profile: String, critical: bool = false) -> void:
	if profile == "":
		play_weighted_hit_reaction(attack_origin, critical)
		return
	if _visual_action_tween != null and _visual_action_tween.is_valid(): _visual_action_tween.kill()
	_visual_action_busy = true
	var away := (position - attack_origin).normalized()
	if away == Vector2.ZERO: away = Vector2.RIGHT
	if _character_visual != null: _character_visual.apply_magic_light(profile, 1.25 if critical else 1.0, 0.22 if profile == "lightning" else 0.34)
	_flash_hit(Color("fff0cf") if profile == "fire" else (Color("d9f8ff") if profile == "ice" else Color("e8fbff")), critical)
	play_action("hit", HIT_ACTION_DURATION, false)
	_visual_action_tween = create_tween()
	if profile == "lightning":
		for i in 3:
			_visual_action_tween.tween_property(_visual_root, "position", away * (3.0 if i % 2 == 0 else -2.0), 0.026)
			_visual_action_tween.parallel().tween_property(_visual_root, "rotation", (0.025 if i % 2 == 0 else -0.025), 0.026)
	elif profile == "ice":
		_visual_action_tween.tween_property(_visual_root, "position", away * 4.5, 0.045).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_visual_action_tween.parallel().tween_property(_visual_root, "scale", Vector2(1.035, 0.94), 0.045)
		_visual_action_tween.tween_interval(0.065)
	else:
		_visual_action_tween.tween_property(_visual_root, "position", away * (10.0 if critical else 7.0), 0.065).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_visual_action_tween.parallel().tween_property(_visual_root, "scale", Vector2(1.07, 0.95), 0.065)
		_visual_action_tween.tween_interval(0.085 if critical else 0.055)
	_visual_action_tween.tween_property(_visual_root, "position", Vector2.ZERO, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_visual_action_tween.parallel().tween_property(_visual_root, "rotation", 0.0, 0.12)
	_visual_action_tween.parallel().tween_property(_visual_root, "scale", Vector2.ONE, 0.12)
	_visual_action_tween.tween_callback(func(): _visual_action_busy = false)

func _draw() -> void:
	if unit.is_empty(): return
	var visual_spec: Dictionary = ANIMAL_SPECS.get(_visual_sprite_key(), {})
	if not visual_spec.is_empty() and unit.get("hp", 0) > 0:
		var shadow: Array = visual_spec["shadow"]
		draw_set_transform(Vector2(0, -2))
		draw_circle(Vector2.ZERO, shadow[0], Color(0.02,0.02,0.025,0.34), false, shadow[1] * 2.0)
		draw_set_transform(Vector2.ZERO)
	if _procedural_status_vfx == "" or unit.get("hp", 0) <= 0: return
	match _procedural_status_vfx:
		"poison":
			# Névoa verde tóxica dos primeiros andares: nuvens grandes,
			# translúcidas e sobrepostas em vez de pequenos pontos isolados.
			for i in 9:
				var a := TAU * float(i) / 9.0 + _status_phase * 0.22
				var drift := sin(_status_phase * 0.8 + float(i) * 1.7) * 5.0
				var p := Vector2(cos(a) * (22.0 + drift), 8.0 + sin(a * 1.4) * 25.0 - fmod(_status_phase * 5.0 + i * 4.0, 12.0))
				draw_circle(p, 9.0 + float(i % 3) * 2.0, Color(0.20,0.74,0.25,0.22))
				draw_circle(p + Vector2(4,-3), 5.0 + float(i % 2), Color(0.45,0.94,0.38,0.16))
		"slowed":
			draw_arc(Vector2(0, 24), 27.0 + sin(_status_phase) * 2.0, 0, TAU, 36, Color(Color("80c8ff"), 0.62), 3.0, true)
			draw_line(Vector2(-18, 28), Vector2(18, 28), Color(Color("d7f2ff"), 0.6), 2.0, true)
		"weakened":
			for i in 3:
				var y := -18.0 + float(i) * 16.0 + sin(_status_phase + i) * 3.0
				draw_line(Vector2(-20, y), Vector2(20, y + 5), Color(Color("8b63b6"), 0.5), 3.0, true)
		"evasive":
			var offset := sin(_status_phase * 2.0) * 7.0
			draw_arc(Vector2(offset - 16, 0), 25, -1.2, 1.2, 18, Color(Color("bca8ff"), 0.42), 3.0, true)
			draw_arc(Vector2(-offset + 16, 0), 25, PI - 1.2, PI + 1.2, 18, Color(Color("bca8ff"), 0.3), 3.0, true)
		"swiftFeet":
			for i in 3:
				var x := -22.0 + float(i) * 16.0 + fmod(_status_phase * 8.0, 12.0)
				draw_polyline(PackedVector2Array([Vector2(x - 7, 24), Vector2(x, 18), Vector2(x + 7, 24)]), Color(Color("ffe07a"), 0.75), 2.5, true)
		"frozen":
			for i in 6:
				var angle := TAU * float(i) / 6.0
				var base := Vector2(cos(angle) * 18.0, 21.0 + sin(angle) * 5.0)
				var tip := base + Vector2(sin(angle) * 3.0, -8.0 - float(i % 3) * 3.0)
				draw_colored_polygon(PackedVector2Array([base + Vector2(-3, 1), base + Vector2(3, 1), tip]), Color(0.58, 0.88, 1.0, 0.52))
			var breath := Vector2(9.0 + sin(_status_phase) * 3.0, -8.0 - fmod(_status_phase * 4.0, 8.0))
			draw_circle(breath, 5.0, Color(0.78, 0.95, 1.0, 0.14))

func _make_resource_bar(at: Vector2, bar_size: Vector2, fill_color: Color, light_color: Color, font_size: int) -> RpgResourceBar:
	var bar := RpgResourceBar.new()
	bar.z_index = 7
	bar.position = at
	(_ui_root if _ui_root != null else self).add_child(bar)
	bar.setup_bar(bar_size, fill_color, light_color, font_size)
	return bar

func setup(u: Dictionary) -> void:
	unit = u
	if is_inside_tree():
		_setup_warrior_3d_visual()
		_apply_warrior_3d_ui_layout()
		if _character_visual != null and _character_visual.host == null:
			_character_visual.configure(self, _visual_root, _sprite, _shadow, unit)
			if _status_fx_root != null: _status_fx_root.scale = Vector2.ONE * float(_character_visual.visual_value("status_scale", 1.0))
		refresh()

func _uses_warrior_3d() -> bool:
	return use_3d_visual and is_instance_valid(_warrior_3d)

func _setup_warrior_3d_visual() -> void:
	var character_id := String(unit.get("spriteKey", ""))
	if not use_3d_visual or not CharacterVisualFactory.has_profile(character_id) or _warrior_3d != null:
		_update_warrior_3d_visibility()
		return
	_warrior_viewport = SubViewport.new()
	_warrior_viewport.name = "Warrior3DViewport"
	_warrior_viewport.size = Vector2i(192, 192)
	_warrior_viewport.transparent_bg = true
	_warrior_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_warrior_viewport)
	_warrior_3d = CharacterVisualFactory.create(character_id)
	_warrior_viewport.add_child(_warrior_3d)
	_warrior_viewport_sprite = Sprite2D.new()
	_warrior_viewport_sprite.name = "Warrior3DComposite"
	_warrior_viewport_sprite.texture = _warrior_viewport.get_texture()
	_warrior_viewport_sprite.position = warrior_3d_screen_offset
	_warrior_viewport_sprite.scale = Vector2.ONE * warrior_3d_scale
	_warrior_viewport_sprite.z_index = 2
	_visual_root.add_child(_warrior_viewport_sprite)
	_update_warrior_3d_visibility()

func _update_warrior_3d_visibility() -> void:
	var enabled := _uses_warrior_3d()
	# Cavaleiro montado: quem é desenhado é a dupla (token da Vestruz) — nem o
	# sprite 2D nem o modelo 3D do herói aparecem por cima.
	var riding: bool = unit.get("mountedOn", "") != ""
	if _warrior_viewport_sprite != null: _warrior_viewport_sprite.visible = enabled and not riding
	if _sprite != null: _sprite.visible = not enabled and not riding
	if _warrior_viewport != null:
		_warrior_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED

func warrior_3d_visual() -> CharacterVisual3D:
	return _warrior_3d

func set_use_3d_visual(enabled: bool) -> void:
	use_3d_visual = enabled
	if enabled and _warrior_3d == null: _setup_warrior_3d_visual()
	_update_warrior_3d_visibility()

func is_using_warrior_3d() -> bool:
	return _uses_warrior_3d()

func visual_3d_capability(capability: StringName) -> bool:
	return _uses_warrior_3d() and _warrior_3d.profile != null and _warrior_3d.profile.capability(capability)

func visual_3d_event_time(event_name: String, fallback: float) -> float:
	return float(_warrior_3d.profile.animation_events.get(event_name,fallback)) if _uses_warrior_3d() and _warrior_3d.profile != null else fallback

func play_warrior_skill_visual(item: Dictionary, target_world_position := Vector2.ZERO, result := "HIT") -> bool:
	if not _uses_warrior_3d(): return false
	var skill_id := _warrior_3d.profile.skill_id_for(item) if _warrior_3d.profile != null else ""
	if skill_id.is_empty(): return false
	var target3 := Vector3(target_world_position.x, 0.0, target_world_position.y) if target_world_position != Vector2.ZERO else Vector3.ZERO
	return _warrior_3d.play_skill_visual(skill_id, result, target3)

func play_magic_body_light(element: String, strength: float = 1.0, duration: float = 0.30) -> void:
	if _character_visual != null:
		_character_visual.apply_magic_light(element, strength, duration)

## Recalcula posição (animada, se já tinha uma posição antes, tocando o
## ciclo de "walk" durante o trajeto), pose parada/ação (attack/hit/death,
## conforme a arte de cada personagem tiver) e textos a partir do
## dicionário `unit` atual — chamar depois de qualquer mudança de estado
## relevante (x/y/hp/facing).
func _build_sync_snapshot() -> Array:
	return [
		unit.get("x"), unit.get("y"), unit.get("hp"), unit.get("maxHp"),
		unit.get("mp"), unit.get("maxMp"), unit.get("facing", {}).duplicate(),
		unit.get("caged", false), unit.get("turnsSinceDeath", -1),
		unit.get("scriptedRevive", false), unit.get("resurrectionTurns", -1),
		unit.get("statusEffects", []).duplicate(true),
		unit.get("footprintWidth", unit.get("footprintSize", 1)), unit.get("footprintHeight", unit.get("footprintSize", 1)),
		unit.get("mountedOn", ""), unit.get("riderName", ""), unit.get("riderSpriteKey", ""),
	]

## Cavaleiro montado: desenhado menor e acima da montaria, no mesmo quadrado.
func _mount_offset() -> Vector2:
	return Vector2.ZERO

## Sprites "idle montado" (herói + Vestruz numa imagem só, uma pose por direção):
## assets/heroes/<pasta do herói>/mounted_idle_<front|back|left|right>.png, todos
## na mesma tela (684x618) com a base dos pés na mesma linha — ver
## tools/prepare_mounted_sprites.py. Só existe pose PARADA: não há animação de
## caminhada montada, então durante o deslocamento a dupla desliza na pose da
## direção do movimento.
const MOUNTED_CANVAS_HEIGHT := 618.0
const MOUNTED_FOOT_MARGIN := 9.0
const MOUNTED_SCALE_MULT := 1.2
const MOUNTED_DIRECTION_FILE := {"down": "front", "up": "back", "left": "left", "right": "right"}

func _mounted_pose_path(direction: String) -> String:
	var rider_key: String = String(unit.get("riderSpriteKey", ""))
	if rider_key == "": return ""
	var folder: String = SpriteManifest.SPRITE_MANIFEST.get(rider_key, "")
	if folder == "": return ""
	var path := "%s/mounted_idle_%s.png" % [folder, MOUNTED_DIRECTION_FILE.get(direction, "front")]
	return path if ResourceLoader.exists(path) else ""

## Escala pela altura da tela (igual aos outros quadros) e ancora a BASE DOS PÉS
## (linha fixa da tela) no chão do quadrado — nunca pelo bbox, que mudaria de
## pose pra pose e faria a dupla "saltar" ao trocar de direção.
func _apply_mounted_texture(texture: Texture2D) -> void:
	var scale_factor: float = DISPLAY_HEIGHT / texture.get_height() * MOUNTED_SCALE_MULT
	_sprite.texture = texture
	_sprite.scale = Vector2.ONE * scale_factor
	var foot_row: float = float(texture.get_height()) - MOUNTED_FOOT_MARGIN
	_sprite.offset = Vector2(0.0, float(texture.get_height()) * 0.5 - foot_row + (DISPLAY_HEIGHT * 0.5) / scale_factor)
	_sprite.flip_h = false

func _show_mounted_pose(direction: String) -> bool:
	var path := _mounted_pose_path(direction)
	if path == "": return false
	_spd_idle_running = false
	_apply_mounted_texture(load(path) as Texture2D)
	return true

func refresh() -> void:
	if unit.is_empty():
		return
	var sync_snapshot := _build_sync_snapshot()
	if _last_sync_snapshot != null and sync_snapshot == _last_sync_snapshot:
		return
	_last_sync_snapshot = sync_snapshot
	var footprint_width := maxi(1, int(unit.get("footprintWidth", unit.get("footprintSize", 1))))
	var footprint_height := maxi(1, int(unit.get("footprintHeight", unit.get("footprintSize", 1))))
	var target_pos: Vector2 = Vector2(unit["x"], unit["y"]) * BoardView.TILE_SIZE + Vector2(footprint_width, footprint_height) * BoardView.TILE_SIZE * 0.5 + _mount_offset()
	var body_half_size := BoardView.TILE_SIZE * float(footprint_height) * 0.5
	# Profundidade usa os pés/base lógica da unidade. A UI fica numa camada
	# global própria e nunca é escondida por copas ou construções.
	z_index = roundi(target_pos.y + body_half_size)
	var is_riding: bool = unit.get("mountedOn", "") != ""
	# Montado: quem aparece é a dupla (sprite "idle montado" no token da Vestruz,
	# que mostra o HP/MP dela); o token do cavaleiro fica sem desenho, só como
	# âncora de seleção/status.
	scale = Vector2.ONE
	_sprite.visible = not is_riding
	if _shadow != null and is_riding: _shadow.visible = false
	var board := get_parent() as BoardView
	if board != null:
		z_index = maxi(z_index, board.structure_occupant_z(int(unit["x"]), int(unit["y"])))
	var info_width := BoardView.TILE_SIZE * float(footprint_width)
	var ui_top_offset := body_half_size - 15.0
	# Pedido do usuário: monstro 2x2 (Goo grande/Salamandra/Dragão/Troll)
	# também aumenta nome/HP/MP proporcionalmente, não só o sprite.
	var is_big: bool = footprint_width > 1 or footprint_height > 1
	var big_ui_scale := 1.5 if is_big else 1.0
	if not _uses_warrior_3d():
		_name_label.position = Vector2(-info_width * 0.5, ui_top_offset)
		_name_label.size.x = info_width
		_name_label.add_theme_font_size_override("font_size", roundi(12 * big_ui_scale))
	var animal_spec: Dictionary = ANIMAL_SPECS.get(_visual_sprite_key(), {})
	if _uses_warrior_3d():
		_apply_warrior_3d_ui_layout()
	else:
		# Em unidades 2x2, a barra fica logo abaixo dos pés da área inteira;
		# não reutiliza o bar_y calibrado para criaturas 1x1 (como o Goo antigo).
		var resource_y := body_half_size + 1.0 if is_big else float(animal_spec.get("bar_y", body_half_size + 1.0))
		var hp_size := Vector2(72, 14) * big_ui_scale
		var mp_size := Vector2(68, 12) * big_ui_scale
		_hp_bar.custom_minimum_size = hp_size
		_hp_bar.size = hp_size
		_hp_bar._value_label.add_theme_font_size_override("font_size", roundi(9 * big_ui_scale))
		_hp_bar.queue_redraw()
		_mp_bar.custom_minimum_size = mp_size
		_mp_bar.size = mp_size
		_mp_bar._value_label.add_theme_font_size_override("font_size", roundi(8 * big_ui_scale))
		_mp_bar.queue_redraw()
		_hp_bar.position = Vector2(-hp_size.x * 0.5, resource_y)
		_mp_bar.position = Vector2(-mp_size.x * 0.5, resource_y + 15.0 * big_ui_scale)
	var first_refresh: bool = _last_hp == -1
	var moving: bool = _path_animating
	if first_refresh:
		position = target_pos
	elif position != target_pos and not _path_animating:
		moving = true
		_animate_move(target_pos, _movement_direction(target_pos - position))
		AudioEngine.play_sfx("move", AudioEngine.pan_for_x(int(unit["x"])))

	var alive: bool = unit["hp"] > 0
	if _shadow != null and ANIMAL_SPECS.get(_visual_sprite_key(), {}).is_empty():
		_shadow.visible = alive or unit.has("turnsSinceDeath")
	# `GameState.finalize_death_if_needed()` (chamado em `_sync_visuals()`,
	# ANTES do refresh() de qualquer token) já decidiu se esta unidade virou
	# cadáver ressuscitável (`turnsSinceDeath` presente) ou alma imediata
	# (bichos do SPD — ver IMMEDIATE_SOUL_SPRITE_KEYS, sem `turnsSinceDeath`
	# nenhum). Este token só lê o resultado; não decide mais nada sozinho.
	var just_died: bool = not first_refresh and _last_hp > 0 and unit["hp"] <= 0
	var just_revived: bool = not first_refresh and _last_hp <= 0 and unit["hp"] > 0
	# Arqueiro da Vila (GameState._setup_village/maybe_revive_village_archer):
	# entra em campo já caído perto da casa em chamas, sem nunca ter passado
	# por just_died nesta sessão — precisa da MESMA pose de corpo desde o
	# primeiro refresh(), só que sem o som de morte (ele não morreu agora).
	var starts_lying: bool = first_refresh and not alive and unit.get("scriptedRevive", false)
	var hp_dropped: bool = not first_refresh and unit["hp"] < _last_hp
	var caged: bool = unit.get("caged", false)
	var rest_color: Color = Color(1, 1, 1, 1) if alive else Color(0.35, 0.35, 0.4, 0.85)
	if alive and caged:
		# Presa na gaiola: tingimento acinzentado, sem VFX de dano/movimento —
		# ela é imóvel e imune enquanto isso (ver GameState._setup_caged_mage).
		rest_color = Color(0.55, 0.52, 0.58, 1.0)

	if just_died:
		if _uses_warrior_3d(): _warrior_3d.play_death()
		_begin_premium_action(PREMIUM_ANIMATION.Priority.DEATH)
		AudioEngine.play_sfx("death", AudioEngine.pan_for_x(int(unit["x"])))
		if _visual_action_tween != null and _visual_action_tween.is_valid(): _visual_action_tween.kill()
		if _character_visual != null: _character_visual.cancel_temporary_visuals()
		if _shadow != null:
			var death_shadow := create_tween().set_parallel(true)
			death_shadow.tween_property(_shadow, "scale", Vector2(1.38, 0.56), 0.22)
			death_shadow.tween_property(_shadow, "position", Vector2(4, 7), 0.22)
			death_shadow.tween_property(_shadow, "color:a", 0.22, DEATH_ACTION_DURATION)
		if _character_visual != null: _character_visual.settle_death(unit.has("turnsSinceDeath"))
		if unit.has("turnsSinceDeath"):
			_sprite.modulate = Color(1, 1, 1, 1)
			if not play_action("death", DEATH_ACTION_DURATION, true):
				# Sem arte de morte pra este personagem: mantém o tingimento
				# cinza como único indicativo visual (comportamento anterior).
				_sprite.modulate = rest_color
		else:
			# Alma já existe na lógica, mas a queda ainda é mostrada antes do token
			# desaparecer visualmente.
			_sprite.modulate = Color.WHITE
			play_action("death", DEATH_ACTION_DURATION, true)
			get_tree().create_timer(DEATH_ACTION_DURATION).timeout.connect(func():
				if unit.get("hp", 0) <= 0 and not unit.has("turnsSinceDeath"): visible = false
			)
	elif just_revived:
		if _uses_warrior_3d(): _warrior_3d.reset_from_death()
		if _shadow != null:
			_shadow.color.a = 0.34
			_shadow.scale = Vector2.ONE
			_shadow.position = Vector2.ZERO
		if _character_visual != null: _character_visual.restore_alive()
		_sprite.modulate = Color.WHITE
		if not play_action("revive", DEATH_ACTION_DURATION, false):
			_restore_idle_pose()
	elif starts_lying:
		_sprite.modulate = Color(1, 1, 1, 1)
		# Duração quase zero: sem som e sem "queda" visível, só posiciona
		# direto no quadro final (deitado) — play_action() tem passo mínimo
		# de 0.04s por quadro, então ainda troca pra pose certa de verdade.
		if not play_action("death", 0.001, true):
			_sprite.modulate = rest_color
	elif hp_dropped:
		if unit.get("deferHitVisual", false):
			unit.erase("deferHitVisual")
		else:
			_flash_hit(rest_color)
			play_action("hit", HIT_ACTION_DURATION, false)
			if _uses_warrior_3d(): _warrior_3d.play_hit()
	elif not moving and alive:
		# Idle parado: só reaplica a pose parada quando não está no meio de
		# uma animação de movimento (senão pisaria no frame de "walk" que
		# _play_walk_cycle está tocando) e quando não está morto de antes
		# (um cadáver já mostrado não deve "ressuscitar" pra pose parada
		# sozinho — mesma ideia do actionPlaying/dying/corpse no JS).
		_restore_idle_pose()
		_sprite.modulate = rest_color
		if _uses_warrior_3d() and not _warrior_3d.is_dead: _warrior_3d.play_idle()
	_update_warrior_3d_visibility()

	_last_hp = unit["hp"]
	# Depois da terceira rodada completa o marcador é apagado e o cadáver
	# vira uma alma no BoardView. Esconde este token para não deixar o corpo
	# antigo desenhado por baixo do fantasminha.
	visible = alive or unit.has("turnsSinceDeath") or unit.get("scriptedRevive", false) or just_died
	if _corpse_badge != null:
		_corpse_badge.visible = not alive and unit.has("turnsSinceDeath")
		if _corpse_badge.visible:
			var is_self_reviving: bool = unit.has("resurrection")
			var elapsed: int = int(unit.get("resurrectionTurns", unit.get("turnsSinceDeath", 0)))
			var total: int = int(unit["resurrection"].get("afterTurns", 3)) if is_self_reviving else 3
			var rounds_left := maxi(0, total - elapsed)
			_corpse_badge.text = "💀 %d" % rounds_left
			_corpse_badge.tooltip_text = "%d rodada(s) para ressuscitar" % rounds_left if is_self_reviving else "%d rodada(s) para virar alma" % rounds_left
	if _cage_badge != null:
		_cage_badge.visible = alive and caged
		if _cage_badge.visible:
			var is_bard: bool = unit.get("spriteKey", "") == "bardo"
			_cage_badge.text = "🔒 Preso" if is_bard else "🔒 Presa"
			_cage_badge.tooltip_text = "Bardo preso. Pare ao lado dele para libertá-lo." if is_bard else "Maga presa. Pare ao lado dela para libertá-la."
	if _cage_sprite != null:
		# Some sozinha assim que caged vira false (ver GameState._release_caged_mage).
		_cage_sprite.visible = alive and caged

	_name_label.text = unit.get("name", "") if unit.get("riderName", "") == "" else "%s + %s" % [unit.get("name", ""), unit.get("riderName", "")]
	_name_label.visible = not is_riding
	_hp_label.text = "%d/%d" % [maxi(unit["hp"], 0), unit["maxHp"]]
	_hp_label.visible = false
	var hp_ratio: float = float(unit["hp"]) / float(unit["maxHp"]) if unit["maxHp"] > 0 else 0.0
	if _uses_warrior_3d(): _warrior_3d.set_health_ratio(hp_ratio)
	_hp_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3) if hp_ratio > 0.5 else (Color(0.95, 0.8, 0.2) if hp_ratio > 0.2 else Color(0.95, 0.3, 0.3)))
	_hp_bar.set_values(int(unit.get("hp", 0)), int(unit.get("maxHp", 0)))
	_hp_bar.visible = alive and not is_riding
	_mp_bar.set_values(int(unit.get("mp", 0)), int(unit.get("maxMp", 0)))
	_mp_bar.visible = alive and unit.has("maxMp") and not is_riding
	_water_overlay.visible = alive and not unit.get("flying", false) and _unit_is_on_water()
	_refresh_status_vfx()
	queue_redraw()
	_sync_process_active()

## `_process()` só precisa rodar enquanto houver algo que realmente muda
## quadro a quadro nesta unidade (respiração idle dos bichos do SPD, chama
## de "queimando", VFX procedural de status como veneno/lentidão). Sem
## nenhum desses, `_process` não tem nada pra fazer — cadáveres, almas
## pendentes e unidades paradas sem status ficam com processamento
## desligado. Tweens de movimento/ataque/dano continuam rodando sozinhos
## (não dependem de `_process` do node), então desligar aqui não trava
## nenhuma animação em andamento.
func _sync_process_active() -> void:
	var alive: bool = unit.get("hp", 0) > 0
	var needs_process: bool = alive and (_character_visual != null or _has_status("burned") or _procedural_status_vfx != "" or _spd_idle_running)
	set_process(needs_process)

## Antes checava só a lista fixa de água do Campo (BoardLayout.TERRAIN_LAYOUT),
## então o ripple nunca disparava certo em outros cenários com água própria
## (ex.: o rio do Vale de Lua/Horda). Usa o terreno REAL do cenário ativo.
func _unit_is_on_water() -> bool:
	var board := get_parent() as BoardView
	if board == null or board.state == null:
		return false
	var terrain = board.state.terrain_at(int(unit.get("x", -1)), int(unit.get("y", -1)))
	return terrain != null and String(terrain.get("type", "")) == "water"

## `speed_scale` alonga a duração por tile sem mudar a lógica de movimento —
## usado pela IA (main.gd) pra deixar o deslocamento mais legível (pedido do
## usuário: ~0.18-0.25s por tile em vez de ~0.15s). Jogador continua em 1.0.
func animate_path(path_tiles: Array, speed_scale: float = 1.0) -> void:
	if path_tiles.is_empty(): return
	if not _begin_premium_action(PREMIUM_ANIMATION.Priority.MOVE): return
	if _move_tween != null and _move_tween.is_valid(): _move_tween.kill()
	_path_animating = true
	if _uses_warrior_3d(): _warrior_3d.play_walk()
	if _character_visual != null and _character_visual.body_weight() in ["heavy", "giant"]: _spawn_ground_effect(DUST_SCENE)
	_move_tween = create_tween()
	var move_timing: Dictionary = PREMIUM_ANIMATION.for_weight(_character_visual.body_weight() if _character_visual != null else "medium")
	_move_tween.tween_property(_visual_root, "scale", Vector2(1.025, 0.975), float(move_timing["start"])).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var previous := position
	for tile in path_tiles:
		var footprint_width := maxi(1, int(unit.get("footprintWidth", unit.get("footprintSize", 1))))
		var footprint_height := maxi(1, int(unit.get("footprintHeight", unit.get("footprintSize", 1))))
		var next_pos := Vector2(tile["x"], tile["y"]) * BoardView.TILE_SIZE + Vector2(footprint_width, footprint_height) * BoardView.TILE_SIZE * 0.5 + _mount_offset()
		var segment_distance := previous.distance_to(next_pos) / BoardView.TILE_SIZE
		_move_tween.tween_callback(_set_visual_move_direction.bind((next_pos - previous).normalized()))
		var segment = _move_tween.tween_property(self, "position", next_pos, maxf(0.12, 0.15 * segment_distance) * speed_scale)
		segment.set_trans(Tween.TRANS_CUBIC)
		segment.set_ease(Tween.EASE_IN if previous == position else (Tween.EASE_OUT if tile == path_tiles[-1] else Tween.EASE_IN_OUT))
		previous = next_pos
	_play_walk_cycle(_movement_direction(previous - position), maxf(0.15, path_tiles.size() * 0.15) * speed_scale)
	AudioEngine.play_sfx("move", AudioEngine.pan_for_x(int(path_tiles[-1]["x"])))
	_move_tween.tween_callback(_finish_path_animation)

func _finish_path_animation() -> void:
	_path_animating = false
	if _uses_warrior_3d():
		_warrior_3d.play_idle()
		_warrior_3d.movement_animation_finished.emit()
	if _character_visual != null and _character_visual.body_weight() in ["heavy", "giant"]: _spawn_ground_effect(DUST_SCENE)
	_play_visual_landing()
	_restore_idle_pose()
	var settle := PREMIUM_ANIMATION.for_weight(_character_visual.body_weight() if _character_visual != null else "medium")
	var stop_tween := create_tween().set_parallel(true)
	stop_tween.tween_property(_visual_root, "position", Vector2.ZERO, float(settle["settle"])).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stop_tween.tween_property(_visual_root, "rotation", 0.0, float(settle["settle"]))
	stop_tween.tween_property(_visual_root, "scale", Vector2.ONE, float(settle["settle"]))
	stop_tween.set_parallel(false).tween_callback(_finish_premium_action.bind(PREMIUM_ANIMATION.Priority.MOVE))
	walk_finished.emit()

func _refresh_status_vfx() -> void:
	if _status_sprite == null: return
	var active := ""
	var procedural := ""
	for wanted in STATUS_PRIORITY:
		for effect in unit.get("statusEffects", []):
			if effect.get("type", "") == wanted:
				if STATUS_STRIPS.has(wanted) and active == "": active = wanted
				if wanted == "paralyzed" and procedural == "": procedural = "frozen"
				elif wanted in ["poison", "slowed", "weakened", "evasive", "swiftFeet"] and procedural == "": procedural = wanted
	if procedural != _procedural_status_vfx:
		if _procedural_status_vfx == "frozen" and procedural == "":
			var shatter := _spawn_ground_effect(HIT_SPARK_SCENE)
			if shatter != null:
				shatter.position = position + Vector2(0, 12)
				shatter.modulate = Color("9de9ff")
				shatter.scale = Vector2.ONE * 0.75
		_procedural_status_vfx = procedural
		queue_redraw()
	if active == _current_status_vfx:
		_status_sprite.visible = active != "" and unit.get("hp", 0) > 0
		return
	_current_status_vfx = active
	_status_sprite.visible = false
	if active == "" or unit.get("hp", 0) <= 0: return
	var spec: Array = STATUS_STRIPS[active]
	var path := "res://assets/vfx/%s" % spec[0]
	if not ResourceLoader.exists(path): return
	var texture := load(path) as Texture2D
	if texture == null: return
	var columns := int(spec[1])
	var rows := int(spec[2])
	var frame_size := Vector2(texture.get_width() / columns, texture.get_height() / rows)
	var frames := SpriteFrames.new()
	frames.add_animation(&"status")
	frames.set_animation_loop(&"status", true)
	frames.set_animation_speed(&"status", 10.0)
	for row in rows:
		for column in columns:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(column, row) * frame_size, frame_size)
			frames.add_frame(&"status", atlas)
	_status_sprite.sprite_frames = frames
	_status_sprite.scale = Vector2.ONE * (82.0 / maxf(frame_size.x, frame_size.y))
	_status_sprite.visible = true
	_status_sprite.play(&"status")

func _animate_move(target_pos: Vector2, direction: String) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	if _uses_weighted_visuals(): _spawn_ground_effect(DUST_SCENE)
	if _uses_weighted_visuals(): _set_visual_move_direction((target_pos - position).normalized())
	_move_tween.tween_property(self, "position", target_pos, MOVE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_callback(func():
		if _uses_weighted_visuals():
			_spawn_ground_effect(DUST_SCENE)
			_play_visual_landing()
	)
	_play_walk_cycle(direction, MOVE_DURATION)

func _spawn_ground_effect(scene: PackedScene) -> Node2D:
	var parent_node := get_parent()
	if parent_node == null: return null
	var effect := scene.instantiate() as Node2D
	parent_node.add_child(effect)
	effect.position = position + Vector2(0, 25)
	return effect

func _set_visual_move_direction(direction: Vector2) -> void:
	if direction != Vector2.ZERO: _visual_move_direction = direction
	if _uses_warrior_3d() and direction != Vector2.ZERO:
		_warrior_3d.face_direction(Vector3(direction.x, 0.0, direction.y), true)

func _play_visual_landing() -> void:
	if _character_visual == null: return
	_visual_action_busy = true
	var landing_strength: float = float(_character_visual.profile["landing"]) * float(_character_visual.visual_value("stop_overshoot", 1.0))
	var recovery: float = float(_character_visual.visual_value("recovery", _character_visual.profile["recovery"]))
	var landing := create_tween()
	landing.tween_property(_visual_root, "position", _visual_move_direction * (1.8 * landing_strength) + Vector2(0, 1.15 * landing_strength), 0.055).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	landing.parallel().tween_property(_visual_root, "scale", Vector2(1.0 + 0.018 / landing_strength, 1.0 - 0.022 / landing_strength), 0.055)
	landing.tween_property(_visual_root, "position", Vector2.ZERO, recovery).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	landing.parallel().tween_property(_visual_root, "scale", Vector2.ONE, recovery)
	landing.parallel().tween_property(_visual_root, "rotation", 0.0, recovery)
	landing.tween_callback(_character_visual.pulse_contact.bind(landing_strength))
	landing.tween_callback(func(): _visual_action_busy = false)

## Pisca vermelho e sacode de leve quando a unidade perde HP desde o último
## refresh() — puramente cosmético, não representa nenhuma regra nova.
func _flash_hit(rest_color: Color, critical: bool = false) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	# SlimeSprite.blood() = 0xFF88CC44 no SPD: fluido verde, não sangue
	# vermelho — preserva a identidade visual da espécie no flash de dano.
	var flash_color := Color(0.55, 2.1, 0.5) if unit.get("spriteKey", "") == "spd_slime" else (Color(2.8, 0.72, 0.48) if critical else Color(2.2, 0.35, 0.35))
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", flash_color, FLASH_DURATION)
	_flash_tween.parallel().tween_property(_sprite, "position", _sprite.position + Vector2(4, 0), FLASH_DURATION * 0.5)
	_flash_tween.tween_property(_sprite, "modulate", rest_color, FLASH_DURATION * 2.0)
	_flash_tween.parallel().tween_property(_sprite, "position", Vector2.ZERO, FLASH_DURATION * 1.5)

## Tenta a pose parada na direção que a unidade está olhando (down/back/
## left/right), com "down" como padrão garantido (ver assets/README.md:
## todo personagem tem pelo menos `<chave>_idle_down_1.png`). Devolve
## [Texture2D, flip_h] — só espelha a pose "down" quando não existe arte
## dedicada de esquerda/direita pro personagem.
func _idle_texture() -> Array:
	var sprite_key: String = _visual_sprite_key()
	if ANIMAL_SPECS.has(sprite_key):
		var mounted_path := _mounted_pose_path(_facing_direction())
		if mounted_path != "":
			return [load(mounted_path), false, mounted_path]
		var key := _animal_directional_key("idle", _facing_direction())
		var anim: Array = ANIMAL_SPECS[sprite_key]["anims"].get(key, [])
		if anim.is_empty(): return [null, false]
		var rect = anim[0][_spd_idle_frame_i % anim[0].size()]
		return [_animal_frame_texture(sprite_key, rect), _animal_should_flip(key), rect]
	if SPD_MOB_ANIMS.has(sprite_key):
		var frames: Array = SPD_MOB_ANIMS[sprite_key]["idle"]["frames"]
		var frame_index: int = frames[_spd_idle_frame_i % frames.size()]
		return [_spd_frame_texture(sprite_key, frame_index), unit.get("facing", {}).get("dx", 0) < 0]
	if SPD_MOB_SPECS.has(sprite_key):
		# spd_goo: sem sequência de animação pedida/portada ainda, mantém o
		# quadro estático já existente (2 = forma "cheia", não a comprimida).
		var spec: Array = SPD_MOB_SPECS[sprite_key]
		var idle_frame := 2 if sprite_key == "spd_goo" else 0
		return [_spd_frame_texture(sprite_key, idle_frame), unit.get("facing", {}).get("dx", 0) < 0]
	var folder: String = SpriteManifest.SPRITE_MANIFEST.get(sprite_key, "")
	if folder == "":
		return [null, false]
	var facing: Dictionary = unit.get("facing", {"dx": 1, "dy": 0})

	if facing.get("dy", 0) < 0:
		var back_path := "%s/%s_idle_back_1.png" % [folder, sprite_key]
		if ResourceLoader.exists(back_path):
			return [load(back_path), false]

	if facing.get("dx", 0) != 0:
		var side: String = "right" if facing["dx"] > 0 else "left"
		var side_path := "%s/%s_idle_%s_1.png" % [folder, sprite_key, side]
		if ResourceLoader.exists(side_path):
			return [load(side_path), false]

	var down_path := "%s/%s_idle_down_1.png" % [folder, sprite_key]
	if ResourceLoader.exists(down_path):
		var flip: bool = facing.get("dx", 0) < 0
		return [load(down_path), flip]
	return [null, false]

## Recorta o quadro `frame_index` da spritesheet real do SPD (linha 0 sempre,
## já que nenhum índice usado por SPD_MOB_ANIMS ultrapassa a contagem de
## colunas da própria imagem — ver auditoria em ASSET_SOURCES.md).
func _spd_frame_texture(sprite_key: String, frame_index: int) -> AtlasTexture:
	var spec: Array = SPD_MOB_SPECS[sprite_key]
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = load("res://assets/third_party/shattered_pixel_dungeon/sprites/%s" % spec[0])
	var frame_w: int = spec[1]
	var frame_h: int = spec[2]
	var cols: int = maxi(1, int(atlas_texture.atlas.get_width()) / frame_w)
	atlas_texture.region = Rect2((frame_index % cols) * frame_w, (frame_index / cols) * frame_h, frame_w, frame_h)
	return atlas_texture

func _restore_idle_pose() -> void:
	_spd_idle_running = SPD_MOB_ANIMS.has(_visual_sprite_key()) or ANIMAL_SPECS.has(_visual_sprite_key())
	var result := _idle_texture()
	if result.size() >= 3:
		_apply_animal_texture(_visual_sprite_key(), result[0], result[2], result[1])
	else:
		_apply_texture(result[0], result[1])
	# Chamado também a partir de callbacks de tween (fim de ataque/andar), fora
	# de refresh() — religa _process aqui se a respiração idle voltou a valer.
	_sync_process_active()

## Cache do retângulo de pixels REALMENTE visíveis (alpha acima do limiar)
## de uma textura de referência — computado uma vez por chave e reaproveitado
## depois, então nem reprocessa pixel a pixel toda hora nem faz o personagem
## "pular" de tamanho/posição entre poses (mesmo recorte sempre pra quem
## compartilha a mesma chave). Duas chamadas abaixo usam chaves diferentes
## por bom motivo: _apply_texture cacheia por spriteKey (canvas uniforme
## entre poses, ver comentário de DISPLAY_HEIGHT) — _apply_animal_texture
## (PNGs "já recortados por ação") cacheia por caminho de arquivo, porque
## aqui cada ação pode ter seu próprio canvas (ver comentário original nela).
static var _visible_bounds_cache: Dictionary = {}

static func _get_visible_bounds(cache_key: String, reference_texture: Texture2D) -> Rect2:
	if _visible_bounds_cache.has(cache_key):
		return _visible_bounds_cache[cache_key]
	var bounds := Rect2(Vector2.ZERO, reference_texture.get_size())
	var image := reference_texture.get_image()
	if image != null:
		if image.is_compressed(): image.decompress()
		var w := image.get_width()
		var h := image.get_height()
		var min_x := w
		var min_y := h
		var max_x := -1
		var max_y := -1
		const ALPHA_THRESHOLD := 10.0 / 255.0
		for y in h:
			for x in w:
				if image.get_pixel(x, y).a > ALPHA_THRESHOLD:
					if x < min_x: min_x = x
					if x > max_x: max_x = x
					if y < min_y: min_y = y
					if y > max_y: max_y = y
		if max_x >= min_x and max_y >= min_y:
			bounds = Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	_visible_bounds_cache[cache_key] = bounds
	return bounds

## Offset (em pixels de TEXTURA, aplicado antes da escala pelo próprio
## Sprite2D) que centraliza o BBOX visível — não o canvas inteiro — no ponto
## (0,0) do nó. _sprite.position sempre descansa em Vector2.ZERO (recoil/
## flash/lunge sempre voltam pra lá, ver _flash_hit), e (0,0) É o centro do
## tile (ver refresh(): target_pos aponta o TOKEN pro centro do tile; o
## sprite não tem posição própria além dessa). Por isso corrigir só o
## OFFSET, nunca a position, centraliza o personagem sem mexer em nenhuma
## animação existente.
static func _centering_offset(bounds: Rect2, texture: Texture2D) -> Vector2:
	var tex_size := Vector2(texture.get_width(), texture.get_height())
	var bbox_center := bounds.position + bounds.size * 0.5
	return tex_size * 0.5 - bbox_center

func _apply_texture(texture: Texture2D, flip: bool, source_path: String = "") -> void:
	if texture == null:
		return
	_sprite.texture = texture
	var sprite_key: String = unit.get("spriteKey", "")
	var scale_factor: float = DISPLAY_HEIGHT / texture.get_height()
	if SPD_MOB_SPECS.has(sprite_key):
		scale_factor = DISPLAY_HEIGHT / SPD_MOB_SCALE_REFERENCE_HEIGHT
	var footprint_w := maxi(1, int(unit.get("footprintWidth", unit.get("footprintSize", 1))))
	var footprint_h := maxi(1, int(unit.get("footprintHeight", unit.get("footprintSize", 1))))
	if footprint_w > 1 or footprint_h > 1:
		# Pedido do usuário: unidade multitile (Goo grande, Salamandra, Dragão
		# Vermelho) escalada pelo bbox REAL de pixel visível (mesma técnica de
		# _get_visible_bounds/_centering_offset usada no caso 1x1 abaixo) até
		# a altura exata da caixa footprint_h x footprint_h — pés colados na
		# base da caixa, cabeça encostando no topo, maior que os personagens
		# de 1 quadrado por construção (não mais um fator de preenchimento
		# "no olho" por spriteKey).
		var bounds := _get_visible_bounds(sprite_key, texture)
		var box_size := Vector2(footprint_w, footprint_h) * BoardView.TILE_SIZE
		var box_height := box_size.y
		# Goo, Salamandra e Dragão são criaturas grandes 2x2. O cálculo
		# anterior preenchia apenas a altura, deixando largura vazia dentro dos
		# quatro quadrados. Para esses três, usamos a maior escala necessária
		# para ocupar também a largura, mantendo a proporção do sprite.
		if sprite_key in ["spd_goo", "tower_salamander", "dragon"]:
			var fill_box := box_size - Vector2.ONE * 8.0
			scale_factor = maxf(fill_box.y / bounds.size.y, fill_box.x / bounds.size.x)
			if sprite_key in ["tower_salamander", "dragon"]:
				scale_factor *= 0.85
		else:
			scale_factor = box_height / bounds.size.y
		var tex_size := Vector2(texture.get_width(), texture.get_height())
		var bbox_bottom_center := Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.position.y + bounds.size.y)
		# offset é aplicado em espaço de TEXTURA (antes do scale, ver
		# _centering_offset) — por isso o deslocamento mundo->textura abaixo
		# divide por scale_factor: quero o pé (base do bbox) exatamente na
		# borda inferior da caixa (metade de box_height abaixo do centro do
		# token, que é onde target_pos ancora a unidade — ver refresh()).
		_sprite.offset = tex_size * 0.5 - bbox_bottom_center + Vector2(0, (box_height * 0.5) / scale_factor)
		_sprite.scale = Vector2(scale_factor, scale_factor)
		_sprite.flip_h = flip
		return
	if SPRITE_SCALE_OVERRIDE.has(source_path):
		scale_factor *= float(SPRITE_SCALE_OVERRIDE[source_path])
	_sprite.offset = _centering_offset(_get_visible_bounds(sprite_key, texture), texture)
	_sprite.scale = Vector2(scale_factor, scale_factor)
	_sprite.flip_h = flip

## `frame` é um retângulo [x,y,w,h] (bichos do SPD, recortados de uma folha
## única) OU o caminho de um PNG já recortado por quadro (humanoides da
## Torre — ver AnimalSpriteCatalog._folder_spec()).
func _animal_frame_texture(sprite_key: String, frame) -> Texture2D:
	if typeof(frame) == TYPE_STRING:
		return load(frame) as Texture2D
	var texture := AtlasTexture.new()
	texture.atlas = load(AnimalSpriteCatalog.SHEET_ROOT + ANIMAL_SPECS[sprite_key]["sheet"])
	texture.region = Rect2(frame[0], frame[1], frame[2], frame[3])
	return texture

func _apply_animal_texture(sprite_key: String, texture: Texture2D, frame, flip: bool) -> void:
	if texture == null: return
	_sprite.texture = texture
	var footprint_w := maxi(1, int(unit.get("footprintWidth", unit.get("footprintSize", 1))))
	var footprint_h := maxi(1, int(unit.get("footprintHeight", unit.get("footprintSize", 1))))
	if footprint_w > 1 or footprint_h > 1:
		# Usa o bbox visível de cada frame, ignorando transparência do canvas.
		# Isso mantém idle, movimento, ataque, hit e morte centrados na área 2x2.
		var bounds_key := String(frame) if typeof(frame) == TYPE_STRING else "%s:%s" % [sprite_key, str(frame)]
		var bounds := _get_visible_bounds(bounds_key, texture)
		var box_size := Vector2(footprint_w, footprint_h) * BoardView.TILE_SIZE
		var fill_box := box_size - Vector2.ONE * 8.0
		var scale_factor := maxf(fill_box.y / maxf(bounds.size.y, 1.0), fill_box.x / maxf(bounds.size.x, 1.0))
		if sprite_key in ["tower_salamander", "dragon"]:
			scale_factor *= 0.85
		# Cadáver deitado (quadro "death"): é largo e baixo, então preencher a
		# ALTURA da caixa o fazia transbordar bem além dos 2x2 quadrados do Troll.
		# Aqui o desenho inteiro tem que caber DENTRO da área do footprint.
		if typeof(frame) == TYPE_STRING and String(frame).contains("death"):
			scale_factor = minf(scale_factor, minf(fill_box.x / maxf(bounds.size.x, 1.0), fill_box.y / maxf(bounds.size.y, 1.0)))
		var tex_size := Vector2(texture.get_width(), texture.get_height())
		var bbox_bottom_center := Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.position.y + bounds.size.y)
		_sprite.scale = Vector2.ONE * scale_factor
		_sprite.offset = tex_size * 0.5 - bbox_bottom_center + Vector2(0, (box_size.y * 0.5) / scale_factor)
		_sprite.flip_h = flip
		return
	if typeof(frame) == TYPE_STRING and String(frame).contains("/mounted_idle_"):
		_apply_mounted_texture(texture)
		return
	if typeof(frame) == TYPE_STRING:
		# PNG já recortado por ação: escala pra altura de exibição padrão e
		# centraliza pelo bbox REAL de pixel visível desse arquivo (cacheado
		# pelo próprio caminho, não pelo spriteKey — cada ação pode ter seu
		# próprio canvas, ver ASSET_SOURCES.md).
		var scale_factor: float = DISPLAY_HEIGHT / texture.get_height()
		scale_factor *= float(ANIMAL_SPECS[sprite_key].get("frame_scale", {}).get(frame, 1.0))
		_sprite.scale = Vector2.ONE * scale_factor
		_sprite.offset = _centering_offset(_get_visible_bounds(frame, texture), texture)
	else:
		_sprite.scale = Vector2.ONE * float(ANIMAL_SPECS[sprite_key]["scale"])
		# Ancora o centro inferior da region no tile. Como todas as regions têm
		# sua própria altura, isso elimina jitter mesmo em sequências irregulares.
		_sprite.offset = Vector2(0.0, -float(frame[3]) * 0.5)
	_sprite.flip_h = flip

func _apply_animal_frame(sprite_key: String, frame, flip: bool) -> void:
	_apply_animal_texture(sprite_key, _animal_frame_texture(sprite_key, frame), frame, flip)

func _animal_directional_key(action: String, direction: String) -> String:
	var anims: Dictionary = ANIMAL_SPECS[_visual_sprite_key()]["anims"]
	var exact := "%s_%s" % [action, direction]
	if anims.has(exact): return exact
	if direction in ["left", "right"] and anims.has(action + "_side"): return action + "_side"
	if anims.has(action + "_down"): return action + "_down"
	return action

func _animal_should_flip(anim_key: String) -> bool:
	if anim_key.ends_with("_left") or anim_key.ends_with("_right"): return false
	return _facing_direction() == "left"

func _apply_frame(path: String, flip: bool) -> void:
	_apply_texture(load(path), flip, path)

func _tween_apply_frame(path: String, flip: bool, token: int) -> void:
	if _action_token == token:
		_apply_frame(path, flip)

func _tween_restore_idle(token: int) -> void:
	if _action_token == token and unit.get("hp", 0) > 0:
		_restore_idle_pose()

func _sprite_folder() -> String:
	return SpriteManifest.SPRITE_MANIFEST.get(unit.get("spriteKey", ""), "")

## Caminho do frame `n` de `action`/`direction` — tenta primeiro o formato
## com direção (`<chave>_<acao>_<direcao>_<n>.png`) e cai pro formato sem
## direção (`<chave>_<acao>_<n>.png`) quando não existir, exatamente como
## assets/README.md descreve pro detector de sprites do jogo original.
func _frame_path(action: String, direction: String, n: int) -> String:
	var folder := _sprite_folder()
	if folder == "":
		return ""
	var key: String = unit.get("spriteKey", "")
	if direction != "":
		var dir_path := "%s/%s_%s_%s_%d.png" % [folder, key, action, direction, n]
		if ResourceLoader.exists(dir_path):
			return dir_path
	var flat_path := "%s/%s_%s_%d.png" % [folder, key, action, n]
	if ResourceLoader.exists(flat_path):
		return flat_path
	return ""

## Detecta quantos frames existem pra essa ação/direção (tenta _1, _2, _3...
## até não achar mais nenhum) — mesma ideia do detectSprites() do JS
## original, então funciona com qualquer quantidade de frames por ação.
func _frames_for(action: String, direction: String) -> Array:
	var frames: Array = []
	var n := 1
	while true:
		var p := _frame_path(action, direction, n)
		if p == "":
			break
		frames.append(p)
		n += 1
	return frames

func _facing_direction() -> String:
	var facing: Dictionary = unit.get("facing", {"dx": 1, "dy": 0})
	if facing.get("dy", 0) < 0:
		return "up"
	if facing.get("dx", 0) < 0:
		return "left"
	if facing.get("dx", 0) > 0:
		return "right"
	return "down"

func _movement_direction(delta: Vector2) -> String:
	if absf(delta.x) > absf(delta.y):
		return "right" if delta.x > 0 else "left"
	if delta.y != 0:
		return "down" if delta.y > 0 else "up"
	return _facing_direction()

## Toca a sequência de frames de `action_key` (ex: "attack"/"hit"/"death")
## espalhada por `duration_sec`, equivalente a playSpriteAction do JS
## original (game.js:1535) — devolve false sem tocar nada se o personagem
## não tiver arte pra essa ação (quem chamou decide o fallback visual).
## `hold_last` mantém o sprite parado no frame final (usado pela morte) em
## vez de voltar pra pose parada quando a sequência termina.
func play_action(action_key: String, duration_sec: float, hold_last: bool = false, fallback_action_key: String = "") -> bool:
	# Dupla montada: só existe a pose idle montada, sem quadros de ataque/hit da
	# Vestruz sozinha (o flash de dano e o recuo continuam valendo).
	if unit.get("riderSpriteKey", "") != "" and action_key != "death":
		return false
	var sprite_key: String = _visual_sprite_key()
	if ANIMAL_SPECS.has(sprite_key):
		if _play_animal_action(sprite_key, action_key, hold_last): return true
		if fallback_action_key != "": return _play_animal_action(sprite_key, fallback_action_key, hold_last)
		return false
	if SPD_MOB_ANIMS.has(sprite_key):
		if _play_spd_action(sprite_key, action_key, hold_last):
			return true
		if fallback_action_key != "":
			return _play_spd_action(sprite_key, fallback_action_key, hold_last)
		return false
	var direction := _facing_direction()
	var frames := _frames_for(action_key, direction)
	if frames.is_empty() and fallback_action_key != "":
		frames = _frames_for(fallback_action_key, direction)
	if frames.is_empty():
		return false
	var flip: bool = unit.get("facing", {}).get("dx", 0) < 0
	_action_token += 1
	var token := _action_token
	var weights := PREMIUM_ANIMATION.frame_weights(action_key, frames.size())
	var total_weight: float = 0.0
	for weight in weights: total_weight += weight
	_apply_frame(frames[0], flip)
	var tween := create_tween()
	for i in range(1, frames.size()):
		var weighted_step := maxf(duration_sec * weights[i - 1] / maxf(total_weight, 0.01), 0.035)
		tween.tween_interval(weighted_step)
		tween.tween_callback(_tween_apply_frame.bind(frames[i], flip, token))
	if not hold_last:
		tween.tween_interval(maxf(duration_sec * weights[-1] / maxf(total_weight, 0.01), 0.035))
		tween.tween_callback(_tween_restore_idle.bind(token))
	return true

## Ciclo de "walk" (2+ frames alternando) durante a janela do tween de
## movimento — o Godot anima o trajeto inteiro (possivelmente vários tiles)
## num tween de posição só, então aqui o ciclo repete em loop por
## `duration_sec` em vez de tocar uma vez só, diferente de play_action().
## Toca attack/death dos bichos do SPD com o FPS/loop REAIS do Java original
## (SPD_MOB_ANIMS), em vez de espalhar os frames por `duration_sec` como o
## play_action() genérico faz pros personagens com PNG por frame. Devolve
## false sem tocar nada quando a ação não existe pra essa espécie (ex.: "hit"
## não tem clipe próprio no SPD — quem chamou já trata isso com _flash_hit).
func _play_spd_action(sprite_key: String, action_key: String, hold_last: bool) -> bool:
	var anim: Dictionary = SPD_MOB_ANIMS.get(sprite_key, {}).get(action_key, {})
	if anim.is_empty():
		return false
	_spd_idle_running = false
	var frames: Array = anim["frames"]
	var step: float = 1.0 / float(anim["fps"])
	var flip: bool = unit.get("facing", {}).get("dx", 0) < 0
	_action_token += 1
	var token := _action_token
	_apply_texture(_spd_frame_texture(sprite_key, frames[0]), flip)
	var tween := create_tween()
	for i in range(1, frames.size()):
		tween.tween_interval(step)
		tween.tween_callback(_tween_apply_spd_frame.bind(sprite_key, frames[i], flip, token))
	if not hold_last:
		tween.tween_interval(step)
		tween.tween_callback(_tween_restore_spd_idle.bind(token))
	return true

func _play_animal_action(sprite_key: String, action_key: String, hold_last: bool) -> bool:
	var anim: Array = ANIMAL_SPECS[sprite_key]["anims"].get(action_key, [])
	if anim.is_empty(): return false
	_spd_idle_running = false
	var frames: Array = anim[0]
	var step := 1.0 / float(anim[1])
	var flip := _facing_direction() == "left"
	_action_token += 1
	var token := _action_token
	_apply_animal_frame(sprite_key, frames[0], flip)
	# Ação de 1 frame só + hold_last (ex.: "death" de um personagem sem várias
	# poses de cadáver, como Arqueiro/Bardo): nada mais pra animar depois do
	# frame único já aplicado acima — criar o Tween mesmo assim resultava num
	# "Tween started with no Tweeners" (nenhum tween_interval/tween_callback
	# encadeado), erro real do engine que os testes acusavam como falha.
	if frames.size() <= 1 and hold_last:
		return true
	var tween := create_tween()
	for i in range(1, frames.size()):
		tween.tween_interval(step)
		tween.tween_callback(_tween_apply_animal_frame.bind(sprite_key, frames[i], flip, token))
	if not hold_last:
		tween.tween_interval(step)
		tween.tween_callback(_tween_restore_spd_idle.bind(token))
	return true

func _tween_apply_animal_frame(sprite_key: String, rect, flip: bool, token: int) -> void:
	if _action_token == token: _apply_animal_frame(sprite_key, rect, flip)

func _tween_apply_spd_frame(sprite_key: String, frame_index: int, flip: bool, token: int) -> void:
	if _action_token == token:
		_apply_texture(_spd_frame_texture(sprite_key, frame_index), flip)

func _tween_restore_spd_idle(token: int) -> void:
	if _action_token == token and unit.get("hp", 0) > 0:
		_restore_idle_pose()

## Ciclo de "walk" dos bichos do SPD no FPS real (run em SPD_MOB_ANIMS),
## repetido em loop pela janela do tween de movimento — mesma ideia de
## _play_walk_cycle() pros personagens de PNG por frame, mas na timing real
## em vez de esticar os frames pra caber em duration_sec.
func _play_spd_walk(sprite_key: String, duration_sec: float) -> bool:
	var anim: Dictionary = SPD_MOB_ANIMS.get(sprite_key, {}).get("walk", {})
	if anim.is_empty():
		return false
	_spd_idle_running = false
	var frames: Array = anim["frames"]
	var step: float = 1.0 / float(anim["fps"])
	var flip: bool = unit.get("facing", {}).get("dx", 0) < 0
	_action_token += 1
	var token := _action_token
	var steps: int = maxi(1, int(ceil(duration_sec / step)))
	var tween := create_tween()
	for i in steps:
		tween.tween_callback(_tween_apply_spd_frame.bind(sprite_key, frames[i % frames.size()], flip, token))
		tween.tween_interval(step)
	tween.tween_callback(_tween_restore_spd_idle.bind(token))
	return true

func _play_walk_cycle(direction: String, duration_sec: float) -> void:
	var sprite_key: String = unit.get("spriteKey", "")
	if unit.get("riderSpriteKey", "") != "" and _show_mounted_pose(direction):
		return
	if ANIMAL_SPECS.has(sprite_key):
		_play_animal_walk(sprite_key, direction, duration_sec)
		return
	if SPD_MOB_ANIMS.has(sprite_key):
		_play_spd_walk(sprite_key, duration_sec)
		return
	var frames := _frames_for("walk", direction)
	if frames.is_empty():
		return
	_action_token += 1
	var token := _action_token
	var step := 0.12
	var steps: int = maxi(1, int(ceil(duration_sec / step)))
	var tween := create_tween()
	for i in range(steps):
		tween.tween_callback(_tween_apply_frame.bind(frames[i % frames.size()], false, token))
		tween.tween_interval(step)
	tween.tween_callback(_tween_restore_idle.bind(token))

func _play_animal_walk(sprite_key: String, direction: String, duration_sec: float) -> void:
	var key := _animal_directional_key("walk", direction)
	var anim: Array = ANIMAL_SPECS[sprite_key]["anims"].get(key, [])
	if anim.is_empty(): return
	_spd_idle_running = false
	var frames: Array = anim[0]
	var step := 1.0 / float(anim[1])
	var flip := direction == "left" and key.ends_with("_side")
	_action_token += 1
	var token := _action_token
	var steps := maxi(1, int(ceil(duration_sec / step)))
	var tween := create_tween()
	for i in steps:
		tween.tween_callback(_tween_apply_animal_frame.bind(sprite_key, frames[i % frames.size()], flip, token))
		tween.tween_interval(step)
	tween.tween_callback(_tween_restore_spd_idle.bind(token))

## Voo longo até `target_pos` (Chute do Dragão do Monge): mantém a pose
## `action_key` (arte da voadora) congelada durante todo o trajeto, em arco
## suave (sobe até a metade e desce), e só devolve a pose parada ao pousar.
## Marca _path_animating pra refresh() não iniciar o passo de caminhada
## normal pro mesmo deslocamento.
func play_flight(target_pos: Vector2, duration: float, action_key: String = "voadora") -> void:
	if _move_tween != null and _move_tween.is_valid(): _move_tween.kill()
	_path_animating = true
	play_action(action_key, duration, true)
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_callback(func():
		_path_animating = false
		if unit.get("hp", 0) > 0: _restore_idle_pose()
	)
	if _visual_root != null:
		var arc := create_tween()
		arc.tween_property(_visual_root, "position:y", -36.0, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		arc.tween_property(_visual_root, "position:y", 0.0, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## Chamado pela view (main.gd) quando esta unidade acerta um golpe com
## arma — equivalente a playSpriteAction(attacker, spriteActionKey, ...).
## `action_key` permite que um item escolha a arte do próprio golpe (campo
## "spriteAction" em weapons.gd/spells.gd — ex.: "soco"/"chute" do Monge);
## sem ele, todo mundo continua usando "attack" como antes, e qualquer
## personagem sem arte pra essa ação cai de volta em "attack".
func play_attack(duration_sec: float = ATTACK_ACTION_DURATION, action_key: String = "attack") -> bool:
	if _uses_warrior_3d(): return _warrior_3d.play_attack_light()
	return play_action(action_key, duration_sec, false, "attack")

## Ponto visual de saída reutilizável para flechas, virotes, tiros e magia.
## O deslocamento acompanha a direção sem alterar a posição lógica no grid.
func projectile_visual_origin(target_world_position: Vector2, kind: String = "arrow") -> Vector2:
	var direction := (target_world_position - position).normalized()
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	var fallback_forward := 18.0 if kind in ["arrow", "huntress-arrow-spd", "fire-arrow", "bolt"] else 13.0
	var forward := float(_character_visual.visual_value("projectile_forward", fallback_forward)) if _character_visual != null else fallback_forward
	var origin_y := float(_character_visual.visual_value("projectile_y", -9.0)) if _character_visual != null else -9.0
	return position + _visual_root.position + direction * forward + Vector2(0, origin_y)

func visual_impact_point() -> Vector2:
	var spec: Dictionary = ANIMAL_SPECS.get(unit.get("spriteKey", ""), {})
	var impact_y := float(spec.get("impact_y", _character_visual.visual_value("impact_y", -12.0) if _character_visual != null else -12.0))
	return position + Vector2(0, impact_y)

## Antecipação e release genéricos de um ataque à distância. O callback que
## cria o projétil é temporizado por Main no mesmo instante do snap visual.
func play_ranged_release(target_world_position: Vector2, release_delay: float = 0.20) -> bool:
	if not _begin_premium_action(PREMIUM_ANIMATION.Priority.ATTACK): return false
	var direction := (target_world_position - position).normalized()
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	var prepare := float(_character_visual.visual_value("ranged_prepare", 0.58)) if _character_visual != null else 0.58
	var recoil := float(_character_visual.visual_value("ranged_recoil", 1.0)) if _character_visual != null else 1.0
	_visual_root.position = Vector2.ZERO
	_visual_root.scale = Vector2.ONE
	_visual_root.rotation = 0.0
	_visual_action_tween = create_tween()
	_visual_action_tween.tween_property(_visual_root, "position", -direction * (3.5 + prepare * 2.0), release_delay * prepare).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_visual_action_tween.parallel().tween_property(_visual_root, "rotation", -direction.x * (0.035 + prepare * 0.018), release_delay * prepare)
	_visual_action_tween.parallel().tween_property(_visual_root, "scale", Vector2(1.0 + 0.025 * prepare, 1.0 - 0.025 * prepare), release_delay * prepare)
	_visual_action_tween.tween_interval(release_delay * maxf(0.05, 1.0 - prepare))
	_visual_action_tween.tween_callback(func(): play_attack(0.24); _spawn_premium_smear(direction, String(_character_visual.visual_profile_name()) == "rogue" if _character_visual != null else false))
	_visual_action_tween.tween_property(_visual_root, "position", -direction * (1.5 + recoil * 2.0), 0.055).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_visual_action_tween.parallel().tween_property(_visual_root, "rotation", direction.x * 0.018 * recoil, 0.055)
	_visual_action_tween.parallel().tween_property(_visual_root, "scale", Vector2(1.0 - 0.015 * recoil, 1.0 + 0.015 * recoil), 0.055)
	_visual_action_tween.tween_property(_visual_root, "position", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_visual_action_tween.parallel().tween_property(_visual_root, "rotation", 0.0, 0.14)
	_visual_action_tween.parallel().tween_property(_visual_root, "scale", Vector2.ONE, 0.14)
	_visual_action_tween.tween_callback(_finish_premium_action.bind(PREMIUM_ANIMATION.Priority.ATTACK))
	return true

## Antecipação/lunge puramente local ao VisualRoot. O token permanece no
## centro lógico do tile durante toda a sequência.
func play_weighted_attack(target_world_position: Vector2, critical: bool = false, action_key: String = "attack") -> bool:
	if _uses_warrior_3d():
		var direction := (target_world_position - position).normalized()
		_warrior_3d.face_direction(Vector3(direction.x, 0.0, direction.y), true)
		return _warrior_3d.play_attack_heavy(critical) if critical else _warrior_3d.play_attack_light()
	if not _uses_weighted_visuals(): return play_attack(ATTACK_ACTION_DURATION, action_key)
	if not _begin_premium_action(PREMIUM_ANIMATION.Priority.ATTACK): return false
	var direction := (target_world_position - position).normalized()
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	var anticipation := float(_character_visual.visual_value("anticipation", 0.12)) * ATTACK_WEIGHT_SCALE
	var lunge := float(_character_visual.visual_value("attack_lunge", 27.0))
	var recovery := float(_character_visual.visual_value("recovery", 0.14)) * ATTACK_WEIGHT_SCALE
	var stop := float(_character_visual.visual_value("hit_stop", 0.07)) * HIT_STOP_WEIGHT_SCALE
	_visual_root.position = Vector2.ZERO
	_visual_root.scale = Vector2.ONE
	_visual_action_tween = create_tween()
	_visual_action_tween.tween_property(_visual_root, "position", -direction * minf(8.0, lunge * 0.26), anticipation).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_visual_action_tween.parallel().tween_property(_visual_root, "scale", Vector2(1.04, 0.96), anticipation)
	_visual_action_tween.parallel().tween_property(_visual_root, "rotation", -direction.x * float(_character_visual.visual_value("walk_tilt", 0.055)), anticipation)
	_visual_action_tween.tween_interval(anticipation * 0.65)
	_visual_action_tween.tween_property(_visual_root, "position", direction * lunge, maxf(0.055, anticipation * 0.78)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_visual_action_tween.parallel().tween_property(_visual_root, "scale", Vector2(0.97, 1.04), 0.095)
	_visual_action_tween.parallel().tween_property(_visual_root, "rotation", direction.x * 0.025, 0.095)
	_visual_action_tween.tween_callback(func():
		play_action(action_key, 0.26, false, "attack")
		_spawn_premium_smear(direction, String(_character_visual.visual_profile_name()) == "rogue")
		_spawn_ground_effect(DUST_SCENE)
	)
	# Hit stop só da ação visual: 70 ms normal e 115 ms no crítico.
	_visual_action_tween.tween_interval(stop * (1.5 if critical else 1.0))
	_visual_action_tween.tween_property(_visual_root, "position", -direction * 2.5, 0.11).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_visual_action_tween.parallel().tween_property(_visual_root, "scale", Vector2(1.03, 0.97), 0.09)
	_visual_action_tween.parallel().tween_property(_visual_root, "rotation", -direction.x * 0.018, 0.10)
	_visual_action_tween.tween_property(_visual_root, "position", Vector2.ZERO, recovery).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_visual_action_tween.parallel().tween_property(_visual_root, "scale", Vector2.ONE, recovery)
	_visual_action_tween.parallel().tween_property(_visual_root, "rotation", 0.0, recovery)
	_visual_action_tween.tween_callback(_finish_premium_action.bind(PREMIUM_ANIMATION.Priority.ATTACK))
	return true

func play_weighted_hit_reaction(attack_origin: Vector2, critical: bool = false) -> void:
	if _uses_warrior_3d():
		_warrior_3d.play_hit(Vector3(attack_origin.x, 0.0, attack_origin.y), &"critical" if critical else &"light")
		return
	if not _begin_premium_action(PREMIUM_ANIMATION.Priority.HIT): return
	var away := (position - attack_origin).normalized()
	if away == Vector2.ZERO: away = Vector2.RIGHT
	var recoil := float(_character_visual.visual_value("hit_recoil", 7.0)) if _character_visual != null else 7.0
	var tilt := float(_character_visual.visual_value("hit_tilt", 0.06)) if _character_visual != null else 0.06
	var squash := float(_character_visual.visual_value("squash", 0.07)) if _character_visual != null else 0.07
	var recovery := (float(_character_visual.visual_value("recovery", 0.15)) if _character_visual != null else 0.15) * ATTACK_WEIGHT_SCALE
	var spark := _spawn_ground_effect(HIT_SPARK_SCENE)
	if spark != null:
		spark.position = position + Vector2(0, -8)
		spark.scale = Vector2.ONE * (1.35 if critical else 1.0)
		spark.rotation = away.angle()
	_flash_hit(Color.WHITE, critical)
	play_action("hit", HIT_ACTION_DURATION, false)
	_visual_action_tween = create_tween()
	_visual_action_tween.tween_property(_visual_root, "position", away * recoil * (1.35 if critical else 1.0), 0.10).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_visual_action_tween.parallel().tween_property(_visual_root, "rotation", -away.x * tilt * (1.4 if critical else 1.0), 0.10)
	_visual_action_tween.parallel().tween_property(_visual_root, "scale", Vector2(1.0 + squash, 1.0 - squash), 0.10)
	_visual_action_tween.tween_interval(HIT_STOP_WEIGHT_SCALE * (0.115 if critical else 0.07))
	_visual_action_tween.tween_property(_visual_root, "position", Vector2.ZERO, recovery).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_visual_action_tween.parallel().tween_property(_visual_root, "rotation", 0.0, recovery)
	_visual_action_tween.parallel().tween_property(_visual_root, "scale", Vector2.ONE, recovery)
	if critical: _visual_action_tween.tween_callback(func(): _spawn_ground_effect(DUST_SCENE))
	_visual_action_tween.tween_callback(_finish_premium_action.bind(PREMIUM_ANIMATION.Priority.HIT))

## Chamado pela view quando esta unidade conjura uma magia — usa arte de
## "cast" dedicada se existir, senão cai pra "attack" (mesma regra do JS:
## "cast é opcional... assets atuais seguem usando attack sem regressão").
func play_cast(duration_sec: float = ATTACK_ACTION_DURATION) -> bool:
	if _character_visual != null:
		var style := String(_character_visual.visual_value("cast_style", "neutral"))
		var element := "heal" if style in ["organic", "musical"] else ("poison" if style == "equipment" else "lightning")
		_character_visual.apply_magic_light(element, 0.72 if style == "equipment" else 1.0, duration_sec)
	return play_action("cast", duration_sec, false, "attack")

func play_victory_pose() -> void:
	if _uses_warrior_3d():
		_warrior_3d.play_victory()
		return
	if unit.get("hp", 0) <= 0 or _character_visual == null: return
	if _visual_action_tween != null and _visual_action_tween.is_valid(): _visual_action_tween.kill()
	_visual_action_busy = true
	var style := String(_character_visual.visual_value("victory_style", "settle"))
	var lift := -5.0 if style in ["rise", "rhythmic"] else -2.0
	var tilt := 0.075 if style in ["quick_relax", "rhythmic", "equipment_check"] else 0.025
	if style == "glow": _character_visual.apply_magic_light("lightning", 0.72, 0.85)
	_visual_action_tween = create_tween()
	_visual_action_tween.tween_property(_visual_root, "position:y", lift, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_visual_action_tween.parallel().tween_property(_visual_root, "rotation", tilt, 0.16)
	_visual_action_tween.parallel().tween_property(_visual_root, "scale", Vector2(1.035, 1.035), 0.16)
	_visual_action_tween.tween_property(_visual_root, "position", Vector2.ZERO, 0.34).set_trans(Tween.TRANS_SINE)
	_visual_action_tween.parallel().tween_property(_visual_root, "rotation", 0.0, 0.34)
	_visual_action_tween.parallel().tween_property(_visual_root, "scale", Vector2.ONE, 0.34)
	_visual_action_tween.tween_callback(func(): _visual_action_busy = false)
