extends RefCounted
var t
const AudioDirector := preload("res://scripts/audio/audio_director.gd")

func _state() -> Dictionary:
	var s := GameState.new_game("Tester")
	for q in ["tool", "bridge", "workshop", "fountain", "dock"]: s.quests[q] = {"status": "done", "progress": {}}
	return s

func test_every_villager_has_tastes_and_a_spot():
	for n in Data.npcs.filter(func(x): return not x.has("island") and Data.quests.any(func(q): return q.giver == x.id and Data.quest_island(String(q.id)) == "hearthglow")):
		var tt := Tastes.of(String(n.id))
		t.ok(not tt.is_empty() and Tastes.near_pos(String(n.id)) != Vector2.INF, "%s has tastes and a spot" % n.id)
		for p in tt.get("pieces", []): t.ok(not Data.piece(String(p)).is_empty(), "%s likes a real piece (%s)" % [n.id, p])
		for c in tt.get("colours", []): t.ok(Data.palette.has(String(c)), "%s likes a colour you can paint (%s)" % [n.id, c])
		t.ok(String(tt.get("line", "")).contains("{piece}") and String(tt.get("gossip", "")) != "", "%s has a line and a bit of gossip" % n.id)

func test_a_liked_piece_near_their_spot_wins_a_heart_once_a_day():
	var s := _state()
	var gate := Tastes.near_pos("fern")
	var hedge := {"uid": 1, "id": "hedge", "i": floor(gate.x), "k": floor(gate.y) - 1.0, "r": 0, "y": 0.0}
	var far := {"uid": 2, "id": "hedge", "i": floor(gate.x) - 30.0, "k": floor(gate.y), "r": 0, "y": 0.0}
	t.eq(Tastes.pleased(s, far), [], "a hedge across the village means nothing to Gigia")
	var got := Tastes.pleased(s, hedge)
	t.ok(got.size() == 1 and got[0].npc == "fern" and String(got[0].line).contains("hedge"), "a hedge by her gate pleases her: %s" % str(got))
	t.ok(Tastes.known(s, "fern"), "and now you know what she likes")
	t.eq(Tastes.pleased(s, hedge.merged({"uid": 3})), [], "only once a day")
	s.time.day = int(s.time.day) + 1
	t.eq(Tastes.pleased(s, hedge.merged({"uid": 4})).size(), 1, "the next day, again")
	var bench := {"uid": 5, "id": "chair", "i": floor(gate.x), "k": floor(gate.y) - 1.0, "r": 0, "y": 0.0, "color": "#5cb85c"}
	s.time.day = int(s.time.day) + 1
	t.eq(Tastes.likes("fern", bench), "colour", "a chair painted her green counts too")
	t.eq(Tastes.pleased(s, bench, ["mabel"]), [], "but not while she's not here to see it")

func test_the_paper_gives_tastes_away_one_at_a_time():
	var s := _state()
	var g := Tastes.gossip(s, 0.0)
	t.ok(not g.is_empty() and String(g.text).begins_with("Overheard:"), "gossip: %s" % str(g))
	t.ok(not Tastes.known(s, String(g.id)), "not known until the paper prints it")
	Tastes.learn(s, String(g.id))
	t.ok(Tastes.gossip(s, 0.0).get("id", "") != g.id, "then the next morning it's someone else's")
	for id in Tastes.defs(): Tastes.learn(s, String(id))
	t.eq(Tastes.gossip(s, 0.5), {}, "and once you know them all, no more gossip")
	var p := MorningPaper.compose({"quests": [], "built": 0, "harmony": 0}, {"day": 4, "harmony": 0, "gossip": "Overheard: something.", "market": "Tomorrow is market day."}, Data.paper, [], 0.0)
	t.ok(p.notes.has("Tomorrow is market day.") and p.notes.has("Overheard: something."), "the paper prints both: %s" % str(p.notes))

func test_the_ceremony_cheers_a_liked_piece():
	var c := Inauguration.cfg()
	var f := {"needs": [], "usable": 1, "stares": 0, "who": "", "hangout": "", "n": 1}
	var r := Inauguration.reactions(f, ["fern", "mabel", "captain"], c, 0.2, {"fern": "Oh, a hedge! You do know me."})
	var gigia: Dictionary = r.filter(func(x): return x.npc == "fern")[0]
	t.ok(gigia.heart and gigia.get("taste", false) and String(gigia.line).contains("hedge"), "Gigia cheers her hedge and likes you more")
	t.ok(r.filter(func(x): return x.line != "").size() == 2, "and one other says something")

func test_market_day_every_fifth_day():
	t.ok(not Market.is_day(1) and not Market.is_day(4) and Market.is_day(5) and Market.is_day(10), "day 5, day 10")
	t.ok(Market.open({"day": 5, "minute": 9 * 60.0}) and not Market.open({"day": 5, "minute": 20 * 60.0}) and not Market.open({"day": 6, "minute": 9 * 60.0}), "from morning to early evening")
	var stalls := [{"uid": 7, "id": "counter"}, {"uid": 3, "id": "counter"}, {"uid": 9, "id": "bench"}]
	var counters := Market.counters(stalls)
	t.ok(counters.size() == 2 and int(counters[0].uid) == 3, "only counters are stalls")
	t.eq(Market.assign(["mabel", "fern", "tilly"], counters), {"fern": 3, "mabel": 7}, "a seller each, in order, for as many stalls as there are")
	t.eq(Market.paper_line(4, 2), String(Market.cfg().paper.tomorrow), "the day before, the paper warns you")
	t.ok(Market.paper_line(5, 2).contains("2 stalls") and Market.paper_line(5, 0) == String(Market.cfg().paper.none), "on the day it counts the stalls, or says there are none")

