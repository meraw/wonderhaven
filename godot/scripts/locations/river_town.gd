extends RefCounted
## Boccapioppo (working id `river_town`): a brick town where a clear Alpine river meets the Po, just after a flood.
## See docs/locations/river_town.md. North is -z.
##
## The town sits on the west bank, behind a levee that runs along the Po (west to east at z = 22, with the breach in
## it) and turns north along the Alpine river (x = 18), fading into the old high ground near the station. Outside
## the levee lies the floodplain: grey mud, the backwater with the stranded houseboat, the sandbank. The Alpine river
## comes down from the north edge, the Roman bridge crosses it there, and the wild east bank (poplars, the sawmill,
## gravel bars) lies beyond. Irrigation canals along the north, west and east edges and the Po along the south keep
## you on the map. Everything here is static: the shared Heightfield calls height() and is_stream_cell().

const TOWN_H := 0.55       # the town and the fields: the old high ground
const FLOOD_H := 0.18      # the floodplain outside the levee
const EAST_H := 0.34       # the east bank
const PIAZZA_H := 0.28     # the piazza, the lowest part of town
const LEVEE_H := 2.8       # the levee crest
const CREST := 1.6         # half the crest's width
const SLOPE := 3.8         # how far each side of the levee runs out
const LEVEE_Z := 22.0      # the Po levee runs along this line
const LEVEE_X := 18.0      # the Alpine levee runs along this line
const LEVEE_WEST := -51.0  # where the levee road ends, at the bus stop
const LEVEE_NORTH := -34.0 # where the Alpine levee fades into the high ground
const BREACH := Vector2(2.5, 7.5)        # x range of the breach in the Po levee
const BUS_SHELF := Rect2(-51.0, 19.0, 9.0, 6.0)     # the bus turnaround at the west end of the levee
const PIAZZA := Vector3(5.0, 0.0, 4.0)   # centre x, -, z
const PIAZZA_R := 7.0
const SUMP := Vector2(11.8, 5.0)         # the piazza's old drain sump
const SUMP_R := 1.0
const DANCE := Rect2(11.2, 28.2, 9.6, 6.6)          # the dance hall's raised floor (x, z, width, depth)
const DANCE_VERANDA := Rect2(9.6, 29.6, 1.6, 3.8)   # its veranda, on the west side by the door
const DANCE_H := 0.9
const ALPINE_X := 30.0     # the Alpine river's mean centre line
const ALPINE_HALF := 4.5   # half its width of water
const ROMAN_Z := -44.0     # the Roman bridge's centre line
const ROMAN_HALF := 1.3    # half the bridge's walkway
const ROMAN_PEAK := 1.9    # the walkway's height at mid-river
const BACKWATER := Vector3(-24.0, 0.0, 35.0)   # the still backwater on the floodplain
const BACKWATER_HALF := Vector2(8.0, 2.0)
const SANDBANK := Vector3(6.0, 0.0, 40.5)
const SANDBANK_HALF := Vector2(6.5, 2.2)
const CANAL_N := -53.5     # centre lines of the edge canals
const CANAL_W := -55.5
const CANAL_E := 55.5
const CANAL_HALF := 2.0
const RAIL_X := -17.0      # the valley railway's embankment runs north from the station
const RAIL_SOUTH := -38.0
const PUMPHOUSE := Vector2(21.5, 5.0)   # the old drainage pumping house, dug into the levee's river side
const QUAY := Rect2(22.5, 1.5, 4.5, 7.0)   # its stone quay: level ground to a sheer edge on the Alpine river
const LANDING := Rect2(23.0, 11.0, 4.0, 5.0)   # the old ferry landing: the bank eases down to the water there

