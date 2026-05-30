---
ea_id: QM5_10381
slug: et-macd-pos
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "SPM Boot Camp contributor, SPM Boot Camp page 9, Elite Trader, 2008-10-21, https://www.elitetrader.com/et/threads/spm-boot-camp.141888/page-9"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/macd-momentum]]"
  - "[[concepts/intraday-momentum]]"
  - "[[concepts/session-flat]]"
indicators: [MACD]
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX, GER40.DWX]
period: M5
expected_trade_frequency: "MACD signal-line crosses during regular session; conservative estimate 80 trades/year/symbol after filters."
expected_trades_per_year_per_symbol: 80
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 source URL/attribution present; R2 mechanical MACD entry/stop/target/session exit with ~80 trades/year/symbol; R3 testable on SP500.DWX plus index CFD fallbacks; R4 fixed-rule no ML/grid/martingale."
---

# Elite Trader MACD Positive Cross

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/spm-boot-camp.141888/page-9
- Author / handle: visible SPM Boot Camp contributor; later replies by `jack hershey`.
- Date: 2008-10-21.
- Location: page 9, post #83. The post provides EasyLanguage for MACD entries, stop/target exits, and market-on-close exits.

## Mechanik

### Entry
- Run on M5 regular-session index data.
- Compute `MACD(close, 12, 26)` and `MACDAvg = EMA(MACD, 9)`.
- Long entry: during 09:30-16:00, `MACD` crosses above `MACDAvg`, and both `MACD` and `MACDAvg` are above zero.
- Short entry: during 09:30-16:00, `MACD` crosses below `MACDAvg`, and both `MACD` and `MACDAvg` are below zero.
- V5 ablation: test `MACD(5,13,6)` because a later reply argues for the faster setting on 5-minute charts.

### Exit
- Apply fixed stop and fixed profit target after at least one bar in trade.
- Exit all open positions after 16:05 or at framework session close.

### Stop Loss
- Source code defaults: `Stop$ = 600`, `Profit$ = 400`.
- V5 port: convert to price distance by symbol point value; ATR ablation uses `1.0 * ATR(20, M5)` stop and `0.67 * ATR` target.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Ignore entries outside regular-session window.
- No entry on the final 30 minutes of the session.
- One active position per symbol/magic.

## Concepts
- [[concepts/macd-momentum]] - trade signal-line crosses only when MACD is on the same side of zero.
- [[concepts/intraday-momentum]] - source applies the rule to ES intraday data.
- [[concepts/session-flat]] - source exits at the end of the trading day.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL and visible thread/page attribution. |
| R2 Mechanical | PASS | Code gives indicator settings, entry conditions, stop/target, and MOC exit. |
| R3 DWX-testbar | PASS | Index momentum rule is testable on SP500.DWX and live DWX index CFDs. |
| R4 No ML | PASS | Fixed MACD parameters; no ML, adaptive online learning, grid, martingale, or pyramiding. |

## R3
Primary P2 basket: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GER40.DWX`.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- The source post says the example is a day-trading system using MOC exit, stop loss, and profit target.
- A later reply says the 5-minute chart should use tuned MACD `5 13 6`; the card treats that as an ablation, not adaptive live tuning.

## Parameters To Test
- MACD settings: 12/26/9, 5/13/6.
- Stop/target: source 600/400 dollars, 1.0/0.67 ATR, 1.5/1.0 ATR.
- Entry cutoff: 15:00, 15:30, 16:00.
- Long-only, short-only, both directions.

## Initial Risk Profile
Medium-cadence intraday momentum system. Main risk is indicator whipsaw and overfit MACD tuning; parameters must stay fixed per backtest run.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.
