class_name CemiterioLayout
extends RefCounted

## CEMITÉRIO: mapa vertical 17x24 montado só com os recortes de
## assets/props/cemiterio (ver ASSET_SOURCES.md). Composição, de baixo pra cima:
## portão de ferro na entrada -> caminho principal de pedras -> ilha da estátua
## memorial (o caminho abre em duas pistas laterais e volta a se juntar) ->
## praça do cemitério antigo, com cripta encaixada no muro do topo.
## Nada de templo, capela, altar, círculo ritual ou runas.
##
## Tudo é determinístico (seed fixa): o mapa é igual em toda partida.

const ID := "cemiterio"
const WIDTH := 17
const HEIGHT := 24
const SEED := 20260918

## Centro das polilinhas em CÉLULAS (x+0.5 = meio da célula), meia-largura em
## células. Largura mínima 2 casas (hw 1.0) nos ramais e 3 no caminho principal.
const PATHS := [
	{"pts": [Vector2(8.5, 23.8), Vector2(8.5, 19.0), Vector2(8.4, 15.2), Vector2(8.5, 14.0)], "hw": 1.5, "wobble": 0.2},
	# Duas pistas laterais ao redor da estátua central; voltam a se encontrar no alto.
	{"pts": [Vector2(8.5, 14.0), Vector2(5.9, 12.4), Vector2(5.3, 9.4), Vector2(7.1, 6.6)], "hw": 1.0, "wobble": 0.2},
	{"pts": [Vector2(8.5, 14.0), Vector2(11.1, 12.6), Vector2(11.8, 9.4), Vector2(10.0, 6.6)], "hw": 1.0, "wobble": 0.2},
	{"pts": [Vector2(7.1, 6.6), Vector2(8.5, 5.0), Vector2(10.0, 6.6)], "hw": 1.0, "wobble": 0.15},
	{"pts": [Vector2(8.5, 5.4), Vector2(8.5, 2.4)], "hw": 1.5, "wobble": 0.2},
	# Ramais curtos até as áreas de sepultamento (2 casas de largura).
	{"pts": [Vector2(7.2, 17.4), Vector2(3.6, 17.0)], "hw": 0.95, "wobble": 0.25},
	{"pts": [Vector2(9.8, 16.4), Vector2(13.6, 16.6)], "hw": 0.95, "wobble": 0.25},
	{"pts": [Vector2(5.6, 10.6), Vector2(2.4, 10.2)], "hw": 0.95, "wobble": 0.25},
	{"pts": [Vector2(11.4, 9.0), Vector2(14.4, 8.6)], "hw": 0.95, "wobble": 0.25},
]

const PLAYER_SPAWNS := [
	{"x": 6, "y": 19}, {"x": 8, "y": 19}, {"x": 10, "y": 19},
	{"x": 7, "y": 17}, {"x": 9, "y": 17}, {"x": 8, "y": 15},
]
## Cada slot inimigo tem 2x2 livres (o Troll/Dragão/Salamandra ocupam 4 casas) e
## nenhum footprint encosta em outro slot.
const ENEMY_SPAWNS := [
	{"x": 3, "y": 3}, {"x": 6, "y": 3}, {"x": 9, "y": 3}, {"x": 12, "y": 3}, {"x": 7, "y": 5},
]

static func catalog() -> Dictionary:
	var c := {}
	for kind in ["gravestone_1", "gravestone_2", "gravestone_3", "gravestone_4", "gravestone_5", "gravestone_ornate",
			"gravestone_arch", "gravestone_double", "gravestone_tall", "cross_1", "cross_2", "cross_celtic"]:
		c[kind] = HauntedScenery.entry(1, 1, "prop")
	c["gravestone_small"] = HauntedScenery.entry(1, 1, "", "y")
	c["raven_stone"] = HauntedScenery.entry(1, 1, "prop", "y", true)
	c["birdbath"] = HauntedScenery.entry(1, 1, "prop")
	c["bench"] = HauntedScenery.entry(2, 1, "prop")
	c["sarcophagus"] = HauntedScenery.entry(2, 1, "prop")
	c["statue_angel"] = HauntedScenery.entry(1, 1, "prop", "y", true)
	c["statue_hooded"] = HauntedScenery.entry(1, 1, "prop", "y", true)
	c["statue_mourning"] = HauntedScenery.entry(1, 1, "prop", "y", true)
	c["crypt_entrance"] = HauntedScenery.entry(3, 1, "wall", "y", true)
	c["gate_left"] = HauntedScenery.entry(2, 1, "wall", "y", true)
	c["gate_right"] = HauntedScenery.entry(2, 1, "wall", "y", true)
	c["fence_1"] = HauntedScenery.entry(2, 1, "wall", "y", true)
	c["fence_2"] = HauntedScenery.entry(2, 1, "wall", "y", true)
	c["wall_ruin_1"] = HauntedScenery.entry(2, 1, "wall", "y", true)
	c["wall_ruin_2"] = HauntedScenery.entry(2, 1, "wall", "y", true)
	c["thorn_bush_1"] = HauntedScenery.entry(2, 1, "prop")
	c["thorn_bush_2"] = HauntedScenery.entry(2, 1, "prop")
	c["thorn_bush_3"] = HauntedScenery.entry(1, 1, "prop")
	c["dead_tree_1"] = HauntedScenery.entry(1, 1, "prop", "y", true)
	c["dead_tree_3"] = HauntedScenery.entry(1, 1, "prop", "y", true)
	# Só visuais: sem colisão.
	for kind in ["rocks_1", "rocks_2", "lamp_post", "lantern", "lantern_hanging", "candle", "candles", "skull_rock"]:
		c[kind] = HauntedScenery.entry(1, 1, "", "y")
	for kind in ["bones", "skull", "skull_bones"]:
		c[kind] = HauntedScenery.entry(1, 1, "", "flat")
	c["coffin_open"] = HauntedScenery.entry(2, 1, "", "flat")
	c["coffin_closed"] = HauntedScenery.entry(2, 1, "", "flat")
	c["open_grave"] = HauntedScenery.entry(3, 2, "", "flat")
	c["leaves_branch"] = HauntedScenery.entry(3, 1, "", "flat")
	return c

