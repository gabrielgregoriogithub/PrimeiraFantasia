extends GPUParticles2D
class_name CombatParticles2D

@export_enum("dust", "hit") var effect_kind := "dust"

func _ready() -> void:
	one_shot = true
	emitting = false
	local_coords = false
	finished.connect(queue_free)
	var particle_material := ParticleProcessMaterial.new()
	if effect_kind == "hit":
		amount = 9
		lifetime = 0.34
		particle_material.direction = Vector3(1, -0.25, 0)
		particle_material.spread = 180.0
		particle_material.initial_velocity_min = 42.0
		particle_material.initial_velocity_max = 86.0
		particle_material.gravity = Vector3(0, 150, 0)
		particle_material.scale_min = 1.8
		particle_material.scale_max = 3.8
		particle_material.color = Color("ffe0a0")
	else:
		amount = 5
		lifetime = 0.46
		particle_material.direction = Vector3(0, -1, 0)
		particle_material.spread = 70.0
		particle_material.initial_velocity_min = 12.0
		particle_material.initial_velocity_max = 28.0
		particle_material.gravity = Vector3(0, -8, 0)
		particle_material.scale_min = 2.8
		particle_material.scale_max = 5.8
		particle_material.color = Color(0.70, 0.61, 0.46, 0.55)
	process_material = particle_material
	var particle_texture := GradientTexture2D.new()
	particle_texture.width = 6
	particle_texture.height = 6
	particle_texture.fill = GradientTexture2D.FILL_RADIAL
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	particle_texture.gradient = gradient
	texture = particle_texture
	restart()
	emitting = true
