class_name CharacterVisualFactory
extends RefCounted

const BASE_SCENE := preload("res://scenes/characters/CharacterVisual3D.tscn")
const PROFILES := {"guerreiro":"res://assets/characters/warrior/warrior_3d_profile.tres"}
static var disable_all_3d_characters := false

static func has_profile(character_id: String) -> bool:
	return not disable_all_3d_characters and PROFILES.has(character_id) and ResourceLoader.exists(PROFILES[character_id])

static func create(character_id: String) -> CharacterVisual3D:
	if not has_profile(character_id): return null
	var visual := BASE_SCENE.instantiate() as CharacterVisual3D
	visual.profile = load(PROFILES[character_id]) as Character3DProfile
	return visual
