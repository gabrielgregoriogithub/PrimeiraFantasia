class_name WinterHordeHill
extends RefCounted

## Mesmo recorte estrutural da Horda: 3 linhas de platô e 4 de paredão.
## Recorte das colunas originais 8..11 para as colunas 0..3 da Estrada.
## GIDs, colisão e escada consultam a fonte original, sem redesenhá-la.
const SOURCE_X := 8
const WIDTH := 4
const HEIGHT := 7
const TOP_ROWS := 3
const SNOW_PATH := "res://assets/tiles/estrada_inverno_neve1.png"

static func contains(x: int, y: int) -> bool:
	return x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT

static func base_gid(x: int, y: int) -> int:
	return LuaValleyLayout.gid(LuaValleyLayout.BASE_GIDS, SOURCE_X + x, y)

static func is_ladder(x: int, y: int) -> bool:
	return LuaValleyLayout.is_ladder_tile(SOURCE_X + x, y)

static func is_blocked(x: int, y: int) -> bool:
	return LuaValleyLayout.is_blocked(SOURCE_X + x, y) and not is_ladder(x, y)

static func ladder_tiles() -> Array:
	return LuaValleyLayout.LADDER_TILES.map(func(tile): return {"x":tile.x - SOURCE_X, "y":tile.y})
