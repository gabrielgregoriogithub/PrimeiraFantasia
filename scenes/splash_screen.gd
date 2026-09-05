class_name SplashScreen
extends Control

## Tela de abertura: mostra a logo "Primeira Fantasia" por 4s (com fade in/
## out) antes do menu principal. A música ambiente já toca sozinha desde o
## boot do jogo (AudioEngine é autoload — ver autoload/audio_engine.gd,
## _process() agenda a trilha sintetizada assim que a cena carrega), então
## esta tela não precisa iniciar música nenhuma por conta própria.

signal finished

const LOGO_TEXTURE_PATH := "res://assets/ui/splash_logo.png"
const HOLD_SEC := 4.0
const FADE_SEC := 0.6

var _logo: TextureRect

func _ready() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = viewport_size
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.position = Vector2.ZERO
	backdrop.size = viewport_size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	_logo = TextureRect.new()
	_logo.texture = load(LOGO_TEXTURE_PATH)
	# EXPAND_IGNORE_SIZE (não EXPAND_FIT_WIDTH_PROPORTIONAL) é o que faz
	# STRETCH_KEEP_ASPECT_CENTERED de fato "conter" a imagem inteira dentro
	# do rect fixo abaixo sem cortar nada — mesmo par usado em
	# intro_cutscene.gd. FIT_WIDTH_PROPORTIONAL recalcula a altura mínima a
	# partir da largura, o que brigava com size=viewport_size e cortava a
	# logo pela metade (bug relatado pelo usuário).
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.position = Vector2.ZERO
	_logo.size = viewport_size
	_logo.modulate.a = 0.0
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)

func play() -> void:
	visible = true
	var tween := create_tween()
	tween.tween_property(_logo, "modulate:a", 1.0, FADE_SEC)
	tween.tween_interval(HOLD_SEC)
	tween.tween_property(_logo, "modulate:a", 0.0, FADE_SEC)
	tween.tween_callback(func(): finished.emit())
