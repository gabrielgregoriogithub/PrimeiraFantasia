class_name IntroCutscene
extends Control

## Cutscene de abertura ("A Vila em Chamas") reimplementada nativa no Godot —
## pedido do usuário: a versão anterior abria a página HTML própria
## (assets/cutscenes/a_vila_em_chamas.html) no navegador padrão do sistema
## via OS.shell_open(), mas isso depende de associação de arquivo .html
## configurada no Windows do usuário, que falhou silenciosamente numa
## máquina (nenhum navegador abria, sem erro nenhum do lado do Godot pra
## detectar). Esta versão usa as 3 mesmas imagens (extraídas do HTML pra
## scene_0/1/2.jpg) e a mesma sequência de falas, mas desenhadas com nós
## nativos do Godot (TextureRect/Label/Tween) — roda dentro da própria
## janela do jogo, sem processo externo, sem depender de navegador/OS.
## Como a sequência inteira roda aqui dentro, dá pra emitir `finished` no
## momento exato em que acaba, em vez do timer de duração estimada que a
## versão em HTML precisava (não existe ponte de volta do navegador).

signal finished

const LINE_INTERVAL_SEC := 3.2
const FINAL_HOLD_SEC := 2.2
const KENBURNS_DURATION_SEC := 9.0
const HERO_COLOR := "6fb3ff"
const ARCHER_COLOR := "7ee08a"

## Mantém a fala elevada em 3 quadrados de tabuleiro, evitando que seja
## cortada pela borda inferior, sem reduzir a imagem nem criar faixas pretas.
const DIALOGUE_BOTTOM_LIFT := 64.0 * 3

const SCENES := [
	{
		"image": "res://assets/cutscenes/scene_0.jpg",
		"lines": [
			{"speaker": "Guerreiro", "color": HERO_COLOR, "text": "— A vila está em perigo!"},
		],
	},
	{
		"image": "res://assets/cutscenes/scene_1.jpg",
		"lines": [
			{"speaker": "Guerreiro", "color": HERO_COLOR, "text": "— O que houve?"},
			{"speaker": "Arqueiro", "color": ARCHER_COLOR, "text": "*tosse* — Fomos atacados...!", "italic": true},
			{"speaker": "Guerreiro", "color": HERO_COLOR, "text": "— Não fale mais, poupe suas forças!"},
		],
	},
	{
		"image": "res://assets/cutscenes/scene_2.jpg",
		"lines": [
			{"speaker": "Guerreiro", "color": HERO_COLOR, "text": "— Vou vingá-los!"},
		],
		"roar": true,
	},
]

var _image_rect: TextureRect
var _stage: Control
var _bubble_container: VBoxContainer
var _roar_label: Label
var _scene_idx := 0
var _line_idx := 0
var _kenburns_tween: Tween

func _ready() -> void:
	# Posição/tamanho absolutos em toda essa cena (nunca anchors/presets):
	# um Control ancorado "full rect" contra OUTRO Control (não direto contra
	# a Viewport/CanvasLayer) fica com size=(0,0) indefinidamente numa árvore
	# montada inteira por código antes do primeiro layout pass real — mesma
	# família de regressão já vista no popup de confirmação de ataque e no
	# overlay antigo (ver STATUS.md), só que em cadeia (Control dentro de
	# Control) em vez de content-hugging. Tamanho fixo e conhecido (viewport
	# do jogo) evita depender de qualquer resolução de anchor.
	var viewport_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = viewport_size

	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.position = Vector2.ZERO
	backdrop.size = viewport_size
	add_child(backdrop)

	var stage_size := viewport_size
	_stage = Control.new()
	_stage.position = Vector2.ZERO
	_stage.size = stage_size
	_stage.clip_contents = true
	backdrop.add_child(_stage)

	_image_rect = TextureRect.new()
	_image_rect.position = Vector2.ZERO
	_image_rect.size = stage_size
	_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image_rect.pivot_offset = stage_size * 0.5
	_stage.add_child(_image_rect)

	var vignette := _build_vignette(stage_size)
	_stage.add_child(vignette)

	var bubble_area_height := 300.0
	var margin := MarginContainer.new()
	margin.position = Vector2(24, stage_size.y - bubble_area_height - 24 - DIALOGUE_BOTTOM_LIFT)
	margin.size = Vector2(stage_size.x - 48, bubble_area_height)
	_stage.add_child(margin)

	_bubble_container = VBoxContainer.new()
	_bubble_container.add_theme_constant_override("separation", 8)
	_bubble_container.alignment = BoxContainer.ALIGNMENT_END
	_bubble_container.size = margin.size
	margin.add_child(_bubble_container)

	# CenterContainer também precisa de tamanho explícito aqui pela mesma
	# razão do resto da cena — sem isso fica 0x0 e nunca centraliza nada.
	var roar_center := CenterContainer.new()
	roar_center.position = Vector2.ZERO
	roar_center.size = stage_size
	roar_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(roar_center)

	_roar_label = Label.new()
	_roar_label.text = "GRRLLL!!!"
	_roar_label.add_theme_font_size_override("font_size", 64)
	_roar_label.add_theme_color_override("font_color", Color("ff2b2b"))
	_roar_label.add_theme_color_override("font_outline_color", Color("200000"))
	_roar_label.add_theme_constant_override("outline_size", 6)
	_roar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_roar_label.modulate.a = 0.0
	_roar_label.rotation_degrees = -6.0
	roar_center.add_child(_roar_label)

