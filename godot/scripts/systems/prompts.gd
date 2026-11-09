class_name Prompts

static func score(dist: float, facing: float, priority: float) -> float:
	return dist - facing * 0.8 - priority

static func better(score_now: float, ambient: bool, best_score: float, best_ambient: bool) -> bool:
	if ambient != best_ambient: return best_ambient
	return score_now < best_score

static func choose(options: Array) -> int:
	var best := -1
	for n in options.size():
		var o: Dictionary = options[n]
		if best < 0 or better(float(o.score), bool(o.get("ambient", false)), float(options[best].score), bool(options[best].get("ambient", false))): best = n
	return best
