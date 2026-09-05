extends RefCounted
class_name CharacterVisualController

const CLASS_VISUAL_PROFILES := preload("res://data/class_visual_profiles.gd")
const ART_DIRECTION := preload("res://data/art_direction_config.gd")

## Camada exclusivamente visual usada por UnitToken. Mantém corpo, luz e
## sombras independentes do tile lógico e da UI.

const QUALITY_LOW := "low"
const QUALITY_MEDIUM := "medium"
const QUALITY_HIGH := "high"

const PROFILES := {
	"light": {"bob": 2.4, "breathe": 0.015, "tilt": 0.045, "shadow": Vector2(0.84, 0.84), "contact": Vector2(0.78, 0.78), "landing": 0.75, "recovery": 0.11},
	"medium": {"bob": 1.75, "breathe": 0.011, "tilt": 0.032, "shadow": Vector2.ONE, "contact": Vector2.ONE, "landing": 1.0, "recovery": 0.14},
	"heavy": {"bob": 1.05, "breathe": 0.007, "tilt": 0.022, "shadow": Vector2(1.16, 1.10), "contact": Vector2(1.15, 1.08), "landing": 1.35, "recovery": 0.18},
	"giant": {"bob": 0.65, "breathe": 0.004, "tilt": 0.014, "shadow": Vector2(1.72, 1.52), "contact": Vector2(1.58, 1.38), "landing": 1.8, "recovery": 0.23},
}

const LIGHT_SHADER_SOURCE := """
shader_type canvas_item;
render_mode unshaded;
uniform float volume_strength = 0.16;
uniform float rim_strength = 0.025;
uniform vec4 magic_color : source_color = vec4(1.0);
uniform float magic_strength = 0.0;
uniform float outline_strength = 0.34;
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform vec4 shadow_color : source_color = vec4(0.12, 0.13, 0.22, 1.0);
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float vertical = (0.50 - UV.y) * volume_strength;
	float directional = (0.52 - UV.x) * volume_strength * 0.72;
	float lower_shadow = smoothstep(0.48, 1.0, UV.y) * volume_strength * 0.34;
	float edge = 0.0;
	vec2 px = TEXTURE_PIXEL_SIZE;
	edge = max(edge, tex.a - texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	edge = max(edge, tex.a - texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	edge = max(edge, tex.a - texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	edge = max(edge, tex.a - texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	vec3 color = tex.rgb * (1.0 + vertical + directional - lower_shadow);
	color += magic_color.rgb * magic_strength * (0.42 + edge * 0.75);
	color += mix(vec3(0.08, 0.10, 0.14), magic_color.rgb, magic_strength) * edge * (rim_strength + magic_strength * 0.12);
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luma), color, saturation);
	color = (color - vec3(0.5)) * contrast + vec3(0.5);
	color = mix(color, shadow_color.rgb, edge * outline_strength * (0.58 + UV.x * 0.18));
	COLOR = vec4(color, tex.a) * COLOR;
}
"""

static var _shared_shader: Shader

var host: Node2D
var body_root: Node2D
var sprite: Sprite2D
var soft_shadow: Polygon2D
var contact_shadow: Polygon2D
var profile_name := "medium"
var profile: Dictionary = PROFILES["medium"]
var class_profile_name := "default"
var class_profile: Dictionary = ClassVisualProfiles.DEFAULT
var visual_quality := QUALITY_MEDIUM
var visual_height := 0.0
var foot_anchor_y := 34.0
var _material: ShaderMaterial
var _magic_tween: Tween

func configure(p_host: Node2D, p_body_root: Node2D, p_sprite: Sprite2D, p_soft_shadow: Polygon2D, unit: Dictionary, quality: String = QUALITY_MEDIUM) -> void:
	host = p_host
	body_root = p_body_root
	sprite = p_sprite
	soft_shadow = p_soft_shadow
	visual_quality = quality
	profile_name = profile_for_unit(unit)
	profile = PROFILES[profile_name]
	class_profile = CLASS_VISUAL_PROFILES.for_unit(unit)
	class_profile_name = class_profile["key"]
	# O perfil de classe pode especializar o peso sem mudar qualquer atributo.
	profile_name = String(class_profile.get("weight", profile_name))
	profile = PROFILES.get(profile_name, PROFILES["medium"])
	_create_contact_shadow(unit)
	_apply_profile_to_shadows()
	_apply_lighting_material()

static func profile_for_unit(unit: Dictionary) -> String:
	var key := String(unit.get("spriteKey", ""))
	var footprint := maxi(int(unit.get("footprintWidth", unit.get("footprintSize", 1))), int(unit.get("footprintHeight", unit.get("footprintSize", 1))))
	if footprint > 1: return "giant"
	if key in ["ladino", "fada", "goblin", "spd_rat", "spd_snake", "fantasma"]: return "light"
	if key in ["guerreiro", "orc", "troll", "zumbi", "esqueleto", "spd_gnoll", "spd_goo"]: return "heavy"
	return "medium"

