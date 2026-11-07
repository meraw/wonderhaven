# Working on Wonderhaven

The game is the Godot 4 project in `godot/` (see `godot/README.md`). The original Three.js web version (`index.html`, `src/`) is **frozen**: kept as it is, not updated. Read `docs/STATUS.md` first: what works, what was only checked technically, and what is still to do.

- Godot content lives in `godot/data/*.json` and is edited directly (quests, NPCs, pieces, layout, shops, tutorial). `npm run godot:data` would overwrite it from the frozen `src/data/` and refuses without `--force`.
- Focus on mechanics and systems that carry over to new islands; the user will rework the story and characters later.
- Islands: Hearthglow (`godot/data/layout.json`) and Clockwork Cove (`layout_clockwork.json`). Island-specific code is gated on `Data.island`; prefer layout data over code for a new island.

- Frozen web version: Three.js 0.180.0 via an import map, plain ES modules, no bundler. Node 22.
- Content is data (`godot/data/*.json`): quests, NPCs, dialogue, building pieces, resource nodes, zones, shops. Add content there, not in systems.
- Rules live in pure GDScript modules (`godot/scripts/systems/`) covered by headless tests (`godot/run_tests.sh`); world, UI and audio read from them.
- Physics and quest validation share `WalkWorld` (`godot/scripts/systems/walk.gd`): if a bridge passes validation, the player can walk across it, and vice versa.
- **Godot in a cloud session: download it, don't ask.** The user has said you may always download and run Godot without asking for permission. Cloud containers don't come with it: get the official Linux build from the godotengine/godot GitHub releases (`https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_linux.x86_64.zip`), unzip it into your scratchpad (not the repo), `chmod +x` it and pass it as `GODOT=/path/to/godot` to `run_tests.sh`, `play.sh`, `play_all.sh`, `shot.sh` and `lookdev.sh`. `xvfb-run` is already installed for playthroughs and screenshots; Forward+ screenshots also need `mesa-vulkan-drivers`, or they silently fall back to the compatibility renderer.
- **Blender** builds models from scripts (`tools/blender/`, `docs/MODELS.md`): download the 4.2 LTS Linux build from download.blender.org into your scratchpad, as with Godot. The models in `godot/assets/models/lab/` are look-dev only, not in the game yet.
- Keep previously working features working. Before every push: `godot/run_tests.sh` (and `npm test` / `npm run build`, which still cover the frozen web version); for gameplay changes also the Godot autoplays for the area you're working on only: Monteforchetta's (`godot/play_all.sh <out>` runs `play_full`, `play_full2` and the short ones at once, with a summary) when you change Monteforchetta, a location's own `play_<id>` (`godot/play_all.sh <out> play_<id>`, or `godot/play.sh`) when you change that location. Other places' playthroughs are their owners' to run; the headless tests cover shared code for everyone.
- A later location's playthrough starts as if the player had reached it, with realistic stats, and plays only that location: start it with `--island=<id>` and call `arrive_as_if_played([earlier places])` (`tests/autoplay_base.gd`, using `Progress.as_if_played`): the earlier places' main stories done, with the approval, lire, plans and clothes they gave..
- Never force-push or rewrite pushed history. Distinguish features verified in play from features only unit-tested.
- Characters, names, story, models and music are original. Keep it that way.

# ENFORCEMENT: ZERO-COMMENT RULE
- You are strictly FORBIDDEN from writing any code comments, inline remarks, or placeholders.
- Do NOT use `--`, `/* */`, `//`, or `#` inside the generated code block.
- You must write out ALL logic, queries, and loops in full. 
- Do NOT abbreviate code blocks, use ellipses (...), or leave "TODO" comments.
- If you cannot complete the code without using a comment or placeholder, fail the request and state why.
