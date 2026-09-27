extends Node2D
class_name BoardView

const ART_DIRECTION := preload("res://data/art_direction_config.gd")

## Desenha o tabuleiro 13x13 (terreno + estruturas) a partir de um
## GameState — puramente apresentação, não decide nenhuma regra (mesmo
## papel que scene3d.js tinha no protótipo JS: só lê o estado já calculado
## pelo motor). Reaproveita os PNGs de assets/tiles/ copiados do protótipo.

## Pedido do usuário: tiles 50% maiores (era 64). Única fonte de verdade pro
## tamanho do tile — quase todo o desenho de terreno/estruturas neste arquivo
## já é parametrizado por TILE_SIZE, então o aumento se propaga sozinho.
const TILE_SIZE := 96

var state: GameState
var scenario_definition: Dictionary = {"id": ScenarioManager.FIELD}

func _is_campo_like(id: String) -> bool:
	return id == ScenarioManager.FIELD

## Overlay de debug temporário (pedido do usuário pro PORTO, mas genérico —
## funciona em qualquer cenário): verde translúcido em tiles battleable e
## livres (GameState.is_battleable + sem ocupante), vermelho no resto.
## Desligado por padrão, sem custo nenhum quando false. Ver
## _draw_battleable_debug().
var debug_show_battleable: bool = false

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
## --- Zoom/arraste interativos (pedido do usuário) -------------------------
## Fonte única de verdade pro zoom e deslocamento de câmera do jogador —
## _update_camera() é a ÚNICA função que lê essas duas variáveis pra
## calcular camera.zoom/camera.position; tudo (botões de zoom, arrastar com o
## mouse) só MUDA view_zoom/view_pan e chama _update_camera() de novo, nunca
## mexe na câmera diretamente. Só vale pra cenários "soltos" (Campo/Torre/
## Vila) — a Horda mantém sua janela fixa 13x13 (LUA_VALLEY_CROP_ORIGIN),
## sem zoom nem arrasto, exatamente como já era.
## Pedido do usuário: alcance de zoom limitado a 60%-120% (era 50%-200%).
const VIEW_ZOOM_MIN := 0.6
const VIEW_ZOOM_MAX := 1.2
const VIEW_ZOOM_STEP := 0.2
var view_zoom := 1.0
## Deslocamento em pixels do MUNDO (não de tela) somado ao centro do tabuleiro
## pra decidir o que a câmera mostra — positivo desloca a área visível pra
## direita/baixo. Clampado a cada _update_camera() conforme o zoom atual (ver
## _clamp_view_pan), então nunca precisa ser resetado manualmente ao mudar
## de zoom, só recalculado.
var view_pan := Vector2.ZERO
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
## Nós do chão/props/luzes/névoa dos cenários de props recortados
## (TEMPLO/CEMITÉRIO, ver SceneryVisuals) — recriados a cada troca de cenário.
var _scenery_nodes: Array = []
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
		# Pedido do usuário: Castelo/Montanha do Campo pareciam "flutuando" com
		# essa sombra (calibrada pro tronco fino de uma árvore, não pra base de
		# uma estrutura 3x3 inteira) — removida só pra esses dois kinds.
		if kind != "castle" and kind != "mountain":
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
	# Píer do PORTO: tábuas reais (recorte da referência do usuário, ver
	# ASSET_SOURCES.md), desenhadas tile a tile pelo loop genérico acima
	# (textura repete bem, ao contrário de "porto-water" — ver
	# _draw_porto_board() pra água/estrada, que precisam de composição
	# própria e por isso NÃO entram aqui).
	"porto-pier": "res://assets/props/porto/pixel/porto_dock_plank.png",
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
	# Obstáculos novos da Vila (Kenney Fantasy Town, CC0 — ver ASSET_SOURCES.md):
	# ao contrário dos demais props curados acima (puramente decorativos), estes
	# três têm sua célula incluída em "blocked_tiles" por _village_definition()
	# (scenario_manager.gd), então bloqueiam movimento de verdade.
	"village-fence-broken": "res://assets/props/village/village_fence_broken.png",
	"village-barricade": "res://assets/props/village/village_barricade.png",
	"village-bridge-broken": "res://assets/props/village/village_bridge_broken.png",
	# Carroça de mercador do PORTO (Kenney Fantasy Town, CC0 — ver
	# ASSET_SOURCES.md) — sem equivalente no recorte pixel-art da referência,
	# mantém o asset 3D original; os demais props do PORTO abaixo são
	# recortes reais da própria imagem de referência do usuário.
	"porto-cart": "res://assets/props/porto/porto_cart.png",
	"porto-fence": "res://assets/props/porto/pixel/porto_fence.png",
	"porto-barrel": "res://assets/props/porto/pixel/porto_barrel.png",
	"porto-barrel-stack": "res://assets/props/porto/pixel/porto_barrel_stack.png",
	"porto-crate": "res://assets/props/porto/pixel/porto_crate.png",
	"porto-mossy-rock": "res://assets/props/porto/pixel/porto_mossy_rock.png",
	"porto-boat": "res://assets/props/porto/pixel/porto_boat.png",
	"porto-market-stall": "res://assets/props/porto/pixel/porto_market_stall.png",
	"porto-awning": "res://assets/props/porto/pixel/porto_awning.png",
	"porto-lantern-post": "res://assets/props/porto/pixel/porto_lantern_post.png",
	"porto-lilypad": "res://assets/props/porto/pixel/porto_lilypad.png",
	# Pedido do usuário (enriquecimento de decoração, prioridade no canto
	# superior direito): recortes reais fornecidos pelo usuário fora do
	# projeto (pasta `porto/`) — ver ASSET_SOURCES.md pra origem de cada um.
		# "porto-house-2" é uma segunda casa, tratada como prop curado para
		# manter a definição do cenário simples, mas renderizada em uma área 2x2.
	"porto-house-2": "res://assets/props/porto/pixel/porto_house_2.png",
	"porto-tree": "res://assets/props/porto/pixel/porto_tree.png",
	"porto-lamp": "res://assets/props/porto/pixel/porto_lamp.png",
	"porto-crate-2": "res://assets/props/porto/pixel/porto_crate_2.png",
	"porto-sacks": "res://assets/props/porto/pixel/porto_sacks.png",
	# Obstáculos e decorações do DESFILADEIRO — recortes reais da imagem de
	# referência do usuário (ver assets/props/desfiladeiro/ASSET_SOURCES.md):
	# 4 pedras, 4 lápides/monólitos e a rocha de cristal, um kind por
	# instância pra usar cada recorte sem repetir a mesma arte.
	"desfiladeiro-rock-1": "res://assets/props/desfiladeiro/desfiladeiro_rock_1.png",
	"desfiladeiro-rock-2": "res://assets/props/desfiladeiro/desfiladeiro_rock_2.png",
	"desfiladeiro-rock-3": "res://assets/props/desfiladeiro/desfiladeiro_rock_3.png",
	"desfiladeiro-rock-4": "res://assets/props/desfiladeiro/desfiladeiro_rock_4.png",
	"desfiladeiro-monolith-1": "res://assets/props/desfiladeiro/desfiladeiro_monolith_1.png",
	"desfiladeiro-monolith-2": "res://assets/props/desfiladeiro/desfiladeiro_monolith_2.png",
	"desfiladeiro-monolith-3": "res://assets/props/desfiladeiro/desfiladeiro_monolith_3.png",
	"desfiladeiro-monolith-4": "res://assets/props/desfiladeiro/desfiladeiro_monolith_4.png",
	"desfiladeiro-crystal": "res://assets/props/desfiladeiro/desfiladeiro_crystal_rock.png",
	"desfiladeiro-bush-1": "res://assets/props/desfiladeiro/desfiladeiro_bush_1.png",
	"desfiladeiro-bush-2": "res://assets/props/desfiladeiro/desfiladeiro_bush_2.png",
	"desfiladeiro-bush-3": "res://assets/props/desfiladeiro/desfiladeiro_bush_3.png",
	# Obstáculos e decorações da ESTRADA INVERNO — recortes reais da imagem de
	# referência do usuário (ver assets/props/estrada_inverno/ASSET_SOURCES.md).
	"estrada-inverno-well": "res://assets/props/estrada_inverno/estrada_inverno_well.png",
	"estrada-inverno-rock-1": "res://assets/props/estrada_inverno/estrada_inverno_rock_1.png",
	"estrada-inverno-rock-2": "res://assets/props/estrada_inverno/estrada_inverno_rock_2.png",
	"estrada-inverno-rock-3": "res://assets/props/estrada_inverno/estrada_inverno_rock_3.png",
	"estrada-inverno-barrel-1": "res://assets/props/estrada_inverno/estrada_inverno_barrel_1.png",
	"estrada-inverno-barrel-2": "res://assets/props/estrada_inverno/estrada_inverno_barrel_2.png",
	"estrada-inverno-skull": "res://assets/props/estrada_inverno/estrada_inverno_skull.png",
	# Enriquecimento de decoração (pedido do usuário) — mais recortes reais da
	# mesma referência do usuário (pasta `estrada inverno/` fora do projeto).
	"estrada-inverno-log-1": "res://assets/props/estrada_inverno/estrada_inverno_log_1.png",
	"estrada-inverno-log-2": "res://assets/props/estrada_inverno/estrada_inverno_log_2.png",
	"estrada-inverno-stump": "res://assets/props/estrada_inverno/estrada_inverno_stump.png",
	"estrada-inverno-snow-rocks-1": "res://assets/props/estrada_inverno/estrada_inverno_snow_rocks_1.png",
	"estrada-inverno-snow-rocks-2": "res://assets/props/estrada_inverno/estrada_inverno_snow_rocks_2.png",
	"estrada-inverno-snow-pebbles-1": "res://assets/props/estrada_inverno/estrada_inverno_snow_pebbles_1.png",
	"estrada-inverno-snow-pebbles-2": "res://assets/props/estrada_inverno/estrada_inverno_snow_pebbles_2.png",
	"estrada-inverno-snow-bush-1": "res://assets/props/estrada_inverno/estrada_inverno_snow_bush_1.png",
	"estrada-inverno-snow-bush-2": "res://assets/props/estrada_inverno/estrada_inverno_snow_bush_2.png",
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
	# Reformulação completa da Vila (pedido do usuário) — recortes reais dos
	# PNGs fornecidos em C:\Users\gabri\Downloads\modo aventura 2d\vila,
	# bbox de alpha real (sem moldura transparente sobrando), copiados pra
	# assets/props/village2/. Puramente decorativos (blocking:false) exceto
	# onde a própria _village_definition() os inclui em "obstacles".
	"village2-well": "res://assets/props/village2/village2_well.png",
	"village2-boat": "res://assets/props/village2/village2_boat.png",
	"village2-dock": "res://assets/props/village2/village2_dock.png",
	"village2-wagon": "res://assets/props/village2/village2_wagon.png",
	"village2-crate-1": "res://assets/props/village2/village2_crate_1.png",
	"village2-crate-2": "res://assets/props/village2/village2_crate_2.png",
	"village2-crate-3": "res://assets/props/village2/village2_crate_3.png",
	"village2-crate-4": "res://assets/props/village2/village2_crate_4.png",
	"village2-crate-5": "res://assets/props/village2/village2_crate_5.png",
	"village2-barrel-1": "res://assets/props/village2/village2_barrel_1.png",
	"village2-barrel-2": "res://assets/props/village2/village2_barrel_2.png",
	"village2-barrel-3": "res://assets/props/village2/village2_barrel_3.png",
	"village2-barrel-4": "res://assets/props/village2/village2_barrel_4.png",
	"village2-barrel-5": "res://assets/props/village2/village2_barrel_5.png",
	"village2-sacks": "res://assets/props/village2/village2_sacks.png",
	"village2-basket": "res://assets/props/village2/village2_basket.png",
	"village2-jar": "res://assets/props/village2/village2_jar.png",
	"village2-stool": "res://assets/props/village2/village2_stool.png",
	"village2-fence-1": "res://assets/props/village2/village2_fence_1.png",
	"village2-fence-2": "res://assets/props/village2/village2_fence_2.png",
	"village2-fence-3": "res://assets/props/village2/village2_fence_3.png",
	"village2-fence-broken": "res://assets/props/village2/village2_fence_broken.png",
	"village2-wall-ruin": "res://assets/props/village2/village2_wall_ruin.png",
	"village2-barricade": "res://assets/props/village2/village2_barricade.png",
	"village2-debris-ash": "res://assets/props/village2/village2_debris_ash.png",
	"village2-rubble-wall": "res://assets/props/village2/village2_rubble_wall.png",
	"village2-rubble-rocks": "res://assets/props/village2/village2_rubble_rocks.png",
	"village2-campfire": "res://assets/props/village2/village2_campfire.png",
	"village2-stick-pile": "res://assets/props/village2/village2_stick_pile.png",
	"village2-branch": "res://assets/props/village2/village2_branch.png",
	"village2-banner": "res://assets/props/village2/village2_banner.png",
	"village2-lamppost": "res://assets/props/village2/village2_lamppost.png",
	"village2-planter-1": "res://assets/props/village2/village2_planter_1.png",
	"village2-planter-2": "res://assets/props/village2/village2_planter_2.png",
	"village2-tree-green-1": "res://assets/props/village2/village2_tree_green_1.png",
	"village2-tree-green-2": "res://assets/props/village2/village2_tree_green_2.png",
	"village2-tree-dead-1": "res://assets/props/village2/village2_tree_dead_1.png",
	"village2-tree-dead-2": "res://assets/props/village2/village2_tree_dead_2.png",
	"village2-stump-1": "res://assets/props/village2/village2_stump_1.png",
	"village2-stump-2": "res://assets/props/village2/village2_stump_2.png",
	"village2-bush": "res://assets/props/village2/village2_bush.png",
	"village2-reeds-1": "res://assets/props/village2/village2_reeds_1.png",
	"village2-reeds-2": "res://assets/props/village2/village2_reeds_2.png",
	"village2-reeds-3": "res://assets/props/village2/village2_reeds_3.png",
	"village2-reeds-4": "res://assets/props/village2/village2_reeds_4.png",
	"village2-reeds-5": "res://assets/props/village2/village2_reeds_5.png",
	"village2-lilypad-1": "res://assets/props/village2/village2_lilypad_1.png",
	"village2-lilypad-2": "res://assets/props/village2/village2_lilypad_2.png",
	"village2-lilypad-3": "res://assets/props/village2/village2_lilypad_3.png",
	"village2-rock-1": "res://assets/props/village2/village2_rock_1.png",
	"village2-rock-2": "res://assets/props/village2/village2_rock_2.png",
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
## Reformulação completa da Vila (pedido do usuário, ver referencia.png em
## C:\Users\gabri\Downloads\modo aventura 2d\vila) — recortes reais dos PNGs
## fornecidos (bbox de alpha real, sem moldura transparente sobrando, ver
## scratchpad/prepare_village2_assets.py), copiados pra
## assets/props/village2/. Os arquivos village_house_*/village_mill.png
## antigos (village/) foram MANTIDOS intactos, só não são mais referenciados
## por essas 3 constantes — trocar aqui basta pra atualizar casas/moinho/
## ruína em todo canto que já lia essas constantes, sem tocar no "kind"
## genérico ("village-house" etc.) de que test_scenario_village.gd depende.
const VILLAGE_HOUSE_TEXTURES := [
	"res://assets/props/village2/village2_house_1.png",
	"res://assets/props/village2/village2_house_2.png",
	"res://assets/props/village2/village2_house_3.png",
]
const VILLAGE_MILL_TEXTURE := "res://assets/props/village2/village2_mill.png"
## Casa colapsada (kind "village-house-ruin"): reaproveita o recorte da casa
## 2 com burning=false — a chama é overlay procedural (_draw_village_flame),
## não faz parte do PNG, então a mesma arte serve pra "intacta pegando
## fogo" e "já não pega mais fogo" sem precisar de um recorte à parte.
const VILLAGE_HOUSE_RUIN_TEXTURE := "res://assets/props/village2/village2_house_ruin.png"
## Celeiro/silo/torre d'água viram "buildings" de verdade (ocupam w/h tiles,
## bloqueiam movimento via _village_definition) na reformulação — antes eram
## props curados sem colisão, mas são estruturas sólidas de verdade,
## incoerente deixar passar por cima delas.
const VILLAGE_BARN_TEXTURE := "res://assets/props/village2/village2_barn.png"
const VILLAGE_SILO_TEXTURE := "res://assets/props/village2/village2_silo.png"
const VILLAGE_WATERTOWER_TEXTURE := "res://assets/props/village2/village2_watertower.png"

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
	# Zoom/arrasto não atravessam troca de cenário — cada mapa começa do
	# mesmo jeito (60% de zoom, centralizado — pedido do usuário), sem
	# herdar (nem acumular) o estado visual de navegação do cenário
	# anterior. Sem efeito na Horda: _update_camera() ignora view_zoom
	# nesse cenário (janela fixa, ver bloco _is_lua_valley() logo abaixo).
	view_zoom = 0.6
	view_pan = Vector2.ZERO
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
	if state == null or not _is_campo_like(scenario_definition.get("id", ScenarioManager.FIELD)):
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
	for node in _scenery_nodes:
		if is_instance_valid(node): node.queue_free()
	_scenery_nodes.clear()
	if scenario_definition.has("scenery_props"):
		_scenery_nodes = SceneryVisuals.build(self, scenario_definition)
		return
	if state == null or not _is_campo_like(scenario_definition.get("id", ScenarioManager.FIELD)): return
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
## troca de cenário (set_scenario). Zoom fica travado em 1:1 pra todo mundo
## exceto CAMPO 2 (ver abaixo); só a posição muda, deslocando a janela fixa
## de 13x13 pro canto LUA_VALLEY_CROP_ORIGIN quando o cenário ativo é a
## Horda. O corte físico pra exatamente 13x13 tiles é feito pelo Control com
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
##
func _is_lua_valley() -> bool:
	return scenario_definition.get("id", ScenarioManager.FIELD) == ScenarioManager.LUA_VALLEY

