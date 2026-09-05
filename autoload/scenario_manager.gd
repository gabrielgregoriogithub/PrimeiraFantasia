class_name ScenarioManager
extends Node

const DungeonFloor4LayoutScript := preload("res://data/dungeon_floor_4_layout.gd")

signal scenario_changed(id: String)

const FIELD := "field"
const TOWER := "tower_floor_1"
const TOWER_FLOOR_2 := "tower_floor_2"
const TOWER_FLOOR_3 := "tower_floor_3"
const TOWER_FLOOR_4 := "tower_floor_4"
const LUA_VALLEY := "lua_valley"
const VILLAGE := "village"
const FOREST := "forest"
var active_id := VILLAGE

## Ordem de progressão de fase (mesma ordem visual dos botões do topo, pedido
## do usuário: VILA, FLORESTA, CAMPO, HORDA, TORRE, 2º ANDAR) — usada por main.gd pra
## avançar automaticamente de fase depois de uma vitória (ver
## _start_victory_phase_advance). Cíclica: vencer a última fase (Torre)
## volta pra Vila.
const PHASE_ORDER := [VILLAGE, FOREST, FIELD, LUA_VALLEY, TOWER, TOWER_FLOOR_2, TOWER_FLOOR_3, TOWER_FLOOR_4]

func set_active(id: String) -> void:
	if id not in [FIELD, TOWER, TOWER_FLOOR_2, TOWER_FLOOR_3, TOWER_FLOOR_4, LUA_VALLEY, VILLAGE, FOREST] or id == active_id: return
	active_id = id
	scenario_changed.emit(id)

func active_definition() -> Dictionary:
	return definition(active_id)

func next_id(from_id: String = "") -> String:
	var current: String = from_id if from_id != "" else active_id
	var idx: int = PHASE_ORDER.find(current)
	if idx < 0: idx = 0
	return PHASE_ORDER[(idx + 1) % PHASE_ORDER.size()]

static func definition(id: String) -> Dictionary:
	if id == TOWER: return _tower_definition()
	if id == TOWER_FLOOR_2: return _tower_floor_2_definition()
	if id == TOWER_FLOOR_3: return _tower_floor_3_definition()
	if id == TOWER_FLOOR_4: return _tower_floor_4_definition()
	if id == LUA_VALLEY: return _lua_valley_definition()
	if id == VILLAGE: return _village_definition()
	if id == FOREST: return _forest_definition()
	return {"id": FIELD, "name": "CAMPO", "indoor": false,
		"decorations": [
			{"x":1,"y":3,"kind":"field-logs","decorative":true,"blocking":false},
			{"x":9,"y":3,"kind":"field-rock-1","decorative":true,"blocking":false},
			{"x":1,"y":7,"kind":"field-rock-2","decorative":true,"blocking":false},
			{"x":11,"y":7,"kind":"field-rock-3","decorative":true,"blocking":false},
		],
		# Pedido do usuário: sem esses spawns nomeados, apply_pvp_scenario
		# (GameState) ancorava o preenchimento de sobra em (0,0) pros DOIS
		# times — herói e monstro nasciam colados no canto do tabuleiro em vez
		# de espalhados nos lados opostos do Campo (ver
		# GameState._apply_scenario_spawns). Coluna x=2 (herói) e x=9/11
		# (monstro) espelham a mesma disposição que os templates de
		# Units.build() já usam nesse cenário fora do PVP.
		"player_spawns": [{"x":2,"y":1},{"x":2,"y":3},{"x":2,"y":5},{"x":2,"y":7},{"x":2,"y":9},{"x":2,"y":11}],
		# Pedido do usuário: (11,1) caía dentro do bloco 3x3 da Montanha
		# (10-12, 0-2) — um inimigo podia nascer literalmente em cima dela.
		# Trocado por (11,7), espalhando mais pra baixo do tabuleiro, longe
		# do bloco da estrutura.
		"enemy_spawns": [
			{"x":9,"y":1},{"x":11,"y":7},{"x":9,"y":5},{"x":11,"y":3},{"x":9,"y":7},
			{"x":11,"y":5},{"x":9,"y":9},{"x":11,"y":9},{"x":9,"y":11},{"x":11,"y":11},
		]}