func _create_contact_shadow(unit: Dictionary) -> void:
	contact_shadow = Polygon2D.new()
	contact_shadow.name = "ContactShadow"
	var footprint := maxi(int(unit.get("footprintWidth", unit.get("footprintSize", 1))), int(unit.get("footprintHeight", unit.get("footprintSize", 1))))
	var rx := 13.5 * float(footprint)
	var ry := 3.4 * sqrt(float(footprint))
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * float(i) / 20.0
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry + 27.0 * float(footprint)))
	contact_shadow.polygon = points
	contact_shadow.color = Color(ART_DIRECTION.DEFAULT_BIOME["shadow_tint"], 0.48)
	contact_shadow.z_index = -3
	host.add_child(contact_shadow)
	host.move_child(contact_shadow, 0)

func _apply_profile_to_shadows() -> void:
	var class_shadow: Vector2 = class_profile.get("shadow_scale", Vector2.ONE)
	var opacity := float(class_profile.get("shadow_opacity", 1.0))
	var grounding := float(class_profile.get("grounding", 1.0))
	if soft_shadow != null:
		soft_shadow.scale = Vector2(profile["shadow"]) * class_shadow
		soft_shadow.color = Color(ART_DIRECTION.DEFAULT_BIOME["shadow_tint"], 0.30 * opacity * float(ART_DIRECTION.GLOBAL["shadow_opacity"]))
	if contact_shadow != null:
		contact_shadow.scale = Vector2(profile["contact"]) * class_shadow * grounding
		contact_shadow.color.a = 0.48 * opacity * float(ART_DIRECTION.GLOBAL["shadow_opacity"])

func _apply_lighting_material() -> void:
	if sprite == null: return
	if _shared_shader == null:
		_shared_shader = Shader.new()
		_shared_shader.code = LIGHT_SHADER_SOURCE
	_material = ShaderMaterial.new()
	_material.shader = _shared_shader
	_material.set_shader_parameter("volume_strength", 0.105 if visual_quality == QUALITY_LOW else (0.185 if visual_quality == QUALITY_HIGH else 0.145))
	_material.set_shader_parameter("rim_strength", 0.0 if visual_quality == QUALITY_LOW else (0.05 if visual_quality == QUALITY_HIGH else 0.022))
	_material.set_shader_parameter("outline_strength", 0.26 if visual_quality == QUALITY_LOW else 0.34)
	_material.set_shader_parameter("saturation", float(ART_DIRECTION.GLOBAL["character_saturation"]))
	_material.set_shader_parameter("contrast", float(ART_DIRECTION.GLOBAL["character_contrast"]))
	_material.set_shader_parameter("shadow_color", ART_DIRECTION.DEFAULT_BIOME["shadow_tint"])
	sprite.material = _material

## ETAPA 17 — `low_hp` é um sinal puramente visual (respiração mais pesada,
## postura mais baixa), sem nenhuma leitura de stats reais além do próprio
## bool já decidido por quem chama (UnitToken, a partir de hp/maxHp). Não
## participa de nenhuma regra e não substitui dano/HP/status reais.
func update_pose(phase: float, moving: bool, move_direction: Vector2, action_busy: bool, alive: bool, low_hp: bool = false) -> bool:
	if not alive or body_root == null: return false
	_update_shadows()
	if action_busy: return false
	var low_hp_slowdown := 0.72 if low_hp else 1.0
	var personality_phase := phase * float(class_profile.get("idle_speed", 1.0)) * low_hp_slowdown + float(abs(hash(str(host.get_instance_id())) % 997)) * 0.013
	var bob := float(class_profile.get("walk_bob", profile["bob"]))
	var breathe := float(profile["breathe"])
	var step_contact := false
	var scale_y := 1.0
	if moving:
		visual_height = -absf(sin(personality_phase)) * bob
		scale_y = 1.0 + sin(personality_phase * 2.0) * breathe * 0.45
		var secondary := sin(personality_phase * 2.0 + 0.7) * float(class_profile.get("secondary_motion", 0.0)) * 0.018
		body_root.rotation = move_direction.x * sin(personality_phase) * float(class_profile.get("walk_tilt", profile["tilt"])) + secondary
		step_contact = absf(sin(phase)) < 0.10
	else:
		# Respiração comprime/expande a silhueta ao redor dos pés; deslocamento
		# vertical mínimo impede a leitura de "flutuação". A terceira harmônica
		# cria inhale/hold/exhale/hold sem manter um seno mecânico perfeito.
		var breath_wave := sin(personality_phase) * 0.86 + sin(personality_phase * 3.0) * 0.14
		visual_height = breath_wave * float(class_profile.get("idle_bob", 0.22)) * (1.35 if low_hp else 1.0)
		if low_hp: visual_height += 1.1 # postura mais baixa, sem mexer no chão lógico
		if class_profile.get("idle_style", "") == "floating": visual_height -= 2.8
		scale_y = 1.0 + breath_wave * breathe * (1.4 if low_hp else 1.0)
		var rare_adjust := maxf(0.0, sin(personality_phase * 0.117 - 1.35)) * float(class_profile.get("idle_variation", 0.0))
		body_root.rotation = sin(personality_phase * 0.43) * float(class_profile.get("walk_tilt", profile["tilt"])) * (0.18 + rare_adjust)
	var scale_x := 1.0 - (scale_y - 1.0) * 0.48
	body_root.scale = Vector2(scale_x, scale_y)
	body_root.position = Vector2(0.0, visual_height + foot_anchor_y * (1.0 - scale_y))
	_update_shadows()
	return step_contact

