extends Node2D
class_name EffectsLayer

const VisualPolicy = preload("res://data/visual_policy.gd")
const AREA_SEQUENCE := preload("res://scenes/area_spell_sequence.gd")

func spawn_area_sequence(item: Dictionary, centers: Array, origin: Vector2, target: Vector2, tile_size: float, flaming := false) -> Node2D:
	var sequence := AREA_SEQUENCE.new()
	sequence.configure(item, centers, origin, target, tile_size, flaming)
	add_child(sequence)
	return sequence

const FIREBALL_VFX_SCENE := preload("res://scenes/vfx/fireball_vfx.tscn")
## Serifada, igual à referência do protótipo Browser (floating-text usa
## "Palatino Linotype"/"Book Antiqua"/Georgia) — troca o pixel font antigo
## só pro popup de dano/combate, sem mexer no resto da UI.
const COMBAT_FONT := preload("res://assets/fonts/CombatDamageFont.tres")
## Fragmentos reais (não procedurais) da explosão de ossos do Esqueleto da
## Torre — arte fornecida pelo usuário, mesmo tratamento de textura_filter
## NEAREST das outras peças com sprite real (ver HuntressArrowSprite).
const BONE_DEBRIS_SKULL := preload("res://assets/vfx/bone_debris_skull.png")
const BONE_DEBRIS_STICKS := preload("res://assets/vfx/bone_debris_sticks.png")
## MagicMissile.SPEED = 200 px/s em tiles de 16 px. O tabuleiro usa tiles
## quatro vezes maiores, então 800 preserva exatamente 12,5 tiles/s.
const SPD_FROST_WORLD_SPEED := 800.0
const SPD_FROST_EMISSION_INTERVAL := 0.01
const SPD_FROST_PARTICLE_LIFESPAN := 0.5
# Tamanhos escalados pra bater com o protótipo Browser (.floating-text usa
# 1.85rem = ~30px de base, .crit 2.65rem = ~42px, .impact 2.4rem = ~38px) —
# razão ~1.36x sobre os tamanhos antigos (pensados pro KenneyPixel, bem
# menor que a serifada nova), mantendo a hierarquia relativa entre os tipos.
const COMBAT_TEXT_PROFILES := {
	"damage":{"color":Color("ffd27a"),"size":30,"duration":1.05,"motion":"rise"},
	"heavy":{"color":Color("ff9f52"),"size":36,"duration":1.15,"motion":"heavy"},
	"crit":{"color":Color("ff5454"),"size":42,"duration":1.38,"motion":"crit"},
	"miss":{"color":Color("c2c8d0"),"size":29,"duration":1.05,"motion":"side"},
	"block":{"color":Color("d7e3ed"),"size":31,"duration":1.08,"motion":"block"},
	"heal":{"color":Color("73ed91"),"size":31,"duration":1.28,"motion":"float"},
	"regen":{"color":Color("9ddb84"),"size":25,"duration":1.05,"motion":"float"},
	"burned":{"color":Color("ff872e"),"size":30,"duration":1.28,"motion":"flame"},
	"fire":{"color":Color("ff6d35"),"size":27,"duration":1.05,"motion":"flame"},
	"poison":{"color":Color("78d34f"),"size":29,"duration":1.38,"motion":"wobble"},
	"ice":{"color":Color("a8e8ff"),"size":29,"duration":1.12,"motion":"snap"},
	"paralyzed":{"color":Color("68dfff"),"size":30,"duration":1.18,"motion":"snap"},
	"dazed":{"color":Color("ffe27a"),"size":29,"duration":1.18,"motion":"wobble"},
	"bleed":{"color":Color("b93246"),"size":27,"duration":1.22,"motion":"drip"},
	"root":{"color":Color("86b85b"),"size":27,"duration":1.24,"motion":"root"},
	"buff":{"color":Color("e5b5ff"),"size":27,"duration":1.18,"motion":"pop"},
	"status":{"color":Color("d8b5ff"),"size":27,"duration":1.22,"motion":"pop"},
	# Pedido do usuário: revide (Orc/Troll) precisa de um sinal claro e
	# distinto na tela, não só a mesma animação de golpe repetida.
	"counter":{"color":Color("ffbd4a"),"size":34,"duration":1.15,"motion":"snap"},
	"death":{"color":Color("ef6675"),"size":34,"duration":1.45,"motion":"drip"},
}
## Alias de leitura mantido para ferramentas e testes antigos; a fonte real
## agora é única em VisualPolicy.
const IMPACT_INTENSITY := VisualPolicy.IMPACT_PRESETS
var visual_quality: String = VisualPolicy.quality

## Camada cosmética equivalente aos VFX do Browser: projéteis com trajetória,
## cortes, feixes, explosões, varreduras elementais, conjuração e partículas.
## Não altera regras nem aguarda Tweens, mantendo GameState como fonte de verdade.

class VfxShape extends Node2D:
	var kind := "orb"
	var radius := 5.0
	var color := Color.WHITE
	var direction := Vector2.RIGHT
	var phase := 0.0

	func _init(p_kind := "orb", p_radius := 5.0, p_color := Color.WHITE) -> void:
		kind = p_kind
		radius = p_radius
		color = p_color

	func _draw() -> void:
		match kind:
			"pixel":
				draw_rect(Rect2(Vector2(-radius, -radius), Vector2(radius * 2.0, radius * 2.0)), color)
			"ring":
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, color, maxf(2.0, radius * 0.10), true)
			"howl-wave":
				# Uivo de Caça: arco de onda sonora aberto pra cima.
				draw_arc(Vector2.ZERO, radius, -PI * 0.82, -PI * 0.18, 20, color, maxf(2.0, radius * 0.12), true)
			"howl-chevron":
				# Bônus de agilidade: seta dupla subindo.
				draw_polyline(PackedVector2Array([Vector2(-radius, radius * 0.5), Vector2(0, -radius * 0.3), Vector2(radius, radius * 0.5)]), color, 2.5, true)
				draw_polyline(PackedVector2Array([Vector2(-radius, radius * 1.2), Vector2(0, radius * 0.4), Vector2(radius, radius * 1.2)]), Color(color, 0.6), 2.0, true)
			"slash":
				draw_arc(Vector2.ZERO, radius, -1.15, 1.15, 18, color, 3.5, true)
				draw_arc(Vector2.ZERO, radius * 0.72, -0.95, 0.95, 14, Color(color, 0.5), 1.5, true)
			"arrow":
				draw_line(Vector2(-radius, 0), Vector2(radius, 0), color, 2.0, true)
				draw_colored_polygon(PackedVector2Array([Vector2(radius + 5, 0), Vector2(radius - 3, -4), Vector2(radius - 3, 4)]), color.lightened(0.25))
				draw_line(Vector2(-radius, 0), Vector2(-radius + 6, -4), color, 2.0, true)
				draw_line(Vector2(-radius, 0), Vector2(-radius + 6, 4), color, 2.0, true)
			"wind-slash":
				# Corte do Vento (Samurai): meia-lua de energia com miolo claro e
				# um rastro fino atrás — convexa para a frente (+x = direção do voo).
				draw_arc(Vector2(-radius * 0.35, 0), radius * 1.15, -1.05, 1.05, 22, Color(color, 0.30), 11.0, true)
				draw_arc(Vector2(-radius * 0.35, 0), radius * 1.15, -1.05, 1.05, 22, color, 5.0, true)
				draw_arc(Vector2(-radius * 0.35, 0), radius * 1.05, -0.85, 0.85, 18, Color("f4fcff"), 2.0, true)
				draw_line(Vector2(-radius * 1.6, -radius * 0.55), Vector2(-radius * 0.6, -radius * 0.25), Color(color, 0.55), 2.0, true)
				draw_line(Vector2(-radius * 1.6, radius * 0.55), Vector2(-radius * 0.6, radius * 0.25), Color(color, 0.55), 2.0, true)
			"blade":
				draw_colored_polygon(PackedVector2Array([Vector2(-radius, -3), Vector2(radius - 4, -4), Vector2(radius + 6, 0), Vector2(radius - 4, 4), Vector2(-radius, 3)]), color)
				draw_line(Vector2(-radius + 3, -7), Vector2(-radius + 3, 7), Color("8a592f"), 4.0, true)
				draw_line(Vector2(-radius - 4, 0), Vector2(-radius + 3, 0), Color("d6a85f"), 5.0, true)
			"bullet":
				draw_colored_polygon(PackedVector2Array([Vector2(-radius, -3), Vector2(radius, -3), Vector2(radius + 4, 0), Vector2(radius, 3), Vector2(-radius, 3)]), color)
			"stone":
				draw_colored_polygon(PackedVector2Array([Vector2(-radius, 2), Vector2(-radius * 0.5, -radius), Vector2(radius * 0.65, -radius * 0.6), Vector2(radius, radius * 0.5), Vector2(0, radius)]), color)
			"fireball":
				# Silhueta original procedural: núcleo quente e coroa assimétrica.
				draw_circle(Vector2.ZERO, radius, Color("ff6a20"))
				draw_circle(Vector2(-radius * 0.18, -radius * 0.12), radius * 0.64, Color("ffd45a"))
				draw_circle(Vector2(-radius * 0.28, -radius * 0.20), radius * 0.28, Color("fff4b0"))
				for i in 3:
					var flame_angle := phase + float(i) * 2.1
					var flame_at := Vector2(-radius * 0.85, sin(flame_angle) * radius * 0.55)
					draw_colored_polygon(PackedVector2Array([flame_at + Vector2(-radius, 0), flame_at + Vector2(2, -4), flame_at + Vector2(3, 4)]), Color("ff8b24"))
			"bomb":
				draw_circle(Vector2(0, 2), radius, Color("252431"))
				draw_arc(Vector2.ZERO, radius, 0.15, 2.65, 16, Color("77788a"), 2.0, true)
				draw_line(Vector2(radius * 0.35, -radius * 0.75), Vector2(radius * 0.78, -radius * 1.35), Color("9a6a3a"), 3.0, true)
				draw_circle(Vector2(radius * 0.9, -radius * 1.48), 3.0, Color("ffd65a"))
			"smoke":
				draw_circle(Vector2.ZERO, radius, Color(color, 0.58))
				draw_circle(Vector2(radius * 0.45, -radius * 0.25), radius * 0.70, Color(color.lightened(0.12), 0.42))
			"trap":
				draw_circle(Vector2.ZERO, radius, Color("342f2b"))
				draw_arc(Vector2.ZERO, radius * 0.78, 0.0, TAU, 12, color, 2.0, true)
				for i in 4:
					var a := float(i) * PI * 0.5 + PI * 0.25
					draw_colored_polygon(PackedVector2Array([Vector2.from_angle(a) * radius * 0.35, Vector2.from_angle(a - 0.22) * radius, Vector2.from_angle(a + 0.22) * radius]), color)
			"wind":
				draw_arc(Vector2.ZERO, radius, -1.2, 1.2, 16, color, 2.5, true)
				draw_arc(Vector2(-radius * 0.35, radius * 0.3), radius * 0.65, -1.0, 1.05, 12, Color(color, 0.55), 1.5, true)
			"poison":
				draw_circle(Vector2(-radius * 0.35, 1), radius * 0.65, Color(color, 0.7))
				draw_circle(Vector2(radius * 0.35, -radius * 0.25), radius * 0.48, Color(color.lightened(0.18), 0.65))
			"cross":
				draw_line(Vector2(-radius, 0), Vector2(radius, 0), color, 4.0, true)
				draw_line(Vector2(0, -radius), Vector2(0, radius), color, 4.0, true)
			"spark":
				for i in 4:
					var a := phase + float(i) * PI * 0.5
					draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * radius, color, 2.0, true)
			"crystal":
				draw_colored_polygon(PackedVector2Array([Vector2(0, -radius), Vector2(radius * 0.55, 0), Vector2(0, radius), Vector2(-radius * 0.55, 0)]), color)
			"leaf":
				draw_colored_polygon(PackedVector2Array([Vector2(-radius, 0), Vector2(0, -radius * 0.6), Vector2(radius, 0), Vector2(0, radius * 0.6)]), color)
			"bone":
				draw_circle(Vector2(-radius * 0.6, 0), radius * 0.42, color)
				draw_circle(Vector2(radius * 0.6, 0), radius * 0.42, color)
				draw_rect(Rect2(Vector2(-radius * 0.6, -radius * 0.16), Vector2(radius * 1.2, radius * 0.32)), color)
			_:
				draw_circle(Vector2.ZERO, radius, color)
				draw_circle(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.35, Color(1, 1, 1, 0.65))

