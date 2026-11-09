# Status

Working title: **Wonderhaven** (to be renamed). The game is moving to a comic, late-1990s north-west Italy (`docs/WORLD.md`). The first location, **Monteforchetta** (`docs/MONTEFORCHETTA.md`), replaces Hearthglow in stages; **stages 1 to 4 (names and text, map and buildings, look and plants, outfits and music) are done** (see below). Clockwork Cove, from the old fantasy setting, is still in the game but hidden from the map.

- **Godot 4 (`godot/`)** is the game. See `godot/README.md`. Its content (`godot/data/*.json`) is edited directly.
- **Web / Three.js (`index.html`, `src/`)** is the original prototype, **frozen**: kept as it was, no longer updated. Everything added since the Godot port (interiors, shops, staged requests, the guided day, the look) exists only in Godot.

## Building by dragging, corners that close, and fixes found on the way (09/11)
The request was open ("improve my game"), so the work went to the centre of the design, building. All of it is shared:
it works the same in every place.
- **Hold and drag builds a row.** With a piece in your hand, hold the left button and drag: a piece goes down on every
  tile the cursor crosses. The bus stop's twelve paving stones, or the Sindaco's eight railings, are one stroke
  instead of one click each; a room with a floor, four walls, a roof and a hedge round it is eight strokes instead of
  sixty-three clicks. A click still builds one piece (it now goes down when you press, not when you let go).
  - **It stays on the level it began on.** Paving begun on the ground lies on the ground, and passes over a tile that
    already has something instead of stacking on it. Railings begun on a bridge deck stay on the deck, walls begun on
    a floor stop at the floor's end, and nothing dragged off the side of a deck or a platform is dropped below. A
    second course of stone blocks, begun on a block, is laid along the blocks under it.
  - **Fences, walls and railings run straight** along the edge they began on, however the hand wobbles. To turn a
    corner, let go and start the next side. Tile pieces (paving, hedges, floors) follow the cursor anywhere, round
    corners and in a zigzag.
  - **Big pieces go edge to edge**: platforms and roofs every two tiles, benches end to end.
  - **A fast sweep leaves no gap**: every tile between one frame's cursor and the next is filled.
  - **The row is set by where you press**, even if that first spot is taken: a row begun on a tile that already has a
    fence carries on along the same edge from the next free tile.
  - **Nothing is refused out loud mid-drag.** A tile where the piece doesn't fit is passed over without a toast. If
    the whole press built nothing, letting go says why, as a click always did. What you can't afford goes into your
    draft, as with a click, and dragging along drafted pieces builds them.
  - **A shaky click isn't a drag**: the cursor has to travel 12 pixels and reach another tile first.
  - **One drag is one undo** (and one redo).
  - **What you see**: the status line counts as you go ("Dragging: 6 placed. Let go to finish."). Until you've dragged
    once it also says you can ("Click to build the fence (🪵1), or hold and drag for a row"); the "How building works"
    card and the ❓ key list say so too.
  - **Gamepad**: holding A while the cursor moves does the same. It shares the mouse's code but was not tried on a
    controller.
  - Where: the rules are in `BuildStroke` (`scripts/systems/build_stroke.gd`); `History` groups a drag's pieces into
    one step; `BuildMode.press`, `_stroke_step` and `end_stroke` are the interactive part.
- **Walls meet at a tile's corner.** Two edge pieces (walls, fences, railings) on different edges of the same tile
  used to bump into each other where their ends cross, so a room built on its own floor couldn't close its corners:
  the second wall of each corner was refused, and the only way round was to stand it on the tile outside. They may
  now meet (`BuildGrid.meet_at_a_corner`). Two on the same edge still bump, and furniture still needs a tile clear of
  walls.
- **Build another like it.** A selected piece's panel has a button that puts the same piece in your hand, turned and
  painted the same way.
- **After you build, the status says so.** With the cursor still on the piece just built, the status line turned red
  ("Bumps into the fence") and a red outline covered the new piece. It now says "Fence built", and the outline stays
  away until the cursor or the view moves. Pieces that stack (blocks, paving) still show the next one on top.
- **Fixes**, each found while playing the above:
  - **Ctrl+Z turned the view.** Z is also "turn camera right", so every undo in build mode swung the camera for as
    long as the key was down (a fifth of a second turned it 20°). The camera keys now wait while Ctrl or Cmd is held.
  - **Two colours couldn't be clicked.** A selected piece's twelve colour swatches were in one row, wider than their
    panel, and the last two ran off the right edge of the window. They wrap onto two rows.
  - **The bakery cat took the boars' prompt.** `play_boars` failed one run in three here: the cat sits 1.2 m from one
    of Ornella's boars, and depending on where the boar had wandered, E petted the cat instead of offering the
    chestnut. Petting (cats, hens, ducks) is now only offered when nothing else is in reach in front of you
    (`Prompts`, `scripts/systems/prompts.gd`; `"ambient": true` on an interactable).
- **Checked:**
  - **Tested** (`godot/run_tests.sh`, 503 passed, 490 before; 510 after merging main). `test_build_stroke` (10 tests) covers: a shaky
    click; a fast sweep's path; paving kept on the ground and off what's there; big pieces edge to edge; a fence's
    straight row on each of its four edges; railings kept on a bridge's deck and a chair not dropped off its side;
    floor tiles not piled on floor tiles, and a second course of blocks; walls meeting at a corner while a second wall
    on the same edge, a fence on a walled edge and a table on a walled tile still bump; one undo for a drag; a drag
    that can't be undone whole being put back. `test_prompts` (3 tests) covers petting giving way, with the bakery
    cat's and boar's real positions. Each rule was also switched off in turn to see its test fail (eleven changes,
    each caught).
  - **Played** (`play_build_rows`, 26 checks, in `play_all.sh`; real mouse presses, moves and releases):
    - a click lays one stone and the status mentions dragging; a click with a 5-pixel slip lays one;
    - a drag paves six tiles flat on the ground while the status counts; one undo and one redo; the view doesn't
      turn; the hint is gone afterwards;
    - dragging back over the row adds only the free tile and stacks nothing; a sweep made in a single frame leaves
      no gap;
    - a fence dragged in a zigzag comes out straight; afterwards the status says "Fence built" with no outline over
      it, and both come back when the cursor moves on;
    - with 2 wood a five-tile drag builds two and drafts three, and with wood again a drag along the drafts builds
      them;
    - "Build another like it" gives the same turn and paint; all twelve swatches are inside the window;
    - a row begun on a tile that has a fence carries on along the same edge; two fences meet at one tile's corner;
    - railings dragged along the washout's bridge stand on its deck, one a plank; planks dragged out from the bank
      stop at their reach with nothing drafted past it;
    - on the farmhouse plot, one zigzag stroke floors a room of 24 tiles, four strokes wall it in with every corner
      closed and every wall on the floor (6, 4, 4, 6), two strokes roof it (six roofs edge to edge), one stroke runs
      13 hedges along the front and round the corner, and three undos take the hedge and roofs off again. For the
      roofs the script looks for a point on the walls where the first roof fits, as a player does by watching the
      outline.
  - **All of Monteforchetta's playthroughs pass** (`play_all.sh`: 25 runs, 260 checks). Before the change the same
    set passed apart from `play_boars`, which lost the prompt to the cat in one run of three. The set caught a
    mistake on the way: the first "Fence built" went by where the cursor was on the screen, so with the view moved
    under a still cursor (as the playthroughs point) it hid the reason a different tile was refused; `play_build`,
    `play_build_clarity` and `play_full` failed on it until it also watched the view.
  - **Seen** in the playthrough's screenshots: the paving mid-drag with the counting status, the straight fence, the
    selected piece's panel with two rows of swatches and the new button, the railings along the bridge, the walled
    room with its corners closed, and the roofed house with its hedge.
  - **Not checked:** how dragging feels with a real mouse at full frame rate, a trackpad, a gamepad; whether 12
    pixels is the right threshold on a high-resolution screen; the other places' playthroughs (their owners' to
    run: a click now builds on the press, and walls may meet at a corner, in every place).
- **Noticed, not changed:** aiming at the last few centimetres of a floor tile's edge from the side you're looking
  from hits the tile's side face, so the wall goes on the grass beside the floor (the outline shows it before you
  click); a piece aimed at through a roof goes on the floor underneath; the paint in your hand stays for whatever you
  pick up next, as it does after choosing a swatch, so after "Build another like it" on a pink fence the next walls
  are pink too (copying an unpainted piece clears it).

## The redesign (07/11)
After a review of how the game plays, the user agreed a new design: building is the core, the game values what you build
whether or not anyone asked for it, requests become briefs with checks, and the day becomes a work day you end
yourself. All of it, and the order it's built in, is in `docs/DESIGN.md`. All seven stages are done for Monteforchetta.

