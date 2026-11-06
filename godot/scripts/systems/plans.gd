class_name Plans
## Ghost plans: a build step can carry a `plan` in quests.json, `[[i, k, piece, quarter-turns?, colour?], ...]`: one
## way of building it that works (a test builds every plan piece by piece and checks the step is then done). While
## that step is current its pieces glow on the site as see-through ghosts, in explore mode and in build mode
## (BuildMode.refresh_plan), each disappearing once that piece is built there, and any piece it uses that you haven't
## unlocked yet is unlocked. You're free to build it some other way. A zone's older `blueprint` list (the same
## shape) is still read, shown while its request is active.

## Placements for a plan's entries, each resting where it would if built in that order on top of what's already
## there (`built`): a deck on its post, a roof on its walls, a railing on the deck you laid.
static func lay_out(entries: Array, zone: Dictionary, built_pieces: Array = []) -> Array:
	var out: Array = []
	for n in entries.size():
		var e: Array = entries[n]
		var id := String(e[2])
		var i := float(e[0]); var k := float(e[1]); var r: int = int(e[3]) if e.size() > 3 else 0
		var pl := {"uid": -1 - n, "id": id, "i": i, "k": k, "r": r, "y": BuildGrid.suggest_bottom(id, i, k, r, 10.0, built_pieces + out, zone)}
		if e.size() > 4: pl["color"] = String(e[4])
		out.append(pl)
	return out

## Is this piece of the plan built: the same piece in the same cell (facing the same way, for a wall, a railing or
## a painting)?
static func built(pl: Dictionary, placements: Array) -> bool:
	var d := Data.piece(pl.id)
	var edge: bool = d.get("edge", false) or d.get("attach", "") == "wall"
	return placements.any(func(p): return p.id == pl.id and p.i == pl.i and p.k == pl.k and (not edge or int(p.r) == int(pl.r)))

## The plans to show now: [{quest, objective, zone, pieces}], one for every current, unfinished step with a plan in
## the place you're in.
static func current(engine: QuestEngine) -> Array:
	var out: Array = []
	for q in engine.active():
		if not engine.here(q.id): continue
		for o in q.objectives:
			if not o.has("plan") or not engine.is_current(q.id, o) or engine.objective(q.id, o).done: continue
			var zone := Data.zone(String(o.get("zone", "")))
			out.append({"quest": q.id, "objective": o.id, "zone": zone, "pieces": lay_out(o.plan, zone, engine.state.get("placements", []))})
	return out
