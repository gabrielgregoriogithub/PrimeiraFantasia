class_name BoardLayout
extends RefCounted

## Porte literal do layout fixo do tabuleiro (game.js:4497-4830): posições de
## terreno/estrutura NUNCA são sorteadas — só a variante de arte (árvore/
## tenda) muda a cada resetGame(). Ver GameConstants para BOARD_SIZE e HPs.

const TERRAIN_LAYOUT := {
	"water": [
		{"x": 6, "y": 0}, {"x": 6, "y": 1}, {"x": 6, "y": 2},
		{"x": 7, "y": 2},
		{"x": 7, "y": 3}, {"x": 7, "y": 4},
		{"x": 6, "y": 5}, {"x": 7, "y": 5}, {"x": 8, "y": 5},
		{"x": 7, "y": 6},
		{"x": 6, "y": 6},
		{"x": 6, "y": 7}, {"x": 6, "y": 8},
		{"x": 5, "y": 9}, {"x": 6, "y": 9}, {"x": 7, "y": 9},
		{"x": 6, "y": 10},
		{"x": 6, "y": 11}, {"x": 6, "y": 12},
	],
	"tree": [
		{"x": 0, "y": 4}, {"x": 1, "y": 4}, {"x": 0, "y": 6},
		{"x": 0, "y": 9}, {"x": 1, "y": 9},
		{"x": 0, "y": 11}, {"x": 0, "y": 12}, {"x": 1, "y": 12},
		{"x": 12, "y": 4}, {"x": 11, "y": 4}, {"x": 12, "y": 6},
		{"x": 12, "y": 9}, {"x": 11, "y": 9},
		{"x": 12, "y": 11}, {"x": 12, "y": 12}, {"x": 11, "y": 12},
		{"x": 4, "y": 2}, {"x": 8, "y": 2},
		{"x": 4, "y": 10}, {"x": 8, "y": 10},
	],
	"house": [
		{"x": 9, "y": 1},
		{"x": 3, "y": 1},
	],
	"tent": [
		{"x": 4, "y": 6},
		{"x": 10, "y": 7},
	],
}

## Cachoeira: puramente estética, sobreposta ao 1º tile de água do rio — não
## é um `type` de terreno próprio, só decoração em cima do tile "water".
const WATERFALL_TILE := {"x": 6, "y": 0}

## Puramente decorativas: sem bloqueio, sem custo, sem popup de regra.
const FLOWER_LAYOUT := [
	{"x": 3, "y": 3, "art": "flower1.png"},
	{"x": 8, "y": 5, "art": "flower2.png"},
	{"x": 3, "y": 7, "art": "flower3.png"},
	{"x": 5, "y": 9, "art": "flower1.png"},
	{"x": 9, "y": 9, "art": "flower2.png"},
	{"x": 4, "y": 9, "art": "flower3.png"},
]

## Árvore/tenda: obstáculo total, ninguém atravessa nem "para" em cima.
## "porto-water"/"porto-pier"/"porto-blocked" são exclusivos do cenário PORTO
## (ver ScenarioManager._porto_definition()) — "porto-water" existe À PARTE
## de "water" de propósito: "water" comum é andável a custo dobrado
## (GameState.water_step_cost), mas o PORTO pede água 100% intransitável;
## criar um type novo em vez de reaproveitar "water" evita mudar esse
## comportamento pros demais cenários (Campo/Vila/Vale de Lua/Torre).
## "desfiladeiro-blocked" é o obstáculo avulso genérico do DESFILADEIRO
## (pedra grande/monólito — ver ScenarioManager._desfiladeiro_definition()).
## A ravina ("desfiladeiro-chasm") de propósito NÃO entra aqui: bloqueia só
## unidades terrestres, sobrevoável — ver a checagem exclusiva desse type em
## GameState.compute_reachable/_can_unit_anchor_at (mesma ideia de exceção
## `flying` já usada ali, não uma entrada nova nesta lista universal, que
## bloquearia voadores também).
## "estrada-inverno-cliff" é a parede do platô elevado da ESTRADA INVERNO
## (ver ScenarioManager._estrada_inverno_definition()) — type PRÓPRIO em vez
## de reaproveitar "lua-mountain" (que já tem seu próprio render em atlas
## específico do Vale de Lua, ver board_view.gd:_draw_lua_valley_board),
## mesmo padrão estrutural (parede sólida + único vão de acesso) mas sem
## qualquer risco de interferir no cenário existente.
const BLOCKING_TERRAIN_TYPES := ["scenery-wall", "scenery-prop", "tree", "tent", "tower-wall", "tower-pillar", "tower-bookshelf", "tower-vase", "lua-mountain", "village-building", "porto-water", "porto-pier", "porto-blocked", "desfiladeiro-blocked", "estrada-inverno-cliff", "estrada-inverno-blocked"]

const TREE_ART_VARIANTS := ["tree1.png", "tree2.png", "tree3.png", "tree4.png", "tree5.png"]
const TENT_ART_VARIANTS := ["tent1.png", "tent2.png"]

## Terreno "destrutível por tile" (HP próprio, ao contrário do HP
## compartilhado de STRUCTURES_LAYOUT do Castelo/Montanha).
static func destructible_tile_types() -> Dictionary:
	return {
		"tree": {"maxHp": GameConstants.TREE_MAX_HP, "ruinType": "stump", "label": "árvore"},
		"house": {"maxHp": GameConstants.HOUSE_MAX_HP, "ruinType": "house-rubble", "label": "casa"},
		"tent": {"maxHp": GameConstants.TENT_MAX_HP, "ruinType": "tent-rubble", "label": "tenda"},
		"tower-bookshelf": {"maxHp": 8, "ruinType": "tower-ashes", "label": "estante"},
		"tower-vase": {"maxHp": 5, "ruinType": "tower-pot-shards", "label": "barril"},
	}

## Subconjunto que também aceita ataque de ALVO ÚNICO (árvore só recebe dano
## em área, nunca mirada diretamente).
const SINGLE_TARGET_TERRAIN_TYPES := ["house", "tent", "tower-bookshelf", "tower-vase"]

## Castelo (heróis) e Montanha (inimigos): blocos 3x3 com 1 HP compartilhado
## pela estrutura inteira — não entram no terrainMap, ficam num array próprio.
const STRUCTURES_LAYOUT := [
	{
		"type": "castle", "team": "player",
		"tiles": [
			{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0},
			{"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1},
			{"x": 0, "y": 2}, {"x": 1, "y": 2}, {"x": 2, "y": 2},
		],
	},
	{
		"type": "mountain", "team": "enemy",
		"tiles": [
			{"x": 10, "y": 0}, {"x": 11, "y": 0}, {"x": 12, "y": 0},
			{"x": 10, "y": 1}, {"x": 11, "y": 1}, {"x": 12, "y": 1},
			{"x": 10, "y": 2}, {"x": 11, "y": 2}, {"x": 12, "y": 2},
		],
	},
]
