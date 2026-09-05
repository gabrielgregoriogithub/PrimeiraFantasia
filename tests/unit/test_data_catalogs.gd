extends GutTest

## Fase 1: valida a tradução literal dos catálogos de dados (Weapons, Spells,
## Units, BoardLayout) contra os números conhecidos de game.js no protótipo
## JS original. Contagens e valores pontuais — não é regra de gameplay ainda
## (isso é Fase 2), só garante que a tradução JS -> GDScript não perdeu nem
## alterou nenhum campo.

func test_weapons_catalog_matches_source_count_and_values() -> void:
	var weapons := Weapons.build()
	assert_eq(weapons.size(), 27, "catálogo inclui a Besta própria do Bardo, Garra/Raio de Fogo (Demônio das Chamas), Toque Vampírico/Mordida (Vampiro), Garra/Cauda (Dragão Vermelho) e Raio de Decaimento (Lich)")

	var sword: Dictionary = weapons["sword"]
	assert_eq(sword["damageMin"], 8)
	assert_eq(sword["damageMax"], 10)
	assert_eq(sword["ctCost"], 50)

	var short_sword: Dictionary = weapons["shortSword"]
	var poison: Dictionary = short_sword["appliesPoison"]
	assert_eq(poison["damageMin"], 1)
	assert_eq(poison["damageMax"], 3)
	assert_eq(poison["turns"], 1)
	assert_eq(poison["ctDrainPerTurn"], 10)

	var dirk: Dictionary = weapons["dirk"]
	var crit_by_angle: Dictionary = dirk["critChanceByAngle"]
	assert_eq(crit_by_angle["back"], 0.25)

func test_spells_catalog_matches_source_count_and_values() -> void:
	var spells := Spells.build()
	assert_eq(spells.size(), 47, "catálogo inclui a Bomba de Gelo do Químico, o Cone de Gelo do Mago e a Flecha de Gelo do Arqueiro")

	var fireball: Dictionary = spells["fireball"]
	assert_eq(fireball["damageMax"], 12)
	assert_eq(fireball["mpCost"], 10)
	var burn: Dictionary = fireball["appliesBurn"]
	assert_eq(burn["turns"], 3)
	assert_eq(burn["damageMin"], 1)
	assert_eq(burn["damageMax"], 1)

	var poison_cone: Dictionary = spells["poisonCone"]
	assert_eq(poison_cone["damageMin"], 1)
	assert_eq(poison_cone["damageMax"], 3)
	assert_eq(poison_cone["turns"], 3)
	assert_eq(poison_cone["mpCost"], 6)

	var quick_shot: Dictionary = spells["quickShot"]
	var restricted_weapon: Dictionary = quick_shot["restrictBonusToWeapon"]
	assert_eq(restricted_weapon["name"], "Arco")
	assert_eq(spells["trueShot"]["mpCost"], 1, "Tiro Certeiro custa apenas 1 MP")

	var lightning: Dictionary = spells["lightning"]
	assert_eq(lightning["maxRange"], GameConstants.BOARD_SIZE - 1)

func test_units_catalog_matches_source_rosters() -> void:
	var units := Units.build()
	assert_eq(units.size(), 11, "elenco inclui o novo Bardo")

	var guerreiro: Dictionary = units["guerreiro"]
	assert_eq(guerreiro["hp"], 35)
	assert_eq(guerreiro["team"], "player")
	assert_eq((guerreiro["weapons"] as Array).size(), 2)
	assert_eq((guerreiro["spells"] as Array).size(), 4)

	var fada: Dictionary = units["fada"]
	assert_true(fada["flying"])

	var quimico: Dictionary = units["quimico"]
	assert_eq((quimico["spells"] as Array).size(), 8, "inclui a Bomba de Gelo")

	assert_eq(Units.player_team_keys(), ["guerreiro", "arqueiro", "mago", "ladino", "quimico", "bardo"])
	assert_eq(Units.enemy_team_keys(), ["goblin", "orc", "xama", "fada", "troll"])

## Pedido do usuário: a Cura do Químico tem a mesma área de efeito da
## Regeneração em Área (mesmo areaRadius/alcance), em vez de alvo único.
func test_chemist_heal_has_same_area_of_effect_as_regen() -> void:
	var spells := Spells.build()
	var heal: Dictionary = spells["healPotion"]
	var regen: Dictionary = spells["regenAoeAlchemist"]
	assert_eq(heal["targetMode"], "heal-aoe")
	assert_eq(heal["areaRadius"], regen["areaRadius"])
	assert_eq(heal["minRange"], regen["minRange"])
	assert_eq(heal["maxRange"], regen["maxRange"])

