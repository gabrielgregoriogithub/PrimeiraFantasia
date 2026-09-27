class_name ElementSystemDraft
extends RefCounted

## Enum de elementos portado de Element.kt (guardian_monsters, Apache 2.0):
## GuardianMonsters/guardians/src/.../guardians/Element.kt
## A matriz de multiplicadores abaixo NÃO existe no código-fonte deles
## (ver README.md desta pasta) — é uma proposta própria só reaproveitando
## os nomes dos elementos deles.
enum Element {
	NONE,
	EARTH,
	FIRE,
	WATER,
	AIR,
	FOREST,
	DEMON,
	LINDWORM,
	FROST,
	SPIRIT,
	MOUNTAIN,
	ARTHROPODA,
	LIGHTNING,
}

const SUPER_EFFECTIVE := 2.0
const NOT_VERY_EFFECTIVE := 0.5
const NEUTRAL := 1.0

## attacker_element -> Array de elementos que ele é super efetivo contra.
## Simétrico ao inverso (se A é forte contra B, B é fraco contra A) e
## qualquer par não listado é NEUTRAL. NONE nunca tem vantagem/desvantagem.
const STRONG_AGAINST := {
	Element.FIRE: [Element.FOREST, Element.FROST, Element.ARTHROPODA],
	Element.WATER: [Element.FIRE, Element.MOUNTAIN],
	Element.EARTH: [Element.LIGHTNING, Element.FIRE],
	Element.AIR: [Element.EARTH, Element.ARTHROPODA],
	Element.FOREST: [Element.WATER, Element.MOUNTAIN],
	Element.FROST: [Element.FOREST, Element.AIR, Element.LINDWORM],
	Element.LIGHTNING: [Element.WATER, Element.AIR],
	Element.MOUNTAIN: [Element.LIGHTNING, Element.FROST],
	Element.DEMON: [Element.SPIRIT, Element.LINDWORM],
	Element.SPIRIT: [Element.DEMON, Element.ARTHROPODA],
	Element.LINDWORM: [Element.SPIRIT, Element.WATER],
	Element.ARTHROPODA: [Element.FOREST, Element.EARTH],
}

## Multiplicador de dano de um ataque de attacker_element contra defender_element.
static func efficiency(attacker_element: Element, defender_element: Element) -> float:
	if attacker_element == Element.NONE or defender_element == Element.NONE:
		return NEUTRAL
	if attacker_element == defender_element:
		return NEUTRAL

	var strong: Array = STRONG_AGAINST.get(attacker_element, [])
	if defender_element in strong:
		return SUPER_EFFECTIVE

	var defender_strong: Array = STRONG_AGAINST.get(defender_element, [])
	if attacker_element in defender_strong:
		return NOT_VERY_EFFECTIVE

	return NEUTRAL
