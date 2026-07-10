# QM5_13117 EURGBP/AUDJPY Cointegration Q02 Priority Handoff

Date: 2026-07-10

Branch: `agents/board-advisor`

## Outcome

The existing logical-basket Q02 row for `QM5_13117_eurgbp-audjpy` was
advanced in place from queue rank 472 to rank 1. Its FIFO timestamps were
preserved and no duplicate build or Q02 row was created.

- Work item: `ed75430e-2ff4-4ea1-9d50-e49a7912d323`
- Logical symbol: `QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1`
- State: `pending`, `attempt_count=0`, `claimed_by=null`
- Priority: `priority_track=true`
- Open `QM5_13117` Q02 rows: exactly one
- Duplicate work items created: zero
- Audit event: `priority_track_set`, event ID `246650`

## Selection And De-duplication

The two published strict survivors are not Q02 setup blockers:

| EA | Pair | Q02 | Current terminal frontier |
|---|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | PASS | Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | PASS | Q04 FAIL |

A filesystem comparison of approved cointegration cards against
`framework/EAs` found no approved cointegration card without an EA directory.
The mission fallback therefore applies: advance an existing forex card instead
of creating a duplicate.

`QM5_13117` is the highest-ranked strict all-sign scan row in its mechanized
lineage. The reproducible screen recorded DEV Sharpe `0.4168`, OOS net Sharpe
`0.8919`, OOS return `4.4752%`, 20 OOS state changes, fixed beta `-0.1220`, and
a 36.84-day half-life. The reputable method supplement is Ernest P. Chan,
*Quantitative Trading* (Wiley, 2009), Example 3.6 and Chapter 7.

The negative beta puts both traded legs in the same direction, while its small
absolute value concentrates package exposure in EURGBP. These remain explicit
risks; no filter, refit, banned indicator, or ML component was added.

## Structural And Risk Checks

- Host: `EURGBP.DWX`, D1.
- Traded legs: `EURGBP.DWX` and `AUDJPY.DWX`.
- Conversion/history-only symbols: `GBPUSD.DWX` and `USDJPY.DWX`.
- Basket manifest:
  `framework/EAs/QM5_13117_eurgbp-audjpy/basket_manifest.json`.
- The logical backtest setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Existing build evidence records strict compile PASS with zero errors and
  warnings, plus build-check PASS with zero failures and warnings.
- The EA remains low-frequency and structural, with no ML, banned indicator,
  grid, martingale, pyramiding, or live setfile.

## Factory State

The canonical `FACTORY_OFF.flag` was present during the handoff. The database
contained five active work items before and after the priority mutation. No
dispatcher, smoke test, manual backtest, or MT5 process was started, and the
factory-OFF state was not overridden.

Database backup before mutation:
`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_13117_priority_20260710T181923Z.sqlite`.

## Safety

No `T_Live`, AutoTrading, live/deploy manifest, portfolio gate,
`portfolio_admission`, portfolio KPI, or Q08-contribution path was touched.
Existing unrelated dirty worktree changes were left untouched.

Machine-readable evidence:
`artifacts/qm5_13117_q02_priority_20260710.json`.
