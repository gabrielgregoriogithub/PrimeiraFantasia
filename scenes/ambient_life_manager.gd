extends Node2D
class_name AmbientLifeManager

## ETAPA 18 — Ambiente Vivo. Microeventos puramente decorativos (folha,
## poeira, névoa, brasa) agendados um de cada vez, em intervalos aleatórios,
## por bioma — nunca todos ao mesmo tempo (regra 2). Não participa de
## nenhuma regra: não altera grid, colisão, pathfinding, dano ou objetivos.
##
## Reaproveita arquitetura existente em vez de criar sistemas paralelos:
## - VisualPolicy.quality/quality_scale() já dá LOW/MEDIUM/HIGH — usado
##   direto como "nível de atividade ambiental" (regra 3).
## - ArtDirectionConfig.BIOMES["ambient_particles"] já existia (era
##   declarado mas nunca lido) — define o tipo de microevento por cenário.
## - EffectsLayer.VfxShape é a mesma primitiva de desenho já usada pelos
##   impactos de combate (folha/poeira/névoa/brasa aqui só usam kinds que já
##   existiam: "leaf", "orb", "smoke", "spark").

const VisualPolicy := preload("res://data/visual_policy.gd")

## Intervalo médio (segundos) entre microeventos por tipo de bioma, antes de
## escalar por qualidade. Ambient life é sempre mais lenta que VFX de
## combate (regra 57).
const BASE_INTERVAL := {"leaves": 3.2, "dust": 4.4, "mist": 5.4, "embers": 2.8}
const MAX_CONCURRENT := {"low": 1, "medium": 2, "high": 3}

var board: Node2D
var active_kind := "dust"
var _clock := 0.0
var _next_event_at := 1.0
var _duck_until := 0.0
var _spawned: Array = []
var _tree_lookup: Callable = Callable()

func setup(p_board: Node2D, tree_lookup: Callable) -> void:
	board = p_board
	_tree_lookup = tree_lookup
	_schedule_next()

func set_biome(ambient_particles_kind: String) -> void:
	active_kind = ambient_particles_kind if BASE_INTERVAL.has(ambient_particles_kind) else "dust"

## Reduz brevemente a densidade ambiental durante um evento visual grande
## (regra 58-59) — chamado de fora (ver EffectsLayer.emit_environment_reaction)
## sempre que a intensidade já registrada for HEAVY/SIGNATURE/EPIC.
func duck(seconds: float = 1.1) -> void:
	_duck_until = maxf(_duck_until, _clock + seconds)

## Chamada ao trocar de cenário/reiniciar partida — nenhum microevento velho
## deve sobreviver à troca (regra 93).
func clear() -> void:
	for node in _spawned:
		if is_instance_valid(node): node.queue_free()
	_spawned.clear()

func _process(delta: float) -> void:
	_clock += delta
	if VisualPolicy.reduced_motion or board == null:
		return
	_spawned = _spawned.filter(func(node): return is_instance_valid(node))
	if _clock < _next_event_at:
		return
	_schedule_next()
	if _spawned.size() >= _current_budget():
		return
	if _clock < _duck_until and randf() < 0.5:
		return
	_spawn_event()

func _current_budget() -> int:
	var tier := "low" if VisualPolicy.quality == VisualPolicy.QUALITY_LOW else ("high" if VisualPolicy.quality == VisualPolicy.QUALITY_HIGH else "medium")
	return int(MAX_CONCURRENT[tier])

func _schedule_next() -> void:
	var base: float = float(BASE_INTERVAL.get(active_kind, 4.0))
	var scaled := base / maxf(0.35, VisualPolicy.quality_scale())
	_next_event_at = _clock + randf_range(scaled * 0.6, scaled * 1.7)

func _spawn_event() -> void:
	match active_kind:
		"leaves": _spawn_leaf()
		"mist": _spawn_mist_wisp()
		"embers": _spawn_ember()
		_: _spawn_dust_mote()

