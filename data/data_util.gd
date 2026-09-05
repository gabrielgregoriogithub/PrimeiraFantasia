class_name DataUtil
extends RefCounted

## Equivalente ao spread de objeto do JS (`{ ...base, extra }`), usado nos
## catálogos para compor entradas a partir de STATUS_DOT_DAMAGE.
static func merge(base: Dictionary, extra: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in extra.keys():
		result[key] = extra[key]
	return result