class HuntressArrowSprite extends Sprite2D:
	const ITEMS := preload("res://assets/third_party/shattered_pixel_dungeon/sprites/items.png")
	func _init() -> void:
		var atlas := AtlasTexture.new()
		atlas.atlas = ITEMS
		# ItemSpriteSheet.SPIRIT_ARROW = xy(3,2)+6 = índice 41.
		atlas.region = Rect2(Vector2(41 % 16, 41 / 16) * 16.0, Vector2(16,16))
		texture = atlas
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		scale = Vector2(2.0, 2.0)

## Porte de MagicMissile.MagicParticle: #88CCFF, light/additive, vida 0,5 s,
## deriva aleatória de ±10 px/s e crescimento de 1 para 4 pixels. Como os
## tiles daqui são 4x maiores, tamanho e velocidade recebem o mesmo fator.
class SpdFrostParticle extends Node2D:
	var age := 0.0
	var velocity := Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
	func _init() -> void:
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive
		z_index = 7
	func _process(delta: float) -> void:
		age += delta
		position += velocity * delta
		queue_redraw()
		if age >= SPD_FROST_PARTICLE_LIFESPAN:
			queue_free()
	func _draw() -> void:
		var remaining := clampf(1.0 - age / SPD_FROST_PARTICLE_LIFESPAN, 0.0, 1.0)
		var pixel_size := (4.0 - remaining * 3.0) * 4.0
		draw_rect(Rect2(Vector2.ONE * -pixel_size * 0.5, Vector2.ONE * pixel_size), Color(0.533, 0.8, 1.0, remaining))

## Porte de MagicMissile.FROST: emissor sem projétil sólido, movimento
## linear e callback exatamente quando alcança o destino.
class SpdFrostMissile extends Node2D:
	var start := Vector2.ZERO
	var destination := Vector2.ZERO
	var flight_time := 0.0
	var elapsed := 0.0
	var emission_clock := SPD_FROST_EMISSION_INTERVAL
	var arrived := Callable()
	func configure(from: Vector2, to: Vector2, callback: Callable) -> void:
		start = from
		destination = to
		position = from
		flight_time = from.distance_to(to) / SPD_FROST_WORLD_SPEED
		arrived = callback
	func _process(delta: float) -> void:
		elapsed += delta
		var ratio := 1.0 if flight_time <= 0.0 else minf(elapsed / flight_time, 1.0)
		position = start.lerp(destination, ratio)
		emission_clock += delta
		while emission_clock >= SPD_FROST_EMISSION_INTERVAL:
			emission_clock -= SPD_FROST_EMISSION_INTERVAL
			var particle := SpdFrostParticle.new()
			particle.position = position
			get_parent().add_child(particle)
		if ratio >= 1.0:
			if arrived.is_valid(): arrived.call()
			queue_free()

## Porte de Speck.TOXIC usado por ToxicGas/ToxicGasRoom no SPD.
class SpdToxicGasSpeck extends Sprite2D:
	const SHEET := preload("res://assets/third_party/shattered_pixel_dungeon/effects/specks.png")
	var lifespan := 2.0
	var age := 0.0
	var drift := Vector2.ZERO
	func _init() -> void:
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET
		# Speck.STEAM = frame 13; frames de 7 px com passo de 8 px.
		atlas.region = Rect2(13 * 8, 0, 7, 7)
		texture = atlas
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		modulate = Color("50ff60")
		rotation = randf() * TAU
		lifespan = randf_range(1.0, 3.0)
		drift = Vector2(randf_range(-5.0, 5.0), randf_range(-13.0, -5.0))
	func _process(delta: float) -> void:
		age += delta
		position += drift * delta
		rotation += deg_to_rad(30.0) * delta
		var remaining := 1.0 - age / lifespan
		modulate.a = clampf(minf(age * 4.0, remaining * 2.0), 0.0, 0.78)
		if age >= lifespan: queue_free()
func _ready() -> void:
	# Sempre acima dos tokens e das auras persistentes.
	z_index = VisualPolicy.Z_EFFECTS_LAYER

func _popup_lane(center: Vector2, requested: int) -> int:
	var used: Dictionary = {}
	for child in get_children():
		if child is Label and child.has_meta("combat_popup"):
			var origin: Vector2 = child.get_meta("popup_origin")
			if origin.distance_to(center) <= VisualPolicy.POPUP_COLLISION_RADIUS:
				used[int(child.get_meta("popup_lane"))] = true
	var lane := clampi(requested, 0, VisualPolicy.MAX_POPUP_LANES - 1)
	while used.has(lane) and lane < VisualPolicy.MAX_POPUP_LANES - 1: lane += 1
	return lane

func spawn_combat_popup(center: Vector2, text: String, kind: String = "damage", delay: float = 0.0, stack_index: int = 0) -> void:
	var profile: Dictionary = COMBAT_TEXT_PROFILES.get(kind, COMBAT_TEXT_PROFILES["status"])
	stack_index = _popup_lane(center, stack_index)
	var label := Label.new()
	label.set_meta("combat_popup", true)
	label.set_meta("popup_origin", center)
	label.set_meta("popup_lane", stack_index)
	label.text = text
	label.z_index = VisualPolicy.Z_COMBAT_TEXT
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var zigzag := 0 if stack_index == 0 else (10 if stack_index % 2 == 1 else -10)
	label.position = center + Vector2(-70 + zigzag, -54 - stack_index * VisualPolicy.POPUP_LANE_HEIGHT)
	label.size = Vector2(140, 34)
	label.add_theme_font_override("font", COMBAT_FONT)
	label.add_theme_font_size_override("font_size", int(profile["size"]))
	label.add_theme_color_override("font_color", profile["color"])
	label.add_theme_color_override("font_shadow_color", Color(0.08, 0.04, 0.10, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.035,0.025,0.045,0.96))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.modulate.a = 0.0 if delay > 0.0 else 1.0
	add_child(label)
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
		tween.tween_property(label, "modulate:a", 1.0, 0.06)
	var duration := float(profile["duration"])
	var motion := String(profile["motion"])
	if motion in ["crit","heavy","pop","snap"]:
		label.scale = Vector2(0.72,0.72) if motion != "snap" else Vector2(1.18,1.18)
		tween.tween_property(label,"scale",Vector2(1.20,1.20) if motion in ["crit","heavy"] else Vector2.ONE,0.09).set_trans(Tween.TRANS_BACK)
		tween.tween_property(label,"scale",Vector2.ONE,0.08)
	if motion == "side":
		label.rotation = -0.10
		tween.parallel().tween_property(label,"position:x",label.position.x+28.0,duration).set_trans(Tween.TRANS_SINE)
	elif motion in ["wobble","block"]:
		tween.parallel().tween_property(label,"position:x",label.position.x+7.0,0.07)
		tween.tween_property(label,"position:x",label.position.x-5.0,0.07)
		tween.tween_property(label,"position:x",label.position.x,0.07)
	elif motion == "drip":
		tween.parallel().tween_property(label,"position:y",label.position.y+22.0,duration)
	elif motion == "root":
		label.position.y += 20.0
		tween.parallel().tween_property(label,"position:y",label.position.y-18.0,duration*0.55)
	else:
		var rise := 28.0 if motion in ["float","flame"] else 38.0
		tween.parallel().tween_property(label,"position:y",label.position.y-rise,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, duration).set_delay(duration * 0.48)
	tween.tween_callback(label.queue_free)

