extends GutTest

const PROFILES := preload("res://data/class_visual_profiles.gd")
const UNIT_TOKEN := preload("res://scenes/unit_token.gd")
const UNITS := preload("res://data/units.gd")

func test_six_heroes_have_distinct_hand_tuned_projectile_and_motion_identities() -> void:
	var expected := {
		"guerreiro":"warrior", "ladino":"rogue", "arqueiro":"archer",
		"mago":"mage", "quimico":"chemist", "bardo":"bard",
	}
	var catalog := UNITS.build()
	for key in expected:
		var profile := PROFILES.for_unit(catalog[key])
		assert_eq(profile["key"], expected[key])
		for field in ["impact_y","overhead_y","status_scale","grounding"]:
			assert_true(profile.has(field), "%s possui %s" % [key, field])
	assert_gt(float(PROFILES.for_unit(catalog["arqueiro"])["ranged_prepare"]), float(PROFILES.for_unit(catalog["bardo"])["ranged_prepare"]), "arqueiro estabiliza; bardo usa snap casual")
	assert_gt(float(PROFILES.for_unit(catalog["quimico"])["ranged_recoil"]), float(PROFILES.for_unit(catalog["arqueiro"])["ranged_recoil"]), "equipamento do químico reage mais")

func test_mass_controls_grounding_status_and_critical_displacement() -> void:
	var catalog := UNITS.build()
	var rogue := PROFILES.for_unit(catalog["ladino"])
	var warrior := PROFILES.for_unit(catalog["guerreiro"])
	var troll := PROFILES.for_unit(catalog["troll"])
	assert_lt(float(rogue["grounding"]), float(warrior["grounding"]))
	assert_lt(float(warrior["grounding"]), float(troll["grounding"]))
	assert_gt(float(rogue["hit_recoil"]), float(warrior["hit_recoil"]))
	assert_gt(float(troll["status_scale"]), float(rogue["status_scale"]))

func test_large_footprint_uses_boss_tuning_and_large_overhead_clearance() -> void:
	var salamander := {"spriteKey":"tower_salamander","footprintWidth":2,"footprintHeight":2}
	var profile := PROFILES.for_unit(salamander)
	assert_eq(profile["key"], "boss")
	assert_gte(float(profile["grounding"]), 1.5)
	assert_lte(float(profile["overhead_y"]), -140.0)
	assert_gte(float(profile["status_scale"]), 1.5)

func test_projectile_origins_are_character_specific_and_flip_safe() -> void:
	var catalog := UNITS.build()
	var origins: Dictionary = {}
	for key in ["arqueiro","mago","quimico","bardo"]:
		var token := UNIT_TOKEN.new()
		add_child_autofree(token)
		token.setup((catalog[key] as Dictionary).duplicate(true))
		await wait_process_frames(1)
		var right := token.projectile_visual_origin(token.position + Vector2.RIGHT * 100.0, "bolt") - token.position
		var left := token.projectile_visual_origin(token.position + Vector2.LEFT * 100.0, "bolt") - token.position
		assert_almost_eq(right.x, -left.x, 0.01, key)
		assert_almost_eq(right.y, left.y, 0.01, key)
		origins[key] = right
	assert_ne(origins["arqueiro"], origins["bardo"])
	assert_ne(origins["quimico"], origins["mago"])
