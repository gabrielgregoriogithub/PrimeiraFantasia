extends Node

## Motor de áudio sintetizado (Fase 5, sexta fatia): porte de playTone/
## playNoise/playFilterSweep, a tabela SFX (game.js:3488-3629) e a trilha
## ambiente (scheduleMusicPad/BassPulse/DrumHit/MelodyNote, game.js:3230-3390)
## — sem nenhum arquivo de áudio, tudo PCM16 estéreo sintetizado em runtime.
## Diferença de arquitetura proposital: o JS monta um grafo Web Audio
## descartável por som (osciladores/filtros/ganho agendados no tempo real do
## AudioContext); aqui cada som é "renderizado" inteiro de uma vez num
## PackedByteArray e tocado por um AudioStreamPlayer efêmero — mesmo
## resultado audível, sem precisar de scheduler sample-accurate. Autoload
## (ver project.godot) — qualquer cena chama `AudioEngine.play_sfx(key, pan)`
## sem precisar de referência.
##
## O filtro de ruído é uma aproximação de 1 polo (lowpass/highpass, bandpass
## = os dois em série) — bom o bastante pra textura do efeito, não uma
## réplica de resposta em frequência do BiquadFilterNode original. A trilha
## ambiente também simplifica um pouco o timbre (pad e baixo sem o filtro
## passa-baixa dedicado do JS) mas preserva a estrutura: progressão Am-F-C-G,
## baixo pulsante, tambor de guerra no mesmo pulso, melodia esparsa.

const SAMPLE_RATE := 44100
const SPD_BURNING_WAV_PATH := "res://assets/third_party/shattered_pixel_dungeon/sounds/burning.wav"
const SPD_GAS_WAV_PATH := "res://assets/third_party/shattered_pixel_dungeon/sounds/gas.wav"
const SPD_FIREBALL_CAST_WAV_PATH := "res://assets/third_party/shattered_pixel_dungeon/sounds/chargeup.wav"
const SPD_FIREBALL_RELEASE_WAV_PATH := "res://assets/third_party/shattered_pixel_dungeon/sounds/zap.wav"
const SPD_FIREBALL_IMPACT_WAV_PATH := "res://assets/third_party/shattered_pixel_dungeon/sounds/blast.wav"
const SPD_STONE_STEP_WAV_PATH := "res://assets/third_party/shattered_pixel_dungeon/sounds/step.wav"
const SPD_PRISON_MUSIC_PATH := "res://assets/third_party/shattered_pixel_dungeon/music/prison_1.ogg"
const SPD_WAND_ZAP_WAV_PATH := "res://assets/third_party/shattered_pixel_dungeon/sounds/wand_zap.wav"
const SPD_WAND_HIT_MAGIC_WAV_PATH := "res://assets/third_party/shattered_pixel_dungeon/sounds/wand_hit_magic.wav"
const SPD_SFX_EVENTS := {
	"bow_shoot":["atk_spiritbow.mp3"], "crossbow_shoot":["atk_crossbow.mp3"],
	"arrow_hit":["hit_arrow.mp3"], "miss":["miss.mp3"],
	"slash_hit":["hit_slash.mp3","hit.mp3"], "stab_hit":["hit_stab.mp3"],
	"crush_hit":["hit_crush.mp3","hit_strong.mp3"], "strong_hit":["hit_strong.mp3"],
	"parry":["hit_parry.mp3"], "magic_hit":["hit_magic.mp3"],
	"fire_status":["burning.mp3"], "poison_status":["gas.mp3"], "ice_status":["shatter.mp3"],
	"lightning":["lightning.mp3"], "ray":["ray.mp3"],
	"nature":["plant.mp3"], "wind":["puff.mp3"], "debuff":["debuff.mp3"],
	"heal":["charms.mp3"], "resurrect":["evoke.mp3"], "blast":["blast.mp3"],
	"bomb_throw":["mine.mp3"], "death":["death.mp3"], "charge":["chargeup.mp3"],
}
const SFX_ALIASES := {
	"bowRelease":"bow_shoot","crossbowRelease":"crossbow_shoot","arrowImpact":"arrow_hit",
	"miss":"miss","magicImpact":"magic_hit","physicalImpact":"slash_hit",
	# Pedido do usuário: revide precisa de um som que se distingue claramente
	# de um bloqueio/aparo comum (antes "counter" tocava o mesmo hit_parry.mp3
	# do BLOCK) — usa o mesmo golpe forte de um crítico/machadada.
	"counter":"strong_hit",
	"poison":"poison_status","toxicGasSpd":"poison_status","burningSpd":"fire_status",
	"freeze":"ice_status","iceCast":"ray","lightning":"lightning","nature":"nature",
	# Pedido do usuário: "heal" não usa mais o charms.mp3 do SPD — troca pelo
	# sino sintetizado mais divino/lírico (ver o case "heal" no match abaixo).
	"blast":"blast","flaskThrow":"bomb_throw","trapTrigger":"debuff",
	"stun":"debuff","blind":"debuff","root":"nature","death":"death",
	"goblinLowBlow":"strong_hit","goblinPoison":"poison_status","goblinSand":"debuff",
	"goblinDash":"charge","goblinAmbush":"strong_hit","goblinBarrel":"blast","goblinPlayDead":"nature",
}

