# QM5_11396 diverse-FX infrastructure rebuild and Q02 handoff

Date: 2026-08-13
Branch: `agents/board-advisor`
EA: `QM5_11396_connors-double7s-sma200-h4`
Build task: `07c901e4-0b2d-4c1e-8ca0-3e99f5dfc2b7`
Agent task: `e81897d7-7a4b-4433-9e99-9279242d341c`

## Selection and collision control

- Canonical strategy-priority rank: 18 (`score=26.15`), ahead of the next
  target-clean low-frequency FX candidate.
- Diversity: four forex majors (`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`,
  `AUDUSD.DWX`) rather than another index, metal, or energy sleeve.
- Edge: Connors/Alvarez Double 7's H4 price-extreme pullback, using only an
  SMA(200) trend regime, bounded seven-close structure, and ATR stop distance.
- Source: Larry Connors and Cesar Alvarez, *Short Term Trading Strategies That
  Work* (2009); card R1-R4 all PASS and G0 APPROVED.
- Legacy build task `2fd4f862-4bbb-4fee-90ea-e3ee4228f2d2` compiled in June but
  failed before Q02 because build validation saw unrelated duplicated
  `QM5_11558` reserved/active magic rows. No Q02 work item was ever created.
- At this rebuild, target-scoped card, EA ID, magic rows, symbols, and build
  guard all passed. Canonical `farmctl build-ea` remained globally blocked only
  by 23 pre-existing retired-XBR/active-XTI duplicate rows belonging to other
  EAs. Those rows were neither changed nor waived globally.
- A `BEGIN IMMEDIATE` transaction rechecked zero target work items, zero open
  build tasks, and zero competing agent claims before inserting this distinct
  claim:
  `manual:codex:agents/board-advisor:QM5_11396:infra-rebuild-q02-handoff:20260813T030411Z`.

Database backups:

- `D:\QM\strategy_farm\state\backups\farm_state.pre_qm5_11396_claim_20260813T030200Z.sqlite`
- `D:\QM\strategy_farm\state\backups\farm_state.pre_qm5_11396_record_build_20260813T031318Z.sqlite`

## Rebuild

- Updated the EA to the current V5 lifecycle: explicit H4/input validation,
  MAE tracking before tick guards, Friday close and structural exits independent
  of entry news/spread filters, one framework new-bar gate, and zero-initialized
  entry requests.
- Moved seven-close exit evaluation behind the H4 new-bar gate while retaining
  per-tick close retries after an exit is requested.
- Preserved the approved mechanical baseline exactly: next-bar market entry,
  seven-close extreme entry/exit, SMA(200) trend state, ATR(14) x 2 protective
  stop capped at 50 pips, no TP variant, and no ML/adaptive/banned indicator.
- Added the approved Strategy Card copy and refreshed the seven-section SPEC.
- Recompiled the tracked `.ex5` and generated four canonical H4 backtest
  setfiles. Each has `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the registered
  symbol slot (`0..3`).

## Verification

- Skill guard: PASS (EA registry row, four magic rows, and EA directory).
- SPEC validator: PASS (`1 PASS, 0 FAIL`).
- Framework build check: PASS, 0 failures; report
  `D:\QM\reports\framework\21\build_check_20260813_031005.json`.
- Compile: PASS, 0 errors, 0 warnings; summary
  `D:\QM\reports\compile\20260813_031042\summary.csv`.
- One permitted EURUSD 2024 smoke attempt was made with `-Terminal any` and
  `-SmokeMode`. Farm dispatch rejected it before terminal launch with
  `status=no_capacity`. No retry was made. `record-build` normalized this to
  `deferred_p2_smoke` with `needs_p2_smoke_via_pump=true`.
- Build result:
  `D:\QM\strategy_farm\artifacts\builds\07c901e4-0b2d-4c1e-8ca0-3e99f5dfc2b7.json`
  (`sha256=81fccf8ae40d3cdc5d7bc0df819d7073457858134106855e9f93f707a8e90ab8`).

## Q02 handoff

`farmctl record-build` completed the build task and atomically enqueued the
stage-1 Q02 cohort:

| Symbol | Work item | Status at handoff |
|---|---|---|
| `EURUSD.DWX` | `8a521922-bf9d-428b-b0ed-34dc1f594397` | `pending` |
| `GBPUSD.DWX` | `67f062c3-103a-4a46-9ceb-c8d513a78f9b` | `pending` |
| `USDJPY.DWX` | `8499d0db-1bf1-4fc7-b22f-14c54e108760` | `pending` |

`AUDUSD.DWX` is retained in the canonical priority-track deferred sidecar with
`q02_cohort_size=4`; the farm sweep will promote it when capacity allows. It was
not forced into the saturated backtest queue.

No T_Live path, AutoTrading control, portfolio gate, deploy manifest, or live
manifest was read or modified. The unrelated Brent/WTI evidence file already
present in the worktree was excluded from this commit.
