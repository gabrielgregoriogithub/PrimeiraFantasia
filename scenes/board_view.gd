extends Node2D
class_name BoardView

const ART_DIRECTION := preload("res://data/art_direction_config.gd")

## Desenha o tabuleiro 13x13 (terreno + estruturas) a partir de um
## GameState — puramente apresentação, não decide nenhuma regra (mesmo
## papel que scene3d.js tinha no protótipo JS: só lê o estado já calculado
## pelo motor). Reaproveita os PNGs de assets/tiles/ copiados do protótipo.

const TILE_SIZE := 64

var state: GameState
var scenario_definition: Dictionary = {"id": ScenarioManager.FIELD}

## Tiles alcançáveis de movimento, alvos atacáveis e área/alvo de magia
## selecionada (Fase 6) — só destaque visual, a fonte de verdade continua
## sendo compute_reachable()/pick_weapon_for_distance()/quem chamou.
## `highlight_move`: Array de {x,y}. `highlight_attack`/`highlight_spell`:
## Array de {x,y} ou de unidades (ambos têm x/y). `highlight_aoe_preview`:
## área real de efeito da magia em área durante a confirmação de 2 cliques
## (equivalente a aoePreviewTiles no JS original) — desenhada por cima do
## roxo de alcance pra distinguir "onde posso mirar" de "quem realmente
## vai ser atingido".
var highlight_move: Array = []
var highlight_attack: Array = []
var highlight_attack_range: Array = []
var highlight_spell: Array = []
var highlight_aoe_preview: Array = []
var hover_tile = null
var preview_path: Array = []
var preview_destination = null
var highlight_profile := "move"
var _highlight_progress := 1.0
var _highlight_fading := false

## Campo/Torre (13x13, 832x832px) sempre couberam inteiros na viewport sem
## câmera nenhuma — por isso o resto do jogo (cliques, efeitos, popups)
## assume coordenada local de board_view == pixel de tela. A Horda usa o
## recorte real 26x22 (1664x1408px) do Legend of Lua, maior que a janela de
## jogo, então esta câmera fica travada mostrando só uma janela fixa de
## 13x13 tiles (LUA_VALLEY_CROP_ORIGIN, canto superior esquerdo do recorte
## dentro do mapa 26x22) — sem zoom e sem arrastar, o board_view fica dentro
## de um Control com clip_contents=true (ver main.gd:_start_new_game) que
## corta fisicamente qualquer tile fora dessa janela. Pra Campo/Torre o
## offset de recorte é zero e a câmera fica centralizada na viewport,
## reproduzindo pixel a pixel o comportamento de antes (sem câmera nenhuma).
var camera: Camera2D
var camera_shake: CameraShake2D
var _ambient_life: AmbientLifeManager
## ETAPA 18 — vento global puramente visual (0 calmo .. 1 rajada), varia
## devagar; só afeta o balanço da copa das árvores (EnvironmentPropVisual)
## e a taxa de folhas do AmbientLifeManager. Nunca lido por regra alguma.
var wind_strength := 0.4
var _wind_target := 0.4
var _wind_change_at := 2.0
var _camera_owner := "player"
var _camera_owner_priority := 0

## Canto superior esquerdo (em tiles) da janela fixa de 13x13 mostrada da
## Horda dentro do recorte 26x22 real. Reconstituído do próprio recorte
## 13x13 "já aprovado visualmente" que existia antes da expansão pra 26x22
## (ver ASSET_SOURCES.md, "Expansão para 26x22"): a expansão só ACRESCENTOU
## conteúdo à esquerda (bosque) e ao sul (ilha de grama/faixa arenosa/cerca),
## então as linhas não mudaram (0) e as colunas do recorte antigo deslocaram
## +6 no recorte novo — confirmado pela própria escada, que a expansão moveu
## da coluna 5 (recorte antigo) pra coluna 11 (recorte novo, LADDER_TILES).
## Contém a boca da caverna (CAVE_MOUTH), a escada, a área de spawn dos
## heróis (player_spawns) e a borda do lago, igual à composição original.
## Pedido do usuário: o recorte estava mostrando demais a cachoeira à
## direita e cortando a boca da caverna (CAVE_MOUTH, x=6) bem na borda
## esquerda da janela — desloca 5 colunas pra esquerda (era x=6) pra centrar
## melhor a área da caverna e tirar a cachoeira de cena.
const LUA_VALLEY_CROP_ORIGIN := Vector2(1, 0)

var _tex_cache: Dictionary = {}
var _soul_phase := 0.0
var _anim_time_ms := 0.0
var _environment_props: Array[Node2D] = []
var _grass_reactions: Array[Dictionary] = []
var _art_profile: Dictionary = ART_DIRECTION.DEFAULT_BIOME.duplicate(true)

class EnvironmentPropVisual extends Node2D:
	var texture: Texture2D
	var visual_size := Vector2(64, 64)
	var visual_height := 64.0
	var kind := "prop"
	var phase := 0.0
	var base_alpha := 1.0
	var reaction_tween: Tween
	var visibility_clock := 0.10

	func configure(p_texture: Texture2D, p_size: Vector2, p_kind: String, p_phase: float) -> void:
		texture = p_texture
		visual_size = p_size
		visual_height = p_size.y
		kind = p_kind
		phase = p_phase
		z_index = roundi(position.y)
		set_process(kind == "tree")
		queue_redraw()

	func _process(delta: float) -> void:
		# Oclusão é decorativa: 10 Hz evita que cada árvore percorra todos os
		# tokens em todo frame sem produzir diferença visível.
		visibility_clock += delta
		if visibility_clock < 0.10: return
		visibility_clock = 0.0
		var hidden := false
		for child in get_parent().get_children():
			if child is UnitToken and child.unit.get("hp", 0) > 0:
				var local: Vector2 = child.position - position
				if absf(local.x) < visual_size.x * 0.42 and local.y < 0.0 and local.y > -visual_height * 1.05:
					hidden = true
					break
		var wanted := 0.68 if hidden else 1.0
		# Compensa a frequência reduzida preservando aproximadamente a mesma
		# velocidade perceptiva da interpolação que antes rodava a cada frame.
		base_alpha = lerpf(base_alpha, wanted, 0.55)
		modulate.a = base_alpha
		queue_redraw()

	func _draw() -> void:
		var shadow_scale := 1.0 if kind == "tree" else 1.25
		var shadow_points := PackedVector2Array()
		for i in 24:
			var angle := TAU * float(i) / 24.0
			shadow_points.append(Vector2(visual_size.x * 0.33 * shadow_scale * cos(angle) + 11.0, visual_size.y * 0.09 * sin(angle) + 2.0))
		draw_colored_polygon(shadow_points, Color(0.045, 0.06, 0.055, 0.27))
		draw_ellipse_contact(Vector2(0, 0), Vector2(visual_size.x * 0.18, 5.0))
		# ETAPA 18 — vento global visual (BoardView.wind_strength, 0..1,
		# varia devagar entre calmo e rajada): só escala a copa das árvores,
		# nunca cria movimento novo em props que hoje ficam parados.
		var board := get_parent() as BoardView
		var wind := 0.35 + float(board.wind_strength) * 0.9 if board != null else 1.0
		var sway := sin(Time.get_ticks_msec() * 0.0011 + phase) * (0.008 if kind == "tree" else 0.0) * wind
		draw_set_transform(Vector2.ZERO, sway, Vector2.ONE)
		draw_texture_rect(texture, Rect2(Vector2(-visual_size.x * 0.5, -visual_size.y), visual_size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func react_from(source: Vector2, strength: float, element: String = "") -> void:
		if kind != "tree" and strength < 0.78: return
		if reaction_tween != null and reaction_tween.is_valid(): reaction_tween.kill()
		var away := (position - source).normalized()
		if away == Vector2.ZERO: away = Vector2.RIGHT
		var tilt := clampf(away.x * 0.045 * strength, -0.055, 0.055)
		var tint := Color("d7efff") if element == "ice" else (Color("fff0cf") if element == "fire" else (Color("e5fbff") if element == "lightning" else Color.WHITE))
		reaction_tween = create_tween()
		reaction_tween.tween_property(self, "rotation", tilt, 0.075).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		reaction_tween.parallel().tween_property(self, "scale", Vector2(1.0 + absf(away.x) * 0.018, 0.985), 0.075)
		reaction_tween.parallel().tween_property(self, "self_modulate", tint, 0.075)
		reaction_tween.tween_property(self, "rotation", 0.0, 0.42).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		reaction_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.36)
		reaction_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.42)

	func draw_ellipse_contact(center: Vector2, radii: Vector2) -> void:
		var points := PackedVector2Array()
		for i in 20:
			var angle := TAU * float(i) / 20.0
			points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
		draw_colored_polygon(points, Color(0.02, 0.025, 0.02, 0.38))

## Ondulações da Horda: porta o comportamento real de
## `src/environment/water.lua` (legend-of-lua-main) — spawna a partícula
## `wave` em posição aleatória dentro da área de água em intervalo
## aleatório, em vez de um shader novo.
var _lua_ripples: Array = []
var _lua_ripple_timer := 0.0
const LUA_RIPPLE_FRAME_S := 0.07
const LUA_RIPPLE_FRAMES := 17
const LUA_RIPPLE_LIFETIME := LUA_RIPPLE_FRAME_S * LUA_RIPPLE_FRAMES

## Peixinho do rio da Vila: a cada 5 turnos globais, um peixe sorteado
## (Cute Fish Pack, Quaternius, CC0) pula pra fora do rio e cai de volta —
## puramente visual, não consulta nenhuma regra de jogo. `_village_fish_
## last_turn` evita disparar de novo enquanto o turno global não muda (senão
## repetiria a cada frame durante os múltiplos de 5).
const VILLAGE_FISH_TEXTURES := [
	"res://assets/props/village/fish_koi.png",
	"res://assets/props/village/fish_goldfish.png",
	"res://assets/props/village/fish_tetra.png",
	"res://assets/props/village/fish_piranha.png",
]
const VILLAGE_FISH_JUMP_DURATION_S := 1.1
const VILLAGE_FISH_JUMP_HEIGHT := 46.0
var _village_fish_last_turn := -1
var _village_fish_jump_active := false
var _village_fish_jump_start_ms := 0.0
var _village_fish_texture_path := ""
var _village_fish_tile := Vector2.ZERO