# Equivalente a MUSIC_TARGET_VOLUME (0.2 de amplitude) em decibéis.
const MUSIC_TARGET_VOLUME_DB := -13.98
const MUSIC_CHORDS := [
	{"notes": [220.0, 261.63, 329.63], "root": 110.0}, # Am
	{"notes": [174.61, 220.0, 261.63], "root": 87.31}, # F
	{"notes": [261.63, 329.63, 392.0], "root": 130.81}, # C
	{"notes": [196.0, 246.94, 293.66], "root": 98.0}, # G
]
const MUSIC_CHORD_DURATION := 3.2
const MUSIC_MELODY_POOL := [440.0, 523.25, 587.33, 659.25, 392.0, 349.23]
const MUSIC_BASS_PULSES_PER_CHORD := 4
const MUSIC_DRUM_INTERVAL := MUSIC_CHORD_DURATION / 4.0

var _music_time: float = 0.0
var _music_chord_index: int = 0
var _music_next_chord_time: float = 0.0
var _music_next_bass_time: float = 0.0
var _music_next_drum_time: float = MUSIC_DRUM_INTERVAL
var _music_next_melody_time: float = 1.6
var _duck_tween: Tween
var _spd_burning_stream: AudioStreamWAV
var _spd_gas_stream: AudioStreamWAV
var _spd_fireball_cast_stream: AudioStreamWAV
var _spd_fireball_release_stream: AudioStreamWAV
var _spd_fireball_impact_stream: AudioStreamWAV
var _spd_stone_step_stream: AudioStreamWAV
var _scenario_music_player: AudioStreamPlayer
var _tower_music_active := false
var _spd_wand_zap_stream: AudioStreamWAV
var _spd_wand_hit_magic_stream: AudioStreamWAV
var _sfx_event_cache: Dictionary = {}

# --- Setup -------------------------------------------------------------

func _ready() -> void:
	_ensure_bus("SFX", "Master")
	_ensure_bus("Music", "Master")
	var idx := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(idx, -80.0)
	var tween := create_tween()
	tween.tween_method(func(db: float): AudioServer.set_bus_volume_db(idx, db), -80.0, MUSIC_TARGET_VOLUME_DB, 2.0)
	_spd_burning_stream = _load_pcm_wav(SPD_BURNING_WAV_PATH)
	_spd_gas_stream = _load_pcm_wav(SPD_GAS_WAV_PATH)
	_spd_fireball_cast_stream = _load_pcm_wav(SPD_FIREBALL_CAST_WAV_PATH)
	_spd_fireball_release_stream = _load_pcm_wav(SPD_FIREBALL_RELEASE_WAV_PATH)
	_spd_fireball_impact_stream = _load_pcm_wav(SPD_FIREBALL_IMPACT_WAV_PATH)
	_spd_stone_step_stream = _load_pcm_wav(SPD_STONE_STEP_WAV_PATH)
	_spd_wand_zap_stream = _load_pcm_wav(SPD_WAND_ZAP_WAV_PATH)
	_spd_wand_hit_magic_stream = _load_pcm_wav(SPD_WAND_HIT_MAGIC_WAV_PATH)
	for event_name in SPD_SFX_EVENTS:
		var pool: Array = []
		for filename in SPD_SFX_EVENTS[event_name]:
			var stream = load("res://assets/third_party/shattered_pixel_dungeon/sounds/%s" % filename)
			if stream != null: pool.append(stream)
		_sfx_event_cache[event_name] = pool
	_scenario_music_player = AudioStreamPlayer.new()
	_scenario_music_player.bus = "Music"
	_scenario_music_player.volume_db = -5.0
	add_child(_scenario_music_player)
	set_process(true)

func set_scenario_music(_scenario_id: String) -> void:
	# Pedido do usuário: a mesma música usada na Torre (prison_1.ogg) toca em
	# TODOS os cenários agora, não só nos andares da Torre — a trilha
	# ambiente sintetizada (_process, mais abaixo) já não roda nunca, já que
	# ela só toca quando _tower_music_active é false.
	_tower_music_active = true
	var prison_music := load(SPD_PRISON_MUSIC_PATH) as AudioStreamOggVorbis
	if prison_music != null:
		prison_music.loop = true
		_scenario_music_player.stream = prison_music
		_scenario_music_player.volume_db = -30.0
		_scenario_music_player.play()
		create_tween().tween_property(_scenario_music_player, "volume_db", -5.0, 0.35)

