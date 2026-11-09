# Serenza: design for the cliff village

Working id `cliffs`. Agreed with the user on 2026-11-08 in a design interview. **All four stages are built: ground and map,
buildings and scenery, people, dialogue and requests, look and ambient life.** See "Status" at the end. This doc is
the plan the build stages follow. The rules every location shares are in `docs/WORLD.md`; `docs/MONTEFORCHETTA.md`
and the other location docs are the models it follows. Tonnarella (`docs/locations/port.md`) comes just before
Serenza, and the two were kept apart where they overlapped (see "Agreements needed with other sessions").

## The concept
Serenza is a fishing and wine village wedged into a steep ravine on the Ligurian coast, in the weeks before Easter in
the spring after the euro came in. Tall pastel houses are stacked up both sides of the ravine down to a tiny harbour,
the boats spend the winter pulled up in the main street, the coastal railway bursts out of one cliff, stops at a
station the width of a platform and dives into the next, and above the village the terraced vineyards climb in narrow
steps to a sanctuary among the pines.

Nobody wrecked Serenza. It is simply falling down, one dry-stone wall at a time. The young people left for the cities,
the old growers can no longer carry the grapes up and down, and half the terraces have gone back to bramble. Marta
Bonanni came home from an advertising agency in Toriano with a fax machine and a plan, and wrote to the province for a
Geometra behind her grandfather's back. Her grandfather, Settimio, is the president of the growers' cooperative, the
last man who still carries a basket on his back up the terraces, and he finds out about the letter on your first day.
You bring the terraces back, one by one, until on Easter morning the procession climbs from the church on the rocks
through vines you rebuilt to the sanctuary, the first guests step off the train, and the cooperative votes to stay
open.

- **Feel:** the Cinque Terre the way a Nintendo game feels Japanese: pastel houses with painted window frames and grey
  slate roofs, stair lanes instead of streets, wisteria over the doors, geraniums on every sill, lemons, knee-high vine
  pergolas on stone terraces, the sea glittering at the bottom of every view, and the train in and out of the cliffs.
- **Running gags:**
  - **Marta's fax.** The only fax machine on the coast lives on Nunzia's bar counter, because that's where the phone
    line is. Marta faxes everything to everyone: press releases, labels, plans for a website. Replies come back from
    wrong numbers: a pizzeria in Toriano, a ferry company, a confused convent.
  - **Sturlese and the last train.** The Ragioniere commutes from the town hall in the next town and misses the
    evening train about one day in three: you see him sprint up the station stairs as it vanishes into the tunnel.
    Then he sleeps on the station bench, and the nap gags happen to him too.
- **Settimio against the modern world:** "In my day we had knees." He distrusts the monorail, the fax, the province
  and the Geometra, in that order, and comes round to all four by Easter, the Geometra first.

## Ground rules for Serenza
- **Size:** a village map, the default 124 m square. The terraces fill the back half and fade into the painted
  hillside beyond the edge.
- **Season:** spring, from March into the start of April, ending at Easter. There are no dates, except that Easter
  is "Sunday".
- **Weather:** mostly clear and bright, with showers some afternoons, and on some mornings a sea fog that rolls in off
  the water, fills the ravine and burns off by late morning. No storms.
- **Money:** euros. Serenza comes after Tonnarella, whose changeover turns lire into euros on screen in every place
  (`docs/locations/port.md`, "The changeover"). Serenza adds no money code of its own: prices are kept in coins like
  everywhere else and show however Tonnarella's changeover left them, euros only once it's complete. Amounts below are
  in the game's coins, with the euro figure (one coin is 1,000 lire, about €0.52).
- **Language, names, originality, no magic:** as in `docs/WORLD.md`. In the game's text the cooperative's cellar is
  "the cellar", the sweet wine is "the sweet wine" and Settimio's basket is "his basket"; Italian is kept for names,
  job titles and honorifics (Presidente, Perito meccanico, Don, Capitano, Ragioniere). Serenza, its church, its
  sanctuary and its cooperative are invented.
- **No bicycles:** it's all steps. Serenza's map entry says `"bikes": false`.

## The place
North is up (towards negative z in the game). The ravine runs north to south and opens onto the sea at the south
edge.

```text
                               N
 +------------------------------------------------------------+
 | [SANCTUARY]   pines and chestnuts            chestnuts     |
 |   chapel   \                                    pines      |
 |  mule path  \  gully X               ~E8~   ~E7~           |
 |   ~W8~  ~W7~ \                       ~E6~ | monorail       |
 |   ~W6~  ~W5~  (halfway rest)         ~E5~ | (the slip)     |
 |   ~W4~  wall collapsed onto ~W3~     ~E4~ [your hut]       |
 |   ~W2~  ~W1~ lemons                  ~E3~ ~E2~ vines       |
 |        [CELLAR]  [Trenin's workshop, monorail foot]  ~E1~  |
 |  ==tunnel=========[STATION on its arch]==========tunnel==  |
 |    houses     |  main  |     houses                        |
 |    stacked    | street |     stacked                       |
 |    up the     | boats  |     up the                        |
 |    slope      |        |     slope                         |
 |  rocks   [harbour square, Nunzia's bar]  [CHURCH on rocks] |
 |  little       [slipway]   harbour          church rocks    |
 |  beach     [ferry landing]~~~ breakwater ~~~~~~~           |
 +------------------------------------------------------------+
        the sea; headlands and the next villages both ways
```

| Area | What's there |
| --- | --- |
| The harbour (south, sea level) | A tiny harbour inside a short breakwater, with **the ferry landing** at the breakwater's end (unused until the finale), **the broken slipway** running down from the harbour square into the water. **The harbour square**, a small paved piazza with **Nunzia's bar** (the payphone, the fax machine on the counter, a few rooms upstairs for guests) and benches. West of it, rocks and **a little pebble beach**; east of it, **the church on the rocks**: grey stone, a square bell tower, the apse right over the water, and below it the rocks where Don Aurelio's rusted ladder used to go down into the sea. |
| The main street (the valley floor) | A stream covered over long ago, now a paved street climbing gently north from the harbour square. **The boats winter here**, pulled up on wooden runners along it: Capo Horn's among them. Tall, narrow pastel houses of three to five storeys rise in steps up both slopes, joined by stair lanes, little arches and washing lines. |
| The railway (across the middle) | The coastal line crosses the ravine about halfway up, on a stone arch high over the main street, between two tunnels in the cliffs. **The station** is a single platform with a canopy on the arch, a tiny waiting room and a bench, reached by stairs from the main street. The departure point. |
| The top of the village | Just above the railway: **the growers' cellar**, the cooperative's stone building where the grapes were pressed, shut up and half empty; beside it **Trenin's workshop**, half cave, at the foot of the monorail. |
| The terraces (the back half) | Sixteen terraces stepping up both slopes, eight a side (W1 to W8 on the west, E1 to E8 on the east, numbered upwards), each a narrow strip held up by a dry-stone wall. At the start only two are tended: **Settimio's lemons** (W1) and **Settimio's vines** (E2). The rest are bramble and wild fennel, some with fallen walls. **The monorail** climbs the east side from the workshop to the top terraces: a single rail on short legs with a footpath beside it; **a slip** has carried away a stretch of it between E5 and E6. **Your hut** is a stone growers' hut on E4. On the west side **the wall of W4 has collapsed** onto W3, and **the mule path** climbs past the terraces to the sanctuary, broken where it crosses **the gully**. |
| The top (north edge) | Maritime pines and chestnut trees. In the north-west corner, **the sanctuary**: a small white chapel with a bell, a forecourt with a bench and the view down to the sea. |
| The edge | The sea to the south. Steep headlands run off both ways along the coast, each with the pastel cluster of the next village and a tunnel mouth for the train; fishing boats and a ferry on the water; behind, the ridge with its pines and chestnut woods. |

