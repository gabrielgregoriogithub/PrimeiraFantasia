extends Node2D
## Camada única, sem partículas/nós por alvo. Coordenadas locais do tabuleiro.
## Somente apresentação: nenhum RNG de combate, HP, status ou custo aqui.
signal impact
signal completed

@export var duration := 2.7
@export var impact_time := 1.1
@export var effect_scale := 1.0
@export var intensity := 1.0
var tile_size := 64.0
var centers: Array = []
var origin := Vector2.ZERO
var target := Vector2.ZERO
var element := "fire"
var shape := "point-aoe"
var flaming := false
var elapsed := 0.0
var impacted := false
var max_distance := 1.0

static func element_for(item: Dictionary) -> String:
	var mode: String = item.get("targetMode", "")
	if item.get("burstKind", "") == "frost": return "ice"
	if mode == "arrow-rain": return "arrows"
	if mode == "pierce-line": return "arrows-line"
	if mode == "crescent-arc": return "slash"
	if mode == "dust-square": return "dust"
	if mode == "heal-cross": return "heal-aoe"
	if mode == "cone-windstorm": return "wind"
	if mode in ["cone-ice", "freeze-aoe"]: return "ice"
	if mode == "line-aoe": return "lightning"
	if mode in ["heal-aoe", "regen-aoe", "cure-aoe", "mana-aoe"]: return mode
	if mode == "creeping-line": return "roots"
	if item.get("burstKind", "") == "sound" or String(item.get("kind", "")).begins_with("bard-song"): return "sound"
	if mode == "cone-poison" or item.get("kind", "") in ["boss-poison", "decay-pulse", "poison-potion"]: return "poison"
	if mode == "trap": return "trap"
	if mode in ["self-attack", "cardinal-blast", "trample"] and item.get("damageType", "") != "fire": return "physical"
	if mode == "inflict-wounds": return "dark"
	return "fire"

func configure(item: Dictionary, points: Array, start: Vector2, end: Vector2, size: float, fire := false) -> void:
	centers = points
	origin = start
	target = end
	tile_size = size
	element = element_for(item)
	shape = item.get("targetMode", "")
	flaming = fire
	duration = float(item.get("visualDuration", 3.85 if element == "arrows" else 2.7))
	impact_time = 0.75 if element == "arrows" else 1.1
	effect_scale = float(item.get("visualScale", 1.0))
	intensity = clampf(float(item.get("visualIntensity", 1.0)), 0.3, 1.5)
	for center in centers: max_distance = maxf(max_distance, origin.distance_to(center))
	z_index = 12

func _process(delta: float) -> void:
	elapsed += delta
	if not impacted and elapsed >= impact_time:
		impacted = true
		impact.emit()
	queue_redraw()
	if elapsed >= duration:
		completed.emit()
		queue_free()

func palette() -> Color:
	match element:
		"poison": return Color("86c940")
		"ice": return Color("83daff")
		"wind": return Color("c4e4dd")
		"lightning": return Color("b2d8ff")
		"heal-aoe", "regen-aoe", "roots": return Color("80d780")
		"mana-aoe": return Color("839aff")
		"cure-aoe": return Color("95efd3")
		"dark": return Color("c875e5")
		"sound": return Color("e3b6ff")
		"physical", "trap", "arrows-line", "arrows": return Color("e4c695")
		"slash": return Color("aee7ff")
		"dust": return Color("c9a56a")
	return Color("ff7929")