func _load_pcm_wav(path: String) -> AudioStreamWAV:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44: return null
	var data_offset := -1
	var data_size := 0
	var cursor := 12
	while cursor + 8 <= bytes.size():
		var chunk_name := bytes.slice(cursor, cursor + 4).get_string_from_ascii()
		var chunk_size := bytes.decode_u32(cursor + 4)
		if chunk_name == "data":
			data_offset = cursor + 8
			data_size = mini(chunk_size, bytes.size() - data_offset)
			break
		cursor += 8 + chunk_size + (chunk_size % 2)
	if data_offset < 0: return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = true
	stream.mix_rate = 44100
	stream.data = bytes.slice(data_offset, data_offset + data_size)
	return stream

func _ensure_bus(bus_name: String, send_to: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send_to)

## Único controle exposto (equivalente a setMusicMuted no JS): fade suave,
## nunca corte abrupto.
func set_music_muted(muted: bool) -> void:
	var idx := AudioServer.get_bus_index("Music")
	var target_db: float = -80.0 if muted else MUSIC_TARGET_VOLUME_DB
	var tween := create_tween()
	tween.tween_method(func(db: float): AudioServer.set_bus_volume_db(idx, db), AudioServer.get_bus_volume_db(idx), target_db, 1.2)

## Abre espaço na mixagem para explosões/raios sem reiniciar a música.
func duck_music(amount_db: float = 5.0, hold: float = 0.24) -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0: return
	if _duck_tween != null and _duck_tween.is_valid(): _duck_tween.kill()
	_duck_tween = create_tween()
	AudioServer.set_bus_volume_db(idx, MUSIC_TARGET_VOLUME_DB - amount_db)
	_duck_tween.tween_interval(hold)
	_duck_tween.tween_method(func(db: float): AudioServer.set_bus_volume_db(idx, db), MUSIC_TARGET_VOLUME_DB - amount_db, MUSIC_TARGET_VOLUME_DB, 0.32)

func play_impact(kind: String, pan: float = 0.0, hit: bool = true) -> void:
	if not hit:
		play_sfx("miss", pan)
		return
	match kind:
		"magic-missile-spd": play_sfx("magicMissileHitSpd", pan)
		"frost-wand-spd": play_sfx("frostWandHitSpd", pan)
		"arrow", "huntress-arrow-spd", "fire-arrow", "bolt": play_sfx("arrowImpact", pan)
		"missile", "spark": play_sfx("magicImpact", pan)
		"fireball": play_sfx("fireImpact", pan)
		"bomb", "bullet-explosive": play_sfx("blast", pan)
		"lightning", "beam": play_sfx("lightning", pan)
		_: play_sfx("physicalImpact", pan)

## Converte a coluna X de uma unidade (0 a BOARD_SIZE-1) num valor de
## panorama estéreo (-1 esquerda a 1 direita) — equivalente a boardPanFor.
func pan_for_x(x: int) -> float:
	if GameConstants.BOARD_SIZE <= 1:
		return 0.0
	return clampf((float(x) / float(GameConstants.BOARD_SIZE - 1)) * 2.0 - 1.0, -1.0, 1.0)

# --- Síntese base (playTone/playNoise/playFilterSweep) ---------------------

func _waveform(wave_type: String, phase: float) -> float:
	var p := fposmod(phase, 1.0)
	match wave_type:
		"square":
			return 1.0 if p < 0.5 else -1.0
		"sawtooth":
			return 2.0 * p - 1.0
		"triangle":
			return 4.0 * absf(p - 0.5) - 1.0
		_:
			return sin(p * TAU)

## Panorama de potência constante (mesmo comportamento perceptual do
## StereoPannerNode do Web Audio).
func _pan_gains(pan: float) -> Vector2:
	var angle: float = (clampf(pan, -1.0, 1.0) + 1.0) * 0.25 * PI
	return Vector2(cos(angle), sin(angle))

## Não usa o sinal `finished` pra liberar o player: sob o driver "Dummy"
## (usado no modo headless, inclusive pelos testes GUT) ele nunca dispara,
## o que vazava `AudioStreamPlayer`/`AudioStreamWAV` a cada som até o fim
## do processo. Em vez disso, calcula a duração real do buffer e agenda a
## liberação por tempo — determinístico em qualquer driver.
func _play_buffer(bytes: PackedByteArray, bus: String) -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = true
	stream.mix_rate = SAMPLE_RATE
	stream.data = bytes
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	add_child(player)
	player.play()
	var duration: float = (float(bytes.size()) / 4.0) / float(SAMPLE_RATE)
	get_tree().create_timer(duration + 0.1).timeout.connect(player.queue_free)

func _play_external(stream: AudioStream, volume_db: float = 0.0, bus: String = "SFX", pitch_scale: float = 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = bus
	player.pitch_scale = pitch_scale
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

## Onda periódica com envelope de decaimento exponencial constante, dado
## por uma função `envelope(t) -> float` (usada pelos sons da trilha
## ambiente, que têm ataque/liberação diferentes do playTone genérico).
func _render_tone_envelope(freq: float, wave_type: String, frame_count: int, envelope: Callable, pan: float) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 4)
	var gains := _pan_gains(pan)
	var phase := 0.0
	for i in range(frame_count):
		var t: float = float(i) / SAMPLE_RATE
		phase += freq / SAMPLE_RATE
		var env: float = envelope.call(t)
		var sample: float = clampf(_waveform(wave_type, phase) * env, -1.0, 1.0)
		bytes.encode_s16(i * 4, int(sample * gains.x * 32767.0))
		bytes.encode_s16(i * 4 + 2, int(sample * gains.y * 32767.0))
	return bytes

