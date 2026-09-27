extends Node
class_name BattlePresentationController

signal presentation_finished
signal outcome_finished(victory: bool)

enum Phase { LOADING, INTRO, OBJECTIVE, UNIT_REVEAL, ENEMY_REVEAL, READY, COMBAT, VICTORY, DEFEAT, ENDING }

const NORMAL_SPEED := 1.0
const REDUCED_SPEED := 0.35

var phase: Phase = Phase.LOADING
var presentation_speed := NORMAL_SPEED
var reduced_presentation := false
var board: BoardView
var hud_layer: CanvasLayer
var active := false

var _layer: CanvasLayer
var _fade: ColorRect
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _card: PanelContainer
var _eyebrow: Label
var _title: Label
var _subtitle: Label
var _skip_hint: Label
var _generation := 0
var _tweens: Array[Tween] = []
var _saved_camera_position := Vector2.ZERO
var _saved_camera_zoom := Vector2.ONE
var _revealed_tokens: Array[CanvasItem] = []

func _ready() -> void:
	_build_overlay()

func setup(p_board: BoardView, p_hud_layer: CanvasLayer) -> void:
	board = p_board
	hud_layer = p_hud_layer
	if board != null and board.camera != null:
		_saved_camera_position = board.camera.position
		_saved_camera_zoom = board.camera.zoom

func is_blocking_input() -> bool:
	return active and phase not in [Phase.COMBAT, Phase.ENDING]

func play_intro(scenario: Dictionary, heroes: Array, enemies: Array, objective_targets: Array = []) -> void:
	_cancel_running(false)
	if board != null: board.acquire_camera("battle_presentation", 30)
	active = true
	phase = Phase.LOADING
	_generation += 1
	var run := _generation
	_capture_camera()
	_layer.visible = true
	_fade.color = Color.BLACK
	_fade.modulate.a = 1.0
	_set_hud_alpha(0.0)
	_set_skip_visible(true)
	_prepare_tokens(heroes + enemies)
	_run_intro(run, scenario, heroes, enemies, objective_targets)

func skip() -> void:
	if not is_blocking_input(): return
	_generation += 1
	_cancel_tweens()
	_finish_intro()

## `hold` (segundos que o card fica exposto) é opcional — pedido do usuário
## pro evento de vento gelado do DESFILADEIRO precisar de uma pausa mais
## longa (~3s) que o padrão de 0.55s já usado por present_reinforcements/
## outros avisos rápidos; qualquer chamador que não passar `hold` continua
## exatamente como antes.
func present_event(heading: String, text: String, targets: Array = [], cinematic := false, hold: float = 0.55) -> void:
	if active or phase != Phase.COMBAT: return
	if board != null and not board.acquire_camera("battle_presentation", 30): return
	active = true
	_generation += 1
	var run := _generation
	_capture_camera()
	_run_event(run, heading, text, targets, cinematic, hold)

func present_reinforcements(tokens: Array) -> void:
	if tokens.is_empty(): return
	for token in tokens:
		if not is_instance_valid(token): continue
		token.modulate.a = 0.0
		token.scale = Vector2(0.92, 0.92)
		var tween := _track(create_tween())
		tween.set_parallel(true)
		tween.tween_property(token, "modulate:a", 1.0, _duration(0.34)).set_trans(Tween.TRANS_SINE)
		tween.tween_property(token, "scale", Vector2.ONE, _duration(0.42)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	present_event("ATENÇÃO", "Reforços chegaram!", tokens, false)

func present_outcome(victory: bool, targets: Array = []) -> void:
	if active or phase in [Phase.VICTORY, Phase.DEFEAT, Phase.ENDING]: return
	if board != null and not board.acquire_camera("battle_outcome", 40): return
	active = true
	phase = Phase.VICTORY if victory else Phase.DEFEAT
	_generation += 1
	var run := _generation
	_capture_camera()
	_run_outcome(run, victory, targets)

func frame_targets(targets: Array, margin := 96.0, max_zoom := 1.10) -> Dictionary:
	var points: Array[Vector2] = []
	for target in targets:
		if not is_instance_valid(target): continue
		if target is Node2D: points.append((target as Node2D).position)
	if points.is_empty():
		return {"position": _saved_camera_position, "zoom": _saved_camera_zoom}
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point.x = minf(min_point.x, point.x); min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x); max_point.y = maxf(max_point.y, point.y)
	var center := (min_point + max_point) * 0.5
	# O tabuleiro usa uma janela fixa: limita o pan para nunca revelar grandes
	# áreas vazias e mantém o zoom em uma faixa legível em qualquer resolução.
	var delta := center - _saved_camera_position
	delta.x = clampf(delta.x, -190.0, 190.0)
	delta.y = clampf(delta.y, -190.0, 190.0)
	var spread := (max_point - min_point) + Vector2.ONE * margin
	var viewport := board.get_viewport_rect().size if board != null else Vector2(832, 832)
	var fit := minf(viewport.x / maxf(spread.x, 1.0), viewport.y / maxf(spread.y, 1.0))
	var zoom_value := clampf(fit, 0.90, max_zoom)
	return {"position": _saved_camera_position + delta, "zoom": Vector2.ONE * zoom_value}

