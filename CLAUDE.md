# Working on Wonderhaven

Read `docs/STATUS.md` first: what works, what was only checked technically, and what is still to do.

- Three.js 0.180.0 via an import map, plain ES modules, no bundler. Node 22.
- Content is data (`src/data/`): quests, NPCs, dialogue, building pieces, resource nodes, zones. Add content there, not in systems.
- Rules live in pure modules (`src/systems/`) with no DOM or WebGL, so `node --test` covers them. Rendering (`src/world/`, `src/build/`), UI (`src/ui/`) and audio (`src/audio/`) read from them.
- Physics and quest validation share `src/systems/walk.js`: if a bridge passes validation, the player can walk across it, and vice versa.
- Keep previously working features working. Before every push: `npm test` and `npm run build`; for gameplay changes also `npm run e2e` (Playwright playthrough, screenshots in `e2e-output/`).
- Never force-push or rewrite pushed history. Distinguish features verified in play from features only unit-tested.
- Characters, names, story, models and music are original. Keep it that way.
