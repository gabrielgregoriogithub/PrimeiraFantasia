extends RefCounted
class_name ClassVisualProfiles

## Dados exclusivamente cosméticos. Nenhum valor daqui é consultado pelo
## GameState: descrevem somente silhueta, timing visual e feedback já disparado
## pelos eventos de UnitToken.
const DEFAULT := {
	"weight":"medium", "idle_style":"steady", "idle_bob":0.22, "idle_speed":1.0,
	"walk_bob":1.75, "walk_tilt":0.032, "secondary_motion":0.18,
	"acceleration_visual":0.09, "stop_overshoot":1.0, "attack_lunge":20.0,
	"anticipation":0.10, "recovery":0.14, "recoil_strength":1.0,
	"hit_recoil":7.0, "hit_tilt":0.06, "squash":0.07, "hit_stop":0.07,
	"footstep_intensity":0.75, "shadow_scale":Vector2.ONE, "shadow_opacity":1.0,
	"cast_style":"neutral", "particle_profile":"none", "trail_profile":"standard",
	"camera_impulse":0.45, "victory_style":"settle", "death_style":"medium",
	"ranged_prepare":0.58, "ranged_recoil":1.0, "idle_variation":0.12,
}

const PROFILES := {
	"warrior": {"weight":"heavy","idle_style":"disciplined","idle_bob":0.12,"idle_speed":0.72,"walk_bob":1.0,"walk_tilt":0.018,"secondary_motion":0.06,"acceleration_visual":0.12,"stop_overshoot":1.25,"attack_lunge":27.0,"anticipation":0.12,"recovery":0.18,"recoil_strength":0.70,"hit_recoil":5.2,"hit_tilt":0.035,"squash":0.055,"hit_stop":0.085,"footstep_intensity":1.25,"shadow_scale":Vector2(1.16,1.10),"shadow_opacity":1.10,"cast_style":"disciplined","particle_profile":"dust_sparks","trail_profile":"broad_slash","camera_impulse":0.78,"victory_style":"firm","death_style":"heavy","idle_variation":0.05},
	"rogue": {"weight":"light","idle_style":"alert","idle_bob":0.32,"idle_speed":1.38,"walk_bob":2.25,"walk_tilt":0.062,"secondary_motion":0.34,"acceleration_visual":0.045,"stop_overshoot":1.65,"attack_lunge":18.0,"anticipation":0.055,"recovery":0.085,"recoil_strength":1.35,"hit_recoil":8.5,"hit_tilt":0.105,"squash":0.09,"hit_stop":0.035,"footstep_intensity":0.38,"shadow_scale":Vector2(0.84,0.84),"shadow_opacity":0.78,"cast_style":"sleight","particle_profile":"afterimage","trail_profile":"thin_fast","camera_impulse":0.18,"victory_style":"quick_relax","death_style":"light","idle_variation":0.20},
	"archer": {"weight":"medium","idle_style":"focused","idle_bob":0.16,"idle_speed":0.82,"walk_bob":1.42,"walk_tilt":0.025,"secondary_motion":0.16,"acceleration_visual":0.08,"stop_overshoot":0.78,"attack_lunge":12.0,"anticipation":0.14,"recovery":0.12,"recoil_strength":0.65,"hit_recoil":6.6,"hit_tilt":0.055,"squash":0.055,"hit_stop":0.04,"footstep_intensity":0.58,"cast_style":"focused","particle_profile":"minimal","trail_profile":"clean_arrow","camera_impulse":0.30,"victory_style":"controlled","death_style":"medium","ranged_prepare":0.74,"ranged_recoil":0.58,"idle_variation":0.08},
	"mage": {"weight":"medium","idle_style":"arcane","idle_bob":0.52,"idle_speed":0.72,"walk_bob":1.18,"walk_tilt":0.018,"secondary_motion":0.48,"acceleration_visual":0.11,"stop_overshoot":0.72,"attack_lunge":8.0,"anticipation":0.16,"recovery":0.18,"recoil_strength":1.15,"hit_recoil":8.2,"hit_tilt":0.085,"squash":0.075,"hit_stop":0.045,"footstep_intensity":0.32,"shadow_scale":Vector2(0.94,0.90),"shadow_opacity":0.82,"cast_style":"arcane","particle_profile":"arcane","trail_profile":"glow","camera_impulse":0.38,"victory_style":"glow","death_style":"light","idle_variation":0.14},
	"chemist": {"weight":"medium","idle_style":"mechanical","idle_bob":0.25,"idle_speed":1.12,"walk_bob":1.62,"walk_tilt":0.038,"secondary_motion":0.55,"acceleration_visual":0.09,"stop_overshoot":1.22,"attack_lunge":11.0,"anticipation":0.11,"recovery":0.15,"recoil_strength":1.18,"hit_recoil":7.0,"hit_tilt":0.065,"squash":0.07,"hit_stop":0.05,"footstep_intensity":0.72,"cast_style":"equipment","particle_profile":"chemical_puff","trail_profile":"chemical","camera_impulse":0.50,"victory_style":"equipment_check","death_style":"medium","ranged_prepare":0.52,"ranged_recoil":1.18,"idle_variation":0.18},
	"bard": {"weight":"medium","idle_style":"rhythmic","idle_bob":0.40,"idle_speed":1.16,"walk_bob":1.68,"walk_tilt":0.042,"secondary_motion":0.46,"acceleration_visual":0.075,"stop_overshoot":1.35,"attack_lunge":13.0,"anticipation":0.09,"recovery":0.13,"recoil_strength":1.02,"hit_recoil":7.2,"hit_tilt":0.07,"squash":0.075,"hit_stop":0.03,"footstep_intensity":0.62,"cast_style":"musical","particle_profile":"music_notes","trail_profile":"music_wave","camera_impulse":0.12,"victory_style":"rhythmic","death_style":"medium","ranged_prepare":0.46,"ranged_recoil":0.92,"idle_variation":0.22},
	"fairy": {"weight":"light","idle_style":"floating","idle_bob":1.15,"idle_speed":0.78,"walk_bob":1.35,"walk_tilt":0.050,"secondary_motion":0.62,"acceleration_visual":0.05,"stop_overshoot":1.28,"attack_lunge":10.0,"anticipation":0.08,"recovery":0.10,"recoil_strength":1.20,"hit_recoil":8.0,"hit_tilt":0.09,"squash":0.06,"hit_stop":0.025,"footstep_intensity":0.05,"shadow_scale":Vector2(0.68,0.62),"shadow_opacity":0.52,"cast_style":"wind","particle_profile":"wind_sparkles","trail_profile":"wind_curve","camera_impulse":0.08,"victory_style":"rise","death_style":"floating","idle_variation":0.16},
	"small_enemy": {"weight":"light","idle_style":"skittish","idle_bob":0.34,"idle_speed":1.42,"walk_bob":2.15,"walk_tilt":0.065,"secondary_motion":0.22,"acceleration_visual":0.05,"stop_overshoot":1.48,"attack_lunge":17.0,"anticipation":0.06,"recovery":0.09,"recoil_strength":1.42,"hit_recoil":9.0,"hit_tilt":0.11,"squash":0.10,"hit_stop":0.035,"footstep_intensity":0.34,"shadow_scale":Vector2(0.82,0.80),"shadow_opacity":0.72,"cast_style":"wild","particle_profile":"minimal","trail_profile":"thin_fast","camera_impulse":0.16,"victory_style":"skittish","death_style":"light","idle_variation":0.24},
	"orc": {"weight":"heavy","idle_style":"aggressive","idle_bob":0.20,"idle_speed":0.92,"walk_bob":1.18,"walk_tilt":0.035,"secondary_motion":0.18,"acceleration_visual":0.12,"stop_overshoot":1.35,"attack_lunge":25.0,"anticipation":0.13,"recovery":0.20,"recoil_strength":0.88,"hit_recoil":6.2,"hit_tilt":0.055,"squash":0.07,"hit_stop":0.08,"footstep_intensity":1.18,"shadow_scale":Vector2(1.18,1.10),"shadow_opacity":1.08,"cast_style":"wild","particle_profile":"dust","trail_profile":"rough_slash","camera_impulse":0.68,"victory_style":"aggressive","death_style":"heavy","idle_variation":0.10},
	"shaman": {"weight":"medium","idle_style":"organic","idle_bob":0.42,"idle_speed":0.68,"walk_bob":1.30,"walk_tilt":0.028,"secondary_motion":0.42,"acceleration_visual":0.10,"stop_overshoot":0.88,"attack_lunge":9.0,"anticipation":0.16,"recovery":0.19,"recoil_strength":1.0,"hit_recoil":7.4,"hit_tilt":0.075,"squash":0.07,"hit_stop":0.045,"footstep_intensity":0.58,"cast_style":"organic","particle_profile":"leaves_roots","trail_profile":"organic","camera_impulse":0.32,"victory_style":"grounded","death_style":"medium","idle_variation":0.15},
	"heavy_enemy": {"weight":"heavy","idle_style":"massive","idle_bob":0.11,"idle_speed":0.66,"walk_bob":0.82,"walk_tilt":0.017,"secondary_motion":0.12,"acceleration_visual":0.15,"stop_overshoot":1.55,"attack_lunge":29.0,"anticipation":0.16,"recovery":0.24,"recoil_strength":0.62,"hit_recoil":4.5,"hit_tilt":0.03,"squash":0.055,"hit_stop":0.10,"footstep_intensity":1.55,"shadow_scale":Vector2(1.30,1.20),"shadow_opacity":1.16,"cast_style":"massive","particle_profile":"heavy_dust","trail_profile":"heavy","camera_impulse":0.88,"victory_style":"massive","death_style":"heavy","idle_variation":0.05},
	"boss": {"weight":"giant","idle_style":"boss","idle_bob":0.08,"idle_speed":0.58,"walk_bob":0.62,"walk_tilt":0.012,"secondary_motion":0.16,"acceleration_visual":0.18,"stop_overshoot":1.75,"attack_lunge":34.0,"anticipation":0.18,"recovery":0.27,"recoil_strength":0.48,"hit_recoil":3.8,"hit_tilt":0.022,"squash":0.045,"hit_stop":0.12,"footstep_intensity":1.8,"shadow_scale":Vector2(1.72,1.52),"shadow_opacity":1.22,"cast_style":"boss","particle_profile":"ambient_heat","trail_profile":"boss_heavy","camera_impulse":1.0,"victory_style":"boss","death_style":"heavy","idle_variation":0.03},
}

