class_name Seats

const REACH := 8.0
const HALF := 0.5
const SEAT_LIFT := 0.28
const APPROACH := 0.85
const TAKEN_R := 0.4
const TAKEN_DY := 0.8
const PROMPT_PRIORITY := 0.9

static func is_seat(piece_id: String) -> bool:
	return String(Data.piece(piece_id).get("interact", "")) == "sit"

static func key_of(seat: Dictionary) -> String:
	if seat.has("uid"): return "pl:%d" % int(seat.uid)
	return "at:%.2f,%.2f,%d" % [float(seat.i), float(seat.k), int(seat.get("r", 0))]

static func feature_seat(f: Dictionary, y: float) -> Dictionary:
	var r := int(f.get("r", 0))
	var fp := BuildGrid.footprint(Data.piece("bench"), r)
	return {"id": "bench", "i": float(f.x) - fp.x / 2.0, "k": float(f.z) - fp.y / 2.0, "r": r, "y": y}

static func spots(seat: Dictionary) -> Array:
	var b := BuildGrid.bounds(seat)
	var c := Vector2((float(b.minX) + float(b.maxX)) / 2.0, (float(b.minZ) + float(b.maxZ)) / 2.0)
	var w: float = b.maxX - b.minX
	var d: float = b.maxZ - b.minZ
	var yaw := -int(seat.get("r", 0)) * PI / 2.0
	var fwd := Vector2(sin(yaw), cos(yaw))
	var y := float(seat.get("y", 0.0)) + SEAT_LIFT
	var offs: Array = [Vector2.ZERO]
	if w > d + 0.5: offs = [Vector2(-HALF, 0.0), Vector2(HALF, 0.0)]
	elif d > w + 0.5: offs = [Vector2(0.0, -HALF), Vector2(0.0, HALF)]
	var out: Array = []
	for o in offs:
		var at: Vector2 = c + o
		var ap: Vector2 = at + fwd * APPROACH
		out.append({"at": Vector3(at.x, y, at.y), "yaw": yaw, "approach": ap})
	return out

static func entries(placements: Array, seats_from_layout: Array) -> Array:
	var out: Array = []
	for pl in placements:
		if not is_seat(String(pl.id)): continue
		out.append({"key": key_of(pl), "seat": pl, "spots": spots(pl)})
	for s in seats_from_layout:
		out.append({"key": key_of(s), "seat": s, "spots": spots(s)})
	return out

static func taken(at: Vector3, sitters: Array) -> bool:
	for p in sitters:
		var q: Vector3 = p
		if Vector2(q.x - at.x, q.z - at.z).length() < TAKEN_R and absf(q.y - at.y) < TAKEN_DY: return true
	return false

static func free_spot(spot_list: Array, sitters: Array, near: Vector2 = Vector2.INF) -> int:
	var best := -1
	var bd := INF
	for i in spot_list.size():
		var at: Vector3 = spot_list[i].at
		if taken(at, sitters): continue
		if near == Vector2.INF:
			best = i
			continue
		var dd := Vector2(at.x, at.z).distance_to(near)
		if dd < bd: bd = dd; best = i
	return best

static func claim(all: Array, near: Vector2, sitters: Array, reach: float = REACH, y: float = INF) -> Dictionary:
	var best := {}
	var bd := reach
	for e in all:
		var spot_list: Array = e.spots
		if spot_list.is_empty(): continue
		var first: Vector3 = spot_list[0].at
		if y != INF and absf(first.y - SEAT_LIFT - y) > 1.2: continue
		var i := free_spot(spot_list, sitters)
		if i < 0: continue
		var at: Vector3 = spot_list[i].at
		var dd := Vector2(at.x, at.z).distance_to(near)
		if dd <= bd:
			bd = dd
			best = (spot_list[i] as Dictionary).duplicate()
			best["key"] = String(e.key)
			best["index"] = i
	return best

static func beside(spot_list: Array, at: Vector3) -> bool:
	for s in spot_list:
		var q: Vector3 = s.at
		if Vector2(q.x - at.x, q.z - at.z).length() < TAKEN_R and absf(q.y - at.y) < TAKEN_DY: return true
	return false
