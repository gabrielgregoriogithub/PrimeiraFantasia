class_name SpdFireParticles
extends RefCounted

## Portes visuais compartilhados de FlameParticle.java e BlastParticle.java.
## Não contêm dano, status ou qualquer outra regra de gameplay.
class ExactFlame extends Node2D:
	# Porte literal usado por CharSprite.State.BURNING no SPD.
	const LIFESPAN := 0.6
	var age := 0.0
	var velocity := Vector2.ZERO

	func _ready() -> void:
		z_index = 6
		queue_redraw()

	func _process(delta: float) -> void:
		age += delta
		velocity.y -= 80.0 * delta
		position += velocity * delta
		if age >= LIFESPAN:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var remaining := 1.0 - age / LIFESPAN
		# FlameParticle.update(): am = p > .8 ? (1-p)*5 : 1.
		var alpha := (1.0 - remaining) * 5.0 if remaining > 0.8 else 1.0
		var size_px := maxf(1.0, 4.0 * remaining)
		draw_rect(Rect2(Vector2.ONE * (-size_px * 0.5), Vector2.ONE * size_px), Color(0.933, 0.467, 0.133, alpha))

class Flame extends Node2D:
	const LIFESPAN := 0.6
	var age := 0.0
	var velocity := Vector2.ZERO
	var base_size := 4.0
	var phase := 0.0
	var heat := 1.0

	func configure(p_velocity: Vector2 = Vector2.ZERO, p_size: float = 4.0, p_heat: float = 1.0) -> void:
		velocity = p_velocity
		base_size = p_size
		heat = clampf(p_heat, 0.35, 1.4)

	func _ready() -> void:
		z_index = 6
		phase = randf() * TAU
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive
		queue_redraw()

	func _process(delta: float) -> void:
		age += delta
		velocity.y -= 80.0 * delta
		position += velocity * delta
		if age >= LIFESPAN:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var progress := age / LIFESPAN
		var remaining := 1.0 - progress
		var alpha := minf(1.0, age / (LIFESPAN * 0.2)) * remaining
		var size_px := maxf(1.0, base_size * (0.35 + remaining * 0.75))
		var wobble := sin(phase + age * 24.0) * maxf(0.5, size_px * 0.22)
		# FlameParticle original é um pixel #EE7722 que encolhe. A adaptação
		# preserva isso como corpo e acrescenta núcleo e ponta em pixels,
		# criando leitura de chama viva sem blur ou arte realista.
		var body_color := Color("ee7722").lerp(Color("cf351c"), progress)
		draw_rect(Rect2(Vector2(-size_px * 0.5, -size_px * 0.15), Vector2(size_px, size_px * 0.82)), Color(body_color, alpha))
		draw_rect(Rect2(Vector2(-size_px * 0.30 + wobble, -size_px * 0.72), Vector2(size_px * 0.60, size_px * 0.72)), Color("ff9b2f", alpha * 0.90))
		if progress < 0.62 and size_px >= 2.0:
			draw_rect(Rect2(Vector2(-size_px * 0.22, size_px * 0.02), Vector2(size_px * 0.44, size_px * 0.42)), Color("fff0a0", alpha * heat))

class Blast extends Node2D:
	var lifespan := 0.6
	var age := 0.0
	var velocity := Vector2.ZERO
	var base_size := 8.0

	func configure(angle: float, speed: float, life: float) -> void:
		velocity = Vector2.from_angle(angle) * speed
		lifespan = clampf(life, 0.22, 1.0)

	func _ready() -> void:
		z_index = 7
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive
		queue_redraw()

	func _process(delta: float) -> void:
		age += delta
		velocity.y += 50.0 * delta
		position += velocity * delta
		if age >= lifespan:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var remaining := 1.0 - age / lifespan
		var alpha := minf(1.0, age / maxf(0.04, lifespan * 0.2))
		var size_px := maxf(1.0, base_size * remaining)
		var hot := Color("fff0a0").lerp(Color("ee7722"), 1.0 - remaining)
		draw_rect(Rect2(Vector2.ONE * -size_px * 0.5, Vector2.ONE * size_px), Color(hot, alpha * remaining))

class Smoke extends Node2D:
	var lifespan := 0.8
	var age := 0.0
	var velocity := Vector2.ZERO
	var acceleration := Vector2(0, -40)
	var base_size := 8.0
	var phase := 0.0

	func configure(p_velocity: Vector2, p_size: float = 8.0, p_lifespan: float = 0.8) -> void:
		velocity = p_velocity
		base_size = p_size
		lifespan = p_lifespan

	func _ready() -> void:
		z_index = 4
		phase = randf() * TAU
		queue_redraw()

	func _process(delta: float) -> void:
		age += delta
		velocity += acceleration * delta
		position += velocity * delta
		if age >= lifespan:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var remaining := 1.0 - age / lifespan
		var alpha := (minf(1.0, age / maxf(0.04, lifespan * 0.2)) * remaining * 0.34)
		var grown := base_size * (1.0 + (1.0 - remaining) * 0.85)
		var drift := sin(phase + age * 7.0) * grown * 0.12
		draw_rect(Rect2(Vector2(-grown * 0.5 + drift, -grown * 0.5), Vector2(grown, grown)), Color(0.13, 0.11, 0.12, alpha))