func test_a_seller_at_a_stall_pays_more_and_sells_market_lines():
	var s := _state()
	s.time.day = 5; s.time.minute = 10 * 60.0
	var base := Shop.sell_price("fern", "fruit", s)
	var lines_before: int = Shop.stock(s, "fern").size()
	s["market"] = {"day": 5, "at": {"fern": 12}}
	t.eq(Shop.sell_price("fern", "fruit", s), int(ceil(base * float(Market.cfg().buys))), "at her stall Gigia pays half as much again")
	t.ok(Shop.stock(s, "fern").size() > lines_before and Shop.stock(s, "fern").any(func(e): return e.kind == "items" and e.items.has("pumpkin")), "and sells pumpkins at her stall")
	for sid in Market.cfg().sellers:
		for line in Data.shops.shops[sid].stock.filter(func(l): return l.get("market", false) and l.has("items")):
			for k in line.items:
				var back := 0
				for other in Data.shops.shops: back = maxi(back, int(ceil(Shop.sell_price(other, k) * float(Market.cfg().buys))))
				t.ok(back * int(line.items[k]) < int(line.price), "%s's market %s can't be sold back at a profit, even on market day" % [sid, k])
	t.ok(Conversation.build(Data.npc("fern"), QuestEngine.new(s), s.flags, "Tester").options.any(func(o): return String(o.label).contains("Market stall")), "talking to her says it's market prices")
	s.time.minute = 20 * 60.0
	t.eq(Shop.sell_price("fern", "fruit", s), base, "after closing, the usual price")

func test_music_at_the_gathering():
	var music: Dictionary = Data.island_def("hearthglow").get("music", {})
	t.eq(AudioDirector.song_for("evening", false, music, {}, true), "hearthglow_festa", "the gathering has its own tune")
	t.ok(AudioDirector.song_for("evening", false, music, {}, false) != "hearthglow_festa", "otherwise the evening's")
	t.ok(not AudioDirector.song_def("hearthglow_festa", music).is_empty() and String(AudioDirector.song_def("hearthglow_festa", music).lead) == "accordion", "an accordion waltz")
	var lively := {"needs": [{"hangout": "piazza", "met": true}, {"hangout": "piazza", "met": true}], "charm": [{"hangout": "piazza", "points": 4}]}
	t.ok(Visits.gathering(lively, true) and not Visits.gathering(lively, false) and not Visits.gathering({"needs": [], "charm": []}, true), "only at dusk with the piazza fully lively")

func test_the_album_remembers_openings():
	var s := _state()
	s.time.day = 3
	Inauguration.remember(s, {"what": "a bench", "place": "outside the bakery", "grade": "8/10"})
	s.time.day = 4
	Inauguration.remember(s, {"what": "a lamp", "place": "in the piazza", "grade": "7/10"})
	t.ok(s.openings.size() == 2 and int(s.openings[0].day) == 3 and String(s.openings[1].what) == "a lamp", "each opening, with its day")
	var back := SaveSystem.deserialize(SaveSystem.serialize(s))
	t.eq(back.openings.size(), 2, "kept in the save")

func test_tastes_the_market_and_the_paper_belong_to_their_place():
	Data.use_island("river_town")
	var people: Array = Data.npcs_here().map(func(n): return String(n.id))
	t.ok(not Tastes.here().is_empty() and Tastes.here().all(func(id): return people.has(String(id))), "in Boccapioppo only its own villagers' tastes count (%d)" % Tastes.here().size())
	for id in people:
		var tt := Tastes.of(String(id))
		t.ok(not tt.is_empty() and Tastes.near_pos(String(id)) != Vector2.INF, "%s has tastes and a spot" % id)
		for p in tt.get("pieces", []): t.ok(not Data.piece(String(p)).is_empty(), "%s likes a real piece (%s)" % [id, p])
		for c in tt.get("colours", []): t.ok(Data.palette.has(String(c)), "%s likes a colour you can paint (%s)" % [id, c])
		t.ok(String(tt.get("line", "")).contains("{piece}") and String(tt.get("gossip", "")) != "", "%s has a line and a bit of gossip" % id)
	t.ok(not Market.here(), "Monteforchetta's market day doesn't come to Boccapioppo")
	var gossip := Tastes.gossip({"tastes": {"known": {}, "day": {}}}, 0.5)
	t.ok(people.has(String(gossip.get("id", ""))), "the paper gossips about someone who lives here (%s)" % gossip.get("id", ""))
	var paper := Data.paper_here()
	var lines := paper.duplicate(true)
	lines.erase("_doc")
	var all := JSON.stringify(lines)
	t.ok(String(Data.naps_here().get("paper", "")) != "Eco del Colle" and not all.contains("Sindaco") and not all.contains("Eco"), "it has its own paper, with no Sindaco and no Eco anywhere in it")
	t.ok(Inauguration.on() and Inauguration.speaker() == "river_town_ermes", "Ermes opens what you build there")
	t.ok(not JSON.stringify(Inauguration.cfg().open + Inauguration.cfg().close).contains("election"), "in his own words")
	Data.use_island("hearthglow")
	t.ok(Tastes.here().has("fern") and not Tastes.here().has("river_town_rina"), "and back in Monteforchetta, only its villagers")
	t.ok(Market.here() and String(Data.naps_here().get("paper", "")) == "Eco del Colle", "with its market and its Eco del Colle")
