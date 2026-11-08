# Liolivato: design for the olive village

Working id `olive_village`. Agreed with the user on 2026-11-08 in a design interview. **Stages 1 (ground and map) and 2 (buildings and
scenery) are built; stages 3 and 4 are not.** See "Build status" at the end. This doc is the plan the build stages follow. The rules every location shares are in `docs/WORLD.md`; `docs/MONTEFORCHETTA.md`
and `docs/locations/river_town.md` are the models this doc follows. Serenza (`docs/locations/cliffs.md`)
comes just before Liolivato, and the two were kept apart where they overlapped (see "Kept apart from Serenza"). Names,
amounts and step details can still change in the build; the choices marked *proposed* weren't asked about and are open
to review.

## The concept
Liolivato is a hill village in western Liguria, high above its own little fishing cove, in late spring, the year after
the euro came in. It is emptying. The young people left for the coast decades ago, the olive terraces are going back
to brambles, and the sign at the village entrance reads **38 inhabitants**. The Sindaco, who with so few people left is
also the barber, the sacristan and the keeper of the ferry timetable, is selling the empty houses for 1,000 lire each
to bring people back. He has never stopped calling them 1,000-lire houses, euro or no euro. So far the only buyers are
a German couple in sandals. He has written to the province for a Geometra.

You arrive on Sirena's ferry from Serenza. The cove's jetty has crumbled, so old Gambero wades out and carries you
ashore on his shoulders. The Sindaco is waiting on the pebbles in his timetable cap, walks you up through the terraces
and over the hump-backed bridge, and sells you a roofless wreck in the covered alleys from his barber's chair. You
spend your stay winning back the terraces, bringing water up to them and making houses fit to live in, and the story
ends with the first festa in years: a carpet of petals from the bridge to the piazza to welcome the band off the evening
ferry, and Rosa's son walking up it behind the band with his family, home to stay. The Sindaco repaints the sign:
**50**.

- **Feel:** a Ligurian hill village the way a Nintendo game would draw one. Whitewashed houses with bare stone corners
  and arches under curved terracotta roofs, stacked up a sunny spur; a church spire of glazed coloured tiles shining in
  the sun; cool covered alleys under the houses; silver olive terraces held up by dry-stone walls; yellow broom and red
  poppies on gold grass; and the sea far below, wide and hazy.
- **The running gag: the foreigners in sandals.** Klaus and Hannelore Wendt, a retired Munich schoolteacher and a keen
  amateur photographer, bought the house next to yours for 1,000 lire and love absolutely everything. Socks with
  sandals, a guidebook full of bookmarks, a photo of every crack. They want nothing fixed, because the cracks are
  "authentic". The villagers call them *i Sandali* (the Sandals), to their faces, and can't work out what they see in
  the place. Affectionate on both sides: the Sandals are the first people in thirty years to choose Liolivato.
