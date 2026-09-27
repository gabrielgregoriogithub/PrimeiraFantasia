class_name SceneryVisuals
extends RefCounted

## Apresentação dos cenários TEMPLO e CEMITÉRIO (ver HauntedScenery): só lê a
## definição e cria nós, nunca decide regra nenhuma.
##
## - Ground: nó filho de BoardView com z_index -1, ou seja, desenhado ANTES do
##   _draw do próprio tabuleiro (destaques de movimento/ataque e grade ficam
##   por cima). Como nunca chama queue_redraw, o Godot mantém os comandos de
##   desenho em cache: as centenas de pedras do caminho não são recalculadas a
##   cada frame (BoardView redesenha todo frame).
## - Prop: sprite ordenado por Y (z_index = linha dos pés). Personagem abaixo
##   do objeto aparece na frente, acima aparece atrás; se estiver atrás de um
##   prop alto, ele fica translúcido (mesma ideia das árvores do Campo).
## - Light / Mist: efeitos aditivos e névoa à deriva; nenhum tem colisão.

const TILE := BoardView.TILE_SIZE

## kind -> [deslocamento X, altura acima dos pés, raio, cor, velocidade do pulso]
const LIGHTS := {
	"candle": [0.0, 66.0, 74.0, Color(1.0, 0.66, 0.26, 0.55), 5.0],
	"candles": [0.0, 62.0, 92.0, Color(1.0, 0.66, 0.26, 0.55), 4.2],
	"lantern": [0.0, 62.0, 96.0, Color(1.0, 0.68, 0.28, 0.6), 2.6],
	"lantern_hanging": [-15.0, 52.0, 88.0, Color(1.0, 0.68, 0.28, 0.6), 2.4],
	"lamp_post": [-26.0, 112.0, 100.0, Color(1.0, 0.68, 0.28, 0.6), 2.2],
	"dead_tree_3": [92.0, 232.0, 66.0, Color(1.0, 0.68, 0.28, 0.5), 2.8],
	"rune_tree": [0.0, 92.0, 104.0, Color(0.3, 0.92, 1.0, 0.5), 1.2],
	"ritual_ring": [0.0, 120.0, 190.0, Color(0.3, 0.92, 1.0, 0.30), 0.9],
}

static var _glow_texture: GradientTexture2D
static var _texture_cache: Dictionary = {}
## Tokens vivos do tabuleiro, atualizados 10x/s pelo Ground (os props com fade
## consultam esta lista curta em vez de varrer todos os filhos do BoardView).
static var live_tokens: Array = []

static func _tex(path: String) -> Texture2D:
	if not _texture_cache.has(path):
		_texture_cache[path] = load(path)
	return _texture_cache[path]

static func glow_texture() -> GradientTexture2D:
	if _glow_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		_glow_texture = GradientTexture2D.new()
		_glow_texture.gradient = gradient
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(0.5, 0.5)
		_glow_texture.fill_to = Vector2(1.0, 0.5)
		_glow_texture.width = 128
		_glow_texture.height = 128
	return _glow_texture

## Cria todos os nós do cenário como filhos de `board` e devolve a lista (pra
## BoardView liberar na troca de cenário).
static func build(board: Node2D, definition: Dictionary) -> Array:
	var nodes: Array = []
	var ground := Ground.new()
	board.add_child(ground)
	ground.configure(definition)
	nodes.append(ground)
	for prop in definition.get("scenery_props", []):
		var is_sorted := String(prop.get("layer", "y")) == "y"
		var feet := Vector2((float(prop["x"]) + float(prop["fw"]) * 0.5) * TILE, (float(prop["y"]) + float(prop["fh"])) * TILE - 6.0)
		var light_z := 2
		if is_sorted:
			var texture: Texture2D = _tex(String(prop["art"]))
			if texture == null:
				continue
			var visual := Prop.new()
			board.add_child(visual)
			visual.configure(texture, prop)
			nodes.append(visual)
			light_z = visual.z_index + 1
		# Decalques (plataforma ritual) também brilham, mas por baixo dos personagens.
		var kind := String(prop["kind"])
		if LIGHTS.has(kind):
			var light := Light.new()
			board.add_child(light)
			light.configure(kind, feet, light_z, float(prop["x"] * 7 + prop["y"] * 13), float(prop.get("scale", 1.0)))
			nodes.append(light)
	for patch in definition.get("mist", []):
		var mist := Mist.new()
		board.add_child(mist)
		mist.configure(patch, String(definition.get("scenery_folder", "")))
		nodes.append(mist)
	return nodes

