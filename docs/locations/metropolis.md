# Toriano: design for the city

Working id `metropolis`. Agreed with the user on 2026-11-04 in a design interview. This doc is the plan the build
stages follow. The rules every location shares are in `docs/WORLD.md`; `docs/MONTEFORCHETTA.md` is the model this doc
follows.

## Status
**All four stages are built: the ground and map, the buildings and scenery, the people and requests, and the look
and ambient life.**
- **Ground and map (stage 1):** the city is 372 m across, with paved ground painted by the layout (asphalt streets,
  stone-slab pavements and squares, setts along the tram loop and in the courtyard, gravel in the park and the
  building sites). The Darsena and its two canals have stone quays; the park has its pond, lawns and gravel paths.
  The city's edge is a ring of tall backdrop blocks.
- **Buildings (stage 2):**
  - **City blocks:** painted façades from Toriano's building kit (`scripts/locations/metropolis/kit.gd`): shuttered
    windows, granite ground floors with shopfronts and roller shutters, cornices, iron balconies, awnings and low
    terracotta roofs, with windows and shops that light up after dark.
  - **The Duomo:** a white marble front with a rose window, the nave with pinnacles, flying buttresses on the aisles,
    and the crossing tower with its great spire and the Golden Angel.
  - **The other landmarks:** the Galleria's glass vaults, dome and arched entrances; the Teatro Civico's porch and
    name; the Castello Rosso's battlements, towers and clock tower; Toriano Centrale's front, canopy and train shed.
- **Number 14:**
  - **The building:** three-storey wings round the courtyard, a balcony ring at the first floor with iron railings,
    a stone stair up from the courtyard, and a low back wing whose roof is your terrace (the build plot).
  - **Its rooms:** Augusto's lodge and Ragioniere Sala's office at street level; Elvira's, Simone's and your flat off
    the balcony; a shared WC at the end of it.
- **Rooms you can walk into:** the nave (pews, pillars, the altar), Franco's bar, Chiara's workshop, the Cathedral
  Works office, and the tenement's rooms. Your flat is empty for the Balcony Flat request.
- **Roof terraces:** the Duomo's aisle roofs are marble terraces 6.3 m up with parapets, and a gap where the
  scaffolding will arrive. They're reachable once you build the scaffolding in stage 3.
- **The old bridge:** a stone deck over the west canal, which flows on underneath.
- **Trams:** three orange trams run the loop on rails under an overhead wire, stop at the five stops and wait for
  anyone on the track. At any stop, "Take the tram" rides to another stop.
- **Street furniture:** bare plane trees along the avenues and the canal, sodium street lamps, the big Christmas
  tree, newsstands, payphones, parked cars, the building sites' hoardings and skips, marble blocks in the works yard,
  the old crane on the Darsena, barges, Gennaro's battered cart and a flea-market stall.
- **On the travel map:** Toriano stays off the map until the flag `rice_village_trainStops` is set, then turns up as
  a surprise (every place does, as the user decided after stage 1). That's the flag the rice village's design
  proposes for its finale, when the regional train stops there again.
