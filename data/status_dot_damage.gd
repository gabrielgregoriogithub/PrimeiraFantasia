class_name StatusDotDamage
extends RefCounted

## Porte literal de STATUS_DOT_DAMAGE (game.js:11). Dano POR TURNO
## padronizado de cada status de dano contínuo — a duração e efeitos extras
## variam por fonte (arma/magia), o dano em si vem sempre daqui.

const STATUS_DOT_DAMAGE := {
	"poison": {"damageMin": 1, "damageMax": 3},
	"burned": {"damageMin": 1, "damageMax": 1},
}