## Tom com envelope de decaimento exponencial (igual playTone do JS).
## `end_freq` null = altura fixa; senão a frequência "desliza" exponencial
## de `freq` até `end_freq` ao longo de `duration`. `delay` agenda a
## renderização pra mais tarde (equivalente a `ctx.currentTime + delay`).
func play_tone(freq: float, end_freq: Variant, duration: float, wave_type: String = "sine", volume: float = 0.2, pan: float = 0.0, delay: float = 0.0, bus: String = "SFX") -> void:
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(func(): _render_and_play_tone(freq, end_freq, duration, wave_type, volume, pan, bus))
		return
	_render_and_play_tone(freq, end_freq, duration, wave_type, volume, pan, bus)

func _render_and_play_tone(freq: float, end_freq: Variant, duration: float, wave_type: String, volume: float, pan: float, bus: String) -> void:
	var frame_count := maxi(1, int(duration * SAMPLE_RATE))
	var has_sweep: bool = end_freq != null and float(end_freq) > 0.0
	var end_f: float = maxf(float(end_freq), 1.0) if has_sweep else freq
	var envelope := func(t: float) -> float:
		return volume * pow(0.001 / maxf(volume, 0.001), t / duration)
	if not has_sweep:
		_play_buffer(_render_tone_envelope(freq, wave_type, frame_count, envelope, pan), bus)
		return
	# Com sweep de frequência a fase precisa acumular a cada amostra com a
	# frequência instantânea, então não dá pra reaproveitar
	# _render_tone_envelope (que assume frequência fixa) — mesma ideia, só
	# com o `f` recalculado por amostra.
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 4)
	var gains := _pan_gains(pan)
	var phase := 0.0
	for i in range(frame_count):
		var t: float = float(i) / SAMPLE_RATE
		var frac: float = t / duration
		var f: float = freq * pow(end_f / freq, frac)
		phase += f / SAMPLE_RATE
		var env: float = envelope.call(t)
		var sample: float = clampf(_waveform(wave_type, phase) * env, -1.0, 1.0)
		bytes.encode_s16(i * 4, int(sample * gains.x * 32767.0))
		bytes.encode_s16(i * 4 + 2, int(sample * gains.y * 32767.0))
	_play_buffer(bytes, bus)

## Ruído filtrado com envelope de decaimento exponencial — cobre tanto
## playNoise (from_freq == to_freq, filtro parado) quanto playFilterSweep
## (filtro "varrendo" de uma frequência a outra).
func play_filtered_noise(duration: float, volume: float, from_freq: float, to_freq: float, pan: float = 0.0, filter_type: String = "lowpass", bus: String = "SFX") -> void:
	var frame_count := maxi(1, int(duration * SAMPLE_RATE))
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 4)
	var gains := _pan_gains(pan)
	var dt := 1.0 / SAMPLE_RATE
	var stage1 := 0.0
	var stage2 := 0.0
	var prev_in := 0.0
	for i in range(frame_count):
		var t: float = float(i) / SAMPLE_RATE
		var frac: float = t / duration
		var cutoff: float = maxf(from_freq, 1.0) * pow(maxf(to_freq, 1.0) / maxf(from_freq, 1.0), frac)
		var raw: float = randf() * 2.0 - 1.0
		var filtered: float = raw
		if filter_type == "lowpass":
			var alpha: float = dt / ((1.0 / (TAU * cutoff)) + dt)
			stage1 += alpha * (raw - stage1)
			filtered = stage1
		elif filter_type == "highpass":
			var rc: float = 1.0 / (TAU * cutoff)
			var alpha_hp: float = rc / (rc + dt)
			var out: float = alpha_hp * (stage1 + raw - prev_in)
			prev_in = raw
			stage1 = out
			filtered = out
		else: # bandpass: passa-baixa seguido de passa-alta em série
			var alpha_lp: float = dt / ((1.0 / (TAU * (cutoff * 1.5))) + dt)
			stage1 += alpha_lp * (raw - stage1)
			var rc2: float = 1.0 / (TAU * maxf(cutoff / 1.5, 1.0))
			var alpha_hp2: float = rc2 / (rc2 + dt)
			var out2: float = alpha_hp2 * (stage2 + stage1 - prev_in)
			prev_in = stage1
			stage2 = out2
			filtered = out2
		var env: float = volume * pow(0.001 / maxf(volume, 0.001), frac)
		var sample: float = clampf(filtered * env, -1.0, 1.0)
		bytes.encode_s16(i * 4, int(sample * gains.x * 32767.0))
		bytes.encode_s16(i * 4 + 2, int(sample * gains.y * 32767.0))
	_play_buffer(bytes, bus)

