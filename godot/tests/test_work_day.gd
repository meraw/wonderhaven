extends RefCounted
var t

const DAY := {"holdAt": 20.5, "regrow": "overnight"}

func _clock(day: int, hour: float) -> Dictionary:
	return {"day": day, "minute": hour * 60.0, "total": (day - 1) * 1440.0 + hour * 60.0}

func test_monteforchetta_has_a_work_day_and_the_others_keep_their_clock():
	var d := WorkDay.def("hearthglow")
	t.ok(not d.is_empty() and absf(WorkDay.hold_minute(d) - 20.5 * 60.0) < 0.01 and String(d.get("regrow", "")) == "overnight", "Monteforchetta holds at 8:30 PM and regrows overnight: %s" % str(d))
	for id in ["metropolis", "clockwork"]:
		t.ok(not WorkDay.on(id), "%s keeps the clock it had" % id)
	var b := WorkDay.def("river_town")
	t.ok(WorkDay.on("river_town") and not WorkDay.holds(b) and String(b.get("regrow", "")) == "overnight", "Boccapioppo has a work day that regrows overnight but doesn't hold the clock: its storm and its catfish are at night")
	var c := WorkDay.def("rice_village")
	t.ok(WorkDay.on("rice_village") and not WorkDay.holds(c) and String(c.get("regrow", "")) == "overnight", "so has Casalrana: the night express and the nativity are in the evening")

func test_a_day_that_doesnt_hold_runs_on_through_the_night():
	var free := {"holdAt": 20.5, "regrow": "overnight", "hold": false}
	var c := _clock(1, 20.0)
	WorkDay.advance(c, 90.0 / Clock.MINUTES_PER_SECOND, free)
	t.ok(not WorkDay.held(c, free) and float(c.minute) > 21.0 * 60.0, "the clock goes past dusk (%.0f minutes)" % c.minute)
	t.ok(absf(WorkDay.regrow_at(_clock(1, 16.0), free, 180.0) - WorkDay.next_morning(_clock(1, 16.0))) < 0.01, "a tree felled at 4 PM is back the next morning, not at 7 PM")
	var late := _clock(1, 23.0)
	t.ok(WorkDay.ends_day(late, 1, 6.0, free), "sleeping until dawn ends the day")
	t.ok(not WorkDay.ends_day(late, 1, 23.5, free), "a nap until half past eleven doesn't")
	var small_hours := _clock(2, 2.0)
	t.ok(WorkDay.ends_day(small_hours, 1, 6.0, free), "staying up past midnight, then sleeping until dawn, ends the day you started")
	t.ok(not WorkDay.ends_day(late, 1, 6.0, {}), "a place with no work day never ends one")
	var dusk := _clock(1, 15.0)
	WorkDay.to_dusk(dusk, free)
	t.ok(absf(float(dusk.minute) - 20.5 * 60.0) < 0.01, "the evening opening moves the clock on to dusk")
	var night := _clock(1, 23.0)
	WorkDay.to_dusk(night, free)
	t.ok(absf(float(night.minute) - 23.0 * 60.0) < 0.01, "and leaves it alone when dusk has gone")

func test_the_clock_holds_at_dusk_until_you_end_the_day():
	var c := _clock(1, 20.0)
	WorkDay.advance(c, 20.0, DAY)
	t.ok(absf(c.minute - 1220.0) < 0.01, "twenty minutes on from 8 PM is 8:20 PM")
	WorkDay.advance(c, 600.0, DAY)
	t.ok(absf(c.minute - 1230.0) < 0.01 and int(c.day) == 1, "ten more hours later it is still 8:30 PM on day 1")
	t.ok(absf(c.total - 1230.0) < 0.01, "and no time passes for anything that grows (total %.1f)" % c.total)
	t.ok(WorkDay.held(c, DAY), "the day is waiting")
	t.ok(not WorkDay.held(_clock(1, 19.0), DAY), "it isn't at 7 PM")
	var free := _clock(1, 20.0)
	WorkDay.advance(free, 600.0, {})
	t.ok(int(free.day) == 2 and absf(free.minute - 360.0) < 0.01, "without a work day the night comes as before (%s)" % Clock.text(free))
	var late := _clock(1, 23.0)
	WorkDay.advance(late, 60.0, DAY)
	t.ok(absf(late.minute - 1380.0) < 0.01, "arriving after dusk (from a place without one), the clock waits where it is")

func test_sleep_ends_the_day_or_naps_within_it():
	var morning: Array = WorkDay.sleep_options(9.0 * 60.0, DAY).map(func(o): return o.id)
	t.eq(morning, ["wake_12", "wake_15", "wake_20", "wake_tomorrow"], "at 9 AM: a nap until noon, the afternoon or dusk, or sleep until tomorrow")
	var late: Array = WorkDay.sleep_options(14.75 * 60.0, DAY).map(func(o): return o.id)
	t.eq(late, ["wake_20", "wake_tomorrow"], "at 2:45 PM the afternoon is too close to nap until")
	var dusk: Array = WorkDay.sleep_options(20.5 * 60.0, DAY)
	t.ok(dusk.size() == 1 and dusk[0].ends_day and absf(float(dusk[0].hour) - 7.0) < 0.01, "at dusk the only sleep is until tomorrow morning, and it ends the day")
	t.ok(WorkDay.sleep_options(9.0 * 60.0, DAY).filter(func(o): return o.ends_day).size() == 1, "only one option ends the day")
	t.eq(Clock.hour_num(20.5), "8:30 PM", "dusk reads 8:30 PM")
	t.eq(Clock.hour_num(7.0), "7 AM", "whole hours stay short")