- **Not here:** the old olive mill is out of the story (at most a roofless ruin by the torrent, as scenery). No olive
  harvest (it's late spring, and the olive trees are in flower). No procession (Serenza's finale has one). No boars
  (Monteforchetta's gag), no goats, no fog (Toriano's, and Serenza's sea fog).

## Ground rules for Liolivato
- **Size:** bigger and gentler than the other villages: about **180 m** across (`size` in the layout), mostly wide,
  open hillside you walk up rather than climb. Terraces are stepped ground; anything taller than the 0.45 m step has
  stairs or a ramp.
- **Season:** late spring, May into June. No dates.
- **Day:** **the clock never holds.** The user decided on 2026-11-08 that the clock should never hold at dusk, in any
  location (now a rule in `docs/WORLD.md`). Liolivato's `day` block is `{"regrow": "overnight", "hold": false}`: the
  night happens, sleeping ends the day, things regrow overnight, and the morning news and the inauguration work as
  everywhere.
- **Getting around:** the bicycle is allowed (no `"bikes": false`). You get off by yourself on stairs and in the covered
  alleys.
- **Money:** euros on screen, however Tonnarella's changeover left them (`docs/locations/port.md`, "The changeover");
  Liolivato adds no money code. Amounts are kept in the game's coins (one coin is 1,000 lire, about €0.52). Lines that
  name a sum in lire stay as written: the Sindaco's houses are "1,000-lire houses" in everything he says, the price
  prints as about €0.52, and he insists he's done the sums.
- **Language, names, originality, no magic:** as in `docs/WORLD.md`. Liolivato, its cove, its church and everyone in it
  are invented. Real places are inspiration only: the hill villages behind the western Riviera, with their olive
  terraces, covered alleys and medieval bridges.

## The place
North is up (negative z in the game). A mountain torrent runs down the middle of the map from north to south and into
the sea at the south edge. The village climbs a spur on the west bank. The olive terraces climb the east bank, and the
fishing cove is on the terraces' side of the torrent's mouth, so arriving means climbing through the terraces and
crossing the bridge into the village. Everyone crosses the bridge every day: it is the heart of the place.

Most of the map is high, open hillside. The cove is a small cluster at the very bottom, on rocks, so from the village
and the terraces you look down on a wide, hazy sea rather than along a harbour.

```text
                      N   chestnut ridges, then the Maritime Alps with the last snow
 +-------------------------------------------------------------------------------+
 | chestnut woods (chopping)          |~~|  chestnut woods (chopping)              |
 |      CASTLE ruin                   |~~|  FUCO'S HUT     broom terrace (hives)   |
 |   CHURCH, tiled spire              |~~|                                         |
 |   whitewashed houses on the spur   |~~|  ^ ^ ^ abandoned terraces ^ ^ ^         |
 |   COVERED ALLEYS (arches)          |~~|  brambles, poppies, broom               |
 |   PIAZZA: ROSA'S OSTERIA,          |~~|  THE FALLEN TERRACE                     |
 |   BARBER SHOP / TOWN HALL,         |~~|  BASTIAN'S TERRACES   ^ ^ ^ ^           |
 |   the empty house beside the bar   |~~|  BASTIAN'S FARMHOUSE   STONE TANK       |
 |   WASH-HOUSE (spring)              |~~|  vegetable rows, figs, basil            |
 |   YOUR HOUSE | THE SANDALS' HOUSE  |~~|          stepped mule track  /          |
 |   their terrace     sign: 38 ======BRIDGE=====  cart track, hairpins          |
 |   pines, holm oak, scrub           |~~|  (waterwheel site below the bridge)     |
 |   rocks, falling away               \~~\   GAMBERO'S STEPS (collapsed flight)   |
 |                                      \~~\  THE COVE: SIRENA'S COTTAGE,         |
 |                                       \~~\ GAMBERO'S BOATHOUSE, boats, rocks   |
 | ~~~~~~~~~~~~~~ rocks ~~~~~~~~~ pebble cove ~~~ JETTY ~~~~~~~~~~~~~~~~~~~~~~~~~~ |
 +-------------------------------------------------------------------------------+
           the sea, far below and wide: a hazy coast along it, Serenza's headland to one side
```

| Area | What's there |
| --- | --- |
| The village (west bank) | Whitewashed houses with bare stone corners, stone arches and curved terracotta roofs, stacked up the spur. **The ruined castle** on top: bare stone walls and a broken tower, with a view over everything. Below it **the church**, whose bell tower ends in a spire of glazed green, yellow and white tiles, seen from every terrace. **The covered alleys:** narrow stepped lanes running under the houses, with arches between the walls, cool and dark even at noon, opening onto **the piazza** with Rosa's osteria and the Sindaco's barber shop, which is also the town hall. The empty house beside the osteria. **The wash-house:** stone basins under a terracotta roof on stone pillars, fed by the spring that is the village's water. Your house and the Sandals' next door, sharing a wall, with the Sandals' terrace looking south over the sea far below. |
| The bridge | The old hump-backed stone bridge over the torrent: one tall arch, a cobbled hump, low parapets. **The population sign** stands at its village end. |
| The torrent | Clear water rushing over grey boulders in a small gorge, with pools under the bridge. Fast enough below the bridge to turn a waterwheel. |
| The terraces (east bank) | Olive terraces held up by dry-stone walls on gold grass, climbing to the chestnut woods on the ridge. **Bastian's terraces** are the last ones still worked, with his farmhouse, his vegetable rows (artichokes, broad beans, courgettes), basil, figs growing out of old walls and **the old stone tank**, dry. Above them **the fallen terrace**, the best one, whose wall came down in the winter rain. Higher up, **abandoned terraces** choked with brambles, red with poppies and yellow with broom, and **the broom terrace** below the woods, where Fuco keeps his bees beside his hut. |
| The way up | A **gravel cart track** zigzags up the east bank from the cove to the bridge in gentle hairpins (rideable). **The stepped mule track** cuts straight up through the terraces, a shortcut on stone steps. One flight of it has collapsed (Gambero's steps). |
| The cove | A small cluster at the very bottom of the map: **Sirena's cottage** and **Gambero's boathouse**, whitewashed stone like the village, wooden boats pulled up on the pebbles, nets drying on the rocks, and **the crumbled jetty**, a stump of stones the ferry can't tie up to. The departure point. |
| The horizon | South: the open sea, seen from high above, wide and hazy, with a coast running away along it and Serenza's headland far off to one side. North, behind the village: ridges of chestnut woods, then the Maritime Alps with the last snow on their peaks. Other villages perched on the ridges. |

## Getting there and around
- **Arrival by ferry.** The travel order is Monteforchetta, Boccapioppo, Casalrana, Toriano, Tonnarella, Serenza,
  Liolivato. Serenza's finale sets `olive_village_revealed`, the flag Liolivato's map entry reveals on, and opens
  Serenza's ferry landing at the end of its breakwater (`cliffs_ferry`, "Take the ferry"), where Sirena's ferry starts
  calling. Sirena's ferry brings you from there. Once Liolivato is unlocked, the ferry from Tonnarella calls here too. Since any revealed place can be reached from any departure
  point, the shared travel map needs nothing new for this; the ferry line is how the places describe it.
- **The departure point** is the jetty: a feature of kind `boat` with `depart_label` "Take the ferry". Until the jetty
  is rebuilt the ferry stands off the cove and Gambero carries people to and from it on his shoulders.
- **Until it's revealed** Liolivato stays off the travel map. Tests reach it with `--island=olive_village`.
- **Inside the village** you walk or ride. The cart track is the gentle way up from the cove, the mule track the short,
  steep one. No other transport.

## The population sign: Liolivato's progress meter
The sign at the village end of the bridge replaces the Sindaco's approval rating here. Every request you finish makes
someone decide to stay or come back, and the Sindaco, in his mayor's cap, repaints the number himself with ceremony.
It's the shared location meter (`LocationMeter`): points count up from 0 and read as inhabitants
(`"display": {"from": 38, "per_point": 1, "format": "%d inhabitants"}`).

- **Starts at 38.** You are the first newcomer: signing for your house makes it **39**, on the spot.
- The jetty, the water, the terrace and your roof add **1** each (43). The three side requests add **1** each (46). The
  finale's family adds **4** (50). Returned lost things add nothing: you can't count half a person.
- Reaching 50 needs everything, the finale included. Without the side requests the sign stops at 47.

| Sign | Points | Milestone | Reward |
| --- | --- | --- | --- |
| 40 | 2 | "Forty. The last time we were forty, there was a war on." | A strip of terrace below your house to build on (`olive_village_plot`) |
| 43 | 5 | "Forty-three, and two of them are German." | The beehive plans (Fuco then asks for help with his swarm), and the plot grows |
| 46 | 8 | "We'll need a second card table." | An old olive tree of your own on your terrace, with your name on a tag |
| 50 | 12 | "Fifty. Fetch the good paint." | A free haircut for life, and a fifth cap for the Sindaco's rack with "Geometra" on it. Needs the finale. |

Plans you already own from earlier places are not given twice. The milestone lines are *proposed*.

## The cast
Ten villagers, plus Rosa's son's family at the finale. Ids are `olive_village_<first name>`, for example
`olive_village_giobatta`.

| Who | Where | Who they are |
| --- | --- | --- |
| **Sindaco Giobatta "Milmestieri" Orengo** | Everywhere: the jetty at ferry times, the church, the barber shop, the town hall | The mayor of everything. With 38 people there's no one else to do the jobs, so he is also the barber, the sacristan and the keeper of the ferry timetable, and changes caps for each ("Milmestieri" means a thousand trades). Rings the church bells a few minutes late because he's cutting someone's hair. Behind the 1,000-lire houses and the sign, which he repaints himself. Meets you, sells you the house and gives the finale. |
| **Klaus Wendt** | The mule tracks, the bridge, his house | One of the Sandals. A retired Munich schoolteacher with a guidebook full of underlinings, who has mapped every mule track and walks them daily. Finds everything wonderful and wants nothing fixed. |
| **Hannelore Wendt** | Wherever there's a crack in a wall | The other Sandal. A keen amateur photographer who photographs every stone, every crack and you, asleep on a bench. Her photos of cracks cover the walls of their spotless house. |
| **Barba Bastian "Ulivo" Ramella** | His terraces and farmhouse | The last olive farmer, as old and twisted as his trees ("Ulivo" means olive tree). Still works his terraces alone, talks to his trees and is sure nobody else knows how to prune one. Gives the water and the fallen terrace. |
| **Nonna Gina Moraldo** | The wash-house, the church steps, the piazza bench | One of the wash-house nonnas: the village's news service. Gina does the talking. |
| **Nonna Delia Cassini** | Always beside Gina | The other wash-house nonna. Delia does the judging, out loud, of everything you build. |
| **Rosangela "la Rosa" Ardoino** | Her osteria on the piazza | Runs the only osteria (bar and kitchen) with its card tables, payphone and boxy TV, and is the first to notice when someone new stays. Her son Davide left for Tonnarella's docks ten years ago, and she still sets a place for him every Sunday. |
| **Giacomo "Gambero" Viale** | His boathouse and boat at the cove; the osteria's card game in the afternoon | The old fisherman. Mends nets on the rocks, carries ferry passengers ashore on his shoulders while the jetty is broken, and walks the mule track up every afternoon for the card game, backwards downhill to save his knees ("Gambero" means shrimp). |
| **Comandante Marisa "Sirena" Novaro** | The ferry and the jetty at ferry times; her cottage at the cove | The ferry skipper on the line between Serenza, Liolivato and Tonnarella. Toots her foghorn for everyone she knows, which is everyone ("Sirena" is the siren, and the horn). Brings news and parcels from the coast. Gives the jetty. |
| **Ilario "Fuco" Anfossi** | His hives and hut on the broom terrace | The beekeeper. Swears his bees know who's going to stay in the village. The village calls him "Fuco", the drone bee, because he naps among his hives. Sells honey. |
| **Davide, Chiara, Luca and Sara Ardoino** | The finale, then the house beside the osteria | Rosa's son, his wife and their two small children, who come on the festa's evening ferry and stay. |
| **The player** | | The Geometra, arriving from Serenza. Buys a house for 1,000 lire. |

## Gathering
As everywhere, gathering counts what's in the bag: a request asks for the total it needs.

| Material | Where it comes from |
| --- | --- |
| Wood | Chopping chestnut trees in the woods on the ridge (the chopping minigame). Olive trees are never felled: their spring prunings lie in heaps on the terraces and give a little wood as kindling. |
| Stone | The grey local stone of the terrace walls: quarrying the rubble of fallen terraces and an old quarry face (the quarrying minigame). The Sindaco also sells slate slabs, the Ligurian stone for steps, sills and basins. |
| Metal, copper wire | The Sindaco's everything shop. |
| Fabric | Old sailcloth from Gambero. |
| Basil (`olive_village_basil`) | From the pots on the alley steps and the rows on Bastian's terraces. Rosa buys it for her pesto. |
| Flowers | Yellow broom on the hillsides, red poppies on the abandoned terraces, pink wild roses and white daisies. Each gives a petal colour for the finale's carpet, and they make gifts. Fuco buys them. |
| Brambles | The abandoned terraces are choked with brambles. Clearing a patch (a short chopping-style minigame) gives a little wood, sometimes turns up a lost thing, and opens that terrace to build on or plant. Cleared patches stay cleared. |
| Fish | From the jetty and the rocks: red mullet, scorpionfish, cuttlefish and, rarely, a moray eel, plus junk such as a flip-flop, a sunken deckchair and a German guidebook. Ids like `olive_village_mullet`. No anchovies: night fishing under a lamp is Tonnarella's. |
| Lost things | Eight in all (the shared lost things). Half are the villagers' mislaid things: the Sindaco's fourth cap, Klaus's guidebook, Bastian's pruning knife, Sirena's binoculars. Half turn up under the brambles on abandoned terraces: things people left behind when they moved away, which you take to whoever remembers them. A key to a house nobody lives in (Gina's sister's), a 1960s transistor radio (Gambero danced to it at the 1962 festa), an old postcard from Tonnarella (Delia's), and a child's tin boat (Davide's, which Rosa puts on her counter). Thanks and gossip, no inhabitants. The owners are *proposed*. |
| Treats | At Rosa's osteria: **sardenaira** (a thick, soft pizza with tomato, anchovies, olives and garlic), **stuffed vegetables** (courgettes, onions and peppers baked with a filling), **farinata** (a thin chickpea pancake from the wood oven), and **fresh broad beans with sharp sheep's cheese**. |

