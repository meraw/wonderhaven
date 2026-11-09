extends RefCounted
var t

const PLACES := [
	{"id": "zz_home"},
	{"id": "zz_port", "currency": {"both": "zz_both", "first": "zz_first", "euro": "zz_euro", "here": "both"}},
]

func _with_islands(list: Array, fn: Callable) -> void:
	var saved: Array = Data.islands
	Data.islands = list
	fn.call()
	Data.islands = saved

func _with_flags(flags: Dictionary, fn: Callable) -> void:
	var saved: Callable = Money.flags_source
	Money.flags_source = func() -> Dictionary: return flags
	fn.call()
	Money.flags_source = saved

func test_lire_by_default_exactly_as_before():
	_with_flags({}, func():
		Data.use_island("hearthglow")
		t.eq(Money.lire(15), "15,000 lire", "a sum of money")
		t.eq(Money.lire(120), "120,000 lire", "the bed's price")
		t.eq(Money.lire(0), "0 lire", "nothing")
		t.eq(Money.lire(-3), "-3,000 lire", "a debt")
		t.eq(Money.amount("coins", 15), "%s 15,000 lire" % Data.resources.coins.icon, "money in a list")
		t.eq(Money.short(120), "120,000", "the build catalog's short figure")
		t.eq(BuildMode._cost_text({"wood": 2, "coins": 120}), "%s2 %s120,000" % [Data.resources.wood.icon, Data.resources.coins.icon], "a build cost"))

func test_euros_to_the_cent():
	t.eq(Money.euros(1), "€0.52", "a thousand lire")
	t.eq(Money.euros(25), "€12.91", "the starter kit's twenty-five thousand lire")
	t.eq(Money.euros(120), "€61.97", "a bed")
	t.eq(Money.euros(2000), "€1,032.91", "two million lire, with a thousands comma")
	t.eq(Money.euros(0), "€0.00", "nothing")
	t.eq(Money.euros(-1), "-€0.52", "a debt")

func test_the_four_ways_to_show_a_price():
	t.eq(Money.format(1, "lire"), "1,000 lire", "lire")
	t.eq(Money.format(1, "both"), "1,000 lire (€0.52)", "both, lire first")
	t.eq(Money.format(1, "first"), "€0.52 (1,000 lire)", "both, euros first")
	t.eq(Money.format(1, "euro"), "€0.52", "euros only")

func test_a_place_switches_the_currency_with_its_flags():
	_with_islands(PLACES, func():
		t.eq(Money.mode_for({}, "zz_home"), "lire", "lire everywhere before the switch")
		t.eq(Money.mode_for({}, "zz_port"), "both", "but the place of the switch shows both from the start")
		t.eq(Money.mode_for({"zz_both": true}, "zz_home"), "both", "then both everywhere")
		t.eq(Money.mode_for({"zz_both": true, "zz_first": true}, "zz_home"), "first", "then euros first")
		t.eq(Money.mode_for({"zz_both": true, "zz_first": true, "zz_euro": true}, "zz_home"), "euro", "then euros only, everywhere")
		t.eq(Money.mode_for({"zz_euro": true}, "zz_port"), "euro", "and in the place itself"))

func test_the_game_flags_choose_what_you_see():
	_with_islands(PLACES, func():
		Data.island = "zz_home"
		_with_flags({}, func(): t.eq(Money.lire(120), "120,000 lire", "no flags, lire"))
		_with_flags({"zz_both": true}, func(): t.eq(Money.lire(120), "120,000 lire (€61.97)", "both"))
		_with_flags({"zz_first": true}, func():
			t.eq(Money.lire(120), "€61.97 (120,000 lire)", "euros first")
			t.eq(Money.short(120), "€61.97", "the short figure follows the main one"))
		_with_flags({"zz_euro": true}, func():
			t.eq(Money.amount("coins", 120), "%s €61.97" % Data.resources.coins.icon, "euros only in lists too")
			t.eq(BuildMode._cost_text({"coins": 120}), "%s€61.97" % Data.resources.coins.icon, "and in build costs"))
		Data.island = "zz_port"
		_with_flags({}, func(): t.eq(Money.lire(1), "1,000 lire (€0.52)", "both at the place of the switch")))
	Data.use_island("hearthglow")

func test_no_game_means_no_flags():
	var saved: Callable = Money.flags_source
	Money.flags_source = Callable()
	t.eq(Money.current_flags(), {}, "without a game there are no flags")
	Money.flags_source = saved