const TERRAIN_STATIC_TEXTURES := {
	"water": "res://assets/tiles/lake.png",
	"house": "res://assets/tiles/house.png",
	"stump": "res://assets/tiles/stump.png",
	# Sem arte dedicada de ruína de casa/tenda no conjunto original — reusa o
	# toco de árvore como indicador genérico de "destruído" por enquanto.
	"house-rubble": "res://assets/tiles/stump.png",
	"tent-rubble": "res://assets/tiles/stump.png",
}

const GRASS_TEXTURE := "res://assets/tiles/grass.png"
const CASTLE_TEXTURE := "res://assets/tiles/castle.png"
const MOUNTAIN_TEXTURE := "res://assets/tiles/mountain.png"
const CASTLE_RUBBLE_TEXTURE := "res://assets/tiles/rubble-castle.png"
const MOUNTAIN_RUBBLE_TEXTURE := "res://assets/tiles/rubble-mountain.png"
const CURATED_PROP_TEXTURES := {
	"field-logs": "res://assets/props/environment/field_logs.png",
	"field-rock-1": "res://assets/props/environment/field_rock_1.png",
	"field-rock-2": "res://assets/props/environment/field_rock_2.png",
	"field-rock-3": "res://assets/props/environment/field_rock_3.png",
	"tower-barrel": "res://assets/props/tower/barrel.png",
	"tower-crate": "res://assets/props/tower/crate.png",
	"tower-crate-stack": "res://assets/props/tower/crate_stack.png",
	"village-wagon": "res://assets/props/village/village_wagon.png",
	"village-crate": "res://assets/props/village/village_crate.png",
	"village-fence": "res://assets/props/village/village_fence.png",
	"village-rubble": "res://assets/props/village/village_rubble.png",
	"village-well": "res://assets/props/village/village_well.png",
	"village-coop": "res://assets/props/village/village_coop.png",
	"village-farmfence": "res://assets/props/village/village_farmfence.png",
	"village-barn": "res://assets/props/village/village_barn.png",
	"village-boat": "res://assets/props/village/village_boat.png",
	"village-silo": "res://assets/props/village/village_silo.png",
	"village-watertower": "res://assets/props/village/village_watertower.png",
	"village-smallbarn": "res://assets/props/village/village_smallbarn.png",
	"village-openbarn": "res://assets/props/village/village_openbarn.png",
	# Árvores da Vila reaproveitam as mesmas artes do Campo (tree1..5.png,
	# BoardLayout.TREE_ART_VARIANTS) — pedido do usuário, pra ficar visualmente
	# consistente entre os dois cenários.
	"village-tree1": "res://assets/tiles/tree1.png",
	"village-tree2": "res://assets/tiles/tree2.png",
	"village-tree3": "res://assets/tiles/tree3.png",
	"village-tree4": "res://assets/tiles/tree4.png",
	"village-tree5": "res://assets/tiles/tree5.png",
	# Props vulcânicos do 3º Andar (props lava.png, recortados em
	# tools/_tmp_preview_tower-like slicing) e de decomposição do 2º Andar
	# (prop corpos.png) — pedido do usuário, ver DungeonFloor2/3Layout.
	"lava-volcano": "res://assets/props/tower/lava/volcano.png",
	"lava-mound-a": "res://assets/props/tower/lava/mound_a.png",
	"lava-mound-b": "res://assets/props/tower/lava/mound_b.png",
	"lava-boulders": "res://assets/props/tower/lava/boulders.png",
	"lava-crystal": "res://assets/props/tower/lava/crystal.png",
	"lava-burning-logs": "res://assets/props/tower/lava/burning_logs.png",
	"lava-smoke-vent": "res://assets/props/tower/lava/smoke_vent.png",
	"lava-pedestal": "res://assets/props/tower/lava/pedestal.png",
	"corpse-bones-pile": "res://assets/props/tower/corpses/bones_pile.png",
	"corpse-skulls-pile": "res://assets/props/tower/corpses/skulls_pile.png",
	"corpse-skeleton-a": "res://assets/props/tower/corpses/skeleton_a.png",
	"corpse-skeleton-hooded": "res://assets/props/tower/corpses/skeleton_hooded.png",
	"corpse-fallen-a": "res://assets/props/tower/corpses/fallen_a.png",
	"corpse-knight-armored": "res://assets/props/tower/corpses/knight_armored.png",
	"corpse-mossy-poison": "res://assets/props/tower/corpses/mossy_poison.png",
}

## Tamanho máximo (largura ou altura, px) dos props vulcânicos/cadáveres —
## pedido do usuário: "1 prop = 1 tile" aproximadamente (TILE_SIZE = 64),
## um pouco maior pros marcos visuais (vulcão, pedestal).
const HAZARD_PROP_MAX_DIM := {
	"lava-volcano": 78.0, "lava-mound-a": 62.0, "lava-mound-b": 58.0,
	"lava-boulders": 56.0, "lava-crystal": 54.0, "lava-burning-logs": 60.0,
	"lava-smoke-vent": 60.0, "lava-pedestal": 74.0,
	"corpse-bones-pile": 50.0, "corpse-skulls-pile": 46.0,
	"corpse-skeleton-a": 68.0, "corpse-skeleton-hooded": 62.0,
	"corpse-fallen-a": 64.0, "corpse-knight-armored": 70.0,
	"corpse-mossy-poison": 64.0,
}

## Casa: 3 variantes prontas do pack Ultimate Fantasy RTS (Quaternius, CC0,
## PNGs já renderizados — sem montagem 3D, só recorte); a variante usada por
## prédio é determinística por posição (_village_house_texture), não um
## "kind" à parte, porque testes/regras dependem só de "village-house"
## genérico (ver test_scenario_village.gd). Moinho: TowerWindmill do pack
## Farm Buildings (Quaternius, CC0), renderizado a partir do .obj numa cena
## 3D à parte — esse sim com pás de verdade, ao contrário do substituto
## anterior (ver ASSET_SOURCES.md, "Vila", pra histórico da troca).
const VILLAGE_HOUSE_TEXTURES := [
	"res://assets/props/village/village_house_1.png",
	"res://assets/props/village/village_house_2.png",
	"res://assets/props/village/village_house_3.png",
]
const VILLAGE_MILL_TEXTURE := "res://assets/props/village/village_mill.png"

func _ready() -> void:
	# Pixel art esticada (16px -> 64px) precisa de nearest, senão borra os
	# tiles reais do Legend of Lua (madeira, espuma, bordas do lago).
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	camera = Camera2D.new()
	add_child(camera)
	camera.enabled = true
	camera_shake = CameraShake2D.new()
	add_child(camera_shake)
	camera_shake.setup(camera)
	# ETAPA 18 — folhas/poeira/névoa/brasa ocasionais, um bioma de cada vez
	# (ver ArtDirectionConfig.BIOMES["ambient_particles"], já existia mas
	# nunca era lido). Puramente decorativo, nunca ganha prioridade de
	# câmera nem participa de nenhuma regra.
	_ambient_life = AmbientLifeManager.new()
	add_child(_ambient_life)
	_ambient_life.setup(self, func(): return _environment_props.filter(func(prop): return prop.kind == "tree"))
	_ambient_life.set_biome(String(_art_profile.get("ambient_particles", "dust")))
	_update_camera()

func shake_camera(direction: Vector2 = Vector2.RIGHT, intensity: float = 1.25, duration: float = 0.10, critical: bool = false) -> void:
	if camera_shake != null:
		camera_shake.shake(direction, intensity, duration, critical)

func acquire_camera(owner: String, priority: int) -> bool:
	if owner == _camera_owner or priority >= _camera_owner_priority:
		_camera_owner = owner
		_camera_owner_priority = priority
		return true
	return false

func release_camera(owner: String) -> void:
	if owner != _camera_owner: return
	_camera_owner = "player"
	_camera_owner_priority = 0

func camera_owner() -> String:
	return _camera_owner

func shake_camera_at(impact_position: Vector2, direction: Vector2, intensity: float, duration: float, critical: bool = false) -> void:
	var focus := camera.position if camera != null else Vector2(GameConstants.BOARD_SIZE, GameConstants.BOARD_SIZE) * TILE_SIZE * 0.5
	var max_distance := Vector2(GameConstants.BOARD_SIZE, GameConstants.BOARD_SIZE).length() * TILE_SIZE * 0.55
	var falloff := lerpf(1.0, 0.35, clampf(impact_position.distance_to(focus) / max_distance, 0.0, 1.0))
	shake_camera(direction, intensity * falloff, duration, critical)

func set_state(s: GameState) -> void:
	state = s
	set_process(true)
	call_deferred("_rebuild_environment_visuals")
	queue_redraw()

func set_scenario(definition: Dictionary) -> void:
	scenario_definition = definition
	_art_profile = ART_DIRECTION.biome_for(String(definition.get("id", "field")))
	_village_fish_last_turn = -1
	_village_fish_jump_active = false
	if _ambient_life != null:
		_ambient_life.set_biome(String(_art_profile.get("ambient_particles", "dust")))
		_ambient_life.clear()
	_update_camera()
	call_deferred("_rebuild_environment_visuals")
	queue_redraw()

## Profundidade visual minima para uma unidade que ocupa Castelo/Montanha
## no Campo. O asset alto da estrutura usa sua base (ultima linha do 3x3)
## como z_index; o ocupante precisa ficar um plano acima para continuar
## legivel. Esta consulta nao altera elevacao, ocupacao ou qualquer regra.
func structure_occupant_z(x: int, y: int) -> int:
	if state == null or scenario_definition.get("id", ScenarioManager.FIELD) != ScenarioManager.FIELD:
		return -1
	var structure = state.structure_at(x, y)
	if structure == null or structure.get("destroyed", false):
		return -1
	var max_y := -1
	for tile in (structure.get("tiles", []) as Array):
		max_y = maxi(max_y, int(tile["y"]))
	return (max_y + 1) * TILE_SIZE + 1

