class_name Money
## Money is kept as whole coins in saves, data and rules, and shown as lire for the late-1990s setting: one coin is
## 1,000 lire, so a coffee costs about one coin. The euro switch later only needs to change how it is shown.
const LIRE_PER_COIN := 1000
const LIRE_PER_EURO := 1936.27
const MODES := ["lire", "both", "first", "euro"]

static var flags_source: Callable = Callable()

## "15,000"
static func group(n: int) -> String:
	var s := str(absi(n)); var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

## A sum of money: "15,000 lire".
static func lire(coins: int) -> String: return format(coins, mode())

static func lire_text(coins: int) -> String: return "%s lire" % group(coins * LIRE_PER_COIN)

static func euros(coins: int) -> String:
	var cents := int(round(float(coins) * LIRE_PER_COIN * 100.0 / LIRE_PER_EURO))
	var neg := "-" if cents < 0 else ""
	cents = absi(cents)
	return "%s€%s.%02d" % [neg, group(cents / 100), cents % 100]

static func format(coins: int, how: String) -> String:
	match how:
		"both": return "%s (%s)" % [lire_text(coins), euros(coins)]
		"first": return "%s (%s)" % [euros(coins), lire_text(coins)]
		"euro": return euros(coins)
	return lire_text(coins)

static func short(coins: int) -> String:
	return euros(coins) if mode() in ["first", "euro"] else group(coins * LIRE_PER_COIN)

static func current_flags() -> Dictionary:
	if flags_source.is_valid(): return flags_source.call()
	return {}

static func mode() -> String: return mode_for(current_flags(), Data.island)

static func mode_for(flags: Dictionary, island: String) -> String:
	var level := 0
	var here := ""
	for isl in Data.islands:
		var c: Dictionary = isl.get("currency", {})
		if c.is_empty(): continue
		if flags.get(String(c.get("euro", "")), false): level = maxi(level, 3)
		elif flags.get(String(c.get("first", "")), false): level = maxi(level, 2)
		elif flags.get(String(c.get("both", "")), false): level = maxi(level, 1)
		if String(isl.get("id", "")) == island: here = String(c.get("here", ""))
	if level == 0 and here == "both": level = 1
	return MODES[level]

## An amount of anything for lists and toasts: "3 🪵 Wood", or "💰 15,000 lire" for money.
static func amount(id: String, n: int) -> String:
	if id == "coins": return "%s %s" % [Data.resources.coins.icon, lire(n)]
	var r: Dictionary = Data.resources.get(id, {"icon": "", "name": id})
	return "%d %s %s" % [n, r.icon, r.name]
