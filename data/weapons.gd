class_name Weapons
extends RefCounted

## Porte literal de WEAPONS (game.js:22-360). Nomes de campos preservados
## exatamente como no original para facilitar comparação linha a linha com
## a especificação viva em prototipoPVP-Browser-main/game.js.
## minRange/maxRange = distância Manhattan em que a arma pode ser usada.

static func build() -> Dictionary:
	var poison: Dictionary = StatusDotDamage.STATUS_DOT_DAMAGE["poison"]
	var burned: Dictionary = StatusDotDamage.STATUS_DOT_DAMAGE["burned"]
	return {
		"sword": {
			"name": "Espada", "icon": "🗡", "ctCost": 50,
			"damageMin": 8, "damageMax": 10, "critMultiplier": 2, "hitChance": 0.8,
			"swing": "slash", "minRange": 1, "maxRange": 1, "sfx": "melee",
		},
		"shortSword": {
			"name": "Espada Curta", "icon": "🗡", "ctCost": 50,
			"damageMin": 3, "damageMax": 6, "critMultiplier": 2, "hitChance": 0.85,
			"swing": "slash", "minRange": 1, "maxRange": 1,
			"appliesPoison": DataUtil.merge(poison, {"turns": 1, "ctDrainPerTurn": 10}),
			"tooltipNote": "Envenena ao acertar (1-2 de dano e -10 de CT por turno, por 1 turno).",
			"sfx": "melee",
		},
		"axe": {
			"name": "Machado", "icon": "🪓", "ctCost": 60,
			"damageMin": 8, "damageMax": 12, "critMultiplier": 3, "hitChance": 0.8,
			"swing": "blunt", "minRange": 1, "maxRange": 1, "sfx": "melee",
		},
		"shield": {
			"name": "Escudo", "icon": "🛡️", "ctCost": 60,
			"damageMin": 10, "damageMax": 12, "critMultiplier": 3, "hitChance": 0.7,
			"swing": "blunt", "minRange": 1, "maxRange": 1,
			"appliesCtDrain": 10,
			"tooltipNote": "Quem for atingido perde 10 de CT.",
			"sfx": "melee",
		},
		"bow": {
			"name": "Arco", "icon": "🏹", "ctCost": 50,
			"damageMin": 6, "damageMax": 8, "critMultiplier": 2, "hitChance": 0.8,
			"minRange": 2, "maxRange": 5, "projectile": "arrow",
			"ignoresTerrainLineOfSight": true,
			"sfx": "ranged",
		},
		"sling": {
			"name": "Funda", "icon": "🌀", "ctCost": 30,
			"damageMin": 3, "damageMax": 6, "critMultiplier": 2, "hitChance": 0.8,
			"minRange": 1, "maxRange": 4, "projectile": "stone",
			"appliesCtDrain": 15, "ctDrainConfirmChance": 0.4,
			"tooltipNote": "Se acertar (70%), tem 40% de chance de roubar 15 de CT do alvo.",
			"sfx": "ranged",
		},
		# Pedido do usuário: ataques do Monge. Soco é a arma corpo a corpo
		# básica dele (mesmo critMultiplier 2 do resto do catálogo, ver
		# Espada/Arco/Funda). A Rajada de Golpes agora é habilidade (ver spells.gd:
		# monkFlurry): reaproveita o campo genérico "hits" (já usado pelo Míssil
		# Mágico da Maga, ver GameState.perform_attack) pra disparar DOIS
		# golpes em sequência, cada um rolando acerto/crítico/dano próprios —
		# o segundo sai mesmo quando o primeiro erra, porque o laço de
		# perform_attack só para cedo se o alvo morrer. "damageType":
		# "physical" é obrigatório aqui: damage_type_of classifica como
		# "magic" qualquer item com mpCost, e a Rajada é soco puro (mesmo
		# motivo do bardCrossbow acima).
		# Pedido do usuário: Samurai. Espada corpo a corpo própria (6-12, 80%
		# de acerto, 15% de crítico, CT 50 = o padrão do corpo a corpo). O Arco
		# dele é LITERALMENTE o w["bow"] do Arqueiro (ver units.gd).
		# Pedido do usuário: Vestruz. Cuspe Afiado é ataque à distância de 0 MP;
		# o alcance/mira (1-3, só linha reta cardeal) é COPIADO de Arremessar
		# Espada do Guerreiro em Units.build(), nunca duplicado aqui.
		"vestruzSpit": {
			"name": "Cuspe Afiado", "icon": "💦", "ctCost": 50,
			"damageMin": 3, "damageMax": 6, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "minRange": 1, "maxRange": 3, "cardinalOnly": true,
			"projectile": "spit", "spriteAction": "cuspe",
			"tooltipNote": "Cospe um jato afiado, só nas 4 direções cardeais, até 3 quadrados (mesma mira do Arremessar Espada). Custa 0 MP.",
			"sfx": "ranged",
		},
		"samuraiSword": {
			"name": "Espada", "icon": "🗡", "ctCost": 50,
			"damageMin": 6, "damageMax": 12, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "swing": "slash", "minRange": 1, "maxRange": 1,
			"tooltipNote": "Golpe de katana corpo a corpo.",
			"sfx": "melee",
		},
		"monkPunch": {
			"name": "Soco", "icon": "👊", "ctCost": 50,
			"damageMin": 5, "damageMax": 10, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "swing": "blunt", "minRange": 1, "maxRange": 1,
			"spriteAction": "soco",
			"tooltipNote": "Golpe corpo a corpo básico do Monge.",
			"sfx": "melee",
		},
		"dagger": {
			"name": "Adaga", "icon": "🔪", "ctCost": 50,
			"damageMin": 2, "damageMax": 5, "critMultiplier": 2, "hitChance": 1,
			"swing": "stab", "minRange": 1, "maxRange": 1,
			"appliesSlow": {"turns": 1, "moveReduction": 1},
			"tooltipNote": "Sempre acerta. Quem for atingido perde 1 de deslocamento por 1 turno.",
			"sfx": "melee",
		},
		# Pedido do usuário: Kobold (Goblinoides). Adaga corpo a corpo (mesmo
		# alcance/CT/swing da Adaga do Goblin) que aplica o Envenenado já
		# existente — o mesmo da Zarabatana (dano padrão de STATUS_DOT_DAMAGE,
		# 3 turnos, reaplicação somando turnos via add_status_effect) — só
		# quando acerta (resolve_single_hit retorna antes dos `applies*` no erro).
		"koboldPoisonDagger": {
			"name": "Adaga Envenenada", "icon": "🗡️", "ctCost": 50,
			"damageMin": 3, "damageMax": 6, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.9, "swing": "stab", "minRange": 1, "maxRange": 1,
			"appliesPoison": DataUtil.merge(poison, {"turns": 3}),
			"tooltipNote": "Ataque corpo a corpo. Ao acertar, aplica Envenenado (1-3 de dano por turno, por 3 turnos).",
			"sfx": "melee",
		},
		# Lança arremessada do Kobold: o alcance/linha limpa são COPIADOS da
		# Zarabatana da Xamã em Units.build() (mesmo padrão do Cuspe Afiado da
		# Vestruz), nunca duplicados aqui. Projétil "arrow", como o Arremessar
		# Lança do Gnoll.
		"koboldSpear": {
			"name": "Lança", "icon": "🔱", "ctCost": 50,
			"damageMin": 3, "damageMax": 6, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "projectile": "arrow",
			"tooltipNote": "Arremesso à distância com o mesmo alcance da Zarabatana. Precisa de linha limpa; se algo bloquear, acerta quem estiver no caminho.",
			"sfx": "ranged",
		},
		# Pedido do usuário: Troncus (Goblinoides, 2x2). Custos de CT no padrão
		# do elenco (o pedido original era CT 0, o que deixaria o Troncus agir
		# sem nunca passar a vez — decidido com o usuário). Empurrão reaproveita
		# o campo genérico `knockback` (Cauda do Dragão), sem dano extra quando
		# bloqueado. Alcance medido da borda do corpo 2x2 (GameState.manhattan).
		"troncusPunch": {
			"name": "Punho de Tronco", "icon": "✊", "ctCost": 60,
			"damageMin": 6, "damageMax": 12, "critMultiplier": 2, "critChance": 0.1,
			"hitChance": 0.85, "swing": "blunt", "minRange": 1, "maxRange": 1,
			"damageType": "physical", "knockback": {"distance": 1},
			"tooltipNote": "Corpo a corpo. Ao acertar, empurra o alvo 1 casa para longe do Troncus, se o destino estiver livre e dentro do mapa (bloqueado: só o dano). Personagens 2x2 não são empurrados.",
			"sfx": "melee",
		},
		# Chicote de Cipó: status próprio "vineSlow" (-1 MOV), que expira no FIM
		# do turno do alvo (mesma convenção do Enraizado) — assim a redução vale
		# de fato durante 1 turno dele. Reaplicar só renova a duração.
		"troncusVineWhip": {
			"name": "Chicote de Cipó", "icon": "🌿", "ctCost": 50,
			"damageMin": 3, "damageMax": 5, "critMultiplier": 2, "critChance": 0.05,
			"hitChance": 0.9, "swing": "slash", "minRange": 1, "maxRange": 2,
			"damageType": "physical", "appliesVineSlow": {"turns": 1, "moveReduction": 1},
			"tooltipNote": "Alcance 2. Ao acertar, o alvo perde 1 de deslocamento durante 1 turno (não acumula; reaplicar renova a duração).",
			"sfx": "melee",
		},
		# Pedido do usuário: Lobo dos Goblinoides. Mordida = ataque básico E a
		# arma do Contra-ataque de Mordida (counterWeapon). `healOnHit` é o
		# campo genérico novo de resolve_single_hit (cura fixa sorteada no
		# atacante ao acertar, sem passar do HP máximo). Acerto/crítico não
		# foram especificados: padrão do catálogo (80%, crítico padrão).
		"wolfBite": {
			"name": "Mordida", "icon": "🐺", "ctCost": 50,
			"damageMin": 4, "damageMax": 8, "critMultiplier": 2, "hitChance": 0.8,
			"swing": "stab", "minRange": 1, "maxRange": 1, "damageType": "physical",
			"healOnHit": {"min": 1, "max": 2},
			"tooltipNote": "Corpo a corpo. Ao acertar, o Lobo recupera 1-2 HP (sem passar do máximo).",
			"sfx": "melee",
		},
		"club": {
			"name": "Tacape", "icon": "🔨", "ctCost": 70,
			"damageMin": 10, "damageMax": 14, "critMultiplier": 2, "critChance": 0.2,
			"hitChance": 0.7, "swing": "blunt", "minRange": 1, "maxRange": 1,
			"appliesCtDrain": 10,
			"tooltipNote": "Quem for atingido perde 10 de CT.",
			"sfx": "melee",
		},
		"cajado": {
			"name": "Cajado", "icon": "🪄", "ctCost": 50,
			"damageMin": 2, "damageMax": 4, "critMultiplier": 2, "critChance": 0.1,
			"hitChance": 0.7, "swing": "blunt", "minRange": 1, "maxRange": 1,
			"appliesMpDrain": 5,
			"tooltipNote": "Quem for atingido perde 5 de MP.",
			"sfx": "melee",
		},
		"zarabatana": {
			"name": "Zarabatana", "icon": "🎯", "ctCost": 40,
			"damageMin": 2, "damageMax": 6, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.7, "minRange": 1, "maxRange": 3, "requiresClearPath": true,
			"appliesPoison": DataUtil.merge(poison, {"turns": 3}),
			"tooltipNote": "Precisa de linha limpa; se algo bloquear, acerta quem estiver no caminho. Envenena ao acertar.",
			"sfx": "ranged",
		},
		"crossbow": {
			"name": "Besta", "icon": "🏹", "ctCost": 50,
			"damageMin": 4, "damageMax": 6, "critMultiplier": 2, "critChance": 0.2,
			"hitChance": 0.8, "minRange": 1, "maxRange": 3, "requiresClearPath": true,
			"aerial": true, "projectile": "bolt",
			"tooltipNote": "Precisa de linha limpa; se algo bloquear, acerta quem estiver no caminho.",
			"sfx": "ranged",
		},
		"bardCrossbow": {
			"name": "Besta", "icon": "🏹", "ctCost": 50,
			"damageMin": 3, "damageMax": 6, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "minRange": 1, "maxRange": 3,
			"requiresClearPath": true, "aerial": true, "projectile": "bolt",
			"damageType": "physical", "spriteAction": "crossbow",
			"tooltipNote": "Ataque físico à distância; precisa de linha limpa e para no primeiro obstáculo.",
			"sfx": "ranged",
		},
		"dirk": {
			"name": "Punhal", "icon": "🗡️", "ctCost": 50,
			"damageMin": 3, "damageMax": 6, "critMultiplier": 3,
			"critChanceByAngle": {"front": 0.15, "side": 0.2, "back": 0.25},
			"invisibleCritChance": 0.40,
			"hitChance": 0.9, "swing": "stab", "minRange": 1, "maxRange": 1,
			# Pedido do usuário: envenena ao acertar, igual outras armas afiadas
			# (Espada Curta/Zarabatana) — turns:2 como meio-termo entre as duas
			# (shortSword usa 1, zarabatana usa 3); ajuste se quiser outro valor.
			"appliesPoison": DataUtil.merge(poison, {"turns": 2}),
			"tooltipNote": "Chance de crítico aumenta atacando pelo lado ou pelas costas; invisível, a crítica fica travada em 40% em qualquer ângulo. Envenena ao acertar.",
			"sfx": "melee",
		},
		"shock": {
			"name": "Choque", "icon": "⚡", "ctCost": 40,
			"damageMin": 6, "damageMax": 8, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "minRange": 1, "maxRange": 1,
			"appliesCtDrain": 20,
			"tooltipNote": "Quem for atingido perde 20 de CT.",
			"sfx": "lightning",
		},
		"light": {
			"name": "Luz", "icon": "💡", "ctCost": 50,
			"damageMin": 4, "damageMax": 6, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "minRange": 1, "maxRange": 3,
			"appliesBlind": {"turns": 2}, "projectile": "spark",
			"tooltipNote": "Quem for atingido fica com -10% de chance de acerto por 2 turnos.",
			"sfx": "arcane",
		},
		"firearm": {
			"name": "Arma de Fogo", "icon": "🔫", "ctCost": 50,
			"damageMin": 6, "damageMax": 8, "critMultiplier": 3, "critChance": 0.1,
			"hitChance": 0.8, "minRange": 1, "maxRange": 6, "requiresClearPath": true,
			"projectile": "bullet",
			# "Arma de Fogo" é só o nome da arma (pistola) — sem isso,
			# damage_type_of() classificava o tiro comum como dano elemental
			# de fogo por causa da palavra "fogo" no nome, curando os
			# inimigos de fogo (Fogo Vivo/Homem de Lava) em vez de feri-los.
			"damageType": "physical",
			"tooltipNote": "Precisa de linha limpa; se algo bloquear, acerta quem estiver no caminho.",
			"sfx": "ranged",
		},
		"trunk": {
			"name": "Tronco", "icon": "🪵", "ctCost": 60,
			"damageMin": 10, "damageMax": 14, "critMultiplier": 2, "critChance": 0.1,
			"hitChance": 0.7, "minRange": 1, "maxRange": 2, "targetMode": "line-aoe",
			"swing": "blunt",
			"tooltipNote": "Acerta todos os inimigos na direção escolhida, até 2 quadrados.",
			"sfx": "melee",
		},
		"throwLog": {
			# Pedido do usuário: ícone próprio (era o mesmo 🪵 do Tronco, o outro
			# ataque do Troll).
			"name": "Tacar Tronco", "icon": "🪃", "ctCost": 70,
			"damageMin": 6, "damageMax": 8, "critMultiplier": 2, "critChance": 0.1,
			"hitChance": 0.8, "minRange": 1, "maxRange": 3, "cardinalOnly": true,
			"targetMode": "cardinal-blast", "bandLength": 3, "bandWidth": 3,
			"knockback": {"distance": 1, "blockedExtraDamage": 1},
			"tooltipNote": "Escolha uma direção cardeal: acerta uma faixa de 3x3 quadrados (9 no total) nessa direção, empurrando os atingidos 1 quadrado pra longe do Troll; quem estiver bloqueado toma +1 de dano em vez de ser empurrado.",
			"sfx": "nature",
		},
		"trollCounter": {
			"name": "Contra-ataque", "icon": "👊", "ctCost": 0,
			"damageMin": 3, "damageMax": 5, "critMultiplier": 2, "hitChance": 0.8,
			"minRange": 1, "maxRange": 1, "sfx": "melee",
		},
		"iceRay": {
			"name": "Raio de Gelo", "icon": "🧊", "ctCost": 50,
			"damageMin": 3, "damageMax": 6, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "minRange": 1, "maxRange": 5, "cardinalOnly": true,
			"requiresClearPath": true,
			"appliesSpeedReduction": {"turns": 2, "amount": 1},
			"projectile": "frost-wand-spd", "beamTint": "ice",
			"tooltipNote": "Só em linha reta cardeal, até 5 quadrados, e precisa de linha limpa (para no primeiro obstáculo). Se acertar, reduz a agilidade do alvo em 1 por 2 turnos.",
			"sfx": "frostWandZapSpd",
		},
		"claw": {
			"name": "Garra", "icon": "🦴", "ctCost": 50,
			"damageMin": 4, "damageMax": 8, "critMultiplier": 2, "hitChance": 0.8,
			"swing": "slash", "minRange": 1, "maxRange": 1,
			"appliesBleed": {"damageMin": 1, "damageMax": 1, "turns": 3},
			"tooltipNote": "Ataque corpo a corpo. Se acertar, o alvo sangra (1 de dano por turno) por 3 turnos.",
			"sfx": "melee",
		},
		# Pedido do usuário: Raio de Fogo do Demônio das Chamas idêntico ao Raio
		# de Gelo (mesmo custo/alcance/chance de acerto/dano/trajetória), só
		# trocando o elemento — reduz agilidade vira incendeia. "fogo" no nome
		# já classifica como damageType "fire" via GameState.damage_type_of,
		# sem precisar declarar o campo. projectile "fireball" reaproveita o
		# VFX/SFX de impacto de fogo já existentes (cor laranja, playSfx
		# "fireImpact") em vez de um "wand" de feixe dedicado.
		"fireRay": {
			"name": "Raio de Fogo", "icon": "🔥", "ctCost": 50,
			"damageMin": 3, "damageMax": 6, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "minRange": 1, "maxRange": 5, "cardinalOnly": true,
			"requiresClearPath": true,
			"appliesBurn": DataUtil.merge(burned, {"turns": 3}),
			"projectile": "fireball", "beamTint": "fire",
			"tooltipNote": "Só em linha reta cardeal, até 5 quadrados, e precisa de linha limpa (para no primeiro obstáculo). Se acertar, incendeia o alvo por 3 turnos.",
			"sfx": "fire",
		},
		# Pedido do usuário: Vampiro. Chance de acerto/crítico não foram
		# especificadas — usa o padrão do resto do catálogo (80% de acerto,
		# crítico ausente = GameConstants.CRIT_CHANCE via get_crit_chance).
		# `lifesteal` é o campo genérico novo de resolve_single_hit (fração do
		# dano REALMENTE causado que volta como HP pro atacante).
		"vampiricTouch": {
			"name": "Toque Vampírico", "icon": "🩸", "ctCost": 50,
			"damageMin": 3, "damageMax": 6, "critMultiplier": 2, "hitChance": 0.8,
			"minRange": 1, "maxRange": 3, "lifesteal": 0.5,
			"tooltipNote": "Alcance 3. Recupera 50% do dano efetivamente causado (100% na forma de morcego).",
			"sfx": "poison",
		},
		"vampireBite": {
			"name": "Mordida", "icon": "🧛", "ctCost": 50,
			"damageMin": 4, "damageMax": 8, "critMultiplier": 2, "hitChance": 0.8,
			"swing": "stab", "minRange": 1, "maxRange": 1, "lifesteal": 0.5,
			"tooltipNote": "Ataque corpo a corpo. Recupera 50% do dano efetivamente causado (100% na forma de morcego).",
			"sfx": "melee",
		},
		# Pedido do usuário: Dragão Vermelho — Garra e Cauda são armas próprias
		# (nomes iguais aos de outros itens do catálogo, ex: "claw"/Demônio das
		# Chamas, mas números diferentes — mesmo padrão já usado por
		# "crossbow"/"bardCrossbow", os dois "Besta" com estatísticas distintas).
		"dragonClaw": {
			"name": "Garra", "icon": "🦴", "ctCost": 50,
			"damageMin": 5, "damageMax": 10, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "swing": "slash", "minRange": 1, "maxRange": 1,
			"appliesBleed": {"damageMin": 1, "damageMax": 1, "turns": 3},
			"tooltipNote": "Ataque corpo a corpo. Se acertar, o alvo sangra (1 de dano por turno) por 3 turnos.",
			"sfx": "melee",
		},
		# Pedido do usuário: Lich. Sem elemento fogo/gelo/relâmpago no nome —
		# damage_type_of cairia no fallback "physical" (sem mpCost) por
		# padrão, o que faria o raio ser bloqueado por corpos etéreos
		# (Fantasma) como um ataque físico comum; "magic" evita isso e
		# combina com a natureza necromântica do efeito.
		"decayRay": {
			"name": "Raio de Decaimento", "icon": "☠️", "ctCost": 50,
			"damageMin": 3, "damageMax": 6, "critMultiplier": 2, "hitChance": 0.8,
			"minRange": 1, "maxRange": 4, "cardinalOnly": true, "requiresClearPath": true,
			"damageType": "magic",
			"appliesSpeedReduction": {"turns": 2, "amount": 1},
			"appliesSlow": {"turns": 1, "moveReduction": 1},
			"appliesCtDrain": 30,
			# "poison" já é verde em _vfx_color_for_kind (main.gd) — reaproveita
			# a cor pronta em vez de criar um kind "necrotic" novo só pra isso.
			"projectile": "poison", "beamTint": "necrotic",
			"tooltipNote": "Só em linha reta cardeal, até 4 quadrados, e precisa de linha limpa (para no primeiro obstáculo). Se acertar: -1 de agilidade por 2 turnos, -1 de deslocamento por 1 turno, e rouba 30 de CT.",
			"sfx": "poison",
		},
		"dragonTail": {
			"name": "Cauda", "icon": "💢", "ctCost": 60,
			"damageMin": 4, "damageMax": 8, "critMultiplier": 2, "critChance": 0.15,
			"hitChance": 0.8, "swing": "blunt", "minRange": 1, "maxRange": 1,
			"knockback": {"distance": 2}, "appliesCtDrain": 30,
			"tooltipNote": "Ataque corpo a corpo. Se acertar, empurra o alvo até 2 quadrados para trás (para na primeira parede/unidade/borda do mapa) e rouba 30 de CT.",
			"sfx": "melee",
		},
	}
