# Tonnarella: design for the port

Working id `port`. Agreed with the user on 2026-11-08 in a design interview. **Stage 1 (ground and map) is built;
stages 2 to 4 are not.** See "Build status" at the end. This doc is the plan the build stages follow. The rules every location shares are in `docs/WORLD.md`; `docs/MONTEFORCHETTA.md`
and the other location docs are the models it follows.

## The concept
Tonnarella is the old quarter of a port city on the Ligurian coast, packed onto a rocky headland: tall, grimy palazzi
with a slice of sky between them, steep stair lanes, laundry lines across the alleys, a black-and-white striped
church, a castle on top and an old lighthouse on its rock at the tip. It comes after Toriano, in late winter, during
the weeks when Italy's lire give way to the euro.

A February sea storm broke the breakwater that leads out to the lighthouse, flooded the lighthouse's engine room and
put out the light. It also tore the roof off the fish market, cut the power to the public lift, brought down a
stretch of the castle's sea wall and stripped every laundry line in the alleys. The harbour office sent for a
Geometra: the fishing boats are sailing blind at night, and the Navy has written to say it will switch the lighthouse
off for good and moor a buoy instead. You come down from Toriano on the regional train, and the bank teller is
waiting on the platform with your euro starter kit. The main story ends when the lighthouse shines again, on the same
night the town spends its last lire.

- **Feel:** Genoa's old town and the Ligurian ports, the way a Nintendo game feels Japanese. Faded red and ochre
  palazzi with painted-on windows, grey slate roofs, green shutters, basil on every sill, capers growing out of the
  walls, mimosa in bloom, focaccia at dawn, seagulls everywhere, the busy port across the bay and the city climbing
  the bare mountains behind.
- **The euro thread:** the whole town is changing its money while you're there. Prices show both currencies, Nonna
  converts every euro back to lire and then to 1950s lire, Baciccia at the fish market won't hear of euros, and the
  bank queue goes out under the arcade. Tonnarella's progress meter is the changeover itself (below).
- **Running gags:**
  - **The 112 steps.** Your flat is at the top of a seven-storey palazzo with no lift. The count shows every time you
    go up, and neighbours pass you on the stairs carrying fridges.
  - **Seagull thieves.** The gulls take food from anyone holding it, focaccia above all. Every morning they escort
    Gerolamo's rowing boat in from the lighthouse and back.
- **The name:** a *tonnarella* is a small tuna-trap net; the town is named after the tuna fishery it once had. It's
  only a name now (a tuna-net store on the quay was offered and not chosen).

## Ground rules for Tonnarella
- **Size:** about 130 m across and 170 m from the station to the lighthouse rock, bigger than a village and much
  smaller than Toriano, in three levels (below). The layout's `size` is 300 m so the sea and the mountain have room.