- **People and requests (stage 3):**
  - **The cast:** the thirteen villagers below, with daily routines on the city's nav spots, greetings that change
    with the story, topics and gifts. Augusto waits on the platform until you arrive; on Christmas Eve everyone
    gathers round the Christmas tree in the cathedral square.
  - **Requests:** the six main and thirteen side requests below, worth 183 column inches in all.
  - **The evening paper:** column inches in *La Sera di Toriano* replace the approval rating here, in the HUD and the
    progress panel, with the six milestones below. The 70-inch column widens your roof terrace; the radio and the
    framed front page turn up in your flat.
  - **Shops:** Franco's bar, Chiara's sartoria, Gennaro's chestnuts, Ottavio's hut, the Cathedral Works and the tram
    depot.
  - **Gathering:** plane trees to prune in the park (with a pink ribbon while they're ready), marble offcuts in the
    works yard, builders' skips (metal and old bricks), old tram wire on the depot's scrap pile, the flea-market
    stall (fabric), fishing on the canals (old bicycles, trolleys, boots and carp), Christmas roses in the park beds,
    lost things in the streets, Gino's score pages at night, and Roman finds at the building sites.
  - **Machines:** the old crane, moved to the canal's mouth, swings and lifts marble once a waterwheel drives it; the
    Golden Angel shines over the square after dark once she's lit on Christmas Eve.
- **Look and ambient life (stage 4):**
  - **Light and weather:** a pale winter sky, a cool grey-blue haze, grey-green canals, a low sun and hoarfrost at
    night; fog most mornings; dusk at five (only the light: the clock and routines stay); the Alps on clear days.
  - **Night:** the sodium street lamps, the Christmas tree, Christmas lights strung across the Galleria and number
    14's courtyard, and the Golden Angel light up at dusk.
  - **The finale's snow:** when the angel lights up on Christmas Eve, it snows for the first time, with a white
    dusting on the square, the streets and the roofs.
  - **Animals:** a hundred pigeons in the cathedral square, in flocks that clatter up when you come close and land
    on the far side; ducks on the park pond; gulls over the Darsena and the canal; cats in number 14's courtyard.
  - **People and traffic:** passers-by hurrying about the streets near you (ten by day, a few at night), and five
    small cars driving round the tram loop, queueing behind the trams.
  - **Sound:** Toriano's own music (dance pop in the morning, pop in the afternoon, lounge at night, a sleigh-bell
    tune on Christmas Eve and the finale's own), the cathedral striking the hour, a peal for the angel, a horn in the
    traffic now and then, pigeons cooing and gulls crying; no songbirds in December.
  - **Outfits:** the cast in their winter clothes (the Architetto's camel coat and hard hat, Rocco's white helmet
    and the rest); the long camel coat and red scarf at 25 inches, Chiara's padded jacket, a wool hat in her shop
    and Rocco's helmet as a friendship gift.
  - **Ambrogio's last run:** on Christmas Eve his tram, number 1528, goes round strung with Christmas lights after
    dark, ringing its bell as it passes you.
- **Shared changes so far:** see the table below.

## The concept
Toriano is the big city of the game: Milan with a few Turin touches, in the weeks before Christmas, around the year
2000. The new Geometra arrives by regional train, lodges in an old courtyard tenement whose flats open onto shared
balconies, helps the neighbours, and works for the Cathedral Works, the office that has been restoring the cathedral
for 600 years. The main story ends on Christmas Eve, when the Golden Angel on the cathedral's top spire lights up
again over the square.

- **Feel:** fog, grey haze and orange sodium streetlights; orange trams; plane trees; pigeons; people in long coats
  and business suits; the first Christmas lights under the glass of the arcade.
- **Turin touches:** arcaded pavements along the avenue from the station, hot chocolate with coffee and cream in the
  cafés, and one Piedmontese-flavoured voice among mostly Lombard names.
- **Running gags:**
  - **Everyone's in a hurry.** Villagers check their watches, talk fast and cut conversations short. "Time is
    money" is the city's motto. The slow ones (Architetto Annoni, who thinks in centuries, and Franco the barman)
    stand out.
  - **The fog.** People get lost between their front door and the tram stop, drop umbrellas and gloves in it, and
    blame it for everything. Vigile Rocco directs traffic in it even when there isn't any.

## Ground rules for Toriano
- **Bigger than the villages.** About 370 m across, three times as wide as a village and nine times its area, a
  minute and a half's walk end to end. The trams make it quick to cross.
- **Season:** the Christmas season. There are no dates: Christmas is "coming soon" until the finale says it's
  Christmas Eve.
- **Money:** lire, with city prices.
- **Language, names, originality, no magic:** as in `docs/WORLD.md`. Real places are inspiration only: the
  cathedral, arcade, opera house, castle, station and canals are invented, with invented names.

## The place
Laid out like the real city's compass, squeezed together. North is up (towards negative z in the game).

```text
                                 N
 +---------------------------------------------------------------+
 |  backdrop blocks and 1950s towers, fading into haze; the Alps  |
 |                                                                |
 |   CASTELLO ROSSO          [TEATRO CIVICO]          TORIANO     |
 |   & PARCO DEI PLATANI      opera square           CENTRALE     |
 |   pond, plane trees  o          |                 station  o   |
 |   chestnut cart     /     GALLERIA DELLE         (arrival)     |
 |                    /        STELLE                   /         |
 |                   /         arcade         arcaded avenue      |
 |      .---------- tram loop ----o------------------'            |
 |      |                         |                               |
 |      |        [ DUOMO ]   cathedral square   o                 |
 |      |   works yard, marble yard, Rocco's platform             |
 |      |                                                         |
 |      |   building sites            tenement blocks             |
 |   o--'                                                         |
 |  ~~ NAVIGLIO DEI FIORI ~~ bars, footbridge   [TENEMENT]        |
 |  ~~~ DARSENA (dock basin) ~~~  crane          number 14        |
 |  ~~ canal ~~        flea market               courtyard, home  |
 +---------------------------------------------------------------+
   o = tram stop (five, one loop line)
```

| Area | What's there |
| --- | --- |
| Cathedral square (centre) | The Duomo, pink-white marble with a forest of spires and the Golden Angel on the top spire. The big Christmas tree, hundreds of pigeons, Vigile Rocco's traffic platform, a tram stop. Behind the cathedral: the Cathedral Works office and the marble yard, where you quarry marble offcuts. |
| Galleria delle Stelle (north of the square) | The glass-roofed arcade, with a star pattern in its glass dome lit up for Christmas, a mosaic floor and café tables. Chiara's tiny workshop is here. It runs north to the opera square. |
| Opera square (north) | The Teatro Civico, a plain cream opera house, with a small square and a statue. Maestro Gino lives in the prompter's box under the stage. Evening crowds in coats. A tram stop. |
| Castello Rosso and Parco dei Platani (north-west) | A big red-brick castle with a gate tower. Behind it the plane-tree park with a duck pond, holm oaks and box hedges: the green corner for pruning wood and picking winter flowers. Gennaro's chestnut cart at the castle gate. A tram stop. |
| Toriano Centrale (north-east edge) | The grand grey stone station where the regional train arrives. The departure point. The tram line starts here, and an avenue with arcaded pavements leads towards the centre. The tram depot and its scrap pile are nearby. |
| Naviglio dei Fiori (south-west) | Two canals meeting at the Darsena, the dock basin, where the cathedral's marble still arrives by barge. Canal-side bars (Franco's among them), iron footbridges, a flea-market stall, moored barges, the crane at the dock. A tram stop. |
| The tenement (south) | Number 14: an old courtyard tenement in ochre plaster, three floors of flats opening onto shared balconies with grey stone slabs and iron railings, and the toilet at the end of the balcony. Augusto's lodge by the gate, Ragioniere Sala's office, Simone's and Elvira's flats, your flat, and the roof terrace above it. Other tenement blocks around it. |
| Building sites | Fenced with poster-covered hoardings, scattered round the city. Builders' skips to dig through for metal and bricks, and Roman finds for the metal detector. |
| The edge | Rows of tall façades past the walkable streets, fading into grey haze, with a few 1950s towers on the skyline and the cathedral spires the tallest thing in view. On very clear days, the white line of the Alps to the north. |

