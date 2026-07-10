# QM5_13106 FX Cointegration Q04 Priority Handoff

Date: 2026-07-10
Branch: `agents/board-advisor`

## Outcome

The existing unique Q04 row for `QM5_13106_aud-eurgbp-coint` was promoted to
the priority lane after its logical-basket Q02 PASS. The guarded database
mutation changed only priority and audit metadata in `payload_json`; it did not
insert a work item or launch MT5.

| Field | Value |
|---|---|
| Work item | `a33683ca-ddff-4291-93c7-df149fb5a324` |
| Logical symbol | `QM5_13106_AUDUSD_EURGBP_COINTEGRATION_D1` |
| State | `pending`, unclaimed, attempt 0 |
| Priority | `priority_track=true` |
| Open matching Q04 rows after mutation | 1 |
| Duplicate work items created | 0 |

Database backup:
`D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_13106_q04_priority_20260710T103344Z.sqlite`.

## Selection

The strict 66-pair scan's two hard qualifiers are already built and are not
Q02-blocked:

| EA | Pair | Current frontier |
|---|---|---|
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |

The positive-hedge scan frontier has no unbuilt pair. The mission fallback
therefore applies. `QM5_13106` is an already approved, non-duplicate
AUDUSD/EURGBP basket from the reproducible all-sign rerun of the same scan. Its
logical Q02 work item `78e5573f-9b83-42fc-8cbc-04125c4e42f1` passed, and its
existing Q03 row `1e2f36e1-a88c-4ee1-b23d-0b2aa2027cc6` was already
priority-pending. Promoting the separate existing Q04 row advances the same FX
candidate without duplicating either lane.

## Structural And Risk Checks

- Approved card: fixed D1 beta and z-score rules; no ML, adaptive refit, grid,
  martingale, pyramiding, or portfolio feedback.
- Traded legs: `AUDUSD.DWX` and `EURGBP.DWX`.
- Conversion/history-only dependency: `GBPUSD.DWX`.
- Basket manifest: three declared symbols; symbol-scope validation `BASKET_OK`
  with zero violations.
- Canonical logical setfile: `environment=backtest`, `risk_mode=FIXED`,
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
- Build check: PASS, zero failures, zero warnings.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260710_103304.json`.
- The build check refreshed the canonical setfile's build hash to
  `03b44c663355c447bab8916669d0fc2d51ab8be3b1d2513c447f7d6a6c037873`.

## CPU Ceiling

At the guarded mutation the farm had 7 active backtests, equal to the paced
controller's active-work-item pause threshold, and 4,427 pending rows. No
dispatch, smoke test, manual backtest, or MT5 process was started. The existing
row remains pending for a paced worker.

## Safety

No `T_Live`, AutoTrading, live/deploy manifest, portfolio gate,
`portfolio_admission`, portfolio KPI, or Q08-contribution path was touched.
Existing unrelated dirty worktree changes were left untouched.

Machine-readable evidence:
`artifacts/qm5_13106_q04_priority_20260710T103344Z.json`.
