extends RefCounted
class_name MaterialVisualProfiles

## ETAPA 19 — Destruição Visual Não Persistente. Dados exclusivamente
## cosméticos: nenhum campo aqui participa de dano/colisão/regras. Descreve
## só COMO o mundo reage visualmente a um impacto, reutilizando o mesmo
## vocabulário de intensidade de VisualPolicy.IMPACT_PRESETS (LIGHT/MEDIUM/
## HEAVY/SIGNATURE/EPIC) já usado por EnvironmentReactionSystem.
##
## - debris_kind: kind de EffectsLayer.VfxShape usado no fragmento.
## - debris_color: cor base do fragmento (WOOD/STONE herdam tom do
##   material, nunca cinza genérico — regra 117).
## - debris_amount: {light, medium, heavy} — quantidade de fragmentos.
## - spark_chance: chance de faísca extra (golpe metálico contra material duro).
## - shake_amount: multiplicador de reação em EnvironmentPropVisual.react_from.
const PROFILES := {
	"wood": {
		"debris_kind": "pixel", "debris_color": Color("8a5a34"),
		"debris_amount": {"light": 2, "medium": 4, "heavy": 6},
		"spark_chance": 0.0, "shake_amount": 1.0,
	},
	"stone": {
		"debris_kind": "stone", "debris_color": Color(0.58, 0.57, 0.56),
		"debris_amount": {"light": 1, "medium": 2, "heavy": 3},
		"spark_chance": 0.35, "shake_amount": 0.4,
	},
	"metal": {
		"debris_kind": "", "debris_color": Color("d8dbe2"),
		"debris_amount": {"light": 0, "medium": 0, "heavy": 0},
		"spark_chance": 0.85, "shake_amount": 0.55,
	},
	"dirt": {
		"debris_kind": "orb", "debris_color": Color(0.55, 0.42, 0.27),
		"debris_amount": {"light": 3, "medium": 4, "heavy": 5},
		"spark_chance": 0.0, "shake_amount": 0.7,
	},
	"grass": {
		"debris_kind": "leaf", "debris_color": Color(0.42, 0.66, 0.25),
		"debris_amount": {"light": 2, "medium": 3, "heavy": 3},
		"spark_chance": 0.0, "shake_amount": 0.5,
	},
	"water": {
		"debris_kind": "orb", "debris_color": Color("b8efff"),
		"debris_amount": {"light": 3, "medium": 4, "heavy": 6},
		"spark_chance": 0.0, "shake_amount": 0.0,
	},
	"generic": {
		"debris_kind": "orb", "debris_color": Color(0.7, 0.7, 0.72),
		"debris_amount": {"light": 1, "medium": 2, "heavy": 3},
		"spark_chance": 0.0, "shake_amount": 0.6,
	},
}

static func for_material(material: String) -> Dictionary:
	return PROFILES.get(material, PROFILES["generic"])

## Tier LIGHT/MEDIUM/HEAVY já usado por VisualPolicy — SIGNATURE/EPIC contam
## como HEAVY pra fins de quantidade de debris (regra 82: eventos EPIC
## reagem numa área maior, não com debris individual maior).
static func amount_for(material: String, intensity: String) -> int:
	var tier := "heavy" if intensity in ["heavy", "signature", "epic"] else ("medium" if intensity == "medium" else "light")
	return int(for_material(material)["debris_amount"].get(tier, 1))