The tenement's names and the invented names in this doc that the user didn't choose (Teatro Civico, Toriano Centrale,
number 14) can change.

## Getting there and around
- **Arrival by regional train.** The bus covers the small villages; one of them, the rice village (the real Turin to
  Milan railway runs past the rice fields), has the little station where you change to the regional train for
  Toriano. Toriano isn't reachable from Monteforchetta directly until later in the story. The rice village
  (Casalrana, `docs/locations/rice_village.md`) adds that station. Its finale gets the regional train stopping again
  and sets `rice_village_trainStops`, the flag Toriano's map entry reveals on.
- **Until that link exists**, Toriano stays off the travel map and tests reach it with `--island=metropolis`.
- **The departure point** is the station platform. For now it's a feature of kind `boat`, as `docs/WORLD.md` asks,
  labelled as the train.
- **Trams.** Old orange trams run one loop line with five stops: Toriano Centrale, the opera square, the castle park,
  the canals and the cathedral square. All five work from the start. At a stop you choose another stop and take a
  short ride: you board, the view follows the tram for a few seconds, and you step off where you chose.
- **Traffic.** Small boxy cars and scooters drive along the streets and park along the kerbs. Moving cars keep to
  their lanes, stop at crossings and for the player, villagers and trams, and never hit anything.
