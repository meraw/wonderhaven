# Monteforchetta: design for the first location

Agreed with the user on 2026-11-04. **Nothing here is built yet.** This doc is the plan the build stages follow.
It replaces Hearthglow Village. The game keeps its working title, *Wonderhaven*, until the new setting is in place.

## The concept
A cozy building game with a comic streak, set in an invented corner of north-west Italy around the year 2000.
It should feel like the region the way a Nintendo game feels Japanese: places, plants, food, jobs and habits that
ring true, without becoming a documentary. The comedy layer comes later, once the setting is in place.

The world grows into many locations reached by transport instead of walking: first the bus, later perhaps a
regional train or a helicopter. Locations floated so far: a vineyard hill village (this one), a big city like
Milan, a dark port city like Genoa's old alleys, cliff villages like the Cinque Terre or a glassmakers' island,
and smaller villages.

## Ground rules
- **Era:** the late 1990s, before smartphones. Payphones, newsstands, beige computers with dial-up modems,
  cassettes and boxy TVs.
- **Money:** lire, with big comic numbers. The switch to the euro happens later, in another location.
- **Language:** plain English. Italian is used only for names and for job titles and honorifics: Sindaco (mayor),
  Geometra (surveyor-builder), Perito (technician), Commendatore, Nonna. No stock exclamations.
- **Names:** realistic regional names, made memorable with nicknames and titles.
- **No magic:** the building mechanic stays, but its framing is a surveyor's job, not a magic tool.
- **Clockwork Cove** is hidden from the map until it is reworked into a location of the new world.
- **The web version** stays frozen. All of this is Godot only.

## The place
A Langhe-style hilltop village with a side valley, in autumn at harvest time.

| Area | What's there |
| --- | --- |
| Hilltop | The castle at the top, now the town hall. Below it the piazza with the dry fountain, the church and bell tower, the newsstand and tobacconist, Ornella's bakery, Elio's shop, village houses. |
| Slopes | Vineyard rows striped across the hillsides, with a rose bush at the end of each row. |
| Hazelnut groves | Gigia's groves, low and leafy. |
| Side valley | Oak and chestnut woods with boars, mushrooms and chestnuts, a stream fed by a spring, and the ruined farmhouse that becomes the player's home. It sits where the vines meet the woods. The user left the spot open. |
| The road | Winds down from the village. A storm has washed part of it away. Aldo's bus turns round at the washout. |
| Horizon | Rolling hills and other hilltop villages fading into haze, and a snowy Alpine range on clear days. No sea. |

**Look:**
- **Village houses:** plaster in ochre, cream and faded rose. Curved terracotta roof tiles, wooden shutters and
  small balconies with geraniums.
- **Farmhouses among the vines:** local sandstone and old brick.
- **The castle:** brick and stone, with the town hall's flags.
- **Plants:** autumn vines turning yellow and red, roses at the row ends, hazelnut, oak, chestnut, walnut and a
  persimmon tree with orange fruit on bare branches. Pumpkins in the garden beds, cyclamen in the woods.
- **Animals:** wild boars, village cats, chickens in farm courtyards and crows. There are no ducks, since there is
  no river.
- **Light:** a warm golden autumn grade, fog filling the valley in the mornings, autumn showers. This is
  Monteforchetta's look in the per-location look system proposed in `GRAPHICS.md`.

**Music:** original pop in the style of Italian pop around 2000. It keeps today's change of theme with the time of
day: dawn, morning, afternoon, evening and night.

## The cast
The current villagers are recast as Italians, keeping their roles and personalities. The chibi style stays, with
late-1990s outfits. Internal ids such as `fern` and `bram` can stay for now to limit churn in saves and tests.

| Today | Now | Who they are |
| --- | --- | --- |
| King Percival | **Sindaco Commendator Gustavo Dalmasso** | The pompous mayor. Runs things from the castle town hall, wants re-election, and takes credit for everything. He also greets the player and runs the guided first day as a long-winded comic tour the player can skip ahead in. The player lodges in his castle's spare room. |
| Fern | **Gigia Ghisolfi** | Hazelnut farmer who talks to her trees. Down to earth, stubborn and kind. |
| Bram | **Elio "Fusibile" Manzone** | Shy electrician with wildly extravagant secret designs. Nicknamed "Fusibile", the Fuse, ever since he blacked out the whole village during a football match. |
| Tilly | **Federica "Fede" Cauda** | Teenage computer whiz, convinced the village needs a website. |
| Mabel | **Ornella Tealdi** | Brisk baker who treats the wild boars as a personal insult. |
| Captain Wendell | **Aldo "Tornanti" Barbero** | Bus driver who knows every hairpin bend in the valley and has a tall tale about each one. |
| Odessa | Removed | Her mentor and tutorial lines go to the mayor. |
| The player | **The new Geometra** | A freshly qualified surveyor-builder sent by the province to fix the village. Arrives on Aldo's bus, gets dropped at the washout and walks the last stretch up with a suitcase. |

Outfit ideas:
- **The mayor:** a suit with a tricolour sash.
- **Gigia:** a work jacket and boots.
- **Elio:** overalls covered in pens.
- **Fede:** an oversized hoodie, big jeans and a portable CD player.
- **Ornella:** an apron.
- **Aldo:** a driver's shirt and cap.
- **The player:** a windbreaker and a clipboard.