- **Season:** late winter, from February into early March. The story ends in early spring. There are no dates.
- **Money:** lire turning into euros, gradually, over the stay (see "The changeover").
- **Language, names, originality, no magic:** as in `docs/WORLD.md`. Tonnarella, its castle, church, lighthouse and
  everyone in it are invented; Genoa's old town and the Ligurian ports are inspiration only. Italian is kept for
  names, titles and honorifics: Ragioniere, Fanalista (lighthouse keeper), Comandante, Padron (a boat's skipper),
  Nonna.
- **No bicycles:** it's all steps. Tonnarella's map entry says `"bikes": false`.

## The place
North is up (negative z in the game). The coast runs east to west along the north edge, and the headland points south
into the sea. The harbour is tucked into the bay on its west side; open sea and rocks are on the east. The ground
climbs from the harbour in three levels: the waterfront at sea level, the alleys halfway up (about 10 m) and the
castle and station on top (about 20 m), joined by stair lanes and the public lift.

```text
                       N   the city's tiers climbing bare mountains, forts on the ridges

 ====tunnel========== STATION ==========tunnel====    coast railway            TOP, about 20 m
    forecourt, payphone          CASTLE in grey stone, its bastion
    [LIFT top stop]   belvedere   umbrella pines, holm oaks    fallen sea wall: rubble
  ~ the bay ~     ^ stair lanes ^                               rocks: driftwood    ~ open ~
  ~ and, far ~    palazzi, alleys, bare laundry lines, mimosa                       ~  sea ~
  ~ across it, ~  STRIPED CHURCH and its square   [LIFT middle stop]            MIDDLE, about 10 m
  ~ the busy ~    YOUR PALAZZO (112 steps)   NONNA'S balcony   capers on the walls  ~
  ~ port:    ~    ^ stair lanes ^                                                   ~
  ~ cranes,  ~    ARCADES: fish market, bakery, bank, chandlery  [LIFT bottom stop]  SEA LEVEL
  ~ ferries, ~    quays, palms, harbour office, boats                        rocks  ~
  ~~~~~~~~~~~~~~~~ HARBOUR ~~~~~~~~~~~~ breakwater ~~ GAP ~~ [LIGHTHOUSE ROCK] ~~~~~~
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ open sea ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

| Area | What's there |
| --- | --- |
| The top (landward neck) | **The station**, a grand, sooty old station building where the coast railway comes out of one tunnel and goes into the next. A forecourt with a payphone. **The castle**, an old fort in grey stone, with its bastion facing the open sea (where the lift's windmill goes) and the stretch of sea wall the storm brought down, its rubble heaped at the foot. **The belvedere** looking over the harbour. At the top of the lane to the castle, the lift's top stop and its machine room, right beside the bastion so the windmill's power has only a short way to go. Umbrella pines and dark holm oaks round the castle and down the slope. |
| The middle (the alleys) | Tall, narrow palazzi of six or seven storeys along dark alleys, with laundry lines strung across them, bare since the storm. **The striped church** in black-and-white stone with its bell tower, on a little square of its own with mimosa in bloom and the lift's middle stop. **Your palazzo**, 112 steps to the top, with a tiny slate roof terrace. **Nonna Pina's palazzo**, her third-floor balcony a jungle of basil pots, her basket on its rope. Capers growing out of the old walls. Stair lanes run down to the waterfront and up to the castle. |
| The waterfront (sea level) | **The arcades**, a long, low, dark arcade along the harbour, with **the fish market** at its end (open stalls whose roof the storm tore off), **Rosetta's bakery**, **the savings bank** and **the chandlery** under its arches. The lift's bottom stop. **The quays** with a row of old palms, **the harbour office**, fishing boats, Stefano's lampara boat and Gerolamo's rowing boat. |
| The breakwater | A stone breakwater curving out from the end of the quays to the lighthouse rock, closing the harbour to the south. The storm smashed a stretch of it, leaving a gap of open water. Spray comes over it on windy days. |
| The lighthouse rock | Just off the tip of the headland. **The lighthouse**, a tall tower in pale stone with a dark lantern on top, the keeper's room at its foot and the stair up to the lantern room. Mussels on the rocks round it. Room for a windmill in the tramontana. |
| The east rocks | Below the castle, facing the open sea: timber, broken boats and planks the storm threw up, where you chop driftwood. |
| The horizon | West, across the bay: the big working port, with cranes, ferries and cargo ships, and its lights at night. North and north-west: the rest of the city climbing the bare mountainsides in tiers of palazzi, with old forts on the ridges. South and east: open sea. |

**The storm, still visible:** the gap in the breakwater; the rubble of the castle's sea wall; the fish market's
roofless frame; bare laundry lines, with the washing stuck in odd places round town; the lift's cabin parked at the
bottom with a handwritten notice; driftwood heaped on the rocks; the dark lighthouse. Each clears with its request:
the washing goes back on the lines as you return it, the lift runs, the fish market gets its roof, the lighthouse
shines.

## Getting there and around
- **Arrival by train.** The regional train from Toriano comes down through the mountain tunnels and stops at
  Tonnarella's station, at the top of the headland. You walk down to the sea. The station is the departure point (a
  feature of kind `boat`, with `depart_label` "Take the train", as `docs/WORLD.md` asks).
- **On the travel map.** Tonnarella has its own entry, off the map until Toriano's finale is done: it reveals on
  `metropolis_angel_lit`, the flag Toriano's Christmas Eve finale already sets, so nothing in Toriano's files
  changes. It sits on the coast south of Toriano. Tonnarella's own finale sets `port_lighthouse_lit`, ready for
  whatever place comes next.
- **On foot.** Stair lanes join the three levels. There are no bicycles.
- **The public lift**, with three stops: the harbour (by the arcades), the church square and the castle (by the
  castle gate, at the top of the lane). It's out of action after the storm until Up and Down; then you ride it with Agostino.
  The stops are features of kind `stop` on the line `port_lift`, added by Tonnarella's own script (`WORLD_FLAGS` and
  `adjust`) once the request's flag is set. Riding to a stop raises `ride:<stop id>`, as elsewhere.
- **Out to the lighthouse.** Over the breakwater once it's mended. Until then Gerolamo rows in and out, and you can't
  reach the rock.

## The changeover: Tonnarella's progress meter and the euro
Money is kept as whole coins in saves and rules (one coin is 1,000 lire, `Money`), so the euro only changes how money
is shown. One euro is 1,936.27 lire, rounded to the cent: one coin is €0.52, and a 120,000-lire bed is €61.97.

**How prices show, step by step:**

| When | What prices show |
| --- | --- |
| Before Tonnarella | Lire only, as now. |
| Arriving in Tonnarella | Tonnarella's own shops show both, lire first ("1,000 lire (€0.52)"), as the law of the two-currency weeks says. The wallet and the other places still show lire. |
| 10%: "Prices in both" | The euro converter: the wallet, the bag, toasts and every shop, in every place, show both, lire first. |
| 50%: "Euros first" | The euro becomes the main figure everywhere: "€0.52 (1,000 lire)". |
| 100%: "The last lira" | Euros only, in every place, for the rest of the game: "€0.52". |

Lines of dialogue and tips that name a sum in lire stay as written, in every place: people went on talking in lire
for years. Only the amounts the game prints from numbers change.

**The meter:** the changeover, from 0 to 100%, shown with its own name and icon in the HUD and the progress panel
(`meter` in `location.json`, `LocationMeter`). Main requests move it 15% each, side requests 4%, and each piece of
washing you return 1% (five pieces). That makes 100% exactly; without the finale it stops at 85%.

| At | Milestone | Reward |
| --- | --- | --- |
| 10% | "Prices in both." Every label shows lire and euros, lire first. | The euro converter: both prices side by side everywhere (above) |
| 25% | "Nonna buys a converter." She still checks it against her head. | A fisherman's wool cap |
| 50% | "Euros first." | The euro becomes the main figure on every price. Your roof terrace grows onto the next roof. |
| 75% | "Baciccia gives in." He frames his last 1,000-lire note over his stall. | A navy cable-knit fisherman's sweater, and a pergola with a vine on your terrace (Tonnarella's own scenery, not a building piece) |
| 100% | "The last lira." Needs the finale. | Lire gone in every place. A framed 1,000-lire note for your flat's wall. |

The first request alone passes 10%, so the converter arrives at the end of your first day. Names and numbers can
change in the build.

## The cast
Nine villagers. Ids are `port_<first name>`, for example `port_nicolo`.

| Who | Where | Who they are | Outfit |
| --- | --- | --- | --- |
| **Ragioniere Nicolò "Arrotonda" Bruzzone** | The savings bank under the arcades | The bank teller. Older, nervous and buried in coin rolls. He's the face of the changeover, so the town blames him for every new price (his nickname means "he rounds"). Meets your train with the euro starter kit, walks you down the stair lanes counting the steps, and gives Mind the Change and The Queue at the Bank. He would never climb 112 steps. | A grey suit a size too big, black clerk's sleeve guards, a converter on a cord round his neck, coin rolls in every pocket |
| **Fanalista Gerolamo "Lanternin" Repetto** | The lighthouse, his rowing boat, Rosetta's counter at dawn | The lighthouse keeper for 40 years. Since the storm broke the breakwater he's been stranded at the lighthouse and won't leave it, so every morning he rows in for focaccia, with the gulls as escort, and rows back. Talks to the light like an old dog. Gives the finale. | A navy pea coat with brass buttons, a white beard, a peaked cap, an old oil lantern he still carries |
| **Comandante Lorenzo "Mugugno" Traverso** | The harbour office and the quays | The harbour master, who sent for the Geometra. Grumbles about everything (the *mugugno* is the old Genoese sailor's right to grumble) and gets it all done. Holds the Navy and its buoy off by letter, and keeps their threat framed on his wall so he can grumble at it. Gives The Broken Breakwater, complains every time you quarry the castle wall, and makes the speech at each inauguration: it starts as a list of complaints and ends in praise. | A navy uniform with gold braid, a white peaked cap, binoculars |
| **Rosetta "la Sveglia" Canepa** | Her bakery under the arcades | The focaccia baker. Opens at 4 AM and wakes the street with her shutter ("la sveglia" is the alarm clock). At war with the seagulls. Gives Seagulls vs Focaccia and, for the shops of the arcade, The Two-Price Labels. Stays open all night for the finale. | A white coat and cap dusted with flour, an oven paddle |
| **Giobatta "Baciccia" Parodi** | His stall at the fish market | The fishmonger, and the town's last holdout: prices everything in lire and swears he'll take them to his grave. Gives in at 75%. Gives The Fish Market. | A rubber apron and boots, a pencil behind his ear, a wad of lire notes |
| **Nonna Pina Lagomarsino** | Her balcony in the alleys | Lives on the third floor among her basil pots and hasn't come down since the lift stopped. Lowers a basket on a rope for anything she wants; requests, gifts and gossip go up and down in it. Converts every euro to lire, then to 1950s lire. Gives Nonna's Hidden Lire. | A black dress, a flowered housecoat, slippers, the basket on its rope |
| **Agostino "Su e Giù" Ottonello** | The lift, at its top stop | The public lift's attendant for 30 years ("su e giù": up and down). Everyone rides with him, so he hears everything. Since the storm he has sat by his dead lift every day, in uniform. Gives Up and Down. | A brown attendant's uniform, a peaked cap, white gloves |
| **Padron Stefano "Lampara" Dellepiane** | His boat on the quay | Skipper of a small boat that fishes anchovies at night under a big lamp (a *lampara*). The dark lighthouse keeps him in harbour. Gives Night of the Lampara. | A yellow oilskin jacket, a wool cap, rubber boots |
| **Davide "Motorino" Cambiaso** | His uncle's chandlery; the stair lanes | 17. Delivers for his uncle's ship chandlery on a scooter he mostly carries up the stairs, and minds the counter while his uncle is "out the back" (the chandlery's shop opens by talking to him, because shops belong to a villager). No request of his own; he has a say in some wishes. | A huge puffer jacket, a scooter helmet worn everywhere, a cassette Walkman |
| **The player** | | The Geometra, come down from Toriano. Monteforchetta's windbreaker and clipboard, plus Tonnarella's wool cap and fisherman's sweater once earned. | |

**Tastes** (for the shared `Tastes`; the build can tune them):
- Nicolò: tables, desks and signs; grey.
- Gerolamo: lamps, rail lanterns and railings; white.
- Traverso: stone blocks, columns and railings; navy blue.
- Rosetta: tables, benches and flower beds; the bakery's warm yellow.
- Baciccia: counters and signs; sea green.
- Nonna Pina: flower beds, hedges and trees; green.
- Agostino: benches and lamps; brown.
- Stefano: railings, rail lanterns and pontoons; oilskin yellow.
- Davide: signposts and street lights; scooter blue.

## Gathering
| Material | Where it comes from |
| --- | --- |
| Wood | Driftwood heaped on the east rocks below the castle: the storm's timber, broken boats and planks (the chopping minigame, on driftwood piles with their own label). The sea throws up more overnight. A few umbrella pines and holm oaks by the castle can be chopped too. The chandlery sells wood at port prices. |
| Stone | The rubble of the castle's fallen sea wall (the quarrying minigame). The Comandante reminds you it's a protected monument every time. |
| Metal, copper wire, fabric | The chandlery: metal fittings, copper wire, and rope and sailcloth as fabric. |
| Glass panes (`port_glass`) | The chandlery, for the lighthouse's lantern. |
| Capers (`port_caper`) | Picked from the old walls in the alleys and round the castle. They grow back. Rosetta, Baciccia and Nonna buy them. |
| Mussels (`port_mussel`) | Off the rocks round the lighthouse rock and the breakwater. Baciccia buys them. |
| Fish | From the quays, the breakwater and the rocks: sea bream, grey mullet, scorpionfish, octopus, and now and then a moray eel (`port_bream` and so on, in the layout's `fish`). Anchovies (`port_anchovy`) only at night on the lampara. Junk: an old boot, a purse of old lire (`port_lire_purse`, which the bank changes) and a lobster pot. |
| The washing the storm blew away | The shared lost things: five pieces of washing tangled round town, each with its own name and model. Nonna's best tablecloth up a lamp post in the alleys, the Comandante's dress shirt on the rocks below the castle, Baciccia's long johns in a waterfront palm, Rosetta's spare apron on a cannon at the castle, Agostino's white gloves on the roof of the lift's top stop. Return them for thanks, gossip and 1% each on the meter, and the washing goes back on the lines. |
| Nonna's tins of lire (`port_lire_tin`) | Buried and hidden round town over fifty years, found with the metal detector during her request (`"fresh": true`). |
| Treats | At Rosetta's: focaccia, onion focaccia, farinata (a thin chickpea pancake from the oven) and a spring greens pie. |

## Shops
| Shop | Who | Sells | Buys |
| --- | --- | --- | --- |
| Rosetta's bakery | Rosetta | The four treats | Capers |
| The fish market | Baciccia | Bait | Fish, anchovies, mussels, capers |
| The chandlery | Davide, for his uncle | Metal, copper wire, fabric (rope and sailcloth), wood, glass panes | Fishing junk: the boot, the lobster pot |
| The savings bank | Nicolò | Nothing | The purse of old lire and Nonna's tins: changing them |

## Clothes
Two pieces in Tonnarella's own `appearance.json`: a **fisherman's wool cap** (25%) and a **navy cable-knit
fisherman's sweater** (75%). Monteforchetta already gives the striped sailor top, so Tonnarella doesn't.

## Requests
Ids are `port_<name>`. As everywhere, a building step is a brief: a site, two or three musts that check what it does,
and up to three wishes from people who have a say. Anything that meets the musts passes, however it looks. Every
building step has a ghost plan, and the request's gathering pays for it (`test_plans`). Step details and amounts are
the plan and can change in the build.

### Main story
| # | Request | Given by | What you do |
| --- | --- | --- | --- |
| 1 | **Mind the Change** (`port_welcome`) | Nicolò | Off the morning train. Nicolò meets you on the platform with a euro starter kit ("twelve euros ninety-one: twenty-five thousand lire exactly, I counted twice"), which goes into your wallet as 25 coins. The lift is out, so he walks you down the stair lanes counting the steps, and the walk is the tour: the castle and its fallen wall, Agostino sitting by his dead lift, the striped church, the bare laundry lines, your palazzo's door (he won't climb it). Under the arcades: the bank, then focaccia at Rosetta's (a gull takes it). Gather driftwood on the rocks, then the harbour office, where the Comandante shows you the broken breakwater and the dark lighthouse. It ends when you climb the 112 steps to your flat. |
| 2 | **The Broken Breakwater** (`port_breakwater`) | Traverso | Gather wood, stone from the castle wall and metal from the chandlery. Brief at the breakwater gap: **musts:** walkable from the quay end to the lighthouse rock (`path:port_breakwater`; any continuous, supported path counts, as with Monteforchetta's road); railings along it. **Wishes:** in stone (Traverso); a lamp at the end (Gerolamo); somewhere to sit and fish from (Stefano). Gerolamo walks across with his focaccia for the first time since the storm, gulls behind him. |
| 3 | **The Fish Market** (`port_fishmarket`) | Baciccia | The storm tore the roof off his stalls at the end of the arcades. Gather wood and fabric. Brief at the fish market: **musts:** three counters to sell from; a roof over them; a sign with the prices. **Wishes:** a light for the dawn sale (Stefano); a seat for the old men who come to watch (Agostino); painted sea green (Baciccia). The sign shows both currencies, and Baciccia hangs a fish over the euro half. |
| 4 | **Up and Down** (`port_lift`) | Agostino | The storm cut the lift's power. Gather metal, copper wire and wood. Brief on the castle bastion, where the tramontana blows: **must:** a windmill's power reaches the lift's machine room at the top stop (`fed:port_lift`). **Wishes:** a light at the top stop for evening riders (Nonna, from her balcony); a bench to wait on (Agostino). Agostino takes you down, all three stops, and from then on you ride between them. Nonna comes down for the first time since the storm. |
| 5 | **Light the Lighthouse** (`port_lighthouse`), the finale | Gerolamo | Buy glass panes at the chandlery and carry them up to the lantern room, where Gerolamo glazes the lantern. Gather metal and copper wire. Brief on the lighthouse rock: **must:** a windmill drives the lighthouse's turning gear (`fed:port_lighthouse`, the lighthouse machine Clockwork Cove already has). **Wishes:** a railing round the rock (Traverso); a bench to watch the beam from (Gerolamo); a light along the breakwater (Stefano). **The finale night:** at dusk the town gathers on the breakwater; you and Gerolamo climb to the lantern room and light it; the beam sweeps the bay and Stefano's boats go out under it with their lamps. At midnight everyone spends their last lire at Rosetta's, open all night. Next morning the meter reaches 100% and it's euros only, the Navy's second letter (no buoy) hangs beside the first in the harbour office, and Il Gabbiano gives it the front page. Sets `port_lighthouse_lit`. |

### Side requests
| Request | Given by | What you do |
| --- | --- | --- |
| **The Queue at the Bank** (`port_queue`) | Nicolò | After Mind the Change. The whole town is queuing out under the arcade to change their lire. Brief at the bank's stretch of arcade: **musts:** four seats; a roof; a light. **Wishes:** something green (Nonna); a table to fill in the forms on (Nicolò). |
| **Seagulls vs Focaccia** (`port_seagulls`) | Rosetta | After Mind the Change. The dockers eat breakfast outside her door from 4 AM, in the dark, and the gulls pinch it. Brief at the bakery door: **musts:** two tables and four seats; a roof over them; a light. **Wishes:** something green (Nonna); the bakery's warm yellow (Rosetta). Next dawn the dockers eat under it, and a gull lands on the roof and glares. Unlike Monteforchetta's tables outside the bakery, the roof and the light are the point. |
| **The Two-Price Labels** (`port_labels`) | Rosetta, for the shops of the arcade | After The Fish Market. The law says every shop must show both prices, and the arcade's shopkeepers argue over every lira. Brief along the arcade: **musts:** a sign by the bakery, the chandlery and the bank (if a must can't carry a site of its own, three signs along the arcade); a lamp so they can be read before dawn. **Wishes:** scooter blue (Davide); something green (Nonna). |
| **Night of the Lampara** (`port_lampara`) | Stefano | After The Broken Breakwater. Meet him at his boat after 8 PM and fish anchovies under his lamp (a fishing spot on the boat with its own `hours` and `gives`; only what you catch during the step counts). Bring the catch to Baciccia when the fish market opens at dawn. |
| **Nonna's Hidden Lire** (`port_nonna_lire`) | Nonna Pina, by basket | After Up and Down. Nonna hid tins of lire round town over fifty years: in flowerpots, in walls, under steps. She lowers a note in her basket and lends you a metal detector if you haven't got one (the shared rule: every request that sends you digging gives it). Find five tins, then meet her at the bank, where Nicolò counts them out: a fortune in 1950s notes worth about €38. No deadline: after the finale the bank still changes them ("the Bank of Italy takes lire for ten years; I'll be retired by then"). |

Five main and five side requests, plus the five pieces of washing.

## Rooms you can walk into
- **Your flat:** an attic at the top of your palazzo. The street door opens on the stairwell; going up shows the
  count of 112 steps and puts you at the flat's door (a short cut, not a seven-storey climb). A small room under the
  slates, with a wardrobe and, until you buy one, no bed. A glass door opens onto the roof terrace, your build plot,
  which grows onto the next roof at 50%.
- **Rosetta's bakery:** the oven, the counter, trays of focaccia, dockers dunking it in milky coffee at 5 AM.
- **The bank:** the counter behind its glass, the queue, coin rolls stacked everywhere.
- **The lighthouse:** the keeper's room at the foot (a bunk, a stove, 40 years of logbooks) and the stair up to the
  lantern room, where the finale happens.
- **The harbour office:** the Comandante's desk, charts, a radio set and the framed letter from the Navy.
- Not the church, the castle, the station (an open platform), the fish market (open stalls) or the chandlery (you buy
  at its door).

## Hangouts and needs
The places villagers pass and want things, for the shared needs, charm and liveliness: the station forecourt, the
belvedere by the lift's top stop, the church square, the fish market, the bakery door, the bank's arcade, and the end
of the breakwater once it's mended. Needs are the shared ones (a seat, shelter, light, green, a counter), at most three
open at a time.

## The day
- **Nights matter**, like Boccapioppo: the clock doesn't hold at dusk (`"day": {"hold": false, "regrow":
  "overnight"}`), because the lampara and the finale happen after dark.
- **You end the day by sleeping**, on a bench until you've bought a bed (120,000 lire, €61.97 once euros come first).
  Things regrow overnight: driftwood, capers, mussels.
- **The morning paper is Il Gabbiano** (the seagull), which reviews yesterday's build.
- **The inauguration speech** is the Comandante's.
- **Benches** on the quays, the belvedere and the church square, with Tonnarella's own nap gags (`naps`): a gull eats
  the focaccia you fell asleep holding (a sight gag, `"visual": true`), spray over the breakwater soaks you, Nonna's
  basket comes down beside you with a note, and Il Gabbiano blows into the harbour.

## Look
- **Buildings:** tall, narrow palazzi of six or seven storeys in faded deep red, ochre, salmon and pale yellow, with
  windows, frames and shutters painted on in fake perspective. Green slatted shutters, grey slate roofs, soot streaks
  and damp in the alleys. The church in black-and-white striped stone. The lighthouse in pale stone with a dark
  lantern; the castle and the breakwater in grey stone. The arcades low, dark and arched.
- **Palette:** faded red `#a8473a`, ochre `#d4a24c`, salmon `#e09a7a`, pale yellow `#e9d39a`, shutters `#3e5b3f`,
  slate `#5d636a`, church stripes `#efeae0` and `#2b2b2e`, lighthouse `#e6dfd2`, castle grey `#8a8a86`.
- **Plants:** basil in pots on every sill and balcony (Nonna's a jungle), capers growing out of the walls, mimosa in
  bloom in the little squares and gardens, a row of old palms along the waterfront, umbrella pines and holm oaks round
  the castle and down the slope.
- **Ground:** stone slabs in the alleys, stair lanes of brick and pebble, cobbles on the quays, grey rocks.
- **Water:** the Ligurian sea in deep blue-green, whitecaps and foam on the rocks on tramontana days, flat and heavy
  on scirocco days, spray over the breakwater.
- **Animals:** seagulls (the thieves), alley cats on the steps, on windowsills and round the fish market, pigeons on
  the church front and in the little squares.
- **Light and weather:** most days the cold tramontana: hard blue skies, whitecaps, sharp sun on the façades and deep
  shadow in the alleys under one slice of sky. Some days the damp scirocco: grey haze and drizzle, the sea flat and
  heavy. At night a few warm lamps in the alleys, the port's lights across the bay, and after the finale the
  lighthouse beam sweeping the bay.
- **The look block** (`location.json`): cool shadows and bright, slightly cold highlights; more wind than anywhere
  else; few motes, no fireflies; falling mimosa fluff (`leafColors` in mimosa yellows); weather from clear (most days)
  through fair and cloudy to haze and drizzle (the scirocco days).

## Sound
- **Music:** original, in the game's procedural music system, with a theme for each part of the day (`music` in the
  map entry), inspired by the Genoese songwriters of the 1960s to the 1990s: nylon-string guitar, accordion, mandolin,
  double bass and soft brushed drums. Wistful by day, slow at night, and its own tune for the finale.
- **Sounds:** the sea on the rocks, spray slapping over the breakwater and boats knocking at their moorings; the port
  across the bay, with ship horns, cranes clanking and the evening ferry's long blast; the seagulls. (Life in the
  alleys, the wind and the church bells were offered and not chosen.)