func _popup_color(kind: String) -> Color:
	match kind:
		"crit": return Color("ff5c5c")
		"miss": return Color("c5c5dc")
		"heal": return Color("6fe08a")
		"poison": return Color("c77dff")
		"burned": return Color("ff8a3d")
		"root", "weakened", "slowed": return Color("9ac878")
		"paralyzed", "dazed", "blinded": return Color("8fd8ff")
		"bleed": return Color("e34b62")
		"status": return Color("d8b5ff")
		_: return Color("ffe08a")

func spawn_projectile_visual(from: Vector2, to: Vector2, color: Color, duration: float = 0.36, on_arrive: Callable = Callable(), p_radius: float = 7.0, kind: String = "orb", trajectory: String = "straight") -> Node2D:
	return spawn_projectile(from, to, color, duration, on_arrive, p_radius, kind, trajectory)

func spawn_projectile_release(center: Vector2, direction: Vector2, color: Color) -> void:
	var cue := VfxShape.new("spark", 5.0, Color(color, 0.72))
	cue.position = center
	cue.rotation = direction.angle()
	cue.z_index = 7
	add_child(cue)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(cue, "position", center + direction * 8.0, 0.13)
	tween.tween_property(cue, "scale", Vector2.ONE * 0.25, 0.13)
	tween.tween_property(cue, "modulate:a", 0.0, 0.13)
	tween.set_parallel(false).tween_callback(cue.queue_free)

func spawn_projectile_miss(center: Vector2, direction: Vector2, color: Color) -> void:
	spawn_burst(center, 11.0, Color(color, 0.48), 0.18, "physical")
	for i in 3:
		var mote := VfxShape.new("pixel", 1.4, Color("c4b79b", 0.62))
		mote.position = center + Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))
		mote.z_index = 2
		add_child(mote)
		var drift := create_tween().set_parallel(true)
		drift.tween_property(mote, "position", mote.position - direction * randf_range(3.0, 8.0) + Vector2(randf_range(-4.0, 4.0), randf_range(-7.0, -3.0)), 0.26)
		drift.tween_property(mote, "modulate:a", 0.0, 0.26)
		drift.set_parallel(false).tween_callback(mote.queue_free)

func play_projectile_impact(center: Vector2, direction: Vector2, kind: String, color: Color, hit: bool, critical: bool = false) -> void:
	if not hit:
		spawn_projectile_miss(center, direction, color)
		return
	spawn_special_impact(center, kind, color)
	emit_environment_reaction("projectile_impact", center, direction, "medium" if critical else "light", "fire" if kind == "fire-arrow" else "")
	if critical:
		spawn_burst(center, 24.0, Color(color.lightened(0.28), 0.76), 0.22, "physical")