static func _tower_definition() -> Dictionary:
	var walls: Array = []
	# Muralha externa; a abertura de três tiles ao sul é a entrada principal.
	for x in 13:
		walls.append({"x": x, "y": 0})
		if x not in [5, 6, 7]: walls.append({"x": x, "y": 12})
	for y in range(1, 12):
		walls.append({"x": 0, "y": y})
		walls.append({"x": 12, "y": y})
	# Salas laterais com portas abertas e corredores de 2–3 tiles.
	for x in [1, 2, 4, 8, 10, 11]: walls.append({"x": x, "y": 3})
	for x in [1, 2, 4, 8, 10, 11]: walls.append({"x": x, "y": 9})
	var pillars := [{"x":4,"y":5},{"x":8,"y":5},{"x":4,"y":7},{"x":8,"y":7}]
	var doors := [{"x":3,"y":3},{"x":9,"y":3},{"x":3,"y":9},{"x":9,"y":9}]
	var torches := [{"x":2,"y":3},{"x":10,"y":3},{"x":2,"y":9},{"x":10,"y":9},{"x":5,"y":5},{"x":7,"y":7}]
	var decorations := [
		{"x":6,"y":1,"kind":"stairs"}, {"x":6,"y":12,"kind":"entrance"},
		{"x":6,"y":5,"kind":"rune"}, {"x":6,"y":6,"kind":"rune"}, {"x":6,"y":7,"kind":"rune"},
		{"x":10,"y":10,"kind":"debris"},
		{"x":1,"y":2,"kind":"tower-crate","decorative":true,"blocking":false,"future_interactive":"container"},
		{"x":11,"y":2,"kind":"tower-barrel","decorative":true,"blocking":false,"future_interactive":"barrel"},
		{"x":1,"y":10,"kind":"tower-crate-stack","decorative":true,"blocking":false,"future_interactive":"container"},
		{"x":11,"y":10,"kind":"tower-barrel","decorative":true,"blocking":false,"future_interactive":"barrel"},
	]
	return {
		"id": TOWER, "name": "TORRE — 1º ANDAR", "indoor": true,
		"walls": walls, "pillars": pillars, "doors": doors,
		"torches": torches, "decorations": decorations,
		"player_spawns": [{"x":2,"y":11},{"x":3,"y":10},{"x":4,"y":11},{"x":5,"y":10},{"x":6,"y":11}],
		"enemy_spawns": [{"x":2,"y":1},{"x":7,"y":2},{"x":8,"y":1},{"x":9,"y":2},{"x":10,"y":1}],
		"music": "res://assets/third_party/shattered_pixel_dungeon/music/prison_1.ogg",
		"step_sfx": "stoneStepSpd",
	}

static func _tower_floor_2_definition() -> Dictionary:
	var layout := DungeonFloor2Layout.build()
	return {
		"id": TOWER_FLOOR_2, "name": "2º ANDAR", "indoor": true,
		"floor_number": 2, "theme": "sewers",
		"walls": layout["walls"], "pillars": layout["pillars"], "doors": layout["doors"],
		"torches": layout["torches"], "decorations": layout["decorations"],
		"poison_gas": layout["poison_gas"],
		"entrance_tile": DungeonFloor2Layout.ENTRANCE,
		"exit_tile": DungeonFloor2Layout.EXIT,
		"next_floor_id": "tower_floor_3",
		"player_spawns": [{"x":1,"y":11},{"x":2,"y":11},{"x":1,"y":10},{"x":2,"y":10},{"x":3,"y":11}],
		# Pedido do usuário: elenco do 2º Andar trocado pra 1 Zumbi, 1
		# Esqueleto, 1 Fantasma, 1 Lich e 1 Vampiro — reaproveita 5 das 9
		# posições já curadas do andar (livres de parede/pilar, testadas na
		# campanha), sem inventar tile novo nenhum.
		"enemy_roster": [
			{"kind":"zombie","x":2,"y":2},
			{"kind":"skeleton","x":6,"y":2},
			{"kind":"ghost","x":1,"y":5},
			{"kind":"lich","x":3,"y":7},
			{"kind":"vampire","x":2,"y":9},
		],
		# Pedido do usuário: sem isso, GameState.apply_pvp_scenario (Modo PVP)
		# não achava "enemy_spawns" nesta definição (só "enemy_roster", que só
		# _setup_dungeon_floor/campanha lê) e ancorava TODO o time inimigo em
		# (0,0) — bem perto dos player_spawns deste andar (canto oposto,
		# 1,10-3,11), grudando os dois times. Mesmas 5 posições do roster acima.
		"enemy_spawns": [
			{"x":2,"y":2}, {"x":6,"y":2}, {"x":1,"y":5}, {"x":3,"y":7}, {"x":2,"y":9},
		],
		"music": "res://assets/third_party/shattered_pixel_dungeon/music/prison_1.ogg",
		"step_sfx": "stoneStepSpd",
	}