## Janela de TELA de verdade que o jogador vê do tabuleiro — não a viewport
## inteira do jogo (que também tem HUD ao redor), e sim o retângulo do
## Control pai com clip_contents=true (main.gd:_board_clip, tamanho fixo
## BOARD_DISPLAY_PX, independente de TILE_SIZE). Zoom/arrasto (ver
## _update_camera/can_pan/_clamp_view_pan) precisam dessa área — não da
## viewport inteira — pra saber quanto do mapa cabe de verdade na tela.
func _display_area_size() -> Vector2:
	var parent := get_parent()
	if parent is Control:
		var control_size: Vector2 = (parent as Control).size
		if control_size.x > 0.0 and control_size.y > 0.0:
			return control_size
	var viewport_size: Vector2 = get_viewport_rect().size
	return viewport_size if viewport_size.x > 0.0 and viewport_size.y > 0.0 else Vector2(832, 832)

## Área do mundo (em px) que a câmera pode de fato mostrar pro cenário atual
## — só Campo/Torre/Vila (13x13 lógico); Horda usa a janela fixa própria e
## nunca chama isto.
func _board_px_size() -> Vector2:
	if state != null:
		return Vector2(state.board_width, state.board_height) * TILE_SIZE
	return Vector2(GameConstants.BOARD_SIZE, GameConstants.BOARD_SIZE) * TILE_SIZE