## Reduz brevemente a densidade de vida ambiental durante um evento visual
## grande (regra 58-59 da ETAPA 18) — chamado por EffectsLayer sempre que um
## impacto HEAVY/SIGNATURE/EPIC acontece, reaproveitando o mesmo vocabulário
## de intensidade que VisualPolicy.IMPACT_PRESETS já usa.
func ambient_life_duck(seconds: float = 1.1) -> void:
	if _ambient_life != null: _ambient_life.duck(seconds)

func _rebuild_environment_visuals() -> void:
	for prop in _environment_props:
		if is_instance_valid(prop): prop.queue_free()
	_environment_props.clear()
	if state == null or scenario_definition.get("id", ScenarioManager.FIELD) != ScenarioManager.FIELD: return
	for y in range(state.board_height):
		for x in range(state.board_width):
			var terrain = state.terrain_at(x, y)
			if terrain == null or terrain.get("type", "") != "tree": continue
			var visual := EnvironmentPropVisual.new()
			visual.position = Vector2((x + 0.5) * TILE_SIZE, (y + 1.0) * TILE_SIZE)
			add_child(visual)
			visual.self_modulate = _art_profile.get("environment_tint", Color.WHITE)
			visual.configure(_get_tex("res://assets/tiles/%s" % terrain["art"]), Vector2(82, 104), "tree", float(x * 17 + y * 31) * 0.13)
			_environment_props.append(visual)
	for structure in state.structures:
		var min_x := 99; var min_y := 99; var max_x := -1; var max_y := -1
		for tile in (structure["tiles"] as Array):
			min_x = mini(min_x, tile["x"]); min_y = mini(min_y, tile["y"]); max_x = maxi(max_x, tile["x"]); max_y = maxi(max_y, tile["y"])
		var size := Vector2(max_x - min_x + 1, max_y - min_y + 1) * TILE_SIZE
		var is_castle: bool = structure["type"] == "castle"
		var path := (CASTLE_RUBBLE_TEXTURE if is_castle else MOUNTAIN_RUBBLE_TEXTURE) if structure["destroyed"] else (CASTLE_TEXTURE if is_castle else MOUNTAIN_TEXTURE)
		var visual := EnvironmentPropVisual.new()
		visual.position = Vector2((min_x + max_x + 1) * TILE_SIZE * 0.5, (max_y + 1) * TILE_SIZE)
		add_child(visual)
		visual.configure(_get_tex(path), size, structure["type"], float(min_x + min_y))
		_environment_props.append(visual)

## Recalcula a posição da câmera pro cenário atual. Chamada de novo a cada
## troca de cenário (set_scenario). Zoom fica sempre travado em 1:1 (sem
## aproximar/afastar); só a posição muda, deslocando a janela fixa de 13x13
## pro canto LUA_VALLEY_CROP_ORIGIN quando o cenário ativo é a Horda. O
## corte físico pra exatamente 13x13 tiles é feito pelo Control com
## clip_contents=true que envolve este nó (ver main.gd), não pela câmera.
##
## Regressão corrigida: `camera` é filho deste próprio nó (board_view), que
## por sua vez é filho do Control de corte (_board_clip) — e o Control NÃO
## está isolado numa CanvasLayer própria, então o transform de câmera afeta
## a viewport inteira, incluindo o retângulo do próprio _board_clip. Somar
## `crop_origin` direto em `camera.position` arrastava o corte inteiro pra
## fora da tela (deslocado pelo mesmo crop_origin), sobrando só uma fração
## das 13 colunas visíveis. A correção é deslocar o CONTEÚDO (este nó) por
## `-crop_origin`, deixando a câmera sempre com global_position EXATAMENTE
## no centro da viewport (transform líquido zero sobre o corte) — só o
## desenho dos tiles se move por baixo do corte fixo, revelando a janela
## certa do mapa 26x22 sem arrastar o _board_clip junto.
func _update_camera() -> void:
	if camera == null:
		return
	camera.zoom = Vector2.ONE
	var crop_origin := Vector2.ZERO
	if scenario_definition.get("id", ScenarioManager.FIELD) == ScenarioManager.LUA_VALLEY:
		crop_origin = LUA_VALLEY_CROP_ORIGIN * TILE_SIZE
	position = -crop_origin
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(920, 1200)
	camera.position = viewport_size * 0.5 - global_position

## Interpola suavemente entre calmo e uma pequena rajada (regra 7 da ETAPA
## 18 — "vento não deve ter força constante"), num intervalo aleatório.
func _update_wind(delta: float) -> void:
	_wind_change_at -= delta
	if _wind_change_at <= 0.0:
		_wind_target = randf_range(0.15, 1.0)
		_wind_change_at = randf_range(2.5, 5.5)
	wind_strength = lerpf(wind_strength, _wind_target, clampf(delta * 0.6, 0.0, 1.0))

func _process(delta: float) -> void:
	if state == null: return
	_update_wind(delta)
	_soul_phase = fmod(_soul_phase + delta * 2.2, TAU)
	if _highlight_fading:
		_highlight_progress = maxf(0.0, _highlight_progress - delta / 0.14)
		if _highlight_progress <= 0.0:
			_highlight_fading = false
			highlight_move.clear(); highlight_attack.clear(); highlight_attack_range.clear(); highlight_spell.clear(); highlight_aoe_preview.clear(); preview_path.clear(); preview_destination = null
	elif _highlight_progress < 1.0:
		_highlight_progress = minf(1.0, _highlight_progress + delta / 0.20)
	_anim_time_ms += delta * 1000.0
	for reaction in _grass_reactions:
		reaction["age"] = float(reaction["age"]) + delta
	_grass_reactions = _grass_reactions.filter(func(reaction): return float(reaction["age"]) < float(reaction["duration"]))
	if scenario_definition.get("id", ScenarioManager.FIELD) == ScenarioManager.LUA_VALLEY:
		_update_lua_ripples(delta)
	elif scenario_definition.get("id", ScenarioManager.FIELD) == ScenarioManager.VILLAGE:
		_update_village_fish_jump()
	queue_redraw()

## Evento exclusivamente visual. Retorna pontos próximos para a camada de
## partículas reagir sem consultar nem modificar regras de terreno.
func react_environment(center: Vector2, radius_tiles: float, direction: Vector2, strength: float, element: String = "") -> Dictionary:
	var radius := maxf(radius_tiles, 0.25) * TILE_SIZE
	var trees: Array[Vector2] = []
	for prop in _environment_props:
		if not is_instance_valid(prop) or prop.position.distance_to(center) > radius: continue
		(prop as EnvironmentPropVisual).react_from(center - direction.normalized() * 4.0, strength, element)
		if prop.kind == "tree" and trees.size() < 6: trees.append(prop.position + Vector2(0, -34))
	_grass_reactions.append({"center": center, "direction": direction.normalized(), "radius": radius, "strength": strength, "age": 0.0, "duration": 0.48})
	var water: Array[Vector2] = []
	for y in range(state.board_height):
		for x in range(state.board_width):
			if water.size() >= 5: break
			var terrain = state.terrain_at(x, y)
			var tile_at := tile_center(x, y)
			if terrain != null and terrain.get("type", "") == "water" and tile_at.distance_to(center) <= radius:
				water.append(tile_at)
	return {"trees": trees, "water": water}

## ETAPA 19 — Material Reaction System: só CONSULTA o que já existe
## (terrain_at/structure_at, sempre já resolvidos pela regra real) pra
## decidir a aparência do impacto; nunca cria um novo tipo de terreno nem
## afeta colisão/pathfinding. "wood"/"tent"/"tower-bookshelf" soam madeira,
## paredes/pilares/estruturas soam pedra, água continua água — fora isso,
## cai no grass/dirt que EnvironmentReactionSystem já usava.
const WOOD_TERRAIN_TYPES := ["tree", "house", "tent", "tower-bookshelf"]
const STONE_TERRAIN_TYPES := ["tower-wall", "tower-pillar", "tower-vase", "lua-mountain", "village-building"]

func material_at(x: int, y: int) -> String:
	if state == null or not state.in_bounds(x, y):
		return "generic"
	var structure = state.structure_at(x, y)
	if structure != null:
		return "stone"
	var terrain = state.terrain_at(x, y)
	var terrain_type := String(terrain.get("type", "")) if terrain != null else ""
	if terrain_type == "water":
		return "water"
	if terrain_type in WOOD_TERRAIN_TYPES:
		return "wood"
	if terrain_type in STONE_TERRAIN_TYPES:
		return "stone"
	return "grass" if scenario_definition.get("id", ScenarioManager.FIELD) == ScenarioManager.FIELD else "dirt"

func _draw_grass_reactions() -> void:
	for reaction in _grass_reactions:
		var progress := clampf(float(reaction["age"]) / float(reaction["duration"]), 0.0, 1.0)
		var alpha := (1.0 - progress) * 0.46
		var direction: Vector2 = reaction["direction"]
		if direction == Vector2.ZERO: direction = Vector2.RIGHT
		var radius: float = minf(float(reaction["radius"]), TILE_SIZE * 2.2)
		for i in 8:
			var angle := TAU * float(i) / 8.0
			var base: Vector2 = reaction["center"] + Vector2.from_angle(angle) * radius * randf_range(0.25, 0.86)
			draw_line(base, base + direction * (5.0 + float(reaction["strength"]) * 7.0) + Vector2.UP * 5.0, Color(0.36, 0.61, 0.24, alpha), 1.5, true)