static func _tower_floor_3_definition() -> Dictionary:
	var layout := DungeonFloor3Layout.build()
	return {
		"id": TOWER_FLOOR_3, "name": "3º ANDAR", "indoor": true,
		"floor_number": 3, "theme": "demon-halls",
		"walls": layout["walls"], "pillars": layout["pillars"], "doors": layout["doors"],
		"lava": layout["lava"], "torches": layout["torches"], "decorations": layout["decorations"],
		"hazards": {"lava": {"walkable": true, "movement_cost": 3, "damage_on_enter": 1, "status_on_end_turn": "burned"}},
		"entrance_tile": DungeonFloor3Layout.ENTRANCE,
		"exit_tile": DungeonFloor3Layout.EXIT,
		"next_floor_id": "tower_floor_4",
		"player_spawns": [{"x":1,"y":1},{"x":2,"y":1},{"x":1,"y":2},{"x":2,"y":2},{"x":3,"y":1}],
		# Pedido do usuário: elenco do 3º Andar trocado pra 1 Dragão, 1 Lava
		# Humana, 2 Fogo Vivo e 1 Demônio das Chamas — reaproveita 5 das 7
		# posições já curadas do andar.
		"enemy_roster": [
			{"kind":"dragon","x":5,"y":2},
			{"kind":"lava_human","x":7,"y":5},
			{"kind":"living_fire","x":5,"y":3},{"kind":"living_fire","x":6,"y":4},
			{"kind":"flame_demon","x":5,"y":9},
		],
		# Pedido do usuário: mesma correção do 2º Andar — sem "enemy_spawns", o
		# Modo PVP ancorava o time inimigo em (0,0), colado nos player_spawns
		# deste andar (mesmo canto, 1,1-3,1). Mesmas 5 posições do roster acima.
		"enemy_spawns": [
			{"x":5,"y":2}, {"x":7,"y":5}, {"x":5,"y":3}, {"x":6,"y":4}, {"x":5,"y":9},
		],
		"music": "res://assets/third_party/shattered_pixel_dungeon/music/prison_1.ogg",
		"step_sfx": "stoneStepSpd",
	}

static func _tower_floor_4_definition() -> Dictionary:
	var layout: Dictionary = DungeonFloor4LayoutScript.build()
	return {
		"id": TOWER_FLOOR_4, "name": "4º ANDAR", "indoor": true,
		"floor_number": 4, "theme": "demon-halls",
		"walls": layout["walls"], "pillars": layout["pillars"], "doors": layout["doors"],
		"lava": layout["lava"], "torches": layout["torches"], "decorations": layout["decorations"],
		"hazards": {"lava": {"walkable": true, "movement_cost": 3, "damage_on_enter": 1, "status_on_end_turn": "burned"}},
		"entrance_tile": DungeonFloor4LayoutScript.ENTRANCE,
		"exit_tile": DungeonFloor4LayoutScript.EXIT,
		"next_floor_id": "tower_floor_5",
		"player_spawns": [{"x":1,"y":1},{"x":2,"y":1},{"x":1,"y":2},{"x":2,"y":2},{"x":3,"y":1}],
		"enemy_roster": [
			{"kind":"salamander","x":8,"y":9},
		],
		# Pedido do usuário: 4º Andar também escolhível no Modo PVP — mesma
		# correção do 2º/3º Andar (ver comentário lá): sem "enemy_spawns", o
		# time inimigo do PVP (roster livre, não o "enemy_roster" fixo acima)
		# ancorava todo mundo em (0,0). 5 tiles "." do layout (ver
		# DungeonFloor4Layout.GRID), espalhados pelo lado oposto aos
		# player_spawns e longe de paredes/lava/portas/pilares/decorações.
		"enemy_spawns": [
			{"x":9,"y":1}, {"x":9,"y":3}, {"x":9,"y":9}, {"x":10,"y":11}, {"x":3,"y":11},
		],
		"music": "res://assets/third_party/shattered_pixel_dungeon/music/prison_1.ogg",
		"step_sfx": "stoneStepSpd",
	}

