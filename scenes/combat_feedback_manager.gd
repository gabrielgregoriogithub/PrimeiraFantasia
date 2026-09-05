extends Node2D
class_name CombatFeedbackManager

const VisualPolicy = preload("res://data/visual_policy.gd")

## Coordena apenas apresentação. Não calcula alcance, caminho, acerto, dano
## ou ordem de turno: recebe sempre os resultados dos sistemas existentes.

const MICRO := 0.12
const FAST := 0.20
const NORMAL := 0.34

var reduced_motion := false
var board: BoardView
var effects: EffectsLayer
var _targets: Array = []
var _primary_target = null
var _current_actor_name := ""
var _banner: Label
var _banner_tween: Tween
var _camera_tween: Tween
var _focus_camera_offset := Vector2.ZERO
var _focus_camera_zoom := Vector2.ONE

func setup(p_board: BoardView, p_effects: EffectsLayer) -> void:
	board = p_board
	effects = p_effects
	z_index = VisualPolicy.Z_FEEDBACK_LAYER
	_build_turn_banner()

func _build_turn_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 18
	add_child(layer)
	_banner = Label.new()
	_banner.position = Vector2(250, 86)
	_banner.size = Vector2(380, 42)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 19)
	_banner.add_theme_color_override("font_color", Color("fff0b0"))
	_banner.add_theme_color_override("font_outline_color", Color(0.05, 0.035, 0.08, 0.96))
	_banner.add_theme_constant_override("outline_size", 5)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	layer.add_child(_banner)

func transition_turn(actor: Dictionary) -> void:
	if actor == null or actor.is_empty(): return
	var name := String(actor.get("name", ""))
	if name == _current_actor_name: return
	_current_actor_name = name
	clear_targets()
	_banner.text = ("SEU TURNO  •  " if actor.get("team", "") == "player" else "TURNO INIMIGO  •  ") + name.to_upper()
	if _banner_tween != null and _banner_tween.is_valid(): _banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner.position.y = 80.0
	_banner.scale = Vector2(0.96, 0.96)
	_banner_tween = create_tween().set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, MICRO)
	_banner_tween.tween_property(_banner, "position:y", 90.0, FAST).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, FAST).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.set_parallel(false).tween_interval(0.38 if not reduced_motion else 0.12)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, FAST)

func set_targets(targets: Array, primary = null) -> void:
	_targets = targets.duplicate()
	_primary_target = primary
	queue_redraw()

func clear_targets() -> void:
	_targets.clear()
	_primary_target = null
	queue_redraw()

func action_focus(from_position: Vector2, to_position: Vector2, importance: String = "normal", zoom_override: float = 0.0) -> void:
	if reduced_motion or board == null or board.camera == null or importance == "basic": return
	if not board.acquire_camera("combat_focus", 10): return
	if _camera_tween != null and _camera_tween.is_valid(): _camera_tween.kill()
	var direction := (to_position - from_position).normalized()
	# "signature" (ETAPA 16 — Signature Abilities): foco perceptível mas
	# breve, um degrau acima de "epic" (dano alto/crítico) sem virar cutscene
	# — respeita a mesma janela FAST/NORMAL e o mesmo retorno suave abaixo.
	var offset := direction * (3.0 if importance == "normal" else (8.0 if importance == "signature" else 6.0))
	var zoom_amount := zoom_override if zoom_override > 0.0 else (1.008 if importance == "normal" else (1.05 if importance == "signature" else 1.018))
	_focus_camera_offset = board.camera.offset
	_focus_camera_zoom = board.camera.zoom
	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.tween_property(board.camera, "offset", offset, FAST).set_trans(Tween.TRANS_SINE)
	_camera_tween.tween_property(board.camera, "zoom", Vector2.ONE * zoom_amount, FAST)
	_camera_tween.set_parallel(false).tween_interval(0.10)
	_camera_tween.set_parallel(true)
	_camera_tween.tween_property(board.camera, "offset", _focus_camera_offset, NORMAL).set_trans(Tween.TRANS_SINE)
	_camera_tween.tween_property(board.camera, "zoom", _focus_camera_zoom, NORMAL)
	_camera_tween.set_parallel(false).tween_callback(func(): board.release_camera("combat_focus"))

func _exit_tree() -> void:
	if _camera_tween != null and _camera_tween.is_valid(): _camera_tween.kill()
	if board != null:
		if board.camera != null:
			board.camera.offset = _focus_camera_offset
			board.camera.zoom = _focus_camera_zoom
		board.release_camera("combat_focus")

func local_error(position: Vector2, text: String = "AÇÃO INDISPONÍVEL") -> void:
	if effects != null: effects.spawn_combat_popup(position, text, "block")

func _draw() -> void:
	if board == null: return
	var pulse := 0.5 + sin(Time.get_ticks_msec() * 0.004) * 0.5
	for target in _targets:
		if target == null: continue
		var rect := Rect2(Vector2(target["x"], target["y"]) * BoardView.TILE_SIZE, Vector2(board.state.footprint_width(target), board.state.footprint_height(target)) * BoardView.TILE_SIZE).grow(-5.0)
		var primary: bool = target == _primary_target
		var friendly: bool = board.state.current_actor != null and target.get("team", "") == board.state.current_actor.get("team", "")
		var color := Color("69dfa2") if friendly else Color("ff665c")
		var corner := 16.0 if primary else 10.0
		var inset := lerpf(4.0, 1.0, pulse) if primary and not reduced_motion else 2.0
		rect = rect.grow(-inset)
		var width := 3.0 if primary else 2.0
		# Quatro cantos, forma além da cor diferencia alvo de simples range.
		draw_line(rect.position, rect.position + Vector2(corner, 0), color, width, true)
		draw_line(rect.position, rect.position + Vector2(0, corner), color, width, true)
		draw_line(rect.end, rect.end - Vector2(corner, 0), color, width, true)
		draw_line(rect.end, rect.end - Vector2(0, corner), color, width, true)
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x-corner, rect.position.y), color, width, true)
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y+corner), color, width, true)
		draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x+corner, rect.end.y), color, width, true)
		draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.end.y-corner), color, width, true)
		if friendly: draw_circle(rect.get_center(), 4.0, Color(color, 0.72), false, 2.0)
		else: draw_line(rect.get_center()-Vector2(5,0), rect.get_center()+Vector2(5,0), Color(color,0.78), 2.0)

func _process(_delta: float) -> void:
	if not _targets.is_empty(): queue_redraw()
