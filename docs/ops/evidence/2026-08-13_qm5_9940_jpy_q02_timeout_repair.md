# QM5_9940 JPY-cross Q02 timeout repair

Date: 2026-08-13
Branch: `agents/board-advisor`
EA: `QM5_9940_ff-ha-ma-fractal-h1`
Scope: one approved diverse-sleeve Q02 infrastructure repair; enqueue deferred at the factory CPU ceiling

## Selection and claim

No unfinished approved build task was claimable, so this unit used the mission's
second priority: repair a built forex sleeve blocked at Q02 by infrastructure.

- Approved card:
  `D:\QM\strategy_farm\artifacts\cards_approved\QM5_9940_ff-ha-ma-fractal-h1.md`
- Card state: `g0_status: APPROVED`; R1-R4 all PASS.
- Source ID: `6e967762-b26d-59a3-b076-35c17f2e7c36`.
- Reputable source: gftcfd, "Heiken-Ashi System + Moving Average +
  Fractals," ForexFactory, 2012.
- Mechanics: deterministic H1 Heiken-Ashi/LWMA/fractal stop entries, one
  position, no ML, grid, martingale, or pyramiding; expected frequency about
  70 trades/year/symbol.
- Diversity target: `EURJPY.DWX` canary, with `GBPJPY.DWX` retained as the
  second approved JPY-cross candidate.

The distinct farm claim was created before editing:

- Agent task: `13ab8cfc-8ba7-413b-baa4-70ffd4374162`
- Type/state at claim: `ops_issue` / `IN_PROGRESS`
- Assigned agent: `codex:agents/board-advisor`
- Claim backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_9940_perf_claim_20260813T043748Z.sqlite`
- EURJPY predecessor: `aebeeafb-3d68-43fd-b350-c92cd3baca91`
- GBPJPY predecessor: `4003e1f9-c0b6-4cec-83d3-bc1f6b3b7740`

There was no open work item or competing repair claim for this EA.

## Diagnosis and repair

The latest EURJPY Q02 evidence is retained at:

`D:\QM\reports\work_items\aebeeafb-3d68-43fd-b350-c92cd3baca91\QM5_9940\20260807_062121\summary.json`

It ended `INFRA_FAIL` with `TIMEOUT`, `METATESTER_HUNG`, and
`INCOMPLETE_RUNS` after the history-warmup retries had progressed beyond the
earlier zero-bars condition. The source exposed a deterministic tester hot
path: open-position and pending-order management called the Heiken-Ashi color
helper on every modeled tick, and each call recursively reconstructed about
100 H1 states through pooled `CopyBuffer` reads.

The repair preserves all card mechanics and parameter defaults:

- Heiken-Ashi open/close states for shifts 1-3 are computed once per latest
  completed H1 bar and cached.
- Repeated calls on the same bar are O(1), while a failed reconstruction stays
  fail-closed for that bar.
- Pending-order management now checks that an owned pending order exists before
  requesting the cached color.
- Position exit logic still checks ownership before reading Heiken-Ashi state.
- A focused source-contract test guards the closed-bar cache and exposure-first
  ordering.

The governed build check refreshed only the existing `build_hash` comments in
the five backtest presets. Strategy inputs were unchanged. Every preset retains
`RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Verification

- Focused regression: PASS, 2 tests.
  - Command: `python -m pytest -q framework/EAs/QM5_9940_ff-ha-ma-fractal-h1/docs/test_ha_cache_contract.py`
- Strict compile: PASS, 0 errors, 0 warnings.
  - Log:
    `C:\QM\repo\framework\build\compile\20260813_044009\QM5_9940_ff-ha-ma-fractal-h1.compile.log`
  - Log SHA-256:
    `1ef485f16245e8df18f9a48f36ef2aaff4f053caaeef82179c835a4f6cbffc2e`
- EA-scoped build check: PASS, 0 failures, 0 warnings.
  - Report: `D:\QM\reports\framework\21\build_check_20260813_044058.json`
  - Report SHA-256:
    `d2c3962606dc5d5d14f23b30b897e82ab4523cbfdb3a27d0b11e2b680633b3e8`
- MQ5 SHA-256:
  `30de5f2384ab81c8680cdd0f976354cb54f37b270e50538a694475f3bba98293`
- EX5 SHA-256:
  `6e5e7a6920506153a96c0467de8db25554bdf2835a98678fcd21df8763e35d32`
- EURJPY setfile SHA-256:
  `c56e449b4b02b99480b9c396e2aeb076fb00779eea1f20ac31d0f16f22e5d104`
- GBPJPY setfile SHA-256:
  `f384b524406a6e51b5239bc4974a53915ac071be2e6fe974bcc809e7aafe4ab`
- `git diff --check`: PASS.

No manual smoke test or backtest was started.

## Capacity stop and handoff

The binding pre-enqueue check hit the backtest CPU ceiling:

- CPU samples: 100.0%, 98.6%, 97.3%.
- Executing governed factory terminals: five (`T2`, `T3`, `T4`, `T5`, `T7`).
- Active work items: five.
- `T_Live` and non-factory terminals were excluded and untouched.

Per the paced-fleet stop condition, no Q02 row was inserted, no dispatch/pump
was called, and no terminal or tester process was started. The next operator
should recheck capacity and, only when below the ceiling, use the public
append-only repaired-INFRA path to create exactly one `EURJPY.DWX` Q02 canary
from predecessor `aebeeafb-3d68-43fd-b350-c92cd3baca91`, binding the EX5 and
EURJPY setfile hashes above. Do not enqueue GBPJPY concurrently with the canary.

## Safety

- No `T_Live` file, terminal, deploy manifest, or AutoTrading state was touched.
- No live setfile or deployment artifact was created or edited.
- No portfolio gate, Q08 contribution, or portfolio KPI artifact was changed.
- Existing unrelated worktree changes were preserved and excluded.
