---
ea_id: QM5_10350
slug: et-sp-adx15
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "acrary, SP trend following System, Elite Trader, 2002-10-14, https://www.elitetrader.com/et/threads/sp-trend-following-system.9828/"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/price-channel-breakout]]"
  - "[[concepts/adx-filter]]"
  - "[[concepts/index-trend-following]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/adx]]"
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX, GER40.DWX, STOXX50.DWX]
period: M30
expected_trade_frequency: "30-minute 15-bar breakout gated by ADX<25; conservative estimate 75 trades/year/symbol after session and one-position filters."
expected_trades_per_year_per_symbol: 75
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 source URL present; R2 mechanical ADX/channel entry/exit with 75 trades/year/symbol estimate; R3 SP500.DWX backtest plus NDX/WS30 live-caveat testable; R4 fixed-rule no ML/grid/martingale."
---

# Elite Trader SP ADX 15-Bar Breakout

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/sp-trend-following-system.9828/
- Author / handle: `acrary`.
- Date: 2002-10-14.
- Location: post #1. The post gives the market, timeframe, ADX gate, 15-bar channel entries, 5-bar channel exits, and risk-per-trade premise.

## Mechanik

### Entry
- Evaluate completed M30 bars.
- Compute ADX(14) on M30.
- Only initiate new trades when ADX(14) < 25.
- Long stop entry when price breaks above the highest high of the previous 15 completed bars.
- Short stop entry when price breaks below the lowest low of the previous 15 completed bars.
- Enter one position per symbol/magic only.

### Exit
- Exit long when price breaks below the lowest low of the previous 5 completed bars.
- Exit short when price breaks above the highest high of the previous 5 completed bars.
- Protective stop at the same 5-bar opposite channel until the channel exit updates.
- Friday close enforced by framework.

### Stop Loss
- Channel stop from the 5-bar opposite extreme.
- Skip entry if the 5-bar channel stop is less than four current spreads or greater than `3.0 * ATR(14,M30)`.

### Position Sizing
- Source risk premise: 2% portfolio risk per trade.
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Index CFD liquid-session filter only.
- Skip first M30 bar after daily market reopen.
- Skip entries when spread exceeds 2.5x rolling median spread.

## Concepts
- [[concepts/price-channel-breakout]] - 15-bar breakout entry.
- [[concepts/adx-filter]] - source starts trades only in low-ADX conditions.
- [[concepts/index-trend-following]] - source was S&P/e-mini oriented.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL plus author handle `acrary`. |
| R2 Mechanical | PASS | Timeframe, ADX filter, channel entry, channel exit, and risk premise are explicit. |
| R3 DWX-testbar | PASS | SP500.DWX is available for backtest; NDX/WS30/GER40 ports are DWX-testable. |
| R4 No ML | PASS | Fixed ADX and channel rules; no ML, adaptive parameters, grid, or martingale. |

## R3
Primary P2 basket: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GER40.DWX`, `STOXX50.DWX`.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- The source frames the system as a starting point for S&P/e-mini trend following.
- The source reports historical profitability but also cautions that the edge may fail.

## Parameters To Test
- ADX gate: 20, 25, 30.
- Entry channel: 10, 15, 20 bars.
- Exit channel: 3, 5, 8 bars.
- Period: M15, M30, H1.
- Max stop cap: 2.0, 3.0, 4.0 ATR.

## Initial Risk Profile
Breakout strategy deliberately enters when ADX is low, so false breakouts and fast reversals are the core risk.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.