## Shops
| Shop | Sells | Buys |
| --- | --- | --- |
| Rosa's osteria | The four treats | Basil, fish |
| The Sindaco's everything shop (the barber shop, also the hardware store, tobacconist and town hall) | Metal, copper wire, slate, building plans, sold between haircuts in the right cap for each | |
| Fuco's honey (a table by his hives) | Jars of broom honey and chestnut honey, beeswax candles | Flowers |
| Gambero's nets (on the rocks at the cove) | Bait, a better fishing rod, old sailcloth | Sea junk |

## Requests
Ids are `olive_village_<name>`. Building steps are briefs with checks (`docs/DESIGN.md`): a site, two or three musts,
and wishes from whoever has a say. Anything that meets the musts passes, and every building step has a ghost plan
(`plan`) that works. Requests end where their last real step happens. Amounts are the plan and can change.

### Main story
| # | Request | Given by | What you do |
| --- | --- | --- | --- |
| 1 | **Welcome to Liolivato** | The Sindaco | Gambero carries you ashore from the ferry. The Sindaco, in his timetable cap, walks you up the mule track through the terraces, over the bridge and into the alleys, changing caps on the way: that's the tour, and you can skip ahead. In the barber shop he sells you the house for 1,000 lire (you sign in the barber's chair, with a haircut you didn't ask for) and repaints the sign: **39**. Gather a little chestnut wood and terrace stone, then see your house: a roofless wreck sharing a wall with the Sandals' spotless one. Klaus and Hannelore introduce themselves. You sleep on a bench until you have a roof and a bed. |
| 2 | **The Jetty** | Sirena | Gather wood and stone, then rebuild the jetty from the shore out to the mooring in deep water. Musts: a walkable path from the shore to the mooring (`path:olive_village_jetty`, any continuous, supported path counts), and a light at the end, lit at night. Wishes: a bench at the end to fish from (Gambero), painted white and blue (Sirena). It ends with the evening ferry tying up for the first time in years: Sirena toots, steps ashore dry, and Gambero is a little sad to lose his piggybacks. |
| 3 | **Water for the Terraces** | Bastian | His stone tank is dry and his vegetable rows and grafted saplings are thirsty. Gather wood, metal and copper wire, then build a waterwheel in the torrent below the bridge, carry its power to a pump and run pipes up the terraces to the tank (`fed:olive_village_tank`). Wishes: the wheel in wood, because it's authentic (Klaus), flowers by the wheel (Gina). It ends at the tank as it fills and Bastian waters his rows. |
| 4 | **The Fallen Terrace** | Bastian, with the nonnas judging | The best terrace's dry-stone wall came down in the winter rain. Quarry the rubble for stone, then rebuild the wall along the terrace edge with no gap (`sealed:olive_village_wall`) and add steps up onto the terrace (`path:olive_village_terrace`, up stairs). Wishes: all in stone (Delia), a young olive tree planted on top (Bastian). Gina and Delia come up to inspect, and Delia's verdict is the highest praise in Liolivato: "It could have gone worse." |
| 5 | **A Roof for 1,000 Lire** | The Sindaco | Make your wreck a home: walls, a door and a roof (a room checklist), then a bed (120,000 lire, about €62 on screen, so you nap on benches until you've saved up). The Sandals' wish: keep the old crooked wall standing, because it's authentic (the ruined wall is a placed piece you could knock down; while it stands, the wish is met). Rosa's wish: flowers at the window. |
| 6 | **The Festa**, the finale | The Sindaco, with a quiet favour for Rosa | The village festa, the first in years. **Just in case:** Rosa asks you quietly to make the empty house beside the osteria ready: beds for a family, a table and a lamp. She pays for the beds from ten years of savings. She doesn't know anyone is coming, and neither do you. **The petal carpet:** gather flowers, then lay a carpet of petal tiles from the village end of the bridge up through the covered alleys to the piazza, with no gap (a path over petal tiles only), to welcome the band. Wishes: at least three colours (Gina), candles along it (Fuco). **The piazza:** tables and seats for the village, lit after dark. **The evening:** the ferry brings the brass band from Tonnarella. They march up from the cove, over the bridge and up your carpet to the piazza, and walking up it behind them come Davide, Chiara and the children. Rosa sees them from her door. The band plays, the village dances under your lights, and the Sindaco repaints the sign: **50**. |

### Side requests
| Request | Given by | What you do |
| --- | --- | --- |
| **The Sandals' Sunset** | Klaus and Hannelore | On their terrace, a place to watch the sunset over the sea. Musts: a seat, a roof over it, and the sea in view from the seat (the new view check). Wish: nothing that looks new, all wood and stone (Klaus). It ends at sunset with the two of them on the seat, and Hannelore photographing you. |
| **Fuco's Swarm** | Fuco, with the Sindaco | Opens at 43 inhabitants, with the beehive plans. A swarm of Fuco's bees has settled in the bell tower, and the Sindaco, as sacristan, can't ring the bells. Build hives on the broom terrace (musts: three hives, flowers beside them; wish: shelter from the breeze). Then, at dawn while the bees are calm, Fuco hands you a box on a pole: take the swarm down from the bell tower's lowest window (a gathering spot with `hours`) and carry it to the hives. The bells ring again, a few minutes late. |
| **Gambero's Steps** | Gambero | A flight of the mule track has collapsed, so Gambero has to go the long way round by the cart track and misses the start of the card game. Rebuild it so you can walk all the way up (`path:olive_village_steps`, up stairs). Wishes: a bench halfway for his knees (Gambero), in stone (Delia). It ends at the osteria's card table, where he arrives on time for once. |

Six main and three side requests, plus eight lost things.

## Rooms you can walk into
- **Your house:** a roofless wreck at first, then your home. The crooked old wall stays if you let it.
- **Rosa's osteria:** card tables, the counter, the payphone, football on a boxy TV. Rosa works behind the counter.
- **The Sindaco's barber shop and town hall:** the barber's chair, a desk with the town seal, the rack of caps, the
  ferry timetable on the wall.
- **The Sandals' house:** spotless, with Hannelore's photos of cracks on every wall and Klaus's maps of mule tracks.
- **Gambero's boathouse:** nets, oars, a stove and an old radio playing the shipping forecast.
- **The church:** pews, the altar and the bell ropes the Sindaco pulls as sacristan.
- **Bastian's farmhouse:** his kitchen, his tools hung in rows, and a calendar from 1987.
- **The empty house beside the osteria:** bare until the finale's favour, then Davide's family's home.
- Not the castle (open ruins you walk round), the wash-house (open-sided, you walk under its roof) or Fuco's hut.

## Look
- **Buildings:** whitewash and stone, everywhere, the cove included. Lime-washed white walls, gone warm and patchy with
  age, with bare stone at the corners, round the doors and in the arches, under curved terracotta roof tiles. Weathered
  green shutters. No pastel and no painted window frames: those are Serenza's. The church's glazed tiled spire is the
  one bright colour among the buildings. The castle ruin, the bridge, the wash-house pillars and the terrace walls in
  bare grey stone.
- **Palette** (*proposed*): whitewash `#f1ece0` and its shade `#ddd5c4`, stone `#a39a8a` and dark stone `#6f6a62`,
  terracotta roofs `#b8643c`, shutters `#5d7a5a`, spire tiles green `#2f7d5b`, yellow `#e2b93b` and white `#f4f1ea`,
  olive leaves `#9aa58f` with silver undersides `#c9cfc0`, broom `#f2c41c`, poppies `#d63a2a`, gold grass `#cdb36b`,
  sea `#2f7fa6`.
- **Plants:** silver, yellow and red. Silver-grey olive trees with gnarled trunks on the terraces, in flower; yellow
  broom blazing on the hillsides; red poppies on the abandoned terraces; all over grass turning gold. Brambles choke the
  highest terraces. Climbing roses over a few doors and arches, pots of basil on every step of the alleys, figs growing
  out of old walls, vegetable rows with artichokes, broad beans and courgettes on the lower terraces. Maritime pines,
  holm oaks and fragrant scrub on the slopes round the cove; chestnut woods on the ridge. No lemons, wisteria or
  geraniums: those are Serenza's.
- **Ground:** dry-stone walls along every terrace, pale earth and gold grass on the terraces, stone steps and cobbles in
  the alleys, gravel on the cart track, grey boulders in the torrent, rocks and pebbles at the cove.
- **Water:** the clear, quick torrent over grey stone; the sea seen from high above, deep blue and wide, with a soft
  haze over it in the mornings.
- **Animals:** cats asleep on every warm step and waiting for Gambero's catch; lizards darting over the dry-stone
  walls; swifts wheeling round the bell tower and the castle; gulls on the jetty posts and the boats.
- **Light:** golden afternoons. A warm golden grade most of the day, long shadows across the terraces, still air. A
  soft haze on the sea in the mornings. **Fireflies** over the olive terraces at night, since late spring is their
  season, and the clock never holds, so you see them.
- **Weather:** mostly clear and still; now and then a warm spring shower.
- **The sea from above:** if the shared camera makes the terraces read as flat ground with the sea out of frame, a
  gentle tilt toward the sea there is the smallest general hook (a per-area camera pitch in the layout), named on that
  pull request.
- **The look block** (`location.json`, *proposed*): warm golden highlights, soft warm shadows, less wind than
  Monteforchetta (the olives barely stir), fireflies and a few motes, no falling leaves (pale petals instead,
  `leafColors`). The layout's `horizon` takes the Alps; the sea, the coast and the perched villages are location
  scenery.

## Sound
- **Music:** original, in the game's procedural music system, with a theme for each part of the day (dawn, morning,
  afternoon, evening and night). Acoustic guitar and mandolin with a soft accordion, in the style of a Ligurian
  singer-songwriter: a slow dawn, a sunny walking tune in the morning, a lazy afternoon, an evening serenade, a quiet
  night. The festa has the village brass band, marching up from the ferry with its own tune. The mandolin and the brass
  are new synth voices (below).