- **Passers-by.** People in long coats and business suits hurry along the pavements and never stop to chat.

## Look
- **Buildings:** a Milanese mix. Tall blocks in ochre and the city's warm yellow plaster, grey granite bases, iron
  balconies, terracotta roofs. The tenement in ochre with grey stone balconies and iron railings round its courtyard.
  The red-brick castle, the pink-white marble cathedral bristling with spires, the glass-and-iron arcade, the plain
  cream opera house, the grand grey stone station. A few 1950s towers on the skyline.
- **Streets:** paving stones, cobbles and asphalt with tram tracks, not grass. Grass only in the park and in a few
  courtyards.
- **Plants:** bare plane trees with mottled bark and a few last brown leaves; evergreen holm oaks and box hedges in
  the park; ivy on the courtyard walls; Christmas roses and cyclamen in the park beds; the big Christmas tree in the
  cathedral square.
- **Animals:** pigeons by the hundred in the cathedral square, ducks on the park pond, gulls over the canal, cats in
  the courtyard.
- **Light:** grey day, golden night. A cool grey-blue haze by day under a low winter sun, dusk at five, then orange
  sodium streetlights and warm Christmas lights in the arcade, the square and the courtyard. The clock's parts of
  the day and the hours of requests stay as in every location; only the light shifts.
- **Weather:** fog most mornings, spells of cold drizzle, a few crisp clear days with the Alps on the horizon. Snow
  falls only once, as the finale's surprise.
