class_name DungeonFloor2Layout
extends RefCounted

## Reforma pedida pelo usuário: mesma linguagem visual/mecânica de paredes e
## portas do 1º Andar (ver ScenarioManager._tower_definition — 4 portas,
## muralha externa), mas com MENOS paredes internas — duas salas grandes
## conectadas por uma parede central com 4 portas, em vez do labirinto de
## salas pequenas de antes. # parede, + porta, E entrada, X saída.
const GRID := [
	"#############",
	"#...........#",
	"#...........#",
	"#...........#",
	"#...........#",
	"#...........#",
	"##+#+...+#+##",
	"#...........#",
	"#...........#",
	"#...........#",
	"#...........#",
	"#E.........X#",
	"#############",
]

const ENTRANCE := {"x": 1, "y": 11}
const EXIT := {"x": 11, "y": 11}

## Cadáveres/ossos: só decoração (Tipo 1/2) ou com névoa venenosa por perto
## (Tipo 3 — ver POISON_GAS). Longe dos spawns de herói/inimigo de propósito
## (ver ScenarioManager._tower_floor_2_definition).
const CORPSE_DECORATIONS := [
	{"x": 2, "y": 3, "kind": "corpse-fallen-a"},
	{"x": 2, "y": 4, "kind": "corpse-mossy-poison"},
	{"x": 10, "y": 3, "kind": "corpse-bones-pile"},
	{"x": 10, "y": 4, "kind": "corpse-skulls-pile"},
	{"x": 3, "y": 10, "kind": "corpse-skeleton-a"},
	{"x": 9, "y": 10, "kind": "corpse-skeleton-hooded"},
	{"x": 8, "y": 3, "kind": "corpse-knight-armored"},
	{"x": 8, "y": 4, "kind": "corpse-mossy-poison"},
	{"x": 5, "y": 9, "kind": "corpse-skulls-pile"},
]

## Névoa venenosa: pequenas áreas (1-2 tiles) perto de corpos contaminados —
## nunca no ponto inicial de herói/inimigo. Hazard atravessável, aplica
## ENVENENADO (ver GameState._apply_tower_path_features).
const POISON_GAS := [
	{"x": 2, "y": 4},
	{"x": 8, "y": 4}, {"x": 9, "y": 4},
]

static func build() -> Dictionary:
	var walls: Array = []
	var doors: Array = []
	for y in GRID.size():
		var row: String = String(GRID[y])
		for x in row.length():
			var cell: String = row.substr(x, 1)
			if cell == "#": walls.append({"x": x, "y": y})
			elif cell == "+": doors.append({"x": x, "y": y})
	var decorations: Array = [
		{"x": int(ENTRANCE["x"]), "y": int(ENTRANCE["y"]), "kind": "entrance"},
		{"x": int(EXIT["x"]), "y": int(EXIT["y"]), "kind": "stairs"},
	]
	decorations.append_array(CORPSE_DECORATIONS)
	return {
		"walls": walls,
		"doors": doors,
		"pillars": [{"x": 3, "y": 3}, {"x": 9, "y": 3}, {"x": 3, "y": 9}, {"x": 9, "y": 9}],
		"torches": [{"x": 2, "y": 2}, {"x": 10, "y": 2}, {"x": 2, "y": 10}, {"x": 10, "y": 10}, {"x": 6, "y": 6}],
		"decorations": decorations,
		"poison_gas": POISON_GAS,
	}
