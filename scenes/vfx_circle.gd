extends Node2D
class_name VfxCircle

## Peça mínima de desenho reaproveitada por EffectsLayer pra projétil (ponto
## que viaja) e explosão (círculo que expande e desvanece) — não guarda
## nenhuma regra, só um raio e uma cor pra `_draw()`.

var radius: float
var color: Color

func _init(p_radius: float = 4.0, p_color: Color = Color.WHITE) -> void:
	radius = p_radius
	color = p_color

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
