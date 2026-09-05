extends GutTest

## Correções pedidas pelo usuário depois de jogar o Campo:
## 1) A Fada usava Ventania contra os próprios aliados.
## 2) Inimigos atacavam a Maga presa mesmo ela sendo imune a dano.
## Ambos são bugs de DECISÃO da IA (game_state.gd), não visuais — cobertos
## aqui em nível de regra, sem cena/token nenhum.

var state: GameState

func before_each() -> void:
	state = GameState.new()
	state.clear_units()
	state.clear_terrain_and_structures()

# --- Ventania nunca acerta aliado ------------------------------------------

## Reproduz o caminho que estava com bug: enemy_act só chegava a considerar
## Ventania pelo segundo despacho genérico (pick_best_cone_direction, sem
## checar aliado) quando o primeiro bloco específico da Fada (que já exigia
## 2+ heróis numa direção "limpa") não se qualificava — aqui só existe UM
## herói, então o primeiro bloco nunca dispara e o teste exercita
## exatamente o trecho corrigido.
func test_windstorm_never_hits_an_ally_blocking_the_only_reachable_hero() -> void:
	var windstorm: Dictionary = Spells.build()["windstorm"]
	var caster := state.spawn_unit("caster", {"x": 5, "y": 5, "team": "enemy", "mp": 20, "maxMp": 20, "spells": [windstorm]})
	var ally := state.spawn_unit("ally", {"x": 6, "y": 5, "team": "enemy", "hp": 40, "maxHp": 40})
	var hero := state.spawn_unit("hero", {"x": 8, "y": 5, "team": "player", "hp": 30, "maxHp": 30})
	var ally_hp_before: int = ally["hp"]
	var ally_status_before: Array = (ally["statusEffects"] as Array).duplicate(true)
	var hero_hp_before: int = hero["hp"]
	state.current_actor = caster
	state.enemy_act(caster)
	# CT não entra na comparação: o próprio avanço de turno (advance_to_next_
	# turn, chamado no fim de enemy_act independente do que a Ventania fez)
	# já muda o CT de todo mundo — não é sinal de dano/efeito de Ventania.
	assert_eq(ally["hp"], ally_hp_before, "Ventania não pode ferir o próprio aliado no caminho")
	assert_eq(ally["x"], 6, "Ventania não pode empurrar o próprio aliado")
	assert_eq(ally["statusEffects"], ally_status_before, "Ventania não pode aplicar status no próprio aliado")
	# Sem direção seguramente livre de aliados, a Ventania simplesmente não
	# deveria disparar — o herói (único alvo de verdade) fica intocado.
	assert_eq(hero["hp"], hero_hp_before)

func test_windstorm_still_fires_when_a_direction_is_actually_clear() -> void:
	# hitChance forçado em 1.0 pra não depender de RNG (windstorm tem 80% de
	# acerto no catálogo real; sem isso o teste seria flaky ~1 em 5 rodadas).
	var windstorm: Dictionary = Spells.build()["windstorm"].duplicate(true)
	windstorm["hitChance"] = 1.0
	var caster := state.spawn_unit("caster", {"x": 5, "y": 5, "team": "enemy", "mp": 20, "maxMp": 20, "spells": [windstorm]})
	# Aliado fora da linha de tiro (norte), herói na única direção limpa (leste).
	var ally := state.spawn_unit("ally", {"x": 5, "y": 2, "team": "enemy", "hp": 40, "maxHp": 40})
	var hero := state.spawn_unit("hero", {"x": 7, "y": 5, "team": "player", "hp": 30, "maxHp": 30})
	state.current_actor = caster
	state.enemy_act(caster)
	assert_true(hero["hp"] < 30 or hero["x"] != 7, "com direção realmente limpa, a Ventania ainda deve funcionar")

# --- IA ignora unidades presas (imunes a dano) ------------------------------

func test_pick_nearest_target_skips_a_caged_unit_and_picks_a_real_target() -> void:
	var goblin := state.spawn_unit("goblin", {"x": 0, "y": 0, "team": "enemy"})
	state.spawn_unit("maga_presa", {"x": 1, "y": 0, "team": "player", "hp": 20, "maxHp": 20, "caged": true})
	var real_hero := state.spawn_unit("heroi_de_verdade", {"x": 6, "y": 0, "team": "player", "hp": 20, "maxHp": 20})
	var picked = state.pick_nearest_target(goblin)
	assert_eq(picked["name"], real_hero["name"], "IA deve ignorar quem está preso (imune) e mirar em alguém que pode ser ferido")

func test_pick_nearest_target_returns_null_when_only_caged_units_remain() -> void:
	var goblin := state.spawn_unit("goblin", {"x": 0, "y": 0, "team": "enemy"})
	state.spawn_unit("maga_presa", {"x": 1, "y": 0, "team": "player", "hp": 20, "maxHp": 20, "caged": true})
	assert_null(state.pick_nearest_target(goblin))

func test_enemy_act_does_not_walk_the_whole_turn_toward_a_caged_unit() -> void:
	var goblin := state.spawn_unit("goblin", {"x": 0, "y": 0, "team": "enemy", "moveRange": 4})
	state.spawn_unit("maga_presa", {"x": 1, "y": 0, "team": "player", "hp": 20, "maxHp": 20, "caged": true})
	var hero := state.spawn_unit("heroi_de_verdade", {"x": 3, "y": 0, "team": "player", "hp": 20, "maxHp": 20})
	state.current_actor = goblin
	state.enemy_act(goblin)
	assert_lt(manhattan(goblin, hero), manhattan(goblin, {"x": 1, "y": 0}), "goblin avança pro herói de verdade, não pra prisioneira imune")

func manhattan(a: Dictionary, b: Dictionary) -> int:
	return absi(int(a["x"]) - int(b["x"])) + absi(int(a["y"]) - int(b["y"]))
