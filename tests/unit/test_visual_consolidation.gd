extends GutTest

const POLICY := preload("res://data/visual_policy.gd")
const BOARD := preload("res://scenes/board_view.gd")
const EFFECTS := preload("res://scenes/effects_layer.gd")

func test_visual_policy_has_quality_budgets_presets_and_safe_defaults() -> void:
	assert_eq(POLICY.impact("unknown"), POLICY.IMPACT_PRESETS["light"])
	# ETAPA 16: 5 tiers agora — LIGHT/MEDIUM/HEAVY/SIGNATURE/EPIC.
	assert_eq(POLICY.IMPACT_PRESETS.size(), 5)
	var previous: String = POLICY.quality
	POLICY.quality = POLICY.QUALITY_LOW
	var low := POLICY.temporary_light_budget()
	POLICY.quality = POLICY.QUALITY_HIGH
	assert_gt(POLICY.temporary_light_budget(), low)
	POLICY.quality = previous

func test_camera_owner_prevents_lower_priority_visual_conflicts() -> void:
	var board := BOARD.new()
	add_child_autofree(board)
	assert_true(board.acquire_camera("combat_focus", 10))
	assert_true(board.acquire_camera("presentation", 30))
	assert_false(board.acquire_camera("combat_focus", 10))
	board.release_camera("combat_focus")
	assert_eq(board.camera_owner(), "presentation")
	board.release_camera("presentation")
	assert_eq(board.camera_owner(), "player")

func test_popup_lanes_separate_simultaneous_feedback_and_lights_stay_budgeted() -> void:
	var effects := EFFECTS.new()
	add_child_autofree(effects)
	for i in 8: effects.spawn_combat_popup(Vector2(100, 100), str(i))
	var lanes: Dictionary = {}
	for child in effects.get_children():
		if child.has_meta("combat_popup"): lanes[int(child.get_meta("popup_lane"))] = true
	assert_gt(lanes.size(), 1)
	var previous: String = POLICY.quality
	POLICY.quality = POLICY.QUALITY_LOW
	for i in 9: effects.spawn_temporary_light(Vector2(i * 3, 0), Color.WHITE, 0.1, 1.0)
	await wait_process_frames(2)
	assert_lte(get_tree().get_nodes_in_group("temporary_visual_lights").size(), POLICY.temporary_light_budget())
	POLICY.quality = previous