## Systems, renamed
| Today | In Monteforchetta |
| --- | --- |
| The Starforge Tool | The Geometra's kit: tape measure, spirit level and clipboard. Build mode works exactly as now. |
| Spark | Removed. Builds cost materials, and some cost lire. Today 17 of the 46 pieces, and several requests, cost Spark. |
| Coins | Lire, with prices scaled up to believable late-1990s amounts. |
| Kingdom Harmony | **The mayor's approval rating.** Milestones mix building unlocks with comic honours: new pieces and a bigger farmhouse plot, an "honorary citizen" sash, a plaque with your name. Today's 120 milestone, the harbour charter, becomes another reward. |
| Magic fragments | **Villagers' lost things**: keys, reading glasses, a dog's ball. You return them for thanks and gossip. The tutorial's first pickup could be the mayor's dropped reading glasses. |
| Treasure hunt guided by the tool's hum | **A metal detector** that beeps faster near buried finds: old coins, junk and the occasional real treasure. |
| Gathering | Chopping wood in the woods and quarrying the local sandstone stay. New: hazelnut picking, which replaces acorns and apples, pumpkins in the garden beds, and foraging mushrooms and chestnuts. |
| Fishing | None in Monteforchetta. It stays in the game for other locations. |
| The ferry and island map | Aldo's bus and a travel map. |
| Truffles | Talked about in the woods. A truffle-dog quest comes later, not in the first pass. |

## Requests
Today Hearthglow has 13 requests, 7 of them main story. They map like this:

| Today | Now | Given by | What you do |
| --- | --- | --- | --- |
| The Starforge Tool | **Welcome, Geometra** | Mayor | His long-winded tour. Gather a little wood and stone, receive the kit. |
| Repair the Orchard Bridge | **The Washed-Out Road** | Aldo | Gather materials, rebuild the missing stretch of road so the bus can come up, then add railings. Same rule as the bridge: any continuous, supported path counts. |
| Furnish the Workshop | **Elio's Shop** | Elio | Gather materials, hear his plan, then fit out his shop: seats, lamps, shelves, a workbench, a splash of colour. |
| Restore the Garden Fountain | **A Fountain for the Website** | Fede | A waterwheel in the valley stream drives a pump that sends water up through pipes to the piazza fountain. Fede photographs it for the village's first website. |
| A Home of Your Own | **A Roof of Your Own** | Mayor | Pay the mayor in lire for the deed to the ruined farmhouse, rebuild walls, door, roof and bed, then make it cosy. |
| The Royal Decree and All Aboard! | **The City Bus**, the finale | Aldo | The new city bus is too long for the old turnaround, so you rebuild the stop and turning circle. This opens the bus line to the city and the travel map. There is no approval-rating gate. |
| Shiny Stones for the Castle | **A Plinth for the Sindaco** | Mayor | He wants local sandstone for a plinth to hold a bust of himself. |
| Squirrels in the Scones | **Boars in the Bakery** | Ornella | Lure the boars back to the woods with chestnuts, then deal with the aftermath. |
| Petals for the Plaza | **Pumpkins for Gigia** | Gigia | Grow pumpkins in her garden beds. |
| A Fishy Tale | **Aldo's Porcini Bet** | Aldo | He bets you can't find three porcini mushrooms. |
| Lost Starforge Notes | **Beep, Beep** | Mayor or Fede | Three finds with the metal detector. |
| Bright Ideas | **A Bright Idea** | Fede | Light a lamp from a power source you built. |

The six main requests become: Welcome, Road, Elio's Shop, Fountain, Roof, City Bus.

## Build stages
Each stage keeps the game playable and the tests passing, and ends with a pull request to review.

1. **Names and text.**
   - Villagers, dialogue, requests, tutorial, tip cards, items and shops.
   - Coins become lire and Harmony becomes the approval rating.
   - Spark is removed, fragments become lost things and the treasure hunt becomes the metal detector.
   - The ferry becomes the bus, and Clockwork Cove is hidden.
   - The map stays Hearthglow's for this stage, so wording that mentions the river and orchard may read oddly
     until stage 2.
2. **Map and buildings.**
   - A new ground shape: hilltop, side valley, road with the washout. Today the ground shape is code in
     `Heightfield`, and moving it into data would make later locations cheaper.
   - The layout: castle town hall, church and bell tower, newsstand, bakery, Elio's shop, houses, the ruined
     farmhouse, the stream and spring, groves, vineyard rows and woods.
   - Rooms you can walk into, paths, schedules and build zones.
3. **Look and plants.**
   - Plaster and stone palettes, curved terracotta roof tiles, the church and bell tower.
   - Vines in rows with autumn colours, hazelnut, oak, chestnut, persimmon, pumpkins, mushrooms, boars.
   - The autumn grade, valley fog and the hills-and-Alps horizon.
4. **Outfits and music.** Late-1990s outfits for the cast, then the pop-style music for each part of the day.
5. **Later.** The comedy layer, the truffle dog, more locations and transport, the euro switch somewhere else,
   and a new game title.

## Open points
- Is "Fusibile" Elio's nickname, as written above, or his actual surname?
- What replaces the crystal material, and do metal and clay stay? One idea: metal comes from scrap and old iron in
  the farmhouse, and crystal becomes copper wire, which suits Elio.
- The farmhouse's exact spot is open. This doc places it where the vines meet the woods.