func _run_intro(run: int, scenario: Dictionary, heroes: Array, enemies: Array, objective_targets: Array) -> void:
	phase = Phase.INTRO
	await _fade_to(0.0, 0.48)
	if run != _generation: return
	await _camera_to(_establishing_frame(heroes, enemies), 0.42)
	if run != _generation: return
	phase = Phase.OBJECTIVE
	var objective := _objective_text(scenario, heroes)
	if not objective_targets.is_empty(): await _camera_to(frame_targets(objective_targets, 120.0, 1.05), 0.38)
	if run != _generation: return
	await _show_card("OBJETIVO", objective, "", 0.82)
	if run != _generation: return
	phase = Phase.UNIT_REVEAL
	_reveal_tokens(heroes)
	await _camera_to(frame_targets(heroes, 112.0, 1.06), 0.36)
	await _pause(0.22)
	if run != _generation: return
	phase = Phase.ENEMY_REVEAL
	_reveal_tokens(enemies)
	var boss: Variant = _find_boss(enemies)
	if boss != null:
		await _camera_to(frame_targets([boss], 150.0, 1.12), 0.52)
		if run != _generation: return
		_set_letterbox(true)
		if board != null: board.shake_camera(Vector2.DOWN, 0.75, 0.12, false)
		await _show_card("CHEFE", str(boss.unit.get("name", "")), "", 0.70)
		_set_letterbox(false)
	elif not enemies.is_empty():
		await _camera_to(frame_targets(enemies.slice(0, mini(enemies.size(), 5)), 112.0, 1.04), 0.34)
		await _pause(0.15)
	if run != _generation: return
	phase = Phase.READY
	await _restore_camera(0.40)
	_set_hud_alpha(1.0, true)
	await _show_card("", "BATALHA!", "", 0.32, true)
	if run == _generation: _finish_intro()

func _run_event(run: int, heading: String, text: String, targets: Array, cinematic: bool, hold: float = 0.55) -> void:
	if cinematic: _set_letterbox(true)
	if not targets.is_empty(): await _camera_to(frame_targets(targets, 110.0, 1.08), 0.34)
	if run != _generation: return
	await _show_card(heading, text, "", hold)
	if run != _generation: return
	await _restore_camera(0.30)
	_set_letterbox(false)
	active = false
	phase = Phase.COMBAT

func _run_outcome(run: int, victory: bool, targets: Array) -> void:
	_set_hud_alpha(0.20, true)
	await _pause(0.42)
	if run != _generation: return
	if victory:
		for target in targets:
			if is_instance_valid(target) and target.has_method("play_victory_pose"): target.play_victory_pose()
	if not targets.is_empty(): await _camera_to(frame_targets(targets, 130.0, 1.08), 0.46)
	if run != _generation: return
	var heading := "VITÓRIA" if victory else "DERROTA"
	var subtitle := "Batalha concluída" if victory else "A equipe foi derrotada"
	await _show_card("", heading, subtitle, 0.92, true)
	if run != _generation: return
	phase = Phase.ENDING
	active = false
	if board != null: board.release_camera("battle_outcome")
	outcome_finished.emit(victory)