## Restringe view_pan (deslocamento em px de MUNDO a partir do centro do
## tabuleiro) pra nunca deixar o tabuleiro sair inteiramente da tela — se a
## área visível (viewport / zoom) for maior que o tabuleiro num eixo, esse
## eixo fica travado em 0 (centralizado); senão, limita a metade da sobra
## de cada lado. Chamada sempre que view_zoom, view_pan ou o tamanho da
## viewport mudam (_update_camera, zoom, arrastar) — nunca guardamos um
## view_pan já fora desses limites.
func _clamp_view_pan(viewport_size: Vector2) -> void:
	# world_per_pixel = 1/zoom (zoom é magnificação — ver _update_camera):
	# quanto de MUNDO cabe em cada pixel de tela no zoom atual.
	var world_per_pixel := 1.0 / clampf(view_zoom, VIEW_ZOOM_MIN, VIEW_ZOOM_MAX)
	var visible_world := viewport_size * world_per_pixel
	var board_px := _board_px_size()
	# BUG corrigido: a fórmula antiga era (visible_world - board_px), que só
	# dá positivo quando o tabuleiro CABE inteiro (sobra tela) — exatamente
	# o caso em que NÃO precisa de arrasto. Quando o tabuleiro é MAIOR que a
	# área visível (o caso de verdade depois do aumento de tile, sempre
	# verdadeiro agora pro tabuleiro 13x13 a 96px), a conta antiga dava
	# negativo e forçava view_pan pra 0 sempre — travando a câmera no centro
	# e tornando bordas/cantos do mapa permanentemente inacessíveis. A conta
	# certa é o excesso de mundo além da janela (board_px - visible_world):
	# positivo quando sobra mapa pra explorar, e é ESSA metade que view_pan
	# pode percorrer pra cada lado do centro.
	var excess := (board_px - visible_world) * 0.5
	view_pan.x = 0.0 if excess.x <= 0.0 else clampf(view_pan.x, -excess.x, excess.x)
	view_pan.y = 0.0 if excess.y <= 0.0 else clampf(view_pan.y, -excess.y, excess.y)

## Achado durante a validação dos 4 cantos do mapa (pedido do usuário): usar
## Camera2D pra zoom/arrasto quebra o clip_contents de _board_clip (main.gd)
## assim que a câmera desloca/escala de verdade — Camera2D manipula o
## canvas_transform da VIEWPORT INTEIRA, e o retângulo de corte do Control
## "anda junto" com esse transform em vez de ficar fixo na tela, cortando
## conteúdo que deveria estar visível (metade do mapa sumia ao arrastar pro
## canto oposto, mesmo com a matemática de câmera perfeitamente correta —
## confirmado imprimindo canvas_transform e comparando com clip_contents=
## false, que mostrou o mapa inteiro certo). A correção é não usar Camera2D
## pra isso: zoom/arrasto (não-Horda) agora escalam/deslocam a TRANSFORM
## DESTE PRÓPRIO NÓ (position/scale) — o mesmo mecanismo simples que já
## funcionava antes de existir zoom/arrasto nenhum, imune a esse problema
## porque nunca mexe no canvas_transform da viewport. A câmera continua
## existindo só pra Horda (comportamento intocado) e pro tremor de tela
## (CameraShake2D) quando não-Horda estiver com ela desabilitada — ver nota
## em CameraShake2D se o tremor precisar de ajuste equivalente no futuro.
func _update_camera() -> void:
	if camera == null:
		return
	var viewport_size: Vector2 = _display_area_size()
	camera.enabled = false
	_clamp_view_pan(viewport_size)
	var zoom_value := clampf(view_zoom, VIEW_ZOOM_MIN, VIEW_ZOOM_MAX)
	scale = Vector2.ONE * zoom_value
	var target_center := _board_px_size() * 0.5 + view_pan
	# Quero "target_center" (espaço local deste nó, ANTES da escala)
	# aparecendo no centro do retângulo de _board_clip. Um ponto local P
	# aparece em "position + P*scale" no espaço do PAI (_board_clip); esse
	# pai tem exatamente viewport_size de largura/altura e este nó fica na
	# origem dele, então o centro do clip nesse espaço é viewport_size*0.5.
	position = viewport_size * 0.5 - target_center * zoom_value

## API pública do zoom/arrasto interativo (ver main.gd: botões +/-/100% e
## arrastar com o mouse). Sempre passam por _update_camera() logo em
## seguida — nenhum outro lugar do código deve escrever em view_zoom/
## view_pan/camera.zoom/camera.position diretamente.
func set_view_zoom(new_zoom: float) -> void:
	view_zoom = clampf(new_zoom, VIEW_ZOOM_MIN, VIEW_ZOOM_MAX)
	_update_camera()

func change_view_zoom(steps: int) -> void:
	set_view_zoom(view_zoom + float(steps) * VIEW_ZOOM_STEP)

func reset_view() -> void:
	view_zoom = 1.0
	view_pan = Vector2.ZERO
	_update_camera()

## `screen_delta` é o deslocamento do MOUSE em pixels de tela desde o último
## frame de arrasto (ver main.gd:_unhandled_input) — convertido pra pixels de
## MUNDO via camera.zoom (screen->world escala por esse fator) e subtraído
## (não somado) de view_pan: arrastar o mouse pra direita precisa mover o
## CENTRO da câmera pra esquerda pro conteúdo parecer "andar junto" do dedo,
## em vez de fugir na direção oposta.
func pan_view_by(screen_delta: Vector2) -> void:
	# view_zoom é magnificação de tela (ver _update_camera: scale = view_zoom
	# direto), então a conversão de volta pra pixels de MUNDO divide por
	# zoom (não multiplica) — a 200%, 1px de mouse deve mover só meio pixel
	# de mundo; a 50%, deve mover 2px de mundo, pra o conteúdo acompanhar o
	# dedo na mesma velocidade aparente em qualquer zoom.
	view_pan -= screen_delta / clampf(view_zoom, VIEW_ZOOM_MIN, VIEW_ZOOM_MAX)
	_update_camera()

## Alcance de arrasto ainda considerado o CENTRO do tabuleiro, é o suficiente
## pra viewport atual não deixar sobrar tela vazia num eixo (ver
## _clamp_view_pan) — main.gd usa isso só pra saber quando iniciar/permitir
## um arrasto sem checar limites por conta própria.
func can_pan() -> bool:
	var viewport_size: Vector2 = _display_area_size()
	var world_per_pixel := 1.0 / clampf(view_zoom, VIEW_ZOOM_MIN, VIEW_ZOOM_MAX)
	var visible_world := viewport_size * world_per_pixel
	var board_px := _board_px_size()
	return visible_world.x < board_px.x or visible_world.y < board_px.y

