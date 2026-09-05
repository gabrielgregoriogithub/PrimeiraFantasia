extends GutTest

func test_every_requested_class_has_a_data_driven_visual_identity() -> void:
	var expected := {
		"guerreiro":"warrior", "ladino":"rogue", "arqueiro":"archer", "mago":"mage",
		"quimico":"chemist", "bardo":"bard", "fada":"fairy", "goblin":"small_enemy",
		"orc":"orc", "xama":"shaman", "troll":"heavy_enemy", "tower_ghost":"fairy",
		"tower_living_fire":"fairy",
	}
	for sprite_key in expected:
		assert_eq(ClassVisualProfiles.key_for_unit({"spriteKey":sprite_key}), expected[sprite_key])

func test_default_profile_is_complete_and_safe_for_unknown_characters() -> void:
	var profile := ClassVisualProfiles.for_unit({"spriteKey":"future_hero"})
	assert_eq(profile["key"], "default")
	for key in ["weight","idle_style","walk_bob","walk_tilt","attack_lunge","hit_recoil","cast_style","particle_profile","trail_profile","victory_style","death_style"]:
		assert_true(profile.has(key), "fallback precisa conter %s" % key)

func test_profiles_change_visuals_without_containing_gameplay_values() -> void:
	var forbidden := ["hp", "mp", "speed", "moveRange", "damage", "range", "crit", "ct", "hitChance"]
	for profile_name in ClassVisualProfiles.PROFILES:
		var profile: Dictionary = ClassVisualProfiles.PROFILES[profile_name]
		for key in forbidden: assert_false(profile.has(key), "%s não pode controlar %s" % [profile_name, key])

func test_warrior_rogue_archer_and_bard_have_distinct_motion_and_attack_signatures() -> void:
	var warrior := ClassVisualProfiles.for_unit({"spriteKey":"guerreiro"})
	var rogue := ClassVisualProfiles.for_unit({"spriteKey":"ladino"})
	var archer := ClassVisualProfiles.for_unit({"spriteKey":"arqueiro"})
	var bard := ClassVisualProfiles.for_unit({"spriteKey":"bardo"})
	assert_lt(warrior["walk_tilt"], rogue["walk_tilt"])
	assert_gt(warrior["footstep_intensity"], rogue["footstep_intensity"])
	assert_gt(warrior["hit_stop"], rogue["hit_stop"])
	assert_gt(archer["ranged_prepare"], bard["ranged_prepare"])
	assert_ne(archer["victory_style"], bard["victory_style"])
	assert_ne(archer["trail_profile"], bard["trail_profile"])

func test_mage_shaman_fairy_troll_and_boss_read_differently() -> void:
	var mage := ClassVisualProfiles.for_unit({"spriteKey":"mago"})
	var shaman := ClassVisualProfiles.for_unit({"spriteKey":"xama"})
	var fairy := ClassVisualProfiles.for_unit({"spriteKey":"fada"})
	var troll := ClassVisualProfiles.for_unit({"spriteKey":"troll"})
	var boss := ClassVisualProfiles.for_unit({"spriteKey":"tower_salamander","footprintWidth":2,"footprintHeight":2})
	assert_eq(mage["cast_style"], "arcane")
	assert_eq(shaman["cast_style"], "organic")
	assert_lt(fairy["footstep_intensity"], mage["footstep_intensity"])
	assert_gt(troll["shadow_scale"].x, fairy["shadow_scale"].x)
	assert_eq(boss["key"], "boss")
	assert_gt(boss["camera_impulse"], troll["camera_impulse"])

func test_character_controller_applies_class_profile_to_existing_visual_root() -> void:
	var host := Node2D.new(); add_child_autofree(host)
	var body := Node2D.new(); host.add_child(body)
	var sprite := Sprite2D.new(); body.add_child(sprite)
	var shadow := Polygon2D.new(); host.add_child(shadow)
	var visual := CharacterVisualController.new()
	visual.configure(host, body, sprite, shadow, {"spriteKey":"bardo"})
	assert_eq(visual.visual_profile_name(), "bard")
	assert_eq(visual.body_weight(), "medium")
	assert_eq(visual.visual_value("cast_style"), "musical")
	assert_not_null(visual.contact_shadow)

func test_unit_tokens_keep_ui_outside_personality_visual_root() -> void:
	var token := UnitToken.new(); add_child_autofree(token)
	token.setup(Units.build()["ladino"].duplicate(true))
	assert_eq(token._character_visual.visual_profile_name(), "rogue")
	assert_eq(token._visual_root.get_parent(), token)
	assert_eq(token._ui_root.get_parent(), token)
	assert_ne(token._ui_root.get_parent(), token._visual_root)
	assert_eq(token._hp_bar.get_parent(), token._ui_root)
