class_name TowerTorch
extends Node2D

var phase := 0.0
var flicker_speed := 8.0
var base_energy := 0.62
var flame_particles: GPUParticles2D
var light: PointLight2D
var animation_player: AnimationPlayer

## Nasce acesa por padrão (comportamento de sempre, usado pela troca manual
## de cenário). A entrada cinematográfica da Torre cria as tochas com
## `lit=false` (via `start_lit=false` em `_build_tower_atmosphere`) e chama
## `ignite()` uma a uma — ver CampaignDirector.
var lit := true
## 0 = totalmente apagada, 1 = totalmente acesa — anima suavemente durante
## ignite() em vez de a chama/luz aparecerem "secas".
var ignite_progress := 1.0
var _ignite_tween: Tween

func _ready() -> void:
	z_index = 3
	phase = randf() * TAU
	flicker_speed = randf_range(7.0, 9.0)
	base_energy = randf_range(0.54, 0.68)
	_build_particles()
	_build_light()
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	if not lit:
		ignite_progress = 0.0
		flame_particles.emitting = false
		light.energy = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	phase += delta * flicker_speed
	light.energy = base_energy * ignite_progress * (0.96 + sin(phase) * 0.045 + sin(phase * 2.37) * 0.018)
	queue_redraw()

func _draw() -> void:
	if ignite_progress <= 0.0:
		return
	draw_rect(Rect2(-4, 4, 8, 13), Color("5c4634"))
	draw_rect(Rect2(-6, 14, 12, 3), Color("26212a"))
	# A chama cresce junto com ignite_progress (some quando apagada, altura
	# cheia quando acesa) em vez de aparecer/sumir de repente.
	var flame_h: float = -10.0 * ignite_progress
	var flame_alpha: float = clampf(ignite_progress * 1.6, 0.0, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-5,5),Vector2(0,4+flame_h+sin(phase)*1.5),Vector2(5,5)]), Color(Color("ee7722"), flame_alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(-2,4),Vector2(0,4+flame_h*0.5),Vector2(2,4)]), Color(Color("fff0a0"), flame_alpha))

## Acende a tocha: pequena faísca (partículas ligam na hora, luz cresce
## suavemente) + SFX de fogo (mesmo `play_sfx("fire", ...)` já usado pra
## queimaduras — sem asset novo). Chamar 2x não faz nada na 2ª vez.
func ignite(pan: float = 0.0) -> void:
	if lit and ignite_progress >= 1.0:
		return
	lit = true
	flame_particles.emitting = true
	AudioEngine.play_sfx("fire", pan)
	if _ignite_tween != null and _ignite_tween.is_valid(): _ignite_tween.kill()
	_ignite_tween = create_tween()
	_ignite_tween.tween_property(self, "ignite_progress", 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _build_particles() -> void:
	flame_particles = GPUParticles2D.new()
	flame_particles.name = "FlameParticles"
	flame_particles.amount = 6
	flame_particles.lifetime = 0.48
	flame_particles.fixed_fps = 24
	flame_particles.position = Vector2(0, -2)
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, -1, 0)
	process.spread = 18.0
	process.initial_velocity_min = 8.0
	process.initial_velocity_max = 17.0
	process.gravity = Vector3(0, -14, 0)
	process.scale_min = 0.6
	process.scale_max = 1.1
	process.color = Color("ee7722")
	flame_particles.process_material = process
	var texture := GradientTexture2D.new()
	texture.width = 4; texture.height = 4
	texture.fill = GradientTexture2D.FILL_SQUARE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("fff0a0"), Color(0.93,0.47,0.13,0)])
	texture.gradient = gradient
	flame_particles.texture = texture
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flame_particles.material = additive
	add_child(flame_particles)

func _build_light() -> void:
	light = PointLight2D.new()
	light.name = "PointLight2D"
	light.position = Vector2(0, 4)
	light.color = Color("ffad5a")
	light.energy = base_energy
	var texture := GradientTexture2D.new()
	texture.width = 96; texture.height = 96
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5); texture.fill_to = Vector2(1,0.5)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1,1,1,0)])
	texture.gradient = gradient
	light.texture = texture
	light.texture_scale = 1.15
	add_child(light)
