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
			"spells": [s["trueShot"], s["fireArrow"], s["iceArrow"], s["pierceShot"], s["quickShot"], s["longShot"], s["arrowRain"]],
			"singleSelfAbilityPerTurn": true,
		},
		"mago": {
			"name": "Mago", "icon": "🧙", "team": "player", "x": 2, "y": 9,
			"hp": 20, "maxHp": 20, "moveRange": 4, "speed": 10, "ct": 0, "mp": 30, "maxMp": 30,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": 1, "dy": 0}, "bodyColor": "#3a5ba0", "spriteKey": "mago",
			"weapons": [w["cajado"], w["iceRay"]],
			"spells": [s["fireball"], s["missile"], s["lightning"], s["iceCone"]],
		},
		"ladino": {
			"name": "Ladino", "icon": "🥷", "team": "player", "x": 2, "y": 11,
			"hp": 25, "maxHp": 25, "moveRange": 5, "speed": 12, "ct": 0, "mp": 10, "maxMp": 10,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": 1, "dy": 0},
			"backstabBonus": {"side": [1, 2], "back": [2, 4], "invisible": [2, 4]}, "hasOpportunityAttack": true, "magicEvasion": 0.1,
			"bodyColor": "#4a3b63", "spriteKey": "ladino",
			"weapons": [w["crossbow"], w["dirk"]],
			"spells": [s["invisibility"], s["weakeningStrike"], s["trap"], s["agility"], s["swiftFeet"], s["evasiveManeuver"], s["stealHp"], s["stealMp"], s["stealCt"]],
		},
		"goblin": {
			"name": "Goblin", "icon": "👹", "team": "enemy", "x": 10, "y": 5,
			"hp": 30, "maxHp": 30, "moveRange": 4, "speed": 12, "ct": 0, "mp": 10, "maxMp": 10,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": -1, "dy": 0}, "innateEvasion": 0.1,
			"bodyColor": "#6b7a3a", "spriteKey": "goblin",
			"weapons": [w["dagger"], w["sling"]],
			# Pedido do usuário: 4 das 10 habilidades ativas foram pro Kobold (ver
			# "kobold" logo abaixo); Pés Ágeis voltou pro Goblin depois.
			"spells": [s["agility"], s["swiftFeet"], s["evasiveManeuver"], s["sandInEyes"], s["stolenBarrel"], s["playDead"]],
		},
		# Pedido do usuário: Kobold, combatente ágil e astuto dos Goblinoides.
		# Recebeu do Goblin as habilidades de veneno/emboscada/mobilidade/
		# ataque oportunista (Golpe Baixo, Poção Venenosa, Bater e Correr,
		# Emboscada Kobold — ex-Emboscada Goblin), sem alterar nenhum número
		# delas. Pés Ágeis voltou pro Goblin a pedido do usuário.
		# Passivas: Escamas Protetoras (physicalDamageReduction, ver
		# GameState.resolve_single_hit) e Sangue Dracônico (elementAffinity
		# fire ×0.75, mesma regra de arredondamento das demais afinidades).
		"kobold": {
			"name": "Kobold", "icon": "🦎", "team": "enemy", "x": 8, "y": 6,
			"hp": 20, "maxHp": 20, "moveRange": 4, "speed": 12, "ct": 0, "mp": 10, "maxMp": 10,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": -1, "dy": 0},
			"physicalDamageReduction": 1,
			"elementAffinity": {"fire": {"mode": "damage", "multiplier": 0.75, "passive": "Sangue Dracônico"}},
			"passives": [
				{"name": "Escamas Protetoras", "description": "Reduz em 1 cada dano físico recebido (mínimo 1 se o golpe causaria dano). Não afeta dano mágico nem dano por turno de status."},
				{"name": "Sangue Dracônico", "description": "Recebe 25% menos dano de fogo."},
			],
			"bodyColor": "#c8502a", "spriteKey": "kobold",
			"weapons": [w["koboldPoisonDagger"], DataUtil.merge(w["koboldSpear"], {"minRange": w["zarabatana"]["minRange"], "maxRange": w["zarabatana"]["maxRange"], "requiresClearPath": w["zarabatana"]["requiresClearPath"]})],
			"spells": [s["lowBlow"], s["poisonPotion"], s["hitAndRun"], s["goblinAmbush"]],
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
			"spells": [s["cure"], s["regenAoe"], s["resurrect"], s["creepingDestruction"], s["poisonCone"], s["vinePrison"], s["reincarnation"]],
		},
		"fada": {
			"name": "Fada", "icon": "🧚", "team": "enemy", "x": 10, "y": 11,
			"hp": 20, "maxHp": 20, "moveRange": 4, "speed": 13, "ct": 0, "mp": 20, "maxMp": 20,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": -1, "dy": 0}, "flying": true,
			"bodyColor": "#d67ab8", "spriteKey": "fada",
			"weapons": [w["shock"], w["light"]],
			"spells": [s["paralysis"], s["cure"], s["regenAoe"], s["resurrect"], s["soundBlast"], s["windstorm"], s["reincarnation"]],
		},
		"quimico": {
			"name": "Químico", "icon": "🧑‍🔬", "team": "player", "x": 2, "y": 3,
			"hp": 20, "maxHp": 20, "moveRange": 4, "speed": 10, "ct": 0, "mp": 20, "maxMp": 20,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": 1, "dy": 0}, "bodyColor": "#c9c9d4", "spriteKey": "quimico",
			"weapons": [w["firearm"]],
			"spells": [
				s["healPotion"], s["manaPotion"], s["antidote"], s["bomb"], s["iceBomb"],
				s["regenAoeAlchemist"], s["resurrectAlchemist"], s["reincarnation"], s["explosiveShot"],
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
		# Pedido do usuário: Monge. Funda é LITERALMENTE a mesma arma do
		# Goblin (w["sling"] — mesmo alcance, custo, acerto, dano e projétil),
		# não uma cópia com números repetidos.
		"monge": {
			"name": "Monge", "icon": "🧘", "team": "player", "x": 3, "y": 3,
			"hp": 30, "maxHp": 30, "moveRange": 8, "speed": 11, "ct": 0, "mp": 10, "maxMp": 10,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": 1, "dy": 0}, "bodyColor": "#c8873f", "spriteKey": "monge",
			"weapons": [w["monkPunch"], w["sling"]],
			"spells": [s["monkFocus"], s["monkDash"], s["dragonKick"], s["monkMeditate"], s["monkFlurry"]],
		},
		# Pedido do usuário: Samurai. O Arco é o mesmo w["bow"] do Arqueiro (mesmo
		# alcance/acerto/crítico/dano/CT/projétil); só ganha "spriteAction" pra
		# usar a pose de saque da katana como pose de tiro (o Samurai não tem
		# arte de arco).
		"samurai": {
			"name": "Samurai", "icon": "🏯", "team": "player", "x": 3, "y": 5,
			"hp": 40, "maxHp": 40, "moveRange": 3, "speed": 9, "ct": 0, "mp": 6, "maxMp": 6,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": 1, "dy": 0}, "bodyColor": "#a3242b", "spriteKey": "samurai",
			"weapons": [w["samuraiSword"], DataUtil.merge(w["bow"], {"spriteAction": "bow"})],
			"spells": [s["samuraiDualWield"], s["samuraiQuickDraw"], s["samuraiMeditate"], s["samuraiIaijutsu"], s["samuraiHeronStance"], s["samuraiGuardBreak"], s["samuraiCrescentSlash"], s["samuraiWindSlash"], s["samuraiLastResolve"]],
		},
		# Pedido do usuário: Vestruz, montaria voadora que também age sozinha.
		# `flying` é o MESMO campo booleano da Fada (mesma mecânica de voo);
		# `isMount` habilita a montaria (ver GameState.mount_unit). O alcance do
		# Cuspe Afiado vem do Arremessar Espada do Guerreiro.
		"vestruz": {
			"name": "Vestruz", "icon": "🐦", "team": "player", "x": 3, "y": 9,
			"hp": 30, "maxHp": 30, "moveRange": 7, "speed": 12, "ct": 0, "mp": 6, "maxMp": 6,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": 1, "dy": 0}, "flying": true, "isMount": true,
			"bodyColor": "#e0a63a", "spriteKey": "vestruz",
			"weapons": [DataUtil.merge(w["vestruzSpit"], {"minRange": s["throwSword"]["minRange"], "maxRange": s["throwSword"]["maxRange"], "cardinalOnly": s["throwSword"]["cardinalOnly"]})],
			"spells": [s["vestruzKick"], s["vestruzDash"], s["vestruzDust"], s["vestruzHeal"]],
		},
		# Pedido do usuário: Troncus, guardião-árvore 2x2 dos Goblinoides
		# (tanque/controle). Slot (8,3) no Campo: como os outros slots do time
		# inimigo, cabe um corpo 2x2 depois do embaralhamento de posições.
		# Passivas: Casca Espessa (physicalDamageReduction), Corpo Vegetal
		# (statusImmunities), Madeira Inflamável (elementAffinity fire ×1.5) e
		# Raízes Regeneradoras (rootRegen, ver GameState._apply_root_regen).
		"troncus": {
			"name": "Troncus", "icon": "🌳", "team": "enemy", "x": 8, "y": 3,
			"description": "Um antigo guardião da floresta, formado por troncos, raízes e folhas. Seus punhos esmagam invasores, seus cipós dificultam a fuga e suas raízes prendem aqueles que ameaçam seus aliados. Sua seiva restaura a vitalidade, principalmente quando permanece imóvel.",
			"hp": 45, "maxHp": 45, "moveRange": 3, "speed": 7, "ct": 0, "mp": 15, "maxMp": 15,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": -1, "dy": 0},
			"footprintWidth": 2, "footprintHeight": 2, "footprintSize": 2,
			"physicalDamageReduction": 1,
			"statusImmunities": ["poison"],
			"elementAffinity": {"fire": {"mode": "damage", "multiplier": 1.5, "passive": "Madeira Inflamável"}},
			"rootRegen": {"moved": 2, "still": 4},
			"passives": [
				{"name": "Casca Espessa", "description": "Reduz em 1 cada dano físico recebido (mínimo 1 se o golpe causaria dano)."},
				{"name": "Corpo Vegetal", "description": "Imune a Envenenado.", "status": "poison"},
				{"name": "Madeira Inflamável", "description": "Recebe 50% a mais de dano de fogo."},
				{"name": "Raízes Regeneradoras", "description": "No fim de cada turno recupera 2 HP; se não se deslocou nesse turno, recupera 4 HP."},
			],
			"bodyColor": "#6b4a2a", "spriteKey": "troncus",
			"weapons": [w["troncusPunch"], w["troncusVineWhip"]],
			"spells": [s["troncusRoots"], s["troncusBranchSweep"], s["troncusBarkArmor"], s["troncusSap"]],
		},
		# Pedido do usuário: Lobo dos Goblinoides (1x1, montaria de goblinoides
		# de 1 casa — `mountRiderGroup`). Arte "montado" combinada por
		# cavaleiro em <pasta>/<cavaleiro>_lobo_<direção>.png (ver
		# UnitToken.mounted_art_path); `riderOverlay` é só a reserva pra quem
		# não tiver essa arte (cavaleiro desenhado por cima). Passivas: Instinto de Matilha
		# (`packInstinct`) e Contra-ataque de Mordida (counterAttackChance +
		# `counterMeleeOnly`, só golpe corpo a corpo, nunca revida um revide).
		# Slot (8,9) no Campo: cabe um corpo 2x2 depois do embaralhamento.
		"lobo": {
			"name": "Lobo", "icon": "🐺", "team": "enemy", "x": 8, "y": 9,
			"description": "Criado pelos goblinoides para caçar e proteger seus acampamentos, esse lobo persegue inimigos, luta em matilha e pode carregar pequenos goblinoides.",
			"hp": 25, "maxHp": 25, "moveRange": 5, "speed": 13, "ct": 0, "mp": 10, "maxMp": 10,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": -1, "dy": 0},
			"isMount": true, "mountRiderGroup": "goblinoides", "riderOverlay": true,
			"packInstinct": {"damageBonus": 2},
			"counterAttackChance": 0.15, "counterMeleeOnly": true, "counterWeapon": w["wolfBite"],
			"passives": [
				{"name": "Instinto de Matilha", "description": "+2 de dano físico quando outro lobo ou goblinoide aliado está adjacente ao alvo (uma vez por ataque)."},
				{"name": "Contra-ataque de Mordida", "description": "Ao levar um golpe corpo a corpo que acerta: 15% de chance de revidar com uma Mordida (4-8 de dano, cura 1-2 HP), sem gastar MP nem o turno."},
				{"name": "Montaria dos Goblinoides", "description": "Pode carregar um goblinoide que ocupe 1 quadrado."},
			],
			"bodyColor": "#5b5f66", "spriteKey": "lobo",
			"weapons": [w["wolfBite"]],
			"spells": [s["wolfPounce"], s["wolfRend"], s["wolfHuntHowl"]],
		},
		"troll": {
			"name": "Troll", "icon": "👺", "team": "enemy", "x": 10, "y": 3,
			"hp": 50, "maxHp": 50, "moveRange": 4, "speed": 8, "ct": 0, "mp": 10, "maxMp": 10,
			"hasMoved": false, "hasActed": false, "statusEffects": [],
			"facing": {"dx": -1, "dy": 0},
			"footprintWidth": 2, "footprintHeight": 2, "footprintSize": 2,
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
	return ["guerreiro", "arqueiro", "mago", "ladino", "quimico", "bardo", "monge", "samurai", "vestruz"]

static func enemy_team_keys() -> Array:
	return ["goblin", "orc", "xama", "fada", "troll", "kobold", "troncus", "lobo"]

## Pedido do usuário (Lobo): quem conta como "goblinoide" para o Instinto de
## Matilha e para montar no Lobo — por spriteKey, mesmo time do grupo
## "Goblinoides" da seleção do PVP.
static func goblinoid_keys() -> Array:
	return ["goblin", "orc", "xama", "fada", "troll", "kobold", "troncus", "lobo"]
