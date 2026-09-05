class_name Units
extends RefCounted

## Porte literal das create<Personagem>State() (game.js:1586-1944). Cada
## entrada é um TEMPLATE (dicionário puro) — GameState é quem instancia uma
## cópia por partida (equivalente a `const guerreiro = createGuerreiroState()`
## + `resetGame()` no original). Nomes de campos preservados: team, x, y, hp,
## maxHp, moveRange, speed, ct, mp, statusEffects, facing, spriteKey, weapons,
## spells (ver AGENTS.md do protótipo).

static func build() -> Dictionary:
	var w := Weapons.build()
	var s := Spells.build()
	return {
		"guerreiro": {
			"name": "Guerreiro", "icon": "⚔️", "team": "player", "x": 2, "y": 5,
			"hp": 35, "maxHp": 35, "moveRange": 4, "speed": 10, "ct": 0, "mp": 6, "maxMp": 6,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": 1, "dy": 0}, "bodyColor": "#6b7a99", "spriteKey": "guerreiro",
			"passiveDamageReduction": 1,
			"weapons": [w["sword"], w["shield"]],
			"spells": [s["powerAttack"], s["throwSword"], s["defend"], s["spinAttack"]],
		},
		"arqueiro": {
			"name": "Arqueiro", "icon": "🏹", "team": "player", "x": 2, "y": 7,
			"hp": 25, "maxHp": 25, "moveRange": 5, "speed": 11, "ct": 0, "mp": 8, "maxMp": 8,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": 1, "dy": 0}, "bodyColor": "#5c8a52", "spriteKey": "arqueiro",
			"weapons": [w["bow"], w["dagger"]],
			"spells": [s["trueShot"], s["fireArrow"], s["iceArrow"], s["pierceShot"], s["quickShot"], s["longShot"]],
			"singleSelfAbilityPerTurn": true,
		},
		"mago": {
			"name": "Mago", "icon": "🧙", "team": "player", "x": 2, "y": 9,
			"hp": 20, "maxHp": 20, "moveRange": 4, "speed": 10, "ct": 0, "mp": 30, "maxMp": 30,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": 1, "dy": 0}, "bodyColor": "#3a5ba0", "spriteKey": "mago",
			"weapons": [w["cajado"], w["iceRay"]],
			"spells": [s["fireball"], s["missile"], s["lightning"], s["iceCone"], s["cure"], s["regenAoe"], s["resurrect"]],
		},
		"ladino": {
			"name": "Ladino", "icon": "🥷", "team": "player", "x": 2, "y": 11,
			"hp": 25, "maxHp": 25, "moveRange": 5, "speed": 12, "ct": 0, "mp": 10, "maxMp": 10,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": 1, "dy": 0},
			"backstabBonus": {"side": [1, 2], "back": [2, 4], "invisible": [2, 4]}, "hasOpportunityAttack": true, "magicEvasion": 0.1,
			"bodyColor": "#4a3b63", "spriteKey": "ladino",
			"weapons": [w["crossbow"], w["dirk"]],
			"spells": [s["invisibility"], s["weakeningStrike"], s["trap"]],
		},
		"goblin": {
			"name": "Goblin", "icon": "👹", "team": "enemy", "x": 10, "y": 5,
			"hp": 30, "maxHp": 30, "moveRange": 4, "speed": 12, "ct": 0, "mp": 8, "maxMp": 8,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": -1, "dy": 0}, "innateEvasion": 0.1,
			"bodyColor": "#6b7a3a", "spriteKey": "goblin",
			"weapons": [w["shortSword"], w["sling"]],
			"spells": [s["agility"], s["swiftFeet"], s["evasiveManeuver"]],
		},
		"orc": {
			"name": "Orc", "icon": "🧌", "team": "enemy", "x": 10, "y": 7,
			"hp": 40, "maxHp": 40, "moveRange": 5, "speed": 9, "ct": 0, "mp": 6, "maxMp": 6,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": -1, "dy": 0},
			"counterAttackChance": 0.2, "counterWeapon": w["axe"],
			"bodyColor": "#7a3d2e", "spriteKey": "orc",
			"weapons": [w["axe"], w["club"]],
			"spells": [s["fury"], s["berserk"], s["charge"]],
		},
		"xama": {
			"name": "Xamã", "icon": "🧙‍♀️", "iconTint": "witch-tint", "team": "enemy",
			"x": 10, "y": 9, "hp": 25, "maxHp": 25, "moveRange": 3, "speed": 11, "ct": 0,
			"mp": 20, "maxMp": 20, "hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": -1, "dy": 0}, "bodyColor": "#5a3d7a", "spriteKey": "xama",
			"weapons": [w["zarabatana"]],
			"spells": [s["cure"], s["regenAoe"], s["resurrect"], s["creepingDestruction"], s["poisonCone"], s["vinePrison"]],
		},
		"fada": {
			"name": "Fada", "icon": "🧚", "team": "enemy", "x": 10, "y": 11,
			"hp": 20, "maxHp": 20, "moveRange": 4, "speed": 13, "ct": 0, "mp": 20, "maxMp": 20,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": -1, "dy": 0}, "flying": true,
			"bodyColor": "#d67ab8", "spriteKey": "fada",
			"weapons": [w["shock"], w["light"]],
			"spells": [s["paralysis"], s["cure"], s["regenAoe"], s["resurrect"], s["soundBlast"], s["windstorm"]],
		},
		"quimico": {
			"name": "Químico", "icon": "🧑‍🔬", "team": "player", "x": 2, "y": 3,
			"hp": 20, "maxHp": 20, "moveRange": 4, "speed": 10, "ct": 0, "mp": 20, "maxMp": 20,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": 1, "dy": 0}, "bodyColor": "#c9c9d4", "spriteKey": "quimico",
			"weapons": [w["firearm"]],
			"spells": [
				s["healPotion"], s["manaPotion"], s["antidote"], s["bomb"], s["iceBomb"],
				s["regenAoeAlchemist"], s["resurrectAlchemist"], s["explosiveShot"],
			],
		},
		"bardo": {
			"name":"Bardo", "icon":"🎵", "team":"player", "x":3, "y":1,
			"hp":25, "maxHp":25, "moveRange":4, "speed":11, "ct":0, "mp":15, "maxMp":15,
			"hasMoved":false, "hasActed":false, "statusEffects":[],
			"facing":{"dx":1,"dy":0}, "innateEvasion":0.1,
			"bodyColor":"#b83b3b", "spriteKey":"bardo",
			"weapons":[w["bardCrossbow"]],
			"spells":[s["bardSongHeal"],s["bardSongInspiration"],s["bardSongDistraction"],s["bardSongPain"]],
		},
		"troll": {
			"name": "Troll", "icon": "👺", "team": "enemy", "x": 10, "y": 3,
			"hp": 50, "maxHp": 50, "moveRange": 4, "speed": 8, "ct": 0, "mp": 10, "maxMp": 10,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": -1, "dy": 0},
			"hpRegenPerTurn": 1, "counterAttackChance": 0.1, "counterWeapon": w["trollCounter"],
			"bodyColor": "#5a6b52", "spriteKey": "troll",
			"weapons": [w["trunk"], w["throwLog"]],
			"spells": [s["regenBoost"], s["growth"], s["trample"]],
		},
	}

## Ordem de criação/times igual ao original (game.js:1886-1898):
## playerTeam = [guerreiro, arqueiro, mago, ladino, quimico]
## enemyTeam  = [goblin, orc, xama, fada, troll]
static func player_team_keys() -> Array:
	return ["guerreiro", "arqueiro", "mago", "ladino", "quimico", "bardo"]

static func enemy_team_keys() -> Array:
	return ["goblin", "orc", "xama", "fada", "troll"]