## Define view_pan diretamente (ver main.gd: barras de rolagem) — mesma
## fonte única de verdade que o arrasto/zoom usam, sempre passando por
## _update_camera() (que por sua vez sempre re-clampa, ver _clamp_view_pan).
func set_view_pan(new_pan: Vector2) -> void:
	view_pan = new_pan
	_update_camera()

## Pedido do usuário: clicar no retrato de um personagem na fila de turnos
## centraliza a câmera nele (só chamado por main.gd quando view_zoom > 0.6 —
## no zoom mínimo o tabuleiro inteiro já cabe na tela, então recentralizar
## não teria efeito). set_view_pan já re-clampa aos limites do tabuleiro.
func center_on_tile(x: int, y: int) -> void:
	set_view_pan(tile_center(x, y) - _board_px_size() * 0.5)

## Alcance MÁXIMO (metade, simétrico ao redor do centro) que view_pan pode
## assumir em cada eixo no zoom atual — 0 num eixo em que o tabuleiro já
## cabe inteiro. main.gd usa isso pra dimensionar min/max das barras de
## rolagem (ver _sync_board_scroll).
func pan_range() -> Vector2:
	var viewport_size: Vector2 = _display_area_size()
	var world_per_pixel := 1.0 / clampf(view_zoom, VIEW_ZOOM_MIN, VIEW_ZOOM_MAX)
	var visible_world := viewport_size * world_per_pixel
	var board_px := _board_px_size()
	var excess := (board_px - visible_world) * 0.5
	return Vector2(maxf(0.0, excess.x), maxf(0.0, excess.y))

## Quanto de MUNDO (em px) a janela atual mostra em cada eixo — usado pra
## dimensionar a "página" (thumb) das barras de rolagem proporcionalmente.
func visible_world_size() -> Vector2:
	var viewport_size: Vector2 = _display_area_size()
	var world_per_pixel := 1.0 / clampf(view_zoom, VIEW_ZOOM_MIN, VIEW_ZOOM_MAX)
	return viewport_size * world_per_pixel

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
	return "grass" if _is_campo_like(scenario_definition.get("id", ScenarioManager.FIELD)) else "dirt"

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
	# Cenários de props recortados desenham o próprio chão (SceneryVisuals.Ground,
	# abaixo deste _draw), então aqui não há linhas de grama a pintar.
	var ground_rows := 0 if scenario_definition.has("scenery_props") else board_h
	for y in range(ground_rows):
		for x in range(board_w):
			draw_texture_rect(grass, tile_rect(x, y), false)
			if _is_campo_like(scenario_definition.get("id", ScenarioManager.FIELD)) and posmod(x * 17 + y * 29, 11) == 0:
				var sway := sin(_anim_time_ms * 0.0012 + float(x * 3 + y)) * 1.5
				var tuft := tile_center(x, y) + Vector2(-17 + posmod(x * 13 + y * 7, 31), 19)
				draw_line(tuft, tuft + Vector2(sway - 3, -8), Color(0.25, 0.47, 0.19, 0.42), 1.5, true)
				draw_line(tuft + Vector2(4, 1), tuft + Vector2(4 - sway, -6), Color(0.42, 0.60, 0.25, 0.34), 1.2, true)
	# Tint ambiental neutro-esverdeado apenas sobre o chão; unidades, UI e
	# highlights permanecem com suas cores originais e totalmente legíveis.
	if _is_campo_like(scenario_definition.get("id", ScenarioManager.FIELD)):
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
			if type == "tree" and _is_campo_like(scenario_definition.get("id", ScenarioManager.FIELD)):
				continue
			if type == "tree" or type == "tent":
				tex_path = "res://assets/tiles/%s" % terrain["art"]
			elif TERRAIN_STATIC_TEXTURES.has(type):
				tex_path = TERRAIN_STATIC_TEXTURES[type]
			if tex_path != "":
				# Sombra de contato só no DESFILADEIRO (pedido do usuário:
				# aproximar da referência — a folhagem clara de snow_pine.png
				# quase some sem isso contra a neve pálida de fundo; ESTRADA
				# INVERNO redesenha a própria árvore depois da neve opaca em
				# _draw_estrada_inverno_board(), então a sombra dela vive lá).
				if type == "tree" and scenario_definition.get("id", ScenarioManager.FIELD) == ScenarioManager.DESFILADEIRO:
					var trect2 := tile_rect(x, y)
					draw_circle(trect2.position + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.82), 14.0, Color(0.12, 0.16, 0.22, 0.20))
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
		if not _is_campo_like(scenario_definition.get("id", ScenarioManager.FIELD)):
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
	elif scenario_definition.get("id", ScenarioManager.FIELD) == ScenarioManager.PORTO:
		_draw_porto_board()
	elif scenario_definition.get("id", ScenarioManager.FIELD) == ScenarioManager.DESFILADEIRO:
		_draw_desfiladeiro_board()
	elif scenario_definition.get("id", ScenarioManager.FIELD) == ScenarioManager.ESTRADA_INVERNO:
		_draw_estrada_inverno_board()
	_draw_curated_props()
	_draw_grass_reactions()
	if debug_show_battleable:
		_draw_battleable_debug()
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
	elif kind == "village-house-ruin":
		tex_path = VILLAGE_HOUSE_RUIN_TEXTURE
	elif kind == "village-house":
		# Cicla pela ordem em que as casas aparecem em "buildings" — garante
		# variedade previsível (não aleatória) em vez de repetir sempre a
		# mesma arte nas 4 casas.
		tex_path = VILLAGE_HOUSE_TEXTURES[house_index % VILLAGE_HOUSE_TEXTURES.size()]
	elif kind == "village-barn":
		tex_path = VILLAGE_BARN_TEXTURE
	elif kind == "village-silo":
		tex_path = VILLAGE_SILO_TEXTURE
	elif kind == "village-watertower":
		tex_path = VILLAGE_WATERTOWER_TEXTURE
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

## Base real do Kenney Fantasy Town (CC0, `fountainRoundDetail.glb` — ver
## ASSET_SOURCES.md "PORTO"); o brilho central é procedural (_draw_porto_
## fountain), não faz parte do PNG.
const PORTO_FOUNTAIN_TEXTURE := "res://assets/props/porto/pixel/porto_fountain.png"
const PORTO_HOUSE_TEXTURE := "res://assets/props/porto/pixel/porto_house.png"
const PORTO_COBBLESTONE_TEXTURE := "res://assets/props/porto/pixel/porto_cobblestone.png"
const PORTO_REEDS_TEXTURES := [
	"res://assets/props/porto/pixel/porto_reeds_1.png",
	"res://assets/props/porto/pixel/porto_reeds_2.png",
]

## PORTO (cenário independente — ScenarioManager._porto_definition()/
## GameState._setup_porto). Praça de pedregulhos e água reais (recortes da
## própria imagem de referência do usuário, ver ASSET_SOURCES.md), casa
## desenhada por `_draw_porto_house()` (kind próprio "porto-house", não usa
## mais _draw_village_building/village-house).
func _draw_porto_board() -> void:
	_draw_porto_water()
	var cobblestone := _get_tex(PORTO_COBBLESTONE_TEXTURE)
	for tile in scenario_definition.get("road", []):
		draw_texture_rect(cobblestone, tile_rect(tile["x"], tile["y"]), false)
	# Junco raso de transição grama→água nas margens conhecidas do cenário —
	# recorte real (porto_reeds_1/2.png) no lugar do tufo senoidal
	# procedural, pedido do usuário pra evitar corte reto entre grama e água.
	var shore_tufts := [
		{"x":2,"y":10},{"x":3,"y":10},{"x":9,"y":10},{"x":10,"y":10},
		{"x":1,"y":7},{"x":1,"y":8},{"x":1,"y":9},{"x":2,"y":0},
	]
	var reeds_textures: Array[Texture2D] = [_get_tex(PORTO_REEDS_TEXTURES[0]), _get_tex(PORTO_REEDS_TEXTURES[1])]
	for i in shore_tufts.size():
		var tuft: Dictionary = shore_tufts[i]
		var reeds_tex := reeds_textures[i % 2]
		var size: Vector2 = reeds_tex.get_size()
		var max_dim := 44.0
		var draw_size: Vector2 = size * (max_dim / maxf(size.x, size.y))
		var center := tile_center(tuft["x"], tuft["y"]) + Vector2(0, 14)
		draw_texture_rect(reeds_tex, Rect2(center - draw_size * Vector2(0.5, 1.0), draw_size), false)
	for building in scenario_definition.get("buildings", []):
		_draw_porto_house(building)
	var fountain: Dictionary = scenario_definition.get("fountain", {})
	if not fountain.is_empty():
		_draw_porto_fountain(fountain)

