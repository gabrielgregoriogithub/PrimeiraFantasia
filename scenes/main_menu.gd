class_name MainMenu
extends Control

## Menu principal (pós-splash): título + 2 opções (Modo História / Modo PVP).
## O arqueiro de assets/ui/selector_*.png funciona como cursor: pose de mira
## (selector_aim.png) ao lado da opção destacada, pose de disparo
## (selector_fire.png) num "golpe" curto pra dentro da opção confirmada, e
## pose de repouso (selector_rest.png) depois de disparar, antes de trocar
## de tela — pedido do usuário (ver conversa: "usa a sequencia [aim] pra
## escolher a opção e qnd escolhe, ele faz esse movimento [fire] pra lançar
## a flecha e fica em repouso nesse [rest]").

signal story_selected
signal pvp_selected

const ART_DIRECTION := preload("res://data/art_direction_config.gd")

const LOGO_TEXTURE_PATH := "res://assets/ui/splash_logo.png"
const SELECTOR_AIM_PATH := "res://assets/ui/selector_aim.png"
const SELECTOR_FIRE_PATH := "res://assets/ui/selector_fire.png"
const SELECTOR_REST_PATH := "res://assets/ui/selector_rest.png"

const OPTIONS := [
	{"key": "story", "label": "MODO HISTÓRIA"},
	{"key": "pvp", "label": "MODO PVP"},
]

const BUTTON_SIZE := Vector2(460, 96)
const BUTTON_SEPARATION := 34.0
const SELECTOR_SIZE := Vector2(150, 150)
const SELECTOR_REST_SIZE := Vector2(90, 105)

var _selector: TextureRect
var _option_buttons: Array = []
var _option_index := 0
var _locked := false
var _selector_rest_pos := Vector2.ZERO