## Chão: grama escurecida, manchas, caminho de pedras, decalques (ossos, covas,
## caixões, folhas) e vinheta nas bordas.
class Ground extends Node2D:
	var definition: Dictionary

	var _token_clock := 0.0

	func configure(p_definition: Dictionary) -> void:
		definition = p_definition
		z_index = -1
		queue_redraw()

	func _process(delta: float) -> void:
		_token_clock += delta
		if _token_clock < 0.10:
			return
		_token_clock = 0.0
		SceneryVisuals.live_tokens = get_parent().get_children().filter(func(child): return child is UnitToken)

	func _noise(x: int, y: int, salt: int = 0) -> float:
		return fposmod(sin(float(x) * 12.9898 + float(y) * 78.233 + float(salt) * 37.719) * 43758.5453, 1.0)

	func _draw() -> void:
		var width := int(definition["board_width"])
		var height := int(definition["board_height"])
		var grass := SceneryVisuals._tex(BoardView.GRASS_TEXTURE)
		var palette: Dictionary = definition.get("palette", {})
		var grass_tint: Color = palette.get("grass", Color(0.62, 0.74, 0.66))
		for y in height:
			for x in width:
				var rect := Rect2(Vector2(x, y) * TILE, Vector2(TILE, TILE))
				draw_texture_rect(grass, rect, false, grass_tint)
				var shade := _noise(x, y)
				if shade > 0.55:
					draw_rect(rect, Color(0.02, 0.06, 0.08, (shade - 0.55) * 0.30))
		_draw_trail(palette)
		_draw_flat_props()
		_draw_vignette(width, height, palette)

	func _draw_trail(palette: Dictionary) -> void:
		var cells: Dictionary = {}
		for cell in definition.get("trail", []):
			cells["%d,%d" % [cell["x"], cell["y"]]] = true
		var stone_color: Color = palette.get("stone", Color(0.53, 0.58, 0.63))
		var gap_color: Color = palette.get("gap", Color(0.17, 0.21, 0.22))
		# Base contínua entre células vizinhas; só recua nas bordas que dão pra grama.
		for cell in definition.get("trail", []):
			var cx := int(cell["x"])
			var cy := int(cell["y"])
			var left := 0.0 if cells.has("%d,%d" % [cx - 1, cy]) else 7.0
			var right := 0.0 if cells.has("%d,%d" % [cx + 1, cy]) else 7.0
			var top := 0.0 if cells.has("%d,%d" % [cx, cy - 1]) else 7.0
			var bottom := 0.0 if cells.has("%d,%d" % [cx, cy + 1]) else 7.0
			var origin := Vector2(cx, cy) * TILE
			draw_rect(Rect2(origin + Vector2(left, top), Vector2(TILE - left - right, TILE - top - bottom)), gap_color)
		# Paralelepípedos grandes (2 por linha, 3 linhas por célula), linhas alternadas.
		for cell in definition.get("trail", []):
			var cx := int(cell["x"])
			var cy := int(cell["y"])
			var has_left := cells.has("%d,%d" % [cx - 1, cy])
			var has_right := cells.has("%d,%d" % [cx + 1, cy])
			var origin := Vector2(cx, cy) * TILE
			for row in 3:
				var xs: Array = [24.0, 72.0]
				if row % 2 == 1:
					xs = [0.0 if has_left else 22.0, 48.0, 96.0 if has_right else 76.0]
					if has_left or has_right:
						xs = [0.0 if has_left else 22.0, 48.0]
				for col in xs.size():
					var salt := row * 3 + col
					var jitter := Vector2(_noise(cx, cy, salt) - 0.5, _noise(cx, cy, salt + 20) - 0.5) * 6.0
					var center := origin + Vector2(float(xs[col]), 16.0 + row * 32.0) + jitter
					var radius := Vector2(19.0 + _noise(cx, cy, salt + 40) * 4.0, 13.0 + _noise(cx, cy, salt + 60) * 3.0)
					_draw_stone(center, radius, stone_color, cx * 31 + cy * 17 + salt)

	func _draw_stone(center: Vector2, radius: Vector2, base: Color, seed_value: int) -> void:
		var tone := 0.9 + fposmod(sin(float(seed_value) * 4.371) * 9137.13, 1.0) * 0.22
		var fill := Color(base.r * tone, base.g * tone, base.b * tone)
		var points := PackedVector2Array()
		for i in 10:
			var angle := TAU * float(i) / 10.0
			var wobble := 0.86 + fposmod(sin(float(seed_value * 10 + i) * 2.917) * 4583.7, 1.0) * 0.24
			points.append(center + Vector2(cos(angle) * radius.x * wobble, sin(angle) * radius.y * wobble))
		draw_colored_polygon(points, fill)
		draw_colored_polygon(PackedVector2Array([points[6], points[7], points[8], points[9], points[0]]), fill.lightened(0.10))
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, Color(0.06, 0.08, 0.10, 0.92), 2.0, true)
		if tone > 1.05:
			draw_circle(center + Vector2(-radius.x * 0.2, radius.y * 0.35), 3.2, Color(0.30, 0.46, 0.22, 0.55))

	func _draw_flat_props() -> void:
		var flats: Array = []
		for prop in definition.get("scenery_props", []):
			if String(prop.get("layer", "y")) == "flat":
				flats.append(prop)
		flats.sort_custom(func(a, b): return int(a["y"]) < int(b["y"]))
		for prop in flats:
			var texture: Texture2D = SceneryVisuals._tex(String(prop["art"]))
			if texture == null:
				continue
			var size: Vector2 = texture.get_size() * float(prop.get("scale", 1.0))
			var feet :=Vector2((float(prop["x"]) + float(prop["fw"]) * 0.5) * TILE, (float(prop["y"]) + float(prop["fh"])) * TILE - 6.0)
			var flip: float = -1.0 if bool(prop.get("flip", false)) else 1.0
			draw_set_transform(feet, 0.0, Vector2(flip, 1.0))
			draw_texture_rect(texture, Rect2(Vector2(-size.x * 0.5, -size.y), size), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_vignette(width: int, height: int, palette: Dictionary) -> void:
		var dark: Color = palette.get("vignette", Color(0.01, 0.03, 0.05))
		var depth := float(TILE) * 2.2
		var board := Vector2(width, height) * TILE
		var clear := Color(dark, 0.0)
		var solid := Color(dark, 0.78)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(board.x, 0), Vector2(board.x, depth), Vector2(0, depth)]), PackedColorArray([solid, solid, clear, clear]))
		draw_polygon(PackedVector2Array([Vector2(0, board.y - depth), Vector2(board.x, board.y - depth), Vector2(board.x, board.y), Vector2(0, board.y)]), PackedColorArray([clear, clear, solid, solid]))
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(depth, 0), Vector2(depth, board.y), Vector2(0, board.y)]), PackedColorArray([solid, clear, clear, solid]))
		draw_polygon(PackedVector2Array([Vector2(board.x - depth, 0), Vector2(board.x, 0), Vector2(board.x, board.y), Vector2(board.x - depth, board.y)]), PackedColorArray([clear, solid, solid, clear]))

