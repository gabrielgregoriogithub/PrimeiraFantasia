class_name HauntedScenery
extends RefCounted

## Montador dos cenários TEMPLO e CEMITÉRIO (assets/props/templo|cemiterio).
##
## Um cenário é uma lista de props posicionados em CÉLULAS do grid (o mesmo
## grid/TILE_SIZE dos demais mapas), mais os caminhos de pedra e as regiões
## livres. Cada prop declara o footprint que ocupa (fw x fh células, ancoradas
## em x,y = canto superior esquerdo), se é sólido e em qual camada é
## desenhado:
##
## - solid "wall": bloqueia todo mundo (muros, portões, cripta, ruínas).
## - solid "prop": bloqueia todas as unidades, inclusive as de 4 casas
##   (mesma regra das árvores).
## - solid "": só visual (velas, ossos, arbustos, folhas, pedras pequenas...).
## - layer "y": nó ordenado por Y (personagem passa na frente/atrás).
## - layer "flat": decalque no chão, desenhado dentro do BoardView (fica
##   SEMPRE abaixo de personagens e dos destaques de movimento/ataque).
##
## O sprite fica centrado no footprint com a base do desenho alinhada à borda
## inferior dele; a colisão são exatamente as células do footprint.

const TERRAIN_WALL := "scenery-wall"
const TERRAIN_PROP := "scenery-prop"

var width: int
var height: int
var folder: String
var catalog: Dictionary
var rng := RandomNumberGenerator.new()
var props: Array = []
var _solid: Dictionary = {}
var _free: Dictionary = {}

func _init(p_width: int, p_height: int, p_folder: String, p_catalog: Dictionary, p_seed: int) -> void:
	width = p_width
	height = p_height
	folder = p_folder
	catalog = p_catalog
	rng.seed = p_seed

## fw x fh células, sólido, camada e se o sprite fica translúcido quando alguém
## está atrás dele (árvores, estátuas, muros altos).
static func entry(fw: int, fh: int, solid: String = "", layer: String = "y", fade: bool = false) -> Dictionary:
	return {"fw": fw, "fh": fh, "solid": solid, "layer": layer, "fade": fade}

static func key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func art_path(kind: String) -> String:
	return "res://assets/props/%s/%s_%s.png" % [folder, folder, kind]

## Células onde NENHUM sólido pode ser colocado (caminhos, clareiras, spawns).
func keep_free(cells: Array) -> void:
	for cell in cells:
		_free[key(int(cell["x"]), int(cell["y"]))] = true

func keep_free_rect(x: int, y: int, w: int, h: int) -> void:
	for cy in range(y, y + h):
		for cx in range(x, x + w):
			_free[key(cx, cy)] = true

func is_free_cell(x: int, y: int) -> bool:
	return _free.has(key(x, y))

func footprint_cells(kind: String, x: int, y: int) -> Array:
	var spec: Dictionary = catalog[kind]
	var cells: Array = []
	for cy in range(y, y + int(spec["fh"])):
		for cx in range(x, x + int(spec["fw"])):
			cells.append({"x": cx, "y": cy})
	return cells

func can_place(kind: String, x: int, y: int) -> bool:
	if not catalog.has(kind):
		return false
	for cell in footprint_cells(kind, x, y):
		var cx := int(cell["x"])
		var cy := int(cell["y"])
		if cx < 0 or cy < 0 or cx >= width or cy >= height:
			return false
		if _solid.has(key(cx, cy)):
			return false
		if String(catalog[kind]["solid"]) != "" and _free.has(key(cx, cy)):
			return false
	return true

func place(kind: String, x: int, y: int, options: Dictionary = {}) -> bool:
	if not can_place(kind, x, y):
		return false
	var spec: Dictionary = catalog[kind]
	var solid := String(spec["solid"])
	if solid != "":
		for cell in footprint_cells(kind, x, y):
			_solid[key(int(cell["x"]), int(cell["y"]))] = solid
	var prop := {
		"kind": kind, "art": art_path(kind), "x": x, "y": y,
		"fw": int(spec["fw"]), "fh": int(spec["fh"]), "solid": solid,
		"layer": String(options.get("layer", spec["layer"])), "fade": bool(spec["fade"]),
		"flip": bool(options.get("flip", rng.randf() < 0.5)),
	}
	for extra in ["scale", "alpha"]:
		if options.has(extra):
			prop[extra] = options[extra]
	props.append(prop)
	return true

## Tenta `count` posições aleatórias dentro de `rect` (em células) com kinds
## sorteados da lista; devolve quantos foram de fato colocados.
func scatter(kinds: Array, rect: Rect2i, count: int, options: Dictionary = {}) -> int:
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 40:
		attempts += 1
		var kind: String = kinds[rng.randi() % kinds.size()]
		var x := rect.position.x + rng.randi() % maxi(1, rect.size.x)
		var y := rect.position.y + rng.randi() % maxi(1, rect.size.y)
		if place(kind, x, y, options):
			placed += 1
	return placed

## Fileira de `count` props em (x,y) avançando (step_x, step_y), sorteando o
## kind de `kinds`; posições ocupadas/proibidas são simplesmente puladas.
func row(kinds: Array, x: int, y: int, count: int, step_x: int, step_y: int = 0) -> int:
	var placed := 0
	for i in count:
		var kind: String = kinds[rng.randi() % kinds.size()]
		if place(kind, x + step_x * i, y + step_y * i):
			placed += 1
	return placed

func blocked_tiles() -> Array:
	var tiles: Array = []
	for cell_key in _solid.keys():
		var parts: PackedStringArray = String(cell_key).split(",")
		tiles.append({"x": int(parts[0]), "y": int(parts[1]), "type": TERRAIN_WALL if _solid[cell_key] == "wall" else TERRAIN_PROP})
	tiles.sort_custom(func(a, b): return int(a["y"]) * 1000 + int(a["x"]) < int(b["y"]) * 1000 + int(b["x"]))
	return tiles

## Células (x,y) cobertas por polilinhas de caminho: cada uma é
## {"pts": [Vector2(centro em células)...], "hw": meia-largura em células,
## "wobble": irregularidade da borda}. Determinístico (sem RNG global).
static func trail_cells(w: int, h: int, paths: Array) -> Array:
	var cells := {}
	for path in paths:
		var pts: Array = path["pts"]
		var half_width: float = path["hw"]
		var wobble: float = path.get("wobble", 0.35)
		for cy in h:
			for cx in w:
				var center := Vector2(cx + 0.5, cy + 0.5)
				var nearest := 1e9
				for i in range(pts.size() - 1):
					nearest = minf(nearest, _distance_to_segment(center, pts[i], pts[i + 1]))
				var noise := fposmod(sin(float(cx) * 12.9898 + float(cy) * 78.233) * 43758.5453, 1.0)
				if nearest <= half_width + (noise - 0.5) * 2.0 * wobble:
					cells[key(cx, cy)] = {"x": cx, "y": cy}
	var result: Array = cells.values()
	result.sort_custom(func(a, b): return int(a["y"]) * 1000 + int(a["x"]) < int(b["y"]) * 1000 + int(b["x"]))
	return result

static func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq == 0.0:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)
