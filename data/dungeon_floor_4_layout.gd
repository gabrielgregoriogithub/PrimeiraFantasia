class_name DungeonFloor4Layout
extends RefCounted

## Evolução direta do 3º Andar: salões internos amplos, uma divisão
## arquitetônica curta com quatro portas e poças separadas. O bloco central
## de lava ocupa exatamente 4x4 tiles (colunas/linhas 5..8).
## # parede, + porta, L lava, E entrada, X saída.
const GRID := [
	"#############",
	"#E.........L#",
	"#..LL.......#",
	"#..LL.......#",
	"#+##+....+#+#",
	"#....LLLL...#",
	"#....LLLL...#",
	"#....LLLL...#",
	"#....LLLL...#",
	"#LL.........#",
	"#L......LL..#",
	"#.......LL.X#",
	"#############",
]

const ENTRANCE := {"x": 1, "y": 1}
const EXIT := {"x": 11, "y": 11}
const CENTRAL_LAVA_ORIGIN := {"x": 5, "y": 5}
const CENTRAL_LAVA_SIZE := 4

## Agrupamentos visuais junto às poças, preservando corredores e arenas.
const LAVA_DECORATIONS := [
	{"x": 4, "y": 5, "kind": "lava-boulders"},
	{"x": 9, "y": 5, "kind": "lava-volcano"},
	{"x": 4, "y": 8, "kind": "lava-crystal"},
	{"x": 9, "y": 8, "kind": "lava-smoke-vent"},
	{"x": 10, "y": 1, "kind": "lava-mound-a"},
	{"x": 5, "y": 2, "kind": "lava-burning-logs"},
	{"x": 3, "y": 10, "kind": "lava-mound-b"},
	{"x": 7, "y": 10, "kind": "lava-pedestal"},
]

static func build() -> Dictionary:
	var walls: Array = []
	var doors: Array = []
	var lava: Array = []
	for y in GRID.size():
		var row: String = String(GRID[y])
		for x in row.length():
			var cell := row.substr(x, 1)
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
		"pillars": [{"x": 2, "y": 5}, {"x": 10, "y": 5}, {"x": 2, "y": 8}, {"x": 10, "y": 8}],
		"torches": [{"x": 1, "y": 4}, {"x": 11, "y": 4}, {"x": 1, "y": 8}, {"x": 11, "y": 8}],
		"decorations": decorations,
	}