## Changes to shared code this needs
Each is the smallest general version, comes with a test, and is named at the top of the pull request that makes it.

| Change | Why | Stage |
| --- | --- | --- |
| **The euro on screen:** `Money` shows lire, both with lire first, both with euros first, or euros only, chosen by story flags (which Tonnarella's milestones set), with a place's own shops able to show both from arrival. One rate, rounded to the cent. Before any flag is set, every printed amount stays exactly as it is today (tested). | The changeover, in every place | 3 |
| **A mandolin voice** in the music synth, if the existing plucked voice doesn't pass for one | The music | 4, optional |
| **Wind that changes with the weather**, only if the look block's wind can't make tramontana days windier than scirocco days | The look | 4, optional |

Everything else lives in Tonnarella's own files (`docs/WORLD.md`): `godot/data/locations/port/`,
`godot/scripts/locations/port.gd` and helpers in `godot/scripts/locations/port/`, `godot/tests/test_port.gd` and
`godot/tests/play_port.gd`. That covers the three-level ground and the sea, the lift's stops appearing with their flag,
the washing's models and the lines refilling, the pergola, the horizon with the port and the city's tiers, the
lighthouse beam (reusing the lighthouse machine and beam Clockwork Cove has), the gulls, the finale night, and the
112-step stair. Toriano's gulls are in Toriano's own files; Tonnarella has its own unless they move to shared code.

## Build stages
One pull request per stage. Each keeps the game playable and the tests passing.

1. **Ground and map.**
   - The ground shape in `port.gd`: the headland in three levels, stair lanes, the quays, the breakwater with its
     gap, the lighthouse rock, the east rocks, the sea round it all.
   - The layout: arrival at the station, the departure point, the nav graph, paths, build zones (the breakwater gap,
     the fish market, the castle bastion, the lighthouse rock, the bakery door, the bank's arcade, your roof terrace),
     resource spots and benches; the lift's stops behind their flag.
   - A hidden map entry revealed by `metropolis_angel_lit`, with `"bikes": false` and a first `look`.
   - Plain boxes for the buildings so the map reads in screenshots.
   - `test_port.gd`: a playable world (the arrival is walkable, every level is reachable by the stair lanes, every
     nav spot can be reached, water where the sea is, build zones where they should be).
2. **Buildings and scenery.**
   - The palazzi with painted windows and slate roofs, the arcades, the striped church, the castle and its fallen
     wall, the station, the lighthouse, the harbour office, the bakery, the bank, the chandlery, the fish market's
     frame, the lift's stops and cabin, boats, laundry lines.
   - Rooms you can walk into, with furniture, and the 112-step stair to your flat.
   - Palms, pines, holm oaks, mimosa, basil pots, capers; the port and the city's tiers on the horizon.
3. **People, dialogue and requests.**
   - The nine villagers with schedules, greetings, topics, gifts and tastes; Nonna's basket.
   - The ten requests with their briefs and ghost plans, the four shops, Tonnarella's materials, fish and treats, the
     washing, the changeover meter and the clothes.
   - The euro on screen (the shared change above).
   - `play_port.gd`: a scripted playthrough of every request with real input, starting off the train as if the player
     had come from Toriano (`arrive_as_if_played(["hearthglow", "river_town", "rice_village", "metropolis"])`).
4. **Look and ambient life.**
   - Tuning the look block, the sea, tramontana and scirocco days, the night lamps, the lighthouse beam and the
     finale night.
   - Gulls, cats and pigeons; the washing back on the lines.
   - The harbour-songwriter themes, the sea and port sounds, the cast's outfits.

## Agreements needed with other sessions
- **Toriano:** Tonnarella's map entry reveals on `metropolis_angel_lit`, which Toriano's finale already sets; nothing
  in Toriano's files changes. If Toriano's owner would rather the regional train line say so in Toriano too, agree it
  with them.
- **Every place:** the euro switch changes how money shows everywhere once you've reached 10% in Tonnarella. Before
  that, every printed amount stays exactly as it is today, so the other places' tests and playthroughs, which start
  before Tonnarella, are unaffected.
- **Whatever comes next:** Tonnarella's finale sets `port_lighthouse_lit` for the next place's map entry.

## Risks
- **Steep ground in three levels.** Stair lanes on the heightfield have to be walkable, and walking and quest checks
  share `WalkWorld`. If slopes that steep fight the player controller, the stair lanes become raised floors and
  stairs (`floors` in the layout) instead.
- **Narrow alleys between tall buildings.** The camera stops sooner in dense streets, and seven-storey palazzi crowd
  it more than any place so far. The alleys need to be wide enough to play in, and the tall fronts may need to fade
  like the rooms' roofs.
- **Frame rate:** many tall buildings, on the software renderer used for screenshots.
- **The euro switch touches everyone.** The shared change must keep today's output byte for byte until its flags are
  set; its tests check that.
- **The lighthouse beam at night** in haze, on the compatibility renderer.

## Checks for every stage
- `godot/run_tests.sh`, and `npm test` and `npm run build` for the frozen web version.
- Screenshots of Tonnarella in both renderers (`godot/shot.sh ... --island=port`, with and without
  `RENDERER=forward_plus`).
- Tonnarella's own playthrough only (`godot/play_all.sh <out> play_port`), starting as if the player had come from
  Toriano with realistic stats.
- Each pull request says what was verified in play and what was only unit-tested.

## Offered and not chosen
So later sessions don't add them back by accident: a tuna-net store on the quay; the bank as a painted palazzo
landmark; a slate quarry; wild herbs on the cliffs; agaves and prickly pears; Baciccia's Last Lira, Nonna's Basil and
Davide's Round as requests; the rounding and the mugugno as town-wide running gags (they stay as Nicolò's and
Traverso's nicknames); life in the alleys, wind and church bells as sounds; cormorants and dolphins; a legendary
grouper; a pergola as a shared building piece; a harbour boat to the lighthouse.

## Build status
What exists now, and the choices made while building that the design above didn't settle.

**Stage 1, the ground and the map:**
- **Where it lives:** the ground shape is code in `godot/scripts/locations/port.gd`. The map is
  `godot/data/locations/port/layout.json`, and the map entry is `location.json`.
- **The levels:** the top is at 20 m, the alleys at 10 m and the quays at 1.2 m. Between them the ground slopes, and
  palazzi stand all along the slopes. The gaps between them are the stair lanes, which are paved ramps for now; the
  steps come with the buildings. Two lanes climb from the alleys to the top: one to the station and one to the castle.
  Three run down to the waterfront: by the bakery, from the church square, and by the fish market.
- **Edges:** where the ground drops straight into the sea, you stop at the edge. Two parapets stand where a fall would
  land you on the east rocks: at the end of the main alley and beside the castle. They are the layout's
  `harbor_cliffs`, drawn as low stone walls.
- **The breakwater** is low, 0.4 m above the sea, so a post standing on the gap's bed (-1.0 m) reaches deck height.
  Posts, columns, stone arches and oak beams can all close the 7 m gap. The path over it waits for
  `port_breakwater_done`, which The Broken Breakwater will set.
- **The lift's stops** are in the layout (`port_lift_stops`) and join the map once `port_lift_on` is set
  (`WORLD_FLAGS` and `adjust`). The top stop is by the castle gate, the middle stop on the east side of the church
  square, and the bottom stop by the lift house under the arcades.
- **Build sites:** the breakwater gap, the fish market, the castle bastion, the lighthouse rock, outside the bakery,
  the bank's stretch of arcade, and your roof terrace. The terrace is a raised floor 30 m up on your palazzo, and it
  stays closed until `port_home` is set.
- **Gathering spots:** driftwood on the east rocks, drawn as piles of grey logs; rubble from the castle's fallen wall
  to quarry; and fishing spots on the quays, the breakwater and the rocks.
- **Buildings:** plain boxes in the palazzo colours, with slate-grey tops. A box on a slope reaches down to the lowest
  ground under it.
- **Behind the station:** the mountain is part of the ground. It rises in a step you can't climb, with two rock spurs
  where the railway's tunnels will go.
- **The travel map:** Tonnarella appears south-east of Monteforchetta and south of Toriano once Toriano's finale sets
  `metropolis_angel_lit`. You leave by train from the station.
- **Not yet:**
  - The rocks and the breakwater come out olive rather than grey, because the shared terrain shading warms all
    ground. That's for the look stage.
  - The HUD still shows the approval rating until the changeover meter arrives with the requests.
  - There's no horizon backdrop yet: the port across the bay and the city's tiers come with the scenery.

**Checked for stage 1:**
- **Tested** (`godot/tests/test_port.gd`): the pack and its map entry; ids; the three levels, the sea and the
  mountain; every path walked both ways with the player's own step rule; every level reached from the station, with
  the lighthouse cut off; the lanes as the only way between levels; the cliff edges; the gap; the build sites; the lift
  stops appearing with their flag; buildings reaching down the slope; arriving as if you'd played the way here.
- **Played** (`godot/tests/play_port.gd`, 25 checks): off the train on the forecourt, with the four earlier places'
  main stories done; across the top to the belvedere; down to the church square; along the alleys to Nonna Pina's door,
  your palazzo and the parapet at the alley's end; down to the arcades, the bakery and the harbour office; out along the
  breakwater to the gap, which stops you; round to the east rocks, whose cliff you can't climb; back up to the castle
  gate; the train opening the travel map; the lift's stops appearing with its flag (set directly by the script); riding
  the lift down to the harbour and up to the church square.
- **Seen** in screenshots in both renderers: the harbour from the air, the arrival, a stair lane, the church square,
  the breakwater gap and the east rocks.
