extends GutTest

var state: GameState
var bard: Dictionary

func before_each() -> void:
	state = GameState.new()
	bard = state.unit("bardo")
	bard["mp"] = 50
	bard["ct"] = 100

func _certain_song(key: String) -> Dictionary:
	var song: Dictionary = Spells.build()[key].duplicate(true)
	song["hitChance"] = 1.0
	return song

func test_bard_catalog_stats_weapon_passive_and_songs() -> void:
	assert_eq([bard["hp"], bard["maxHp"], bard["maxMp"], bard["speed"], bard["moveRange"]], [25,25,15,11,4])
	assert_eq(bard["innateEvasion"], state.unit("goblin")["innateEvasion"])
	var crossbow: Dictionary = bard["weapons"][0]
	assert_eq([crossbow["damageMin"],crossbow["damageMax"],crossbow["hitChance"],crossbow["critChance"],crossbow["ctCost"],crossbow["maxRange"]], [3,6,0.8,0.15,50,3])
	assert_true(crossbow["requiresClearPath"])
	assert_eq(bard["spells"].size(), 4)
	for song in bard["spells"]:
		assert_eq([song["mpCost"],song["ctCost"],song["applications"],song["hitChance"]], [10,50,3,0.8])

func test_song_heal_has_three_applications_and_independent_target_rolls() -> void:
	var ally_a := state.unit("guerreiro")
	var ally_b := state.unit("mago")
	ally_a["hp"] = 10; ally_a["mp"] = 0
	ally_b["hp"] = 10; ally_b["mp"] = 0
	var song := _certain_song("bardSongHeal")
	state.cast_bard_song(bard, song)
	assert_eq([ally_a["hp"],ally_b["hp"]], [13,13])
	assert_eq(bard["activeBardSong"]["applicationsLeft"], 2)
	state.global_turn_count += 1
	state.process_bard_song_turn_end(bard)
	state.global_turn_count += 1
	state.process_bard_song_turn_end(bard)
	assert_eq([ally_a["hp"],ally_b["hp"]], [19,19])
	assert_false(bard.has("activeBardSong"))
	assert_true(bard["bardSongCleanupPending"])

## Bug relatado pelo usuário: a canção era aplicada 2x no turno em que era
## conjurada (uma vez na hora de conjurar, outra vez no FIM daquele mesmo
## turno). A música precisa durar exatamente 3 turnos, 1 aplicação por turno:
## na conjuração, e no FIM de cada um dos 2 turnos seguintes do próprio Bardo
## (pedido do usuário: mudado do INÍCIO pro FIM do turno do Bardo — ver
## process_bard_song_turn_end/advance_to_next_turn). O guard de "castTurn"
## (global_turn_count no instante da conjuração) é o que impede reaplicar no
## MESMO turno da conjuração.
func test_song_applies_exactly_once_per_turn_not_twice_on_the_casting_turn() -> void:
	var ally := state.unit("guerreiro")
	ally["hp"] = 10
	var song := _certain_song("bardSongHeal")
	state.cast_bard_song(bard, song)
	assert_eq(ally["hp"], 13, "1ª aplicação: na hora de conjurar")
	# Fim do MESMO turno em que a música foi conjurada — não pode aplicar de novo.
	state.process_bard_song_turn_end(bard)
	assert_eq(ally["hp"], 13, "fim do turno de conjuração não aplica a música de novo")
	assert_eq(bard["activeBardSong"]["applicationsLeft"], 2, "as 2 aplicações restantes continuam intactas")
	# Fim do PRÓXIMO turno do próprio Bardo — aqui sim aplica.
	state.global_turn_count += 1
	state.process_bard_song_turn_end(bard)
	assert_eq(ally["hp"], 16, "2ª aplicação: fim do 2º turno do Bardo")
	assert_eq(bard["activeBardSong"]["applicationsLeft"], 1)
	state.global_turn_count += 1
	state.process_bard_song_turn_end(bard)
	assert_eq(ally["hp"], 19, "3ª e última aplicação: fim do 3º turno do Bardo")
	assert_false(bard.has("activeBardSong"), "música termina depois da 3ª aplicação, exatamente 3 turnos")

