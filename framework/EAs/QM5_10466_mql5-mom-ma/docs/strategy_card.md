---
ea_id: QM5_10466
slug: mql5-mom-ma
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/momentum]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/momentum]]"
  - "[[indicators/moving-average]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; MQL5 CodeBase URL with named author `Vladimir Karputov` and publish date provide full lineage."
r2_mechanical: PASS
r2_reasoning: "Momentum line cross of MA-smoothed line with level-100 filter, fixed TP/SL, and opposite-signal close are deterministic."
r3_data_available: PASS
r3_reasoning: "Momentum and moving averages use OHLC history available on DWX symbols (EURUSD, GBPUSD, XAUUSD)."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed Momentum/MA parameters with no ML, online adaptation, martingale, or grid; V5 enforces one position per magic."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 50
target_symbols:
  - EURUSD.DWX
  - GBPUSD.DWX
  - XAUUSD.DWX
last_updated: 2026-05-22
card_body_incomplete: true
card_body_missing: "target_symbols"
g0_approval_reasoning: "R1 PASS MQL5 CodeBase URL; R2 PASS mechanical momentum/MA cross with exits and ~50 trades/year/symbol; R3 PASS OHLC indicators portable to DWX; R4 PASS no ML/grid/martingale."
---

# MQL5 MA On Momentum Level Cross

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Page / Timestamp: MQL5 CodeBase, "MA on Momentum Min Profit - expert for MetaTrader 5", author Vladimir Karputov, published 2022-04-28, https://www.mql5.com/en/code/39175

## Mechanik

### Entry
- Baseline symbols: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, plus liquid DWX index CFD variants.
- Timeframe: H1 baseline; M30/H4 variants can be swept.
- Use the custom MA on Momentum indicator, which plots Momentum and a moving-average-smoothed Momentum line.
- Long setup:
  - Momentum line crosses above its MA-smoothed line.
  - The cross occurs below the level 100.
  - Enter long at market on the next bar.
- Short setup:
  - Momentum line crosses below its MA-smoothed line.
  - The cross occurs above the level 100.
  - Enter short at market on the next bar.

### Exit
- Source closes through take profit in points or stop loss in money, with no trailing.
- V5 baseline uses fixed TP = 2R.
- Close early on opposite qualifying momentum cross.

### Stop Loss
- V5 baseline: SL = 1.5 x ATR(14), replacing source money-denominated SL for cross-symbol backtest consistency.

### Position Sizing
- V5 baseline: fixed-risk $1,000 per backtest trade.
- Live sizing deferred to V5 risk conventions.

### Zusätzliche Filter
- One market entry per bar, matching source behavior.
- One-position-per-magic.
- V5 default spread guard.

## Concepts (was ist das für eine Strategie)
- [[concepts/momentum]] - primary
- [[concepts/mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable MQL5 CodeBase page with title, named author, publish date, and URL. |
| R2 Mechanical | PASS | Source defines line-cross direction, level-100 filter, TP/SL behavior, and one-entry-per-bar mechanics. |
| R3 Data Available | PASS | Momentum and moving averages use OHLC history available on DWX symbols. |
| R4 ML Forbidden | PASS | No ML, no online adaptation, no martingale/grid; V5 enforces one position per magic. |

## Pipeline-Verlauf
- G0: Pending batch review.

## Verwandte Strategien
- [[strategies/QM5_10460_mql5-cci-macd]] - prior oscillator/momentum cross card.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Research note: expected cadence is conservative for H1 momentum/MA crosses.*
