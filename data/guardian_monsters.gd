class_name GuardianMonsters
extends RefCounted

## 33 monstros ("Guardians") portados de lucidtanooki/guardian_monsters
## (guardians.json, id/elemento/nomes das 3 formas por família são fiéis ao
## original — ver data/reference_guardian_monsters_port/README.md). O jogo
## original nunca chegou a balancear estes monstros de verdade
## (guardians.json dá os MESMOS base stats — hp 300/mp 50/tudo mais 10 — pras
## 14 famílias inteiras); os números abaixo são nossos, escalados pro
## intervalo já usado por GameState.dungeon_monster_data/Units.build()
## (hp ~15-45, mesma faixa dos outros grupos de monstro do PVP).
## Sprites: assets/enemies/guardians/<key>/ — ver ATTRIBUTION.md lá (arte
## original de Georg Eckert, CC-BY-SA-4.0).

const ELEMENT_THEME := {
	"earth": {"color": "#8a6a3a", "weapon": "Investida", "spell": "Terremoto"},
	"water": {"color": "#3a7aa0", "weapon": "Mordida", "spell": "Jato d'Água"},
	"fire": {"color": "#c9481f", "weapon": "Chamas", "spell": "Baforada de Fogo"},
	"air": {"color": "#8fd0e0", "weapon": "Investida Alada", "spell": "Rajada Cortante"},
	"demon": {"color": "#5a3d63", "weapon": "Garra Sombria", "spell": "Onda de Temor"},
	"forest": {"color": "#4a7a3a", "weapon": "Folhas Cortantes", "spell": "Fúria da Floresta"},
	"arthropoda": {"color": "#6b7a2e", "weapon": "Picada", "spell": "Teia Pegajosa"},
	"mountain": {"color": "#7a6a5a", "weapon": "Investida Rochosa", "spell": "Avalanche"},
}

## id = número da família em guardians.json. forms = nomes das formas na
## ordem base -> evoluções. element = elemento primário; guardians.json
## também lista um secundário nas evoluções de Fordin/Kroki/Devidin
## ("forest"/"lindworm") — omitido aqui, só afeta flavor no original.
const FAMILIES := [
	{"id": 1, "element": "earth", "forms": ["fordin", "stegofor", "brachifor"]},
	{"id": 2, "element": "water", "forms": ["kroki", "krokivip", "leviadile"]},
	{"id": 3, "element": "fire", "forms": ["devidin", "devidra", "deviraptor"]},
	{"id": 4, "element": "air", "forms": ["aerodin", "aerodeer", "aerostag"]},
	{"id": 5, "element": "demon", "forms": ["weastoat"]},
	{"id": 6, "element": "demon", "forms": ["mooty", "camoon", "moopard"]},
	{"id": 7, "element": "demon", "forms": ["wuppy", "earog", "deemog"]},
	{"id": 8, "element": "forest", "forms": ["dradder", "driper"]},
	{"id": 9, "element": "demon", "forms": ["spreye", "buttereye"]},
	{"id": 10, "element": "arthropoda", "forms": ["duggot", "breem"]},
	{"id": 11, "element": "arthropoda", "forms": ["marvillar", "marvantis"]},
	{"id": 12, "element": "forest", "forms": ["palmpot", "bonsot"]},
	{"id": 13, "element": "mountain", "forms": ["erimat", "erichief"]},
	{"id": 14, "element": "air", "forms": ["eggatch", "owlock"]},
]

