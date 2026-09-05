class_name DungeonFloor3Layout
extends RefCounted

## Reforma pedida pelo usuário: mesma linguagem visual/mecânica de paredes e
## portas do 1º Andar, com MENOS paredes internas (duas salas grandes
## conectadas por uma parede central com 4 portas — mesmo número de portas
## do 1º Andar) e a lava reorganizada em POÇAS independentes (nunca um rio
## atravessando o mapa): um bloco de 4 (LL/LL), uma cruz de 5 (.L./LLL/.L.),
## um bloco de 6 (LLL/LLL), uma poça irregular de 4 (.LL/LL.) e duas poças
## avulsas de 1 tile perto das paredes. # parede, + porta, L lava, E
## entrada, X saída.
const GRID := [
	"#############",
	"#E..........#",
	"#........L..#",
	"#.LL....L...#",
	"#.LL...LLL..#",
	"#.......L...#",
	"##+#+...+#+##",
	"#...........#",
	"#.LLL.......#",
	"#.LLL...LL..#",
	"#......LL.L.#",
	"#..........X#",
	"#############",
]

const ENTRANCE := {"x": 1, "y": 1}
const EXIT := {"x": 11, "y": 11}

## Props vulcânicos (props lava.png) agrupados perto das poças — nunca
## soltos aleatoriamente (ver GameState._setup_dungeon_floor/board_view).
const LAVA_DECORATIONS := [
	{"x": 1, "y": 4, "kind": "lava-boulders"},
	{"x": 4, "y": 3, "kind": "lava-volcano"},
	{"x": 6, "y": 4, "kind": "lava-crystal"},
	{"x": 10, "y": 4, "kind": "lava-mound-a"},
	{"x": 11, "y": 2, "kind": "lava-smoke-vent"},
	{"x": 1, "y": 9, "kind": "lava-mound-b"},
	{"x": 5, "y": 8, "kind": "lava-boulders"},
	{"x": 10, "y": 9, "kind": "lava-crystal"},
	{"x": 9, "y": 11, "kind": "lava-pedestal"},
	{"x": 6, "y": 7, "kind": "lava-burning-logs"},
]

static func build() -> Dictionary:
	var walls: Array = []
	var doors: Array = []
	var lava: Array = []
	for y in GRID.size():
		var row: String = String(GRID[y])
		for x in row.length():
			var cell: String = row.substr(x, 1)
			if cell == "#": walls.append({"x": x, "y": y})
			elif cell == "+": doors.append({"x": x, "y": y})
			elif cell == "L": lava.append({"x": x, "y": y})
	var decorations: Array = [
		{"x": int(ENTRANCE["x"]), "y": int(ENTRANCE["y"]), "kind": "entrance"},
		{"x": int(EXIT["x"]), "y": int(EXIT["y"]), "kind": "stairs"},
	]
	decorations.append_array(LAVA_DECORATIONS)
	return {
		"walls": walls,
		"doors": doors,
		"lava": lava,
		# Pedido do usuário: colunas removidas — atrapalhavam demais o
		# deslocamento nas salas de lava do 3º andar.
		"pillars": [],
		"torches": [{"x": 3, "y": 2}, {"x": 9, "y": 2}, {"x": 1, "y": 7}, {"x": 11, "y": 7}],
		"decorations": decorations,
	}
