extends RefCounted
var t

func _winner(options: Array) -> String:
	var scored: Array = options.map(func(o): return {"id": o.id, "score": Prompts.score(float(o.dist), float(o.facing), float(o.get("priority", 0.0))), "ambient": o.get("ambient", false)})
	var chosen := Prompts.choose(scored)
	return String(scored[chosen].id) if chosen >= 0 else ""

func test_something_with_a_purpose_wins_the_prompt_over_petting():
	var cat := {"id": "cat", "dist": 0.3, "facing": 1.0, "ambient": true}
	var boar := {"id": "boar", "dist": 2.0, "facing": 0.2, "priority": 0.3}
	t.eq(_winner([cat, boar]), "boar", "the boar you came to feed, though the cat is at your feet")
	t.eq(_winner([boar, cat]), "boar", "whichever the game looks at first")
	t.eq(_winner([cat]), "cat", "with nothing else in reach you can pet the cat")
	t.eq(_winner([]), "", "and with nothing in reach there is no prompt")

func test_among_equals_the_nearer_one_you_face_wins():
	var near := {"id": "near", "dist": 0.8, "facing": 0.9}
	var far := {"id": "far", "dist": 1.6, "facing": 1.0}
	t.eq(_winner([far, near]), "near", "two benches: the nearer")
	var hen := {"id": "hen", "dist": 0.5, "facing": 1.0, "ambient": true}
	var puss := {"id": "puss", "dist": 1.0, "facing": 1.0, "ambient": true}
	t.eq(_winner([puss, hen]), "hen", "two animals to pet: the nearer")
	var villager := {"id": "villager", "dist": 1.5, "facing": 0.9, "priority": 0.6}
	var sign := {"id": "sign", "dist": 1.3, "facing": 0.9}
	t.eq(_winner([sign, villager]), "villager", "priority still decides between things with a purpose")

func test_the_bakery_cat_cannot_take_the_prompt_from_the_boar_beside_it():
	Data.use_island("hearthglow")
	var boar := Vector2(float(WorldActions.SQUIRREL_SPOTS[0][0]), float(WorldActions.SQUIRREL_SPOTS[0][1]))
	var nearest := Vector2.INF
	for spot in Data.layout.get("wildlife", {}).get("cats", []):
		var at := Vector2(float(spot[0]), float(spot[1]))
		if at.distance_to(boar) < nearest.distance_to(boar): nearest = at
	t.ok(nearest.distance_to(boar) < 2.0, "a cat sits within two metres of a bakery boar (%.2f m)" % nearest.distance_to(boar))
	var you := nearest + (nearest - boar).normalized() * 0.7
	var look := (boar - you).normalized()
	var options: Array = [
		{"id": "cat", "dist": you.distance_to(nearest), "facing": look.dot((nearest - you).normalized()), "ambient": true},
		{"id": "boar", "dist": you.distance_to(boar), "facing": look.dot((boar - you).normalized()), "priority": 0.3},
	]
	t.ok(float(options[1].dist) <= 1.5 + 0.6, "standing by the cat, the boar is still in reach (%.2f m)" % float(options[1].dist))
	var by_score: bool = Prompts.score(float(options[0].dist), float(options[0].facing), 0.0) < Prompts.score(float(options[1].dist), float(options[1].facing), 0.3)
	t.ok(by_score, "by distance alone the cat would take the prompt, as it did")
	t.eq(_winner(options), "boar", "the boar keeps it")
