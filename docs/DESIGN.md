# Wonderhaven: game design

Agreed with the user on 2026-11-07, after a review of how the game plays. It replaces the Hearthglow-era notes.
Monteforchetta is built first, as the model the later places follow; everything here is meant to carry over to them.
The setting, cast and story are in `docs/WORLD.md` and `docs/MONTEFORCHETTA.md`.

## What was wrong
The game had a life sim's systems (a clock, gathering, shops, gifts, crops) attached to a building game, and neither
half was finished. Building, the core of the game, was the rarest, most gated and least explained thing you did: six of
Monteforchetta's twelve requests had a building step, each on a site the request opened, each with a ghost plan to
follow. Most of the time went on walking and gathering for requests. Days were short, started and ended on their own
and meant nothing. The gathering minigames never changed. Free building was allowed but ignored.

The inspiration is the user's own love of MySims Kingdom: a resident gives you a spot and a few things a build must
have, the design is yours, and the payoff is seeing it used. The structure is what's taken, not the content.

## The core loop
See a need in the village → design something, your way → the village uses it and judges it → the village comes alive,
and new pieces and needs appear.

Days, gathering, money and requests serve that loop.

## 1. Free building that the game values
- **Needs you can see in the world.** Villagers' routines pass hangouts (the bus stop, the piazza, the church steps,
  the bakery door, the belvedere: spots in the layout, each about 4 m across) where they want something: a seat,
  shelter, light after dusk, green, a counter to sell from. An unmet need shows there (Ornella waiting at the bus stop
  in the rain). Anything you build there that provides it counts, however it looks.
- **Pieces carry tags** for what they provide (a bench, chair or sofa is a seat; a roof is shelter; a lit lamp is light;
  a flower bed, hedge or tree is green; a counter is a stall). A need is met when a tagged piece stands in the hangout
  and you can walk to it (the same `WalkWorld` check as bridges).
- **At most three needs open at a time**, only for pieces you can already build, and nothing bad happens if you leave
  one.
- **Villagers use what you build** in their free time: they sit on your bench, stand under your roof, set out wares on
  your counter. A villager who can't use something (a seat with no clear front, a bench on a roof) stops and gives it
  a puzzled stare instead. That changes nothing in the rules; it makes the wonky builds read as jokes.
- **Approval is what the village has right now**: needs met, charm, and commissions done (those are permanent).
  Removing a piece lowers it; a milestone you've reached is never taken back. A "Why?" panel lists every point, and a
  draft previews the change before you build it.
- **Charm** counts the variety of pieces and colours in each hangout, less for repeats: the first of a piece counts in
  full, the second half, the third nothing. It's feedback (comments, more people around), never lire per piece.
- **Liveliness**: each hangout has a level from 0 to 3 from its needs and charm, and more villagers spend their free
  time at livelier ones. At piazza level 3 people gather in the evening with music; later a market day comes every
  fifth day, with sellers at the stalls you built.
- **Tastes**: villagers like certain pieces and colours; building them near their homes earns hearts and a comment.

## 2. Commissions: briefs with checks
Requests that build become commissions:
- a **site**, or "anywhere in the village";
- **2 or 3 musts** that check function: reachable from the road, four seats, lit at night, covered from rain, water
  reaches the trough, visible from the piazza;
- **0 to 3 wishes**, optional, from whoever has a say: the Sindaco wants it taller than the bell tower, Gigia wants it
  all in wood, the province wants a fire exit on every floor.

Anything that meets the musts passes. Wishes earn a better stamp on the permit and a bonus. Pleasing everyone at once is
what makes the comic abomination (a wooden tower with a staircase to nowhere and a fire exit onto the roof), and it
passes: wonkiness is the joke, not a fault. Checks tick live while you build and highlight the piece that meets them.
No more than three musts, one new kind of check per commission, and wishes may clash in taste but can always be met
together. Many checks already exist: walkable paths, room checklists, water and power reaching a target, line of sight.