func _draw() -> void:
	var color := palette()
	var s := tile_size * effect_scale
	var fade := clampf((duration - elapsed) / 0.8, 0.0, 1.0)
	# Preparação: arcos de concentração com trajetória legível.
	if elapsed < impact_time:
		var charge := clampf(elapsed / 0.35, 0.0, 1.0)
		for ring in 3:
			draw_arc(origin + Vector2(0, -s * 0.18), s * (0.17 + ring * 0.10) * charge, elapsed * 3 + ring, elapsed * 3 + ring + 4.4, 28, Color(color, 0.65), 2.5, true)
		if shape == "point-aoe":
			var t := clampf((elapsed - 0.3) / (impact_time - 0.3), 0.0, 1.0)
			var pos := origin.lerp(target, t) + Vector2(0, -sin(t * PI) * s * 0.5)
			for tail in range(10, 0, -1):
				var p := origin.lerp(target, maxf(0, t - tail * 0.025))
				draw_circle(p, s * (0.27 - tail * 0.018), Color(color, 0.16))
			_flame(pos, s * 0.46, 1.0, elapsed * 13) if element == "fire" else draw_arc(pos, s * 0.35, 0, TAU, 32, color, 4, true)
		elif element == "arrows":
			for n in 3:
				_arrow(origin + Vector2(n * 9 - 9, -s * 0.25 - clampf((elapsed - 0.18) / 0.5, 0, 1) * s * 3), Vector2.UP, s * 0.55, 1.0)
	# A forma principal ocupa exclusivamente os tiles da geometria real.
	for index in centers.size():
		var p: Vector2 = centers[index]
		var seed_value := float(index) * 2.39996
		var arrival := 0.35 + 0.65 * origin.distance_to(p) / max_distance
		if shape == "point-aoe": arrival = impact_time
		if element == "arrows":
			_rain_tile(p, index, s, fade)
			continue
		var age := elapsed - arrival
		if age < 0: continue
		var grow := clampf(age / 0.28, 0, 1)
		var a := grow * fade * intensity
		# Base em losango não inventa uma esfera de dano fora da área.
		var ground := PackedVector2Array([p + Vector2(-s * 0.43, 0), p + Vector2(0, -s * 0.25), p + Vector2(s * 0.43, 0), p + Vector2(0, s * 0.25)])
		draw_colored_polygon(ground, Color(color, a * 0.12))
		match element:
			"fire":
				for layer in 3:
					var offset := Vector2(sin(seed_value + layer * 2.1) * s * 0.20, layer * -s * 0.07)
					_flame(p + offset, s * (0.68 - layer * 0.08) * grow, a * 0.90, elapsed * 8 + seed_value + layer)
				_smoke(p + Vector2(0, -age * s * 0.19), s * 0.38, a * 0.18, seed_value)
				_fragments(p, age, s, Color("ffd17c"), a, true)
			"poison":
				for cloud in 4:
					var q := p + Vector2(sin(seed_value + cloud * 1.8 + elapsed) * s * 0.23, -s * 0.1 + cos(seed_value + cloud + elapsed * 1.4) * s * 0.14)
					_smoke(q, s * (0.42 + sin(elapsed * 2 + cloud) * 0.05), a * 0.28, seed_value + cloud, color)
				for bubble in 3:
					var phase := fposmod(age * 0.7 + bubble * 0.33 + seed_value, 1.0)
					var q := p + Vector2(sin(seed_value + bubble * 3) * s * 0.27, -phase * s * 0.56)
					draw_arc(q, s * 0.06 * (1 - phase * 0.5), 0, TAU, 12, Color("d3ec85", a * (1 - phase)), 1.6, true)
			"ice":
				for crystal in 3:
					var q := p + Vector2((crystal - 1) * s * 0.23, sin(seed_value + crystal) * s * 0.1)
					_crystal(q, s * (0.46 + 0.17 * sin(seed_value + crystal)) * grow, a)
				_smoke(p + Vector2(sin(elapsed + seed_value) * s * 0.15, 0), s * 0.35, a * 0.18, seed_value, Color("ccedff"))
				_fragments(p, age, s, color, a * 0.8)
			"wind":
				var direction := (target - origin).normalized()
				for ribbon in 4:
					var points := PackedVector2Array()
					var phase := fposmod(elapsed * 1.8 + ribbon * 0.25 + seed_value, 1.0)
					for segment in 17:
						var t := float(segment) / 16
						points.append(p + direction * ((t + phase - 0.9) * s * 0.75) + direction.orthogonal() * (sin(t * 5 + elapsed * 4 + ribbon) * s * 0.12 + (ribbon - 1.5) * s * 0.13))
					draw_polyline(points, Color(color, a * 0.18), 9 + ribbon, true)
					draw_polyline(points, Color(color, a * 0.68), 2.5 + ribbon * 0.5, true)
				if index % 3 == 0:
					var spiral := PackedVector2Array()
					for k in 40:
						var t := k / 39.0
						spiral.append(p + Vector2.from_angle(t * TAU * 1.6 + elapsed * 4) * t * s * 0.45)
					draw_polyline(spiral, Color(color, a * 0.65), 3, true)
				_fragments(p, age, s, Color("bda987"), a * 0.65)
			"lightning":
				var points := PackedVector2Array()
				for segment in 9:
					points.append(p + Vector2(sin(segment * 17 + floor(elapsed * 15) + seed_value) * s * 0.23, (segment / 8.0 - 0.5) * s * 0.8))
				draw_polyline(points, Color(color, a * 0.23), 12, true)
				draw_polyline(points, Color("eefaff", a), 3, true)
				_fragments(p, age, s, color, a)
			"roots", "dark":
				for branch in 4:
					var points := PackedVector2Array()
					for segment in 12:
						var t := segment / 11.0
						points.append(p + Vector2(sin(t * 5 + branch + seed_value) * s * 0.32 * t, -t * s * 0.65 * grow))
					draw_polyline(points, Color(color.darkened(0.35), a), 6, true)
					draw_polyline(points, Color(color, a * 0.8), 2, true)
				_smoke(p, s * 0.34, a * 0.22, seed_value, color)
			"arrows-line":
				_arrow(p, (target - origin).normalized(), s * 0.6, a)
				_fragments(p, age, s, color, a)
			"dust":
				# Nuvem de Poeira (Vestruz): nuvens marrons rodopiando em cada quadrado 3x3.
				for cloud in 5:
					var q := p + Vector2(sin(seed_value + cloud * 1.7 + elapsed * 0.8) * s * 0.28, cos(seed_value + cloud * 2.3 + elapsed) * s * 0.16 - s * 0.08)
					_smoke(q, s * (0.40 + sin(elapsed * 2 + cloud) * 0.05), a * 0.30, seed_value + cloud, Color("b8955f"))
				_fragments(p, age, s, Color("d9bc86"), a)
			"slash":
				# Corte Crescente (Samurai): meia-lua de energia em cada quadrado do
				# arco, varrendo na direção do golpe e deixando faíscas.
				var sweep_dir := (target - origin).normalized()
				if sweep_dir == Vector2.ZERO: sweep_dir = Vector2.RIGHT
				var facing_angle := sweep_dir.angle()
				var sweep := clampf(age / 0.22, 0.0, 1.0)
				for arc in 3:
					var arc_radius := s * (0.24 + arc * 0.09)
					var from_angle := facing_angle - 1.25 + sweep * 0.5
					draw_arc(p, arc_radius, from_angle, from_angle + 2.5 * sweep, 22, Color(color, a * (0.85 - arc * 0.2)), 6.0 - arc * 1.6, true)
				draw_arc(p, s * 0.26, facing_angle - 1.0, facing_angle + 1.0, 18, Color("f4fcff", a), 2.0, true)
				_fragments(p, age, s, Color("dff6ff"), a)
			"physical", "trap":
				for arc in 3:
					draw_arc(p, s * (0.22 + arc * 0.10) * grow, seed_value + elapsed * 3, seed_value + elapsed * 3 + 3.0, 24, Color(color, a * 0.65), 4 - arc, true)
				_fragments(p, age, s, color, a)
				_smoke(p, s * 0.3, a * 0.20, seed_value)
			_:
				for ring in 3:
					var phase := fposmod(age * 0.7 + ring * 0.33, 1.0)
					draw_arc(p + Vector2(0, -phase * s * 0.5), s * (0.13 + phase * 0.26), 0, TAU, 32, Color(color, a * (1 - phase)), 3, true)
				if element != "sound":
					var q := p + Vector2(0, -s * 0.2)
					draw_line(q - Vector2(s * 0.14, 0), q + Vector2(s * 0.14, 0), Color(color, a), 5, true)
					draw_line(q - Vector2(0, s * 0.14), q + Vector2(0, s * 0.14), Color(color, a), 5, true)
		if elapsed >= impact_time and elapsed < impact_time + 0.45:
			var shock := (elapsed - impact_time) / 0.45
			draw_arc(p, s * 0.44 * shock, 0, TAU, 28, Color(color, (1 - shock) * 0.6), 2, true)