## Dispara um pulo de peixe a cada 5 turnos globais (turno > 0) e desliga o
## anterior quando termina. `_village_fish_last_turn` garante 1 disparo por
## turno múltiplo de 5, não 1 por frame enquanto o turno não avança.
func _update_village_fish_jump() -> void:
	var turn: int = state.global_turn_count
	if turn > 0 and turn % 5 == 0 and turn != _village_fish_last_turn:
		_village_fish_last_turn = turn
		var water: Array = scenario_definition.get("water", [])
		if not water.is_empty():
			var cell: Dictionary = water[randi() % water.size()]
			_village_fish_tile = tile_center(int(cell["x"]), int(cell["y"]))
			_village_fish_texture_path = VILLAGE_FISH_TEXTURES[randi() % VILLAGE_FISH_TEXTURES.size()]
			_village_fish_jump_start_ms = _anim_time_ms
			_village_fish_jump_active = true
	if _village_fish_jump_active and (_anim_time_ms - _village_fish_jump_start_ms) / 1000.0 > VILLAGE_FISH_JUMP_DURATION_S:
		_village_fish_jump_active = false

## Arco parabólico simples: sobe, faz uma leve virada no ar e desce de volta
## no mesmo ponto do rio — não nada pra lugar nenhum, só um respiro visual.
func _draw_village_fish_jump() -> void:
	if not _village_fish_jump_active:
		return
	var t: float = clampf((_anim_time_ms - _village_fish_jump_start_ms) / 1000.0 / VILLAGE_FISH_JUMP_DURATION_S, 0.0, 1.0)
	var arc: float = sin(t * PI)
	var lift := Vector2(0, -arc * VILLAGE_FISH_JUMP_HEIGHT)
	var tex := _get_tex(_village_fish_texture_path)
	var tex_size: Vector2 = tex.get_size()
	var scale_factor: float = 44.0 / maxf(tex_size.x, tex_size.y)
	var size := tex_size * scale_factor
	var center := _village_fish_tile + lift
	draw_set_transform(center, lerp(-0.5, 0.5, t), Vector2.ONE)
	draw_texture_rect(tex, Rect2(-size * 0.5, size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Splash discreto só na entrada/saída da água (perto do início/fim do arco).
	if t < 0.12 or t > 0.88:
		draw_circle(_village_fish_tile, 10.0, Color(0.85, 0.95, 1.0, 0.35))

func set_highlights(move_tiles: Array, attack_targets: Array, spell_tiles: Array = [], aoe_preview_tiles: Array = [], attack_range_tiles: Array = []) -> void:
	var had_none := highlight_move.is_empty() and highlight_attack.is_empty() and highlight_spell.is_empty() and highlight_attack_range.is_empty()
	highlight_move = move_tiles
	highlight_attack = attack_targets
	highlight_attack_range = attack_range_tiles
	highlight_spell = spell_tiles
	highlight_aoe_preview = aoe_preview_tiles
	if had_none and not (move_tiles.is_empty() and attack_targets.is_empty() and spell_tiles.is_empty() and attack_range_tiles.is_empty()):
		_highlight_progress = 0.0
	_highlight_fading = false
	queue_redraw()

func set_interaction_preview(p_hover, p_path: Array = [], destination = null, profile: String = "move") -> void:
	hover_tile = p_hover
	preview_path = p_path.duplicate(true)
	preview_destination = destination
	highlight_profile = profile
	queue_redraw()

func fade_action_feedback() -> void:
	_highlight_fading = true
	hover_tile = null
	preview_path.clear()
	preview_destination = null
	queue_redraw()

## Converte uma posição LOCAL (já relativa a este nó) em coordenada de tile,
## ou null se cair fora do tabuleiro.
func tile_at_local_pos(local_pos: Vector2) -> Variant:
	var x := int(floor(local_pos.x / TILE_SIZE))
	var y := int(floor(local_pos.y / TILE_SIZE))
	if state != null and state.in_bounds(x, y):
		return {"x": x, "y": y}
	return null

func _get_tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]

func tile_rect(x: int, y: int) -> Rect2:
	return Rect2(Vector2(x, y) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE))

func tile_center(x: int, y: int) -> Vector2:
	return Vector2(x, y) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5

