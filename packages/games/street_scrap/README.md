# Street Scrap game package

This package owns Street Scrap's executable module, save/content contracts,
authoring inputs, design documents, and versioned downloadable payloads.

- `design/` contains the machine-readable item dictionary and recipe policy.
- `docs/` contains the game-specific design plan, taskbook, material catalog,
  art direction, and completion audit.
- `resources/data/` contains compiler-generated aggregate and chapter payloads.
- `resources/art/` contains versioned presentation payloads.
- `lib/` and `test/` contain the module implementation and owner tests.
- `tool/` contains the game-specific design audit, content compiler, simulator,
  and their Node owner tests.

The game-specific [design plan](docs/third-game-design-plan.md),
[material catalog](docs/third-game-material-catalog.md),
[implementation taskbook](docs/third-game-implementation-taskbook.md),
[completion audit](docs/third-game-design-completion-audit.md), and
[art direction](docs/third-game-art-direction.md) are owned here as well.

The coordination repository provides cross-game contracts, invokes these owner
tools as part of its workspace test suite, and performs cross-repository
release orchestration. It is not the source of Street Scrap game data. From the
workspace root, run:

```bash
cd taiwan_brawl_front/packages/games/street_scrap
npm run design:audit
npm run content:check
npm run test:tools
flutter analyze
flutter test
```

Compiled data is versioned by the owning resource manifest; editing design
inputs does not silently change an existing installed payload version.
The downloadable payloads under `resources/data/` are intentionally excluded
from Flutter's bundled asset list; the catalog installer provides them as
player-selected resources.
