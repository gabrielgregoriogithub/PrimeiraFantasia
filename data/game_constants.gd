class_name GameConstants
extends RefCounted

## Porte literal das constantes soltas de game.js (raiz do repositório JS).
## Nenhum valor foi alterado — ver AGENTS.md do protótipo: "Não mude valores
## existentes de armas, magias, personagens ou mapa sem pedido explícito".

const BOARD_SIZE := 13
const CT_THRESHOLD := 100
const CRIT_CHANCE := 0.15
const MAX_GLOBAL_TURNS := 100

const WAIT_COST := 60
const MOVE_MAX_COST := 50

const RANGED_MELEE_HIT_PENALTY := 0.10
const RANGED_MELEE_COUNTER_CHANCE := 0.25
const MAGIC_TRAVEL_MULTIPLIER := 2
const AREA_STRUCTURE_DAMAGE_MULTIPLIER := 2

const TREE_MAX_HP := 10
const HOUSE_MAX_HP := 30
const TENT_MAX_HP := 20
const STRUCTURE_MAX_HP := 100

const CASTLE_ELEVATION := 2
const MOUNTAIN_ELEVATION := 3
const MAX_CLIMB_HEIGHT := 1

const FALL_DAMAGE := 5

## game.js:4940 — status de dano/cura contínuo (duração SOMA em vez de
## substituir quando reaplicado — ver GameState.add_status_effect).
const DOT_HOT_TYPES := ["poison", "bleed", "root", "burned", "regenBoost", "regen", "weakened"]

## game.js:5195 — só magias de área "cobrem o terreno" o bastante pra achar
## quem está invisível.
const AOE_TARGET_MODES := ["point-aoe", "line-aoe", "creeping-line", "flame-creeping-line", "cone-poison", "cone-fire", "freeze-aoe", "cone-windstorm"]
