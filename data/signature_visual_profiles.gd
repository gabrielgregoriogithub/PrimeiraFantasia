extends RefCounted
class_name SignatureVisualProfiles

## ETAPA 16 — Signature Abilities. Dados exclusivamente cosméticos: nenhum
## campo aqui participa de dano/alcance/CT/regras (mesmo espírito de
## ClassVisualProfiles). Cada entrada casa UM herói com UMA habilidade já
## existente no catálogo (data/spells.gd) e descreve o quanto a apresentação
## dela deve se destacar sobre uma habilidade comum, reaproveitando
## CombatFeedbackManager (câmera), EffectsLayer (VFX/environment reaction) e
## VisualPolicy (nível de impacto) — não cria nenhum sistema paralelo.
##
## Campos:
## - camera_importance: nível passado a CombatFeedbackManager.action_focus.
## - camera_zoom: zoom de pico do micro-focus (0.0 = usa o padrão da tabela).
## - prepare_delay: pausa entre o VFX de preparo e o "golpe" propriamente
##   dito (silhueta/antecipação antes do impacto).
## - impact_delay: pequena pausa entre o golpe e a reação de ambiente/câmera
##   (efeito "hit stop" local, sem mexer no ritmo de turno/IA).
## - environment_intensity: chave de VisualPolicy.IMPACT_PRESETS usada em
##   EffectsLayer.emit_environment_reaction no momento do impacto.
## - environment_element: elemento repassado à mesma chamada ("" = físico).
## - body_light: força de UnitToken.play_magic_body_light (0.0 = nenhuma,
##   evita "brilho mágico" em habilidades sem magia — Guerreiro/Ladino/
##   Arqueiro/Químico).
## - impact_radius_mult: multiplicador aplicado ao raio do burst/explosão
##   final, para o impacto parecer mais cheio sem multiplicar partículas.
const PROFILES := {
	"guerreiro": {
		"match_kind": "spin-attack",
		"camera_importance": "signature", "camera_zoom": 1.05,
		"prepare_delay": 0.14, "impact_delay": 0.07,
		"environment_intensity": "signature", "environment_element": "",
		"body_light": 0.0, "impact_radius_mult": 1.3,
	},
	"ladino": {
		"match_kind": "weakening-strike",
		"camera_importance": "signature", "camera_zoom": 1.03,
		"prepare_delay": 0.05, "impact_delay": 0.0,
		"environment_intensity": "medium", "environment_element": "",
		"body_light": 0.0, "impact_radius_mult": 1.1,
	},
	"arqueiro": {
		"match_target_mode": "pierce-line",
		"camera_importance": "signature", "camera_zoom": 1.04,
		"prepare_delay": 0.10, "impact_delay": 0.0,
		"environment_intensity": "medium", "environment_element": "",
		"body_light": 0.0, "impact_radius_mult": 1.15,
	},
	"mago": {
		"match_name": "Bola de Fogo",
		"camera_importance": "signature", "camera_zoom": 1.06,
		"prepare_delay": 0.24, "impact_delay": 0.0,
		"environment_intensity": "signature", "environment_element": "fire",
		"body_light": 1.25, "impact_radius_mult": 1.2,
	},
	"quimico": {
		"match_name": "Bomba de Fogo",
		"camera_importance": "signature", "camera_zoom": 1.045,
		"prepare_delay": 0.0, "impact_delay": 0.0,
		"environment_intensity": "signature", "environment_element": "fire",
		"body_light": 0.0, "impact_radius_mult": 1.25,
	},
	"bardo": {
		"match_kind": "bard-song-inspiration",
		"camera_importance": "signature", "camera_zoom": 1.02,
		"prepare_delay": 0.12, "impact_delay": 0.0,
		"environment_intensity": "light", "environment_element": "",
		"body_light": 0.9, "impact_radius_mult": 1.15,
	},
}

## Devolve o perfil se `unit` for o herói dono da Signature E `item` for
## exatamente a habilidade escolhida para ela; caso contrário, devolve {}
## (uso: `if not profile.is_empty(): ...`). Casar por spriteKey + kind/
## targetMode/name evita qualquer ambiguidade com habilidades de outros
## personagens que reaproveitem o mesmo kind/targetMode/nome (ex.: Troll
## também tem um "Ataque Giratório", mas com kind "growth-attack").
static func for_item(unit: Dictionary, item: Dictionary) -> Dictionary:
	var hero_key := String(unit.get("spriteKey", ""))
	if not PROFILES.has(hero_key):
		return {}
	var profile: Dictionary = PROFILES[hero_key]
	if profile.has("match_kind") and String(item.get("kind", "")) != profile["match_kind"]:
		return {}
	if profile.has("match_target_mode") and String(item.get("targetMode", "")) != profile["match_target_mode"]:
		return {}
	if profile.has("match_name") and String(item.get("name", "")) != profile["match_name"]:
		return {}
	return profile

static func is_signature(unit: Dictionary, item: Dictionary) -> bool:
	return not for_item(unit, item).is_empty()
