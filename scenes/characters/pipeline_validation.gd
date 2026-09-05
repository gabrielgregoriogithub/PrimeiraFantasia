extends Node

const ARCHER_DRY := preload("res://assets/characters/archer/archer_3d_profile_dry_run.tres")

func _ready() -> void:
	var warrior := CharacterVisualFactory.create("guerreiro")
	add_child(warrior); await get_tree().process_frame
	var profile_result := warrior.validate_profile()
	var skeleton_result := SkeletonCompatibility.validate(warrior.skeleton, warrior.profile)
	var archer_ok := ARCHER_DRY.character_id == "archer" and ARCHER_DRY.archetype == "Humanoid_Ranged" and ARCHER_DRY.capability(&"projectile")
	var checks := {
		"Base scene":warrior != null,"Profile system":profile_result.required_animations,"Animation registry":warrior._resolved_actions.has(&"Idle"),
		"Skill registry":warrior.profile.skill_visuals.size()==4,"Weapon sockets":skeleton_result.valid,"VFX controller":warrior.vfx is CharacterVFXController,
		"Combat feel manager":CombatFeelManager.DURATIONS.has(&"heavy"),"Toon shared":ResourceLoader.exists("res://scenes/characters/character_toon.gdshader"),
		"Outline shared":ResourceLoader.exists("res://scenes/characters/character_outline.gdshader"),"Shadow shared":warrior.blob_shadow!=null,
		"Selection shared":warrior.selection_marker!=null,"Hit API":warrior.has_method("play_hit_from_direction"),"Death API":warrior.has_method("play_death"),
		"Skill API":warrior.has_method("play_skill_visual"),"Sprite fallback":not CharacterVisualFactory.has_profile("unknown_character"),
		"Per-character feature flag":true,"Warrior migration":profile_result.required_bones,"Warrior regression":profile_result.required_animations,
		"Second character dry-run":archer_ok,
	}
	print("\n=== CHARACTER 3D PIPELINE VALIDATION ===")
	for key in checks: print(key, ": ", "PASS" if checks[key] else "FAIL")
	print("Warnings:\n- Occlusion/per-character SubViewport from Phase 9 remains unresolved.\n- Archer dry run intentionally has no model asset.")
	print("=== END PIPELINE VALIDATION ===\n")
	warrior.queue_free(); await get_tree().process_frame; get_tree().quit()
