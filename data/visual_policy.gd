extends RefCounted
class_name VisualPolicy

## Fonte única para orçamento, acessibilidade e camadas da apresentação.
## Não contém regras de combate e pode ser trocada sem alterar o GameState.
const QUALITY_LOW := "low"
const QUALITY_MEDIUM := "medium"
const QUALITY_HIGH := "high"

const Z_GROUND_DECAL := -1
const Z_WORLD_EFFECT := 6
const Z_OVERHEAD_EFFECT := 90
const Z_COMBAT_TEXT := 40
const Z_EFFECTS_LAYER := 30
const Z_FEEDBACK_LAYER := 1850

const MAX_TEMPORARY_LIGHTS := {QUALITY_LOW: 3, QUALITY_MEDIUM: 6, QUALITY_HIGH: 10}
const MAX_POPUP_LANES := 5
const POPUP_LANE_HEIGHT := 22.0
const POPUP_COLLISION_RADIUS := 54.0
const MAX_CAMERA_SHAKE := 3.25

const IMPACT_PRESETS := {
	"light": {"radius": 1.15, "strength": 0.32, "leaves": 2, "particle_scale": 0.65},
	"medium": {"radius": 1.65, "strength": 0.52, "leaves": 4, "particle_scale": 0.85},
	"heavy": {"radius": 2.20, "strength": 0.78, "leaves": 6, "particle_scale": 1.0},
	# Tier das Signature Abilities (ETAPA 16): mais forte que HEAVY, mas
	# deliberadamente abaixo de EPIC — destaque vem de timing/composição, não
	# de um evento do tamanho de um boss.
	"signature": {"radius": 2.45, "strength": 0.88, "leaves": 7, "particle_scale": 1.08},
	"epic": {"radius": 2.80, "strength": 1.0, "leaves": 8, "particle_scale": 1.15},
}

static var quality := QUALITY_MEDIUM
static var reduced_motion := false
static var debug_visuals := false

static func quality_scale() -> float:
	return 0.55 if quality == QUALITY_LOW else (1.25 if quality == QUALITY_HIGH else 1.0)

static func temporary_light_budget() -> int:
	return int(MAX_TEMPORARY_LIGHTS.get(quality, MAX_TEMPORARY_LIGHTS[QUALITY_MEDIUM]))

static func impact(name: String) -> Dictionary:
	return IMPACT_PRESETS.get(name, IMPACT_PRESETS["light"])