func set_visual_height(height: float) -> void:
	visual_height = height
	if body_root != null: body_root.position.y = height
	_update_shadows()

func _update_shadows() -> void:
	var height := maxf(0.0, -visual_height)
	var height_ratio := clampf(height / 20.0, 0.0, 1.0)
	var class_shadow: Vector2 = class_profile.get("shadow_scale", Vector2.ONE)
	var opacity := float(class_profile.get("shadow_opacity", 1.0))
	if soft_shadow != null:
		soft_shadow.position = Vector2(4.0, 0.0)
		soft_shadow.scale = Vector2(profile["shadow"]) * class_shadow * lerpf(1.0, 0.77, height_ratio)
		soft_shadow.color.a = lerpf(0.30, 0.17, height_ratio) * opacity
	if contact_shadow != null:
		contact_shadow.scale = Vector2(profile["contact"]) * class_shadow * lerpf(1.0, 0.70, height_ratio)
		contact_shadow.color.a = lerpf(0.48, 0.18, height_ratio) * opacity

func pulse_contact(strength: float = 1.0) -> void:
	if contact_shadow == null: return
	var base_scale: Vector2 = Vector2(profile["contact"]) * Vector2(class_profile.get("shadow_scale", Vector2.ONE)) * float(class_profile.get("grounding", 1.0))
	var tween := host.create_tween()
	tween.tween_property(contact_shadow, "scale", base_scale * (1.0 + 0.10 * strength), 0.045)
	tween.tween_property(contact_shadow, "scale", base_scale, float(profile["recovery"]))

func apply_magic_light(element: String, strength: float = 1.0, duration: float = 0.28) -> void:
	if _material == null or visual_quality == QUALITY_LOW: return
	var color := Color("fff0b0")
	match element:
		"fire": color = Color("ff9a43")
		"ice", "frost": color = Color("9de9ff")
		"lightning": color = Color("e3fbff")
		"heal": color = Color("a9ffd0")
		"poison": color = Color("9ee66b")
	_material.set_shader_parameter("magic_color", color)
	if _magic_tween != null and _magic_tween.is_valid(): _magic_tween.kill()
	_set_magic_strength(minf(strength, 1.35) * (0.25 if visual_quality == QUALITY_MEDIUM else 0.38))
	_magic_tween = host.create_tween()
	_magic_tween.tween_method(_set_magic_strength, float(_material.get_shader_parameter("magic_strength")), 0.0, maxf(0.08, duration)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _set_magic_strength(value: float) -> void:
	if _material != null: _material.set_shader_parameter("magic_strength", value)

func settle_death(has_corpse: bool) -> void:
	visual_height = 0.0
	if contact_shadow != null:
		contact_shadow.visible = has_corpse
		contact_shadow.scale = Vector2(profile["contact"]) * Vector2(1.32, 0.58)
		contact_shadow.color.a = 0.34

func restore_alive() -> void:
	visual_height = 0.0
	if contact_shadow != null:
		contact_shadow.visible = true
		contact_shadow.scale = profile["contact"]
		contact_shadow.color.a = 0.48
	_apply_profile_to_shadows()

func body_weight() -> String:
	return profile_name

func visual_profile_name() -> String:
	return class_profile_name

func visual_value(key: String, fallback: Variant = null) -> Variant:
	return class_profile.get(key, fallback)

func cancel_temporary_visuals() -> void:
	if _magic_tween != null and _magic_tween.is_valid(): _magic_tween.kill()
	_set_magic_strength(0.0)
	visual_height = 0.0
	if body_root != null:
		body_root.position = Vector2.ZERO
		body_root.rotation = 0.0
		body_root.scale = Vector2.ONE
