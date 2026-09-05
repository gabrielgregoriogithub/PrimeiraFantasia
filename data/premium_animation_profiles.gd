extends RefCounted
class_name PremiumAnimationProfiles

enum Priority { IDLE, MOVE, ATTACK, HIT, DEATH }

const SPEED := {
	"light": {"start":0.045,"settle":0.085,"impact_hold":0.040,"smear":0.055,"stretch":0.045},
	"medium": {"start":0.065,"settle":0.115,"impact_hold":0.055,"smear":0.065,"stretch":0.035},
	"heavy": {"start":0.090,"settle":0.160,"impact_hold":0.075,"smear":0.075,"stretch":0.022},
	"giant": {"start":0.110,"settle":0.210,"impact_hold":0.085,"smear":0.0,"stretch":0.012},
}

static var debug_speed := 1.0
static var timing_log_enabled := false

static func for_weight(weight: String) -> Dictionary:
	return SPEED.get(weight, SPEED["medium"])

static func scaled(seconds: float) -> float:
	return seconds / maxf(0.05, debug_speed)

static func frame_weights(action: String, count: int) -> Array[float]:
	var result: Array[float] = []
	if count <= 0: return result
	for i in count:
		var ratio := float(i) / maxf(1.0, float(count - 1))
		var weight := 1.0
		if action in ["attack", "cast"]:
			weight = 1.35 if i == 0 else (0.62 if ratio < 0.72 else 1.12)
		elif action == "death": weight = 0.72 if ratio < 0.55 else 1.45
		elif action == "hit": weight = 0.68 if i == 0 else 1.25
		result.append(weight)
	return result