func _spawn_leaf() -> void:
	if not _tree_lookup.is_valid():
		return
	var trees: Array = _tree_lookup.call()
	if trees.is_empty():
		return
	var tree = trees[randi() % trees.size()]
	var leaf := EffectsLayer.VfxShape.new("leaf", randf_range(2.2, 3.6), Color("8fae4f", 0.62))
	leaf.position = tree.position + Vector2(randf_range(-16.0, 16.0), -tree.visual_height * randf_range(0.35, 0.85))
	leaf.rotation = randf_range(0.0, TAU)
	leaf.z_index = roundi(leaf.position.y) + 1
	board.add_child(leaf)
	_spawned.append(leaf)
	var drift := Vector2(randf_range(-26.0, 26.0), randf_range(42.0, 74.0))
	var duration := randf_range(2.0, 3.2)
	var tween := leaf.create_tween().set_parallel(true)
	tween.tween_property(leaf, "position", leaf.position + drift, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(leaf, "rotation", leaf.rotation + randf_range(-5.0, 5.0), duration)
	tween.tween_property(leaf, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tween.set_parallel(false).tween_callback(leaf.queue_free)

func _spawn_dust_mote() -> void:
	var view_size: Vector2 = board.get_viewport_rect().size if board.get_viewport() != null else Vector2(832, 832)
	var start := Vector2(randf_range(0.0, view_size.x), randf_range(view_size.y * 0.3, view_size.y))
	var mote := EffectsLayer.VfxShape.new("orb", randf_range(1.0, 1.8), Color("f0e3c0", 0.22))
	mote.position = start
	mote.z_index = 4
	board.add_child(mote)
	_spawned.append(mote)
	var drift := Vector2(randf_range(-18.0, 18.0), randf_range(-30.0, -10.0))
	var duration := randf_range(2.6, 4.0)
	var tween := mote.create_tween().set_parallel(true)
	tween.tween_property(mote, "position", mote.position + drift, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mote, "modulate:a", 0.0, duration * 0.35).set_delay(duration * 0.65)
	tween.set_parallel(false).tween_callback(mote.queue_free)

func _spawn_mist_wisp() -> void:
	var view_size: Vector2 = board.get_viewport_rect().size if board.get_viewport() != null else Vector2(832, 832)
	var start := Vector2(randf_range(0.0, view_size.x), randf_range(view_size.y * 0.55, view_size.y * 0.95))
	var wisp := EffectsLayer.VfxShape.new("smoke", randf_range(20.0, 34.0), Color("d8ecef", 0.10))
	wisp.position = start
	wisp.z_index = -1
	board.add_child(wisp)
	_spawned.append(wisp)
	var drift := Vector2(randf_range(20.0, 46.0), randf_range(-4.0, 4.0))
	var duration := randf_range(3.4, 5.0)
	var tween := wisp.create_tween().set_parallel(true)
	tween.tween_property(wisp, "position", wisp.position + drift, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(wisp, "scale", Vector2.ONE * 1.4, duration)
	tween.tween_property(wisp, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.set_parallel(false).tween_callback(wisp.queue_free)

func _spawn_ember() -> void:
	var view_size: Vector2 = board.get_viewport_rect().size if board.get_viewport() != null else Vector2(832, 832)
	var start := Vector2(randf_range(0.0, view_size.x), randf_range(view_size.y * 0.5, view_size.y))
	var ember := EffectsLayer.VfxShape.new("spark", randf_range(1.4, 2.2), Color("ff9a43", 0.75))
	ember.position = start
	ember.z_index = 6
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ember.material = additive
	board.add_child(ember)
	_spawned.append(ember)
	var drift := Vector2(randf_range(-10.0, 10.0), randf_range(-52.0, -30.0))
	var duration := randf_range(1.4, 2.2)
	var tween := ember.create_tween().set_parallel(true)
	tween.tween_property(ember, "position", ember.position + drift, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(ember, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.set_parallel(false).tween_callback(ember.queue_free)