func _build_vignette(viewport_size: Vector2) -> Control:
	var vignette := ColorRect.new()
	vignette.position = Vector2.ZERO
	vignette.size = viewport_size
	vignette.color = Color(0, 0, 0, 0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 c = UV - vec2(0.5);
	float d = length(c) * 1.35;
	float vig = smoothstep(0.45, 1.0, d);
	COLOR = vec4(0.0, 0.0, 0.0, vig * 0.55);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	vignette.material = mat
	return vignette

func play() -> void:
	visible = true
	await _show_scene(0)
	await _reveal_current_line()
	while true:
		await get_tree().create_timer(LINE_INTERVAL_SEC).timeout
		var more: bool = await _advance_step()
		if not more:
			break
	await get_tree().create_timer(FINAL_HOLD_SEC).timeout
	finished.emit()

func _show_scene(index: int) -> void:
	_scene_idx = index
	_line_idx = 0
	for child in _bubble_container.get_children():
		child.queue_free()
	_roar_label.modulate.a = 0.0
	var tex: Texture2D = load(SCENES[index]["image"])
	_image_rect.texture = tex
	_run_kenburns()

func _run_kenburns() -> void:
	if _kenburns_tween != null and _kenburns_tween.is_valid():
		_kenburns_tween.kill()
	_image_rect.scale = Vector2.ONE
	_image_rect.position = Vector2.ZERO
	_kenburns_tween = create_tween()
	_kenburns_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_kenburns_tween.tween_property(_image_rect, "scale", Vector2(1.12, 1.12), KENBURNS_DURATION_SEC)
	_kenburns_tween.parallel().tween_property(_image_rect, "position", Vector2(-14, -10), KENBURNS_DURATION_SEC)

## Retorna true se ainda tem mais história pela frente, false quando terminou.
func _advance_step() -> bool:
	var scene: Dictionary = SCENES[_scene_idx]
	if _line_idx < (scene["lines"] as Array).size():
		await _reveal_current_line()
		return true
	if _scene_idx < SCENES.size() - 1:
		await _show_scene(_scene_idx + 1)
		await _reveal_current_line()
		return true
	return false

func _reveal_current_line() -> void:
	var scene: Dictionary = SCENES[_scene_idx]
	var lines: Array = scene["lines"]
	var line: Dictionary = lines[_line_idx]
	_add_bubble(line)
	if scene.get("roar", false) and _line_idx == lines.size() - 1:
		await get_tree().create_timer(0.9).timeout
		_show_roar()
		_shake_stage()
	_line_idx += 1

func _add_bubble(line: Dictionary) -> void:
	var bubble := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.039, 0.031, 0.024, 0.82)
	style.border_color = Color("d4af6a")
	style.border_color.a = 0.55
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	bubble.add_theme_stylebox_override("panel", style)
	bubble.modulate.a = 0.0
	_bubble_container.add_child(bubble)

	var vbox := VBoxContainer.new()
	bubble.add_child(vbox)

	var speaker := Label.new()
	speaker.text = String(line.get("speaker", "")).to_upper()
	speaker.add_theme_font_size_override("font_size", 12)
	speaker.add_theme_color_override("font_color", Color(String(line.get("color", "d4af6a"))))
	vbox.add_child(speaker)

	var body := Label.new()
	body.text = String(line.get("text", ""))
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color("f2e6c9"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	if line.get("italic", false):
		body.add_theme_font_size_override("font_size", 18)
		body.modulate.a = 0.85
	vbox.add_child(body)

	var tween := create_tween()
	tween.tween_property(bubble, "modulate:a", 1.0, 0.4)

func _show_roar() -> void:
	_roar_label.pivot_offset = _roar_label.size * 0.5
	_roar_label.modulate.a = 0.0
	_roar_label.scale = Vector2(0.3, 0.3)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_roar_label, "modulate:a", 1.0, 0.35)
	tween.parallel().tween_property(_roar_label, "scale", Vector2(1.05, 1.05), 0.55)

func _shake_stage() -> void:
	var tween := create_tween()
	var origin := Vector2.ZERO
	for offset in [Vector2(-6, 3), Vector2(5, -4), Vector2(-4, 4), Vector2(6, -2), Vector2.ZERO]:
		tween.tween_property(_stage, "position", origin + offset, 0.1)