static func definition() -> Dictionary:
	var s := HauntedScenery.new(WIDTH, HEIGHT, folder_name(), catalog(), SEED)
	var trail := HauntedScenery.trail_cells(WIDTH, HEIGHT, PATHS)
	s.keep_free(trail)
	s.keep_free_rect(3, 3, 11, 2)   # praça do cemitério antigo: 4 slots inimigos 2x2
	s.keep_free_rect(7, 5, 2, 2)    # 5º slot inimigo 2x2
	s.keep_free_rect(5, 15, 7, 6)   # clareira logo depois do portão (spawns dos heróis)
	_build_entrance(s)
	_build_top(s)
	_build_center(s)
	_build_west(s)
	_build_east(s)
	_build_borders(s)
	_build_details(s)
	return {
		"id": ID, "name": "CEMITÉRIO", "indoor": false,
		"board_width": WIDTH, "board_height": HEIGHT,
		"trail": trail, "scenery_props": s.props, "blocked_tiles": s.blocked_tiles(),
		"mist": _mist(), "decorations": [],
		"scenery_folder": folder_name(),
		"palette": {"grass": Color(0.50, 0.62, 0.58), "stone": Color(0.50, 0.55, 0.60), "gap": Color(0.14, 0.18, 0.19), "vignette": Color(0.005, 0.02, 0.035)},
		"player_spawns": PLAYER_SPAWNS, "enemy_spawns": ENEMY_SPAWNS,
		"music": "res://assets/third_party/shattered_pixel_dungeon/music/prison_1.ogg", "step_sfx": "grassStep",
	}

static func folder_name() -> String:
	return "cemiterio"

## Portão de ferro (2 metades com o vão do caminho no meio) e o muro que fecha o cemitério.
static func _build_entrance(s: HauntedScenery) -> void:
	s.place("gate_left", 5, 21)
	s.place("gate_right", 10, 21)
	s.place("wall_ruin_1", 3, 21)
	s.place("fence_2", 1, 21)
	s.place("thorn_bush_3", 0, 21)
	s.place("wall_ruin_2", 12, 21)
	s.place("fence_1", 14, 21)
	s.place("thorn_bush_3", 16, 21)
	s.place("lamp_post", 7, 22)
	s.place("lamp_post", 9, 22)
	# Fora do portão: espinheiros e pedras nas bordas, caminho livre no meio.
	s.place("thorn_bush_2", 1, 22)
	s.place("dead_tree_3", 3, 23)
	s.place("rocks_1", 5, 23)
	s.place("thorn_bush_1", 12, 22)
	s.place("rocks_2", 14, 23)
	s.place("thorn_bush_3", 16, 23)

## Cemitério antigo: túmulos maiores, cripta no muro, estátuas guardando o fim do caminho.
static func _build_top(s: HauntedScenery) -> void:
	s.place("crypt_entrance", 3, 1)
	s.place("wall_ruin_2", 1, 1)
	s.place("wall_ruin_1", 6, 1)
	s.place("fence_2", 8, 1)
	s.place("fence_1", 10, 1)
	s.place("wall_ruin_2", 12, 1)
	s.place("dead_tree_1", 15, 1)
	s.place("thorn_bush_3", 0, 1)
	s.place("statue_hooded", 5, 5)
	s.place("statue_angel", 11, 5)
	s.place("sarcophagus", 1, 4)
	s.place("sarcophagus", 13, 5)
	s.place("coffin_closed", 14, 3)
	s.place("gravestone_ornate", 2, 6)
	s.place("cross_celtic", 14, 7)
	s.place("bench", 4, 9)
	s.place("gravestone_double", 12, 7)
	s.place("thorn_bush_2", 0, 6)
	s.place("thorn_bush_1", 15, 9)