static func ss(a: float, b: float, v: float) -> float:
	var t := clampf((v - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

## Where the Alpine river's centre is at a given z.
static func alpine_center(z: float) -> float:
	return ALPINE_X + 1.6 * sin(z * 0.045 + 0.8)

## Where the Po's north bank is at a given x (water lies south of it).
static func po_bank(x: float) -> float:
	return 38.5 + 1.8 * sin(x * 0.06 + 0.3) + 0.8 * cos(x * 0.13)

## A gravel bar narrows the river on its east side between z = -20 and -4.
static func _east_bar(z: float) -> float:
	return 1.8 * ss(-21.0, -16.0, z) * (1.0 - ss(-8.0, -3.0, z))

static func _box_dist(x: float, z: float, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - x, x - r.end.x), 0.0)
	var dz := maxf(maxf(r.position.y - z, z - r.end.y), 0.0)
	return sqrt(dx * dx + dz * dz)

## Distance from the levee crest's centre region (0 on the crest), or a large number away from it.
static func _levee_dist(x: float, z: float) -> float:
	var d := INF
	# the Po stretch, west end at the bus stop, east end at the corner
	if x >= LEVEE_WEST - 6.0 and x <= LEVEE_X + 6.0:
		var cx := clampf(x, LEVEE_WEST, LEVEE_X)
		d = minf(d, maxf(0.0, Vector2(x - cx, z - LEVEE_Z).length() - CREST))
	# the Alpine stretch, from the corner north
	if z <= LEVEE_Z + 6.0 and z >= LEVEE_NORTH - 12.0:
		var cz := clampf(z, LEVEE_NORTH, LEVEE_Z)
		d = minf(d, maxf(0.0, Vector2(x - LEVEE_X, z - cz).length() - CREST))
	d = minf(d, _box_dist(x, z, BUS_SHELF))
	return d

## How tall the levee is here, 0..1 (it fades out at its north end, and the breach is a gap in it).
static func _levee_strength(x: float, z: float) -> float:
	var s := 1.0
	if z < LEVEE_NORTH + 2.0 and absf(x - LEVEE_X) < 8.0: s = ss(LEVEE_NORTH - 8.0, LEVEE_NORTH + 2.0, z)
	if absf(z - LEVEE_Z) < CREST + SLOPE + 1.0:
		s *= 1.0 - (ss(BREACH.x - 1.2, BREACH.x + 0.4, x) * (1.0 - ss(BREACH.y - 0.4, BREACH.y + 1.2, x)))
	return s

## The ground before rivers and canals: town, floodplain or east bank, with the levee on top.
static func _land(x: float, z: float) -> float:
	var ac := alpine_center(z)
	var h: float
	if x > ac:
		h = EAST_H + 0.05 * sin(x * 0.21 + 0.4) * cos(z * 0.17)
	else:
		# outside the levee: south of the Po stretch, or between the Alpine stretch and the river (until the levee
		# fades into the high ground in the north)
		var south := ss(LEVEE_Z - 1.0, LEVEE_Z + 1.5, z) * ss(LEVEE_WEST - 3.0, LEVEE_WEST, x)
		var strip := ss(LEVEE_X - 1.0, LEVEE_X + 1.5, x) * ss(LEVEE_NORTH - 10.0, LEVEE_NORTH, z)
		var flood := maxf(south, strip)
		var town := TOWN_H + 0.06 * sin(x * 0.15 + 1.0) * cos(z * 0.12 - 0.5)
		var mud := FLOOD_H + 0.05 * sin(x * 0.33 + 2.0) * sin(z * 0.27)
		h = lerpf(town, mud, flood)
		# the piazza sits low; the sump at its edge holds water
		var dp := Vector2(x - PIAZZA.x, z - PIAZZA.z).length()
		h = lerpf(h, PIAZZA_H, 1.0 - ss(PIAZZA_R - 1.0, PIAZZA_R + 1.5, dp))
		var dsu := Vector2(x - SUMP.x, z - SUMP.y).length()
		if dsu < SUMP_R + 0.3: h = minf(h, -0.75 if dsu < SUMP_R else lerpf(-0.75, h, (dsu - SUMP_R) / 0.3))
		# the dance hall stands on stilts: its floor and veranda are a raised platform (hidden behind a lattice skirt
		# in the model), with a ramp down to the floodplain on the west
		var dd := minf(_box_dist(x, z, DANCE), _box_dist(x, z, DANCE_VERANDA))
		if dd < 0.35: h = maxf(h, lerpf(DANCE_H, h, dd / 0.35))
		if z > 30.6 and z < 32.4 and x > 7.4 and x <= DANCE_VERANDA.position.x:
			h = maxf(h, lerpf(h, DANCE_H, (x - 7.4) / (DANCE_VERANDA.position.x - 7.4)))
		# the valley railway's embankment, from the station north
		if z < RAIL_SOUTH + 2.0 and absf(x - RAIL_X) < 4.5:
			var rail := TOWN_H + 0.5 * (1.0 - ss(1.6, 3.6, absf(x - RAIL_X))) * ss(RAIL_SOUTH + 2.0, RAIL_SOUTH - 1.0, z)
			h = maxf(h, rail)
	var ld := _levee_dist(x, z)
	if ld < SLOPE:
		var top := lerpf(h, LEVEE_H, _levee_strength(x, z))
		h = maxf(h, lerpf(top, h, ss(0.0, SLOPE, ld)))
	return h

## The quay by the pumping house: level with the floodplain right to its stone edge, where the river runs deep and
## fast (a waterwheel there turns, and a shaft on the quay takes its turning to the pump's drive).
static func _quay(x: float, z: float) -> bool:
	return x >= QUAY.position.x and x < QUAY.end.x and z >= QUAY.position.y and z < QUAY.end.y

static func height(x: float, z: float) -> float:
	var h := _land(x, z)
	# the Alpine river: clear, fast and shallow, with a gravel bar on its east side
	var ac := alpine_center(z)
	var dx := x - ac
	var half := ALPINE_HALF - (_east_bar(z) if dx > 0.0 else 0.0)
	var da := absf(dx)
	if da < half + 1.5:
		var bed := lerpf(-1.05, -0.55, ss(half - 2.5, half, da))
		var rh := bed if da < half else lerpf(-0.5, h, ss(half, half + 1.5, da))
		h = minf(h, rh)
	if _quay(x, z): h = maxf(h, FLOOD_H)
	# the ferry landing: a gentle slope from the floodplain to the water's edge, where the pontoon bridge starts
	if x >= LANDING.position.x and x < LANDING.end.x and z >= LANDING.position.y and z < LANDING.end.y:
		h = maxf(h, lerpf(FLOOD_H, -0.22, (x - LANDING.position.x) / LANDING.size.x))
	if dx > 0.0 and _east_bar(z) > 0.05 and da < ALPINE_HALF + 0.2 and da >= half - 0.6:
		h = maxf(h, -0.16 + 0.04 * sin(z * 1.3))   # pale gravel, just above the water
	# the Roman bridge: a narrow hump-backed walkway over the river (its stone model sits on top)
	if absf(z - ROMAN_Z) < ROMAN_HALF and absf(dx) < 8.0:
		var u := dx / 8.0
		h = maxf(h, lerpf(_land(x, z), ROMAN_PEAK, cos(u * PI * 0.5)))
	# the Po: wide and slow along the south, with the sandbank reaching out into it
	var pb := po_bank(x)
	if z > pb - 2.0:
		var ph := lerpf(-0.55, -1.7, ss(pb, pb + 7.0, z)) if z > pb else lerpf(h, -0.5, ss(pb - 2.0, pb, z))
		h = minf(h, ph)
	var sb := Vector2((x - SANDBANK.x) / SANDBANK_HALF.x, (z - SANDBANK.z) / SANDBANK_HALF.y).length()
	if sb < 1.4: h = maxf(h, lerpf(-0.14, -0.9, ss(0.85, 1.4, sb)))
	# the backwater, and its outlet to the Po
	var bw := Vector2((x - BACKWATER.x) / BACKWATER_HALF.x, (z - BACKWATER.z) / BACKWATER_HALF.y).length()
	if bw < 1.5: h = minf(h, lerpf(-0.95, h, ss(0.8, 1.5, bw)))
	var out_d := _seg_dist(x, z, -31.0, 35.5, -35.0, 41.0)
	if out_d < 2.6: h = minf(h, lerpf(-0.95, h, ss(1.2, 2.6, out_d)))
	# irrigation canals along the north, west and east edges
	var dc := minf(absf(z - CANAL_N), minf(absf(x - CANAL_W), absf(x - CANAL_E)))
	if (absf(z - CANAL_N) < CANAL_HALF + 1.2 and x > CANAL_W - 2.0 and x < CANAL_E + 2.0) \
			or (absf(x - CANAL_W) < CANAL_HALF + 1.2 and z > CANAL_N - 2.0) \
			or (absf(x - CANAL_E) < CANAL_HALF + 1.2 and z > CANAL_N - 2.0):
		h = minf(h, lerpf(-1.0, h, ss(CANAL_HALF - 0.4, CANAL_HALF + 1.2, dc)))
	return h

static func _seg_dist(px: float, pz: float, ax: float, az: float, bx: float, bz: float) -> float:
	var v := Vector2(bx - ax, bz - az)
	var t := clampf(Vector2(px - ax, pz - az).dot(v) / v.length_squared(), 0.0, 1.0)
	return Vector2(px - (ax + t * v.x), pz - (az + t * v.y)).length()

## Build-grid cells with flowing water: the Alpine river, where a waterwheel turns. The Po is too slow and too deep
## by the bank, and the backwater, the canals and the sump are still.
static func is_stream_cell(i: float, k: float) -> bool:
	var x := i + 0.5
	var z := k + 0.5
	if z < CANAL_N + CANAL_HALF + 1.0 or z > po_bank(x) - 1.0: return false
	var dx := x - alpine_center(z)
	var half := ALPINE_HALF - (_east_bar(z) if dx > 0.0 else 0.0)
	if absf(z - ROMAN_Z) < ROMAN_HALF + 0.5: return false
	return absf(dx) < half - 0.3

# ---- The story's changes to the place -----------------------------------------------------------------------------
## Flags that reshape Boccapioppo (Data.apply_world_flags): when one is set, the world is built again where you
## stand. The scenery and models read Data.world_flags; adjust() moves the houseboat.
const WORLD_FLAGS := ["river_town_piazza_drained", "river_town_hall_open", "river_town_storm", "river_town_flood_over",
	"river_town_launched", "river_town_monster_seen"]
const MOORING := Vector2(-24.0, 36.0)   # where the Speranza floats once she's launched
const DECK_Y := 0.18                     # her deck, and the jetty at her door

static func adjust(layout: Dictionary, flags: Dictionary) -> void:
	if flags.get("river_town_launched", false): _launch(layout)

## The Speranza afloat: from the mud to her mooring in the backwater, standing on her own deck, with a jetty at her
## door and a gangway to the bank. The flood's junk is gone from her cabin: her bed and wardrobe wait for you to
## furnish the rest (interior "launched_items").
static func _launch(layout: Dictionary) -> void:
	for b in layout.buildings:
		if b.id != "river_town_houseboat": continue
		var d := MOORING - Vector2(b.x, b.z)
		b.x = MOORING.x; b.z = MOORING.y; b["y"] = DECK_Y; b["afloat"] = true
		b.interior["items"] = b.interior.get("launched_items", [])
		for f in layout.features:
			if f.id in ["river_town_bed", "river_town_wardrobe"]: f.x += d.x; f.z += d.y
		var door_x: float = b.x + b.w / 2.0
		layout.nav_nodes["houseboat"] = [door_x + 0.9, b.z]
		layout.nav_nodes["jettyFoot"] = [door_x + 1.3, 32.0]
		var edges: Array = layout.nav_edges.filter(func(e): return not ("houseboat" in [e[0], e[1]]))
		edges.append(["floodRamp", "jettyFoot"]); edges.append(["jettyFoot", "houseboat"])
		layout.nav_edges = edges
		var floors: Array = layout.get("floors", [])
		floors.append({"id": "river_town_deck", "rect": [b.x - b.w / 2.0 - 0.25, b.z - b.d / 2.0 - 0.2, door_x + 0.25, b.z + b.d / 2.0 + 0.2], "top": DECK_Y, "bottom": -1.0})
		floors.append({"id": "river_town_jetty", "rect": [door_x - 0.05, b.z - 1.4, door_x + 1.85, b.z + 1.4], "top": DECK_Y, "bottom": -1.0})
		floors.append({"id": "river_town_gangway", "rect": [door_x + 0.75, 32.2, door_x + 1.85, b.z - 1.4], "top": DECK_Y, "bottom": -1.0})
		layout["floors"] = floors

# ---- Buildings and scenery ---------------------------------------------------------------------------------------
# The models live in river_town/models.gd and the scenery in river_town/scenery.gd.
const P := preload("res://scripts/world/palette.gd")
const Models := preload("res://scripts/locations/river_town/models.gd")
const Scenery := preload("res://scripts/locations/river_town/scenery.gd")

## The model for one of the layout's buildings (null for a kind this location doesn't draw itself).
static func building(b: Dictionary) -> Node3D:
	return Models.build(b)

## Extra scenery: the far land beyond the map's edge (so the plain doesn't end in sea), then trees, landmarks, the
## flood's leftovers and the horizon (Scenery).
static func dress(village: Node3D) -> void:
	var mat: Material = village.terrain.material_override
	var far := 240.0
	var e := 62.0
	# west and east of the map, down to the Po; north of it, either side of the Alpine river; the Po's far bank
	_skirt(village, Rect2(-far, -far, far - e, far + 37.5), TOWN_H - 0.03, mat)
	_skirt(village, Rect2(e, -far, far - e, far + 37.5), EAST_H - 0.03, mat)
	_skirt(village, Rect2(-e, -far, e + alpine_center(-e) - ALPINE_HALF, far - e), TOWN_H - 0.03, mat)
	var rx := alpine_center(-e) + ALPINE_HALF
	_skirt(village, Rect2(rx, -far, e - rx, far - e), EAST_H - 0.03, mat)
	_skirt(village, Rect2(-far, 92.0, far * 2.0, far - 92.0), 0.45, mat)
	Scenery.dress(village, load("res://scripts/locations/river_town.gd"))

## A flat stretch of far land, painted like the map's grass, at height y.
static func _skirt(village: Node3D, r: Rect2, y: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 8.0
	var nx := maxi(1, int(ceil(r.size.x / step))); var nz := maxi(1, int(ceil(r.size.y / step)))
	var grass := Color("8fd16a"); var grass2 := Color("76c25a")
	for j in nz + 1:
		for i in nx + 1:
			var x := r.position.x + r.size.x * i / nx
			var z := r.position.y + r.size.y * j / nz
			st.set_color(grass.lerp(grass2, 0.5 + 0.5 * sin(x * 0.05) * cos(z * 0.04)))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(x, y, z))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			st.add_index(a); st.add_index(a + 1); st.add_index(a + nx + 1)
			st.add_index(a + 1); st.add_index(a + nx + 2); st.add_index(a + nx + 1)
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.name = "FarLand"
	village.add_child(m)
