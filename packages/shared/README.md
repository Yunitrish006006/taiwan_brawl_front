# Shared Dart packages

Reusable Taiwan Brawl packages are kept under the frontend repository so a CI
checkout has the complete local package graph without adding repositories.

- `taiwan_brawl_core`: platform-neutral runtime configuration.
- `taiwan_brawl_messaging`: transport-neutral events, identity/storage ports,
  projections, synchronization, and messaging primitives.

Each directory is an independent Dart package with its own `pubspec.yaml`,
public `lib/` entrypoint, and tests. Keep Flutter, platform adapters, secrets,
provider tokens, and game-specific behavior out of these packages. The
frontend app references them with relative path dependencies; other projects
can consume the packages by checking out this repository and using the
corresponding package path.