## Vila atacada recentemente: a estrada de terra cruza o centro sem fechar
## corredores, enquanto as construções ficam nas bordas. `blocked_tiles`
## representa apenas a base física dos prédios; fogo/destroços são visuais.
static func _village_definition() -> Dictionary:
	var dirt: Array = []
	for y in range(13):
		for x in range(13):
			var main_road := y in [6, 7] and x <= 10
			var north_branch := x in [5, 6] and y in range(2, 7)
			var south_branch := x in [8, 9] and y in range(7, 12)
			var yard_patch := (x + y * 3) % 11 == 0 and x not in [0, 12]
			if main_road or north_branch or south_branch or yard_patch:
				dirt.append({"x":x,"y":y})
	# Rio contínuo (2 células de largura) na borda leste, atravessando o
	# cenário inteiro de cima a baixo e saindo pelas duas bordas (linha 0 e
	# linha 12) — pedido do usuário. O moinho fica encostado nele (colunas
	# 9-10, logo a oeste do rio), ao contrário do lago isolado de antes.
	var water: Array = []
	for y in range(13):
		water.append({"x":11,"y":y})
		water.append({"x":12,"y":y})
	var buildings := [
		{"x":1,"y":1,"w":3,"h":2,"kind":"village-house","damaged":true,"burning":true},
		{"x":7,"y":1,"w":2,"h":2,"kind":"village-house","damaged":true,"burning":true},
		{"x":1,"y":9,"w":3,"h":2,"kind":"village-house","damaged":true,"burning":true},
		{"x":6,"y":9,"w":3,"h":2,"kind":"village-house","damaged":true,"burning":false},
		{"x":9,"y":1,"w":2,"h":3,"kind":"village-mill","damaged":true,"burning":false},
	]
	var blocked: Array = []
	for building in buildings:
		for oy in int(building["h"]):
			for ox in int(building["w"]):
				var tile := {"x":int(building["x"])+ox,"y":int(building["y"])+oy}
				if not water.has(tile): blocked.append(tile)
	return {
		"id":VILLAGE,"name":"VILA","indoor":false,
		"dirt":dirt,"water":water,"buildings":buildings,"blocked_tiles":blocked,
		"decorations":[
			{"x":4,"y":2,"kind":"village-debris"},{"x":3,"y":8,"kind":"village-char"},
			{"x":10,"y":10,"kind":"village-debris"},{"x":5,"y":5,"kind":"village-char"},
			# Props curados do Medieval Village MegaKit espalhados pra dar mais
			# vida estática ao cenário (ver VILLAGE_PROP_MAX_DIM/CURATED_PROP_TEXTURES
			# em board_view.gd) — puramente decorativos, mesma regra dos demais
			# props curados (não entram no terrainMap, não bloqueiam nada).
			{"x":2,"y":7,"kind":"village-wagon","decorative":true,"blocking":false},
			{"x":5,"y":11,"kind":"village-crate","decorative":true,"blocking":false},
			{"x":4,"y":4,"kind":"village-crate","decorative":true,"blocking":false},
			{"x":6,"y":3,"kind":"village-fence","decorative":true,"blocking":false},
			{"x":4,"y":7,"kind":"village-fence","decorative":true,"blocking":false},
			{"x":7,"y":4,"kind":"village-rubble","decorative":true,"blocking":false},
			{"x":3,"y":11,"kind":"village-rubble","decorative":true,"blocking":false},
			# Props do pack Farm Buildings (Quaternius, CC0) — poço, galinheiro
			# e cerca de fazenda, reforçando o tema rural ao redor do moinho.
			{"x":10,"y":5,"kind":"village-well","decorative":true,"blocking":false},
			{"x":2,"y":4,"kind":"village-coop","decorative":true,"blocking":false},
			{"x":8,"y":11,"kind":"village-farmfence","decorative":true,"blocking":false},
			{"x":4,"y":9,"kind":"village-barn","decorative":true,"blocking":false},
			# Barquinho parado no rio (Ships by @Quaternius, CC0) — só decoração,
			# não interfere no custo de atravessar água.
			{"x":12,"y":6,"kind":"village-boat","decorative":true,"blocking":false},
			# Mais elementos de fazenda (Farm Buildings, Quaternius, CC0)
			# espalhados pelo cenário, a pedido do usuário — alguns pegando
			# fogo (village-flame procedural, ver board_view.gd:_draw_curated_
			# props) pra reforçar o tema de vila atacada, outros intactos.
			{"x":9,"y":10,"kind":"village-silo","decorative":true,"blocking":false,"burning":true},
			{"x":10,"y":11,"kind":"village-openbarn","decorative":true,"blocking":false,"burning":true},
			{"x":2,"y":11,"kind":"village-smallbarn","decorative":true,"blocking":false},
			{"x":8,"y":4,"kind":"village-watertower","decorative":true,"blocking":false},
			# Árvores avulsas espalhadas pela Vila (mesma arte do Campo,
			# tree1..5.png) — só paisagismo, a pedido do usuário.
			{"x":0,"y":3,"kind":"village-tree1","decorative":true,"blocking":false},
			{"x":3,"y":3,"kind":"village-tree2","decorative":true,"blocking":false},
			{"x":5,"y":8,"kind":"village-tree3","decorative":true,"blocking":false},
			{"x":9,"y":4,"kind":"village-tree4","decorative":true,"blocking":false},
			{"x":6,"y":7,"kind":"village-tree5","decorative":true,"blocking":false},
			{"x":0,"y":10,"kind":"village-tree1","decorative":true,"blocking":false},
			{"x":10,"y":4,"kind":"village-tree2","decorative":true,"blocking":false},
		],
		"player_spawns":[{"x":1,"y":6}],
		"enemy_spawns":[{"x":10,"y":8}],
		"archer_reinforcement":{"turn":4,"x":6,"y":2,"ct":80},
		"goblin_reinforcement":{"turn":6,"x":9,"y":8,"ct":80},
		"music":"res://assets/audio/music/battle_theme.ogg","step_sfx":"grassStep",
	}