func _draw() -> void:
	if state == null:
		return
	var board_w := state.board_width
	var board_h := state.board_height

	# Grama por baixo de tudo.
	var grass := _get_tex(GRASS_TEXTURE)
	for y in range(board_h):
		for x in range(board_w):
			draw_texture_rect(grass, tile_rect(x, y), false)
			if scenario_definition.get("id", ScenarioManager.FIELD) == ScenarioManager.FIELD and posmod(x * 17 + y * 29, 11) == 0:
				var sway := sin(_anim_time_ms * 0.0012 + float(x * 3 + y)) * 1.5
				var tuft := tile_center(x, y) + Vector2(-17 + posmod(x * 13 + y * 7, 31), 19)
				draw_line(tuft, tuft + Vector2(sway - 3, -8), Color(0.25, 0.47, 0.19, 0.42), 1.5, true)
				draw_line(tuft + Vector2(4, 1), tuft + Vector2(4 - sway, -6), Color(0.42, 0.60, 0.25, 0.34), 1.2, true)
	# Tint ambiental neutro-esverdeado apenas sobre o chão; unidades, UI e
	# highlights permanecem com suas cores originais e totalmente legíveis.
	if scenario_definition.get("id", ScenarioManager.FIELD) == ScenarioManager.FIELD:
		draw_rect(Rect2(Vector2.ZERO, Vector2(board_w, board_h) * TILE_SIZE), Color(0.12, 0.22, 0.15, 0.035))

	# Um único curso d'água contínuo, seguindo o mesmo traçado dos tiles de
	# água existentes. A regra continua tile a tile no GameState; somente os
	# antigos sprites de "laguinho" são substituídos por esta faixa conectada.
	# Traçado fixo do Campo — o Vale de Lua desenha o próprio rio (a partir
	# dos tiles de água reais do cenário) dentro de _draw_lua_valley_board().
	if scenario_definition.get("id", ScenarioManager.FIELD) == ScenarioManager.FIELD:
		_draw_continuous_river()

	# Terreno estático (água/árvore/casa/tenda/ruínas).
	for y in range(board_h):
		for x in range(board_w):
			var terrain = state.terrain_at(x, y)
			if terrain == null:
				continue
			var tex_path: String = ""
			var type: String = terrain["type"]
			if type == "water":
				continue
			if type == "tree" and scenario_definition.get("id", ScenarioManager.FIELD) == ScenarioManager.FIELD:
				continue
			if type == "tree" or type == "tent":
				tex_path = "res://assets/tiles/%s" % terrain["art"]
			elif TERRAIN_STATIC_TEXTURES.has(type):
				tex_path = TERRAIN_STATIC_TEXTURES[type]
			if tex_path != "":
				draw_texture_rect(_get_tex(tex_path), tile_rect(x, y), false)

	# Flores pertencem ao Campo; outros cenários têm composição própria.
	if scenario_definition.get("id", ScenarioManager.FIELD) == ScenarioManager.FIELD:
		for f in BoardLayout.FLOWER_LAYOUT:
			draw_texture_rect(_get_tex("res://assets/tiles/%s" % f["art"]), tile_rect(f["x"], f["y"]), false)

	# Estruturas (Castelo/Montanha), esticadas pelos 3x3 tiles.
	for s in state.structures:
		var min_x := 99
		var min_y := 99
		var max_x := -1
		var max_y := -1
		for t in (s["tiles"] as Array):
			min_x = mini(min_x, t["x"])
			min_y = mini(min_y, t["y"])
			max_x = maxi(max_x, t["x"])
			max_y = maxi(max_y, t["y"])
		var rect := Rect2(Vector2(min_x, min_y) * TILE_SIZE, Vector2(max_x - min_x + 1, max_y - min_y + 1) * TILE_SIZE)
		var is_castle: bool = s["type"] == "castle"
		var tex_path: String = ""
		if s["destroyed"]:
			tex_path = CASTLE_RUBBLE_TEXTURE if is_castle else MOUNTAIN_RUBBLE_TEXTURE
		else:
			tex_path = CASTLE_TEXTURE if is_castle else MOUNTAIN_TEXTURE
		if scenario_definition.get("id", ScenarioManager.FIELD) != ScenarioManager.FIELD:
			draw_texture_rect(_get_tex(tex_path), rect, false)
		if not s["destroyed"]:
			var hp_ratio: float = float(s["hp"]) / float(s["maxHp"])
			var bar_bg := Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 6))
			draw_rect(bar_bg, Color(0, 0, 0, 0.6))
			draw_rect(Rect2(bar_bg.position, Vector2(bar_bg.size.x * hp_ratio, bar_bg.size.y)), Color(0.3, 0.85, 0.3) if is_castle else Color(0.85, 0.3, 0.3))

	# A Torre é desenhada por cima do Campo antes da grid/destaques. Isso
	# mantém uma única camada de gameplay e preserva integralmente o cenário
	# original quando o id ativo é FIELD.
	if scenario_definition.get("id", ScenarioManager.FIELD) in [ScenarioManager.TOWER, ScenarioManager.TOWER_FLOOR_2, ScenarioManager.TOWER_FLOOR_3, ScenarioManager.TOWER_FLOOR_4]:
		_draw_tower_board()
	elif scenario_definition.get("id", ScenarioManager.FIELD) == ScenarioManager.LUA_VALLEY:
		_draw_lua_valley_board()
	elif scenario_definition.get("id", ScenarioManager.FIELD) == ScenarioManager.VILLAGE:
		_draw_village_board()
		_draw_village_fish_jump()
	elif scenario_definition.get("id", ScenarioManager.FIELD) == ScenarioManager.FOREST:
		_draw_forest_board()
	_draw_curated_props()
	_draw_grass_reactions()
	# Grading somente do mundo desenhado por BoardView. Tokens, VFX e UI são
	# filhos separados e preservam cores de classe/gameplay.
	draw_rect(Rect2(Vector2.ZERO, Vector2(board_w, board_h) * TILE_SIZE), _art_profile.get("ambient_tint", Color.TRANSPARENT))

	# Linhas de grade: quase invisíveis em estado neutro (o cenário real deve
	# aparecer por baixo, não uma planilha) — só ficam nítidas quando há
	# destaque de movimento/ataque/magia ativo, i.e. quando a grid realmente
	# importa pra decisão do jogador.
	var _has_highlight := not (highlight_move.is_empty() and highlight_attack.is_empty() and highlight_attack_range.is_empty() and highlight_spell.is_empty() and highlight_aoe_preview.is_empty())
	var grid_color := Color(ART_DIRECTION.PALETTE["ink"], 0.18 if _has_highlight else 0.04)
	for i in range(board_w + 1):
		draw_line(Vector2(i, 0) * TILE_SIZE, Vector2(i, board_h) * TILE_SIZE, grid_color, 1.0)
	for i in range(board_h + 1):
		draw_line(Vector2(0, i) * TILE_SIZE, Vector2(board_w, i) * TILE_SIZE, grid_color, 1.0)

	# Almas deixadas pelos cadáveres após o contador 3, 2, 1, 0. O desenho
	# procedural mantém o recurso legível mesmo sem depender de um PNG.
	for soul in state.souls:
		_draw_soul(soul)

	# Armadilhas são mecanismos apoiados no terreno, não ícones flutuantes.
	# Regressão corrigida: a Armadilha do Ladino (cast_trap) nasce sem
	# "visible" (só as armadilhas do ambiente/Torre têm visible:true, ver
	# GameState._setup_tower) justamente pra ficar escondida até alguém
	# pisar nela — mas este loop desenhava TODAS as armadilhas sempre,
	# entregando a posição da armadilha escondida na hora que era instalada
	# e anulando a surpresa. Só desenha se for uma armadilha visível por
	# natureza (ambiente) ou já revelada (triggered) por ter sido pisada.
	for trap in state.traps:
		if not trap.get("visible", false) and not trap.get("triggered", false):
			continue
		for tile in trap.get("tiles", []):
			_draw_ground_trap(int(tile["x"]), int(tile["y"]), bool(trap.get("triggered", false)), String(trap.get("kind", "basic")))
	for pickup in state.tower_pickups:
		_draw_tower_pickup(pickup)

	# Destaques de mira (Fase 6): azul = mover, vermelho = atacar, roxo = magia/habilidade selecionada.
	for t in highlight_move:
		var distance := 0
		if state.current_actor != null: distance = absi(int(t["x"])-int(state.current_actor["x"])) + absi(int(t["y"])-int(state.current_actor["y"]))
		var appear := clampf(_highlight_progress * 1.45 - float(distance) * 0.045, 0.0, 1.0)
		var move_rect := tile_rect(t["x"], t["y"]).grow(-lerpf(7.0, 2.0, appear))
		draw_rect(move_rect, Color(ART_DIRECTION.PALETTE["move"], 0.22 * appear))
		draw_rect(move_rect, Color(ART_DIRECTION.PALETTE["move"].lightened(0.28), 0.80 * appear), false, 1.5)
	# Alcance da arma selecionada: preenchimento vermelho suave e borda
	# nítida, equivalente ao azul de movimentação mesmo em casas vazias.
	for t in highlight_attack_range:
		var rect := tile_rect(t["x"], t["y"])
		draw_rect(rect.grow(-2), Color(ART_DIRECTION.PALETTE["attack"], 0.24 * _highlight_progress))
		draw_rect(rect.grow(-4.0), Color(ART_DIRECTION.PALETTE["attack"].lightened(0.12), 0.86 * _highlight_progress), false, 2.0)
	for u in highlight_attack:
		for tile in state.footprint_tiles(u):
			draw_rect(tile_rect(tile["x"], tile["y"]).grow(-3), Color(1.0, 0.25, 0.25, 0.45 * _highlight_progress), false, 3.0)
	for t in highlight_spell:
		var spell_rect := tile_rect(t["x"], t["y"]).grow(-3)
		draw_rect(spell_rect, Color(0.55, 0.25, 0.92, 0.27 * _highlight_progress))
		draw_rect(spell_rect, Color(0.83, 0.58, 1.0, 0.72 * _highlight_progress), false, 1.5)
	for t in highlight_aoe_preview:
		draw_rect(tile_rect(t["x"], t["y"]).grow(-4), Color(1.0, 0.60, 0.08, 0.34 * _highlight_progress))
	if hover_tile != null:
		var hover_rect := tile_rect(hover_tile["x"], hover_tile["y"]).grow(-5.0 - sin(_soul_phase * 2.2) * 1.5)
		var hover_color := Color("73e6ff") if highlight_profile == "move" else (Color("77e5a5") if highlight_profile == "heal" else Color("ff8a72"))
		draw_rect(hover_rect, Color(hover_color, 0.18))
		draw_rect(hover_rect, Color(hover_color, 0.94), false, 3.0)
	if not preview_path.is_empty():
		for index in range(preview_path.size()):
			var step: Dictionary = preview_path[index]
			var center := tile_center(step["x"], step["y"])
			var previous := tile_center(state.current_actor["x"], state.current_actor["y"]) if index == 0 else tile_center(preview_path[index-1]["x"], preview_path[index-1]["y"])
			var direction := (center-previous).normalized()
			draw_circle(center, 5.0, Color(0.72,0.92,1.0,0.82))
			draw_colored_polygon(PackedVector2Array([center+direction*10.0, center-direction.rotated(0.65)*6.0, center-direction.rotated(-0.65)*6.0]), Color(0.78,0.94,1.0,0.88))
	if preview_destination != null:
		var dest_rect := tile_rect(preview_destination["x"], preview_destination["y"]).grow(-8.0 - sin(_soul_phase*2.0)*2.0)
		draw_rect(dest_rect, Color(0.9,0.98,1.0,0.96), false, 3.0)

	# O ator atual recebe um halo dourado pulsante, sempre por cima dos
	# destaques de movimento/mira e por baixo do sprite do personagem.
	if state.current_actor != null and state.current_actor.get("hp", 0) > 0:
		var actor: Dictionary = state.current_actor
		var rect := Rect2(Vector2(actor["x"], actor["y"]) * TILE_SIZE, Vector2(state.footprint_width(actor), state.footprint_height(actor)) * TILE_SIZE)
		var pulse := 0.48 + sin(_soul_phase * 1.8) * 0.16
		draw_ellipse_ring(rect.get_center(), Vector2(rect.size.x*0.39, rect.size.y*0.22), Color(1.0,0.76,0.18,pulse), 4.0)
		draw_ellipse_ring(rect.get_center(), Vector2(rect.size.x*0.31, rect.size.y*0.16), Color(1.0,0.94,0.54,0.66), 2.0)