func _flame(p: Vector2, size: float, a: float, phase: float) -> void:
	if size < 0.5 or a <= 0.001: return
	var polygon := PackedVector2Array()
	for i in 16:
		var angle := TAU * i / 16.0
		var radius := size * (0.72 + 0.18 * sin(angle * 5 + phase))
		polygon.append(p + Vector2(cos(angle) * radius * 0.58, sin(angle) * radius - size * 0.22))
	draw_colored_polygon(polygon, Color("e94317", a * 0.60))
	for i in 4:
		var q := p + Vector2(sin(phase + i * 1.9) * size * 0.20, -size * i * 0.12)
		draw_colored_polygon(PackedVector2Array([q + Vector2(-size * 0.22, 0), q + Vector2(sin(phase + i) * size * 0.25, -size * (0.7 + 0.2 * sin(phase))), q + Vector2(size * 0.22, 0)]), Color("ffad32", a * 0.70))
	draw_circle(p + Vector2(0, -size * 0.14), size * 0.16, Color("fff0a5", a))

func _smoke(p: Vector2, size: float, a: float, seed_value: float, tint := Color("665d64")) -> void:
	for lobe in 5:
		var offset := Vector2.from_angle(lobe * 1.256 + elapsed * 0.5 + seed_value) * size * 0.38
		draw_circle(p + offset, size * (0.65 + sin(seed_value + lobe) * 0.1), Color(tint.lightened(lobe * 0.025), a))

