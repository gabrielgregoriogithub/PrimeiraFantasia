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
## Cenário independente (pedido do usuário) — vila portuária costeira usada
## só pra validar o mapa (ver ASSET_SOURCES.md "PORTO"). De propósito FORA de
## PHASE_ORDER: não entra no ciclo de progressão automática dos cenários
## existentes, só é alcançável setando active_id diretamente (ferramentas de
## QA/teste) ou por uma tela que o usuário decida adicionar depois.
const PORTO := "porto"
## Cenário independente (pedido do usuário) — desfiladeiro gelado com ravina
## central intransitável (só voadores atravessam fora da ponte) e evento
## periódico de vento gelado. Mesma regra de PORTO: fora de PHASE_ORDER.
const DESFILADEIRO := "desfiladeiro"
## Cenário independente (pedido do usuário) — trilha de inverno com rio
## (mesmo comportamento de água do Campo) e um platô elevado ao estilo da
## Horda (parede bloqueada + escada única de acesso). Fora de PHASE_ORDER,
## mesma regra dos outros dois acima.
const ESTRADA_INVERNO := "estrada_inverno"
## Cenários independentes (pedido do usuário) montados só com props recortados
## (ver HauntedScenery): mapas verticais maiores que 13x13, navegados pela mesma
## câmera de zoom/arrasto/barras. Fora de PHASE_ORDER, como os demais.
const TEMPLO := "templo"
const CEMITERIO := "cemiterio"
var active_id := VILLAGE

## Ordem de progressão de fase (mesma ordem visual dos botões do topo, pedido
## do usuário: VILA, FLORESTA, CAMPO, HORDA, TORRE, 2º ANDAR) — usada por main.gd pra
## avançar automaticamente de fase depois de uma vitória (ver
## _start_victory_phase_advance). Cíclica: vencer a última fase (Torre)
## volta pra Vila.
const PHASE_ORDER := [VILLAGE, FOREST, FIELD, LUA_VALLEY, TOWER, TOWER_FLOOR_2, TOWER_FLOOR_3, TOWER_FLOOR_4]