- **Sounds:**
  - **Sea and torrent:** waves dragging on the pebbles at the cove, and the torrent rushing under the bridge, louder as
    you get close, so you can tell by ear where you are.
  - **Bells, rung late:** the church bells, rung by the Sindaco a few minutes late. Silent while Fuco's swarm is in the
    tower.
  - **Swifts and bees:** swifts screaming round the bell tower in the evening, bees humming in the broom by day,
    crickets at night.
  - **Sirena's horn:** the ferry's foghorn as it comes and goes, and a short toot for everyone she knows.

## Bench naps
Every day ends with a nap on a bench until you own a bed, and Liolivato has its own wake-ups (a `naps` block in the
layout): a free haircut (the Sindaco was passing with his scissors and couldn't resist); Hannelore's camera clicking,
"authentic village life" (a sight gag with no line); a cat that has slept on your chest all night and won't move; and a
gull flying off with the farinata you'd saved for breakfast.

## The morning news
There's no newspaper in a village of 38. The morning news is Nonna Gina and Nonna Delia at the wash-house: Gina tells
yesterday's build (the headline), and Delia gives the grade. It is the shared morning paper with Liolivato's own name
and lines, set by the layout's `paper` and `naps` blocks, so it needs no shared change.

## Kept apart from Serenza
Serenza is also a Ligurian village of terraces and dry-stone walls, and it comes just before Liolivato. The user asked
for the two to look very different, and for these changes:

| | Serenza | Liolivato |
| --- | --- | --- |
| Buildings | Pastel plaster, painted window frames, grey slate roofs | Whitewash and bare stone, terracotta roofs, no painted frames |
| Plants | Wisteria, geraniums, lemons, vine pergolas | Silver olives, yellow broom, red poppies on gold grass; basil in pots |
| Light | Bright spring, showers, morning sea fog | Golden afternoons, still air, a soft haze; fireflies |
| The sea | A tiny harbour at eye level at the foot of a ravine | Seen from high above, wide and hazy; the cove is a small cluster at the bottom |
| Finale | The Easter procession over a bridge you built | No procession: a petal carpet to welcome the band and Rosa's son |
| Food | Wild greens, borage, the Easter pie | Basil for pesto, stuffed vegetables |
| Fish | Bream, grey mullet, octopus | Red mullet, scorpionfish, cuttlefish, a moray eel |
| Getting around | No bicycles | Bicycles allowed |

## Changes to shared code this needs
Each is the smallest general version, comes with a test, and is named at the top of the pull request that makes it.

| Change | Why | Stage |
| --- | --- | --- |
| **A petal-carpet piece** (agreed with the user): a flat tile in the colours of the flowers you gathered, walkable, costing flowers | The festa's carpet; any location's festa can use it | 3 |
| **A beehive piece** (agreed with the user): a wooden hive | Fuco's swarm; anyone can keep bees | 3 |
| **A path over given pieces only:** the `path` check takes an optional list of pieces the path must run over (`"on": [...]`) | A carpet with no gaps from the bridge to the piazza; also rug runners or a red carpet | 3 |
| **A view check:** nothing solid stands between a piece on the site (a seat) and a target point | The Sandals' sea view; reusable ("the statue can be seen from the piazza") | 3 |
| **Two new synth voices** in `AudioDirector`: a tremolo-plucked mandolin and a brass section (trumpet and tuba) | The music and the festa's band; any location can use them | 4 |
| **Tastes from a location pack**, if the shared `tastes.json` can't take them the way Boccapioppo's did | The cast's tastes | 3 |
| **A per-area camera pitch**, only if the terraces don't show the sea without it | The sea seen from above | 4 |

Already in the game and reused as they are: a location's own meter (`LocationMeter`), the zone path and sealed checks,
water and power reaching a target (`fed:`), room checklists, fishing catches per location (`fish`), lost things per
location (`lost`), gathering spots with `gives` and `hours`, a request's own weather, `WORLD_FLAGS` for a place that
changes with the story, the bicycle, benches and nap blocks, the morning paper's lines per layout, the work day without
a hold, the money display after Tonnarella's changeover, and the ride and departure features.

Everything else lives in Liolivato's own files (`docs/WORLD.md`): `godot/data/locations/olive_village/`,
`godot/scripts/locations/olive_village.gd` with helpers in `godot/scripts/locations/olive_village/`,
`godot/tests/test_olive_village.gd` and `godot/tests/play_olive_village.gd`. The jetty the ferry ties up to, the tank
filling, the bells falling silent and ringing again, the petal carpet's colours, the empty house becoming a home and
the repainted sign are location code.

## Build stages
One pull request per stage. Each keeps the game playable and the tests passing.

1. **Ground and map.**
   - The ground shape in `olive_village.gd`: the spur, the torrent's gorge with flowing-water cells below the bridge,
     the east bank's terraces as stepped ground with stairs and ramps, the cart track's hairpins, the rocky cove and
     the sea.
   - The layout: spawn on the pebbles of the cove, the departure point at the jetty, the nav graph, paths, build zones
     (the jetty, the waterwheel site, the tank, the fallen terrace, your house, the Sandals' terrace, the broom terrace,
     the collapsed steps, the carpet's route, the piazza, the empty house), resource nodes and benches.
   - A hidden map entry revealed on `olive_village_revealed`, the meter and a first `look` in `location.json`, with
     `"day": {"regrow": "overnight", "hold": false}`.
   - Plain boxes for the buildings so the map reads in screenshots.
   - `test_olive_village.gd`: a playable world (the arrival is walkable, every nav spot is reachable, the bridge links
     the banks, water in the torrent and the sea, build zones where they should be, the cove reachable by the cart
     track, and by the mule track once the steps are rebuilt).
2. **Buildings and scenery.**
   - Models for the whitewashed houses and terracotta roofs, the covered alleys and their arches, the church and its
     tiled spire, the castle ruin, the wash-house, the osteria, the barber shop, Sirena's cottage, Gambero's boathouse,
     Bastian's farmhouse, Fuco's hut, the stone tank, the population sign, the crumbled jetty and the ferry; the
     hump-backed bridge.
   - Rooms you can walk into, with furniture and routes.
   - Olives, broom, poppies, brambles, climbing roses, basil pots, figs, pines and scrub, chestnuts; the sea from
     above, the coast, the Alps and the perched villages on the horizon.
3. **People, dialogue and requests.**
   - The ten villagers with routines (the Sindaco changing caps between his jobs), greetings, topics, gifts and tastes;
     Davide's family for the finale.
   - The nine requests, the four shops, Liolivato's materials, fish and treats, the lost things, the population sign,
     the bench naps and the morning news.
   - The shared changes listed above for this stage.
   - `play_olive_village.gd`: a scripted playthrough of every request with real input, starting as if the player had
     reached Liolivato (`arrive_as_if_played([...])` with every place before it on the travel order, Serenza's once it
     exists) and playing only Liolivato. It joins `test_plans`' `PLACES` so the ghost plans are checked.
4. **Look and ambient life.**
   - Tuning the look block, the golden grade, the sea haze, the fireflies, the petals, and the camera over the sea.
   - Cats, lizards, swifts and gulls; the ferry coming and going.
   - The guitar-and-mandolin themes and the brass band, the sea, torrent, bell, bird, bee and horn sounds; the cast's
     outfits.

## Agreements needed with other sessions
- **Serenza (`cliffs`):** agreed with that session. Serenza's finale sets `olive_village_revealed`, which Liolivato's
  map entry reveals on, and opens Serenza's ferry landing (`cliffs_ferry`) for the ferry to Liolivato; both are in
  Serenza's files (`docs/locations/cliffs.md`).
- **Tonnarella (`port`):** its ferry calls at Liolivato once Liolivato is unlocked (a description only: the travel map
  already links every revealed place). Prices show however Tonnarella's changeover left them.
- **Everyone:** the clock never holds (`docs/WORLD.md`). Monteforchetta still holds today (the `day` block in
  `godot/data/islands.json`, and `WorkDay.holds` defaults to true when `hold` is missing); that change is its owner's.

## Risks
- **Steep ground.** The spur and the terraces need many level changes. Anything over the 0.45 m step needs stairs or a
  ramp, and the bike gets off on stairs. Gentle slopes and the cart track keep it rideable.
- **The bridge.** The hump-backed bridge has to be a walkable floor between the banks, and the band and the villagers
  walk over it to the carpet.
- **The covered alleys** are narrow and roofed, so the camera needs care there, as it does indoors, and the carpet's
  path check has to follow them.
- **Shared changes in parallel.** Serenza and Tonnarella add shared pieces and checks of their own. Merging main often
  keeps them from colliding.

## Proposed, not asked
Choices this doc makes that the interview didn't cover. Change any of them in review.
- **Tastes:** the Sindaco likes signs, enamel signs, statues and streetlights, and red; Klaus stone arches, columns and
  stone blocks (anything old), and terracotta; Hannelore paintings, flower beds and lamps (good light for photos), and
  sea blue; Bastian trees, fences and garden paths, and olive green; Gina benches and flower beds, and white; Delia
  stairs and railings (things that hold you up), and black; Rosa tables, chairs, counters and lamps, and rose pink;
  Gambero benches, railings and lanterns, and navy; Sirena signposts and streetlights, and white; Fuco flower beds,
  hedges and beehives, and broom yellow.
- **Hangouts** (where needs show): the piazza, the wash-house, the top of the bridge, the jetty, the church steps and
  the osteria door.
- **Homes:** the Sindaco above the barber shop, the Sandals next to you, Bastian in his farmhouse, the nonnas in the
  alleys, Rosa above the osteria, Gambero in his boathouse, Sirena in her cottage at the cove, Fuco in his hut.
- **Outfits** (stage 4): the Sindaco in a white barber's jacket and a cap for each job (a peaked timetable cap, a black
  sacristan's beret, a white barber's cap, the mayor's sash); Klaus in socks and sandals, khaki shorts and a sunhat;
  Hannelore in a straw hat and linen dress with a camera round her neck, socks and sandals too; Bastian in a flat cap and
  patched waistcoat with a pruning knife on his belt; Gina in a flowered housecoat and headscarf with a basket of
  washing; Delia in a black dress and cardigan with spectacles on a chain; Rosa in a red cardigan and apron with a pencil
  in her bun; Gambero in a striped top, rolled trousers and a woollen cap; Sirena in a navy skipper's jacket and cap;
  Fuco in white overalls with his veiled hat pushed back; Davide's family in city clothes from Tonnarella.
- **The fish**, the milestone lines, the lost things' owners and the palette above.
- **The festa's saint** is left unnamed ("the village festa") until the user picks one.
- **Two near-repeats to look at in review:** Tonnarella has a fishmonger called Giobatta "Baciccia" Parodi, two places
  before the Sindaco Giobatta Orengo; and Tonnarella's bench naps include a gull taking your focaccia, close to
  Liolivato's gull taking your farinata.

## Build status
What exists now, and the choices made while building that the design above didn't settle.

**Stage 1, the ground and the map:**
- **Where it lives:** the ground shape, its colours, the stream cells, plain-box buildings, the bridge and the far
  hills are code in `godot/scripts/locations/olive_village.gd`; the map is `godot/data/locations/olive_village/layout.json`
  and the travel-map entry `location.json`.
- **Size and height:** 180 m square. The game's water lies at one level, so the torrent runs at sea level in a gorge
  about 8 m deep at the bridge. The village spur climbs from 8.3 m at the bridge to 13.8 m at the piazza and 26.6 m at
  the castle; the east bank climbs from the cove to about 30 m at the chestnut woods.
- **The edges:** the sea along the south, a gully with a stream down the west and the east edges, and a rock crag along
  the north ridge keep you on the map. Beyond them the location draws far hills that fall to the coast in the south.
- **The terraces:** on the east bank, level treads 1.8 m apart follow the contours, too tall to step or jump up. The
  cart track (a smooth gravel slope with hairpins, rideable), the stepped mule track and two paths not in the design
  cut across them: **a terrace path** of stone steps from the bridge north to Fuco's hut, and **a farm lane** to
  Bastian's farmhouse. Their edges ease into the treads, so you can step off onto a terrace from any of them.
- **The fallen terrace:** a 12 m stretch where the wall has slumped into a slope of rubble you can scramble up, with
  the wall standing either side. Since the rubble already lets you up, stage 3 is likely to check for steps as pieces
  rather than as a path.
- **Gambero's steps:** one flight of the mule track (between z 29.5 and 33.5) is gone, and its riser can't be climbed;
  the cart track is the long way round.
- **Below the bridge:** a level stone shelf at 0.25 m runs right to the torrent's edge, so a pump there sits beside a
  waterwheel in flowing water. A ramp climbs from it to the old tank's level ground, gentle enough for pipes (no more
  than 0.7 m a cell). The tank's inlet is a machine target, `olive_village_tank`.
- **The bridge:** two ramps and a crown of raised floors (the layout's `floors`) with parapets, the torrent flowing
  beneath, crowned at 9.9 m. For now it is drawn as stone slabs, parapets and two piers.
- **The village:** buildings stand on level ground cut into the slope (the piazza, Rosa's osteria, the empty house and
  the barber shop all at 13.8 m), with slopes between. Nonna Gina's house moved west to keep your plot level.
- **Buildings** are plain boxes: whitewash with a terracotta roof slab, the church with a green-capped tower, the
  castle's broken tower, Fuco's stone hut and the tank. Your house is a plot framed by ruined walls.
- **Build sites:** the jetty (from the pebbles out into the sea), below the bridge (waterwheel, pump, pipes and the
  tank's inlet), the fallen terrace, your house (opens with Welcome to Liolivato), your terrace (opens at 40
  inhabitants and grows at 43), the Sandals' terrace, the broom terrace, Gambero's steps, the way from the bridge to the
  piazza, and the piazza (an open site).
- **Gathering:** eight chestnut trees in the woods on both ridges, six stone spots (rubble at the fallen terrace and on
  the abandoned terraces, an old quarry face on the west flank), five flower spots and three fishing spots at the cove.
  Brambles, basil and Liolivato's own fish come with stage 3.
- **Benches:** on the piazza, at the bridge's east end, at the cove, on the church square and by the castle.
- **The map entry** stays hidden until `olive_village_revealed`. The day never holds. The population sign reads 38
  inhabitants and has its first two milestones (your terrace at 40, growing at 43); the olive tree at 46 and the
  honours at 50 come with stage 3, with the rewards they need. A first golden look; the weather is clear, fair or a
  drizzle.
- **Checked:**
  - **Tested** (`test_olive_village`, 6 tests): the pack and its map entry; the ground's shape; the map's bounds and
    the bridge as the only way across (the torrent is water from the crag to the sea); every nav edge walked both ways
    with real collisions; every building on level ground; the build sites fit their jobs (the jetty reaches the sea,
    the shelf meets flowing water, pipes can climb to the tank, Gambero's flight can't be climbed, the rubble can).
  - **Played** (`play_olive_village`, 14 checks), starting as if the earlier places' main stories were done: from the
    pebbles up the cart track's hairpins, over the bridge's crown at 9.9 m, up to the piazza, the church and the
    castle, back over to Bastian's farmhouse, up the fallen terrace's rubble, along the terrace path to the broom
    terrace and Fuco's hut, down the ramp to the shelf by the torrent, to the lower mule track (the collapsed flight
    stops you) and back to the beach (the sea stops you). Screenshots in both renderers.
  - **Not checked:** riding the cart track on the bicycle (it is a smooth slope, but no playthrough rides it).

**Stage 2, the buildings and scenery:**
- **Where it lives:** the location's own models are in `godot/scripts/locations/olive_village/models.gd` and its scenery
  in `godot/scripts/locations/olive_village/scenery.gd`; the houses come from the shared house kit (`houseStyle` in the
  layout).
- **Houses:** whitewash in four slightly different whites, with stone quoins at the corners, green shutters (the empty
  houses' are shut), curved terracotta roofs and chimneys, two or three storeys on the spur and one or two at the cove.
  Rosa's osteria and the barber shop have shopfronts with painted signs ("Rosa's", "Barber"); the Sandals' house has a
  balcony; Gambero's boathouse and Fuco's hut are in bare stone.
- **The church:** its nave is a whitewashed hall from the house kit, so you can walk in. Its bell tower is a model of
  its own beside it: whitewash with stone corners, dark belfry openings, and a spire of glazed green, yellow and white
  tiles that catches the light, the tallest thing in the village.
- **Other landmarks:** the castle's broken tower among its ruined walls; the wash-house, open-sided under a terracotta
  roof on four stone pillars, with a long stone basin and a spout (you walk in under its roof; the basin and pillars are
  solid); the old stone tank, dry for now; the hump-backed bridge as a single tall stone arch springing from the gorge's
  rock walls, with spandrel walls, parapets and a paved deck; the crumbled jetty, a stump of stones at the water's edge;
  Sirena's white and blue ferry off the cove; three wooden boats pulled up on the pebbles; and the population sign, a
  painted board at the bridge's village end reading "LIOLIVATO 38 inhabitants".
- **The covered alleys:** three passages arch over the alley from the bridge to the piazza, each a stone arch on two
  piers with a whitewashed room above it. The piers are solid; the passages are clear.
- **Rooms you can walk into:** Rosa's osteria (counter, shelves, a boxy TV on a cabinet, two card tables), the barber
  shop and town hall (the barber's chair and basin, the town hall's desk and shelves), the Sandals' house (a sofa, a rug,
  paintings on every wall), the church (eight pews, the altar and two lamps), Bastian's farmhouse (table and chairs, his
  workbench, a bed, the calendar on the wall), Gambero's boathouse (workbench, barrel, crate, bed) and the empty house
  beside the osteria, bare until the finale. Each has a route in from its door. Your house is still the plot framed by
  ruined walls.