## Trilha de terra de 3 colunas (5-7) cruzando o cenário inteiro de baixo pra
## cima; as demais colunas são grama tomada por árvores (tipo "tree" real,
## igual ao Campo — bloqueia e é destrutível, ver BoardLayout.
## BLOCKING_TERRAIN_TYPES/destructible_tile_types), forçando quem quiser
## atravessar o mapa a usar a trilha. Densidade bem alta (~93%, pedido do
## usuário "mais árvores") com clareiras raras espalhadas de forma
## determinística (não aleatória) pra não ficar 100% sólido. Arte mistura as
## 3 variantes próprias da Floresta com as 5 árvores do Campo
## (`res://assets/tiles/tree1-5.png`, já existentes — mesmo mecanismo
## `terrain["art"]`) pra diversificar em vez de repetir só 3 modelos.
static func _forest_definition() -> Dictionary:
	var path: Array = []
	for y in range(13):
		for x in [5, 6, 7]:
			path.append({"x":x,"y":y})
	# Só as artes que também existem no Campo (tree1..5.png,
	# BoardLayout.TREE_ART_VARIANTS) — tree4.png já É uma árvore seca/morta
	# (galhos sem folha) e as outras 4 são cheias/frondosas mas com formatos
	# diferentes, então esse conjunto sozinho já cobre "seca + cheia +
	# outros tipos" sem precisar de nenhuma arte nova.
	var tree_arts := ["tree1.png", "tree2.png", "tree3.png", "tree4.png", "tree5.png"]
	# RNG com seed fixa (mapa fica igual entre partidas/testes) em vez da
	# fórmula aritmética anterior — pedido do usuário: o padrão de
	# (x*3+y*5)%5 criava faixas diagonais bem regulares/repetitivas em vez
	# de uma distribuição que parece natural.
	var tree_rng := RandomNumberGenerator.new()
	tree_rng.seed = 20260826
	var trees: Array = []
	for y in range(13):
		for x in range(13):
			if x in [5, 6, 7]:
				continue
			# ~15% de clareiras, sorteadas tile a tile (não mais um padrão
			# fixo) — também "tira algumas" árvores, a pedido do usuário.
			if tree_rng.randf() < 0.15:
				continue
			trees.append({"x":x, "y":y, "art":tree_arts[tree_rng.randi() % tree_arts.size()]})
	return {
		"id":FOREST,"name":"FLORESTA","indoor":false,
		"path":path,"trees":trees,
		"player_spawns":[{"x":6,"y":11}],
		"enemy_spawns":[{"x":6,"y":1}],
		# Químico entra pela parte de baixo do mapa (perto do Ladino) no
		# turno 8; Xamã entra pela trilha bem no meio do cenário (como se
		# tivesse saído do meio das árvores) no turno 10 — dois reforços
		# distintos, um pra cada lado, em turnos diferentes.
		"chemist_reinforcement":{"turn":8,"x":6,"y":12,"ct":80},
		"shaman_reinforcement":{"turn":10,"x":6,"y":6,"ct":80},
		"music":"res://assets/audio/music/battle_theme.ogg","step_sfx":"grassStep",
	}

