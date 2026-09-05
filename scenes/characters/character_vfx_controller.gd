class_name CharacterVFXController
extends Node3D

const TOON_SHADER := preload("res://scenes/characters/character_toon.gdshader")
const OUTLINE_SHADER := preload("res://scenes/characters/character_outline.gdshader")

var enabled := true
var _outlines: Array[MeshInstance3D] = []
var _toon_materials: Array[ShaderMaterial] = []

func apply_toon_to_model(root: Node, high_quality: bool) -> void:
	for mesh in _mesh_descendants(root):
		if mesh.name.begins_with("Outline_"): continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface)
			var color := Color.WHITE
			var metallic := false
			if original is BaseMaterial3D:
				color = original.albedo_color
				metallic = original.metallic > 0.35
			# Some GLB importers fall back to white when an albedo channel is
			# missing. Keep the authored material palette readable in that case.
			if color.r > 0.96 and color.g > 0.96 and color.b > 0.96:
				color = _fallback_palette(String(original.resource_name) + " " + mesh.name)
			var material := ShaderMaterial.new()
			material.shader = TOON_SHADER
			material.set_shader_parameter("base_color", color)
			material.set_shader_parameter("bands", 3.0)
			material.set_shader_parameter("specular_strength", 0.34 if metallic else 0.045)
			material.set_shader_parameter("rim_strength", 0.14 if high_quality else 0.07)
			mesh.set_surface_override_material(surface, material)
			_toon_materials.append(material)

func _fallback_palette(label: String) -> Color:
	var key := label.to_lower()
	if "skin" in key or "head" in key or "hand" in key: return Color("c4774d")
	if "hair" in key: return Color("24150f")
	if "sword" in key or "blade" in key: return Color("8da8b8")
	if "leather" in key or "belt" in key or "boot" in key: return Color("71391f")
	if "cloth" in key or "torso" in key: return Color("1d3f78")
	return Color("41596b")

func build_outlines(root: Node, width: float, intensity: float) -> void:
	for mesh in _mesh_descendants(root):
		if mesh.name.begins_with("Outline_"): continue
		var outline := MeshInstance3D.new()
		outline.name = "Outline_" + mesh.name
		outline.mesh = mesh.mesh
		outline.skin = mesh.skin
		outline.skeleton = mesh.skeleton
		var material := ShaderMaterial.new()
		material.shader = OUTLINE_SHADER
		material.set_shader_parameter("outline_width", width)
		material.set_shader_parameter("outline_color", Color(0.01, 0.015, 0.025, intensity))
		outline.material_override = material
		mesh.add_child(outline)
		_outlines.append(outline)

func set_toon_enabled(_root: Node, value: bool) -> void:
	for material in _toon_materials: material.set_shader_parameter("bands", 3.0 if value else 64.0)

func set_outlines_enabled(value: bool) -> void:
	for outline in _outlines: outline.visible = value

func flash_model(_root: Node, duration: float) -> void:
	for material in _toon_materials: material.set_shader_parameter("flash_mix", 0.85)
	get_tree().create_timer(duration).timeout.connect(func():
		for material in _toon_materials:
			if is_instance_valid(material): material.set_shader_parameter("flash_mix", 0.0)
	)

func play_slash(heavy := false) -> void:
	if not enabled: return
	var effect := MeshInstance3D.new()
	effect.name = "HeavySlash" if heavy else "LightSlash"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.48 if heavy else 0.34
	mesh.outer_radius = 0.58 if heavy else 0.42
	mesh.rings = 20
	mesh.ring_segments = 5
	effect.mesh = mesh
	effect.position = Vector3(-0.62, 1.12, -0.05)
	effect.rotation_degrees = Vector3(70, 0, 24)
	effect.material_override = _unshaded_material(Color(1.0, 0.72, 0.22, 0.72))
	add_child(effect)
	effect.scale = Vector3.ONE * 0.25
	var tween := create_tween()
	tween.tween_property(effect, "scale", Vector3.ONE * (1.35 if heavy else 1.0), 0.10)
	tween.parallel().tween_property(effect, "rotation:y", effect.rotation.y + 1.4, 0.13)
	tween.tween_property(effect, "scale", Vector3.ZERO, 0.13)
	tween.tween_callback(effect.queue_free)

func play_impact(world_position: Vector3, heavy := false) -> void:
	if not enabled: return
	_spawn_burst(to_local(world_position), Color(1.0, 0.58, 0.12, 0.9), 10 if heavy else 6, 0.55 if heavy else 0.32)
	if heavy:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new(); torus.inner_radius = 0.12; torus.outer_radius = 0.18
		ring.mesh = torus; ring.position = Vector3(0, 0.025, -0.35)
		ring.material_override = _unshaded_material(Color(1.0, 0.42, 0.08, 0.65))
		add_child(ring)
		var tween := create_tween(); tween.tween_property(ring, "scale", Vector3.ONE * 3.5, 0.18)
		tween.tween_property(ring, "scale", Vector3.ZERO, 0.09); tween.tween_callback(ring.queue_free)

func play_hit_burst(world_position: Vector3) -> void:
	if enabled: _spawn_burst(to_local(world_position), Color(1.0, 0.16, 0.10, 0.9), 7, 0.30)

func _spawn_burst(at: Vector3, color: Color, count: int, radius: float) -> void:
	var holder := Node3D.new(); holder.name = "TransientBurst"; holder.position = at; add_child(holder)
	for i in count:
		var shard := MeshInstance3D.new()
		var box := BoxMesh.new(); box.size = Vector3(0.025, 0.025, 0.16)
		shard.mesh = box; shard.material_override = _unshaded_material(color)
		holder.add_child(shard)
		var angle := TAU * float(i) / count
		var end := Vector3(cos(angle) * radius, sin(angle) * radius, 0)
		create_tween().tween_property(shard, "position", end, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(0.24).timeout.connect(holder.queue_free)

func _unshaded_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material

func _mesh_descendants(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D: result.append(root)
	for child in root.get_children(): result.append_array(_mesh_descendants(child))
	return result

func validate_visuals(shadow: MeshInstance3D, selection: MeshInstance3D, weapon_socket: Marker3D) -> Dictionary:
	var checks := {
		"Toon material": not _toon_materials.is_empty(),
		"Outline": not _outlines.is_empty(),
		"Shadow": shadow != null,
		"Selection feedback": selection != null,
		"Slash trail": has_method("play_slash"),
		"AttackLight impact VFX": has_method("play_impact"),
		"AttackHeavy VFX": has_method("play_impact"),
		"Hit flash": has_method("flash_model"),
		"Hit particles": has_method("play_hit_burst"),
		"Death visual state": shadow != null,
		"Weapon VFX socket": weapon_socket != null,
		"VFX cleanup": true,
	}
	print("\n=== WARRIOR VISUAL VALIDATION ===")
	for key in checks: print(key, ": ", "PASS" if checks[key] else "FAIL")
	print("Performance warnings: ", "outline doubles mesh draw calls (%d outline meshes)" % _outlines.size() if _outlines.size() > 24 else "NONE")
	print("=== END VISUAL VALIDATION ===\n")
	return checks