**Heights:** the harbour square is just above the water; the station is about 9 m up; the cellar about 12 m; the
terraces climb from about 14 m to about 30 m, about 2 m a step; the sanctuary is about 32 m up.

## Getting there and around
- **Arrival by train.** The regional train comes along the coast from Tonnarella, out of the west tunnel, and stops on
  the arch. Marta is waiting on the platform. The order the user decided: Monteforchetta, Boccapioppo, Casalrana,
  Toriano, Tonnarella, Serenza.
- **On the travel map.** Serenza's entry stays off the map until Tonnarella's finale sets `port_lighthouse_lit` (the
  flag Tonnarella's doc already keeps "ready for whatever place comes next"). It sits on the coast east of Tonnarella,
  further down the line; the exact spot is placed once Tonnarella's entry exists. Serenza's finale sets
  `olive_village_revealed`, the flag Liolivato's map entry reveals on (agreed with that session).
- **The departure points:**
  - **The station platform**, from the start: a feature of kind `boat` (`cliffs_train`), with `depart_label`
    "Take the train", as `docs/WORLD.md` asks.
  - **The ferry landing**, after the finale: a second `boat` feature at the end of the breakwater (`cliffs_ferry`,
    `depart_label` "Take the ferry") that waits for `olive_village_revealed` (the shared `flag` on a departure
    point). From then on a little white ferry calls at the landing on its way along the coast; it's the way to
    Liolivato (the user decided the travel order goes on Serenza, then Liolivato by sea).
- **The trains.** A timetable in Serenza's own code: regional trains stop at the platform every hour or so; faster
  trains rush through without stopping, horn blaring, out of one tunnel and into the other. Sturlese arrives on the
  morning regional at about 8:10 and leaves on the evening one at about 18:05.
- **On foot only.** Stair lanes join the harbour, the main street, the station and the cellar; steps in the terrace
  walls and the paths along them join the terraces. The monorail carries crates, not people: once The Monorail is
  done, its carts buzz up and down by day with stakes, stones and saplings.
- **Until the link exists,** tests reach Serenza with `--island=cliffs`, and the playthrough starts as if the earlier
  places had been played (`arrive_as_if_played(["hearthglow", "river_town", "rice_village", "metropolis", "port"])`;
  without `"port"` until Tonnarella's pack is on main).

## The cast
Seven villagers. Ids are `cliffs_<first name>`: `cliffs_marta`, `cliffs_settimio`, `cliffs_mario`, `cliffs_aurelio`,
`cliffs_giacomo`, `cliffs_nunzia`, `cliffs_fulvio`. Marta is Settimio's granddaughter (her mother's father, hence the
different surname). Every villager has `"pronoun"` set, as the shared rules ask.

| Who | Where | Who they are | Outfit |
| --- | --- | --- | --- |
| **Marta Bonanni** | The station platform for the morning train; the cellar in the afternoon; the harbour square in the evening | 27, back from an advertising agency in Toriano with a fax machine, a mobile phone and a slogan for everything. Wrote to the province behind her grandfather's back. Meets your train, runs your first day, gives the finale, and opens every build you finish like a product launch: a disposable camera, a slogan for every bench and a press release faxed to nobody. Argues with Settimio daily. | A cropped denim jacket, a long skirt, a roll of fax paper under her arm |
| **Presidente Settimio "Gerla" Crovara** | His vines (E2) in the morning, his lemons (W1) at midday, the bench by the cellar in the afternoon, Nunzia's bar in the evening | 78, president of the growers' cooperative, the last man who still carries a basket on his back up the terraces (his nickname is the basket). Stubborn, proud, kind underneath, and the best dry-stone waller on the coast. Grumbles from the back at every opening, more kindly as the terraces come back. | A battered straw hat, braces, rolled sleeves, his basket |
| **Mario "Trenin" Cozzani**, Perito meccanico | His workshop by the cellar; up and down the monorail once it runs | Keeps the monorail's little carts running, has named every one after an aunt, and talks to their engines. His nickname means "little train", after the carts. | Blue overalls, a woolly hat, an oily rag |
| **Don Aurelio Natale** | The rocks below the church at dawn; the church in the morning; up the mule path to the sanctuary in the afternoon | Priest of the church on the rocks and keeper of the sanctuary. Swims in the sea every morning of the year (from the rocks, until the ladder rusted away). Wants the mule path safe for the Easter procession. | A black cassock, a towel round his neck at dawn |
| **Capitano Giacomo "Capo Horn" Rollandi** | His boat in the main street by day; the harbour wall in the evening | A retired merchant captain, nicknamed for rounding Cape Horn eleven times, or fourteen, depending on who's listening. Has sailed every sea and has a tall tale about each, but the running gags are Marta's and Sturlese's, not his. Mends nets beside his boat until it goes back in the water. | A navy reefer jacket, a captain's cap, a white beard |
| **Nunzia Lercari** | Her bar on the harbour square all day; a turn up to the terraces for greens at midday | Runs the bar and the little guesthouse above it, with the village's payphone and Marta's fax. Keeps the guest book and counts the days to her first Easter guests. Knows everything and repeats most of it. | A floral dress, an apron, reading glasses on a chain |
| **Ragioniere Fulvio Sturlese** | Off the morning train; round the village with his forms; the station for the evening train (or its bench) | The comune's clerk, who comes from the town hall in the next town with forms and the landscape rules: dry stone only, slate roofs only, nothing taller than the bell tower. His rules turn up as wishes on every brief; he stamps the permit whether they're met or not. Misses the last train one day in three. | A grey suit and tie, a briefcase, running shoes |
| **The hiking club** (not villagers) | Only in the finale and after it | Eight retired schoolteachers from Toriano in matching red anoraks, with maps, sandwiches and opinions: Nunzia's first Easter guests. They step off the train for the procession and walk the terraces as passers-by afterwards. No topics or gifts. | Matching red anoraks, walking sticks, maps |
| **The player** | | The Geometra, come down the coast from Tonnarella. Monteforchetta's windbreaker and clipboard, plus Serenza's clothes below. | |

Daily routines are drafted in stage 3, as outlined in the table. Sturlese's follows the timetable: he arrives with the
morning regional and, on a day he misses the evening one, sleeps on the station bench (or in your shelter, once it's
built) and catches the first train in the morning.

## The terraces: Serenza's progress meter
Requests in Serenza bring **terraces back into use** instead of raising the Sindaco's approval rating, which stays
Monteforchetta's. The hillside has sixteen; two are tended when you arrive. A terrace is back in use when its wall is
whole and something green grows on it: a vine pergola, a lemon tree, a young tree, a flower bed or a hedge. You see
the meter on the hillside: a terrace that comes back loses its brambles, its wall is mended, vines bud on it and wall
lizards bask on its stones.

**Any terrace counts, request or not.** Every abandoned terrace is an open build site. Mend its wall and plant on it
and it counts, once, for good: removing the planting later doesn't take it back, as a milestone is never taken back.
Requests that bring back particular terraces do it through the same check, so no terrace counts twice.

| Terrace | Comes back with |
| --- | --- |
| W1 (Settimio's lemons), E2 (Settimio's vines) | Tended from the start |
| E4 | The Hut on the Terrace |
| W3, W4 | The First Wall |
| E5, E6 | The Monorail |
| W7 | The Sanctuary Path |
| E1 | The Cellar Reopens |
| W2 | Herbs for the Easter Pie |
| E3, W5, W6, E7, W8, E8 | Your own work, whenever you like |

The main story brings six back and two side requests two more, which makes the ten the finale needs; the last six are
yours to bring back, before or after Easter.

| Terraces | Milestone | Reward |
| --- | --- | --- |
| 4 | Green on the hill | 30 coins (about €15) from the cooperative's tin |
| 6 | The lizards are back | The lemon tree's plan and two lemon saplings from Settimio's own trees |
| 8 | Settimio takes his hat off | Your plot grows onto E3, the terrace below the hut |
| 10 | Ready for Easter | The finale's first step is met |
| 13 | The hillside in green | 100 coins (about €52) and the hiking club's postcard, framed in your hut |
| 16 | Sixteen of sixteen | A slate plaque with your name by the cellar door, and 150 coins (about €77) |

In data: the shared location meter (`location.json`, `LocationMeter`), counting points from 0 with a display that
starts at two (`"display": {"from": 2, "per_point": 1, "format": "%d of 16 terraces", "to": 16}`) and milestones at
2, 4, 6, 8, 11 and 14 points. Requests add their terraces with `"meter"` rewards and set the terraces' flags
(`cliffs_terrace_w3` and so on); terraces brought back by free building need the small shared hook below.

## Gathering
| Material | Where it comes from |
| --- | --- |
| Wood | Chopping the maritime pines and chestnuts at the top of the map, round the sanctuary (the chopping minigame). The brambles on your hut's terrace give a little, once, when you cut them. |
| Stone | Wall stones from the rubble heaps of collapsed terrace walls (the quarrying minigame). The stone you rebuild the walls with comes from the walls that fell, and every heap is a terrace waiting to come back. |
| Clay | Dug from the gully bank below the mule path. |
| Lemons (`cliffs_lemon`) | Picked from Settimio's lemon terrace, the village gardens and any lemon tree you plant. For gifts, treats and selling. |
| Wild greens (`cliffs_greens`) and borage (`cliffs_borage`) | Picked off the abandoned terraces and along the walls (flower spots that give them, with their own `label`). For Nunzia's Easter pie; she buys them and likes them as gifts. |
| Flowers | Broom and rosemary on the wild cliff slopes. |
| Vine and lemon saplings (`cliffs_vine`, `cliffs_lemon_sapling`) | Settimio gives the first ones; then the cellar's shop sells them. The vine pergola and the lemon tree are planted with them. |
| Fish | Off the harbour wall and the rocks, by day: sea bream (`cliffs_bream`), grey mullet (`cliffs_mullet`) and now and then a little octopus (`cliffs_octopus`), in the layout's `fish`. Junk: an old boot you put back. No anchovies: night fishing under a lamp is Tonnarella's. |
| Metal and copper wire | Only from Trenin's shop. |
| Fabric | Nunzia's old sheets and tablecloths, and Capo Horn's sailcloth. |
| Lost things | The shared lost things, blown down the terraces or dropped from the train over the winter: Sturlese's season ticket, Marta's Walkman, Nunzia's umbrella, a cassette, Capo Horn's photo of his ship and Trenin's glove. Each named, so it looks like what it is. |
| Metal detector finds | With your own metal detector, on the terraces and the little beach: an old coin, a brass ship's button and a pilgrim's medal near the mule path (Serenza items, as dig spots' `gives`). Trenin buys them; Capo Horn likes the button and Don Aurelio the medal. |
| Treats | At Nunzia's: coffee, focaccia, lemon cake and, after the herbs, the Easter pie of greens and eggs. Capo Horn's salted anchovies. The cellar's sweet wine. |

## Shops
| Shop | Sells | Buys |
| --- | --- | --- |
| Nunzia's bar (the harbour square) | Coffee, focaccia, lemon cake, the Easter pie (after Herbs for the Easter Pie), building plans, fabric (old sheets and tablecloths) | Lemons, wild greens, borage, fish |
| Trenin's workshop (by the cellar) | Metal, copper wire, spare parts, the tool upgrades, building plans | Metal-detector finds, junk from the sea |
| Capo Horn's boat (the main street, then the harbour) | Sailcloth (fabric), salted anchovies, bait; the white captain's cap after Boats Back to Sea | Fish, wood |
| The cellar (Marta, after The Cellar Reopens) | Vine and lemon saplings, seed packets (broad beans for the garden beds by your hut), bottles of the sweet wine, wood and stone delivered by the train | Lemons |

## Clothes
Three clothing variants in Serenza's own `appearance.json`, each an existing shape in its own colours. The sailor top
(Monteforchetta's) and the fisherman's wool cap (Tonnarella's) already exist, so Serenza doesn't repeat them.

| Clothes | Shape | How you get them |
| --- | --- | --- |
| Settimio's straw hat, wide and battered | `sunhat` | Settimio's friendship gift, once he's warmed to you |
| A white captain's peaked cap | `captain` | The reward for Boats Back to Sea; then in Capo Horn's shop |
| Rope-soled espadrilles | `sandals` | The reward for Fish for the Easter Lunch |

## Requests
Ids are `cliffs_<name>`. Every building step is a brief with musts and wishes (`docs/DESIGN.md`), with a ghost plan
that meets every must and that the request's gathering pays for. As everywhere, a brief checks what you built, not one
layout. Wishes come from whoever has a say; Sturlese's landscape rules are only ever wishes, and nothing is refused.
No brief brings in more than one kind of check the player hasn't met yet.

### Main story
| # | Request | Given by | What you do |
| --- | --- | --- | --- |
| 1 | **Welcome to Serenza** (`cliffs_welcome`) | Marta | Off the morning train. Marta meets you on the platform, and the walk is the tour: down the station stairs and under the arch into the main street, past Capo Horn mending nets beside his boat, to the harbour square (Nunzia, the payphone, the fax on the counter) and Don Aurelio on the church rocks; back up to the cellar and Trenin's workshop; and up the terrace steps to Settimio's vines, where he finds out about the letter. Gather a little wood and stone on the way (the gifts on accepting count). It ends there, with Settimio. Your first night is on a bench. |
| 2 | **The Hut on the Terrace** (`cliffs_hut`) | Settimio | "If you're staying, you'll stay where I can see you." The cooperative's roofless hut on E4. Cut the three bramble patches on the terrace (chopping spots that are gone once cut). **Brief** at the hut: **musts:** a roof; a door; a light. **Wishes:** walls in stone (Settimio); no taller than 4 m (Sturlese); something painted (Marta). Then plant something green on the terrace with Settimio's two vine saplings (the vine pergola's plan comes with them), and E4 is back in use. The hut becomes your home (a wardrobe, and a bed once you've bought one; until then the stone bench by its door) and E4 your build plot. |
| 3 | **The First Wall** (`cliffs_wall`) | Settimio | The wall under W4 has collapsed onto W3 and buried its vines. Quarry 12 wall stones from the rubble, then Settimio shows you how (the dry-stone wall and its plan). **Brief** at the gap: **musts:** a wall across the gap, with nothing low enough for the terrace to spill through (`sealed`); at least 1.8 m tall. **Wishes:** stone only (Settimio); a sign for the visitors (Marta); no higher than the terrace above (Sturlese). Then plant something green on W3 and on W4. Both come back, the wall lizards come out on the new stones, and Settimio pays his first compliment: "It'll do. For now." |
| 4 | **The Monorail** (`cliffs_monorail`) | Trenin | A slip took the footpath beside the monorail between E5 and E6, and the rail with it, so the carts can't reach the top and the terraces up there were given up. Gather wood and stone and buy metal at Trenin's. **Brief** along the slip: **musts:** a walkable path from its lower end up to its upper end (`path`, climbing); a railing on the open side. **Wishes:** a lever at the top for the cart stop (Trenin); stone steps (Settimio). Trenin lays the rail along your path (drawn by Serenza's code on the path the check found), and the first cart creeps up loaded with stakes, his aunt's name painted on its side. The growers bring E5 and E6 back. From then on the carts run by day. |
| 5 | **The Sanctuary Path** (`cliffs_path`) | Don Aurelio | The procession climbs to the sanctuary on Easter morning, but a winter flood in the gully took the mule path's steps and its little footbridge. Gather wood and stone. **Brief** at the gully: **musts:** a walkable path across the gully from the lower path to the upper (`path`, climbing); railings for the old ladies. **Wishes:** a little statue on the way (Don Aurelio); in stone (Settimio); no taller than 3 m (Sturlese). Walk up to the sanctuary with him and ring its bell. The old growers can reach W7 again, and it comes back. Don Aurelio's afternoon walk uses your bridge from then on (a layout `crossing`). |
| 6 | **Easter on the Terraces**, the finale (`cliffs_easter`) | Marta | Offered once the other five are done. In steps. **Ten terraces back in use** (the meter). **The resting place:** a brief at the halfway spot on the procession route (the hangout by W5): **musts:** a seat; shade; something green. **Wishes:** a statue of the saint (Don Aurelio); in stone (Settimio); no taller than 3 m (Sturlese). **Easter morning** (after you sleep): the procession climbs from the church on the rocks up the main street, under the arch, past the cellar, along the terraces, across your bridge and up to the sanctuary, pausing at the resting place, with the church bells pealing; the hiking club steps off the morning train and joins at the back. **The vote:** in the cellar, the cooperative votes to stay open, Settimio casting the deciding vote with Marta's label on the first bottle; Sturlese abstains on procedural grounds. It ends there. Sets `olive_village_revealed`: the ferry starts calling at the landing, and Liolivato appears on the travel map. |

### Side requests
| Request | Given by | What you do |
| --- | --- | --- |
| **Boats Back to Sea** (`cliffs_boats`) | Capo Horn | After Welcome to Serenza. Every spring the village slides the boats that wintered in the main street down the slipway into the harbour, and the slipway has crumbled. Gather stone and wood. **Brief** at the slipway: **musts:** a walkable ramp from the harbour square down to the water's edge (`path`); at least six pieces. **Wishes:** a railing at the top so nobody follows the boats in (Capo Horn); a bench to watch from (Nunzia); in stone (Sturlese). At dawn the next day the village launches the boats; the main street opens up and the boats ride at their moorings in the harbour from then on (`WORLD_FLAGS`, `cliffs_boats_launched`). Rewards include the white captain's cap. |
| **The Cellar Reopens** (`cliffs_cellar`) | Marta | After The Monorail (the carts bring up the crates). **Brief** in the cellar: **musts:** a counter; two lamps; shelves for the bottles. **Wishes:** a workbench for the press (Trenin); a table for tasting (Settimio); the counter painted (Marta). Marta draws her labels and faxes them to forty numbers, then you plant the first saplings on E1, the terrace below the cellar, and it comes back. The cellar becomes Marta's shop. |
| **Fish for the Easter Lunch** (`cliffs_lunch`) | Capo Horn | Nunzia is cooking Easter lunch for the hiking club. Fish off the harbour wall and the rocks with the captain by day, a tall tale per fish: three sea bream and two grey mullet (what's in your bag counts). Hand them to Nunzia at the bar, where it ends. Rewards include the espadrilles. |
| **A Shelter for the Last Train** (`cliffs_shelter`) | Sturlese | Offered the morning after you first see him miss the evening train. **Brief** on the station platform: **musts:** a seat; a roof; a light. **Wishes:** no taller than the canopy, 3 m (Sturlese); a sign with the timetable (Marta); a flower bed (Nunzia). That evening he misses the train again and naps in your shelter, dry (a sight gag, no line), which ends the request. |
| **Herbs for the Easter Pie** (`cliffs_herbs`) | Nunzia | Gather 8 wild greens and 3 borage off the abandoned terraces and along the walls; she bakes the Easter pie of greens and eggs and gives you a slice (and sells it from then on). Then she wants her greens nearer next year: plant two green things on W2, the terrace just above the houses, and it comes back. |
| **Tables for the Guests** (`cliffs_tables`) | Nunzia | Before Easter. **Brief** on the harbour square: **musts:** two tables; four chairs; shade. **Wishes:** a railing along the quay edge (Capo Horn); nothing taller than 3 m (Sturlese); a lemon tree (Nunzia). |
| **Don Aurelio's Morning Swim** (`cliffs_swim`) | Don Aurelio | The iron ladder down the rocks below the church has rusted away. **Brief** at the church rocks: **musts:** a walkable way down the rocks from the church terrace to the water (`path`, climbing down); a platform on the water (a pontoon). **Wishes:** a rail to hold (Don Aurelio); painted (Capo Horn); no taller than the church terrace (Sturlese). At dawn he swims, invites you in, and you decline, which ends it. From then on he swims every dawn. |

Six main and seven side requests.

## Rooms you can walk into
- **Nunzia's bar:** the counter with the fax machine and the payphone, the coffee machine, three tables, the guest book.
- **The cellar:** the old press, empty barrels, and the space the Cellar Reopens brief fills.
- **Your hut** on E4: one stone room, empty until The Hut on the Terrace.
- **The church:** the stone nave with ship paintings left as thanks by sailors, candles, and the sea heard through the
  walls.
- **Trenin's workshop:** half cave, full of engines, a spare cart, and his aunts' photographs.
- **The station waiting room:** a ticket window, the timetable and a bench.
- **The sanctuary chapel:** the altar, candles, the bell rope, and the view to the sea from the door.
- Not the houses, Marta's flat, the guest rooms or the captain's house.

## Hangouts and needs
The places villagers pass and want things, for the shared needs, charm and liveliness: the station platform, the
harbour square, the church rocks, the cellar door, the halfway spot on the procession route (by W5) and the sanctuary
forecourt. Needs are the shared ones (a seat, shelter, light, green, a counter), at most three open at a time.

## Tastes
| Villager | Pieces | Colour |
| --- | --- | --- |
| Marta | Signposts, enamel signs, electric lamps | Teal and purple |
| Settimio | Dry-stone walls, vine pergolas, stone blocks | Stone grey |
| Trenin | Gear boxes, drive shafts, levers, workbenches | Cart red |
| Don Aurelio | Benches, flower beds, statues | White |
| Capo Horn | Railings, pontoons, bridge planks, signposts | Sea blue |
| Nunzia | Tables, chairs, lemon trees, roofs for shade | Lemon yellow |
| Sturlese | Fences, garden paths, pillars, signposts | Slate grey |

## The day
- **Nights matter**, like Boccapioppo and Tonnarella: the clock doesn't hold at dusk (`"day": {"holdAt": 20.5,
  "regrow": "overnight", "hold": false}`), so the evening train, Sturlese's sprint and the village lit up after dark
  happen in play. Things regrow overnight: wall-stone heaps, greens, lemons.
- **You end the day by sleeping**, on a bench until you've bought a bed (the shared price, about €62).
- **The morning paper is Il Gabbiano**, the coast's own paper, the same one Tonnarella reads: its reporter remembers
  you from Tonnarella and reviews yesterday's build in Serenza. Serenza's headlines are in its own files.
- **The opening ceremony** is Marta's: a launch with slogans, the disposable camera and Settimio grumbling from the
  back.
- **Benches** on the station platform, the harbour square, the church rocks, the halfway spot and the sanctuary
  forecourt, and the stone bench by your hut. Serenza's `naps` block names Il Gabbiano and adds two gags that need
  only lines: the dawn train's horn bursting out of the tunnel, and Sturlese asleep at the other end of the bench
  with his briefcase for a pillow.

## Look
- **Buildings:** narrow houses three to five storeys tall, stacked tight up both sides of the ravine, in pink, salmon,
  yellow, ochre and brick red, with window frames, corner stones and cornices painted on in white and grey, green
  shutters, stone footings and flat grey slate roofs. The shared house kit gets a slate roof (and, if it doesn't
  already hold up, taller houses); the painted frames are Serenza's own, added on top of the kit as Boccapioppo's
  models add the tide line. The church in grey stone with a square tower and a slate spire; the cellar in rough
  stone; the station small and plain, cream with a slate canopy; the sanctuary white with a little bell gable; the
  hut a stone box with a slate roof.
- **Ground:** stone paving and steps in the main street and the stair lanes, the harbour square's flagstones, the
  terraces' bare earth and dry-stone walls, brambles and wild fennel on the abandoned terraces, grey sandstone rocks,
  the pebble beach, pine needles at the top. No meadow.
- **Plants:** vines trained knee-high on pergolas of canes on the tended terraces, bare and just budding; lemon trees
  on Settimio's terrace and in gardens; wisteria in purple bloom over doorways and pergolas; geraniums and basil in
  pots on sills and stairs; a few silver olive trees on the lower terraces; yellow broom and rosemary on the wild
  cliff slopes; maritime pines and chestnuts at the top.
- **Animals:** gulls on the harbour wall, the boats and the church roof, flapping up when you come close, and a few
  circling over the sea; wall lizards basking on sound dry-stone walls that dart into the cracks as you pass, and
  more of them as more terraces come back; swallows arriving for spring, swooping over the harbour and nesting under
  the eaves, more of them as Easter nears.
- **Light and weather:** bright spring light, the sea glittering at the bottom of every view, the sun setting over the
  water to the west. Showers some afternoons. On some mornings the sea fog rolls in off the water and fills the
  ravine to the station, burning off by late morning. At night the village's windows, a few street lamps on the
  stair lanes, the station's lamps and the lights of the next villages along the coast.
- **The look block** (`location.json`): a little cool shade, warm highlights, a moderate sea breeze, a few motes, no
  fireflies or falling leaves, weather `clear` and `rain`, `mist` for the fog mornings, a clear Mediterranean sky, a
  pale blue-grey haze along the coast, the sea's blues and turquoise over the rocks, a spring sun (`sun_peak` about
  50), songbirds on.

## Sound
- **Music:** sparse and quiet themes for each part of the day in the game's own synthesiser, with long pauses between
  phrases, like Casalrana's, so the sea, the gulls and the trains carry the place. (A seaside-songwriter sound and a
  mandolin were offered and not chosen.)
- **The sea and the gulls:** waves washing on the rocks and slapping in the harbour, louder near the water; gulls
  crying overhead.
- **The trains:** a rumble growing inside the tunnel, the horn as the train bursts out onto the arch, the rush past
  the station, and quiet again as it dives into the other tunnel.
- **The monorail:** the carts' little two-stroke engines buzzing and stuttering up the terraces, once they run again.
- **Swallows** twittering over the harbour.
- **Church bells for big moments only:** the sanctuary's bell at the end of The Sanctuary Path, and peals for the
  procession and the vote. No noon or hourly bells.

## Changes to shared code this needs
Each is the smallest general version, comes with a test, and is named at the top of the pull request that makes it.

| Change | Why | Stage |
| --- | --- | --- |
| **Three new building pieces** (the user agreed): a **dry-stone wall** (stone, a tile wide, for terrace walls), a **vine pergola** (wood and a vine sapling; green) and a **lemon tree** (a lemon sapling; green), with their icons and plans. A shared piece may cost a place's own item, as Boccapioppo's sandbags cost its sand | Bringing terraces back | 3 (built) |
| **A placed piece you can pick from**, once a day (`gives` on a piece): the lemon tree's lemons | The lemon tree | 3 (built: `Gardening.pick`, the `pick` interaction) |
| **A "no taller than" check** for briefs (`lower {height}`), the other side of `taller` | Sturlese's landscape rules | 3 (built) |
| **Meter points from the world:** a location's code can award points on its meter once per named thing (a terrace), saved, never taken back | Terraces you bring back without a request | 3 (built: a pack's `meter_things(state)`, `LocationMeter.new_things`, `Story.count_world_meter`) |
| **Tastes from a location's pack** (`tastes.json` beside its villagers), merged like its shops | Serenza's villagers' tastes, without touching `data/tastes.json` | 3 (built by Tonnarella's stage 3, the same change) |
| **Ghost plans stack on high ground:** a plan's pieces stack from the site's floor height (`floorY`), not from sea level | Every site in Serenza is 10 to 30 m up | 3 (built by Liolivato's stage 3; every Serenza site has a `floorY`) |
| **A slate roof in the house kit**, chosen per building or per layout, and taller houses (three to five storeys) if the kit's `floors` doesn't already hold up | Serenza's houses; offered to Tonnarella, whose palazzi have slate roofs too | 2 (built: `roofTiles`; taller houses needed no change) |
| ~~A garden-bed look for broad beans~~ | Dropped in stage 3: the cellar sells saplings, not seed packets | |

Everything else lives in Serenza's own files (`docs/WORLD.md`): `godot/data/locations/cliffs/`,
`godot/scripts/locations/cliffs.gd` and helpers in `godot/scripts/locations/cliffs/`, `godot/tests/test_cliffs.gd` and
`godot/tests/play_cliffs.gd`. That covers the ravine, the terraces, the harbour and the sea; the painted frames on top
of the kit houses; the station on its arch, the tunnels and the trains; the monorail, its rail drawn along the
built path and its freight carts; the boats moving from the main street to the harbour; the ferry calling at the
landing after the finale (`WORLD_FLAGS`); checking which terraces are
back in use (a wall `sealed` across its zone and something green on it) and how they look; the gulls, lizards and
swallows; the procession; the coast and the next villages past the edge.

## Build stages
One pull request per stage. Each keeps the game playable and the tests passing.

1. **Ground and map.**
   - The ground shape in `cliffs.gd`: the ravine and its slopes, the harbour and the breakwater, the rocks and the
     little beach, the sixteen terraces as flat strips stepping up both sides, the gully, the sea round the south.
   - The layout: arrival on the station platform, the two departure points (the station, and the ferry landing
     behind `olive_village_revealed`), the nav graph, paths, stair lanes and terrace
     steps (raised floors and stairs where the ground is too steep to walk), build zones (the hut, the W4 gap, the
     slip, the gully, the slipway, the church rocks, the cellar, the sixteen terraces, the hangouts), resource spots
     and benches.
   - A hidden map entry revealed by `port_lighthouse_lit`, with `"bikes": false`, the `day` block and a first
     `look`.
   - Plain boxes for the buildings so the map reads in screenshots.
   - `test_cliffs.gd`: a playable world (the arrival is walkable, the harbour, the station, the cellar, every terrace
     and the sanctuary can be reached on foot, every nav spot can be reached, water where the sea and the harbour
     are, build zones on solid ground).
2. **Buildings and scenery.**
   - The slate roof in the shared house kit (and taller houses if needed), then the stacked pastel houses with their
     painted frames; the church on the rocks, the station on its arch and the tunnel mouths, the cellar, Trenin's
     workshop, the hut, the sanctuary, Nunzia's bar.
   - Rooms you can walk into, with furniture and routes.
   - The trains on their timetable; the monorail's rail and its stopped carts; the boats on their runners in the main
     street; the dry-stone walls, the collapsed W4 wall, the slip and the broken gully path.
   - Vines on cane pergolas, lemons, wisteria, geraniums, olives, broom, rosemary, pines and chestnuts; brambles on
     the abandoned terraces; the coast, the headlands and the next villages past the edge.
3. **People, dialogue and requests.**
   - The seven villagers with routines, greetings, topics, gifts and tastes; the hiking club for the finale.
   - The thirteen requests with their briefs and ghost plans, the four shops, Serenza's items, fish and finds, the
     terraces meter, the clothes, the paper's headlines, Marta's openings and the naps block.
   - The shared changes marked stage 3 above.
   - The boats' launch, the monorail running, the procession and the vote, and the ferry at the landing after it.
   - `play_cliffs.gd`: a scripted playthrough of every request with real input, starting off the train as if the
     player had come from Tonnarella with realistic stats.
4. **Look and ambient life.**
   - Tuning the look block, the sea fog mornings, the night lights.
   - Gulls, wall lizards and swallows, growing with the terraces and towards Easter.
   - The music and the sounds of the sea, the gulls, the trains, the monorail, the swallows and the bells.
   - The cast's outfits.

## Agreements needed with other sessions
- **Tonnarella (`port`):** Serenza's map entry reveals on `port_lighthouse_lit`, which Tonnarella's doc already keeps
  for the next place; nothing in Tonnarella's files changes. Serenza starts after its changeover and has no money code
  of its own. Il Gabbiano is the coast's paper in both places; each keeps its own headlines in its own files. Where
  the two docs overlapped, Serenza moved: its captain is "Capo Horn", not a second Baciccia; it has no night anchovy
  fishing (that's Tonnarella's lampara); its clothes don't repeat Tonnarella's wool cap. The kit's slate roof is
  offered to Tonnarella; whoever needs it first builds it, and the other merges main and reuses it.
- **The playthrough** starts with `arrive_as_if_played(["hearthglow", "river_town", "rice_village", "metropolis",
  "port"])` once Tonnarella's pack is on main, so money shows as Tonnarella leaves it; until then without `"port"`,
  and the playthrough's amounts show in lire.
- **Liolivato (`olive_village`):** it comes after Serenza, reached by the ferry. Serenza's finale sets
  `olive_village_revealed`, the flag Liolivato's map entry reveals on, and opens Serenza's ferry landing; nothing in
  Liolivato's files changes for it. A ferry from Tonnarella once Liolivato is unlocked is Liolivato's and
  Tonnarella's to agree.
- **No dusk hold:** the rule the user set for every place (the clock never holds at dusk) is already Serenza's: its
  `day` block has `"hold": false`.

## Risks
- **Steep ground.** Stair lanes and terrace steps on the heightfield must be walkable (a step up is at most 0.45 m in
  `WalkWorld`), and walking and quest checks share `WalkWorld`. Where slopes that steep fight the player controller,
  the stair lanes and terrace steps become raised floors and stairs (`floors` in the layout). The terrace walls are
  near-vertical: the height map steps there, and Serenza's code draws the stone faces over the steep cells.
- **Room to build.** Flat ground is rare in a ravine. Each terrace needs to be at least four tiles deep to build on,
  and the harbour square, the platform and the church rocks need room for their briefs.
- **The camera in a narrow ravine** between houses up to five storeys tall: buildings carry their height (`h`), and
  the tall fronts may need to fade like the rooms' roofs, as Tonnarella also expects.
- **Counting terraces fairly.** A terrace must count exactly once, whether a request or free building brings it back,
  and never be taken back. Tested in `test_cliffs.gd` and the shared hook's own test.
- **The house kit is shared.** The slate roof and taller houses must leave every other place's houses exactly as they
  are unless their layout asks for them; checked with the fixed views (`views.sh`, `measure_views.py`) before and
  after.
- **Frame rate:** many tall houses and the trains, on the software renderer used for screenshots.
- **Sea fog** can wash the picture out; average brightness is measured in screenshots, as `docs/GRAPHICS.md`
  describes.
- **Links to Tonnarella.** The reveal flag and the euro come from Tonnarella. If its pack isn't on main when Serenza's
  first stage lands, Serenza still reveals on `port_lighthouse_lit`; it just can't be reached in play yet.

## Checks for every stage
- `godot/run_tests.sh`, and `npm test` and `npm run build` for the frozen web version.
- Screenshots of Serenza in both renderers (`godot/shot.sh ... --island=cliffs`, with and without
  `RENDERER=forward_plus`).
- From stage 3, Serenza's own playthrough only (`godot/play_all.sh <out> play_cliffs`), starting as if the player had
  come from Tonnarella with realistic stats.
- Each pull request says what was verified in play and what was only unit-tested.

## Offered and not chosen
So later sessions don't add them back by accident: a bus over the hills or a ferry as the way in; summer, the grape
harvest or late winter as the season; a village on a cliff top, or two hamlets joined by a cliff path; a sea storm or
a landslide as the reason you're sent; the old watchtower; an island offshore; members of the cooperative or Easter
bottle orders as the meter; a 160 m map; Settimio or Don Aurelio as the first-day guide; Zia Assunta the lemon grower
and Luca "Acciuga" Moggia the harbour boy; Anchovies by Lamplight (Tonnarella has night fishing), the gerla against the
monorail race; giant canes and driftwood; monorail rides for the player; terracotta roofs and low kit houses; agaves
and prickly pears; always-clear or stormy weather; holding the clock at dusk; a seaside-songwriter or mandolin sound;
church bells at noon; cats; Settimio or Sturlese opening the builds; Serenza Notizie and L'Eco delle Fasce as the
paper; the sailor jersey and the fisherman's wool cap; Marta's neon windbreaker; trains cutting conversations off and
Capo Horn's ports as running gags; a monorail rail as a building piece; real bans (`noBuild`) for Sturlese's rules;
the euro switch happening in Serenza itself.

## Status
**Stage 1, ground and map: built.**
- **The ground** (`godot/scripts/locations/cliffs.gd`, with its shape in `cliffs/ground_data.gd`):
  - Flat areas and ramps laid out as rectangles: the harbour square, the main street rising under the railway arch,
    the steps up to the cellar square, the station platform and its lane, the east lane and the belvedere, the church
    rocks, the breakwater and the ferry landing, the pebble beach running into the sea, and the house plots.
  - Sixteen terraces 4 m deep and 2 m apart (12 m up for W1 and E1, 26 m for W8 and E8), the stair up the middle, the
    monorail's footpath on the east (broken by the slip between E5 and E6), the mule path on the west (broken by a
    gully beside W3 and W4), the band of pines along the top at 27 m and the sanctuary at 29.5 m in the north-west
    corner. W4's wall has fallen onto W3, and six other terraces have a gap in their wall (rubble you can scramble up).
  - Outside those areas, rock: it rises up the sides of the ravine and towards the north, and always stands at least
    2.4 m above any path beside it, so the walls can't be climbed. Below the coast line, the sea.
  - Ground paint: grey rock with scrub and pines on the cliffs, bare soil on Settimio's terraces, bramble green on the
    abandoned ones, rubble in the gaps, sand under the sea. The layout's paving (`ground`) lays stone on the square,
    the lanes, the platform, the breakwater and the stair, setts on the street and the cellar square, gravel on the
    railway. The mule path, the monorail's footpath and the sanctuary are painted rather than paved, because a paving
    edge next to a steep wall runs up it in spikes.
- **The layout** (`godot/data/locations/cliffs/layout.json`):
  - You arrive on the station platform. Two departure points: the train from the start, and the ferry at the landing
    once `olive_village_revealed` is set.
  - 13 kit houses (three or four storeys, pastel, green shutters) and Nunzia's bar; plain boxes for the station, the
    church and its tower, the cellar, Trenin's workshop, the sanctuary, the railway, the arch and the two tunnels.
  - 64 nav spots; the slip and the gully are nav edges that wait for their requests (`cliffs_monorailRuns`,
    `cliffs_sanctuaryPath`).
  - Build sites: the hut, your terrace (E4, behind `cliffs_homePlot`), the fallen wall under W4, the slip, the gully,
    the slipway, the rocks below the church (each behind its request), and 13 abandoned terraces open from the start.
  - Basic gathering: pines and chestnuts at the top, eight rubble heaps of fallen walls, clay in the gully, wild greens
    on the abandoned terraces, fishing in the harbour and off the rocks and the beach. Six benches.
- **The map entry** (`location.json`): Serenza, off the map until `port_lighthouse_lit`; no bicycles; a work day
  that doesn't hold the clock at dusk; a first look (spring sun, sea colours, clear, fair, drizzle and misty mornings).
- **Checked:**
  - **Tested** (`test_cliffs.gd`, 11 tests): the map entry; arriving on the platform; a walk over the whole map on a
    1 m grid with the player's own rules (0.45 m up per step, falls allowed, solid boxes block) reaches the harbour,
    the beach, the breakwater, the belvedere, the cellar square, both halves of every terrace, the top and the
    sanctuary, and not the railway, the cliffs or the ridge; terrace walls, the gully and the slip can't be climbed;
    water where the design puts it; build sites on dry ground and clear of scenery, the slip and the gully climbing
    from one end to the other; every nav spot reachable and every nav edge walkable both ways; ground paint and
    greenery; ids and models; the whole place builds.
  - **Played** (`play_cliffs.gd`, real input): see the stage 1 pull request.

**Stage 2, buildings and scenery: built** (helpers in `godot/scripts/locations/cliffs/`).
- **The shared change:** the house kit lays slate roofs when the layout's `houseStyle` (or a building) says
  `"roofTiles": "slate"`: flat slates in staggered rows and a slate ridge instead of coppi. Every other place keeps its
  coppi (tested in `test_house_kit`).
- **Houses** (`buildings.gd`): the kit's three- and four-storey pastel houses under slate, with the layout's white
  painted corners (`quoins`) and cornices, and painted window surrounds that Serenza adds on top of the kit's windows.
- **Landmarks** (`buildings.gd`): the church on the rocks in grey stone with arched windows and a rose window, and
  its bell tower beside it with a belfry, a bell and a slate spire; the growers' cellar and Trenin's workshop; the
  white sanctuary with its bell gable; the roofless stone hut on E4; the railway arch over the main street, the stone
  tunnel mouths and the track with its sleepers.
- **Rooms you can walk into:** Nunzia's bar and the station's waiting room (kit rooms), and the church, the cellar,
  the workshop, the sanctuary chapel and the hut, whose walls are built from the same rectangles the collision uses,
  so they always agree. Their roofs fade while you're inside. Furniture: the bar's counter and tables, the waiting
  room's benches and ticket window, the church's pews, altar and candles, the cellar's barrels and press, the
  workshop's bench and crates, the chapel's altar. The hut is empty, and its build site is inside its walls.
- **Scenery** (`scenery.gd`):
  - Dry-stone walls wherever one walkable level drops more than 0.9 m to another (terrace walls, the stair's and the
    paths' sides, the top band), quay walls round the harbour, the breakwater and the church rocks, and steps on every
    stair, lane and path.
  - The monorail's rail on its legs up the east side, broken across the slip, with one cart at the bottom and one
    stuck below the slip; four boats on their runners in the main street; Settimio's lemon trees on W1 and the vines
    on their cane pergolas on E2, just budding.
  - Brambles on the abandoned terraces, broom and rosemary on the cliffs, a few olives, wisteria over the bar's door,
    the cellar's door and the station lane; the station's awning with the SERENZA board; rubble in the gully, the slip,
    under W4's fallen wall and where the slipway broke.
  - Past the edge: the coast's headlands running off both ways, the ridge behind, and the next villages on the
    headlands, pastel with grey roofs and a bell tower each.
- **Trains** (`trains.gd`): a train every twenty minutes from 5:10 to 23:10, alternating directions; two in three
  are red-and-white regionals that brake into the station and wait a minute and a half (the 8:10 and the 18:10 are
  Sturlese's), the third a white-and-green fast train that runs straight through. They come out of one tunnel and go
  into the other, and are only drawn between them.
- **Changes from the plan:**
  - The platform's canopy became a narrow awning on the station's front: a full canopy hid you and the train from the
    camera.
  - The departure point by the platform is `cliffs_train` (its first id was the station building's, which stopped the
    station's roof fading).
  - The bell tower stands beside the church, not on it, so the church's room is clear inside.
- **Checked:**
  - **Tested** (`test_cliffs.gd`, 15 tests): stage 1's, plus the seven rooms (each reachable on the nav graph, roofs
    that fade, the hut empty), slate roofs and painted surrounds on every kit house, the scenery and the trains built,
    the timetable (every twenty minutes, regionals standing at 8:10 and 18:10, fast trains never stopping, only drawn
    between the tunnels), the boats pulled up at the sides of the street. The shared room test (nothing across a room)
    covers Serenza's rooms.
  - **Played** (`play_cliffs.gd`, real input): see the stage 2 pull request.
- **Not yet:** the people, requests, shops and items, the terraces meter, the boats' launch, the monorail running
  (stage 3); the look, the animals, the music and sounds, the trains' horns (stage 4). The terrain still shows the
  low slope in front of each wall that its mesh can't make vertical.

**Stage 3, people, dialogue and requests: built.**
- **The shared changes** (each with a test): the dry-stone wall, the vine pergola and the lemon tree, with their
  models and rendered icons (`piece_meshes.gd`, `assets/icons/pieces/`); picking from a placed piece once a day
  (`Gardening.pickable`/`pick`, the `pick` interaction in `game.gd`); the brief's `lower` check; meter points a
  location's code awards for what the world shows (`meter_things`, counted after every build and every finished
  request). Tastes from a location's pack and ghost plans that stack from a site's floor height arrived from
  Tonnarella's and Liolivato's stage 3 with the same changes, and Serenza uses theirs.
- **The people** (`npcs.json`): Marta, Settimio, Trenin, Don Aurelio, Capo Horn, Nunzia and Sturlese, each with a
  routine that changes with the story (Marta meets the train until you've been shown round, Capo Horn moves to the
  harbour once the boats are launched, Trenin rides the monorail once it runs, Sturlese sleeps in your shelter, and
  on Easter morning everyone gathers at the church door), greetings that change as the terraces come back, three
  topics each, gifts (Settimio's straw hat at six hearts) and tastes (`tastes.json`).
- **The requests** (`quests.json`): the thirteen in the tables above, each building step a brief with musts, wishes
  from whoever has a say (Sturlese's landscape rules are always wishes) and a ghost plan that meets every must and
  that the request's gathering and gifts pay for.
- **The terraces meter** (`location.json`, `cliffs/terraces.gd`): the meter reads "2 of 16 terraces" at the start.
  Serenza's check counts a terrace back in use once, for good, when something green grows on it and, for the seven
  terraces with a gap in their wall, the gap is closed (`Validate.sealed` across the breach); E5 and E6 when the
  monorail runs, W7 when the sanctuary path is open. Requests add 0 points themselves, so nothing counts twice; the
  flags (`cliffs_terrace_w3` and so on) are what the wall's request waits for. Milestones at 4, 6, 8, 10, 13 and 16.
- **Shops, items and clothes:** Nunzia's bar, Trenin's workshop, Capo Horn's boat and the cellar (after it reopens);
  lemons, wild greens, borage, saplings, three fish, six treats, three metal-detector finds and the hiking club's
  postcard; the straw hat, the white captain's cap and the espadrilles. Six lost things named for Serenza.
- **The place changing with the story** (`cliffs.gd` `WORLD_FLAGS`, `cliffs/life.gd`): the boats launched at the
  first dawn after the slipway's done ride at moorings in the harbour; the monorail's rail runs across the slip once
  it's mended and a cart climbs up and down it by day; the sanctuary bell rings when you pull its rope; a slate plaque
  goes up by the cellar door at sixteen terraces; the ferry calls once the finale is done.
- **Ground changed for the requests:** the mule path climbs to a landing on each side of the gully (the gully floor
  3 m below the upper one); the slip is level with E5, 2 m below E6; a low rock shelf under the church rocks, reached
  from the rock path, carries the steps down to Don Aurelio's pontoon. Every build site knows its own floor height
  (`floorY`), as the shared height limit is measured from it.
- **Paper, openings and naps:** Il Gabbiano's headlines, Marta's openings with slogans and her disposable camera, and
  two nap gags (the dawn train's horn, Sturlese asleep at the other end of the bench).
- **Changes from the plan:**
  - The hut is a ruin whose walls have tumbled to waist height: you roof it on two pillars, hang a door and light a
    lamp, then plant vines beside it. It isn't a room any more.
  - The vine pergola is green only. Shade, wherever a brief asks for it, is a roof on pillars, so the shared needs
    (shelter you can stand under) and the briefs agree.
  - The milestone at eight terraces gives three vine saplings and forty coins: your plot doesn't grow onto E3, which
    is an open build site from the start.
  - The hiking club appears in the finale's lines, not yet as people walking the terraces (stage 4).
  - A Shelter for the Last Train is offered once the hut is done, not after you first see Sturlese miss the train.
  - Trenin's rail runs straight across the slip rather than along the path you built.
  - Terraces don't yet change on the hillside when they come back (brambles cleared, walls mended): the meter and the
    toasts say so. That's stage 4, with the lizards.
  - Fishing spots stand on the edge (the square's quay, both sides of the breakwater, the beach) with the water in
    front, rather than out in the harbour where you couldn't reach them.
  - Tables for the Guests is built along the square's south edge, so nothing built there blocks the way from the
    square to the church; a test keeps every request's site off the routes villagers walk.
  - On Easter morning the villagers gather on the square beside the route, not on it, and each has a spot of their
    own, so you can walk through to Don Aurelio and talk to whoever you like.
- **Checked:**
  - **Tested** (`test_cliffs.gd`, 23 tests): stages 1 and 2's, plus the cast (homes and every routine on the nav
    graph, pronouns, topics, gifts, tastes, liked items that exist), the requests (thirteen, six main, givers and items
    that exist, the finale after the other five and opening Liolivato, four shops selling real things), every brief
    built from its ghost plan with the game's own placement rules and finished by it (and not finished before), the
    gathering paying for the plans, the wall needing both courses and the whole gap, the slip, the gully, the rocks
    and the slipway uncrossable before you build, terraces coming back on the meter (wall and green, green alone,
    flags, once each, never taken back, the readings and milestones), the boats' moorings, the plaque, the paper, the naps
    and the hangouts, fishing spots on the water's edge, and request sites that leave the villagers' routes open. Shared tests cover the new pieces, picking, `lower`, the meter hook and pack tastes.
  - **Played** (`play_cliffs.gd`, real input): see the stage 3 pull request.

**Stage 4, look and ambient life: built** (helpers `cliffs/animals.gd`, `cliffs/sounds.gd`, `cliffs/hikers.gd`).
- **No shared changes.** Everything uses what the game already has: the look block, a layout's `valley_fog` (here the
  sea fog), lamp posts, window glass lit at night, a location's music block and the place sounds.
- **The look** (`location.json`): a clear Mediterranean sky, a pale blue-grey haze along the coast, weather clear, fair,
  drizzle and mist, with fog on about one early morning in three (`mist` 0.3).
- **Sea fog** (layout `valley_fog`): fills the ravine up to the station (9.5 m): a little on any early morning, thick
  on a misty one, burning off by eleven, a wisp at night.
- **Night lights:** fifteen lamp posts along the station lane, the main street, the stair through the terraces, the
  square, the harbour and the church; the houses' windows; and windows lit in the next villages along the coast.
- **Terraces coming back on the hillside:** each terrace's brambles are a group of their own, gone the moment it comes
  back (from the meter's flag, without a rebuild) and left out of every rebuild after.
- **Animals** (`cliffs/animals.gd`): gulls on the boats (on their runners or afloat), the quay, the breakwater and the
  church ridge, flapping up when you come within 3 m and settling again after twenty seconds, and three wheeling over
  the sea; two wall lizards on each terrace's wall, out from nine to six only on terraces in use (four on W1 and E2
  when you arrive, twenty by Easter), darting away as you pass; swallows from six to eight over the harbour, the church
  tower and the station, four when you arrive and two more for each main request done, sixteen by the vote.
- **Hikers** (`cliffs/hikers.gd`): after the vote, eight walkers in red anoraks, boots and rucksacks walk a loop from
  the platform up the stair to the sanctuary, down the mule path, through the terraces to the square, out along the
  breakwater and back, from nine to five. They are only for looking at.
- **Music** (`location.json` `music`): sparse tunes in the game's own synthesiser: a flute dawn, a marimba morning
  (also for building), a clarinet afternoon, a Rhodes evening and a glockenspiel night; and a brighter Easter tune in
  the mornings from the resting place being built until the vote.
- **Sounds** (`cliffs/sounds.gd`): the sea, louder near the water and quiet up on the terraces; gulls crying over the
  harbour by day; every train's two-tone horn as it comes out of the tunnel, and its rumble while it's near; the
  monorail cart's engine once it runs; swallows twittering near where they fly. Church bells only for big moments: the
  sanctuary bell when you ring it, peals every quarter hour on Easter morning until the vote, and a long peal from the
  church and the sanctuary at the vote. No hourly bells.
- **Clothes:** Settimio wears his straw hat and Nunzia her espadrilles, the same ones they give you.
- **Changes from the plan:**
  - Drizzle instead of afternoon showers, as the shared weather has it.
  - Swallows wheel over three spots rather than nesting under the eaves.
  - The platform and the harbour square no longer ask you for light after dusk: their lamp posts light them. The
    church rocks and the sanctuary forecourt still do.
- **Checked:**
  - **Tested** (`test_cliffs.gd`, 31 tests): stages 1 to 3's, plus the lamp posts (on walkable ground, clear of every
    path, and no hangout with a lamp post asking for light), the sea fog's spec and the misty mornings, brambles hidden by a terrace's flag and cleared live by the flag
    event, the animals (hours, terraces in use, swallows growing with the main requests, every lizard on a wall face,
    every gull's seat above the water), the train horns (once per train, as it leaves the tunnel), the sea and the
    gulls by distance, the Easter peals, the hikers' loop (on the nav graph, through the sanctuary and the breakwater,
    only after the vote and by day, dressed for it), the music (a tune for each part of the day, real instruments,
    melodies that fit, the Easter tune and back) and the cast's clothes.
  - **Played** (`play_cliffs.gd`, real input): see the stage 4 pull request.
