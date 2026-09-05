extends GutTest

func test_warrior_profile_and_factory_are_reusable() -> void:
	assert_true(CharacterVisualFactory.has_profile("guerreiro"))
	var visual := CharacterVisualFactory.create("guerreiro")
	add_child_autofree(visual)
	assert_eq(visual.profile.character_id,"warrior")
	assert_eq(visual.profile.archetype,"Humanoid_Melee")

func test_unknown_character_falls_back_without_instantiating_3d() -> void:
	assert_false(CharacterVisualFactory.has_profile("unknown"))
	assert_null(CharacterVisualFactory.create("unknown"))

func test_archer_dry_run_requires_configuration_not_controller_copy() -> void:
	var profile := load("res://assets/characters/archer/archer_3d_profile_dry_run.tres") as Character3DProfile
	assert_eq(profile.archetype,"Humanoid_Ranged")
	assert_true(profile.capability(&"projectile"))
	assert_eq(profile.animation_events.projectile_spawn,0.38)
	assert_null(profile.model,"Dry run deliberately waits for its GLB")

func test_profile_skill_matching_preserves_existing_ids() -> void:
	var profile := load("res://assets/characters/warrior/warrior_3d_profile.tres") as Character3DProfile
	assert_eq(profile.skill_id_for(Spells.build().spinAttack),"spinAttack")
	assert_eq(profile.skill_id_for(Spells.build().throwSword),"throwSword")

func test_warrior_ground_anchor_keeps_gameplay_and_visual_transforms_separate() -> void:
	var visual := CharacterVisualFactory.create("guerreiro")
	add_child_autofree(visual)
	await get_tree().process_frame
	assert_not_null(visual.get_node_or_null("GroundAnchor"))
	assert_not_null(visual.get_node_or_null("GroundAnchor/VisualRoot/ModelRoot"))
	visual.set_tile_visual_position(Vector2i(3, 4), 1.0)
	assert_eq(visual.position, Vector3(3, 0, 4), "logical position remains on the tile floor")
	assert_eq(visual.visual_root.position, visual.visual_offset, "offset belongs only to VisualRoot")
	assert_eq(visual.visual_root.scale, Vector3.ONE, "procedural root never owns model scale")
	assert_eq(visual.model_root.scale, Vector3.ONE * visual.model_scale)

func test_warrior_recoil_restores_baseline_and_debug_anchor_is_opt_in() -> void:
	var visual := CharacterVisualFactory.create("guerreiro")
	add_child_autofree(visual)
	await get_tree().process_frame
	visual._apply_attack_recoil(true, false)
	await get_tree().create_timer(0.30).timeout
	assert_eq(visual.visual_root.position, visual.visual_offset)
	assert_eq(visual.visual_root.scale, Vector3.ONE)
	assert_eq(visual.model_root.scale, Vector3.ONE * visual.model_scale)
	assert_false(visual._ground_debug_root.visible)
	visual.set_show_ground_anchor(true)
	assert_true(visual._ground_debug_root.visible)

func test_warrior_asset_contains_readable_shield_on_current_rig() -> void:
	var visual := CharacterVisualFactory.create("guerreiro")
	add_child_autofree(visual)
	await get_tree().process_frame
	assert_not_null(visual.skeleton.find_child("HeroShield*", true, false))

func test_warrior_facing_is_strictly_cardinal() -> void:
	var visual := CharacterVisualFactory.create("guerreiro")
	add_child_autofree(visual)
	await get_tree().process_frame
	var cases := {
		Vector3(0, 0, -1): 0.0,
		Vector3(-1, 0, 0): PI * 0.5,
		Vector3(0, 0, 1): PI,
		Vector3(1, 0, 0): -PI * 0.5,
	}
	for direction in cases:
		visual.face_direction(direction, false)
		assert_almost_eq(visual.rotation.y, float(cases[direction]), 0.001)
	visual.face_direction(Vector3(0.8, 0, 0.2), false)
	assert_almost_eq(visual.rotation.y, -PI * 0.5, 0.001, "diagonal input snaps to dominant cardinal axis")

func test_pipeline_profiles_do_not_contain_gameplay_values() -> void:
	var text := FileAccess.get_file_as_string("res://assets/characters/warrior/warrior_3d_profile.tres")
	for forbidden in ["damageMin","damageMax","mpCost","ctCost","hitChance","critChance"]:
		assert_false(forbidden in text,forbidden+" must remain in gameplay data")
