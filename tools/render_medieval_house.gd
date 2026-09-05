extends SceneTree

const KIT_DIR := "C:/Users/gabri/Downloads/evolução pvp 2d/props/Medieval Village MegaKit[Standard]/Medieval Village MegaKit[Standard]/glTF/"
const OUTPUT := "C:/Users/gabri/Downloads/evolução pvp 2d/prototipoPVP-Godot/tools/_house_render.png"

var _cache: Dictionary = {}

func _load_piece(piece_name: String) -> Node3D:
	if not _cache.has(piece_name):
		print("loading ", piece_name, " ...")
		var path := KIT_DIR + piece_name + ".gltf"
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_file(path, state)
		if err != OK:
			push_error("failed to load %s: %s" % [piece_name, err])
			return null
		_cache[piece_name] = doc.generate_scene(state)
		print("  loaded ", piece_name)
	return (_cache[piece_name] as Node3D).duplicate()

func _place(parent: Node3D, piece_name: String, pos: Vector3, yaw_deg: float = 0.0) -> void:
	var inst := _load_piece(piece_name)
	if inst == null:
		return
	parent.add_child(inst)
	inst.position = pos
	inst.rotation_degrees = Vector3(0, yaw_deg, 0)

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var world := Node3D.new()
	viewport.add_child(world)

	# Piso 2x2m (uma célula do grid do kit).
	_place(world, "Floor_WoodDark", Vector3.ZERO)

	# Paredes: sul com porta (encarando a câmera), as outras 3 lisas.
	_place(world, "Wall_Plaster_Door_Flat", Vector3(0, 0, 1), 0)
	_place(world, "Door_1_Flat", Vector3(-0.5, 0, 1), 0)
	_place(world, "Wall_Plaster_Straight", Vector3(0, 0, -1), 180)
	_place(world, "Wall_Plaster_Window_Wide_Flat", Vector3(1, 0, 0), -90)
	_place(world, "Wall_Plaster_Straight", Vector3(-1, 0, 0), 90)

	# Postes de canto.
	_place(world, "Corner_Exterior_Wood", Vector3(1, 0, 1), 0)
	_place(world, "Corner_Exterior_Wood", Vector3(-1, 0, 1), 90)
	_place(world, "Corner_Exterior_Wood", Vector3(-1, 0, -1), 180)
	_place(world, "Corner_Exterior_Wood", Vector3(1, 0, -1), -90)

	# Telhado de duas águas (cumeeira ao longo do X), apoiado no topo das paredes.
	var roof_y := 3.05
	_place(world, "Roof_Wooden_2x1", Vector3(0, roof_y, 0), 0)
	_place(world, "Roof_Wooden_2x1", Vector3(0, roof_y, 0), 180)

	_place(world, "Prop_Chimney", Vector3(0.6, roof_y + 0.25, -0.6), 0)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.6
	camera.position = Vector3(8.3, 7.0, 8.3)
	world.add_child(camera)
	camera.look_at(Vector3(0, 2.0, 0), Vector3.UP)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, -40, 0)
	key.light_color = Color("fff0d2")
	key.light_energy = 1.3
	key.shadow_enabled = false
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 140, 0)
	fill.light_color = Color("8fcfff")
	fill.light_energy = 0.45
	fill.shadow_enabled = false
	world.add_child(fill)

	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	image.save_png(OUTPUT)
	print("saved ", OUTPUT)
	quit()