func test_each_target_roll_can_fail_without_consuming_extra_application() -> void:
	var ally := state.unit("guerreiro")
	ally["hp"] = 10
	var song := _certain_song("bardSongHeal")
	song["hitChance"] = 0.0
	state.cast_bard_song(bard, song)
	assert_eq(ally["hp"], 10)
	assert_eq(bard["activeBardSong"]["applicationsLeft"], 2)
	assert_true(state.bard_song_vfx_events.is_empty(), "falha individual não pode gerar notas")
	assert_true(state.bard_song_feedback_events.any(func(event): return event["targetName"] == ally["name"] and not event["success"]), "falha individual ganha apenas feedback visual próprio")

func test_song_visual_events_are_emitted_only_for_individual_successes() -> void:
	var ally := state.unit("guerreiro")
	var song := _certain_song("bardSongHeal")
	state.apply_bard_song_tick(bard, song)
	assert_true(state.bard_song_vfx_events.any(func(event): return event["targetName"] == ally["name"] and event["songKind"] == "heal"))
	state.bard_song_vfx_events.clear()
	song["hitChance"] = 0.0
	state.apply_bard_song_tick(bard, song)
	assert_true(state.bard_song_vfx_events.is_empty())
	assert_true(state.bard_song_feedback_events.any(func(event): return not event["success"]))

func test_inspiration_replaces_per_target_results_and_cleans_without_stacking() -> void:
	var ally := state.unit("guerreiro")
	var song := _certain_song("bardSongInspiration")
	state.cast_bard_song(bard, song)
	assert_eq(state.bard_inspiration_bonus(ally, "damageBonus"), 2)
	state.apply_bard_song_tick(bard, song)
	assert_eq(ally["statusEffects"].filter(func(e): return e.get("type","") == "bardInspiration").size(), 1)
	state.stop_bard_song(bard)
	assert_eq(state.bard_inspiration_bonus(ally, "damageBonus"), 0)

func test_switching_song_removes_inspiration_and_restarts_duration() -> void:
	var ally := state.unit("guerreiro")
	state.cast_bard_song(bard, _certain_song("bardSongInspiration"))
	bard["hasActed"] = false; bard["ct"] = 100; bard["mp"] = 50
	state.cast_bard_song(bard, _certain_song("bardSongDistraction"))
	assert_eq(state.bard_inspiration_bonus(ally, "damageBonus"), 0)
	assert_eq(bard["activeBardSong"]["item"]["songKind"], "distraction")
	assert_eq(bard["activeBardSong"]["applicationsLeft"], 2)

func test_distraction_and_pain_clamp_resources_and_use_normal_death_state() -> void:
	var enemy := state.unit("goblin")
	enemy["ct"] = 20; enemy["hp"] = 3; enemy["mp"] = 0
	state.apply_bard_song_tick(bard, _certain_song("bardSongDistraction"))
	assert_eq(enemy["ct"], 0)
	state.apply_bard_song_tick(bard, _certain_song("bardSongPain"))
	assert_eq([enemy["hp"],enemy["mp"]], [0,0])
	state.finalize_death_if_needed(enemy)
	assert_true(enemy.has("turnsSinceDeath"))

func test_crossbow_is_blocked_while_song_is_active_but_movement_remains_available() -> void:
	state.cast_bard_song(bard, _certain_song("bardSongPain"))
	assert_true(state.is_bard_singing(bard))
	assert_true(state.get_attack_options(bard).is_empty())
	bard["hasMoved"] = false
	var reachable := state.compute_reachable(bard)
	assert_false(reachable.is_empty())
	state.perform_move(bard, reachable[0])
	assert_true(bard["hasMoved"])