func spawn_projectile(from: Vector2, to: Vector2, color: Color, duration: float = 0.36, on_arrive: Callable = Callable(), p_radius: float = 7.0, kind: String = "orb", trajectory: String = "auto") -> Node2D:
	if kind == "frost-wand-spd":
		var frost_missile := SpdFrostMissile.new()
		add_child(frost_missile)
		frost_missile.configure(from, to, on_arrive)
		return frost_missile
	var visual_kind := "orb"
	var visual_radius := maxf(p_radius, 7.0)
	match kind:
		"arrow", "bolt":
			visual_kind = "arrow"
			visual_radius = 16.0
		"blade":
			visual_kind = "blade"
			visual_radius = 18.0
		"spit":
			visual_kind = "orb"
			visual_radius = 8.0
			color = Color("dff29a")
		"wind-blade":
			visual_kind = "wind-slash"
			visual_radius = 20.0
			color = Color("a8e6ff")
		"bullet":
			visual_kind = "bullet"
			visual_radius = 10.0
		"stone":
			visual_kind = "stone"
			visual_radius = 9.0
		"ice", "ice-ray", "frost":
			visual_kind = "crystal"
			visual_radius = 11.0
		"bomb":
			visual_kind = "bomb"
			visual_radius = 11.0
		"fireball":
			visual_kind = "fireball"
			visual_radius = 14.0
		"missile", "spark":
			visual_radius = 11.0
		"magic-missile-spd":
			# MagicMissile.MAGIC_MISSILE: emissor branco de 4 px em light mode.
			visual_radius = 5.0
			color = Color.WHITE
		"frost-wand-spd":
			# MagicMissile.FROST / MagicParticle.java: azul #88CCFF.
			visual_radius = 5.0
			color = Color("88ccff")
		"fire-arrow":
			visual_kind = "arrow"
			visual_radius = 17.0
			color = Color("ff7a22")
		"bullet-explosive":
			visual_kind = "bullet"
			visual_radius = 12.0
			color = Color("ff9a25")
	var projectile: Node2D
	if kind == "huntress-arrow-spd":
		projectile = HuntressArrowSprite.new()
	else:
		projectile = VfxShape.new(visual_kind, visual_radius, color)
	projectile.position = from
	projectile.rotation = from.angle_to_point(to)
	projectile.z_as_relative = false
	# Altura média visual: o núcleo pode ficar atrás de copas cuja base esteja
	# abaixo dele, sem afetar trajetória, colisão ou linha de visão.
	projectile.z_index = clampi(roundi((from.y + to.y) * 0.5 + 18.0), 1, 1800)
	if projectile is VfxShape: (projectile as VfxShape).phase = randf() * TAU
	if kind in ["magic-missile-spd", "frost-wand-spd"]:
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		projectile.material = additive
	add_child(projectile)
	var flight_direction := (to - from).normalized()
	# Emissão temporal ao longo da trajetória: pontos separados, nunca uma
	# linha sólida. Fogo usa fagulhas quentes; magia alterna violeta/branco.
	var trail_count := mini(36 if kind in ["magic-missile-spd", "frost-wand-spd"] else 18, maxi(5, int(from.distance_to(to) / (14.0 if kind in ["magic-missile-spd", "frost-wand-spd"] else 34.0))))
	for i in trail_count:
		var frac := float(i + 1) / float(trail_count + 1)
		if kind in ["fire-arrow", "bullet-explosive"]:
			# FlameParticle.java: pequenas chamas quadradas #EE7722, 0,6 s,
			# aceleração vertical -80 e encolhimento. Elas aparecem ao longo
			# do caminho no instante em que a flecha passa por cada ponto.
			var flame_point := from.lerp(to, frac)
			var flame_timer := get_tree().create_timer(duration * frac)
			var flame_amount := 2 if kind == "fire-arrow" else 1
			flame_timer.timeout.connect(func():
				for flame_index in flame_amount:
					var flame := SpdFireParticles.Flame.new()
					flame.position = flame_point + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
					flame.configure(-flight_direction * randf_range(7.0, 16.0) + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)), randf_range(3.2, 5.2), 1.0)
					add_child(flame)
			)
			continue
		var trail_kind := "pixel" if kind in ["magic-missile-spd", "frost-wand-spd"] else ("spark" if kind in ["fireball", "fire-arrow"] else "orb")
		var trail_color := color
		if kind == "fireball": trail_color = Color("ffb52e") if i % 2 == 0 else Color("ff5b20")
		elif kind in ["missile", "spark"]: trail_color = Color("f2ecff") if i % 3 == 0 else Color("9f7cff")
		elif kind == "magic-missile-spd": trail_color = Color(1, 1, 1, 0.5)
		elif kind == "frost-wand-spd": trail_color = Color("88ccff")
		var is_arrow := kind in ["arrow", "huntress-arrow-spd", "fire-arrow", "bolt"]
		var particle_radius := randf_range(0.8, 1.25) if is_arrow else (randf_range(1.0, 2.0) if kind in ["magic-missile-spd", "frost-wand-spd"] else maxf(2.0, visual_radius * 0.28))
		var trail := VfxShape.new(trail_kind, particle_radius, Color(trail_color, 0.40 if is_arrow else 0.72))
		trail.position = from.lerp(to, frac) + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		trail.modulate.a = 0.0
		if kind in ["magic-missile-spd", "frost-wand-spd"]:
			var trail_additive := CanvasItemMaterial.new()
			trail_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			trail.material = trail_additive
		add_child(trail)
		var trail_tween := create_tween()
		trail_tween.tween_interval(duration * frac)
		trail_tween.tween_property(trail, "modulate:a", 0.85, 0.025)
		var particle_lifespan := 0.5 if kind == "frost-wand-spd" else (0.4 if kind == "magic-missile-spd" else 0.20)
		var particle_drift := Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)) if kind in ["magic-missile-spd", "frost-wand-spd"] else Vector2(randf_range(-5.0, 5.0), randf_range(-12.0, -5.0))
		trail_tween.tween_property(trail, "position", trail.position + particle_drift, particle_lifespan)
		trail_tween.parallel().tween_property(trail, "modulate:a", 0.0, particle_lifespan)
		trail_tween.tween_callback(trail.queue_free)
	var tween := create_tween()
	if kind in ["arrow", "huntress-arrow-spd", "fire-arrow", "bolt"]:
		get_tree().create_timer(duration * 0.52).timeout.connect(func(): emit_environment_reaction("projectile_pass", from.lerp(to, 0.52), flight_direction, "light", "fire" if kind == "fire-arrow" else ""))
	if trajectory == "arc" or (trajectory == "auto" and kind in ["bomb", "stone", "flask"]):
		var midpoint := (from + to) * 0.5 + Vector2.UP * minf(70.0, from.distance_to(to) * 0.22)
		tween.tween_property(projectile, "position", midpoint, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(projectile, "position", to, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(projectile, "position", to, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		projectile.queue_free()
		if on_arrive.is_valid(): on_arrive.call()
	)
	if kind == "blade":
		var spin := create_tween()
		spin.tween_property(projectile, "rotation", projectile.rotation + TAU * 4.0, duration).set_trans(Tween.TRANS_LINEAR)
	elif kind == "fireball":
		var pulse := create_tween().set_loops(maxi(1, int(duration / 0.12)))
		pulse.tween_property(projectile, "scale", Vector2.ONE * 1.16, 0.06)
		pulse.tween_property(projectile, "scale", Vector2.ONE * 0.92, 0.06)
	return projectile

## Composição reutilizável exclusiva do novo piloto da Bola de Fogo. O
## callback é emitido pela cena no instante exato em que chega ao destino.
func spawn_fireball(from: Vector2, to: Vector2, speed: float, on_impact: Callable = Callable(), visual_scale: float = 1.0) -> Node2D:
	var fireball := FIREBALL_VFX_SCENE.instantiate() as Node2D
	add_child(fireball)
	fireball.impacted.connect(func(impact_position: Vector2, direction: Vector2):
		if on_impact.is_valid(): on_impact.call(impact_position, direction)
	)
	fireball.call_deferred("launch", from, to, speed, visual_scale)
	return fireball

func spawn_fireball_cast(center: Vector2, direction: Vector2) -> void:
	var hand_position := center + direction * 25.0 + Vector2(0, -9)
	play_magic_cast(center, hand_position, {"color": Color("ff9a32"), "duration": 0.24, "intensity": 1.0, "element": "fire"})

## Base configurável para casts. É puramente cosmética e pode ser reutilizada
## por fogo, gelo, eletricidade e magia arcana sem conhecer regras da magia.
func play_magic_cast(center: Vector2, focus: Vector2, config: Dictionary = {}) -> void:
	var color: Color = config.get("color", Color("b78cff"))
	var duration: float = float(config.get("duration", 0.24))
	var intensity: float = float(config.get("intensity", 1.0))
	spawn_cast_cue(focus, color, String(config.get("element", "arcane")))
	spawn_temporary_light(focus, color, 0.48 * intensity, duration + 0.10, 52.0)
	var amount := clampi(roundi(8.0 * intensity), 5, 14)
	for i in amount:
		var mote := VfxShape.new("spark" if i % 3 == 0 else "pixel", randf_range(1.2, 2.5), Color(color.lightened(randf_range(0.0, 0.32)), 0.82))
		var angle := TAU * float(i) / float(amount) + randf_range(-0.22, 0.22)
		mote.position = focus + Vector2.from_angle(angle) * randf_range(24.0, 43.0) + Vector2(0, randf_range(-8.0, 8.0))
		mote.scale = Vector2.ONE * randf_range(0.65, 1.25)
		mote.z_index = 8
		add_child(mote)
		var gather := create_tween()
		gather.tween_interval(randf_range(0.0, duration * 0.22))
		gather.tween_property(mote, "position", focus + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)), duration * randf_range(0.62, 0.92)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		gather.parallel().tween_property(mote, "scale", Vector2.ONE * 0.25, duration * 0.72)
		gather.parallel().tween_property(mote, "rotation", randf_range(-2.5, 2.5), duration * 0.72)
		gather.tween_callback(mote.queue_free)

func spawn_temporary_light(center: Vector2, color: Color, energy: float = 0.65, duration: float = 0.30, radius: float = 64.0) -> PointLight2D:
	var lights: Array[Node] = get_tree().get_nodes_in_group("temporary_visual_lights")
	if lights.size() >= VisualPolicy.temporary_light_budget():
		var oldest: Node = lights[0]
		if is_instance_valid(oldest):
			# Retira já do orçamento; queue_free só conclui no fim do frame.
			oldest.remove_from_group("temporary_visual_lights")
			oldest.queue_free()
	var charge_light := PointLight2D.new()
	charge_light.add_to_group("temporary_visual_lights")
	charge_light.position = center
	charge_light.color = color
	charge_light.energy = energy
	charge_light.texture = _radial_light_texture(roundi(radius))
	charge_light.texture_scale = 0.72
	charge_light.z_index = 6
	add_child(charge_light)
	var light_tween := create_tween().set_parallel(true)
	light_tween.tween_property(charge_light, "energy", 0.0, duration).set_delay(duration * 0.42)
	light_tween.tween_property(charge_light, "scale", Vector2.ONE * 1.18, duration)
	light_tween.set_parallel(false).tween_callback(charge_light.queue_free)
	return charge_light

func spawn_shockwave(center: Vector2, color: Color, radius: float = 56.0, duration: float = 0.28) -> void:
	var wave := VfxShape.new("ring", radius, Color(color, 0.72))
	wave.position = center
	wave.scale = Vector2.ONE * 0.08
	wave.z_index = 5
	add_child(wave)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(wave, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(wave, "modulate:a", 0.0, duration)
	tween.set_parallel(false).tween_callback(wave.queue_free)

func spawn_temporary_ground_decal(center: Vector2, color: Color, duration: float = 2.4, radius: float = 26.0) -> void:
	var decal := VfxShape.new("orb", radius, Color(color, 0.24))
	decal.position = center + Vector2(0, 17)
	decal.scale = Vector2(1.0, 0.30)
	decal.z_index = -1
	add_child(decal)
	var fade := create_tween()
	fade.tween_interval(duration * 0.55)
	fade.tween_property(decal, "modulate:a", 0.0, duration * 0.45)
	fade.parallel().tween_property(decal, "scale", Vector2(0.82, 0.22), duration * 0.45)
	fade.tween_callback(decal.queue_free)

func spawn_fireball_impact(center: Vector2, direction: Vector2) -> void:
	# Flash branco/amarelo de 60 ms e luz quente curta.
	var flash := VfxShape.new("orb", 24.0, Color("fff8c8"))
	flash.position = center
	flash.scale = Vector2.ONE * 0.18
	flash.z_index = 10
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.material = additive
	add_child(flash)
	var ft := create_tween().set_parallel(true)
	ft.tween_property(flash, "scale", Vector2.ONE * 1.6, 0.06)
	ft.tween_property(flash, "modulate:a", 0.0, 0.08)
	ft.set_parallel(false).tween_callback(flash.queue_free)
	var impact_light := PointLight2D.new()
	impact_light.position = center
	impact_light.color = Color("ffb043")
	impact_light.energy = 1.25
	impact_light.texture = _radial_light_texture(84)
	impact_light.z_index = 9
	add_child(impact_light)
	var lt := create_tween()
	lt.tween_property(impact_light, "energy", 0.0, 0.18)
	lt.tween_callback(impact_light.queue_free)
	spawn_shockwave(center, Color("ffb34d"), 58.0, 0.30)
	spawn_temporary_ground_decal(center, Color("24120d"), 2.6, 29.0)
	emit_environment_reaction("explosion", center, direction, "heavy", "fire")
	# BlastParticle-like: poucos fragmentos #EE7722 com queda, mais sparks.
	spawn_burst(center, 52.0, Color("ee7722"), 0.34, "fireball")
	# WandOfFireblast usa burst de BlastParticle e SmokeParticle ao redor do
	# alvo. Mantemos a linguagem, com contagem menor adequada ao tabuleiro.
	for i in 18:
		var blast := SpdFireParticles.Blast.new()
		blast.position = center
		blast.z_index = -1 if i % 3 == 0 else (7 if i % 3 == 1 else 13)
		blast.configure(randf_range(-PI, PI), randf_range(32.0, 64.0), randf_range(0.30, 0.82))
		add_child(blast)
	for i in 7:
		var smoke := SpdFireParticles.Smoke.new()
		smoke.position = center + Vector2(randf_range(-12.0, 12.0), randf_range(-6.0, 8.0))
		smoke.z_index = 5 if i % 2 == 0 else 11
		smoke.configure(Vector2(randf_range(-4.0, 4.0), randf_range(-8.0, 5.0)), randf_range(6.0, 10.0), randf_range(0.60, 1.0))
		add_child(smoke)
	# O shake usa CameraShake2D em Main; esta composição não move o tabuleiro.

func _radial_light_texture(pixel_size: int) -> Texture2D:
	var texture := GradientTexture2D.new()
	texture.width = pixel_size
	texture.height = pixel_size
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	texture.gradient = gradient
	return texture

func _shake_parent(intensity: float, duration: float) -> void:
	var target := get_parent() as Node2D
	if target == null: return
	var original := target.position
	var shake := create_tween()
	shake.tween_property(target, "position", original + Vector2(intensity, -intensity * 0.5), duration * 0.25)
	shake.tween_property(target, "position", original + Vector2(-intensity * 0.65, intensity * 0.45), duration * 0.25)
	shake.tween_property(target, "position", original + Vector2(intensity * 0.3, -intensity * 0.2), duration * 0.25)
	shake.tween_property(target, "position", original, duration * 0.25)

func spawn_burst(center: Vector2, max_radius: float, color: Color, duration: float = 0.3, kind: String = "generic") -> void:
	var ring := VfxShape.new("ring", max_radius, color)
	ring.position = center
	ring.scale = Vector2.ONE * 0.12
	add_child(ring)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.set_parallel(false).tween_callback(ring.queue_free)
	var count := 16 if kind in ["fireball", "bomb"] else 9
	for i in count:
		var particle_kind := "crystal" if kind in ["ice", "frost"] else ("leaf" if kind in ["nature", "wind"] else "spark")
		var particle := VfxShape.new(particle_kind, 4.0 if count > 10 else 3.0, color.lightened(0.18))
		particle.position = center
		particle.phase = float(i) * 0.4
		# Três planos visuais: resíduos atrás/próximos ao chão, fragmentos no
		# plano médio e partículas altas passando à frente do alvo.
		particle.z_index = -1 if i % 3 == 0 else (6 if i % 3 == 1 else 12)
		add_child(particle)
		var angle := TAU * float(i) / float(count) + randf_range(-0.18, 0.18)
		var distance := max_radius * randf_range(0.55, 1.05)
		var height := randf_range(0.0, 8.0) if particle.z_index < 0 else (randf_range(8.0, 20.0) if particle.z_index < 10 else randf_range(20.0, 38.0))
		var pt := create_tween().set_parallel(true)
		pt.tween_property(particle, "position", center + Vector2.from_angle(angle) * distance + Vector2.UP * height, duration)
		pt.tween_property(particle, "modulate:a", 0.0, duration)
		pt.tween_property(particle, "rotation", randf_range(-2.0, 2.0), duration)
		pt.set_parallel(false).tween_callback(particle.queue_free)

func spawn_beam(from: Vector2, to: Vector2, color: Color, kind: String = "beam", duration: float = 0.24) -> void:
	var line := Line2D.new()
	line.width = 5.0 if kind == "lightning" else 8.0
	line.default_color = color
	line.antialiased = true
	var points := PackedVector2Array([from])
	var segments := 10 if kind == "lightning" else 5
	var normal := (to - from).normalized().orthogonal()
	for i in range(1, segments):
		var p := from.lerp(to, float(i) / float(segments))
		p += normal * (randf_range(-9.0, 9.0) if kind == "lightning" else sin(float(i) * 1.7) * 5.0)
		points.append(p)
	points.append(to)
	line.points = points
	add_child(line)
	var glow := line.duplicate() as Line2D
	glow.width = line.width * 2.8
	glow.default_color = Color(color, 0.22)
	add_child(glow)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(line, "modulate:a", 0.0, duration)
	tween.tween_property(glow, "modulate:a", 0.0, duration)
	tween.set_parallel(false).tween_callback(line.queue_free)
	tween.tween_callback(glow.queue_free)
	if kind == "lightning":
		# Ramificações curtas e faíscas tornam o arco irregular e elétrico.
		var direction := (to - from).normalized()
		var branch_normal := direction.orthogonal()
		for i in 3:
			var branch_from := from.lerp(to, 0.25 + float(i) * 0.2)
			var branch_to := branch_from + direction * randf_range(8.0, 18.0) + branch_normal * randf_range(-22.0, 22.0)
			var branch := Line2D.new()
			branch.width = 2.0
			branch.default_color = Color(color, 0.8)
			branch.points = PackedVector2Array([branch_from, branch_from.lerp(branch_to, 0.5) + branch_normal * randf_range(-4.0, 4.0), branch_to])
			add_child(branch)
			var bt := create_tween()
			bt.tween_property(branch, "modulate:a", 0.0, duration * 0.8)
			bt.tween_callback(branch.queue_free)
		spawn_electric_sparks(to, color)

func spawn_electric_sparks(center: Vector2, color: Color = Color("b9edff")) -> void:
	for i in 10:
		var spark := VfxShape.new("spark", randf_range(3.0, 6.0), color)
		spark.position = center
		spark.phase = randf() * TAU
		add_child(spark)
		var target := center + Vector2.from_angle(TAU * float(i) / 10.0 + randf_range(-0.2, 0.2)) * randf_range(14.0, 32.0)
		var st := create_tween().set_parallel(true)
		st.tween_property(spark, "position", target, 0.22)
		st.tween_property(spark, "modulate:a", 0.0, 0.28)
		st.set_parallel(false).tween_callback(spark.queue_free)

## Conexão elétrica configurável e pronta para saltos futuros. Cada par de
## pontos é um trecho independente; nenhuma regra escolhe alvos aqui.
func spawn_lightning_connection(points: Array, color: Color = Color("d7f6ff"), intensity: float = 1.0) -> void:
	if points.size() < 2: return
	for index in range(points.size() - 1):
		var from: Vector2 = points[index]
		var to: Vector2 = points[index + 1]
		var delay := float(index) * 0.055
		get_tree().create_timer(delay).timeout.connect(func():
			spawn_beam(from, to, color, "lightning", 0.10)
			spawn_temporary_light(to, Color("bdefff"), 0.85 * intensity, 0.16, 58.0)
			spawn_electric_sparks(to, color)
			spawn_shockwave(to, Color(color, 0.58), 24.0, 0.14)
			spawn_temporary_ground_decal(to, Color("273840"), 1.3, 17.0)
			emit_environment_reaction("lightning", to, (to - from).normalized(), "medium", "lightning")
		)

func spawn_ice_impact(center: Vector2, intensity: float = 1.0) -> void:
	spawn_temporary_light(center, Color("9de9ff"), 0.55 * intensity, 0.26, 62.0)
	spawn_shockwave(center, Color("bcefff"), 38.0 * intensity, 0.20)
	spawn_temporary_ground_decal(center, Color("9ed9e8"), 2.0, 27.0)
	var amount := clampi(roundi(9.0 * intensity), 6, 14)
	for i in amount:
		var shard := VfxShape.new("crystal", randf_range(3.0, 6.5), Color("d9f8ff" if i % 2 == 0 else "79cce8"))
		var angle := TAU * float(i) / float(amount) + randf_range(-0.18, 0.18)
		shard.position = center + Vector2.from_angle(angle) * randf_range(2.0, 8.0)
		shard.rotation = angle + PI * 0.5
		shard.scale = Vector2(0.25, 0.15)
		shard.z_index = -1 if i % 3 == 0 else (7 if i % 3 == 1 else 12)
		add_child(shard)
		var target := center + Vector2.from_angle(angle) * randf_range(20.0, 43.0) + Vector2.UP * randf_range(3.0, 24.0)
		var crack := create_tween()
		crack.tween_property(shard, "scale", Vector2.ONE * randf_range(0.8, 1.25), 0.075).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		crack.parallel().tween_property(shard, "position", target, 0.18)
		crack.tween_interval(randf_range(0.12, 0.30))
		crack.tween_property(shard, "modulate:a", 0.0, 0.22)
		crack.parallel().tween_property(shard, "scale", Vector2.ZERO, 0.22)
		crack.tween_callback(shard.queue_free)
	spawn_burst(center, 31.0, Color("bcefff"), 0.24, "frost")
	emit_environment_reaction("ice", center, Vector2.UP, "medium" if intensity >= 0.8 else "light", "ice")

func spawn_slash(center: Vector2, color: Color, swing: String = "slash") -> void:
	var slash := VfxShape.new("slash", 24.0, color)
	slash.position = center
	slash.rotation = -0.7 if swing != "stab" else 0.0
	slash.scale = Vector2.ONE * 0.35
	add_child(slash)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(slash, "scale", Vector2.ONE * 1.35, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(slash, "modulate:a", 0.0, 0.22)
	tween.set_parallel(false).tween_callback(slash.queue_free)

func spawn_cast_cue(center: Vector2, color: Color, kind: String) -> void:
	var ring := VfxShape.new("ring", 22.0, color)
	ring.position = center
	ring.scale = Vector2.ONE * 1.5
	add_child(ring)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * 0.45, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(ring, "rotation", PI, 0.25)
	tween.tween_property(ring, "modulate:a", 0.0, 0.3)
	tween.set_parallel(false).tween_callback(ring.queue_free)
	for i in 6:
		var spark := VfxShape.new("spark", 5.0, color)
		spark.position = center + Vector2.from_angle(TAU * float(i) / 6.0) * 30.0
		add_child(spark)
		var st := create_tween().set_parallel(true)
		st.tween_property(spark, "position", center, 0.24)
		st.tween_property(spark, "modulate:a", 0.0, 0.28)
		st.set_parallel(false).tween_callback(spark.queue_free)

func spawn_sweep(centers: Array, color: Color, kind: String, origin: Vector2) -> void:
	for center_variant in centers:
		var center: Vector2 = center_variant
		var delay := origin.distance_to(center) / 900.0
		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(func():
			if kind == "lightning": spawn_beam(origin, center, color, kind, 0.2)
			elif kind == "ground": spawn_ground_crack(center, color)
			elif kind == "wind": spawn_gust(center, color)
			elif kind == "poison": spawn_toxic_gas(center, true)
			elif kind == "log": spawn_log_sweep(center, origin, color)
			elif kind == "nature": spawn_regen_cue(center, color)
			else: spawn_burst(center, 20.0, color, 0.3, kind)
		)

func spawn_special_impact(center: Vector2, kind: String, color: Color) -> void:
	match kind:
		"arrow":
			spawn_burst(center, 18.0, Color("dec58f"), 0.24, "physical")
		"fire-arrow":
			spawn_fire_arrow_impact(center)
		"bullet":
			spawn_burst(center, 15.0, Color("e8e0c8"), 0.20, "physical")
		"bullet-explosive":
			spawn_explosive_shot_impact(center)
		"bomb":
			spawn_explosion(center)
		"ice", "ice-ray", "beam", "frost":
			spawn_ice_impact(center)
		"missile", "spark":
			spawn_burst(center, 30.0, Color("c9a3ff"), 0.40, "arcane")
		"magic-missile-spd":
			spawn_spd_wand_impact(center, Color.WHITE, 10)
		"frost-wand-spd":
			# WandOfFrost nível-base: buffedLvl()/2 + 2 = duas partículas.
			spawn_spd_wand_impact(center, Color("99ccff"), 2)
		"lightning":
			spawn_electric_sparks(center)
			spawn_burst(center, 30.0, Color("a8dfff"), 0.30, "lightning")
		"fireball":
			spawn_burst(center, 46.0, Color("ff7024"), 0.40, "fireball")
		_:
			spawn_burst(center, 22.0, color, 0.24, kind)

func spawn_spd_wand_impact(center: Vector2, color: Color, amount: int) -> void:
	# WandOfMagicMissile/WandOfFrost chamam sprite.burst com partículas
	# brancas ou #99CCFF após HIT_MAGIC. Quadrados aditivos preservam o pixel
	# art e se dispersam radialmente sem criar uma explosão genérica grande.
	for i in amount:
		var particle := VfxShape.new("pixel", randf_range(1.2, 2.4), color)
		particle.position = center + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 6.0)
		particle.z_index = 8
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		particle.material = additive
		add_child(particle)
		var direction := Vector2.from_angle(randf() * TAU)
		var burst := create_tween().set_parallel(true)
		burst.tween_property(particle, "position", particle.position + direction * randf_range(16.0, 34.0), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		burst.tween_property(particle, "modulate:a", 0.0, 0.42)
		burst.tween_property(particle, "scale", Vector2.ZERO, 0.42)
		burst.set_parallel(false).tween_callback(particle.queue_free)

func spawn_fire_arrow_impact(center: Vector2) -> void:
	# Impacto menor que a Bola de Fogo, baseado em BlastParticle.java:
	# fragmentos de 8 px, #EE7722, velocidade 32–64 e gravidade +50.
	var flash := VfxShape.new("orb", 11.0, Color("fff2a6"))
	flash.position = center
	flash.z_index = 9
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.material = additive
	add_child(flash)
	var flash_tween := create_tween().set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2.ONE * 1.7, 0.055)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.09)
	flash_tween.set_parallel(false).tween_callback(flash.queue_free)
	for i in 9:
		var blast := SpdFireParticles.Blast.new()
		blast.position = center
		blast.configure(randf_range(-PI, PI), randf_range(32.0, 64.0), randf_range(0.32, 0.72))
		add_child(blast)
	for i in 4:
		var flame := SpdFireParticles.Flame.new()
		flame.position = center + Vector2(randf_range(-7.0, 7.0), randf_range(-5.0, 6.0))
		flame.configure(Vector2(randf_range(-8.0, 8.0), randf_range(-10.0, 1.0)), randf_range(3.5, 6.0), 1.1)
		add_child(flame)
	for i in 3:
		var smoke := SpdFireParticles.Smoke.new()
		smoke.position = center + Vector2(randf_range(-7.0, 7.0), randf_range(-4.0, 5.0))
		smoke.configure(Vector2(randf_range(-5.0, 5.0), randf_range(-8.0, -2.0)), randf_range(4.0, 7.0), randf_range(0.55, 0.85))
		add_child(smoke)
	spawn_burst(center, 22.0, Color("ee7722"), 0.22, "fireball")

func spawn_fire_weapon_launch(center: Vector2, direction: Vector2, kind: String) -> void:
	var amount := 7 if kind == "fire-arrow" else 5
	for i in amount:
		var flame := SpdFireParticles.Flame.new()
		flame.position = center + direction * randf_range(7.0, 18.0) + direction.orthogonal() * randf_range(-5.0, 5.0)
		flame.configure(-direction * randf_range(4.0, 12.0) + Vector2(randf_range(-3.0, 3.0), randf_range(-5.0, 1.0)), randf_range(3.2, 5.5), 1.1)
		add_child(flame)
	var launch_flash := VfxShape.new("orb", 8.0, Color("fff0a0"))
	launch_flash.position = center + direction * 15.0
	launch_flash.z_index = 8
	add_child(launch_flash)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(launch_flash, "scale", Vector2.ONE * 1.6, 0.06)
	tween.tween_property(launch_flash, "modulate:a", 0.0, 0.11)
	tween.set_parallel(false).tween_callback(launch_flash.queue_free)

func spawn_explosive_shot_impact(center: Vector2) -> void:
	# O Tiro Explosivo usa a mesma família da WandOfFireblast, mas numa
	# escala intermediária e sem criar qualquer dano de área adicional.
	spawn_fire_arrow_impact(center)
	for i in 7:
		var blast := SpdFireParticles.Blast.new()
		blast.position = center
		blast.configure(randf_range(-PI, PI), randf_range(38.0, 66.0), randf_range(0.35, 0.72))
		add_child(blast)
	for i in 3:
		var smoke := SpdFireParticles.Smoke.new()
		smoke.position = center + Vector2(randf_range(-7.0, 7.0), randf_range(-5.0, 5.0))
		smoke.configure(Vector2(randf_range(-5.0, 5.0), randf_range(-9.0, -2.0)), randf_range(5.0, 8.0), randf_range(0.55, 0.9))
		add_child(smoke)

func spawn_fireblast_area(centers: Array, origin: Vector2) -> void:
	# A onda visual se espalha do centro como o burst da WandOfFireblast.
	# Cada célula recebe poucas partículas; não existe lógica de combate aqui.
	for center_variant in centers:
		var center: Vector2 = center_variant
		if center.distance_to(origin) < 2.0: continue
		var delay := center.distance_to(origin) / 620.0
		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(func(): _spawn_fireblast_tile(center))

func _spawn_fireblast_tile(center: Vector2) -> void:
	for i in 7:
		var flame := SpdFireParticles.Flame.new()
		flame.position = center + Vector2(randf_range(-18.0, 18.0), randf_range(-10.0, 16.0))
		flame.configure(Vector2(randf_range(-7.0, 7.0), randf_range(-9.0, 1.0)), randf_range(3.2, 6.0), 1.05)
		add_child(flame)
	for i in 3:
		var blast := SpdFireParticles.Blast.new()
		blast.position = center
		blast.configure(randf_range(-PI, PI), randf_range(28.0, 52.0), randf_range(0.28, 0.60))
		add_child(blast)
	for i in 2:
		var smoke := SpdFireParticles.Smoke.new()
		smoke.position = center + Vector2(randf_range(-12.0, 12.0), randf_range(-5.0, 10.0))
		smoke.configure(Vector2(randf_range(-4.0, 4.0), randf_range(-7.0, 0.0)), randf_range(4.0, 7.0), randf_range(0.50, 0.82))
		add_child(smoke)
	spawn_burst(center, 18.0, Color(0.93, 0.47, 0.13, 0.68), 0.20, "fireball")

func spawn_explosion(center: Vector2) -> void:
	# Clarão rápido -> fragmentos -> fumaça curta. Todos os nós se liberam.
	var flash := VfxShape.new("orb", 28.0, Color("fff2b0"))
	flash.position = center
	flash.scale = Vector2.ONE * 0.2
	add_child(flash)
	var ft := create_tween().set_parallel(true)
	ft.tween_property(flash, "scale", Vector2.ONE * 1.7, 0.10).set_trans(Tween.TRANS_EXPO)
	ft.tween_property(flash, "modulate:a", 0.0, 0.16)
	ft.set_parallel(false).tween_callback(flash.queue_free)
	spawn_burst(center, 48.0, Color("ff7626"), 0.34, "bomb")
	for i in 7:
		var smoke := VfxShape.new("smoke", randf_range(7.0, 13.0), Color("56515b"))
		smoke.position = center + Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0))
		smoke.modulate.a = 0.0
		add_child(smoke)
		var delay := 0.08 + float(i) * 0.018
		var st := create_tween()
		st.tween_interval(delay)
		st.tween_property(smoke, "modulate:a", 0.65, 0.08)
		st.tween_property(smoke, "position", smoke.position + Vector2(randf_range(-12.0, 12.0), -32.0), 0.52)
		st.parallel().tween_property(smoke, "scale", Vector2.ONE * 1.55, 0.52)
		st.parallel().tween_property(smoke, "modulate:a", 0.0, 0.52)
		st.tween_callback(smoke.queue_free)