func draw_ellipse_ring(center: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in 33:
		var angle := TAU * float(index) / 32.0
		points.append(center + Vector2(cos(angle)*radii.x, sin(angle)*radii.y))
	draw_polyline(points, color, width, true)

func _draw_tower_board() -> void:
	var is_floor_2: bool = scenario_definition.get("id", "") == ScenarioManager.TOWER_FLOOR_2
	var is_volcanic_floor: bool = scenario_definition.get("id", "") in [ScenarioManager.TOWER_FLOOR_3, ScenarioManager.TOWER_FLOOR_4]
	var atlas_path := "res://assets/third_party/shattered_pixel_dungeon/environment/tiles_halls.png" if is_volcanic_floor else ("res://assets/third_party/shattered_pixel_dungeon/environment/tiles_sewers.png" if is_floor_2 else "res://assets/third_party/shattered_pixel_dungeon/environment/tiles_prison.png")
	var atlas := _get_tex(atlas_path)
	var prison_water := _get_tex("res://assets/third_party/shattered_pixel_dungeon/environment/water0.png" if is_floor_2 else "res://assets/third_party/shattered_pixel_dungeon/environment/water1.png")
	# Piso contínuo com variações determinísticas (~85/10/5).
	for y in range(GameConstants.BOARD_SIZE):
		for x in range(GameConstants.BOARD_SIZE):
			var selector := posmod(x * 17 + y * 31, 20)
			var floor_index := 0 if selector < 17 else (6 if selector < 19 else 1)
			_draw_spd_atlas_tile(atlas, floor_index, tile_rect(x, y))
	for y in range(GameConstants.BOARD_SIZE):
		for x in range(GameConstants.BOARD_SIZE):
			var terrain = state.terrain_at(x, y)
			if terrain == null: continue
			var type := String(terrain.get("type", ""))
			if type == "tower-wall":
				draw_rect(Rect2(Vector2(x, y) * TILE_SIZE + Vector2(3, 48), Vector2(TILE_SIZE - 6, 13)), Color(0,0,0,0.34))
				_draw_spd_atlas_tile(atlas, 48 + (4 if posmod(x + y, 7) == 0 else 0), tile_rect(x, y))
			elif type == "tower-pillar":
				draw_circle(tile_center(x, y) + Vector2(0, 15), 22, Color(0,0,0,0.35))
				_draw_spd_atlas_tile(atlas, 72, tile_rect(x, y).grow(-5))
			elif type == "tower-door":
				_draw_spd_atlas_tile(atlas, 57 if terrain.get("opened", false) else 56, tile_rect(x, y))
			elif type == "water" and terrain.get("towerPuddle", false):
				var puddle_rect := tile_rect(x, y).grow(-5)
				draw_style_box(_puddle_style(), puddle_rect)
				# Textura de água da prisão do SPD, em vez da faixa lisa colorida.
				draw_texture_rect(prison_water, puddle_rect.grow(-2), true, Color(0.86, 0.96, 1.0, 0.92))
				draw_arc(puddle_rect.get_center()+Vector2(-3,2), 19, 0.18, 2.85, 20, Color(0.62,0.88,0.94,0.62), 2, true)
			elif type == "tower-bookshelf":
				# FLAT_BOOKSHELF do atlas oficial; ocupa visualmente quase toda a casa.
				_draw_spd_atlas_tile(atlas, 67, tile_rect(x, y).grow(-2))
			elif type == "tower-grass":
				_draw_spd_atlas_tile(atlas, 66, tile_rect(x, y).grow(-7))
			elif type == "tower-vase":
				# Barril real (assets/props/tower/barrel.png) — o mesmo prop já usado
				# nos barris decorativos, agora como o breakável funcional (5 HP).
				draw_texture_rect(_get_tex("res://assets/props/tower/barrel.png"), tile_rect(x, y).grow(-6), false)
			elif type == "tower-pot-shards":
				var debris_center := tile_center(x,y) + Vector2(0,15)
				for i in 5:
					var offset := Vector2(-18+i*9, -5+posmod(i*7,11))
					draw_line(debris_center+offset, debris_center+offset+Vector2(7,-4), Color("8a542f"), 4, true)
			elif type == "tower-ashes":
				draw_circle(tile_center(x, y) + Vector2(0, 18), 16, Color(0.12,0.10,0.10,0.72))
			elif type == "hazard" and terrain.get("hazard", "") == "lava":
				_draw_lava_tile(x, y)
			elif type == "hazard" and terrain.get("hazard", "") == "poison-gas":
				_draw_poison_gas_tile(x, y)
	for deco in scenario_definition.get("decorations", []):
		var rect := tile_rect(deco["x"], deco["y"])
		match String(deco["kind"]):
			"stairs": _draw_spd_atlas_tile(atlas, 17, rect)
			"entrance": _draw_spd_atlas_tile(atlas, 16, rect)
			"books": _draw_spd_atlas_tile(atlas, 50, rect)
			"debris": _draw_spd_atlas_tile(atlas, 1, rect)
			"scorched-rubble":
				draw_circle(rect.get_center() + Vector2(0, 14), 19, Color(0.09,0.055,0.045,0.82))
				_draw_spd_atlas_tile(atlas, 1, rect.grow(-8))
			"lava-wall-flow": _draw_lava_wall_flow(rect, int(deco["x"]) + int(deco["y"]) * 5)
			"rune":
				draw_arc(rect.get_center(), 15, 0, TAU, 8, Color(0.55,0.68,0.88,0.38), 2, true)
	# O segundo andar é mais úmido e escuro; a camada azul-esverdeada mantém
	# a leitura da grade sem parecer um cenário externo.
	var darkness := Color(0.19,0.025,0.005,0.16) if is_volcanic_floor else (Color(0.025,0.11,0.10,0.28) if is_floor_2 else Color(0.08,0.09,0.14,0.17))
	draw_rect(Rect2(Vector2.ZERO, Vector2(GameConstants.BOARD_SIZE, GameConstants.BOARD_SIZE) * TILE_SIZE), darkness)

## Pedido do usuário: lava "muito melhorada", com qualidade parecida com o
## rio do Campo (_draw_river_bands) — superfície animada, profundidade,
## bordas orgânicas — mas em poças paradas (nunca correndo feito rio).
## Cada tile é desenhado como manchas sobrepostas (não um quadrado duro), o
## que também faz poças vizinhas emendarem visualmente numa só mancha
## orgânica. Sem Light2D por tile (custaria caro com várias poças na tela);
## o "aquecimento" do ambiente ao redor é só um glow pintado por baixo dos
## props/paredes/personagens, que já são desenhados depois no mesmo _draw().
func _draw_lava_tile(x: int, y: int) -> void:
	var rect := tile_rect(x, y)
	var center := rect.get_center()
	var pulse := 0.5 + sin(_soul_phase * 1.6 + x * 0.8 + y * 0.55) * 0.5
	draw_circle(center, TILE_SIZE * 0.95, Color(1.0, 0.42, 0.08, 0.10 + pulse * 0.05))
	draw_rect(rect.grow(-1), Color("3a0a05"))
	for i in 5:
		var ox := sin(float(i) * 2.4 + x * 1.3) * 14.0
		var oy := cos(float(i) * 1.9 + y * 1.1) * 12.0
		var r := 16.0 + float(posmod(x * 13 + y * 7 + i * 11, 9))
		draw_circle(center + Vector2(ox, oy), r, Color("6b1806"))
	for i in 4:
		var ox := sin(float(i) * 3.1 + x * 0.7 + _soul_phase * 0.3) * 10.0
		var oy := cos(float(i) * 2.6 + y * 0.9) * 9.0
		var r := 10.0 + float(posmod(x * 7 + y * 17 + i * 5, 6))
		draw_circle(center + Vector2(ox, oy), r, Color(0.92, 0.24 + pulse * 0.10, 0.03, 0.96))
	draw_circle(center + Vector2(sin(_soul_phase * 0.7 + x) * 6.0, cos(_soul_phase * 0.6 + y) * 5.0), 8.0 + pulse * 3.0, Color(1.0, 0.62 + pulse * 0.2, 0.10, 0.92))
	# Bolhas: crescem e estouram num anel que some, em vez de pontinhos fixos.
	for i in 3:
		var seed := x * 19 + y * 11 + i * 23
		var t := fmod(_soul_phase * 0.9 + float(posmod(seed, 17)) * 0.31, TAU) / TAU
		var bx := float(posmod(seed, 41)) - 20.0
		var by := float(posmod(seed * 3, 37)) - 18.0
		if t < 0.7:
			draw_circle(center + Vector2(bx, by), 1.0 + t * 5.0, Color(1.0, 0.82, 0.25, 0.9))
		else:
			var pop_t := (t - 0.7) / 0.3
			draw_arc(center + Vector2(bx, by), 4.0 + pop_t * 3.0, 0, TAU, 10, Color(1.0, 0.85, 0.4, (1.0 - pop_t) * 0.85), 1.4, true)
	# Brasa ocasional subindo — só em 1 a cada 5 tiles, pra não virar chuva
	# de partículas.
	if posmod(x * 31 + y * 17, 5) == 0:
		var ember_t := fmod(_soul_phase * 0.5 + float(x + y) * 0.13, 1.0)
		var ember_pos := center + Vector2(sin(float(x) * 1.7) * 10.0, 20.0 - ember_t * 46.0)
		draw_circle(ember_pos, 1.6 * (1.0 - ember_t * 0.5), Color(1.0, 0.75, 0.3, (1.0 - ember_t) * 0.85))

## Névoa venenosa do 2º Andar: verde, translúcida, ondula perto do chão sem
## esconder o tile por baixo (pedido do usuário). Nuvens sobrepostas que
## derivam devagar, parecido com o procedural de "poison" em
## UnitToken._draw() mas pintado no próprio tile em vez de sobre a unidade.
func _draw_poison_gas_tile(x: int, y: int) -> void:
	var center := tile_center(x, y)
	for i in 4:
		var drift := sin(_soul_phase * 0.55 + float(i) * 1.9 + x * 0.6) * 8.0
		var ox := cos(float(i) * 2.1 + y * 0.7) * 16.0 + drift
		var oy := sin(float(i) * 1.6 + x * 0.4) * 12.0
		var r := 14.0 + float(posmod(x * 11 + y * 5 + i * 7, 7))
		draw_circle(center + Vector2(ox, oy), r, Color(0.24, 0.68, 0.22, 0.16))
	draw_circle(center, 20.0 + sin(_soul_phase * 0.8 + x + y) * 3.0, Color(0.42, 0.90, 0.35, 0.10))

func _draw_lava_wall_flow(rect: Rect2, seed: int) -> void:
	var pulse := 0.72 + sin(_soul_phase * 2.0 + seed) * 0.18
	var center := rect.get_center().x
	draw_line(Vector2(center - 5, rect.position.y + 4), Vector2(center + 2, rect.end.y - 7), Color(0.42,0.045,0.01,0.92), 16.0, true)
	draw_line(Vector2(center - 3, rect.position.y + 5), Vector2(center + 2, rect.end.y - 8), Color(1.0,0.25,0.015,pulse), 9.0, true)
	draw_line(Vector2(center, rect.position.y + 6), Vector2(center + 4, rect.end.y - 10), Color(1.0,0.72,0.12,pulse), 3.0, true)
	draw_circle(Vector2(center + 2, rect.end.y - 8), 13.0, Color(0.92,0.16,0.01,0.74))

## Vila medieval atacada. Casas/moinho usam os sprites reais renderizados a
## partir do Medieval Village MegaKit (ver VILLAGE_BUILDING_TEXTURES);
## fogo/sombra continuam procedurais por cima pra preservar a animação e a
## leitura da grade.
func _draw_village_board() -> void:
	# Terra irregular por cima da grama, com pequenas variações determinísticas.
	for tile in scenario_definition.get("dirt", []):
		var rect := tile_rect(tile["x"], tile["y"])
		draw_rect(rect, Color("8b623d"))
		var fleck := Vector2(12 + posmod(tile["x"] * 17 + tile["y"] * 5, 38), 13 + posmod(tile["x"] * 7 + tile["y"] * 19, 36))
		draw_circle(rect.position + fleck, 3.0, Color(0.31,0.20,0.12,0.26))
	# Mesma linguagem visual/gradiente de água do Campo, em uma curva curta.
	_draw_river_bands(_village_stream_points())
	var house_count := 0
	for building in scenario_definition.get("buildings", []):
		if String(building.get("kind", "")) == "village-house":
			_draw_village_building(building, house_count)
			house_count += 1
		else:
			_draw_village_building(building, 0)
	for deco in scenario_definition.get("decorations", []):
		var c := tile_center(deco["x"], deco["y"])
		if deco["kind"] == "village-char":
			draw_ellipse_shadow(c + Vector2(0,13), Vector2(24,10), Color(0.08,0.06,0.05,0.55))
		elif deco["kind"] == "village-debris":
			for i in 4:
				var a := -0.65 + i * 0.42
				draw_line(c + Vector2(-21+i*11,11), c + Vector2(-7+i*9,-7).rotated(a), Color("5a321f"), 7, true)
		# Demais kinds ("village-wagon"/"village-crate"/"village-fence"/
		# "village-rubble") são props curados de verdade, desenhados por
		# _draw_curated_props() (chamada incondicional no _draw() principal)
		# — não duplicar aqui.

func _draw_village_building(building: Dictionary, house_index: int) -> void:
	var rect := Rect2(Vector2(building["x"], building["y"]) * TILE_SIZE, Vector2(building["w"], building["h"]) * TILE_SIZE).grow(-5)
	draw_ellipse_shadow(rect.get_center() + Vector2(0, rect.size.y * 0.38), Vector2(rect.size.x * 0.43, 15), Color(0.03,0.02,0.02,0.42))
	var kind := String(building.get("kind", ""))
	var tex_path: String = ""
	if kind == "village-mill":
		tex_path = VILLAGE_MILL_TEXTURE
	elif kind == "village-house":
		# Cicla pela ordem em que as casas aparecem em "buildings" — garante
		# variedade previsível (não aleatória) em vez de repetir sempre a
		# mesma arte nas 4 casas.
		tex_path = VILLAGE_HOUSE_TEXTURES[house_index % VILLAGE_HOUSE_TEXTURES.size()]
	var destination := rect
	if tex_path != "":
		var tex := _get_tex(tex_path)
		destination = _contain_rect(rect, tex.get_size())
		draw_texture_rect(tex, destination, false)
	if building.get("burning", false):
		for i in 3:
			var base := destination.position + Vector2(destination.size.x * (0.22 + i * 0.28), destination.size.y * 0.32)
			_draw_village_flame(base, i)

## Encaixa `tex_size` centralizado dentro de `bounds` preservando proporção
## (equivalente a `background-size: contain`) — evita esticar/achatar os
## sprites reais da casa/moinho, cujo recorte é bem mais alto que largo e
## não bate 1:1 com o retângulo (às vezes 3x2, às vezes 2x3) do prédio.
func _contain_rect(bounds: Rect2, tex_size: Vector2) -> Rect2:
	var scale_factor: float = minf(bounds.size.x / tex_size.x, bounds.size.y / tex_size.y)
	var size := tex_size * scale_factor
	var position := bounds.position + (bounds.size - size) * 0.5
	return Rect2(position, size)

func _draw_village_flame(base: Vector2, seed: int) -> void:
	var pulse := sin(_soul_phase * 3.6 + seed * 1.7)
	var tip := base + Vector2(pulse*5,-30-pulse*5)
	draw_colored_polygon(PackedVector2Array([base+Vector2(-13,5),base+Vector2(-8,-13),tip,base+Vector2(11,-10),base+Vector2(14,5)]),Color(1.0,0.24,0.04,0.88))
	draw_colored_polygon(PackedVector2Array([base+Vector2(-6,4),base+Vector2(-3,-9),tip+Vector2(2,10),base+Vector2(7,4)]),Color(1.0,0.78,0.12,0.94))
	draw_circle(base+Vector2(0,-34),10+pulse*2,Color(0.13,0.10,0.10,0.18))

## Curva visual do rio da Vila — acompanha as células reais de "water" em
## _village_definition() (colunas 11-12, linha 0 até a 12), com uma leve
## serpenteada em vez de retas perfeitas. Nasce fora do tabuleiro na borda
## de cima e termina fora na borda de baixo (pedido do usuário: o rio
## atravessa o cenário inteiro em vez de parar num lago isolado no canto).
func _village_stream_points() -> PackedVector2Array:
	var result := PackedVector2Array()
	result = _append_river_curve(result,Vector2(13.3,-0.3),Vector2(11.8,0.0),Vector2(10.5,0.5),Vector2(10.8,1.7))
	result = _append_river_curve(result,Vector2(10.8,1.7),Vector2(10.9,2.4),Vector2(11.6,2.5),Vector2(12.5,3.6),true)
	result = _append_river_curve(result,Vector2(12.5,3.6),Vector2(12.3,5.0),Vector2(11.3,6.4),Vector2(11.6,8.0),true)
	result = _append_river_curve(result,Vector2(11.6,8.0),Vector2(11.9,9.2),Vector2(11.2,10.5),Vector2(11.5,11.8),true)
	result = _append_river_curve(result,Vector2(11.5,11.8),Vector2(11.6,12.4),Vector2(11.5,12.9),Vector2(11.5,13.3),true)
	for i in range(result.size()): result[i] *= TILE_SIZE
	return result

## Floresta: só desenha a trilha de terra (colunas 5-7). As árvores dos lados
## já são terreno real ("tree", ver GameState._setup_forest) e caem
## automaticamente no loop genérico de terreno estático lá em cima em
## _draw() — mesmo caminho que desenha as árvores do Campo, só que com arte
## própria (forest_tree/forest_pine/forest_birch.png).
func _draw_forest_board() -> void:
	for tile in scenario_definition.get("path", []):
		var rect := tile_rect(tile["x"], tile["y"])
		draw_rect(rect, Color("8b623d"))
		var fleck := Vector2(12 + posmod(tile["x"] * 17 + tile["y"] * 5, 38), 13 + posmod(tile["x"] * 7 + tile["y"] * 19, 36))
		draw_circle(rect.position + fleck, 3.0, Color(0.31,0.20,0.12,0.26))

## Maior dimensão (largura ou altura, em px) que cada prop "village-*" pode
## ocupar antes de escalar preservando proporção — variam muito de forma
## (carroça alongada, cerca larga e baixa, entulho pequeno), então um
## quadrado fixo como os demais props curados esticaria/achataria demais.
const VILLAGE_PROP_MAX_DIM := {
	"village-wagon": 110.0,
	"village-crate": 60.0,
	"village-fence": 92.0,
	"village-rubble": 46.0,
	"village-well": 78.0,
	"village-coop": 84.0,
	"village-farmfence": 128.0,
	"village-barn": 150.0,
	"village-boat": 70.0,
	"village-silo": 110.0,
	"village-watertower": 120.0,
	"village-smallbarn": 130.0,
	"village-openbarn": 130.0,
	"village-tree1": 100.0,
	"village-tree2": 100.0,
	"village-tree3": 100.0,
	"village-tree4": 100.0,
	"village-tree5": 100.0,
}

## Props transparentes curados da biblioteca externa. São declarados como
## decoração no cenário, não entram no terrainMap e nunca alteram colisão,
## custo de movimento, targeting ou fila de turnos.
func _draw_curated_props() -> void:
	for decoration in scenario_definition.get("decorations", []):
		var kind := String(decoration.get("kind", ""))
		if not CURATED_PROP_TEXTURES.has(kind):
			continue
		var center := tile_center(int(decoration["x"]), int(decoration["y"]))
		var tex := _get_tex(CURATED_PROP_TEXTURES[kind])
		var village_prop := kind.begins_with("village-")
		var hazard_prop := kind.begins_with("lava-") or kind.begins_with("corpse-")
		var size: Vector2
		var tint := Color.WHITE
		if village_prop:
			var tex_size: Vector2 = tex.get_size()
			var max_dim: float = VILLAGE_PROP_MAX_DIM.get(kind, 64.0)
			size = tex_size * (max_dim / maxf(tex_size.x, tex_size.y))
		elif hazard_prop:
			# Cores reais preservadas (sem tingimento) — a arte já é
			# estilizada pro tema volcânico/decomposição.
			var tex_size: Vector2 = tex.get_size()
			var max_dim: float = HAZARD_PROP_MAX_DIM.get(kind, 60.0)
			size = tex_size * (max_dim / maxf(tex_size.x, tex_size.y))
		else:
			var tower_prop := kind.begins_with("tower-")
			size = Vector2(72, 72) if tower_prop else (Vector2(84, 84) if kind == "field-logs" else Vector2(56, 56))
			tint = Color(0.76, 0.70, 0.60) if tower_prop else Color(0.72, 0.78, 0.62)
		var destination := Rect2(center - size * 0.5, size)
		var shadow_size := Vector2(size.x * 0.58, size.y * 0.18)
		draw_set_transform(center + Vector2(0, size.y * 0.30), 0.0, shadow_size)
		draw_circle(Vector2.ZERO, 0.5, Color(0.02, 0.025, 0.03, 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_texture_rect(tex, destination, false, tint)
		# Props curados também podem pegar fogo (pedido do usuário pros props
		# de fazenda da Vila) — mesma chama procedural das casas/moinho
		# (_draw_village_flame), ancorada perto do topo do sprite em vez do
		# ponto fixo usado pra prédios com "buildings" própria.
		if decoration.get("burning", false):
			var flame_base := destination.position + Vector2(destination.size.x * 0.5, destination.size.y * 0.3)
			_draw_village_flame(flame_base, int(decoration["x"]) * 7 + int(decoration["y"]) * 13)

## Vale de Lua/Horda: renderiza os tiles REAIS do mapa inicial do
## Legend of Lua (`legend-of-lua-main/maps/test.lua`), amostrados direto do
## atlas original `overworld_edit_atlas.png` — sem montanha/água/cachoeira
## genéricas. Layout e GIDs vêm de `LuaValleyLayout`
## (data/lua_valley_layout.gd); ver ASSET_SOURCES.md para a proveniência.
func _draw_lua_valley_board() -> void:
	var atlas := _get_tex(LuaValleyLayout.ATLAS_PATH)
	for y in LuaValleyLayout.GRID_HEIGHT:
		for x in LuaValleyLayout.GRID_WIDTH:
			var base_gid: int = LuaValleyLayout.gid(LuaValleyLayout.BASE_GIDS, x, y)
			if base_gid != 0:
				_draw_lua_atlas_tile(atlas, _lua_animated_gid(base_gid), tile_rect(x, y))
	# Segunda passada: tronco/pedras/flor (camada "Objects") por cima do chão.
	for y in LuaValleyLayout.GRID_HEIGHT:
		for x in LuaValleyLayout.GRID_WIDTH:
			var obj_gid: int = LuaValleyLayout.gid(LuaValleyLayout.OBJECTS_GIDS, x, y)
			if obj_gid != 0:
				_draw_lua_atlas_tile(atlas, obj_gid, tile_rect(x, y))
	_draw_lua_ladder()
	for ripple in _lua_ripples:
		_draw_lua_ripple(ripple)

func _draw_lua_ladder() -> void:
	var tiles: Array = LuaValleyLayout.LADDER_TILES
	if tiles.is_empty(): return
	var ladder := _get_tex(LuaValleyLayout.LADDER_PATH)
	var top: Dictionary = tiles[0]
	var destination := Rect2(Vector2(int(top["x"]), int(top["y"])) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE * tiles.size()))
	# Sombra curta dá leitura contra a rocha sem encobrir os degraus.
	draw_rect(Rect2(destination.position + Vector2(23, 3), Vector2(18, destination.size.y - 6)), Color(0.03, 0.025, 0.02, 0.22))
	draw_texture_rect(ladder, destination, false)

func _draw_lua_atlas_tile(atlas: Texture2D, id: int, destination: Rect2) -> void:
	var src := LuaValleyLayout.atlas_rect(id)
	draw_texture_rect_region(atlas, destination, Rect2(src.position, src.size))

## Troca o gid pelo seu frame de animação atual, reaproveitando as durações
## REAIS gravadas no Tiled (100ms/frame na queda, 200ms/frame na espuma da
## base) — não é um timing novo, é o mesmo do mapa original.
func _lua_animated_gid(base_gid: int) -> int:
	if LuaValleyLayout.WATERFALL_ANIM.has(base_gid):
		var frames: Array = LuaValleyLayout.WATERFALL_ANIM[base_gid]
		var idx := int(_anim_time_ms / LuaValleyLayout.WATERFALL_ANIM_FRAME_MS) % frames.size()
		return frames[idx]
	if LuaValleyLayout.FOAM_ANIM.has(base_gid):
		var frames: Array = LuaValleyLayout.FOAM_ANIM[base_gid]
		var idx := int(_anim_time_ms / LuaValleyLayout.FOAM_ANIM_FRAME_MS) % frames.size()
		return frames[idx]
	return base_gid

## Ondulações da água: reaproveita o comportamento e o sprite reais de
## `src/environment/water.lua`/`sprites/environment/wave.png` do Legend of
## Lua — partícula de onda numa célula de água aleatória, em intervalo
## aleatório, tocando 1x e sumindo (17 frames a 0.07s cada).
func _update_lua_ripples(delta: float) -> void:
	var alive: Array = []
	for ripple in _lua_ripples:
		ripple["age"] += delta
		if ripple["age"] < LUA_RIPPLE_LIFETIME:
			alive.append(ripple)
	_lua_ripples = alive
	_lua_ripple_timer -= delta
	if _lua_ripple_timer <= 0.0:
		_lua_ripple_timer = randf_range(0.5, 1.3)
		var water_tiles: Array = scenario_definition.get("water", [])
		if not water_tiles.is_empty():
			var cell: Dictionary = water_tiles[randi() % water_tiles.size()]
			_lua_ripples.append({"x": int(cell["x"]), "y": int(cell["y"]), "age": 0.0})

func _draw_lua_ripple(ripple: Dictionary) -> void:
	var wave := _get_tex(LuaValleyLayout.WAVE_PATH)
	var frame := clampi(int(ripple["age"] / LUA_RIPPLE_FRAME_S), 0, LUA_RIPPLE_FRAMES - 1)
	var size := Vector2(TILE_SIZE, TILE_SIZE) * 0.7
	var destination := Rect2(tile_center(ripple["x"], ripple["y"]) - size * 0.5, size)
	draw_texture_rect_region(wave, destination, Rect2(frame * 16, 0, 16, 16))

func _draw_spd_atlas_tile(atlas: Texture2D, index: int, destination: Rect2) -> void:
	var source := Rect2(Vector2(index % 16, index / 16) * 16.0, Vector2(16, 16))
	draw_texture_rect_region(atlas, destination, source)

func _draw_item_atlas(index: int, destination: Rect2) -> void:
	var atlas := _get_tex("res://assets/third_party/shattered_pixel_dungeon/sprites/items.png")
	var source := Rect2(Vector2(index % 16, index / 16) * 16.0, Vector2(16, 16))
	draw_texture_rect_region(atlas, destination, source)

func _draw_tower_pickup(pickup: Dictionary) -> void:
	var index: int = 352 if pickup.get("kind", "hp") == "hp" else 357
	# Poções legíveis no tabuleiro, mantendo margem para highlights da grid.
	_draw_item_atlas(index, tile_rect(pickup["x"], pickup["y"]).grow(-5))

func _puddle_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08,0.31,0.43,0.94)
	style.border_color = Color(0.26,0.57,0.63,0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	return style

func _draw_ground_trap(x: int, y: int, triggered: bool, kind: String = "basic") -> void:
	var features := _get_tex("res://assets/third_party/shattered_pixel_dungeon/environment/terrain_features.png")
	var color_index: int = 8 if triggered else int({"poison-arrow":3,"corrosive-gas":2,"poison-gas":3,"fire":0}.get(kind,7))
	# Trap.CROSSHAIR=5: a cruz original do atlas, ampliada para 54x54 px.
	draw_texture_rect_region(features, tile_rect(x,y).grow(-5), Rect2(color_index*16,5*16,16,16))

func draw_ellipse_shadow(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)

func _draw_soul(soul: Dictionary) -> void:
	var x: int = int(soul["x"])
	var y: int = int(soul["y"])
	var bob := sin(_soul_phase + float(x + y) * 0.7) * 4.0
	var center := tile_center(x, y) + Vector2(0, bob - 4)
	# GhostSprite: o Fantasma Triste que oferece a primeira sidequest do SPD.
	# Idle original alterna os frames 0 e 1 a 5 FPS, cada um com 14x15 px.
	var ghost := _get_tex("res://assets/third_party/shattered_pixel_dungeon/sprites/ghost.png")
	var frame := posmod(int(_soul_phase * 5.0), 2)
	var destination := Rect2(center - Vector2(24, 27), Vector2(48, 51))
	draw_circle(center, 27.0 + sin(_soul_phase) * 2.0, Color(0.58, 0.92, 1.0, 0.18))
	draw_texture_rect_region(ghost, destination, Rect2(frame * 14, 0, 14, 15), Color(0.88, 0.97, 1.0, 0.96))
	var hp_amount: int = int(soul.get("hpAmount", 10))
	var mp_amount: int = int(soul.get("mpAmount", 5))
	draw_string(ThemeDB.fallback_font, center + Vector2(-25, 29), "+%d HP  +%d MP" % [hp_amount, mp_amount], HORIZONTAL_ALIGNMENT_CENTER, 50, 9, Color(0.9, 1, 1, 0.95))

func _draw_continuous_river() -> void:
	var points: PackedVector2Array = _river_curve_points()
	_draw_river_bands(points)

## Bandas/gradiente + brilho de correnteza de um curso d'água contínuo —
## reaproveitado pelo rio fixo do Campo (_draw_continuous_river) e pelo rio
## real do Vale de Lua (_draw_lua_river), cada um com seus próprios pontos.
func _draw_river_bands(points: PackedVector2Array) -> void:
	if points.size() < 2: return
	# Margem orgânica contínua, profundidade e duas faixas internas formam
	# um gradiente sem introduzir qualquer recorte entre quadrados.
	draw_polyline(points, Color("36582e"), TILE_SIZE * 1.30, true)
	draw_polyline(points, Color("123f5c"), TILE_SIZE * 1.08, true)
	draw_polyline(points, Color("1d6687"), TILE_SIZE * 0.98, true)
	draw_polyline(points, Color(0.20, 0.56, 0.67, 0.72), TILE_SIZE * 0.72, true)
	draw_polyline(points, Color(0.28, 0.66, 0.73, 0.30), TILE_SIZE * 0.42, true)

	# Pequenos traços claros percorrem a curva para sugerir correnteza. São
	# desenhados sobre o mesmo caminho, portanto também atravessam as emendas.
	var phase_index: int = int(floorf(_soul_phase * 7.0))
	for i in range(points.size() - 1):
		# A curva está armazenada da nascente (topo) para a foz (parte
		# inferior). Subtrair a fase faz os brilhos avançarem nesse mesmo
		# sentido; somar fazia a corrente parecer subir até a cachoeira.
		if posmod(i - phase_index, 13) < 4:
			draw_line(points[i], points[i + 1], Color(0.78, 0.96, 0.95, 0.46), 2.2, true)

func _river_curve_points() -> PackedVector2Array:
	# Porte do SVG contínuo da versão Browser. Os pontos estão em unidades
	# de tile e passam pelo centro do mesmo conjunto TERRAIN_LAYOUT.water.
	var result := PackedVector2Array()
	var start := Vector2(6.5, -0.3)
	result = _append_river_curve(result, start, Vector2(6.35, 0.8), Vector2(6.34, 1.7), Vector2(6.7, 2.35))
	start = Vector2(6.7, 2.35)
	result = _append_river_curve(result, start, Vector2(7.12, 3.05), Vector2(7.55, 3.7), Vector2(7.48, 4.65), true)
	start = Vector2(7.48, 4.65)
	result = _append_river_curve(result, start, Vector2(7.4, 5.55), Vector2(7.18, 6.05), Vector2(6.72, 6.55), true)
	start = Vector2(6.72, 6.55)
	result = _append_river_curve(result, start, Vector2(6.35, 7.02), Vector2(6.42, 8.12), Vector2(6.5, 9.1), true)
	start = Vector2(6.5, 9.1)
	result = _append_river_curve(result, start, Vector2(6.58, 10.08), Vector2(6.55, 10.72), Vector2(6.5, 11.25), true)
	start = Vector2(6.5, 11.25)
	result = _append_river_curve(result, start, Vector2(6.46, 11.72), Vector2(6.5, 12.25), Vector2(6.5, 13.3), true)
	for i in range(result.size()): result[i] *= TILE_SIZE
	return result

func _append_river_curve(points: PackedVector2Array, start: Vector2, control_a: Vector2, control_b: Vector2, finish: Vector2, skip_first: bool = false) -> PackedVector2Array:
	var samples := 18
	for i in range(samples + 1):
		if skip_first and i == 0: continue
		var t := float(i) / float(samples)
		points.append(start.bezier_interpolate(control_a, control_b, finish, t))
	return points