## Estátua memorial no centro, sem arena: uma ilha de grama entre as duas pistas.
static func _build_center(s: HauntedScenery) -> void:
	s.place("statue_mourning", 8, 10)
	s.place("rocks_2", 7, 9)
	s.place("rocks_1", 9, 11)
	s.place("candles", 7, 11)
	s.place("candle", 9, 9)
	s.place("thorn_bush_3", 7, 8)
	s.place("thorn_bush_3", 9, 8)

## Área de sepultamento oeste: fileiras de lápides, cruzes, sarcófago e um túmulo aberto.
static func _build_west(s: HauntedScenery) -> void:
	s.place("open_grave", 0, 12)
	s.place("bones", 3, 14)
	s.row(["gravestone_1", "gravestone_2", "cross_1", "gravestone_4", "gravestone_3"], 1, 15, 3, 2)
	s.row(["gravestone_5", "cross_2", "gravestone_arch", "gravestone_tall"], 1, 19, 2, 2)
	s.row(["gravestone_tall", "gravestone_1", "cross_1", "gravestone_2"], 1, 9, 2, 2)
	s.place("gravestone_ornate", 1, 17)
	s.place("cross_celtic", 4, 19)
	s.place("gravestone_small", 4, 15)
	s.place("sarcophagus", 2, 7)
	s.place("gravestone_double", 4, 12)
	s.place("dead_tree_3", 0, 14)
	s.place("thorn_bush_1", 2, 12)
	s.place("gravestone_arch", 0, 20)
	s.place("coffin_open", 1, 5)

## Área de sepultamento leste.
static func _build_east(s: HauntedScenery) -> void:
	s.row(["gravestone_2", "cross_celtic", "gravestone_4", "gravestone_1", "gravestone_5"], 11, 14, 3, 2)
	s.row(["gravestone_5", "gravestone_3", "cross_1", "gravestone_tall"], 12, 19, 2, 2)
	s.row(["gravestone_tall", "gravestone_arch", "gravestone_ornate"], 13, 11, 2, 2)
	s.place("sarcophagus", 12, 8)
	s.place("raven_stone", 15, 10)
	s.place("dead_tree_1", 14, 17)
	s.place("thorn_bush_2", 11, 18)
	s.place("gravestone_double", 15, 15)
	s.place("birdbath", 13, 7)
	s.place("coffin_open", 14, 12)
	s.place("gravestone_small", 12, 17)
	s.place("thorn_bush_3", 16, 13)
	s.place("gravestone_1", 15, 19)

## Muros e espinheiros nas laterais (borda que não bloqueia a área jogável).
static func _build_borders(s: HauntedScenery) -> void:
	for y in [3, 8, 13, 18]:
		s.place("fence_2", 0, y)
		s.place("fence_1", 15, y)
	s.place("wall_ruin_1", 0, 20)
	s.place("wall_ruin_2", 15, 20)
	s.scatter(["thorn_bush_3", "thorn_bush_1"], Rect2i(0, 2, 2, 19), 5)
	s.scatter(["thorn_bush_3", "thorn_bush_2"], Rect2i(15, 2, 2, 19), 5)
	s.scatter(["rocks_1", "rocks_2"], Rect2i(0, 2, 17, 20), 6)

## Detalhes: velas, lanternas, ossos e folhas (nenhum bloqueia).
static func _build_details(s: HauntedScenery) -> void:
	s.place("candles", 4, 12)
	s.place("candle", 2, 19)
	s.place("candles", 14, 18)
	s.place("candle", 12, 11)
	s.place("candle", 5, 4)
	s.place("candles", 11, 4)
	s.place("lantern", 5, 20)
	s.place("lantern", 11, 20)
	s.place("lantern_hanging", 4, 16)
	s.place("lantern_hanging", 12, 15)
	s.place("lantern", 7, 4)
	s.place("bones", 12, 13)
	s.place("skull_bones", 2, 14)
	s.place("skull", 15, 6)
	s.place("skull_rock", 4, 18)
	s.place("bones", 10, 14)
	s.scatter(["leaves_branch"], Rect2i(0, 3, 14, 18), 3)

## Manchas de névoa (em células) sobre o chão; o desenho é do renderer.
static func _mist() -> Array:
	return [
		{"x": 2.0, "y": 21.0, "w": 5.0, "h": 2.0, "art": "fog_2"}, {"x": 11.0, "y": 22.0, "w": 5.0, "h": 2.0, "art": "fog_2"},
		{"x": 0.5, "y": 11.0, "w": 3.0, "h": 2.0, "art": "fog_1"}, {"x": 13.5, "y": 6.0, "w": 3.0, "h": 2.0, "art": "fog_1"},
		{"x": 3.0, "y": 3.0, "w": 5.0, "h": 2.0, "art": "fog_2"}, {"x": 9.0, "y": 14.0, "w": 4.0, "h": 2.0, "art": "fog_1"},
		{"x": 5.0, "y": 16.0, "w": 4.0, "h": 2.0, "art": "fog_2"},
	]
