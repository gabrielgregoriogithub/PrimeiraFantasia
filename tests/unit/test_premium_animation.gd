extends GutTest

const PREMIUM := preload("res://data/premium_animation_profiles.gd")
const UNIT_TOKEN := preload("res://scenes/unit_token.gd")
const UNITS := preload("res://data/units.gd")

func test_weight_profiles_keep_light_fast_heavy_readable_and_giant_subtle() -> void:
	assert_lt(float(PREMIUM.SPEED["light"]["start"]), float(PREMIUM.SPEED["heavy"]["start"]))
	assert_gt(float(PREMIUM.SPEED["heavy"]["impact_hold"]), float(PREMIUM.SPEED["light"]["impact_hold"]))
	assert_eq(float(PREMIUM.SPEED["giant"]["smear"]), 0.0)
	assert_lt(float(PREMIUM.SPEED["heavy"]["stretch"]), float(PREMIUM.SPEED["light"]["stretch"]))

func test_attack_frame_timing_has_prepare_travel_and_recovery_holds() -> void:
	var weights := PREMIUM.frame_weights("attack", 4)
	assert_eq(weights.size(), 4)
	assert_gt(weights[0], weights[1], "preparo segura mais que travel")
	assert_gt(weights[-1], weights[1], "recovery segura mais que travel")
	assert_eq(PREMIUM.frame_weights("attack", 1).size(), 1, "fallback de um frame é seguro")

func test_visual_priority_is_death_hit_attack_move_idle() -> void:
	assert_gt(PREMIUM.Priority.DEATH, PREMIUM.Priority.HIT)
	assert_gt(PREMIUM.Priority.HIT, PREMIUM.Priority.ATTACK)
	assert_gt(PREMIUM.Priority.ATTACK, PREMIUM.Priority.MOVE)
	assert_gt(PREMIUM.Priority.MOVE, PREMIUM.Priority.IDLE)

func test_priority_interrupt_resets_visual_root_without_moving_logical_token() -> void:
	var token := UNIT_TOKEN.new()
	token.setup((UNITS.build()["guerreiro"] as Dictionary).duplicate(true))
	add_child_autofree(token)
	await wait_process_frames(1)
	var logical_position := token.position
	assert_true(token._begin_premium_action(PREMIUM.Priority.ATTACK))
	token._visual_root.position = Vector2(20, -4)
	assert_false(token._begin_premium_action(PREMIUM.Priority.MOVE))
	assert_true(token._begin_premium_action(PREMIUM.Priority.DEATH))
	assert_eq(token._visual_root.position, Vector2.ZERO)
	assert_eq(token.position, logical_position)

func test_debug_speed_changes_only_visual_duration() -> void:
	var previous: float = PREMIUM.debug_speed
	PREMIUM.debug_speed = 0.25
	assert_eq(PREMIUM.scaled(0.1), 0.4)
	PREMIUM.debug_speed = previous
