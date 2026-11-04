class_name Money
## Money is kept as whole coins in saves, data and rules, and shown as lire for the late-1990s setting: one coin is
## 1,000 lire, so a coffee costs about one coin. The euro switch later only needs to change how it is shown.
const LIRE_PER_COIN := 1000

## "15,000"
static func group(n: int) -> String:
	var s := str(absi(n)); var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

## A sum of money: "15,000 lire".
static func lire(coins: int) -> String: return "%s lire" % group(coins * LIRE_PER_COIN)

## An amount of anything for lists and toasts: "3 🪵 Wood", or "💰 15,000 lire" for money.
static func amount(id: String, n: int) -> String:
	if id == "coins": return "%s %s" % [Data.resources.coins.icon, lire(n)]
	var r: Dictionary = Data.resources.get(id, {"icon": "", "name": id})
	return "%d %s %s" % [n, r.icon, r.name]