func play_noise(duration: float, volume: float, filter_freq: float, pan: float = 0.0, filter_type: String = "lowpass") -> void:
	play_filtered_noise(duration, volume, filter_freq, filter_freq, pan, filter_type, "SFX")

func play_filter_sweep(duration: float, volume: float, from_freq: float, to_freq: float, pan: float = 0.0, filter_type: String = "bandpass") -> void:
	play_filtered_noise(duration, volume, from_freq, to_freq, pan, filter_type, "SFX")

# --- Tabela SFX (porte literal de game.js:3488-3629) ------------------------

func play_event(event_name: String, pan: float = 0.0) -> void:
	if not _play_cached_event(event_name, event_name):
		play_sfx(event_name, pan)

func _play_cached_event(event_name: String, source_key: String = "") -> bool:
	var pool: Array = _sfx_event_cache.get(event_name, [])
	if pool.is_empty(): return false
	var stream: AudioStream = pool[randi_range(0, pool.size()-1)]
	var repeated := event_name in ["slash_hit","stab_hit","crush_hit","arrow_hit","miss"]
	var pitch := randf_range(0.96,1.04) if repeated else 1.0
	var volume := -8.0 if event_name in ["nature","wind","debuff"] else (-3.0 if event_name in ["blast","lightning","strong_hit","death"] else -5.0)
	if event_name in ["blast","lightning","strong_hit"]: duck_music(5.0,0.24)
	_play_external(stream, volume, "SFX", pitch)
	return true