func test_board_layout_tile_counts_match_source() -> void:
	var water: Array = BoardLayout.TERRAIN_LAYOUT["water"]
	assert_eq(water.size(), 19)
	var trees: Array = BoardLayout.TERRAIN_LAYOUT["tree"]
	assert_eq(trees.size(), 20)
	assert_eq(BoardLayout.STRUCTURES_LAYOUT.size(), 2)
	assert_eq((BoardLayout.STRUCTURES_LAYOUT[0]["tiles"] as Array).size(), 9)

func test_animal_sprite_catalog_has_all_required_states_inside_each_sheet() -> void:
	var catalog := AnimalSpriteCatalog.build()
	assert_eq(catalog.keys(), ["spd_rat", "spd_snake", "spd_gnoll", "spd_slime", "spd_goo", "tower_zombie", "tower_ghost", "tower_skeleton", "tower_lava_human", "tower_living_fire", "flame_demon", "vampire", "vampire_bat", "lich", "dragon", "tower_salamander", "bardo", "arqueiro", "mago", "quimico", "troll", "xama", "orc", "goblin"])
	var spd_keys := ["spd_rat", "spd_snake", "spd_gnoll", "spd_slime", "spd_goo"]
	for sprite_key: String in spd_keys:
		var spec: Dictionary = catalog[sprite_key]
		var texture := load(AnimalSpriteCatalog.SHEET_ROOT + str(spec["sheet"])) as Texture2D
		assert_not_null(texture, "%s carrega sua folha nova" % sprite_key)
		var anims: Dictionary = spec["anims"]
		for required_action: String in ["idle_down", "walk_down", "attack", "hit", "death"]:
			assert_true(anims.has(required_action), "%s possui %s" % [sprite_key, required_action])
			assert_gt((anims[required_action][0] as Array).size(), 0)
		for animation_key: String in anims:
			if animation_key == "contact":
				continue
			for raw_rect: Array in anims[animation_key][0]:
				var rect := Rect2i(raw_rect[0], raw_rect[1], raw_rect[2], raw_rect[3])
				assert_true(rect.position.x >= 0 and rect.position.y >= 0)
				assert_true(rect.end.x <= texture.get_width() and rect.end.y <= texture.get_height(),
					"%s/%s permanece dentro de %dx%d" % [sprite_key, animation_key, texture.get_width(), texture.get_height()])

func test_tower_animal_sprite_catalog_frame_files_all_exist() -> void:
	# Humanoides da Torre (tower_*) vieram como PNG por quadro em pasta
	# própria (não uma folha única), então aqui validamos que cada caminho
	# referenciado realmente existe em vez de checar limites de região.
	var catalog := AnimalSpriteCatalog.build()
	for sprite_key: String in ["tower_zombie", "tower_ghost", "tower_skeleton", "tower_lava_human", "tower_living_fire", "tower_salamander", "flame_demon", "vampire", "vampire_bat", "lich", "dragon"]:
		var spec: Dictionary = catalog[sprite_key]
		assert_true(ResourceLoader.exists(spec["portrait"]), "%s carrega seu retrato" % sprite_key)
		var anims: Dictionary = spec["anims"]
		for required_action: String in ["idle_down", "walk_down", "attack", "hit"]:
			assert_true(anims.has(required_action), "%s possui %s" % [sprite_key, required_action])
			assert_gt((anims[required_action][0] as Array).size(), 0)
		for animation_key: String in anims:
			for frame_path: String in anims[animation_key][0]:
				assert_true(ResourceLoader.exists(frame_path), "%s/%s/%s existe" % [sprite_key, animation_key, frame_path])

func test_processed_slime_and_goo_have_transparent_canvas_corners() -> void:
	for file_name: String in ["slime.png", "goo.png"]:
		var texture := load(AnimalSpriteCatalog.SHEET_ROOT + file_name) as Texture2D
		var image := texture.get_image()
		assert_false(image.is_empty())
		for point: Vector2i in [Vector2i.ZERO, Vector2i(image.get_width() - 1, 0), Vector2i(0, image.get_height() - 1), Vector2i(image.get_width() - 1, image.get_height() - 1)]:
			assert_eq(image.get_pixelv(point).a, 0.0, "%s sem fundo no canto %s" % [file_name, point])
