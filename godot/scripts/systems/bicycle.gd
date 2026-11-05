class_name Bicycle
## The bicycle (docs/locations/river_town.md, "The bicycle"): unlocked in Boccapioppo, then yours everywhere outdoors,
## unless a place's map entry says "bikes": false. Owning it and its upgrades are story flags, so any request or a
## location meter's milestone can give them: hasBike, and bikeBell, bikeBasket, bikeLamp, bikeRack, bikePaint. You
## get off by yourself to talk, build, gather or sleep, indoors and on stairs (Game.update_bike). Pure: no nodes.

const SPEED := 12.5   # metres a second: not quite twice running speed
const OWNED := "hasBike"
const UPGRADES := {"bell": "bikeBell", "basket": "bikeBasket", "lamp": "bikeLamp", "rack": "bikeRack", "paint": "bikePaint"}
## Colours for the paint job, in the order repainting goes through them (the first is how it comes).
const COLORS := ["#2f5f9e", "#c0392b", "#3f8f5a", "#f2c53a", "#f4f1ea", "#2a2a2a", "#e8a0b4"]

static func owned(flags: Dictionary) -> bool: return flags.get(OWNED, false)
static func has(flags: Dictionary, upgrade: String) -> bool: return flags.get(UPGRADES.get(upgrade, ""), false)
static func upgrades(flags: Dictionary) -> Array: return UPGRADES.keys().filter(func(u): return has(flags, u))

## Does this place (its map entry) allow bikes?
static func allowed(place: Dictionary) -> bool: return bool(place.get("bikes", true))

## Why you can't get on here, or "" when you can.
static func cant_mount(flags: Dictionary, place: Dictionary, indoors: bool, on_stairs: bool) -> String:
	if not owned(flags): return "You don't have a bike yet."
	if not allowed(place): return "No bikes here: you'll walk."
	if indoors: return "Not indoors! Wheel it outside first."
	if on_stairs: return "Not on the stairs."
	return ""

## The paint job's next colour.
static func next_color(current: String) -> String:
	var i := COLORS.find(current)
	return COLORS[(i + 1) % COLORS.size()]

static func color(state: Dictionary) -> String: return String(state.get("bike_color", COLORS[0]))

## Inside a room you can walk into (its floor to its ceiling)?
static func indoors(p: Vector3) -> bool:
	for b in Data.layout.buildings:
		if not Interiors.enterable(b): continue
		var base := float(b.get("y", maxf(0.0, Heightfield.height(b.x, b.z))))
		var room := Interiors.room(b, base)
		if room.has_point(Vector3(p.x, room.position.y + 1.0, p.z)) and p.y < room.end.y: return true
	return false

## On stairs (a raised floor that climbs, WorldStatics.floors)?
static func on_stairs(p: Vector3) -> bool:
	for s in WorldStatics.floors():
		if s.has("ramp") and s.walkable and p.x >= s.minX and p.x <= s.maxX and p.z >= s.minZ and p.z <= s.maxZ: return true
	return false
