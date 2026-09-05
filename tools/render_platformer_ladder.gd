extends SceneTree

const OUTPUT := "res://assets/props/waterfall/ladder_long.png"

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var world := Node3D.new()
	viewport.add_child(world)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = load("res://assets/props/waterfall/source/Ladder_long.obj")
	world.add_child(mesh_instance)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color("9b5528")
	material.roughness = 0.86
	mesh_instance.material_override = material

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.0
	camera.position = Vector3(0, 3.64, 10)
	world.add_child(camera)
	camera.look_at(Vector3(0, 3.64, 0), Vector3.UP)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-18, -25, 0)
	key.light_color = Color("fff0d2")
	key.light_energy = 1.35
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20, 150, 0)
	fill.light_color = Color("8fcfff")
	fill.light_energy = 0.42
	world.add_child(fill)

	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	image.resize(64, 256, Image.INTERPOLATE_NEAREST)
	image.save_png(OUTPUT)
	quit()