## Casa grande do PORTO (landmark #1) — recorte real da referência do
## usuário (PORTO_HOUSE_TEXTURE), encaixado no retângulo via _contain_rect
## (mesma técnica da fonte abaixo). Kind próprio "porto-house": não passa
## por _draw_village_building/village-house, que continuam intactos pra
## Vila e demais cenários.
func _draw_porto_house(building: Dictionary) -> void:
	var rect := Rect2(Vector2(building["x"], building["y"]) * TILE_SIZE, Vector2(building["w"], building["h"]) * TILE_SIZE)
	draw_ellipse_shadow(rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.94), Vector2(rect.size.x * 0.42, 14), Color(0.03,0.02,0.02,0.35))
	var tex := _get_tex(PORTO_HOUSE_TEXTURE)
	draw_texture_rect(tex, _contain_rect(rect.grow(6), tex.get_size()), false)

## Água do PORTO: costa irregular própria (não é rio/lago contínuo como
## Campo/Vale de Lua/Vila — ver ScenarioManager._porto_definition() pro
## formato da borda) — textura real (recorte da referência do usuário) por
## célula + o mesmo brilho de correnteza animado de antes.
## Água do PORTO (pedido do usuário: precisa ficar "unida" — um corpo só,
## igual o rio do Campo — em vez de blocos separados). A textura real por
## célula (recorte da referência) criava costura visível de tile em tile;
## em vez disso, gradiente contínuo (varia suave de célula pra célula via
## seno, sem repetição de padrão) + uma margem/costa (mesma linguagem de
## `bank_color` de _draw_river_bands) traçada em CADA aresta onde água
## encosta em terra firme — cobre qualquer formato de costa (recorte do
## píer, bolsão isolado do canto) sem precisar forçar um polyline fino por
## cima de uma área larga como a do Campo/Vale de Lua.
func _draw_porto_water() -> void:
	var water_tiles: Array = scenario_definition.get("water", [])
	var water_set := {}
	for tile in water_tiles:
		water_set[Vector2i(int(tile["x"]), int(tile["y"]))] = true
	for tile in water_tiles:
		var rect := tile_rect(tile["x"], tile["y"])
		var depth: float = 0.5 + 0.5 * sin(float(tile["x"]) * 0.7 + float(tile["y"]) * 0.5)
		draw_rect(rect, Color(0.10, 0.24, 0.34).lerp(Color(0.16, 0.36, 0.46), depth))
		var shimmer: float = 0.5 + 0.5 * sin(_soul_phase * 1.4 + float(tile["x"]) * 0.9 + float(tile["y"]) * 0.6)
		draw_line(rect.position + Vector2(6, 18 + shimmer*6), rect.position + Vector2(TILE_SIZE-10, 14 + shimmer*6), Color(1,1,1,0.10+shimmer*0.08), 2.0, true)
	var bank_color := Color("2f4a55")
	var board_w := state.board_width
	var board_h := state.board_height
	for tile in water_tiles:
		var x: int = int(tile["x"])
		var y: int = int(tile["y"])
		var rect := tile_rect(x, y)
		if y > 0 and not water_set.has(Vector2i(x, y - 1)):
			draw_line(rect.position, rect.position + Vector2(TILE_SIZE, 0), bank_color, 5.0)
		if y < board_h - 1 and not water_set.has(Vector2i(x, y + 1)):
			draw_line(rect.position + Vector2(0, TILE_SIZE), rect.position + Vector2(TILE_SIZE, TILE_SIZE), bank_color, 5.0)
		if x > 0 and not water_set.has(Vector2i(x - 1, y)):
			draw_line(rect.position, rect.position + Vector2(0, TILE_SIZE), bank_color, 5.0)
		if x < board_w - 1 and not water_set.has(Vector2i(x + 1, y)):
			draw_line(rect.position + Vector2(TILE_SIZE, 0), rect.position + Vector2(TILE_SIZE, TILE_SIZE), bank_color, 5.0)

## Fonte/monumento (landmark #2 do PORTO): base real (PORTO_FOUNTAIN_
## TEXTURE) encaixada no retângulo 2x2 via _contain_rect (mesma técnica das
## casas), com um brilho mágico pulsante por cima — procedural, ecoa o
## obelisco luminoso da imagem de referência do usuário sem copiar o desenho.
func _draw_porto_fountain(fountain: Dictionary) -> void:
	var rect := Rect2(Vector2(fountain["x"], fountain["y"]) * TILE_SIZE, Vector2(fountain["w"], fountain["h"]) * TILE_SIZE).grow(-4)
	draw_ellipse_shadow(rect.get_center() + Vector2(0, rect.size.y * 0.36), Vector2(rect.size.x * 0.4, 14), Color(0.03,0.02,0.02,0.4))
	var tex := _get_tex(PORTO_FOUNTAIN_TEXTURE)
	var destination := _contain_rect(rect, tex.get_size())
	draw_texture_rect(tex, destination, false)
	var center := destination.position + destination.size * Vector2(0.5, 0.38)
	var pulse: float = 0.6 + 0.4 * sin(_soul_phase * 2.2)
	draw_circle(center, 9.0 + pulse * 3.0, Color(0.55, 0.85, 1.0, 0.20 + pulse * 0.12))
	draw_circle(center, 4.0 + pulse * 1.5, Color(0.75, 0.95, 1.0, 0.55 + pulse * 0.2))

## Overlay de QA temporário (ver `debug_show_battleable`): verde translúcido
## em tile battleable+livre de ocupante, vermelho no resto. Desenhado por
## último (por cima de terreno/props), não lê nem escreve nenhum highlight
## de jogo (highlight_move/attack/spell) — puramente informativo.
## Terceira cor (azul, "só voo") pedida especificamente pro DESFILADEIRO —
## qualquer tile "desfiladeiro-chasm" (ver GameState.compute_reachable/
## _can_unit_anchor_at) é sempre "só voo", nunca aparece verde/vermelho puro.
func _draw_battleable_debug() -> void:
	if state == null: return
	for y in range(state.board_height):
		for x in range(state.board_width):
			var terrain = state.terrain_at(x, y)
			var flight_only: bool = terrain != null and terrain.get("type", "") == "desfiladeiro-chasm"
			var free_ok: bool = state.is_battleable(x, y) and state.occupant_at(x, y) == null
			var color: Color
			if flight_only:
				color = Color(0.20, 0.55, 0.95, 0.34)
			elif free_ok:
				color = Color(0.15, 0.85, 0.25, 0.32)
			else:
				color = Color(0.9, 0.15, 0.15, 0.32)
			draw_rect(tile_rect(x, y), color)

const DESFILADEIRO_SNOW_TEXTURE := "res://assets/props/desfiladeiro/desfiladeiro_snow_ground.png"
const DESFILADEIRO_FOOTPRINTS_TEXTURE := "res://assets/props/desfiladeiro/desfiladeiro_snow_footprints.png"
const DESFILADEIRO_BRIDGE_TEXTURE := "res://assets/props/desfiladeiro/desfiladeiro_bridge.png"
const DESFILADEIRO_MOUNTAINS_TEXTURE := "res://assets/props/desfiladeiro/desfiladeiro_mountains_bg.png"
## Pedido do usuário: a borda do penhasco repetindo a MESMA imagem (com capim
## nevado no topo) célula a célula lia como um carimbo repetido, não uma
## parede contínua. Mesma técnica do paredão da ESTRADA INVERNO (ver
## _draw_estrada_inverno_cliff_tile): a arte "cheia" (com capim) só na
## primeira linha visível da coluna, um recorte "_body" (só a rocha, sem
## capim) repetindo por baixo — sem a faixa branca se repetindo a cada
## célula, a coluna lê como uma única face de rocha contínua.
const DESFILADEIRO_CLIFF_WALL_TEXTURES := [
	"res://assets/props/desfiladeiro/desfiladeiro_cliff_wall_1.png",
	"res://assets/props/desfiladeiro/desfiladeiro_cliff_wall_2.png",
]
const DESFILADEIRO_CLIFF_WALL_BODY_TEXTURES := [
	"res://assets/props/desfiladeiro/desfiladeiro_cliff_wall_1_body.png",
	"res://assets/props/desfiladeiro/desfiladeiro_cliff_wall_2_body.png",
]
## Altura do "céu" (ScenarioManager._desfiladeiro_definition():sky) em linhas
## de tile — mantido como constante em vez de reler `sky` a cada frame só pra
## descobrir a altura do retângulo do fundo de montanhas.
const DESFILADEIRO_SKY_ROWS := 3
## Pegadas na neve levando até as duas bocas da ponte (x=3/x=8, y=5) —
## puramente visual (pedido do usuário, ecoa a trilha de pegadas da imagem de
## referência), não altera blocked_tiles nem custo de movimento. Só a linha
## y=5 agora (regra 10: y=6 deixou de ser ponte andável, virou ravina — ver
## ScenarioManager._desfiladeiro_definition()), senão as pegadas levariam a
## uma borda de ravina em vez da ponte de fato.
const DESFILADEIRO_FOOTPRINT_TILES := [
	{"x":3,"y":5},{"x":8,"y":5},
]

