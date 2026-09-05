extends GutTest

## Bug relatado pelo usuário: bardo_unlocked (Main, persistido em
## user://campaign_progress.cfg pra continuar liberado nos andares
## SEGUINTES depois de libertado) vazava pro 2º andar em si — entrar nele
## de novo (clique direto no botão, ou reinício) mostrava o Bardo já solto,
## como se a Maga aparecesse solta ao entrar no Campo.

func test_entering_floor_2_directly_always_shows_the_bard_caged_even_if_a_previous_run_unlocked_him() -> void:
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main_scene)
	await wait_process_frames(1)
	# Simula o cenário do bug: uma partida anterior (ou o config salvo em
	# disco) já tinha libertado o Bardo antes deste clique.
	main_scene.bardo_unlocked = true
	main_scene._switch_scenario(ScenarioManager.TOWER_FLOOR_2)
	await wait_seconds(0.5) # fade de saída (0.20s) + entrada (0.24s) do _switch_scenario
	assert_eq(main_scene.scenario_manager.active_id, ScenarioManager.TOWER_FLOOR_2)
	var bard: Dictionary = main_scene.state.unit("bardo")
	assert_true(bard.get("caged", false), "2º andar precisa sempre recomeçar com o Bardo preso, igual a Maga sempre presa no Campo")
	assert_false(main_scene.bardo_unlocked, "a flag de campanha também é resetada, não só o estado da unidade")

## Bug relatado pelo usuário logo depois da correção acima: sem o Bardo
## desbloqueado, só 5 dos 6 heróis ficam disponíveis — e como o limite de
## seleção também é 5, a tela "escolha 5 de 6" nunca aparecia (5 não é
## maior que 5). Acessar o 3º/4º andar direto precisa pressupor que o 2º
## andar já foi concluído (Bardo já resgatado), simétrico ao reset do teste
## acima.
func test_entering_floor_3_directly_always_offers_all_six_heroes_for_party_selection() -> void:
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main_scene)
	await wait_process_frames(1)
	main_scene.bardo_unlocked = false
	main_scene._switch_scenario(ScenarioManager.TOWER_FLOOR_3)
	await wait_seconds(0.3) # só o fade de saída roda; _show_party_selection interrompe antes do fade de entrada
	assert_true(main_scene.bardo_unlocked, "3º andar direto pressupõe que o Bardo já foi resgatado no 2º")
	assert_true(main_scene._party_selection_panel.visible, "com 6 heróis disponíveis, a escolha de 5 precisa aparecer")
	assert_eq(main_scene._party_card_buttons.size(), 6)

func test_entering_floor_4_directly_also_offers_all_six_heroes() -> void:
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	add_child_autofree(main_scene)
	await wait_process_frames(1)
	main_scene.bardo_unlocked = false
	main_scene._switch_scenario(ScenarioManager.TOWER_FLOOR_4)
	await wait_seconds(0.3)
	assert_true(main_scene.bardo_unlocked)
	assert_true(main_scene._party_selection_panel.visible)
