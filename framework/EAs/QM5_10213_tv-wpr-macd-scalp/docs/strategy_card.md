---
ea_id: QM5_10213
slug: tv-wpr-macd-scalp
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/scalping]]"
  - "[[concepts/momentum-reversal]]"
indicators:
  - "[[indicators/williams-r]]"
  - "[[indicators/macd]]"
  - "[[indicators/simple-moving-average]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 320
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL/author cited; R2 mechanical W%R setup, MACD/SMA entry and MACD/time/ATR exit with ~320 trades/year/symbol; R3 indicators/OHLC testable on DWX FX/gold/index CFDs; R4 fixed non-ML one-position rules."
---

# TradingView Williams R MACD SMA Scalper

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Scalping with Williams %R, MACD, and SMA (1m)`, author handle `girishmanuja`, published 2024-08-27, https://www.tradingview.com/script/975ByLQ5-Scalping-with-Williams-R-MACD-and-SMA-1m/

## Mechanik

### Entry
Use M1 baseline only. Compute Williams %R length 140, MACD 24/52/9, and SMA(7). Activate long setup when Williams %R crosses from below -94 to above -94. Enter long when MACD histogram flips from negative to positive while the long setup is active and price is above SMA(7). Activate short setup when Williams %R crosses from above -6 to below -6. Enter short when MACD histogram flips from positive to negative while the short setup is active and price is below SMA(7).

### Exit
Exit long when MACD histogram turns negative and is below the previous histogram bar. Exit short when MACD histogram turns positive and is above the previous histogram bar. Deactivate unfilled long setup if Williams %R crosses above -40. Deactivate unfilled short setup if Williams %R crosses below -60.

### Stop Loss
Source uses indicator exits only. Add V5 emergency stop at 1.2 * ATR(14) on M1 and a 90-minute maximum holding time.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
Target symbols: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX. Trade only liquid sessions: London and New York for FX/gold, cash-session overlap for indices. Skip when spread exceeds 20% of the emergency stop.

## Concepts (was ist das fur eine Strategie)
- [[concepts/scalping]] - M1 high-cadence oscillator / momentum entries.
- [[concepts/momentum-reversal]] - Williams %R reversal trigger confirmed by MACD turn.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `girishmanuja` are cited. |
| R2 Mechanical | PASS | Source gives Williams %R activation thresholds, MACD histogram entry/exit, SMA trend confirmation, and setup deactivation rules. |
| R3 Data Available | PASS | Williams %R, MACD, SMA, ATR, and OHLC are available on DWX FX, gold, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator rules, no ML, no grid, no martingale, no pyramiding, one-position compatible. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView popular Pine strategy page.

## Verwandte Strategien
- [[strategies/QM5_10163_tv-rsi-macd-long]] - oscillator plus MACD confirmation family.
- [[strategies/QM5_10187_tv-vwap-rsi-scalp]] - intraday oscillator scalping family.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