func play_sfx(key: String, pan: float = 0.0) -> void:
	if SFX_ALIASES.has(key) and _play_cached_event(String(SFX_ALIASES[key]), key): return
	match key:
		"magicMissileZapSpd", "frostWandZapSpd":
			# WandOfFrost.fx: Sample.play(ZAP), volume padrão 1.
			if _spd_wand_zap_stream != null: _play_external(_spd_wand_zap_stream, 0.0, "SFX")
		"magicMissileHitSpd":
			if _spd_wand_hit_magic_stream != null: _play_external(_spd_wand_hit_magic_stream, -5.0, "SFX", randf_range(0.87, 1.15))
		"frostWandHitSpd":
			# WandOfFrost.onZap: volume 1 e pitch 1,1 × Random(0,87–1,15).
			if _spd_wand_hit_magic_stream != null: _play_external(_spd_wand_hit_magic_stream, 0.0, "SFX", 1.1 * randf_range(0.87, 1.15))
		"burningSpd":
			# Asset original do SPD; aplicação única do status, nunca em loop.
			if _spd_burning_stream != null: _play_external(_spd_burning_stream, -5.0, "SFX")
		"toxicGasSpd":
			if _spd_gas_stream != null: _play_external(_spd_gas_stream, -4.0, "SFX")
		"fireballCastSpd":
			if _spd_fireball_cast_stream != null: _play_external(_spd_fireball_cast_stream, -7.0, "SFX")
		"fireballReleaseSpd":
			if _spd_fireball_release_stream != null: _play_external(_spd_fireball_release_stream, -8.0, "SFX")
		"fireballImpactSpd":
			# Pedido do usuário: o impacto da Bola de Fogo da Maga soava como uma
			# explosão genérica (só blast.wav) sem "cara" de fogo/brasa. Mantém o
			# estrondo original só como corpo grave (mais baixo, -9dB), soma o
			# crepitar real de fogo do próprio SPD (burning.wav, mesmo asset do
			# status Queimando) e um chiado sintetizado de brasa por cima
			# (ruído passa-alta curto) pra ficar reconhecível como fogo.
			duck_music(4.0, 0.20)
			if _spd_fireball_impact_stream != null: _play_external(_spd_fireball_impact_stream, -9.0, "SFX")
			if _spd_burning_stream != null: _play_external(_spd_burning_stream, -3.0, "SFX", randf_range(0.9, 1.1))
			play_filtered_noise(0.3, 0.12, 3000, 6000, pan, "highpass")
		"melee":
			play_noise(0.07, 0.25, 1400, pan)
			play_tone(180, 90, 0.12, "square", 0.15, pan)
		"ranged":
			play_tone(950, 320, 0.16, "sine", 0.15, pan)
		"fire":
			play_noise(0.35, 0.3, 500, pan)
			play_tone(150, 50, 0.4, "sawtooth", 0.2, pan)
		"arcane":
			play_tone(1100, null, 0.07, "square", 0.12, pan)
			play_tone(1450, null, 0.09, "square", 0.12, pan, 0.08)
		"lightning":
			play_noise(0.12, 0.3, 5000, pan)
			play_tone(2200, 200, 0.18, "sawtooth", 0.18, pan)
		"heal":
			# Pedido do usuário: sonoplastia mais divina/santa/abençoada/lírica
			# pra cura — arpejo ascendente de tríade maior (Sol-Si-Ré) em sine
			# puro (sem harmônicos ásperos, "limpo" como um sino de cristal),
			# cada nota reforçada por uma sombra bem baixinha uma oitava abaixo
			# (corpo/reverb artificial) e fechado por um brilho agudo sustentado.
			var heal_notes := [[783.99, 0.00], [987.77, 0.10], [1174.66, 0.20]]
			for note in heal_notes:
				play_tone(note[0], null, 0.55, "sine", 0.16, pan, note[1])
				play_tone(note[0] * 0.5, null, 0.65, "sine", 0.05, pan, note[1])
			play_tone(1567.98, null, 0.9, "sine", 0.08, pan, 0.24)
		"resurrectChime":
			# Pedido do usuário: Ressurreição ganha sonoplastia própria, mais
			# grandiosa que a Cura — arpejo ascendente de quase 2 oitavas (Sol
			# maior) terminando num acorde sustentado de Ré maior, como um
			# coro/sino celestial "chegando". Sine puro do início ao fim.
			var res_arpeggio := [
				[392.00, 0.00], [493.88, 0.14], [587.33, 0.28], [783.99, 0.42],
				[987.77, 0.60], [1174.66, 0.78],
			]
			for note in res_arpeggio:
				play_tone(note[0], null, 0.65, "sine", 0.15, pan, note[1])
			var res_chord := [1174.66, 1479.98, 1760.00, 2349.32]
			for freq in res_chord:
				play_tone(freq, null, 1.6, "sine", 0.10, pan, 1.00)
		"wolfHowl":
			# Uivo de Caça (Lobo): glissando ascendente que sustenta e cai no
			# fim, duas vozes levemente desafinadas + sopro de ar filtrado.
			duck_music(4.0, 1.2)
			play_tone(300, 560, 0.45, "sine", 0.16, pan)
			play_tone(560, 470, 1.05, "sine", 0.15, pan, 0.42)
			play_tone(306, 572, 0.45, "triangle", 0.06, pan, 0.02)
			play_tone(572, 478, 1.05, "triangle", 0.05, pan, 0.44)
			play_filtered_noise(1.3, 0.035, 900, 1600, pan, "bandpass")
		"poison":
			play_tone(260, 130, 0.3, "triangle", 0.15, pan)
		"nature":
			play_tone(130, 80, 0.35, "square", 0.15, pan)
		"miss":
			play_tone(320, 220, 0.12, "sine", 0.08, pan)
		"crit":
			play_tone(900, null, 0.09, "square", 0.2, pan)
			play_tone(1300, null, 0.14, "square", 0.2, pan, 0.07)
		"telegraph":
			play_tone(300, 500, 0.3, "sine", 0.08, pan)
		"whoosh":
			play_filter_sweep(0.22, 0.16, 500, 2400, pan, "bandpass")
		"bowRelease":
			play_noise(0.05, 0.11, 2400, pan)
			play_tone(720, 380, 0.09, "triangle", 0.08, pan)
		"arrowTravel":
			play_filter_sweep(0.16, 0.08, 1800, 700, pan, "bandpass")
		"arrowImpact":
			play_noise(0.045, 0.17, 2600, pan, "highpass")
			play_tone(310, 170, 0.09, "triangle", 0.10, pan)
		"magicImpact":
			play_tone(1260, 480, 0.16, "sine", 0.13, pan)
			play_noise(0.08, 0.07, 4200, pan, "highpass")
		"fireImpact":
			play_noise(0.22, 0.20, 720, pan, "lowpass")
			play_tone(240, 75, 0.22, "sawtooth", 0.12, pan)
		"physicalImpact":
			play_noise(0.06, 0.20, 1500, pan)
			play_tone(170, 85, 0.10, "square", 0.10, pan)
		"blast":
			duck_music(6.0, 0.30)
			play_noise(0.34, 0.28, 520, pan, "lowpass")
			play_tone(105, 38, 0.32, "sawtooth", 0.16, pan)
		"waterStep":
			play_noise(0.14, 0.08, 950, pan, "lowpass")
			play_tone(420, 250, 0.10, "sine", 0.035, pan)
		"trapTrigger":
			play_tone(760, 210, 0.12, "triangle", 0.13, pan)
			play_noise(0.05, 0.12, 2300, pan)
		"crossbowRelease":
			play_noise(0.04, 0.15, 1700, pan)
			play_tone(240, 120, 0.08, "square", 0.08, pan)
		"boltTravel":
			play_filter_sweep(0.12, 0.07, 1500, 500, pan, "bandpass")
		"slingRelease":
			play_filter_sweep(0.18, 0.09, 500, 1900, pan, "bandpass")
		"stoneTravel":
			play_filter_sweep(0.24, 0.07, 900, 350, pan, "lowpass")
		"firearmRelease":
			play_noise(0.07, 0.2, 2600, pan)
			play_tone(150, 60, 0.11, "square", 0.12, pan)
		"bladeRelease":
			play_filter_sweep(0.18, 0.13, 700, 2600, pan, "bandpass")
		"bladeTravel":
			play_tone(620, 420, 0.22, "triangle", 0.07, pan)
		"arcaneCast":
			play_tone(440, 880, 0.18, "sine", 0.08, pan)
			play_tone(660, null, 0.16, "triangle", 0.06, pan, 0.06)
		"arcaneTravel":
			play_tone(980, 620, 0.3, "sine", 0.07, pan)
		"lightCast":
			play_tone(1050, null, 0.12, "sine", 0.07, pan)
			play_tone(1420, null, 0.14, "sine", 0.06, pan, 0.05)
		"iceCast":
			play_tone(1250, 1900, 0.18, "sine", 0.07, pan)
			play_noise(0.1, 0.04, 5000, pan)
		"iceTravel":
			play_filter_sweep(0.28, 0.07, 4200, 1800, pan, "highpass")
		"fireCast":
			play_tone(210, 480, 0.2, "triangle", 0.08, pan)
			play_noise(0.15, 0.05, 700, pan)
		"fireTravel":
			play_filter_sweep(0.34, 0.1, 350, 1100, pan, "lowpass")
		"soundCast":
			play_tone(320, 760, 0.16, "sine", 0.08, pan)
		"soundTravel":
			play_tone(520, 260, 0.3, "sine", 0.08, pan)
			play_tone(780, 390, 0.28, "sine", 0.05, pan)
		"flaskThrow":
			play_noise(0.05, 0.08, 1200, pan)
			play_tone(460, 700, 0.11, "triangle", 0.06, pan)
		"flaskTravel":
			play_tone(700, 520, 0.24, "sine", 0.045, pan)
		"freeze":
			play_tone(1900, null, 0.14, "sine", 0.14, pan)
			play_tone(2500, null, 0.12, "sine", 0.1, pan, 0.05)
			play_noise(0.1, 0.08, 6000, pan)
		"stun":
			play_tone(520, 300, 0.09, "square", 0.16, pan)
			play_tone(420, 220, 0.09, "square", 0.13, pan, 0.1)
		"blind":
			play_noise(0.16, 0.16, 900, pan)
		"dodge":
			play_filter_sweep(0.12, 0.14, 2000, 500, pan, "bandpass")
		"counter":
			play_noise(0.05, 0.3, 2200, pan)
			play_tone(260, 90, 0.11, "square", 0.22, pan)
		"cageOpen":
			play_noise(0.14, 0.22, 2600, pan, "highpass")
			play_tone(260, 90, 0.30, "sawtooth", 0.16, pan)
			play_tone(180, 70, 0.22, "square", 0.10, pan, 0.06)
		"death":
			play_noise(0.3, 0.22, 280, pan)
			play_tone(220, 55, 0.5, "sawtooth", 0.18, pan)
		"move":
			if _tower_music_active and _spd_stone_step_stream != null:
				_play_external(_spd_stone_step_stream, -12.0, "SFX")
			else:
				play_noise(0.05, 0.1, 700, pan)
				play_tone(110, 65, 0.07, "sine", 0.07, pan)
		"turnStart":
			play_tone(660, null, 0.12, "sine", 0.1, 0.0)
			play_tone(880, null, 0.16, "sine", 0.1, 0.0, 0.09)
		"victory":
			var vnotes := [523.0, 659.0, 784.0, 1047.0]
			for i in range(vnotes.size()):
				play_tone(vnotes[i], null, 0.28, "triangle", 0.22, 0.0, i * 0.16)
		"victoryFanfare":
			# Comemoração de ~2,9s tocada nos 3s de espera antes de avançar de
			# fase (ver main.gd:_start_victory_phase_advance): flourish
			# ascendente C-E-G-C, respiro, e um acorde de chegada C-E-G-C mais
			# agudo — melodia triangle (mais "metálica"/trompete) reforçada por
			# uma camada sawtooth grave nos tempos fortes, imitando corpo de
			# trompete sem precisar de um asset de música real.
			var fanfare_melody := [
				[523.25, 0.00], [659.25, 0.16], [784.00, 0.32], [1046.50, 0.50],
				[880.00, 0.85], [1046.50, 1.05], [1318.50, 1.25],
				[1046.50, 1.65], [1318.50, 1.85], [1568.00, 2.05], [2093.00, 2.35],
			]
			for note in fanfare_melody:
				play_tone(note[0], null, 0.5, "triangle", 0.20, 0.0, note[1])
			var fanfare_brass_hits := [[523.25, 0.00], [784.00, 0.32], [1046.50, 1.05], [1568.00, 2.05]]
			for note in fanfare_brass_hits:
				play_tone(note[0] * 0.5, null, 0.45, "sawtooth", 0.10, 0.0, note[1])
		"revive":
			var rnotes := [523.0, 784.0, 1047.0, 1319.0]
			for i in range(rnotes.size()):
				play_tone(rnotes[i], null, 0.22, "triangle", 0.18, pan, i * 0.09)
			play_noise(0.3, 0.06, 4000, pan)
		"reviveFail":
			play_tone(300, 120, 0.5, "sine", 0.14, pan)
			play_tone(220, 90, 0.55, "sine", 0.1, pan, 0.15)
		"soulPickup":
			play_tone(900, null, 0.3, "sine", 0.12, pan)
			play_tone(1350, null, 0.35, "sine", 0.1, pan, 0.12)
			play_noise(0.3, 0.05, 3500, pan)
		"soulRise":
			play_filter_sweep(0.5, 0.1, 300, 1800, pan, "bandpass")
		"defeat":
			var dnotes := [400.0, 340.0, 280.0, 200.0]
			for i in range(dnotes.size()):
				play_tone(dnotes[i], dnotes[i] * 0.8, 0.4, "sawtooth", 0.2, 0.0, i * 0.28)
		"caveRumble":
			# Introdução cinematográfica dos monstros saindo da abertura da
			# montanha (Horda) — rumor grave de pedra, não um impacto.
			play_filtered_noise(0.6, 0.16, 90, 220, pan, "lowpass")
			play_tone(70, 45, 0.5, "sine", 0.12, pan)
		_:
			pass

