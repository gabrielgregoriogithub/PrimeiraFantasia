class_name TemploLayout
extends RefCounted

## TEMPLO: mapa vertical 13x26 montado só com os recortes de
## assets/props/templo (ver ASSET_SOURCES.md). De baixo pra cima: entrada entre
## cercas e sebes -> caminho de pedras -> plataforma ritual central (o caminho
## abre em duas pistas ao redor dela) -> praça diante da fachada de ruínas com o
## arco do templo, e o santuário da árvore rúnica logo atrás. Ruínas, monólitos,
## árvores secas e floresta de pinheiros preenchem as laterais.
##
## O pacote não traz velas nem lanternas: a atmosfera sobrenatural vem do brilho
## das runas (árvore e plataforma), da névoa e das partículas do bioma.

const ID := "templo"
const WIDTH := 13
const HEIGHT := 26
const SEED := 20260919

const PATHS := [
	{"pts": [Vector2(6.5, 25.8), Vector2(6.5, 20.0), Vector2(6.3, 17.0), Vector2(6.5, 15.4)], "hw": 1.5, "wobble": 0.22},
	# Duas pistas ao redor da plataforma ritual; voltam a se juntar antes da fachada.
	{"pts": [Vector2(6.5, 15.4), Vector2(3.8, 13.8), Vector2(2.7, 11.2), Vector2(3.6, 9.0), Vector2(5.6, 8.0)], "hw": 1.0, "wobble": 0.2},
	{"pts": [Vector2(6.5, 15.4), Vector2(9.2, 13.8), Vector2(10.3, 11.2), Vector2(9.4, 9.0), Vector2(7.4, 8.0)], "hw": 1.0, "wobble": 0.2},
	{"pts": [Vector2(5.6, 8.0), Vector2(6.5, 7.2), Vector2(7.4, 8.0)], "hw": 1.0, "wobble": 0.15},
	{"pts": [Vector2(6.5, 7.8), Vector2(6.5, 4.4)], "hw": 1.5, "wobble": 0.2},
	# Ramais curtos até os terrenos de ruínas (2 casas de largura).
	{"pts": [Vector2(5.2, 19.0), Vector2(2.4, 18.4)], "hw": 0.95, "wobble": 0.25},
	{"pts": [Vector2(7.8, 18.0), Vector2(10.6, 17.6)], "hw": 0.95, "wobble": 0.25},
]

const PLAYER_SPAWNS := [
	{"x": 5, "y": 21}, {"x": 7, "y": 21}, {"x": 4, "y": 19},
	{"x": 8, "y": 19}, {"x": 5, "y": 18}, {"x": 7, "y": 17},
]
## Todos com 2x2 livres (Troll/Dragão/Salamandra/Goo grande) e sem footprint em comum.
const ENEMY_SPAWNS := [
	{"x": 2, "y": 6}, {"x": 5, "y": 6}, {"x": 8, "y": 6}, {"x": 10, "y": 6}, {"x": 6, "y": 4},
]

static func folder_name() -> String:
	return "templo"

static func catalog() -> Dictionary:
	var c := {}
	for i in range(1, 9):
		c["pine_%d" % i] = HauntedScenery.entry(1, 1, "prop", "y", true)
	for kind in ["oak", "dead_tree_1", "dead_tree_2", "rune_tree", "monolith_cross", "monolith_pillar", "monolith_shard",
			"monolith_tall", "standing_stone_1", "standing_stone_2"]:
		c[kind] = HauntedScenery.entry(1, 1, "prop", "y", true)
	c["hedge_block"] = HauntedScenery.entry(1, 1, "prop")
	c["stone_arch_curved"] = HauntedScenery.entry(1, 1, "prop")
	c["boulder_bush"] = HauntedScenery.entry(2, 1, "prop")
	c["cave_hill"] = HauntedScenery.entry(2, 1, "wall", "y", true)
	for kind in ["fence_1", "fence_2", "ruin_wall_1", "ruin_wall_2", "ruin_wall_3", "ruin_wall_5", "ruin_wall_6"]:
		c[kind] = HauntedScenery.entry(1, 1, "wall", "y", true)
	c["ruin_wall_4"] = HauntedScenery.entry(2, 1, "wall", "y", true)
	c["ruin_wall_large"] = HauntedScenery.entry(2, 1, "wall", "y", true)
	# Só visuais: sem colisão.
	c["stone_arch"] = HauntedScenery.entry(1, 1, "", "y", true)
	for kind in ["bush_1", "bush_2", "bush_3", "bush_berries", "bush_yellow_1", "bush_yellow_2", "bush_yellow_small",
			"fence_broken", "post_1", "post_2", "post_3", "post_4", "post_tall", "signpost", "stone_small", "stone_flat",
			"pebble_1", "pebble_2", "rock_flat", "rock_mossy", "rocks_pile", "stones_long", "stone_cube", "plank"]:
		c[kind] = HauntedScenery.entry(1, 1, "", "y")
	c["dead_branch"] = HauntedScenery.entry(1, 1, "", "flat")
	c["ritual_ring"] = HauntedScenery.entry(5, 3, "", "flat")
	c["pond"] = HauntedScenery.entry(5, 3, "", "flat")
	return c