## Sprite ordenado por Y. Origem = base do desenho (centro inferior).
class Prop extends Node2D:
	var texture: Texture2D
	var visual_size := Vector2.ZERO
	var flip := false
	var fade := false
	var base_alpha := 1.0
	var _clock := 0.1

	func configure(p_texture: Texture2D, prop: Dictionary) -> void:
		texture = p_texture
		visual_size = texture.get_size() * float(prop.get("scale", 1.0))
		flip = bool(prop.get("flip", false))
		fade = bool(prop.get("fade", false))
		position = Vector2((float(prop["x"]) + float(prop["fw"]) * 0.5) * TILE, (float(prop["y"]) + float(prop["fh"])) * TILE - 6.0)
		z_index = roundi(position.y)
		set_process(fade)
		queue_redraw()

	func _process(delta: float) -> void:
		_clock += delta
		if _clock < 0.10:
			return
		_clock = 0.0
		var hidden := false
		for child in SceneryVisuals.live_tokens:
			if is_instance_valid(child) and child.unit.get("hp", 0) > 0:
				var local: Vector2 = child.position - position
				if absf(local.x) < visual_size.x * 0.42 and local.y < 0.0 and local.y > -visual_size.y * 1.05:
					hidden = true
					break
		base_alpha = lerpf(base_alpha, 0.62 if hidden else 1.0, 0.55)
		modulate.a = base_alpha

	func _draw() -> void:
		var points := PackedVector2Array()
		var radius := Vector2(minf(visual_size.x * 0.34, 62.0), minf(maxf(visual_size.y * 0.07, 5.0), 11.0))
		for i in 20:
			var angle := TAU * float(i) / 20.0
			points.append(Vector2(cos(angle) * radius.x, sin(angle) * radius.y - 1.0))
		draw_colored_polygon(points, Color(0.02, 0.03, 0.04, 0.34))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
		draw_texture_rect(texture, Rect2(Vector2(-visual_size.x * 0.5, -visual_size.y), visual_size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Brilho aditivo com pulso (velas, lanternas, runas). Puramente visual.
class Light extends Node2D:
	var radius := 80.0
	var tint := Color.WHITE
	var pulse_speed := 3.0
	var phase := 0.0

	func configure(kind: String, feet: Vector2, z_value: int, p_phase: float, prop_scale: float = 1.0) -> void:
		var spec: Array = SceneryVisuals.LIGHTS[kind]
		position = feet + Vector2(float(spec[0]), -float(spec[1])) * prop_scale
		radius = float(spec[2]) * prop_scale
		tint = spec[3]
		pulse_speed = float(spec[4])
		phase = p_phase
		z_index = z_value
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var blend := CanvasItemMaterial.new()
		blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = blend

	func _process(_delta: float) -> void:
		var t := Time.get_ticks_msec() * 0.001
		var flicker := 0.82 + 0.18 * sin(t * pulse_speed + phase) * sin(t * pulse_speed * 2.3 + phase * 0.7)
		modulate = Color(1, 1, 1, flicker)
		queue_redraw()

	func _draw() -> void:
		draw_texture_rect(SceneryVisuals.glow_texture(), Rect2(Vector2(-radius, -radius), Vector2(radius, radius) * 2.0), false, tint)

## Névoa à deriva: usa a arte de névoa da pasta quando existe (Cemitério), senão
## um borrão radial procedural translúcido (Templo).
class Mist extends Node2D:
	var texture: Texture2D
	var size_px := Vector2(300, 120)
	var origin := Vector2.ZERO
	var base_alpha := 0.3
	var drift := 36.0
	var phase := 0.0
	var tint := Color.WHITE

	func configure(patch: Dictionary, folder: String) -> void:
		var art := String(patch.get("art", ""))
		if art != "" and folder != "":
			texture = SceneryVisuals._tex("res://assets/props/%s/%s_%s.png" % [folder, folder, art])
		if texture == null:
			texture = SceneryVisuals.glow_texture()
		size_px = Vector2(float(patch["w"]), float(patch["h"])) * TILE
		origin = (Vector2(float(patch["x"]), float(patch["y"])) + Vector2(float(patch["w"]), float(patch["h"])) * 0.5) * TILE
		base_alpha = float(patch.get("alpha", 0.32))
		phase = float(patch["x"]) * 1.7 + float(patch["y"]) * 0.9
		position = origin
		z_index = 2
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tint = Color.WHITE if art != "" else Color(0.72, 0.86, 0.92)

	func _process(_delta: float) -> void:
		var t := Time.get_ticks_msec() * 0.001
		position.x = origin.x + sin(t * 0.16 + phase) * drift
		modulate.a = base_alpha * (0.8 + 0.2 * sin(t * 0.31 + phase * 1.3))
		queue_redraw()

	func _draw() -> void:
		draw_texture_rect(texture, Rect2(-size_px * 0.5, size_px), false, tint)