## Explosão de ossos do Esqueleto da Torre (`boneExplosion`, ver
## GameState._trigger_bone_explosion/bone_explosion_events). Antes usava o
## `spawn_burst` genérico cinza; agora dois fragmentos GRANDES (crânio e
## feixe de ossos, arte real fornecida pelo usuário) saltam em arcos opostos
## com giro e queda, num punhado de estilhaços pequenos (VfxShape "bone"
## procedural, mesma cor) preenche o miolo da explosão, e uma poeira curta
## assenta por cima — igual em espírito ao spawn_explosion (fogo), só que no
## tom osso/terra do Esqueleto.
func spawn_bone_explosion(center: Vector2) -> void:
	var flash := VfxShape.new("orb", 20.0, Color("f1e7cf"))
	flash.position = center
	flash.scale = Vector2.ONE * 0.2
	add_child(flash)
	var ft := create_tween().set_parallel(true)
	ft.tween_property(flash, "scale", Vector2.ONE * 1.5, 0.09).set_trans(Tween.TRANS_EXPO)
	ft.tween_property(flash, "modulate:a", 0.0, 0.14)
	ft.set_parallel(false).tween_callback(flash.queue_free)
	var ring := VfxShape.new("ring", BoardView.TILE_SIZE * 0.62, Color("d8cba8"))
	ring.position = center
	ring.scale = Vector2.ONE * 0.15
	add_child(ring)
	var rt := create_tween().set_parallel(true)
	rt.tween_property(ring, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring, "modulate:a", 0.0, 0.32)
	rt.set_parallel(false).tween_callback(ring.queue_free)
	var chunks := [
		{"tex": BONE_DEBRIS_SKULL, "scale": 0.34, "angle": randf_range(-2.5, -0.6)},
		{"tex": BONE_DEBRIS_STICKS, "scale": 0.30, "angle": randf_range(0.6, 2.5)},
	]
	for chunk_data in chunks:
		var chunk := Sprite2D.new()
		chunk.texture = chunk_data["tex"]
		chunk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		chunk.position = center
		chunk.scale = Vector2.ONE * float(chunk_data["scale"])
		chunk.z_index = 12
		add_child(chunk)
		var angle: float = chunk_data["angle"]
		var landing := center + Vector2.from_angle(angle) * randf_range(30.0, 46.0)
		var apex := center.lerp(landing, 0.5) + Vector2(0, -34.0)
		var arc := create_tween()
		arc.tween_property(chunk, "position", apex, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		arc.tween_property(chunk, "position", landing, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		arc.parallel().tween_property(chunk, "rotation", (1.0 if angle > 0.0 else -1.0) * randf_range(5.0, 8.0), 0.38)
		arc.tween_interval(0.28)
		arc.tween_property(chunk, "modulate:a", 0.0, 0.30)
		arc.tween_callback(chunk.queue_free)
	for i in 7:
		var shard := VfxShape.new("bone", randf_range(3.0, 5.5), Color("e8dcc0"))
		shard.position = center
		add_child(shard)
		var shard_angle := TAU * float(i) / 7.0 + randf_range(-0.3, 0.3)
		var shard_target := center + Vector2.from_angle(shard_angle) * randf_range(26.0, 52.0)
		var st := create_tween().set_parallel(true)
		st.tween_property(shard, "position", shard_target, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		st.tween_property(shard, "rotation", randf_range(-4.0, 4.0), 0.30)
		st.tween_property(shard, "modulate:a", 0.0, 0.36)
		st.set_parallel(false).tween_callback(shard.queue_free)
	for i in 4:
		var puff := VfxShape.new("smoke", randf_range(6.0, 10.0), Color("6b6255"))
		puff.position = center + Vector2(randf_range(-10.0, 10.0), randf_range(-4.0, 6.0))
		puff.modulate.a = 0.0
		add_child(puff)
		var pt := create_tween()
		pt.tween_interval(0.05 + float(i) * 0.03)
		pt.tween_property(puff, "modulate:a", 0.45, 0.08)
		pt.tween_property(puff, "position", puff.position + Vector2(randf_range(-8.0, 8.0), -20.0), 0.40)
		pt.parallel().tween_property(puff, "scale", Vector2.ONE * 1.4, 0.40)
		pt.parallel().tween_property(puff, "modulate:a", 0.0, 0.40)
		pt.tween_callback(puff.queue_free)

func spawn_poison_application(center: Vector2) -> void:
	spawn_toxic_gas(center, false)
	for i in 7:
		var droplet := VfxShape.new("poison", randf_range(2.5, 5.0), Color("a970e8" if i % 2 == 0 else "7bdc42"))
		droplet.position = center + Vector2(randf_range(-18.0, 18.0), randf_range(4.0, 20.0))
		add_child(droplet)
		var dt := create_tween().set_parallel(true)
		dt.tween_property(droplet, "position", droplet.position + Vector2(randf_range(-5.0, 5.0), randf_range(-35.0, -18.0)), 0.52)
		dt.tween_property(droplet, "modulate:a", 0.0, 0.52)
		dt.set_parallel(false).tween_callback(droplet.queue_free)

func spawn_water_step(center: Vector2, strong: bool = false) -> void:
	var ripple := VfxShape.new("ring", 24.0 if strong else 17.0, Color(0.78, 0.96, 1.0, 0.78))
	ripple.position = center + Vector2(0, 18)
	ripple.scale = Vector2(0.12, 0.06)
	add_child(ripple)
	var rt := create_tween().set_parallel(true)
	rt.tween_property(ripple, "scale", Vector2(1.2, 0.48), 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rt.tween_property(ripple, "modulate:a", 0.0, 0.48)
	rt.set_parallel(false).tween_callback(ripple.queue_free)
	var drops := 6 if strong else 3
	for i in drops:
		var drop := VfxShape.new("orb", 2.5, Color("b8efff"))
		drop.position = center + Vector2(randf_range(-12.0, 12.0), 17.0)
		add_child(drop)
		var target := drop.position + Vector2(randf_range(-9.0, 9.0), randf_range(-18.0, -9.0))
		var wt := create_tween().set_parallel(true)
		wt.tween_property(drop, "position", target, 0.20)
		wt.tween_property(drop, "modulate:a", 0.0, 0.30)
		wt.set_parallel(false).tween_callback(drop.queue_free)

## ETAPA 19 — `direction`/`element`/`intensity` são opcionais (compatíveis
## com os chamados antigos, que só passavam center/profile/strong) e só
## afetam os materiais novos (wood/stone/metal): debris nasce enviesado na
## direção do golpe (regra 7/45) e ganha uma leve reação por elemento
## (regra 31-39), sem criar nenhum tipo de dano ou marca permanente.
func spawn_surface_step(center: Vector2, profile: String, strong: bool = false, direction: Vector2 = Vector2.ZERO, element: String = "", intensity: String = "") -> void:
	match profile:
		"water":
			spawn_water_step(center, strong)
		"wood", "stone", "metal":
			_spawn_material_debris(center, profile, strong, direction, element, intensity)
		"dirt":
			for i in (5 if strong else 3):
				var dust := VfxShape.new("orb", randf_range(1.5, 3.0), Color(0.55, 0.42, 0.27, 0.42))
				dust.position = center + Vector2(randf_range(-9.0, 9.0), randf_range(13.0, 20.0))
				dust.z_index = -1
				add_child(dust)
				var drift := create_tween().set_parallel(true)
				drift.tween_property(dust, "position", dust.position + Vector2(randf_range(-7.0, 7.0), randf_range(-9.0, -4.0)), 0.28)
				drift.tween_property(dust, "modulate:a", 0.0, 0.28)
				drift.set_parallel(false).tween_callback(dust.queue_free)
		"grass":
			for i in (3 if strong else 2):
				var leaf := VfxShape.new("leaf", randf_range(1.5, 2.6), Color(0.42, 0.66, 0.25, 0.48))
				leaf.position = center + Vector2(randf_range(-10.0, 10.0), randf_range(14.0, 20.0))
				leaf.z_index = -1 if i == 0 else 5
				add_child(leaf)
				var flutter := create_tween().set_parallel(true)
				flutter.tween_property(leaf, "position", leaf.position + Vector2(randf_range(-8.0, 8.0), randf_range(-12.0, -5.0)), 0.34)
				flutter.tween_property(leaf, "rotation", randf_range(-2.0, 2.0), 0.34)
				flutter.tween_property(leaf, "modulate:a", 0.0, 0.34)
				flutter.set_parallel(false).tween_callback(leaf.queue_free)

## ETAPA 19 — WOOD/STONE/METAL. Reaproveita MaterialVisualProfiles pra
## quantidade/cor/tipo de fragmento; nunca decide dano nem cria estado
## persistente (todo nó criado aqui se desfaz sozinho em menos de 1s).
func _spawn_material_debris(center: Vector2, material: String, strong: bool, direction: Vector2, element: String, intensity: String) -> void:
	var profile := MaterialVisualProfiles.for_material(material)
	# Regra 7/45 — debris continua na direção do golpe/projétil (não volta
	# pro atacante): `direction` já chega como o vetor de deslocamento do
	# impacto (ex.: atacante->alvo em melee), então o debris usa ele direto.
	var away := direction.normalized() if direction != Vector2.ZERO else Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	var tier := intensity if intensity != "" else ("heavy" if strong else "light")
	var amount := MaterialVisualProfiles.amount_for(material, tier)
	var debris_kind := String(profile["debris_kind"])
	var base_color: Color = profile["debris_color"]
	if debris_kind != "":
		for i in amount:
			var spread := away.rotated(randf_range(-0.9, 0.9)) * randf_range(14.0, 30.0)
			var chip := VfxShape.new(debris_kind, randf_range(2.0, 4.2) if material != "stone" else randf_range(2.6, 4.6), base_color)
			chip.position = center + Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))
			chip.rotation = randf_range(0.0, TAU)
			chip.z_index = roundi(center.y) + 6
			add_child(chip)
			var fall := create_tween().set_parallel(true)
			fall.tween_property(chip, "position", chip.position + spread + Vector2(0, randf_range(10.0, 20.0)), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			fall.tween_property(chip, "rotation", chip.rotation + randf_range(-4.0, 4.0), 0.34)
			fall.tween_property(chip, "modulate:a", 0.0, 0.30).set_delay(0.10)
			fall.set_parallel(false).tween_callback(chip.queue_free)
	if randf() < float(profile["spark_chance"]):
		spawn_electric_sparks(center, Color("f2f0e0"))
	# Sinal do elemento por cima do fragmento físico — mesma cor já usada
	# pelo resto do jogo pra cada elemento, sem inventar paleta nova.
	match element:
		"fire":
			for i in (2 if strong else 1):
				var flame := SpdFireParticles.Flame.new()
				flame.position = center + Vector2(randf_range(-5.0, 5.0), randf_range(-4.0, 2.0))
				flame.configure(away * randf_range(6.0, 14.0), randf_range(3.0, 4.5), 0.7)
				add_child(flame)
		"ice", "frost":
			spawn_temporary_ground_decal(center, Color("b8efff"), 0.8, 16.0 if material == "wood" else 12.0)
		"lightning":
			spawn_electric_sparks(center, Color("d7f6ff"))

func emit_environment_reaction(event_type: String, center: Vector2, direction: Vector2 = Vector2.RIGHT, intensity: String = "light", element: String = "") -> void:
	var board := get_parent() as BoardView
	if board == null or board.state == null: return
	# ETAPA 18 — evento visual grande "abaixa" brevemente a vida ambiental
	# decorativa, pra ela nunca competir com o combate (regra 58-59).
	if intensity in ["heavy", "signature", "epic"]: board.ambient_life_duck()
	var preset: Dictionary = VisualPolicy.impact(intensity)
	var quality_scale := VisualPolicy.quality_scale()
	var reaction: Dictionary = board.react_environment(center, float(preset["radius"]), direction, float(preset["strength"]), element)
	var leaf_budget := mini(8, roundi(float(preset["leaves"]) * quality_scale))
	var emitted := 0
	for tree_position in reaction["trees"]:
		if emitted >= leaf_budget: break
		var leaf := VfxShape.new("leaf", randf_range(2.0, 3.2), Color("76a84b" if element != "fire" else "b98542", 0.72))
		leaf.position = tree_position + Vector2(randf_range(-14.0, 14.0), randf_range(-12.0, 8.0))
		leaf.z_index = 12 if emitted % 2 == 0 else 5
		add_child(leaf)
		var away := (leaf.position - center).normalized()
		if away == Vector2.ZERO: away = direction.normalized()
		var fall := create_tween().set_parallel(true)
		fall.tween_property(leaf, "position", leaf.position + away * randf_range(18.0, 34.0) + Vector2(randf_range(-7.0, 7.0), randf_range(18.0, 32.0)), 0.62)
		fall.tween_property(leaf, "rotation", randf_range(-4.0, 4.0), 0.62)
		fall.tween_property(leaf, "modulate:a", 0.0, 0.62).set_delay(0.24)
		fall.set_parallel(false).tween_callback(leaf.queue_free)
		emitted += 1
	if event_type != "projectile_pass":
		for water_position in reaction["water"]:
			if element == "lightning":
				spawn_electric_sparks(water_position, Color("c9f7ff"))
			elif element == "ice":
				spawn_temporary_ground_decal(water_position, Color("b8efff"), 0.9, 22.0)
			else:
				spawn_water_step(water_position, intensity in ["heavy", "epic"])
	var tile := Vector2i(floori(center.x / BoardView.TILE_SIZE), floori(center.y / BoardView.TILE_SIZE))
	if board.state.in_bounds(tile.x, tile.y):
		# ETAPA 19 — antes só distinguia água/grama/terra; agora consulta o
		# Material Reaction System (madeira/pedra continuam sem regra nova,
		# só leem terrain_at/structure_at que já existiam).
		var surface := board.material_at(tile.x, tile.y)
		if event_type in ["melee_impact", "heavy_impact", "death"]:
			spawn_surface_step(center, surface, intensity in ["heavy", "signature", "epic"], direction, element, intensity)

func spawn_trap_marker(center: Vector2, color: Color = Color("c8a86a")) -> Node2D:
	var marker := VfxShape.new("trap", 13.0, color)
	marker.position = center + Vector2(0, 17)
	marker.z_index = -1
	add_child(marker)
	return marker

func spawn_trap_trigger(center: Vector2) -> void:
	var marker := VfxShape.new("trap", 15.0, Color("ff6b4a"))
	marker.position = center + Vector2(0, 17)
	add_child(marker)
	var tt := create_tween().set_parallel(true)
	tt.tween_property(marker, "scale", Vector2.ONE * 1.65, 0.18).set_trans(Tween.TRANS_BACK)
	tt.tween_property(marker, "modulate:a", 0.0, 0.34)
	tt.set_parallel(false).tween_callback(marker.queue_free)
	spawn_burst(center, 24.0, Color("ff8b55"), 0.28, "physical")

func spawn_gust(center: Vector2, color: Color) -> void:
	var gust := VfxShape.new("wind", 25.0, color)
	gust.position = center - Vector2(18, 0)
	gust.scale = Vector2(0.5, 0.8)
	add_child(gust)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(gust, "position", center + Vector2(22, 0), 0.42).set_trans(Tween.TRANS_SINE)
	tween.tween_property(gust, "scale", Vector2(1.3, 1.0), 0.42)
	tween.tween_property(gust, "modulate:a", 0.0, 0.42)
	tween.set_parallel(false).tween_callback(gust.queue_free)

func spawn_cloud(center: Vector2, color: Color) -> void:
	for i in 5:
		var puff := VfxShape.new("poison", randf_range(8.0, 14.0), color)
		puff.position = center + Vector2(randf_range(-15, 15), randf_range(-8, 8))
		puff.modulate.a = 0.75
		add_child(puff)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(puff, "position", puff.position + Vector2(randf_range(-8, 8), -28), 0.58)
		tween.tween_property(puff, "scale", Vector2.ONE * 1.6, 0.58)
		tween.tween_property(puff, "modulate:a", 0.0, 0.58)
		tween.set_parallel(false).tween_callback(puff.queue_free)

func spawn_toxic_gas(center: Vector2, dense: bool = true) -> void:
	# ToxicGas.java usa pour(..., 0.4f). Aqui o cone é instantâneo, então
	# distribuímos uma curta sequência equivalente sobre cada tile atingido.
	var count := 9 if dense else 5
	for i in count:
		var speck := SpdToxicGasSpeck.new()
		speck.position = center + Vector2(randf_range(-25.0, 25.0), randf_range(-18.0, 24.0))
		speck.modulate.a = 0.0
		add_child(speck)
		if i > 0:
			speck.process_mode = Node.PROCESS_MODE_DISABLED
			var timer := get_tree().create_timer(float(i) * 0.055)
			timer.timeout.connect(func(): speck.process_mode = Node.PROCESS_MODE_INHERIT)

func spawn_ground_crack(center: Vector2, color: Color) -> void:
	var crack := Line2D.new()
	crack.width = 3.0
	crack.default_color = color
	crack.points = PackedVector2Array([center + Vector2(-24, 8), center + Vector2(-11, -5), center + Vector2(-3, 5), center + Vector2(9, -8), center + Vector2(24, 2)])
	add_child(crack)
	var tween := create_tween()
	tween.tween_property(crack, "modulate:a", 0.0, 0.52)
	tween.tween_callback(crack.queue_free)
	spawn_burst(center, 20.0, color, 0.34, "ground")

func spawn_log_sweep(center: Vector2, origin: Vector2, color: Color) -> void:
	var log_piece := VfxShape.new("stone", 13.0, color)
	log_piece.position = center
	log_piece.rotation = origin.angle_to_point(center)
	log_piece.scale = Vector2(1.7, 0.65)
	add_child(log_piece)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(log_piece, "rotation", log_piece.rotation + PI, 0.36)
	tween.tween_property(log_piece, "modulate:a", 0.0, 0.4)
	tween.set_parallel(false).tween_callback(log_piece.queue_free)

func spawn_heal_absorb(center: Vector2, color: Color = Color("6fe08a")) -> void:
	for i in 8:
		var mote := VfxShape.new("cross", 4.0, color)
		var angle := TAU * float(i) / 8.0
		mote.position = center + Vector2.from_angle(angle) * 32.0
		add_child(mote)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(mote, "position", center, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(mote, "modulate:a", 0.0, 0.42)
		tween.set_parallel(false).tween_callback(mote.queue_free)
	spawn_burst(center, 25.0, color, 0.38, "heal")

## Uivo de Caça: ondas sonoras em arco que nascem acima da cabeça do lobo,
## sobem, abrem e somem, uma atrás da outra.
func spawn_howl_waves(center: Vector2, color: Color = Color("dfe8ff")) -> void:
	for i in 4:
		var wave := VfxShape.new("howl-wave", 9.0, Color(color, 0.9))
		wave.position = center + Vector2(0, -34)
		wave.z_index = 6
		wave.modulate.a = 0.0
		add_child(wave)
		var tween := create_tween()
		tween.tween_interval(float(i) * 0.16)
		tween.tween_property(wave, "modulate:a", 1.0, 0.06)
		tween.tween_property(wave, "position", wave.position + Vector2(0, -46), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(wave, "scale", Vector2.ONE * 2.4, 0.7)
		tween.parallel().tween_property(wave, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
		tween.tween_callback(wave.queue_free)

## Aliado atingido pelo Uivo: anel curto nos pés e setas subindo (+AGI).
func spawn_howl_buff(center: Vector2, color: Color = Color("ffd66b")) -> void:
	spawn_shockwave(center + Vector2(0, 14), color, 26.0, 0.32)
	var chevron := VfxShape.new("howl-chevron", 7.0, color)
	chevron.position = center + Vector2(0, -6)
	chevron.z_index = 6
	add_child(chevron)
	var tween := create_tween()
	tween.tween_property(chevron, "position", chevron.position + Vector2(0, -30), 0.6).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(chevron, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tween.tween_callback(chevron.queue_free)

func spawn_regen_cue(center: Vector2, color: Color = Color("70e895")) -> void:
	for i in 5:
		var leaf := VfxShape.new("leaf", 5.0, color)
		leaf.position = center + Vector2((float(i) - 2.0) * 8.0, 18.0)
		add_child(leaf)
		var tween := create_tween()
		tween.tween_interval(float(i) * 0.04)
		tween.tween_property(leaf, "position", leaf.position + Vector2(0, -48), 0.58).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(leaf, "modulate:a", 0.0, 0.58)
		tween.tween_callback(leaf.queue_free)

func spawn_resurrection(from: Vector2, to: Vector2) -> void:
	var gold := Color("ffd978")
	spawn_cast_cue(from, gold, "resurrect")
	spawn_beam(from, to, gold, "nature", 0.65)
	var column := Line2D.new()
	column.width = 18.0
	column.default_color = Color(gold, 0.55)
	column.points = PackedVector2Array([to + Vector2(0, 34), to + Vector2(0, -58)])
	add_child(column)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(column, "width", 3.0, 0.85)
	tween.tween_property(column, "modulate:a", 0.0, 0.85)
	tween.set_parallel(false).tween_callback(column.queue_free)
	spawn_burst(to, 42.0, gold, 0.8, "resurrect")