## 3. Building you can understand (the most important part)
Building had about a dozen invisible rules (sites opening one request at a time, tile and edge pieces, the 2-tile
plank reach, water, what rests on what, roofs and paintings needing walls, the half grid, the height limit, no building
inside houses, mechanisms needing neighbours), and each fix added explanation on top instead of taking a rule away.
The rule now: fewer rules, and the ones left are shown before you click.
- **The spots where the piece in your hand can go glow.** With a plank in hand you see how far it reaches.
- **Drafts.** A piece you can't build yet (you're short of materials, it rests on drafted pieces, someone is standing
  there, or you switched on "draft only") goes down as a draft: a see-through piece that costs nothing and blocks
  nothing. Build the draft when you're ready; the build screen and the request tracker list what you're short of, so
  gathering has a purpose you chose.
- **Fewer kinds of rule**: one grid (no half grid), edge pieces turn to the nearest edge by themselves, and sites are
  open from the start (your own plot still needs its deed).
- **The clock stops in build mode**, as in The Sims.
- **Teach through commissions**, one new piece or rule at a time. Ghost plans stay as an optional example, and a plan
  can be copied into your draft in one go.

## 4. The work day
- **The day runs from 7 AM to dusk**, about 13 real minutes of daylight. The clock stops in build mode, and nothing
  important depends on the hour.
- **At 8:30 PM the clock holds** at dusk, lamps on, until you end the day.
- **A place opts in** with a `day` block in its map entry (`{"holdAt": 20.5, "regrow": "overnight"}`, `WorkDay`).
  Monteforchetta has one; Boccapioppo, Casalrana and Toriano keep the clock they had until their owners convert them,
  because some of their requests happen at night.
- **You end the day by sleeping, and until you own a bed that means a bench.** Sleeping on a bench is the way every
  day ends until you've saved for a bed (beds cost 120,000 lire), so the nap gags are the everyday humiliation of a
  Geometra the village hasn't housed yet, not a joke you might never see: a night on a bench always ends with one.
  The Sindaco's camp bed in the castle sends you to the public benches. Naps during the day still skip ahead, but only
  within the same day.
- **Evening: the inauguration** of what you finished that day. Villagers gather at it, the Sindaco makes a speech taking
  the credit, people react to it, approval is counted. It is short, always skippable, happens only when something new
  was finished, and changes with what you built. Villagers are placed around the build behind a camera cut rather than
  walking there.
- **Morning: the Eco del Colle** reports on yesterday's build with a headline and a grade, and lists up to three new
  things noticed. Overnight trees and rocks grow back, crops grow, deliveries arrive, and the daily limits reset.

## 5. Gathering that feeds building
- Tool upgrades unlock new materials, and new materials unlock new building: a better axe fells the big oaks for beams
  (planks reach further), a chisel dresses stone for arches.
- Each tool level makes its minigame faster and its yield bigger; a run of perfect swings gives a bonus.
- Lire can buy materials, so a player who only wants to build can.

## Build order
Each stage is playable and tested before the next.
1. **Building you can understand**: glowing spots, drafts with a shopping list, the clock stopping in build mode, fewer
   rules. *Done: see `docs/STATUS.md`.*
2. **The work day**: dusk holds, sleeping (on a bench until you have a bed) ends the day, overnight regrowth, the
   morning paper, naps within a day. *Done for Monteforchetta: see `docs/STATUS.md`.*
3. **Needs and live approval**, with the "Why?" panel; no villagers using things yet. *Done for Monteforchetta: see
   `docs/STATUS.md`.*
4. **Villagers using your builds** (and their puzzled stares), and liveliness. *Done for Monteforchetta, apart from the
   market day and the evening music: see `docs/STATUS.md`.*
5. **The inauguration.** *Done for Monteforchetta: see `docs/STATUS.md`.*
6. **Requests rebuilt as commissions** (Monteforchetta's playthrough scripts are rewritten here).
7. **Tools and materials.**

## Kept from before
Construction checks look at what you built, not one layout: any continuous, supported walkable path counts as a
bridge; any room with the listed pieces counts as furnished; any connected wheel → power → pump → pipe chain that
delivers water counts. Physics and these checks share `WalkWorld`, so what passes is what you can walk on.