## DESFILADEIRO (cenário independente — ScenarioManager._desfiladeiro_
## definition()/GameState._setup_desfiladeiro). Fundo de céu+montanhas nas 3
## primeiras linhas (pedido do usuário: essas linhas não fazem parte do
## tabuleiro pisável, só cenário ao fundo — ver `sky` em ScenarioManager),
## neve real cobrindo o restante, ponte de pedra real esticada pro retângulo
## 4x2 — árvores/pedras/monólitos não precisam de código aqui: árvores usam
## o mecanismo genérico de "tree"+art já desenhado pelo loop de terreno
## estático em _draw(), e pedra/monólito/cristal/arbusto são props curados
## (_draw_curated_props(), chamada logo depois desta função no _draw()
## principal).
func _draw_desfiladeiro_board() -> void:
	var board_w := state.board_width
	var board_h := state.board_height
	_draw_desfiladeiro_sky()
	var snow_tex := _get_tex(DESFILADEIRO_SNOW_TEXTURE)
	var footprints_tex := _get_tex(DESFILADEIRO_FOOTPRINTS_TEXTURE)
	var sky_tiles: Array = scenario_definition.get("sky", [])
	for y in range(board_h):
		for x in range(board_w):
			if y < DESFILADEIRO_SKY_ROWS:
				var in_sky := false
				for tile in sky_tiles:
					if int(tile["x"]) == x and int(tile["y"]) == y:
						in_sky = true
						break
				if in_sky: continue
			var rect := tile_rect(x, y)
			var is_footprint_tile := false
			for tile in DESFILADEIRO_FOOTPRINT_TILES:
				if int(tile["x"]) == x and int(tile["y"]) == y:
					is_footprint_tile = true
					break
			draw_texture_rect(footprints_tex if is_footprint_tile else snow_tex, rect, false)
	# Rio + muros desenhados ANTES da ponte de propósito: o PNG real da ponte
	# (recorte da referência) tem o vão do arco TRANSPARENTE (ver
	# ASSET_SOURCES.md) — desenhar a ponte por cima deixa o rio aparecer
	# através do arco, exatamente como uma ponte de verdade cruzando um rio
	# (pedido do usuário: nada de neve "vazando" por baixo da ponte).
	_draw_desfiladeiro_chasm()
	var bridge_tiles: Array = scenario_definition.get("bridge", [])
	if not bridge_tiles.is_empty():
		var min_x := 99
		var min_y := 99
		var max_x := -1
		var max_y := -1
		for tile in bridge_tiles:
			min_x = mini(min_x, int(tile["x"]))
			min_y = mini(min_y, int(tile["y"]))
			max_x = maxi(max_x, int(tile["x"]))
			max_y = maxi(max_y, int(tile["y"]))
		var bridge_rect := Rect2(Vector2(min_x, min_y) * TILE_SIZE, Vector2(max_x - min_x + 1, max_y - min_y + 1) * TILE_SIZE)
		draw_texture_rect(_get_tex(DESFILADEIRO_BRIDGE_TEXTURE), bridge_rect, false)

## Fundo de céu do DESFILADEIRO (pedido do usuário): as 3 primeiras linhas
## (`sky`, gerado por ScenarioManager._desfiladeiro_definition()) não são
## tabuleiro pisável, só cenário — gradiente de céu + montanhas reais
## (recorte da referência do usuário) cobrindo a largura inteira, inclusive
## por trás do vão da ravina (x=4..7): a boca do desfiladeiro segue sendo
## desenhada por cima disso por _draw_desfiladeiro_chasm(), como se a
## ravina cortasse a cordilheira.
func _draw_desfiladeiro_sky() -> void:
	var board_w := state.board_width
	var band_rect := Rect2(Vector2.ZERO, Vector2(board_w * TILE_SIZE, DESFILADEIRO_SKY_ROWS * TILE_SIZE))
	draw_rect(band_rect, Color("bcdcec"))
	var mountains := _get_tex(DESFILADEIRO_MOUNTAINS_TEXTURE)
	draw_texture_rect(mountains, band_rect, false)

## Ravina do DESFILADEIRO (pedido do usuário): as 2 colunas externas (x=4/
## x=7) são um bloco vertical único por coluna — a MESMA arte real de
## paredão rochoso nevado (recorte da referência) repetida sem interrupção
## por toda a altura da ravina (y=3..12), inclusive por trás da ponte (ela
## cobre por cima depois, ver _draw_desfiladeiro_board). As 2 colunas
## internas (x=5/x=6) são um rio de verdade — reaproveita _draw_river_bands
## (mesma técnica do Campo/Vale de Lua/Estrada Inverno), só mais largo (2
## células) e com tom de água fria em vez do verde do Campo. Desenhado ANTES
## dos muros de propósito: garante que a margem do rio nunca vaza por cima
## da arte da parede. Puramente visual — blocked_tiles continua vindo só de
## "chasm" em ScenarioManager, as 4 colunas seguem igualmente intransitáveis
## (inclusive pra voadoras nas 2 externas).
func _draw_desfiladeiro_chasm() -> void:
	var river_points := PackedVector2Array([Vector2(5.5, 3.0), Vector2(5.5, 13.0)])
	for i in range(river_points.size()): river_points[i] *= TILE_SIZE
	_draw_river_bands(river_points, Color("2d3038"), 1.9)
	_draw_desfiladeiro_waterfall_crest()
	var wall_caps: Array[Texture2D] = [_get_tex(DESFILADEIRO_CLIFF_WALL_TEXTURES[0]), _get_tex(DESFILADEIRO_CLIFF_WALL_TEXTURES[1])]
	var wall_bodies: Array[Texture2D] = [_get_tex(DESFILADEIRO_CLIFF_WALL_BODY_TEXTURES[0]), _get_tex(DESFILADEIRO_CLIFF_WALL_BODY_TEXTURES[1])]
	for y in range(3, 13):
		var is_top_row := y == 3
		draw_texture_rect(wall_caps[0] if is_top_row else wall_bodies[0], tile_rect(4, y), false)
		draw_texture_rect(wall_caps[1] if is_top_row else wall_bodies[1], tile_rect(7, y), false)

## Queda d'água (pedido do usuário): sem isso, o topo do rio era uma linha
## reta exatamente na fronteira y=3/y=4 (onde a montanha de fundo termina e a
## ravina começa) — espuma branca irregular + 2 pedrinhas (mesmos recortos
## `desfiladeiro-rock-*` já usados como obstáculo alhures, aqui só
## decorativos, sem entrar em blocked_tiles) quebram essa linha, sugerindo
## uma pequena cachoeira despencando pra dentro da ravina.
func _draw_desfiladeiro_waterfall_crest() -> void:
	var crest_y: float = 3.55 * TILE_SIZE
	for fx in [5.15, 5.55, 5.95, 6.35]:
		var center := Vector2(fx * TILE_SIZE, crest_y + sin(fx * 11.0) * 6.0)
		var foam: float = 0.5 + 0.5 * sin(_soul_phase * 2.1 + fx * 4.0)
		draw_circle(center, 7.0 + foam * 3.0, Color(0.90, 0.96, 0.98, 0.55 + foam * 0.25))
	var rock_1 := _get_tex("res://assets/props/desfiladeiro/desfiladeiro_rock_4.png")
	var rock_2 := _get_tex("res://assets/props/desfiladeiro/desfiladeiro_rock_2.png")
	_draw_scaled_prop(rock_1, Vector2(5.25, 3.75) * TILE_SIZE, 30.0)
	_draw_scaled_prop(rock_2, Vector2(6.35, 3.35) * TILE_SIZE, 26.0)

## Desenha `tex` centrada em `center`, redimensionada pra caber num quadrado
## de lado `max_dim` — mesma fórmula de _draw_curated_props(), só reaproveita
## fora do mecanismo de "decorations" pra acentos fixos como a cachoeira acima.
func _draw_scaled_prop(tex: Texture2D, center: Vector2, max_dim: float) -> void:
	var tex_size: Vector2 = tex.get_size()
	var size: Vector2 = tex_size * (max_dim / maxf(tex_size.x, tex_size.y))
	draw_texture_rect(tex, Rect2(center - size * 0.5, size), false)

## O morro da ESTRADA INVERNO foi removido. Estas constantes/função ficam
## inertes para preservar compatibilidade com cenas ou ferramentas antigas que
## ainda possam referenciá-las.
const ESTRADA_INVERNO_CLIFF_CAP_GID := 1926
const ESTRADA_INVERNO_CLIFF_BODY_GIDS := [1966, 2006, 2046]