- **Plants:**
  - 132 trees in the layout's invisible solid `olive_village_tree` props, drawn by the scenery script: silver-grey
    olives in rows on the terraces' treads (thinner on the abandoned ones), a few figs, and a handful of olives and figs
    in the village. The positions were worked out with the real ground shape: on level treads, clear of the walls, the
    tracks, the build sites, the buildings and the nav paths.
  - Yellow broom on the upper slopes, the west flank and round the cove; brambles on the highest terraces; red poppies
    on the abandoned terraces and the west flank; pots of basil either side of every house door; climbing roses on
    every third house.
  - Chestnut woods on both ridges and pines in the scrub are the shared decor clusters, in spring greens.
- **The horizon:** far hills drawn round the map, falling to the coast in the south with Serenza's headland far off to
  the east; five perched villages on the far ridges; the Alps, snow-capped, along the northern arc (the shared backdrop's
  `alps`, without its Langhe hills).
- **The ground:** terrace walls are painted dry-stone grey where the ground steps; the gullies at the map's west and
  east edges have gentle banks now, instead of tall canyon walls (the crag is applied after them, so it stays sheer).
- **Checked:**
  - **Tested** (`test_olive_village`, now 8 tests): all of stage 1's, plus the seven rooms (each enterable, with a spot
    outside its door, reachable from the beach; the empty house bare), and the landmarks and trees (the spire above every
    roof, the open wash-house with a solid basin, olives on level treads and off the build sites, three covered
    passages). Every nav edge, now including the routes into the rooms past their furniture, is walked both ways with
    real collisions.
  - **Played** (`play_olive_village`, now 20 checks): stage 1's walk, now also into the osteria, the barber shop, the
    church, the Sandals' house, Bastian's farmhouse and Gambero's boathouse, each with its roof fading while you're
    inside. Screenshots in both renderers.
  - **Not checked:** the glaze on the spire and the look at dusk in Forward+ beyond the screenshots.
