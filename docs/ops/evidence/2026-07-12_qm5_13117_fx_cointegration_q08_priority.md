# QM5_13117 FX Cointegration Q08 Priority

**Date:** 2026-07-12

**Branch:** `agents/board-advisor`

**Scope:** one existing low-frequency EURGBP/AUDJPY D1 basket

## Outcome

`QM5_13117_eurgbp-audjpy` remains the sole live strict sleeve from the
sign-aware 66-pair FX cointegration frontier. Its existing Q08 work item was
priority-marked in place, moving from paced-worker claim rank 138 to rank 1.

- Work item: `d9f360d4-6fa3-47ab-bddb-6a33a616f540`.
- Logical symbol: `QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1`.
- Traded legs: `EURGBP.DWX` and `AUDJPY.DWX`.
- State after mutation: `pending`, unclaimed, attempt 0, no verdict.
- `priority_track`: `true`.
- Open Q08 rows for the logical basket: exactly one.
- New or duplicate work items created: zero.
- Audit event: `priority_track_set`, ID `246804`.

No tester was dispatched by this unit. The existing queue row will be claimed
by the paced worker fleet when factory operation resumes.

## Selection And De-duplication

The controlling research remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced with:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

The original positive-hedge scan admitted only EURJPY/GBPJPY and
AUDUSD/NZDUSD. The strict sign-aware reproduction has seven qualifying rows,
all already carded and built:

| Rank | Pair | EA | Current frontier |
|---:|---|---|---|
| 1 | GBPUSD/USDCAD | `QM5_12978` | Q04 FAIL |
| 2 | EURJPY/GBPJPY | `QM5_12533` | Q04 FAIL |
| 3 | AUDUSD/NZDUSD | `QM5_12532` | Q05 FAIL |
| 4 | USDCAD/NZDUSD | `QM5_13003` | Q04 FAIL |
| 5 | AUDUSD/EURGBP | `QM5_13106` | Q04 FAIL |
| 6 | EURGBP/AUDJPY | `QM5_13117` | Q02-Q07 PASS; Q08 pending |
| 7 | USDJPY/EURAUD | `QM5_13119` | Q04 FAIL |

Creating another card would therefore duplicate a build or weaken the fixed
research threshold. The mission fallback applies: advance the strongest
existing sleeve still alive in the funnel.

The reputable method supplement remains Ernest P. Chan, *Quantitative
Trading* (Wiley, 2009), Example 3.6 and Chapter 7. The pair's empirical screen
row records DEV net Sharpe `0.4168`, OOS net Sharpe `0.8919`, OOS return
`4.4752%`, 20 OOS state changes, fixed beta `-0.1220`, and a 36.84-day
half-life. The negative, small hedge ratio and resulting directional
concentration remain explicit risks; no refit or filter was added.

## Anchor Q02 Triage

Neither published anchor has an open ONINIT or NO_HISTORY blocker:

- `QM5_12532`: logical Q02 PASS, Q04 PASS, then genuine Q05 FAIL at PF 0.95
  over 204 trades.
- `QM5_12533`: logical Q02 PASS, then genuine Q04 FAIL at pooled PF 0.432 over
  43 trades with all folds structurally complete.

Requeueing either anchor at Q02 would be duplicate churn rather than a setup
repair.

## Queue Mutation

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`.

A consistent pre-mutation backup was written to:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_13117_q08_priority_20260712T125223Z.sqlite`

The existing pending row's payload received only queue metadata:

- `priority_track=true`
- a mission-specific `priority_reason`
- `priority_set_at_utc=2026-07-12T12:52:23+00:00`
- `priority_set_by=Codex agents/board-advisor`
- backup and no-dispatch notes

The row's `created_at` and `updated_at` timestamps were preserved. The worker's
canonical ordering now places it first because it is the only priority Q08 row;
downstream phases outrank the 134 priority Q02 rows and one priority Q07 row.

## Pipeline And Risk Evidence

`farmctl work-items --ea QM5_13117` reports Q02, Q03, Q04, Q05, Q06, and Q07
PASS plus exactly one pending Q08 successor. Canonical Q07 evidence is:

`D:/QM/reports/work_items/22eb034c-ec8f-43e5-a695-3f60e5d9e4ba/QM5_13117/Q07/QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1/aggregate.json`

The existing basket package was not changed. Its logical backtest setfile
continues to specify `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The manifest declares USD tester currency, 100,000
deposit, D1 host `EURGBP.DWX`, both traded legs, and the two conversion-history
symbols `GBPUSD.DWX` and `USDJPY.DWX`.

## Verification And Safety

- Live DB `PRAGMA quick_check`: `ok`.
- Backup DB `PRAGMA quick_check`: `ok`.
- `mt5_queue_status.py`: QM5_13117 Q08 is `queued_top[0]`, priority true, with
  no preflight failure.
- Pending count stayed 3,688; the action created no queue row.
- `FACTORY_OFF.flag` remained asserted.
- One unrelated factory tester was observed, below the seven-job CPU ceiling;
  total CPU sampled at 20.7%. This unit started none.
- No strategy source, EX5, manifest, setfile, registry, gate threshold, live
  artifact, or deploy artifact changed.
- No AutoTrading setting or `T_Live` path was touched.
- No portfolio gate, portfolio admission/KPI, or Q08-contribution path was
  touched.

Machine-readable evidence:
`artifacts/qm5_13117_q08_priority_20260712.json`.