const DISPLAY_NAME := {
	"fordin": "Fordin", "stegofor": "Stegofor", "brachifor": "Brachifor",
	"kroki": "Kroki", "krokivip": "Krokivip", "leviadile": "Leviadile",
	"devidin": "Devidin", "devidra": "Devidra", "deviraptor": "Deviraptor",
	"aerodin": "Aerodin", "aerodeer": "Aerodeer", "aerostag": "Aerostag",
	"weastoat": "Weastoat",
	"mooty": "Mooty", "camoon": "Camoon", "moopard": "Moopard",
	"wuppy": "Wuppy", "earog": "Earog", "deemog": "Deemog",
	"dradder": "Dradder", "driper": "Driper",
	"spreye": "Spreye", "buttereye": "Buttereye",
	"duggot": "Duggot", "breem": "Breem",
	"marvillar": "Marvillar", "marvantis": "Marvantis",
	"palmpot": "Palmpot", "bonsot": "Bonsot",
	"erimat": "Erimat", "erichief": "Erichief",
	"eggatch": "Eggatch", "owlock": "Owlock",
}

## Escala por estágio evolutivo (0 = base .. 2 = forma final).
const HP_BY_TIER := [16, 26, 38]
const MP_BY_TIER := [0, 8, 14]
const SPEED_BY_TIER := [10, 11, 12]
const WEAPON_DAMAGE_BY_TIER := [[3, 5], [4, 7], [6, 10]]
const SPELL_DAMAGE_BY_TIER := [[0, 0], [5, 9], [8, 13]]

static func keys() -> Array:
	var out: Array = []
	for family in FAMILIES:
		out.append_array(family["forms"])
	return out

static func build() -> Dictionary:
	var out := {}
	for family in FAMILIES:
		var element: String = family["element"]
		var theme: Dictionary = ELEMENT_THEME[element]
		var forms: Array = family["forms"]
		for stage in forms.size():
			var key: String = forms[stage]
			out[key] = _build_monster(key, element, theme, stage, forms.size())
	return out

## Famílias de forma única (Weastoat) entram direto no patamar "evoluído"
## (tier 1) em vez de ficarem travadas no tier 0 de uma família que nunca
## evolui.
static func _build_monster(key: String, element: String, theme: Dictionary, stage: int, form_count: int) -> Dictionary:
	var tier: int = stage if form_count > 1 else 1

	var weapon_dmg: Array = WEAPON_DAMAGE_BY_TIER[tier]
	var spell_dmg: Array = SPELL_DAMAGE_BY_TIER[tier]
	var weapon_damage_type: String = "fire" if element == "fire" else "physical"

	var weapon := {
		"name": theme["weapon"], "damageMin": weapon_dmg[0], "damageMax": weapon_dmg[1],
		"hitChance": 0.78, "critChance": 0.10 + tier * 0.03, "critMultiplier": 2,
		"ctCost": 50, "minRange": 1, "maxRange": 1, "damageType": weapon_damage_type,
	}
	if element == "fire":
		weapon["appliesBurn"] = {"damageMin": 1, "damageMax": 3, "turns": 3}
	elif element == "arthropoda":
		weapon["appliesPoison"] = {"damageMin": 1, "damageMax": 2, "turns": 3}

	var spells := []
	if tier > 0:
		spells.append({
			"name": theme["spell"], "targetMode": "enemy", "damageMin": spell_dmg[0], "damageMax": spell_dmg[1],
			"hitChance": 0.78, "critChance": 0.05, "critMultiplier": 2, "ctCost": 55, "mpCost": 4 + tier * 2,
			"minRange": 1, "maxRange": 1, "damageType": ("fire" if element == "fire" else "magic"),
		})

	return {
		"name": DISPLAY_NAME[key], "icon": "🐲", "team": "enemy", "x": 0, "y": 0,
		"hp": HP_BY_TIER[tier], "maxHp": HP_BY_TIER[tier],
		"mp": MP_BY_TIER[tier], "maxMp": MP_BY_TIER[tier],
		"moveRange": 3, "speed": SPEED_BY_TIER[tier], "ct": 0,
		"hasMoved": false, "hasActed": false, "statusEffects": [],
		"facing": {"dx": -1, "dy": 0}, "bodyColor": theme["color"], "spriteKey": key,
		"guardianElement": element,
		"weapons": [weapon], "spells": spells,
	}
