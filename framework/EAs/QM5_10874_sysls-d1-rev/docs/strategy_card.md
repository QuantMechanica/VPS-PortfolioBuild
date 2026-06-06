---
ea_id: QM5_10874
slug: sysls-d1-rev
type: strategy
source_id: 66a6c726-c456-5899-be49-561e86612e8a
source_citation: "sysls, Your Firm Wants You Blind So You Can't Compete!, X longpost archived Dec 24 2025, https://archive.ph/2025.12.24-233512/https%3A/x.com/systematicls/status/2003486775642321172?s=12"
sources:
  - "[[sources/systematicls-x-substack]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/close-execution]]"
  - "[[concepts/execution-timing]]"
indicators:
  - "[[indicators/rate-of-change]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 40
last_updated: 2026-05-22
g0_approval_reasoning: "R1 cited archived sysls/X source; R2 deterministic close-timing D1 reversal with plausible ~40/year daily-threshold cadence; R3 portable to DWX FX/metals/oil/index CFDs; R4 fixed-rule ML-free one-position strategy."
---

# SystematicLS Same-Close D1 Reversal

## Quelle
- Source: [[sources/systematicls-x-substack]]
- Page / Timestamp: sysls / `@systematicls`, `Your Firm Wants You Blind So You Can't Compete!`, X longpost archived Dec 24 2025, https://archive.ph/2025.12.24-233512/https%3A/x.com/systematicls/status/2003486775642321172?s=12

## Mechanik

### Entry
Use intraday M15 bars to approximate same-day close execution for a D1 reversal factor.

- At 15 minutes before the symbol's configured session close, compute today's return from prior D1 close to current M15 close.
- Compute ATR(20) on D1 and normalize today's return by ATR(20) / prior close.
- If normalized day return > +0.75, enter short.
- If normalized day return < -0.75, enter long.
- Only one entry attempt per symbol per day.

### Exit
- Primary: exit at next session open plus 30 minutes.
- Alternate test: exit at next D1 close.
- Flatten immediately if opposite same-close signal occurs before scheduled exit.

### Stop Loss
- Initial stop = 0.75 * ATR(20) from entry.
- Take profit = 0.50 * ATR(20) from entry.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic.

### Zusatzliche Filter
- Trade only on symbols with stable session-close mapping.
- Skip if current D1 true range is below 0.5 * ATR(20).
- Skip if spread > 8% of stop distance.
- Skip during OWNER-provided no-trade news windows if later wired.

## Concepts (was ist das fur eine Strategie)
- [[concepts/mean-reversion]] - fades large same-day moves near the close.
- [[concepts/close-execution]] - source emphasizes that close timing materially affects the factor.
- [[concepts/execution-timing]] - the whole edge is sensitive to close-versus-next-open execution.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact archived X URL and author handle are cited. |
| R2 Mechanical | PASS | Source identifies one-day reversal and same-close execution; deterministic thresholds, stops, and exits are supplied for V5 testing. |
| R3 Data Available | PASS | Uses only OHLC and ATR on DWX FX/metals/oil/index CFDs. |
| R4 ML Forbidden | PASS | Fixed return/ATR thresholds; no ML, grid, martingale, or adaptive parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX, GER40.DWX.

If this is later tested primarily on SP500.DWX, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says a one-day reversal factor loses most of its Sharpe when execution moves from same close to next open.
- Source uses this as an example of execution timing overwhelming signal research.

## Parameters To Test
- Entry threshold: 0.50, 0.75, 1.00 * D1 ATR-normalized return.
- Entry time: close-15m, close-30m, close-60m.
- Exit: next open+30m, next close.
- Stop: 0.5, 0.75, 1.0 * ATR(20).
- Take profit: 0.35, 0.50, 0.75 * ATR(20).

## Initial Risk Profile
Medium-cadence close-timing mean-reversion card. Main risk is session-close approximation and slippage around the configured close.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from Systematic Long Short / @systematicls.

## Verwandte Strategien
- TBD

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