static func definition() -> Dictionary:
	var s := HauntedScenery.new(WIDTH, HEIGHT, folder_name(), catalog(), SEED)
	var trail := HauntedScenery.trail_cells(WIDTH, HEIGHT, PATHS)
	s.keep_free(trail)
	s.keep_free_rect(2, 6, 10, 2)    # praça diante da fachada: 4 slots inimigos 2x2
	s.keep_free_rect(6, 4, 2, 2)     # 5º slot inimigo 2x2
	s.keep_free_rect(3, 17, 7, 5)    # clareira da entrada (spawns dos heróis)
	s.keep_free_rect(4, 12, 5, 3)    # plataforma ritual
	_build_platform(s)
	_build_facade(s)
	_build_ruin_plots(s)
	_build_entrance(s)
	_build_forest(s)
	_build_details(s)
	return {
		"id": ID, "name": "TEMPLO", "indoor": false,
		"board_width": WIDTH, "board_height": HEIGHT,
		"trail": trail, "scenery_props": s.props, "blocked_tiles": s.blocked_tiles(),
		"water": _pond_water(), "mist": _mist(), "decorations": [],
		"scenery_folder": folder_name(),
		"palette": {"grass": Color(0.60, 0.72, 0.66), "stone": Color(0.60, 0.65, 0.68), "gap": Color(0.20, 0.25, 0.22), "vignette": Color(0.01, 0.04, 0.05)},
		"player_spawns": PLAYER_SPAWNS, "enemy_spawns": ENEMY_SPAWNS,
		"music": "res://assets/third_party/shattered_pixel_dungeon/music/prison_1.ogg", "step_sfx": "grassStep",
	}

## Plataforma ritual (ponto central) e as pedras que a rodeiam.
static func _build_platform(s: HauntedScenery) -> void:
	s.place("ritual_ring", 4, 12, {"flip": false})
	s.place("monolith_tall", 3, 11)
	s.place("standing_stone_2", 9, 11)
	s.place("stone_arch_curved", 3, 14)
	s.place("rocks_pile", 9, 14)
	s.place("dead_tree_2", 1, 12)
	s.place("dead_tree_1", 11, 12)
	s.place("bush_yellow_1", 3, 13)
	s.place("bush_yellow_2", 9, 13)

## Fachada do templo: arco monumental entre muros em ruína, com o santuário da
## árvore rúnica logo atrás (a árvore aparece emoldurada pelo arco).
static func _build_facade(s: HauntedScenery) -> void:
	s.place("rune_tree", 6, 2, {"scale": 1.3, "flip": false})
	s.place("stone_arch", 6, 3, {"scale": 1.9, "flip": false})
	s.place("ruin_wall_large", 3, 3, {"scale": 1.3, "flip": false})
	s.place("ruin_wall_large", 8, 3, {"scale": 1.3, "flip": true})
	s.place("ruin_wall_4", 1, 3, {"scale": 1.2})
	s.place("ruin_wall_4", 10, 3, {"scale": 1.2})
	s.place("monolith_cross", 0, 3)
	s.place("monolith_pillar", 12, 3)
	s.place("standing_stone_1", 4, 2, {"scale": 1.2})
	s.place("standing_stone_2", 8, 2, {"scale": 1.2})
	s.place("ruin_wall_3", 3, 1, {"scale": 1.3})
	s.place("ruin_wall_6", 9, 1, {"scale": 1.3})
	s.place("cave_hill", 0, 1, {"scale": 1.3})
	s.place("boulder_bush", 11, 1, {"scale": 1.2})
	s.place("monolith_shard", 3, 4)
	s.place("monolith_shard", 9, 4)
	s.place("bush_yellow_2", 5, 1)
	s.place("bush_1", 7, 1)

