# Production Web frontend release — 2026-11-09

The user authorized updating the production website to the current frontend
containing the couple-days feature.

- Website: https://taiwan-brawl-api.yunitrish0419.workers.dev
- Application source: `dfb95c46d1f397a68ab21aef66f6c4ace3f948d3`
- App version: `0.132.0`
- Build: Flutter Web release, production API URL, `PREVIEW_MODE=false`.
- Offline shell version: `be125cd884daff10969e`.
- `main.dart.js` SHA-256:
  `2cedda51fe920ee0498552a61222982a95bdd1b48c1a341a64922442811fa64c`.
- Target: the existing `STATIC_ASSETS` KV binding; 119 frontend files plus
  10 routing aliases (129 keys total).
- Public release marker: `/frontend-release.json` records the source commit,
  build timestamp, main bundle hash and offline shell version.

The source revision passed all 21 jobs in
[frontend CI](https://github.com/Yunitrish006006/taiwan_brawl_front/actions/runs/42563530156).
The production release build and four offline-shell tests passed locally.
The previous publicly served assets were backed up before uploading. No Worker
code deployment, D1 migration, production database split or backend feature-flag
change was performed.

## Scope of the couple feature

The frontend includes the couple entry, invitations, anniversary date and day
count UI. The production `/api/couples/overview` endpoint returned HTTP 404 at
release time. Production binding and synchronization require a separate backend
release and its database prerequisites; this frontend publication does not
establish that the online couple flow is usable. Existing preview test accounts
and local preview state were not migrated to production.

Browser visual acceptance was not performed: the connected browser host was
unavailable. File integrity and HTTP checks are recorded separately below.

## Final production verification

At `2026-11-09T09:06:20.872Z`, all 129 publicly served keys matched the local
release bytes by SHA-256. Both `/` and `/login` returned HTTP 200 with the exact
new `index.html`; `/api/health` returned `ok: true`. The live release marker,
main bundle and offline shell matched the release identifiers above.
The couple overview endpoint continued to return HTTP 404, as expected for the
unchanged production backend.

The existing KV asset handler maps unknown extensions to `<path>/index.html`.
Initial verification exposed this for binary shaders, NOTICES and symbol files.
The upload generator now retains original keys and adds the exact mapped keys,
allowing the current production handler to return the original bytes. This
avoids changing the running Worker or its database configuration. The handler's
existing MIME inference remains in effect.

The upload generator correction is
[backend commit 31702e2](https://github.com/Yunitrish006006/taiwan_brawl_back/commit/31702e2).
Its regression tests exercise the actual KV handler with binary shader data;
all 209 backend Node tests passed. The original failed HTTP comparisons were
rechecked after uploading the aliases and all passed.
