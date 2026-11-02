# Working on Wonderhaven

Two versions share one set of content: the Godot 4 game in `godot/` (the user's chosen engine; see `godot/README.md`) and the original Three.js web version (`index.html`, `src/`). Read `docs/STATUS.md` first: what works, what was only checked technically, and what is still to do.

- Three.js 0.180.0 via an import map, plain ES modules, no bundler. Node 22.
- Content is data (`src/data/`, exported to `godot/data/*.json` with `npm run godot:data`): quests, NPCs, dialogue, building pieces, resource nodes, zones. Add content there, not in systems.
- Rules live in pure modules (`src/systems/`) with no DOM or WebGL, so `node --test` covers them. Rendering (`src/world/`, `src/build/`), UI (`src/ui/`) and audio (`src/audio/`) read from them.
- Physics and quest validation share `src/systems/walk.js`: if a bridge passes validation, the player can walk across it, and vice versa.
- Keep previously working features working. Before every push: `npm test`, `npm run build` and `godot/run_tests.sh`; for gameplay changes also `npm run e2e` (Playwright playthrough, screenshots in `e2e-output/`).
- Never force-push or rewrite pushed history. Distinguish features verified in play from features only unit-tested.
- Characters, names, story, models and music are original. Keep it that way.