# --- Trilha ambiente (porte simplificado de game.js:3230-3390) -------------
# Ver nota no topo do arquivo: mesma estrutura (progressão Am-F-C-G, baixo
# pulsante, tambor no mesmo pulso, melodia esparsa em cima), timbre um
# pouco mais simples que o original (sem o passa-baixa dedicado do baixo/
# passa-faixa do "stab"). `_process` checa a cada frame se é hora do
# próximo evento — mais preciso que o polling de 250ms do JS (que existia
# só porque setInterval não é confiável no nível de amostra; aqui não
# precisa de scheduler com lookahead).

func _process(delta: float) -> void:
	_music_time += delta
	if _tower_music_active:
		return
	while _music_next_chord_time <= _music_time:
		_schedule_music_pad(MUSIC_CHORDS[_music_chord_index])
		_music_chord_index = (_music_chord_index + 1) % MUSIC_CHORDS.size()
		_music_next_chord_time += MUSIC_CHORD_DURATION
	while _music_next_bass_time <= _music_time:
		_schedule_music_bass_pulse(MUSIC_CHORDS[_music_chord_index])
		_music_next_bass_time += MUSIC_DRUM_INTERVAL
	while _music_next_drum_time <= _music_time:
		_schedule_music_drum_hit()
		_music_next_drum_time += MUSIC_DRUM_INTERVAL
	while _music_next_melody_time <= _music_time:
		if randf() < 0.7:
			_schedule_music_melody_note()
		_music_next_melody_time += 1.5 + randf() * 1.1