func _ready() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = viewport_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = ART_DIRECTION.make_ui_theme()

	var backdrop := ColorRect.new()
	backdrop.color = Color("0c0f16")
	backdrop.position = Vector2.ZERO
	backdrop.size = viewport_size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var logo := TextureRect.new()
	logo.texture = load(LOGO_TEXTURE_PATH)
	# Ver comentário equivalente em splash_screen.gd: EXPAND_IGNORE_SIZE (não
	# FIT_WIDTH_PROPORTIONAL) é o que faz STRETCH_KEEP_ASPECT_CENTERED conter
	# a logo inteira dentro do rect fixo abaixo sem cortar.
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size = Vector2(680, 380)
	logo.position = Vector2((viewport_size.x - logo.size.x) * 0.5, 70)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)

	var hint := Label.new()
	hint.text = "↑ / ↓ escolher · Enter / clique confirmar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("9aa2b8"))
	hint.position = Vector2(0, viewport_size.y - 60)
	hint.size = Vector2(viewport_size.x, 30)
	add_child(hint)

	var buttons_top := 560.0
	var buttons_left := (viewport_size.x - BUTTON_SIZE.x) * 0.5
	for i in OPTIONS.size():
		var opt: Dictionary = OPTIONS[i]
		var button := Button.new()
		button.text = String(opt["label"])
		button.add_theme_font_size_override("font_size", 30)
		button.position = Vector2(buttons_left, buttons_top + i * (BUTTON_SIZE.y + BUTTON_SEPARATION))
		button.size = BUTTON_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_entered.connect(_on_option_hovered.bind(i))
		button.pressed.connect(_on_option_clicked.bind(i))
		add_child(button)
		_option_buttons.append(button)

	_selector = TextureRect.new()
	_selector.texture = load(SELECTOR_AIM_PATH)
	_selector.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_selector.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_selector.size = SELECTOR_SIZE
	_selector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_selector)

	_refresh_selection()
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if _locked:
		return
	if event.is_action_pressed("ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_confirm_selection()
		get_viewport().set_input_as_handled()

func _move_selection(delta: int) -> void:
	_option_index = (_option_index + delta + OPTIONS.size()) % OPTIONS.size()
	_refresh_selection()

func _on_option_hovered(index: int) -> void:
	if _locked:
		return
	_option_index = index
	_refresh_selection()

func _on_option_clicked(index: int) -> void:
	if _locked:
		return
	_option_index = index
	_confirm_selection()

func _refresh_selection() -> void:
	for i in _option_buttons.size():
		var button: Button = _option_buttons[i]
		button.modulate = Color("ffe29a") if i == _option_index else Color.WHITE
	var target: Button = _option_buttons[_option_index]
	_selector_rest_pos = Vector2(
		target.position.x - SELECTOR_SIZE.x + 26.0,
		target.position.y + (target.size.y - SELECTOR_SIZE.y) * 0.5,
	)
	_selector.texture = load(SELECTOR_AIM_PATH)
	_selector.size = SELECTOR_SIZE
	_selector.position = _selector_rest_pos

func _confirm_selection() -> void:
	_locked = true
	var target: Button = _option_buttons[_option_index]
	var lunge_pos := Vector2(_selector_rest_pos.x + 46.0, _selector_rest_pos.y)
	var arrow_origin := Vector2(_selector_rest_pos.x + SELECTOR_SIZE.x - 12.0, _selector_rest_pos.y + SELECTOR_SIZE.y * 0.42)

	_selector.texture = load(SELECTOR_FIRE_PATH)
	_spawn_piercing_arrow_vfx(arrow_origin)
	var tween := create_tween()
	tween.tween_property(_selector, "position", lunge_pos, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(target, "modulate", Color("fff6c8"), 0.12)
	tween.tween_property(target, "modulate", Color("ffe29a"), 0.18)
	tween.tween_property(_selector, "position", _selector_rest_pos, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_selector.texture = load(SELECTOR_REST_PATH)
		_selector.size = SELECTOR_REST_SIZE
		_selector.position = Vector2(
			_selector_rest_pos.x + (SELECTOR_SIZE.x - SELECTOR_REST_SIZE.x) * 0.5,
			_selector_rest_pos.y + (SELECTOR_SIZE.y - SELECTOR_REST_SIZE.y) * 0.5,
		)
	)
	tween.tween_interval(0.45)
	tween.tween_callback(func():
		var key: String = OPTIONS[_option_index]["key"]
		if key == "story": story_selected.emit()
		else: pvp_selected.emit()
	)

## Pedido do usuário: a flecha disparada ao confirmar uma opção precisa
## "atravessar toda a tela", não só um pequeno lunge até o botão — dois
## Line2D crescendo quase instantaneamente até além da borda direita (um fino
## e brilhante por cima de um mais grosso e translúcido, simulando o brilho
## visto em selector_fire.png) e depois desaparecendo. Sem asset de
## projétil próprio: o game principal desenha flechas proceduralmente, então
## aqui segue o mesmo espírito em vez de inventar uma textura nova.
func _spawn_piercing_arrow_vfx(start: Vector2) -> void:
	var end_x: float = get_viewport_rect().size.x + 140.0
	var glow := Line2D.new()
	glow.width = 18.0
	glow.default_color = Color(1.0, 0.85, 0.4, 0.4)
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	glow.z_index = 499
	glow.points = PackedVector2Array([start, start])
	add_child(glow)

	var core := Line2D.new()
	core.width = 6.0
	core.default_color = Color(1.0, 0.96, 0.75, 0.95)
	core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core.end_cap_mode = Line2D.LINE_CAP_ROUND
	core.z_index = 500
	core.points = PackedVector2Array([start, start])
	add_child(core)

	var travel := create_tween()
	travel.tween_method(func(x: float):
		var tip := Vector2(x, start.y)
		glow.points = PackedVector2Array([start, tip])
		core.points = PackedVector2Array([start, tip])
	, start.x, end_x, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	var fade := create_tween()
	fade.tween_interval(0.05)
	fade.set_parallel(true)
	fade.tween_property(glow, "modulate:a", 0.0, 0.22)
	fade.tween_property(core, "modulate:a", 0.0, 0.22)
	fade.set_parallel(false)
	fade.tween_callback(func():
		glow.queue_free()
		core.queue_free()
	)
