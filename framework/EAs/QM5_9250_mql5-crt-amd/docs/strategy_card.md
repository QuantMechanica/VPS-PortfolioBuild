---
ea_id: QM5_9250
slug: mql5-crt-amd
type: strategy
source_id: ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
source_citation: "Allan Munene Mutiiria, Automating Trading Strategies in MQL5 (Part 41): Candle Range Theory (CRT) - Accumulation, Manipulation, Distribution (AMD), MQL5 Articles, 2025-11-21, https://www.mql5.com/en/articles/20323"
sources:
  - "[[sources/mql5-articles]]"
concepts:
  - "[[concepts/liquidity-sweep]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/candle-range]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, GER40.DWX]
period: M15
expected_trade_frequency: "Medium frequency; session/range manipulation reversal should trigger roughly 40-100 trades per year per symbol"
expected_trades_per_year_per_symbol: 70
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present (ba57d97a); named MQL5 article with URL and author Allan Munene Mutiiria."
r2_mechanical: PASS
r2_reasoning: "Deterministic CRT AMD range, breach percentage, and confirmation bar rules with ATR stop; fully implementable."
r3_data_available: PASS
r3_reasoning: "EURUSD.DWX, GBPUSD.DWX, GER40.DWX are all available DWX instruments."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed price-action CRT rules, single position per magic, no ML/grid/martingale."
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS MQL5 article URL; R2 PASS mechanical CRT AMD entry/exit/stop with ~70 trades/year/symbol; R3 PASS OHLC/ATR portable to DWX FX/index CFDs; R4 PASS fixed non-ML one-position rules."
---

# MQL5 CRT AMD Reversal

## Quelle
- Source: [[sources/mql5-articles]]
- Article: "Automating Trading Strategies in MQL5 (Part 41): Candle Range Theory (CRT) - Accumulation, Manipulation, Distribution (AMD)"
- Author: Allan Munene Mutiiria
- Date: 2025-11-21
- URL: https://www.mql5.com/en/articles/20323
- Page / Timestamp: Introduction; "Understanding the Candle Range Theory (CRT) Framework"; implementation input parameters.

## Zielmärkte
- Target symbols: EURUSD.DWX, GBPUSD.DWX, GER40.DWX.

## Mechanik

### Entry
- On each new M15 bar, define an accumulation range from a higher timeframe candle or fixed lookback range. Default: previous H1 candle high/low.
- Bullish setup: the source range candle closes upward; price breaches below the range low by at least `MinManipulationDepthPct = 10%` of range height.
- Bullish confirmation: after the breach, at least `ConfirmBars = 1` closed M15 bar closes back above the range low.
- Enter long at the next bar open.
- Bearish setup: the source range candle closes downward; price breaches above the range high by at least `MinManipulationDepthPct = 10%` of range height.
- Bearish confirmation: after the breach, at least `ConfirmBars = 1` closed M15 bar closes back below the range high.
- Enter short at the next bar open.
- One position per magic number; ignore additional same-range signals after one completed trade.

### Exit
- Initial take profit at `2.0R`.
- Close if an opposite valid CRT AMD signal appears.
- Time exit after 48 M15 bars if neither stop nor target is reached.

### Stop Loss
- Long stop: breached manipulation low minus 0.25 * ATR(14).
- Short stop: breached manipulation high plus 0.25 * ATR(14).

### Position Sizing
- V5 fixed $1,000 P2 risk from stop distance; live RISK_PERCENT default after approval.

### Zusätzliche Filter
- Minimum range height: 0.5 * ATR(14); maximum range height: 2.5 * ATR(14).
- Closed-bar execution only; no forming-bar manipulation confirmations.
- V5 default spread/news filters.

## Concepts (was ist das für eine Strategie)
- [[concepts/liquidity-sweep]] - primary
- [[concepts/mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full MQL5 article URL with named author Allan Munene Mutiiria. |
| R2 Mechanical | PASS | Source gives accumulation range, manipulation breach, reversal close confirmation, stop/TP, trailing, and position-limit mechanics. |
| R3 Data Available | PASS | Uses OHLC ranges and ATR, available on DWX FX, metals, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed price-action rules; no ML, online learning, grid, martingale, or required multi-position logic. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9199_mql5-liq-ma-sweep]] - related liquidity sweep family, but this card uses CRT/AMD range phase logic.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Research note: Source supports dynamic/static SL/TP and trailing. This card pins fixed V5-compatible defaults to avoid adaptive review risk.*
