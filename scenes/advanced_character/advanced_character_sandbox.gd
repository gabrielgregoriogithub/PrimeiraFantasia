extends Node2D

## Cena isolada de validação da Fase 2 (fundação) do AdvancedCharacter2D —
## pedido do usuário: laboratório separado do jogo de verdade, sem tocar em
## main.gd/unit_token.gd. Nesta etapa só instancia um personagem placeholder,
## liga os gizmos de debug (anchors visíveis) e mostra a respiração de idle
## mínima. Botões de IDLE/WALK/ATTACK/etc. e o seletor de AnimationProfile
## entram na Fase 3, quando o AnimationController existir de fato.

const AdvancedCharacter2DScript := preload("res://scenes/advanced_character/advanced_character_2d.gd")
const AnimationProfileScript := preload("res://scenes/advanced_character/animation_profile.gd")

var character: Node2D

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("2b2f36")
	background.size = Vector2(800, 600)
	background.position = Vector2(-400, -500)
	add_child(background)

	var ground_line := Line2D.new()
	ground_line.points = PackedVector2Array([Vector2(-400, 0), Vector2(400, 0)])
	ground_line.width = 2.0
	ground_line.default_color = Color(1, 1, 1, 0.15)
	add_child(ground_line)

	character = AdvancedCharacter2DScript.new()
	character.name = "PlaceholderCharacter"
	character.position = Vector2.ZERO
	add_child(character)
	character.animation_profile = AnimationProfileScript.new()
	character.debug_visible = true

	var label := Label.new()
	label.text = "AdvancedCharacter2D — Fase 2 (fundação)\nRespiração de idle + anchors visíveis (pontos amarelos)."
	label.position = Vector2(-200, -260)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	add_child(label)
