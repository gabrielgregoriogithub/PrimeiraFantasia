extends GutTest

## ETAPA 16 — Signature Abilities. Confirma que cada Signature casa com o
## herói e a habilidade certos (usando o catálogo real de data/spells.gd e
## data/units.gd, não cópias soltas) e que nenhuma outra combinação
## herói/habilidade é reconhecida como signature por engano.

var _units: Dictionary
var _spells: Dictionary

func before_each() -> void:
	_units = Units.build()
	_spells = Spells.build()

## hero spriteKey -> chave da habilidade em data/spells.gd escolhida como
## Signature (ver ETAPA 16: guerreiro=Ataque Giratório, ladino=Golpe
## Debilitante, arqueiro=Tiro Penetrante, mago=Bola de Fogo,
## quimico=Bomba, bardo=Canção da Inspiração).
const SIGNATURE_SPELL_KEY := {
	"guerreiro": "spinAttack", "ladino": "weakeningStrike", "arqueiro": "pierceShot",
	"mago": "fireball", "quimico": "bomb", "bardo": "bardSongInspiration",
}

func test_each_hero_signature_spell_is_recognized() -> void:
	for hero_key in SIGNATURE_SPELL_KEY:
		var unit: Dictionary = _units[hero_key]
		var spell: Dictionary = _spells[SIGNATURE_SPELL_KEY[hero_key]]
		assert_true(SignatureVisualProfiles.is_signature(unit, spell), "%s deveria reconhecer %s como signature" % [hero_key, spell.get("name", "")])

func test_other_spells_from_the_same_hero_are_not_signatures() -> void:
	var guerreiro: Dictionary = _units["guerreiro"]
	for key in ["powerAttack", "throwSword", "defend"]:
		assert_false(SignatureVisualProfiles.is_signature(guerreiro, _spells[key]), "%s não deveria virar signature do Guerreiro" % key)

func test_signature_spell_does_not_leak_to_other_heroes() -> void:
	var fireball: Dictionary = _spells["fireball"]
	for hero_key in ["guerreiro", "ladino", "arqueiro", "quimico", "bardo"]:
		assert_false(SignatureVisualProfiles.is_signature(_units[hero_key], fireball), "Bola de Fogo só é signature do Mago")

func test_troll_growth_attack_shares_name_and_target_mode_with_spin_attack_but_is_not_signature() -> void:
	# Troll ("growth") e Guerreiro ("spinAttack") compartilham nome
	# ("Ataque Giratório") e targetMode ("self-attack") — só o "kind" difere
	# (growth-attack vs spin-attack). Confirma que o casamento por kind evita
	# a ambiguidade em vez de reconhecer o golpe do Troll por engano.
	var troll: Dictionary = _units["troll"]
	var growth: Dictionary = _spells["growth"]
	assert_eq(growth.get("name", ""), _spells["spinAttack"].get("name", ""))
	assert_false(SignatureVisualProfiles.is_signature(troll, growth))
	assert_false(SignatureVisualProfiles.is_signature(_units["guerreiro"], growth))

func test_profiles_do_not_contain_gameplay_values() -> void:
	var forbidden := ["hp", "mp", "damage", "damageMin", "damageMax", "range", "minRange", "maxRange", "critChance", "hitChance", "ctCost", "mpCost"]
	for hero_key in SignatureVisualProfiles.PROFILES:
		var profile: Dictionary = SignatureVisualProfiles.PROFILES[hero_key]
		for key in forbidden:
			assert_false(profile.has(key), "%s não pode controlar %s" % [hero_key, key])

func test_unmatched_unit_or_item_returns_empty_profile() -> void:
	assert_eq(SignatureVisualProfiles.for_item({"spriteKey": "goblin"}, _spells["fireball"]), {})
	assert_eq(SignatureVisualProfiles.for_item(_units["mago"], {"name": "Nada"}), {})
