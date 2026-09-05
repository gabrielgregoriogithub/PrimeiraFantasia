extends RefCounted
class_name EnemyVisualBehaviorController

## ETAPA 17 — vida visual de inimigos/chefes. Fluxo permitido, sempre numa
## direção só:
##
##   IA (GameState.enemy_act) decide  →  GameState resolve  →  este
##   controller só TRADUZ o resultado já aplicado em apresentação.
##
## Nunca o contrário: nada aqui escolhe alvo, decide mover, calcula dano ou
## reavalia a decisão da IA. As funções abaixo só leem `state.units`,
## `combat_before` (snapshot tirado ANTES da IA agir) e o board pra saber "o
## que aconteceu", nunca "o que fazer".

const ALLY_DEATH_REACTION_COOLDOWN_MS := 2200
const ALLY_DEATH_REACTION_RADIUS_SQ := 9.0 # raio 3 tiles, ao quadrado
const ALLY_DEATH_REACTION_MAX_PER_EVENT := 2

var _ally_death_last_reaction_ms: Dictionary = {}

## Pequeno "entrar em ação" no início do turno do inimigo: reaproveita o
## pulso de contato já usado pros passos (CharacterVisualController.
## pulse_contact), sem inventar tween novo. Roda dentro da janela de pausa
## que Main já esperava antes de agir (AI_TURN_INTRO_DELAY) — não adiciona
## nenhum atraso extra ao ritmo do turno.
func on_turn_start(token) -> void:
	if token == null or token._character_visual == null:
		return
	token._character_visual.pulse_contact(0.5)

## Reação curta e limitada (cooldown por unidade + teto por evento) de
## aliados vivos e próximos quando alguém do mesmo time morre. Nunca reage
## em todo mundo ao mesmo tempo (regra 23/64 — orçamento de reação).
func on_ally_died(units: Array, dying_unit: Dictionary, unit_tokens: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	var reacted := 0
	for unit in units:
		if reacted >= ALLY_DEATH_REACTION_MAX_PER_EVENT:
			break
		if unit["name"] == dying_unit["name"] or unit.get("team", "") != dying_unit.get("team", ""):
			continue
		if int(unit.get("hp", 0)) <= 0:
			continue
		var dx := int(unit["x"]) - int(dying_unit["x"])
		var dy := int(unit["y"]) - int(dying_unit["y"])
		if float(dx * dx + dy * dy) > ALLY_DEATH_REACTION_RADIUS_SQ:
			continue
		var last_reaction: int = int(_ally_death_last_reaction_ms.get(unit["name"], -ALLY_DEATH_REACTION_COOLDOWN_MS))
		if now - last_reaction < ALLY_DEATH_REACTION_COOLDOWN_MS:
			continue
		var token = unit_tokens.get(unit["name"])
		if token == null or token._character_visual == null:
			continue
		token._character_visual.pulse_contact(0.85)
		_ally_death_last_reaction_ms[unit["name"]] = now
		reacted += 1

## Limpa o cooldown de reação — chamado ao trocar de cenário/batalha, pra
## unidades novas não herdarem timestamps de uma partida anterior.
func reset() -> void:
	_ally_death_last_reaction_ms.clear()
