class_name Progress
## A save as if the player had already played some places, for starting a later place's playthrough (or screenshots)
## where a real player would be instead of on a blank new game. Each listed place's main requests are done, with
## everything they handed out applied: approval and its milestones, lire and items, plans, clothes, flags, the
## location meter, and the givers' friendship. The guided first day is behind you, and you stand where travellers
## arrive in `here`.
##
## Main requests only, so the stats are what any player arriving there has, not a completionist's. What you paid for
## on the way (the farmhouse deed) is left out along with what you sold to afford it. What you built in those places
## isn't kept: this is for playing the next place, not for going back. Pure: no nodes.
##   Progress.as_if_played(["hearthglow"], "river_town")   # Boccapioppo, reached by Monteforchetta's bus line

static func as_if_played(places: Array, here: String, player_name: String = "Pip") -> Dictionary:
	var s := GameState.new_game(player_name)
	s.tutorial = Tutorial.new_state(false, true)
	for q in Data.quests:
		if q.get("main", false) and places.has(Data.quest_island(q.id)): _finish(s, q)
	for u in Data.harmony_unlocks:   # the approval milestones reached on the way
		if float(u.at) > float(s.harmony): continue
		_grant(s, u)
		if u.get("allBlueprints", false):
			for p in Data.pieces: _plan(s, p.id)
		s.unlocks_seen.append(u.get("id", ""))
	s.island = here
	var L: Dictionary = Data.read_layout(here)
	var at: Dictionary = L.get("arrive", L.get("spawn", {"x": 0.0, "z": 0.0}))
	s.player = {"x": float(at.x), "z": float(at.z), "yaw": float(at.get("yaw", 0.0))}
	return s

## One request done, as if it had been played: accepted (its gifts and plans), every step's own rewards, then its rewards.
static func _finish(s: Dictionary, q: Dictionary) -> void:
	s.quests[q.id] = {"status": "done", "progress": {}, "done": {}}
	var acc: Dictionary = q.get("onAccept", {})
	for f in acc.get("flags", []): s.flags[f] = true
	for b in acc.get("blueprints", []): _plan(s, b)
	for o in q.get("objectives", []):
		var od: Dictionary = o.get("onDone", {})
		for f in od.get("flags", []): s.flags[f] = true
		for b in od.get("blueprints", []): _plan(s, b)
	var rw: Dictionary = q.get("rewards", {})
	for k in rw.get("items", {}): s.inventory[k] = int(s.inventory.get(k, 0)) + int(rw.items[k])
	_grant(s, rw)
	s.harmony = int(s.harmony) + int(rw.get("harmony", 0))
	if int(rw.get("meter", 0)) > 0:
		for u in LocationMeter.add(s, Data.quest_island(q.id), int(rw.meter)): _grant(s, u)
	var giver := String(q.get("giver", ""))
	if giver != "":
		if not s.relationships.has(giver): s.relationships[giver] = {"hearts": 0, "talked_day": 0, "gifts": []}
		s.relationships[giver].hearts = mini(10, int(s.relationships[giver].hearts) + 2)

static func _grant(s: Dictionary, r: Dictionary) -> void:
	for b in r.get("blueprints", []): _plan(s, b)
	for c in r.get("clothes", []):
		if not s.clothes_owned.has(c): s.clothes_owned.append(c)
	for f in r.get("flags", []): s.flags[f] = true

static func _plan(s: Dictionary, id: String) -> void:
	if not s.blueprints.has(id): s.blueprints.append(id)
