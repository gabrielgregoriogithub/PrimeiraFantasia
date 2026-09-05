extends GutTest

const ART := preload("res://data/art_direction_config.gd")
const BOARD := preload("res://scenes/board_view.gd")
const CHARACTER := preload("res://scenes/character_visual_controller.gd")

func test_global_palette_keeps_gameplay_colors_distinct_and_avoids_absolute_black() -> void:
	for required in ["move","attack","heal","buff","debuff","objective","ally","enemy"]:
		assert_true(ART.PALETTE.has(required))
	assert_ne(ART.PALETTE["move"], ART.PALETTE["attack"])
	assert_ne(ART.PALETTE["heal"], ART.PALETTE["debuff"])
	assert_gt((ART.PALETTE["ink"] as Color).get_luminance(), 0.0)

func test_every_biome_profile_has_same_art_direction_contract() -> void:
	for id in ["field","village","forest","lua_valley","tower","tower_floor_2","tower_floor_3","tower_floor_4"]:
		var profile := ART.biome_for(id)
		for key in ["ambient_tint","environment_tint","shadow_tint","water_tint","background_saturation","ambient_particles","ambient_light"]:
			assert_true(profile.has(key), "%s possui %s" % [id, key])
		assert_between(float(profile["background_saturation"]), 0.80, 1.0)
		assert_between(float(profile["ambient_light"]), 0.80, 1.05)

func test_character_shader_preserves_class_color_while_unifying_light_and_outline() -> void:
	assert_string_contains(CHARACTER.LIGHT_SHADER_SOURCE, "uniform float saturation")
	assert_string_contains(CHARACTER.LIGHT_SHADER_SOURCE, "uniform float contrast")
	assert_string_contains(CHARACTER.LIGHT_SHADER_SOURCE, "shadow_color")
	assert_false(CHARACTER.LIGHT_SHADER_SOURCE.contains("glow"), "personagem comum não ganha glow permanente")

func test_board_uses_biome_grading_only_for_world_and_keeps_translucent_grid() -> void:
	var board := BOARD.new()
	add_child_autofree(board)
	board.set_scenario({"id":"forest"})
	assert_eq(board._art_profile, ART.biome_for("forest"))
	assert_lt(float((board._art_profile["ambient_tint"] as Color).a), 0.10)

func test_ui_theme_has_complete_button_states_from_same_family() -> void:
	var theme := ART.make_ui_theme()
	for state in ["normal","hover","pressed","focus","disabled"]:
		assert_true(theme.has_stylebox(state, "Button"), state)
	assert_ne(theme.get_stylebox("normal", "Button").border_color, theme.get_stylebox("hover", "Button").border_color)
