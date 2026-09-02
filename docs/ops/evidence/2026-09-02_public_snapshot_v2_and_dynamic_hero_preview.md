# Public snapshot v2 and dynamic hero — local preview only

**Router task:** `7d291110-ac8c-4de3-88f7-ae05cded6082`  
**Prepared:** 2026-09-02 15:10–15:17Z  
**Publication state:** local only; no commit/push in the deploy repository, no
Netlify hook, no deploy

## Result

The producer now emits a breaking `public-snapshot` v2 rather than widening the
frozen v1 schema:

- top-level `phase` is the exact Qxx token (`Q14` in the preview);
- the legacy `t6` object is absent;
- the P-keyed `pipeline.by_phase` compatibility view is absent;
- `pipeline.by_gate_v4` is the only public funnel;
- `pipeline.work_items_total` is derived by the pipeline-state producer from a
  read-only SQLite connection; and
- a separate `stats.json` sidecar exposes only four aggregate website counters:
  strategies, cards, work items/backtests, and the 18 Q gates. Its schema rejects
  infrastructure/live-account fields such as `terminals`.

The local deploy preview changes `Website/index.html` so every hero counter has
a neutral zero fallback and a `data-stat` binding. The former terminal-count KPI
is replaced by `strategy_cards`; no new VPS, terminal, account, credential or
live-state detail is published. `Website/scripts/stats-loader.js` reads the
generated public stats sidecar with the old frozen file as fallback.

## Generated preview

Source pipeline-state snapshot was read-only and carried:

- `eas_registered_count=4799`
- `strategy_cards_count=3953`
- `work_items_total=122248`

Exporter output is under `D:\QM\exports\public_v2_task72_20260902\`:

- `public-snapshot.json` SHA-256
  `219d9a4523788941d29356e0b572bed974cf0debf8679d4f2847636c76a9f0c6`
- `stats.json` SHA-256
  `1fadd9e41e5a983e315f702ffc309acec0c145c3b51f1aa16f2c9ea1132c2278`

Direct readback confirmed snapshot schema 2, `phase=Q14`, no `t6`, public
pipeline keys `eas_built/work_items_total/by_gate_v4/strategy_cards`, and stats
values 4799 / 3953 / 122248 / 18.

The same generated JSON was written into the **uncommitted local preview** at
`C:\QM\deploy\quantmechanica-ops\Website\public-data\`. No Git or network
publication step ran.

## Verification

- Focused Python suite: `71 passed, 1 skipped` (the skip is the optional Python
  `jsonschema` package; PowerShell schema validation below is authoritative).
- `scripts/validate_public_snapshot.ps1` under Windows PowerShell relaunches
  PowerShell 7 when `Test-Json` is unavailable. Against the preview directory:
  `PASS public-snapshot`, `process-roadmap`, `strategy-archive`,
  `company-operating-model`, and `public-stats`, including all negative fixtures.
- `tools/serve_local_website.py --check` served the local site on loopback and
  returned HTTP 200 for `/`, `/scripts/stats-loader.js`,
  `/public-data/stats.json`, and `/public-data/public-snapshot.json`.
- PowerShell AST parse, Python compile, and `git diff --check` passed.

## Publication boundary

The deploy repository remains dirty only as a local preview. It was not
committed or pushed. `netlify.toml` is unchanged, no build hook was invoked, and
no public URL was touched. Publication remains gated on the separate publisher
task and explicit OWNER go.
