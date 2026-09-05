class_name WarriorSkillRegistry
extends RefCounted

# Cosmetic-only mapping. Gameplay values deliberately remain in data/spells.gd.
const VISUALS := {
	"powerAttack": {"kind":"power-attack", "animation":&"SkillPowerAttack", "impact_marker":"cast", "vfx":"power", "camera":"LIGHT", "hit_stop":"LIGHT"},
	"throwSword": {"kind":"throw-sword", "animation":&"SkillThrowSword", "impact_marker":"impact", "vfx":"throw", "camera":"MEDIUM", "hit_stop":"LIGHT"},
	"spinAttack": {"kind":"spin-attack", "animation":&"SkillWhirlwind", "impact_marker":"impact", "vfx":"whirlwind", "camera":"HEAVY", "hit_stop":"HEAVY"},
	"defend": {"kind":"defend", "animation":&"SkillDefend", "impact_marker":"cast", "vfx":"defend", "camera":"NONE", "hit_stop":"NONE"},
}

static func id_for(item: Dictionary) -> String:
	for id in VISUALS:
		var v: Dictionary = VISUALS[id]
		if item.get("kind", "") == v.kind: return id
	if item.get("projectile", "") == "blade" and item.get("name", "") == "Arremessar Espada": return "throwSword"
	return ""