## Terrenos de ruínas nas laterais (como na referência): muros baixos, sebe, pedras.
static func _build_ruin_plots(s: HauntedScenery) -> void:
	# Oeste
	s.place("ruin_wall_2", 1, 9, {"scale": 1.2})
	s.place("ruin_wall_1", 0, 10)
	s.place("ruin_wall_5", 1, 11)
	s.place("monolith_cross", 0, 8)
	s.place("hedge_block", 0, 16)
	s.place("ruin_wall_3", 2, 16, {"scale": 1.2})
	s.place("ruin_wall_6", 0, 14)
	s.place("standing_stone_1", 1, 14)
	# Leste
	s.place("ruin_wall_1", 11, 9)
	s.place("ruin_wall_2", 12, 10, {"scale": 1.2})
	s.place("monolith_pillar", 11, 8)
	s.place("ruin_wall_5", 12, 14)
	s.place("ruin_wall_3", 10, 15, {"scale": 1.2})
	s.place("hedge_block", 12, 16)
	s.place("ruin_wall_4", 10, 13)
	s.place("standing_stone_2", 11, 14)

## Entrada: lagoa à esquerda, cercas e sebes nas laterais e o caminho aberto.
static func _build_entrance(s: HauntedScenery) -> void:
	s.place("pond", 0, 21)
	for x in [1, 3]:
		s.place("fence_1", x, 19)
	for x in [9, 11]:
		s.place("fence_2", x, 19)
	s.place("fence_broken", 2, 19)
	s.place("fence_broken", 10, 19)
	s.place("ruin_wall_large", 9, 22, {"scale": 1.2})
	s.place("hedge_block", 11, 18)
	s.place("signpost", 5, 22)
	s.place("boulder_bush", 10, 23)
	s.place("post_1", 4, 21)
	s.place("post_tall", 8, 21)

## Floresta de pinheiros: bordas esquerda/direita e o fundo do mapa.
static func _build_forest(s: HauntedScenery) -> void:
	var pines := ["pine_1", "pine_2", "pine_3", "pine_4", "pine_5", "pine_6", "pine_7", "pine_8"]
	s.row(pines, 0, 0, 13, 0, 2)
	s.row(pines, 12, 0, 13, 0, 2)
	s.row(pines + ["oak"], 1, 1, 12, 0, 2)
	s.row(pines + ["oak"], 11, 1, 12, 0, 2)
	s.row(pines, 0, 25, 13, 1, 0)
	s.row(pines, 2, 0, 9, 1, 0)
	s.scatter(pines + ["dead_tree_1", "dead_tree_2", "oak"], Rect2i(0, 5, 3, 20), 8)
	s.scatter(pines + ["dead_tree_1", "dead_tree_2", "oak"], Rect2i(10, 5, 3, 20), 8)

## Arbustos, pedras, postes e galhos que quebram a simetria (nenhum bloqueia).
static func _build_details(s: HauntedScenery) -> void:
	s.scatter(["bush_1", "bush_2", "bush_3", "bush_berries", "bush_yellow_1", "bush_yellow_2", "bush_yellow_small"], Rect2i(0, 5, 13, 19), 22)
	s.scatter(["stone_small", "stone_flat", "pebble_1", "pebble_2", "rock_flat", "rock_mossy", "rocks_pile", "stones_long", "stone_cube"], Rect2i(0, 5, 13, 19), 20)
	s.scatter(["post_2", "post_3", "post_4", "plank", "fence_broken"], Rect2i(0, 8, 13, 12), 6)
	s.scatter(["dead_branch"], Rect2i(0, 5, 13, 19), 6, {"layer": "flat"})

static func _pond_water() -> Array:
	var cells: Array = []
	for y in [22, 23]:
		for x in [1, 2, 3]:
			cells.append({"x": x, "y": y})
	return cells

static func _mist() -> Array:
	return [
		{"x": 1.0, "y": 8.0, "w": 5.0, "h": 2.4, "alpha": 0.26}, {"x": 7.5, "y": 10.5, "w": 5.0, "h": 2.4, "alpha": 0.22},
		{"x": 0.0, "y": 19.0, "w": 6.0, "h": 2.6, "alpha": 0.28}, {"x": 7.0, "y": 21.0, "w": 6.0, "h": 2.6, "alpha": 0.25},
		{"x": 3.0, "y": 0.5, "w": 7.0, "h": 2.4, "alpha": 0.24}, {"x": 2.0, "y": 14.5, "w": 4.0, "h": 2.0, "alpha": 0.18},
	]
