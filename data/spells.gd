class_name Spells
extends RefCounted

## Porte literal de SPELLS (game.js:368-1052). Além dos campos de arma
## normais, magias têm mpCost (nunca se recupera) e targetMode define como a
## mira funciona: "enemy" (alvo único, igual arma), "point-aoe" (mira um
## tile e explode em raio), "line-aoe" (linha reta/diagonal), "self" (buff
## sem alvo/alcance), cones e variações documentadas em cada tooltipNote.

static func build() -> Dictionary:
	var burned: Dictionary = StatusDotDamage.STATUS_DOT_DAMAGE["burned"]
	var poison: Dictionary = StatusDotDamage.STATUS_DOT_DAMAGE["poison"]
	var weapons := Weapons.build()
	var spells := {
		"fireball": {
			"name": "Bola de Fogo", "icon": "🔥", "ctCost": 70, "mpCost": 10,
			"damageMin": 6, "damageMax": 12, "critMultiplier": 1, "critChance": 0,
			"hitChance": 0.8, "minRange": 1, "maxRange": 6, "areaRadius": 3,
			"targetMode": "point-aoe",
			"appliesBurn": DataUtil.merge(burned, {"turns": 3}),
			"tooltipNote": "Explode em área; se algo bloquear o caminho, detona antes do alvo. Quem for atingido pega fogo (1 de dano por turno, 3 turnos).",
			"sfx": "fire",
		},
		"soundBlast": {
			"name": "Explosão Sonora", "icon": "📣", "ctCost": 70, "mpCost": 10,
			"damageMin": 4, "damageMax": 6, "critMultiplier": 1, "critChance": 0,
			"hitChance": 0.8, "minRange": 1, "maxRange": 6, "areaRadius": 3,
			"targetMode": "point-aoe",
			"appliesDaze": {"turns": 2},
			"projectileKind": "soundwave", "burstKind": "sound",
			"tooltipNote": "Explode em área; se algo bloquear o caminho, detona antes do alvo. Quem for atingido fica atordoado(a): -10% de chance de acerto nos próprios ataques por 2 turnos.",
			"sfx": "lightning",
		},
		"missile": {
			"name": "Míssil Mágico", "icon": "✨", "ctCost": 50, "mpCost": 4,
			# Pedido do usuário: em vez de 1 impacto só (2-8 de dano), agora
			# dispara 4 mísseis em sequência (ver "hits" em perform_attack),
			# cada um rolando acerto/dano próprios (1-2 cada) — mesmo VFX/SFX
			# da Varinha de Míssil Mágico do SPD (magic-missile-spd), só
			# disparado 4 vezes.
			"damageMin": 1, "damageMax": 2, "hits": 4, "critMultiplier": 1, "critChance": 0,
			"hitChance": 1, "minRange": 1, "maxRange": 6, "targetMode": "enemy",
			"projectile": "magic-missile-spd",
			# A varinha de referência nunca "erra" por obstrução — o disparo
			# sempre acerta o primeiro personagem no caminho da Ballistica,
			# sem checar terreno/elevação (ver WandOfMagicMissile.onZap). O
			# texto abaixo já prometia esse comportamento ("como o Arco", que
			# tem ignoresTerrainLineOfSight true), mas a flag em si nunca
			# tinha sido setada aqui — a magia era bloqueada por elevação na
			# prática, ao contrário do que o tooltip dizia.
			"ignoresTerrainLineOfSight": true,
			"tooltipNote": "Dispara 4 mísseis em sequência, cada um causando 1-2 de dano. Ignora obstáculos no caminho, como o Arco.",
			"sfx": "magicMissileZapSpd",
		},
		"lightning": {
			"name": "Relâmpago", "icon": "⚡", "ctCost": 60, "mpCost": 12,
			"damageMin": 10, "damageMax": 20, "critMultiplier": 1, "critChance": 0,
			"hitChance": 0.8, "minRange": 1, "maxRange": GameConstants.BOARD_SIZE - 1,
			"targetMode": "line-aoe",
			"appliesCtDrain": 15,
			"tooltipNote": "Só em linha reta ou diagonal; atinge todos os inimigos no caminho. Quem for atingido perde 15 de CT.",
			"sfx": "lightning",
		},
		"cure": {
			"name": "Cura", "icon": "💚", "kind": "heal-aoe", "ctCost": 45, "mpCost": 5,
			"healMin": 5, "healMax": 10, "areaRadius": 1, "critChance": 0, "hitChance": 1,
			"minRange": 0, "maxRange": 3, "targetMode": "heal-aoe",
			"tooltipNote": "Área de 5 quadrados (losango); cura qualquer um dentro dela, aliado ou inimigo.",
			"sfx": "heal",
		},
		"regenAoe": {
			"name": "Regeneração em Área", "icon": "🌱", "kind": "regen-aoe",
			"ctCost": 40, "mpCost": 5, "healMin": 2, "healMax": 4, "regenTurns": 3,
			"areaRadius": 1, "critChance": 0, "hitChance": 0.8, "minRange": 0, "maxRange": 3,
			"targetMode": "regen-aoe",
			"tooltipNote": "Área de 5 quadrados (losango), alcance 3. 80% de chance de acerto; quem for atingido regenera 2-4 de vida por turno, por 3 turnos.",
			"sfx": "heal",
		},
		"regenAoeAlchemist": {
			"name": "Regeneração em Área", "icon": "🌱", "kind": "regen-aoe",
			"ctCost": 40, "mpCost": 5, "healMin": 2, "healMax": 4, "regenTurns": 3,
			"areaRadius": 1, "critChance": 0, "hitChance": 1, "minRange": 0, "maxRange": 3,
			"targetMode": "regen-aoe",
			"tooltipNote": "Área de 5 quadrados (losango), alcance 3. Quem for atingido regenera 2-4 de vida por turno, por 3 turnos.",
			"sfx": "heal",
		},
		"resurrect": {
			# Pedido do usuário: ícone próprio (era o mesmo ✨ do Míssil Mágico
			# da Maga).
			"name": "Ressurreição", "icon": "🕊️", "kind": "resurrect", "ctCost": 90, "mpCost": 7,
			"critChance": 0, "hitChance": 0.7, "minRange": 0, "maxRange": 3,
			"targetMode": "resurrect",
			"tooltipNote": "Alcance 3; ressuscita um aliado morto há até 3 turnos com metade do HP máximo. 70% de chance de sucesso.",
			# Pedido do usuário: sonoplastia própria (mais grandiosa que a Cura,
			# ver AudioEngine.play_sfx:"resurrectChime"), não mais a mesma da Cura.
			"sfx": "resurrectChime",
		},
		# Pedido do usuário: Reencarnação (Maga/Xamã/Fada/Lich). Lançada num
		# ALIADO VIVO (não num cadáver, ao contrário de Ressurreição/
		# Reanimação) — marca o alvo com o status "reincarnation" (ver
		# add_status_effect em cast_reincarnation, sem turnsLeft: fica
		# indefinidamente até ser consumido). Se esse aliado morrer depois,
		# GameState.finalize_death_if_needed trata a morte como se ele
		# tivesse o campo `resurrection` embutido (mesmo motor do Zumbi):
		# ressuscita sozinho na sua PRÓPRIA próxima rodada, com metade do
		# HP/MP, 100% de chance (não é um "teste", é automático) — e o selo
		# se consome nessa hora, não protege uma segunda morte.
		"reincarnation": {
			"name": "Reencarnação", "icon": "♻️", "kind": "reincarnation", "ctCost": 50, "mpCost": 10,
			"critChance": 0, "hitChance": 0.8, "minRange": 1, "maxRange": 5,
			"targetMode": "reincarnation",
			"tooltipNote": "Alcance 5; marca um aliado vivo com um selo de reencarnação. Se ele morrer depois, ressuscita sozinho na rodada seguinte com metade do HP e do MP — selo de uso único.",
			"sfx": "heal",
		},
		"resurrectAlchemist": {
			# Mesmo ícone da Ressurreição comum (ver "resurrect" acima) — é a
			# mesma habilidade, só sem chance de falha.
			"name": "Ressurreição", "icon": "🕊️", "kind": "resurrect", "ctCost": 90, "mpCost": 7,
			"critChance": 0, "hitChance": 1, "minRange": 0, "maxRange": 3,
			"targetMode": "resurrect",
			"tooltipNote": "Alcance 3; ressuscita um aliado morto há até 3 turnos com metade do HP máximo.",
			"sfx": "resurrectChime",
		},
		"creepingDestruction": {
			"name": "Destruição Rastejante", "icon": "🕸️", "kind": "creeping-line",
			"ctCost": 60, "mpCost": 8, "damageMin": 5, "damageMax": 12, "critMultiplier": 1,
			"critChance": 0, "hitChance": 0.8, "minRange": 1, "maxRange": 3, "cardinalOnly": true,
			"targetMode": "creeping-line",
			"bandLength": GameConstants.BOARD_SIZE, "bandWidth": 3,
			"tooltipNote": "Escolha uma direção cardeal: faixa de 3 tiles de espessura que se estende até a borda do tabuleiro. 80% de chance de causar 5-12 de dano; todo mundo na área perde 15 de CT e fica imóvel no próximo turno, acertando ou não.",
			"sfx": "nature",
		},
		"poisonCone": DataUtil.merge(
			{
				"name": "Envenenamento", "icon": "☠️", "kind": "cone-poison",
				"ctCost": 75, "mpCost": 6,
			},
			DataUtil.merge(poison, {
				"turns": 3, "critChance": 0, "hitChance": 0.8, "minRange": 1, "maxRange": 5,
				"targetMode": "cone-poison",
				"tooltipNote": "Cone reto (1, 3, 5, 7, 9 quadrados de largura); acerta qualquer um na área, aliado ou inimigo.",
				"sfx": "poison",
			})
		),
		# Pedido do usuário: habilidades do Lobo dos Goblinoides. O pedido
		# original era CT 0; Bote e Dilacerar encerram a ação, então usam o
		# custo padrão (mesma decisão tomada com o usuário no Troncus, senão o
		# Lobo agiria de novo sem passar a vez). Uivo é ação livre (CT 0).
		# Bote Selvagem reaproveita a Investida do Orc (targetMode "charge"):
		# linha reta até 3 casas, pára ao lado do alvo; `clearPathOnly` exige
		# caminho sem obstáculo; `rootsUntilCasterTurn` imobiliza até o início
		# do próximo turno do Lobo (expira pelo turno DELE, não do alvo).
		"wolfPounce": {
			"name": "Bote Selvagem", "icon": "🐾", "kind": "charge", "ctCost": 65, "mpCost": 3,
			"damageMin": 5, "damageMax": 9, "critMultiplier": 2, "critChance": 0.1, "hitChance": 0.9,
			"minRange": 1, "maxRange": 3, "targetMode": "charge", "damageType": "physical",
			"clearPathOnly": true, "rootsUntilCasterTurn": true,
			"tooltipNote": "Avança até 3 casas em linha reta (caminho livre) e pára ao lado do alvo: 5-9 de dano físico. Se acertar, o alvo fica imobilizado até o início do próximo turno do Lobo (ainda pode atacar e usar habilidades).",
			"sfx": "melee",
		},
		"wolfRend": {
			"name": "Dilacerar", "icon": "🩸", "kind": "rend", "ctCost": 50, "mpCost": 3,
			"damageMin": 5, "damageMax": 11, "critMultiplier": 2, "hitChance": 0.8,
			"minRange": 1, "maxRange": 1, "targetMode": "enemy", "damageType": "physical",
			"appliesBleed": {"damageMin": 2, "damageMax": 2, "turns": 2, "refresh": true},
			"tooltipNote": "Corpo a corpo: 5-11 de dano físico e Sangrando (2 de dano por turno, por 2 turnos). Não acumula: reaplicar renova a duração.",
			"sfx": "melee",
		},
		"wolfHuntHowl": {
			"name": "Uivo de Caça", "icon": "🌕", "kind": "hunt-howl", "ctCost": 0, "mpCost": 4,
			"speedBonus": 2, "turns": 2, "targetMode": "self",
			"tooltipNote": "Todos os aliados vivos no campo (inclusive o Lobo), sem limite de distância: +2 de agilidade por 2 turnos. Não acumula com outro uivo; reaplicar renova a duração.",
			"sfx": "wolfHowl",
		},
		# Pedido do usuário: habilidades do Troncus. Raízes reaproveita o modo
		# "root" da Prisão de Vinhas, mas só em inimigos e renovando a duração
		# (sem somar turnos). O Enraizado é descontado no fim do turno de quem
		# sofre, então 2 turnos = preso durante 2 turnos dele.
		"troncusRoots": {
			"name": "Raízes Aprisionadoras", "icon": "🌱", "kind": "root", "ctCost": 55, "mpCost": 4,
			"damageMin": 0, "damageMax": 0, "turns": 2, "critChance": 0, "hitChance": 0.8,
			"minRange": 1, "maxRange": 3, "targetMode": "root", "enemyOnly": true, "refreshesDuration": true,
			"tooltipNote": "Um inimigo a até 3 casas: 80% de chance de aplicar Enraizado por 2 turnos (não se move, mas ataca e usa habilidades). Reaplicar renova a duração.",
			"sfx": "nature",
		},
		# Mesma mira/prévia de direção do Tacar Tronco ("cardinal-blast"); pela
		# regra 2x2, a faixa sai das 2 casas da borda do corpo (4 de largura).
		"troncusBranchSweep": {
			"name": "Varredura de Galhos", "icon": "🌳", "kind": "branch-sweep", "ctCost": 60, "mpCost": 5,
			"damageMin": 4, "damageMax": 7, "critMultiplier": 1, "critChance": 0, "hitChance": 0.85,
			"minRange": 1, "maxRange": 3, "targetMode": "cardinal-blast", "bandLength": 3, "bandWidth": 3,
			"damageType": "physical",
			"tooltipNote": "Escolha uma direção: 4-7 de dano físico a cada inimigo na área de 3 casas à frente (85% de acerto por alvo, 1 golpe por inimigo mesmo ocupando várias casas). Não atinge aliados.",
			"sfx": "nature",
		},
		"troncusBarkArmor": {
			"name": "Casca Fortificada", "icon": "🪵", "kind": "bark-armor", "ctCost": 0, "mpCost": 3,
			"turns": 2, "damageReductionPercent": 0.25, "targetMode": "self",
			"tooltipNote": "Por 2 turnos, recebe 25% menos dano físico. Reaplicar renova a duração, sem acumular.",
			"sfx": "nature",
		},
		"troncusSap": {
			"name": "Seiva Restauradora", "icon": "💧", "kind": "restoring-sap", "ctCost": 45, "mpCost": 4,
			"healMin": 5, "healMax": 10, "mpRestoreMin": 1, "mpRestoreMax": 3, "hitChance": 1, "critChance": 0,
			"minRange": 0, "maxRange": 1, "targetMode": "sap",
			"tooltipNote": "O próprio Troncus ou um aliado adjacente: recupera 5-10 HP e 1-3 MP (sempre funciona) e remove Envenenado.",
			"sfx": "heal",
		},
		"vinePrison": {
			"name": "Prisão de Vinhas", "icon": "🌿", "kind": "root", "ctCost": 55, "mpCost": 2,
			"damageMin": 1, "damageMax": 2, "turns": 2, "critChance": 0, "hitChance": 0.7,
			"minRange": 1, "maxRange": 3, "targetMode": "root",
			"tooltipNote": "Impede o alvo de se mover; atravessa outras unidades.",
			"sfx": "nature",
		},
		"invisibility": {
			"name": "Invisibilidade", "icon": "🫥", "kind": "invisibility", "ctCost": 60,
			"mpCost": 5, "turns": 2, "targetMode": "self",
			"tooltipNote": "Por 2 turnos inteiros, ataques de arma não acertam você (magias ainda acertam normalmente).",
			"sfx": "arcane",
		},
		"weakeningStrike": {
			"name": "Golpe Debilitante", "icon": "🩸", "kind": "weakening-strike",
			"ctCost": 0, "mpCost": 3, "targetMode": "self",
			"tooltipNote": "Se o próximo ataque neste turno acertar, o alvo sangra (1 de dano por turno) e perde 1 de deslocamento, por 3 turnos. Acumula com usos futuros.",
			"sfx": "melee",
		},
		"stealHp": {
			"name": "Furtar HP", "kind": "steal-hp", "ctCost": 0, "mpCost": 3,
			"damageMin": 3, "damageMax": 6, "critMultiplier": 1, "critChance": 0,
			"hitChance": 0.8, "minRange": 0, "maxRange": 0, "targetMode": "self",
			"tooltipNote": "Prepara o próximo ataque de Punhal ou Besta: adiciona 3-6 de dano e recupera esse valor de HP.", "sfx": "melee",
		},
		"stealMp": {
			"name": "Furtar MP", "kind": "steal-mp", "ctCost": 0, "mpCost": 3,
			"damageMin": 0, "damageMax": 0, "critMultiplier": 1, "critChance": 0,
			"hitChance": 0.8, "minRange": 0, "maxRange": 0, "targetMode": "self", "noDamage": true,
			"appliesMpDrainMin": 3, "appliesMpDrainMax": 6,
			"tooltipNote": "Prepara o próximo ataque de Punhal ou Besta: rouba 3-6 MP e transfere o mesmo valor ao Ladino.", "sfx": "melee",
		},
		"stealCt": {
			"name": "Furtar CT", "kind": "steal-ct", "ctCost": 0, "mpCost": 3,
			"damageMin": 0, "damageMax": 0, "critMultiplier": 1, "critChance": 0,
			"hitChance": 0.8, "minRange": 0, "maxRange": 0, "targetMode": "self", "noDamage": true,
			"appliesCtDrainMin": 10, "appliesCtDrainMax": 40,
			"tooltipNote": "Prepara o próximo ataque de Punhal ou Besta: rouba 10-40 CT e transfere o mesmo valor ao Ladino.", "sfx": "melee",
		},
		"trap": {
			"name": "Armadilha", "icon": "🪤", "ctCost": 55, "mpCost": 3, "areaRadius": 1,
			"noDamage": true, "minRange": 1, "maxRange": 3, "targetMode": "trap",
			"tooltipNote": "Fica instalada sem limite de turnos até alguém pisar: causa 1-3 de dano, interrompe o movimento naquele quadrado e some na hora. Só o Ladino que a instalou é imune — aliados também podem detoná-la; não instala em cima de alguém.",
			"sfx": "nature",
		},
		"paralysis": {
			"name": "Congelamento", "icon": "❄️", "kind": "freeze-aoe", "ctCost": 70, "mpCost": 4,
			"damageMin": 1, "damageMax": 3, "areaRadius": 1, "critChance": 0, "hitChance": 0.7,
			"minRange": 1, "maxRange": 3, "targetMode": "freeze-aoe",
			"tooltipNote": "Área de 5 quadrados (losango); quem for atingido fica congelado por 1 turno, sofrendo 1-3 de dano.",
			"sfx": "freeze",
		},
		"windstorm": {
			"name": "Ventania", "icon": "🌪️", "kind": "windstorm", "ctCost": 65, "mpCost": 8,
			"damageMin": 4, "damageMax": 6, "critMultiplier": 2, "critChance": 0, "hitChance": 0.8,
			"minRange": 1, "maxRange": 5, "appliesCtDrain": 15, "targetMode": "cone-windstorm",
			"tooltipNote": "Cone reto (mesma área do Envenenamento); quem for atingido sofre 4-6 de dano, perde 15 de CT e é empurrado(a) 2-3 quadrados para trás.",
			"sfx": "arcane",
		},
		"powerAttack": {
			"name": "Ataque Poderoso", "icon": "💪", "kind": "power-attack", "ctCost": 0,
			"mpCost": 4, "damageBonus": 5, "critBonus": 0.10, "targetMode": "self",
			"tooltipNote": "Soma +5 de dano e +10% de chance de crítico ao seu próximo ataque neste turno.",
			"sfx": "melee",
		},
		"throwSword": {
			# Pedido do usuário: ícone próprio (era o mesmo 🗡️ da Espada,
			# escondendo que são 2 ataques diferentes do Guerreiro).
			"name": "Arremessar Espada", "icon": "⚔️", "ctCost": 50, "mpCost": 3,
			"damageMin": 8, "damageMax": 10, "critMultiplier": 2, "hitChance": 0.8,
			"minRange": 1, "maxRange": 3, "cardinalOnly": true, "targetMode": "enemy",
			"projectile": "blade",
			"tooltipNote": "Só nas 4 direções cardeais, até 3 quadrados de distância. Mesmos dano/crítico/acerto da Espada.",
			"sfx": "melee",
		},
		"spinAttack": {
			"name": "Ataque Giratório", "icon": "🔄", "kind": "spin-attack", "ctCost": 50,
			"mpCost": 3, "damageMin": 8, "damageMax": 10, "critMultiplier": 2, "hitChance": 0.8,
			"targetMode": "self-attack",
			"tooltipNote": "Ataca com a Espada todas as 8 casas ao redor (incluindo diagonais) de uma vez.",
			"sfx": "melee",
		},
		"defend": {
			# Pedido do usuário: ícone próprio (era o mesmo 🛡️ do Escudo).
			"name": "Defender", "icon": "🧱", "kind": "defend", "ctCost": 0, "mpCost": 1,
			"turns": 3, "targetMode": "self",
			"tooltipNote": "Reduz o dano recebido em 2 nos próximos 3 turnos.",
			"sfx": "melee",
		},
		"trueShot": {
			"name": "Tiro Certeiro", "icon": "🎯", "kind": "true-shot", "ctCost": 0, "mpCost": 1,
			"critBonus": 0.1, "targetMode": "self",
			"tooltipNote": "Seu próximo ataque neste turno tem 100% de acerto e +10% de chance de crítico.",
			"sfx": "ranged",
		},
		"longShot": {
			# Pedido do usuário: ícone próprio (era o mesmo 🏹 do Arco, da Chuva
			# de Flechas e do Tiro Penetrante — as 4 habilidades do Arqueiro
			# ficavam indistinguíveis no menu).
			"name": "Tiro Longo", "icon": "🔭", "kind": "long-shot", "ctCost": 0, "mpCost": 3,
			"targetMode": "self",
			"tooltipNote": "Dobra o alcance do seu próximo ataque neste turno.",
			"sfx": "ranged",
		},
		"arrowRain": {
			# Pedido do usuário: ícone próprio (mesma duplicação do Tiro Longo
			# acima).
			"name": "Chuva de flechas", "icon": "🌧️", "kind": "arrow-rain", "ctCost": 0, "mpCost": 5,
			"targetMode": "self", "sfx": "ranged",
			"tooltipNote": "Prepara o próximo ataque de arco em 3 × 3 quadrados. Combina com outros modificadores; Tiro Rápido mantém a chuva no disparo extra. Custa 5 MP uma vez; o disparo mantém seu CT. Não acumula consigo mesma.",
		},
		"fireArrow": {
			"name": "Flecha de Fogo", "icon": "🔥", "kind": "fire-arrow", "ctCost": 0, "mpCost": 3,
			"bonusDamageMin": 1, "bonusDamageMax": 3, "burnTurns": 3, "targetMode": "self",
			"tooltipNote": "Seu próximo ataque queima o alvo por 3 turnos (1 de dano por turno), acertando ou não. Se acertar, ainda causa +1-3 de dano na hora.",
			"sfx": "fire",
		},
		# Pedido do usuário: Flecha de Gelo idêntica à Flecha de Fogo (mesmo
		# custo, bônus de dano e regra de "acertando ou não"), trocando só o
		# efeito — reduz agilidade em vez de queimar, mesmo efeito do Raio de
		# Gelo (weapons.gd:"iceRay"); reaproveita os feats e o som dele
		# (frost-wand-spd/frostWandZapSpd) em vez de ter VFX próprio.
		"iceArrow": {
			"name": "Flecha de Gelo", "icon": "🧊", "kind": "ice-arrow", "ctCost": 0, "mpCost": 3,
			"damageType": "ice", "bonusDamageMin": 1, "bonusDamageMax": 3,
			"slowTurns": 2, "slowAmount": 1, "targetMode": "self",
			"tooltipNote": "Seu próximo ataque reduz a agilidade do alvo em 1 por 2 turnos, acertando ou não, igual ao Raio de Gelo. Se acertar, ainda causa +1-3 de dano na hora.",
			"sfx": "frostWandZapSpd",
		},
		"pierceShot": {
			# Pedido do usuário: ícone próprio (mesma duplicação do Tiro Longo
			# acima).
			"name": "Tiro Penetrante", "icon": "➡️", "ctCost": 60, "mpCost": 3,
			"damageMin": 4, "damageMax": 8, "critMultiplier": 3, "critChance": 0.15,
			# Sem teto de alcance próprio: maxRange = toda a extensão do
			# tabuleiro — quem realmente limita o alcance é a borda do mapa
			# (in_bounds em compute_line_target_tiles/compute_aoe_area_tiles),
			# não um número fixo.
			"hitChance": 0.8, "minRange": 1, "maxRange": GameConstants.BOARD_SIZE - 1, "targetMode": "pierce-line",
			"tooltipNote": "Sempre atira em linha reta (só nas 4 direções cardeais, nunca na diagonal), até a borda do mapa — não dá pra escolher um alcance menor. Perfura e acerta todos os inimigos no caminho.",
			"sfx": "ranged",
		},
		"quickShot": {
			"name": "Tiro Rápido", "icon": "💨", "kind": "haste-attack", "ctCost": 0, "mpCost": 4,
			"targetMode": "self", "restrictBonusToWeapon": weapons["bow"],
			"tooltipNote": "Permite atirar com o Arco mais uma vez neste turno. Se atacar com outra arma em vez do Arco, a rodada de ataque acaba ali e o disparo extra é perdido.",
			"sfx": "ranged",
		},
		"agility": {
			# Pedido do usuário: ícone próprio (era o mesmo 🌀 da Funda, a arma
			# do Goblin) — mesmo ícone do Tiro Rápido do Arqueiro, já que é a
			# mesma habilidade (kind "haste-attack") reaproveitada.
			"name": "Agilidade", "icon": "💨", "kind": "haste-attack", "ctCost": 0, "mpCost": 4,
			"targetMode": "self",
			"tooltipNote": "Permite atacar mais uma vez neste turno.",
			"sfx": "melee",
		},
		"swiftFeet": {
			"name": "Pés Ágeis", "icon": "🦶", "kind": "swift-feet", "ctCost": 0, "mpCost": 2,
			"targetMode": "self",
			"tooltipNote": "Dobra seu deslocamento neste turno.",
			"sfx": "melee",
		},
		"evasiveManeuver": {
			"name": "Evasiva", "icon": "🍃", "kind": "evasive", "ctCost": 0, "mpCost": 3,
			"turns": 2, "targetMode": "self",
			"tooltipNote": "Por 2 turnos, reduz em mais 20% a chance de ser acertado — acumula com a esquiva inata do Goblin.",
			"sfx": "melee",
		},
		"charge": {
			"name": "Investida", "icon": "💢", "kind": "charge", "ctCost": 65, "mpCost": 3,
			"damageMin": 4, "damageMax": 8, "critMultiplier": 2, "critChance": 0.1,
			"hitChance": 0.9, "targetMode": "charge",
			"tooltipNote": "Corre em linha reta (só nas 4 direções cardeais) até 2x o seu deslocamento, pára ao lado do primeiro inimigo encontrado no caminho e ataca. Conta como mover E atacar no mesmo turno.",
			"sfx": "melee",
		},
		"fury": {
			"name": "Fúria", "icon": "😡", "kind": "fury", "ctCost": 0, "mpCost": 3,
			"damageBonus": 2, "speedBonus": 2, "hpDrainPerTurn": 1, "turns": 3, "targetMode": "self",
			"tooltipNote": "Por 3 turnos: +2 de dano nos ataques e +2 de agilidade, mas perde 1 de HP por turno.",
			"sfx": "melee",
		},
		"berserk": {
			"name": "Berserk", "icon": "🤬", "kind": "fury", "ctCost": 0, "mpCost": 6,
			"damageBonus": 4, "speedBonus": 4, "hpDrainPerTurn": 2, "turns": 3, "targetMode": "self",
			"tooltipNote": "Versão dobrada da Fúria — por 3 turnos: +4 de dano nos ataques e +4 de agilidade, mas perde 2 de HP por turno.",
			"sfx": "melee",
		},
		"explosiveShot": {
			"name": "Tiro Explosivo", "icon": "💥", "kind": "explosive-shot", "ctCost": 0,
			"mpCost": 6, "bonusDamageMin": 1, "bonusDamageMax": 3, "burnTurns": 3,
			"targetMode": "self",
			"tooltipNote": "Seu próximo ataque com arma causa +1-3 de dano extra e, se acertar, deixa o alvo queimando (1 de dano por turno, 3 turnos).",
			"sfx": "fire",
		},
		"healPotion": {
			# Pedido do usuário: a Cura passa a ter a mesma área de efeito da
			# Regeneração em Área (regenAoeAlchemist) — mesmo areaRadius/alcance,
			# em vez de alvo único com linha limpa.
			"name": "Poção de Cura", "icon": "🧪", "kind": "heal-aoe", "ctCost": 45, "mpCost": 5,
			"healMin": 5, "healMax": 10, "areaRadius": 1, "critChance": 0, "hitChance": 1,
			"minRange": 0, "maxRange": 3, "targetMode": "heal-aoe",
			"tooltipNote": "Área de 5 quadrados (losango); cura qualquer um dentro dela, aliado ou inimigo.",
			"sfx": "heal",
		},
		# Pedido do usuário: a Poção de Mana passa a ter a mesma área de efeito
		# da Poção de Cura/Regeneração em Área (mesmo areaRadius/alcance), em
		# vez de alvo único com linha limpa.
		"manaPotion": {
			"name": "Poção de Mana", "icon": "💠", "kind": "mana-aoe", "ctCost": 45, "mpCost": 3,
			"manaMin": 5, "manaMax": 10, "areaRadius": 1, "critChance": 0, "hitChance": 1,
			"minRange": 0, "maxRange": 3, "targetMode": "mana-aoe",
			"tooltipNote": "Área de 5 quadrados (losango); restaura mana de qualquer um dentro dela, aliado ou inimigo.",
			"sfx": "heal",
		},
		"antidote": {
			"name": "Antídoto", "icon": "💉", "ctCost": 60, "mpCost": 7, "areaRadius": 2,
			"noDamage": true, "minRange": 1, "maxRange": 4, "targetMode": "cure-aoe",
			"tooltipNote": "Remove veneno e paralisia na hora de qualquer um na área, aliado ou inimigo.",
			"sfx": "heal",
		},
		"bomb": {
			"name": "Bomba de Fogo", "icon": "💣", "ctCost": 50, "mpCost": 5,
			"damageMin": 4, "damageMax": 8, "critMultiplier": 1, "critChance": 0, "hitChance": 1,
			# maxRange igual ao Arco (2-5, ver weapons.gd:"bow") — o alcance
			# original (2-3) formava um anel estreito demais pra mirar "em
			# qualquer lugar" com folga tática; agora a Bomba alcança tão longe
			# quanto uma flecha, mesma faixa de distância mínima (2, ver
			# ignoresTerrainLineOfSight abaixo — o alvo em si já podia ser
			# qualquer tile do anel, isso nunca foi o gargalo).
			"minRange": 2, "maxRange": 5, "areaRadius": 1,
			"appliesBurn": DataUtil.merge(burned, {"turns": 3}),
			"targetMode": "point-aoe", "projectileKind": "bomb", "burstKind": "bomb",
			"ignoresTerrainLineOfSight": true,
			# Diferente de Bola de Fogo/Explosão Sonora (mesmo cast_fireball,
			# ver game_state.gd): a Bomba é ARREMESSADA em arco, não um
			# projétil reto — pedido do usuário pra poder jogá-la livremente
			# em qualquer quadrado do alcance mesmo com alguém no meio do
			# caminho, sem detonar antes na hora (ver resolve_obstructed_target).
			"ignoresUnitObstruction": true,
			"tooltipNote": "Explode em losango de 5 quadrados (raio 1); quem for atingido pega fogo por 3 turnos. Sempre acerta exatamente o quadrado mirado, mesmo com alguém no meio do caminho.",
			"sfx": "fire",
		},
		# Pedido do usuário: Bomba de Gelo idêntica à Bomba (mesmo custo,
		# dano, alcance e área), trocando só o efeito — reduz agilidade em
		# vez de queimar, mesmo efeito do Raio de Gelo (weapons.gd:"iceRay").
		"poisonPotion": {
			"name": "Poção Venenosa", "kind": "poison-potion", "ctCost": 50, "mpCost": 5,
			"targetMode": "self", "tooltipNote": "Prepara o próximo ataque de Adaga Envenenada ou Lança para aplicar Veneno por 3 turnos.", "sfx": "poison",
		},
		"lowBlow": {
			"name": "Golpe Baixo", "kind": "low-blow", "ctCost": 50, "mpCost": 2, "damageMin": 1, "damageMax": 1,
			"targetMode": "self", "tooltipNote": "Próximo ataque de Adaga Envenenada ou Lança causa dano normal e aplica -20% de acerto.", "sfx": "melee",
		},
		"sandInEyes": {
			"name": "Areia nos Olhos", "kind": "sand-in-eyes", "ctCost": 20, "mpCost": 3, "damageMin": 0, "damageMax": 0,
			"targetMode": "self", "tooltipNote": "Próximo ataque de Funda ou Adaga aplica -10% de acerto e -1 de alcance à distância.", "sfx": "nature",
		},
		"hitAndRun": {
			"name": "Bater e Correr", "kind": "hit-and-run", "ctCost": 0, "mpCost": 1, "targetMode": "self",
			"tooltipNote": "Após acertar, permite mover novamente ou concede 2 quadrados extras.", "sfx": "melee",
		},
		"goblinAmbush": {
			"name": "Emboscada Kobold", "kind": "power-attack", "ctCost": 10, "mpCost": 2, "damageBonus": 2, "critBonus": 0.1,
			"targetMode": "self", "tooltipNote": "Próximo ataque: +2 dano e +10% crítico.", "sfx": "melee",
		},
		"stolenBarrel": {
			"name": "Barril Roubado", "kind": "line-aoe", "ctCost": 50, "mpCost": 4, "damageMin": 4, "damageMax": 8,
			"critMultiplier": 1, "critChance": 0, "hitChance": 0.8, "minRange": 1, "maxRange": GameConstants.BOARD_SIZE - 1,
			"targetMode": "line-aoe", "tooltipNote": "Atinge todos em uma linha, causando 4-8 de dano.", "sfx": "melee",
		},
		"playDead": {
			"name": "Fingir de Morto", "kind": "play-dead", "ctCost": 0, "mpCost": 5, "targetMode": "self", "turns": 1,
			"tooltipNote": "Fica intocável por ataques diretos e de área neste turno.", "sfx": "nature",
		},
		"iceBomb": {
			"name": "Bomba de Gelo", "icon": "🧊", "ctCost": 50, "mpCost": 5,
			"damageMin": 4, "damageMax": 8, "critMultiplier": 1, "critChance": 0, "hitChance": 1,
			"minRange": 2, "maxRange": 5, "areaRadius": 1,
			"damageType": "ice",
			"appliesSpeedReduction": {"turns": 2, "amount": 1},
			"targetMode": "point-aoe", "projectileKind": "bomb", "burstKind": "frost",
			"ignoresTerrainLineOfSight": true,
			"ignoresUnitObstruction": true,
			"tooltipNote": "Explode em losango de 5 quadrados (raio 1); quem for atingido tem a agilidade reduzida em 1 por 2 turnos, igual ao Raio de Gelo. Sempre acerta exatamente o quadrado mirado, mesmo com alguém no meio do caminho.",
			"sfx": "frostWandZapSpd",
		},
		# Pedido do usuário: mesma área do Envenenamento (cone reto, 1/3/5/7/9
		# quadrados de largura), mas com dano direto de gelo e a mesma redução
		# de agilidade que Raio de Gelo/Bomba de Gelo já aplicam (weapons.gd:
		# "iceRay", spells.gd:"iceBomb") — não uma queimadura contínua nova.
		"iceCone": {
			# Pedido do usuário: ícone próprio (era o mesmo 🧊 do Raio de Gelo,
			# a outra magia de gelo da Maga).
			"name": "Cone de Gelo", "icon": "❄️", "kind": "cone-ice", "ctCost": 50, "mpCost": 10,
			"damageMin": 5, "damageMax": 10, "damageType": "ice", "critMultiplier": 1, "critChance": 0,
			"hitChance": 0.8, "minRange": 1, "maxRange": 5, "targetMode": "cone-ice",
			"appliesSpeedReduction": {"turns": 2, "amount": 1},
			"tooltipNote": "Cone reto (1, 3, 5, 7, 9 quadrados de largura, mesma área do Envenenamento); acerta qualquer um na área, aliado ou inimigo. Quem for atingido sofre 5-10 de dano e tem a agilidade reduzida em 1 por 2 turnos, igual ao Raio de Gelo.",
			"sfx": "frostWandZapSpd",
		},
		"regenBoost": {
			"name": "Regeneração", "icon": "🌱", "kind": "regen-boost", "ctCost": 0, "mpCost": 4,
			"regenBonus": 3, "turns": 3, "targetMode": "self",
			"tooltipNote": "Aumenta sua regeneração passiva em +3 de vida por turno, por 3 turnos.",
			"sfx": "nature",
		},
		"growth": {
			"name": "Ataque Giratório", "icon": "🔄", "kind": "growth-attack", "ctCost": 50,
			"mpCost": 3, "damageMin": 8, "damageMax": 10, "critMultiplier": 2, "hitChance": 0.8,
			"targetMode": "self-attack",
			"tooltipNote": "Ataca todas as 8 casas ao redor (incluindo diagonais) de uma vez.",
			"sfx": "melee",
		},
		"trample": {
			"name": "Atropelar", "icon": "💥", "ctCost": 60, "mpCost": 2,
			"damageMin": 4, "damageMax": 6, "critMultiplier": 2, "critChance": 0, "hitChance": 0.8,
			"minRange": 1, "maxRange": 4, "appliesCtDrain": 20,
			"appliesSlow": {"turns": 1, "moveReduction": 1}, "targetMode": "trample",
			"tooltipNote": "Move até 4 quadrados em linha reta cardeal, atropelando todo inimigo no caminho sem parar: 80% de acerto, 0% de crítico, tira 20 de CT e reduz o deslocamento em 1 por 1 turno de quem for atingido.",
			"sfx": "melee",
		},
		# --- Habilidades do Monge (pedido do usuário) ----------------------
		# Foco: mesma família das posturas defensivas já existentes (Defender
		# do Guerreiro, kind "defend"), só que em vez de reduzir o dano em 2
		# ele ANULA ataque físico e corta magia pela metade (ver o bloco
		# "focus" em GameState.resolve_single_hit). Ação livre (ctCost 0,
		# finish_free_self_action) igual ao Defender, então o Monge ainda
		# pode mover/atacar no mesmo turno. turns 1 usa o idioma do Pés
		# Ágeis/Forma de Morcego: aplicado durante o próprio turno e
		# decrementado só quando o MESMO Monge começa o turno seguinte, ou
		# seja, "dura o turno em que foi usada" e protege até ele voltar a
		# agir.
		# Rajada de Golpes (Monge): HABILIDADE (aba Habilidades). Reaproveita o
		# campo "hits" (o mesmo do Míssil Mágico): dois golpes seguidos, cada um
		# com acerto (80%), crítico (15%) e dano (3-6) próprios; o 2º sai mesmo
		# que o 1º erre. Na tela o Monge ataca DUAS vezes (ver
		# Main._play_multi_strike). damageType "physical" porque item com mpCost
		# viraria "magic" em damage_type_of.
		"monkFlurry": {
			"name": "Rajada de Golpes", "icon": "🥊", "kind": "monk-flurry", "ctCost": 50, "mpCost": 3,
			"damageMin": 3, "damageMax": 6, "hits": 2, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "swing": "blunt", "minRange": 1, "maxRange": 1,
			"targetMode": "enemy", "damageType": "physical", "manualOnly": true, "spriteAction": "soco",
			"tooltipNote": "Custa 3 MP. O Monge ataca DUAS vezes seguidas, 3-6 de dano cada, com acerto (80%) e crítico (15%) calculados separadamente. O 2º golpe acontece mesmo que o 1º erre.",
			"sfx": "melee",
		},
		"monkFocus": {
			"name": "Foco", "icon": "🧘", "kind": "monk-focus", "ctCost": 0, "mpCost": 2,
			"turns": 1, "healAmount": 3, "manaAmount": 3, "targetMode": "self",
			"tooltipNote": "Custa 2 MP. Bloqueia por completo todo ataque físico recebido e reduz pela metade o dano de magia até o começo do próximo turno do Monge. Recupera 3 HP e 3 MP (descontados depois do custo).",
			"sfx": "melee",
		},
		# Dash: mesmo desenho da Agilidade/Tiro Rápido (kind "haste-attack",
		# ataque bônus), só que pro MOVIMENTO — guarda um movimento extra que
		# GameState.perform_move consome em vez de marcar hasMoved, sempre no
		# máximo um (nunca um terceiro, ver cast_monk_dash).
		"monkDash": {
			"name": "Dash", "icon": "👟", "kind": "monk-dash", "ctCost": 0, "mpCost": 2,
			"targetMode": "self",
			"tooltipNote": "Custa 2 MP. Permite mover duas vezes neste turno; cada movimento respeita o deslocamento normal (MOV 8) e as regras de colisão/terreno de sempre. Não concede um terceiro movimento.",
			"sfx": "melee",
		},
		# Chute do Dragão: alcance idêntico ao do Relâmpago da Maga (mesmo
		# minRange/maxRange), obstrução no estilo da Flecha do Arqueiro
		# (ignoresTerrainLineOfSight, ver weapons.gd:"bow") e empurrão/
		# paralisia resolvidos pelos campos genéricos que resolve_single_hit
		# já entende (knockback/appliesParalyzed, mesmos usados por Cauda do
		# Dragão Vermelho e pelo Choque da Fada). O voo até o alvo mora em
		# GameState.cast_dragon_kick.
		"dragonKick": {
			"name": "Chute do Dragão", "icon": "🐉", "kind": "dragon-kick", "ctCost": 60, "mpCost": 8,
			"damageMin": 5, "damageMax": 20, "critMultiplier": 2, "hitChance": 0.8,
			"minRange": 1, "maxRange": GameConstants.BOARD_SIZE - 1,
			"damageType": "physical", "targetMode": "dragon-kick",
			"ignoresTerrainLineOfSight": true,
			"knockback": {"distance": 2}, "appliesParalyzed": {"turns": 1},
			"spriteAction": "chute",
			"tooltipNote": "Custa 8 MP. Escolha um lugar em linha reta (horizontal, vertical ou diagonal, como o Relâmpago) dentro do mesmo alcance dele: o Monge voa até lá e chuta, causando 5-20 de dano. Não precisa de linha de visão livre. Quem for atingido é empurrado 2 quadrados na direção do golpe e fica paralisado por 1 turno.",
			"sfx": "melee",
		},
		# Meditar: mesma receita da Troca de Pele da Cobra (cura + limpeza de
		# status negativos) somada ao status "regen" já existente — os
		# valores da Regeneração são copiados da Regeneração em Área logo
		# depois de montar este dicionário (ver o final de build()), então
		# nunca saem de sincronia com ela. Consome a ação do turno
		# (ctCost > 0, finalize_action), igual às outras curas do jogo.
		"monkMeditate": {
			"name": "Meditar", "icon": "☯️", "kind": "monk-meditate", "ctCost": 45, "mpCost": 5,
			"healMin": 5, "healMax": 10, "targetMode": "self",
			"tooltipNote": "Custa 5 MP. Remove todos os status negativos do Monge, cura 5-10 de HP e aplica Regeneração (mesmo valor por turno e mesma duração da Regeneração em Área).",
			"sfx": "heal",
		},
		# --- Habilidades do Samurai (pedido do usuário) --------------------
		# Todo golpe de espada declara damageType "physical" (damage_type_of
		# trataria qualquer item com mpCost como "magic") e "usesSword": o
		# Saque Rápido só potencializa golpes de espada (ver
		# GameState.resolve_single_hit). "manualOnly" tira estas habilidades
		# do atalho do tile vermelho (get_attack_options): elas custam MP e só
		# devem sair pelo menu Habilidades, nunca por um clique de atalho.
		"samuraiDualWield": {
			"name": "Empunhadura Dupla", "icon": "⚔️", "ctCost": 50, "mpCost": 4,
			"damageMin": 12, "damageMax": 24, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "swing": "slash", "minRange": 1, "maxRange": 1,
			"targetMode": "enemy", "damageType": "physical", "usesSword": true, "manualOnly": true,
			"tooltipNote": "Golpe de espada com o dobro do dano normal (12-24, antes do crítico). 80% de acerto e 15% de crítico, como a Espada.",
			"sfx": "melee",
		},
		# Saque Rápido: custo de MP/CT e bônus copiados do Tiro Certeiro no
		# fim de build() — nunca divergem dele.
		"samuraiQuickDraw": {
			"name": "Saque Rápido", "icon": "🗡️", "kind": "quick-draw", "targetMode": "self",
			"tooltipNote": "Seu próximo golpe de espada neste turno tem 100% de acerto e +10% de chance de crítico. Só vale para a espada (não para o Arco).",
			"sfx": "melee",
		},
		# Meditar do Samurai: mesma habilidade do Monge (kind "monk-meditate",
		# mesma função), só com o custo pedido: 5 MP / CT 60. Os valores da
		# Regeneração vêm de regenAoe no fim de build().
		"samuraiMeditate": {
			"name": "Meditar", "icon": "☯️", "kind": "monk-meditate", "ctCost": 60, "mpCost": 5,
			"healMin": 5, "healMax": 10, "targetMode": "self",
			"tooltipNote": "Custa 5 MP. Remove todos os status negativos do Samurai, cura 5-10 de HP e aplica Regeneração (mesmo valor por turno e mesma duração da Regeneração em Área).",
			"sfx": "heal",
		},
		# Corte Iaijutsu: reaproveita a mira da Investida do Orc (targetMode
		# "charge" ~ linha reta cardeal até o primeiro inimigo), mas com o
		# próprio resolvedor (respeita terreno/elevação/ocupantes). Avança até
		# 2 quadrados e corta o alvo colado: alcance de mira 3 ("reach"); o golpe em
		# si é corpo a corpo (maxRange 1), sem a penalidade de tiro à queima-roupa.
		"samuraiIaijutsu": {
			"name": "Corte Iaijutsu", "icon": "💨", "kind": "iaijutsu", "ctCost": 70, "mpCost": 4,
			"damageMin": 5, "damageMax": 10, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "swing": "slash", "minRange": 1, "maxRange": 1, "reach": 3, "advanceMax": 2,
			"targetMode": "iaijutsu", "damageType": "physical", "usesSword": true,
			"firstStrikeCritBonus": 0.2,
			"tooltipNote": "Avança até 2 quadrados em linha reta (não atravessa obstáculos nem unidades) e corta o primeiro inimigo à frente: 5-10 de dano. Se o alvo ainda não agiu nesta rodada, +20 pontos percentuais de chance de crítico.",
			"sfx": "melee",
		},
		"samuraiHeronStance": {
			"name": "Postura da Garça", "icon": "🦢", "kind": "heron-stance", "ctCost": 40, "mpCost": 3,
			"turns": 1, "evasionBonus": 0.25, "counterMin": 5, "counterMax": 8, "targetMode": "self",
			"tooltipNote": "Até o próximo turno do Samurai: +25% de esquiva. Ao esquivar de um ataque corpo a corpo, contra-ataca o agressor causando 5-8 de dano.",
			"sfx": "melee",
		},
		"samuraiGuardBreak": {
			"name": "Quebra-Guarda", "icon": "🛡️", "kind": "guard-break", "ctCost": 50, "mpCost": 3,
			"damageMin": 5, "damageMax": 8, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "swing": "blunt", "minRange": 1, "maxRange": 1,
			"targetMode": "enemy", "damageType": "physical", "usesSword": true, "manualOnly": true,
			"appliesGuardBroken": {"turns": 2},
			"tooltipNote": "5-8 de dano e Guarda Quebrada por 2 turnos: cada ataque que acertar o alvo causa +1 de dano. Usar de novo renova a duração, sem acumular o bônus.",
			"sfx": "melee",
		},
		"samuraiCrescentSlash": {
			"name": "Corte Crescente", "icon": "🌙", "kind": "crescent-slash", "ctCost": 80, "mpCost": 5,
			"damageMin": 6, "damageMax": 10, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "swing": "slash", "minRange": 1, "maxRange": 1,
			"targetMode": "crescent-arc", "damageType": "physical",
			"tooltipNote": "Escolha uma direção: o arco atinge os 3 quadrados à frente (o da frente e os dois ao lado dele), 6-10 de dano em cada inimigo. A área aparece antes de confirmar.",
			"sfx": "melee",
		},
		"samuraiWindSlash": {
			"name": "Corte do Vento", "icon": "🌪️", "kind": "wind-slash", "ctCost": 60, "mpCost": 4,
			"damageMin": 7, "damageMax": 10, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "minRange": 1, "maxRange": 4, "cardinalOnly": true, "requiresClearPath": true,
			"targetMode": "enemy", "damageType": "physical", "projectile": "wind-blade", "manualOnly": true,
			"tooltipNote": "Lança um corte de espada em linha reta (4 direções) até 4 quadrados: 7-10 de dano no primeiro alvo do caminho.",
			"sfx": "melee",
		},
		# Só com menos de 40% do HP máximo (15 HP ou menos com HP 40).
		"samuraiLastResolve": {
			"name": "Última Determinação", "icon": "⛩️", "kind": "last-resolve", "ctCost": 50, "mpCost": 5,
			"damageMin": 10, "damageMax": 15, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "swing": "slash", "minRange": 1, "maxRange": 1,
			"targetMode": "enemy", "damageType": "physical", "usesSword": true, "manualOnly": true,
			"requiresHpBelowRatio": 0.4, "restoresMpOnKill": 3,
			"tooltipNote": "Só pode ser usada com menos de 40% do HP máximo (15 HP ou menos). 10-15 de dano; se derrotar o alvo, recupera 3 MP.",
			"sfx": "melee",
		},
		# --- Habilidades da Vestruz (pedido do usuário) --------------------
		"vestruzKick": {
			"name": "Coice Veloz", "icon": "🦶", "kind": "vestruz-kick", "ctCost": 50, "mpCost": 0,
			"damageMin": 5, "damageMax": 9, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "swing": "blunt", "minRange": 1, "maxRange": 1,
			"targetMode": "enemy", "damageType": "physical", "manualOnly": true,
			"knockback": {"distance": 1},
			"tooltipNote": "Ataque corpo a corpo: 5-9 de dano e empurra o alvo 1 quadrado (para na borda do mapa ou em quem estiver atrás).",
			"sfx": "melee",
		},
		# Disparada: corre até 4 quadrados em linha reta por espaços livres e, se
		# parar adjacente a um inimigo, dá uma trombada (damageMin/Max abaixo).
		"vestruzDash": {
			"name": "Disparada", "icon": "🏃", "kind": "vestruz-dash", "ctCost": 60, "mpCost": 3,
			"damageMin": 4, "damageMax": 7, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "swing": "blunt", "minRange": 1, "maxRange": 1, "reach": 4,
			"targetMode": "vestruz-dash", "damageType": "physical",
			"tooltipNote": "Corre até 4 quadrados em linha reta por espaços livres (leva o cavaleiro junto). Se terminar adjacente a um inimigo, dá uma trombada de 4-7 de dano nele (o da frente tem prioridade).",
			"sfx": "melee",
		},
		"vestruzDust": {
			"name": "Nuvem de Poeira", "icon": "🌫️", "kind": "dust-cloud", "ctCost": 70, "mpCost": 4,
			"areaRadius": 1, "accuracyDown": 0.2,
			"targetMode": "dust-square",
			"tooltipNote": "Poeira em área 3x3 centrada na Vestruz: todo inimigo atingido perde 20 pontos percentuais de chance de acerto por 1 turno (o próximo turno dele).",
			"sfx": "nature",
		},
		# Cura da Vestruz: healMin/healMax/hitChance copiados da Poção de Cura do
		# Químico (fim de build()) — mesmo efeito, mas só nela mesma e nos aliados
		# dos 4 quadrados cardeais (a área em losango de raio 1: sem diagonais).
		"vestruzHeal": {
			"name": "Cura da Vestruz", "icon": "💚", "kind": "vestruz-heal", "ctCost": 50, "mpCost": 4,
			"areaRadius": 1, "targetMode": "heal-cross",
			"tooltipNote": "Cura a própria Vestruz (e o cavaleiro montado) e cada aliado nos 4 quadrados cardeais adjacentes, 5-10 de HP. Não cura quem está nas diagonais.",
			"sfx": "heal",
		},
		"bardSongHeal": {
			"name":"Canção da Cura", "icon":"🎵", "kind":"bard-song-heal", "songKind":"heal",
			"ctCost":50, "mpCost":10, "hitChance":0.8, "applications":3, "targetMode":"self",
			"tooltipNote":"Global. Três aplicações (agora e no início dos próximos 2 turnos do Bardo); cada aliado vivo tem teste individual de 80%. Sucesso: +3 HP e +1 MP.", "sfx":"heal"},
		"bardSongInspiration": {
			"name":"Canção da Inspiração", "icon":"🎶", "kind":"bard-song-inspiration", "songKind":"inspiration",
			"ctCost":50, "mpCost":10, "hitChance":0.8, "applications":3, "targetMode":"self",
			"tooltipNote":"Global. Três aplicações; teste individual de 80% por aliado vivo a cada aplicação. Sucesso: +2 dano e +10 p.p. de acerto até a próxima aplicação.", "sfx":"arcane"},
		"bardSongDistraction": {
			"name":"Canção da Distração", "icon":"🎼", "kind":"bard-song-distraction", "songKind":"distraction",
			"ctCost":50, "mpCost":10, "hitChance":0.8, "applications":3, "targetMode":"self",
			"tooltipNote":"Global. Três aplicações; teste individual de 80% por inimigo vivo a cada aplicação. Sucesso: -30 CT (mínimo 0).", "sfx":"arcane"},
		"bardSongPain": {
			"name":"Canção da Dor", "icon":"🎻", "kind":"bard-song-pain", "songKind":"pain",
			"ctCost":50, "mpCost":10, "hitChance":0.8, "applications":3, "targetMode":"self",
			"tooltipNote":"Global. Três aplicações; teste individual de 80% por inimigo vivo a cada aplicação. Sucesso: -3 HP e -1 MP, usando a morte normal.", "sfx":"arcane"},
	}
	# Identidade visual/sonora das novas técnicas do Goblin.
	spells["lowBlow"]["sfx"] = "goblinLowBlow"
	spells["lowBlow"]["swing"] = "goblin-low-blow"
	spells["poisonPotion"]["sfx"] = "goblinPoison"
	spells["poisonPotion"]["projectileKind"] = "goblin-poison-potion"
	spells["poisonPotion"]["burstKind"] = "poison"
	spells["sandInEyes"]["sfx"] = "goblinSand"
	spells["sandInEyes"]["projectileKind"] = "goblin-sand"
	spells["sandInEyes"]["burstKind"] = "goblin-sand"
	spells["hitAndRun"]["sfx"] = "goblinDash"
	spells["hitAndRun"]["animationKind"] = "goblin-dash"
	spells["goblinAmbush"]["sfx"] = "goblinAmbush"
	spells["goblinAmbush"]["animationKind"] = "goblin-ambush"
	spells["stolenBarrel"]["sfx"] = "goblinBarrel"
	spells["stolenBarrel"]["projectileKind"] = "goblin-barrel"
	spells["stolenBarrel"]["burstKind"] = "goblin-barrel"
	spells["playDead"]["sfx"] = "goblinPlayDead"
	spells["playDead"]["animationKind"] = "goblin-feign"
	# Meditar (Monge) reaproveita LITERALMENTE o status Regeneração já
	# existente: valor por turno e duração vêm da Regeneração em Área, em vez
	# de números próprios que poderiam divergir dela depois.
	spells["monkMeditate"]["regenHealMin"] = spells["regenAoe"]["healMin"]
	spells["monkMeditate"]["regenHealMax"] = spells["regenAoe"]["healMax"]
	spells["monkMeditate"]["regenTurns"] = spells["regenAoe"]["regenTurns"]
	# Samurai: Saque Rápido = Tiro Certeiro (custo de MP, CT e bônus de
	# crítico copiados); Meditar = mesma Regeneração do Monge/Regeneração em Área.
	spells["samuraiQuickDraw"]["mpCost"] = spells["trueShot"]["mpCost"]
	spells["samuraiQuickDraw"]["ctCost"] = spells["trueShot"]["ctCost"]
	spells["samuraiQuickDraw"]["critBonus"] = spells["trueShot"]["critBonus"]
	spells["samuraiMeditate"]["regenHealMin"] = spells["regenAoe"]["healMin"]
	spells["samuraiMeditate"]["regenHealMax"] = spells["regenAoe"]["healMax"]
	spells["samuraiMeditate"]["regenTurns"] = spells["regenAoe"]["regenTurns"]
	# Vestruz: a cura é a MESMA da Poção de Cura do Químico.
	spells["vestruzHeal"]["healMin"] = spells["healPotion"]["healMin"]
	spells["vestruzHeal"]["healMax"] = spells["healPotion"]["healMax"]
	spells["vestruzHeal"]["hitChance"] = spells["healPotion"]["hitChance"]
	return spells
