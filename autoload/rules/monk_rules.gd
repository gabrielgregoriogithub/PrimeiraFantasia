class_name MonkRules
extends RefCounted

## Monge: Foco, Dash, Meditar e Chute do Dragao.
## Extraido de autoload/game_state.gd: todas as funcoes sao estaticas e recebem o
## estado (`gs`) como 1o argumento. A API publica continua em GameState, via
## wrappers de uma linha (mesmos nomes e assinaturas).

## Foco (Monge): postura defensiva "total" — ver o bloco `focus` em
## resolve_single_hit (ataque físico é anulado, magia cai pela metade). Ação
## livre igual ao Defender (ctCost 0, finish_free_self_action), então o Monge
## ainda pode mover/atacar no mesmo turno. A duração usa o idioma do Pés
## Ágeis: turnsLeft 1 aplicado no próprio turno e decrementado só quando o
## MESMO Monge recomeça (apply_status_effects_at_turn_start). Pedido do
## usuário: o custo de MP sai ANTES da recuperação, então o saldo líquido de
## MP no turno é +1, não +3.
static func cast_monk_focus(gs: GameState, caster: Dictionary, item: Dictionary) -> void:
	gs.finish_free_self_action(caster, item)
	var existing = null
	for e in caster.get("statusEffects", []):
		if e["type"] == "focus":
			existing = e
			break
	if existing != null:
		existing["turnsLeft"] = int(item.get("turns", 1))
	else:
		(caster["statusEffects"] as Array).append({"type": "focus", "turnsLeft": int(item.get("turns", 1))})
	var heal_amount: int = int(item.get("healAmount", 0))
	var mana_amount: int = int(item.get("manaAmount", 0))
	var healed: int = mini(heal_amount, int(caster["maxHp"]) - int(caster["hp"]))
	caster["hp"] = mini(int(caster["maxHp"]), int(caster["hp"]) + heal_amount)
	var restored: int = 0
	if caster.has("maxMp"):
		restored = mini(mana_amount, int(caster["maxMp"]) - int(caster["mp"]))
		caster["mp"] = mini(int(caster["maxMp"]), int(caster["mp"]) + mana_amount)
	gs._log("%s entra em Foco: bloqueia ataques físicos, reduz o dano de magia pela metade e recupera %d HP e %d MP." % [caster["name"], healed, restored])


## Dash (Monge): mesmo desenho da Agilidade (cast_agility) só que pro
## MOVIMENTO. Antes de mover, guarda um movimento extra que perform_move
## consome em vez de marcar hasMoved; depois de já ter movido, reabre o
## movimento na hora (sem somar bônus nenhum) — assim existe exatamente mais
## um movimento no turno, nunca um terceiro.
static func cast_monk_dash(gs: GameState, caster: Dictionary, item: Dictionary) -> void:
	if caster.get("hasMoved", false):
		caster["hasMoved"] = false
		caster["extraMovesRemaining"] = 0
	else:
		caster["extraMovesRemaining"] = 1
	gs._log("%s usa %s e poderá se mover mais uma vez neste turno!" % [caster["name"], item["name"]])
	gs.finish_free_self_action(caster, item)


## Meditar (Monge/Samurai): limpeza + cura + Regeneração. A Regeneração aplicada é
## LITERALMENTE o status "regen" já existente (mesmo valor por turno e mesma
## duração da Regeneração em Área — os números vêm do próprio item, copiados
## de regenAoe em Spells.build()), então resolve no fim do turno pelo mesmo
## caminho de sempre (apply_status_effects_at_turn_end). Consome a ação do
## turno (ctCost > 0, finalize_action), igual às outras curas do jogo.
static func cast_monk_meditate(gs: GameState, caster: Dictionary, item: Dictionary) -> void:
	# Devolve o que os status removidos tinham tirado: quem restaura
	# agilidade/deslocamento normalmente é o vencimento em
	# apply_status_effects_at_turn_start, e ele nunca roda pra um efeito que
	# some antes da hora.
	for effect in caster.get("statusEffects", []):
		match String(effect.get("type", "")):
			"slowed": caster["speed"] = int(caster["speed"]) + int(effect.get("speedReduction", 0))
			"weakened": caster["moveRange"] = int(caster["moveRange"]) + int(effect.get("moveReduction", 0))
	caster["statusEffects"] = (caster.get("statusEffects", []) as Array).filter(
		func(effect): return not gs.MONK_MEDITATE_REMOVABLE_STATUSES.has(effect.get("type", ""))
	)
	var heal: int = gs.rng.randi_range(int(item.get("healMin", 5)), int(item.get("healMax", 10)))
	var healed: int = mini(heal, int(caster["maxHp"]) - int(caster["hp"]))
	caster["hp"] = mini(int(caster["maxHp"]), int(caster["hp"]) + heal)
	gs.add_status_effect(caster, {
		"type": "regen",
		"healMin": int(item.get("regenHealMin", 2)),
		"healMax": int(item.get("regenHealMax", 4)),
		"turnsLeft": int(item.get("regenTurns", 3)),
	})
	gs._log("%s medita: remove todos os efeitos negativos, recupera %d HP e passa a regenerar vida." % [caster["name"], healed])
	gs.finalize_action(caster, item)


