# Prompt for a session that builds one location

Copy everything in the box into a new Claude Code session on this repository. Replace `[LOCATION]` with a
location from the table in `docs/WORLD.md` and `[id]` with its working id. Start one session per location.

```text
You're building one location for Wonderhaven, a cozy building game made in Godot 4 that is being turned into a comic, late-1990s north-west Italian setting. Your location: [LOCATION]. Its working id is `[id]`.

Other Claude sessions are building other locations at the same time, and another session is turning the starting village into Monteforchetta. Stay out of each other's way.

1. Read first: CLAUDE.md, docs/WORLD.md (setting rules, the list of locations, which files are yours, and the tools for tests and screenshots), docs/MONTEFORCHETTA.md (a finished design to use as a model), docs/GRAPHICS.md, docs/STATUS.md and godot/README.md. Then look through the game's data and scripts enough to know what already exists.

2. Interview me before building anything. Ask in rounds of up to four questions, each with concrete options and your recommendation where you have one. Cover the place and the shape of its map, its landmarks, what surrounds it, the people (realistic Italian names with nicknames and job titles), their requests, what to gather and do there, how the player arrives and gets around, the look (buildings, plants, light, weather) and the sound. Keep asking until everything is settled. Then write docs/locations/[id].md and open a pull request containing only that doc.

3. Once I've approved the doc, build in stages, with one pull request per stage: ground and map; buildings and scenery; people, dialogue and requests; look and ambient life. Keep the game playable and the tests passing after every stage.

4. Work only in your location's own files, as docs/WORLD.md lists them, and prefix every id with `[id]_`. If you truly need to change a shared file, make the smallest general change, add a test, and say so at the top of the pull request. Merge main into your branch often. Never rebase or force-push.

5. Check your work before each push: godot/run_tests.sh, screenshots of your location in both renderers (--island=[id]), and a scripted playthrough of its requests. In each pull request, say what you verified in play and what you only unit-tested.
```