### The village comes alive (Monteforchetta)
- **Tastes.** Each villager likes some pieces and paint colours (`data/tastes.json`):
  - Gigia: hedges, flower beds, young trees, fences, greens.
  - Elio: lamps, yellow.
  - The Sindaco: statues, pillars, columns, arches, red.
  - Fede: electric lamps, signs, windmills, blue and lilac.
  - Ornella: benches, tables, flower beds, counters, pink.
  - Aldo: benches, roofs, signs, street lights, bus blue.

  A piece they like, or a piece painted their colour, put up within 8 m of their spot (their hangout, or Elio's door)
  earns a heart and a remark ("Oh, a hedge! You do know me."), once a day each. The morning paper gives away one taste
  you don't know yet ("Overheard: Gigia can't walk past a hedge without patting it."), and the bag lists the tastes you
  know under Friends.
- **The ceremony reacts to tastes**: a villager who likes a piece in what's being opened cheers it with their remark and
  likes you a heart more.
- **Market day** every fifth day (day 5, 10, ...), from 8 AM to 7 PM (`data/market.json`):
  - Gigia, Ornella, Aldo and Fede, in that order, stand at the counters you've built, one each.
  - At a stall they pay half as much again for what they buy, and sell a market line: Gigia pumpkins, Ornella cheap
    hazelnut cake, Aldo fabric, Fede copper wire. Their shop option says "Market stall: today's prices".
  - The paper warns you the morning before and counts the stalls on the day, or says there was nowhere to sell.
  - Remove a counter and its seller goes home. A market bundle can never be sold back at a profit, even on market day
    (tested).
- **Evening music**: at dusk, with the piazza fully lively and you nearby, an accordion waltz plays (`hearthglow_festa`,
  the place's `gathering` tune) and the gathered villagers clap and wave.
- **An album of openings** on the approval screen: the day, what was opened, where, and its mark, newest first.
- Where: `Tastes` (`scripts/systems/tastes.gd`), `Market` (`scripts/systems/market.gd`), `Visits.gathering`,
  `AudioDirector.song_for(..., festa)`, `Inauguration.remember`; the game's `_update_market` and `festa_now`.
- **Checked:**
  - **Tested** (`test_alive`): every villager has tastes, real pieces and paintable colours; a liked piece by their
    spot pleases them once a day, not across the village or while they're away; gossip one taste at a time, printed
    with the market line; the ceremony's fan reaction; market days, stalls, sellers, prices, lines and paper; the
    festa's tune and when it plays; the album, saved.
  - **Played** (`play_alive`, 9 checks, in `play_all.sh`): a hedge by Gigia's gate pleases her and the bag then lists
    her tastes; Elio cheers the lamps opened by his door; day 5's paper counts two stalls; the album lists the opening;
    at 8 AM Gigia and Ornella stand at the two counters; Gigia's stall pays more and sells pumpkins; at 7 PM they go
    home; at dusk the festa plays at the fully lively piazza. The script moves the clock on to the market's opening
    and closing instead of waiting.
  - **Not checked:** hearing the festa (the test machine has no sound); a market with three or four stalls.

### More to build (Monteforchetta, after the redesign)
- **Four more briefs**, so there's more to build than the main story's six:
  - **A Plinth for the Sindaco** (his side request) is now a build on the castle steps: three stone pieces, at least
    two metres tall. Wishes: taller than three metres (the Sindaco), a light on it (Elio), flowers round it (Gigia).
    It used to be "gather stone and copper wire, hand them over".
  - **Tables Outside the Bakery** (Ornella, after the crossing): two tables and four seats outside her door.
    Wishes: something green (Gigia), a sunshade (Ornella).
  - **A Stall for Gigia's Hazelnuts** (Gigia, after the bus stop), **anywhere in the village**: a counter and two
    green things round it. Wishes: painted cheerfully (Gigia), a bench for customers (Ornella).
  - **A Reading Corner** (Fede, after the bus stop), anywhere: a seat, a light and a bookshelf. Wishes: a roof
    (Fede), a rug (Elio).
- **New kinds of site.** A brief can name one of the village's places (`hangout`) instead of a build zone, or no site
  at all: then the pieces that count are the best group built together, each within 3 m of another. A counter here
  and hedges across the village aren't a stall. Build mode shows a site-less brief in whichever zone you build, when
  no brief belongs to that zone.
- **Ticks keep coming after the musts**: a brief's checks stay live once its musts are met, so the last must ticks
  too and a wish met afterwards still sparkles. Before, the last must's tick was lost.
- Each brief has an example plan that meets every must (tested), and none brings in more than one new kind of check.
- **Checked:**
  - **Tested** (`godot/run_tests.sh`): the ten briefs are sound; every example plan builds and meets its musts; a
    brief at a hangout counts only what stands there; "anywhere" counts only pieces together.
  - **Played** (`play_commissions`, 6 checks, in `play_all.sh`): Ornella offers her request in conversation; build
    mode in the village streets shows her brief with its wishes; two tables and four chairs tick both musts and her
    permit is stamped; Gigia's stall doesn't count apart and does together; three stacked blocks make the plinth,
    tall enough for the Sindaco's wish.
  - **Not checked:** Fede's reading corner in play (tests only).

### Stage 7: tools and materials (shared; content for Monteforchetta)
- **Tools have levels.** You start with an old hatchet and an old pick; Elio's shop sells the next one, for lire and
  metal, one level at a time:
  - **Steel axe** (after the crossing): fells the **big oaks** for **oak beams**, and gets a little more wood from
    every tree. Then the **woodcutter's axe** (50 approval): two swings a tree, and more from each.
  - **Pick and chisel** (after Elio's shop): every perfect strike also dresses a block of **cut stone**. Then the
    **mason's pick** (80 approval): two strikes a rock, and more stone.
  - A better tool makes its minigame quicker and easier: a wider green or ring, a slower needle, less wait between
    swings, one swing fewer at the top level, and a bigger yield.
- **A perfect run pays**: when every swing is gold, you get 2 more wood or stone, a "Perfect run!" in the panel and a
  toast.
- **Big oaks**: two of them stand in the woods west of the village (`bigoak0`, `bigoak1`), larger than the ribboned
  trees. The old hatchet can't fell them: the prompt says so, and a toast says Elio sells a steel axe. They grow back
  overnight like the others.
- **New materials make new building**:
  - an **oak beam** (from beams) is a deck that reaches four tiles out over water, twice as far as a plank. Oak beams
    cross Aldo's washout from both banks without a single post;
  - a **stone arch** (cut stone) reaches three tiles, with an arch underneath;
  - a **stone column** (cut stone) stands in a river bed like a post and holds up a deck.
  The tool upgrades bring their plans; Elio sells the plans too.
- **Lire can buy materials**: Elio sells beams and cut stone (and the plans), so a player who only wants to build
  can buy instead of chopping. Wood, stone, metal, clay, copper wire and fabric were already for sale.
- **What you see**: the minigame panel names your tool and shows as many dots as it takes swings; the bag lists your
  tools, what each does and what the next one costs; the shop lists only the next upgrade of each tool. The
  chopping and mining tips mention gold swings and the new tools. Gigia's "all in wood" wish on the crossing counts
  oak beams as wood.
- Where: `Tools` (`scripts/systems/tools.gd`) and `data/tools.json` (levels, prices, what each level does to the
  minigame); `Minigames.Chop` and `Mine` take a tool's stats; each span piece has its own `reach` in `pieces.json`
  (`BuildGrid.reach`); shop lines `{tool, level}`; new resources `beam` and `cutstone` with watercolour icons (drawn in
  `tools/icons/icons.cjs`), and rendered pictures for the three new pieces.
- **Checked:**
  - **Tested** (`godot/run_tests.sh`). `test_tools` covers: better tools make the minigame quicker and the yield
    bigger; a perfect run's bonus; big oaks need the steel axe and give beams, small trees don't; the chisel's cut
    stone; buying upgrades at Elio's (lire and materials spent, one level at a time, waiting on the request or the
    approval it needs, saved); beams and cut stone for sale; oak beams reach four tiles and cross the washout with
    no post, arches three; a column holds up a plank.
  - **Played** (`play_tools`, 10 checks, in `play_all.sh`): the old hatchet refused at a big oak; the steel axe bought
    at Elio's; the oak felled for beams with "Steel axe" in the panel; the pick and chisel bought; a perfect run at
    the quarry gives the bonus and 4 cut stone; beams and cut stone bought with lire; an oak beam crossing and a stone
    arch crossing with a column built over the washout; the bag lists the tools; you walk across on the beams. For
    the perfect run the script puts the shrinking ring on the mark just before each press (at ten frames a second a
    scripted press can't hit the gold reliably); the game's own judging, bonus and cut stone do the rest.
  - **Seen** in screenshots: the two crossings side by side, the tool name in the minigame panel, the perfect run,
    Elio's shop, the bag.
  - **Not checked:** the woodcutter's axe and the mason's pick in play (only in tests); how the prices feel over a
    whole game.

### Stage 6: requests as commissions (Monteforchetta)
- **A request's building step is now a brief**: a site, two or three **musts** that check what it does, and up to
  three **wishes** from people who have a say. Anything that meets the musts passes, however it looks.
  - The crossing (Aldo): walkable from bank to bank; railings along it. Wishes: all in wood (Gigia); eight railings
    (the Sindaco).
  - Elio's shop: a workbench, two places to sit, two lamps. Wishes: two shelves or cabinets; one thing painted bright
    (both Elio's).
  - The fountain (Fede): water flows into it. Wishes: two flower beds by it (Fede); a bench to admire it from (the
    Sindaco).
  - The farmhouse: four walls with a door, a roof, a bed. Wishes: a table (Ornella), something growing (Gigia), two
    cosy touches (the Sindaco). These replace the old "make it cosy" step.
  - The bus stop (Aldo): twelve paving stones, somewhere to wait, a sign. Wishes: a roof for rainy days (Aldo); a
    light at night (the Sindaco).
  - The electric lamp (Fede): one lit by a waterwheel you built. Wish: two lit.
  - The labels are kept to a few words so the list fits beside the plan in build mode.
- **Checks tick live** in build mode's list on the right: ○ / ✔ for each must, with a count, and ☆ / ★ for each
  wish with who wants it. When one ticks, the pieces that meet it sparkle (green for a must, gold for a wish) and a
  short toast names it. For the fountain the list also shows the two steps on the way (a wheel turning, a pump
  powered). The request tracker says to build it your way and that the musts tick off as you go.
- **Handing it in stamps the permit**: "Approvato" for the musts alone, "Approvato con plauso" with some wishes,
  "Approvato con lode" with all of them. Each wish met adds 5 approval and a heart with whoever wished it. The stamp
  is shown on the request-complete banner and kept with the request (`stamp`).
- **Teaching**: each brief brings in at most one new kind of check after the ones before it (a test checks this
  along the order requests unlock): the crossing a path and counting pieces; the shop and the farmhouse what pieces
  give (seats, light, shelter); the fountain water arriving; the lamp a lamp lit. The example plans are still there
  to follow or copy into a draft, and each one meets every must.
- **The guided first day** waits on the crossing's first must (walkable) before asking for the railings, with a new
  `must:Q:O:N` step condition (`data/tutorial.json`).
- Where: `Commission` (`scripts/systems/commission.gd`) holds the checks, the stamp and the bonus; settings and the
  check list are in `data/commissions.json`. `QuestEngine` has the new `commission` step (done when every must is
  met, and it stays done); `Story` supplies what the checks look at and does the ticks and the stamp. Other places'
  requests keep their old `build`, `room` and `pieces` steps until their owners convert them.
- **Checked:**
  - **Tested** (`godot/run_tests.sh`, 310 passed). `test_commission` covers: every brief has at most three musts and
    three wishes, known checks, villagers wishing, and at most one new kind of check; each example plan meets every
    must; each kind of check; a brief done when its musts are met, staying done, with the wishes left for later and
    the guided day able to wait on one must; the stamps and the wish bonus. `test_story`, `test_plans` and
    `test_build` were updated for the new steps.
  - **Played**: see below.
  - **Not checked:** the farmhouse, bus stop and lamp briefs played through to their stamp (the main playthroughs
    build them, but only the crossing's and the shop's stamps are checked); a brief "anywhere in the village" (none
    of Monteforchetta's requests uses one yet).

### Stage 5: the inauguration (Monteforchetta)
- **When you end the day** (sleep until tomorrow morning) after putting up pieces that are still standing, the
  Sindaco opens them first. The clock goes to dusk (8:30 PM). The camera cuts to the build, and everyone is placed
  round it rather than walking there: the Sindaco on one side of a red ribbon, you on the other, the villagers on
  either side. Then you go to sleep as before. A day with nothing new has no ceremony.
- **What is opened**: the biggest group of the day's pieces. Pieces within 3 m of each other form a group, and a
  need met counts extra. Pieces put up and taken away again the same day don't count. Other groups that day are left
  out.
- **The speech** is three lines from `data/inauguration.json`:
  - what and where ("Citizens! Tonight I give you a bench and a flower bed outside the bakery.");
  - one line that fits the build: the complaint it answers from the paper, the Sindaco's own castle steps, "art"
    for something nobody can use, something perched high, a painted piece, a spree of pieces, a single piece;
  - him taking the credit ("My vision, of course. The Geometra held the ladder.").
- **The ribbon and the crowd**: he cuts the ribbon (confetti, fanfare) and the crowd reacts. If people can use the
  build they clap and cheer, and the villager whose spot it is thanks you and gains a heart (Ornella at the bakery,
  Gigia at her gate, and so on). If nobody can use it (a chair on two blocks) everyone shrugs under a question mark,
  to crickets, even when it counts for the need. One or two villagers say a word in a bubble.
- **Approval is counted**: a small card gives the day's approval change and a mark out of ten, in halves (Italian
  school marks, up to "10 e lode"). The mark goes up for each need met, each different kind of piece, someone being
  able to use it, and a painted piece; wonkiness costs nothing.
- **The next morning's Eco del Colle** leads with the opening ("Sindaco opens a bench and a flower bed outside the
  bakery; calls it 'my vision'") and gives the mark. A request finished that day still takes the headline.
- **Always skippable**: a Skip button or Esc ends it at once, and its results (the heart, the paper) still count.
  "Evening inaugurations" in the settings turns it off; the paper still reports the build.
- Where: `Inauguration` (`scripts/systems/inauguration.gd`) holds the rules: today's pieces, the groups, the facts,
  the speech, the mark, the reactions, and where everyone stands. `InaugurationScene`
  (`scripts/world/inauguration_scene.gd`) is the scene, run by `game.sleep_until` while the screen is faded. A place
  turns it on with a work day and a `speaker` in its layout's `inauguration` block (Monteforchetta:
  `"speaker": "percival"`). Scripted playthroughs skip the scene unless they ask for it (`inauguration=play`), the
  way they skip the nap jokes.
- **Checked:**
  - **Tested** (`godot/run_tests.sh`, 305 passed after merging main). `test_inauguration` covers:
    - naming what was built;
    - today's pieces remembered across a save, and pieces taken away dropped;
    - the bakery bench opened with the right place, complaint and credit, and Ornella's heart;
    - a chair on a stack called art, with the crowd shrugging and no hearts;
    - the Sindaco's own steps;
    - the marks;
    - everyone given a free spot to stand, clear of the pieces and of each other;
    - the paper's headline and mark.
  - **Played** (`play_inauguration`, 11 checks, in `play_all.sh`; the pieces are placed by the script, and you
    sleep on a public bench each night):
    - a day with nothing built has no ceremony;
    - a bench and a flower bed at the bakery are opened at 8:30 PM, with all five villagers gathered round;
    - the speech names them, quotes "Nowhere to sit outside the bakery." and takes the credit;
    - the ribbon is cut, Ornella thanks you ("Just what we needed!" in this run) and gains a heart, and the card
      shows "Voto 9/10, +16 today";
    - the next paper leads with the opening and gives the mark;
    - a stone block put up across the village the same day is left out;
    - a chair on two blocks on the church steps gets a ceremony with the whole crowd shrugging and no hearts;
    - Esc ends a ceremony within a fifth of a second and the paper still reports it;
    - with the setting off there is no ceremony and the build is still reported.
  - **Monteforchetta's other playthroughs passed** before main was merged in (`play_all.sh`), apart from
    `play_needs`, which main has since fixed. They were not run again after the merge.
  - **Seen** in screenshots: the speech with the bench, the flower bed and the ribbon between the Sindaco and you;
    the cut ribbon and the cheering; the mark; the puzzled crowd at the church.
  - **Not checked:** the ceremony on the tutorial's first night (the guided day's playthrough skips it); builds
    indoors or in tight spots, where there may be no room to gather (then it is skipped and only reported); a
    camera view blocked from every side (the camera then moves in until the view is clear); how it feels to see one
    every evening.
- **Not built yet:** the ceremony changing with the villagers' tastes (stage 1's "tastes" are still to do), music at
  the ceremony, and a record of past openings to look back on.

### Stage 4: villagers use what you build (Monteforchetta)
- **Visits.** Now and then a villager takes a break from their routine and goes to one of the village's spots to use
  something you built there:
  - they sit on a bench, chair or sofa;
  - stand under a roof;
  - work at a counter;
  - read under a lamp;
  - tend the flowers.

  They walk the village's paths to the nearest spot, then only over ground the walk-up check proved a villager can
  stand on, so they don't walk through what you built. They stay a while and go back to their routine. Two villagers
  never take the same seat, and if you remove a piece, whoever is using it gets up and goes. Timings are real seconds,
  so visits go on while the day waits at dusk. Settings are in `data/needs.json` (`visits`); rules in `Visits`
  (`scripts/systems/visits.gd`), the walking in `NpcAgent`.
- **Puzzled stares.** A piece that provides something but can't be used gets visited too: a seat facing a wall, a chair
  on top of a stack of blocks. The villager stands as close as they can get, shrugs, and stares at it with a purple
  "?". It changes nothing in the rules (a bench you can walk up to from the side still meets the need); it's there for
  the joke.
- **A heart a day**: the first time each day a villager uses something you built, their friendship goes up by one.
- **Liveliness**: each spot is lively from 0 to 3 once its met needs plus half its charm reach 1, 2.5 and 4. Villagers
  pick livelier spots more often, and prefer their own (Ornella the bakery door, Gigia her gate, Aldo the bus stop,
  the Sindaco the castle steps, Fede the piazza). The approval screen and build mode show "lively n/3".
- **Gathering at dusk**: when the day waits at dusk and the piazza is fully lively, nearly every villager still awake
  goes there and stays longer.
- **Not built yet:**
  - the market day every fifth day;
  - the evening music when people gather;
  - villagers' tastes for pieces and colours near their homes.
- **Checked:**
  - **Tested** (`godot/run_tests.sh`, 292 passed). `test_visits` covers: liveliness levels; a bench with room in front
    sat on, from the front; a bench facing blocks still meets the need but gets a stare; a chair on a stack gets a
    stare; who goes where (the gathering at dusk, a villager's own spot, a taken seat); paths that stay on standable
    ground.
  - **Played** (`play_visits`, 9 checks, now in `play_all.sh`; the pieces are placed by the script's setup and the
    villagers are watched as time passes, with visits sped up six times):
    - a chair on two blocks on the church steps gets a shrug and a stare;
    - a bench outside the bakery gets sat on, by Elio in this run, who gains a heart;
    - removing the bench sends him off;
    - two flower beds, two lamps and a counter make the piazza fully lively, and the approval screen says so;
    - at dusk three of the four villagers still awake gathered there.
  - **All of Monteforchetta's playthroughs pass** (`play_all.sh`: 19 runs).
  - **Seen** in screenshots: the stare, the villager on the bench, the gathering.
  - **Not checked:** how often visits feel right at normal speed (every one to two and a half minutes per villager);
    villagers using pieces indoors or upstairs.

### Less text on screen (07/11)
The user found too much text everywhere. Changes, all shared:
- **Smaller text:** all of it is 12% smaller (`UiTheme.TEXT_SCALE`, `UiTheme.px`), and panels are padded a little
  less.
- **Fewer toasts:** at most three at once, and a build that meets a need gives one toast ("✔ Something green outside
  the bakery · charm ★ +6 💖") instead of three.
- **Build mode:**
  - undo, redo and help are icons with tooltips, and draft only is a toggle button;
  - the key list only shows when you press ❓;
  - the catalogue's buttons are smaller;
  - hangout names only show for the places within 14 m of the view;
  - the glowing spots are fainter and reach 6 m.
- **Narrower cards:** the guide and tip cards, the tracker and build mode's right column are narrower.
- **Shorter lines:** the tracker lists open needs as "The bakery door · somewhere to sit", and the paper says
  "Noticed:" once.
- **Checked:** all of Monteforchetta's playthroughs pass (`play_all.sh`, 18 runs), and the HUD, the morning paper and
  build mode were compared in screenshots before and after.

### Stage 3: needs and live approval (Monteforchetta)
- **Hangouts**: six spots in Monteforchetta's layout (`hangouts`) where people want things:
  - the piazza (green, light, a stall);
  - the bakery door (a seat, green);
  - the church steps (light, a seat);
  - Gigia's gate (green, a seat);
  - the castle steps (light, green);
  - the bus stop on the belvedere (a seat, light, shelter).

  Each has a name, a phrase for lines ("outside the bakery"), a radius and, for later, the villager who goes there.
- **Pieces say what they provide** (`provides` in `pieces.json`):
  - seat: bench, chair, sofa;
  - shelter: roof;
  - light: lamp, street light, rail lantern, and an electric lamp while it's lit;
  - green: flower bed, hedge, tree;
  - stall: counter.
- **A need is met** while such a piece stands in the hangout and someone can walk up to it. For a seat or counter that
  means at its height; for shelter, standing under it. The walk-up check floods out from the middle of the hangout over
  the same `WalkWorld` the player walks on, at villager size, so a chair on top of a stack of blocks, or a bench walled
  in, doesn't count. Rules in `Needs` (`scripts/systems/needs.gd`), numbers in `data/needs.json`.
- **Approval is what the village has now.** Each met need is worth 5. Each hangout adds up to 5 for charm: the first
  of each kind of piece there counts 1, the second half, then nothing, plus half a point per colour you've painted.
  Building raises approval and removing lowers it, recounted on every change, with a toast ("✔ Somewhere to sit outside
  the bakery: +5 approval"). Requests and first-of-a-kind pieces still give permanent points. Milestones go by the best
  approval ever reached, so they're never taken back or given twice, and the home plot's size goes by it too
  (`state.village_points`, `state.approval_best`). An approval milestone is announced only where the HUD shows
  approval (Monteforchetta, Clockwork Cove): one reached in a place with its own meter (Boccapioppo's gauge,
  Casalrana's petition, Toriano's paper) waits until you're back, and is announced on arrival (`Harmony.due`).
  `state.unlocks_seen` holds each milestone once (`GameState.see_unlock`; older saves are cleaned on load), and
  `Progress.as_if_played` sets the best approval and marks the milestones of the places played on the way, so a later
  place's first bed no longer announces Monteforchetta's five milestones again (headless: `test_milestones.gd`).
- **Noticed needs.** Each morning, once the guided day is over, the village notices needs, three open at a time and
  only for pieces you can already build. The paper leads with them ("Noticed: Nowhere to sit outside the bakery."), an
  icon floats over the place, and the request tracker lists them under "The village could use". Leaving one costs
  nothing. A need you meet before anyone mentions it still counts.
- **"Why?"** The approval screen (P) splits the rating into requests and firsts versus the village now, then lists each
  hangout: its charm stars, the needs met (+5 each), the ones wanted, and a hint when something hasn't been mentioned
  yet.
- **In build mode** each hangout's area shows as a dashed ring (gold while something is wanted there), with its name
  and its needs (✔ met, ○ wanted) and charm. The draft bar shows how much approval the draft would add ("+6 💖").
- **Checked:**
  - **Tested** (`godot/run_tests.sh`, 283 passed). `test_needs` covers: the hangouts' data (buildable from the start,
    walkable, every need met by some piece); a bench you can walk to counts and a chair on a stack doesn't; a roof on a
    pillar is shelter; a lamp is light, and an electric lamp only when lit; charm's repeats, colours and cap; three
    needs noticed at a time, only buildable ones, the same for the same morning; approval going down and up again
    without a milestone twice; the plot not shrinking; the paper leading with what was noticed.
  - **Played** (`play_needs`, 19 checks, in `play_all.sh`):
    - a night on a bench brings three noticed needs in the paper, with icons over the places and the tracker list;
    - build mode shows each place's ring, name and needs;
    - building the right piece there meets the need and raises approval;
    - the approval screen explains it;
    - removing it takes the village's points back but keeps the best approval;
    - drafting it previews the approval, and building the draft meets it again.

    The morning's needs are picked at random, so v2 and v3 check only that three are noticed and shown. After that the
    playthrough doesn't rely on the roll: for each kind it builds (seat, green, light) it takes the first place in
    the layout that wants that kind and has room, makes the village notice it if the morning didn't, and plays the
    build, remove, draft and rebuild steps there (v5 to v9, once per kind: a bench at the bakery door, a hedge and a
    lamp in the piazza). Five runs in a row passed all 19 checks.
  - **Why it used to fail about one run in four** (only when the roll picked a seat): the playthrough aimed its
    clicks at the middle of the bench's first cell, but build mode centres a piece on the cursor, so for a piece two
    cells wide that point is exactly on the line between two cells, and the bench landed one cell over. The test then
    couldn't find its bench at the planned spot and never removed it (v7), and the draft (v8) went next to a bench
    that already met the need, so it previewed no approval. The game was right; the test was wrong. The new
    `place_anchored` helper (`tests/full_base.gd`) aims at the middle of the piece's footprint, and v5 now checks that
    the piece landed where it was aimed.
  - **All of Monteforchetta's playthroughs pass** (`play_all.sh`: 18 runs).
  - **Seen** in the playthroughs' screenshots: the paper with needs, build mode's labels, the "Why?" panel.
  - **Bug the playthrough found**: the village wasn't counted when a new game began, only once something was built.
    It's now counted when play begins and when a save loads.
  - **Not checked:**
    - How the numbers feel over a whole game (5 a need, up to 5 charm a place, about 100 in all).
    - Whether the six spots are the right ones.
    - Whether the rings read well from every camera angle (in the screenshot the camera was over a roof).

### Stage 2: the work day (Monteforchetta)
- **A place opts in** with a `day` block in its map entry (`islands.json`: Monteforchetta has `{"holdAt": 20.5, "regrow":
  "overnight"}`); the rules are in `WorkDay` (`scripts/systems/work_day.gd`). Boccapioppo, Casalrana, Toriano and the
  Cove keep the clock they had, because some of their requests happen at night; their owners can switch them over.
- **The day waits at dusk.** The clock runs from 7 AM and stops at 8:30 PM (lamps on, the evening music), about 13 real
  minutes of daylight, and it still stops in build mode. The HUD says "Dusk, the day waits for you", and a tip card the
  first time explains how to end the day. Riding a line can't carry you past dusk either.
- **You end the day by sleeping, on a bench until you have a bed.** A bed or bench now offers: sleep until tomorrow
  morning (which ends the day), or a nap until noon, the afternoon or dusk if they're still to come. The Sindaco's camp
  bed in the castle has a note sending you to the public benches (a `refuse` line on the layout's `rest` feature), and
  his lines about the guest room say so. A bed you build ends the day too, quietly.
- **A night on a bench always ends with a joke** (`overnight` in `naps.json`, 1.0), where a daytime nap is still only
  sometimes funny. Nobody has written more gags yet, so the same few come round often.
- **Overnight, gathering spots grow back**: trees, rocks, clay, flowers, hazelnuts, chestnuts, porcini, the street bins
  and lost things come back the next morning instead of minutes later, so each day has its own share. When all the
  spots for something a request needs are picked, the tracker says they grow back overnight.
- **Nothing in Monteforchetta depends on the hour**: Ornella's boars and Fede's metal detector can be taken on at any
  time. The rule for requests that keep hours stays for the places that use it.
- **The morning paper.** Waking after a night, the *Eco del Colle* (the paper from `naps.json`) comes up as a card:
  - a headline about yesterday: a finished request (a request can have its own `headline`), else how many pieces you
    built, else a quiet-day line;
  - up to three notes: the approval rating and how much it moved, who is asking for you, what your draft still needs,
    that the trees and quarry grew back, and the day's weather.

  The day so far is kept in `state.today` (pieces built, spots gathered, requests finished, approval at the start).
  Lines are data (`data/paper.json`, `MorningPaper`).
- **Checked:**
  - **Tested** (`godot/run_tests.sh`, 276 passed). `test_work_day` covers: the clock holding at dusk (and not elsewhere);
    the sleep options at different hours; spots growing back the next morning and not after a nap; a night on a bench
    always ending with a joke; the castle bed's note; no hours on Monteforchetta's requests; the day record and its save;
    the paper's headlines and notes. The shared rule for requests that keep hours is still tested in `test_story`.
  - **Played** (`play_sleep`, rewritten, 19 checks):
    - a bench at 3 PM offers dusk or tomorrow;
    - a nap until dusk lands at 8:30 PM the same day, and the clock then waits, saying so, with its tip card;
    - a tree cut earlier hasn't grown back by dusk, and has by morning;
    - Ornella's request is offered at dusk;
    - the camp bed sends you to the benches;
    - a night on the bench ends the day at 7 AM with a joke, and the paper comes;
    - the four gags, through naps within the day and a rainy night;
    - the bed's price and the draft;
    - your own bed ending the day quietly, with the paper.
  - **All of Monteforchetta's playthroughs pass** (`play_all.sh`: 17 runs). Part two of the full story now boards the
    city bus from beside Aldo when he's in front of it. His routine keeps him at the stop from 6 AM to 10 PM, and with
    the clock waiting at dusk he's always there. A real player could meet this during the day before too.
  - **Seen** in the playthroughs' screenshots (compatibility renderer): the bench panel, dusk, the morning on the bench,
    the paper.
  - **Not checked:**
    - A whole day at a real computer's speed.
    - The gathering helper's bench sleep in the full playthrough: the story never ran out of trees there.
    - How the other places feel: they don't use the work day yet.

### Stage 1: building you can understand (shared)
- **The spots where the piece in your hand can go glow green** (for walls, fences and railings, the edges), within
  6 m of the cursor, filled in a few cells a frame. With a plank in hand you see how far it reaches from a bank or a
  post. The check is the real one (`BuildGrid.spot`): a cached support check (`support_cache`, `supported_with`) gives
  exactly the same answer as the full one, which a test compares on random sites.
- **Drafts.** A piece you can't build yet goes into your draft instead of being refused: when you're short of
  materials, when it rests on drafted pieces, when someone is standing there, or when "Draft only" is on (`G`, or the
  button in the top bar). Drafts are blue see-through pieces that cost nothing and block nothing but other drafts; they
  stay on the site outside build mode, are saved, and stay in their place when you travel (`state.drafts`,
  `away[place].drafts`). **Build the draft** builds everything you can afford, bottom up; clicking a drafted piece with
  the same piece in hand builds just that one; a drafted piece can be selected, built or removed. The build screen's
  draft panel and the request tracker list what it needs and what you're still short of. Undo and redo cover drafts.
  The plan panel can put the whole ghost plan into your draft at once. The build checklist marks what your draft would
  cover ("(drafted)", "+2 drafted"). Rules in `Drafts` (`scripts/systems/drafts.gd`).
- **Fewer rules:** the clock stops in build mode; walls, fences and railings turn to the edge you point at (R still
  turns them when you point at a tile's middle); the half grid is gone (`G` is now draft only); Monteforchetta's sites
  (the washout, Elio's shop, the piazza, the bus turnaround) are open from the start, while your plot still waits for
  its deed and Gigia's groves for the crossing.
- The build help card (kept to its old length, so it still fits between the guide card and the catalogue), the guided
  day's building steps and the railing hints say how it works now.
- **Checked:**
  - **Tested** (`godot/run_tests.sh`, 263 passed). `test_build_clarity` covers: the cached support check against the
    full one on random sites; glowing spots against validation; plank reach; edge turning; what drafts cost and short;
    their build order; saves and travel; the sites being open.
  - **Played** (`play_build_clarity`, 14 checks, now in `play_all.sh`): the clock waits in build mode; with a plank in
    hand the bank glows, and the glow reaches out as you build; a plank past its reach is refused, saying why; a post you
    can't afford is drafted, and the rest of the crossing drafts onto it; the shopping list shows in build mode and in
    the tracker; no boxes overlap with the draft bar up; Build the draft builds it all and the request moves on;
    railings turn to the edge you point at; draft only, undo and redo; clicking a drafted piece builds it; you can walk
    across.
  - **All of Monteforchetta's playthroughs pass** (`play_all.sh`: 17 runs, 153 checks). Two changed: `play_sleep`'s bed
    now goes into the draft with too little money and is built from it, and `play_full2` waits longer for the clay to
    grow back (with the clock waiting in build mode, part one ends earlier in the day).
  - **Seen** in the playthroughs' screenshots, in the compatibility renderer and in a Forward+ run of `play_build_clarity`
    on a software GPU (which also passed).
  - **Not checked:** how it feels with a real mouse at full frame rate; the gamepad; the spot scan's speed on a real
    machine (it spends at most 4 ms a frame). The build code is shared, but Boccapioppo's, Casalrana's and Toriano's
    playthroughs were not run (their owners run them). Boccapioppo's railing hint still says R turns railings, which is
    only true when you point at a tile's middle.

## Playtest fixes (second playtest notes, Boccapioppo, 06/11–07/11)
Each fix is the general version, for every place. What was checked how is at the end of this section.
- **Gathering counts what's in your bag** (shared): wood chopped before anyone asked counts towards a request that asks for wood, and a finished gathering step stays finished when you build with it. Only a hunt for fresh finds (`"fresh": true`: Toriano's and Casalrana's five lost things) or one tied to hours counts just what turns up during the step. The counts now mean the total a request needs, so two were raised to what following their plans costs: Monteforchetta's crossing asks for 14 wood ("have 14 wood"), Boccapioppo's pontoon bridge 19, and the dance hall 17 wood and a stone for the bar counter's top.
- **Building is explained, everywhere** (shared): every Boccapioppo building step now has a ghost plan, like Monteforchetta's (the pontoons and railings, the waterwheel and shafts to the pumping house, the dance hall, the breach wall, the slipway and the cabin), taken from the playthrough's working builds. Build mode follows a plan: opening it at the site puts the next piece in your hand turned to match, a purple arrow bobs over where it goes, a plan panel says how far along you are, what's next and what you still need, and `V` (or its button) picks up the next piece. The request tracker says how ("At the site press B, then follow the glowing plan"). A "How building works" card comes up the first time you build in each place, and again under ❓ How to build in build mode.
- **Straight to Work** no longer sends you back to Ermes after coffee: once you take his shovel he waits at the breach for the sand, and the request ends over coffee at Rina's, where you hear about the houseboat. (The other requests were checked for the same "go back and tell them" pattern; the rest end where their last step happens, or with the giver in the same room.)
- **The resource chips no longer cover the request tracker** (shared): they wrap onto more rows before reaching the panel at the top centre, the guide and tip cards move down below them, and they show lire, building materials and what a request here has you collect; the rest (treats, letters, lost things, junk) is in the bag. In build mode they sit in the left column, under the tool bar.
- **The journal shows the place you're in** (shared): its requests, side requests and completed ones; requests left going elsewhere are in their own "Other places" tab, with a line saying so. The notice board lists only the place's own requests.
- **The geese** were what shook: each one started and stopped every other frame, so its walking bob flickered on and off. They now stand and peck, then walk somewhere with a waddle that eases in and out (and hurry home after a chase), checked by a test that simulates 20 seconds. Their wings are rounded folded wings instead of white slabs, with a fuller body, tail, beak knob and webbed feet; the cormorants' and crows' wings are rounded too.
- **Nap gags:** the villager caught staring and waking up soaked are sight gags (`"visual": true` in `naps.json`): no line explains them, and the usual greeting comes once the joke has played. The paper and the umbrella keep their lines.
- **Goodbye is always 0** (and Esc) in every conversation, whatever comes before it, as is the "not now" answer to an offer; the other answers are numbered 1, 2, 3... The talking tip says so.
- **The Roman bridge** was built from 64 thin slices per wall, each restarting the stone texture and stepping its top, and its deck took the riverbed's and banks' paint (pebbles, and grass tufts up the ramps): it read as fuzzy and ribbed. Each wall and parapet is now one continuous mesh with a smooth hump, a ring of dressed stones round each arch, and the deck is worn paving with no grass. The kingfishers' twigs hung in the air: each perch is now a willow branch growing out of the bank over the water.
- **Lost things look like what they are** (shared): a model for each kind (glasses, keys, a ball, a glove, a ticket, a phone card, a cassette, a Walkman, an umbrella, a felt hat, a scarf, earmuffs, a briefcase, a newspaper, a cuckoo clock, a gnome, a trophy, a photo, an oar, a log, a page), picked from the lost thing's name. An unnamed lost thing now has its own name from the start (the place's list, by its place in the layout), so it looks the same before you pick it up as it's called after; Monteforchetta's other lost things wait until you've found the Sindaco's glasses, so the first one you find is still his.
- **Ermes's door** faced the levee's slope: his house now opens north onto the lane, its room mirrored to match.
- **Gildo under his floor:** the shack's flood tide line was a slab right across the room at knee height (the pumping house had one too, hidden in its walls). It's a band round the outside now. The houseboat's hull filled her cabin to 25 cm above the floorboards; it now stops at the floor, with bulwarks round the cabin. A test builds every room in every place and checks nothing lies across it between the floor and head height.
- **Checked:** **tested**: 253 headless tests, among them Boccapioppo's seven plans built piece by piece (each finishing its step, each paid for by what its request gathers), every room in every place with nothing across it, the geese simulated for 20 seconds, a model for every lost thing in every place, gathering in advance and Goodbye on 0. **Played**: Boccapioppo's whole playthrough, all 33 checks, including two new ones that build mode's boxes don't overlap at the bridge and in the dance hall (one full run on the merged code lost the bike request when a bench nap's panel didn't open with four runs sharing four cores; that section passes from its checkpoint); Monteforchetta's whole set, every check (`play_full2`'s bus stop missed its press once in the same crowded run and passes alone). **Seen**: screenshots of the Roman bridge, Gildo's shack, Ermes's house, the geese, the kingfisher's branch, Wanda's trophy, Ines's log and Mattia's Walkman, and build mode with the how-to card, the plan panel and the catalogue's "You have" strip. **Not checked**: the Forward+ renderer, a gamepad (the plan's next piece has a key, `V`, but no button), and how it feels to a real player.

## Converting to the chosen look (07/11)
- **Step one, physically based materials** (tested, played, seen in the ten fixed views before and after): everything built in code, in every location, now has real roughness and specular. Plaster, stone, wood and fabric have the chosen texture mix. By day the ambient light is stronger and warmer, to make up for the fill the old rim light gave. The terrain keeps its old light until step two, and the outlines stay. Against main, brightness is within -2% to +9% in most fixed views, with richer golden hours. Night is 13% darker, and the castle hall at dawn 17% darker. `--look=painted` shows the old materials. Plan and results: `docs/CONVERSION.md`. Not checked: frame rate and texture memory on real graphics cards.
- **Step two, ground and wet** (tested, played, seen in the fixed views before and after, and in three views in the compatibility renderer): the squares are laid with the generated flagstones, tinted with each layout's cobble colours, and so is the castle hall's floor. Grass looks as before. In the rain, paving and paths turn glossy and puddles mirror the sky and, in Forward+, the village around them (screen-space reflections). A little ambient light stays at night. Dry daytime views moved by 2% or less; night is 8% brighter than after step one. The castle hall at dawn stayed about 20% darker than before the conversion; step three's hall lamps fixed it. Dirt paths keep their painted look. Plan and results: `docs/CONVERSION.md`. Not checked: frame rate with the reflections on real graphics cards.
- **Step three, part one: houses from a Blender kit** (tested, played, seen in the fixed views and in close-ups by day, at night, inside and in snow): Monteforchetta's bakery, newsstand, Ghisolfi house, Cauda farm, gatehouse and Aldo's cottage are Langhe houses assembled from a 233 KB kit of Blender parts (`HouseKit`). Each has two storeys (Aldo's one), shutters in random positions, coppi laid tile by tile, a sandstone footing, and a balcony, shopfront, sign or awning where the layout asks. Rooms you walk into keep their walls and doorway, and the upper floor and roof fade while you're inside; windows light at night. Not checked: frame rate on real graphics cards (a house is 20 to 27 draw batches, up to 24,000 triangles).
- **Step three, part two: a village core** (tested, played, seen from above, in the piazza, down the south lane and at the bus stop): ten more kit houses, some in attached rows, frame the piazza's north side, line the south lane toward the belvedere and stand at the village gate, one beside the church and one by the newsstand. None of them is on a lane, a villager's route, a resource spot, a building site, a bench or a hangout, and no gameplay data moved; the playthroughs pass unchanged. They take buildable ground from the open village zone, so a save with something built exactly there would now overlap a house.
- **Step three, part three: the church, castle and workshop** (tested, played, seen in close-ups and in the castle hall at dawn): all three are restyled with the kit, with their shapes, rooms, doors and named parts unchanged. The church has a gabled front, an arched stone portal, quoins, a coppi roof and a brick tower with a stone belfry; the workshop a coppi roof that fades while you're inside, a stone door frame and kit windows; the castle tiled tower roofs, barred keep windows and two wall lamps in the hall. The lamps fix the dark hall at dawn left over from step one: it is about as bright as before the conversion again. Step three of the conversion is done; places without the kit keep their old buildings.
- **Steps four and six: characters and performance** (tested, played, seen in the cast lineup and in renders with full and simpler graphics and in the compatibility renderer): villagers have builds of their own (height, width, belly in their appearance data; the Sindaco short and round, the electrician tall and lean); jeans and overalls are denim and shoes leather; hair has real specular. Settings has "Simpler graphics, for slower computers" (no screen-space reflections, contact shadows or anti-aliasing, shorter sun shadows), which halves texture memory and draw calls in a wide view of the village. The conversion plan is done for Monteforchetta; other places are their owners' to convert. Not checked: frame rate on a real graphics card.
- **Step five: Boccapioppo and Casalrana** (08/11; tested, played, seen in before-and-after views of both places and in their casts' lineups): Monteforchetta's graphic improvements, done the same way in the other two villages (Toriano later: see "Toriano catches up").
  - **Houses from the kit.** Boccapioppo's nine houses, Rina's bar, Primo's workshop, Ermes's house, the station and the sawmill's office, and Casalrana's crossing keeper's cottage, presbytery, farm office and Cascina Grande are assembled from the house kit, with what each place adds on top: Boccapioppo's tide line above the stone footing, the bar's shopfront, sign, awning and payphone, the workshop's wheels, Ermes's plaque and quoins, the station's canopy and boards; Cascina Grande's long wooden gallery with its stair. Any kind of building can now join the kit with `"kit": true`, and a house can be `shut` (an empty house: closed shutters, dark at night), have a `gallery` and go without a chimney (`docs/MODELS.md`).
  - **Landmarks restyled with kit parts,** shapes, rooms, doors and named parts unchanged: Boccapioppo's church and bell tower, arcade, farm courtyard and pumping house; in Casalrana every building with a roof (station, church, bell tower, mill, machine shed, barn, cowshed, the farm workers' houses) gets coppi laid tile by tile, kit windows, doors and chimneys and a stone footing. The farm workers' houses stay shut up and dark. Wood and tin buildings (the houseboat, shack, dance hall, rice dryer) are unchanged.
  - **A denser core:** nine more houses in Boccapioppo and six in Casalrana, some in attached rows, placed clear of lanes, villagers' routes, resource spots, building sites, features, trees and the square, on level ground. No gameplay data moved.
  - **Builds:** every villager in both places has a body of their own, from their description (round old Gildo and lanky Mattia, tiny Nonna and ten-year-old Matteo). `tests/lookdev.gd` takes `--island=<id>` to line up one place's cast.
  - **Checked:** **tested** (`godot/run_tests.sh`, 364 passed after merging main): `test_house_kit`'s four new tests cover a shut house (dark at night, every shutter closed), a house without a chimney and a gallery with its stair, both places' kit houses (on their footprint, no taller than the camera thinks, lit windows, fading coppi in rooms you walk into, smoke only from a chimney, drawn by the place's own script), the camera heights, the new houses kept off lanes and resource spots with every shared wall against a neighbour, the landmarks' coppi roofs, the bar's sign, the shut-up workers' houses, the station's roof still fading over your flat, and every villager's build. **Played:** `play_river_town` (33 checks) and `play_rice_village` (30), `play_rice_village2` (48) and `play_rice_village3` (40) all pass, as they did before the change, and again after merging main. **Seen:** before and after in `docs/models/conversion_step5_a.jpg` (Boccapioppo), `conversion_step5_b.jpg` (Casalrana) and `conversion_step5_c.jpg` (both casts); both places at night (the kit windows light up, the shut-up workers' houses stay dark); a view of Monteforchetta's piazza, whose buildings are pixel for pixel as before. **Not checked:** frame rate on a real graphics card (both places now draw more instanced parts); Monteforchetta's and Toriano's playthroughs (the shared kit code only gained options, and Monteforchetta's tests pass unchanged); these two places in snow. The taller kit houses stop the camera sooner, so in the denser streets it comes in closer to you, as in Monteforchetta.

## Icons and Blender models (07/11)
- **Bigger eyes** (tested, played, seen in look-dev renders of the cast and in the character creator): the villagers' and the player's eyes are 1.45× the old dots, after the look tests (`docs/MODELS.md`). Every eye shape lands between 1.45× and 1.55×: the wide eyes were already 1.55×, so they keep their size (`Chibi.EYE_SIZE`, `test_faces`).
- **Look tests, look-dev only** (seen): the paintover's look tried in the model lab: photo-scanned and generated textures, outlines, two layouts, eye sizes. The decisions are in `docs/MODELS.md`. Converting the game needs a fresh look at its graphics first, since another agent is working on them.
- **Icons come from bundled fonts** (tested, played, seen): the interface's emoji and symbols used to come from the player's own system font, so they looked different on every computer and could show as empty boxes. They now come from one-colour Noto Emoji, which takes the text's colour (ink and pink), plus subsets of Noto Sans Symbols 2 and Noto Sans Math for arrows and stars (`UiTheme.ICON_FONTS`, `tools/fonts/make_icon_fonts.py`). `test_ui_icons` checks every symbol in the scripts and data has a glyph. A few icons relied on colour and now read less well as one-colour glyphs (the coloured squares for wood and stone in the build menu).
- **Blender model experiments, look-dev only** (seen, tested; not in the game, no collision): four Langhe village houses, a cobbled street with slab tracks and a rigged, animated Sindaco, built by scripts in `tools/blender/` and loaded with the game's own materials (`ModelKit`). The model lab lines the road into the piazza with them for screenshots (`--models=res://tests/model_lab.json`). What they showed and the decisions they raise: `docs/MODELS.md`.

## Playtest fixes (first playtest notes, 06/11)
What was checked how: **tested** means headless tests (`godot/run_tests.sh`), **played** means a scripted playthrough with real input, **seen** means screenshots reviewed by eye. Nobody has listened to the new sounds yet.
- **The opening is animated** (played, seen): Aldo's blue bus climbs the mule track, nose up on the slope, pulls into the lay-by with a toot and sways to a stop; the door hisses and you step off, then the letter of appointment. Any key or a click skips it (`world/bus_intro.gd`; the camera's `cinema` shot). The lay-by's south fence now starts past the bus door.
- **Conversations** (tested, played): Goodbye just ends the conversation (a wave, no parting line). Villagers remember you've met (`relationships.met`): Aldo introduces himself the first time you talk to him (`intro` in npcs.json), and his crossing request uses `offerMet` lines if you'd already talked. You can't talk to someone through a building's wall (`WalkWorld.sight_clear`); across a counter or through an open door is fine.
- **Pronouns and faces** (tested): every villager has `"pronoun": "he"|"she"`, and the HUD, journal and shop use it (`Data.pron`). The Italian villagers have fair to tan skin; Fede is no longer dark-skinned. Clockwork Cove's old cast is unchanged. Toriano's random passers-by still use the full range of skin tones.
- **Birds and hens** (tested, not listened to): a bird every 5 to 30 seconds (busiest in the morning, none in the rain) instead of chirps every second or two; five different calls, each sung a little differently every time, never the same one twice running. Chickens cluck (a new hen voice) when you're within 14 m; petting one clucks, petting a cat purrs.
- **Bench nap gags** (seen, played): the paper is a spread draped over your head and face, a sheet on your lap, one on the seat beside you (it used to sit inside the bench, under the seat) and one on the ground; the umbrella is a proper striped, ribbed one stood off the end of the bench, leaning over you instead of through your head.
- **Building** (tested, played, seen):
  - **Ghost plans for every building step**: every building step of Monteforchetta's requests carries a `plan` (one way to build it that works); while the step is current its pieces glow on the site, each gone once built there. A test builds every plan piece by piece and checks each step is then done. Pieces a plan needs are unlocked. See `Plans`.
  - **The village streets** are a building area (`"open": true` zone): B in town builds where you stand instead of jumping to the nearest site (often Elio's shop); nothing goes inside a building.
  - **No railings, walls or fences over water**: an edge piece is refused if its edge is over the stream, even on a dry cell (the bank row of Aldo's crossing).
- **A Bright Idea** (tested): says how it works (a waterwheel in running water sends power onto the banks beside it; a lamp touching it lights; shafts and gear boxes carry it further), its plan is a wheel in the mill channel by the piazza with a lamp beside it, and Fede gives you the copper wire and metal for the lamp.
- **Boars** (not checked in play yet): the wild boars in the woods come over when you carry chestnuts and take one; before, only Ornella's three at the bakery could be fed, and the woods boars ran off.
- **Garden beds** (seen): raised plank frames heaped with tilled earth in ridges, instead of a flat dark slab in a wooden tray that read like water.
- **Black and magenta blobs on the ground, everywhere** (seen in Forward+ on a software GPU, tested): with 4x MSAA a pixel on a triangle's edge reads its vertex colour from just outside it, a little below zero, and the plant, terrain and far-hills shaders' sRGB `pow()` made that NaN, which the glow spread into a black (or magenta) square with a bright halo, 10 to 15 of them in a view of Boccapioppo and in Monteforchetta too. The shaders clamp at zero first. This is the likeliest cause of Boccapioppo looking "hellish"; not yet confirmed on the tester's machine. Forward+ screenshots on a headless Linux machine need `mesa-vulkan-drivers`, or `RENDERER=forward_plus` silently falls back to the compatibility renderer.
- **Nobody about in Boccapioppo at night** (tested): Ermes waits at the bus stop at any hour until he has welcomed you (he used to go home at 10 PM, with everyone else asleep indoors). In the late afternoon the townspeople are indoors; with no talking through walls, you go in to talk to them.
- **Camera** (tested, probed): near a wall the camera no longer snaps onto your head while looking away from it (walking round the bakery: 23 snaps before, 6 after, all with your back to a wall), and walking into a room it can look in through the doorway.
- **The game stopped on Continue after a trip to Boccapioppo** (played with the tester's own save, and `play_load_away`): Continue (or Load) on a save made in another place reloads the scene for that place, and the "Welcome back" banner was then drawn on the old scene, already out of the tree: a script error, which in the Godot editor pauses the game in the debugger. Saves were never damaged. The new scene now shows the banner (and the pause menu's "Game loaded"). The tester's save loads and plays (8 runs, compatibility renderer and Forward+ on a software GPU).
- **The crash after Load from the pause menu into another place was the test harness, not the game** (played, tested): `await_island` (`tests/autoplay_base.gd`) asked the old game for its id after a click-triggered load had already freed it. Only Godot run from the editor catches a call on a freed object; a standalone run reads freed memory, and after a second swap in one run that crashed (signal 11, 6 runs in 8). Found with gdb: the crash was inside the playthrough's own awaits. It now checks the old game is still there first: 12 runs in 12 clean. The game itself never crashed: the same two loads driven with real clicks from a plain per-frame script, with no awaits held across the swap, ran 12 times in 12 without a crash, before the harness fix. `play_load_away` now also loads from the pause menu (two swaps in one run).

## Livelier characters (08/11)
Checked by the headless tests (`test_animation.gd`: stopping eases, the stride stays smooth when speed changes, turning leans the body and turns the head first, landing squashes and settles, a chop winds up, strikes and jolts) and every playthrough (nothing in play broke); seen in a recorded reel before and after (`tests/anim_reel.gd`, 30 fps, see `docs/GRAPHICS.md`). Not seen at full frame rate on a real screen.
- **Everyone moves with more weight** (the player, the villagers, Toriano's passers-by, all through `Chibi.animate`): walking eases in and out instead of snapping, the stride follows the distance walked, each step squashes and stretches a little, the body leans into the walk and tips forward when it stops, banks into turns while the head leads, and landing from a jump squashes and springs back.
- **Standing still is alive:** breathing, a slow shift of weight, and now and then a glance to one side.
- **Actions have anticipation and follow-through:** chopping and mining wind the tool back over the shoulder, strike fast and jolt on impact; hammering and digging do the same; the wave overshoots and lowers; celebrating crouches before the jumps and squashes on each landing; surprise squashes before it jumps.

## Toriano gets spots that want things, open streets and the new furniture (09/11)
Toriano had caught up with everything else ("Toriano catches up"); what Boccapioppo and Casalrana got since was missing:
- **Seven spots that want things** (`hangouts`): the cathedral square, the Duomo's steps (Vale), the Duomo tram stop
  (Ambrogio), the bars' quay on the Naviglio (Franco), the Parco dei Platani (Ottavio), the castle gate (Gennaro) and
  the opera's steps (Gino), each wanting two or three of a seat, light, something green, shelter or a counter, noticed a
  few at a time in *La Sera* and listed by place. Toriano keeps its column inches, so they don't move Monteforchetta's
  approval.
- **Open streets to build in** round each: the square and its streets, the quay, the park, the castle gate and the
  opera's forecourt. The park's zone is `"wild": true`, so its trees and bushes grow where they did (a build zone
  normally keeps the scattered decor out, and moving the park's trees had put one on the pond path).
- **The new furniture**: Chiara sells the armchair, mirror, potted plant, side table, credenza and piano.
- **The map** in Toriano labels its real places, not the numbered blocks or the backdrop ring, and villagers go by their
  names, not their titles (Augusto, not Signor).
- **Not changed:** the north end of number 14's west balcony ("noticed, not changed" in "Toriano catches up"): a probe
  walking off it in sixteen directions from five spots never drops into the courtyard, so the step-off couldn't be
  reproduced and no wall was added.
- **Checked:** **tested** (454 passed): Toriano's spots are in its open streets, reachable and every need there can be
  met, Monteforchetta's needs aren't listed, no approval moves; the map's label rules. **Played:** all of Toriano's
  playthroughs pass with the spots and streets in place (`play_metropolis` 37 checks, `play_metropolis_story` 41,
  `play_metropolis_side` 50), and `play_ui_shots`. **Seen:** in Toriano the needs card lists "The cathedral square ·
  something green", "The Duomo's steps · somewhere to sit" and "The Duomo tram stop · somewhere to sit", and the map
  shows the villagers by name with the backdrop unlabelled. **Not checked:** building at one of Toriano's spots and
  meeting its need in a playthrough (the tests place pieces at every spot).

## Monteforchetta's clock no longer holds at dusk (08/11)
- **The rule now** (from the user, for every location): the clock never holds. Monteforchetta's day runs on past
  8:30 PM into the night like the other places'; no `day` block holds unless it asks with `"hold": true`.
- **What used the hold now uses the evening around dusk** (`WorkDay.dusk`, 7:30 to 10:30 PM): the piazza's gathering when
  it's fully lively, the festa music, and the lamps tip (now "Dusk: the lamps come on": the evening goes on as long as
  you like, and sleeping ends the day). The opening ceremony still plays at dusk when you end the day.
- **Beds and benches everywhere** offer "Sleep until tomorrow morning" (which ends the day) as well as their wake times.
- **Checked:** **tested** (432 passed): no day holds unless it asks, Monteforchetta's doesn't, dusk is the evening
  around 8:30. **Played:** all of Monteforchetta's playthroughs pass without the hold (24 runs: the sleep one naps to 9 PM
  and watches the clock run on with the new dusk tip, sleeps until tomorrow morning from a bench and from your own bed;
  the opening ceremony still plays at dusk; the piazza still gathers at dusk), and Casalrana's three.
- **Ines's log by the Roman bridge** (Boccapioppo): the same run missed one of Ines's runaway logs. It lay on the bank
  just behind the bridge's west parapet, which has been solid since the fix for falling off the bridge, so coming
  along the bridge you walked into the wall. It now lies on the open bank, and a test keeps anything you can pick up
  more than 1.2 m from a parapet. From the same saved state all twelve logs and lost things are found.

## The sawmill's letterbox moves to the yard gate (08/11)
- **A letterbox you couldn't reach** (Boccapioppo): after the merge with main, Boccapioppo's playthrough posted only four
  of Pierina's five letters. The sawmill's box stood inside the open shed, among the log piles and two metres from
  Ines's door, so she took the interaction when she was home and the way in was blocked. It now stands at the yard gate
  on the path, and a test keeps every letterbox more than 2.5 m from any spot a villager's day takes them to.

## Playtest fixes: the flood, the monster, Pierina's far round (08/11)
- **The storm night's river really rises** (Boccapioppo): it used to come up 32 cm, all at once, and stay in its bed.
  Now a muddy flood spreads outside the levee through the evening: still in its bed at 9 PM, over the floodplain by
  11, and by midnight lapping at the foot of the levee and against your wall in the breach, the trees standing in it,
  while the town behind the levee stays dry. It stays up until Ermes calls the flood over (`RiverTown.flood_level`, a
  flood layer in `scenery.gd`; the shared water shader gained an `opaque` setting for muddy water).
- **The Monster of the Po shows itself** (Boccapioppo): when it bites, the camera cuts to the water and a three-metre
  catfish bursts out, arcs through the air thrashing, hangs there turning to stare at you, and crashes back in, before
  the whisker and the toast (`BigFish`, `WorldActions.leap`, the fish's `leap` in the layout: any fish can do it).
- **Pierina's Far Round** (Boccapioppo): the town is too small for a bike to make a difference, so the round now goes
  where she can't: five letters posted in letterboxes the length of the map, at the farm out west, the station, Gildo's
  biscuit tin on the floodplain, and over the river the sawmill and the plantation foreman's box. Letterboxes are a new
  shared feature (`letterbox` in a layout: "Post a letter" when a request is waiting for one, `post:<id>`).
- **Checked:** **tested** (384 passed): the flood's rise through the evening (in its bed at 9 PM, over the floodplain by
  midnight, short of the town and the dance hall's floor), the monster's leap and model, the five letterboxes (dry,
  by a path, two over the river, 70 m and more apart) and the round's steps. **Played**, from the playthrough's own
  checkpoints: the round (`b3`: five letters posted by bike, 251 m ridden), the catfish (`s8b`: it leapt 3.9 m and the
  request finished) and the levee (`s11b`: at midnight the flood stands at 0.45 m over the floodplain while the town is
  dry; `s11` and `s12` still pass), then Boccapioppo's whole playthrough from the start (36 checks, all passing). The
  flood and the leap were checked in Forward+ screenshots by day and by night.

## Playtest fixes: a village map, the Roman bridge, the town's needs, dancing, furniture, naps (08/11)
- **A map of where you are** (shared): M opens a map of the place you're in, drawn from its layout: the ground and the
  water, the paths, the buildings (the ones with a name are labelled), the building sites open to you (dashed), the
  bus stop, benches, the spots that want something, every villager about with their name and a ! or ★ if they have
  a request or are waiting to hear from you, what you're tracking (⭐) and you (the pink arrow, pointing the way you
  face). Click anything for its name. A tab switches to the travel map; catching the bus still opens the travel map
  (`VillageMap`, `scripts/ui/village_map.gd`).
- **The Roman bridge** (Boccapioppo) looked like two loose walls with the dirt path between them, and a dark hole
  showed through the walkway where an arch's shadow was. It's one stone body now: arches that run right through it
  under a paved deck, parapets standing on it, and the piers' cutwaters capped in stone.
- **The things the village could use** (Boccapioppo, Casalrana): the list showed Monteforchetta's wishes ("somewhere to
  sit", with no place) because the other villages had no spots of their own. Now each has six (Rina's bar, Primo's
  workshop, the church door, Ermes's door, Pierina's doorstep and the piazza; in Casalrana the crossroads, the station
  forecourt, the church door, the farmyard, Nonna's garden gate and the farm office), each wanting two or three things,
  noticed a few at a time in the morning paper, and an open area in the streets where you can build anything, as in
  Monteforchetta. The list only shows the place you're in. Since these villages keep their own meter, what you build
  there doesn't move Monteforchetta's approval (`Needs.open_here`, `Needs.approval_here`).
- **Dancing at the dance hall** (Boccapioppo): once the hall is ready, the town still comes every evening from 8 to 10,
  but now they dance (a new `dance` pose: a swaying three-step with one arm up and a slow turn), Wanda too.
- **Bench naps**: you only wake up soaked if it rained in the four hours before you woke (rain anywhere in a long night
  used to count, so it was nearly every night), and a night on a bench ends in a joke about half the time instead of
  always.
- **Ten more pieces of furniture**: an armchair you can sit in, a side table, a potted plant (it counts as something
  green), a coat stand, a chest of drawers, a mirror for the wall, a grandfather clock, a wood stove, a credenza with the
  good plates and an upright piano, each with its own model and build-bar picture. Elio sells all ten plans in
  Monteforchetta (the bigger pieces once his workshop is done), Ines four in Boccapioppo and Silvia four in Casalrana.
- **Checked:** **tested** (381 passed): the map's labels, the spots in both villages (in the open streets, reachable,
  every need meetable there, Monteforchetta's needs not listed, no approval moved), the dance schedules and pose, the
  four-hour rain window and the quieter nights, and the furniture (models, costs, plans on sale). **Played:** all of
  Monteforchetta's playthroughs pass (24 runs; `play_ui_shots` checks M shows you, every villager about, the buildings
  and the bus stop), Boccapioppo's (34 checks: the new `s5b` finds nine villagers dancing in the hall on the first
  night) and Casalrana's three. The map, the bridge and the furniture were checked in screenshots in all three places.
  **Not checked:** building in Boccapioppo's or Casalrana's new streets and meeting a need there in a playthrough (the
  tests place pieces at every spot); a bench nap's gag in play (it's random by design).

## Casalrana catches up (08/11)
Casalrana gets the redesign's systems, as Boccapioppo did:
- **A work day that doesn't hold the clock** (`"hold": false` in its `day`): poplars, straw, cobbles and clay grow back
  the next morning, the clock runs on through the night for the night express, the dawn inspection train and the
  nativity, and a sleep into the next day ends the day.
- **Its own paper**, *La Gazzetta del Binario Morto* (the dead-end siding's gazette), with headlines about Paletta,
  the herons and the 8.12 that never stops.
- **Paletta opens what you build** at dusk, in station-master's words ("Ladies and gentlemen, now arriving: two flower
  beds and a bench in Casalrana.").
- **Tastes** for the six villagers, each near the place they spend their days: Paletta likes railway lanterns, enamel
  signs and flower beds in signal red and green on the platform, Barba Tista stone, fences, levers and pumps by the
  sluice, Nonna flowers, trees and benches at her corner of the paddy, Silvia waterwheels and gears at the mill, Don
  Remo lamps, pillars and statues in the churchyard, Matteo railway things by the crossing. The inspector is only
  visiting.
- **Every building request is a brief with wishes**:
  - the flat (a bed, a table, somewhere to sit; a rug for Nonna, a lamp in the window for Paletta);
  - the bell-tower climb (a lamp for Don Remo, something to hold on to for Silvia);
  - the nativity stable (a fence for Barba Tista's ox, a seat for Nonna to sing from);
  - the platform (flower beds for Paletta, a railway lantern for Matteo) and its shelter (an enamel sign for Paletta,
    some colour for Nonna);
  - the sluice (a fence for the cows, a lamp for Silvia), its walkway (railings for Matteo's BMX, a bench for Don
    Remo), the winter paddy (a lever for Barba Tista, flowers for Nonna);
  - the mill (a lamp for Silvia, a workbench for Barba Tista) and Nonna's bench (flowers on both sides, a lamp for
    Matteo).
  - The shelter keeps the inspector's four conditions as its four musts (roof, bench, two lamps, a sign).
  - A wish met there adds hearts but no Monteforchetta approval, since Casalrana keeps its petition.
- **Checked:** **tested** (377 passed): every Casalrana building step is a brief whose wishes come from its own
  villagers and use only checks met before; each step's playthrough build meets its musts, the pieces for every wish
  can be built alongside it, and you hold the plans for all of them; Casalrana's day, paper, ceremony and tastes are
  its own (`test_commission`, `test_alive`, `test_work_day`). **Played:** all three of Casalrana's playthroughs pass
  with the briefs (`play_rice_village` 30 checks, `play_rice_village2` 48, `play_rice_village3` 40): the flat, the
  sluice and its walkway, the paddy, Nonna's bench, the tower climb, the mill, the stable, the platform and the shelter
  all tick off from the same builds as before. A separate check built a bench and two flower beds at Nonna's corner:
  Nonna gave a heart, her wish for flowers on both sides was met, and sleeping into the next day Paletta opened them
  ("Ladies and gentlemen, now arriving: two flower beds and a bench in Casalrana."), Nonna cheered, and the morning
  *Gazzetta del Binario Morto* led with it ("Ribbon cut on two flower beds and a bench in Casalrana. The 8.12 regional
  went straight past"), with Barba Tista's gossip. **Not checked:** most wishes met in play (only Nonna's).

## Playtest fixes: Boccapioppo catches up, and travel (08/11)
- **Leaving a conversation is 1** (shared): the way out ("Goodbye", "Not now") is listed first and numbered 1, so it's
  next to the other choices on the keyboard instead of 0 at the far end; the other choices follow from 2. Esc still
  leaves, and E still picks the first real choice, so tapping through a conversation never leaves it by accident.
- **The Roman bridge's ends** (Boccapioppo): where the walkway rises above the banks you could step off either side and
  drop up to 1.5 m, through the parapets, which were only drawn. They are solid there now (invisible `river_town_parapet`
  boxes in the layout); over the water the river already stops you, and the last stretch onto each bank, where the drop
  is under 30 cm, stays open so villagers' routes still reach the bridge.
- **Travel has a journey** (shared): taking the bus to another place fades to the travel map, where a little bus drives
  along the road from where you are to where you're going (by Monteforchetta when neither end is, where the roads meet),
  with the trip's names over it, before the new place fades in. Any key skips it (`Journey`, `scripts/ui/journey.gd`;
  the map's `MapView` draws the trip).
- **Boccapioppo gets the redesign's systems**, the way Monteforchetta has them:
  - **A work day that doesn't hold the clock** (`"hold": false` in its `day`): trees, rocks and the rest grow back the
    next morning instead of three hours later (the east bank's poplars reset at 7 PM before), but the clock runs on
    through the night for the storm, the first dance and the catfish, and beds and benches keep their wake times. A
    sleep that carries into the next day ends the day: the evening opening and the morning paper.
  - **Its own paper**, *La Voce dell'Argine*, with headlines about the warden and the river instead of the Sindaco
    (a layout's `paper` block now overrides the shared lines, the way `naps` names the paper; its verdict on a new build
    is *La Voce*'s, not the Eco's).
  - **Ermes opens what you build** at the end of the day, in his own words (a layout `inauguration` block with
    Boccapioppo's lines: "Boccapioppo! Tonight, a bench and two lamps in town. I measured it.").
  - **Tastes** for all nine villagers (a heart and a remark for a liked piece or colour near their spot, gossip in the
    paper): Ermes likes sandbags, stone and streetlights in dark slate, Wanda lamps and flowers in pink or lilac, and so
    on. Tastes, gossip and Monteforchetta's market day now only count the villagers of the place you're in.
  - **The building requests are briefs with wishes**: the pontoon bridge (walkable, four railings; wishes: railings on
    both sides for Ermes, a lamp for Primo), pumping out the piazza (power to the pump; a lamp on the quay for Rina, a
    bench to watch the wheel for Tullio), the dance hall (a dance floor, a stage, three seats; two lamps for Wanda, a bar
    counter for Rina, something bright for Pierina), closing the breach (sealed, a new kind of check; a lamp for Tullio,
    a bench on the levee for Gildo), the houseboat's slipway (a path over the water; a railing for Ermes, a lamp for
    Gildo) and her cabin (a table, a seat, a lamp; a rug for Ermes, a splash of colour for Wanda). The ticks, the permit
    stamp and the hearts work as in Monteforchetta; a wish met there adds no Monteforchetta approval, since Boccapioppo
    keeps its flood gauge.
- **The game looking different after talking to Gildo:** not found. Handing in his catfish request is the one
  conversation with him that changes the town (Mattia's photo goes up in the bar), which rebuilds the world where you
  stand; rebuilt at night, by day and inside his shack, it looks the same before and after. Needs a screenshot or a
  description of what changed to go further.
- **Checked:** **tested** (374 passed): leaving is `1` and comes first, also when turning down an offer
  (`test_goodbye_is_always_one`); walking sideways off either raised end of the Roman bridge stops at the parapet, and you
  can still walk across it (`test_you_cant_step_off_the_roman_bridge`); the journey's timing, its caption and its road by
  Monteforchetta (`test_journey`); a day that doesn't hold runs on through the night and regrows next morning
  (`test_work_day`); every Boccapioppo building request is a brief whose plan meets its musts and whose wishes can all be
  met with pieces you can build, and the new sealed check (`test_commission`); tastes, gossip, the market and the paper
  belong to their place (`test_alive`). **Played:** Boccapioppo's whole playthrough passes (`play_river_town`, 33 checks)
  with the new briefs: it builds the pontoon bridge, the pumping house's waterwheel, the dance hall, the slipway, the
  cabin and the levee wall to their musts, and crosses the Roman bridge; Tullio and Wanda give hearts for a pontoon and a
  lamp near their spots. A separate check in Boccapioppo built a lamp and a bench on the quay and slept on a bench into
  the next day: Ermes opened the lamp at dusk in his own lines, in front of Boccapioppo's villagers, and the morning
  paper was *La Voce dell'Argine* ("Warden opens a lamp in town, to the nearest centimetre"), with Ermes's gossip and
  no Sindaco or Eco (which is how the Eco's verdict line was found and replaced). Travelling shows the journey (screenshots
  mid-ride and on arrival; `play_map` travels to Toriano through it). Every playthrough of the three villages passes
  (`play_all.sh`, 28 runs; `play_full2` needed its wood-gathering helper to skip the big oaks the old
  hatchet can't fell, and passes). **Not checked:** the Gildo glitch (not reproduced); leaving with `1` was only tested,
  not pressed in a playthrough; the wishes beyond Tullio's and Wanda's weren't met in play.

## Ornella's boars can always be finished (08/11)
- **A missing boar** (Monteforchetta, playtest): her request needs three boars fed, but it only counted a feed made on the "Offer a chestnut to each boar" step, while a bakery boar takes a chestnut any time the request is on. Feed one while you're still on the chestnut step (say, with a chestnut left over after feeding the woods boars) and it trotted off to the woods for good, uncounted: two boars left for a step that needs three, and no way to finish. A save stuck like that had all three boars fed and only two counted.
- **The fix:** the step counts the bakery boars that are fed, from their own flags (`WorldActions.count_boars`, the request's `stat` `bakeryBoars`), whenever they were fed. Loading a stuck save counts them, so the request moves on to Ornella's hazelnuts.
- **Checked:** **tested** (366 passed): `test_boars` feeds a boar while you're still gathering and finishes with the other two, and repairs a save with all three fed and two counted (both fail without the fix). **Played:** the new `play_boars` (9 checks, in `play_all.sh`) takes on the request with one chestnut left over, feeds a bakery boar early, shakes the chestnut tree, feeds the other two and moves on to the hazelnuts; then it saves a stuck state, loads it, and the request moves on. Without the fix it fails at both points, as the playtest did (2 of 3, no boar left). All of Monteforchetta's playthroughs pass (`play_all.sh`, 24 runs). **Not checked:** the tester's own save (not available here); it should load straight onto the hazelnut step if all three boars are fed.

## Toriano catches up (08/11)
The user asked for Toriano's graphics, requests and systems to work like the other places'. It gets what Boccapioppo got
("Boccapioppo catches up", below) and conversion step five's look, done in a city's way. Toriano's own doc has the details
(`docs/locations/metropolis.md`, Status).
- **A work day that doesn't hold the clock** (`day` in its `location.json`): spots regrow overnight; Gino's score pages
  at night and Christmas Eve keep their hours; a sleep into the next morning ends the day.
- **Its own paper and opening**: the morning paper is *La Sera di Toriano* (its layout's `naps` and `paper` blocks,
  with no Sindaco, Eco or approval rating), and Architetto Annoni opens the day's build at dusk in her own words (its
  `inauguration` block).
- **Tastes** for all thirteen villagers, near their spots (number 14's courtyard has four: Augusto, Sala, Simone and
  Elvira, who like different pieces).
- **Every building request is a brief** (13 of them; the footbridge's railings step joined its crossing, as in
  Monteforchetta and Boccapioppo), with one to three musts, two or three wishes from Toriano's villagers, at most one
  new kind of check, and an example plan taken from the playthroughs' builds. The scaffolding's plan is a stair one
  tile wide (21 pieces). Gathering now pays for each plan: the footbridge asks for 24 wood (was 14), the scaffolding
  30 stone (was 16).
- **The look**: `"kit": true` in Toriano's `houseStyle`; city blocks and number 14 dressed with the house kit's
  windows, shutters, doors and a granite base by `metropolis/facades.gd` instead of the painted façade; rooms keep
  their walls and doorways, with fading kit windows above; shared walls stay blank; landmarks and the backdrop ring
  unchanged; a build for every villager. Before and after: `docs/models/conversion_toriano.jpg`.
- **The side playthrough's first check** (loading the main story's save from the title screen) missed every time it
  ran in `play_all.sh`, and passed when started by hand: its run line lacked the `Run:` label `play_all.sh` reads, so it
  was started without `--title`, its frame limit or its timeout, in Monteforchetta. The label is back, and the script
  now also waits for the title's buttons to be on screen and then for the game to be playing in Toriano (following the
  reloaded scene), noting what it found. Its walk home to your flat (`[home:spot]`, which also failed on main) planned its
  route over the flat path graph and ended up in the courtyard under the balcony: going to a room upstairs now climbs
  the stair and follows the balcony's own path nodes to the door (`metropolis_base.gd`, `go`, `nav_path`).
- **Checked:** **tested** (379 passed): Toriano's systems (`test_alive`), its work day (`test_work_day`), every brief
  sound, every plan built and meeting its musts and every wish then met (`test_commission`), every city block and
  tenement wing with real windows that light at night, none opening onto a neighbour, rooms fading their upper windows,
  the backdrops unchanged, and thirteen different builds (`test_house_kit`). **Played:** a throwaway run in Toriano built a
  bench and a lamp at the tram shelter's site (Ambrogio liked the bench: "A bench! Passengers will wait in comfort. Ding
  ding! ♥") and slept on the square's bench into the next morning: Annoni opened them at dusk in her own words ("Gather
  round, before the fog does. A bench and a lamp in the city, opened in our lifetime."), and the paper was *La Sera di
  Toriano*, leading with the opening, with La Sera's verdict and a taste of Elvira's, and no Sindaco or approval. All of
  Toriano's playthroughs pass through `play_all.sh` with everything in place: `play_metropolis_story` (41 checks, the
  new briefs and the footbridge's two musts included), `play_metropolis_side` (50, from the title screen, every side
  brief built to its musts) and `play_metropolis` (37). **Seen:**
  number 14's courtyard, a city block from the street, the cathedral square from above and a street at night, before and
  after, and the cast lineup (a bin in the look-dev scene hides the last villager). **Not checked:** frame rate on a real graphics card with the city's windows (4,087
  windows, about 17,000 instanced parts in all, drawn a few batches per building); the landmarks restyled with the kit (not done). **Noticed, not changed:** at the
  north end of number 14's west balcony the playthrough sometimes steps off onto the stair beside it and down into the
  courtyard (it climbs back up); a player might too.

## Playtest fixes (third playtest notes, 08/11)
- **Build mode's view** (shared): you could move (WASD), turn (Q/Z, right-drag) and zoom it, but in build mode nothing said so (the key bar is hidden there), and on a trackpad only zooming worked. Now ⟲ ⟳ buttons in the top bar turn it 45°, a line along the bottom of the catalogue gives the keys, middle-drag moves the view (grab the map), sideways or Shift+scroll turns it, and a trackpad's two-finger swipe moves it and a pinch zooms.
- **The bakery's boars** (Monteforchetta): offering them chestnuts worked in a fresh run, but one boar was squeezed into the 1.4 m alley between the bakery and the house next door, half in the walls, and a fed boar only hopped to the bakery's corner by the chestnut tree, so it looked as if they never left. That boar now waits on the open west side, the boars win the prompt over the cat beside them, and a fed boar trots off into the woods.
- **Build mode follows the site you're at** (shared): away from a site with a plan, the plan panel, its arrow, "Next" and V showed the first plan of any request. They now show only the plan of the site you're building at (none in the village streets), and while you build, the request list leads with the request whose building step is at that site.
- **Chairs at a table** (shared): a villager only sat on a seat with free ground straight in front of it, so a chair pulled up to a table got stares. A table, desk or counter (`"sitAt"` in pieces.json) in front means they step in from the side; a seat facing a wall still gets a stare.
- **The Sindaco's glasses kept turning up** (Monteforchetta): lost things grow back after a day, and the first one is always his glasses. They, Gino's score pages (Toriano) and the things from the trains (Casalrana) are `"once"` now.
- **Undo** (shared) only reaches back to when you opened build mode.
- **Checked:** **played**: a throwaway run in Monteforchetta (the turn buttons, middle-drag and Shift+scroll; with the house and the workshop both under way and the house tracked, the workshop's site shows the workshop's plan and leads the list with it, the village streets show no plan and go back to the house; a piece built, build mode left and reopened, Ctrl+Z leaves it alone and undoes the next one; the glasses gone days later), and a run feeding the three boars (each counts, and they end up in the woods). Monteforchetta's whole set (`play_all.sh`, 23 runs): every check, after the card was kept short (`play_overlays` caught it running into the catalogue); `play_tools`'s quarry check `k5` failed once because the oak felling before it happened to be a perfect run too (it counts every perfect run), and passes run again. `play_rice_village2` (48) and `play_rice_village3` (40); `play_metropolis_story` (41) and `play_metropolis_side`, Gino's score pages included, failing only `[home:spot]` as on main (its first check needs the run to itself, as before). Seen: the build view with the turn buttons and the catalogue's line. **Tested**: 360 headless tests, among them `test_boars`, a lost thing with its own name turning up once in every place, and a chair at a table sat on from the side (fails without `sitAt`). **Not checked in play**: villagers actually sitting at a table you built, and a real trackpad (the gestures are Godot's; which way a two-finger swipe moves the view may want flipping).

## The metal detector is Fede's to give (08/11)
- **You could dig for treasure from day one** (shared): dig spots and the beeping checked the Geometra's kit, not the detector. A `metalDetector` flag now gates both. Fede's Beep, Beep gives it when you take it on ("Here, you carry it"); Matteo's museum and Vale's Roman finds give it too, so a later place's digging request works for a player who skipped Fede's side request. Saves with any of those requests already taken on get it on load. Lost things still turn up with the kit, as before.
- **Checked:** **played**: a throwaway run in Monteforchetta, standing on a dig spot with the kit: no beeping and no prompt before Beep, Beep, full beeping and a find once it's taken on; Monteforchetta's whole set (`play_all.sh`, 23 runs, every check); `play_rice_village2` (48) and `play_rice_village3` (40), digging for Matteo's museum; `play_metropolis_story` (41) and `play_metropolis_side`, whose Roman finds pass. `play_metropolis_side` fails one check, `[home:spot]` (the walk home to the flat), on main too; run beside three others its first check also missed the slow load from the title screen, which passes run alone. **Tested**: `test_detector` (no detector in a new game, every request in every place that sends you digging gives it, old saves keep it). **Not checked**: Boccapioppo's and the Cove's dig spots in play; they now need the detector from Fede.

## Prompts and villagers on the right storey (08/11)
Casalrana's second playthrough had stopped at the flat: the roof could not be patched, so the flat never opened for building and everything after it fell short of signatures.
- **A villager spawned under a raised floor stood on top of it** (shared): Matteo's morning spot is the waiting room, right under the flat, and he appeared upstairs in the empty flat, where "Talk to Matteo Mosso" took the roof's prompt. A villager placed at a room's spot (at start, after a time skip, or getting up from a seat) now stands on that room's storey (its `y`); spots outside a room with its own storey are placed as before.
- **Prompts stay on their storey** (shared): villagers and layout features (benches, beds, wardrobes, boards, stops) now carry their height, so from the flat you no longer get the waiting room's bench or a villager on the floor below. A feature with no `y` is on the ground, like its model; the departure point is unchanged.
- **Banners no longer swallow clicks** (shared): the subtitle and reward chips of a banner ("Approval milestone!", "Quest Complete!") caught the mouse, so a build click under one was lost. They let clicks through, like toasts.
- **Checked:** **played**: `play_rice_village2` (48 checks), `play_rice_village3` from its save (40) and `play_rice_village` (30), all passing; before the fix, `play_rice_village2` failed the same 6 checks on main. **Tested**: 320 headless tests, among them `test_storeys` (every feature in every place can be reached from a surface beside it, every room spot puts a villager on that room's storey, and the waiting room's bench and spot are a storey below the flat). **Not run**: the other places' playthroughs (Metropolis has rooms on upper storeys; the headless test covers its spots). **Noticed, not fixed**: placing the first bed in Casalrana shows all five of Monteforchetta's approval milestones as banners at once, and `unlocks_seen` then lists them twice.

## Build-piece icons (08/11)
Seen in the game (the build bar in play_build_clarity's screenshots) and checked by the headless tests (`test_icons.gd`: every piece has its picture) and every playthrough (nothing in play broke).
- **The build bar shows each piece as a small render of its own model** (ink outline, the game's lighting), in place of its emoji; locked pieces show their picture faded instead of a padlock. The selected-piece and draft panels show it beside the name. The pictures are rendered by `tests/render_piece_icons.gd` into `assets/icons/pieces/` (render again after changing a piece's model: `tools/icons/README.md`).
- The categories' tabs and lines of text (the plan panel's "Next: ...") keep the piece's emoji, from the one-colour icon font.

## Icons (07/11)
Checked in the game (Forward+ screenshots of the top bar, the bag, the journal and the pause menu, loading a real save), by the headless tests (`test_icons.gd`) and every playthrough (nothing in play broke). Not seen on a real monitor yet.
- **The emoji are now the game's own icons** in watercolour and pencil (style E of the icon directions): the 17 shared resources, the HUD and key hints, the journal, the menus, the weather in the clock, the hours, the minigame tools, build mode's tools and common symbols (84 in all). They are a colour font the UI fonts try before the bundled one-colour icon fonts (`tools/icons/`, `UiTheme.drawn_icon_font`), so the text and data keep their emoji and nothing else changed.
- **Still one-colour (bundled Noto Emoji):** the other locations' own resources (Boccapioppo's sand, bicycles...). The build pieces are now pictures of the pieces (above).
- The approval rating's icon is a green, white and red rosette instead of a heart.

## Tonemapping and light (07/11)
Checked in Forward+ renders of ten fixed views before and after (`godot/views.sh`, measured with `godot/measure_views.py`), three in the compatibility renderer, and by the headless tests and every playthrough (nothing in play broke). **Not seen on a real monitor or graphics card yet**: please look at mornings, golden hour and night.
- **ACES tonemapping** instead of linear: bright sky and white walls roll off instead of clipping flat (the sunset view had 6.2% pure white, now 0.5%), so the sun could get stronger. **The sun is nearly three times the ambient by day** (it was 1.5 to 1), so lit and shaded sides read apart: 15 to 55% more contrast in every view. Daytime is 5 to 11% brighter, golden hour and rain within 5%, night 15% darker but moonlit blue with warm lamps and windows. AgX and Filmic were tried and dropped (`docs/GRAPHICS.md`).
- **Monteforchetta's square** is a warm grey local stone (`cobbleColors` in the layout, new) instead of near-white granite, so the piazza no longer glares and the characters on it stand out. Other places keep the old stone unless their layout sets it.

## Monteforchetta, stage 4 (outfits and music)
Outfits checked in Forward+ renders of the cast, reviewed by eye, by the headless tests, and in the character creator's screenshot. The music was checked by the tests and in offline renders: their levels and pitch were measured, but nobody on the team has listened to it yet. The playthroughs cover that nothing in play broke.
- **Music:** original songs in the style of Italian pop around 2000, one for each part of the day and one for building, as data in Monteforchetta's map entry (`music` in `islands.json`):
  - dawn: a clean guitar picking out the chords under a piano melody;
  - morning, the main theme: guitar pop with a strummed guitar, eighth-note bass and a backbeat;
  - afternoon: dance-pop with a kick on every beat, offbeat bass and a synth hook;
  - evening: a piano ballad with strings, which goes up a tone every second time round;
  - night: slow piano over strings;
  - building: bouncy guitar pop.

  New instruments for this: a plucked guitar (tuned exactly, whatever the note), piano, synth bass, a bright saw lead, strings, snare, handclap and open hi-hat. New drum patterns (pop, dance, ballad), bass patterns and strummed chords. Clockwork Cove and places without their own music keep the shared tunes, which play exactly as before.
- **Tested:**
  - every Monteforchetta part of the day has its own tune, on known instruments;
  - no step stacks too many loud notes;
  - the pop patterns land where they should (snare on the backbeat, four on the floor, offbeat bass, the key change);
  - the guitar, piano, bass, lead and strings sound within 12 cents of their notes.
- **To hear it:** `tests/render_music.gd` renders a place's songs to WAV files, using the game's own notes and instruments.
- **The cast in late-1990s clothes:**
  - the Sindaco: a dark suit with a tie and the tricolour sash;
  - Gigia: a brown work jacket with big pockets and a corduroy collar, and rubber boots;
  - Elio: blue overalls with a pocket full of pens and a screwdriver;
  - Fede: an oversized hoodie, baggy jeans, white sneakers, headphones with orange foam pads and a CD player at her hip;
  - Ornella: a baker's apron over a sweater;
  - Aldo: a bus driver's shirt with shoulder straps and a peaked driver's cap.

  Gigia's and Ornella's hair are natural colours now.
- **The Geometra:** arrives in a colour-blocked windbreaker and carries a clipboard instead of the old magic staff. The creator says "Create your Geometra", and the default name is Geometra.
- **New pieces for everyone:**
  - tops: windbreaker, hoodie, suit, uniform shirt, work jacket;
  - baggy jeans;
  - hats: headphones, driver's cap;
  - accessories: tricolour sash, pocket of pens, CD player, apron.

  Most are in the wardrobe from the start. Aldo's porcini bet now gives his spare driver's cap; the captain's cap joins the sailor top at a 120 approval rating; the 200 milestone adds the Sindaco's spare sash, lent for the photographs.
- **Tested:** every villager's outfit uses pieces that exist (none falls back to the default look), every piece builds a character, and every clothing reward and unlock hint names a real piece.

## Monteforchetta, stage 3 (look and plants)
Checked in Forward+ screenshots, reviewed by eye, and by the headless tests; the playthroughs cover that nothing in play broke, not the look.
- **Autumn light:** Monteforchetta's `look` (in `islands.json`) warms the grade a touch, blows a little harder, drops more leaves in autumn golds and rusts (`leafColors`) and has fewer fireflies. The grade stays within a few percent of neutral, as `docs/GRAPHICS.md` advises.
- **Valley fog:** mist fills the valley below the hilltop in the mornings and burns off by late morning, gathers a little again at dusk and at night, and stays all day when it's misty. It thins along a ragged edge where the slopes and far hills come up through it, takes its colour from the sky, and drifts with the wind (layout `valley_fog`; `TerrainBuilder.build_valley_fog`, `Atmosphere.valley_fog_at`, tested). Its soft edge against the far hills needs Forward+; the compatibility renderer thins it on the slopes only.
- **The horizon:** the far hills are patched with autumn vineyards in gold, yellow and rust, rows striped along the contours (they fade to their average colour where they would be finer than a pixel, so they don't shimmer), woods on the tops, and six small hilltop villages with bell towers on the crests (`horizon.villages`). The Alps are lower and whiter: a long snowy line with one taller peak (`alps_peak`).
- **The village:** plaster in ochre, cream, faded rose and sandstone, and the castle in brick; curved terracotta roof tiles (coppi: rounded caps over hollow pans in ribs down the slope, `roofStyle`); green shutters, stone quoins at the corners and a plaster cornice instead of timber corner posts and beams (`houseStyle`). Window boxes keep their flowers.
- **Plants:** an olive and straw meadow (`grassColors`) with greener tufts, autumn bushes (`decor.bushColors`) and fewer meadow flowers; the choppable trees take the autumn leaf mix; Gigia's groves are hazels, clumps of slender stems under a low crown (`fruitTree`); a rose bush at each end of the vineyard rows (`roses`); cyclamen under the woods (`decor.woodFlowers`); two persimmon trees, bare and hung with orange fruit, by the Cauda farm and on the belvedere; pumpkins by the farm door, the church steps and the market stall.
- **Animals:** three wild boars root about in the woods and trot off if you come close (the bakery's boar model, now shared as `Props.wild_boar`); four village cats sit about the piazza, the bakery, the newsstand and the church, watch you go by and can be petted; crows hop in the fields and fly off to another field when you get near (layout `wildlife`, tested to stand on dry land).
- **For other places:** all of this is layout or `look` data, listed in `docs/WORLD.md`, so the other locations can use it.

## Monteforchetta, stage 2 (map and buildings)
- **The ground:** a hilltop. The village and its fields are nearly level (the castle on its mound); past the edge the hill falls away in long slopes to a valley floor 28 m below, which you can't walk down (the same rule as water). The stream still crosses the hilltop in a fold, fed by the spring by the mill channel. Code in `Heightfield._monteforchetta`.
- **Beyond the edge:** vineyard rows striped along the slopes' contours in autumn colours (`vineyards` in the layout), and a backdrop (`horizon`) of rolling hills patched in fields and vines, bluer with distance, with a snowy Alpine range from the west round to the north. Water only draws inside `water_radius`, so the valley isn't flooded by the single water plane. The ground mesh is bigger (the layout's `size`, 250 m).
- **Buildings:** the church of San Martino with its bell tower replaces Odessa's house (not enterable); the newsstand and tobacconist replaces the inn; the Cauda farm replaces Fede's caravan; the castle is the town hall, and its hall holds your camp bed and wardrobe; Aldo's cottage stands on the belvedere. Plaster and terracotta colours are set; the roof tiles and plaster look came in stage 3.
- **The farmhouse plot** moved across the stream, where the vines meet the woods, framed by ruined walls.
- **Woods:** two stands of autumn oak and chestnut (`decor.woods`), with porcini to pick (`forage` nodes, a new 🍄 Porcini item) and two more chestnut trees to shake. Leaf colours come from the layout (`decor.leaves`, `decor.woodLeaves`).
- **The road and the bus:** you arrive at the lay-by by the village gate, where Aldo's old blue bus is stranded since the storm washed out the main road. Aldo now gives **The Washed-Out Road** (the stream crossing, same rules as the old bridge). The harbour, its cliffs, its gate and Ordinance No. 47 are gone. The finale, **The City Bus**, follows the fountain: pave a turning circle on the belvedere (12 paving pieces, a bench, a signpost or street light), and the region's orange city bus arrives there (solid only once it's there: a `whileFlag` collider) and Boccapioppo appears on the travel map as its first stop.
- **Requests:** Aldo's fishing bet is now **Aldo's Porcini Bet** (three porcini from the woods). The approval rating's 120 milestone, which used to lift the ordinance, now gives a sailor top. No fishing spots in Monteforchetta (fishing stays in the game for other places). No ducks (`"ducks": 0`).
- **Fixed along the way:** chests still gave the removed Spark (now lire); the wardrobe's unlock hints still used the old names; a one-tile bridge with railings on both sides left exactly a walker's width, so you could get stuck on it (railings now hug the outer edge of their tile); the nav test now asks paths to clear buildings by a walker's radius; walking turns a step to slip round a railing end or door post you're slightly off from; the bin by Elio's shop no longer wedges you against its wall; requests ask you to gather enough to build what they ask for (Elio's shop: 12 wood and 2 lengths of copper wire, one of them his; the city bus: 12 stone), checked by a test; Clockwork Cove's rich rocks give crystal again (stage 1 had left its clock request without any); the church's bell tower no longer pulls the camera in when you build in Elio's shop next door; the road from the piazza to the Cauda farm goes round the spring instead of across it (villagers used to walk on the water), checked by a test; the city bus can be boarded anywhere along its side.

## Monteforchetta, stage 1 (names and text)
- **The cast:** Sindaco Commendator Gustavo Dalmasso (the pompous mayor, ex-King Percival) welcomes the new Geometra at the gate and runs the guided first day; Gigia Ghisolfi (hazelnut farmer, ex-Fern), Elio Fusibile (electrician, ex-Bram), Fede Cauda (teen computer whiz, ex-Tilly), Ornella Tealdi (baker, ex-Mabel) and Aldo "Tornanti" Barbero (bus driver, ex-Captain). Odessa is gone. Internal ids (`fern`, `bram`, ...) are unchanged.
- **All the words:** every request, greeting, topic, gift line, shop, tip card, tutorial step, milestone, the arrival card (a letter of appointment from the province), the map and the interface.
- **Systems:** no Spark (builds cost materials, some cost lire); money shows as lire (1 coin = 1,000 lire, `Money`); Kingdom Harmony is the Sindaco's approval rating; magic fragments are lost things (keys on the ground; the first is the Sindaco's glasses); the treasure hum is a metal detector that beeps; crystal is copper wire, dug out of three big street garbage bins with a gag line each time; the rich rock is iron-red and gives metal; apples are hazelnuts, acorns are chestnuts, Gigia's beds grow pumpkins; the bakery squirrels are wild boars (new model); the Lantern Inn is the guest house; fish have real names.

The story is being reworked as described in `docs/MONTEFORCHETTA.md`; the focus stays on mechanics that carry over to new locations.

## Islands
- **Island system:** each island has its own layout file (`godot/data/layout.json` for Hearthglow, `layout_<id>.json` for the others) and ground shape (`Heightfield`); villagers (`island` in `npcs.json`) and their requests belong to an island. Sailing (board the ferry, pick an island on the map) puts away what you built on the island you leave, reloads the scene and rebuilds the world for the destination; saves remember the island. Requests from another island keep their progress but don't point the compass while you're away.
- **Location packs:** a new location can live in its own folders (`godot/data/locations/<id>/`, `godot/scripts/locations/<id>.gd`), merged into the shared lists at load, with its own ground shape, buildings, scenery and `look`. Checked by unit tests and a throwaway pack rendered in the game; no real pack exists yet. The setting is moving to late-1990s north-west Italy: see `docs/WORLD.md` and `docs/MONTEFORCHETTA.md`.
- **Clockwork Cove** (hidden from the map; tests reach it directly): formerly reached by the ferry once Hearthglow's dock was rebuilt; now only through a test-only route. A round island with a bay, the cape lighthouse, the Old Clock Tower beside a millrace, Gearspring Hill and a small village square. Three villagers: Barnaby Sprocket (clockmaker, Tilly's uncle), Juniper Flint (lighthouse keeper) and Hazel Rivet (smith, with a shop). Requests: meet the neighbours; light the lighthouse (gather, then a windmill on the cape powering the tower's drive; the beam sweeps the bay at night); the stopped clock (gather, hand Barnaby parts, then a waterwheel in the millrace driving the clock); fuel Hazel's forge. Houses you can walk into, and a guest house to rest and change in.
- **Machine targets** are data (`machines` in a layout): a cell that wants power or water. Hearthglow's fountain inlet, the lighthouse and the clock all use the same rule.

## What's in Monteforchetta / Hearthglow (and shared systems)
Internal ids are the old ones (`fern` is Gigia, `bram` Elio, `tilly` Fede, `mabel` Ornella, `captain` Aldo, `percival` the Sindaco).
- **World:** the hilltop from one shared heightfield; village with the castle town hall, church, houses, Elio's shop, bakery, newsstand, the Cauda farm, dry fountain, the stream cutting off Gigia's groves, spring and mill channel, quarry, woods, the belvedere with the bus turnaround; vineyard slopes and a hills-and-Alps horizon; instanced trees, flowers, grass; ambient animals.
- **Time and weather:** the day is split into dawn, morning, afternoon, evening and night, each with its own music and a sky that changes gradually; sunny, cloudy and rainy spells.
- **Rooms you can walk into:** every house and shop and the castle: the bakery (Ornella bakes behind her counter), Gigia's house, the newsstand, Aldo's cottage and the castle's hall (the Sindaco's desk-throne, and your camp bed and wardrobe). The Old Gatehouse is empty (someone could want help furnishing it) and Bram's workshop is his request. Inside, the roof fades (in both renderers: the compatibility renderer used to keep a roof's plain parts solid, which hid Elio's shop while you furnished it) and the camera looks down over the walls; villagers walk in to work and sleep. Rooms, furniture and routes are data (`interior` blocks in `layout.json`).
- **Character:** original chibi apprentice and seven villagers with expressive faces (blink, moods, talking), procedural walk/idle/actions; character creator with five distinct dot-eye styles and mouths, wardrobe with outfits that unlock in play.
- **Story start:** an arrival card sets the scene (the new Geometra, appointed by the province, steps off Aldo's stranded bus at the lay-by by the village gate). The Sindaco runs the town hall from the castle.
- **Guided first day:** a skippable walkthrough led by the Sindaco, one step at a time (walk, look, talk, chop, bag, lost thing, return, journal, meet Aldo, gather for the crossing, build it, add railings). HUD parts appear as they're introduced; one-time tip cards explain talking, chopping, mining, fishing, building, the approval rating, the journal and the map (`godot/data/tutorial.json`).
- **Requests that take a while:** requests come in steps (stages): gather materials first, then build, then finishing touches; the tracker and journal show "Step 2 of 3" and only the current step. Step types: gather, events, live build checks, room checklists, piece counts in a zone, paying a villager, talking to someone mid-request. Examples: the washed-out road (10 wood, build the crossing, 4 railings), Elio's shop (wood, metal and copper wire, hear his plan, then two seats, two lamps, two shelves, a workbench and a splash of colour), your own home (pay the Sindaco 100,000 lire for the deed, rebuild the farmhouse, make it cosy), the fountain and the city bus turnaround (materials first). 12 requests, 6 of them main story.
- **Time of day matters (outside Monteforchetta):** a few requests are only offered at certain hours (Hazel's forge in the morning on the Cove, and some in the later places); outside those hours the villager says when to come back, and the journal lists the hours. Monteforchetta's work day has none (stage 2 above). The lighthouse ends by watching its first night beam with Juniper after 8 PM.
- **Sleep or nap until you choose:** beds (the Cove's guest house, your own house; the castle's camp bed no longer, see stage 2) and benches (five in Monteforchetta, four on the Cove, plus any bench or sofa you build) open a small panel: in Monteforchetta, sleep until tomorrow or a nap within the day; elsewhere dawn, morning, noon, evening or night. A bench can also just be sat on. **Bench naps:** you wake up on the bench (a step gets you up), and about a third of the time to a joke: the local paper (the *Eco del Colle*) you slept under blows away, a stranger's wet umbrella was left open to dry beside you, or a villager caught staring hurries off; if it rained while you slept, you're always soaked (drips, a puddle, a wet-dog shake). Odds and lines are data (`godot/data/naps.json`); never the same joke twice running. **Beds are dear:** a bed costs 120,000 lire as well as its wood and fabric (more than the farmhouse deed), so you save up for the one your home needs, and nap on benches meanwhile. Villagers wake up where their routine puts them; if that's right where you are (or where a loaded save put you), you step aside instead of being stuck inside them.
- **Minigames in the world:** chopping, mining and fishing play in a small panel at the bottom right while the camera watches your character work from the side; the tree or rock shakes and chips fly with each hit.
- **Coins, shops and gifts:** coins come from requests, chests, digging and selling. Elio, Gigia, Fede, Ornella and Aldo run shops (choose "🛍" in conversation): sell them what they want, buy materials, blueprints and Ornella's treats (`godot/data/shops.json`). Give any villager one gift a day; things they love and treats raise friendship more, and friendship unlocks their own gifts.
- **Following the story:** the next main-story request is always shown, so side requests never hide it; the compass points at the next step (the nearest place to gather an item, or the person to talk to or pay).
- **Build mode (the Geometra's kit):** 46 pieces in four categories; zone grids; green/red ghost with plain-language reasons, glowing spots where the piece in hand fits, and drafts (blue) for what you can't build yet; snapping; rotate, move, remove (refund), recolour; undo/redo; stacking, stairs, doors, paintings, roofs on walls; bridges that really carry you; machines simulated (waterwheel/windmill → shafts/gears/levers → pump → pipes → fountain, spark lamps). The checklist on the right shows the request's current step. When you leave build mode standing on the site (or stuck in what you built), you step off to the nearest free spot outside it.
- **Unstuck:** Menu → 🆘 I'm stuck takes you back to the castle steps (the layout's `safeSpot`).
- **Gathering:** chop and mine minigames (fishing exists but Monteforchetta has no spots); clay, flowers, chestnuts, hazelnuts, porcini; chests; metal-detector digging; lost things; copper wire from the street bins; garden beds that grow over time; the bakery boars.
- **Progression:** the Sindaco's approval rating with milestones; journal, bag, progress screen, world map (other islands locked; the ferry sails to a "next chapter" preview), notice board.
- **Saves and settings:** three slots plus autosave; volume, camera sensitivity, invert Y, weather and outline toggles, fullscreen, key remapping; gamepad for movement, camera and menus.
- **Look and sound:** ink outlines, surface textures, rounded fonts, soft lighting with SSAO and glow (Forward+), original procedural music and sound effects. A location can bring its own tunes for each part of the day, its own sky, haze, water colour, hoarfrost and sun height (`look`), and its own clothes (variants of the wardrobe's shapes in its colours); Casalrana uses all of them (see `godot/README.md`).

## How it was checked
- `godot/run_tests.sh`: 87 headless tests (it also compiles every playthrough script) of the rules (walk physics, placement, span rule, machines, bridge path, staged quest flow, paying and talk steps, shops and gifts, conversations, schedules, clock, minigames, gardening, save round-trip, tutorial, data integrity, camera collision and the indoor camera, interiors, islands: every island a playable world, the cove's machine puzzles, travel keeping each island's pieces, no path cutting through a building).
- Scripted playthroughs with real key and mouse events, reviewed as screenshots: `play_core`, `play_build`, `play_story`, `play_dialogue`, `play_tutorial`, `play_camera`, `play_overlays`, `play_interiors` (walks into every room; Mabel at work; talking indoors), `play_shop` (buy, sell, give a gift, pay for the deed), `play_sleep` (nap on a bench, sleep in the castle's guest bed, a morning-only request), `play_cove` (catch the bus, reach Clockwork Cove by a test-only route, finish its requests with real input, come home), and the full playthrough in two parts (`play_full`, `play_full2`, which ends by paving the bus turnaround and catching the city bus to the travel map). See the latest PR description for which passed. Frames are only drawn for the screenshots and every frame is 0.1 s of game time, so Monteforchetta's whole set takes about seven minutes with `godot/play_all.sh` (four at once on four cores; part one and part two about three minutes each, the others one to two and a half) where part one alone used to need an hour. Playthroughs and screenshots are silent (the scripts start Godot with `--audio-driver Dummy` and the game mutes itself for `--autoplay` and `--shot`): since they started running faster than real time, a computer with speakers played their music many times too fast and louder, one stream per run at once. The master bus has a limiter at -1 dB, so normal play can't clip at full volume (measured in an offline mix of the game's own notes, not yet by ear or in the engine).
- Web (frozen): `npm test`, `npm run build`.
- **Not checked:** how it feels on a real monitor at full frame rate, real gamepads, sound (the test machine has no audio device), Windows/macOS, and how long the requests take a real player. Please report anything that looks or feels off.

## Not done yet
- Furnishing the Old Gatehouse as a request; more shop stock and clothes to buy.
- Remapping gamepad buttons (keys can be remapped). Gamepad build controls exist but were not tested on a real controller.
- The other three islands (Blooming Wilds, Starlight Shores, Moonveil Hollow); more requests on Clockwork Cove (the Great Engine), Acts 2–3, the central landmark, programmable mechanisms and the elevator puzzle, postgame quests.