func test_spots_grow_back_overnight_in_a_work_day():
	var c := _clock(3, 10.0)
	t.ok(absf(WorkDay.next_morning(c) - (3 * 1440.0 + 7 * 60.0)) < 0.01, "from 10 AM, the next morning is 7 AM tomorrow")
	t.ok(absf(WorkDay.next_morning(_clock(3, 5.0)) - (2 * 1440.0 + 7 * 60.0)) < 0.01, "from 5 AM it is 7 AM today")
	t.ok(absf(WorkDay.regrow_at(c, DAY, 180.0) - WorkDay.next_morning(c)) < 0.01, "a tree cut in a work day is back the next morning, not in three hours")
	t.ok(absf(WorkDay.regrow_at(c, {}, 180.0) - (c.total + 180.0)) < 0.01, "elsewhere it is back in three hours as before")
	var slept := c.duplicate()
	Clock.sleep_until(slept, 7.0)
	t.ok(slept.total >= WorkDay.regrow_at(c, DAY, 180.0) - 0.01, "and a night's sleep brings it back")
	var napped := c.duplicate()
	Clock.sleep_until(napped, 20.5)
	t.ok(napped.total < WorkDay.regrow_at(c, DAY, 180.0), "a nap until dusk doesn't")

func test_a_night_on_a_bench_always_ends_with_a_joke():
	var naps: Dictionary = Data.naps.duplicate(true)
	t.ok(float(naps.get("overnight", 0.0)) >= 1.0, "naps.json: a night on a bench always ends with something")
	var quiet := 0
	for i in 40:
		if BenchNap.pick(naps, {"overnight": true, "watchers": ["Gigia"], "last": ""}, float(i) / 40.0, 0.5) == "": quiet += 1
	t.eq(quiet, 0, "every overnight roll gives a gag")
	t.eq(BenchNap.pick(naps, {"overnight": false, "watchers": []}, 0.9, 0.5), "", "a daytime nap is still mostly quiet")
	t.eq(BenchNap.pick(naps, {"overnight": true, "indoors": true}, 0.0, 0.5), "", "your own sofa indoors stays quiet")

func test_the_castle_bed_sends_you_to_the_benches():
	var bed := {}
	for f in Data.read_layout("hearthglow").features:
		if f.id == "bed": bed = f
	t.ok(bed.get("kind", "") == "rest" and String(bed.get("refuse", "")).contains("bench"), "the Sindaco's camp bed has a note pointing to the benches: %s" % bed.get("refuse", ""))
	var benches: Array = Data.read_layout("hearthglow").features.filter(func(f): return f.kind == "bench")
	t.ok(benches.size() >= 4, "and there are %d public benches" % benches.size())

func test_monteforchetta_requests_keep_no_hours():
	var timed: Array = Data.quests.filter(func(q): return Data.quest_island(q.id) == "hearthglow" and (q.has("hours") or q.objectives.any(func(o): return o.has("hours")))).map(func(q): return q.id)
	t.eq(timed, [], "nothing important in Monteforchetta depends on the hour")

func test_the_day_record_counts_what_happened():
	var s := GameState.new_game("Tester")
	s.harmony = 12; s.inventory["coins"] = 40
	WorkDay.note(s, "built"); WorkDay.note(s, "built"); WorkDay.note(s, "gathered")
	WorkDay.note(s, "quests", "bridge")
	var r := WorkDay.record(s)
	t.ok(int(r.built) == 2 and int(r.gathered) == 1 and r.quests == ["bridge"] and int(r.harmony) == 12 and int(r.day) == 1, str(r))
	var back := SaveSystem.deserialize(SaveSystem.serialize(s))
	t.eq(WorkDay.record(back).get("built", 0), 2, "the day so far is saved")

func test_the_morning_paper_reports_yesterday():
	var data: Dictionary = Data.paper
	var quests: Array = [{"id": "bridge", "title": "The Washed-Out Road", "main": true}, {"id": "catch", "title": "Aldo's Porcini Bet"}]
	var done := MorningPaper.compose({"quests": ["catch", "bridge"], "built": 9, "gathered": 3, "harmony": 10}, {"paper": "Eco del Colle", "day": 2, "harmony": 52, "lead": "Elio", "weather": "rain"}, data, quests, 0.0)
	t.eq(done.title, "Eco del Colle · Day 2", "the paper's name and the day")
	t.ok(String(done.headline).contains("The Washed-Out Road"), "a finished story request makes the headline: %s" % done.headline)
	t.ok(done.notes.size() == 3 and String(done.notes[0]).contains("52") and String(done.notes[0]).contains("+42") and String(done.notes[1]).contains("Elio"), "then the approval rating, who is asking for you, and one more: %s" % str(done.notes))
	var built := MorningPaper.compose({"quests": [], "built": 4, "harmony": 5}, {"day": 3, "harmony": 5}, data, quests, 0.5)
	t.ok(String(built.headline).contains("4"), "pieces built make the headline when nothing was finished: %s" % built.headline)
	var quiet := MorningPaper.compose({"quests": [], "built": 0, "harmony": 5}, {"day": 4, "harmony": 5, "draft": "3 wood"}, data, quests, 0.9)
	t.ok(data.quiet.has(quiet.headline) and quiet.notes.size() == 1 and String(quiet.notes[0]).contains("3 wood"), "a quiet day gets a quiet headline, and the draft's shopping list: %s %s" % [quiet.headline, str(quiet.notes)])
	var own := MorningPaper.compose({"quests": ["bridge"]}, {"day": 2}, data, [{"id": "bridge", "title": "X", "headline": "Bridge opens"}], 0.0)
	t.eq(own.headline, "Bridge opens", "a request can have its own headline")

func test_a_tip_card_explains_dusk():
	t.ok(Data.tutorial.tips.has("dusk"), "a tip card explains dusk")