- **The look block** (`location.json`): bluer shadows, slightly cooler highlights by day, little wind, a few motes,
  no fireflies (it's December) and only the odd falling leaf.

## Sound
- **Music:** original, in the game's procedural music system, with a theme for each part of the day. Italian pop
  around 2000, as in Monteforchetta, but more urban: a bouncy dance beat in the morning and afternoon, a smooth lounge
  feel in the evening and at night. Sleigh bells and a carol-like melody creep in as the main story nears Christmas
  Eve, and the finale has its own tune.
- **City sounds:** the cathedral strikes the hour, with a big peal on Christmas Eve; a low hum of traffic with a horn
  now and then; pigeons cooing and taking off in a clatter of wings. (Tram, canal and opera sounds were offered and
  not chosen.)

## The cast
Thirteen villagers. Ids are `metropolis_<first name>`, for example `metropolis_augusto`.

| Who | Where | Who they are | Outfit |
| --- | --- | --- | --- |
| **Signor Augusto Viganò**, the Portinaio | The tenement's lodge by the gate | The concierge. A retired opera chorus singer who sings while he mops the stairs. Meets your train, walks you home and runs your first day. Knows Maestro Gino from the chorus days. Keeps the building's lost property. | Grey cardigan, slippers, a scarf knitted by a soprano in 1974 |
| **Ragioniere Mario Sala** | His office in the tenement | The building's administrator, an accountant. Collects your rent. Every repair needs a residents' meeting, a vote and three quotes. | Brown suit, thick glasses, a ledger |
| **Architetto Ludovica Annoni** | The Cathedral Works office and the cathedral | Head of the Cathedral Works. Thinks in centuries, the only unhurried person in the city: "Nearly finished: 2130 at the latest." Knows every one of the cathedral's statues by name. Gives the main story. Runs the marble yard herself. | Long camel coat, hard hat, a roll of drawings |
| **Ambrogio "Tranvee" Colombo** | The tram line; breaks at the station stop | Tram driver ("Tranvee" is Milanese for it). Thirty years on the same line, calls his tram Carlotta, never late in any fog. Retires on Christmas Eve, so the finale is his last run. | Driver's blue uniform and cap |
| **Franco Brioschi** | His bar on the canal | An old barman who has served the same twelve regulars since 1962 and knows every secret in the neighbourhood. Moves very slowly in a fast city. | White barman's jacket, bow tie |
| **Chiara Pozzi** | Her workshop in the Galleria | A seamstress who rents the tiniest workshop in the arcade and dreams of her own fashion label. Sews from offcuts, so she's where fabric comes from. | Black polo-neck, a tape measure round her neck, pins in her collar |
| **Maestro Gino Pirovano** | The prompter's box under the opera stage | The opera prompter. Knows every opera by heart and only ever whispers. | Old velvet jacket, reading glasses |
| **Ottavio Re** | The castle park | Park keeper for 25 years. Prunes the plane trees, feeds the ducks, walks the same loop every morning even in the thickest fog. | Green park keeper's jacket, boots |
| **Gennaro Russo** | His chestnut cart at the castle gate | Roasts chestnuts every winter, up from Campania. Warm, chatty, and the best weather forecaster in the city. | Wool cap, fingerless gloves, apron |
| **Vigile Rocco "il Ghisa" Spreafico** | His platform in the cathedral square | Traffic warden ("il Ghisa", Milanese for the city's traffic police, after their old helmets). Proud of his white helmet and gloves. In thick fog he keeps directing traffic that isn't there. | White helmet, white gloves, dark uniform, whistle |
| **Valentina "Vale" Meroni** | All over; evenings at Franco's bar | Junior reporter at *La Sera di Toriano*, the evening paper, desperate for her first front page. Follows you with a notepad and a film camera. The face of the city's progress meter. | Bomber jacket, big scarf, camera |
| **Simone Bonfanti** | Next door on your balcony | Architecture student. Loud cassettes, cold pasta, endless cardboard models. A friendly rival in building. | Oversized jumper, round glasses |
| **Signora Elvira Marelli** | The end of your balcony | Hangs her washing across everyone's window. Remembers the courtyard "before the war". | Quilted housecoat, hairnet |
| **The player** | | The Geometra from Monteforchetta, sent for by the Cathedral Works. | The windbreaker, plus a long winter coat and scarf to unlock |

## The evening paper: Toriano's progress meter
Requests in Toriano earn **column inches** in *La Sera di Toriano* instead of the Sindaco's approval rating, which
stays Monteforchetta's. Vale writes the stories. Main requests are worth more than side requests, and there are more
inches on offer than the last milestone needs.

| Inches | Milestone | Reward |
| --- | --- | --- |
| 10 | A notice on page 18: "New Geometra in town." | Streetlight plans |
| 25 | A photo with a caption | A winter outfit: long coat and scarf |
| 45 | An interview, half a page | New pieces: the bathroom set (see below) |
| 70 | Your own weekly column, "The Geometra Answers", readers' building questions | A bigger roof terrace on the tenement |
| 90 | On the radio: a local station interviews you | A portable radio for your flat |
| 120 | The front page, on Christmas Day | Vale gets her promotion; the framed front page hangs in your flat. It needs the finale done too, so the front-page story is always the Golden Angel. |

## Gathering
| Material | Where it comes from |
| --- | --- |
| Wood | Pruning the plane trees in the castle park (the chopping minigame). |
| Stone | Marble offcuts in the Cathedral Works' marble yard (the quarrying minigame). |
| Metal | Builders' skips at the fenced building sites, head first, like Monteforchetta's garbage bins. |
| Clay (bricks) | Old bricks from the same skips. |
| Copper wire | Old overhead tram wire on the depot's scrap pile. |
| Fabric | Chiara's offcuts (her shop) and the flea-market stall by the canal. |
| Flowers | Christmas roses and cyclamen in the park beds. |
| Canal fishing | Old bicycles, a shopping trolley, a boot, and now and then a carp. City items, ids like `metropolis_bicycle`. |
| Lost things | Umbrellas, gloves and hats dropped in the fog (the shared lost things), for Augusto's lodge. |
| Score pages | Pages of Gino's score, blown across the city. They count only at night. `metropolis_score_page`. |
| Roman finds | Coins and odds and ends dug up with the metal detector at building sites. City items. |
| Treats | Panettone and hot chocolate with coffee and cream at Franco's bar; roast chestnuts from Gennaro. |

## Shops
| Shop | Sells | Buys |
| --- | --- | --- |
| Franco's bar | Panettone slices, hot chocolate with coffee and cream (treats) | Bicycles and canal junk |
| Chiara | Fabric, rugs, winter clothes (a long coat, a scarf, a wool hat) | Fabric and flowers |
| Gennaro | Roast chestnuts (treat) | |
| Ottavio | Wood bundles, young trees, seeds | Flowers |
| The Cathedral Works (Annoni) | Marble (stone) bundles, statue and pillar plans | Stone |
| Ambrogio | Copper wire from the depot, a tram driver's cap for the wardrobe | |

## Requests
Ids are `metropolis_<name>`. As everywhere, construction requests check what you built, not one layout.

### Main story
| # | Request | Given by | What you do |
| --- | --- | --- | --- |
| 1 | **Welcome to Toriano** | Augusto | He meets your train with a hand-drawn map and walks you home through the fog. Your first tram ride together, the neighbours, the keys. This is Toriano's first day: a request in steps, with his commentary to skip through. |
| 2 | **The Balcony Flat** | Ragioniere Sala | Pay the first month's rent in lire, then furnish the basics: a bed, a table, a chair and a lamp. The flat becomes your home (bed and wardrobe) and the roof terrace above it your plot. |
| 3 | **Marble by Water** | Architetto Annoni | The cathedral's marble still comes up the canal by barge, as it has for 600 years. Gather materials, then rebuild the crane at the Darsena and drive it with a waterwheel in the canal (a machine target, `fed:metropolis_crane`). A barge unloads the blocks for the spire. |
| 4 | **The Footbridge** | Franco | The old iron footbridge was condemned. Build a new one so his regulars reach the bar and the marble carts reach the cathedral, then add railings. Any continuous, supported path counts, as with Monteforchetta's road. |
| 5 | **Scaffolding for the Spire** | Annoni | Build a walkable climb of stairs and platforms from the works yard up the cathedral's side to the roof terraces. Any continuous climb counts, and you can really walk up it. The roof terraces become a place you can walk and build on. |
| 6 | **The Golden Angel**, the finale | Annoni | Up on the roof among the spires, build a windmill and carry its power to the Angel's floodlight drive (`fed:metropolis_angel`). Then, after dark, it's Christmas Eve: everyone gathers in the square, Ambrogio makes his last run, the bells peal, the Golden Angel lights up and the one snowfall begins. |

### Side requests
| Request | Given by | What you do |
| --- | --- | --- |
| **The Lost-Property Lodge** | Augusto | Everyone drops things in the fog and brings them to his lodge. Find five lost things around the city (umbrellas, gloves, a hat) and return them, for thanks and gossip. |
| **The Residents' Meeting** | Ragioniere Sala | To buy your flat outright you need the residents' vote: talk round every neighbour, then pay Sala. |
| **A Bathroom of Your Own** | Ragioniere Sala | Offered after the 45-inch interview, in which you complained about the balcony toilet. Fit a toilet, a washbasin and a bathtub in your flat, ending the running gag. |
| **A Shelter in the Fog** | Ambrogio | Passengers at the cathedral stop can't see the tram coming. Rebuild the stop's shelter with a bench, a streetlight and a sign. |
| **Chiara's First Collection** | Chiara | In steps: gather fabric and winter flowers for her first collection, then fit out her shop so shoppers stop at the window (a counter, two lamps, a rug, a painting and a splash of colour). She makes you a padded late-1990s jacket. |
| **The Scattered Score** | Maestro Gino | The wind blew the pages of a rare score across the city. Find six pages. Only at night, after the opera, when he's free. |
| **Pruning, then the Ducks** | Ottavio | In steps: prune six plane trees in the park, then use the wood to build a duck house out on the pond (a platform over the water with a roof). |
| **A New Chestnut Cart** | Gennaro | His old cart is falling apart. Build him a stall at the castle gate: a counter, a roof and a lamp for the dark afternoons. |
| **A Light in the Fog** | Vigile Rocco | Drivers can't see him in the fog. Build him a new raised platform in the cathedral square with a streetlight beside it. |
| **Roman Finds** | Vale | Toriano was a Roman town, and every building site turns something up. Dig up three Roman finds with the metal detector for her story. |
| **Full-Size Model** | Simone | He dares you to build his cardboard exam model full size in the courtyard: a pergola of four pillars with a roof and two benches. |
| **A Tree for the Courtyard** | Signora Elvira | She wants a proper Christmas tree in the courtyard, like before the war. Plant a young tree with flower beds and lamps around it. |
| **The Canal's Treasures** | Franco | Fish three old bicycles out of the canal to hang on his bar wall. |

Six main and thirteen side requests.

## Rooms you can walk into
- **The tenement:** your flat, Augusto's lodge, Simone's and Elvira's flats, Ragioniere Sala's office.
- **Shops:** Franco's bar, Chiara's workshop in the Galleria, the Cathedral Works office. Gennaro's cart is open-air.
- **The cathedral nave:** a huge candlelit interior with stained glass and the Christmas crib.
- Not the opera house or the station hall.

## Changes to shared code this needs
Each is the smallest general version, comes with a test, and is named at the top of the pull request that makes it.
Other locations can reuse all of them.

| Change | Why | Stage |
| --- | --- | --- |
| **Map size per layout:** a `size` in a layout, defaulting to today's 124 m, used by the terrain mesh, its height texture and the water plane. *Done in stage 1.* | The city is about 370 m across | 1 |
| **Ground paint:** a layout's `ground` list of rectangles, circles and lines painted over the grass (asphalt, setts, slabs, gravel), drawn by the terrain shader, with greenery kept off paving and inside a decor `area`. *Done in stage 1, as layout data rather than script code.* | A city isn't a meadow | 1 |
| **A building's height (`h`) for the camera**, so it doesn't pass through the upper floors of a tall block. *Done in stage 1.* | City blocks are 12 to 22 m tall | 1 |
| **A departure point with any id**, and an optional `depart_label` ("Take the train"). *Done in stage 1.* | The station isn't a bus stop called `boat` | 1 |
| **Raised floors:** a layout's `floors` (slabs, solid blocks, stairs that rise) and buildings with a walkable roof (`roof_walk`), read by `WalkWorld` and build mode; build sites with a floor height (`floorY`); rooms on their own storey (`y`), so rooms stack with their own doors; scenery-only buildings (`solid: false`). *Done in stage 2.* | The cathedral's roof terraces, the tenement's balcony, flats and terrace, the old bridge's deck | 2 |
| **Rides between stops:** features of kind `stop` on a `line`; at a stop you choose another and ride there (`Travel.stops_on`, `game.ride_to`). *Done in stage 2.* | The trams. Funiculars, public lifts and cable cars elsewhere can reuse it | 2 |
| **A path check for any zone** (`path:<zone>`), with endpoints that may be at different heights. *Done in stage 3: the build check came with Boccapioppo's stage 3, and Casalrana's made it climb stairs and gave endpoints a height (`y`); Toriano added endpoints that lie just outside the site (a quay, a roof terrace).* | The footbridge, and the scaffolding climb | 3 |
| **What fishing catches, per location**, and what a node gives: *done by Boccapioppo's stage 3 (`fish`, `gives`).* Toriano added what the lost things are (`lost`), gathering spots with their own label, hours and lines, and a location's own models for them (`node(n)`). | Bicycles, a trolley and a boot from the canal; skips, score pages at night, Roman finds | 3 |
| **A location's own progress meter**: *done by Boccapioppo's stage 3 (`LocationMeter`).* Toriano added milestones that wait for a request (`requires`), milestone items, and build sites that grow with the meter. | The evening paper's column inches | 3 |
| **Three new building pieces:** toilet, washbasin, bathtub (agreed with the user in the interview). *Done in stage 3.* | A Bathroom of Your Own; usable anywhere | 3 |
| **Build mode on raised floors:** the cursor lands on balconies, terraces and upstairs floors, and the site's grid is drawn there; the build view can move over the whole of a big map (`BuildMode.view_limit()`), and a cell is checked again when the cursor comes back to it from the build bar. *Done in stage 3.* | Furnishing your flat; the windmill on the cathedral's roof | 3 |
| **Walking out of an edge you overlap** (`WalkWorld.unstick`): stepped off the side of a stair onto the ground beside it, you were still touching its edge and could never walk away; you now ease out to the nearest free spot within half a metre. *Done in stage 3.* | Found by the side-requests playthrough at number 14's courtyard stair (which now has sides too) | 3 |
| **Villagers squeeze past you** after waiting two seconds for you to step out of their way (`NpcAgent`): met head-on on a narrow balcony, you couldn't, and you'd both wait for ever. *Done in stage 3.* | Number 14's balconies are 1.3 m wide, and the neighbours use them | 3 |
| **Daylight shifted per location**: a look's `sunrise` and `sunset` (only the light follows them, `Daylight.light_hour`; the clock's parts of the day stay), and how often mornings are misty (`mist`). *Done in stage 4.* | Dusk at five in December, fog most mornings | 4 |
| **A scripted snowfall**: a `snow` weather that only a request brings (a step's `onDone` weather), with flakes and a light white dusting on the ground, paving and roofs (the shader global `world_snow`). *Done in stage 4.* | The finale | 4 |
| **New clothing shapes**: a long coat and a helmet, locked until Toriano gives them. *Done in stage 4.* | The cast's winter outfits | 4 |
| **Music that changes with the story** (`"when": [{flag, parts}]` in a location's music) and **no songbirds** where a look says so (`songbirds`). *Done in stage 4.* | Christmas Eve's sleigh bells and the finale's tune; a city in December | 4 |

Everything else lives in Toriano's own files (`docs/WORLD.md`): `godot/data/locations/metropolis/`,
`godot/scripts/locations/metropolis.gd` and helpers in `godot/scripts/locations/metropolis/`,
`godot/tests/test_metropolis.gd`, and the playthroughs `godot/tests/play_metropolis.gd` (the walk round the city),
`play_metropolis_story.gd` (the main story) and `play_metropolis_side.gd` (the side requests, from the main story's save),
with their helpers in `metropolis_base.gd`. Trams, traffic and passers-by are location code;
moving cars and trams block the player through `WalkWorld`'s moving bodies.

## Build stages
One pull request per stage. Each keeps the game playable and the tests passing.

1. **Ground and map.**
   - The shared map-size and ground-paint changes.
   - The ground shape: flat city ground, the canals and the Darsena, the park pond.
   - The street plan: streets, squares, the tram loop, the station platform as spawn and arrival, the departure
     point, the nav graph, paths, build zones and the tenement roof terrace plot.
   - A hidden map entry and a first `look` in `location.json`.
   - Plain boxes for the buildings so the map reads in screenshots.
   - `test_metropolis.gd`: a playable world (the arrival is walkable, every nav spot is reachable, water where the
     canals are, build zones on dry ground).
2. **Buildings and scenery.**
   - Models for the cathedral (spires, the Golden Angel, roof terraces), the Galleria, the Teatro Civico, the Castello
     Rosso, Toriano Centrale, the tenement with its courtyard and balconies, the bar, the city blocks and the
     backdrop at the edge.
   - Rooms you can walk into, with furniture and routes.
   - The trams on their loop and rides between stops; plane trees, sodium streetlights, newsstands, payphones,
     hoardings and skips, parked cars, the Christmas tree.
3. **People, dialogue and requests.**
   - The thirteen villagers with schedules, greetings, topics and gifts.
   - The nineteen requests, the six shops, the city items and the column-inch meter.
   - The shared path check, fishing catches, meter and bathroom pieces.
   - `play_metropolis_story.gd` and `play_metropolis_side.gd`: a scripted playthrough of every request with real input.
4. **Look and ambient life.**
   - Tuning the look block, the fog, sodium and Christmas lights at night, dusk at five, the finale's snowfall.
   - Pigeons, ducks, gulls and cats; hurrying passers-by; moving traffic (this may get its own pull request).
   - The music themes and city sounds; the cast's outfits.

## Risks
- **Size.** Nine times a village's area means far more to draw. Buildings are built from few, merged meshes, the
  edge is cheap backdrop boxes, small details fade with distance, and passers-by and cars exist only near the player.
  Frame time is measured before and after each stage (in the software renderer here; real graphics cards are not
  checked in a cloud session).
- **Moving traffic** is the most code for the least gameplay. It comes last and can be cut back to parked cars and
  trams if it misbehaves.
- **The train link** depends on the rice village, which another session builds.

## Checks for every stage
`godot/run_tests.sh`, `npm test` and `npm run build`; screenshots of Toriano in both renderers
(`--island=metropolis`); from stage 3, the scripted playthrough of its requests. Each pull request says what was
verified in play and what was only unit-tested.