func _schedule_music_pad(chord: Dictionary) -> void:
	var duration: float = MUSIC_CHORD_DURATION
	var peak := 0.05
	for freq in chord["notes"]:
		var envelope := func(t: float) -> float:
			if t < 0.5:
				return peak * (t / 0.5)
			if t < duration - 0.6:
				return peak
			return peak * (1.0 - clampf((t - (duration - 0.6)) / 0.6, 0.0, 1.0))
		var frame_count := int(duration * SAMPLE_RATE)
		_play_buffer(_render_tone_envelope(freq, "sine", frame_count, envelope, 0.0), "Music")
	# "Stab" curto na virada do acorde — simplificado (dente de serra puro,
	# sem o passa-faixa do JS original), decaimento exponencial rápido.
	var stab_freq: float = chord["notes"][0]
	var stab_dur := 0.5
	var stab_peak := 0.05
	var stab_envelope := func(t: float) -> float:
		if t < 0.03:
			return stab_peak * (t / 0.03)
		return stab_peak * pow(0.001 / stab_peak, (t - 0.03) / (stab_dur - 0.03))
	var stab_frames := int(stab_dur * SAMPLE_RATE)
	_play_buffer(_render_tone_envelope(stab_freq, "sawtooth", stab_frames, stab_envelope, 0.0), "Music")

func _schedule_music_bass_pulse(chord: Dictionary) -> void:
	var dur: float = (MUSIC_CHORD_DURATION / MUSIC_BASS_PULSES_PER_CHORD) * 0.85
	var peak := 0.055
	var envelope := func(t: float) -> float:
		return peak * pow(0.001 / peak, t / dur)
	var frames := int(dur * SAMPLE_RATE)
	_play_buffer(_render_tone_envelope(chord["root"], "sawtooth", frames, envelope, 0.0), "Music")

func _schedule_music_drum_hit() -> void:
	play_filtered_noise(0.12, 0.05, 900, 900, 0.0, "lowpass", "Music")
	play_tone(90, 45, 0.18, "sine", 0.06, 0.0, 0.0, "Music")

func _schedule_music_melody_note() -> void:
	var freq: float = MUSIC_MELODY_POOL[randi() % MUSIC_MELODY_POOL.size()]
	var peak := 0.05
	var dur: float = 0.9 + randf() * 0.8
	var envelope := func(t: float) -> float:
		if t < 0.08:
			return peak * (t / 0.08)
		return peak * (1.0 - clampf((t - 0.08) / (dur - 0.08), 0.0, 1.0))
	var frames := int(dur * SAMPLE_RATE)
	_play_buffer(_render_tone_envelope(freq, "triangle", frames, envelope, 0.0), "Music")