## Ajustes artesanais de encaixe visual. São offsets em pixels e escalas de
## apresentação; nunca participam de alcance, colisão ou regras do tabuleiro.
const CHARACTER_TUNING := {
	"default": {"projectile_forward":16.0,"projectile_y":-10.0,"impact_y":-12.0,"overhead_y":-88.0,"status_scale":1.0,"grounding":1.0},
	"warrior": {"impact_y":-14.0,"overhead_y":-91.0,"status_scale":1.03,"grounding":1.10},
	"rogue": {"impact_y":-13.0,"overhead_y":-87.0,"status_scale":0.94,"grounding":0.86},
	"archer": {"projectile_forward":23.0,"projectile_y":-15.0,"impact_y":-15.0,"overhead_y":-91.0,"status_scale":0.98,"release_style":"precise"},
	"mage": {"projectile_forward":17.0,"projectile_y":-19.0,"impact_y":-15.0,"overhead_y":-94.0,"status_scale":1.0,"release_style":"staff"},
	"chemist": {"projectile_forward":21.0,"projectile_y":-9.0,"impact_y":-14.0,"overhead_y":-91.0,"status_scale":1.02,"release_style":"equipment"},
	"bard": {"projectile_forward":19.0,"projectile_y":-11.0,"impact_y":-14.0,"overhead_y":-93.0,"status_scale":1.0,"release_style":"casual"},
	"fairy": {"projectile_forward":14.0,"projectile_y":-18.0,"impact_y":-16.0,"overhead_y":-82.0,"status_scale":0.82,"grounding":0.66},
	"small_enemy": {"impact_y":-10.0,"overhead_y":-70.0,"status_scale":0.78,"grounding":0.78},
	"orc": {"impact_y":-17.0,"overhead_y":-96.0,"status_scale":1.08,"grounding":1.14},
	"shaman": {"projectile_forward":15.0,"projectile_y":-17.0,"impact_y":-15.0,"overhead_y":-92.0,"status_scale":1.02,"release_style":"organic"},
	"heavy_enemy": {"impact_y":-21.0,"overhead_y":-108.0,"status_scale":1.20,"grounding":1.28},
	"boss": {"impact_y":-39.0,"overhead_y":-154.0,"status_scale":1.55,"grounding":1.62},
}