func _draw_estrada_inverno_cliff_tile(x: int, y: int) -> void:
	# Os dois trechos verticais da parede (regra "stairs" em
	# ScenarioManager._estrada_inverno_definition(): y em [9,10] é o vão da
	# escada) começam de novo em y=0 e em y=11 — cada um mostra a borda com
	# capim (cap) só na própria linha do topo.
	var row_in_run := y if y <= 8 else y - 11
	var gid: int
	if row_in_run == 0:
		gid = ESTRADA_INVERNO_CLIFF_CAP_GID
	else:
		gid = ESTRADA_INVERNO_CLIFF_BODY_GIDS[(row_in_run - 1) % ESTRADA_INVERNO_CLIFF_BODY_GIDS.size()]
	var atlas := _get_tex(LuaValleyLayout.ATLAS_PATH)
	var src: Rect2i = LuaValleyLayout.atlas_rect(gid)
	draw_texture_rect_region(atlas, tile_rect(x, y), Rect2(src.position, src.size))

## Cordilheira de fundo da ESTRADA INVERNO (pedido do usuário: "a mesma
## montanha que tem no cenário da Horda" — na prática, a mesma imagem de
## montanhas nevadas já usada no fundo de céu do DESFILADEIRO, ver
## DESFILADEIRO_MOUNTAINS_TEXTURE). Ao contrário do Desfiladeiro, aqui as 3
## primeiras linhas são água de verdade (jogável, mesmo type "water" do
## Campo — não dá pra virar céu sem quebrar a regra 7/8 do pedido original),
## então a montanha fica FORA do tabuleiro, numa faixa acima da linha y=0 —
## a câmera padrão sobra margem suficiente ao redor do tabuleiro 13x13 pra
## essa faixa aparecer, sem tirar nem um tile jogável do cenário.
## Enriquecimento de decoração (pedido do usuário): recorte real da
## referência (estrada inverno/neve1.png) substituindo a neve procedural que
## existia aqui antes — mesmo papel de DESFILADEIRO_SNOW_TEXTURE. O arquivo já
## estava importado em assets/tiles/ (mesma pasta usada pelas árvores da
## própria Estrada Inverno, ver correção acima) de uma tentativa anterior que
## nunca chegou a ligar o código de desenho a ele.
const ESTRADA_INVERNO_SNOW_TEXTURE := "res://assets/tiles/estrada_inverno_neve1.png"

func _draw_estrada_inverno_mountains_bg(board_w: int) -> void:
	var band_height := TILE_SIZE * 2.4
	var band_rect := Rect2(Vector2(0, -band_height), Vector2(board_w * TILE_SIZE, band_height))
	draw_rect(band_rect, Color("bcdcec"))
	draw_texture_rect(_get_tex(DESFILADEIRO_MOUNTAINS_TEXTURE), band_rect, false)

## ESTRADA INVERNO (cenário independente — ScenarioManager._estrada_inverno_
## definition()/GameState._setup_estrada_inverno). Neve procedural cobrindo o
## tabuleiro inteiro (opaca — ver comentário abaixo sobre por que não pode
## ser translúcida aqui), trilha de terra clara e escada de madeira real
## (LuaValleyLayout.LADDER_PATH, mesmo asset da Horda). O rio reaproveita a
## MESMA _draw_river_bands() já usada pelo Campo/Vale de Lua, só com pontos
## próprios.
func _draw_estrada_inverno_board() -> void:
	var board_w := state.board_width
	var board_h := state.board_height
	# Neve contínua: uma única superfície cobre o tabuleiro inteiro. Desenhar o
	# recorte uma vez evita a borda marrom que aparecia em cada quadrado quando
	# a textura era repetida tile a tile.
	var snow_tex := _get_tex(ESTRADA_INVERNO_SNOW_TEXTURE)
	var board_rect := Rect2(Vector2.ZERO, Vector2(board_w, board_h) * TILE_SIZE)
	draw_rect(board_rect, Color("dce8ef"))
	# Usa apenas o miolo do recorte (sem a moldura de terra/grama), esticado
	# como uma camada única para não criar emendas entre quadrados.
	draw_texture_rect_region(snow_tex, board_rect, Rect2(30, 30, 213, 207))
	for y in range(board_h):
		for x in range(board_w):
			var terrain = state.terrain_at(x, y)
			if terrain == null: continue
			var terrain_type := String(terrain.get("type", ""))
			if terrain_type == "tree":
				var trect := tile_rect(x, y)
				draw_circle(trect.position + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.82), 14.0, Color(0.12, 0.16, 0.22, 0.24))
				draw_texture_rect(_get_tex("res://assets/tiles/%s" % terrain["art"]), trect, false)
	# Margem de neve/gelo em vez da grama padrão de _draw_river_bands (pedido
	# do usuário: aproximar da referência, onde a água encontra neve direto,
	# sem faixa verde).
	_draw_river_bands(_estrada_inverno_river_points(), Color("d8e4ea"))
	var trail_tiles: Array = scenario_definition.get("trail", [])
	if trail_tiles.size() > 1:
		var trail_path := PackedVector2Array()
		for tile in trail_tiles:
			trail_path.append(tile_center(int(tile["x"]), int(tile["y"])))
		draw_polyline(trail_path, Color("b99c6d"), TILE_SIZE * 0.58, true)
		draw_polyline(trail_path, Color("d0b582"), TILE_SIZE * 0.42, true)
	for tile in trail_tiles:
		var rect := tile_rect(tile["x"], tile["y"])
		draw_rect(rect, Color("c9ad78"))
		var speck := rect.position + Vector2(12 + posmod(tile["x"]*13 + tile["y"]*7, 40), 12 + posmod(tile["x"]*19 + tile["y"]*11, 40))
		draw_circle(speck, 3.0, Color(0.55, 0.44, 0.26, 0.30))

## Curva do rio da ESTRADA INVERNO — mesma técnica do rio do Campo
## (`_river_curve_points`/`_append_river_curve`), pontos próprios cobrindo a
## borda superior (linhas 0-2) em vez da coluna central do Campo.
func _estrada_inverno_river_points() -> PackedVector2Array:
	var result := PackedVector2Array()
	var start := Vector2(-0.3, 1.0)
	result = _append_river_curve(result, start, Vector2(2.0, 0.6), Vector2(4.0, 1.6), Vector2(6.0, 0.9))
	start = Vector2(6.0, 0.9)
	result = _append_river_curve(result, start, Vector2(7.4, 0.4), Vector2(8.3, 1.1), Vector2(9.3, -0.3), true)
	for i in range(result.size()): result[i] *= TILE_SIZE
	return result

## Escada única de acesso ao platô — mesmo asset real da Horda
## (LuaValleyLayout.LADDER_PATH, ladder_long.png, CC0), esticado pra cobrir
## as N células de "stairs" (mesma técnica de _draw_lua_ladder, só que pros
## tiles próprios da ESTRADA INVERNO em vez do array hardcoded do Vale de
## Lua).
func _draw_estrada_inverno_stairs() -> void:
	var tiles: Array = scenario_definition.get("stairs", [])
	if tiles.is_empty(): return
	var ladder := _get_tex(LuaValleyLayout.LADDER_PATH)
	var top: Dictionary = tiles[0]
	var destination := Rect2(Vector2(int(top["x"]), int(top["y"])) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE * tiles.size()))
	draw_rect(Rect2(destination.position + Vector2(23, 3), Vector2(18, destination.size.y - 6)), Color(0.03, 0.025, 0.02, 0.22))
	draw_texture_rect(ladder, destination, false)

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
	"village-fence-broken": 92.0,
	"village-barricade": 90.0,
	"village-bridge-broken": 110.0,
}

## Mesmo papel de VILLAGE_PROP_MAX_DIM, pros props "village2-*" da
## reformulação completa (pedido do usuário) — valores já pensados pro
## TILE_SIZE atual (96px), não os 64px de quando VILLAGE_PROP_MAX_DIM foi
## calibrado.
const VILLAGE2_PROP_MAX_DIM := {
	"village2-well": 110.0, "village2-boat": 110.0, "village2-dock": 150.0,
	"village2-wagon": 150.0,
	"village2-crate-1": 70.0, "village2-crate-2": 70.0, "village2-crate-3": 70.0,
	"village2-crate-4": 70.0, "village2-crate-5": 70.0,
	"village2-barrel-1": 70.0, "village2-barrel-2": 75.0, "village2-barrel-3": 75.0,
	"village2-barrel-4": 80.0, "village2-barrel-5": 75.0,
	"village2-sacks": 90.0, "village2-basket": 70.0, "village2-jar": 75.0, "village2-stool": 60.0,
	"village2-fence-1": 130.0, "village2-fence-2": 130.0, "village2-fence-3": 130.0,
	"village2-fence-broken": 130.0, "village2-wall-ruin": 150.0, "village2-barricade": 135.0,
	"village2-debris-ash": 130.0, "village2-rubble-wall": 150.0, "village2-rubble-rocks": 120.0,
	"village2-campfire": 130.0, "village2-stick-pile": 120.0, "village2-branch": 70.0,
	"village2-banner": 130.0, "village2-lamppost": 160.0,
	"village2-planter-1": 80.0, "village2-planter-2": 80.0,
	"village2-tree-green-1": 140.0, "village2-tree-green-2": 140.0,
	"village2-tree-dead-1": 140.0, "village2-tree-dead-2": 140.0,
	"village2-stump-1": 90.0, "village2-stump-2": 90.0, "village2-bush": 70.0,
	"village2-reeds-1": 90.0, "village2-reeds-2": 90.0, "village2-reeds-3": 90.0,
	"village2-reeds-4": 90.0, "village2-reeds-5": 90.0,
	"village2-lilypad-1": 70.0, "village2-lilypad-2": 70.0, "village2-lilypad-3": 70.0,
	"village2-rock-1": 80.0, "village2-rock-2": 80.0,
}