## Layout portado DIRETAMENTE do recorte 26x22 (colunas 8-33, linhas 0-21)
## do mapa inicial real de `legend-of-lua-main` (`maps/test.lua`, layers
## "Base"/"Objects", tileset `Overworld-edit.png`) — ver
## `data/lua_valley_layout.gd` para os GIDs/máscaras de colisão célula a
## célula e ASSET_SOURCES.md para a proveniência. `walls`/`water` vêm da
## geometria REAL das layers de objeto "Walls"/"Water" do mapa original
## (BLOCKED_MASK/WATER_MASK), não de uma tabela de GIDs adivinhada — é a
## mesma fonte de verdade que o próprio Legend of Lua usa pra colisão.
static func _lua_valley_definition() -> Dictionary:
	var walls: Array = []
	var water: Array = []
	for y in LuaValleyLayout.GRID_HEIGHT:
		for x in LuaValleyLayout.GRID_WIDTH:
			if LuaValleyLayout.is_ladder_tile(x, y):
				continue
			elif LuaValleyLayout.is_blocked(x, y):
				walls.append({"x": x, "y": y})
			elif LuaValleyLayout.is_water(x, y):
				water.append({"x": x, "y": y})
	# Área de grama aberta a sudoeste do lago, livre de parede/água/decoração
	# (tronco, pedras) — mesma faixa visível na composição original.
	var player_spawns := [
		{"x":7,"y":9},{"x":8,"y":9},{"x":9,"y":9},{"x":7,"y":10},{"x":8,"y":10},
	]
	return {"id":LUA_VALLEY,"name":"HORDA — SOBREVIVÊNCIA","indoor":false,
		"board_width":LuaValleyLayout.GRID_WIDTH,"board_height":LuaValleyLayout.GRID_HEIGHT,
		"walls":walls,"water":water,"ladders":LuaValleyLayout.LADDER_TILES,
		"cave_mouth":LuaValleyLayout.CAVE_MOUTH,
		"player_spawns":player_spawns,
		"music":"res://assets/audio/music/battle_theme.ogg","step_sfx":"grassStep"}
