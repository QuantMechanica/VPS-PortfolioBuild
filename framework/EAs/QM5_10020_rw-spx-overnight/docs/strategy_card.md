---
ea_id: QM5_10020
slug: rw-spx-overnight
type: strategy
source_id: dcbac84f-6ecf-5d21-9630-50faa69306ec
source_citation: "Robot Wealth / Robot James, 'Overnight and Intraday SPX returns', https://robotwealth.com/overnight-and-intraday-spx-returns/"
sources:
  - "[[sources/robot-wealth-blog]]"
concepts:
  - "[[concepts/overnight-risk-premium]]"
  - "[[concepts/index-seasonality]]"
indicators:
  - "[[indicators/session-close-open]]"
  - "[[indicators/overnight-return]]"
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX]
period: D1
expected_trade_frequency: "Daily close-to-open exposure on eligible sessions, reduced by filters. Conservative estimate 180 trades/year/symbol."
expected_trades_per_year_per_symbol: 180
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL present; R2 deterministic close-to-open entry/exit with rolling filter and ~180 trades/year/symbol; R3 SP500.DWX backtest plus NDX/WS30 live caveat; R4 fixed rules no ML/martingale."
---

# Robot Wealth SPX Overnight Premium

## Quelle
- Source: [[sources/robot-wealth-blog]]
- Citation: Robot Wealth / Robot James, "Overnight and Intraday SPX returns", https://robotwealth.com/overnight-and-intraday-spx-returns/, accessed 2026-05-19.
- Source location: the article defines intraday as open-to-close and overnight as close-to-next-open, then compares long intraday vs long overnight strategies.
- Author / institution: Robot James / Robot Wealth.

## Mechanik

### Entry
- On each eligible US equity index trading day, enter long at the cash-session close proxy.
- For SP500.DWX, use the broker/session close bar closest to 16:00 New York time.
- Trade only if the prior 20-session overnight-minus-intraday average is positive.

### Exit
- Exit at the next cash-session open proxy, closest to 09:30 New York time.
- Do not hold through the regular intraday session.

### Stop Loss
- Initial SL = 1.0 * ATR(14,H1) measured at entry.
- No TP by default; time exit is primary.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Skip Friday close to Monday open in baseline to avoid weekend event risk; P3 may test including weekends separately.
- Skip if spread at entry > 20% of ATR(14,H1).
- Skip scheduled FOMC day and CPI day until P8 news-mode review.

## Concepts
- [[concepts/overnight-risk-premium]] - primary
- [[concepts/index-seasonality]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Public Robot Wealth article URL, author handle, and full rule definitions for overnight/intraday return decomposition. |
| R2 Mechanical | PASS | Entry and exit are session-close/session-open rules with a fixed rolling filter. |
| R3 DWX-testbar | PASS | SP500.DWX is available as a custom backtest symbol; NDX.DWX and WS30.DWX are live-tradable index CFDs for parallel validation. |
| R4 No ML | PASS | Fixed session and rolling-average rules; no ML, grid, martingale, or adaptive live parameters. |

## R3
Primary P2 basket: SP500.DWX, NDX.DWX, WS30.DWX.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10023_rw-eom-flow]] - both use index calendar/session flow effects.

## Lessons Learned
- TBD during pipeline run.
