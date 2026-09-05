extends Node2D
class_name FireballVFX

signal impacted(position: Vector2, direction: Vector2)
signal finished

const FIREBALL_SHEET := preload("res://assets/third_party/shattered_pixel_dungeon/effects/fireball-short.png")
const FRAME_SIZE := Vector2i(47, 47)
const FRAME_COUNT := 24

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var flame_particles: GPUParticles2D = $FlameParticles
@onready var spark_particles: GPUParticles2D = $SparkParticles
@onready var smoke_particles: GPUParticles2D = $SmokeParticles
@onready var warm_light: PointLight2D = $PointLight2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _origin := Vector2.ZERO
var _destination := Vector2.ZERO
var _direction := Vector2.RIGHT
var _speed := 330.0
var _travel_time := 0.1
var _elapsed := 0.0
var _launched := false
var _impact_sent := false
var _visual_scale := 1.0
var _arc_height := 14.0

func _ready() -> void:
	z_index = 34
	_build_sprite_frames()
	_configure_particles()
	_configure_light()
	animation_player.play("pulse")
	set_process(false)

func launch(from_position: Vector2, to_position: Vector2, speed: float = 330.0, visual_scale: float = 1.0) -> void:
	_origin = from_position
	_destination = to_position
	_direction = (_destination - _origin).normalized()
	if _direction == Vector2.ZERO: _direction = Vector2.RIGHT
	_speed = maxf(speed, 1.0)
	_visual_scale = maxf(visual_scale, 0.25)
	_travel_time = maxf(_origin.distance_to(_destination) / _speed, 0.06)
	position = _origin
	rotation = _direction.angle()
	scale = Vector2.ONE * _visual_scale
	_elapsed = 0.0
	_launched = true
	flame_particles.emitting = true
	spark_particles.emitting = true
	smoke_particles.emitting = true
	animated_sprite.play("fly")
	set_process(true)

func _process(delta: float) -> void:
	if not _launched: return
	_elapsed = minf(_elapsed + delta, _travel_time)
	var progress := _elapsed / _travel_time
	# O eixo lógico permanece perfeitamente reto. Só o conteúdo recebe um
	# deslocamento perpendicular subpixel, dando vida sem alterar a mira.
	# Altura estritamente visual: a trajetória lógica continua reta e intacta.
	position = _origin.lerp(_destination, progress) + Vector2.UP * sin(progress * PI) * _arc_height * _visual_scale
	z_as_relative = false
	z_index = clampi(roundi(_origin.lerp(_destination, progress).y + 28.0), 1, 1800)
	animated_sprite.position.y = sin(progress * TAU * 3.0) * 1.25
	if _elapsed >= _travel_time:
		_arrive()

func _arrive() -> void:
	if _impact_sent: return
	_impact_sent = true
	_launched = false
	set_process(false)
	flame_particles.emitting = false
	spark_particles.emitting = false
	smoke_particles.emitting = false
	animated_sprite.visible = false
	warm_light.energy = 0.0
	impacted.emit(_destination, _direction)
	# Emissores ficam vivos só pelo tempo necessário para o rastro terminar.
	get_tree().create_timer(0.75).timeout.connect(func():
		finished.emit()
		queue_free()
	)

func _build_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("fly")
	frames.set_animation_speed("fly", 24.0)
	frames.set_animation_loop("fly", true)
	for index in FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = FIREBALL_SHEET
		atlas.region = Rect2(index * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.add_frame("fly", atlas)
	animated_sprite.sprite_frames = frames
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.centered = true
	animated_sprite.rotation = -rotation

func _configure_particles() -> void:
	# Mesma assinatura de FlameParticle.java: #EE7722 e poucos pixels vivos.
	_setup_particle(flame_particles, 12, 0.60, Color("ee7722"), Vector2(4, 4), 22.0, 7.0, true)
	_setup_particle(spark_particles, 7, 0.25, Color("fff09a"), Vector2(2, 2), 48.0, 13.0, true)
	_setup_particle(smoke_particles, 5, 0.58, Color(0.10, 0.08, 0.09, 0.30), Vector2(7, 7), 14.0, 8.0, false)

func _setup_particle(node: GPUParticles2D, amount: int, lifetime: float, color: Color, pixel_size: Vector2, velocity: float, spread: float, additive: bool) -> void:
	node.amount = amount
	node.lifetime = lifetime
	node.randomness = 0.6
	node.fixed_fps = 24
	node.local_coords = true
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(-1, 0, 0)
	process.spread = spread
	process.initial_velocity_min = velocity * 0.55
	process.initial_velocity_max = velocity
	process.gravity = Vector3(0, -9 if node != smoke_particles else -15, 0)
	process.scale_min = 0.55
	process.scale_max = 1.2
	process.color = Color.WHITE
	var life_gradient := Gradient.new()
	if node == flame_particles:
		life_gradient.offsets = PackedFloat32Array([0.0, 0.16, 0.58, 1.0])
		life_gradient.colors = PackedColorArray([Color("fff5b0"), Color("ffb13b"), Color("ee7722"), Color(0.55, 0.08, 0.02, 0.0)])
	elif node == spark_particles:
		life_gradient.offsets = PackedFloat32Array([0.0, 0.38, 1.0])
		life_gradient.colors = PackedColorArray([Color.WHITE, Color("ffd65a"), Color(1.0, 0.25, 0.04, 0.0)])
	else:
		life_gradient.offsets = PackedFloat32Array([0.0, 0.22, 1.0])
		life_gradient.colors = PackedColorArray([Color(0.12, 0.10, 0.11, 0.0), Color(0.12, 0.10, 0.11, 0.28), Color(0.08, 0.07, 0.08, 0.0)])
	var life_ramp := GradientTexture1D.new()
	life_ramp.gradient = life_gradient
	process.color_ramp = life_ramp
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.45))
	scale_curve.add_point(Vector2(0.22, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.08 if node != smoke_particles else 1.65))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = scale_curve
	process.scale_curve = scale_texture
	node.process_material = process
	var texture := GradientTexture2D.new()
	texture.width = maxi(2, int(pixel_size.x))
	texture.height = maxi(2, int(pixel_size.y))
	texture.fill = GradientTexture2D.FILL_SQUARE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	texture.gradient = gradient
	node.texture = texture
	if additive:
		var canvas_material := CanvasItemMaterial.new()
		canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		node.material = canvas_material

func _configure_light() -> void:
	var light_texture := GradientTexture2D.new()
	light_texture.width = 64
	light_texture.height = 64
	light_texture.fill = GradientTexture2D.FILL_RADIAL
	light_texture.fill_from = Vector2(0.5, 0.5)
	light_texture.fill_to = Vector2(1.0, 0.5)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	light_texture.gradient = gradient
	warm_light.texture = light_texture
	warm_light.color = Color("ff9a3d")
	warm_light.energy = 0.78
	warm_light.texture_scale = 1.35
