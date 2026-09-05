extends GutTest

## ETAPA 18 — Ambiente Vivo. Cobre o AmbientLifeManager isoladamente (matching
## de bioma, orçamento por qualidade, ducking, cleanup) e a integração com
## BoardView (vento variando devagar, duck disparado por impacto pesado).

## EnvironmentPropVisual de verdade (kind/visual_height são campos reais da
## classe, ao contrário de um Node2D genérico) — mas nunca adicionado à
## árvore de cena, então _draw()/_process() nunca rodam nele; serve só como
## um "double" com os campos que _spawn_leaf() de fato lê.
func _fake_tree(pos: Vector2) -> Node2D:
	var tree := BoardView.EnvironmentPropVisual.new()
	tree.configure(null, Vector2(64, 96), "tree", 0.0)
	tree.position = pos
	return tree

func test_set_biome_accepts_known_kinds_and_falls_back_to_dust_otherwise() -> void:
	var manager := AmbientLifeManager.new(); add_child_autofree(manager)
	manager.set_biome("mist")
	assert_eq(manager.active_kind, "mist")
	manager.set_biome("leaves")
	assert_eq(manager.active_kind, "leaves")
	manager.set_biome("nao-existe")
	assert_eq(manager.active_kind, "dust", "kind desconhecido cai pro padrão em vez de travar")

func test_budget_scales_with_visual_policy_quality() -> void:
	var manager := AmbientLifeManager.new(); add_child_autofree(manager)
	var previous := VisualPolicy.quality
	VisualPolicy.quality = VisualPolicy.QUALITY_LOW
	var low := manager._current_budget()
	VisualPolicy.quality = VisualPolicy.QUALITY_HIGH
	var high := manager._current_budget()
	VisualPolicy.quality = previous
	assert_lt(low, high, "LOW deve permitir menos microeventos simultâneos que HIGH")

func test_duck_temporarily_raises_the_skip_window() -> void:
	var manager := AmbientLifeManager.new(); add_child_autofree(manager)
	assert_eq(manager._duck_until, 0.0)
	manager.duck(2.0)
	assert_almost_eq(manager._duck_until, 2.0, 0.01)
	manager._clock = 5.0
	manager.duck(1.0)
	assert_almost_eq(manager._duck_until, 6.0, 0.01, "duck não reduz uma janela maior já agendada")

func test_spawn_leaf_adds_a_tracked_child_near_a_tree_and_clear_removes_it() -> void:
	var board := Node2D.new(); add_child_autofree(board)
	# A árvore-double nunca entra na SceneTree (só serve de leitura de
	# position/visual_height pro lookup abaixo) — evita depender de textura
	# real só pra este teste.
	var tree := _fake_tree(Vector2(100, 100))
	var manager := AmbientLifeManager.new(); add_child_autofree(manager)
	manager.setup(board, func(): return [tree])
	var before := board.get_child_count()
	manager._spawn_leaf()
	assert_eq(board.get_child_count(), before + 1)
	assert_eq(manager._spawned.size(), 1)
	manager.clear()
	assert_eq(manager._spawned.size(), 0)
	# queue_free() é adiado pro fim do frame; espera processar antes de
	# soltar a árvore-double, pra não sobrar node órfão no relatório do GUT.
	await wait_process_frames(1)
	tree.free()

func test_spawn_leaf_does_nothing_without_a_tree() -> void:
	var board := Node2D.new(); add_child_autofree(board)
	var manager := AmbientLifeManager.new(); add_child_autofree(manager)
	manager.setup(board, func(): return [])
	var before := board.get_child_count()
	manager._spawn_leaf()
	assert_eq(board.get_child_count(), before, "sem árvore, não inventa posição nenhuma")

func test_board_wind_strength_drifts_smoothly_and_stays_in_range() -> void:
	var board := BoardView.new(); add_child_autofree(board)
	board.wind_strength = 0.4
	for i in 40:
		board._update_wind(0.1)
	assert_between(board.wind_strength, 0.0, 1.05)

func test_heavy_environment_reaction_ducks_ambient_life() -> void:
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main_scene)
	await wait_process_frames(1)
	var board: BoardView = main_scene.board_view
	assert_not_null(board._ambient_life)
	var duck_before: float = board._ambient_life._duck_until
	main_scene.effects_layer.emit_environment_reaction("melee_impact", Vector2(100, 100), Vector2.RIGHT, "heavy", "")
	assert_gt(board._ambient_life._duck_until, duck_before, "impacto HEAVY abaixa a vida ambiental")

func test_light_environment_reaction_does_not_duck_ambient_life() -> void:
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main_scene)
	await wait_process_frames(1)
	var board: BoardView = main_scene.board_view
	var duck_before: float = board._ambient_life._duck_until
	main_scene.effects_layer.emit_environment_reaction("projectile_impact", Vector2(100, 100), Vector2.RIGHT, "light", "")
	assert_eq(board._ambient_life._duck_until, duck_before)

func test_switching_scenario_updates_biome_and_clears_pending_ambient_nodes() -> void:
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main_scene)
	await wait_process_frames(1)
	var board: BoardView = main_scene.board_view
	if board._ambient_life.active_kind == "leaves": board._ambient_life._spawn_leaf()
	else: board._ambient_life._spawn_dust_mote()
	board.set_scenario({"id": "lua_valley"})
	assert_eq(board._ambient_life.active_kind, "mist")
	assert_eq(board._ambient_life._spawned.size(), 0, "trocar de cenário limpa microeventos pendentes")
	await wait_process_frames(1)
