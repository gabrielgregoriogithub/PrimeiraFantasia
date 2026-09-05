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
			"name": "Míssil Mágico", "icon": "✨", "ctCost": 50, "mpCost": 3,
			# Dano igual à Varinha de Míssil Mágico de referência sem nenhum
			# nível de upgrade: min(lvl)=2+lvl, max(lvl)=8+2*lvl com lvl=0 —
			# ver WandOfMagicMissile.java. O dano máximo aqui era 10 (não 8),
			# divergindo do valor real da varinha.
			"damageMin": 2, "damageMax": 8, "critMultiplier": 1, "critChance": 0,
			"hitChance": 1, "minRange": 1, "maxRange": 5, "targetMode": "enemy",
			"projectile": "magic-missile-spd",
			# A varinha de referência nunca "erra" por obstrução — o disparo
			# sempre acerta o primeiro personagem no caminho da Ballistica,
			# sem checar terreno/elevação (ver WandOfMagicMissile.onZap). O
			# texto abaixo já prometia esse comportamento ("como o Arco", que
			# tem ignoresTerrainLineOfSight true), mas a flag em si nunca
			# tinha sido setada aqui — a magia era bloqueada por elevação na
			# prática, ao contrário do que o tooltip dizia.
			"ignoresTerrainLineOfSight": true,
			"tooltipNote": "Ignora obstáculos no caminho, como o Arco.",
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
			"name": "Ressurreição", "icon": "✨", "kind": "resurrect", "ctCost": 90, "mpCost": 7,
			"critChance": 0, "hitChance": 0.7, "minRange": 0, "maxRange": 3,
			"targetMode": "resurrect",
			"tooltipNote": "Alcance 3; ressuscita um aliado morto há até 3 turnos com metade do HP máximo. 70% de chance de sucesso.",
			"sfx": "heal",
		},
		"resurrectAlchemist": {
			"name": "Ressurreição", "icon": "✨", "kind": "resurrect", "ctCost": 90, "mpCost": 7,
			"critChance": 0, "hitChance": 1, "minRange": 0, "maxRange": 3,
			"targetMode": "resurrect",
			"tooltipNote": "Alcance 3; ressuscita um aliado morto há até 3 turnos com metade do HP máximo.",
			"sfx": "heal",
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
		"trap": {
			"name": "Armadilha", "icon": "🪤", "ctCost": 55, "mpCost": 3, "areaRadius": 1,
			"noDamage": true, "minRange": 1, "maxRange": 3, "targetMode": "trap",
			"tooltipNote": "Invisível até um inimigo pisar: causa 1-3 de dano e cada quadrado custa +1 de deslocamento.<br>Revela a área ao ser acionada, some em 3 turnos. Aliados imunes; não instala em cima de alguém.",
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
			"mpCost": 4, "damageBonus": 3, "critBonus": 0.15, "targetMode": "self",
			"tooltipNote": "Soma +3 de dano e +15% de chance de crítico ao seu próximo ataque neste turno.",
			"sfx": "melee",
		},
		"throwSword": {
			"name": "Arremessar Espada", "icon": "🗡️", "ctCost": 50, "mpCost": 3,
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
			"name": "Defender", "icon": "🛡️", "kind": "defend", "ctCost": 0, "mpCost": 1,
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
			"name": "Tiro Longo", "icon": "🏹", "kind": "long-shot", "ctCost": 0, "mpCost": 3,
			"targetMode": "self",
			"tooltipNote": "Dobra o alcance do seu próximo ataque neste turno.",
			"sfx": "ranged",
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
			"name": "Tiro Penetrante", "icon": "🏹", "ctCost": 60, "mpCost": 3,
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
			"name": "Agilidade", "icon": "🌀", "kind": "haste-attack", "ctCost": 0, "mpCost": 4,
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
			"name": "Cone de Gelo", "icon": "🧊", "kind": "cone-ice", "ctCost": 50, "mpCost": 10,
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
	return spells
