extends GutTest

## Seleção de inimigos do PVP agrupada por categoria (pedido do usuário).
## Instancia PvpSetup de verdade (headless, sem clique de mouse real —
## mesmo espírito de test_main_scene.gd) e chama os métodos de clique
## diretamente.

var setup: PvpSetup

func before_each() -> void:
	setup = PvpSetup.new()
	add_child_autofree(setup)
	setup.begin(["guerreiro", "arqueiro", "mago", "ladino", "quimico"])

func _group_card_count() -> int:
	return setup._grid.get_child_count()

func test_begin_opens_the_groups_screen_with_exactly_4_category_cards() -> void:
	assert_eq(setup._step, "groups")
	assert_eq(_group_card_count(), 4, "só as 4 categorias, não os ~15 monstros de uma vez")

func test_goblinoides_group_shows_exactly_its_8_monsters() -> void:
	setup._open_monster_group("goblinoides")
	assert_eq(setup._step, "monsters")
	assert_eq(setup._card_buttons.keys(), ["orc", "troll", "fada", "xama", "goblin", "kobold", "troncus", "lobo"])

func test_criaturas_group_shows_exactly_its_5_monsters() -> void:
	setup._open_monster_group("criaturas")
	assert_eq(setup._card_buttons.keys(), ["rat", "snake", "gnoll", "goo", "slime"])

func test_undead_group_shows_exactly_its_5_monsters() -> void:
	setup._open_monster_group("undead")
	assert_eq(setup._card_buttons.keys(), ["vampire", "lich", "skeleton", "zombie", "ghost"])

func test_fire_group_shows_exactly_its_5_monsters() -> void:
	setup._open_monster_group("fire")
	assert_eq(setup._card_buttons.keys(), ["living_fire", "lava_human", "salamander", "dragon", "flame_demon"])

## Pedido do usuário: as fichas de "criaturas/mortos-vivos/elementais do
## fogo" mostram só 1 exemplar por vez — o índice "1" que
## dungeon_monster_data/lua_monster_data sempre numeram não deve aparecer
## na seleção (mas o spawn real ainda numera cada cópia normalmente).
func test_monster_names_in_the_selection_screen_drop_the_index_1_suffix() -> void:
	for entry in [["undead", "vampire", "Vampiro"], ["undead", "lich", "Lich"], ["fire", "dragon", "Dragão Vermelho"], ["fire", "flame_demon", "Demônio das Chamas"], ["criaturas", "snake", "Cobra"]]:
		var monster: Dictionary = setup._monster_template(entry[1])
		assert_eq(monster["name"], entry[2], "%s não deve exibir sufixo de índice" % entry[1])
	# O nome real usado ao spawnar de verdade continua numerado.
	assert_eq(GameState.dungeon_monster_data("vampire")["name"], "Vampiro 1")

func test_group_covers_point_to_the_real_files_in_assets_enemies_capas() -> void:
	assert_eq(setup.MONSTER_GROUP_COVER_FILE["goblinoides"], "globinoides.png")
	assert_eq(setup.MONSTER_GROUP_COVER_FILE["criaturas"], "criaturas.png")
	assert_eq(setup.MONSTER_GROUP_COVER_FILE["undead"], "mortos-vivos.png")
	assert_eq(setup.MONSTER_GROUP_COVER_FILE["fire"], "elementais do fogo.png")
	for key in setup.MONSTER_GROUP_COVER_FILE:
		var path := "res://assets/enemies/capas/%s" % setup.MONSTER_GROUP_COVER_FILE[key]
		assert_true(ResourceLoader.exists(path), "capa de %s existe de verdade" % key)

func test_clicking_a_group_cover_does_not_select_any_monster() -> void:
	setup._open_monster_group("undead")
	assert_eq(setup._selected_monsters.size(), 0, "abrir a categoria não seleciona ninguém sozinho")

func test_selection_persists_across_groups_matching_the_user_example_scenario() -> void:
	setup._open_monster_group("undead")
	setup._toggle_monster("vampire")
	setup._toggle_monster("lich")
	setup._on_back_pressed() # "Voltar aos grupos"
	assert_eq(setup._step, "groups")
	assert_eq(setup._selected_monsters, ["vampire", "lich"], "voltar aos grupos não apaga a seleção")

	setup._open_monster_group("fire")
	setup._toggle_monster("dragon")
	setup._toggle_monster("flame_demon")
	setup._on_back_pressed()

	setup._open_monster_group("criaturas")
	setup._toggle_monster("gnoll")

	assert_eq(setup._selected_monsters, ["vampire", "lich", "dragon", "flame_demon", "gnoll"])
	assert_eq(setup._selected_monsters.size(), 5)

func test_cannot_select_a_6th_monster_once_5_are_chosen() -> void:
	setup._open_monster_group("undead")
	for key in ["vampire", "lich", "skeleton", "zombie", "ghost"]:
		setup._toggle_monster(key)
	assert_eq(setup._selected_monsters.size(), 5)
	setup._open_monster_group("fire")
	setup._toggle_monster("dragon")
	assert_eq(setup._selected_monsters.size(), 5, "6º monstro é recusado")
	assert_false(setup._selected_monsters.has("dragon"))

func test_removing_one_of_5_allows_choosing_another() -> void:
	setup._open_monster_group("undead")
	for key in ["vampire", "lich", "skeleton", "zombie", "ghost"]:
		setup._toggle_monster(key)
	setup._toggle_monster("vampire") # clicar de novo remove
	assert_eq(setup._selected_monsters.size(), 4)
	setup._toggle_monster("vampire")
	assert_eq(setup._selected_monsters.size(), 5)

func test_confirm_button_only_enabled_at_exactly_5() -> void:
	setup._open_monster_group("undead")
	assert_true(setup._confirm_button.disabled, "0/5 desativado")
	setup._toggle_monster("vampire")
	assert_true(setup._confirm_button.disabled, "1/5 desativado")
	for key in ["lich", "skeleton", "zombie"]:
		setup._toggle_monster(key)
	assert_true(setup._confirm_button.disabled, "4/5 desativado")
	setup._toggle_monster("ghost")
	assert_false(setup._confirm_button.disabled, "5/5 ativado")

func test_confirm_from_the_groups_screen_advances_to_scenario_step_once_5_are_chosen() -> void:
	setup._open_monster_group("undead")
	for key in ["vampire", "lich", "skeleton", "zombie", "ghost"]:
		setup._toggle_monster(key)
	setup._on_back_pressed() # volta pra tela de grupos com 5/5 já escolhidos
	assert_eq(setup._step, "groups")
	setup._on_confirm_pressed()
	assert_eq(setup._step, "scenario", "confirmar direto da tela de grupos também funciona com 5/5")