static func key_for_unit(unit: Dictionary) -> String:
	var key := String(unit.get("visualProfile", unit.get("spriteKey", "")))
	var footprint := maxi(int(unit.get("footprintWidth", unit.get("footprintSize", 1))), int(unit.get("footprintHeight", unit.get("footprintSize", 1))))
	if footprint > 1: return "boss"
	match key:
		"guerreiro": return "warrior"
		"ladino": return "rogue"
		"arqueiro": return "archer"
		"mago": return "mage"
		"quimico": return "chemist"
		# Monge: lutador leve e rápido — reaproveita o perfil do Ladino
		# ("rogue": pouca antecipação, recuperação curta, passo leve) em vez
		# de inventar um perfil só pra ele. É 100% cosmético.
		"monge": return "rogue"
		# Samurai: espadachim de armadura pesada — mesmo perfil do Guerreiro
		# ("warrior": golpe com peso, passo firme). 100% cosmético.
		"samurai": return "warrior"
		# Vestruz: ave veloz e voadora — mesmo perfil leve da Fada/Ladino
		# (sem peso no passo). Cosmético.
		"vestruz": return "rogue"
		"bardo": return "bard"
		"fada", "fantasma", "fogo_vivo", "tower_ghost", "tower_living_fire": return "fairy"
		"goblin", "spd_rat", "spd_snake", "spd_slime": return "small_enemy"
		"orc": return "orc"
		"xama": return "shaman"
		"troll", "spd_gnoll", "spd_goo", "dragon": return "heavy_enemy"
		# Pedido do usuário: Demônio das Chamas conjura com cajado/gema, igual
		# ao Mago — reaproveita o mesmo perfil "mage" (release_style "staff",
		# cast_style/particle_profile "arcane") em vez de inventar um perfil
		# próprio só pra isso.
		"flame_demon", "lich": return "mage"
	return "default"

static func for_unit(unit: Dictionary) -> Dictionary:
	var result := DEFAULT.duplicate(true)
	var key := key_for_unit(unit)
	if PROFILES.has(key): result.merge(PROFILES[key], true)
	result.merge(CHARACTER_TUNING["default"], true)
	if CHARACTER_TUNING.has(key): result.merge(CHARACTER_TUNING[key], true)
	result["key"] = key
	return result
