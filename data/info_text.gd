class_name InfoText
extends RefCounted

## Porte literal de TERRAIN_INFO/STRUCTURE_INFO (game.js:4014-4094) — textos
## de popup mostrados ao clicar num tile de terreno/estrutura vazio. Puro
## texto de UI, sem lógica de regra.

const TERRAIN_INFO := {
	"water": {
		"icon": "🌊", "name": "Rio",
		"desc": "Custa 2 pontos de movimento pra atravessar 1 quadrado (em vez de 1). Quem está na água tem +10% de chance de SER acertado e -10% de chance de acertar com os próprios golpes.",
	},
	"waterfall": {
		"icon": "💦", "name": "Cachoeira",
		"desc": "Custa 2 pontos de movimento pra atravessar 1 quadrado (em vez de 1). Quem está na cachoeira tem +10% de chance de SER acertado e -10% de chance de acertar com os próprios golpes.",
	},
	"tree": {
		"icon": "🌳", "name": "Árvore",
		"desc": "Bloqueia o caminho por completo. Ninguém consegue atravessar nem parar aqui. Tem 10 de HP: ataques em área que passarem por cima dela causam dano, e ao chegar a 0 ela é destruída, liberando o quadrado.",
	},
	"house": {
		"icon": "🏠", "name": "Casa",
		"desc": "Bloqueia o caminho, mas dá pra subir nela (ocupar o mesmo quadrado). Quem está em cima tem +10% de chance de acertar os próprios golpes. Tem 30 de HP: pode ser destruída por qualquer tipo de ataque, mesmo vazia, virando escombros e liberando o quadrado.",
	},
	"tent": {
		"icon": "⛺", "name": "Tenda",
		"desc": "Bloqueia o caminho por completo. Ninguém consegue atravessar nem parar aqui. Tem 20 de HP: pode ser destruída por qualquer tipo de ataque, mesmo vazia, virando escombros e liberando o quadrado.",
	},
	"stump": {
		"icon": "🪵", "name": "Galhos no chão",
		"desc": "Restos de uma árvore destruída. Só decoração, não bloqueia nem tem nenhum efeito.",
	},
	"house-rubble": {
		"icon": "🧱", "name": "Escombros",
		"desc": "Restos de uma casa destruída. Só decoração, não bloqueia nem tem nenhum efeito.",
	},
	"tent-rubble": {
		"icon": "🧱", "name": "Escombros",
		"desc": "Restos de uma tenda destruída. Só decoração, não bloqueia nem tem nenhum efeito.",
	},
	"flower": {
		"icon": "🌼", "name": "Flor",
		"desc": "Só decoração — não bloqueia movimento nem linha de mira de ataques à distância, não tem HP nem nenhum efeito de jogo.",
	},
}

const STRUCTURE_INFO := {
	"castle": {
		"icon": "🏰", "name": "Castelo",
		"desc": "Só heróis podem entrar (bloqueia o caminho pra qualquer inimigo por completo, nem passar). Dá pra ocupar os 9 quadrados como se fosse 1 só, no máximo 1 herói por vez. Quem está lá dentro regenera 1 HP e 1 MP a cada turno que passa (de qualquer personagem), tem +20% de chance de acertar os próprios golpes, e quem ataca esse herói tem -10% de chance de acertar. Pode ser atacado mesmo vazio; ataques em área que atingirem o quadrado causam o DOBRO de dano nele, e se houver um herói lá dentro, a mesma explosão também o atinge normalmente. Se o Castelo for destruído, o time inimigo vence a partida na hora.",
	},
	"mountain": {
		"icon": "⛰", "name": "Montanha",
		"desc": "Só inimigos podem entrar (bloqueia o caminho pra qualquer herói por completo, nem passar). Dá pra ocupar os 9 quadrados como se fosse 1 só, no máximo 1 inimigo por vez. Quem está lá dentro regenera 1 HP e 1 MP a cada turno que passa (de qualquer personagem), tem +20% de chance de acertar os próprios golpes, e quem ataca esse inimigo tem -10% de chance de acertar. Pode ser atacada mesmo vazia; ataques em área que atingirem o quadrado causam o DOBRO de dano nela, e se houver um inimigo lá dentro, a mesma explosão também o atinge normalmente. Se a Montanha for destruída, o time do Guerreiro vence a partida na hora.",
	},
}