func set_active(id: String) -> void:
	if id not in [FIELD, TOWER, TOWER_FLOOR_2, TOWER_FLOOR_3, TOWER_FLOOR_4, LUA_VALLEY, VILLAGE, FOREST, PORTO, DESFILADEIRO, ESTRADA_INVERNO, TEMPLO, CEMITERIO] or id == active_id: return
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
	if id == PORTO: return _porto_definition()
	if id == DESFILADEIRO: return _desfiladeiro_definition()
	if id == ESTRADA_INVERNO: return _estrada_inverno_definition()
	if id == TEMPLO: return TemploLayout.definition()
	if id == CEMITERIO: return CemiterioLayout.definition()
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
		# Pedido do usuário: elenco do 3º Andar trocado pra 3 Fogo Vivo e 2 Lava
		# Humana, sem Dragão nem Demônio das Chamas — mesmas 5 posições já
		# curadas do andar, só as kinds mudaram.
		"enemy_roster": [
			{"kind":"living_fire","x":5,"y":2},
			{"kind":"living_fire","x":7,"y":5},
			{"kind":"living_fire","x":5,"y":3},
			{"kind":"lava_human","x":6,"y":4},
			{"kind":"lava_human","x":5,"y":9},
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

## Vila atacada recentemente — REFORMULAÇÃO COMPLETA (pedido do usuário,
## referência visual em C:\Users\gabri\Downloads\modo aventura 2d\vila\
## referencia.png): poço na praça central, moinho encostado no rio, celeiro
## e silo/torre d'água como estruturas secundárias, 4 casas queimadas/em
## ruína espalhadas pelas bordas (não simétricas), cais+barco na margem do
## rio, cercas/muros/destroços/caixas/barris preenchendo o entorno. A estrada
## de terra cruza o centro sem fechar corredores (mesma geração de antes),
## as construções ficam nas bordas. `blocked_tiles` soma a base física dos
## prédios (`buildings`) com os obstáculos avulsos (`obstacles` — cerca
## arrombada, barricada, ponte quebrada, poço, muro em ruína); os demais
## itens de `decorations` (fogo, destroços, props curados) são só visuais.
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
	# linha 12) — mantido da versão anterior, já batia com a referência
	# ("rio em uma das laterais").
	var water: Array = []
	for y in range(13):
		water.append({"x":11,"y":y})
		water.append({"x":12,"y":y})
	var buildings := [
		# 4 casas espalhadas pelas bordas, não simetricamente (pedido do
		# usuário) — 3 ainda pegando fogo, 1 já reduzida a ruína.
		{"x":0,"y":0,"w":3,"h":2,"kind":"village-house","damaged":true,"burning":true},
		{"x":8,"y":0,"w":2,"h":2,"kind":"village-house","damaged":true,"burning":true},
		{"x":0,"y":9,"w":3,"h":2,"kind":"village-house","damaged":true,"burning":true},
		{"x":9,"y":9,"w":2,"h":2,"kind":"village-house-ruin","damaged":true,"burning":false},
		# Moinho encostado no rio, região superior (pedido do usuário:
		# "moinho próximo ao rio").
		{"x":9,"y":2,"w":2,"h":3,"kind":"village-mill","damaged":true,"burning":false},
		# Celeiro numa região inferior/lateral (pedido do usuário) — agora
		# BLOQUEIA movimento de verdade (estrutura sólida), diferente da
		# versão anterior (só decorativo).
		{"x":3,"y":10,"w":3,"h":2,"kind":"village-barn","damaged":true,"burning":false},
		# Silo e torre d'água como "estruturas secundárias distribuídas de
		# maneira natural" (pedido do usuário), também bloqueando agora.
		{"x":5,"y":1,"w":1,"h":2,"kind":"village-silo","damaged":true,"burning":true},
		{"x":9,"y":6,"w":1,"h":2,"kind":"village-watertower","damaged":true,"burning":false},
	]
	var blocked: Array = []
	for building in buildings:
		for oy in int(building["h"]):
			for ox in int(building["w"]):
				var tile := {"x":int(building["x"])+ox,"y":int(building["y"])+oy}
				if not water.has(tile): blocked.append(tile)
	# Obstáculos avulsos: ao contrário dos demais props curados em
	# "decorations" (puramente visuais), estes têm a própria célula somada a
	# "blocked_tiles" logo abaixo — bloqueiam movimento de verdade, não só
	# decoram. Poço (praça central) e um trecho de muro em ruína entraram
	# aqui na reformulação — antes só cerca/barricada/ponte bloqueavam.
	var obstacles := [
		# Poço de pedra aproximadamente no centro da praça (pedido do usuário).
		{"x":6,"y":6,"kind":"village2-well"},
		# Barricada de madeira atravessada na estrada principal.
		{"x":7,"y":7,"kind":"village2-barricade"},
		# Trecho da cerca arrombado pelo ataque.
		{"x":4,"y":7,"kind":"village2-fence-broken"},
		# Trecho de muro de pedra em ruína, perto da casa incendiada a leste.
		{"x":7,"y":9,"kind":"village2-wall-ruin"},
	]
	for obstacle in obstacles:
		blocked.append({"x":obstacle["x"],"y":obstacle["y"]})
	return {
		"id":VILLAGE,"name":"VILA","indoor":false,
		"dirt":dirt,"water":water,"buildings":buildings,"blocked_tiles":blocked,
		"decorations":[
			# Cais quebrado + barco na margem do rio (pedido do usuário).
			{"x":10,"y":6,"kind":"village2-dock","decorative":true,"blocking":false},
			{"x":12,"y":7,"kind":"village2-boat","decorative":true,"blocking":false},
			# Reeds/vitórias-régias ao longo da margem, dando textura ao rio.
			{"x":10,"y":2,"kind":"village2-reeds-1","decorative":true,"blocking":false},
			{"x":10,"y":11,"kind":"village2-reeds-2","decorative":true,"blocking":false},
			{"x":11,"y":4,"kind":"village2-lilypad-1","decorative":true,"blocking":false},
			{"x":11,"y":8,"kind":"village2-lilypad-2","decorative":true,"blocking":false},
			# Carroça destruída perto do celeiro.
			{"x":1,"y":8,"kind":"village2-wagon","decorative":true,"blocking":false},
			# Caixas, barris, sacos e cesto espalhados perto de casas/celeiro/moinho.
			{"x":4,"y":9,"kind":"village2-crate-1","decorative":true,"blocking":false},
			{"x":2,"y":7,"kind":"village2-crate-2","decorative":true,"blocking":false},
			{"x":8,"y":8,"kind":"village2-crate-3","decorative":true,"blocking":false},
			{"x":9,"y":5,"kind":"village2-barrel-1","decorative":true,"blocking":false},
			{"x":3,"y":2,"kind":"village2-barrel-2","decorative":true,"blocking":false},
			{"x":6,"y":10,"kind":"village2-barrel-3","decorative":true,"blocking":false},
			{"x":2,"y":6,"kind":"village2-sacks","decorative":true,"blocking":false},
			{"x":4,"y":1,"kind":"village2-basket","decorative":true,"blocking":false},
			{"x":8,"y":9,"kind":"village2-jar","decorative":true,"blocking":false},
			# Cercas (inteiras e quebradas) ao redor do celeiro e da praça.
			{"x":2,"y":8,"kind":"village2-fence-1","decorative":true,"blocking":false},
			{"x":6,"y":11,"kind":"village2-fence-2","decorative":true,"blocking":false},
			{"x":6,"y":5,"kind":"village2-fence-3","decorative":true,"blocking":false},
			# Destroços/entulho perto das casas queimadas e do silo.
			{"x":2,"y":2,"kind":"village2-debris-ash","decorative":true,"blocking":false},
			{"x":10,"y":1,"kind":"village2-rubble-wall","decorative":true,"blocking":false},
			{"x":1,"y":11,"kind":"village2-rubble-rocks","decorative":true,"blocking":false},
			{"x":8,"y":10,"kind":"village2-campfire","decorative":true,"blocking":false},
			{"x":3,"y":7,"kind":"village2-stick-pile","decorative":true,"blocking":false},
			# Bandeira rasgada e poste com lanterna perto da praça.
			{"x":4,"y":5,"kind":"village2-banner","decorative":true,"blocking":false},
			{"x":7,"y":5,"kind":"village2-lamppost","decorative":true,"blocking":false},
			# Vasos/floreiras perto da casa que não está em chamas.
			{"x":10,"y":8,"kind":"village2-planter-1","decorative":true,"blocking":false},
			# Árvores verdes, mortas e troncos cortados espalhados (pedido do
			# usuário) — preenchem os cantos abertos sem fechar corredores.
			{"x":1,"y":4,"kind":"village2-tree-green-1","decorative":true,"blocking":false},
			{"x":3,"y":5,"kind":"village2-tree-green-2","decorative":true,"blocking":false},
			{"x":2,"y":12,"kind":"village2-tree-dead-1","decorative":true,"blocking":false},
			{"x":7,"y":2,"kind":"village2-tree-dead-2","decorative":true,"blocking":false},
			{"x":0,"y":6,"kind":"village2-stump-1","decorative":true,"blocking":false},
			{"x":9,"y":8,"kind":"village2-stump-2","decorative":true,"blocking":false},
			{"x":5,"y":4,"kind":"village2-bush","decorative":true,"blocking":false},
			{"x":0,"y":12,"kind":"village2-rock-1","decorative":true,"blocking":false},
			{"x":8,"y":6,"kind":"village2-rock-2","decorative":true,"blocking":false},
		] + obstacles,
		"player_spawns":[{"x":1,"y":6}],
		"enemy_spawns":[{"x":10,"y":8}],
		"archer_reinforcement":{"turn":4,"x":6,"y":2,"ct":80},
		"goblin_reinforcement":{"turn":6,"x":9,"y":8,"ct":80},
		"music":"res://assets/third_party/shattered_pixel_dungeon/music/prison_1.ogg","step_sfx":"grassStep",
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
		"music":"res://assets/third_party/shattered_pixel_dungeon/music/prison_1.ogg","step_sfx":"grassStep",
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
		"music":"res://assets/third_party/shattered_pixel_dungeon/music/prison_1.ogg","step_sfx":"grassStep"}

## Obstáculos avulsos de 1 casa (pedra, barril, poço...) do Desfiladeiro/
## Estrada Inverno — viram terreno com "prop": true, que unidades 2x2
## ignoram (ver BoardLayout.LARGE_UNIT_PASSABLE_TERRAIN_TYPES). Entradas com
## "w"/"h" são prédios de várias casas, fora da lista.
static func _prop_tiles(obstacles: Array) -> Array:
	var result: Array = []
	for obstacle in obstacles:
		if not obstacle.has("w"):
			result.append({"x":obstacle["x"],"y":obstacle["y"]})
	return result

## PORTO — vila portuária costeira (cenário independente, pedido do usuário,
## inspirado na composição de `cenario1.png`: casa grande + praça de pedra +
## fonte central + margem de água, SEM copiar pixel a pixel). Tabuleiro
## 13x13 padrão (mesmo BOARD_SIZE do Campo/Vila/Torre — câmera genérica de
## `board_view.gd` já assume esse tamanho por padrão, nenhuma câmera especial
## precisou ser criada).
##
## Regra central pedida pelo usuário: SÓ "grass" (implícito, ausência de
## entrada em terrain_map) e "porto-road" contam como `is_battleable()`
## (ver GameState.is_battleable) — todo o resto (casa, fonte, píer, cercas,
## barris/caixas, carroça, água) vira obstáculo físico via `blocked_tiles`,
## igual ao mecanismo já usado por `_village_definition()` pra prédios.
##
## Água: diferente de todo cenário existente (onde "water" é andável a custo
## dobrado, ver GameState.water_step_cost), o PORTO precisa de água 100%
## intransitável (pedido explícito do usuário). Em vez de mudar essa regra
## global, os tiles de água daqui usam o type NOVO "porto-water" (distinto de
## "water"), incluído em BoardLayout.BLOCKING_TERRAIN_TYPES — bloqueia total,
## sem alterar em nada o comportamento de "water" nos outros cenários.
static func _porto_definition() -> Dictionary:
	# Estrada de pedra: tronco vertical junto à casa + anel de praça ao redor
	# da fonte + ramal até o píer. Formato à mão (não fórmula), com nichos
	# assimétricos (4,5)/(7,4)/(10,6) pra fugir de um retângulo perfeito,
	# como pedido ("bordas levemente irregulares... pequenas expansões").
	var road := [
		{"x":5,"y":2},{"x":5,"y":3},{"x":5,"y":4},{"x":5,"y":5},{"x":4,"y":5},
		{"x":6,"y":5},{"x":7,"y":5},{"x":8,"y":5},{"x":9,"y":5},{"x":7,"y":4},
		{"x":6,"y":6},{"x":9,"y":6},{"x":10,"y":6},
		{"x":6,"y":7},{"x":9,"y":7},
		{"x":6,"y":8},{"x":7,"y":8},{"x":8,"y":8},{"x":9,"y":8},
		{"x":7,"y":9},
	]
	# Casa grande (landmark #1): recorte real da própria imagem de referência
	# do usuário (porto_house.png, telhado azul-esverdeado — ver
	# ASSET_SOURCES.md), desenhada por `_draw_porto_house()` (kind próprio
	# "porto-house", não passa mais por `_draw_village_building`/
	# village-house — aquele mecanismo continua intacto pra Vila/demais).
	var house := {"x":1,"y":1,"w":4,"h":3,"kind":"porto-house"}
	# Fonte/monumento (landmark #2), cercada por `road` nos 4 lados (ver lista
	# acima: linhas 5 e 8, colunas 6 e 9) — bloqueia como a casa, mas usa kind
	# próprio ("porto-fountain") desenhado por `_draw_porto_fountain` em
	# board_view.gd (base = fonte real do Kenney Fantasy Town, CC0; brilho
	# mágico no centro é procedural, ecoando o obelisco luminoso da
	# referência sem copiar o desenho exato).
	var fountain := {"x":7,"y":6,"w":2,"h":2,"kind":"porto-fountain"}
	# Píer: 3 tiles de madeira (não-battleable, ver regra central acima) na
	# ponta da estrada, bem onde o "gap" da água (linha 11, colunas 6-7)
	# deixa terra seca em vez de água — o barco fica ancorado 1 tile à frente
	# (na própria água, decoração pura, ver "decorations").
	var pier := [{"x":6,"y":11},{"x":7,"y":10},{"x":7,"y":11}]
	# Água: faixa inferior + trecho da borda esquerda subindo até perto da
	# casa + um bolsão isolado no canto superior esquerdo — borda costeira
	# irregular de propósito (pedido explícito: "não precisa formar um
	# retângulo perfeito"), com o "gap" nas colunas 6-7/linha 11 reservado
	# pro píer acima.
	var water := []
	for x in range(13): water.append({"x":x,"y":12})
	for x in [0,1,2,3,4,5,8,9,10,11,12]: water.append({"x":x,"y":11})
	water.append({"x":0,"y":10}); water.append({"x":1,"y":10})
	water.append({"x":0,"y":7}); water.append({"x":0,"y":8}); water.append({"x":0,"y":9})
	water.append({"x":0,"y":0}); water.append({"x":0,"y":1})
	# Obstáculos avulsos — recortes reais da imagem de referência do usuário
	# (porto_fence/barrel/crate.png, ver ASSET_SOURCES.md) no lugar dos kinds
	# genéricos da Vila/Torre, exceto o carrinho de mercador (porto-cart:
	# sem equivalente no novo recorte, mantém o asset 3D já existente). Mesma
	# técnica da Vila (`obstacles` sofre merge em `blocked_tiles` E em
	# `decorations`, ver fim da função): clusters lógicos perto da casa e
	# perto do píer, não espalhados pelo mapa (pedido explícito do usuário).
	var obstacles := [
		{"x":5,"y":1,"kind":"porto-fence"},
		{"x":3,"y":5,"kind":"porto-fence"},
		{"x":6,"y":4,"kind":"porto-fence"},
		{"x":4,"y":4,"kind":"porto-barrel"},
		{"x":3,"y":4,"kind":"porto-barrel"},
		{"x":2,"y":4,"kind":"porto-crate"},
		{"x":8,"y":10,"kind":"porto-barrel"},
		{"x":9,"y":10,"kind":"porto-crate"},
		{"x":5,"y":10,"kind":"porto-barrel-stack"},
		{"x":9,"y":9,"kind":"porto-cart"},
		# Cluster de mercado (landmark #3, pedido do usuário — banca +
		# toldo + poste de lanterna, canto direito da praça, ecoando a
		# referência) — puramente decorativo/obstáculo simples, sem regra
		# nova (mesmo mecanismo de "obstacles" acima).
		{"x":11,"y":4,"kind":"porto-market-stall"},
		{"x":11,"y":3,"kind":"porto-awning"},
		{"x":0,"y":3,"kind":"porto-lantern-post"},
		# Enriquecimento de decoração (pedido do usuário) — concentrado no
		# canto superior direito (segunda casa + luz + árvores + cluster de
		# caixa/saco perto da banca de mercado já existente), com reforço
		# moderado nas demais bordas (topo, esquerda, píer) pra não deixar a
		# composição desequilibrada. Nenhum destes tiles pisa em road/water/
		# pier/fountain/house/spawn/obstáculo já existente (ver conferência
		# tile a tile no pedido original).
		{"x":9,"y":1,"w":2,"h":2,"kind":"porto-house-2","decorative":false,"blocking":true},
		{"x":11,"y":1,"kind":"porto-tree"},
		{"x":12,"y":0,"kind":"porto-tree"},
		{"x":12,"y":2,"kind":"porto-tree"},
		{"x":12,"y":3,"kind":"porto-sacks"},
		{"x":12,"y":4,"kind":"porto-crate-2"},
		{"x":6,"y":1,"kind":"porto-lantern-post"},
		{"x":0,"y":2,"kind":"porto-tree"},
		{"x":1,"y":4,"kind":"porto-sacks"},
		{"x":8,"y":9,"kind":"porto-lamp"},
		{"x":11,"y":9,"kind":"porto-crate-2"},
		{"x":12,"y":6,"kind":"porto-tree"},
		{"x":12,"y":8,"kind":"porto-tree"},
	]
	var blocked: Array = []
	for oy in int(house["h"]):
		for ox in int(house["w"]):
			blocked.append({"x":int(house["x"])+ox,"y":int(house["y"])+oy})
	for oy in int(fountain["h"]):
		for ox in int(fountain["w"]):
			blocked.append({"x":int(fountain["x"])+ox,"y":int(fountain["y"])+oy})
	# Segunda casa (recorte `porto/casa.png`): ocupa uma área 2x2,
	# portanto os quatro quadrados ficam fisicamente bloqueados.
	var house_2 := {"x":9,"y":1,"w":2,"h":2}
	for oy in int(house_2["h"]):
		for ox in int(house_2["w"]):
			blocked.append({"x":int(house_2["x"])+ox,"y":int(house_2["y"])+oy})
	for tile in pier: blocked.append({"x":tile["x"],"y":tile["y"]})
	for obstacle in obstacles: blocked.append({"x":obstacle["x"],"y":obstacle["y"]})
	return {
		"id":PORTO,"name":"PORTO","indoor":false,
		"road":road,"water":water,"pier":pier,
		"buildings":[house],"fountain":fountain,"blocked_tiles":blocked,
		"decorations":[
			# Pedras musgosas de transição grama→água — recorte real da
			# referência (porto_mossy_rock.png), só paisagismo, não bloqueiam.
			{"x":2,"y":9,"kind":"porto-mossy-rock","decorative":true,"blocking":false},
			{"x":10,"y":9,"kind":"porto-mossy-rock","decorative":true,"blocking":false},
			# Barquinho ancorado na água, à frente do píer — recorte real da
			# referência (porto_boat.png), substitui o village-boat genérico.
			{"x":7,"y":12,"kind":"porto-boat","decorative":true,"blocking":false},
			# Vitória-régia na água — recorte real da referência, puramente
			# decorativa (os juncos da margem já são cobertos por
			# _draw_porto_board():shore_tufts, com posições próprias).
			{"x":0,"y":8,"kind":"porto-lilypad","decorative":true,"blocking":false},
			{"x":1,"y":10,"kind":"porto-lilypad","decorative":true,"blocking":false},
		] + obstacles,
		# Spawns mínimos só pra QA do mapa (pedido explícito: nada de
		# narrativa/encontro definitivo nesta etapa) — 1 herói genérico e 1
		# monstro genérico de Units.build(), ver GameState._setup_porto.
		"player_spawns":[{"x":2,"y":6}],
		"enemy_spawns":[{"x":10,"y":4}],
		"music":"res://assets/third_party/shattered_pixel_dungeon/music/prison_1.ogg","step_sfx":"grassStep",
	}

## DESFILADEIRO — cenário independente (pedido do usuário, inspirado em
## `cenario3.png`: desfiladeiro gelado com ravina central, ponte de pedra e
## monólitos/lápides — SEM copiar pixel a pixel). Tabuleiro 13x13 padrão,
## mesma câmera genérica de sempre.
##
## Estrutura: ravina/desfiladeiro vertical de 4 colunas (x=4..7, "largura de
## 4 quadrados" pedida na regra 8) atravessando o tabuleiro inteiro (y=0..12),
## MENOS uma única linha (y=5) onde fica a ponte de fato pisável — um
## retângulo lógico de 1x4 (espessura x comprimento). A linha logo abaixo
## (y=6), que antes também era ponte andável, virou ravina: pedido do
## usuário (regra 10) é que só a linha horizontal SUPERIOR da ponte (y=5,
## visualmente mais acima já que y cresce pra baixo) seja atravessável por
## unidades terrestres — a linha de baixo passa a valer como o resto da
## ravina, com a MESMA exceção de voo já existente (ver abaixo). Acima e
## abaixo da ponte, essas mesmas 4 colunas são vazio/ravina: intransitável
## pra unidades terrestres, sobrevoável por voadoras (ver GameState.
## compute_reachable/_can_unit_anchor_at, checagem exclusiva do type
## "desfiladeiro-chasm" — a mesma idéia de exceção `u.get("flying", false)`
## já usada ali pra cadáver/ocupante/estrutura, não uma mecânica de voo
## nova).
static func _desfiladeiro_definition() -> Dictionary:
	var chasm: Array = []
	var bridge: Array = []
	# Pedido do usuário: a ravina de 4 colunas não entra nas 3 primeiras
	# linhas (y=0..2, faixa de céu — ver `sky` abaixo) — o corredor só começa
	# em y=3, logo abaixo de onde as montanhas de fundo terminam.
	for x in range(4, 8):
		for y in range(3, 13):
			if y == 5:
				bridge.append({"x":x,"y":y})
			else:
				chasm.append({"x":x,"y":y})
	# Árvores nevadas (reaproveita o type "tree" já existente — HP/bloqueio/
	# destructible_tile_types de BoardLayout), alternando os 2 pinheiros
	# recortados da referência real do usuário (snow_pine_1/2.png, ver
	# assets/props/desfiladeiro/ASSET_SOURCES.md). Longe das bocas da ponte
	# (x=3/8, y=5/6) de propósito, pra não atrapalhar a aproximação, e fora
	# da faixa de céu (y<3, ver `sky` abaixo).
	var trees := [
		{"x":1,"y":3,"art":"snow_pine_1.png"},{"x":2,"y":3,"art":"snow_pine_2.png"},
		{"x":1,"y":9,"art":"snow_pine_1.png"},{"x":2,"y":11,"art":"snow_pine_2.png"},
		{"x":10,"y":3,"art":"snow_pine_1.png"},{"x":11,"y":10,"art":"snow_pine_2.png"},
		{"x":9,"y":4,"art":"snow_pine_1.png"},
		# Pedido do usuário: mais árvores, mesmos 2 pinheiros já usados acima.
		{"x":0,"y":4,"art":"snow_pine_2.png"},{"x":0,"y":9,"art":"snow_pine_1.png"},
		{"x":2,"y":10,"art":"snow_pine_2.png"},{"x":11,"y":3,"art":"snow_pine_2.png"},
		{"x":9,"y":11,"art":"snow_pine_1.png"},
	]
	# Obstáculos avulsos: pedra grande (desfiladeiro-rock-N), lápide/monólito
	# (desfiladeiro-monolith-N) e a rocha de cristal (desfiladeiro-crystal) —
	# todos bloqueiam igual (ver BoardLayout.BLOCKING_TERRAIN_TYPES), kind
	# próprio por instância pra usar os recortes reais da referência do
	# usuário em vez de repetir uma única arte. Mesma técnica de "obstacles"
	# da Vila/Porto: célula soma em blocked_tiles E em decorations.
	var obstacles := [
		{"x":0,"y":6,"kind":"desfiladeiro-rock-1"},
		{"x":3,"y":10,"kind":"desfiladeiro-rock-2"},
		{"x":9,"y":3,"kind":"desfiladeiro-rock-3"},
		{"x":12,"y":9,"kind":"desfiladeiro-rock-4"},
		{"x":1,"y":4,"kind":"desfiladeiro-monolith-1"},
		{"x":2,"y":7,"kind":"desfiladeiro-monolith-2"},
		{"x":10,"y":5,"kind":"desfiladeiro-monolith-3"},
		{"x":11,"y":8,"kind":"desfiladeiro-monolith-4"},
		{"x":12,"y":6,"kind":"desfiladeiro-crystal"},
	]
	# CÉU (pedido do usuário): as 3 primeiras linhas (y=0..2) não fazem parte
	# do tabuleiro pisável — só as montanhas ao fundo (desenhadas por
	# board_view.gd:_draw_desfiladeiro_board, `sky` só entra em blocked_tiles
	# aqui). Cobre a largura INTEIRA (nenhum vão nas colunas da ravina — pedido
	# do usuário: o corredor de 4 quadrados não deve existir nesta faixa, a
	# ravina só começa em y=3, ver `chasm`/`bridge` acima). Vira
	# "desfiladeiro-blocked" igual pedra/monólito (mesmo fallback de
	# GameState._setup_desfiladeiro), então bloqueia geral (inclusive
	# voadoras) — ninguém pisa nem sobrevoa o "fundo do cenário".
	var sky: Array = []
	for y in range(3):
		for x in range(13):
			sky.append({"x":x,"y":y})
	var blocked: Array = []
	for tree in trees: blocked.append({"x":tree["x"],"y":tree["y"]})
	for obstacle in obstacles: blocked.append({"x":obstacle["x"],"y":obstacle["y"]})
	for tile in sky: blocked.append({"x":tile["x"],"y":tile["y"]})
	return {
		"id":DESFILADEIRO,"name":"DESFILADEIRO","indoor":false,
		"chasm":chasm,"bridge":bridge,"trees":trees,"sky":sky,"blocked_tiles":blocked,"prop_tiles":_prop_tiles(obstacles),
		"decorations":[
			# Arbustos secos na neve, puramente decorativos (recortes reais da
			# referência do usuário) — não bloqueiam.
			{"x":0,"y":3,"kind":"desfiladeiro-bush-1","decorative":true,"blocking":false},
			{"x":3,"y":3,"kind":"desfiladeiro-bush-2","decorative":true,"blocking":false},
			{"x":9,"y":9,"kind":"desfiladeiro-bush-3","decorative":true,"blocking":false},
			{"x":12,"y":3,"kind":"desfiladeiro-bush-1","decorative":true,"blocking":false},
		] + obstacles,
		# Spawns mínimos só pra QA do mapa e do evento de vento (pedido
		# explícito: nada de encontro definitivo nesta etapa).
		"player_spawns":[{"x":1,"y":6}],
		"enemy_spawns":[{"x":11,"y":6}],
		"music":"res://assets/third_party/shattered_pixel_dungeon/music/prison_1.ogg","step_sfx":"grassStep",
	}

## ESTRADA INVERNO — cenário independente (pedido do usuário, inspirado em
## `cenario2.png`: trilha de terra clara cortando a neve, rio na borda
## superior e pedras espalhadas — SEM copiar pixel a pixel). Tabuleiro
## 13x13 padrão, mesma câmera de sempre.
##
## Água (regra 7/8 do pedido): usa o type genérico `"water"` — o MESMO já
## usado pelo Campo/Vila/Vale de Lua/Torre, sem type próprio nenhum. Isso
## herda automaticamente TODO o comportamento existente (GameState.
## water_step_cost: andável a custo dobrado; get_effective_hit_chance_
## breakdown: -10pp atacando de dentro d'água, +10pp acertando alvo atolado;
## imunidade a queimar) sem duplicar UMA linha de lógica — é literalmente a
## mesma água do Campo, só com posição/forma próprias. O visual reaproveita
## a MESMA função `_draw_river_bands()` que o Campo/Vale de Lua já usam
## (ver board_view.gd:_draw_estrada_inverno_river), só com pontos próprios.
##
## O morro/platô foi removido: o cenário inteiro agora é um único campo de
## neve contínuo, sem parede ou escada bloqueando a coluna direita.
static func _estrada_inverno_definition() -> Dictionary:
	var water: Array = []
	for x in range(9): water.append({"x":x,"y":0})
	for x in range(7): water.append({"x":x,"y":1})
	for x in range(3): water.append({"x":x,"y":2})
	var cliff: Array = []
	var stairs: Array = []
	# Trilha orgânica (bordas irregulares, sem linha reta) ligando a margem
	# do rio ao pé da escada do platô — mesma técnica de lista manual já
	# usada pela praça do PORTO, em vez de fórmula geométrica.
	# Estrada predominantemente diagonal, atravessando o mapa de uma ponta à
	# outra. Pequenas curvas e trechos horizontais quebram a rigidez sem criar
	# um zigue-zague acentuado.
	var trail := [
		{"x":0,"y":12},{"x":1,"y":11},{"x":2,"y":10},{"x":3,"y":9},
		{"x":4,"y":8},{"x":5,"y":8},{"x":6,"y":7},{"x":7,"y":6},
		{"x":8,"y":5},{"x":9,"y":4},{"x":10,"y":4},{"x":10,"y":3},
		{"x":11,"y":2},{"x":12,"y":1},{"x":12,"y":0},
	]
	# Árvores nevadas (reaproveita o obstáculo "tree" já existente). Recorte
	# real de árvore seca/nevada tirado pelo usuário da própria referência
	# (estrada_inverno_tree_1/2.png — ver ASSET_SOURCES.md), substituindo o
	# antigo substituto "snow_pine.png" (o recolor original de
	# "bare_snow_tree.png" saiu corrompido — ver histórico no ASSET_SOURCES.md).
	var trees := [
		{"x":0,"y":4,"art":"estrada_inverno_tree_1.png"},{"x":2,"y":3,"art":"estrada_inverno_tree_2.png"},
		{"x":4,"y":5,"art":"estrada_inverno_tree_1.png"},{"x":7,"y":3,"art":"estrada_inverno_tree_2.png"},
		{"x":8,"y":6,"art":"estrada_inverno_tree_1.png"},{"x":1,"y":8,"art":"estrada_inverno_tree_2.png"},
		{"x":4,"y":12,"art":"estrada_inverno_tree_1.png"},
		# Pedido do usuário: mais árvores, mesmos 2 recortes já usados acima.
		{"x":11,"y":7,"art":"estrada_inverno_tree_2.png"},{"x":12,"y":8,"art":"estrada_inverno_tree_1.png"},
		{"x":10,"y":11,"art":"estrada_inverno_tree_2.png"},{"x":0,"y":11,"art":"estrada_inverno_tree_1.png"},
		{"x":3,"y":4,"art":"estrada_inverno_tree_2.png"},
		# Enriquecimento de decoração (pedido do usuário): terceira variante de
		# árvore (estrada_inverno_tree_3.png, recorte novo da mesma referência).
		{"x":3,"y":2,"art":"estrada_inverno_tree_3.png"},{"x":6,"y":3,"art":"estrada_inverno_tree_3.png"},
		{"x":2,"y":9,"art":"estrada_inverno_tree_3.png"},
	]
	# Poço de pedra, pedras grandes e barris — recortes reais tirados pelo
	# usuário da própria referência (estrada_inverno_well/rock_N/barrel_N.png,
	# ver ASSET_SOURCES.md), kind próprio por instância em vez de reaproveitar
	# os kinds genéricos da Vila/Torre/Campo. Clusters lógicos perto da
	# trilha, não espalhados pelo mapa inteiro.
	var obstacles := [
		{"x":6,"y":6,"kind":"estrada-inverno-well"},
		{"x":3,"y":6,"kind":"estrada-inverno-rock-1"},
		{"x":6,"y":10,"kind":"estrada-inverno-rock-2"},
		{"x":4,"y":9,"kind":"estrada-inverno-barrel-1"},
		{"x":5,"y":11,"kind":"estrada-inverno-barrel-2"},
		# Enriquecimento de decoração (pedido do usuário) — troncos caídos,
		# toco nevado e pequenos agrupamentos de pedra/pebble na neve, mais
		# recortes reais da mesma referência do usuário, espalhados pelo mapa.
		{"x":1,"y":3,"kind":"estrada-inverno-stump"},
		{"x":7,"y":2,"kind":"estrada-inverno-log-1"},
		{"x":4,"y":3,"kind":"estrada-inverno-snow-bush-1"},
		{"x":7,"y":7,"kind":"estrada-inverno-snow-rocks-1"},
		{"x":2,"y":5,"kind":"estrada-inverno-snow-rocks-2"},
		{"x":8,"y":11,"kind":"estrada-inverno-log-2"},
		{"x":3,"y":8,"kind":"estrada-inverno-snow-bush-2"},
		{"x":0,"y":5,"kind":"estrada-inverno-snow-pebbles-2"},
		{"x":11,"y":10,"kind":"estrada-inverno-snow-pebbles-1"},
	]
	var blocked: Array = []
	for tile in cliff: blocked.append({"x":tile["x"],"y":tile["y"]})
	for tree in trees: blocked.append({"x":tree["x"],"y":tree["y"]})
	for obstacle in obstacles: blocked.append({"x":obstacle["x"],"y":obstacle["y"]})
	return {
		"id":ESTRADA_INVERNO,"name":"ESTRADA INVERNO","indoor":false,
		"water":water,"cliff":cliff,"stairs":stairs,"trail":trail,"trees":trees,
		"blocked_tiles":blocked,"prop_tiles":_prop_tiles(obstacles),
		"decorations":[
			# Pedrinhas soltas, puramente decorativas.
			{"x":5,"y":3,"kind":"estrada-inverno-rock-3","decorative":true,"blocking":false},
			{"x":1,"y":10,"kind":"estrada-inverno-rock-1","decorative":true,"blocking":false},
			{"x":8,"y":3,"kind":"estrada-inverno-rock-2","decorative":true,"blocking":false},
			# Ossada na neve (pedido do usuário, presente na imagem de
			# referência) — recorte real de caveira na neve
			# (estrada_inverno_skull.png), puramente decorativa.
			{"x":2,"y":6,"kind":"estrada-inverno-skull","decorative":true,"blocking":false},
		] + obstacles,
		# Spawns mínimos só pra QA do mapa (pedido explícito: nada de encontro
		# definitivo nesta etapa).
		"player_spawns":[{"x":2,"y":10}],
		"enemy_spawns":[{"x":11,"y":4}],
		"music":"res://assets/third_party/shattered_pixel_dungeon/music/prison_1.ogg","step_sfx":"grassStep",
	}
