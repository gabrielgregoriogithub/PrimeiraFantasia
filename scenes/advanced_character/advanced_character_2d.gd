class_name AdvancedCharacter2D
extends Node2D

## Fundação isolada do novo framework de personagem 2D avançado — pedido do
## usuário: "não destrua nem substitua o sistema atual, crie em paralelo".
## Nada em unit_token.gd/main.gd/board_view.gd referencia esta pasta; é uma
## árvore de nós paralela, só instanciada pela cena sandbox por enquanto.
##
## Mesma separação lógica/visual que unit_token.gd já usa (VisualRoot lá,
## VisualOffsetRoot aqui): a posição deste nó raiz É a posição lógica no
## grid, nunca deve ser alterada por squash/recoil/breathing — só
## `visual_offset_root` se move por cosmética.
##
## Fase 2 (fundação): só a árvore de nós, os 10 anchors e uma respiração de
## idle mínima o bastante pra provar que o AnimationProfile já influencia
## alguma coisa. O AnimationController de verdade (estados, markers,
## transições, prioridade) é Fase 3.

@export var animation_profile: AnimationProfile:
	set(value):
		animation_profile = value
		_apply_idle_breathing_params()
@export var debug_visible: bool = false:
	set(value):
		debug_visible = value
		if is_instance_valid(_debug_overlay):
			_debug_overlay.visible = value

var visual_offset_root: Node2D
var shadow: Polygon2D
var back_vfx: Node2D
var character_visual: Sprite2D
var front_vfx: Node2D
var anchors: CharacterAnchors2D
var selection_indicator: Node2D

var _debug_overlay: Node2D
var _idle_tween: Tween

const PLACEHOLDER_SIZE := Vector2(40, 64)
const PLACEHOLDER_COLOR := Color("6b9bd1")

func _ready() -> void:
	visual_offset_root = Node2D.new()
	visual_offset_root.name = "VisualOffsetRoot"
	add_child(visual_offset_root)

	shadow = _build_shadow()
	add_child(shadow)

	back_vfx = Node2D.new()
	back_vfx.name = "BackVFX"
	visual_offset_root.add_child(back_vfx)

	character_visual = _build_placeholder_visual()
	visual_offset_root.add_child(character_visual)

	front_vfx = Node2D.new()
	front_vfx.name = "FrontVFX"
	visual_offset_root.add_child(front_vfx)

	anchors = CharacterAnchors2D.new()
	anchors.name = "Anchors"
	visual_offset_root.add_child(anchors)

	selection_indicator = _build_selection_indicator()
	add_child(selection_indicator)

	_debug_overlay = _build_debug_overlay()
	_debug_overlay.visible = debug_visible
	add_child(_debug_overlay)

	if animation_profile == null:
		animation_profile = AnimationProfile.new()
	else:
		_apply_idle_breathing_params()

## Sombra em elipse — mesma técnica de polígono em leque de unit_token.gd
## (24 pontos), fora de `visual_offset_root` de propósito: a sombra não deve
## herdar squash/recoil do personagem, só a posição base.
func _build_shadow() -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = "Shadow"
	var points := PackedVector2Array()
	var radius := Vector2(16, 6)
	for i in 24:
		var angle := TAU * float(i) / 24.0
		points.append(Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	poly.polygon = points
	poly.color = Color(0, 0, 0, 0.35)
	poly.z_index = -2
	return poly

## Placeholder sem depender de arte: uma cápsula colorida gerada em runtime
## (retângulo com topo/base arredondados via GradientTexture2D seria
## exagero pra um placeholder — um Sprite2D com ImageTexture sólido já
## resolve: prova a árvore de nós sem bloquear em arte final, como pedido.
func _build_placeholder_visual() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "CharacterVisual"
	var image := Image.create(int(PLACEHOLDER_SIZE.x), int(PLACEHOLDER_SIZE.y), false, Image.FORMAT_RGBA8)
	image.fill(PLACEHOLDER_COLOR)
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = true
	sprite.offset = Vector2(0, -PLACEHOLDER_SIZE.y * 0.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite

func _build_selection_indicator() -> Node2D:
	var node := Node2D.new()
	node.name = "SelectionIndicator"
	node.visible = false
	return node

func _build_debug_overlay() -> Node2D:
	var overlay := _DebugOverlay.new()
	overlay.name = "DebugOverlay"
	overlay.owner_character = self
	return overlay

## Respiração mínima pra esta etapa (fundação): sobe/desce levemente o
## CharacterVisual em loop, amplitude/velocidade lidas do AnimationProfile —
## só o suficiente pra "provar" que o profile já influencia alguma coisa.
## O AnimationController completo (breathing com segundo harmônico,
## body sway, head bob, micro-idles) é Fase 3 — não duplicar isso aqui.
## Chamado tanto na inicialização (`_ready()`) quanto sempre que
## `animation_profile` troca (via setter acima) — recria o tween do zero com
## os novos parâmetros.
func _apply_idle_breathing_params() -> void:
	if not is_inside_tree() or animation_profile == null or character_visual == null:
		return
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	var amplitude: float = 2.0 * animation_profile.idle_amplitude * animation_profile.breathing_strength
	var speed: float = maxf(0.05, animation_profile.idle_speed)
	var half_cycle := 1.0 / speed
	_idle_tween = create_tween()
	_idle_tween.set_loops()
	_idle_tween.tween_property(character_visual, "position:y", -amplitude, half_cycle).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(character_visual, "position:y", 0.0, half_cycle).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Gizmos de debug: um ponto + rótulo por anchor. Só desenha quando
## `debug_visible` está ligado (via export ou código) — custo zero fora do
## sandbox/desenvolvimento.
class _DebugOverlay:
	extends Node2D
	var owner_character: AdvancedCharacter2D

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		if owner_character == null or owner_character.anchors == null:
			return
		for anchor_name in CharacterAnchors2D.DEFAULT_POSITIONS:
			var marker: Marker2D = owner_character.anchors.get_anchor(anchor_name)
			if marker == null:
				continue
			var local_pos: Vector2 = owner_character.visual_offset_root.position + marker.position
			draw_circle(local_pos, 3.0, Color(1.0, 0.85, 0.2, 0.9))
			draw_string(ThemeDB.fallback_font, local_pos + Vector2(5, -5), anchor_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.9))