## Chute do Dragão (Monge): o jogador escolhe o TILE (alcance idêntico ao do
## Relâmpago da Maga) e o Monge VOA até lá pra chutar. A trajetória dispensa
## linha de visão livre pela mesma flag da Flecha do Arqueiro
## (ignoresTerrainLineOfSight, já respeitada por compute_range_tiles). O
## pouso é no quadrado do lado de cá do alvo — assim o empurrão sai na mesma
## direção do voo — e, se ele não servir, no quadrado livre mais próximo do
## impacto (_nearest_free_anchor, o mesmo buscador em anéis dos spawns), o
## que já cobre colisão, terreno e borda do mapa. Dano/crítico/empurrão de 2/
## paralisia de 1 turno são resolvidos por resolve_single_hit a partir dos
## campos genéricos do item (knockback/appliesParalyzed — os mesmos da Cauda
## do Dragão Vermelho e do Choque da Fada), inclusive a regra de empurrão
## bloqueado (push_unit para na primeira parede/unidade/borda). Conta como
## mover E atacar no mesmo turno, igual à Investida do Orc.
static func cast_dragon_kick(gs: GameState, caster: Dictionary, item: Dictionary, target_tile: Dictionary) -> bool:
	var tx: int = int(target_tile["x"])
	var ty: int = int(target_tile["y"])
	# Trajetória só linear, igual ao Relâmpago: mesma linha, coluna ou diagonal.
	var offset_x: int = tx - int(caster["x"])
	var offset_y: int = ty - int(caster["y"])
	if (offset_x == 0 and offset_y == 0) or not (offset_x == 0 or offset_y == 0 or absi(offset_x) == absi(offset_y)):
		gs._log("%s só pode usar o %s em linha reta (horizontal, vertical ou diagonal)." % [caster["name"], item["name"]])
		return false
	var target = gs.unit_at(tx, ty)
	var dx: int = gs._signi(tx - int(caster["x"]))
	var dy: int = gs._signi(ty - int(caster["y"]))
	var previous_tile := {"x": caster["x"], "y": caster["y"]}
	var landing := {"x": tx, "y": ty}
	if target != null or not gs._can_unit_anchor_at(caster, tx, ty):
		var near_side := {"x": tx - dx, "y": ty - dy}
		if (dx != 0 or dy != 0) and gs._can_unit_anchor_at(caster, near_side["x"], near_side["y"]):
			landing = near_side
		else:
			landing = gs._nearest_free_anchor(caster, tx, ty)
	if not gs._can_unit_anchor_at(caster, landing["x"], landing["y"]):
		gs._log("%s não encontra onde pousar o Chute do Dragão." % caster["name"])
		return false
	caster["x"] = landing["x"]
	caster["y"] = landing["y"]
	caster["hasMoved"] = true
	gs.separate_living_unit_from_corpse(caster, previous_tile, dy, -dx)
	gs.set_facing_towards(caster, target_tile)
	if target == null:
		gs._log("%s voa até (%d, %d) e o Chute do Dragão acerta o vazio." % [caster["name"], tx, ty])
		gs.finalize_action(caster, item)
		return true
	gs._log("%s voa até %s e desfere o Chute do Dragão!" % [caster["name"], target["name"]])
	gs.resolve_single_hit(caster, target, item)
	gs.finalize_action(caster, item)
	return true