func _objective_text(scenario: Dictionary, heroes: Array) -> String:
	if scenario.has("objective"): return str(scenario["objective"])
	if scenario.get("id", "") == ScenarioManager.LUA_VALLEY:
		return "Sobreviva até o fim do combate"
	for hero in heroes:
		if is_instance_valid(hero) and hero.unit.get("caged", false):
			return "Derrote os inimigos e liberte %s" % hero.unit.get("name", "o prisioneiro")
	return "Derrote todos os inimigos"

func _find_boss(enemies: Array):
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		var data: Dictionary = enemy.unit
		if data.get("boss", false) or int(data.get("footprintW", 1)) > 1 or int(data.get("footprintH", 1)) > 1:
			return enemy
	return null

func _establishing_frame(heroes: Array, enemies: Array) -> Dictionary:
	var relevant := heroes.duplicate()
	for enemy in enemies.slice(0, mini(enemies.size(), 5)): relevant.append(enemy)
	var frame := frame_targets(relevant, 150.0, 0.95)
	frame["zoom"] = Vector2.ONE * clampf(frame["zoom"].x, 0.90, 0.95)
	return frame

func _prepare_tokens(tokens: Array) -> void:
	_revealed_tokens.clear()
	for token in tokens:
		if not is_instance_valid(token): continue
		token.modulate.a = 0.0
		token.scale = Vector2(0.96, 0.96)
		_revealed_tokens.append(token)