func _crystal(p: Vector2, height: float, a: float) -> void:
	if height < 0.5 or a <= 0.001: return
	var tip := p + Vector2(height * 0.12, -height)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-height * 0.19, 0), tip, p + Vector2(height * 0.24, -height * 0.25), p + Vector2(height * 0.16, 0)]), Color("55afd8", a * 0.8))
	draw_colored_polygon(PackedVector2Array([p, tip, p + Vector2(height * 0.24, -height * 0.25)]), Color("c9f3ff", a * 0.9))
	draw_line(p, tip, Color("f0fcff", a), 1.5, true)

func _fragments(p: Vector2, age: float, s: float, tint: Color, a: float, rising := false) -> void:
	for n in 5:
		var t := fposmod(age * 0.9 + n * 0.2, 1.0)
		var direction := Vector2.from_angle(n * 2.4 + p.x)
		var q := p + direction * t * s * 0.40 + Vector2(0, (-t if rising else -sin(t * PI)) * s * 0.34)
		draw_line(q, q + direction * s * 0.065, Color(tint, a * (1 - t)), 2.5, true)

func _arrow(p: Vector2, direction: Vector2, length: float, a: float) -> void:
	var side := direction.orthogonal()
	var tail := p - direction * length
	if flaming:
		draw_line(tail - direction * length * 0.35, p, Color(1, 0.28, 0.02, a * 0.5), 8, true)
		_flame(tail, length * 0.4, a, elapsed * 15 + p.x)
	draw_line(tail, p, Color("302b34", a), 5, true)
	draw_line(tail, p, Color("e5bd7d", a), 2.5, true)
	draw_colored_polygon(PackedVector2Array([p + direction * 7, p - direction * 6 + side * 5, p - direction * 6 - side * 5]), Color("f0f5fa", a))
	for sign_value in [-1, 1]:
		draw_line(tail + direction * 9, tail + side * sign_value * 5, Color("f0e7cd", a), 3, true)

func _rain_tile(p: Vector2, index: int, s: float, fade: float) -> void:
	# Dez ondas por tile durante 3 s reais, mesmo em tiles vazios.
	for wave in 20:
		var landing := impact_time + wave * 0.15 + (index % 3) * 0.022
		var age := elapsed - landing
		var offset := Vector2(sin(index * 4.7 + wave * 2.4), cos(index * 2.9 + wave * 4.1)) * s * 0.27
		var q := p + offset
		if age >= -0.32 and age < 0:
			_arrow(q + Vector2(age * s * 0.5, age * s * 6), Vector2(0.08, 1).normalized(), s * 0.62, fade)
		elif age >= 0 and age < 0.30:
			_arrow(q, Vector2(0.08, 1).normalized(), s * 0.30, (1 - age / 0.30) * fade)
			_fragments(q, age * 2, s * 0.5, Color("ffb453") if flaming else Color("bbae95"), (1 - age / 0.30) * fade, flaming)
			if flaming: _flame(q, s * 0.24, (1 - age / 0.3) * fade, wave)
			else: _smoke(q, s * 0.13, (1 - age / 0.3) * 0.2, wave)
