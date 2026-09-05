extends Node2D

var tint := Color("fff0b2")

func setup(direction: Vector2 = Vector2.RIGHT, color: Color = Color("fff0b2")) -> void:
	tint = color
	rotation = direction.angle()
	queue_redraw()

func _ready() -> void:
	scale = Vector2.ONE * 0.35
	modulate.a = 0.0
	queue_redraw()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 1.25, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.05)
	tween.tween_property(self, "rotation", rotation + 0.38, 0.20)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.09)
	tween.chain().tween_callback(queue_free)

func _draw() -> void:
	draw_arc(Vector2.ZERO, 29.0, -0.95, 0.95, 20, tint, 4.0, true)
	draw_arc(Vector2.ZERO, 22.0, -0.82, 0.82, 16, Color(tint, 0.42), 2.0, true)