func _reveal_tokens(tokens: Array) -> void:
	for i in tokens.size():
		var token = tokens[i]
		if not is_instance_valid(token): continue
		var tween := _track(create_tween())
		tween.set_parallel(true)
		tween.tween_interval(_duration(float(i) * 0.035))
		tween.tween_property(token, "modulate:a", 1.0, _duration(0.25)).set_trans(Tween.TRANS_SINE)
		tween.tween_property(token, "scale", Vector2.ONE, _duration(0.34)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _capture_camera() -> void:
	if board == null or board.camera == null: return
	_saved_camera_position = board.camera.position
	_saved_camera_zoom = board.camera.zoom

func _camera_to(frame: Dictionary, seconds: float) -> void:
	if board == null or board.camera == null or reduced_presentation: return
	var tween := _track(create_tween())
	tween.set_parallel(true)
	tween.tween_property(board.camera, "position", frame["position"], _duration(seconds)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(board.camera, "zoom", frame["zoom"], _duration(seconds)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _restore_camera(seconds: float) -> void:
	await _camera_to({"position": _saved_camera_position, "zoom": _saved_camera_zoom}, seconds)

func _fade_to(alpha: float, seconds: float) -> void:
	var tween := _track(create_tween())
	tween.tween_property(_fade, "modulate:a", alpha, _duration(seconds)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _show_card(eyebrow: String, title: String, subtitle: String, hold: float, emphatic := false) -> void:
	_eyebrow.text = eyebrow
	_title.text = title
	_subtitle.text = subtitle
	_title.add_theme_font_size_override("font_size", 42 if emphatic else 27)
	_card.visible = true
	_card.modulate.a = 0.0
	_card.position.y = -10.0
	_card.scale = Vector2(0.82, 0.82) if emphatic else Vector2(0.96, 0.96)
	var enter := _track(create_tween())
	enter.set_parallel(true)
	enter.tween_property(_card, "modulate:a", 1.0, _duration(0.16))
	enter.tween_property(_card, "position:y", 0.0, _duration(0.22)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	enter.tween_property(_card, "scale", Vector2.ONE, _duration(0.24)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await enter.finished
	await _pause(hold)
	var leave := _track(create_tween())
	leave.tween_property(_card, "modulate:a", 0.0, _duration(0.16))
	await leave.finished
	_card.visible = false

func _pause(seconds: float) -> void:
	if reduced_presentation: return
	await get_tree().create_timer(_duration(seconds)).timeout

func _duration(seconds: float) -> float:
	var mode_scale := REDUCED_SPEED if reduced_presentation else 1.0
	return maxf(0.01, seconds * presentation_speed * mode_scale)

func _set_hud_alpha(alpha: float, animated := false) -> void:
	if hud_layer == null: return
	for child in hud_layer.get_children():
		if not child is CanvasItem: continue
		if not animated:
			(child as CanvasItem).modulate.a = alpha
		else:
			var tween := _track(create_tween())
			tween.tween_property(child, "modulate:a", alpha, _duration(0.28)).set_trans(Tween.TRANS_SINE)

func _set_letterbox(enabled: bool) -> void:
	var wanted := 1.0 if enabled else 0.0
	var tween := _track(create_tween())
	tween.set_parallel(true)
	tween.tween_property(_top_bar, "modulate:a", wanted, _duration(0.18))
	tween.tween_property(_bottom_bar, "modulate:a", wanted, _duration(0.18))

func _set_skip_visible(value: bool) -> void:
	_skip_hint.visible = value

func _finish_intro() -> void:
	_cancel_tweens()
	for token in _revealed_tokens:
		if is_instance_valid(token): token.modulate.a = 1.0; token.scale = Vector2.ONE
	_revealed_tokens.clear()
	if board != null and board.camera != null:
		board.camera.position = _saved_camera_position
		board.camera.zoom = _saved_camera_zoom
	_set_hud_alpha(1.0)
	_fade.modulate.a = 0.0
	_card.visible = false
	_top_bar.modulate.a = 0.0
	_bottom_bar.modulate.a = 0.0
	_set_skip_visible(false)
	active = false
	phase = Phase.COMBAT
	if board != null: board.release_camera("battle_presentation")
	presentation_finished.emit()

func _cancel_running(restore := true) -> void:
	_generation += 1
	_cancel_tweens()
	if restore and active: _finish_intro()

func _cancel_tweens() -> void:
	for tween in _tweens:
		if tween != null and tween.is_valid(): tween.kill()
	_tweens.clear()

func _track(tween: Tween) -> Tween:
	_tweens.append(tween)
	return tween

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 80
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)
	_top_bar = ColorRect.new(); _bottom_bar = ColorRect.new()
	for bar in [_top_bar, _bottom_bar]:
		bar.color = Color(0.02, 0.015, 0.01, 0.94); bar.mouse_filter = Control.MOUSE_FILTER_IGNORE; bar.modulate.a = 0.0; _layer.add_child(bar)
	_top_bar.anchor_right = 1.0; _top_bar.offset_bottom = 52.0
	_bottom_bar.anchor_top = 1.0; _bottom_bar.anchor_right = 1.0; _bottom_bar.anchor_bottom = 1.0; _bottom_bar.offset_top = -52.0
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(center)
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(430, 0)
	_card.pivot_offset = Vector2(215, 55)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e8d3a3"); style.border_color = Color("76502c"); style.set_border_width_all(3); style.set_corner_radius_all(12)
	style.content_margin_left = 26; style.content_margin_right = 26; style.content_margin_top = 14; style.content_margin_bottom = 16
	_card.add_theme_stylebox_override("panel", style)
	center.add_child(_card)
	var box := VBoxContainer.new(); box.alignment = BoxContainer.ALIGNMENT_CENTER; _card.add_child(box)
	_eyebrow = Label.new(); _title = Label.new(); _subtitle = Label.new()
	for label in [_eyebrow, _title, _subtitle]: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_color_override("font_color", Color("382617")); box.add_child(label)
	_eyebrow.add_theme_font_size_override("font_size", 15); _title.add_theme_font_size_override("font_size", 27); _subtitle.add_theme_font_size_override("font_size", 14)
	_card.visible = false
	_skip_hint = Label.new()
	_skip_hint.text = "ESPAÇO / ESC / CLIQUE — pular"
	_skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_hint.position = Vector2(-258, -36); _skip_hint.size = Vector2(240, 24)
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.add_theme_font_size_override("font_size", 12); _skip_hint.add_theme_color_override("font_color", Color("f6e6bf")); _skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_skip_hint)
	_layer.visible = false
