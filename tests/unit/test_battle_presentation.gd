extends GutTest

var controller: BattlePresentationController
var board: BoardView
var hud: CanvasLayer

func before_each() -> void:
	board = BoardView.new()
	add_child_autofree(board)
	hud = CanvasLayer.new()
	add_child_autofree(hud)
	var hud_content := Control.new()
	hud.add_child(hud_content)
	controller = BattlePresentationController.new()
	add_child_autofree(controller)
	controller.setup(board, hud)

func test_presentation_exposes_complete_battle_lifecycle() -> void:
	assert_eq(BattlePresentationController.Phase.keys(), ["LOADING", "INTRO", "OBJECTIVE", "UNIT_REVEAL", "ENEMY_REVEAL", "READY", "COMBAT", "VICTORY", "DEFEAT", "ENDING"])
	assert_eq(controller.presentation_speed, 1.0)
	assert_false(controller.reduced_presentation)

func test_frame_targets_is_bounded_and_keeps_readable_zoom() -> void:
	var left := Node2D.new(); left.position = Vector2(-900, -900); board.add_child(left)
	var right := Node2D.new(); right.position = Vector2(1900, 1900); board.add_child(right)
	var frame := controller.frame_targets([left, right], 96.0, 1.10)
	assert_between(float(frame["zoom"].x), 0.899, 1.101)
	assert_between(float(frame["position"].x - controller._saved_camera_position.x), -190.0, 190.0)
	assert_between(float(frame["position"].y - controller._saved_camera_position.y), -190.0, 190.0)

func test_objective_card_uses_existing_battle_conditions() -> void:
	var prisoner := UnitToken.new()
	prisoner.unit = {"name":"Bardo", "caged":true}
	assert_eq(controller._objective_text({"id":ScenarioManager.LUA_VALLEY}, []), "Sobreviva até o fim do combate")
	assert_eq(controller._objective_text({"id":ScenarioManager.TOWER_FLOOR_2}, [prisoner]), "Derrote os inimigos e liberte Bardo")
	assert_eq(controller._objective_text({"id":ScenarioManager.FIELD}, []), "Derrote todos os inimigos")
	assert_eq(controller._objective_text({"id":ScenarioManager.FIELD, "objective":"Texto existente"}, []), "Texto existente")
	prisoner.free()

func test_skip_restores_camera_hud_tokens_and_enters_combat_once() -> void:
	watch_signals(controller)
	var hero := Node2D.new(); hero.position = Vector2(64, 64); board.add_child(hero)
	var enemy := Node2D.new(); enemy.position = Vector2(640, 640); board.add_child(enemy)
	var original_position := board.camera.position
	var original_zoom := board.camera.zoom
	controller.play_intro({"id":ScenarioManager.FIELD}, [hero], [enemy])
	assert_true(controller.is_blocking_input())
	controller.skip()
	assert_false(controller.is_blocking_input())
	assert_eq(controller.phase, BattlePresentationController.Phase.COMBAT)
	assert_eq(board.camera.position, original_position)
	assert_eq(board.camera.zoom, original_zoom)
	assert_eq((hud.get_child(0) as CanvasItem).modulate.a, 1.0)
	assert_eq(hero.modulate.a, 1.0)
	assert_eq(enemy.modulate.a, 1.0)
	assert_signal_emit_count(controller, "presentation_finished", 1)

func test_main_keeps_presentation_visual_only_during_gut() -> void:
	var main_scene = preload("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main_scene)
	assert_not_null(main_scene.battle_presentation)
	assert_eq(main_scene.battle_presentation.phase, BattlePresentationController.Phase.COMBAT)
	assert_false(main_scene.battle_presentation.is_blocking_input())
	assert_not_null(main_scene.state.current_actor)
