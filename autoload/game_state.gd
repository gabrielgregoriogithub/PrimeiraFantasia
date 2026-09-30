class_name GameState
extends RefCounted

## Estado de UMA partida (equivalente ao estado de módulo de game.js:
## `units`, `terrainMap`, `structures`, `elevationMap`, `traps`, `souls`,
## `turnToken`, etc). Instanciável (`GameState.new()`), não um singleton
## autoload de verdade — cada teste GUT cria o seu próprio, isolado, do
## mesmo jeito que `resetGame()` reconstruía tudo do zero no JS. A cena
## jogável (Fase 5/6) decide se quer expor UMA instância como autoload.
##
## Nomes de campo dos dicionários de unidade preservados de game.js: team,
## x, y, hp, maxHp, moveRange, speed, ct, mp, statusEffects, facing,
## spriteKey, weapons, spells (ver AGENTS.md do protótipo).

var units: Array = []
var units_by_key: Dictionary = {}
var terrain_map: Dictionary = {}
## Campo/Torre continuam 13x13 (GameConstants.BOARD_SIZE, default aqui). A
## Horda agora usa o recorte real 26x22 do Legend of Lua — bem maior que a
## janela de 13x13 tiles mostrada em tela, por isso board_view.gd ganhou uma
## Camera2D fixa nesse enquadramento (ver _lua_valley_definition() em
## scenario_manager.gd, que preenche "board_width"/"board_height" no
## dicionário lido por apply_scenario).
var board_width: int = GameConstants.BOARD_SIZE
var board_height: int = GameConstants.BOARD_SIZE
var structures: Array = []
var elevation_map: Dictionary = {}
var traps: Array = []
var souls: Array = []
## Rato/Cobra/Gnoll/Slime/Slime Negro não deixam cadáver ressuscitável: a
## morte já vira alma na hora, sem a janela de 3 rodadas, e essa alma cura
## menos que a alma "normal" (5 HP / 2 MP em vez de 10 HP / 5 MP).
const IMMEDIATE_SOUL_SPRITE_KEYS := ["spd_rat", "spd_snake", "spd_gnoll", "spd_slime", "spd_goo"]
## Armas básicas que recebem o preparo de Golpe Baixo/Poção Venenosa/Areia
## nos Olhos, por spriteKey de quem ataca.
const GOBLIN_TRICK_WEAPONS := {"goblin": ["Adaga", "Funda"], "kobold": ["Adaga Envenenada", "Lança"]}
const IMMEDIATE_SOUL_HP := 5
const IMMEDIATE_SOUL_MP := 2
var last_reachable_came_from: Dictionary = {}
var last_reachable_costs: Dictionary = {}
var turn_token: int = 0
var battle_ended: bool = false
## Quem venceu quando battle_ended vira true (ver check_battle_outcome/
## check_global_turn_limit) — só significativo depois de battle_ended==true.
## main.gd lê ISSO em vez de procurar "Vitória"/"Derrota" no último log:
## finalize_death_if_needed pode logar "se desfaz numa alma" (bichos SPD da
## Torre/Horda, ver IMMEDIATE_SOUL_SPRITE_KEYS) DEPOIS da mensagem de
## resultado, dentro do mesmo _sync_visuals() — ler só a última linha do log
## detectava derrota por engano toda vez que o kill decisivo era um desses
## bichos (praticamente sempre na Horda).
var battle_won: bool = false
var global_turn_count: int = 0
var current_actor: Variant = null
## Emula um Set (nomes de unidade) — game.js usa um `Set<unit>` de verdade;
## aqui comparação por nome, mesmo motivo de structure_occupant.
var round_acted_units: Array = []
var scenario_id := ScenarioManager.FIELD
var tower_pickups: Array = []
var tower_spawn_count := 0
var village_archer_spawned := false
var village_goblin_spawned := false
var forest_chemist_spawned := false
var forest_shaman_spawned := false
## DESFILADEIRO (ver maybe_trigger_desfiladeiro_wind): último global_turn_count
## em que o vento gelado já disparou (evita disparo duplo no mesmo turno,
## mesmo padrão de village_archer_spawned/village_goblin_spawned acima) e a
## fila de eventos que a camada visual (main.gd:_sync_visuals) drena pra
## mostrar a pausa/rajada — mesmo mecanismo de bone_explosion_events/
## bard_song_vfx_events logo abaixo.
var desfiladeiro_wind_last_turn: int = -1
var desfiladeiro_wind_events: Array = []
## Preenchido por _release_caged_mage() a cada libertação da Maga (ver
## _setup_caged_mage/_check_cage_release); main.gd lê e limpa a cada
## _sync_visuals() pra disparar popup/som/refresh sem acoplar UI ao estado.
var cage_release_events: Array = []
var bone_explosion_events: Array = []
## Um evento por alvo que passou no teste individual de uma Canção. A camada
## visual consome esta fila sem refazer o sorteio de 80%.
var bard_song_vfx_events: Array = []
## Uivo de Caça (Lobo): um evento por uso, com quem uivou e quem recebeu o
## bônus — a camada visual (main.gd:_sync_visuals) toca o uivo e as ondas.
var hunt_howl_events: Array = []
## Canal somente visual: inclui sucesso e falha individual sem alterar o
## canal legado, que continua contendo exclusivamente aplicações bem-sucedidas.
var bard_song_feedback_events: Array = []
var last_action_vfx: Dictionary = {}
var campaign_bardo_unlocked := false
var selected_party_keys: Array = []
## true durante uma batalha do Modo PVP (roster de heróis/monstros escolhido
## livremente pelo jogador, ver apply_pvp_scenario) — suspende os gatilhos de
## reforço/spawn roteirizados de cada cenário (Arqueiro/Goblin da Vila,
## Químico/Xamã da Floresta, onda da Horda, spawns aleatórios da Torre), que
## pressupõem o elenco fixo da campanha e não devem alterar um roster
## montado à mão pelo jogador. Ver begin_turn_for().
var pvp_custom_battle := false

## Substitui os console.log/spawnFloatingText/playSfx do original — a
## camada de regras não conhece view nem áudio ainda (Fase 5/6). Guarda
## as mesmas mensagens do JS pra quem quiser exibi-las depois.
var event_log: Array = []

## RNG próprio da instância (em vez de randf()/randi() globais) — permite
## testes determinísticos via `state.rng.seed = N` sem precisar mexer no
## RNG global do processo. Equivalente a Math.random() no JS original.
var rng := RandomNumberGenerator.new()

## Ultima ordem de slots usada por cenario/time no PVP. Alem do
## embaralhamento, impede repeticao acidental entre partidas consecutivas.
var _last_pvp_spawn_orders: Dictionary = {}

func _init() -> void:
	reset()

## Equivalente a resetGame(): reconstrói unidades (do roster completo dos
## 10 personagens), terreno, estruturas e elevação do zero.
func reset() -> void:
	_build_units()
	_build_terrain_map()
	_build_structures()
	_build_elevation_map()
	traps = []
	souls = []
	last_reachable_came_from = {}
	last_reachable_costs = {}
	turn_token += 1
	battle_ended = false
	battle_won = false
	global_turn_count = 0
	graveyard_spawn_count = 0
	event_log = []
	current_actor = null
	round_acted_units = []
	scenario_id = ScenarioManager.FIELD
	tower_pickups = []
	tower_spawn_count = 0
	village_archer_spawned = false
	pvp_custom_battle = false
	cage_release_events = []
	bone_explosion_events = []
	bard_song_vfx_events = []
	hunt_howl_events = []
	bard_song_feedback_events = []
	last_action_vfx = {}

func configure_campaign(bardo_unlocked: bool, party_keys: Array = []) -> void:
	campaign_bardo_unlocked = bardo_unlocked
	selected_party_keys = party_keys.duplicate()

func _filter_campaign_heroes_for_scenario() -> void:
	var future_floor := scenario_id in [ScenarioManager.TOWER_FLOOR_3, ScenarioManager.TOWER_FLOOR_4]
	var allowed: Array = selected_party_keys if future_floor and campaign_bardo_unlocked and not selected_party_keys.is_empty() else Units.player_team_keys()
	units = units.filter(func(u):
		if u.get("team", "") != "player": return true
		var key := String(u.get("spriteKey", ""))
		if key == "bardo":
			if scenario_id == ScenarioManager.TOWER_FLOOR_2: return true
			if not future_floor or not campaign_bardo_unlocked: return false
		return not future_floor or not campaign_bardo_unlocked or allowed.has(key)
	)
	units_by_key = {}
	for u in units: units_by_key[String(u.get("spriteKey", u["name"]))] = u

func apply_scenario(definition: Dictionary) -> void:
	scenario_id = String(definition.get("id", ScenarioManager.FIELD))
	board_width = int(definition.get("board_width", GameConstants.BOARD_SIZE))
	board_height = int(definition.get("board_height", GameConstants.BOARD_SIZE))
	_filter_campaign_heroes_for_scenario()
	if scenario_id == ScenarioManager.FIELD:
		_setup_caged_mage()
		return
	terrain_map = {}
	structures = []
	elevation_map = {}
	if scenario_id == ScenarioManager.LUA_VALLEY:
		_setup_lua_valley(definition)
		return
	if scenario_id == ScenarioManager.VILLAGE:
		_setup_village(definition)
		return
	if scenario_id == ScenarioManager.FOREST:
		_setup_forest(definition)
		return
	if scenario_id == ScenarioManager.PORTO:
		_setup_porto(definition)
		return
	if scenario_id == ScenarioManager.DESFILADEIRO:
		_setup_desfiladeiro(definition)
		return
	if scenario_id == ScenarioManager.ESTRADA_INVERNO:
		_setup_estrada_inverno(definition)
		return
	if scenario_id in [ScenarioManager.TEMPLO, ScenarioManager.CEMITERIO]:
		_setup_haunted_scenery(definition)
		return
	if scenario_id in [ScenarioManager.TOWER_FLOOR_2, ScenarioManager.TOWER_FLOOR_3, ScenarioManager.TOWER_FLOOR_4]:
		_setup_dungeon_floor(definition)
		return
	for tile in definition.get("walls", []):
		terrain_map[tile_key(tile["x"], tile["y"])] = {"type":"tower-wall"}
	for tile in definition.get("pillars", []):
		terrain_map[tile_key(tile["x"], tile["y"])] = {"type":"tower-pillar"}
	for tile in definition.get("doors", []):
		terrain_map[tile_key(tile["x"], tile["y"])] = {"type":"tower-door", "opened":false}
	_apply_scenario_spawns("player", definition.get("player_spawns", []))
	units = units.filter(func(unit): return unit["team"] == "player")
	units_by_key = {}
	for hero in units: units_by_key[hero["name"]] = hero
	_spawn_black_slime_boss()
	_setup_tower_features()

const PVP_DUNGEON_MONSTER_KINDS := ["zombie", "ghost", "skeleton", "living_fire", "lava_human", "salamander", "flame_demon", "vampire", "lich", "dragon"]
const PVP_LUA_MONSTER_KINDS := ["rat", "slime", "snake", "gnoll", "goo"]
## Os 33 Guardians (ver data/guardian_monsters.gd) — lista literal espelhando
## GuardianMonsters.keys() pra seguir o mesmo padrão de const das duas linhas
## acima (GDScript não permite inicializar const com chamada de função).
const PVP_GUARDIAN_MONSTER_KINDS := [
	"fordin", "stegofor", "brachifor", "kroki", "krokivip", "leviadile",
	"devidin", "devidra", "deviraptor", "aerodin", "aerodeer", "aerostag",
	"weastoat", "mooty", "camoon", "moopard", "wuppy", "earog", "deemog",
	"dradder", "driper", "spreye", "buttereye", "duggot", "breem",
	"marvillar", "marvantis", "palmpot", "bonsot", "erimat", "erichief",
	"eggatch", "owlock",
]

## Pedido do usuário: alguns "chefes" de masmorra (HP calibrado pra campanha,
## enfrentado sozinho ou com pouca gente) ficam desbalanceados quando
## escolhidos como 1 de 5 no Modo PVP — reduz só o HP nesse modo, sem tocar
## no resto do kit (armas/magias/IA continuam as mesmas). Único ponto de
## ajuste pra esse tipo de rebalanceamento: novos overrides entram aqui, não
## como `if pvp_custom_battle` espalhado pelas funções de dados dos monstros.
## Pedido do usuário (revisado): Slime Negro (goo) agora TEM escala própria
## no PVP também — 80 HP em vez dos 200 da campanha (ver
## _check_black_slime_split pro limiar/HP dos filhos, que escala junto).
const PVP_MONSTER_STAT_OVERRIDES := {
	# Pedido do usuário (revisado): Elementais do Fogo com HP próprio no PVP
	# — bem abaixo do padrão de campanha, que os deixava fora de escala
	# contra um time de 5 heróis (ver diagnóstico de balanceamento).
	"salamander": {"hp": 60, "maxHp": 60},
	"dragon": {"hp": 70, "maxHp": 70},
	"lava_human": {"hp": 50, "maxHp": 50},
	"goo": {"hp": 100, "maxHp": 100},
	# Pedido do usuário: Troll e Orc com HP próprio no PVP, mais baixo que o
	# padrão da campanha (50/40).
	"troll": {"hp": 50, "maxHp": 50},
	"orc": {"hp": 40, "maxHp": 40},
	# Pedido do usuário: no PVP, os "figurantes" do Vale da Lua (Rato/Slime/
	# Cobra/Gnoll) dobram de HP e ganham +2 de dano em cada ataque — eram HP/
	# dano baixo demais pra sobreviver ou ameaçar um time de 5 escolhido pelo
	# jogador (ver diagnóstico de balanceamento). Armas duplicadas de
	# _tower_creature_templates só com damageMin/damageMax +2.
	"rat": {"hp": 20, "maxHp": 20, "speed": 11, "weapons": [{"name":"Mordida","icon":"🦷","ctCost":50,"damageMin":5,"damageMax":7,"critMultiplier":1,"critChance":0.0,"hitChance":0.7,"minRange":1,"maxRange":1,"sfx":"melee","swing":"stab"}]},
	"slime": {"hp": 25, "maxHp": 25, "speed": 12, "weapons": [{"name":"Pancada","icon":"💥","ctCost":50,"damageMin":6,"damageMax":8,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":1,"maxRange":1,"sfx":"melee","swing":"crush"}]},
	"snake": {"hp": 25, "maxHp": 25, "speed": 12, "weapons": [{"name":"Picada","icon":"🐍","ctCost":50,"damageMin":5,"damageMax":7,"critMultiplier":1,"critChance":0.0,"hitChance":0.9,"minRange":1,"maxRange":1,"appliesPoison":{"damageMin":1,"damageMax":3,"turns":3,"ctDrainPerTurn":10},"sfx":"poison","swing":"stab"}]},
	"gnoll": {"hp": 35, "maxHp": 35, "speed": 12, "weapons": [{"name":"Lança","icon":"🔱","ctCost":50,"damageMin":7,"damageMax":10,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":1,"maxRange":1,"sfx":"melee","swing":"stab"},{"name":"Arremessar Lança","icon":"🔱","ctCost":50,"damageMin":6,"damageMax":9,"critMultiplier":1,"critChance":0.0,"hitChance":0.7,"minRange":2,"maxRange":5,"projectile":"arrow","sfx":"ranged"}]},
}

## Monta uma partida do Modo PVP: reaproveita o terreno/visual de qualquer um
## dos cenarios (via apply_scenario(), que ja sabe montar cada mapa) mas
## descarta o elenco roteirizado que ele criaria (heroi unico da Vila,
## Ladino+Orc da Floresta, onda fixa da Horda, etc.) e entra com o roster
## escolhido pelo jogador na tela de selecao (PvpSetup) -- 5 herois de
## hero_keys e de 5 a 10 monstros de monster_keys (goblin/orc/xama/fada/troll
## vem de Units.build(); os 6 exclusivos de masmorra, de _spawn_dungeon_enemy).
## Reaproveita _apply_scenario_spawns (mesma logica de "campo aberto ao redor
## do ultimo spawn" que os cenarios ja usam pra elencos maiores que os spawns
## nomeados no mapa) pra posicionar os dois times nos spawns do cenario.
## hero_keys joga como "player" e monster_keys como "enemy". No online cada
## lado pode misturar heróis e monstros de qualquer grupo; no PVP local os
## lados continuam sendo só heróis x só monstros.
func apply_pvp_scenario(definition: Dictionary, hero_keys: Array, monster_keys: Array) -> void:
	pvp_custom_battle = true
	apply_scenario(definition)
	clear_units()
	var templates := Units.build()
	var player_side: Array = []
	for i in hero_keys.size():
		player_side.append(_add_pvp_unit(String(hero_keys[i]), i + 1, "player", templates))
	var enemy_side: Array = []
	for i in monster_keys.size():
		enemy_side.append(_add_pvp_unit(String(monster_keys[i]), i + 1, "enemy", templates))
	_mark_pvp_side_duplicates(player_side.filter(func(u): return not u.is_empty()), enemy_side.filter(func(u): return not u.is_empty()))
	# O PVP reutiliza somente os tiles seguros definidos pelo cenário, mas
	# embaralha quem ocupa cada slot para variar a formação a cada partida.
	# A campanha continua usando a ordem original dessas listas.
	_apply_scenario_spawns("player", _pvp_spawn_slots("player", definition))
	_apply_scenario_spawns("enemy", _pvp_spawn_slots("enemy", definition))

## Cria uma unidade do PVP (herói ou monstro, pela chave) já no lado `team`.
func _add_pvp_unit(key: String, index: int, team: String, templates: Dictionary) -> Dictionary:
	var spawned: Dictionary
	if key in PVP_DUNGEON_MONSTER_KINDS:
		spawned = _spawn_dungeon_enemy(key, index, {"x": 0, "y": 0})
	elif key in PVP_LUA_MONSTER_KINDS:
		spawned = _spawn_lua_monster(key, index, {"x": 0, "y": 0})
	elif key in PVP_GUARDIAN_MONSTER_KINDS:
		spawned = _spawn_guardian_monster(key, index, {"x": 0, "y": 0})
	elif templates.has(key):
		spawned = (templates[key] as Dictionary).duplicate(true)
		units.append(spawned)
		units_by_key[key] = spawned
	if spawned.is_empty():
		return spawned
	spawned["team"] = team
	if PVP_MONSTER_STAT_OVERRIDES.has(key):
		for stat_key in PVP_MONSTER_STAT_OVERRIDES[key]:
			spawned[stat_key] = PVP_MONSTER_STAT_OVERRIDES[key][stat_key]
	if key in ["rat", "snake", "gnoll", "slime"]:
		_add_creature_ranged_attack(spawned, key)
	# Pedido do usuário: sem numeração ("Vampiro 1", "Zumbi 2"...) no nome
	# dos monstros do PVP — o sufixo só desambigua várias cópias do MESMO
	# monstro na campanha. Aqui cada lado escolhe cada chave no máximo 1 vez.
	if key in PVP_DUNGEON_MONSTER_KINDS or key in PVP_LUA_MONSTER_KINDS or key in PVP_GUARDIAN_MONSTER_KINDS:
		var numbered_name: String = String(spawned["name"])
		var suffix := " %d" % index
		if numbered_name.ends_with(suffix):
			units_by_key.erase(numbered_name)
			spawned["name"] = numbered_name.substr(0, numbered_name.length() - suffix.length())
			units_by_key[String(spawned["name"])] = spawned
	return spawned

## Pedido do usuário: o mesmo personagem nos dois lados ganha uma bola azul
## (lado do criador) e uma vermelha (adversário) no nome. Também mantém os
## nomes únicos, que o online usa para sincronizar as unidades.
const PVP_PLAYER_MARKER := " 🔵"
const PVP_ENEMY_MARKER := " 🔴"

func _mark_pvp_side_duplicates(player_side: Array, enemy_side: Array) -> void:
	var enemy_names := {}
	for u in enemy_side: enemy_names[String(u["name"])] = true
	for u in player_side:
		var shared := String(u["name"])
		if not enemy_names.has(shared): continue
		for other in enemy_side:
			if String(other["name"]) == shared:
				other["name"] = shared + PVP_ENEMY_MARKER
				units_by_key[other["name"]] = other
		u["name"] = shared + PVP_PLAYER_MARKER
		units_by_key[u["name"]] = u
		units_by_key.erase(shared)

## Copia e embaralha apenas os slots do PVP; as definições dos cenários e os
## spawns da campanha permanecem intactos. No Campo, a faixa válida começa na
## quarta linha visual (índice y=3).
func _pvp_spawn_slots(team: String, definition: Dictionary) -> Array:
	var source_key := "player_spawns" if team == "player" else "enemy_spawns"
	var slots: Array = (definition.get(source_key, []) as Array).duplicate(true)
	if String(definition.get("id", "")) == ScenarioManager.FIELD:
		slots = slots.filter(func(tile: Dictionary): return int(tile.get("y", -1)) >= 3)
	_shuffle_tiles(slots)
	var history_key := "%s:%s" % [String(definition.get("id", "")), team]
	var order: Array = slots.map(func(tile: Dictionary): return "%d,%d" % [int(tile["x"]), int(tile["y"])])
	if slots.size() > 1 and _last_pvp_spawn_orders.get(history_key, []) == order:
		var first = slots.pop_front()
		slots.push_back(first)
		order = slots.map(func(tile: Dictionary): return "%d,%d" % [int(tile["x"]), int(tile["y"])])
	_last_pvp_spawn_orders[history_key] = order
	return slots

## Kinds do enemy_roster com footprint maior que 1x1 — ver comentário em
## _setup_dungeon_floor sobre por que ficam fora do embaralhamento de
## posições iniciais.
const DUNGEON_LARGE_ENEMY_KINDS := ["salamander"]

func _setup_dungeon_floor(definition: Dictionary) -> void:
	for tile in definition.get("walls", []):
		terrain_map[tile_key(tile["x"], tile["y"])] = {"type":"tower-wall"}
	for tile in definition.get("pillars", []):
		terrain_map[tile_key(tile["x"], tile["y"])] = {"type":"tower-pillar"}
	for tile in definition.get("doors", []):
		terrain_map[tile_key(tile["x"], tile["y"])] = {"type":"tower-door", "opened":false}
	for tile in definition.get("lava", []):
		terrain_map[tile_key(tile["x"], tile["y"])] = {
			"type":"hazard", "hazard":"lava", "walkable":true,
			"movementCost":3, "damageOnEnter":1, "statusOnEndTurn":"burned"
		}
	# Névoa venenosa do 2º Andar: atravessável, sem dano instantâneo — só
	# aplica ENVENENADO (ver _apply_tower_path_features). Custo de
	# deslocamento maior (3, igual à lava) faz a IA evitar quando possível
	# sem nunca bloquear o tile.
	for tile in definition.get("poison_gas", []):
		terrain_map[tile_key(tile["x"], tile["y"])] = {
			"type":"hazard", "hazard":"poison-gas", "walkable":true, "movementCost":3
		}
	_apply_scenario_spawns("player", definition.get("player_spawns", []))
	if definition.has("enemy_roster"):
		units = units.filter(func(unit): return unit["team"] == "player")
		units_by_key = {}
		for hero in units: units_by_key[hero["name"]] = hero
		# Pedido do usuário: inimigos nascem em posições aleatórias a cada
		# início de partida — embaralha as posições curadas do andar entre
		# si (mesmos tiles válidos de sempre, só troca quem nasce em qual),
		# mesmo princípio já usado em _shuffle_team_positions/Vale da Lua,
		# sem risco de cair em parede/lava/fora do alcance. A Salamandra
		# (footprint 2x2, ver DUNGEON_LARGE_ENEMY_KINDS) fica de fora do
		# embaralhamento: seu tile foi escolhido a dedo pra caber o corpo
		# grande sem sobrepor parede/pilar — trocar de lugar com um monstro
		# 1x1 comum arrisca não caber ali.
		var roster: Array = definition["enemy_roster"]
		var kinds: Array = []
		var positions: Array = []
		for i in roster.size():
			var entry: Dictionary = roster[i]
			if String(entry["kind"]) in DUNGEON_LARGE_ENEMY_KINDS:
				_spawn_dungeon_enemy(String(entry["kind"]), i + 1, entry)
			else:
				kinds.append(String(entry["kind"]))
				positions.append({"x": entry["x"], "y": entry["y"], "roster_index": i})
		_shuffle_tiles(positions)
		for i in kinds.size():
			_spawn_dungeon_enemy(kinds[i], positions[i]["roster_index"] + 1, positions[i])
	else:
		_apply_scenario_spawns("enemy", definition.get("enemy_spawns", []))
	# Mantém os dois times completos neste andar; só reconstrói o índice após
	# aplicar os pontos de entrada e as salas inimigas.
	units_by_key = {}
	for unit_data in units:
		units_by_key[unit_data["name"]] = unit_data
		units_by_key[String(unit_data.get("spriteKey", unit_data["name"]))] = unit_data
	if scenario_id == ScenarioManager.TOWER_FLOOR_2 and not campaign_bardo_unlocked:
		_setup_caged_bardo(definition)

func _spawn_dungeon_enemy(kind: String, index: int, pos: Dictionary) -> Dictionary:
	var data := dungeon_monster_data(kind, index, pos)
	if data.is_empty():
		return {}
	return spawn_unit(String(data["name"]), data)

## Mesma ideia de _spawn_dungeon_enemy/dungeon_monster_data, só que pros
## bichos do Vale da Lua (Rato/Slime/Cobra/Gnoll, ver _tower_creature_templates)
## + o Slime Negro (ver black_slime_boss_data) — pedido do usuário foi poder
## escolher esses 5 também no time inimigo do Modo PVP (PvpSetup), não só os
## 6 exclusivos de masmorra que já tinham esse caminho.
func _spawn_lua_monster(kind: String, index: int, pos: Dictionary) -> Dictionary:
	var data := lua_monster_data(kind, index, pos)
	if data.is_empty():
		return {}
	return spawn_unit(String(data["name"]), data)

## Mesma ideia de _spawn_dungeon_enemy/_spawn_lua_monster, pros 33 Guardians
## portados de lucidtanooki/guardian_monsters (ver data/guardian_monsters.gd
## — dados vêm de lá, GameState só aplica índice/posição igual aos outros
## dois caminhos).
func _spawn_guardian_monster(kind: String, index: int, pos: Dictionary) -> Dictionary:
	var data := guardian_monster_data(kind, index, pos)
	if data.is_empty():
		return {}
	return spawn_unit(String(data["name"]), data)

static func guardian_monster_data(kind: String, index: int = 1, pos: Dictionary = {"x": 0, "y": 0}) -> Dictionary:
	var templates := GuardianMonsters.build()
	if not templates.has(kind):
		return {}
	var data: Dictionary = (templates[kind] as Dictionary).duplicate(true)
	_add_creature_ranged_attack(data, kind)
	data["name"] = "%s %d" % [String(data["name"]), index]
	data["x"] = int(pos["x"])
	data["y"] = int(pos["y"])
	return data

static func lua_monster_data(kind: String, index: int = 1, pos: Dictionary = {"x": 0, "y": 0}) -> Dictionary:
	if kind == "goo":
		return black_slime_boss_data(pos, "Slime Negro %d" % index)
	var templates := _tower_creature_templates()
	if not templates.has(kind):
		return {}
	var data: Dictionary = (templates[kind] as Dictionary).duplicate(true)
	data["name"] = "%s %d" % [String(data["name"]), index]
	data["x"] = int(pos["x"])
	data["y"] = int(pos["y"])
	return data

## Extraído de _spawn_dungeon_enemy (era o corpo dela até virar só o
## match/dicionário) pra poder montar a ficha de um monstro de masmorra SEM
## precisar de uma partida em andamento — usado pela tela de seleção de
## monstros do Modo PVP (PvpSetup) pra mostrar retrato/atributos/armas/
## magias antes de escolher, do mesmo jeito que Units.build() já serve de
## fonte pros heróis e pros 5 inimigos "de campo". static: não depende de
## nenhum campo de instância do GameState, só dos parâmetros.
static func dungeon_monster_data(kind: String, index: int = 1, pos: Dictionary = {"x": 0, "y": 0}) -> Dictionary:
	var burn := {"damageMin":2,"damageMax":4,"turns":3}
	var poison := {"damageMin":1,"damageMax":3,"turns":3}
	var common := {"team":"enemy","x":int(pos["x"]),"y":int(pos["y"]),"moveRange":3,"ct":0,"hasMoved":false,"hasActed":false,"statusEffects":[],"facing":{"dx":-1,"dy":0}}
	var data: Dictionary
	match kind:
		"zombie":
			# Pedido do usuário: +10 HP em todo morto-vivo (ver também a
			# resistência a ataque de arma em resolve_single_hit).
			data = {"name":"Zombie %d" % index,"hp":30,"maxHp":30,"mp":5,"maxMp":5,"speed":9,"spriteKey":"tower_zombie","bodyColor":"#71845a","undead":true,"resurrection":{"afterTurns":3,"hpPercent":1.0,"mpPercent":1.0},"weapons":[{"name":"Pancada","damageMin":3,"damageMax":6,"hitChance":0.70,"critChance":0.15,"critMultiplier":2,"ctCost":50,"minRange":1,"maxRange":1,"damageType":"physical","appliesPoison":poison}],"spells":[]}
		"ghost":
			data = {"name":"Fantasma %d" % index,"hp":35,"maxHp":35,"mp":10,"maxMp":10,"speed":12,"spriteKey":"tower_ghost","bodyColor":"#7750ba","flying":true,"ethereal":true,"undead":true,"immediateSoul":true,"soulHp":10,"soulMp":5,"weapons":[{"name":"Mordida","damageMin":4,"damageMax":8,"hitChance":0.80,"critChance":0.15,"critMultiplier":2,"ctCost":50,"minRange":1,"maxRange":1,"damageType":"physical","appliesCtDrain":20}],"spells":[{"name":"Raio Congelante","targetMode":"enemy","damageMin":5,"damageMax":10,"hitChance":0.80,"critChance":0.0,"critMultiplier":1,"ctCost":50,"mpCost":5,"minRange":1,"maxRange":3,"damageType":"ice","projectile":"frost-wand-spd","beamTint":"ice","requiresClearPath":true,"appliesParalyzed":{"turns":1}}]}
		"skeleton":
			data = {"name":"Esqueleto %d" % index,"hp":30,"maxHp":30,"mp":0,"maxMp":0,"speed":10,"spriteKey":"tower_skeleton","bodyColor":"#c6b48f","undead":true,"boneExplosion":true,"weapons":[{"name":"Lança","damageMin":3,"damageMax":6,"hitChance":0.80,"critChance":0.15,"critMultiplier":2,"ctCost":50,"minRange":1,"maxRange":1,"damageType":"physical"},{"name":"Arremesso de Lança","damageMin":3,"damageMax":6,"hitChance":0.80,"critChance":0.0,"critMultiplier":1,"ctCost":50,"minRange":2,"maxRange":3,"cardinalOnly":true,"requiresClearPath":true,"projectile":"spear","damageType":"physical"}],"spells":[]}
		"living_fire":
			data = {"name":"Fogo Vivo %d" % index,"hp":20,"maxHp":20,"mp":10,"maxMp":10,"speed":11,"spriteKey":"tower_living_fire","bodyColor":"#ff7a16","flying":true,"elementAffinity":{"fire":{"mode":"heal","multiplier":1.0},"ice":{"mode":"damage","multiplier":2.0}},"weapons":[{"name":"Toque de Fogo","damageMin":3,"damageMax":6,"hitChance":0.80,"critChance":0.0,"critMultiplier":1,"ctCost":50,"minRange":1,"maxRange":1,"damageType":"fire","appliesBurn":burn}],"spells":[{"name":"Cuspe de Fogo","targetMode":"enemy","damageMin":4,"damageMax":8,"hitChance":0.80,"critChance":0.0,"critMultiplier":1,"ctCost":60,"mpCost":5,"minRange":2,"maxRange":3,"requiresClearPath":true,"projectile":"fireball","damageType":"fire","appliesBurn":burn},{"name":"Autodestruição","kind":"living-fire-self-destruct","targetMode":"self","damageMin":5,"damageMax":15,"hitChance":0.80,"critChance":0.0,"critMultiplier":1,"ctCost":0,"mpCost":0,"damageType":"fire"}]}
		"lava_human":
			# Pedido do usuário: Pancada de Fogo é o ATAQUE da Lava Humana (por
			# isso tinha mpCost 0 — nunca custava mana de verdade), não uma
			# habilidade — agora mora em "weapons" (sem campo mpCost nenhum,
			# convenção do catálogo pra diferenciar arma de magia, ver
			# resolve_single_hit:is_weapon_attack), com minRange/maxRange 1
			# igual toda arma corpo a corpo. _find_spell na IA (mais abaixo)
			# virou _find_weapon pra continuar achando ela.
			data = {"name":"Lava Humana %d" % index,"hp":80,"maxHp":80,"mp":10,"maxMp":10,"speed":10,"spriteKey":"tower_lava_human","bodyColor":"#c94719","elementAffinity":{"fire":{"mode":"heal","multiplier":1.0},"ice":{"mode":"damage","multiplier":2.0}},"weapons":[{"name":"Pancada de Fogo","kind":"fire-self-area","damageMin":4,"damageMax":8,"hitChance":0.80,"critChance":0.15,"critMultiplier":2,"ctCost":50,"minRange":1,"maxRange":1,"damageType":"fire","appliesBurn":burn}],"spells":[{"name":"Cone de Fogo","kind":"cone-fire","targetMode":"cone-fire","damageMin":5,"damageMax":10,"hitChance":0.80,"critChance":0.0,"critMultiplier":1,"ctCost":60,"mpCost":5,"minRange":1,"maxRange":3,"damageType":"fire","appliesBurn":burn}]}
		"salamander":
			data = {"name":"Salamandra %d" % index,"hp":300,"maxHp":300,"mp":20,"maxMp":20,"speed":11,"moveRange":4,"spriteKey":"tower_salamander","bodyColor":"#d85b24","footprintWidth":2,"footprintHeight":2,"footprintSize":2,"elementAffinity":{"fire":{"mode":"heal","multiplier":1.0},"ice":{"mode":"damage","multiplier":2.0}},"weapons":[{"name":"Tridente","damageMin":6,"damageMax":10,"hitChance":0.80,"critChance":0.15,"critMultiplier":2,"ctCost":50,"minRange":1,"maxRange":2,"requiresClearPath":true,"swing":"stab","damageType":"fire","appliesBurn":burn}],"spells":[{"name":"Explosão de Fogo","kind":"growth-attack","targetMode":"self-attack","damageMin":8,"damageMax":12,"hitChance":0.80,"critChance":0.0,"critMultiplier":1,"ctCost":60,"mpCost":5,"damageType":"fire","appliesBurn":burn,"sfx":"fire"},{"name":"Labaredas de Chamas","kind":"salamander-flame-wave","targetMode":"flame-creeping-line","damageMin":10,"damageMax":15,"hitChance":0.80,"critChance":0.0,"critMultiplier":1,"ctCost":70,"mpCost":10,"minRange":1,"maxRange":3,"cardinalOnly":true,"bandLength":GameConstants.BOARD_SIZE,"bandWidth":3,"damageType":"fire","appliesBurn":burn,"projectileKind":"fireball","burstKind":"fireball","sfx":"fire"}]}
		"flame_demon":
			# Pedido do usuário: Demônio das Chamas. Garra/Raio de Fogo vêm do
			# catálogo comum (data/weapons.gd) — Garra é nova (sangramento, ver
			# resolve_single_hit), Raio de Fogo espelha Raio de Gelo da Maga só
			# trocando o elemento. Bola de Fogo é literalmente a MESMA magia do
			# Mago (duplicate() do dicionário de Spells.build(), não uma cópia
			# manual dos números) — reforça que é a mesma habilidade, não uma
			# recriação. Flecha de Fogo Penetrante = Tiro Penetrante do Arqueiro
			# (mesmo alcance/dano/crítico/perfuração, cast_pierce_shot
			# inalterado) + o efeito de queimar da Flecha de Fogo do Arqueiro
			# (mesmo burn canônico usado por resolve_single_hit), só com MP
			# próprio (7) pedido pelo usuário. Invocar Fogo Vivo usa
			# cast_summon_living_fire, que por sua vez chama esta mesma função
			# com kind "living_fire" pra montar a criatura invocada — nenhuma
			# unidade nova é inventada.
			var weapons_catalog := Weapons.build()
			var spells_catalog := Spells.build()
			var fire_pierce: Dictionary = (spells_catalog["pierceShot"] as Dictionary).duplicate(true)
			fire_pierce["name"] = "Flecha de Fogo"
			fire_pierce["kind"] = "fire-arrow-pierce"
			fire_pierce["mpCost"] = 7
			fire_pierce["damageType"] = "fire"
			fire_pierce["appliesBurn"] = DataUtil.merge(StatusDotDamage.STATUS_DOT_DAMAGE["burned"], {"turns": 3})
			fire_pierce["projectileKind"] = "fire-arrow"
			fire_pierce["burstKind"] = "fire-arrow"
			fire_pierce["tooltipNote"] = "Sempre atira em linha reta (só nas 4 direções cardeais), até a borda do mapa — igual ao Tiro Penetrante do Arqueiro. Perfura e acerta todos os inimigos no caminho, incendiando cada um por 3 turnos (efeito da Flecha de Fogo)."
			fire_pierce["sfx"] = "fire"
			var summon_living_fire := {
				"name": "Invocar Fogo Vivo", "icon": "🔥", "kind": "summon-living-fire",
				"ctCost": 70, "mpCost": 20, "targetMode": "summon",
				"minRange": 0, "maxRange": 3,
				"tooltipNote": "Alcance 3; invoca 1 Fogo Vivo (mesma unidade da Torre) num tile vazio e caminhável.",
				"sfx": "fire",
			}
			data = {
				"name": "Demônio das Chamas %d" % index, "hp": 25, "maxHp": 25, "mp": 20, "maxMp": 20, "speed": 10,
				"spriteKey": "flame_demon", "bodyColor": "#ff4d1c",
				"statusImmunities": ["burned"],
				"elementAffinity": {"fire": {"mode": "heal", "multiplier": 1.0}, "ice": {"mode": "damage", "multiplier": 2.0}},
				"weapons": [weapons_catalog["claw"], weapons_catalog["fireRay"]],
				"spells": [(spells_catalog["fireball"] as Dictionary).duplicate(true), fire_pierce, summon_living_fire],
			}
		"vampire":
			# Pedido do usuário: Vampiro. Mordida/Toque Vampírico vêm do
			# catálogo comum (weapons.gd, campo genérico `lifesteal`, ver
			# resolve_single_hit). Virar Morcego/Invocar Morcegos são
			# `kind`/`targetMode` despachados por cast_self_ability/
			# _resolve_spell — nenhuma lógica de transformação ou invocação
			# mora aqui, só a ficha da unidade. `undead: true` (pedido do
			# usuário: Vampiro conta como morto-vivo pra tudo — inclusive a
			# fraqueza a gelo ×0.5 e as magias do Lich).
			var vampire_weapons := Weapons.build()
			data = {
				"name": "Vampiro %d" % index, "hp": 45, "maxHp": 45, "mp": 15, "maxMp": 15, "speed": 10,
				"spriteKey": "vampire", "bodyColor": "#6b1836", "undead": true,
				"weapons": [vampire_weapons["vampireBite"], vampire_weapons["vampiricTouch"]],
				"spells": [
					{
						"name": "Virar Morcego", "icon": "🦇", "kind": "vampire-bat-form", "ctCost": 0, "mpCost": 5,
						"targetMode": "self",
						"tooltipNote": "Ação livre: não gasta CT nem consome sua ação/movimento do turno. Dobra o deslocamento, concede Voo (igual à Fada) e eleva o lifesteal de Mordida/Toque Vampírico para 100% até o início do seu próximo turno.",
						"sfx": "arcane",
					},
					{
						"name": "Invocar Morcegos", "icon": "🦇", "kind": "summon-vampire-bat", "ctCost": 0, "mpCost": 10,
						"targetMode": "summon", "minRange": 0, "maxRange": 2,
						"tooltipNote": "Alcance 2; invoca 1 Morcego Vampiro (variação da Cobra, com Voo permanente e lifesteal 50%) num tile vazio e caminhável.",
						"sfx": "arcane",
					},
				],
			}
		"lich":
			# Pedido do usuário: Lich. Raio de Decaimento vem do catálogo comum
			# (weapons.gd — reutiliza appliesSpeedReduction/appliesSlow/
			# appliesCtDrain, já genéricos em resolve_single_hit, sem nenhuma
			# lógica nova). Invocar Esqueleto/Zumbi despacham pra
			# cast_summon_skeleton/cast_summon_zombie (mesma unidade exata da
			# Torre, ver dungeon_monster_data). Decaimento é a MESMA área da
			# Bola de Fogo (areaRadius 3, mesma forma/losango — ver
			# cast_decay_pulse), só centrada no próprio Lich. Reanimação é
			# cast_reanimate (mesma matemática de cast_resurrect, só restrita a
			# undead). Infligir Ferimentos é a MESMA quantidade/chance/custo da
			# Cura (spells.gd:"cure"), só com resolve_harm invertendo quem cura
			# e quem sofre dano.
			var cure_spell: Dictionary = Spells.build()["cure"]
			data = {
				"name": "Lich %d" % index, "hp": 35, "maxHp": 35, "mp": 20, "maxMp": 20, "speed": 10,
				"spriteKey": "lich", "bodyColor": "#2f7d4f", "undead": true,
				"weapons": [Weapons.build()["decayRay"]],
				"spells": [
					{
						"name": "Invocar Esqueleto", "icon": "💀", "kind": "summon-skeleton", "ctCost": 50, "mpCost": 15,
						"targetMode": "summon", "minRange": 0, "maxRange": 2,
						"tooltipNote": "Alcance 2; invoca 1 Esqueleto (mesma unidade da Torre) num tile vazio e caminhável.",
						"sfx": "poison",
					},
					{
						"name": "Invocar Zumbi", "icon": "🧟", "kind": "summon-zombie", "ctCost": 50, "mpCost": 15,
						"targetMode": "summon", "minRange": 0, "maxRange": 2,
						"tooltipNote": "Alcance 2; invoca 1 Zumbi (mesma unidade da Torre, com a própria ressurreição automática) num tile vazio e caminhável.",
						"sfx": "poison",
					},
					{
						"name": "Decaimento", "icon": "☠️", "kind": "decay-pulse", "ctCost": 50, "mpCost": 10,
						"targetMode": "self-aoe", "areaRadius": 3,
						"damageMin": 2, "damageMax": 4, "hitChance": 0.8, "critChance": 0.0, "critMultiplier": 1,
						"healMin": 2, "healMax": 4,
						"appliesBleed": {"damageMin": 1, "damageMax": 1, "turns": 3},
						"appliesPoison": DataUtil.merge(StatusDotDamage.STATUS_DOT_DAMAGE["poison"], {"turns": 3}),
						"tooltipNote": "Mesma área da Bola de Fogo (raio 3), só centrada no próprio Lich. Vivos: 80% de chance de 2-4 de dano + Sangrando + Envenenado. Mortos-vivos (aliados ou inimigos) na área: regeneram 2-4 HP.",
						"sfx": "poison",
					},
					{
						"name": "Reanimação", "icon": "✨", "kind": "reanimate", "ctCost": 90, "mpCost": 7,
						"critChance": 0, "hitChance": 0.7, "minRange": 0, "maxRange": 3,
						"targetMode": "reanimate",
						"tooltipNote": "Igual à Ressurreição (alcance 3, metade do HP máximo, 70% de chance de sucesso), mas só funciona em mortos-vivos.",
						"sfx": "poison",
					},
					{
						"name": "Infligir Ferimentos", "icon": "💚", "kind": "inflict-wounds",
						"ctCost": cure_spell["ctCost"], "mpCost": cure_spell["mpCost"],
						"healMin": cure_spell["healMin"], "healMax": cure_spell["healMax"],
						"areaRadius": cure_spell["areaRadius"], "hitChance": cure_spell["hitChance"], "critChance": 0,
						"minRange": cure_spell["minRange"], "maxRange": cure_spell["maxRange"],
						"targetMode": "inflict-wounds",
						"tooltipNote": "Mesma área/alcance/custo da Cura (raio 1, alcance 3): mortos-vivos recuperam %d-%d de vida; qualquer outra criatura sofre %d-%d de dano." % [cure_spell["healMin"], cure_spell["healMax"], cure_spell["healMin"], cure_spell["healMax"]],
						"sfx": "poison",
					},
					(Spells.build()["reincarnation"] as Dictionary).duplicate(true),
				],
			}
		"dragon":
			# Pedido do usuário: Dragão Vermelho. Garra/Cauda vêm do catálogo
			# comum (weapons.gd) — Cauda usa o novo campo genérico `knockback`
			# de resolve_single_hit (empurrão de golpe direto) + o já existente
			# `appliesCtDrain`. Cone de Fogo é literalmente a MESMA magia da
			# Lava Humana (mesmos números do dicionário "Cone de Fogo" em
			# dungeon_monster_data("lava_human"), reaproveitando a var `burn`
			# já calculada no topo desta função) — o pedido do usuário
			# menciona "Cone de Fogo da Salamandra", mas a habilidade com esse
			# nome pertence à Lava Humana no projeto atual (a Salamandra tem
			# Explosão de Fogo/Labaredas de Chamas); reaproveitada pela
			# identidade da habilidade, não pelo nome de quem a possui hoje.
			# elementAffinity fire:immune (0 dano, sem Queimando — ver
			# resolve_single_hit) + ice:×2 é o mesmo par fire/ice já usado
			# pelas outras criaturas de fogo, só trocando "heal" por "immune".
			var dragon_weapons := Weapons.build()
			data = {
				# Pedido do usuário: HP ajustado de 50 pra 100 depois da spec original.
			"name": "Dragão Vermelho %d" % index, "hp": 100, "maxHp": 100, "mp": 10, "maxMp": 10, "speed": 9, "moveRange": 4,
				"spriteKey": "dragon", "bodyColor": "#b3241f",
				# Pedido do usuário: Dragão também é unidade 2x2 agora, igual
				# Salamandra/Goo grande — mesma regra de escala (ver
				# unit_token.gd:_apply_texture, pés na base/cabeça no topo da caixa).
				"footprintWidth": 2, "footprintHeight": 2, "footprintSize": 2,
				"statusImmunities": ["burned"],
				"elementAffinity": {"fire": {"mode": "immune"}, "ice": {"mode": "damage", "multiplier": 2.0}},
				"weapons": [dragon_weapons["dragonClaw"], dragon_weapons["dragonTail"]],
				"spells": [
					{"name":"Cone de Fogo","kind":"cone-fire","targetMode":"cone-fire","damageMin":5,"damageMax":10,"hitChance":0.80,"critChance":0.0,"critMultiplier":1,"ctCost":60,"mpCost":5,"minRange":1,"maxRange":3,"damageType":"fire","appliesBurn":burn},
				],
			}
		_:
			return {}
	for key in common:
		if not data.has(key): data[key] = common[key]
	# Criaturas de fogo apenas ignoram fogo; ataques de fogo não causam dano
	# nem recuperam HP. A cura da lava é tratada separadamente pelo terreno.
	if kind in ["living_fire", "lava_human", "salamander", "flame_demon"]:
		if data.has("elementAffinity"):
			data["elementAffinity"]["fire"] = {"mode": "immune"}
	# Rebalanceamento dos Elementais do Fogo: todos os danos diretos de suas
	# armas e habilidades caem em 2 pontos. Status secundários, como queimadura,
	# continuam com seus próprios valores. Salamandra e Dragão perdem 1 agilidade.
	if kind in ["living_fire", "lava_human", "salamander", "dragon", "flame_demon"]:
		for attack_list_name in ["weapons", "spells"]:
			for attack in data.get(attack_list_name, []):
				if attack.has("damageMin"):
					attack["damageMin"] = maxi(0, int(attack["damageMin"]) - 2)
				if attack.has("damageMax"):
					attack["damageMax"] = maxi(0, int(attack["damageMax"]) - 2)
	if kind == "salamander" or kind == "dragon":
		data["speed"] = maxi(1, int(data.get("speed", 1)) - 1)
	return data

static func _add_creature_ranged_attack(data: Dictionary, kind: String) -> void:
	var attack: Dictionary = {}
	match kind:
		"rat":
			attack = {"name":"Arremesso de Entulho","ctCost":40,"mpCost":1,"damageMin":2,"damageMax":4,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":2,"maxRange":3,"projectile":"stone","accuracyPenaltyChance":0.3,"appliesAccuracyPenalty":0.1,"penaltyTurns":1,"sfx":"ranged"}
			data["mp"] = maxi(int(data.get("mp", 0)), 1); data["maxMp"] = maxi(int(data.get("maxMp", 0)), 1)
		"snake":
			attack = {"name":"Jato de Peçonha","ctCost":50,"mpCost":4,"damageMin":2,"damageMax":4,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":2,"maxRange":4,"projectile":"poison","poisonChance":0.6,"appliesPoison":{"damageMin":1,"damageMax":1,"turns":3},"sfx":"poison"}
			data["mp"] = maxi(int(data.get("mp", 0)), 4); data["maxMp"] = maxi(int(data.get("maxMp", 0)), 4)
		"gnoll":
			attack = {"name":"Lança de Caça","ctCost":55,"mpCost":3,"damageMin":5,"damageMax":8,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":2,"maxRange":4,"projectile":"spear","appliesMarked":{"turns":2,"damageBonus":1},"sfx":"ranged"}
			data["mp"] = maxi(int(data.get("mp", 0)), 3); data["maxMp"] = maxi(int(data.get("maxMp", 0)), 3)
		"slime":
			attack = {"name":"Glóbulo Viscoso","ctCost":45,"mpCost":3,"damageMin":3,"damageMax":5,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":2,"maxRange":3,"projectile":"slime","sfx":"ranged"}
			data["mp"] = maxi(int(data.get("mp", 0)), 3); data["maxMp"] = maxi(int(data.get("maxMp", 0)), 3)
		_:
			return
	# Ataques à distância das criaturas são armas CT-only: o campo MP fica
	# explicitamente em zero para a ficha/tooltip, mas nunca condiciona a ação.
	attack["mpCost"] = 0
	attack["minRange"] = 1
	attack["maxRange"] = {"rat": 3, "snake": 4, "gnoll": 4, "slime": 3}.get(kind, attack.get("maxRange", 1))
	if kind == "slime":
		attack["appliesSlow"] = {"moveReduction": 1, "turns": 1}
	var weapons: Array = (data.get("weapons", []) as Array).duplicate(true)
	if not weapons.any(func(w): return w.get("name", "") == attack["name"]):
		weapons.append(attack)
		data["weapons"] = weapons

## Chave/posição da Maga presa no Campo (única unidade caged: ver
## _setup_caged_mage). Tile livre de árvore/água/decoração bloqueante, do
## lado inimigo (colunas 10-12), com 3 dos 4 vizinhos cardeais andáveis —
## ver BoardLayout.TERRAIN_LAYOUT.
const CAGED_MAGE_KEY := "mago"
const CAGED_MAGE_TILE := {"x": 11, "y": 8}
const CAGED_BARDO_KEY := "bardo"

## No Campo, a Maga começa presa numa gaiola do lado inimigo: imóvel
## (hasMoved/hasActed já true, fora da corrida de CT — ver
## advance_ct_until_ready), imune a qualquer dano (ver resolve_single_hit) e
## nunca um alvo válido pra ninguém (ver opposing_team_of). Libertação: ver
## _check_cage_release/_release_caged_mage, chamados de advance_to_next_turn.
func _setup_caged_mage() -> void:
	var maga: Dictionary = units_by_key.get(CAGED_MAGE_KEY, {})
	if maga.is_empty():
		return
	maga["x"] = CAGED_MAGE_TILE["x"]
	maga["y"] = CAGED_MAGE_TILE["y"]
	maga["facing"] = {"dx": -1, "dy": 0}
	maga["caged"] = true
	maga["ct"] = 0
	maga["hasMoved"] = true
	maga["hasActed"] = true
	# Pedido do usuário: nenhum personagem pode começar a partida em cima da
	# gaiola — inclusive uma unidade 2x2 (Troll) cujo footprint só ENCOSTE
	# nela depois do embaralhamento de posições (_shuffle_team_positions em
	# _build_units, que roda antes da gaiola existir e não sabia dela).
	_relocate_units_overlapping_tile(maga, int(CAGED_MAGE_TILE["x"]), int(CAGED_MAGE_TILE["y"]))

## A regra de não sobrepor unidades vale pros 4 quadrados inteiros de uma
## unidade grande (Troll/Goo grande/Salamandra/Dragão), não só o tile-âncora
## — mesma cobertura de footprint que _can_unit_anchor_at já garante pro
## MOVIMENTO, aplicada aqui num posicionamento inicial que não passava por
## ela. `protected_unit` nunca é movida (posição roteirizada); qualquer outra
## unidade cujo footprint invada (tx,ty) é realocada pro tile andável mais
## próximo da sua própria posição (mesma busca em anéis de
## _apply_scenario_spawns, que já cobre footprint/estrutura/ocupante).
func _relocate_units_overlapping_tile(protected_unit: Dictionary, tx: int, ty: int) -> void:
	for u in units:
		if u == protected_unit or u["hp"] <= 0 or not unit_contains_tile(u, tx, ty):
			continue
		var anchor := {"x": u["x"], "y": u["y"]}
		var placed := false
		for radius in range(1, maxi(board_width, board_height)):
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if absi(dx) + absi(dy) != radius: continue
					var x: int = int(anchor["x"]) + dx
					var y: int = int(anchor["y"]) + dy
					if structure_at(x, y) != null or not _can_unit_anchor_at(u, x, y): continue
					u["x"] = x; u["y"] = y
					placed = true
					break
				if placed: break
			if placed: break

## Âncora mais próxima de (x,y) — busca em anéis, mesma ordem de
## _apply_scenario_spawns — onde o corpo inteiro de `u` cabe (limites, terreno,
## ocupantes). Devolve o próprio (x,y) se já couber ou, sem nenhuma opção, também.
func _nearest_free_anchor(u: Dictionary, x: int, y: int) -> Dictionary:
	if _can_unit_anchor_at(u, x, y):
		return {"x": x, "y": y}
	for radius in range(1, maxi(board_width, board_height)):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) + absi(dy) == radius and _can_unit_anchor_at(u, x + dx, y + dy):
					return {"x": x + dx, "y": y + dy}
	return {"x": x, "y": y}

func _setup_caged_bardo(definition: Dictionary) -> void:
	var bard: Dictionary = units_by_key.get(CAGED_BARDO_KEY, {})
	if bard.is_empty(): return
	var heroes := team_units("player").filter(func(u): return u != bard)
	if heroes.is_empty(): return
	var probe: Dictionary = heroes[0]
	var old_move: int = probe["moveRange"]
	probe["moveRange"] = board_width * board_height
	var reachable: Array = compute_reachable(probe)
	probe["moveRange"] = old_move
	var forbidden := {}
	for spawn in definition.get("player_spawns", []): forbidden[tile_key(spawn["x"],spawn["y"])] = true
	for tile in [definition.get("entrance_tile", {}), definition.get("exit_tile", {})]:
		if not tile.is_empty(): forbidden[tile_key(tile["x"],tile["y"])] = true
	for tile in definition.get("doors", []): forbidden[tile_key(tile["x"],tile["y"])] = true
	for deco in definition.get("decorations", []):
		if deco.get("kind", "") in ["stairs", "entrance", "exit"]: forbidden[tile_key(deco["x"],deco["y"])] = true
	var candidates: Array = []
	for tile in reachable:
		var key := tile_key(tile["x"],tile["y"])
		if forbidden.has(key): continue
		var terrain = terrain_at(tile["x"],tile["y"])
		if terrain != null and (BoardLayout.BLOCKING_TERRAIN_TYPES.has(terrain.get("type","")) or terrain.get("hazard","") != "" or terrain.get("type","") == "tower-door"): continue
		var occupant = occupant_at(tile["x"],tile["y"])
		if occupant != null and occupant != bard: continue
		var open_neighbors := 0
		for d in [[1,0],[-1,0],[0,1],[0,-1]]:
			var nx: int = tile["x"] + d[0]; var ny: int = tile["y"] + d[1]
			if not in_bounds(nx,ny): continue
			var neighbor_terrain = terrain_at(nx,ny)
			if neighbor_terrain == null or (not BoardLayout.BLOCKING_TERRAIN_TYPES.has(neighbor_terrain.get("type","")) and neighbor_terrain.get("hazard","") == ""):
				open_neighbors += 1
		if open_neighbors >= 1: candidates.append(tile)
	if candidates.is_empty(): return
	var chosen: Dictionary = candidates[rng.randi_range(0, candidates.size()-1)]
	bard["x"] = chosen["x"]; bard["y"] = chosen["y"]
	bard["facing"] = {"dx":-1,"dy":0}
	bard["caged"] = true
	bard["ct"] = 0; bard["hasMoved"] = true; bard["hasActed"] = true
	bard["campaignRecruit"] = true

## Chamado do início de advance_to_next_turn(): um herói ("team" player, humano
## ou IA) que acabou de encerrar o turno numa das 4 direções cardeais da
## gaiola liberta a Maga na hora.
func _check_cage_release(finished_unit: Dictionary) -> void:
	if finished_unit.get("team", "") != "player":
		return
	for prisoner in units:
		if prisoner.get("team", "") != "player" or not prisoner.get("caged", false): continue
		var dx: int = absi(int(finished_unit["x"]) - int(prisoner["x"]))
		var dy: int = absi(int(finished_unit["y"]) - int(prisoner["y"]))
		if (dx == 1 and dy == 0) or (dx == 0 and dy == 1):
			_release_caged_unit(prisoner)

## A gaiola some, a Maga entra na fila de turnos (CT 80, ver GameConstants.
## CT_THRESHOLD = 100) com vida/mana cheias, na mesma posição da gaiola.
func _release_caged_mage(maga: Dictionary) -> void:
	_release_caged_unit(maga)

func _release_caged_unit(prisoner: Dictionary) -> void:
	prisoner.erase("caged")
	prisoner["ct"] = 80
	prisoner["hp"] = prisoner["maxHp"]
	prisoner["mp"] = prisoner.get("maxMp", prisoner.get("mp", 0))
	prisoner["hasMoved"] = false
	prisoner["hasActed"] = false
	prisoner["abilityUsedThisTurn"] = false
	var recruited_bard: bool = prisoner.get("spriteKey", "") == CAGED_BARDO_KEY
	if recruited_bard: campaign_bardo_unlocked = true
	var message := "Bardo entrou para o grupo!" if recruited_bard else "%s: Estou livre!" % prisoner["name"]
	_log(message)
	cage_release_events.append({"name":prisoner["name"],"x":prisoner["x"],"y":prisoner["y"],"bardoUnlocked":recruited_bard,"message":message})

func _apply_scenario_spawns(team: String, spawns: Array) -> void:
	var members := team_units(team)
	for i in range(mini(members.size(), spawns.size())):
		members[i]["x"] = spawns[i]["x"]
		members[i]["y"] = spawns[i]["y"]
		members[i]["facing"] = {"dx": 1, "dy": 0} if team == "player" else {"dx": 0, "dy": 1}
	# Catálogos novos podem ampliar um time antes dos mapas ganharem um slot
	# explícito. Coloca os excedentes no piso livre mais próximo do último
	# spawn, sem sobrepor unidade, estrutura ou terreno bloqueante.
	for i in range(spawns.size(), members.size()):
		var anchor: Dictionary = spawns[-1] if not spawns.is_empty() else {"x":0,"y":0}
		var placed := false
		for radius in range(1, maxi(board_width, board_height)):
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if absi(dx) + absi(dy) != radius: continue
					var x: int = int(anchor["x"]) + dx
					var y: int = int(anchor["y"]) + dy
					# _can_unit_anchor_at já cobre in_bounds/terreno bloqueante/
					# ocupante pra TODO o footprint da unidade (não só o tile
					# âncora) — necessário pra unidades 2x2 (ver ESTRADA INVERNO
					# TESTE) não caírem em cima de quem já foi posicionado ao
					# lado; pra unidades 1x1 de sempre o resultado é idêntico
					# aos 3 checks manuais que substituiu.
					if structure_at(x,y) != null or not _can_unit_anchor_at(members[i], x, y): continue
					members[i]["x"] = x; members[i]["y"] = y
					members[i]["facing"] = {"dx":1,"dy":0} if team == "player" else {"dx":0,"dy":1}
					placed = true
					break
				if placed: break
			if placed: break

func _setup_tower_features() -> void:
	tower_pickups = []
	# Biblioteca de cinco módulos na parede direita da sala central.
	var library_drop_y := rng.randi_range(4, 8)
	for y in range(4, 9):
		terrain_map[tile_key(11, y)] = {"type":"tower-bookshelf", "hp":8, "dropMana":y == library_drop_y}
	var candidates := _tower_random_floor_tiles()
	_shuffle_tiles(candidates)
	for i in 6:
		var puddle: Dictionary = candidates.pop_back()
		terrain_map[tile_key(puddle["x"], puddle["y"])] = {"type":"water", "towerPuddle":true}
	for i in 3:
		var vase: Dictionary = candidates.pop_back()
		terrain_map[tile_key(vase["x"], vase["y"])] = {"type":"tower-vase", "hp":5, "dropRolled":false}
	var trap_kinds := ["poison-arrow", "corrosive-gas", "poison-gas", "fire"]
	for kind in trap_kinds:
		var trap_tile: Dictionary = candidates.pop_back()
		traps.append({"tiles":[trap_tile], "ownerTeam":"environment", "triggered":false, "turnsLeft":null, "kind":kind, "visible":true})

func _setup_lua_valley(definition: Dictionary) -> void:
	tower_pickups = []
	for tile in definition.get("walls", []): terrain_map[tile_key(tile["x"],tile["y"])] = {"type":"lua-mountain"}
	for tile in definition.get("water", []): terrain_map[tile_key(tile["x"],tile["y"])] = {"type":"water","luaStream":true}
	for tile in definition.get("ladders", []): terrain_map[tile_key(tile["x"],tile["y"])] = {"type":"lua-ladder","walkable":true}
	_apply_scenario_spawns("player", definition.get("player_spawns", []))
	units = units.filter(func(unit): return unit["team"] == "player")
	units_by_key = {}
	for hero in units: units_by_key[hero["name"]] = hero
	var starts := _lua_initial_spawn_tiles(); _shuffle_tiles(starts)
	var kinds := ["rat","rat","rat","rat","snake","snake","snake","slime","slime","gnoll"]
	for i in kinds.size(): _spawn_lua_creature(kinds[i], starts[i])

func _setup_village(definition: Dictionary) -> void:
	tower_pickups = []
	village_archer_spawned = false
	for tile in definition.get("dirt", []):
		terrain_map[tile_key(tile["x"],tile["y"])] = {"type":"village-dirt","walkable":true}
	for tile in definition.get("water", []):
		terrain_map[tile_key(tile["x"],tile["y"])] = {"type":"water","villageStream":true}
	for tile in definition.get("blocked_tiles", []):
		var key := tile_key(tile["x"],tile["y"])
		if not terrain_map.has(key) or terrain_map[key].get("type", "") != "water":
			terrain_map[key] = {"type":"village-building"}
	var templates := Units.build()
	var warrior: Dictionary = (templates["guerreiro"] as Dictionary).duplicate(true)
	var spawn: Dictionary = definition["player_spawns"][0]
	warrior["x"] = spawn["x"]; warrior["y"] = spawn["y"]
	warrior["facing"] = {"dx":1,"dy":0}
	units = [warrior]
	units_by_key = {"guerreiro":warrior}
	var enemy_spawns: Array = definition.get("enemy_spawns", [])
	for i in range(mini(2, enemy_spawns.size())):
		var troll: Dictionary = (templates["troll"] as Dictionary).duplicate(true)
		troll["name"] = "Troll"
		# Troll ocupa 2x2: o ponto do cenário pode não comportar o corpo inteiro
		# (prédio/obstáculo numa das 4 casas), então usa a âncora livre mais próxima.
		var troll_anchor := _nearest_free_anchor(troll, int(enemy_spawns[i]["x"]), int(enemy_spawns[i]["y"]))
		troll["x"] = troll_anchor["x"]; troll["y"] = troll_anchor["y"]
		troll["facing"] = {"dx":-1,"dy":0}
		units.append(troll)
		units_by_key["troll_%d" % (i + 1)] = troll
	# Arqueiro já entra em campo desde o início, caído perto da casa em chamas
	# (ver "archer_reinforcement") — hp/mp zerados e SEM "turnsSinceDeath" de
	# propósito: sem essa chave ele fica fora de alive_units()/advance_ct_
	# until_ready() (não age, não decai pra alma) mas continua "ocupando" a
	# casa (occupant_at, ver dead_unit_at) e visível como corpo (ver
	# UnitToken.refresh() e "scriptedRevive"). "_deathHandled" pré-marcado
	# impede finalize_death_if_needed() de "processar a morte" dele no
	# primeiro _sync_visuals() (ele nunca morreu de verdade agora — sem essa
	# trava ganharia turnsSinceDeath=0 e viraria uma alma antes do turno 6).
	# maybe_revive_village_archer() o levanta no turno configurado, com
	# HP/MP cheios e o CT de "archer_reinforcement", e desfaz essa trava.
	var archer_entry: Dictionary = definition["archer_reinforcement"]
	var archer: Dictionary = (templates["arqueiro"] as Dictionary).duplicate(true)
	archer["x"] = archer_entry["x"]; archer["y"] = archer_entry["y"]
	archer["hp"] = 0
	archer["mp"] = 0
	archer["scriptedRevive"] = true
	archer["_deathHandled"] = true
	archer["facing"] = {"dx":1,"dy":0}
	archer["hasMoved"] = true; archer["hasActed"] = true
	units.append(archer)
	units_by_key["arqueiro"] = archer

## PORTO (cenário independente, pedido do usuário — ver
## ScenarioManager._porto_definition()): monta terrain_map a partir da
## estrada/água/píer/prédios/obstáculos da definição e spawna só 1 herói +
## 1 monstro genéricos (Units.build()) pra QA do mapa — sem roteiro/reforço,
## ao contrário de _setup_village().
##
## Terrain types usados aqui:
## - "porto-road": walkable=true (única, junto da ausência de entrada = grama,
##   ver is_battleable) — as DUAS únicas coisas battleable no PORTO.
## - "porto-water": água 100% bloqueada (type PRÓPRIO, não "water" — ver
##   comentário em BoardLayout.BLOCKING_TERRAIN_TYPES).
## - "porto-pier"/"porto-blocked": píer, casa, fonte, cercas, barris/caixas e
##   carroça — todos bloqueiam igual, só o "type" muda pra granularidade do
##   relatório de QA (ver is_battleable/testes).
func _setup_porto(definition: Dictionary) -> void:
	for tile in definition.get("road", []):
		terrain_map[tile_key(tile["x"],tile["y"])] = {"type":"porto-road","walkable":true}
	for tile in definition.get("water", []):
		terrain_map[tile_key(tile["x"],tile["y"])] = {"type":"porto-water"}
	for tile in definition.get("pier", []):
		terrain_map[tile_key(tile["x"],tile["y"])] = {"type":"porto-pier"}
	for building in definition.get("buildings", []):
		for oy in int(building["h"]):
			for ox in int(building["w"]):
				var key := tile_key(int(building["x"])+ox, int(building["y"])+oy)
				terrain_map[key] = {"type":"porto-blocked"}
	var fountain: Dictionary = definition.get("fountain", {})
	if not fountain.is_empty():
		for oy in int(fountain["h"]):
			for ox in int(fountain["w"]):
				var key := tile_key(int(fountain["x"])+ox, int(fountain["y"])+oy)
				terrain_map[key] = {"type":"porto-blocked"}
	# Obstáculos avulsos: só as células que ainda não viraram água/píer/prédio/
	# fonte acima entram como "porto-blocked" — blocked_tiles já vem com TODAS
	# as células (prédio+fonte+píer+obstáculos somados em
	# _porto_definition()), então sem essa checagem uma célula de píer/água
	# seria reescrita (inofensivo aqui, mas evita reescrita redundante).
	for tile in definition.get("blocked_tiles", []):
		var key := tile_key(tile["x"],tile["y"])
		if not terrain_map.has(key):
			terrain_map[key] = {"type":"porto-blocked"}
	var templates := Units.build()
	var hero: Dictionary = (templates["guerreiro"] as Dictionary).duplicate(true)
	var spawn: Dictionary = definition["player_spawns"][0]
	hero["x"] = spawn["x"]; hero["y"] = spawn["y"]
	hero["facing"] = {"dx":1,"dy":0}
	units = [hero]
	units_by_key = {"guerreiro":hero}
	var enemy_spawns: Array = definition.get("enemy_spawns", [])
	if not enemy_spawns.is_empty():
		var goblin: Dictionary = (templates["goblin"] as Dictionary).duplicate(true)
		goblin["name"] = "Goblin"
		goblin["x"] = enemy_spawns[0]["x"]; goblin["y"] = enemy_spawns[0]["y"]
		goblin["facing"] = {"dx":-1,"dy":0}
		units.append(goblin)
		units_by_key["goblin_1"] = goblin

## Regra central pedida pelo usuário pro PORTO, mas escrita como utilitário
## genérico (funciona pra qualquer cenário): elegibilidade de TERRENO pra
## batalha, ignorando quem esteja em cima agora (ver compute_reachable/
## _can_unit_anchor_at pra "andável AGORA", que também considera ocupante).
## Neste projeto não existe um "modo exploração" separado do "modo batalha" —
## todo tile andável já É um tile de batalha, então "battleable" aqui é
## sinônimo de "não bloqueado pelo terreno" (BoardLayout.BLOCKING_TERRAIN_
## TYPES). Grama é o chão implícito (nunca ganha entrada em terrain_map,
## ver qualquer _setup_*), por isso `terrain == null` conta como battleable.
func is_battleable(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	var terrain = terrain_at(x, y)
	if terrain == null:
		return true
	# Ravina do Desfiladeiro: property de TERRENO (sem unidade nenhuma em
	# jogo) — pra maioria das unidades é obstáculo, então conta como
	# bloqueada aqui, mesmo não estando em BoardLayout.BLOCKING_TERRAIN_TYPES
	# (que precisa deixar voadoras passarem, ver compute_reachable/
	# _can_unit_anchor_at). O overlay de debug (_draw_battleable_debug)
	# ainda distingue esse caso com uma 3ª cor (azul, "só voo").
	if terrain.get("type", "") == "desfiladeiro-chasm":
		return false
	return not BoardLayout.BLOCKING_TERRAIN_TYPES.has(terrain.get("type", ""))

## DESFILADEIRO (cenário independente, pedido do usuário — ver
## ScenarioManager._desfiladeiro_definition()): monta terrain_map a partir
## da ravina/ponte/árvores/obstáculos e spawna 1 herói + 1 monstro genéricos
## pra QA (sem roteiro), igual _setup_porto().
##
## Terrain types:
## - "desfiladeiro-bridge": battleable/walkable (a única travessia terrestre
##   da ravina).
## - "desfiladeiro-chasm": bloqueia terrestres, sobrevoável — NÃO está em
##   BoardLayout.BLOCKING_TERRAIN_TYPES (ver comentário lá); a checagem mora
##   em compute_reachable/_can_unit_anchor_at.
## - "tree": reaproveita o obstáculo já existente (HP/bloqueio/ruína de
##   BoardLayout.destructible_tile_types), só com "art" pintada de neve.
## - "desfiladeiro-blocked": pedra grande/monólito — obstáculo genérico,
##   bloqueia todo mundo (inclusive voadores, ver comentário na constante).
func _setup_desfiladeiro(definition: Dictionary) -> void:
	for tile in definition.get("bridge", []):
		terrain_map[tile_key(tile["x"],tile["y"])] = {"type":"desfiladeiro-bridge","walkable":true}
	for tile in definition.get("chasm", []):
		terrain_map[tile_key(tile["x"],tile["y"])] = {"type":"desfiladeiro-chasm"}
	for tree in definition.get("trees", []):
		terrain_map[tile_key(tree["x"],tree["y"])] = {"type":"tree","art":tree["art"],"hp":GameConstants.TREE_MAX_HP,"maxHp":GameConstants.TREE_MAX_HP}
	for tile in definition.get("blocked_tiles", []):
		var key := tile_key(tile["x"],tile["y"])
		if not terrain_map.has(key):
			terrain_map[key] = {"type":"desfiladeiro-blocked"}
	_mark_prop_tiles(definition, "desfiladeiro-blocked")
	var templates := Units.build()
	var hero: Dictionary = (templates["guerreiro"] as Dictionary).duplicate(true)
	var spawn: Dictionary = definition["player_spawns"][0]
	hero["x"] = spawn["x"]; hero["y"] = spawn["y"]
	hero["facing"] = {"dx":1,"dy":0}
	units = [hero]
	units_by_key = {"guerreiro":hero}
	var enemy_spawns: Array = definition.get("enemy_spawns", [])
	if not enemy_spawns.is_empty():
		var goblin: Dictionary = (templates["goblin"] as Dictionary).duplicate(true)
		goblin["name"] = "Goblin"
		goblin["x"] = enemy_spawns[0]["x"]; goblin["y"] = enemy_spawns[0]["y"]
		goblin["facing"] = {"dx":-1,"dy":0}
		units.append(goblin)
		units_by_key["goblin_1"] = goblin
	desfiladeiro_wind_last_turn = -1
	desfiladeiro_wind_events = []

## Vento gelado do DESFILADEIRO: a cada 5 turnos globais (5, 10, 15... —
## mesmo contador `global_turn_count` que a Vila já usa pros reforços
## dela, chamado de dentro de `begin_turn_for`) reaproveita EXATAMENTE o
## efeito do Cone de Gelo do Mago (`Spells.build()["iceCone"].
## appliesSpeedReduction`, a mesma lentidão -1 de agilidade por 2 turnos) e
## as MESMAS regras de afinidade elemental/resistência a gelo que já
## existem (elementAffinity["ice"], meio dano em mortos-vivos — os mesmos
## trechos usados por resolve_single_hit) — só com dano ambiental próprio
## (1-3, pedido explícito) e uma chance própria (80%) por unidade, em vez da
## mira/ângulo geométrico de um golpe de verdade (flanquear não faz sentido
## pra vento). Não chama finalize_action/consome CT de ninguém — é hazard de
## mapa, não uma ação de unidade (ver `begin_turn_for`: chamado fora do
## bloco "if not pvp_custom_battle", pra valer também no Modo PVP).
func maybe_trigger_desfiladeiro_wind() -> void:
	if scenario_id != ScenarioManager.DESFILADEIRO:
		return
	if global_turn_count <= 0 or global_turn_count % 5 != 0:
		return
	if desfiladeiro_wind_last_turn == global_turn_count:
		return
	desfiladeiro_wind_last_turn = global_turn_count
	var ice_cone: Dictionary = Spells.build()["iceCone"]
	var reduction: Dictionary = ice_cone["appliesSpeedReduction"]
	var hit_names: Array = []
	_log("Um vento gelado varre o desfiladeiro!")
	for u in units:
		if u["hp"] <= 0:
			continue
		if rng.randf() >= 0.8:
			continue
		var damage: int = rng.randi_range(1, 3)
		var affinity: Dictionary = u.get("elementAffinity", {}).get("ice", {})
		var mode: String = affinity.get("mode", "damage")
		if mode == "immune":
			_log("%s é imune ao vento gelado." % u["name"])
			continue
		if mode == "heal":
			var healing: int = int(round(damage * float(affinity.get("multiplier", 1.0))))
			var actual_heal: int = mini(healing, int(u["maxHp"]) - int(u["hp"]))
			u["hp"] = mini(int(u["maxHp"]), int(u["hp"]) + healing)
			_log("%s absorve o frio do vento gelado e recupera %d HP!" % [u["name"], actual_heal])
			continue
		var final_damage: int = int(round(damage * float(affinity.get("multiplier", 1.0))))
		if u.get("undead", false):
			final_damage = int(floor(final_damage * 0.5))
		u["hp"] -= final_damage
		var amount: int = int(reduction["amount"])
		u["speed"] -= amount
		add_status_effect(u, {"type":"slowed","turnsLeft":int(reduction["turns"]),"speedReduction":amount})
		_log("%s é atingido(a) pelo vento gelado! %d de dano e -%d de agilidade por %d turno(s)." % [u["name"], final_damage, amount, int(reduction["turns"])])
		hit_names.append(u["name"])
	desfiladeiro_wind_events.append({"turn":global_turn_count,"hit":hit_names})

## ESTRADA INVERNO (cenário independente, pedido do usuário — ver
## ScenarioManager._estrada_inverno_definition()): monta terrain_map a
## partir do rio/trilha/parede/escada/árvores/obstáculos e spawna 1 herói +
## 1 monstro genéricos pra QA (sem roteiro), igual _setup_porto()/_setup_
## desfiladeiro(). O monstro nasce NO PLATÔ de propósito, só alcançável pela
## escada, pra validar a regra de elevação na prática.
##
## Terrain types:
## - "water": o MESMO type comum já usado em todo cenário (Campo/Vila/Vale
##   de Lua/Torre) — sem type próprio, herda GameState.water_step_cost/
##   get_effective_hit_chance_breakdown automaticamente (ver comentário em
##   ScenarioManager._estrada_inverno_definition()).
## - "estrada-inverno-trail": battleable/walkable (a trilha).
## - "estrada-inverno-cliff": bloqueia todo mundo (parede do platô).
## - "estrada-inverno-stairs": battleable/walkable (único vão da parede).
## - "tree": reaproveita o obstáculo já existente, só com "art" nevada.
## - "estrada-inverno-blocked": poço/pedra grande/barril — obstáculo
##   genérico avulso, bloqueia todo mundo.
func _setup_estrada_inverno(definition: Dictionary) -> void:
	for tile in definition.get("water", []):
		terrain_map[tile_key(tile["x"],tile["y"])] = {"type":"water","estradaInvernoRiver":true}
	for tile in definition.get("trail", []):
		terrain_map[tile_key(tile["x"],tile["y"])] = {"type":"estrada-inverno-trail","walkable":true}
	for tile in definition.get("cliff", []):
		terrain_map[tile_key(tile["x"],tile["y"])] = {"type":"estrada-inverno-cliff"}
	for tile in definition.get("stairs", []):
		terrain_map[tile_key(tile["x"],tile["y"])] = {"type":"estrada-inverno-stairs","walkable":true}
	for tree in definition.get("trees", []):
		terrain_map[tile_key(tree["x"],tree["y"])] = {"type":"tree","art":tree["art"],"hp":GameConstants.TREE_MAX_HP,"maxHp":GameConstants.TREE_MAX_HP}
	for tile in definition.get("blocked_tiles", []):
		var key := tile_key(tile["x"],tile["y"])
		# Pedra/poço/barril sobre a trilha (andável) BLOQUEIA: blocked_tiles é a
		# fonte de verdade de "isto bloqueia" e vence terreno andável.
		if not terrain_map.has(key) or terrain_map[key].get("walkable", false):
			terrain_map[key] = {"type":"estrada-inverno-blocked"}
	_mark_prop_tiles(definition, "estrada-inverno-blocked")
	var templates := Units.build()
	var hero: Dictionary = (templates["guerreiro"] as Dictionary).duplicate(true)
	var spawn: Dictionary = definition["player_spawns"][0]
	hero["x"] = spawn["x"]; hero["y"] = spawn["y"]
	hero["facing"] = {"dx":1,"dy":0}
	units = [hero]
	units_by_key = {"guerreiro":hero}
	var enemy_spawns: Array = definition.get("enemy_spawns", [])
	if not enemy_spawns.is_empty():
		var goblin: Dictionary = (templates["goblin"] as Dictionary).duplicate(true)
		goblin["name"] = "Goblin"
		goblin["x"] = enemy_spawns[0]["x"]; goblin["y"] = enemy_spawns[0]["y"]
		goblin["facing"] = {"dx":-1,"dy":0}
		units.append(goblin)
		units_by_key["goblin_1"] = goblin

## Marca os obstáculos avulsos do cenário ("prop_tiles", ver
## ScenarioManager._prop_tiles) como prop — só onde o tile de fato virou
## `blocked_type`, pra nunca transformar prédio/penhasco/água num prop.
func _mark_prop_tiles(definition: Dictionary, blocked_type: String) -> void:
	for tile in definition.get("prop_tiles", []):
		var terrain = terrain_at(int(tile["x"]), int(tile["y"]))
		if terrain != null and terrain.get("type", "") == blocked_type:
			terrain["prop"] = true

## TEMPLO / CEMITÉRIO (ver HauntedScenery): terreno sólido vem de
## "blocked_tiles" (cada um com o próprio type: "scenery-wall" bloqueia todo
## mundo, "scenery-prop" só unidades de 1 casa) e "water". Caminhos, névoa e
## decalques são só visuais. Sem unidades fixas: os times padrão nascem nos
## spawns do cenário (heróis na entrada, inimigos no fundo do mapa).
func _setup_haunted_scenery(definition: Dictionary) -> void:
	for tile in definition.get("water", []):
		terrain_map[tile_key(tile["x"],tile["y"])] = {"type":"water"}
	for tile in definition.get("blocked_tiles", []):
		terrain_map[tile_key(tile["x"],tile["y"])] = {"type":String(tile["type"])}
	_apply_scenario_spawns("player", definition.get("player_spawns", []))
	_apply_scenario_spawns("enemy", definition.get("enemy_spawns", []))

## Reforço único da Vila: o Arqueiro já está em campo desde _setup_village()
## (caído, hp/mp 0, "scriptedRevive" — ver comentário lá), então aqui só
## levanta ele no turno configurado, não cria unidade nova. O gatilho usa a
## mesma contagem global de begin_turn_for; acontece exatamente quando o
## turno configurado começa.
func maybe_revive_village_archer() -> void:
	var definition := ScenarioManager.definition(ScenarioManager.VILLAGE)
	var entry: Dictionary = definition["archer_reinforcement"]
	if scenario_id != ScenarioManager.VILLAGE or village_archer_spawned or global_turn_count != int(entry["turn"]):
		return
	var archer: Dictionary = units_by_key.get("arqueiro", {})
	if archer.is_empty():
		return
	archer["hp"] = archer["maxHp"]
	archer["mp"] = archer.get("maxMp", 0)
	archer["ct"] = entry["ct"]
	archer.erase("scriptedRevive")
	archer.erase("_deathHandled")
	archer["hasMoved"] = false; archer["hasActed"] = false
	village_archer_spawned = true
	_log("O Arqueiro se levanta da casa em chamas, pronto pra lutar com %d de CT!" % int(entry["ct"]))

## Segundo reforço inimigo da Vila: um Goblin chega no turno configurado já
## com o CT de "goblin_reinforcement" — mesmo padrão dos demais reforços por
## turno (Arqueiro/Químico/Xamã), só que unidade nova (não estava em campo
## antes, ao contrário do Arqueiro caído). O Goblin chega sozinho: o elenco
## inimigo da Vila fica restrito a Troll e Goblin.
func maybe_spawn_village_goblin() -> void:
	var definition := ScenarioManager.definition(ScenarioManager.VILLAGE)
	var entry: Dictionary = definition["goblin_reinforcement"]
	if scenario_id != ScenarioManager.VILLAGE or village_goblin_spawned or global_turn_count != int(entry["turn"]):
		return
	var goblin_terrain = terrain_at(entry["x"], entry["y"])
	var goblin_tile_blocked: bool = goblin_terrain != null and not goblin_terrain.get("walkable", false)
	if goblin_tile_blocked or occupant_at(entry["x"], entry["y"]) != null:
		return
	var goblin: Dictionary = ((Units.build()["goblin"] as Dictionary).duplicate(true))
	goblin["name"] = "Goblin"
	goblin["x"] = entry["x"]; goblin["y"] = entry["y"]
	goblin["ct"] = entry["ct"]
	goblin["facing"] = {"dx":-1,"dy":0}
	goblin["hasMoved"] = false; goblin["hasActed"] = false
	units.append(goblin)
	units_by_key["goblin_2"] = goblin
	village_goblin_spawned = true
	_log("Um Goblin chega como reforço com %d de CT!" % int(entry["ct"]))

## Cria um bicho SPD (template de _tower_creature_templates()) no tile livre
## mais próximo de (origin_x, origin_y) — usado pelos reforços que "trazem
## companhia" (Goblin da Vila / Xamã da Floresta). CT 0 de propósito: essas
## criaturas chegam de carona, não com o CT alto do reforço principal.
func _spawn_companion_creature(kind: String, display_name: String, origin_x: int, origin_y: int, ct: int = 0) -> void:
	var tile: Variant = _first_free_tile_near(origin_x, origin_y)
	if tile == null:
		return
	var data: Dictionary = _tower_creature_templates()[kind].duplicate(true)
	data["name"] = display_name
	data["x"] = tile["x"]; data["y"] = tile["y"]
	data["ct"] = ct
	spawn_unit(display_name, data)

## Trilha central (colunas 5-7) fica livre de terreno (grama comum); as
## demais colunas viram "tree" de verdade — mesmo type do Campo, com HP e
## bloqueio (BoardLayout.BLOCKING_TERRAIN_TYPES/destructible_tile_types),
## só que com arte própria da Floresta ("art" vem de _forest_definition()
## em vez de BoardLayout.TREE_ART_VARIANTS). Só o Ladino (embaixo) e o Orc
## (em cima) começam em campo; o Químico entra depois via
## maybe_spawn_forest_chemist().
func _setup_forest(definition: Dictionary) -> void:
	for tile in definition.get("trees", []):
		terrain_map[tile_key(tile["x"], tile["y"])] = {
			"type": "tree", "art": tile["art"],
			"hp": GameConstants.TREE_MAX_HP, "maxHp": GameConstants.TREE_MAX_HP,
		}
	var templates := Units.build()
	var ladino: Dictionary = (templates["ladino"] as Dictionary).duplicate(true)
	var spawn: Dictionary = definition["player_spawns"][0]
	ladino["x"] = spawn["x"]; ladino["y"] = spawn["y"]
	ladino["facing"] = {"dx":0,"dy":-1}
	units = [ladino]
	units_by_key = {"ladino":ladino}
	var orc: Dictionary = (templates["orc"] as Dictionary).duplicate(true)
	var enemy_spawn: Dictionary = definition["enemy_spawns"][0]
	orc["x"] = enemy_spawn["x"]; orc["y"] = enemy_spawn["y"]
	orc["facing"] = {"dx":0,"dy":1}
	units.append(orc)
	units_by_key["orc"] = orc

## Reforço único da Floresta: o Químico aparece já em campo (não caído —
## diferente do Arqueiro da Vila) no turno configurado, pela parte de BAIXO
## do cenário (perto do Ladino), com HP/MP cheios (do próprio template) e o
## CT de "chemist_reinforcement".
func maybe_spawn_forest_chemist() -> void:
	var definition := ScenarioManager.definition(ScenarioManager.FOREST)
	var entry: Dictionary = definition["chemist_reinforcement"]
	if scenario_id != ScenarioManager.FOREST or forest_chemist_spawned or global_turn_count != int(entry["turn"]):
		return
	if terrain_at(entry["x"], entry["y"]) != null or occupant_at(entry["x"], entry["y"]) != null:
		return
	var chemist: Dictionary = ((Units.build()["quimico"] as Dictionary).duplicate(true))
	chemist["x"] = entry["x"]; chemist["y"] = entry["y"]
	chemist["ct"] = entry["ct"]
	chemist["facing"] = {"dx":0,"dy":-1}
	chemist["hasMoved"] = false; chemist["hasActed"] = false
	units.append(chemist)
	units_by_key["quimico"] = chemist
	forest_chemist_spawned = true
	_log("Químico chega como reforço com %d de CT, pronto pra lutar!" % int(entry["ct"]))

## Reforço único da Floresta (inimigo): o Xamã surge bem no meio da trilha,
## como se tivesse saído do meio das árvores, no turno configurado — mesmo
## padrão do Químico, só que pro time inimigo. O Xamã chega sozinho: o
## elenco inimigo da Floresta fica restrito a Orc e Xamã.
func maybe_spawn_forest_shaman() -> void:
	var definition := ScenarioManager.definition(ScenarioManager.FOREST)
	var entry: Dictionary = definition["shaman_reinforcement"]
	if scenario_id != ScenarioManager.FOREST or forest_shaman_spawned or global_turn_count != int(entry["turn"]):
		return
	if terrain_at(entry["x"], entry["y"]) != null or occupant_at(entry["x"], entry["y"]) != null:
		return
	var shaman: Dictionary = ((Units.build()["xama"] as Dictionary).duplicate(true))
	shaman["x"] = entry["x"]; shaman["y"] = entry["y"]
	shaman["ct"] = entry["ct"]
	shaman["facing"] = {"dx":0,"dy":1}
	shaman["hasMoved"] = false; shaman["hasActed"] = false
	units.append(shaman)
	units_by_key["xama"] = shaman
	forest_shaman_spawned = true
	_log("O Xamã surge do meio das árvores com %d de CT!" % int(entry["ct"]))

func _lua_initial_spawn_tiles() -> Array:
	var result: Array = []
	for y in range(2,11):
		for x in range(3,9):
			if terrain_at(x,y) == null and occupant_at(x,y) == null: result.append({"x":x,"y":y})
	return result

func _tower_random_floor_tiles() -> Array:
	var result: Array = []
	var reserved := {"6,1":true,"6,12":true}
	for unit_data in units:
		for tile in footprint_tiles(unit_data):
			reserved[tile_key(tile["x"], tile["y"])] = true
	for y in range(1, 12):
		for x in range(1, 12):
			var key := tile_key(x, y)
			var terrain = terrain_map.get(key)
			if reserved.has(key) or terrain != null: continue
			result.append({"x":x,"y":y})
	return result

## 10% de chance de contra-ataque em qualquer forma (aplica-se só a ataques
## corpo a corpo — counterWeapon é o próprio Pancada, alcance 1). A forma
## inicial (200 HP) não tem esquiva bônus; as formas pós-divisão ganham
## innateEvasion (ver _check_black_slime_split).
const BLACK_SLIME_COUNTER_CHANCE := 0.10

func _spawn_black_slime_boss() -> Dictionary:
	var data := black_slime_boss_data()
	return spawn_unit(String(data["name"]), data)

## Extraído de _spawn_black_slime_boss pra poder montar a ficha do Slime Negro
## SEM precisar de uma partida em andamento — usado pela tela de seleção de
## monstros do Modo PVP (PvpSetup, via lua_monster_data("goo",...)), mesmo
## motivo de dungeon_monster_data existir separado de _spawn_dungeon_enemy.
static func black_slime_boss_data(pos: Dictionary = {"x": 5, "y": 5}, display_name: String = "Slime Negro") -> Dictionary:
	var slam := {"name":"Pancada","icon":"💥","ctCost":50,"damageMin":5,"damageMax":10,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":1,"maxRange":1,"sfx":"melee"}
	var poison := {"name":"Nuvem Venenosa","icon":"☠","kind":"boss-poison","ctCost":50,"mpCost":5,"minRange":0,"maxRange":2,"areaRadius":2,"targetMode":"self-aoe","sfx":"poison"}
	return {"name":display_name,"team":"enemy","x":int(pos["x"]),"y":int(pos["y"]),"hp":200,"maxHp":200,"moveRange":3,"speed":20,"ct":0,"mp":10,"maxMp":10,"hasMoved":false,"hasActed":false,"statusEffects":[],"facing":{"dx":0,"dy":1},"spriteKey":"spd_goo","footprintWidth":2,"footprintHeight":2,"footprintSize":2,"slimeStage":0,"weapons":[slam],"spells":[poison],"counterAttackChance":BLACK_SLIME_COUNTER_CHANCE,"counterWeapon":slam}

func cast_black_slime_poison(caster: Dictionary) -> void:
	record_area_action(caster, {"name":"Nuvem Venenosa", "targetMode":"self-aoe", "kind":"boss-poison", "areaRadius":2, "sfx":"poison"}, caster)
	for target in alive_units():
		if target["team"] == caster["team"] or manhattan(caster, target) > 2: continue
		add_status_effect(target, {"type":"poison","damageMin":1,"damageMax":3,"turnsLeft":3,"ctDrainPerTurn":10})
		_log("%s é coberto pelo veneno do Slime Negro!" % target["name"])
	caster["mp"] -= 5
	caster["ct"] -= 50
	caster["hasActed"] = true

func _check_black_slime_split(slime: Dictionary) -> void:
	if slime.get("spriteKey", "") != "spd_goo" or slime.get("splitting", false): return
	var stage := int(slime.get("slimeStage", -1))
	# Pedido do usuário: no Modo PVP o Slime Negro começa com 80 HP (ver
	# PVP_MONSTER_STAT_OVERRIDES["goo"]) em vez dos 200 da campanha — limiar e
	# HP dos filhos escalam junto (80→divide aos 60 em 2x30→divide aos 20 em
	# 2x10), senão a divisão nunca aconteceria a partir de só 80 HP.
	var threshold: int
	var child_hp: int
	if pvp_custom_battle:
		threshold = 70 if stage == 0 else (20 if stage == 1 else -1)
		child_hp = 35 if stage == 0 else 10
	else:
		threshold = 140 if stage == 0 else (40 if stage == 1 else -1)
		child_hp = 70 if stage == 0 else 20
	if threshold < 0 or slime["hp"] > threshold: return
	slime["splitting"] = true
	var child_speed := 25 if stage == 0 else 30
	var damage_min := 4 if stage == 0 else 2
	var damage_max := 8 if stage == 0 else 4
	# Forma de 100 HP (1ª divisão): 10% mais difícil de acertar. Forma de
	# 25 HP (2ª divisão): 20% mais difícil — ver get_effective_hit_chance,
	# que já subtrai innateEvasion do mesmo jeito que a Cobra usa.
	var child_evasion := 0.10 if stage == 0 else 0.20
	var origin := {"x":slime["x"],"y":slime["y"]}
	# Os filhos herdam os status que o pai tinha no momento da divisão (em
	# vez de "purificar" tudo) — cada um recebe sua PRÓPRIA cópia, pra um
	# status novo aplicado num filho não vazar pro outro.
	var inherited_status: Array = (slime.get("statusEffects", []) as Array).duplicate(true)
	units.erase(slime)
	units_by_key.erase(slime["name"])
	for i in 2:
		var tile := _find_slime_split_tile(origin, i * 3)
		var slam := {"name":"Pancada","icon":"💥","ctCost":50,"damageMin":damage_min,"damageMax":damage_max,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":1,"maxRange":1,"sfx":"melee"}
		var poison := {"name":"Nuvem Venenosa","icon":"☠","kind":"boss-poison","ctCost":50,"mpCost":5,"minRange":0,"maxRange":2,"areaRadius":2,"targetMode":"self-aoe","sfx":"poison"}
		var child_name := "Slime Negro %d-%d" % [stage + 1, tower_spawn_count + i + 1]
		spawn_unit(child_name,{"name":child_name,"team":"enemy","x":tile["x"],"y":tile["y"],"hp":child_hp,"maxHp":child_hp,"moveRange":3,"speed":child_speed,"ct":0,"mp":10,"maxMp":10,"hasMoved":false,"hasActed":false,"statusEffects":inherited_status.duplicate(true),"facing":{"dx":0,"dy":1},"spriteKey":"spd_goo","footprintSize":1,"slimeStage":stage+1,"weapons":[slam],"spells":[poison],"innateEvasion":child_evasion,"counterAttackChance":BLACK_SLIME_COUNTER_CHANCE,"counterWeapon":slam})
	tower_spawn_count += 2
	_log("%s se divide em dois slimes, mantendo os status que já tinha!" % slime["name"])

func _find_slime_split_tile(origin: Dictionary, distance_offset: int) -> Dictionary:
	var candidates := [{"x":origin["x"]+distance_offset,"y":origin["y"]},{"x":origin["x"]-distance_offset,"y":origin["y"]},{"x":origin["x"],"y":origin["y"]+distance_offset},{"x":origin["x"],"y":origin["y"]-distance_offset}]
	for tile in candidates:
		if in_bounds(tile["x"],tile["y"]) and occupant_at(tile["x"],tile["y"]) == null and not BoardLayout.BLOCKING_TERRAIN_TYPES.has((terrain_at(tile["x"],tile["y"]) as Dictionary).get("type","") if terrain_at(tile["x"],tile["y"]) != null else ""): return tile
	return origin.duplicate()

func _shuffle_tiles(tiles: Array) -> void:
	for i in range(tiles.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = tiles[i]
		tiles[i] = tiles[j]
		tiles[j] = temp

func _log(message: String) -> void:
	event_log.append(message)

func _build_units() -> void:
	units = []
	units_by_key = {}
	var templates := Units.build()
	for key in templates.keys():
		var u: Dictionary = (templates[key] as Dictionary).duplicate(true)
		units.append(u)
		units_by_key[key] = u
	_shuffle_team_positions("player")
	_shuffle_team_positions("enemy")

## Embaralha as posições iniciais DENTRO do próprio time — cada personagem
## fica num dos slots fixos do time, só a ordem muda (pedido do usuário:
## partida nova deve reposicionar os personagens; equivalente a
## shuffleTeamPositions no JS, game.js:10481, chamado uma vez por time em
## resetGame()).
func _shuffle_team_positions(team: String) -> void:
	var members := team_units(team)
	var positions: Array = []
	for u in members:
		positions.append({"x": u["x"], "y": u["y"]})
	for i in range(positions.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = positions[i]
		positions[i] = positions[j]
		positions[j] = tmp
	for i in range(members.size()):
		members[i]["x"] = positions[i]["x"]
		members[i]["y"] = positions[i]["y"]

func unit(key: String) -> Dictionary:
	return units_by_key[key]

## Cria uma unidade mínima ad-hoc para cenários de teste isolados (mesmo
## espírito dos testes de tests/run_tests.js, que mutam x/y/hp direto dos
## personagens reais — aqui, quando o cenário não precisa de um personagem
## específico do roster, um synthetic unit evita depender de números de
## balanceamento de um personagem existente).
func spawn_unit(key: String, overrides: Dictionary = {}) -> Dictionary:
	var u := {
		"name": key, "team": "player", "x": 0, "y": 0,
		"hp": 20, "maxHp": 20, "moveRange": 3, "speed": 10,
		"ct": 0, "mp": 0, "maxMp": 0, "hasMoved": false, "hasActed": false,
		"statusEffects": [], "facing": {"dx": 1, "dy": 0},
	}
	for k in overrides.keys():
		u[k] = overrides[k]
	units.append(u)
	units_by_key[key] = u
	return u

func clear_units() -> void:
	units = []
	units_by_key = {}

## Para testes isolados de movimento/combate que não querem o mapa fixo
## (rio/árvores/casas/tendas/castelo/montanha) interferindo.
func clear_terrain_and_structures() -> void:
	terrain_map = {}
	structures = []
	elevation_map = {}

func _build_terrain_map() -> void:
	terrain_map = {}
	for terrain_type in BoardLayout.TERRAIN_LAYOUT.keys():
		for t in (BoardLayout.TERRAIN_LAYOUT[terrain_type] as Array):
			var entry := {"type": terrain_type}
			if terrain_type == "tree":
				var variants: Array = BoardLayout.TREE_ART_VARIANTS
				entry["art"] = variants[rng.randi() % variants.size()]
				entry["hp"] = GameConstants.TREE_MAX_HP
				entry["maxHp"] = GameConstants.TREE_MAX_HP
			elif terrain_type == "tent":
				var variants: Array = BoardLayout.TENT_ART_VARIANTS
				entry["art"] = variants[rng.randi() % variants.size()]
				entry["hp"] = GameConstants.TENT_MAX_HP
				entry["maxHp"] = GameConstants.TENT_MAX_HP
			elif terrain_type == "house":
				entry["hp"] = GameConstants.HOUSE_MAX_HP
				entry["maxHp"] = GameConstants.HOUSE_MAX_HP
			terrain_map[tile_key(t["x"], t["y"])] = entry

func _build_structures() -> void:
	structures = []
	for s in BoardLayout.STRUCTURES_LAYOUT:
		var tiles := []
		for t in (s["tiles"] as Array):
			tiles.append({"x": t["x"], "y": t["y"]})
		structures.append({
			"type": s["type"], "team": s["team"], "tiles": tiles,
			"hp": GameConstants.STRUCTURE_MAX_HP, "maxHp": GameConstants.STRUCTURE_MAX_HP,
			"destroyed": false,
		})

func _build_elevation_map() -> void:
	elevation_map = {}
	for t in (BoardLayout.TERRAIN_LAYOUT["water"] as Array):
		elevation_map[tile_key(t["x"], t["y"])] = -1

# --- Grade/consultas (game.js:4472-4926) ------------------------------------

func tile_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < board_width and y >= 0 and y < board_height

func terrain_at(x: int, y: int) -> Variant:
	return terrain_map.get(tile_key(x, y))

func structure_at(x: int, y: int) -> Variant:
	for s in structures:
		if s["destroyed"]:
			continue
		for t in (s["tiles"] as Array):
			if t["x"] == x and t["y"] == y:
				return s
	return null

func destroyed_structure_at(x: int, y: int) -> Variant:
	for s in structures:
		if not s["destroyed"]:
			continue
		for t in (s["tiles"] as Array):
			if t["x"] == x and t["y"] == y:
				return s
	return null

func elevation_at(x: int, y: int) -> int:
	var s = structure_at(x, y)
	if s != null:
		return GameConstants.CASTLE_ELEVATION if s["type"] == "castle" else GameConstants.MOUNTAIN_ELEVATION
	return elevation_map.get(tile_key(x, y), 0)

func alive_units() -> Array:
	return units.filter(func(u): return u["hp"] > 0)

func footprint_width(u: Dictionary) -> int:
	return maxi(1, int(u.get("footprintWidth", u.get("footprintSize", 1))))

func footprint_height(u: Dictionary) -> int:
	return maxi(1, int(u.get("footprintHeight", u.get("footprintSize", 1))))

## Unidade de 4 casas (Troll/Dragão/Salamandra/Goo grande). O corpo inteiro
## é barrado por terreno bloqueante (menos props, ver _terrain_blocks_unit) e
## nunca fica sobre uma estrutura (Castelo/Montanha) — ver _can_unit_anchor_at.
func is_large_unit(u: Dictionary) -> bool:
	return footprint_width(u) > 1 or footprint_height(u) > 1

## Prop do cenário (árvore, tenda, estante, barril, pedra avulsa...) — ver
## BoardLayout.LARGE_UNIT_PASSABLE_TERRAIN_TYPES.
func is_prop_terrain(terrain: Variant) -> bool:
	if terrain == null:
		return false
	return terrain.get("prop", false) or BoardLayout.LARGE_UNIT_PASSABLE_TERRAIN_TYPES.has(terrain.get("type", ""))

## Terreno bloqueante PARA ESTA unidade. Pedido do usuário: unidades de 4
## casas ignoram props (atravessam e param em cima); os demais continuam
## obstruídos por eles.
func _terrain_blocks_unit(u: Dictionary, terrain: Variant) -> bool:
	if terrain == null:
		return false
	if is_large_unit(u) and is_prop_terrain(terrain):
		return false
	return BoardLayout.BLOCKING_TERRAIN_TYPES.has(terrain.get("type", ""))

## Caixa do corpo (limites inclusivos). Corpo 1x1: left == right, top == bottom.
func _body_box(u: Dictionary) -> Dictionary:
	return {"left": int(u["x"]), "top": int(u["y"]),
		"right": int(u["x"]) + footprint_width(u) - 1, "bottom": int(u["y"]) + footprint_height(u) - 1}

## Direção (-1/0/1 por eixo) de `tile` em relação ao CORPO de `caster`: fora da
## caixa num eixo = ±1; dentro da faixa do corpo naquele eixo = 0. Corpo 1x1 =
## o _signi de sempre (âncora).
func body_direction(caster: Dictionary, tile: Dictionary) -> Vector2i:
	var box := _body_box(caster)
	var tx := int(tile["x"])
	var ty := int(tile["y"])
	return Vector2i(
		1 if tx > box["right"] else (-1 if tx < box["left"] else 0),
		1 if ty > box["bottom"] else (-1 if ty < box["top"] else 0))

## Igual a body_direction, mas pra habilidades só-cardeais: se o tile está fora
## da caixa nos dois eixos (canto de uma faixa), vale o eixo mais distante.
## Corpo 1x1 não muda (mantém o comportamento original, inclusive diagonal).
func _cardinal_direction(caster: Dictionary, tile: Dictionary) -> Vector2i:
	var dir := body_direction(caster, tile)
	if is_large_unit(caster) and dir.x != 0 and dir.y != 0:
		var box := _body_box(caster)
		var out_x: int = absi(int(tile["x"]) - (box["right"] if dir.x > 0 else box["left"]))
		var out_y: int = absi(int(tile["y"]) - (box["bottom"] if dir.y > 0 else box["top"]))
		return Vector2i(dir.x, 0) if out_x >= out_y else Vector2i(0, dir.y)
	return dir

## Casas do corpo de onde uma habilidade sai na direção (dx,dy): corpo 1x1 = a
## própria casa; corpo grande cardeal = as casas da borda daquele lado (2 no
## 2x2, ou seja, o ataque cobre os 2 quadrados e não só 1); diagonal = o canto.
func body_lane_origins(u: Dictionary, dx: int, dy: int) -> Array:
	var box := _body_box(u)
	var xs: Array = range(box["left"], box["right"] + 1) if dx == 0 else [box["right"] if dx > 0 else box["left"]]
	var ys: Array = range(box["top"], box["bottom"] + 1) if dy == 0 else [box["bottom"] if dy > 0 else box["top"]]
	var result: Array = []
	for y in ys:
		for x in xs:
			result.append({"x": x, "y": y})
	return result

## Casa logo fora do corpo na direção (dx,dy) — alvo "de mira" usado pela IA
## e por testes. Corpo 1x1: âncora + (dx,dy), como antes.
func body_probe_tile(u: Dictionary, dx: int, dy: int) -> Dictionary:
	var lane: Dictionary = body_lane_origins(u, dx, dy)[0]
	return {"x": lane["x"] + dx, "y": lane["y"] + dy}

func footprint_tiles(u: Dictionary, anchor_x: Variant = null, anchor_y: Variant = null) -> Array:
	var origin_x := int(u["x"] if anchor_x == null else anchor_x)
	var origin_y := int(u["y"] if anchor_y == null else anchor_y)
	var result: Array = []
	for oy in footprint_height(u):
		for ox in footprint_width(u):
			result.append({"x":origin_x + ox, "y":origin_y + oy})
	return result

func unit_contains_tile(u: Dictionary, x: int, y: int) -> bool:
	return x >= int(u["x"]) and x < int(u["x"]) + footprint_width(u) and y >= int(u["y"]) and y < int(u["y"]) + footprint_height(u)

func units_in_tiles(tiles: Array) -> Array:
	var result: Array = []
	for tile in tiles:
		var found = unit_at(int(tile["x"]), int(tile["y"]))
		if found != null and not result.has(found):
			result.append(found)
	return result

func units_cardinally_aligned(a: Dictionary, b: Dictionary) -> bool:
	var overlap_x := int(a["x"]) <= int(b["x"]) + footprint_width(b) - 1 and int(b["x"]) <= int(a["x"]) + footprint_width(a) - 1
	var overlap_y := int(a["y"]) <= int(b["y"]) + footprint_height(b) - 1 and int(b["y"]) <= int(a["y"]) + footprint_height(a) - 1
	return overlap_x or overlap_y

func unit_at(x: int, y: int) -> Variant:
	for u in alive_units():
		# Montado na Vestruz: o quadrado é ocupado pela montaria (é ela quem
		# leva os ataques); o cavaleiro não conta como ocupante à parte.
		if u.get("mountedOn", "") != "":
			continue
		if unit_contains_tile(u, x, y):
			return u
	return null

## Cadáver ainda ressuscitável (ver game.js:6321) — só existe depois que a
## Fase 3 (morte/ressurreição) marcar `turnsSinceDeath` na unidade; até lá
## nenhuma unidade morta conta como cadáver aqui, exatamente como no JS
## original (checa `turnsSinceDeath !== undefined`).
func dead_unit_at(x: int, y: int) -> Variant:
	for u in units:
		# "turnsSinceDeath": cadáver ressuscitável normal. "scriptedRevive":
		# corpo de evento roteirizado (ex.: Arqueiro da Vila, ver _setup_village)
		# — ainda não tem turnsSinceDeath porque nunca "morreu" de verdade,
		# mas o corpo precisa ocupar o tile igual a um cadáver comum.
		if u["hp"] <= 0 and (u.has("turnsSinceDeath") or u.get("scriptedRevive", false)) and unit_contains_tile(u, x, y):
			return u
	return null

func occupant_at(x: int, y: int) -> Variant:
	var u = unit_at(x, y)
	if u != null:
		return u
	return dead_unit_at(x, y)

## Só 1 unidade por vez ocupa a estrutura inteira (os 9 tiles contam como 1
## vaga só). Comparação por `name` (não por identidade de objeto: Dictionary
## em GDScript compara por valor, não por referência, ao contrário do
## `!==` do JS) — seguro aqui porque nomes de unidade são únicos no roster.
func structure_occupant(structure: Dictionary) -> Variant:
	for u in alive_units():
		for t in (structure["tiles"] as Array):
			if t["x"] == u["x"] and t["y"] == u["y"]:
				return u
	return null

# --- Movimento (game.js:5442-5648) ------------------------------------------

## Voa por cima de armadilhas sem custo extra nem gatilho. Armadilhas do Ladino
## não aumentam o custo: ao serem pisadas, interrompem o movimento no próprio
## quadrado. Armadilhas do ambiente continuam custando um ponto extra.
func trap_step_cost(u: Dictionary, x: int, y: int) -> int:
	if u.get("flying", false):
		return 1
	for trap in traps:
		if trap["ownerTeam"] == u["team"]:
			continue
		for t in (trap["tiles"] as Array):
			if t["x"] == x and t["y"] == y:
				return 1 if trap.get("instant", false) else 2
	return 1

## Água custa 2 pra entrar; quem voa passa sem o custo extra.
func water_step_cost(u: Dictionary, x: int, y: int) -> int:
	if u.get("flying", false):
		return 1
	var terrain = terrain_at(x, y)
	return 2 if (terrain != null and terrain["type"] == "water") else 1

## Interface reutilizável para terrenos perigosos. Hoje existe lava; novos
## hazards podem declarar seu próprio movementCost sem alterar o pathfinder.
func hazard_step_cost(_u: Dictionary, x: int, y: int) -> int:
	var terrain = terrain_at(x, y)
	if terrain == null or terrain.get("type", "") != "hazard":
		return 1
	return maxi(1, int(terrain.get("movementCost", 1)))

## Soma TODAS as fontes de custo extra (armadilha inimiga + água) — as duas
## somam se coincidirem.
func step_cost(u: Dictionary, x: int, y: int) -> int:
	return trap_step_cost(u, x, y) + water_step_cost(u, x, y) + hazard_step_cost(u, x, y) - 2

## Dijkstra (não BFS puro) porque atravessar uma armadilha inimiga custa 2
## em vez de 1. Tabuleiro pequeno (13x13): busca linear pelo menor custo não
## visitado a cada passo, sem heap. Guarda cameFrom/custos em
## last_reachable_came_from/last_reachable_costs pra reconstruct_path.
func compute_reachable(u: Dictionary) -> Array:
	# Montado: quem se move é a montaria (MOV e voo dela), levando o cavaleiro.
	var carrying_mount = mount_of(u)
	if carrying_mount != null:
		return compute_reachable(carrying_mount)
	var dist := {}
	var came_from := {}
	var visited := {}
	var start_key := tile_key(u["x"], u["y"])
	dist[start_key] = 0
	var result := []

	while true:
		var current_key = null
		var current_dist: int = 999999
		for key in dist.keys():
			if not visited.has(key) and dist[key] < current_dist:
				current_dist = dist[key]
				current_key = key
		if current_key == null or current_dist > u["moveRange"]:
			break
		visited[current_key] = true
		var parts: PackedStringArray = current_key.split(",")
		var cx := int(parts[0])
		var cy := int(parts[1])

		# Só entra no resultado (pode "parar aqui") se o tile estiver vazio —
		# mesmo um tile atravessado voando não é destino válido.
		if current_dist > 0 and _can_unit_anchor_at(u, cx, cy):
			result.append({"x": cx, "y": cy})

		# Casa/Castelo/Montanha: "pode parar, não atravessa" — currentDist>0
		# obrigatório, senão uma unidade que JÁ começou o turno ali ficaria
		# presa, incapaz de sair.
		# Unidade 2x2 ignora a casa (asset do cenário) e atravessa.
		var terrain_here = terrain_at(cx, cy)
		if current_dist > 0 and terrain_here != null and terrain_here["type"] == "house" and not is_large_unit(u):
			continue
		var structure_here = structure_at(cx, cy)
		if current_dist > 0 and structure_here != null:
			continue

		var dirs := [[1, 0], [-1, 0], [0, 1], [0, -1]]
		for d in dirs:
			var nx: int = cx + d[0]
			var ny: int = cy + d[1]
			if not in_bounds(nx, ny):
				continue
			if (footprint_width(u) > 1 or footprint_height(u) > 1) and not _can_unit_anchor_at(u, nx, ny):
				continue
			var key := tile_key(nx, ny)
			if visited.has(key):
				continue

			# Pedido do usuário: cadáver (ainda na janela de ressurreição de 3
			# rodadas) não obstrui passagem — qualquer um pode atravessar o
			# tile dele livremente. _can_unit_anchor_at (chamado logo acima,
			# no "pode parar aqui") continua barrando esse tile como DESTINO
			# via occupant_at, então ninguém termina o movimento em cima de um
			# corpo, só não é mais bloqueado ao passar por ele no caminho.

			# Aliado nunca bloqueia PASSAGEM, só não pode ser destino
			# (occupant_at acima já garante isso). Inimigo bloqueia a menos
			# que a unidade voe por cima.
			var occupant = unit_at(nx, ny)
			if occupant != null:
				var same_team: bool = occupant["team"] == u["team"]
				if not same_team and not u.get("flying", false):
					continue

			# No Campo, árvores ocupam o espaço, mas não formam uma parede:
			# podem ser atravessadas durante o caminho, porém _can_unit_anchor_at
			# continua impedindo que alguém termine o movimento nelas.
			var terrain = terrain_at(nx, ny)
			if _terrain_blocks_transit(terrain, u):
				continue
			# Ravina do Desfiladeiro: bloqueia só quem não voa — mesma ideia de
			# exceção `flying` já usada acima pra ocupante inimigo/cadáver, só
			# que pro terreno em si. Não é um type em BLOCKING_TERRAIN_TYPES de
			# propósito (ver comentário na constante), senão bloquearia
			# voadores também.
			if terrain != null and terrain.get("type", "") == "desfiladeiro-chasm" and not u.get("flying", false):
				continue

			# Castelo/Montanha: exclusivo do time dono, vaga única (1 por vez).
			var structure = structure_at(nx, ny)
			if structure != null:
				if structure["team"] != u["team"]:
					continue
				var struct_occupant = structure_occupant(structure)
				if struct_occupant != null and struct_occupant["name"] != u["name"]:
					continue

			# Altura: só se aplica a terreno aberto — isenta os dois lados da
			# transição (origem OU destino sendo estrutura), senão a unidade
			# entra no castelo mas fica travada lá dentro pra sempre.
			if structure == null and structure_at(cx, cy) == null and not u.get("flying", false):
				var height_delta: int = abs(elevation_at(nx, ny) - elevation_at(cx, cy))
				if height_delta > GameConstants.MAX_CLIMB_HEIGHT:
					continue

			var new_dist: int = current_dist + step_cost(u, nx, ny)
			if new_dist > u["moveRange"]:
				continue
			if not dist.has(key) or new_dist < dist[key]:
				dist[key] = new_dist
				came_from[key] = {"x": cx, "y": cy}

	last_reachable_came_from = came_from
	last_reachable_costs = dist
	return result

func _can_unit_anchor_at(u: Dictionary, x: int, y: int) -> bool:
	for tile in footprint_tiles(u, x, y):
			var tx := int(tile["x"])
			var ty := int(tile["y"])
			if not in_bounds(tx, ty): return false
			var terrain = terrain_at(tx, ty)
			if _terrain_blocks_unit(u, terrain): return false
			# Corpo de 4 casas nunca invade Castelo/Montanha (a regra de vaga
			# única/time dono de compute_reachable só olha o tile-âncora).
			if is_large_unit(u) and structure_at(tx, ty) != null: return false
			# Ravina do Desfiladeiro: mesma exceção de voo do terreno em
			# compute_reachable — quem voa PODE parar sobre a ravina, quem não
			# voa nunca.
			if terrain != null and terrain.get("type", "") == "desfiladeiro-chasm" and not u.get("flying", false): return false
			var occupant = occupant_at(tx, ty)
			if occupant != null and occupant != u: return false
	return true

## Só terreno/limites/estrutura (ignora ocupantes) — usado pelo Atropelar de
## corpo grande, que passa POR CIMA de inimigos mas não de morro/parede.
func _large_body_blocked_at(u: Dictionary, x: int, y: int) -> bool:
	for tile in footprint_tiles(u, x, y):
		var tx := int(tile["x"])
		var ty := int(tile["y"])
		if not in_bounds(tx, ty) or _terrain_blocks_unit(u, terrain_at(tx, ty)) or structure_at(tx, ty) != null:
			return true
	return false

func _terrain_blocks_transit(terrain: Variant, u: Dictionary = {}) -> bool:
	if terrain == null:
		return false
	# Regra exclusiva do cenário Campo: árvore não é uma barreira de rota.
	if scenario_id == ScenarioManager.FIELD and terrain.get("type", "") == "tree":
		return false
	if not u.is_empty():
		return _terrain_blocks_unit(u, terrain)
	return BoardLayout.BLOCKING_TERRAIN_TYPES.has(terrain.get("type", ""))

## Reconstrói o caminho (sem incluir o tile de partida) até (dest_x,dest_y)
## usando o cache do último compute_reachable() — só confiável logo após
## essa chamada, antes de outro compute_reachable rodar.
func reconstruct_path(dest_x: int, dest_y: int) -> Array:
	var path := []
	var cur_key := tile_key(dest_x, dest_y)
	while last_reachable_came_from.has(cur_key):
		var parts: PackedStringArray = cur_key.split(",")
		path.push_front({"x": int(parts[0]), "y": int(parts[1])})
		var prev = last_reachable_came_from[cur_key]
		cur_key = tile_key(prev["x"], prev["y"])
	return path

## Dano (uma vez por armadilha distinta, não por tile) e revelação da área
## inteira no primeiro gatilho. Aliados do dono nunca acionam.
func apply_trap_crossings(u: Dictionary, path_tiles: Array) -> void:
	if u.get("flying", false):
		# Voo ignora armadilhas, mas hazards de ambiente declarados pelo tile
		# (como calor da lava) continuam sendo processados para todo personagem.
		_apply_tower_path_features(u, path_tiles)
		return
	var triggered_indices := {}
	for step in path_tiles:
		for i in range(traps.size()):
			var trap: Dictionary = traps[i]
			# Pedido do usuário: armadilha do Ladino (identificada por
			# "ownerName") só poupa quem a instalou, não o time inteiro dele —
			# aliados podem sofrer o dano normalmente. Armadilhas do ambiente
			# (sem "ownerName") continuam usando a imunidade por time de antes.
			var is_immune: bool = trap["ownerName"] == u["name"] if trap.has("ownerName") else trap["ownerTeam"] == u["team"]
			if is_immune or trap.get("triggered", false) or triggered_indices.has(i):
				continue
			for t in (trap["tiles"] as Array):
				if t["x"] == step["x"] and t["y"] == step["y"]:
					triggered_indices[i] = true
					break
	# Pedido do usuário: armadilha "instant" (do Ladino) some assim que
	# alguém a aciona e sofre o dano, em vez de ficar revelada por 3 turnos.
	var consumed_indices := {}
	for i in triggered_indices.keys():
		var trap: Dictionary = traps[i]
		_trigger_tower_trap(trap, u)
		if trap.get("instant", false):
			consumed_indices[i] = true
			_log("A armadilha se desfaz depois de acionada!")
		elif not trap["triggered"]:
			trap["triggered"] = true
			trap["turnsLeft"] = 3
			_log("A armadilha é revelada!")
	if not consumed_indices.is_empty():
		var remaining_traps: Array = []
		for i in range(traps.size()):
			if not consumed_indices.has(i):
				remaining_traps.append(traps[i])
		traps = remaining_traps
	if u["hp"] <= 0:
		u["hp"] = 0
		_log("%s foi derrotado!" % u["name"])
	_apply_tower_path_features(u, path_tiles)

func _trigger_tower_trap(trap: Dictionary, trigger_unit: Dictionary) -> void:
	var kind := String(trap.get("kind", "basic"))
	if kind == "basic":
		var damage := rng.randi_range(1, 3)
		trigger_unit["hp"] -= damage
		_log("%s pisa numa armadilha e sofre %d de dano!" % [trigger_unit["name"], damage])
		return
	var center: Dictionary = trap["tiles"][0]
	if kind == "poison-arrow":
		var arrow_damage := rng.randi_range(1, 3)
		trigger_unit["hp"] -= arrow_damage
		add_status_effect(trigger_unit, {"type":"poison", "damageMin":1, "damageMax":3, "turnsLeft":3, "ctDrainPerTurn":10})
		_log("Uma flecha envenenada acerta %s por %d de dano!" % [trigger_unit["name"], arrow_damage])
		return
	for affected in alive_units():
		if manhattan(affected, center) > 6: continue
		if kind == "corrosive-gas":
			affected["hp"] = maxi(0, affected["hp"] - rng.randi_range(1, 3))
			add_status_effect(affected, {"type":"weakened", "turnsLeft":2, "amount":1})
		elif kind == "poison-gas":
			add_status_effect(affected, {"type":"poison", "damageMin":1, "damageMax":3, "turnsLeft":3, "ctDrainPerTurn":10})
		elif kind == "fire" and not is_on_water(affected):
			add_status_effect(affected, {"type":"burned", "damageMin":2, "damageMax":4, "turnsLeft":3})
	_log("A armadilha de %s cobre uma área em losango de raio 6!" % kind)

func _apply_tower_path_features(u: Dictionary, path_tiles: Array) -> void:
	if scenario_id not in [ScenarioManager.TOWER, ScenarioManager.TOWER_FLOOR_2, ScenarioManager.TOWER_FLOOR_3, ScenarioManager.TOWER_FLOOR_4, ScenarioManager.LUA_VALLEY] or u["hp"] <= 0: return
	for step in path_tiles:
		var key := tile_key(step["x"], step["y"])
		var terrain = terrain_map.get(key)
		if scenario_id in [ScenarioManager.TOWER, ScenarioManager.TOWER_FLOOR_2, ScenarioManager.TOWER_FLOOR_3, ScenarioManager.TOWER_FLOOR_4] and terrain != null and terrain.get("type", "") == "tower-door" and not terrain.get("opened", false):
			terrain["opened"] = true
			_log("A porta se abre quando %s atravessa a passagem." % u["name"])
		if terrain != null and terrain.get("type", "") == "hazard":
			var damage_on_enter := int(terrain.get("damageOnEnter", 0))
			if damage_on_enter > 0:
				u["hp"] = maxi(0, int(u["hp"]) - damage_on_enter)
				_log("%s pisa na lava e sofre %d de dano de queimadura!" % [u["name"], damage_on_enter])
				if u["hp"] <= 0:
					_log("%s foi derrotado pelo calor extremo!" % u["name"])
					break
			# Névoa venenosa do 2º Andar: sem dano instantâneo, só aplica o
			# ENVENENADO — mesmo status/valores do Xamã (ver linha ~494) — daí
			# em diante o sistema normal de veneno cuida do resto.
			if terrain.get("hazard", "") == "poison-gas":
				add_status_effect(u, {"type": "poison", "damageMin": 1, "damageMax": 3, "turnsLeft": 3, "ctDrainPerTurn": 10})
				_log("%s atravessa a névoa venenosa e fica envenenado(a)!" % u["name"])
		if terrain != null and terrain.get("type", "") == "tower-grass" and rng.randf() < 0.25:
			var healed := mini(2, u["maxHp"] - u["hp"])
			var restored := mini(2, u.get("maxMp", 0) - u.get("mp", 0))
			u["hp"] += healed
			if u.has("maxMp"): u["mp"] += restored
			_log("%s encontra uma gota de orvalho no mato: +%d HP e +%d MP." % [u["name"], healed, restored])
		_collect_tower_pickup_at(u, step["x"], step["y"])

func _collect_tower_pickup_at(u: Dictionary, x: int, y: int) -> void:
	for pickup in tower_pickups.duplicate():
		if pickup["x"] != x or pickup["y"] != y: continue
		var amount := int(pickup["amount"])
		if pickup["kind"] == "hp": u["hp"] = mini(u["maxHp"], u["hp"] + amount)
		elif u.has("maxMp"): u["mp"] = mini(u["maxMp"], u["mp"] + amount)
		_log("%s coleta uma poção: +%d %s." % [u["name"], amount, "HP" if pickup["kind"] == "hp" else "MP"])
		tower_pickups.erase(pickup)

func manhattan(a: Dictionary, b: Dictionary) -> int:
	# Distância entre as bordas dos corpos, não apenas entre as âncoras.
	# Para o Slime Negro 2x2 isto torna cada uma das oito casas cardeais
	# tangentes uma casa de alcance, permitindo atacar qualquer lado do chefe.
	var a_left := int(a["x"])
	var a_right := a_left + footprint_width(a) - 1
	var a_top := int(a["y"])
	var a_bottom := a_top + footprint_height(a) - 1
	var b_left := int(b["x"])
	var b_right := b_left + footprint_width(b) - 1
	var b_top := int(b["y"])
	var b_bottom := b_top + footprint_height(b) - 1
	var dx := maxi(0, maxi(a_left - b_right, b_left - a_right))
	var dy := maxi(0, maxi(a_top - b_bottom, b_top - a_bottom))
	return dx + dy

# --- Status effects: predicados (game.js:5012-5236) -------------------------

func _has_status(u: Dictionary, type: String) -> bool:
	for e in u.get("statusEffects", []):
		if e["type"] == type:
			return true
	return false

func is_rooted(u: Dictionary) -> bool:
	return _has_status(u, "root")

func is_poisoned(u: Dictionary) -> bool:
	return _has_status(u, "poison")

func is_invisible(u: Dictionary) -> bool:
	return _has_status(u, "invisible")

func _update_goblin_cowardice(u: Dictionary) -> void:
	if u.get("spriteKey", "") != "goblin": return
	var active := bool(u.get("strategicCowardice", false))
	var should_be_active := int(u.get("hp", 0)) > 0 and int(u.get("hp", 0)) * 100 < int(u.get("maxHp", 1)) * 30
	if should_be_active and not active:
		u["moveRange"] += 2
		u["strategicCowardice"] = true
	elif not should_be_active and active:
		u["moveRange"] = maxi(1, int(u["moveRange"]) - 2)
		u["strategicCowardice"] = false

## Ofuscado (Luz da Fada): reduz a própria chance de acerto de quem foi
## atingido, não a de quem o ataca.
func is_blinded(u: Dictionary) -> bool:
	return _has_status(u, "blinded")

## Atordoado por som (Explosão Sonora da Fada): mesmo efeito de is_blinded,
## mas empilha com ele em vez de travar num valor fixo (ver
## get_effective_hit_chance).
func is_dazed(u: Dictionary) -> bool:
	return _has_status(u, "dazed")

func is_paralyzed(u: Dictionary) -> bool:
	return _has_status(u, "paralyzed")

## Água apaga fogo: quem está molhado não pega (nem continua) queimando —
## voando não conta como "estar na água de verdade".
func is_on_water(u: Dictionary) -> bool:
	if u.get("flying", false):
		return false
	var terrain = terrain_at(u["x"], u["y"])
	return terrain != null and terrain["type"] == "water"

func _unit_footprint_touches_water(u: Dictionary) -> bool:
	for tile in footprint_tiles(u):
			var terrain = terrain_at(tile["x"], tile["y"])
			if terrain != null and (terrain.get("type", "") == "water" or terrain.get("towerStream", false)): return true
	return false

## Só magias de área "cobrem o terreno" o bastante pra achar quem está
## invisível — armas e magias de alvo único (qualquer alcance) não acertam.
func bypasses_invisibility(item: Dictionary) -> bool:
	return item.has("mpCost") and GameConstants.AOE_TARGET_MODES.has(item.get("targetMode"))

## Usado por magias que rolam acerto por conta própria (não passam por
## resolve_single_hit) mas precisam da mesma regra de invisibilidade.
func blocked_by_invisibility(item: Dictionary, target: Dictionary) -> bool:
	return not bypasses_invisibility(item) and is_invisible(target)

## Duração SOMA (não pega só a maior) quando o mesmo tipo de status já está
## ativo — ex: queimadura da Flecha de Fogo + Tiro Explosivo vira 1 status só
## com os turnos das duas fontes somados. `weakened` é exceção: moveReduction
## também soma (o moveRange já foi reduzido pela soma no ponto de chamada).
## Imunidade genérica a status (pedido do usuário: Demônio das Chamas é
## imune a Queimando, sem checar por nome de unidade/habilidade em lugar
## nenhum — só o campo de dados `statusImmunities`, mesmo padrão de
## `elementAffinity`). Único ponto de checagem: toda aplicação de status do
## jogo passa por add_status_effect, então qualquer imunidade futura basta
## declarar o tipo aqui, sem espalhar condições pelo resto do código.
func add_status_effect(u: Dictionary, effect: Dictionary) -> void:
	if (u.get("statusImmunities", []) as Array).has(effect["type"]):
		return
	if not u.has("statusEffects"):
		u["statusEffects"] = []
	var effects: Array = u["statusEffects"]
	if GameConstants.DOT_HOT_TYPES.has(effect["type"]):
		var existing = null
		for e in effects:
			if e["type"] == effect["type"]:
				existing = e
				break
		if existing != null:
			var turns_left: int = existing["turnsLeft"] + effect["turnsLeft"]
			var merged_move_reduction = null
			if effect["type"] == "weakened":
				merged_move_reduction = existing["moveReduction"] + effect["moveReduction"]
			for k in effect.keys():
				existing[k] = effect[k]
			existing["turnsLeft"] = turns_left
			if merged_move_reduction != null:
				existing["moveReduction"] = merged_move_reduction
			return
	effects.append(effect)

## Antagonismo elemental (pedido do usuário): ser atingido por um ataque de
## gelo apaga a Queimadura vigente, e ser atingido por um ataque de fogo apaga
## a Lentidão vigente (Raio de Gelo/Flecha de Gelo/Bomba de Gelo/Cone de
## Gelo) — desfazendo a redução de agilidade, igual a remoção normal em
## apply_status_effects_at_turn_start.
func _cancel_opposing_elemental_status(defender: Dictionary, hit_damage_type: String) -> void:
	var cancel_type: String
	if hit_damage_type == "fire": cancel_type = "slowed"
	elif hit_damage_type == "ice": cancel_type = "burned"
	else: return
	var effects: Array = defender.get("statusEffects", [])
	var remaining: Array = []
	var removed := false
	for e in effects:
		if e["type"] == cancel_type:
			removed = true
			if cancel_type == "slowed":
				defender["speed"] += e["speedReduction"]
			continue
		remaining.append(e)
	if not removed:
		return
	defender["statusEffects"] = remaining
	if cancel_type == "burned":
		_log("%s é atingido(a) por gelo — o fogo se apaga!" % defender["name"])
	else:
		_log("%s é atingido(a) por fogo — o gelo derrete e a lentidão passa!" % defender["name"])

# --- Combate: chances e dano (game.js:1054-1256) ----------------------------

func get_hit_chance(item: Dictionary, distance: int) -> Variant:
	if item.has("hitChanceByDistance"):
		return (item["hitChanceByDistance"] as Dictionary).get(distance)
	return item.get("hitChance")

## `angle` (front/side/back, ver get_attack_angle) só importa pra itens com
## critChanceByAngle (ex: Punhal do Ladino) — os demais ignoram o parâmetro.
## `invisibleCritChance` (Punhal): enquanto o atacante está invisível, a
## crítica vira esse valor fixo em qualquer ângulo, por cima do
## critChanceByAngle normal — pedido do usuário.
func get_crit_chance(item: Dictionary, angle: String = "front", attacker: Dictionary = {}) -> float:
	if item.has("invisibleCritChance") and not attacker.is_empty() and is_invisible(attacker):
		return item["invisibleCritChance"]
	if item.has("critChanceByAngle"):
		var by_angle: Dictionary = item["critChanceByAngle"]
		return by_angle.get(angle, by_angle["front"])
	return item.get("critChance", GameConstants.CRIT_CHANCE)

## Ataque Furtivo do Ladino: bônus de dano por ângulo do golpe (lateral,
## costas), ou o bônus "invisível" (mais forte, sempre o mesmo em qualquer
## ângulo) quando o atacante está invisível — não soma os dois, invisível
## simplesmente vale mais e substitui o de ângulo. Devolve [min, max] pra
## quem chamar rolar (resolve_single_hit) ou mostrar como faixa
## (describe_attack_preview).
func _sneak_attack_bonus_range(attacker: Dictionary, defender: Dictionary) -> Array:
	var backstab: Dictionary = attacker.get("backstabBonus", {})
	if backstab.is_empty():
		return [0, 0]
	if is_invisible(attacker):
		return backstab.get("invisible", [0, 0])
	var angle := get_attack_angle(attacker, defender)
	if angle == "back":
		return backstab.get("back", [0, 0])
	if angle == "side":
		return backstab.get("side", [0, 0])
	return [0, 0]

## Classifica o ângulo do ataque em relação a pra onde o defensor está virado.
func get_attack_angle(attacker: Dictionary, defender: Dictionary) -> String:
	var facing: Dictionary = defender.get("facing", {"dx": 1, "dy": 0})
	var dx: int = attacker["x"] - defender["x"]
	var dy: int = attacker["y"] - defender["y"]
	var dot: int = dx * facing["dx"] + dy * facing["dy"]
	if dot > 0:
		return "front"
	if dot < 0:
		return "back"
	return "side"

func is_attack_from_front(attacker: Dictionary, defender: Dictionary) -> bool:
	return get_attack_angle(attacker, defender) == "front"

## Chance de acerto real de um golpe contra um defensor específico: base da
## arma/magia, +10pp de lado / +20pp de trás, -10pp se o atacante estiver
## ofuscado e/ou atordoado (empilham), +10pp atacando de cima (casa/voo),
## -10pp atacando de dentro d'água, +10pp acertando alvo atolado n'água,
## +20pp/-10pp de dentro do próprio Castelo/Montanha, -esquiva do defensor
## (inata + evasiva, empilham), -esquiva mágica (só contra magia), -10pp de
## ataque à distância usado a queima-roupa.
func get_effective_hit_chance(attacker: Dictionary, defender: Dictionary, item: Dictionary, distance: int) -> Variant:
	var result = get_effective_hit_chance_breakdown(attacker, defender, item, distance)
	return null if result == null else result["chance"]

## Mesma fórmula de get_effective_hit_chance, mas devolve também o passo a
## passo (rótulo + delta em fração, ex.: -0.1 = "-10pp") que gerou o número
## final — usado pelo popup de confirmação de ataque (ver
## main.gd:_show_attack_confirmation) pra explicar de onde vem a % exibida.
## Só lista modificadores que de fato mudaram algo (ângulo "front", evasão
## zero etc. não aparecem) — o total resultante é idêntico ao da função
## acima de qualquer forma, já que somar/subtrair 0 não muda nada.
func get_effective_hit_chance_breakdown(attacker: Dictionary, defender: Dictionary, item: Dictionary, distance: int) -> Variant:
	var base = get_hit_chance(item, distance)
	if base == null:
		return null
	var breakdown: Array = [{"label": "Ataque", "delta": float(base)}]
	var chance: float = base
	var angle := get_attack_angle(attacker, defender)
	if angle == "back":
		breakdown.append({"label": "Pelas costas", "delta": 0.2})
		chance += 0.2
	elif angle == "side":
		breakdown.append({"label": "Flanqueado", "delta": 0.1})
		chance += 0.1
	if is_blinded(attacker):
		breakdown.append({"label": "Ofuscado", "delta": -0.1})
		chance -= 0.1
	if is_dazed(attacker):
		breakdown.append({"label": "Atordoado", "delta": -0.1})
		chance -= 0.1
	for dust_effect in attacker.get("statusEffects", []):
		if dust_effect.get("type", "") == "dustBlind":
			var dust_penalty: float = float(dust_effect.get("amount", 0.2))
			breakdown.append({"label": "Poeira nos olhos", "delta": -dust_penalty})
			chance -= dust_penalty
			break
	for effect in defender.get("statusEffects", []):
		if effect.get("type", "") == "accuracyPenalty":
			var penalty: float = float(effect.get("amount", 0.0))
			breakdown.append({"label": "Precisão reduzida", "delta": -penalty})
			chance -= penalty
			break
	if is_ranged_attack(item):
		for effect in defender.get("statusEffects", []):
			if effect.get("type", "") == "rangedRangePenalty" and distance > maxi(1, int(item["maxRange"]) - int(effect.get("amount", 0))):
				return {"chance": 0.0, "breakdown": breakdown + [{"label": "Alcance reduzido", "delta": -1.0}]}
	var attacker_terrain = terrain_at(attacker["x"], attacker["y"])
	var attacker_elevated: bool = attacker.get("flying", false) or (attacker_terrain != null and attacker_terrain["type"] == "house")
	if attacker_elevated:
		breakdown.append({"label": "Vantagem de altura", "delta": 0.1})
		chance += 0.1
	if not attacker.get("flying", false) and attacker_terrain != null and attacker_terrain["type"] == "water":
		breakdown.append({"label": "Atacando da água", "delta": -0.1})
		chance -= 0.1
	var defender_terrain = terrain_at(defender["x"], defender["y"])
	if not defender.get("flying", false) and defender_terrain != null and defender_terrain["type"] == "water":
		breakdown.append({"label": "Alvo atolado na água", "delta": 0.1})
		chance += 0.1
	var attacker_structure = structure_at(attacker["x"], attacker["y"])
	if attacker_structure != null and attacker_structure["team"] == attacker["team"]:
		breakdown.append({"label": "Atirando de dentro do forte", "delta": 0.2})
		chance += 0.2
	var defender_structure = structure_at(defender["x"], defender["y"])
	if defender_structure != null and defender_structure["team"] == defender["team"]:
		breakdown.append({"label": "Alvo protegido pelo forte", "delta": -0.1})
		chance -= 0.1
	var innate_evasion: float = defender.get("innateEvasion", 0.0)
	if innate_evasion > 0.0:
		breakdown.append({"label": "Esquiva do alvo", "delta": -innate_evasion})
		chance -= innate_evasion
	var inspiration_hit_bonus: float = float(bard_inspiration_bonus(defender, "hitBonus"))
	if inspiration_hit_bonus > 0.0:
		breakdown.append({"label":"Canção da Inspiração", "delta":inspiration_hit_bonus})
		chance += inspiration_hit_bonus
	for effect in defender.get("statusEffects", []):
		if effect.get("type", "") == "warHowl":
			chance += float(effect.get("accuracyBonus", 0.0))
			break
	var evasive_effect = null
	for e in defender.get("statusEffects", []):
		if e["type"] == "evasive":
			evasive_effect = e
			break
	if evasive_effect != null:
		var amount: float = evasive_effect["amount"]
		breakdown.append({"label": "Esquiva (habilidade)", "delta": -amount})
		chance -= amount
	for e in defender.get("statusEffects", []):
		if e.get("type", "") == "heronStance":
			var stance_evasion: float = float(e.get("evasion", 0.0))
			breakdown.append({"label": "Postura da Garça", "delta": -stance_evasion})
			chance -= stance_evasion
			break
	if item.has("mpCost") and int(item.get("mpCost", 0)) > 0:
		var magic_evasion: float = defender.get("magicEvasion", 0.0)
		if magic_evasion > 0.0:
			breakdown.append({"label": "Resistência mágica", "delta": -magic_evasion})
			chance -= magic_evasion
	if is_ranged_attack(item) and distance <= 1:
		breakdown.append({"label": "Distância à queima-roupa", "delta": -GameConstants.RANGED_MELEE_HIT_PENALTY})
		chance -= GameConstants.RANGED_MELEE_HIT_PENALTY
	return {"chance": clampf(chance, 0.0, 1.0), "breakdown": breakdown}

## Estimativa de dano/efeitos pra exibir ANTES de confirmar um ataque —
## mesmas fontes de bônus/redução de resolve_single_hit (Ataque Furtivo,
## Fúria, Guarda/redução passiva) e os `applies*` de dano ao longo do tempo
## (Veneno/Fogo). Não modela bônus efêmeros de 1 uso (Tiro Certeiro, Ataque
## Poderoso etc.) porque quem os ativou já sabe que estão prontos pra sair.
func describe_attack_preview(attacker: Dictionary, defender: Dictionary, item: Dictionary) -> Dictionary:
	var distance: int = manhattan(attacker, defender)
	var hit_breakdown = get_effective_hit_chance_breakdown(attacker, defender, item, distance)
	var result := {
		"hitChance": (hit_breakdown["chance"] if hit_breakdown != null else null),
		"hitBreakdown": (hit_breakdown["breakdown"] if hit_breakdown != null else []),
		"damageMin": 0, "damageMax": 0,
		"critDamageMin": 0, "critDamageMax": 0,
		"critChance": 0.0,
		"bonusEffects": [],
	}
	if item.has("damageMin") and item.has("damageMax"):
		var dmin: int = item["damageMin"]
		var dmax: int = item["damageMax"]
		var sneak_range := _sneak_attack_bonus_range(attacker, defender)
		dmin += sneak_range[0]
		dmax += sneak_range[1]
		for e in attacker.get("statusEffects", []):
			if e["type"] == "fury":
				dmin += int(e["damageBonus"])
				dmax += int(e["damageBonus"])
				break
		dmin += int(bard_inspiration_bonus(attacker, "damageBonus"))
		dmax += int(bard_inspiration_bonus(attacker, "damageBonus"))
		var damage_reduction: int = defender.get("passiveDamageReduction", 0)
		for e in defender.get("statusEffects", []):
			if e["type"] == "guarding":
				damage_reduction += int(e["damageReduction"])
				break
		dmin = apply_physical_damage_reduction(defender, maxi(0, dmin - damage_reduction), damage_type_of(item))
		dmax = apply_physical_damage_reduction(defender, maxi(0, dmax - damage_reduction), damage_type_of(item))
		result["damageMin"] = dmin
		result["damageMax"] = dmax
		result["critChance"] = clampf(get_crit_chance(item, get_attack_angle(attacker, defender), attacker) + attacker.get("critBonusNextAttack", 0.0), 0.0, 1.0)
		var crit_multiplier: int = item.get("critMultiplier", 1)
		result["critDamageMin"] = dmin * crit_multiplier
		result["critDamageMax"] = dmax * crit_multiplier
	if item.has("appliesBurn"):
		var b: Dictionary = item["appliesBurn"]
		result["bonusEffects"].append({"label": "Fogo", "min": b["damageMin"], "max": b["damageMax"], "turns": b["turns"]})
	if item.has("appliesPoison"):
		var p: Dictionary = item["appliesPoison"]
		result["bonusEffects"].append({"label": "Veneno", "min": p["damageMin"], "max": p["damageMax"], "turns": p["turns"]})
	return result

func get_weapon_damage(item: Dictionary) -> int:
	if item.has("damageMin") and item.has("damageMax"):
		return rng.randi_range(item["damageMin"], item["damageMax"])
	return item.get("damage", 0)

func is_in_weapon_range(item: Dictionary, distance: int) -> bool:
	return distance >= item["minRange"] and distance <= item["maxRange"]

## Regra global: qualquer arma/magia com alcance máximo > 1 conta como
## RANGED — só pelo dado real do item, não por nome/classe. Alguns itens
## sintéticos passados pra resolve_single_hit (ex: o "golpe" de
## cast_growth_attack/cast_charge) não têm maxRange nenhum — o JS original
## lê isso como `undefined > 1` (false, silencioso); aqui o acesso direto
## por colchete lançava erro de script no lugar, então usa .get() com o
## mesmo padrão "sem dado = melee" das outras funções desta camada.
func is_ranged_attack(item: Dictionary) -> bool:
	return item.get("maxRange", 1) > 1

## Classificação única usada por imunidade etérea e afinidades elementais.
## Itens antigos são reconhecidos pelos metadados que já possuíam; itens
## novos declaram `damageType` explicitamente.
## Escamas Protetoras (Kobold): -N em cada golpe FÍSICO recebido, sem
## zerar um golpe que causaria dano (mínimo 1). Aplicada junto das demais
## reduções de golpe direto, antes da afinidade elemental — então um golpe
## físico E de fogo passa por ela e depois pelo ×0.75 do Sangue Dracônico.
## Dano por turno de status nunca passa por aqui (outro caminho).
## Casca Fortificada (Troncus, status "barkArmor") entra DEPOIS da redução
## fixa, como porcentagem com o mesmo round() das afinidades elementais.
func apply_physical_damage_reduction(defender: Dictionary, damage: int, damage_type: String) -> int:
	if damage <= 0 or damage_type != "physical":
		return damage
	var reduction: int = int(defender.get("physicalDamageReduction", 0))
	if reduction > 0:
		damage = maxi(1, damage - reduction)
	for effect in defender.get("statusEffects", []):
		if effect.get("type", "") == "barkArmor":
			damage = int(round(damage * (1.0 - float(effect.get("reduction", 0.0)))))
			break
	return damage

## Instinto de Matilha (Lobo, campo `packInstinct`): bônus de dano FÍSICO se
## outro lobo ou goblinoide aliado vivo estiver adjacente ao alvo — um único
## bônus por ataque, não importa quantos aliados. O cavaleiro/montaria do
## próprio atacante (mesma casa) não conta como "outro" aliado.
func pack_instinct_bonus(attacker: Dictionary, defender: Dictionary, damage_type: String) -> int:
	var pack: Dictionary = attacker.get("packInstinct", {})
	if pack.is_empty() or damage_type != "physical":
		return 0
	var goblinoids := Units.goblinoid_keys()
	for ally in alive_units():
		if ally["name"] == attacker["name"] or ally["team"] != attacker["team"] or ally["name"] == defender["name"]:
			continue
		if String(ally.get("mountedOn", "")) == String(attacker["name"]) or String(attacker.get("mountedOn", "")) == String(ally["name"]):
			continue
		if goblinoids.has(String(ally.get("spriteKey", ""))) and manhattan(ally, defender) == 1:
			return int(pack.get("damageBonus", 0))
	return 0

func damage_type_of(item: Dictionary) -> String:
	if item.has("damageType"):
		return String(item["damageType"]).to_lower()
	var name := String(item.get("name", "")).to_lower()
	var kind := String(item.get("kind", "")).to_lower()
	var projectile := String(item.get("projectile", "")).to_lower()
	var sfx := String(item.get("sfx", "")).to_lower()
	if "fire" in projectile or "fogo" in name or "fire" in kind or sfx == "fire": return "fire"
	if "ice" in projectile or "gelo" in name or "congel" in name or "freeze" in kind or sfx == "ice": return "ice"
	if "lightning" in projectile or "raio" in name or "relâmpago" in name or sfx == "lightning": return "lightning"
	return "magic" if item.has("mpCost") else "physical"

## Ataque corpo a corpo básico do defensor pra revidar — primeira arma dele
## com alcance 1.
func find_basic_melee_weapon(u: Dictionary) -> Variant:
	for w in u.get("weapons", []):
		if w["maxRange"] == 1:
			return w
	return null

## Quem leva um ataque RANGED a distância de MELEE (alvo adjacente) tem uma
## chance de contra-atacar, mesmo se o ataque errar — o risco vem da
## tentativa em si, de tão perto. No JS original isso roda depois de um
## atraso cosmético (setTimeout); aqui roda na hora, já que esta camada não
## tem animação (ver Fase 5/6).
func _maybe_trigger_ranged_melee_counter(attacker: Dictionary, defender: Dictionary, item: Dictionary, distance: int, is_counter_attack: bool) -> void:
	if is_counter_attack or attacker["name"] == defender["name"]:
		return
	if not is_ranged_attack(item) or distance > 1:
		return
	var counter_weapon = find_basic_melee_weapon(defender)
	if counter_weapon == null:
		return
	if defender["hp"] <= 0 or attacker["hp"] <= 0:
		return
	if is_paralyzed(defender):
		return
	if rng.randf() < GameConstants.RANGED_MELEE_COUNTER_CHANCE:
		_log("%s aproveita a distância curta e contra-ataca %s!" % [defender["name"], attacker["name"]])
		resolve_single_hit(defender, attacker, counter_weapon, true)

## Resolve UM golpe (arma ou magia de alvo único) de attacker contra
## defender. Autoridade central de dano direto (game.js:7272-7646) — toda
## regra de combate cruzada do jogo passa por aqui: invisibilidade, imunidade
## de voo a corpo-a-corpo, buffs de "próximo ataque" (Tiro Certeiro, Ataque
## Poderoso, Flecha de Fogo, Golpe Debilitante), furtividade do Ladino,
## Fúria, Defender/redução passiva, todos os `applies*` de item (veneno,
## queimadura, cegueira, atordoamento, dreno de CT/MP, lentidão), contra-
## ataque passivo (Orc/Troll) e contra-ataque por proximidade (regra global).
## Retorna true se acertou, false se errou. NÃO chama finalize_action — quem
## chamar decide quando a ação termina (algumas habilidades acertam vários
## alvos com um resolve_single_hit cada, uma finalize_action só no fim).
func resolve_single_hit(attacker: Dictionary, defender: Dictionary, item: Dictionary, is_counter_attack: bool = false) -> bool:
	# Os ataques recebidos pela dupla causam dano ao HP da Vestruz.
	if defender.get("mountedOn", "") != "":
		var carrying_mount = mount_of(defender)
		if carrying_mount != null:
			defender = carrying_mount
	if defender.get("caged", false):
		var caged_word := "preso" if defender.get("spriteKey", "") == CAGED_BARDO_KEY else "presa"
		_log("%s está %s na gaiola e imune a qualquer dano!" % [defender["name"], caged_word])
		return false
	if _has_status(defender, "invulnerable"):
		_log("%s está intocável por Fingir de Morto e ignora %s!" % [defender["name"], item["name"]])
		return true
	var is_weapon_attack: bool = not item.has("mpCost") or int(item.get("mpCost", 0)) == 0
	var damage_type := damage_type_of(item)
	# Fada: só armas corpo a corpo (alcance 1) erram nela — à distância (ou
	# marcadas "aerial") e magias sempre podem atingi-la. Calculado ANTES do
	# corpo etéreo do Fantasma logo abaixo, que usa a MESMA distinção.
	var is_melee_weapon: bool = is_weapon_attack and item.get("maxRange", 1) == 1 and not item.get("aerial", false)
	# Pedido do usuário: o corpo etéreo do Fantasma bloqueava QUALQUER ataque
	# físico, inclusive Arco do Arqueiro/Arma de Fogo do Químico (ambos
	# maxRange > 1, sem elemento no nome — caem no fallback "physical" de
	# damage_type_of) — nenhum dos dois conseguia acertá-lo. Corrigido pra só
	# atravessar golpes corpo a corpo (mesmo is_melee_weapon da Fada acima):
	# ataque físico À DISTÂNCIA volta a acertar normalmente.
	if is_melee_weapon and defender.get("ethereal", false) and damage_type == "physical":
		_log("IMUNE! %s atravessa o corpo etéreo de %s sem causar dano." % [item["name"], defender["name"]])
		return false
	if not bypasses_invisibility(item) and is_invisible(defender):
		_log("%s ataca %s com %s, mas %s está invisível e o golpe não acerta nada!" % [attacker["name"], defender["name"], item["name"], defender["name"]])
		return false
	if is_melee_weapon and defender.get("flying", false):
		_log("%s ataca %s com %s, mas %s só pode ser atingida por ataques à distância ou magia!" % [attacker["name"], defender["name"], item["name"], defender["name"]])
		return false
	# Foco (Monge): enquanto o status estiver ativo, ataque FÍSICO não passa
	# de jeito nenhum (mesmo "muro" do Fingir de Morto lá em cima, só que
	# restrito ao tipo de dano) e magia chega pela metade — a metade é
	# aplicada mais abaixo, junto do cálculo de dano.
	var focus_active: bool = _has_status(defender, "focus")
	if focus_active and damage_type == "physical":
		_log("%s está em Foco e bloqueia completamente o ataque físico de %s!" % [defender["name"], attacker["name"]])
		return false

	var distance: int = manhattan(attacker, defender)
	var attack_angle: String = get_attack_angle(attacker, defender)
	# Buffs de "próximo ataque" são consumidos aqui, na tentativa em si.
	var guaranteed_hit: bool = attacker.get("guaranteedNextHit", false)
	var crit_bonus: float = attacker.get("critBonusNextAttack", 0.0)
	# Saque Rápido (Samurai): mesmo efeito do Tiro Certeiro (100% de acerto e
	# +crítico no próximo ataque), mas SÓ vale para golpe de espada (a Espada
	# ou uma habilidade marcada "usesSword"). Qualquer outro ataque — o Arco,
	# por exemplo — não gasta o saque.
	if attacker.get("quickDrawNextSword", false) and (item.get("name", "") == "Espada" or item.get("usesSword", false)):
		guaranteed_hit = true
		crit_bonus += float(attacker.get("quickDrawCritBonus", 0.0))
		attacker["quickDrawNextSword"] = false
	var one_shot_damage_bonus: int = attacker.get("oneShotDamageBonus", 0)
	# `.get(key, default)` só cai no default quando a CHAVE não existe — mas
	# um ataque anterior pode ter deixado essa chave com valor `null`
	# explicitamente (ver reset de buffs logo abaixo). Fallback por
	# "falsy", igual o `|| "habilidade"` do JS original.
	var one_shot_damage_bonus_source_raw = attacker.get("oneShotDamageBonusSource")
	var one_shot_damage_bonus_source: String = one_shot_damage_bonus_source_raw if one_shot_damage_bonus_source_raw else "habilidade"
	var weakening_strike: bool = attacker.get("weakeningStrikeNextAttack", false)
	var bonus_burn_turns: int = attacker.get("burnNextAttackTurns", 0)
	# Flecha de Fogo: queima o alvo MESMO SE O GOLPE ERRAR.
	var bonus_always_burn_turns: int = attacker.get("burnNextAttackAlwaysTurns", 0)
	# Flecha de Gelo: reduz a agilidade do alvo MESMO SE O GOLPE ERRAR (mesma
	# regra da Flecha de Fogo, trocando queimadura por lentidão).
	var bonus_always_slow_turns: int = attacker.get("slowNextAttackAlwaysTurns", 0)
	var bonus_always_slow_amount: int = attacker.get("slowNextAttackAlwaysAmount", 0)
	var pending_steal: String = String(attacker.get("stealNextAttack", ""))
	var steal_eligible: bool = is_weapon_attack and item.get("name", "") in ["Punhal", "Besta"] and pending_steal != ""
	var steal_hp_bonus: int = rng.randi_range(3, 6) if steal_eligible and pending_steal == "steal-hp" else 0
	# Golpe Baixo/Poção Venenosa/Areia nos Olhos preparam o próximo ataque
	# básico: Adaga/Funda do Goblin ou Adaga Envenenada/Lança do Kobold (que
	# recebeu parte dessas habilidades do Goblin).
	var goblin_attack_eligible: bool = GOBLIN_TRICK_WEAPONS.get(String(attacker.get("spriteKey", "")), []).has(item.get("name", "")) and is_weapon_attack
	var goblin_low_blow: bool = goblin_attack_eligible and attacker.get("goblinLowBlowNextAttack", false)
	var goblin_poison: bool = goblin_attack_eligible and attacker.get("goblinPoisonNextAttack", false)
	var goblin_sand: bool = goblin_attack_eligible and attacker.get("goblinSandNextAttack", false)
	# Flecha de Fogo/Flecha de Gelo + Tiro Rápido: se ainda sobra um disparo
	# bônus DEPOIS deste, o buff da flecha elemental não reseta ainda.
	var keep_arrow_buff_for_bonus_shot: bool = one_shot_damage_bonus_source in ["Flecha de Fogo", "Flecha de Gelo"] and attacker.get("bonusAttacksRemaining", 0) > 0
	attacker["guaranteedNextHit"] = false
	attacker["critBonusNextAttack"] = 0
	if not keep_arrow_buff_for_bonus_shot:
		attacker["oneShotDamageBonus"] = 0
		attacker["oneShotDamageBonusSource"] = null
		attacker["burnNextAttackAlwaysTurns"] = 0
		attacker["slowNextAttackAlwaysTurns"] = 0
		attacker["slowNextAttackAlwaysAmount"] = 0
		attacker["doubleRangeNextAttack"] = false
		attacker["weakeningStrikeNextAttack"] = false
		attacker["burnNextAttackTurns"] = 0
	if steal_eligible:
		attacker["stealNextAttack"] = ""
	if goblin_attack_eligible:
		attacker["goblinLowBlowNextAttack"] = false
		attacker["goblinPoisonNextAttack"] = false
		attacker["goblinSandNextAttack"] = false

	if bonus_always_burn_turns > 0:
		if is_on_water(defender):
			_log("%s está na água — a Flecha de Fogo não consegue incendiá-lo(a)!" % defender["name"])
		else:
			var burned_dmg: Dictionary = StatusDotDamage.STATUS_DOT_DAMAGE["burned"]
			add_status_effect(defender, {"type": "burned", "damageMin": burned_dmg["damageMin"], "damageMax": burned_dmg["damageMax"], "turnsLeft": bonus_always_burn_turns})
			_log("%s pega fogo com a Flecha de Fogo, acertando ou não!" % defender["name"])
	if bonus_always_slow_turns > 0:
		defender["speed"] -= bonus_always_slow_amount
		add_status_effect(defender, {"type": "slowed", "turnsLeft": bonus_always_slow_turns, "speedReduction": bonus_always_slow_amount})
		_log("%s fica mais lento(a) com a Flecha de Gelo, acertando ou não! -%d de agilidade por %d turno(s)." % [defender["name"], bonus_always_slow_amount, bonus_always_slow_turns])

	var hit_chance = 1.0 if guaranteed_hit else get_effective_hit_chance(attacker, defender, item, distance)
	var hit_roll: float = 1.0 if hit_chance == null else rng.randf()
	var is_hit: bool = false if hit_chance == null else (hit_roll < float(hit_chance))

	if not is_hit:
		_log("%s atacou %s com %s e errou!" % [attacker["name"], defender["name"], item["name"]])
		_try_heron_counter(attacker, defender, item, hit_chance, hit_roll, is_counter_attack)
		_maybe_trigger_ranged_melee_counter(attacker, defender, item, distance, is_counter_attack)
		return false

	var is_crit: bool = rng.randf() < minf(get_crit_chance(item, attack_angle, attacker) + crit_bonus, 1.0)
	var base_damage: int = get_weapon_damage(item)
	# Ladino, Ataque Furtivo: bônus de dano por ângulo (lateral/costas), ou o
	# bônus mais forte de "invisível" (não soma com o de ângulo — ver
	# _sneak_attack_bonus_range).
	var sneak_range := _sneak_attack_bonus_range(attacker, defender)
	var sneak_attack_bonus: int = rng.randi_range(sneak_range[0], sneak_range[1]) if sneak_range[1] > 0 else 0
	var fury_effect = null
	for e in attacker.get("statusEffects", []):
		if e["type"] == "fury":
			fury_effect = e
			break
	var fury_bonus: int = fury_effect["damageBonus"] if fury_effect != null else 0
	var song_damage_bonus: int = int(bard_inspiration_bonus(attacker, "damageBonus"))
	var war_howl_bonus: int = 0
	for effect in attacker.get("statusEffects", []):
		if effect.get("type", "") == "warHowl":
			war_howl_bonus += int(effect.get("damageBonus", 0))
	# Redução de dano recebido, aplicada por último (depois do crítico): o
	# Defender (postura, guarding) soma com a redução passiva (sempre ativa,
	# ex: Guerreiro). Só vale pra dano de golpe direto; dano de status por
	# turno roda num caminho totalmente separado (apply_status_effects_at_turn_start).
	var guard_effect = null
	for e in defender.get("statusEffects", []):
		if e["type"] == "guarding":
			guard_effect = e
			break
	var damage_reduction: int = (guard_effect["damageReduction"] if guard_effect != null else 0) + defender.get("passiveDamageReduction", 0)
	var defense_down: int = 0
	for effect in defender.get("statusEffects", []):
		if effect.get("type", "") == "defenseDown": defense_down += int(effect.get("amount", 0))
	var marked_bonus: int = 0
	for effect in defender.get("statusEffects", []):
		if effect.get("type", "") == "marked":
			marked_bonus += int(effect.get("damageBonus", 1))
	var crit_multiplier: int = item["critMultiplier"] if is_crit else 1
	var pack_bonus: int = pack_instinct_bonus(attacker, defender, damage_type)
	var damage: int = maxi(0, (base_damage + sneak_attack_bonus + one_shot_damage_bonus + fury_bonus + song_damage_bonus + war_howl_bonus + steal_hp_bonus + marked_bonus + defense_down + pack_bonus) * crit_multiplier - damage_reduction)
	damage = apply_physical_damage_reduction(defender, damage, damage_type)
	if item.get("noDamage", false): damage = 0
	# Guarda Quebrada (Quebra-Guarda do Samurai): cada ataque que acerta o
	# alvo causa +1 de dano enquanto o status durar (um único +1: reaplicar só
	# renova a duração, ver appliesGuardBroken mais abaixo).
	elif _has_status(defender, "guardBroken"):
		damage += 1
	# Tiro Explosivo (Químico): o tiro em si vira dano de fogo pra fins de
	# afinidade elemental (cura Fogo Vivo/Homem de Lava, dobra em Gelo) —
	# a arma de base continua física (ver damageType do firearm), só esse
	# disparo específico conta como fogo. Flecha de Gelo, do mesmo jeito, faz
	# o disparo contar como gelo (dobra em Fogo Vivo/Lava Humana/Salamandra).
	var affinity_damage_type: String = "fire" if bonus_burn_turns > 0 else ("ice" if bonus_always_slow_turns > 0 else damage_type)
	var affinity: Dictionary = defender.get("elementAffinity", {}).get(affinity_damage_type, {})
	if not affinity.is_empty():
		# Pedido do usuário: Dragão Vermelho — imune a dano de fogo (0, não
		# reduzido) e a qualquer status que o mesmo golpe aplicaria (Queimando)
		# — mesmo padrão de dados do "heal" logo abaixo, só terminando aqui
		# antes de chegar nos `applies*` (appliesBurn nunca roda).
		if affinity.get("mode", "damage") == "immune":
			_log("IMUNE! %s ignora completamente o ataque de fogo de %s." % [defender["name"], attacker["name"]])
			_cancel_opposing_elemental_status(defender, affinity_damage_type)
			_maybe_trigger_ranged_melee_counter(attacker, defender, item, distance, is_counter_attack)
			return true
		if affinity.get("mode", "damage") == "heal":
			var healing := int(round(damage * float(affinity.get("multiplier", 1.0))))
			var actual_heal := mini(healing, int(defender["maxHp"]) - int(defender["hp"]))
			defender["hp"] = mini(int(defender["maxHp"]), int(defender["hp"]) + healing)
			_log("%s absorve o ataque de fogo e recupera %d HP!" % [defender["name"], actual_heal])
			_cancel_opposing_elemental_status(defender, affinity_damage_type)
			_maybe_trigger_ranged_melee_counter(attacker, defender, item, distance, is_counter_attack)
			return true
		damage = int(round(damage * float(affinity.get("multiplier", 1.0))))
	# Pedido do usuário: todo morto-vivo (campo genérico `undead`, o mesmo já
	# usado por Zumbi/Fantasma/Esqueleto e agora também Vampiro/Lich) sofre
	# só metade do dano de gelo, arredondado pra baixo — independe de
	# elementAffinity (que é opt-in só pras criaturas de fogo) e de nome de
	# unidade/habilidade, só do tipo elemental do golpe.
	# Resistência de 50% removida: mortos-vivos recebem dano elemental normal.
	# Pedido do usuário: morto-vivo resiste a ATAQUE (arma — Flecha/Besta/
	# Espada/Punhal/Cajado e qualquer outra arma física, `is_weapon_attack`
	# já genérico no topo desta função), sofrendo só metade do dano; magia/
	# habilidade (qualquer item com mpCost, mesmo custando 0) continua
	# causando o dano cheio. Empilha com a resistência a gelo acima quando os
	# dois se aplicam (ex.: uma arma de gelo).
	# Resistência de 50% removida: ataques físicos também causam dano normal.
	# Foco (Monge): magia passa, mas com metade do dano (arredondado pra
	# baixo) — depois de crítico/afinidade elemental e antes de descontar do
	# HP, o mesmo lugar onde a redução do Defender já entrou.
	if focus_active and damage > 0:
		var damage_before_focus := damage
		damage = int(floor(damage / 2.0))
		_log("%s está em Foco e sofre só metade do dano mágico (%d em vez de %d)." % [defender["name"], damage, damage_before_focus])
	var hp_before_hit: int = int(defender["hp"])
	defender["hp"] -= damage
	var sneak_note: String = " (Ataque Furtivo!)" if sneak_attack_bonus > 0 else ""
	var crit_note: String = " (CRÍTICO!)" if is_crit else ""
	_log("%s ataca %s com %s%s%s causando %d de dano." % [attacker["name"], defender["name"], item["name"], crit_note, sneak_note, damage])
	_cancel_opposing_elemental_status(defender, affinity_damage_type)
	# Lifesteal genérico (Vampiro: Toque Vampírico/Mordida, "lifesteal" no
	# item = fração 0..1 do dano REALMENTE retirado da vida, não do valor
	# bruto sorteado — floor(), respeitando o HP máximo do atacante). Um
	# status effect com `lifestealMultiplierOverride` (forma de morcego)
	# substitui a fração do item — mesmo idioma já usado por fury_bonus/
	# song_damage_bonus/guard_effect logo acima: procurar um campo no
	# statusEffects do envolvido, não checar o nome da unidade/habilidade.
	if item.has("lifesteal"):
		var actual_damage_dealt: int = mini(damage, hp_before_hit)
		if actual_damage_dealt > 0:
			var lifesteal_fraction: float = float(item["lifesteal"])
			for e in attacker.get("statusEffects", []):
				if e.has("lifestealMultiplierOverride"):
					lifesteal_fraction = float(e["lifestealMultiplierOverride"])
					break
			var healed: int = int(floor(actual_damage_dealt * lifesteal_fraction))
			if healed > 0:
				var actual_heal := mini(healed, int(attacker["maxHp"]) - int(attacker["hp"]))
				attacker["hp"] = mini(int(attacker["maxHp"]), int(attacker["hp"]) + healed)
				_log("%s absorve %d HP com %s!" % [attacker["name"], actual_heal, item["name"]])
	# Mordida (Lobo): cura fixa sorteada no atacante ao acertar, sem passar
	# do HP máximo (vale também pro Contra-ataque de Mordida).
	if item.has("healOnHit") and int(attacker.get("hp", 0)) > 0:
		var bite_heal: int = rng.randi_range(int(item["healOnHit"]["min"]), int(item["healOnHit"]["max"]))
		var bite_healed: int = mini(bite_heal, int(attacker["maxHp"]) - int(attacker["hp"]))
		attacker["hp"] = int(attacker["hp"]) + bite_healed
		if bite_healed > 0:
			_log("%s recupera %d HP com %s!" % [attacker["name"], bite_healed, item["name"]])
	if steal_hp_bonus > 0:
		var stolen_hp: int = mini(steal_hp_bonus, hp_before_hit)
		var steal_heal: int = mini(stolen_hp, int(attacker["maxHp"]) - int(attacker["hp"]))
		attacker["hp"] = mini(int(attacker["maxHp"]), int(attacker["hp"]) + stolen_hp)
		_log("%s furta %d de HP com %s!" % [attacker["name"], steal_heal, item["name"]])

	if item.has("appliesPoison") and rng.randf() < float(item.get("poisonChance", 1.0)):
		var p: Dictionary = item["appliesPoison"]
		add_status_effect(defender, {"type": "poison", "damageMin": p["damageMin"], "damageMax": p["damageMax"], "turnsLeft": p["turns"], "ctDrainPerTurn": p.get("ctDrainPerTurn")})
		_log("%s foi envenenado!" % defender["name"])
	if goblin_poison:
		add_status_effect(defender, {"type": "poison", "damageMin": 1, "damageMax": 3, "turnsLeft": 3, "ctDrainPerTurn": 10})
		_log("%s foi envenenado pela Poção Venenosa!" % defender["name"])
	if goblin_low_blow:
		add_status_effect(defender, {"type": "accuracyPenalty", "turnsLeft": 1, "amount": 0.2})
		_log("%s sofre Golpe Baixo e perde 20%% de acerto!" % defender["name"])
	if goblin_sand:
		add_status_effect(defender, {"type": "accuracyPenalty", "turnsLeft": 1, "amount": 0.1})
		add_status_effect(defender, {"type": "rangedRangePenalty", "turnsLeft": 1, "amount": 1})
		_log("%s fica com areia nos olhos: -10%% de acerto e -1 de alcance à distância!" % defender["name"])
	# Garra (Demônio das Chamas): mesmo padrão genérico de appliesPoison/
	# appliesBurn, aplicando o status "bleed" já existente (usado hoje só
	# pelo Golpe Debilitante do Ladino). Mortos-vivos não sangram, mesma
	# regra já aplicada ao Golpe Debilitante.
	if item.has("appliesBleed") and not defender.get("undead", false) and rng.randf() < float(item["appliesBleed"].get("chance", 1.0)):
		var bl: Dictionary = item["appliesBleed"]
		if bl.get("refresh", false):
			# Dilacerar (Lobo): não acumula — reaplicar só renova a duração.
			_replace_timed_status(defender, {"type": "bleed", "damageMin": bl["damageMin"], "damageMax": bl["damageMax"], "turnsLeft": bl["turns"]})
		else:
			add_status_effect(defender, {"type": "bleed", "damageMin": bl["damageMin"], "damageMax": bl["damageMax"], "turnsLeft": bl["turns"]})
		_log("%s está sangrando!" % defender["name"])
	if item.has("appliesBurn"):
		if is_on_water(defender):
			_log("%s está na água — não pega fogo!" % defender["name"])
		else:
			var b: Dictionary = item["appliesBurn"]
			add_status_effect(defender, {"type": "burned", "damageMin": b["damageMin"], "damageMax": b["damageMax"], "turnsLeft": b["turns"]})
			_log("%s pegou fogo!" % defender["name"])
	if item.has("appliesBlind"):
		add_status_effect(defender, {"type": "blinded", "turnsLeft": item["appliesBlind"]["turns"]})
		_log("%s ficou ofuscado(a)! -10%% de chance de acerto por %d turno(s)." % [defender["name"], item["appliesBlind"]["turns"]])
	# Explosão Sonora (Fada): mesmo desconto de Ofuscado, mas empilha com ele
	# se o atacante tiver os dois ao mesmo tempo.
	if item.has("appliesDaze"):
		add_status_effect(defender, {"type": "dazed", "turnsLeft": item["appliesDaze"]["turns"]})
		_log("%s fica atordoado(a) pelo som! -10%% de chance de acerto nos próprios ataques por %d turno(s)." % [defender["name"], item["appliesDaze"]["turns"]])
	if item.has("appliesAccuracyPenalty") and rng.randf() < float(item.get("accuracyPenaltyChance", 1.0)):
		add_status_effect(defender, {"type": "accuracyPenalty", "turnsLeft": item.get("penaltyTurns", 1), "amount": item["appliesAccuracyPenalty"]})
	if item.has("appliesRangedRangeReduction"):
		add_status_effect(defender, {"type": "rangedRangePenalty", "turnsLeft": item.get("penaltyTurns", 1), "amount": item["appliesRangedRangeReduction"]})
	if item.has("appliesMarked"):
		var marked: Dictionary = item["appliesMarked"]
		add_status_effect(defender, {"type": "marked", "turnsLeft": marked.get("turns", 2), "damageBonus": marked.get("damageBonus", 1)})
	if item.has("appliesGuardBroken") and defender["hp"] > 0:
		_replace_timed_status(defender, {"type": "guardBroken", "turnsLeft": int(item["appliesGuardBroken"].get("turns", 2))})
		_log("%s fica com a Guarda Quebrada por %d turno(s): cada ataque que o acertar causa +1 de dano!" % [defender["name"], int(item["appliesGuardBroken"].get("turns", 2))])
	if item.has("appliesRoot"):
		add_status_effect(defender, {"type":"root", "turnsLeft":int(item["appliesRoot"].get("turns", 1)), "damageMin":0, "damageMax":0})
		_log("%s fica imobilizado(a) por %d turno(s)!" % [defender["name"], item["appliesRoot"].get("turns", 1)])
	if item.has("appliesDefenseReduction"):
		var defense: Dictionary = item["appliesDefenseReduction"]
		_replace_timed_status(defender, {"type":"defenseDown","turnsLeft":int(defense.get("turns", 2)),"amount":int(defense.get("amount", 2))})
		_log("%s sofre Corrosão: defesa -%d por %d turno(s)." % [defender["name"], defense.get("amount", 2), defense.get("turns", 2)])
	# ctDrainConfirmChance (Funda do Goblin) é uma SEGUNDA rolagem, além do
	# acerto do golpe em si.
	if item.has("appliesCtDrain") or item.has("appliesCtDrainMin"):
		var confirm_chance: float = item.get("ctDrainConfirmChance", 1.0)
		if rng.randf() < confirm_chance:
			var ct_min: int = int(item.get("appliesCtDrainMin", item.get("appliesCtDrain", 0)))
			var ct_max: int = int(item.get("appliesCtDrainMax", ct_min))
			var ct_drained: int = mini(rng.randi_range(ct_min, ct_max), int(defender.get("ct", 0)))
			defender["ct"] = maxi(defender.get("ct", 0) - ct_drained, 0)
			_log("%s perde %d de CT!" % [defender["name"], ct_drained])
			if item.has("appliesCtDrainMin") and ct_drained > 0:
				attacker["ct"] = mini(attacker.get("ct", 0) + ct_drained, 100)
				_log("%s recupera %d de CT roubado!" % [attacker["name"], ct_drained])
	# Cauda (Dragão Vermelho): empurrão de golpe direto (não epicentro de
	# explosão) — mesma direção do golpe (atacante -> defensor) e mesmo
	# push_unit já usado pelo empurrão radial de área (apply_point_blast_
	# knockback)/Ventania, que já pára no primeiro obstáculo/unidade/borda do
	# mapa e nunca solta a unidade fora dos limites.
	if (item.get("hitAndRun", false) or attacker.get("hitAndRun", false)) and defender["hp"] > 0:
		if attacker.get("hasMoved", false):
			attacker["moveRange"] += 2
		else:
			attacker["hasMoved"] = false
		attacker["hitAndRun"] = false
		_log("%s pode bater e correr após acertar!" % attacker["name"])
	if (item.get("hitAndRun", false) or attacker.get("hitAndRun", false)) and defender["hp"] > 0:
		if attacker.get("hasMoved", false): attacker["moveRange"] += 2
		else: attacker["hasMoved"] = false
		attacker["hitAndRun"] = false
		_log("%s pode bater e correr após acertar!" % attacker["name"])
	if item.has("knockback") and defender["hp"] > 0:
		# Direção a partir da borda do corpo de quem ataca (Troncus/Dragão 2x2
		# não empurram na diagonal um alvo que está reto à frente de uma das
		# casas do corpo). Corpo 1x1: mesmo sinal de antes.
		var push_dir := body_direction(attacker, {"x": defender["x"], "y": defender["y"]})
		if push_dir == Vector2i.ZERO:
			push_dir = Vector2i(_signi(defender["x"] - attacker["x"]), _signi(defender["y"] - attacker["y"]))
		var push_dx: int = push_dir.x
		var push_dy: int = push_dir.y
		if push_dx != 0 or push_dy != 0:
			push_unit(defender, push_dx, push_dy, item["knockback"]["distance"])
	if item.get("hitAndRun", false) and defender["hp"] > 0:
		if attacker.get("hasMoved", false):
			attacker["moveRange"] += 2
		else:
			attacker["hasMoved"] = false
		_log("%s pode bater e correr após acertar!" % attacker["name"])
	# Cajado (Mago): dreno de MP vampírico — o atacante rouba, não só tira.
	if (item.has("appliesMpDrain") or item.has("appliesMpDrainMin")) and defender.has("maxMp"):
		var mp_min: int = int(item.get("appliesMpDrainMin", item.get("appliesMpDrain", 0)))
		var mp_max: int = int(item.get("appliesMpDrainMax", mp_min))
		var drained: int = mini(rng.randi_range(mp_min, mp_max), defender["mp"])
		defender["mp"] -= drained
		_log("%s perde %d de MP!" % [defender["name"], drained])
		if drained > 0 and attacker.has("maxMp"):
			attacker["mp"] = mini(attacker["mp"] + drained, attacker["maxMp"])
			_log("%s recupera %d de MP roubado!" % [attacker["name"], drained])
	if steal_eligible and pending_steal == "steal-mp" and defender.has("maxMp"):
		var stolen_mp: int = mini(rng.randi_range(3, 6), int(defender.get("mp", 0)))
		defender["mp"] = maxi(int(defender.get("mp", 0)) - stolen_mp, 0)
		attacker["mp"] = mini(int(attacker.get("mp", 0)) + stolen_mp, int(attacker.get("maxMp", attacker.get("mp", 0))))
		_log("%s furta %d de MP de %s!" % [attacker["name"], stolen_mp, defender["name"]])
	if steal_eligible and pending_steal == "steal-ct":
		var stolen_ct: int = mini(rng.randi_range(10, 40), int(defender.get("ct", 0)))
		defender["ct"] = maxi(int(defender.get("ct", 0)) - stolen_ct, 0)
		attacker["ct"] = mini(int(attacker.get("ct", 0)) + stolen_ct, 100)
		_log("%s furta %d de CT de %s!" % [attacker["name"], stolen_ct, defender["name"]])
	# Lentidão embutida na própria arma/magia (ex: Atropelar) — diferente do
	# Golpe Debilitante (buff condicional no atacante): aqui é sempre que o
	# golpe acertar. Reaproveita o status "weakened".
	if item.get("kind", "") in ["creature-charge", "slime-slam"]:
		item["appliesSlow"] = {"moveReduction": 1, "turns": (1 if item.get("kind", "") == "creature-charge" else 2)}
	if item.has("appliesSlow"):
		var slow_amount: int = int(item["appliesSlow"]["moveReduction"])
		var weakened_existing = null
		for existing in defender.get("statusEffects", []):
			if existing.get("type", "") == "weakened": weakened_existing = existing; break
		if weakened_existing == null:
			slow_amount = mini(slow_amount, defender["moveRange"])
			defender["moveRange"] -= slow_amount
			add_status_effect(defender, {"type": "weakened", "turnsLeft": item["appliesSlow"]["turns"], "moveReduction": slow_amount})
		else:
			slow_amount = int(weakened_existing.get("moveReduction", slow_amount))
			weakened_existing["turnsLeft"] = item["appliesSlow"]["turns"]
		_log("%s fica mais lento! -%d de deslocamento por %d turno(s)." % [defender["name"], slow_amount, item["appliesSlow"]["turns"]])
	if item.has("appliesVineSlow"):
		_apply_vine_slow(defender, item["appliesVineSlow"])
	# Raio de Gelo: reduz agilidade (não deslocamento) — soma com usos
	# futuros em vez de substituir.
	if item.has("appliesSpeedReduction") and defender["hp"] > 0:
		var amount: int = item["appliesSpeedReduction"]["amount"]
		var slowed_existing = null
		for existing in defender.get("statusEffects", []):
			if existing.get("type", "") == "slowed": slowed_existing = existing; break
		if slowed_existing == null:
			defender["speed"] -= amount
			add_status_effect(defender, {"type": "slowed", "turnsLeft": item["appliesSpeedReduction"]["turns"], "speedReduction": amount})
		else:
			slowed_existing["turnsLeft"] = item["appliesSpeedReduction"]["turns"]
		_log("%s fica mais lento(a)! -%d de agilidade por %d turno(s)." % [defender["name"], amount, item["appliesSpeedReduction"]["turns"]])
	if item.has("appliesParalyzed") and defender["hp"] > 0:
		add_status_effect(defender, {"type":"paralyzed", "turnsLeft":int(item["appliesParalyzed"].get("turns", 1))})
		_log("%s fica completamente congelado(a) e perderá 1 turno!" % defender["name"])

	if defender["hp"] <= 0:
		defender["hp"] = 0
		_log("%s foi derrotado!" % defender["name"])
		# O reembolso só entra em finalize_action, DEPOIS de descontar o custo
		# de MP da própria habilidade (senão o teto de MP máximo engoliria o
		# ganho quando o Samurai está com o MP cheio).
		if int(item.get("restoresMpOnKill", 0)) > 0 and attacker.has("maxMp"):
			attacker["mpRefundAfterCost"] = int(attacker.get("mpRefundAfterCost", 0)) + int(item["restoresMpOnKill"])

	if defender["hp"] <= 0 and defender.get("riderName", "") != "":
		_release_rider_on_mount_death(defender)

	# Golpe Debilitante (Ladino): só aplica se o alvo sobreviveu ao golpe.
	# Cada uso empilha um novo sangramento + nova redução de deslocamento.
	# Pedido do usuário: mortos-vivos (`undead`) não sangram — imunes ao
	# sangramento, mas ainda sofrem a redução de deslocamento normalmente.
	if weakening_strike and defender["hp"] > 0:
		if not defender.get("undead", false):
			add_status_effect(defender, {"type": "bleed", "damageMin": 1, "damageMax": 1, "turnsLeft": 3})
		var move_reduction: int = mini(1, defender["moveRange"])
		defender["moveRange"] -= move_reduction
		add_status_effect(defender, {"type": "weakened", "turnsLeft": 3, "moveReduction": move_reduction})
		if defender.get("undead", false):
			_log("%s é um morto-vivo e não sangra, mas fica mais lento por causa do Golpe Debilitante!" % defender["name"])
		else:
			_log("%s está sangrando e mais lento por causa do Golpe Debilitante!" % defender["name"])

	# Tiro Explosivo (Químico): só queima se o golpe realmente acertou.
	if bonus_burn_turns > 0 and defender["hp"] > 0:
		if is_on_water(defender):
			_log("%s está na água — o Tiro Explosivo não consegue incendiá-lo(a)!" % defender["name"])
		else:
			var burned_dmg2: Dictionary = StatusDotDamage.STATUS_DOT_DAMAGE["burned"]
			add_status_effect(defender, {"type": "burned", "damageMin": burned_dmg2["damageMin"], "damageMax": burned_dmg2["damageMax"], "turnsLeft": bonus_burn_turns})
			_log("%s pega fogo com o Tiro Explosivo!" % defender["name"])

	# Contra-ataque passivo (Orc/Troll): só dispara em quem levou o golpe
	# original (nunca no próprio contra-ataque), só se sobreviveu, e só se
	# quem bateu ainda está ao alcance do contra-ataque.
	# Lobo (`counterMeleeOnly`): só revida golpe corpo a corpo (alcance 1,
	# adjacente) — nunca ataque à distância, área ou outro revide.
	var counter_allowed: bool = not defender.get("counterMeleeOnly", false) or (not is_ranged_attack(item) and distance <= 1)
	if not is_counter_attack and counter_allowed and defender["hp"] > 0 and attacker["hp"] > 0 and defender.get("counterAttackChance", 0) > 0 and attacker["name"] != defender["name"]:
		var counter_weapon = defender.get("counterWeapon")
		if counter_weapon != null and is_in_weapon_range(counter_weapon, distance):
			if rng.randf() < defender["counterAttackChance"]:
				_log("%s revida com um contra-ataque!" % defender["name"])
				resolve_single_hit(defender, attacker, counter_weapon, true)

	# Regra global: ataque RANGED usado a distância de MELEE dá ao defensor
	# uma chance de contra-atacar, além (não em vez) de qualquer contra-
	# ataque passivo próprio acima.
	_maybe_trigger_ranged_melee_counter(attacker, defender, item, distance, is_counter_attack)
	_check_black_slime_split(defender)

	return true

## Paga o custo da ação (game.js:8582). Invariante: chamar exatamente uma vez
## por ação (ver AGENTS.md do protótipo) — repetir consome CT/MP indevidamente.
## Agilidade/Tiro Rápido (bonusAttacksRemaining): se sobrar ataque bônus,
## consome ele em vez de marcar a ação como feita, liberando outro ataque no
## mesmo turno. bonusAttackWeaponRestriction (Tiro Rápido) exige a MESMA arma
## pro bônus — qualquer outra encerra a rodada ali, sem desfazer o golpe.
func finalize_action(attacker: Dictionary, item: Dictionary) -> void:
	# Montaria: quem gasta CT/ação é o dono do turno (o cavaleiro, quando a
	# Vestruz age carregando alguém); o MP sai de quem executa a habilidade.
	var turn_unit := turn_owner(attacker)
	var restriction = turn_unit.get("bonusAttackWeaponRestriction")
	if restriction != null:
		if item["name"] != restriction["name"]:
			turn_unit["bonusAttacksRemaining"] = 0
			turn_unit["bonusAttackWeaponRestriction"] = null
			turn_unit["hasActed"] = true
		elif turn_unit.get("bonusAttacksRemaining", 0) > 0:
			turn_unit["bonusAttacksRemaining"] -= 1
		else:
			turn_unit["hasActed"] = true
			turn_unit["bonusAttackWeaponRestriction"] = null
	elif turn_unit.get("bonusAttacksRemaining", 0) > 0:
		turn_unit["bonusAttacksRemaining"] -= 1
	else:
		turn_unit["hasActed"] = true
	turn_unit["ct"] -= item["ctCost"]
	if item.get("mpCost", 0):
		attacker["mp"] = maxi(attacker["mp"] - item["mpCost"], 0)
	if int(attacker.get("mpRefundAfterCost", 0)) > 0:
		var refund: int = mini(int(attacker["mpRefundAfterCost"]), int(attacker.get("maxMp", 0)) - int(attacker["mp"]))
		attacker["mp"] = int(attacker["mp"]) + maxi(refund, 0)
		attacker["mpRefundAfterCost"] = 0
		_log("%s recupera %d MP por derrotar o alvo." % [attacker["name"], maxi(refund, 0)])

func bard_inspiration_bonus(u: Dictionary, field: String):
	for effect in u.get("statusEffects", []):
		if effect.get("type", "") == "bardInspiration":
			return effect.get(field, 0)
	return 0

func is_bard_singing(u: Dictionary) -> bool:
	return not (u.get("activeBardSong", {}) as Dictionary).is_empty()

func _remove_bard_inspiration(source_name: String) -> void:
	for target in units:
		target["statusEffects"] = (target.get("statusEffects", []) as Array).filter(func(effect):
			return not (effect.get("type", "") == "bardInspiration" and effect.get("source", "") == source_name)
		)

func _eligible_song_targets(caster: Dictionary, allies: bool) -> Array:
	return units.filter(func(target):
		return target.get("hp", 0) > 0 and not target.get("caged", false) and ((target.get("team", "") == caster.get("team", "")) == allies)
	)

func apply_bard_song_tick(caster: Dictionary, song: Dictionary) -> void:
	var song_kind: String = song.get("songKind", "")
	if song_kind == "inspiration":
		_remove_bard_inspiration(caster["name"])
	var affects_allies: bool = song_kind in ["heal", "inspiration"]
	_log("%s entoa %s — teste individual de 80%% para cada alvo." % [caster["name"], song["name"]])
	for target in _eligible_song_targets(caster, affects_allies):
		if rng.randf() >= float(song.get("hitChance", 0.8)):
			_log("%s não é afetado(a) por %s nesta aplicação." % [target["name"], song["name"]])
			bard_song_feedback_events.append({"targetName":target["name"], "songKind":song_kind, "success":false})
			continue
		match song_kind:
			"heal":
				var hp_before: int = target["hp"]
				var mp_before: int = target.get("mp", 0)
				target["hp"] = mini(target["maxHp"], target["hp"] + 3)
				if target.has("maxMp"): target["mp"] = mini(target["maxMp"], target["mp"] + 1)
				_log("%s recupera %d HP e %d MP com a canção." % [target["name"], target["hp"]-hp_before, target.get("mp",0)-mp_before])
			"inspiration":
				(target["statusEffects"] as Array).append({"type":"bardInspiration","source":caster["name"],"damageBonus":2,"hitBonus":0.1})
				_log("%s recebe +2 de dano e +10 p.p. de acerto pela inspiração." % target["name"])
			"distraction":
				target["ct"] = maxi(0, target["ct"] - 30)
				_log("%s perde 30 de CT pela distração." % target["name"])
			"pain":
				target["hp"] = maxi(0, target["hp"] - 3)
				if target.has("mp"): target["mp"] = maxi(0, target["mp"] - 1)
				_log("%s sofre 3 de dano e perde 1 MP pela canção." % target["name"])
				if target["hp"] <= 0:
					_log("%s foi derrotado!" % target["name"])
					_check_black_slime_split(target)
		bard_song_vfx_events.append({"targetName":target["name"], "songKind":song_kind})
		bard_song_feedback_events.append({"targetName":target["name"], "songKind":song_kind, "success":true})

func stop_bard_song(caster: Dictionary) -> void:
	_remove_bard_inspiration(caster["name"])
	caster.erase("activeBardSong")
	caster.erase("bardSongCleanupPending")

func cast_bard_song(caster: Dictionary, item: Dictionary) -> void:
	record_area_action(caster, item, caster)
	if is_bard_singing(caster) or caster.get("bardSongCleanupPending", false):
		stop_bard_song(caster)
	# "castTurn" (global_turn_count no instante da conjuração) é o que deixa
	# process_bard_song_turn_end saber que já aplicou o tique deste MESMO
	# turno aqui embaixo (apply_bard_song_tick) e não deve aplicar de novo no
	# fim dele — ver comentário lá.
	caster["activeBardSong"] = {"item":item, "applicationsLeft":2, "castTurn":global_turn_count}
	apply_bard_song_tick(caster, item)
	_log("%s mantém %s por mais 2 turno(s) próprios." % [caster["name"], item["name"]])
	finalize_action(caster, item)

## Pedido do usuário: a Canção de Dor (e as outras 3 variações da canção do
## Bardo) tocavam dano/efeito nos alvos no INÍCIO do turno do Bardo — pedido
## foi mover pro FIM do turno do Bardo, chamada agora em advance_to_next_turn
## (mesmo ponto de apply_status_effects_at_turn_end), não mais em
## apply_status_effects_at_turn_start. O guard de castTurn evita reaplicar no
## MESMO turno em que a canção acabou de ser conjurada — cast_bard_song já
## aplicou o 1º tique na hora de conjurar; sem o guard, o fim daquele mesmo
## turno aplicaria de novo (2x no turno da conjuração, 1 a mais que o
## pretendido: a canção precisa durar exatamente 3 turnos, 1 tique por turno).
func process_bard_song_turn_end(caster: Dictionary) -> void:
	if caster.get("bardSongCleanupPending", false):
		stop_bard_song(caster)
	var active: Dictionary = caster.get("activeBardSong", {})
	if active.is_empty(): return
	if int(active.get("castTurn", -1)) == global_turn_count:
		return
	apply_bard_song_tick(caster, active["item"])
	active["applicationsLeft"] = int(active["applicationsLeft"]) - 1
	if int(active["applicationsLeft"]) <= 0:
		caster.erase("activeBardSong")
		caster["bardSongCleanupPending"] = true
		_log("%s conclui %s após a terceira aplicação." % [caster["name"], active["item"]["name"]])

## Chamado no início do turno de uma unidade, antes de qualquer outra coisa
## (game.js:5242): aplica a contagem regressiva/efeito dos status que NÃO
## causam dano por turno (invisibilidade, ofuscamento, atordoamento, pés
## ágeis, lentidão, postura defensiva, evasão, agilidade reduzida, inspiração
## de bardo) e remove os que zeraram. Efeitos que causam dano por turno
## (veneno, sangramento, queimadura, raízes, Congelamento, fúria,
## regeneração) rodam em apply_status_effects_at_turn_end, quando a unidade
## afetada ENCERRA o próprio turno — ver esse comentário para o porquê.
func apply_status_effects_at_turn_start(u: Dictionary) -> void:
	_update_goblin_cowardice(u)
	if not u.has("statusEffects") or (u["statusEffects"] as Array).is_empty():
		return
	var effects: Array = (u["statusEffects"] as Array).duplicate()
	for effect in effects:
		var type: String = effect["type"]
		if type == "accuracyPenalty" or type == "rangedRangePenalty" or type == "invulnerable":
			effect["turnsLeft"] -= 1
			continue
		if type == "invisible" or type == "blinded" or type == "dazed":
			effect["turnsLeft"] -= 1
			if effect["turnsLeft"] <= 0:
				var label: String = {"invisible": "não está mais invisível", "blinded": "não está mais ofuscado(a)", "dazed": "não está mais atordoado(a) pelo som"}[type]
				_log("%s %s." % [u["name"], label])
			continue
		if type == "swiftFeet":
			effect["turnsLeft"] -= 1
			if effect["turnsLeft"] <= 0:
				u["moveRange"] -= effect["moveBonus"]
				_log("%s não está mais com os pés ágeis." % u["name"])
			continue
		# Virar Morcego (Vampiro): mesmo idioma do swiftFeet (turnsLeft:1
		# aplicado durante o próprio turno do Vampiro, decrementado só quando
		# esse MESMO Vampiro começa o turno seguinte — "dura até o início do
		# próximo turno do Vampiro" sem precisar de nenhum contador dedicado).
		# Desfaz exatamente o que cast_vampire_bat_form concedeu: MOV volta
		# ao normal, Voo (mesmo campo booleano da Fada) é removido.
		if type == "batForm":
			effect["turnsLeft"] -= 1
			if effect["turnsLeft"] <= 0:
				u["moveRange"] -= effect["moveBonus"]
				u["flying"] = false
				_log("%s volta à forma normal." % u["name"])
			continue
		if type == "weakened":
			effect["turnsLeft"] -= 1
			if effect["turnsLeft"] <= 0:
				u["moveRange"] += effect["moveReduction"]
				_log("%s não está mais lento por causa do Golpe Debilitante." % u["name"])
			continue
		if type == "guarding":
			effect["turnsLeft"] -= 1
			if effect["turnsLeft"] <= 0:
				_log("%s não está mais na postura defensiva." % u["name"])
			continue
		if type == "huntHowl":
			effect["turnsLeft"] -= 1
			if effect["turnsLeft"] <= 0:
				u["speed"] -= effect["speedBonus"]
				_log("%s não está mais sob o Uivo de Caça." % u["name"])
			continue
		# Casca Fortificada: mesma contagem da Evasiva/Defender (início do turno).
		if type == "barkArmor":
			effect["turnsLeft"] -= 1
			if effect["turnsLeft"] <= 0:
				_log("%s não está mais com a casca fortificada." % u["name"])
			continue
		if type == "focus":
			effect["turnsLeft"] -= 1
			if effect["turnsLeft"] <= 0:
				_log("%s sai do Foco." % u["name"])
			continue
		if type == "heronStance":
			effect["turnsLeft"] -= 1
			if effect["turnsLeft"] <= 0:
				_log("%s deixa a Postura da Garça." % u["name"])
			continue
		if type == "guardBroken":
			effect["turnsLeft"] -= 1
			if effect["turnsLeft"] <= 0:
				_log("%s recupera a guarda." % u["name"])
			continue
		if type == "evasive":
			effect["turnsLeft"] -= 1
			if effect["turnsLeft"] <= 0:
				_log("%s não está mais evasivo(a)." % u["name"])
			continue
		if type == "slowed":
			effect["turnsLeft"] -= 1
			if effect["turnsLeft"] <= 0:
				u["speed"] += effect["speedReduction"]
				_log("%s não está mais lento(a) de agilidade." % u["name"])
			continue
		if type == "bardInspiration":
			# A duração pertence ao ciclo da música do Bardo, não ao turno do alvo.
			continue

	# Reencarnação é um selo permanente e, por isso, não possui turnsLeft.
	# Efeitos temporários continuam sendo removidos normalmente.
	u["statusEffects"] = (u["statusEffects"] as Array).filter(func(e): return e.get("turnsLeft", 1) > 0)

## Chamado quando uma unidade ENCERRA o próprio turno (advance_to_next_turn,
## para quem agiu normalmente; ou dentro do bloco de paralisia de
## begin_turn_for, para quem perde o turno inteiro — ali o "fim do turno" é
## o mesmo instante do "início", já que não há ação no meio). Pedido do
## usuário: todo efeito que causa DANO por turno (veneno, sangramento,
## queimadura, raízes, Congelamento, dreno de HP da Fúria, regeneração que
## fere mortos-vivos) só é resolvido aqui, não mais no início do turno —
## regenBoost fica de fora por nunca causar dano, então continua em
## apply_status_effects_at_turn_start. Remove os efeitos processados aqui
## que zeraram a duração. Se isso matar a unidade, quem chamar percebe pelo
## hp <= 0.
func apply_status_effects_at_turn_end(u: Dictionary) -> void:
	if not u.has("statusEffects") or (u["statusEffects"] as Array).is_empty():
		return
	var effects: Array = (u["statusEffects"] as Array).duplicate()
	for effect in effects:
		var type: String = effect["type"]
		if type == "vineSlow":
			effect["turnsLeft"] -= 1
			if effect["turnsLeft"] <= 0:
				u["moveRange"] += effect["moveReduction"]
				_log("%s se livra dos cipós." % u["name"])
			continue
		if type == "fury":
			if effect.get("hpDrainPerTurn", 0) > 0:
				u["hp"] -= effect["hpDrainPerTurn"]
				_log("%s perde %d de HP por causa da fúria!" % [u["name"], effect["hpDrainPerTurn"]])
			effect["turnsLeft"] -= 1
			if effect["turnsLeft"] <= 0:
				u["speed"] -= effect["speedBonus"]
				_log("%s não está mais em fúria." % u["name"])
			if u["hp"] <= 0:
				u["hp"] = 0
				_log("%s foi derrotado!" % u["name"])
			continue
		if type == "dustBlind":
			effect["turnsLeft"] -= 1
			if effect["turnsLeft"] <= 0:
				_log("%s não está mais com poeira nos olhos." % u["name"])
			continue
		if type == "regen":
			var heal: int = rng.randi_range(effect["healMin"], effect["healMax"])
			# Pedido do usuário: Zumbi/Esqueleto/Fantasma são mortos-vivos —
			# regeneração também os fere em vez de curar (mesma regra de
			# resolve_heal()).
			if u.get("undead", false):
				u["hp"] = maxi(0, u["hp"] - heal)
				_log("%s sofre %d de dano da regeneração profana!" % [u["name"], heal])
				if u["hp"] <= 0:
					_log("%s foi derrotado!" % u["name"])
			else:
				u["hp"] = mini(u["hp"] + heal, u["maxHp"])
				_log("%s regenera %d de vida." % [u["name"], heal])
			effect["turnsLeft"] -= 1
			if effect["turnsLeft"] <= 0:
				_log("%s não está mais regenerando." % u["name"])
			continue
		if type != "poison" and type != "bleed" and type != "burned" and type != "root":
			continue

		# DOT genérico: poison / bleed / burned / root.
		var damage: int = rng.randi_range(effect["damageMin"], effect["damageMax"])
		u["hp"] -= damage
		effect["turnsLeft"] -= 1
		if damage > 0:
			var label: String = "veneno" if type == "poison" else ("sangramento" if type == "bleed" else ("queimadura" if type == "burned" else "raízes"))
			_log("%s sofre %d de dano de %s." % [u["name"], damage, label])
		elif type == "root":
			_log("%s continua imobilizado(a)." % u["name"])

		# Veneno da Espada Curta do Goblin também drena CT a cada turno.
		if effect.get("ctDrainPerTurn"):
			u["ct"] = maxi(u["ct"] - effect["ctDrainPerTurn"], 0)
			_log("%s perde %d de CT por causa do veneno!" % [u["name"], effect["ctDrainPerTurn"]])

		if u["hp"] <= 0:
			u["hp"] = 0
			_log("%s foi derrotado!" % u["name"])

	# Reencarnação permanece até ser consumida na morte do alvo.
	u["statusEffects"] = (u["statusEffects"] as Array).filter(func(e): return e.get("turnsLeft", 1) > 0)
	_check_black_slime_split(u)

# --- Turnos / CT (game.js:5429-5440, 9603-9781) ------------------------------

## Avança o CT de todo mundo vivo (pela própria agilidade) tick a tick até
## alguém cruzar CT_THRESHOLD, então devolve essa unidade — quem tem mais
## agilidade cruza com mais frequência (pode agir 2x antes de quem é mais
## lento agir 1x). Empate: maior CT primeiro, depois maior agilidade.
## Cadáveres não entram nessa corrida (ver alive_units). A Maga presa na
## gaiola (ver _setup_caged_mage) também fica de fora até ser libertada —
## nem acumula CT, nem nunca fica "pronta".
func advance_ct_until_ready() -> Dictionary:
	while true:
		var ready: Array = []
		for u in alive_units():
			if u.get("caged", false) or u.get("riderName", "") != "": continue
			if u["ct"] >= GameConstants.CT_THRESHOLD:
				ready.append(u)
		if ready.size() > 0:
			ready.sort_custom(func(a, b):
				if a["ct"] != b["ct"]:
					return a["ct"] > b["ct"]
				return a["speed"] > b["speed"]
			)
			return ready[0]
		for u in alive_units():
			if u.get("caged", false) or u.get("riderName", "") != "": continue
			u["ct"] = mini(u["ct"] + u["speed"], GameConstants.CT_THRESHOLD)
	push_error("advance_ct_until_ready chamado sem nenhuma unidade viva")
	return {}

## Custo de CT de um movimento: proporcional à distância percorrida — mover
## o alcance todo gasta MOVE_MAX_COST cheio, metade gasta a metade.
func move_ct_cost(u: Dictionary, distance: int) -> int:
	return int(round((float(distance) / float(u["moveRange"])) * GameConstants.MOVE_MAX_COST))

## Regenera 1 HP e 1 MP de quem ocupa Castelo/Montanha do próprio time, uma
## vez por TROCA DE TURNO GLOBAL (não só nos turnos do ocupante).
func tick_structure_regen() -> void:
	for s in structures:
		if s["destroyed"]:
			continue
		var occupant = structure_occupant(s)
		if occupant == null or occupant["team"] != s["team"]:
			continue
		occupant["hp"] = mini(occupant["hp"] + 1, occupant["maxHp"])
		if occupant.has("maxMp"):
			occupant["mp"] = mini(occupant["mp"] + 1, occupant["maxMp"])

## Time com mais HP total (unidades vivas + Castelo/Montanha, se de pé)
## vence se a batalha não terminar até MAX_GLOBAL_TURNS. `team` é "player"
## ou "enemy" (não o array de unidades como no JS original — aqui filtramos
## `units` pelo campo `team`, equivalente pro roster padrão de 10).
func total_team_hp(team: String, structure_type: String) -> int:
	var units_hp := 0
	for u in units:
		if u["team"] == team and u["hp"] > 0:
			units_hp += u["hp"]
	var structure_hp := 0
	for s in structures:
		if s["type"] == structure_type and not s["destroyed"]:
			structure_hp = s["hp"]
			break
	return units_hp + structure_hp

func check_global_turn_limit() -> bool:
	if scenario_id == ScenarioManager.LUA_VALLEY and not battle_ended and global_turn_count >= 100:
		_log("Derrota... os heróis não venceram a Horda em 100 turnos.")
		battle_ended = true
		battle_won = false
		return true
	var turn_limit := max_global_turns()
	if battle_ended or global_turn_count < turn_limit:
		return false
	var player_total := total_team_hp("player", "castle")
	var enemy_total := total_team_hp("enemy", "mountain")
	var player_wins: bool = player_total >= enemy_total
	_log("Limite de %d turnos atingido! HP total: time do Guerreiro %d, time inimigo %d. %s" % [
		turn_limit, player_total, enemy_total,
		("O time do Guerreiro vence no total de HP!" if player_wins else "O time inimigo vence no total de HP!"),
	])
	battle_ended = true
	battle_won = player_wins
	return true

## A luta contra o Slime Negro na Torre é mais longa que as batalhas do
## campo. Centralizar o valor aqui mantém regra e HUD sempre sincronizadas.
## Pedido do usuário: Modo PVP tem limite próprio de 300 turnos (times
## montados pelo jogador podem ser bem mais tanques que o elenco padrão),
## checado antes da regra de cenário — PVP pode rodar em qualquer mapa,
## inclusive a Torre.
func max_global_turns() -> int:
	if pvp_custom_battle:
		return 300
	return 150 if scenario_id == ScenarioManager.TOWER else GameConstants.MAX_GLOBAL_TURNS

## Castelo/Montanha destruído decide a batalha na hora, mesmo com unidades
## de qualquer time ainda vivas. Senão, checa time inimigo/jogador zerado.
func check_battle_outcome() -> bool:
	if battle_ended:
		return true
	var mountain = null
	var castle = null
	for s in structures:
		if s["type"] == "mountain":
			mountain = s
		elif s["type"] == "castle":
			castle = s
	if mountain != null and mountain["destroyed"]:
		_log("Vitória! A Montanha inimiga foi destruída.")
		battle_ended = true
		battle_won = true
		return true
	if castle != null and castle["destroyed"]:
		_log("Derrota... o Castelo foi destruído.")
		battle_ended = true
		battle_won = false
		return true
	var enemy_alive := false
	var player_alive := false
	for u in units:
		# A Maga presa não conta pra manter o time "vivo" — senão o time do
		# Guerreiro nunca seria derrotado enquanto ela seguir na gaiola, mesmo
		# com todo o resto do time morto.
		# Um cadáver auto-revivível (atualmente o Zumbi,
		# `resurrection`) em contagem regressiva NÃO deve mais segurar a
		# vitória — se todo o time inimigo já está com 0 HP (incluindo esses
		# cadáveres ainda "pendentes" de ressuscitar), a batalha já acabou.
		if u["hp"] > 0 and not u.get("caged", false):
			if u["team"] == "enemy":
				enemy_alive = true
			elif u["team"] == "player":
				player_alive = true
	if not enemy_alive:
		_log("Vitória! O time do Guerreiro venceu o combate.")
		battle_ended = true
		battle_won = true
		return true
	if not player_alive:
		_log("Derrota... o time do Guerreiro foi derrotado.")
		battle_ended = true
		battle_won = false
		return true
	return false

## Marca que `u` agiu nesta rodada; quando TODA unidade viva já agiu, avança
## a decomposição de cadáveres em 1 rodada e reabre a marcação.
func note_unit_acted_this_round(u: Dictionary) -> void:
	if not round_acted_units.has(u["name"]):
		round_acted_units.append(u["name"])
	var currently_alive := alive_units()
	if currently_alive.is_empty():
		return
	for au in currently_alive:
		if au.get("riderName", "") != "":
			continue
		if not round_acted_units.has(au["name"]):
			return
	round_acted_units = []
	advance_corpse_decay_for_round()

## Reforço da Horda: criatura garantida a cada 7 turnos globais corridos
## (7, 14, 21, 28...) em vez
## do gatilho "todo herói vivo já agiu" (que segurava reforços indefinidamente
## enquanto qualquer herói ainda não tivesse começado o turno, e por isso
## nunca produzia uma janela estável de "sem inimigos" pra vencer por
## eliminação). Chamado uma vez por virada de turno global (ver
## begin_turn_for); a distribuição de criatura continua a mesma da Torre
## (ver maybe_spawn_lua_creature/_tower_spawn_kind_for_roll).
func maybe_spawn_lua_reinforcement_by_turn() -> void:
	if scenario_id != ScenarioManager.LUA_VALLEY or global_turn_count < 7 or global_turn_count % 7 != 0:
		return
	maybe_spawn_lua_creature()

## 4º Andar: pedido do usuário — um Fogo Vivo garantido a cada 10 turnos
## globais corridos (10, 20, 30...), entrando pela escada da saída, mesma
## lógica de reforço por turno determinístico do Vale da Lua (a cada 7 turnos,
## ver maybe_spawn_lua_reinforcement_by_turn) em vez do sorteio com chance da
## Torre original (maybe_spawn_tower_creature).
func maybe_spawn_tower_floor4_living_fire_by_turn() -> Variant:
	if scenario_id != ScenarioManager.TOWER_FLOOR_4 or global_turn_count < 10 or global_turn_count % 10 != 0:
		return null
	var stairs: Variant = _tower_stairs_tile(ScenarioManager.TOWER_FLOOR_4)
	if stairs == null:
		return null
	var tile: Variant = _first_free_tile_near(stairs["x"], stairs["y"])
	if tile == null:
		return null
	tower_spawn_count += 1
	var spawned := _spawn_dungeon_enemy("living_fire", tower_spawn_count, tile)
	spawned["ct"] = REINFORCEMENT_STARTING_CT
	_log("Um Fogo Vivo aparece pela escada do 4º Andar!")
	return spawned

func advance_corpse_decay_for_round() -> void:
	for u in units:
		if u["hp"] > 0 or not u.has("turnsSinceDeath"):
			continue
		apply_corpse_decay_tick(u)

## Um cadáver perde mais uma rodada da janela de ressurreição (3 rodadas).
## Passado disso, vira alma (ou cura na hora quem já estiver em cima).
func apply_corpse_decay_tick(u: Dictionary) -> void:
	if u.has("resurrection"):
		u["resurrectionTurns"] = int(u.get("resurrectionTurns", 0)) + 1
		var revive: Dictionary = u["resurrection"]
		_log("%s ressuscitará em %d turno(s)." % [u["name"], maxi(0, int(revive["afterTurns"]) - int(u["resurrectionTurns"]))])
		if int(u["resurrectionTurns"]) < int(revive["afterTurns"]):
			return
		u["hp"] = maxi(1, int(round(float(u["maxHp"]) * float(revive["hpPercent"]))))
		u["mp"] = int(round(float(u.get("maxMp", 0)) * float(revive["mpPercent"])))
		u["ct"] = 0
		u["hasMoved"] = false
		u["hasActed"] = false
		u["statusEffects"] = []
		u.erase("turnsSinceDeath")
		u.erase("resurrectionTurns")
		u.erase("_deathHandled")
		u.erase("_boneExplosionHandled")
		# Reencarnação é uso único (ver finalize_death_if_needed) — some o
		# `resurrection` dinâmico junto, diferente do campo permanente do
		# Zumbi (que nunca tem essa marca e continua revivendo pra sempre).
		if u.get("_reincarnationSeal", false):
			u.erase("resurrection")
			u.erase("_reincarnationSeal")
		_log("%s se levanta novamente com %d HP e %d MP!" % [u["name"], u["hp"], u["mp"]])
		return
	u["turnsSinceDeath"] += 1
	_log("%s está morto(a) e perde mais uma rodada de ressurreição!" % u["name"])
	if u["turnsSinceDeath"] <= 3:
		return
	u.erase("turnsSinceDeath")
	var occupant = unit_at(u["x"], u["y"])
	if occupant != null:
		var healed: int = mini(10, occupant["maxHp"] - occupant["hp"])
		occupant["hp"] = mini(occupant["hp"] + 10, occupant["maxHp"])
		var text: String = "+%d" % healed
		if occupant.has("maxMp"):
			var restored_mp: int = mini(5, occupant["maxMp"] - occupant["mp"])
			occupant["mp"] = mini(occupant["mp"] + 5, occupant["maxMp"])
			text += " / +%d MP" % restored_mp
		_log("A alma de %s se dissipa em %s, que recupera %d de vida%s." % [u["name"], occupant["name"], healed, (" e MP" if occupant.has("maxMp") else "")])
	else:
		spawn_soul_at(int(u["x"]), int(u["y"]))
		_log("O corpo de %s se dissipa, deixando uma alma pra trás." % u["name"])

func spawn_soul_at(x: int, y: int, hp_amount: int = 10, mp_amount: int = 5) -> void:
	souls.append({"x": x, "y": y, "hpAmount": hp_amount, "mpAmount": mp_amount})

## Chamado depois de qualquer ação que possa ter zerado o HP de alguém (ver
## `_sync_visuals` em main.gd, chamado após toda ação). Bichos do SPD
## (`IMMEDIATE_SOUL_SPRITE_KEYS`) não deixam cadáver ressuscitável — a morte
## já vira alma na mesma hora, sem a janela de 3 rodadas de
## `apply_corpse_decay_tick`. O resto (heróis/Slime Negro antes de dividir
## count como corpo normal) continua marcando `turnsSinceDeath` pra
## UnitToken.refresh() tocar a animação de morte e manter o cadáver visível.
func finalize_death_if_needed(u: Dictionary) -> void:
	if u["hp"] <= 0 and u.get("riderName", "") != "":
		_release_rider_on_mount_death(u)
	if u["hp"] > 0 or u.has("turnsSinceDeath") or u.get("_deathHandled", false):
		return
	if u.get("spriteKey", "") == "bardo":
		stop_bard_song(u)
	u["_deathHandled"] = true
	if u.get("boneExplosion", false) and not u.get("_boneExplosionHandled", false):
		u["_boneExplosionHandled"] = true
		_trigger_bone_explosion(u)
	# Pedido do usuário: Reencarnação (selo lançado em vida, ver
	# cast_reincarnation) consome o próprio selo na hora da morte e passa a
	# tratar a unidade como se tivesse o campo `resurrection` do Zumbi (mesmo
	# motor de apply_corpse_decay_tick), só que sempre 1 rodada depois e com
	# metade do HP/MP — uso único, por isso erase() em vez de deixar a
	# unidade "marcada pra sempre".
	var has_reincarnation_seal: bool = (u.get("statusEffects", []) as Array).any(func(e): return e["type"] == "reincarnation")
	if has_reincarnation_seal and not u.has("resurrection"):
		u["statusEffects"] = (u["statusEffects"] as Array).filter(func(e): return e["type"] != "reincarnation")
		u["resurrection"] = {"afterTurns": 1, "hpPercent": 0.5, "mpPercent": 0.5}
		# Marca a origem como o selo (não o campo permanente do Zumbi) pra
		# apply_corpse_decay_tick remover `resurrection` de volta depois de
		# reviver — selo de uso único, não vira auto-ressurreição pra sempre.
		u["_reincarnationSeal"] = true
	if u.has("resurrection"):
		u["turnsSinceDeath"] = 0
		u["resurrectionTurns"] = 0
		_log("%s permanece caído(a), mas ainda pode ressuscitar." % u["name"])
	elif u.get("immediateSoul", false) or IMMEDIATE_SOUL_SPRITE_KEYS.has(u.get("spriteKey", "")):
		spawn_soul_at(int(u["x"]), int(u["y"]), int(u.get("soulHp", IMMEDIATE_SOUL_HP)), int(u.get("soulMp", IMMEDIATE_SOUL_MP)))
		_log("%s se desfaz numa alma." % u["name"])
	else:
		u["turnsSinceDeath"] = 0

func _trigger_bone_explosion(skeleton: Dictionary) -> void:
	_log("Os ossos de %s explodem em todas as direções!" % skeleton["name"])
	bone_explosion_events.append({"x":int(skeleton["x"]),"y":int(skeleton["y"])})
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0: continue
			var x := int(skeleton["x"]) + dx
			var y := int(skeleton["y"]) + dy
			if not in_bounds(x, y): continue
			var victim = unit_at(x, y)
			if victim == null: continue
			var damage := rng.randi_range(1, 5)
			victim["hp"] = maxi(0, int(victim["hp"]) - damage)
			_log("A explosão de ossos atinge %s por %d de dano!" % [victim["name"], damage])

## Começa o turno de `u` (game.js:9705): checa limite global de turnos e
## fim de batalha primeiro, aplica status effects de início de turno (só os
## que NÃO causam dano — ver apply_status_effects_at_turn_start), resolve
## paralisia (perde a vez, dano de Congelamento incluso, encadeia pro
## próximo pronto), regenera MP/HP passivo e libera a ação do turno. NÃO
## dispara IA nem UI (Fase 4/6) — quem chamar decide o que fazer com a
## unidade pronta.
func begin_turn_for(u: Dictionary) -> void:
	current_actor = u
	global_turn_count += 1
	_expire_caster_turn_effects(u)
	# Hazard de mapa (não roteiro de campanha) — dispara em qualquer modo,
	# inclusive PVP, ao contrário dos reforços abaixo.
	maybe_trigger_desfiladeiro_wind()
	# Cemitério: vale também no Modo PVP (é hazard do cenário, não roteiro).
	maybe_spawn_graveyard_undead()
	if not pvp_custom_battle:
		maybe_spawn_tower_creature()
		maybe_revive_village_archer()
		maybe_spawn_village_goblin()
		maybe_spawn_forest_chemist()
		maybe_spawn_forest_shaman()
	# Vitória/derrota por eliminação sempre tem prioridade sobre o prazo de
	# turnos — senão os heróis podiam zerar os inimigos da Horda e ainda
	# assim levar a derrota automática se isso coincidisse com o turno 100.
	if check_battle_outcome():
		return
	if check_global_turn_limit():
		return

	note_unit_acted_this_round(u)
	if not pvp_custom_battle:
		maybe_spawn_lua_reinforcement_by_turn()
		maybe_spawn_tower_floor4_living_fire_by_turn()
	apply_status_effects_at_turn_start(u)
	var ridden_mount = mount_of(u)
	if ridden_mount != null:
		apply_status_effects_at_turn_start(ridden_mount)
	if not units.has(u):
		begin_turn_for(advance_ct_until_ready())
		return
	if u.get("spriteKey", "") == "spd_goo" and _unit_footprint_touches_water(u) and u["hp"] > 0:
		u["hp"] = mini(u["maxHp"], u["hp"] + 1)
		_log("%s absorve a água e recupera 1 HP." % u["name"])

	if u["hp"] <= 0:
		# Rede de segurança: dano por turno (veneno/sangramento/queimadura/
		# raízes/fúria/regeneração) não roda mais aqui — ver
		# apply_status_effects_at_turn_end, chamada no FIM do turno de quem
		# tem o status, não no início do turno de quem seria o próximo a agir.
		if check_battle_outcome():
			return
		begin_turn_for(advance_ct_until_ready())
		return

	if is_paralyzed(u):
		# Consome a vez inteira; decrementa aqui (não em
		# apply_status_effects_at_turn_start) pra durar exatamente o número
		# de vezes perdidas, não de "ticks".
		var paralyze_effect = null
		for e in u.get("statusEffects", []):
			if e["type"] == "paralyzed":
				paralyze_effect = e
				break
		paralyze_effect["turnsLeft"] -= 1
		if paralyze_effect["turnsLeft"] <= 0:
			u["statusEffects"] = (u["statusEffects"] as Array).filter(func(e): return e["type"] != "paralyzed")
		u["ct"] -= GameConstants.WAIT_COST
		_log("%s está paralisado(a) e perde a vez!" % u["name"])
		# Dano opcional (Choque paralisa sem dano; Congelamento da Fada
		# machuca a cada turno perdido). Pedido do usuário: dano por turno só
		# se resolve no FIM do turno — como a paralisia consome a vez inteira
		# sem nenhuma ação no meio, o fim é este mesmo instante, não o início.
		if paralyze_effect.has("damageMin"):
			var dmg: int = rng.randi_range(paralyze_effect["damageMin"], paralyze_effect["damageMax"])
			u["hp"] -= dmg
			_log("%s sofre %d de dano por causa do Congelamento." % [u["name"], dmg])
			if u["hp"] <= 0:
				u["hp"] = 0
				_log("%s foi derrotado!" % u["name"])
		# Turno perdido também é um fim de turno parado (Raízes Regeneradoras).
		u["displacedThisTurn"] = false
		u["turnStartX"] = u["x"]
		u["turnStartY"] = u["y"]
		_apply_root_regen(u)
		if check_battle_outcome():
			return
		begin_turn_for(advance_ct_until_ready())
		return

	if u.has("maxMp"):
		u["mp"] = mini(u["mp"] + 1, u["maxMp"])
	if u.get("hpRegenPerTurn", 0) > 0:
		u["hp"] = mini(u["hp"] + u["hpRegenPerTurn"], u["maxHp"])

	u["hasMoved"] = false
	u["hasActed"] = false
	u["cannotMoveThisTurn"] = false
	u["abilityUsedThisTurn"] = false
	# Raízes Regeneradoras: posição de início do turno + qualquer deslocamento
	# (movimento, empurrão) decidem a regeneração no fim do turno.
	u["turnStartX"] = u["x"]
	u["turnStartY"] = u["y"]
	u["displacedThisTurn"] = false
	# Sem isso, o nome/tipo de habilidade usado num turno anterior nunca sai
	# daqui — cast_self_ability bloqueava permanentemente qualquer reuso
	# futuro de Tiro Rápido (ou qualquer outra habilidade de auto-alvo) como
	# se já tivesse sido usada neste turno, mesmo turnos depois.
	u["selfAbilitiesUsedThisTurn"] = []
	u["selfAbilityKindsUsedThisTurn"] = []
	_log("--- Turno: %s ---" % u["name"])

## Fecha o turno de current_actor e encadeia pro próximo pronto (game.js:9603).
## Paga o custo de espera se a unidade não moveu/atacou (com recompensa de
## MP/HP por descansar), zera buffs de "só este turno", decrementa
## armadilhas acionadas, regenera Castelo/Montanha, e começa o turno de
## quem for o próximo pronto (ou encerra, se a batalha já tiver terminado).
## Raízes Regeneradoras (Troncus, campo `rootRegen`): uma vez no FIM de cada
## turno dele, enquanto vivo — "still" HP se não se deslocou em nenhum momento
## do turno (atacar/usar habilidade/virar não conta), "moved" caso contrário
## (andar, ser empurrado, teleporte...). Nunca passa do HP máximo.
func _apply_root_regen(u: Dictionary) -> void:
	var regen: Dictionary = u.get("rootRegen", {})
	if regen.is_empty() or int(u.get("hp", 0)) <= 0:
		return
	var displaced: bool = u.get("displacedThisTurn", false) \
		or int(u.get("turnStartX", u["x"])) != int(u["x"]) or int(u.get("turnStartY", u["y"])) != int(u["y"])
	var amount: int = int(regen["moved"] if displaced else regen["still"])
	var healed: int = mini(amount, int(u["maxHp"]) - int(u["hp"]))
	u["hp"] = int(u["hp"]) + healed
	u["displacedThisTurn"] = false
	u["turnStartX"] = u["x"]
	u["turnStartY"] = u["y"]
	if healed > 0:
		_log("%s regenera %d HP pelas raízes%s." % [u["name"], healed, "" if displaced else " (ficou parado)"])

func advance_to_next_turn() -> void:
	var finished_unit: Dictionary = current_actor
	_check_cage_release(finished_unit)
	# Antes do hazard de tile: se ele aplicar um status novo agora (ex:
	# queimando por pisar em lava), esse status só deve dar seu primeiro
	# tick de dano no PRÓXIMO fim de turno desta unidade, não neste mesmo
	# instante em que acabou de ser aplicado.
	apply_status_effects_at_turn_end(finished_unit)
	_apply_root_regen(finished_unit)
	var finished_mount = mount_of(finished_unit)
	if finished_mount != null:
		apply_status_effects_at_turn_end(finished_mount)
	for maybe_dead_mount in units:
		if maybe_dead_mount["hp"] <= 0 and maybe_dead_mount.get("riderName", "") != "":
			_release_rider_on_mount_death(maybe_dead_mount)
	sync_mounts()
	# Pedido do usuário: tíque da canção do Bardo (Dor/Cura/Inspiração/
	# Distração) agora no FIM do turno do Bardo, não mais no início (ver
	# process_bard_song_turn_end) — mesmo ponto de apply_status_effects_at_
	# turn_end acima, que já é onde as outras DOTs do jogo resolvem quando
	# a unidade afetada ENCERRA o próprio turno.
	if finished_unit.get("spriteKey", "") == "bardo":
		process_bard_song_turn_end(finished_unit)
	_apply_end_turn_tile_hazard(finished_unit)
	if not finished_unit["hasMoved"] and not finished_unit["hasActed"]:
		finished_unit["ct"] -= GameConstants.WAIT_COST
		if finished_unit.has("maxMp"):
			finished_unit["mp"] = mini(finished_unit["mp"] + 3, finished_unit["maxMp"])
		# Guarda contra dano por turno (agora resolvido logo acima, no fim
		# do turno) matando a unidade e este descanso "reviver" ela com +1 HP.
		if finished_unit["hp"] > 0:
			finished_unit["hp"] = mini(finished_unit["hp"] + 1, finished_unit["maxHp"])
		_log("%s descansou o turno inteiro e recupera 3 MP e 1 HP." % finished_unit["name"])
	elif not finished_unit["hasMoved"] or not finished_unit["hasActed"]:
		if finished_unit.has("maxMp"):
			finished_unit["mp"] = mini(finished_unit["mp"] + 2, finished_unit["maxMp"])
			_log("%s recupera 2 MP por não ter usado toda a ação do turno." % finished_unit["name"])

	var has_regen := false
	for e in finished_unit.get("statusEffects", []):
		if e["type"] == "regenBoost" or e["type"] == "regen":
			has_regen = true
			break
	if has_regen:
		finished_unit["ct"] = mini(finished_unit["ct"] + 10, GameConstants.CT_THRESHOLD)
		_log("%s ganha 10 de CT pela Regeneração." % finished_unit["name"])

	# Buffs de "só neste turno" e ataques bônus não usados não sobrevivem.
	finished_unit["oneShotDamageBonus"] = 0
	finished_unit["oneShotDamageBonusSource"] = null
	finished_unit["guaranteedNextHit"] = false
	finished_unit["critBonusNextAttack"] = 0
	finished_unit["bonusAttacksRemaining"] = 0
	finished_unit["extraMovesRemaining"] = 0
	finished_unit["quickDrawNextSword"] = false
	finished_unit["mpRefundAfterCost"] = 0
	finished_unit["goblinLowBlowNextAttack"] = false
	finished_unit["goblinPoisonNextAttack"] = false
	finished_unit["goblinSandNextAttack"] = false

	# Armadilhas: a contagem de 3 turnos só começa quando acionada.
	traps = traps.filter(func(trap):
		if not trap["triggered"]:
			return true
		trap["turnsLeft"] -= 1
		if trap["turnsLeft"] <= 0:
			_log("Uma armadilha se desfez.")
			return false
		return true
	)

	tick_structure_regen()

	if check_battle_outcome():
		return
	begin_turn_for(advance_ct_until_ready())

## Aplica o efeito declarado pelo tile somente quando a unidade realmente
## encerra seu turno ali. Reutiliza o status global `burned`.
func _apply_end_turn_tile_hazard(u: Dictionary) -> void:
	if u.is_empty() or int(u.get("hp", 0)) <= 0:
		return
	var occupied_lava_tiles := 0
	var end_turn_hazard = null
	for tile in footprint_tiles(u):
		var occupied_terrain = terrain_at(int(tile["x"]), int(tile["y"]))
		if occupied_terrain != null and occupied_terrain.get("type", "") == "hazard":
			end_turn_hazard = occupied_terrain
			if occupied_terrain.get("hazard", "") == "lava": occupied_lava_tiles += 1
	if end_turn_hazard == null:
		return
	if end_turn_hazard.get("statusOnEndTurn", "") == "burned":
		var fire_affinity: Dictionary = u.get("elementAffinity", {}).get("fire", {})
		if fire_affinity.get("mode", "") in ["heal", "immune"]:
			# Pedido do usuário: personagem de fogo de corpo normal (1x1) que
			# termina o turno sobre lava cura sempre exatamente 1 HP, não
			# importa quantos quadrados de lava toque nem outra condição.
			# Corpos grandes (ex: Salamandra, footprint 2x2) continuam com a
			# cura escalada por quadrado ocupado (mecânica própria, testada
			# separadamente em test_scenario_floor_4.gd).
			if footprint_width(u) == 1 and footprint_height(u) == 1:
				var actual_heal := mini(1, int(u["maxHp"]) - int(u["hp"]))
				u["hp"] = mini(int(u["maxHp"]), int(u["hp"]) + 1)
				_log("%s absorve o calor da lava sob seu corpo e recupera %d HP!" % [u["name"], actual_heal])
				return
			# Conta somente lava fisicamente sob o footprint. A extensão da poça
			# conectada fora do corpo nunca participa desta cura.
			var healing := 0
			for i in occupied_lava_tiles: healing += rng.randi_range(2, 4)
			var actual_heal := mini(healing, int(u["maxHp"]) - int(u["hp"]))
			u["hp"] = mini(int(u["maxHp"]), int(u["hp"]) + healing)
			_log("%s absorve o calor de %d quadrado(s) de lava sob seu corpo e recupera %d HP!" % [u["name"], occupied_lava_tiles, actual_heal])
			return
		add_status_effect(u, {"type":"burned", "damageMin":2, "damageMax":4, "turnsLeft":3})
		_log("%s encerra o turno sobre lava e fica Queimando!" % u["name"])

# --- Fase 3: habilidades de auto-alvo/buff (game.js:8055-8286) --------------
# Cada `cast_*` muta o estado (status effects, buffs de "próximo ataque",
# MP/CT) e loga a mesma mensagem do original; spawnFloatingText/playAttackFx/
# render/promptNextAction (visual/UI) ficam pra Fase 5/6.

const FIRE_ARROW_COMBO_KINDS := ["haste-attack", "long-shot", "true-shot"]

## Flecha de Gelo é a mesma habilidade que Flecha de Fogo, só trocando o
## efeito elemental — combina com o mesmo trio de habilidades e do mesmo jeito.
const ELEMENTAL_ARROW_KINDS := ["fire-arrow", "ice-arrow"]

## Flecha de Fogo/Flecha de Gelo podem combinar com Tiro Rápido, Tiro Longo OU
## Tiro Certeiro (sempre só 2 habilidades no máximo) — fura o
## singleSelfAbilityPerTurn do Arqueiro só pra esses pares específicos.
func is_self_ability_combo_allowed(u: Dictionary, item: Dictionary) -> bool:
	if item.get("kind", "") == "arrow-rain": return true
	var used: Array = u.get("selfAbilityKindsUsedThisTurn", []).filter(func(k): return k != "arrow-rain")
	if used.is_empty(): return true
	if used.size() != 1:
		return false
	var used_kind = used[0]
	if ELEMENTAL_ARROW_KINDS.has(used_kind):
		return FIRE_ARROW_COMBO_KINDS.has(item["kind"])
	if FIRE_ARROW_COMBO_KINDS.has(used_kind):
		return ELEMENTAL_ARROW_KINDS.has(item["kind"])
	return false

## Ponto único de despacho pras habilidades com targetMode "self". Rastreia
## uso por NOME (repetir a mesma habilidade no turno é sempre bloqueado) e
## por singleSelfAbilityPerTurn (Arqueiro: só uma habilidade de si mesmo por
## turno, salvo a combinação com Flecha de Fogo acima).
func cast_self_ability(caster: Dictionary, item: Dictionary) -> void:
	if item.get("kind", "") == "arrow-rain" and caster.get("mp", 0) < item.get("mpCost", 0): return
	if item.get("kind", "") == "arrow-rain" and caster.get("arrowRainPrepared", false): return
	if caster.get("singleSelfAbilityPerTurn", false) and caster.get("abilityUsedThisTurn", false) and not is_self_ability_combo_allowed(caster, item):
		_log("%s já usou uma habilidade neste turno." % caster["name"])
		return
	if not caster.has("selfAbilitiesUsedThisTurn"):
		caster["selfAbilitiesUsedThisTurn"] = []
	var used_names: Array = caster["selfAbilitiesUsedThisTurn"]
	if used_names.has(item["name"]):
		_log("%s já usou %s neste turno." % [caster["name"], item["name"]])
		return
	used_names.append(item["name"])
	if not caster.has("selfAbilityKindsUsedThisTurn"):
		caster["selfAbilityKindsUsedThisTurn"] = []
	(caster["selfAbilityKindsUsedThisTurn"] as Array).append(item.get("kind"))
	if caster.get("singleSelfAbilityPerTurn", false):
		caster["abilityUsedThisTurn"] = true
	match item["kind"]:
		"arrow-rain":
			caster["arrowRainPrepared"] = true
			finish_free_self_action(caster, item)
			_log("%s prepara Chuva de flechas." % caster["name"])
		"bard-song-heal", "bard-song-inspiration", "bard-song-distraction", "bard-song-pain":
			cast_bard_song(caster, item)
		"invisibility":
			cast_invisibility(caster, item)
		"power-attack":
			cast_power_attack(caster, item)
		"true-shot":
			cast_true_shot(caster, item)
		"long-shot":
			cast_long_shot(caster, item)
		"haste-attack":
			cast_agility(caster, item)
		"swift-feet":
			cast_swift_feet(caster, item)
		"fury":
			cast_fury(caster, item)
		"regen-boost":
			cast_regen_boost(caster, item)
		"weakening-strike":
			cast_weakening_strike(caster, item)
		"low-blow":
			caster["goblinLowBlowNextAttack"] = true
			finish_free_self_action(caster, item)
		"poison-potion":
			caster["goblinPoisonNextAttack"] = true
			finish_free_self_action(caster, item)
		"sand-in-eyes":
			caster["goblinSandNextAttack"] = true
			finish_free_self_action(caster, item)
		"steal-hp", "steal-mp", "steal-ct":
			cast_steal(caster, item)
		"defend":
			cast_defend(caster, item)
		"quick-draw":
			cast_quick_draw(caster, item)
		"heron-stance":
			cast_heron_stance(caster, item)
		"monk-focus":
			cast_monk_focus(caster, item)
		"monk-dash":
			cast_monk_dash(caster, item)
		"monk-meditate":
			cast_monk_meditate(caster, item)
		"evasive":
			cast_evasive_maneuver(caster, item)
		"hunt-howl":
			cast_hunt_howl(caster, item)
		"bark-armor":
			_replace_timed_status(caster, {"type": "barkArmor", "turnsLeft": int(item.get("turns", 2)), "reduction": float(item.get("damageReductionPercent", 0.25))})
			_log("%s endurece a casca: -%d%% de dano físico por %d turno(s)." % [caster["name"], roundi(float(item.get("damageReductionPercent", 0.25)) * 100.0), int(item.get("turns", 2))])
			finish_free_self_action(caster, item)
		"hit-and-run":
			caster["hitAndRun"] = true
			_log("%s prepara Bater e Correr: o próximo acerto libera movimento extra." % caster["name"])
			finish_free_self_action(caster, item)
		"play-dead":
			if caster.get("hasMoved", false):
				_log("Fingir de Morto só pode ser usado antes de mover.")
				return
			add_status_effect(caster, {"type": "invulnerable", "turnsLeft": item.get("turns", 1)})
			# Bloqueia movimento, mas mantém a ação de ataque disponível.
			caster["hasMoved"] = true
			caster["cannotMoveThisTurn"] = true
			_log("%s finge de morto e fica intocável neste turno!" % caster["name"])
			finish_free_self_action(caster, item)
		"explosive-shot":
			cast_explosive_shot(caster, item)
		"fire-arrow":
			cast_fire_arrow(caster, item)
		"ice-arrow":
			cast_ice_arrow(caster, item)
		"vampire-bat-form":
			cast_vampire_bat_form(caster, item)
		"living-fire-self-destruct":
			# Pedido do usuário: Autodestruição não fazia nada ao ser escolhida
			# no menu — faltava "targetMode" (só a IA usava, chamando
			# cast_living_fire_self_destruct direto, sem passar pela UI).
			cast_living_fire_self_destruct(caster, item)
		"rat-pack-call":
			cast_rat_pack_call(caster, item)
		"gnoll-war-howl":
			cast_gnoll_war_howl(caster, item)
		"snake-skin":
			cast_snake_skin(caster, item)
		"slime-jump":
			pass

func cast_rat_pack_call(caster: Dictionary, item: Dictionary) -> void:
	for ally in team_units(caster["team"]):
		if ally.get("hp", 0) <= 0 or ally.get("spriteKey", "") != "spd_rat": continue
		if manhattan(caster, ally) > int(item.get("radius", 3)): continue
		ally["ct"] = mini(100, int(ally.get("ct", 0)) + int(item.get("ctBonus", 15)))
		_replace_timed_status(ally, {"type":"evasive","turnsLeft":int(item.get("turns", 2)),"amount":float(item.get("evasionBonus", 0.1))})
		_log("%s ouve o Guincho da Ninhada e recebe +15 CT e +10%% de esquiva." % ally["name"])
	finalize_action(caster, item)

func cast_gnoll_war_howl(caster: Dictionary, item: Dictionary) -> void:
	for ally in team_units(caster["team"]):
		if ally.get("hp", 0) <= 0 or manhattan(caster, ally) > int(item.get("radius", 3)): continue
		_replace_timed_status(ally, {"type":"warHowl","turnsLeft":int(item.get("turns", 2)),"damageBonus":int(item.get("damageBonus", 2)),"accuracyBonus":float(item.get("accuracyBonus", 0.1))})
		_log("%s recebe o Uivo de Guerra: +2 dano e +10%% acerto." % ally["name"])
	finalize_action(caster, item)

func cast_snake_skin(caster: Dictionary, item: Dictionary) -> void:
	var heal := mini(int(item.get("healMax", 5)), int(caster.get("maxHp", 0)) - int(caster.get("hp", 0)))
	caster["hp"] = mini(int(caster.get("maxHp", 0)), int(caster.get("hp", 0)) + int(item.get("healMax", 5)))
	var removable := ["poison", "bleed", "burned", "slowed", "weakened", "accuracyPenalty", "rangedRangePenalty", "defenseDown"]
	caster["statusEffects"] = (caster.get("statusEffects", []) as Array).filter(func(effect): return not removable.has(effect.get("type", "")))
	_replace_timed_status(caster, {"type":"evasive","turnsLeft":int(item.get("turns", 1)),"amount":float(item.get("evasionBonus", 0.15))})
	_log("%s usa Troca de Pele, recupera %d HP e remove efeitos negativos." % [caster["name"], heal])
	finalize_action(caster, item)

func _replace_timed_status(unit: Dictionary, effect: Dictionary) -> void:
	var effects: Array = unit.get("statusEffects", [])
	effects = effects.filter(func(existing): return existing.get("type", "") != effect.get("type", ""))
	effects.append(effect)
	unit["statusEffects"] = effects

## Habilidades "livres": não gastam CT nem marcam hasActed, só MP — a
## unidade continua o turno normalmente depois de ativar.
func finish_free_self_action(caster: Dictionary, item: Dictionary) -> void:
	caster["mp"] = maxi(caster["mp"] - item.get("mpCost", 0), 0)

func cast_power_attack(caster: Dictionary, item: Dictionary) -> void:
	caster["oneShotDamageBonus"] = caster.get("oneShotDamageBonus", 0) + item["damageBonus"]
	caster["oneShotDamageBonusSource"] = item["name"]
	# Pedido do usuário: além do dano bônus, o Ataque Poderoso também soma
	# chance de crítico ao próximo golpe (mesmo campo do Tiro Certeiro).
	caster["critBonusNextAttack"] = caster.get("critBonusNextAttack", 0.0) + item.get("critBonus", 0.0)
	_log("%s usa %s e prepara um golpe mais forte (+%d de dano e +%d%% de crítico no próximo ataque)!" % [caster["name"], item["name"], item["damageBonus"], int(round(item.get("critBonus", 0.0) * 100.0))])
	finish_free_self_action(caster, item)

func cast_true_shot(caster: Dictionary, item: Dictionary) -> void:
	caster["guaranteedNextHit"] = true
	caster["critBonusNextAttack"] = caster.get("critBonusNextAttack", 0.0) + item["critBonus"]
	_log("%s usa %s: próximo ataque com 100%% de acerto e +%d%% de crítico!" % [caster["name"], item["name"], int(round(item["critBonus"] * 100.0))])
	finish_free_self_action(caster, item)

## Tiro Longo (Arqueiro): dobra o alcance só do PRÓXIMO ataque — a flag é
## lida na mira (Fase 5/6, ainda não portada) e resetada em resolve_single_hit.
func cast_long_shot(caster: Dictionary, item: Dictionary) -> void:
	caster["doubleRangeNextAttack"] = true
	_log("%s usa %s: o alcance do próximo ataque está dobrado!" % [caster["name"], item["name"]])
	finish_free_self_action(caster, item)

## Tiro Explosivo (Químico): bônus de dano rolado JÁ na hora de ativar. A
## queimadura só "pega" se o próximo golpe realmente acertar.
func cast_explosive_shot(caster: Dictionary, item: Dictionary) -> void:
	var bonus: int = rng.randi_range(item["bonusDamageMin"], item["bonusDamageMax"])
	caster["oneShotDamageBonus"] = caster.get("oneShotDamageBonus", 0) + bonus
	caster["oneShotDamageBonusSource"] = item["name"]
	caster["burnNextAttackTurns"] = item["burnTurns"]
	_log("%s usa %s! Próximo ataque: +%d de dano e queima o alvo se acertar." % [caster["name"], item["name"], bonus])
	finish_free_self_action(caster, item)

## Flecha de Fogo (Arqueiro): diferente do Tiro Explosivo, a queimadura
## aplica MESMO SE ERRAR — só o bônus de dano extra depende de acertar.
func cast_fire_arrow(caster: Dictionary, item: Dictionary) -> void:
	var bonus: int = rng.randi_range(item["bonusDamageMin"], item["bonusDamageMax"])
	caster["oneShotDamageBonus"] = caster.get("oneShotDamageBonus", 0) + bonus
	caster["oneShotDamageBonusSource"] = item["name"]
	caster["burnNextAttackAlwaysTurns"] = item["burnTurns"]
	_log("%s usa %s! Próxima flecha queima o alvo mesmo se errar, e causa +%d de dano se acertar." % [caster["name"], item["name"], bonus])
	finish_free_self_action(caster, item)

## Flecha de Gelo (Arqueiro): mesma regra da Flecha de Fogo (efeito aplica
## mesmo se errar, bônus de dano só se acertar), trocando queimadura por
## redução de agilidade — mesmo efeito do Raio de Gelo (weapons.gd:"iceRay").
func cast_ice_arrow(caster: Dictionary, item: Dictionary) -> void:
	var bonus: int = rng.randi_range(item["bonusDamageMin"], item["bonusDamageMax"])
	caster["oneShotDamageBonus"] = caster.get("oneShotDamageBonus", 0) + bonus
	caster["oneShotDamageBonusSource"] = item["name"]
	caster["slowNextAttackAlwaysTurns"] = item["slowTurns"]
	caster["slowNextAttackAlwaysAmount"] = item["slowAmount"]
	_log("%s usa %s! Próxima flecha reduz a agilidade do alvo mesmo se errar, e causa +%d de dano se acertar." % [caster["name"], item["name"], bonus])
	finish_free_self_action(caster, item)

func cast_weakening_strike(caster: Dictionary, item: Dictionary) -> void:
	caster["weakeningStrikeNextAttack"] = true
	_log("%s usa %s: se o próximo ataque acertar, vai debilitar o alvo!" % [caster["name"], item["name"]])
	finish_free_self_action(caster, item)

func cast_steal(caster: Dictionary, item: Dictionary) -> void:
	# Roubo é uma preparação, como as habilidades de flecha do Arqueiro:
	# o efeito é aplicado no próximo ataque de Punhal ou Besta.
	caster["stealNextAttack"] = item.get("kind", "")
	_log("%s prepara %s para o próximo ataque de Punhal ou Besta!" % [caster["name"], item["name"]])
	finish_free_self_action(caster, item)

func cast_evasive_maneuver(caster: Dictionary, item: Dictionary) -> void:
	var existing = null
	for e in caster.get("statusEffects", []):
		if e["type"] == "evasive":
			existing = e
			break
	if existing != null:
		existing["turnsLeft"] = item["turns"]
	else:
		(caster["statusEffects"] as Array).append({"type": "evasive", "turnsLeft": item["turns"], "amount": 0.2})
	_log("%s usa %s e fica mais difícil de acertar por %d turno(s)!" % [caster["name"], item["name"], item["turns"]])
	finish_free_self_action(caster, item)

## Defender (Guerreiro): postura defensiva. Um segundo uso só renova a
## duração (não empilha redução de dano).
func cast_defend(caster: Dictionary, item: Dictionary) -> void:
	var existing = null
	for e in caster.get("statusEffects", []):
		if e["type"] == "guarding":
			existing = e
			break
	if existing != null:
		existing["turnsLeft"] = item["turns"]
	else:
		(caster["statusEffects"] as Array).append({"type": "guarding", "turnsLeft": item["turns"], "damageReduction": 2})
	_log("%s usa %s e reduz o dano recebido em 2 por %d turno(s)!" % [caster["name"], item["name"], item["turns"]])
	finish_free_self_action(caster, item)

# --- Monge: Foco, Dash, Meditar e Chute do Dragao. (ver autoload/rules/monk_rules.gd) ---
func cast_monk_focus(caster: Dictionary, item: Dictionary) -> void: MonkRules.cast_monk_focus(self, caster, item)
func cast_monk_dash(caster: Dictionary, item: Dictionary) -> void: MonkRules.cast_monk_dash(self, caster, item)
## Status negativos que Meditar remove — mesma lista da Troca de Pele da
## Cobra (cast_snake_skin) mais os que tiram o turno/atrapalham a mira
## (paralisia, raízes, atordoamento, cegueira, marcação).
const MONK_MEDITATE_REMOVABLE_STATUSES := ["poison", "bleed", "burned", "root", "paralyzed", "blinded", "dazed", "slowed", "weakened", "accuracyPenalty", "rangedRangePenalty", "defenseDown", "marked", "guardBroken", "dustBlind"]

func cast_monk_meditate(caster: Dictionary, item: Dictionary) -> void: MonkRules.cast_monk_meditate(self, caster, item)
# --- Samurai: Saque Rapido, Postura da Garca, Corte Iaijutsu, Corte Crescente e requisitos de uso de habilidades. (ver autoload/rules/samurai_rules.gd) ---
func cast_heron_stance(caster: Dictionary, item: Dictionary) -> void: SamuraiRules.cast_heron_stance(self, caster, item)
func _try_heron_counter(attacker: Dictionary, defender: Dictionary, item: Dictionary, hit_chance: Variant, hit_roll: float, is_counter_attack: bool) -> void: SamuraiRules._try_heron_counter(self, attacker, defender, item, hit_chance, hit_roll, is_counter_attack)
func item_requirements_met(u: Dictionary, item: Dictionary) -> bool: return SamuraiRules.item_requirements_met(self, u, item)
func cast_quick_draw(caster: Dictionary, item: Dictionary) -> void: SamuraiRules.cast_quick_draw(self, caster, item)
func cast_agility(caster: Dictionary, item: Dictionary) -> void:
	# A habilidade pode ser usada antes OU depois do ataque normal. Antes do
	# primeiro golpe, guardamos um ataque bônus para finalize_action consumir.
	# Depois de um golpe já feito, reabrimos diretamente a ação e não somamos
	# outro bônus — assim existe exatamente mais um ataque, nunca um terceiro.
	if caster.get("hasActed", false):
		caster["hasActed"] = false
		caster["bonusAttacksRemaining"] = 0
	else:
		caster["bonusAttacksRemaining"] = caster.get("bonusAttacksRemaining", 0) + 1
	caster["bonusAttackWeaponRestriction"] = item.get("restrictBonusToWeapon")
	_log("%s usa %s e poderá atacar mais uma vez neste turno!" % [caster["name"], item["name"]])
	finish_free_self_action(caster, item)

## Pés Ágeis (Goblin): dobra o deslocamento só até o início do próprio
## próximo turno (turnsLeft:1 — expira em apply_status_effects_at_turn_start,
## exatamente quando moveRange volta a ser consultado pra mover).
func cast_swift_feet(caster: Dictionary, item: Dictionary) -> void:
	var existing = null
	for e in caster.get("statusEffects", []):
		if e["type"] == "swiftFeet":
			existing = e
			break
	if existing != null:
		existing["turnsLeft"] = 1
	else:
		(caster["statusEffects"] as Array).append({"type": "swiftFeet", "turnsLeft": 1, "moveBonus": caster["moveRange"]})
		caster["moveRange"] *= 2
	_log("%s usa %s e dobra seu deslocamento neste turno!" % [caster["name"], item["name"]])
	finish_free_self_action(caster, item)

## Virar Morcego (Vampiro): ação livre (ctCost 0, finish_free_self_action só
## desconta MP, não marca hasActed — o Vampiro continua podendo mover/atacar
## no mesmo turno) que dura até o início do PRÓPRIO próximo turno do
## Vampiro, mesmo idioma exato de cast_swift_feet (status turnsLeft:1,
## revertido em apply_status_effects_at_turn_start). MOV dobra (mesmo campo
## moveRange), Voo é concedido pelo mesmíssimo campo booleano `flying` que a
## Fada já usa em todo o resto do motor (terreno/alcance/pathfinding — ver
## resolve_single_hit `is_melee_weapon and defender.get("flying", false)` e
## compute_reachable), e o lifesteal de Toque Vampírico/Mordida passa a
## contar 100% via `lifestealMultiplierOverride` no próprio status (ver
## resolve_single_hit). Reusar o cast já em andamento (existing != null) só
## renova a duração, sem dobrar MOV de novo nem reconceder Voo — protege
## contra o "não pode ser usada repetidamente pra gerar exploit" pedido.
func cast_vampire_bat_form(caster: Dictionary, item: Dictionary) -> void:
	var existing = null
	for e in caster.get("statusEffects", []):
		if e["type"] == "batForm":
			existing = e
			break
	if existing != null:
		existing["turnsLeft"] = 1
		_log("%s renova a forma de morcego." % caster["name"])
	else:
		(caster["statusEffects"] as Array).append({"type": "batForm", "turnsLeft": 1, "moveBonus": caster["moveRange"], "lifestealMultiplierOverride": 1.0})
		caster["moveRange"] *= 2
		caster["flying"] = true
		_log("%s se transforma em morcego! Deslocamento dobrado, ganha Voo e o lifesteal sobe para 100%%." % caster["name"])
	finish_free_self_action(caster, item)

func cast_fury(caster: Dictionary, item: Dictionary) -> void:
	var existing = null
	for e in caster.get("statusEffects", []):
		if e["type"] == "fury":
			existing = e
			break
	if existing != null:
		# Já em fúria: só renova a duração, não soma o bônus de novo.
		existing["turnsLeft"] = item["turns"]
	else:
		(caster["statusEffects"] as Array).append({
			"type": "fury", "turnsLeft": item["turns"], "damageBonus": item["damageBonus"],
			"speedBonus": item["speedBonus"], "hpDrainPerTurn": item["hpDrainPerTurn"],
		})
		caster["speed"] += item["speedBonus"]
	_log("%s entra em fúria! +%d de dano e +%d de agilidade por %d turno(s)." % [caster["name"], item["damageBonus"], item["speedBonus"], item["turns"]])
	finish_free_self_action(caster, item)

## Regeneração (Troll): igual à Fúria, mas sem lado ruim. add_status_effect
## já cuida de estender a duração em vez de empilhar (ver DOT_HOT_TYPES).
func cast_regen_boost(caster: Dictionary, item: Dictionary) -> void:
	add_status_effect(caster, {"type": "regenBoost", "turnsLeft": item["turns"], "bonus": item["regenBonus"]})
	_log("%s usa %s e aumenta a própria regeneração em +%d por %d turno(s)!" % [caster["name"], item["name"], item["regenBonus"], item["turns"]])
	finish_free_self_action(caster, item)

## Invisibilidade (Ladino): diferente das outras "self" acima, tem ctCost de
## verdade — consome a ação do turno (finalize_action), não é livre.
func cast_invisibility(caster: Dictionary, item: Dictionary) -> void:
	add_status_effect(caster, {"type": "invisible", "turnsLeft": item["turns"]})
	_log("%s usa %s e some de vista por %d turnos!" % [caster["name"], item["name"], item["turns"]])
	finalize_action(caster, item)

# --- Geometria de mira (game.js:4406-4462) -----------------------------------

## Vira `u` pra encarar `tile` — só as 4 direções cardeais, escolhendo o
## eixo dominante do deslocamento.
func set_facing_towards(u: Dictionary, tile: Dictionary) -> void:
	var dx: int = tile["x"] - u["x"]
	var dy: int = tile["y"] - u["y"]
	if dx == 0 and dy == 0:
		return
	if abs(dx) >= abs(dy):
		u["facing"] = {"dx": (1 if dx > 0 else -1), "dy": 0}
	else:
		u["facing"] = {"dx": 0, "dy": (1 if dy > 0 else -1)}

## Algoritmo de Bresenham: lista os tiles que uma linha reta entre dois
## pontos atravessa — usado pra checar obstrução no caminho de ataques que
## exigem linha limpa.
func bresenham_line(x0: int, y0: int, x1: int, y1: int) -> Array:
	var points: Array = []
	var dx: int = abs(x1 - x0)
	var dy: int = abs(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx - dy
	var x: int = x0
	var y: int = y0
	while true:
		points.append({"x": x, "y": y})
		if x == x1 and y == y1:
			break
		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
	return points

func has_line_of_sight(from_x: int, from_y: int, to_x: int, to_y: int) -> bool:
	var path := bresenham_line(from_x, from_y, to_x, to_y)
	if path.size() <= 2:
		return true
	var eye_level: int = maxi(elevation_at(from_x, from_y), elevation_at(to_x, to_y))
	for i in range(1, path.size() - 1):
		if elevation_at(path[i]["x"], path[i]["y"]) > eye_level:
			return false
	return true

## Acha o primeiro tile OCUPADO no caminho reto até target_tile (pra ataques
## que exigem linha limpa); se nada bloquear, o impacto acontece no próprio
## target_tile. Props não obstruem; as casas do próprio corpo (2x2) também não.
func resolve_obstructed_target(caster: Dictionary, target_tile: Dictionary) -> Dictionary:
	var path: Array = bresenham_line(caster["x"], caster["y"], target_tile["x"], target_tile["y"])
	path = path.slice(1)
	for tile in path:
		if unit_contains_tile(caster, tile["x"], tile["y"]):
			continue
		var blocker = unit_at(tile["x"], tile["y"])
		var is_final: bool = tile["x"] == target_tile["x"] and tile["y"] == target_tile["y"]
		if blocker != null or is_final:
			return tile
	return target_tile

# --- Fase 3: habilidades de alvo único (game.js:7778-8008, 8459-8485) -------

## Autoridade central de cura instantânea — usada tanto por magia de alvo
## único quanto (chamada em loop) pelas de área. Pedido do usuário: Zumbi/
## Esqueleto/Fantasma são mortos-vivos (`undead`) — cura os fere em vez de
## curar, mesmo tropo de "unliving recoil from healing" de RPGs clássicos.
func resolve_heal(caster: Dictionary, target: Dictionary, spell: Dictionary) -> void:
	var is_hit: bool = rng.randf() < float(spell["hitChance"])
	if not is_hit:
		_log("%s tenta curar %s com %s, mas falha!" % [caster["name"], target["name"], spell["name"]])
		return
	var heal_amount: int = rng.randi_range(spell["healMin"], spell["healMax"])
	if target.get("undead", false):
		target["hp"] = maxi(0, target["hp"] - heal_amount)
		_log("%s tenta curar %s com %s, mas o morto-vivo sofre %d de dano!" % [caster["name"], target["name"], spell["name"], heal_amount])
		return
	target["hp"] = mini(target["hp"] + heal_amount, target["maxHp"])
	_log("%s cura %s com %s, recuperando %d de vida." % [caster["name"], target["name"], spell["name"], heal_amount])

## Infligir Ferimentos (Lich): a MESMA rolagem/quantia de resolve_heal
## (healMin/healMax/hitChance do item — pedido do usuário: "a quantidade
## usada deve ser exatamente a mesma que Cura restauraria"), só com as duas
## metades trocadas — resolve_heal já fere morto-vivo em vez de curar
## quando a Cura (mágica benigna) toca um morto-vivo; aqui é o oposto:
## Infligir Ferimentos (magia necromântica) cura morto-vivo e fere vivo.
func resolve_harm(caster: Dictionary, target: Dictionary, spell: Dictionary) -> void:
	var is_hit: bool = rng.randf() < float(spell["hitChance"])
	if not is_hit:
		_log("%s tenta usar %s em %s, mas falha!" % [caster["name"], spell["name"], target["name"]])
		return
	var amount: int = rng.randi_range(spell["healMin"], spell["healMax"])
	if target.get("undead", false):
		target["hp"] = mini(target["hp"] + amount, target["maxHp"])
		_log("%s usa %s em %s, regenerando %d de vida (morto-vivo)." % [caster["name"], spell["name"], target["name"], amount])
		return
	target["hp"] = maxi(0, target["hp"] - amount)
	_log("%s usa %s em %s, causando %d de dano." % [caster["name"], spell["name"], target["name"], amount])

## Igual resolve_heal (mesma rolagem de acerto), mas aplica o status "regen"
## em vez de curar na hora — a cura de verdade acontece aos poucos, no
## início dos próximos turnos (ver apply_status_effects_at_turn_start).
func resolve_regen(caster: Dictionary, target: Dictionary, spell: Dictionary) -> void:
	var is_hit: bool = rng.randf() < float(spell["hitChance"])
	if not is_hit:
		_log("%s tenta curar %s com %s, mas falha!" % [caster["name"], target["name"], spell["name"]])
		return
	add_status_effect(target, {"type": "regen", "healMin": spell["healMin"], "healMax": spell["healMax"], "turnsLeft": spell["regenTurns"]})
	_log("%s usa %s em %s, que passa a regenerar vida." % [caster["name"], spell["name"], target["name"]])

## Poção de Mana (Químico): igual à cura, mas recupera MP em vez de HP —
## não faz nada em quem não usa MP (maxMp indefinido).
func resolve_mana_restore(caster: Dictionary, target: Dictionary, spell: Dictionary) -> void:
	var is_hit: bool = rng.randf() < float(spell["hitChance"])
	if not is_hit:
		_log("%s tenta usar %s em %s, mas falha!" % [caster["name"], spell["name"], target["name"]])
		return
	if not target.has("maxMp"):
		_log("%s usa %s em %s, mas %s não usa MP." % [caster["name"], spell["name"], target["name"], target["name"]])
		return
	var amount: int = rng.randi_range(spell["manaMin"], spell["manaMax"])
	target["mp"] = mini(target["mp"] + amount, target["maxMp"])
	_log("%s usa %s em %s, recuperando %d de MP." % [caster["name"], spell["name"], target["name"], amount])

## Poção de Cura / Poção de Mana (Químico): como um ataque à distância que
## exige linha limpa — se algo estiver no caminho até o aliado escolhido, o
## item afeta quem bloqueou o caminho em vez do alvo pretendido.
func cast_supply_item(caster: Dictionary, target: Dictionary, item: Dictionary) -> void:
	set_facing_towards(caster, target)
	var impact_tile: Dictionary = resolve_obstructed_target(caster, {"x": target["x"], "y": target["y"]})
	var actual_target = unit_at(impact_tile["x"], impact_tile["y"])

	if actual_target == null:
		_log("%s usa %s, mas não havia ninguém no caminho." % [caster["name"], item["name"]])
		finalize_action(caster, item)
		return
	if actual_target["name"] != target["name"]:
		_log("%s tentou usar %s em %s, mas algo bloqueou o caminho — %s foi afetado(a) no lugar!" % [caster["name"], item["name"], target["name"], actual_target["name"]])

	if item.has("manaMin"):
		resolve_mana_restore(caster, actual_target, item)
	else:
		resolve_heal(caster, actual_target, item)
	finalize_action(caster, item)

## Ressurreição (Xamã/Fada/Químico): alvo já validado como cadáver do mesmo
## time pelo chamador (via dead_unit_at). CT zerado de propósito — sem isso
## a unidade podia voltar já com CT suficiente pra agir de novo na mesma
## rodada. Volta "limpo": nenhum status de antes da morte sobrevive —
## alguns tipos mexem direto num atributo (fury/swiftFeet somam,
## weakened/slowed subtraem), então precisa desfazer isso antes de zerar.
func cast_resurrect(caster: Dictionary, target: Dictionary, spell: Dictionary) -> void:
	set_facing_towards(caster, target)
	var is_hit: bool = rng.randf() < float(spell["hitChance"])
	if not is_hit:
		_log("%s tenta ressuscitar %s com %s, mas falha!" % [caster["name"], target["name"], spell["name"]])
		finalize_action(caster, spell)
		return
	# Zumbis já estão tentando ressuscitar
	# sozinhos (`resurrection` + contagem regressiva própria via
	# apply_corpse_decay_tick) — forçar uma ressurreição externa nesse meio
	# tempo atrapalha o processo e mata o morto-vivo de vez, virando alma
	# (mesmo destino de um cadáver comum que termina de decompor).
	if target.has("resurrection") and target.has("turnsSinceDeath"):
		target.erase("turnsSinceDeath")
		target.erase("resurrectionTurns")
		target.erase("_deathHandled")
		spawn_soul_at(int(target["x"]), int(target["y"]))
		_log("%s tenta ressuscitar %s com %s, mas a ressurreição forçada acaba de vez com o morto-vivo, que vira uma alma!" % [caster["name"], target["name"], spell["name"]])
		finalize_action(caster, spell)
		return
	var revived_hp: int = _revive_unit_to_half_hp(target)
	_log("%s ressuscita %s com %s! Volta com %d de vida." % [caster["name"], target["name"], spell["name"], revived_hp])
	finalize_action(caster, spell)

## Extraído de cast_resurrect pra ser reutilizado por cast_reanimate
## (Lich): metade do HP máximo, CT zerado, desfaz qualquer efeito que
## mexia em atributo direto (fúria/pés ágeis/enfraquecido/lentidão) ANTES
## de limpar o array de status por completo — mesma ordem de sempre, senão
## o bônus/penalidade fica "vazado" no atributo permanentemente. Devolve o
## HP com que a unidade voltou, só pra log de quem chamou.
func _revive_unit_to_half_hp(target: Dictionary) -> int:
	var revived_hp: int = int(round(float(target["maxHp"]) / 2.0))
	target["hp"] = revived_hp
	target["ct"] = 0
	target.erase("turnsSinceDeath")
	target.erase("_deathHandled")
	for effect in target.get("statusEffects", []):
		if effect["type"] == "fury" or effect["type"] == "huntHowl":
			target["speed"] -= effect["speedBonus"]
		elif effect["type"] == "swiftFeet":
			target["moveRange"] -= effect["moveBonus"]
		elif effect["type"] == "weakened" or effect["type"] == "vineSlow":
			target["moveRange"] += effect["moveReduction"]
		elif effect["type"] == "slowed":
			target["speed"] += effect["speedReduction"]
	target["statusEffects"] = []
	return revived_hp

## Reanimação (Lich): mesma matemática de cast_resurrect (_revive_unit_to_
## half_hp), mas só pode ser usada em mortos-vivos (checado por quem
## seleciona o alvo — ver pick_resurrect_target(..., require_undead=true) e
## a UI/AI que chamam esta função) e NUNCA "acaba de vez virando alma" —
## essa regra de cast_resurrect existe só pro caso acidental de um HERÓI
## reviver à força um morto-vivo que já tinha revival próprio agendado
## (Zumbi). Aqui é o oposto: o Lich reanimando SEU PRÓPRIO Zumbi é o
## fluxo normal e esperado, então cancela o contador de revival automático
## dele (resurrectionTurns) pra não duplicar uma 2ª ressurreição depois, em
## vez de destruir a unidade.
func cast_reanimate(caster: Dictionary, target: Dictionary, spell: Dictionary) -> void:
	set_facing_towards(caster, target)
	var is_hit: bool = rng.randf() < float(spell["hitChance"])
	if not is_hit:
		_log("%s tenta reanimar %s com %s, mas falha!" % [caster["name"], target["name"], spell["name"]])
		finalize_action(caster, spell)
		return
	target.erase("resurrectionTurns")
	var revived_hp: int = _revive_unit_to_half_hp(target)
	_log("%s reanima %s com %s! Volta com %d de vida." % [caster["name"], target["name"], spell["name"], revived_hp])
	finalize_action(caster, spell)

## Prisão de Vinhas (Xamã): imobiliza o alvo (status "root"); bloqueada por
## invisibilidade como qualquer magia de alvo único (não é área).
func cast_root_spell(caster: Dictionary, target: Dictionary, spell: Dictionary) -> void:
	set_facing_towards(caster, target)
	if blocked_by_invisibility(spell, target):
		_log("%s tenta atingir %s com %s, mas %s está invisível!" % [caster["name"], target["name"], spell["name"], target["name"]])
		finalize_action(caster, spell)
		return
	if spell.get("enemyOnly", false) and target["team"] == caster["team"]:
		_log("%s só pode ser usada em inimigos." % spell["name"])
		return
	var is_hit: bool = rng.randf() < float(get_effective_hit_chance(caster, target, spell, manhattan(caster, target)))
	if not is_hit:
		_log("%s lança %s em %s e erra!" % [caster["name"], spell["name"], target["name"]])
	elif spell.get("refreshesDuration", false):
		# Raízes Aprisionadoras (Troncus): reaplicar renova, não soma turnos.
		if not (target.get("statusImmunities", []) as Array).has("root"):
			_replace_timed_status(target, {"type": "root", "damageMin": spell["damageMin"], "damageMax": spell["damageMax"], "turnsLeft": spell["turns"]})
		_log("%s prende %s com %s por %d turno(s)!" % [caster["name"], target["name"], spell["name"], spell["turns"]])
	else:
		add_status_effect(target, {"type": "root", "damageMin": spell["damageMin"], "damageMax": spell["damageMax"], "turnsLeft": spell["turns"]})
		_log("%s prende %s com %s!" % [caster["name"], target["name"], spell["name"]])
	finalize_action(caster, spell)

## Pedido do usuário: Reencarnação (Maga/Xamã/Fada/Lich). Marca um alvo VIVO
## (unit_at só devolve unidades vivas — mesma garantia de "não pode ser
## lançada sobre um cadáver" sem checagem extra) com o status "reincarnation"
## (sem turnsLeft: fica indefinidamente até ser consumido — nenhum laço de
## decaimento de status reconhece esse tipo, ver apply_status_effects_at_*).
## finalize_death_if_needed é quem consome o selo na hora da morte, tratando
## a unidade como se tivesse o campo `resurrection` do Zumbi (mesmo motor:
## apply_corpse_decay_tick), só que sempre com 1 rodada e metade do HP/MP.
func cast_reincarnation(caster: Dictionary, target: Dictionary, spell: Dictionary) -> void:
	set_facing_towards(caster, target)
	if blocked_by_invisibility(spell, target):
		_log("%s tenta marcar %s com %s, mas %s está invisível!" % [caster["name"], target["name"], spell["name"], target["name"]])
		finalize_action(caster, spell)
		return
	var is_hit: bool = rng.randf() < float(get_effective_hit_chance(caster, target, spell, manhattan(caster, target)))
	if not is_hit:
		_log("%s lança %s em %s e erra!" % [caster["name"], spell["name"], target["name"]])
	else:
		add_status_effect(target, {"type": "reincarnation"})
		_log("%s marca %s com %s!" % [caster["name"], target["name"], spell["name"]])
	finalize_action(caster, spell)

func _signi(n: int) -> int:
	if n > 0:
		return 1
	if n < 0:
		return -1
	return 0

# --- Destruição de terreno/estrutura (game.js:4738-4794, 4831-4870) ---------

## Terreno/estrutura alto (Castelo/Casa) — se desmoronar com alguém em cima,
## essa unidade cai e se machuca.
func apply_fall_damage(u) -> void:
	if u == null or u["hp"] <= 0:
		return
	u["hp"] -= GameConstants.FALL_DAMAGE
	_log("%s cai com o desmoronamento e sofre %d de dano de queda!" % [u["name"], GameConstants.FALL_DAMAGE])
	if u["hp"] <= 0:
		u["hp"] = 0
		_log("%s foi derrotado!" % u["name"])

## Árvore/casa/tenda: HP por tile (ao contrário do HP compartilhado do
## Castelo/Montanha). Ao zerar, vira "stump"/"house-rubble"/"tent-rubble" —
## como nenhum ruinType bloqueia passagem, o tile já sai liberado sozinho.
func damage_tree(x: int, y: int, damage_min: int, damage_max: int) -> void:
	var key := tile_key(x, y)
	var terrain = terrain_map.get(key)
	if terrain == null:
		return
	var config: Dictionary = BoardLayout.destructible_tile_types().get(terrain["type"], {})
	if config.is_empty():
		return
	var dmg: int = rng.randi_range(damage_min, damage_max)
	terrain["hp"] -= dmg
	if terrain["hp"] <= 0:
		var destroyed_type := String(terrain["type"])
		terrain_map[key] = {"type": config["ruinType"]}
		_log("Uma %s em (%d, %d) é destruída pelo ataque!" % [config["label"], x, y])
		_on_tower_terrain_destroyed(destroyed_type, x, y, terrain)
		apply_fall_damage(unit_at(x, y))
	else:
		_log("Uma %s em (%d, %d) leva %d de dano (%d/%d)." % [config["label"], x, y, dmg, maxi(terrain["hp"], 0), config["maxHp"]])

## Dano em área que já tem uma lista de tiles pronta (linha, cruz, cone
## etc.) — chamada pelas magias/armas de área depois de resolver os alvos
## de verdade (unidades), pra árvore/casa na mesma área também sofrerem.
func damage_trees_in_tiles(tiles: Array, damage_min: int, damage_max: int) -> void:
	var destructible := BoardLayout.destructible_tile_types()
	for t in tiles:
		var terrain = terrain_at(t["x"], t["y"])
		if terrain == null or not destructible.has(terrain["type"]):
			continue
		damage_tree(t["x"], t["y"], damage_min, damage_max)

## Versão pra explosões em raio (Bola de Fogo) — varre terrain_map direto em
## vez de montar uma lista de BOARD_SIZE² tiles só pra achar árvore/casa.
func damage_trees_in_radius(center: Dictionary, radius: int, damage_min: int, damage_max: int) -> void:
	var destructible := BoardLayout.destructible_tile_types()
	for key in terrain_map.keys():
		var terrain = terrain_map[key]
		if not destructible.has(terrain["type"]):
			continue
		var parts: PackedStringArray = (key as String).split(",")
		var tx := int(parts[0])
		var ty := int(parts[1])
		if manhattan({"x": tx, "y": ty}, center) > radius:
			continue
		damage_tree(tx, ty, damage_min, damage_max)

func burn_tower_bookshelves_in_radius(center: Dictionary, radius: int) -> void:
	for key in terrain_map.keys().duplicate():
		var terrain = terrain_map[key]
		if terrain.get("type", "") != "tower-bookshelf": continue
		var parts := String(key).split(",")
		var x := int(parts[0])
		var y := int(parts[1])
		if manhattan({"x":x,"y":y}, center) <= radius:
			terrain["hp"] = 0
			terrain_map[key] = {"type":"tower-ashes"}
			_on_tower_terrain_destroyed("tower-bookshelf", x, y, terrain)
			_log("As chamas consomem um módulo da estante!")

func _on_tower_terrain_destroyed(type: String, x: int, y: int, source: Dictionary = {}) -> void:
	if type == "tower-bookshelf" and source.get("dropMana", false):
		# Cada módulo atingido pelo fogo pode revelar a poção; apenas um drop
		# é produzido por módulo porque o terreno vira cinza imediatamente.
		tower_pickups.append({"x":x,"y":y,"kind":"hp","amount":10,"art":"potion"})
		_log("Uma Poção de Cura (+10 HP) aparece entre os livros queimados!")
	elif type == "tower-vase":
		var kind := "hp" if rng.randf() < 0.5 else "mp"
		tower_pickups.append({"x":x,"y":y,"kind":kind,"amount":10,"art":"potion"})
		_log("O barril se despedaça e deixa cair uma poção de %s (+10)!" % ("cura" if kind == "hp" else "mana"))

func perform_terrain_attack(attacker: Dictionary, tile: Dictionary, item: Dictionary) -> void:
	set_facing_towards(attacker, tile)
	var terrain = terrain_at(tile["x"], tile["y"])
	var fire_attack: bool = item.get("projectile", "") == "fireball" or item.get("sfx", "") == "fire" or attacker.get("burnNextAttackTurns", 0) > 0 or attacker.get("burnNextAttackAlwaysTurns", 0) > 0
	if terrain != null and terrain.get("type", "") == "tower-bookshelf" and fire_attack:
		damage_tree(tile["x"], tile["y"], 999, 999)
	else:
		damage_tree(tile["x"], tile["y"], item.get("damageMin", 1), item.get("damageMax", 1))
	attacker["burnNextAttackTurns"] = 0
	attacker["burnNextAttackAlwaysTurns"] = 0
	finalize_action(attacker, item)

## Reforço da Torre: a partir do turno global 15, tenta uma vez a cada dois
## turnos (15, 17, 19...) com 25% de chance. A criatura entra pela escada do
## topo; se a casa estiver ocupada, aquela tentativa é perdida. Os argumentos
## opcionais existem para testes determinísticos e não são usados pelo jogo.
# --- Cemitério: mortos-vivos selvagens (terceiro time) -----------------------
const GRAVEYARD_SPAWN_INTERVAL := 10
const GRAVEYARD_SPAWN_CHANCE := 0.25
## Distribuição do sorteio: 40% Zumbi, 30% Esqueleto, 15% Fantasma, 10% Vampiro,
## 5% Lich (limites acumulados).
const GRAVEYARD_UNDEAD_TABLE := [["zombie", 0.40], ["skeleton", 0.70], ["ghost", 0.85], ["vampire", 0.95], ["lich", 1.0]]
const GRAVEYARD_UNDEAD_NAMES := {"zombie": "Zumbi", "skeleton": "Esqueleto", "ghost": "Fantasma", "vampire": "Vampiro", "lich": "Lich"}
var graveyard_spawn_count := 0

static func graveyard_undead_kind_for_roll(roll: float) -> String:
	for entry in GRAVEYARD_UNDEAD_TABLE:
		if roll < float(entry[1]):
			return String(entry[0])
	return "lich"

# --- Cemiterio: mortos-vivos selvagens (terceiro time) e a mira do time neutro. (ver autoload/rules/graveyard_rules.gd) ---
func maybe_spawn_graveyard_undead(chance_roll: float = -1.0, kind_roll: float = -1.0) -> Variant: return GraveyardRules.maybe_spawn_graveyard_undead(self, chance_roll, kind_roll)
func maybe_spawn_tower_creature(chance_roll: float = -1.0, creature_roll: float = -1.0) -> Variant:
	if scenario_id != ScenarioManager.TOWER or global_turn_count < 15 or (global_turn_count - 15) % 5 != 0:
		return null
	var rolled_chance := rng.randf() if chance_roll < 0.0 else chance_roll
	if rolled_chance >= 0.25:
		return null
	var stairs: Variant = _tower_stairs_tile()
	if stairs == null:
		return null
	var tile: Variant = _first_free_tile_near(stairs["x"], stairs["y"])
	if tile == null:
		return null
	var roll := rng.randf() if creature_roll < 0.0 else creature_roll
	var kind := _tower_spawn_kind_for_roll(roll)
	tower_spawn_count += 1
	var templates := _tower_creature_templates()
	var data: Dictionary = templates[kind].duplicate(true)
	data["name"] = "%s da Torre %d" % [data["name"], tower_spawn_count]
	data["x"] = tile["x"]
	data["y"] = tile["y"]
	data["ct"] = REINFORCEMENT_STARTING_CT
	var spawned := spawn_unit(data["name"], data)
	_log("Um %s aparece pela escada da Torre!" % data["name"])
	return spawned

## Reforços (Torre e Horda) já entram com esse CT em vez de 0 — ficam a
## 20 de agir na primeira rolagem em vez de precisar acumular do zero.
const REINFORCEMENT_STARTING_CT := 80

func _tower_stairs_tile(scenario: String = ScenarioManager.TOWER) -> Variant:
	for decoration in ScenarioManager.definition(scenario).get("decorations", []):
		if decoration.get("kind", "") == "stairs":
			return {"x": decoration["x"], "y": decoration["y"]}
	return null

## A escada em si é a posição preferida (raio 0), mas se estiver ocupada —
## por exemplo, um cadáver deixado ali por um inimigo morto bem em cima
## dela — procura o primeiro espaço livre mais próximo (raios crescentes,
## sorteando entre os empates) em vez de simplesmente desistir do reforço.
func _first_free_tile_near(origin_x: int, origin_y: int) -> Variant:
	for radius in range(0, maxi(board_width, board_height) * 2):
		var cells: Array = []
		for y in board_height:
			for x in board_width:
				if absi(x - origin_x) + absi(y - origin_y) != radius: continue
				if not in_bounds(x, y): continue
				var terrain = terrain_at(x, y)
				var open_ground: bool = terrain == null or terrain.get("walkable", false)
				if occupant_at(x, y) == null and open_ground:
					cells.append({"x": x, "y": y})
		if not cells.is_empty():
			return cells[rng.randi_range(0, cells.size() - 1)]
	return null

func _tower_spawn_kind_for_roll(roll: float) -> String:
	if roll < 0.50: return "rat"
	if roll < 0.80: return "slime"
	if roll < 0.95: return "snake"
	return "gnoll"

## Reforço da Horda: distribuição ponderada 50% Rato / 30% Slime / 15%
## Cobra / 5% Gnoll, mesma regra da Torre. Chamada por
## maybe_spawn_lua_reinforcement_by_turn (a cada 7 turnos globais) ou direto
## pelos testes. O argumento opcional permite testar a distribuição sem
## depender do RNG.
func maybe_spawn_lua_creature(_chance_roll: float = -1.0, creature_roll: float = -1.0) -> Variant:
	if scenario_id != ScenarioManager.LUA_VALLEY:
		return null
	var mouth: Dictionary = ScenarioManager.definition(ScenarioManager.LUA_VALLEY)["cave_mouth"]
	var cells: Array = []
	for radius in range(0, 6):
		for y in board_height:
			for x in board_width:
				if abs(x-mouth["x"])+abs(y-mouth["y"]) != radius: continue
				var terrain = terrain_at(x,y)
				if occupant_at(x,y) == null and (terrain == null or terrain.get("type","") == "tower-grass"): cells.append({"x":x,"y":y})
		if not cells.is_empty(): break
	if cells.is_empty(): return null
	var roll := rng.randf() if creature_roll < 0.0 else creature_roll
	var kind := _tower_spawn_kind_for_roll(roll)
	return _spawn_lua_creature(kind, cells[rng.randi_range(0,cells.size()-1)], REINFORCEMENT_STARTING_CT)

## `starting_ct` fica 0 pro elenco inicial (10 criaturas sorteadas por
## _setup_lua_valley) e REINFORCEMENT_STARTING_CT pros reforços que entram
## ao longo da partida via maybe_spawn_lua_creature (mesma regra do Tower).
func _spawn_lua_creature(kind: String, tile: Dictionary, starting_ct: int = 0) -> Dictionary:
	tower_spawn_count += 1
	var data: Dictionary = _tower_creature_templates()[kind].duplicate(true)
	data["name"] = "%s da Horda %d" % [data["name"], tower_spawn_count]
	data["x"] = tile["x"]
	data["y"] = tile["y"]
	data["ct"] = starting_ct
	var spawned: Dictionary = spawn_unit(data["name"], data)
	_log("%s sai da abertura da montanha!" % data["name"])
	return spawned

static func _tower_creature_templates() -> Dictionary:
	# "swing" só escolhe a categoria de SFX/VFX de impacto (stab/crush/slash em
	# _play_attack_vfx, main.gd) — não altera dano/acerto/crítico. Mordida e
	# picada soam como perfuração (RatSprite/SnakeSprite: bote), pancada soa
	# como esmagamento (SlimeSprite), lança soa como perfuração.
	var bite := {"name":"Mordida","icon":"🦷","ctCost":50,"damageMin":1,"damageMax":3,"critMultiplier":1,"critChance":0.0,"hitChance":0.7,"minRange":1,"maxRange":1,"sfx":"melee","swing":"stab"}
	var slam := {"name":"Pancada","icon":"💥","ctCost":50,"damageMin":2,"damageMax":4,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":1,"maxRange":1,"sfx":"melee","swing":"crush"}
	var sting := {"name":"Picada","icon":"🐍","ctCost":50,"damageMin":1,"damageMax":3,"critMultiplier":1,"critChance":0.0,"hitChance":0.9,"minRange":1,"maxRange":1,"appliesPoison":{"damageMin":1,"damageMax":3,"turns":3,"ctDrainPerTurn":10},"sfx":"poison","swing":"stab"}
	var spear := {"name":"Lança","icon":"🔱","ctCost":50,"damageMin":3,"damageMax":6,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":1,"maxRange":1,"sfx":"melee","swing":"stab"}
	var throw_spear := {"name":"Arremessar Lança","icon":"🔱","ctCost":50,"damageMin":2,"damageMax":5,"critMultiplier":1,"critChance":0.0,"hitChance":0.7,"minRange":2,"maxRange":5,"projectile":"arrow","sfx":"ranged"}
	var rat_septic := {"name":"Mordida Séptica","icon":"🦷","kind":"creature-septic-bite","ctCost":35,"mpCost":0,"damageMin":2,"damageMax":4,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":1,"maxRange":1,"appliesBleed":{"damageMin":1,"damageMax":1,"turns":2,"chance":0.35},"targetMode":"enemy","sfx":"melee","swing":"stab","tooltipNote":"35% de chance de causar Sangramento: 1 de dano por 2 turnos."}
	var rat_charge := {"name":"Investida Rasteira","icon":"🐀","kind":"creature-charge","ctCost":45,"mpCost":2,"damageMin":3,"damageMax":5,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":1,"maxRange":3,"targetMode":"charge","sfx":"melee","swing":"stab","tooltipNote":"Avança até 3 quadrados em linha reta e reduz MOV em 1 por 1 turno."}
	var rat_call := {"name":"Guincho da Ninhada","icon":"📣","kind":"rat-pack-call","ctCost":55,"mpCost":5,"minRange":0,"maxRange":0,"targetMode":"self","radius":3,"ctBonus":15,"evasionBonus":0.1,"turns":2,"sfx":"nature","tooltipNote":"Ratos aliados no raio 3 recebem +15 CT e +10% de esquiva por 2 turnos."}
	var snake_bite := {"name":"Bote Venenoso","icon":"🐍","kind":"creature-poison-bite","ctCost":45,"mpCost":3,"damageMin":3,"damageMax":5,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":1,"maxRange":2,"targetMode":"enemy","poisonChance":0.7,"appliesPoison":{"damageMin":2,"damageMax":2,"turns":3},"sfx":"poison","swing":"stab","tooltipNote":"70% de chance de aplicar Veneno: 2 de dano por 3 turnos."}
	var snake_constrict := {"name":"Constrição","icon":"🐍","kind":"snake-constrict","ctCost":60,"mpCost":5,"damageMin":2,"damageMax":4,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":1,"maxRange":1,"targetMode":"enemy","appliesRoot":{"turns":1},"appliesCtDrain":20,"sfx":"poison","swing":"crush","tooltipNote":"Imobiliza por 1 turno e remove 20 CT."}
	var snake_skin := {"name":"Troca de Pele","icon":"✨","kind":"snake-skin","ctCost":50,"mpCost":6,"targetMode":"self","healMin":5,"healMax":5,"evasionBonus":0.15,"turns":1,"sfx":"heal","tooltipNote":"Recupera 5 HP, remove um efeito negativo e concede +15% de esquiva até a próxima ação."}
	var gnoll_axe := {"name":"Machado Serrilhado","icon":"🪓","kind":"creature-serrated-axe","ctCost":55,"mpCost":0,"damageMin":6,"damageMax":9,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":1,"maxRange":1,"targetMode":"enemy","appliesBleed":{"damageMin":2,"damageMax":2,"turns":2},"sfx":"melee","swing":"slash","tooltipNote":"Aplica Sangramento: 2 de dano por 2 turnos."}
	var gnoll_charge := {"name":"Investida de Caça","icon":"🐺","kind":"gnoll-hunt-charge","ctCost":65,"mpCost":4,"damageMin":7,"damageMax":10,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":1,"maxRange":3,"targetMode":"charge","knockback":{"distance":1,"blockedExtraDamage":2},"sfx":"melee","swing":"slash","tooltipNote":"Avança, causa dano e empurra 1 quadrado; se bloqueado, causa +2 dano."}
	var gnoll_howl := {"name":"Uivo de Guerra","icon":"🐺","kind":"gnoll-war-howl","ctCost":50,"mpCost":6,"targetMode":"self","radius":3,"damageBonus":2,"accuracyBonus":0.1,"turns":2,"sfx":"nature","tooltipNote":"Aliados no raio 3 recebem +2 dano e +10% acerto por 2 turnos."}
	var slime_slam := {"name":"Pancada Viscosa","icon":"💥","kind":"slime-slam","ctCost":45,"mpCost":0,"damageMin":4,"damageMax":6,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":1,"maxRange":1,"targetMode":"enemy","appliesSpeedReduction":{"amount":1,"turns":2},"sfx":"melee","swing":"crush","tooltipNote":"Reduz MOV em 1 por 2 turnos."}
	var slime_spit := {"name":"Cuspe Ácido","icon":"🧪","kind":"slime-acid-spit","ctCost":55,"mpCost":5,"damageMin":3,"damageMax":5,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":1,"maxRange":3,"targetMode":"enemy","appliesDefenseReduction":{"amount":2,"turns":2},"projectile":"poison","sfx":"poison","tooltipNote":"Reduz a defesa em 2 por 2 turnos."}
	var slime_jump := {"name":"Salto Gelatinoso","icon":"🟢","kind":"slime-jump","ctCost":65,"mpCost":7,"damageMin":5,"damageMax":8,"critMultiplier":1,"critChance":0.0,"hitChance":0.8,"minRange":1,"maxRange":3,"targetMode":"slime-jump","areaRadius":1,"knockback":{"distance":1},"sfx":"melee","tooltipNote":"Salta até 3 quadrados; o impacto em cruz empurra os atingidos."}
	return {
		"rat":{"name":"Rato","team":"enemy","hp":5,"maxHp":5,"moveRange":3,"speed":9,"ct":0,"mp":5,"maxMp":5,"hasMoved":false,"hasActed":false,"statusEffects":[],"facing":{"dx":0,"dy":1},"spriteKey":"spd_rat","weapons":[bite],"spells":[rat_septic,rat_charge,rat_call]},
		"slime":{"name":"Slime","team":"enemy","hp":10,"maxHp":10,"moveRange":3,"speed":10,"ct":0,"mp":10,"maxMp":10,"hasMoved":false,"hasActed":false,"statusEffects":[],"facing":{"dx":0,"dy":1},"spriteKey":"spd_slime","weapons":[slam],"spells":[slime_slam,slime_spit,slime_jump]},
		"snake":{"name":"Cobra","team":"enemy","hp":10,"maxHp":10,"moveRange":3,"speed":10,"ct":0,"mp":12,"maxMp":12,"hasMoved":false,"hasActed":false,"statusEffects":[],"facing":{"dx":0,"dy":1},"innateEvasion":0.1,"spriteKey":"spd_snake","weapons":[sting],"spells":[snake_bite,snake_constrict,snake_skin]},
		"gnoll":{"name":"Gnoll","team":"enemy","hp":15,"maxHp":15,"moveRange":3,"speed":10,"ct":0,"mp":10,"maxMp":10,"hasMoved":false,"hasActed":false,"statusEffects":[],"facing":{"dx":0,"dy":1},"spriteKey":"spd_gnoll","weapons":[spear,throw_spear],"spells":[gnoll_axe,gnoll_charge,gnoll_howl]},
		# Pedido do usuário: Morcego Vampiro invocado por Invocar Morcegos —
		# "variação da Cobra" (mesmos stats/ataque/IA), só com Voo permanente
		# (mesmo campo booleano que a Fada usa) e lifesteal 50% na Picada
		# reaproveitada (mesmo campo genérico `lifesteal` de resolve_single_hit,
		# ver Toque Vampírico/Mordida do Vampiro). NÃO é a transformação do
		# Vampiro (cast_vampire_bat_form) — é uma unidade nova e independente.
		"vampire_bat":{"name":"Morcego Vampiro","team":"enemy","hp":10,"maxHp":10,"moveRange":3,"speed":10,"ct":0,"mp":0,"maxMp":0,"hasMoved":false,"hasActed":false,"statusEffects":[],"facing":{"dx":0,"dy":1},"innateEvasion":0.1,"spriteKey":"vampire_bat","flying":true,"weapons":[DataUtil.merge(sting, {"lifesteal": 0.5})],"spells":[]},
	}

## Aplica dano de ataque a UMA estrutura — sem chance de acerto própria
## (quem decide atacar a estrutura sempre acerta).
func damage_structure(structure: Dictionary, damage_min: int, damage_max: int) -> void:
	if structure["destroyed"]:
		return
	var dmg: int = rng.randi_range(damage_min, damage_max)
	structure["hp"] -= dmg
	var label: String = "O Castelo" if structure["type"] == "castle" else "A Montanha"
	if structure["hp"] <= 0:
		structure["hp"] = 0
		structure["destroyed"] = true
		_log("%s é destruída pelo ataque!" % label)
		apply_fall_damage(structure_occupant(structure))
	else:
		_log("%s leva %d de dano (%d/%d)." % [label, dmg, structure["hp"], structure["maxHp"]])

## Ataque de ALVO ÚNICO mirado direto num tile do Castelo/Montanha, mesmo
## sem ninguém em cima dele — pedido do usuário: antes só dano em área
## (damage_structures_in_tiles/_in_radius) alcançava a estrutura vazia.
## Sem rolagem de acerto (estrutura não esquiva) nem crítico, dano cheio
## (não é ataque em área, então não leva o dobro de damage_structures_in_tiles).
func perform_structure_attack(attacker: Dictionary, structure: Dictionary, tile: Dictionary, item: Dictionary) -> void:
	set_facing_towards(attacker, tile)
	damage_structure(structure, item.get("damageMin", 1), item.get("damageMax", 1))
	finalize_action(attacker, item)

## Ataque em ÁREA que pega Castelo/Montanha causa o DOBRO de dano nela —
## só aqui e em damage_structures_in_radius (magias/armas de área); ataque
## de alvo único mirado na estrutura continua com o dano normal.
func damage_structures_in_tiles(tiles: Array, damage_min: int, damage_max: int) -> void:
	var hit := {}
	for t in tiles:
		var s = structure_at(t["x"], t["y"])
		if s != null and not hit.has(s["type"]):
			hit[s["type"]] = true
			damage_structure(s, damage_min * GameConstants.AREA_STRUCTURE_DAMAGE_MULTIPLIER, damage_max * GameConstants.AREA_STRUCTURE_DAMAGE_MULTIPLIER)

func damage_structures_in_radius(center: Dictionary, radius: int, damage_min: int, damage_max: int) -> void:
	for s in structures:
		if s["destroyed"]:
			continue
		var in_range := false
		for t in (s["tiles"] as Array):
			if manhattan(t, center) <= radius:
				in_range = true
				break
		if in_range:
			damage_structure(s, damage_min * GameConstants.AREA_STRUCTURE_DAMAGE_MULTIPLIER, damage_max * GameConstants.AREA_STRUCTURE_DAMAGE_MULTIPLIER)

# --- Geometria de área/linha/cone (game.js:4182-4406, 8489-8521) -----------

func compute_cardinal_rect_tiles(caster: Dictionary, target_tile: Dictionary, length: int, width: int) -> Array:
	var dir := _cardinal_direction(caster, target_tile)
	return _cardinal_rect_in_dir(caster, dir.x, dir.y, length, width)

## Faixa saindo da borda do corpo: cada casa da borda (2 no 2x2) abre a própria
## faixa de `width`, então o corpo grande cobre uma faixa mais larga.
func _cardinal_rect_in_dir(caster: Dictionary, dx: int, dy: int, length: int, width: int) -> Array:
	var perp_x: int = -dy
	var perp_y: int = dx
	var half: int = int(floor(float(width) / 2.0))
	var offsets: Array = []
	for i in range(width):
		offsets.append(i - half)
	var tiles: Array = []
	var seen := {}
	var lanes := body_lane_origins(caster, dx, dy)
	for d in range(1, length + 1):
		for lane in lanes:
			for offset in offsets:
				var x: int = lane["x"] + dx * d + perp_x * offset
				var y: int = lane["y"] + dy * d + perp_y * offset
				if in_bounds(x, y) and not seen.has(tile_key(x, y)):
					seen[tile_key(x, y)] = true
					tiles.append({"x": x, "y": y})
	return tiles

## Mesma faixa de compute_cardinal_rect_tiles, só que nas 4 direções cardeais
## AO MESMO TEMPO (cruz) — só pra mostrar o "alcance" antes do clique; o
## efeito de verdade sempre escolhe UMA direção só (ver compute_aoe_area_tiles).
func compute_cardinal_cross_tiles(caster: Dictionary, length: int, width: int) -> Array:
	var dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]]
	var seen := {}
	var result := []
	for d in dirs:
		var rect := _cardinal_rect_in_dir(caster, d[0], d[1], length, width)
		for t in rect:
			var key := tile_key(t["x"], t["y"])
			if seen.has(key):
				continue
			seen[key] = true
			result.append({"x": t["x"], "y": t["y"]})
	return result

## Tiles do cone numa direção cardeal: largura 1, 3, 5, 7, 9 nas
## profundidades 1 a 5 (maxDepth) — usado pelo Envenenamento/Ventania.
func compute_cone_tiles_for_dir(u: Dictionary, dx: int, dy: int, max_depth: int) -> Array:
	var result: Array = []
	var seen := {}
	var lanes := body_lane_origins(u, dx, dy)
	for d in range(1, max_depth + 1):
		var half: int = d - 1
		for lane in lanes:
			for o in range(-half, half + 1):
				var px: int = (lane["x"] + dx * d) if dx != 0 else (lane["x"] + o)
				var py: int = (lane["y"] + dy * d) if dy != 0 else (lane["y"] + o)
				if in_bounds(px, py) and not seen.has(tile_key(px, py)):
					seen[tile_key(px, py)] = true
					result.append({"x": px, "y": py})
	return result

## União dos 4 cones — usado pra destacar todas as opções de mira de uma vez.
func compute_all_cone_tiles(u: Dictionary, max_depth: int) -> Array:
	var dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]]
	var seen := {}
	var result: Array = []
	for d in dirs:
		for t in compute_cone_tiles_for_dir(u, d[0], d[1], max_depth):
			var key := tile_key(t["x"], t["y"])
			if not seen.has(key):
				seen[key] = true
				result.append(t)
	return result

## Calcula quais quadrados serão afetados se target_tile for confirmado, pro
## targetMode do item — usado pra pré-visualização das magias de área.
## `null` (não `[]`) quando o modo não tem uma área diferente do próprio
## tile — chamador decide o fallback (ver cast_heal_aoe etc: `?? [target_tile]`).
func compute_aoe_area_tiles(caster: Dictionary, item: Dictionary, target_tile: Dictionary) -> Variant:
	var mode: String = item.get("targetMode", "enemy")
	if String(item.get("kind", "")).begins_with("bard-song"):
		return _eligible_song_targets(caster, item.get("songKind", "") in ["heal", "inspiration"]).map(func(u): return {"x":u["x"], "y":u["y"]})
	if mode == "arrow-rain":
		if item.get("rainBaseMode", "") == "pierce-line": return arrow_rain_tiles(caster, item, target_tile)
		var tiles: Array = []
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var x: int = target_tile["x"] + dx
				var y: int = target_tile["y"] + dy
				if in_bounds(x, y): tiles.append({"x":x, "y":y})
		return tiles
	if mode in ["self-aoe", "self-attack"]:
		var tiles: Array = []
		for y in range(board_height):
			for x in range(board_width):
				var distance := manhattan(caster, {"x":x, "y":y})
				if mode == "self-attack":
					var box := _body_box(caster)
					var out_x: int = maxi(maxi(box["left"] - x, x - box["right"]), 0)
					var out_y: int = maxi(maxi(box["top"] - y, y - box["bottom"]), 0)
					if maxi(out_x, out_y) == 1: tiles.append({"x":x, "y":y})
				elif distance <= item.get("areaRadius", 2): tiles.append({"x":x, "y":y})
		return tiles
	if mode == "point-aoe":
		var impact: Dictionary = target_tile if item.get("ignoresUnitObstruction", false) else resolve_obstructed_target(caster, target_tile)
		var tiles := []
		for y in range(board_height):
			for x in range(board_width):
				if manhattan({"x": x, "y": y}, impact) <= item["areaRadius"]:
					tiles.append({"x": x, "y": y})
		return tiles
	if mode == "line-aoe":
		return _line_tiles_from_body(caster, target_tile)
	if mode == "creeping-line" or mode == "flame-creeping-line" or mode == "cardinal-blast":
		return compute_cardinal_rect_tiles(caster, target_tile, item["bandLength"], item["bandWidth"])
	if mode == "cone-poison" or mode == "cone-fire" or mode == "cone-windstorm" or mode == "cone-ice":
		var dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]]
		for d in dirs:
			var tiles := compute_cone_tiles_for_dir(caster, d[0], d[1], item["maxRange"])
			for t in tiles:
				if t["x"] == target_tile["x"] and t["y"] == target_tile["y"]:
					return tiles
		return null
	if mode == "freeze-aoe" or mode == "cure-aoe" or mode == "heal-aoe" or mode == "regen-aoe" or mode == "mana-aoe" or mode == "trap":
		var tiles := []
		for y in range(board_height):
			for x in range(board_width):
				if manhattan({"x": x, "y": y}, target_tile) <= item["areaRadius"]:
					tiles.append({"x": x, "y": y})
		return tiles
	if mode == "pierce-line":
		var dir := _cardinal_direction(caster, target_tile)
		return compute_pierce_line_tiles(caster, dir.x, dir.y, item["maxRange"])
	if mode == "dust-square" or mode == "heal-cross":
		var radius: int = int(item.get("areaRadius", 1))
		var square_tiles: Array = []
		for ty in range(int(caster["y"]) - radius, int(caster["y"]) + radius + 1):
			for tx in range(int(caster["x"]) - radius, int(caster["x"]) + radius + 1):
				if not in_bounds(tx, ty): continue
				# heal-cross = só os 4 cardeais + o centro (losango de raio 1, sem diagonais).
				if mode == "heal-cross" and absi(tx - int(caster["x"])) + absi(ty - int(caster["y"])) > radius: continue
				square_tiles.append({"x": tx, "y": ty})
		return square_tiles
	if mode == "crescent-arc":
		var arc_dir := _cardinal_direction(caster, target_tile)
		return compute_crescent_tiles_for_dir(caster, arc_dir.x, arc_dir.y)
	return null

## Linha reta/diagonal (Relâmpago/Tronco) até `target_tile`, saindo da borda do
## corpo: corpo grande cardeal cobre as 2 casas do lado, não só 1. Sem filtro
## de limites, como sempre foi.
func _line_tiles_from_body(caster: Dictionary, target_tile: Dictionary) -> Array:
	var dir := body_direction(caster, target_tile)
	var box := _body_box(caster)
	var out_x: int = absi(int(target_tile["x"]) - (box["right"] if dir.x > 0 else box["left"])) if dir.x != 0 else 0
	var out_y: int = absi(int(target_tile["y"]) - (box["bottom"] if dir.y > 0 else box["top"])) if dir.y != 0 else 0
	var tiles: Array = []
	var lanes := body_lane_origins(caster, dir.x, dir.y)
	for d in range(1, maxi(out_x, out_y) + 1):
		for lane in lanes:
			tiles.append({"x": lane["x"] + dir.x * d, "y": lane["y"] + dir.y * d})
	return tiles

## Terreno elevado (Castelo ou Casa) dá +1 de alcance a ataques à distância
## de quem está em cima — voar conta como "sempre elevado".
func is_unit_elevated(u: Dictionary) -> bool:
	if u.get("flying", false):
		return true
	var terrain = terrain_at(u["x"], u["y"])
	if terrain != null and terrain["type"] == "house":
		return true
	var structure = structure_at(u["x"], u["y"])
	if structure != null and not structure["destroyed"]:
		return true
	return false

## Tiles dentro do alcance de `item` pra `u` — considera Tiro Longo (dobra
## maxRange) e elevação (+1), nessa ordem, e linha de visão (a menos que o
## item ignore, como o Arco).
## Aplica Tiro Longo (dobra maxRange) e elevação (+1), nessa ordem — mesmo
## item efetivo usado tanto pra pintar o alcance (compute_range_tiles)
## quanto pra decidir quem é clicável (_select_attack_item em main.gd).
## Duplicar o item só quando algum bônus realmente se aplica evita alocar
## um Dictionary novo à toa no caso comum (sem Tiro Longo, sem elevação).
func effective_weapon_item(u: Dictionary, item: Dictionary) -> Dictionary:
	var effective_item := item
	var duplicated := false
	if u.get("doubleRangeNextAttack", false):
		effective_item = item.duplicate()
		effective_item["maxRange"] = item["maxRange"] * 2
		duplicated = true
	if effective_item["maxRange"] > 1 and is_unit_elevated(u):
		if not duplicated:
			effective_item = item.duplicate()
			duplicated = true
		effective_item["maxRange"] = effective_item["maxRange"] + 1
	return effective_item

func compute_range_tiles(u: Dictionary, item: Dictionary) -> Array:
	var effective_item := effective_weapon_item(u, item)
	var result: Array = []
	for y in range(board_height):
		for x in range(board_width):
			if is_in_weapon_range(effective_item, manhattan(u, {"x": x, "y": y})) and (item.get("ignoresTerrainLineOfSight", false) or has_line_of_sight(u["x"], u["y"], x, y)):
				result.append({"x": x, "y": y})
	return result

## Tiles válidos pra item "em linha" (Relâmpago/Tronco: 8 direções retas/
## diagonais; Perfurante/Atropelar/qualquer `cardinalOnly` como Arremessar
## Espada/Raio de Gelo: só as 4 cardeais), até `item.maxRange`, parando na
## borda do tabuleiro — NÃO é um raio de alcance em diamante como
## compute_range_tiles, é só as retas/diagonais que partem do conjurador
## (porte literal de computeLineTargetTiles, game.js:4418).
func compute_line_target_tiles(u: Dictionary, item: Dictionary, cardinal_only: bool = false) -> Array:
	var dirs: Array = [[1, 0], [-1, 0], [0, 1], [0, -1]]
	if not cardinal_only:
		dirs.append_array([[1, 1], [1, -1], [-1, 1], [-1, -1]])
	var result: Array = []
	for d in dirs:
		for lane in body_lane_origins(u, d[0], d[1]):
			var dist := 1
			while dist <= item["maxRange"]:
				var x: int = lane["x"] + d[0] * dist
				var y: int = lane["y"] + d[1] * dist
				if not in_bounds(x, y):
					break
				result.append({"x": x, "y": y})
				dist += 1
	return result

## Empurra `u` em linha reta (dx,dy) até `distance` quadrados; pára antes se
## sair do tabuleiro ou esbarrar em alguém. Devolve se de fato se moveu.
## Pedido do usuário: personagens 2x2 (Troll/Goo/Dragão/Salamandra/Troncus)
## não são afetados por empurrão — nunca saem do lugar e também não levam o
## dano extra de "bloqueado" (quem chama checa is_large_unit). O dano normal
## do golpe continua.
func push_unit(u: Dictionary, dx: int, dy: int, distance: int) -> bool:
	if is_large_unit(u):
		_log("%s é grande demais para ser empurrado(a)." % u["name"])
		return false
	var final_x: int = u["x"]
	var final_y: int = u["y"]
	for d in range(1, distance + 1):
		var nx: int = u["x"] + dx * d
		var ny: int = u["y"] + dy * d
		if not _push_destination_free(u, nx, ny):
			break
		final_x = nx
		final_y = ny
	var moved: bool = final_x != u["x"] or final_y != u["y"]
	if moved:
		u["x"] = final_x
		u["y"] = final_y
		u["displacedThisTurn"] = true
		_log("%s é empurrado(a) para (%d, %d)!" % [u["name"], final_x, final_y])
		sync_mounts()
	return moved

## Chicote de Cipó (Troncus): -MOV que dura até o FIM do próximo turno do
## alvo (tick em apply_status_effects_at_turn_end, mesma convenção do
## Enraizado). Não acumula: reaplicar só renova turnsLeft. Nunca deixa MOV
## negativo e devolve exatamente o que tirou quando expira.
func _apply_vine_slow(defender: Dictionary, slow: Dictionary) -> void:
	for existing in defender.get("statusEffects", []):
		if existing.get("type", "") == "vineSlow":
			existing["turnsLeft"] = int(slow["turns"])
			_log("%s continua enredado(a) pelos cipós (%d turno)." % [defender["name"], int(slow["turns"])])
			return
	var amount: int = mini(int(slow["moveReduction"]), maxi(int(defender.get("moveRange", 0)), 0))
	defender["moveRange"] = int(defender.get("moveRange", 0)) - amount
	(defender["statusEffects"] as Array).append({"type": "vineSlow", "turnsLeft": int(slow["turns"]), "moveReduction": amount})
	_log("%s é enredado(a) pelos cipós! -%d de deslocamento por %d turno." % [defender["name"], amount, int(slow["turns"])])

## Destino de empurrão: todas as casas do corpo dentro do mapa e sem outra
## unidade/cadáver — nunca empurra pra fora nem por cima de alguém.
func _push_destination_free(u: Dictionary, x: int, y: int) -> bool:
	for tile in footprint_tiles(u, x, y):
		if not in_bounds(int(tile["x"]), int(tile["y"])):
			return false
		var occupant = occupant_at(int(tile["x"]), int(tile["y"]))
		if occupant != null and occupant["name"] != u["name"]:
			return false
	return true

## Empurrão radial de explosão em área: cada atingido vai pra LONGE do ponto
## de impacto. Quem está bem em cima do impacto não tem direção — tratado
## como bloqueado, igual quem tem o caminho fisicamente barrado.
func apply_point_blast_knockback(defender: Dictionary, impact: Dictionary, knockback: Dictionary) -> void:
	var dx: int = _signi(defender["x"] - impact["x"])
	var dy: int = _signi(defender["y"] - impact["y"])
	var moved: bool = (dx != 0 or dy != 0) and push_unit(defender, dx, dy, knockback["distance"])
	if not moved and knockback.get("blockedExtraDamage") and not is_large_unit(defender):
		defender["hp"] = maxi(defender["hp"] - knockback["blockedExtraDamage"], 0)
		_log("%s está bloqueado(a) e não pode ser empurrado(a) — leva %d de dano extra!" % [defender["name"], knockback["blockedExtraDamage"]])

# --- Fase 3: habilidades de área/linha/cone (game.js:7876-7948, 8317-8578, 9097-9316) ---

func cast_heal_aoe(caster: Dictionary, spell: Dictionary, target_tile: Dictionary) -> void:
	record_area_action(caster, spell, target_tile)
	set_facing_towards(caster, target_tile)
	var tiles = compute_aoe_area_tiles(caster, spell, target_tile)
	if tiles == null:
		tiles = [target_tile]
	var targets: Array = units_in_tiles(tiles)
	if targets.is_empty():
		_log("Não havia ninguém na área do %s." % spell["name"])
	for u in targets:
		resolve_heal(caster, u, spell)
	finalize_action(caster, spell)

## Infligir Ferimentos (Lich): mesma área/alcance/lógica de seleção de
## cast_heal_aoe (compute_aoe_area_tiles + units_in_tiles, mesmos campos de
## alcance/raio da própria Cura, ver GameState.dungeon_monster_data("lich")
## em como a magia é montada), só chamando resolve_harm em vez de
## resolve_heal em cada alvo da área.
func cast_inflict_wounds(caster: Dictionary, spell: Dictionary, target_tile: Dictionary) -> void:
	record_area_action(caster, spell, target_tile)
	set_facing_towards(caster, target_tile)
	var tiles = compute_aoe_area_tiles(caster, spell, target_tile)
	if tiles == null:
		tiles = [target_tile]
	var targets: Array = units_in_tiles(tiles)
	if targets.is_empty():
		_log("Não havia ninguém na área de %s." % spell["name"])
	for u in targets:
		resolve_harm(caster, u, spell)
	finalize_action(caster, spell)

func cast_regen_aoe(caster: Dictionary, spell: Dictionary, target_tile: Dictionary) -> void:
	record_area_action(caster, spell, target_tile)
	set_facing_towards(caster, target_tile)
	var tiles = compute_aoe_area_tiles(caster, spell, target_tile)
	if tiles == null:
		tiles = [target_tile]
	var targets: Array = units_in_tiles(tiles)
	if targets.is_empty():
		_log("Não havia ninguém na área do %s." % spell["name"])
	for u in targets:
		resolve_regen(caster, u, spell)
	finalize_action(caster, spell)

## Poção de Mana (Químico): pedido do usuário — mesma área de efeito da
## Poção de Cura/Regeneração em Área (heal-aoe/regen-aoe, areaRadius/alcance
## idênticos), restaurando MP em vez de HP em todos os atingidos.
func cast_mana_aoe(caster: Dictionary, spell: Dictionary, target_tile: Dictionary) -> void:
	record_area_action(caster, spell, target_tile)
	set_facing_towards(caster, target_tile)
	var tiles = compute_aoe_area_tiles(caster, spell, target_tile)
	if tiles == null:
		tiles = [target_tile]
	var targets: Array = units_in_tiles(tiles)
	if targets.is_empty():
		_log("Não havia ninguém na área do %s." % spell["name"])
	for u in targets:
		resolve_mana_restore(caster, u, spell)
	finalize_action(caster, spell)

## Antídoto (Químico): em área, remove veneno e paralisia instantaneamente
## de qualquer um atingido (aliado ou inimigo) — sem rolagem de acerto,
## sem dano. `tiles` já vem calculado pelo chamador (não recalcula aqui).
func cast_antidote(caster: Dictionary, spell: Dictionary, tiles: Array) -> void:
	record_area_action(caster, spell, caster, tiles)
	var targets: Array = units_in_tiles(tiles)
	var cured_any := false
	for u in targets:
		var before: Array = u["statusEffects"]
		var after: Array = before.filter(func(e): return e["type"] != "poison" and e["type"] != "paralyzed")
		u["statusEffects"] = after
		if after.size() < before.size():
			cured_any = true
			_log("%s foi curado(a) de veneno/paralisia por %s." % [u["name"], spell["name"]])
	if not cured_any:
		_log("%s não encontrou nada para curar na área." % spell["name"])
	finalize_action(caster, spell)

## Armadilha (Ladino): checa de novo (a validação anterior pode estar
## desatualizada se o alvo se moveu) que nenhum tile da área está ocupado
## antes de instalar. Se bloqueada, não gasta CT/MP nem consome a ação.
func cast_trap(caster: Dictionary, item: Dictionary, target_tile: Dictionary) -> void:
	record_area_action(caster, item, target_tile)
	var area_tiles = compute_aoe_area_tiles(caster, item, target_tile)
	if area_tiles == null:
		area_tiles = []
	var blocked := false
	for t in area_tiles:
		if unit_at(t["x"], t["y"]) != null:
			blocked = true
			break
	if blocked:
		_log("%s tenta armar %s, mas há alguém na área — a armadilha não foi instalada." % [caster["name"], item["name"]])
		return
	# "visible" pedido pelo usuário: a armadilha do Ladino fica visível pra
	# todo mundo assim que instalada (mesmo padrão das armadilhas do
	# ambiente/Torre, ver _setup_tower), não escondida até ser pisada.
	# "ownerName"/"instant" pedido pelo usuário: só o próprio Ladino que a
	# instalou é imune (aliados dele podem sofrer o dano normalmente, ver
	# apply_trap_crossings) e ela some assim que alguém aciona e sofre o
	# dano, em vez de ficar revelada por mais 3 turnos.
	traps.append({"tiles": area_tiles, "ownerTeam": caster["team"], "ownerName": caster["name"], "instant": true, "triggered": false, "turnsLeft": null, "visible": true})
	_log("%s instala uma %s na área!" % [caster["name"], item["name"]])
	finalize_action(caster, item)

## Bola de Fogo / Explosão Sonora / Bomba (mesmo resolvedor, "kind" visual
## muda quem chama): por padrão, se algo bloquear o caminho, a explosão
## detona antes do alvo (ver resolve_obstructed_target) — igual um projétil
## reto. A Bomba tem "ignoresUnitObstruction": true (ver Spells.build()) e
## pula essa checagem: é lançada em arco, então pousa exatamente no quadrado
## clicado mesmo com alguém no meio do caminho. Acerta qualquer um dentro do
## raio, aliado ou inimigo.
func cast_fireball(caster: Dictionary, spell: Dictionary, target_tile: Dictionary) -> void:
	record_area_action(caster, spell, target_tile)
	set_facing_towards(caster, target_tile)
	var impact: Dictionary = target_tile if spell.get("ignoresUnitObstruction", false) else resolve_obstructed_target(caster, target_tile)
	var hits: Array = []
	for u in alive_units():
		if manhattan(u, impact) <= spell["areaRadius"]:
			hits.append(u)
	if hits.is_empty():
		_log("Não havia ninguém na área da explosão.")
	for enemy in hits:
		var was_hit := resolve_single_hit(caster, enemy, spell)
		if was_hit and enemy["hp"] > 0 and spell.has("knockback"):
			apply_point_blast_knockback(enemy, impact, spell["knockback"])
	damage_trees_in_radius(impact, spell["areaRadius"], spell["damageMin"], spell["damageMax"])
	burn_tower_bookshelves_in_radius(impact, spell["areaRadius"])
	damage_structures_in_radius(impact, spell["areaRadius"], spell["damageMin"], spell["damageMax"])
	finalize_action(caster, spell)

## Decaimento (Lich): MESMA forma de área de cast_fireball — losango
## (manhattan <= areaRadius) sobre todo mundo vivo, aliado ou inimigo, sem
## filtro de time — só que o centro é sempre a própria posição do caster
## em vez de um target_tile escolhido (mesma ideia de targetMode "self-aoe"
## já usado por cast_black_slime_poison, ver _resolve_spell). Cada unidade
## na área é tratada individualmente: morto-vivo (campo genérico `undead`,
## nunca por nome) regenera HP; criatura viva sofre a rolagem normal de
## resolve_single_hit (que já testa acerto/aplica appliesBleed/appliesPoison
## sozinha — nenhuma lógica de dano nova aqui).
func cast_decay_pulse(caster: Dictionary, spell: Dictionary) -> void:
	record_area_action(caster, spell, caster)
	var impact := {"x": caster["x"], "y": caster["y"]}
	var hits: Array = []
	for u in alive_units():
		if manhattan(u, impact) <= spell["areaRadius"]:
			hits.append(u)
	if hits.is_empty():
		_log("Não havia ninguém na área de %s." % spell["name"])
	for target in hits:
		if target.get("undead", false):
			var healing: int = rng.randi_range(spell["healMin"], spell["healMax"])
			var actual_heal := mini(healing, int(target["maxHp"]) - int(target["hp"]))
			target["hp"] = mini(int(target["maxHp"]), int(target["hp"]) + healing)
			_log("%s é regenerado(a) por %s, recuperando %d HP!" % [target["name"], spell["name"], actual_heal])
		else:
			resolve_single_hit(caster, target, spell)
	finalize_action(caster, spell)

## Relâmpago (magia) e Tronco (arma do Troll, mesmo targetMode "line-aoe")
## reaproveitam este mesmo resolvedor: percorre a linha reta/diagonal
## clicada, acertando todo mundo no caminho, aliado ou inimigo.
func cast_lightning(caster: Dictionary, spell: Dictionary, target_tile: Dictionary) -> void:
	record_area_action(caster, spell, target_tile)
	set_facing_towards(caster, target_tile)
	var line_tiles: Array = _line_tiles_from_body(caster, target_tile)
	var length: int = line_tiles.size()
	_log("%s lança %s, atingindo %d quadrado(s) em linha." % [caster["name"], spell["name"], length])
	var hits: Array = units_in_tiles(line_tiles)
	if hits.is_empty():
		_log("Não havia ninguém na linha do relâmpago.")
	for enemy in hits:
		resolve_single_hit(caster, enemy, spell)
	damage_trees_in_tiles(line_tiles, spell["damageMin"], spell["damageMax"])
	damage_structures_in_tiles(line_tiles, spell["damageMin"], spell["damageMax"])
	finalize_action(caster, spell)

## Congelamento (Fada): losango ao redor do ponto clicado (sem redirecionar
## por obstrução). Quem for atingido fica paralisado por 1 turno (renova em
## vez de empilhar se já estava paralisado).
func cast_freeze_aoe(caster: Dictionary, spell: Dictionary, target_tile: Dictionary) -> void:
	record_area_action(caster, spell, target_tile)
	set_facing_towards(caster, target_tile)
	var tiles = compute_aoe_area_tiles(caster, spell, target_tile)
	if tiles == null:
		tiles = [target_tile]
	var targets: Array = units_in_tiles(tiles)
	if targets.is_empty():
		_log("Não havia ninguém na área do %s." % spell["name"])
	for u in targets:
		if blocked_by_invisibility(spell, u):
			_log("%s tenta atingir %s com %s, mas %s está invisível!" % [caster["name"], u["name"], spell["name"], u["name"]])
			continue
		var is_hit: bool = rng.randf() < float(get_effective_hit_chance(caster, u, spell, manhattan(caster, u)))
		if not is_hit:
			_log("%s tenta congelar %s com %s, mas erra!" % [caster["name"], u["name"], spell["name"]])
			continue
		var existing = null
		for e in u.get("statusEffects", []):
			if e["type"] == "paralyzed":
				existing = e
				break
		if existing != null:
			existing["turnsLeft"] = 1
			existing["damageMin"] = spell["damageMin"]
			existing["damageMax"] = spell["damageMax"]
		else:
			add_status_effect(u, {"type": "paralyzed", "turnsLeft": 1, "damageMin": spell["damageMin"], "damageMax": spell["damageMax"]})
		_log("%s congela %s com %s!" % [caster["name"], u["name"], spell["name"]])
	damage_trees_in_tiles(tiles, spell["damageMin"], spell["damageMax"])
	damage_structures_in_tiles(tiles, spell["damageMin"], spell["damageMax"])
	finalize_action(caster, spell)

## Ventania (Fada): mesma área do Envenenamento (cone reto). Reaproveita
## resolve_single_hit pra acerto/dano/crítico/dreno de CT e só cuida do
## empurrão por cima disso — direção sai do primeiro tile do cone.
func cast_windstorm(caster: Dictionary, spell: Dictionary, cone_tiles: Array) -> void:
	record_area_action(caster, spell, cone_tiles.back() if not cone_tiles.is_empty() else caster, cone_tiles)
	if cone_tiles.is_empty():
		finalize_action(caster, spell)
		return
	set_facing_towards(caster, cone_tiles[0])
	var dir := {"dx": _signi(cone_tiles[0]["x"] - caster["x"]), "dy": _signi(cone_tiles[0]["y"] - caster["y"])}
	var targets: Array = units_in_tiles(cone_tiles)
	if targets.is_empty():
		_log("Não havia ninguém na área da %s." % spell["name"])
	for u in targets:
		var was_hit := resolve_single_hit(caster, u, spell)
		if was_hit and u["hp"] > 0:
			var push_distance: int = (rng.randi() % 2) + 2
			push_unit(u, dir["dx"], dir["dy"], push_distance)
	damage_trees_in_tiles(cone_tiles, spell["damageMin"], spell["damageMax"])
	damage_structures_in_tiles(cone_tiles, spell["damageMin"], spell["damageMax"])
	finalize_action(caster, spell)

## Envenenamento (Xamã): acerta qualquer um dentro do cone (aliado ou
## inimigo), cada um com sua própria rolagem de acerto.
func cast_poison_cone(caster: Dictionary, spell: Dictionary, cone_tiles: Array) -> void:
	record_area_action(caster, spell, cone_tiles.back() if not cone_tiles.is_empty() else caster, cone_tiles)
	if not cone_tiles.is_empty():
		set_facing_towards(caster, cone_tiles[0])
	var targets: Array = units_in_tiles(cone_tiles)
	if targets.is_empty():
		_log("Não havia ninguém na área do Envenenamento.")
	for u in targets:
		var is_hit: bool = rng.randf() < float(get_effective_hit_chance(caster, u, spell, manhattan(caster, u)))
		if not is_hit:
			_log("%s tenta envenenar %s com %s, mas erra!" % [caster["name"], u["name"], spell["name"]])
			continue
		add_status_effect(u, {"type": "poison", "damageMin": spell["damageMin"], "damageMax": spell["damageMax"], "turnsLeft": spell["turns"]})
		_log("%s envenena %s com %s!" % [caster["name"], u["name"], spell["name"]])
	finalize_action(caster, spell)

## Cone de Gelo (Mago): mesma área do Envenenamento (cone reto), mas com
## dano direto e redução de agilidade em vez de status contínuo — cada alvo
## tem sua própria rolagem de acerto (resolve_single_hit já aplica dano,
## crítico e appliesSpeedReduction, igual Raio de Gelo/Bomba de Gelo).
func cast_ice_cone(caster: Dictionary, spell: Dictionary, cone_tiles: Array) -> void:
	record_area_action(caster, spell, cone_tiles.back() if not cone_tiles.is_empty() else caster, cone_tiles)
	if not cone_tiles.is_empty():
		set_facing_towards(caster, cone_tiles[0])
	var targets: Array = units_in_tiles(cone_tiles)
	if targets.is_empty():
		_log("Não havia ninguém na área do %s." % spell["name"])
	for u in targets:
		resolve_single_hit(caster, u, spell)
	finalize_action(caster, spell)

## Destruição Rastejante (Xamã): a faixa vai até a BORDA do tabuleiro na
## direção escolhida (não só até o clique). Roubo de CT e imobilização são
## INCONDICIONAIS (independem do dano, que é hit-gated à parte).
func cast_creeping_destruction(caster: Dictionary, spell: Dictionary, target_tile: Dictionary) -> void:
	record_area_action(caster, spell, target_tile)
	set_facing_towards(caster, target_tile)
	var line_tiles = compute_aoe_area_tiles(caster, spell, target_tile)
	if line_tiles == null:
		line_tiles = []
	_log("%s conjura %s, cobrindo uma faixa de 3 tiles de largura até a borda do tabuleiro na direção escolhida." % [caster["name"], spell["name"]])
	var hits: Array = units_in_tiles(line_tiles)
	if hits.is_empty():
		_log("Não havia ninguém na linha da Destruição Rastejante.")
	for target in hits:
		target["ct"] = maxi(target["ct"] - 15, 0)
		add_status_effect(target, {"type": "root", "damageMin": 0, "damageMax": 0, "turnsLeft": 1})
		_log("%s perde 15 de CT e fica imóvel no próximo turno, com a Destruição Rastejante!" % target["name"])
		resolve_single_hit(caster, target, spell)
	damage_trees_in_tiles(line_tiles, spell["damageMin"], spell["damageMax"])
	damage_structures_in_tiles(line_tiles, spell["damageMin"], spell["damageMax"])
	finalize_action(caster, spell)

## Labaredas da Salamandra: reutiliza exatamente a faixa/direção da
## Destruição Rastejante, mas cada alvo recebe somente a rolagem normal de
## fogo/Queimando; não herda o dreno de CT nem o enraizamento do Xamã.
## Pedido do usuário: mesma regra de cast_fire_self_area/cast_fire_cone —
## acerta qualquer um na área, cura em vez de ferir quem tiver afinidade
## fire:heal.
func cast_salamander_flame_wave(caster: Dictionary, spell: Dictionary, target_tile: Dictionary) -> void:
	set_facing_towards(caster, target_tile)
	var tiles = compute_aoe_area_tiles(caster, spell, target_tile)
	if tiles == null: tiles = []
	last_action_vfx = {"kind":"flame-wave", "caster":caster, "item":spell, "target":target_tile.duplicate(true), "tiles":tiles.duplicate(true)}
	_log("%s lança %s pela faixa vulcânica!" % [caster["name"], spell["name"]])
	var hit_any := false
	for victim in units_in_tiles(tiles):
		if victim != null:
			hit_any = true
			resolve_single_hit(caster, victim, spell)
	if not hit_any: _log("Não havia ninguém na área das labaredas.")
	damage_trees_in_tiles(tiles, spell["damageMin"], spell["damageMax"])
	damage_structures_in_tiles(tiles, spell["damageMin"], spell["damageMax"])
	finalize_action(caster, spell)

## Tacar Tronco (Troll): mesma faixa cardeal da Destruição Rastejante, só
## que bandLength x bandWidth (3x3) numa direção só, e dano/empurrão são
## hit-gated normal (não incondicional). Empurrão na direção do arremesso.
func cast_throw_log(caster: Dictionary, spell: Dictionary, target_tile: Dictionary) -> void:
	record_area_action(caster, spell, target_tile)
	set_facing_towards(caster, target_tile)
	var throw_dir := _cardinal_direction(caster, target_tile)
	var dx: int = throw_dir.x
	var dy: int = throw_dir.y
	var line_tiles = compute_aoe_area_tiles(caster, spell, target_tile)
	if line_tiles == null:
		line_tiles = []
	_log("%s arremessa %s, cobrindo uma faixa de %dx%d tiles na direção escolhida." % [caster["name"], spell["name"], spell["bandLength"], spell["bandWidth"]])
	var hits: Array = units_in_tiles(line_tiles)
	if hits.is_empty():
		_log("Não havia ninguém na faixa do Tacar Tronco.")
	for target in hits:
		var was_hit := resolve_single_hit(caster, target, spell)
		if was_hit and target["hp"] > 0 and spell.has("knockback"):
			var moved := push_unit(target, dx, dy, spell["knockback"]["distance"])
			if not moved and spell["knockback"].get("blockedExtraDamage") and not is_large_unit(target):
				target["hp"] = maxi(target["hp"] - spell["knockback"]["blockedExtraDamage"], 0)
				_log("%s está bloqueado(a) e não pode ser empurrado(a) — leva %d de dano extra!" % [target["name"], spell["knockback"]["blockedExtraDamage"]])
	damage_trees_in_tiles(line_tiles, spell["damageMin"], spell["damageMax"])
	damage_structures_in_tiles(line_tiles, spell["damageMin"], spell["damageMax"])
	finalize_action(caster, spell)

## Varredura de Galhos (Troncus): mesma faixa cardeal do Tacar Tronco (pela
## regra 2x2, sai das 2 casas da borda do corpo), mas só atinge INIMIGOS e
## cada um no máximo uma vez (units_in_tiles já deduplica quem ocupa várias
## casas da área) — acerto rolado por alvo em resolve_single_hit.
func cast_branch_sweep(caster: Dictionary, spell: Dictionary, target_tile: Dictionary) -> void:
	record_area_action(caster, spell, target_tile)
	set_facing_towards(caster, target_tile)
	var tiles = compute_aoe_area_tiles(caster, spell, target_tile)
	if tiles == null:
		tiles = []
	_log("%s usa %s, varrendo a área à frente!" % [caster["name"], spell["name"]])
	var hits: Array = units_in_tiles(tiles).filter(func(o): return o["team"] != caster["team"] and o["hp"] > 0)
	if hits.is_empty():
		_log("Não havia inimigos na área da varredura.")
	for enemy in hits:
		resolve_single_hit(caster, enemy, spell)
	finalize_action(caster, spell)

## Seiva Restauradora (Troncus): o próprio Troncus ou um aliado adjacente ao
## corpo 2x2. MP pago ANTES da recuperação (inclusive em si mesmo); HP e MP
## sorteados separadamente, sem passar dos máximos; remove Envenenado.
func cast_restoring_sap(caster: Dictionary, target: Dictionary, spell: Dictionary) -> bool:
	var cost: int = int(spell.get("mpCost", 0))
	var is_self: bool = target["name"] == caster["name"]
	if target["hp"] <= 0 or target["team"] != caster["team"] or (not is_self and manhattan(caster, target) > int(spell.get("maxRange", 1))):
		_log("%s só pode ser usada no próprio Troncus ou num aliado adjacente." % spell["name"])
		return false
	if int(caster.get("mp", 0)) < cost:
		_log("%s não tem MP suficiente para %s." % [caster["name"], spell["name"]])
		return false
	caster["mp"] = int(caster["mp"]) - cost
	var hp_roll: int = rng.randi_range(int(spell["healMin"]), int(spell["healMax"]))
	var mp_roll: int = rng.randi_range(int(spell["mpRestoreMin"]), int(spell["mpRestoreMax"]))
	var healed: int = mini(hp_roll, int(target["maxHp"]) - int(target["hp"]))
	target["hp"] = int(target["hp"]) + healed
	var restored: int = mini(mp_roll, maxi(int(target.get("maxMp", 0)) - int(target.get("mp", 0)), 0))
	if target.has("mp"):
		target["mp"] = int(target["mp"]) + restored
	var was_poisoned: bool = _has_status(target, "poison")
	target["statusEffects"] = (target.get("statusEffects", []) as Array).filter(func(e): return e.get("type", "") != "poison")
	_log("%s usa %s em %s: +%d HP e +%d MP%s." % [caster["name"], spell["name"], target["name"], healed, restored, " e remove o veneno" if was_poisoned else ""])
	set_facing_towards(caster, target)
	# MP já pago acima — finalize_action só cobra o CT e encerra a ação.
	finalize_action(caster, DataUtil.merge(spell, {"mpCost": 0}))
	return true

## Tiro Penetrante (Arqueiro): igual ao Relâmpago, mas sempre vai até o
## alcance máximo fixo (não até onde clicou) e só nas 4 direções cardeais.
## Extraído de cast_pierce_shot pra ser reutilizado também pela IA (ver
## enemy_act/Flecha de Fogo Penetrante do Demônio das Chamas), que precisa
## computar a mesma linha reta pra CADA uma das 4 direções cardeais antes de
## escolher a melhor, sem duplicar a lógica de raycast.
func compute_pierce_line_tiles(caster: Dictionary, dx: int, dy: int, max_range: int) -> Array:
	var line_tiles: Array = []
	for lane in body_lane_origins(caster, dx, dy):
		for d in range(1, max_range + 1):
			var x: int = lane["x"] + dx * d
			var y: int = lane["y"] + dy * d
			if not in_bounds(x, y):
				break
			line_tiles.append({"x": x, "y": y})
	return line_tiles

func cast_pierce_shot(caster: Dictionary, spell: Dictionary, target_tile: Dictionary) -> void:
	record_area_action(caster, spell, target_tile)
	if is_arrow_rain_attack(caster, spell):
		cast_arrow_rain(caster, spell, target_tile)
		return
	set_facing_towards(caster, target_tile)
	var pierce_dir := _cardinal_direction(caster, target_tile)
	var line_tiles: Array = compute_pierce_line_tiles(caster, pierce_dir.x, pierce_dir.y, spell["maxRange"])
	_log("%s atira %s, perfurando %d quadrado(s) em linha reta." % [caster["name"], spell["name"], line_tiles.size()])
	var hits: Array = units_in_tiles(line_tiles)
	if hits.is_empty():
		_log("Não havia ninguém na linha de %s." % spell["name"])
	for enemy in hits:
		resolve_single_hit(caster, enemy, spell)
	damage_trees_in_tiles(line_tiles, spell["damageMin"], spell["damageMax"])
	damage_structures_in_tiles(line_tiles, spell["damageMin"], spell["damageMax"])
	finalize_action(caster, spell)

## Invocar Fogo Vivo (Demônio das Chamas): reaproveita integralmente
## dungeon_monster_data("living_fire", ...) — a MESMA unidade da Torre, sem
## nenhuma variação — e spawn_unit, o mesmo ponto de entrada usado por todo
## reforço/invocação já existente no jogo (Torre/Horda/Vale da Lua), então o
## Fogo Vivo invocado entra automaticamente na corrida de CT/turnos como
## qualquer outra unidade. Validade do tile: mesmo par
## `terrain walkable + occupant_at == null` já usado por
## _first_free_tile_near (reforços da Torre), mais a checagem de estrutura
## que aquele helper não precisa (ele já procura só em terreno aberto).
## Núcleo compartilhado de toda magia "invocar 1 unidade num tile vazio
## dentro de alcance" (Invocar Fogo Vivo do Demônio das Chamas, Invocar
## Morcegos do Vampiro, Invocar Esqueleto/Zumbi do Lich): valida o tile
## (mesmo par terrain walkable + occupant_at + structure_at já usado por
## _first_free_tile_near/reforços da Torre) e registra a unidade pelo mesmo
## spawn_unit de sempre — nenhuma invocação nova cria um 2º sistema de spawn
## paralelo. `unit_data_builder` recebe (índice, {x,y}) e devolve o
## dicionário pronto pra spawn_unit, igual a dungeon_monster_data/
## lua_monster_data já fazem pros outros caminhos de spawn do jogo.
func _cast_summon_unit(caster: Dictionary, item: Dictionary, target_tile: Dictionary, name_prefix: String, unit_data_builder: Callable) -> void:
	var tx: int = int(target_tile["x"])
	var ty: int = int(target_tile["y"])
	var terrain = terrain_at(tx, ty)
	var open_ground: bool = terrain == null or terrain.get("walkable", false)
	if not open_ground or occupant_at(tx, ty) != null or structure_at(tx, ty) != null:
		_log("%s tenta usar %s, mas o local escolhido não está livre." % [caster["name"], item["name"]])
		return
	var existing_count: int = units.filter(func(o): return String(o.get("name", "")).begins_with(name_prefix)).size()
	var data: Dictionary = unit_data_builder.call(existing_count + 1, {"x": tx, "y": ty})
	data["team"] = caster["team"]
	var spawned := spawn_unit(String(data["name"]), data)
	_log("%s invoca %s!" % [caster["name"], spawned["name"]])
	finalize_action(caster, item)

func cast_summon_living_fire(caster: Dictionary, item: Dictionary, target_tile: Dictionary) -> void:
	_cast_summon_unit(caster, item, target_tile, "Fogo Vivo", func(index, pos): return dungeon_monster_data("living_fire", index, pos))

func cast_summon_vampire_bat(caster: Dictionary, item: Dictionary, target_tile: Dictionary) -> void:
	_cast_summon_unit(caster, item, target_tile, "Morcego Vampiro", func(index, pos): return lua_monster_data("vampire_bat", index, pos))

## Invocar Esqueleto/Invocar Zumbi (Lich): mesmo Esqueleto/Zumbi exatos da
## Torre (dungeon_monster_data), nenhuma variação nova.
func cast_summon_skeleton(caster: Dictionary, item: Dictionary, target_tile: Dictionary) -> void:
	_cast_summon_unit(caster, item, target_tile, "Esqueleto", func(index, pos): return dungeon_monster_data("skeleton", index, pos))

func cast_summon_zombie(caster: Dictionary, item: Dictionary, target_tile: Dictionary) -> void:
	_cast_summon_unit(caster, item, target_tile, "Zombie", func(index, pos): return dungeon_monster_data("zombie", index, pos))

# --- Fase 3: interação de movimento com terreno/estrutura (game.js:4345-4373, 4887-4924, 8285-8308, 9318-9420) ---

## Rede de segurança: uma unidade viva nunca permanece sobre um cadáver
## ressuscitável — acha um tile vazio ao lado (preferindo a direção dada),
## respeitando bloqueio de terreno e exclusividade de Castelo/Montanha.
func find_corpse_safe_side_tile(u: Dictionary, origin: Dictionary, preferred_dx: int = 0, preferred_dy: int = 0) -> Variant:
	var directions_raw = [
		[preferred_dx, preferred_dy],
		[preferred_dy, -preferred_dx],
		[-preferred_dy, preferred_dx],
		[-preferred_dx, -preferred_dy],
		[1, 0], [-1, 0], [0, 1], [0, -1],
	]
	var seen := {}
	var directions: Array = []
	for d in directions_raw:
		if d[0] == 0 and d[1] == 0:
			continue
		var key := "%d,%d" % [d[0], d[1]]
		if seen.has(key):
			continue
		seen[key] = true
		directions.append(d)
	for d in directions:
		var x: int = origin["x"] + d[0]
		var y: int = origin["y"] + d[1]
		if not in_bounds(x, y) or occupant_at(x, y) != null:
			continue
		var terrain = terrain_at(x, y)
		if terrain != null and BoardLayout.BLOCKING_TERRAIN_TYPES.has(terrain["type"]):
			continue
		var structure = structure_at(x, y)
		if structure != null and structure["team"] != u["team"]:
			continue
		return {"x": x, "y": y}
	return null

func separate_living_unit_from_corpse(u, previous_tile, preferred_dx: int = 0, preferred_dy: int = 0) -> bool:
	if u == null or u["hp"] <= 0 or dead_unit_at(u["x"], u["y"]) == null:
		return true
	var side = find_corpse_safe_side_tile(u, {"x": u["x"], "y": u["y"]}, preferred_dx, preferred_dy)
	if side != null:
		u["x"] = side["x"]
		u["y"] = side["y"]
		_log("%s é desviado(a) para o lado para não ocupar um cadáver." % u["name"])
		return true
	if previous_tile != null and occupant_at(previous_tile["x"], previous_tile["y"]) == null:
		u["x"] = previous_tile["x"]
		u["y"] = previous_tile["y"]
	return false

## Tiles inimigos alcançáveis pela Investida: só nas 4 direções cardeais,
## até 2x o próprio deslocamento; pára no primeiro ocupante do caminho — só
## vira alvo clicável se for inimigo (aliado no meio bloqueia sem virar alvo).
func compute_charge_targets(u: Dictionary, item: Dictionary = {}) -> Array:
	var max_dist: int = int(item.get("maxRange", u["moveRange"] * 2))
	var dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]]
	var targets: Array = []
	for d in dirs:
		for dist in range(1, max_dist + 1):
			var x: int = u["x"] + d[0] * dist
			var y: int = u["y"] + d[1] * dist
			if not in_bounds(x, y):
				break
			if dead_unit_at(x, y) != null:
				break
			var occupant = unit_at(x, y)
			if occupant != null:
				if occupant["team"] != u["team"]:
					targets.append({"x": x, "y": y})
				break
			# Bote Selvagem (`clearPathOnly`): terreno bloqueante/estrutura no
			# caminho encerra a linha (a Investida do Orc continua como era).
			if item.get("clearPathOnly", false) and (_terrain_blocks_transit(terrain_at(x, y), u) or structure_at(x, y) != null):
				break
	return targets

## Investida (Orc): corre em linha reta até `target`, pára ao lado dele
## (não em cima) e ataca — conta como mover E atacar no mesmo turno.
func cast_charge(caster: Dictionary, target: Dictionary, item: Dictionary) -> bool:
	var dx: int = _signi(target["x"] - caster["x"])
	var dy: int = _signi(target["y"] - caster["y"])
	var previous_tile := {"x": caster["x"], "y": caster["y"]}
	var landing := {"x": target["x"] - dx, "y": target["y"] - dy}
	var charge_path: Array = []
	var charge_distance: int = maxi(absi(landing["x"] - caster["x"]), absi(landing["y"] - caster["y"]))
	for distance in range(1, charge_distance + 1):
		charge_path.append({"x": caster["x"] + dx * distance, "y": caster["y"] + dy * distance})
	# Alvo já adjacente: o ponto de parada é a própria casa de quem avança.
	var landing_blocker = occupant_at(landing["x"], landing["y"])
	if landing_blocker != null and landing_blocker["name"] != caster["name"]:
		_log("%s não pode executar %s: o ponto de parada está ocupado por um corpo." % [caster["name"], item.get("name", "Investida")])
		return false
	if landing["x"] != caster["x"] or landing["y"] != caster["y"]:
		caster["displacedThisTurn"] = true
	caster["x"] = landing["x"]
	caster["y"] = landing["y"]
	caster["hasMoved"] = true
	# Montaria conduzida (Lobo com cavaleiro): quem gasta o movimento do turno
	# é o cavaleiro, e ele acompanha a montaria.
	turn_owner(caster)["hasMoved"] = true
	separate_living_unit_from_corpse(caster, previous_tile, dy, -dx)
	set_facing_towards(caster, target)
	sync_mounts()
	apply_trap_crossings(caster, charge_path)
	_log("%s avança numa investida contra %s!" % [caster["name"], target["name"]])
	var was_hit := resolve_single_hit(caster, target, item)
	if was_hit and item.get("rootsUntilCasterTurn", false) and target.get("hp", 0) > 0:
		_apply_caster_turn_root(caster, target)
	if was_hit and item.has("knockback") and target.get("hp", 0) > 0:
		var moved := push_unit(target, dx, dy, int(item["knockback"].get("distance", 1)))
		if not moved and item["knockback"].has("blockedExtraDamage") and not is_large_unit(target):
			target["hp"] = maxi(0, int(target["hp"]) - int(item["knockback"]["blockedExtraDamage"]))
			_log("%s está bloqueado(a) e sofre %d dano extra!" % [target["name"], item["knockback"]["blockedExtraDamage"]])
	finalize_action(caster, item)
	return true

## Bote Selvagem: imobilizado ("root", sem dano) até o INÍCIO do próximo
## turno de quem aplicou — `expiresOnTurnOf` é conferido em begin_turn_for
## (ver _expire_caster_turn_effects), não o contador do alvo. turnsLeft alto
## só impede o tique de fim de turno do alvo de removê-lo antes da hora.
func _apply_caster_turn_root(caster: Dictionary, target: Dictionary) -> void:
	if (target.get("statusImmunities", []) as Array).has("root"):
		return
	var effects: Array = (target.get("statusEffects", []) as Array).filter(func(e): return not (e.get("type", "") == "root" and e.get("expiresOnTurnOf", "") == caster["name"]))
	effects.append({"type": "root", "damageMin": 0, "damageMax": 0, "turnsLeft": 99, "expiresOnTurnOf": caster["name"]})
	target["statusEffects"] = effects
	_log("%s fica imobilizado(a) até o próximo turno de %s!" % [target["name"], caster["name"]])

## Início do turno de `u` (ou da montaria que ele conduz): encerra os efeitos
## presos ao turno dele (Bote Selvagem). Efeito cuja fonte morreu também cai.
func _expire_caster_turn_effects(u: Dictionary) -> void:
	var owners := [String(u["name"])]
	var ridden = mount_of(u)
	if ridden != null: owners.append(String(ridden["name"]))
	for other in units:
		var effects: Array = other.get("statusEffects", [])
		if not effects.any(func(e): return e.has("expiresOnTurnOf")):
			continue
		other["statusEffects"] = effects.filter(func(e):
			if not e.has("expiresOnTurnOf"): return true
			var source_name: String = String(e["expiresOnTurnOf"])
			if owners.has(source_name): return false
			return units.any(func(s): return s["name"] == source_name and s["hp"] > 0))

## Uivo de Caça (Lobo): todos os aliados VIVOS no campo, inclusive quem uivou,
## sem limite de distância. +AGI por N turnos; não acumula (renova a duração
## e mantém o mesmo bônus). Ação livre (só MP).
func cast_hunt_howl(caster: Dictionary, item: Dictionary) -> void:
	var bonus: int = int(item.get("speedBonus", 2))
	var turns: int = int(item.get("turns", 2))
	var affected: Array = []
	for ally in units:
		if ally["team"] != caster["team"] or int(ally["hp"]) <= 0 or ally.get("caged", false):
			continue
		var existing = null
		for e in ally.get("statusEffects", []):
			if e.get("type", "") == "huntHowl":
				existing = e
				break
		if existing != null:
			existing["turnsLeft"] = turns
		else:
			ally["speed"] = int(ally["speed"]) + bonus
			(ally["statusEffects"] as Array).append({"type": "huntHowl", "turnsLeft": turns, "speedBonus": bonus})
		affected.append(String(ally["name"]))
	hunt_howl_events.append({"casterName": caster["name"], "targetNames": affected})
	_log("%s uiva! %d aliado(s) ganham +%d de agilidade por %d turno(s)." % [caster["name"], affected.size(), bonus, turns])
	finish_free_self_action(caster, item)

func cast_dragon_kick(caster: Dictionary, item: Dictionary, target_tile: Dictionary) -> bool: return MonkRules.cast_dragon_kick(self, caster, item, target_tile)
func compute_iaijutsu_targets(u: Dictionary, item: Dictionary) -> Array: return SamuraiRules.compute_iaijutsu_targets(self, u, item)
func compute_iaijutsu_range_tiles(u: Dictionary, item: Dictionary) -> Array: return SamuraiRules.compute_iaijutsu_range_tiles(self, u, item)
func cast_iaijutsu(caster: Dictionary, target: Dictionary, item: Dictionary) -> bool: return SamuraiRules.cast_iaijutsu(self, caster, target, item)
func compute_crescent_anchor_tiles(u: Dictionary) -> Array: return SamuraiRules.compute_crescent_anchor_tiles(self, u)
func compute_crescent_tiles_for_dir(u: Dictionary, dx: int, dy: int) -> Array: return SamuraiRules.compute_crescent_tiles_for_dir(self, u, dx, dy)
func cast_crescent_slash(caster: Dictionary, item: Dictionary, target_tile: Dictionary) -> void: SamuraiRules.cast_crescent_slash(self, caster, item, target_tile)
const MOUNT_FALL_DAMAGE_MIN := 2
const MOUNT_FALL_DAMAGE_MAX := 5

# --- Montaria (Vestruz): montar/desmontar, fila de turnos da dupla, queda do cavaleiro e as habilidades da Vestruz. (ver autoload/rules/mount_rules.gd) ---
func mount_of(rider: Dictionary) -> Variant: return MountRules.mount_of(self, rider)
func rider_of(mount: Dictionary) -> Variant: return MountRules.rider_of(self, mount)
func turn_owner(u: Dictionary) -> Dictionary: return MountRules.turn_owner(self, u)
func can_mount(rider: Dictionary, mount: Dictionary) -> bool: return MountRules.can_mount(self, rider, mount)
func mount_candidates(rider: Dictionary) -> Array: return MountRules.mount_candidates(self, rider)
func mount_unit(rider: Dictionary, mount: Dictionary) -> bool: return MountRules.mount_unit(self, rider, mount)
func dismount_tiles(rider: Dictionary) -> Array: return MountRules.dismount_tiles(self, rider)
func dismount_unit(rider: Dictionary, tile: Dictionary) -> bool: return MountRules.dismount_unit(self, rider, tile)
func sync_mounts() -> void: MountRules.sync_mounts(self)
func _release_rider_on_mount_death(mount: Dictionary) -> void: MountRules._release_rider_on_mount_death(self, mount)
func compute_vestruz_dash_tiles(u: Dictionary, item: Dictionary) -> Array: return MountRules.compute_vestruz_dash_tiles(self, u, item)
func cast_vestruz_dash(caster: Dictionary, item: Dictionary, dest: Dictionary) -> bool: return MountRules.cast_vestruz_dash(self, caster, item, dest)
func cast_dust_cloud(caster: Dictionary, item: Dictionary) -> void: MountRules.cast_dust_cloud(self, caster, item)
func cast_vestruz_heal(caster: Dictionary, item: Dictionary) -> void: MountRules.cast_vestruz_heal(self, caster, item)
func compute_slime_jump_targets(caster: Dictionary, item: Dictionary) -> Array:
	var result: Array = []
	for tile in compute_range_tiles(caster, item):
		if occupant_at(tile["x"], tile["y"]) != null: continue
		var terrain = terrain_at(tile["x"], tile["y"])
		if terrain != null and BoardLayout.BLOCKING_TERRAIN_TYPES.has(terrain.get("type", "")): continue
		result.append(tile)
	return result

func cast_slime_jump(caster: Dictionary, item: Dictionary, target_tile: Dictionary) -> void:
	if occupant_at(target_tile["x"], target_tile["y"]) != null:
		_log("%s não pode pousar no quadrado ocupado." % caster["name"])
		return
	caster["x"] = target_tile["x"]
	caster["y"] = target_tile["y"]
	caster["hasMoved"] = true
	set_facing_towards(caster, target_tile)
	_log("%s salta e aterrissa em (%d, %d)!" % [caster["name"], caster["x"], caster["y"]])
	var tiles: Array = []
	for d in [[1,0],[-1,0],[0,1],[0,-1]]:
		var tile := {"x": caster["x"] + d[0], "y": caster["y"] + d[1]}
		if in_bounds(tile["x"], tile["y"]): tiles.append(tile)
	for target in units_in_tiles(tiles):
		if target["team"] == caster["team"]: continue
		var was_hit := resolve_single_hit(caster, target, item)
		if was_hit and target.get("hp", 0) > 0:
			var dx := _signi(target["x"] - caster["x"])
			var dy := _signi(target["y"] - caster["y"])
			push_unit(target, dx, dy, 1)
	finalize_action(caster, item)

## Atropelar (Troll): não pára no primeiro inimigo — passa por cima de todo
## mundo no caminho (cada um sofre o golpe) e só pára de verdade num aliado,
## numa estrutura inimiga ou na borda do tabuleiro. Sempre move o máximo
## possível na direção escolhida; se a última casa ficar ocupada, empurra o
## Troll pra uma das 4 casas livres ao lado.
func cast_trample(caster: Dictionary, item: Dictionary, target_tile: Dictionary) -> void:
	var trample_dir := _cardinal_direction(caster, target_tile)
	var dx: int = trample_dir.x
	var dy: int = trample_dir.y
	var final_x: int = caster["x"]
	var final_y: int = caster["y"]
	var previous_tile := {"x": caster["x"], "y": caster["y"]}
	var hits: Array = []
	var structure_hits: Array = []
	var trample_path: Array = []

	for d in range(1, item["maxRange"] + 1):
		var x: int = caster["x"] + dx * d
		var y: int = caster["y"] + dy * d
		if not in_bounds(x, y):
			break
		if dead_unit_at(x, y) != null:
			break
		# Corpo de 4 casas: morro/parede/estrutura em QUALQUER casa do corpo
		# interrompe o atropelo (árvore e outros props não).
		if is_large_unit(caster) and _large_body_blocked_at(caster, x, y):
			break
		# Castelo/Montanha do time adversário: intransponível — o atropelo
		# pára ANTES desse tile, mas ainda acerta quem estiver nele e a
		# própria estrutura, como se o Troll tivesse batido de frente nela.
		var structure = structure_at(x, y)
		if structure != null and structure["team"] != caster["team"]:
			var defender = unit_at(x, y)
			if defender != null:
				hits.append(defender)
			structure_hits.append(structure)
			break
		# Corpo 1x1: só o próprio tile. Corpo grande: as 4 casas que ele cobre.
		var body_units: Array = units_in_tiles(footprint_tiles(caster, x, y)).filter(func(o): return o["name"] != caster["name"])
		if body_units.any(func(o): return o["team"] == caster["team"]):
			break
		final_x = x
		final_y = y
		trample_path.append({"x": x, "y": y})
		for occupant in body_units:
			if not hits.any(func(h): return h["name"] == occupant["name"]):
				hits.append(occupant)

	var last_occupant = unit_at(final_x, final_y)
	if last_occupant != null and last_occupant["name"] != caster["name"]:
		var push_options_raw = [
			{"x": final_x + dx, "y": final_y + dy},
			{"x": final_x + dy, "y": final_y + dx},
			{"x": final_x - dy, "y": final_y - dx},
			{"x": final_x - dx, "y": final_y - dy},
		]
		var push_options: Array = []
		for t in push_options_raw:
			if not in_bounds(t["x"], t["y"]) or occupant_at(t["x"], t["y"]) != null:
				continue
			var push_structure = structure_at(t["x"], t["y"])
			if push_structure != null and push_structure["team"] != caster["team"]:
				continue
			push_options.append(t)
		if push_options.size() > 0:
			final_x = push_options[0]["x"]
			final_y = push_options[0]["y"]
			trample_path.append({"x": final_x, "y": final_y})

	# Corpo grande nunca termina sobreposto a alguém/algo: recua pelo caminho
	# até a última casa onde o corpo inteiro cabe (no pior caso, o ponto de partida).
	if is_large_unit(caster):
		while (final_x != caster["x"] or final_y != caster["y"]) and not _can_unit_anchor_at(caster, final_x, final_y):
			trample_path.pop_back()
			var back: Dictionary = trample_path.back() if not trample_path.is_empty() else {"x": caster["x"], "y": caster["y"]}
			final_x = back["x"]
			final_y = back["y"]

	set_facing_towards(caster, {"x": final_x, "y": final_y})
	caster["x"] = final_x
	caster["y"] = final_y
	separate_living_unit_from_corpse(caster, previous_tile, dy, -dx)
	caster["hasMoved"] = true
	apply_trap_crossings(caster, trample_path)
	_log("%s atropela em linha reta!" % caster["name"])

	if hits.is_empty() and structure_hits.is_empty():
		_log("Não havia ninguém no caminho do atropelo.")
	for enemy in hits:
		resolve_single_hit(caster, enemy, item)
	for structure in structure_hits:
		damage_structure(structure, item["damageMin"], item["damageMax"])

	finalize_action(caster, item)

## Ataque Giratório (Guerreiro) / Crescimento (Troll): mesmo resolvedor —
## ataca as 8 casas ao redor (incluindo diagonais) de uma vez, sem mirar.
func cast_growth_attack(caster: Dictionary, spell: Dictionary) -> void:
	record_area_action(caster, spell, caster)
	var dirs = [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]
	var tiles: Array = []
	# Anel ao redor do corpo inteiro (1 casa: as 8 de sempre; 2x2: as 12 vizinhas).
	for body_tile in footprint_tiles(caster):
		for d in dirs:
			var t := {"x": body_tile["x"] + d[0], "y": body_tile["y"] + d[1]}
			if in_bounds(t["x"], t["y"]) and not unit_contains_tile(caster, t["x"], t["y"]) and not tiles.has(t):
				tiles.append(t)
	if spell.get("damageType", "") == "fire":
		last_action_vfx = {"kind":"fire-area", "caster":caster, "item":spell, "tiles":tiles.duplicate(true)}
	_log("%s usa %s e ataca tudo ao redor!" % [caster["name"], spell["name"]])
	var hits: Array = units_in_tiles(tiles).filter(func(target): return target["name"] != caster["name"])
	if hits.is_empty():
		_log("Não havia ninguém ao redor.")
	for enemy in hits:
		resolve_single_hit(caster, enemy, spell)
	damage_trees_in_tiles(tiles, spell["damageMin"], spell["damageMax"])
	damage_structures_in_tiles(tiles, spell["damageMin"], spell["damageMax"])
	finalize_action(caster, spell)

# --- Fase 4: execução de movimento e reações (game.js:5653-5735, 6295-6321, 7664-7687, 8620-8646) ---

func team_units(team: String) -> Array:
	return units.filter(func(u): return u["team"] == team)

## A Maga presa na gaiola nunca conta como oponente (nem pra IA inimiga mirar
## nela, nem pra nenhuma outra heurística de alvo) — ver _setup_caged_mage.
func opposing_team_of(u: Dictionary) -> Array:
	# Morto-vivo do Cemitério ("neutral", um terceiro time): só ataca o time
	# MAIS PRÓXIMO dele (o de qualquer unidade viva mais perto, jogadores ou
	# inimigos); os dois times, por sua vez, o tratam como oponente.
	if u["team"] == "neutral":
		return _neutral_targets(u)
	var hostile: Array = team_units("enemy" if u["team"] == "player" else "player") + team_units("neutral")
	return hostile.filter(func(o): return not o.get("caged", false) and o.get("mountedOn", "") == "")

func _neutral_targets(u: Dictionary) -> Array: return GraveyardRules._neutral_targets(self, u)
## Água apaga fogo: atravessar QUALQUER quadrado de água no caminho (não só
## terminar nele) já apaga o fogo — voando não conta.
func extinguish_burn_on_water_crossing(u: Dictionary, path_tiles: Array) -> void:
	if u.get("flying", false):
		return
	var has_burn := false
	for e in u.get("statusEffects", []):
		if e["type"] == "burned":
			has_burn = true
			break
	if not has_burn:
		return
	var crossed_water := false
	for t in path_tiles:
		var terrain = terrain_at(t["x"], t["y"])
		if terrain != null and terrain["type"] == "water":
			crossed_water = true
			break
	if not crossed_water:
		return
	u["statusEffects"] = (u["statusEffects"] as Array).filter(func(e): return e["type"] != "burned")
	_log("%s atravessa a água e apaga o fogo!" % u["name"])

## Almas: nascem onde um cadáver termina de decompor sem ser ressuscitado a
## tempo. Passar por cima (ou parar) numa cura 10 HP (+5 MP se tiver mana).
func apply_soul_pickups(u: Dictionary, path_tiles: Array) -> void:
	var collected: Array = []
	for s in souls:
		for t in path_tiles:
			if t["x"] == s["x"] and t["y"] == s["y"]:
				collected.append(s)
				break
	if collected.is_empty():
		return
	souls = souls.filter(func(s): return not collected.has(s))
	for soul in collected:
		var hp_amount: int = int(soul.get("hpAmount", 10))
		var mp_amount: int = int(soul.get("mpAmount", 5))
		var healed: int = mini(hp_amount, u["maxHp"] - u["hp"])
		u["hp"] = mini(u["hp"] + hp_amount, u["maxHp"])
		if u.has("maxMp"):
			u["mp"] = mini(u["mp"] + mp_amount, u["maxMp"])
		_log("%s encontra uma alma no campo de batalha e recupera %d de vida%s." % [u["name"], healed, (" e MP" if u.has("maxMp") else "")])

## Item genérico do ataque de oportunidade do Ladino — nunca aparece em
## nenhum menu, só é usado internamente por apply_opportunity_attacks.
const OPPORTUNITY_ATTACK_ITEM := {
	"name": "Ataque de Oportunidade", "icon": "🗡", "damageMin": 1, "damageMax": 4,
	"critMultiplier": 2, "critChance": 0.0, "hitChance": 0.5, "minRange": 1, "maxRange": 1,
}

## Ataque de oportunidade (Ladino): fora do próprio turno dele, se um
## inimigo passar por um quadrado adjacente a ele (incluindo diagonais), o
## Ladino ataca de surpresa uma vez por movimento, mesmo sem ser sua vez.
func apply_opportunity_attacks(u: Dictionary, path_tiles: Array) -> void:
	var sentinels: Array = []
	for s in alive_units():
		if s.get("hasOpportunityAttack", false) and s["name"] != u["name"] and s["team"] != u["team"] and not is_paralyzed(s):
			sentinels.append(s)
	for sentinel in sentinels:
		var passes_by := false
		for t in path_tiles:
			if maxi(abs(t["x"] - sentinel["x"]), abs(t["y"] - sentinel["y"])) <= 1:
				passes_by = true
				break
		if not passes_by or u["hp"] <= 0 or sentinel["hp"] <= 0:
			continue
		_log("%s aproveita a brecha e ataca %s de surpresa!" % [sentinel["name"], u["name"]])
		resolve_single_hit(sentinel, u, OPPORTUNITY_ATTACK_ITEM)
	if u["hp"] <= 0:
		u["hp"] = 0

## Executa o movimento de fato (jogador ou IA): reconstrói o caminho de
## verdade (não só a distância em linha reta) pra cobrar o custo certo de CT
## e checar armadilhas/água/almas/ataques de oportunidade no percurso.
func perform_move(u: Dictionary, dest: Dictionary) -> void:
	var carrying_mount = mount_of(u)
	if carrying_mount != null:
		perform_move(carrying_mount, dest)
		return
	# Quem "gasta" o movimento/CT é o dono do turno (o cavaleiro, se montado).
	var mover_owner := turn_owner(u)
	if mover_owner.get("cannotMoveThisTurn", false):
		_log("A unidade não pode se mover depois de Fingir de Morto neste turno.")
		return
	var path := reconstruct_path(dest["x"], dest["y"])
	# A armadilha do Ladino não cobra +1 de deslocamento. Em vez disso, o
	# primeiro quadrado dela encerra o movimento imediatamente, mesmo quando o
	# destino original ficava além da armadilha.
	var stop_index := -1
	if not u.get("flying", false):
		for path_index in range(path.size()):
			var step: Dictionary = path[path_index]
			for trap in traps:
				if not trap.get("instant", false):
					continue
				if trap.get("ownerName", "") == u.get("name", ""):
					continue
				for trap_tile in (trap["tiles"] as Array):
					if trap_tile["x"] == step["x"] and trap_tile["y"] == step["y"]:
						stop_index = path_index
						break
				if stop_index >= 0:
					break
			if stop_index >= 0:
				break
	if stop_index >= 0:
		path = path.slice(0, stop_index + 1)
		dest = path[path.size() - 1]
	var cost: int = 0
	for step in path:
		cost += step_cost(u, step["x"], step["y"])
	if path.is_empty():
		cost = last_reachable_costs.get(tile_key(dest["x"], dest["y"]), manhattan(u, dest))
	set_facing_towards(u, dest)
	if int(u["x"]) != int(dest["x"]) or int(u["y"]) != int(dest["y"]):
		u["displacedThisTurn"] = true
	u["x"] = dest["x"]
	u["y"] = dest["y"]
	sync_mounts()
	# Dash (Monge): gasta o movimento extra guardado em vez de encerrar o
	# movimento do turno — exatamente o que finalize_action faz com o ataque
	# bônus da Agilidade/Tiro Rápido.
	if int(mover_owner.get("extraMovesRemaining", 0)) > 0:
		mover_owner["extraMovesRemaining"] = int(mover_owner["extraMovesRemaining"]) - 1
	else:
		mover_owner["hasMoved"] = true
	mover_owner["ct"] -= move_ct_cost(u, cost)
	_log("%s se moveu para (%d, %d)." % [u["name"], dest["x"], dest["y"]])
	apply_trap_crossings(u, path)
	extinguish_burn_on_water_crossing(u, path)
	if u["hp"] > 0:
		apply_soul_pickups(u, path)
	if u["hp"] > 0:
		apply_opportunity_attacks(u, path)

## Mesma detecção de crítico que Main já fazia varrendo o log pra decidir
## reação de dano (ver _show_combat_changes) — usada aqui só pra anotar
## last_action_vfx, nunca pra decidir dano/regra nenhuma (o crítico já foi
## resolvido dentro de resolve_single_hit antes desta função rodar).
func _log_slice_has_critical(log_start: int) -> bool:
	for line in event_log.slice(log_start):
		if "CRÍTICO" in String(line): return true
	return false

const RAIN_BUFF_FIELDS := ["guaranteedNextHit", "critBonusNextAttack", "oneShotDamageBonus", "oneShotDamageBonusSource", "burnNextAttackAlwaysTurns", "slowNextAttackAlwaysTurns", "slowNextAttackAlwaysAmount", "doubleRangeNextAttack", "weakeningStrikeNextAttack", "burnNextAttackTurns"]

func is_arrow_rain_attack(caster: Dictionary, item: Dictionary) -> bool:
	return caster.get("arrowRainPrepared", false) and (item.get("name", "") == "Arco" or item.get("targetMode", "") == "pierce-line" or item.get("targetMode", "") == "arrow-rain")

func record_area_action(caster: Dictionary, item: Dictionary, target: Dictionary, explicit_tiles: Variant = null) -> void:
	var tiles = compute_aoe_area_tiles(caster, item, target) if explicit_tiles == null else explicit_tiles
	if tiles == null: tiles = [target]
	var impact_target := {"x":target["x"], "y":target["y"]}
	if item.get("targetMode", "") == "point-aoe" and not item.get("ignoresUnitObstruction", false): impact_target = resolve_obstructed_target(caster, target)
	last_action_vfx = {"kind":"area-sequence", "caster":caster, "item":item, "target":impact_target, "tiles":tiles.duplicate(true)}

func arrow_rain_item(item: Dictionary) -> Dictionary:
	var result := item.duplicate(true)
	result["rainBaseMode"] = item.get("targetMode", "enemy")
	result["targetMode"] = "arrow-rain"
	return result

func arrow_rain_tiles(caster: Dictionary, item: Dictionary, target: Dictionary) -> Array:
	if item.get("rainBaseMode", item.get("targetMode", "")) != "pierce-line":
		return compute_aoe_area_tiles(caster, {"targetMode":"arrow-rain"}, target)
	var result: Array = []
	var seen := {}
	var rain_dir := _cardinal_direction(caster, target)
	var line := compute_pierce_line_tiles(caster, rain_dir.x, rain_dir.y, item["maxRange"])
	for center in line:
		for tile in compute_aoe_area_tiles(caster, {"targetMode":"arrow-rain"}, center):
			var key := tile_key(tile["x"], tile["y"])
			if not seen.has(key):
				seen[key] = true
				result.append(tile)
	return result

func cast_arrow_rain(caster: Dictionary, item: Dictionary, target: Dictionary) -> void:
	if not is_arrow_rain_attack(caster, item) or caster.get("hasActed", false): return
	var effective := effective_weapon_item(caster, item)
	if not is_in_weapon_range(effective, manhattan(caster, target)): return
	var tiles := arrow_rain_tiles(caster, item, target)
	var buffs := {}
	for key in RAIN_BUFF_FIELDS:
		if caster.has(key): buffs[key] = caster[key]
	var consumed := {}
	var piercing: bool = item.get("rainBaseMode", item.get("targetMode", "")) == "pierce-line"
	# Arco seleciona inimigos e ignora terreno; Perfurante já atinge ambos os times.
	for victim in units_in_tiles(tiles):
		if not piercing and (victim["team"] == caster["team"] or victim.get("caged", false)): continue
		for key in RAIN_BUFF_FIELDS:
			caster.erase(key)
			if buffs.has(key): caster[key] = buffs[key]
		resolve_single_hit(caster, victim, item)
		for key in RAIN_BUFF_FIELDS:
			if caster.has(key): consumed[key] = caster[key]
	for key in RAIN_BUFF_FIELDS:
		caster.erase(key)
		if consumed.has(key): caster[key] = consumed[key]
	if piercing:
		damage_trees_in_tiles(tiles, item["damageMin"], item["damageMax"])
		damage_structures_in_tiles(tiles, item["damageMin"], item["damageMax"])
	caster["arrowRainPrepared"] = caster.get("bonusAttacksRemaining", 0) > 0 and item["name"] == "Arco"
	last_action_vfx = {"kind":"area-sequence", "caster":caster, "item":arrow_rain_item(item), "target":target.duplicate(), "tiles":tiles, "rainFire":buffs.get("burnNextAttackAlwaysTurns", 0) > 0}
	set_facing_towards(caster, target)
	finalize_action(caster, item)

func perform_attack(attacker: Dictionary, defender: Dictionary, item: Dictionary) -> void:
	if not item_requirements_met(attacker, item):
		_log("%s não pode usar %s agora." % [attacker["name"], item["name"]])
		return
	if is_arrow_rain_attack(attacker, item):
		cast_arrow_rain(attacker, item, defender)
		return
	if is_bard_singing(attacker):
		_log("%s está cantando e não pode usar a Besta." % attacker["name"])
		return
	set_facing_towards(attacker, defender)
	var log_start := event_log.size()
	# Pedido do usuário: Míssil Mágico dispara "hits" projéteis em sequência
	# (4, cada um 1-2 de dano) em vez de um impacto só — cada míssil rola seu
	# próprio acerto/dano via resolve_single_hit; pára cedo se o alvo já
	# morreu pros mísseis restantes não "atirarem" num cadáver.
	var shots := maxi(1, int(item.get("hits", 1)))
	var hit := false
	var missile_damages: Array[int] = []
	var shot_results: Array = []
	for i in shots:
		if defender["hp"] <= 0:
			break
		var hp_before_shot := int(defender["hp"])
		var shot_log_start := event_log.size()
		var shot_hit := resolve_single_hit(attacker, defender, item)
		hit = shot_hit or hit
		var shot_damage := maxi(0, hp_before_shot - int(defender["hp"]))
		missile_damages.append(shot_damage)
		# Resultado de CADA golpe (acerto/crítico/dano) para a tela animar um a um.
		shot_results.append({"hit": shot_hit, "critical": _log_slice_has_critical(shot_log_start), "damage": shot_damage})
	if item.get("damageType", "") == "fire":
		last_action_vfx = {"kind":"fire-strike", "caster":attacker, "target":{"x":defender["x"],"y":defender["y"]}}
	else:
		# ETAPA 17: sem isso, um ataque de arma resolvido pela IA (enemy_act)
		# não deixava rastro nenhum pra Main animar depois — só o alvo
		# reagia (_show_combat_changes), o atacante nunca disparava
		# projétil/golpe pesado de verdade. Mesmo padrão que fire-strike já
		# usava, só que cobrindo o caso comum (sem elemento).
		last_action_vfx = {"kind":"weapon-attack", "caster":attacker, "target":{"x":defender["x"],"y":defender["y"]}, "item":item, "hit":hit, "critical":_log_slice_has_critical(log_start)}
		if item.get("name", "") == "Míssil Mágico":
			last_action_vfx["missileDamages"] = missile_damages
		if shots > 1:
			last_action_vfx["shotResults"] = shot_results
	finalize_action(attacker, item)

func perform_ranged_attack_with_obstruction(caster: Dictionary, target: Dictionary, weapon: Dictionary) -> void:
	if is_bard_singing(caster):
		_log("%s está cantando e não pode usar a Besta." % caster["name"])
		return
	set_facing_towards(caster, target)
	var impact_tile := resolve_obstructed_target(caster, {"x": target["x"], "y": target["y"]})
	var actual_defender = unit_at(impact_tile["x"], impact_tile["y"])
	if actual_defender == null:
		_log("%s atira com %s, mas não atinge nada." % [caster["name"], weapon["name"]])
		finalize_action(caster, weapon)
		return
	if actual_defender["name"] != target["name"]:
		_log("%s mirou em %s, mas algo bloqueou o caminho — %s foi atingido no lugar!" % [caster["name"], target["name"], actual_defender["name"]])
	var log_start := event_log.size()
	var hit := resolve_single_hit(caster, actual_defender, weapon)
	if weapon.get("damageType", "") == "fire":
		last_action_vfx = {"kind":"fire-strike", "caster":caster, "target":{"x":actual_defender["x"],"y":actual_defender["y"]}}
	else:
		last_action_vfx = {"kind":"weapon-attack", "caster":caster, "target":{"x":actual_defender["x"],"y":actual_defender["y"]}, "item":weapon, "hit":hit, "critical":_log_slice_has_critical(log_start)}
	finalize_action(caster, weapon)

# --- Fase 4: heurísticas de IA (game.js:9783-10030) -------------------------

# --- IA dos inimigos e de herois controlados pela IA (heuristicas de alvo/magia e o turno da IA). (ver autoload/ai/enemy_ai.gd) ---
func _walkable_path_distance_map(target_x: int, target_y: int, u: Dictionary = {}) -> Dictionary: return EnemyAI._walkable_path_distance_map(self, target_x, target_y, u)
func pick_nearest_target(u: Dictionary) -> Variant: return EnemyAI.pick_nearest_target(self, u)
func pick_weapon_for_distance(weapons: Array, distance: int, target) -> Variant: return EnemyAI.pick_weapon_for_distance(self, weapons, distance, target)
func pick_best_heal_aoe_spot(caster: Dictionary, spell: Dictionary) -> Variant: return EnemyAI.pick_best_heal_aoe_spot(self, caster, spell)
func pick_resurrect_target(caster: Dictionary, spell: Dictionary, require_undead: bool = false) -> Variant: return EnemyAI.pick_resurrect_target(self, caster, spell, require_undead)
func pick_best_safe_aoe_direction(caster: Dictionary, compute_tiles_for_dir: Callable) -> Variant: return EnemyAI.pick_best_safe_aoe_direction(self, caster, compute_tiles_for_dir)
func pick_best_cone_direction(caster: Dictionary, spell: Dictionary) -> Variant: return EnemyAI.pick_best_cone_direction(self, caster, spell)
func pick_best_blast_spot(caster: Dictionary, spell: Dictionary) -> Variant: return EnemyAI.pick_best_blast_spot(self, caster, spell)
func weapon_aim_tiles(u: Dictionary, target: Dictionary, weapon: Dictionary) -> Array:
	if weapon.get("requiresClearPath", false):
		var line: Array = bresenham_line(u["x"], u["y"], target["x"], target["y"])
		return line.slice(1)
	return [{"x": target["x"], "y": target["y"]}]

## Armas normais + qualquer magia de alvo único (targetMode "enemy") que a
## unidade tenha MP pra pagar — deixa pick_weapon_for_distance tratar tudo
## igual, pela distância.
func get_attack_options(u: Dictionary) -> Array:
	if is_bard_singing(u): return []
	var result: Array = (u.get("weapons", []) as Array).filter(func(item): return not item.has("mpCost") or int(item.get("mpCost", 0)) == 0 or int(u.get("mp", 0)) >= int(item["mpCost"]))
	for s in u.get("spells", []):
		if s.get("targetMode") == "enemy" and u["mp"] >= s["mpCost"] and not s.get("manualOnly", false):
			result.append(s)
	return result

## Regra geral (pedido do usuário, Demônio das Chamas/Raio de Fogo):
## qualquer arma/magia "cardinalOnly" exige alvo alinhado na mesma linha ou
## coluna — generalizado do caso específico do Esqueleto (Arremesso de
## Lança) pra qualquer unidade, já que o Demônio das Chamas é o 2º inimigo
## a carregar um item cardinalOnly (Raio de Fogo, ver weapons.gd).
func get_attack_options_against(u: Dictionary, target: Dictionary) -> Array:
	var result := get_attack_options(u)
	if int(u["x"]) != int(target["x"]) and int(u["y"]) != int(target["y"]):
		result = result.filter(func(item): return not item.get("cardinalOnly", false))
	return result

func enemy_attack_then_advance(u: Dictionary, target: Dictionary, weapon_item: Dictionary) -> void: EnemyAI.enemy_attack_then_advance(self, u, target, weapon_item)
func special_fire_area_tiles(caster: Dictionary) -> Array:
	var result: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0: continue
			var x := int(caster["x"]) + dx
			var y := int(caster["y"]) + dy
			if in_bounds(x, y): result.append({"x":x,"y":y})
	for d in [[2,0],[-2,0],[0,2],[0,-2]]:
		var x: int = int(caster["x"]) + int(d[0])
		var y: int = int(caster["y"]) + int(d[1])
		if in_bounds(x, y): result.append({"x":x,"y":y})
	return result

func living_fire_self_destruct_chance(hp: int) -> float:
	return 0.05 if hp > 10 else (0.30 if hp >= 6 else 0.70)

func _count_enemies_in_special_area(caster: Dictionary) -> int:
	var count := 0
	for tile in special_fire_area_tiles(caster):
		var victim = unit_at(tile["x"], tile["y"])
		if victim != null and victim["team"] != caster["team"]: count += 1
	return count

## Pedido do usuário: habilidade de fogo acerta QUALQUER UM na área (aliado
## ou inimigo, mesmo padrão já usado por Bola de Fogo/Cura) — um aliado de
## afinidade "fire:heal" (Fogo Vivo/Lava Humana/Salamandra/Demônio das
## Chamas) recupera HP em vez de sofrer dano, e o Dragão (fire:immune) só
## ignora o golpe; os dois casos retornam antes de chegar em `appliesBurn`
## dentro de resolve_single_hit, então nenhum dos dois pega fogo.
func cast_fire_self_area(caster: Dictionary, item: Dictionary) -> void:
	var tiles := special_fire_area_tiles(caster)
	last_action_vfx = {"kind":"fire-area", "caster":caster, "item":item, "tiles":tiles.duplicate(true)}
	for tile in tiles:
		var victim = unit_at(tile["x"], tile["y"])
		if victim != null:
			resolve_single_hit(caster, victim, item)
	finalize_action(caster, item)

func cast_living_fire_self_destruct(caster: Dictionary, item: Dictionary) -> void:
	cast_fire_self_area(caster, item)
	caster["hp"] = 0
	_log("%s se autodestrói numa explosão de fogo!" % caster["name"])
	finalize_death_if_needed(caster)

## Pedido do usuário: mesma regra de cast_fire_self_area — acerta qualquer
## um na área, cura em vez de ferir quem tiver afinidade fire:heal.
func cast_fire_cone(caster: Dictionary, item: Dictionary, tiles: Array) -> void:
	last_action_vfx = {"kind":"fire-cone", "caster":caster, "item":item, "tiles":tiles.duplicate(true)}
	for tile in tiles:
		var victim = unit_at(tile["x"], tile["y"])
		if victim != null:
			resolve_single_hit(caster, victim, item)
	finalize_action(caster, item)

func _wants_to_summon_reinforcement(u: Dictionary) -> bool: return EnemyAI._wants_to_summon_reinforcement(self, u)
func enemy_act(u: Dictionary) -> void: EnemyAI.enemy_act(self, u)