## Mesmo papel de VILLAGE_PROP_MAX_DIM, só que pros props "porto-*"
## (recortes reais da referência do usuário, ver CURATED_PROP_TEXTURES).
const PORTO_PROP_MAX_DIM := {
	"porto-cart": 100.0,
	"porto-fence": 92.0,
	"porto-barrel": 52.0,
	"porto-barrel-stack": 60.0,
	"porto-crate": 52.0,
	"porto-mossy-rock": 56.0,
	"porto-boat": 96.0,
	"porto-market-stall": 110.0,
	"porto-awning": 110.0,
	"porto-lantern-post": 84.0,
	"porto-lilypad": 40.0,
	# Pedido do usuário: enriquecimento de decoração (ver obstacles em
	# ScenarioManager._porto_definition()). "porto-house-2" maior que os
	# demais props curados de propósito — precisa ler como uma construção;
	# seu span 2x2 é aplicado diretamente em _draw_curated_props().
	"porto-house-2": 150.0,
	"porto-tree": 110.0,
	"porto-lamp": 84.0,
	"porto-crate-2": 54.0,
	"porto-sacks": 62.0,
}

## Mesmo papel de VILLAGE_PROP_MAX_DIM/PORTO_PROP_MAX_DIM, pros props
## "desfiladeiro-*" (pedras, lápides/monólitos, cristal e arbustos secos).
const DESFILADEIRO_PROP_MAX_DIM := {
	"desfiladeiro-rock-1": 92.0,
	"desfiladeiro-rock-2": 92.0,
	"desfiladeiro-rock-3": 68.0,
	"desfiladeiro-rock-4": 52.0,
	"desfiladeiro-monolith-1": 76.0,
	"desfiladeiro-monolith-2": 76.0,
	"desfiladeiro-monolith-3": 76.0,
	"desfiladeiro-monolith-4": 76.0,
	"desfiladeiro-crystal": 84.0,
	"desfiladeiro-bush-1": 60.0,
	"desfiladeiro-bush-2": 60.0,
	"desfiladeiro-bush-3": 70.0,
}

## Mesmo papel de DESFILADEIRO_PROP_MAX_DIM, pros props "estrada-inverno-*"
## (poço, pedras, barris e a caveira na neve).
const ESTRADA_INVERNO_PROP_MAX_DIM := {
	"estrada-inverno-well": 78.0,
	"estrada-inverno-rock-1": 84.0,
	"estrada-inverno-rock-2": 68.0,
	"estrada-inverno-rock-3": 48.0,
	"estrada-inverno-barrel-1": 60.0,
	"estrada-inverno-barrel-2": 56.0,
	"estrada-inverno-skull": 56.0,
	"estrada-inverno-log-1": 88.0,
	"estrada-inverno-log-2": 76.0,
	"estrada-inverno-stump": 58.0,
	"estrada-inverno-snow-rocks-1": 54.0,
	"estrada-inverno-snow-rocks-2": 54.0,
	"estrada-inverno-snow-pebbles-1": 42.0,
	"estrada-inverno-snow-pebbles-2": 38.0,
	"estrada-inverno-snow-bush-1": 52.0,
	"estrada-inverno-snow-bush-2": 48.0,
}

## Props transparentes curados da biblioteca externa. São declarados como
## decoração no cenário e nunca alteram custo de movimento, targeting ou fila
## de turnos por si só — mas alguns (village-fence-broken/barricade/
## bridge-broken) têm a própria célula somada a "blocked_tiles" pelo cenário
## que os declara, então bloqueiam movimento como qualquer parede.
func _draw_curated_props() -> void:
	for decoration in scenario_definition.get("decorations", []):
		var kind := String(decoration.get("kind", ""))
		if not CURATED_PROP_TEXTURES.has(kind):
			continue
		var tex := _get_tex(CURATED_PROP_TEXTURES[kind])
		var span_w := int(decoration.get("w", 1))
		var span_h := int(decoration.get("h", 1))
		var center := Vector2(
			(float(decoration["x"]) + float(span_w) * 0.5) * TILE_SIZE,
			(float(decoration["y"]) + float(span_h) * 0.5) * TILE_SIZE
		)
		var village_prop := kind.begins_with("village-")
		var village2_prop := kind.begins_with("village2-")
		var porto_prop := kind.begins_with("porto-")
		var desfiladeiro_prop := kind.begins_with("desfiladeiro-")
		var estrada_inverno_prop := kind.begins_with("estrada-inverno-")
		var hazard_prop := kind.begins_with("lava-") or kind.begins_with("corpse-")
		var size: Vector2
		var tint := Color.WHITE
		if village_prop:
			var tex_size: Vector2 = tex.get_size()
			var max_dim: float = VILLAGE_PROP_MAX_DIM.get(kind, 64.0)
			size = tex_size * (max_dim / maxf(tex_size.x, tex_size.y))
		elif village2_prop:
			# Recortes reais (ver CURATED_PROP_TEXTURES) — cores originais
			# preservadas, sem tingimento (mesma ideia de porto/desfiladeiro/
			# estrada-inverno abaixo).
			var tex_size: Vector2 = tex.get_size()
			var max_dim: float = VILLAGE2_PROP_MAX_DIM.get(kind, 80.0)
			size = tex_size * (max_dim / maxf(tex_size.x, tex_size.y))
		elif porto_prop:
			var tex_size: Vector2 = tex.get_size()
			if kind == "porto-house-2":
				# A casa usa os quatro quadrados declarados no cenário, mantendo
				# a proporção original e um pequeno respiro nas bordas.
				size = tex_size * (min(span_w, span_h) * TILE_SIZE - 8.0) / maxf(tex_size.x, tex_size.y)
			else:
				var max_dim: float = PORTO_PROP_MAX_DIM.get(kind, 64.0)
				size = tex_size * (max_dim / maxf(tex_size.x, tex_size.y))
		elif desfiladeiro_prop:
			var tex_size: Vector2 = tex.get_size()
			var max_dim: float = DESFILADEIRO_PROP_MAX_DIM.get(kind, 64.0)
			size = tex_size * (max_dim / maxf(tex_size.x, tex_size.y))
		elif estrada_inverno_prop:
			var tex_size: Vector2 = tex.get_size()
			var max_dim: float = ESTRADA_INVERNO_PROP_MAX_DIM.get(kind, 64.0)
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
## reaproveitado pelo rio fixo do Campo (_draw_continuous_river), pelo rio
## real do Vale de Lua (_draw_lua_river) e pelo rio do DESFILADEIRO
## (_draw_desfiladeiro_chasm, ver `width_scale` abaixo), cada um com seus
## próprios pontos. `width_scale` (default 1.0, sem efeito nos chamadores
## que não passam o parâmetro) multiplica as 5 faixas — o DESFILADEIRO usa
## um valor maior porque seu rio ocupa 2 células de largura, não 1 como o
## rio fino do Campo/Vale de Lua.
func _draw_river_bands(points: PackedVector2Array, bank_color: Color = Color("36582e"), width_scale: float = 1.0) -> void:
	if points.size() < 2: return
	# Margem orgânica contínua, profundidade e duas faixas internas formam
	# um gradiente sem introduzir qualquer recorte entre quadrados.
	draw_polyline(points, bank_color, TILE_SIZE * 1.30 * width_scale, true)
	draw_polyline(points, Color("123f5c"), TILE_SIZE * 1.08 * width_scale, true)
	draw_polyline(points, Color("1d6687"), TILE_SIZE * 0.98 * width_scale, true)
	draw_polyline(points, Color(0.20, 0.56, 0.67, 0.72), TILE_SIZE * 0.72 * width_scale, true)
	draw_polyline(points, Color(0.28, 0.66, 0.73, 0.30), TILE_SIZE * 0.42 * width_scale, true)

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
