---
ea_id: QM5_10093
slug: gh-ssp-breakout
type: strategy
source_id: 3b3ec48a-0755-5187-9331-afb36e174175
sources:
  - "[[sources/github-mql5-stars-20]]"
concepts:
  - "[[concepts/breakout]]"
  - "[[concepts/trend-following]]"
  - "[[concepts/momentum]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/rsi]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 120
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
card_body_incomplete: false
card_body_missing: ""
g0_approval_reasoning: "R1 source repo/files cited; R2 deterministic EMA/RSI/ATR breakout with fixed exits and ~120 trades/year/symbol; R3 testable on DWX forex/metals/indices; R4 no ML/grid/martingale and one-position-per-magic."
---

# GitHub SafeScalper EMA RSI Breakout

## Quelle
- Source: [[sources/github-mql5-stars-20]]
- Repository: https://github.com/e49nana/Algorithmic-trading
- Files:
  - https://github.com/e49nana/Algorithmic-trading/blob/main/tradfi/mql5/SafeScalperPro_v3.mq5
  - https://github.com/e49nana/Algorithmic-trading/blob/main/tradfi/mql5/SSPStrategy.mqh
- Author / institution: Algosphere Quant / e49nana
- Location: `SSPStrategy.mqh`, `CSSPStrategy::GetSignal()`
- Source citation: 2026 GitHub URL https://github.com/e49nana/Algorithmic-trading/blob/main/tradfi/mql5/SSPStrategy.mqh
- Target symbols: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, DAX.DWX, NDX.DWX.

## Mechanik

### Entry
- Run once per new bar on M5 or M15.
- Update EMA fast, EMA slow, RSI, ATR, last two closes, and N-bar high/low.
- Buy only when all conditions align:
  - EMA fast > EMA slow.
  - EMA separation is at least the configured ATR fraction.
  - Last closed bar is above both EMAs.
  - Last closed bar breaks above the lookback high with ATR buffer logic.
  - RSI is between configured buy bounds, default 40-65.
  - Last closed bar closes above the prior close.
- Sell only when all mirrored conditions align:
  - EMA fast < EMA slow.
  - EMA separation is at least the configured ATR fraction.
  - Last closed bar is below both EMAs.
  - Last closed bar breaks below the lookback low with ATR buffer logic.
  - RSI is between configured sell bounds, default 35-60.
  - Last closed bar closes below the prior close.
- Default parameters from source: EMA 50/200, RSI 14, ATR 14, breakout lookback 20, breakout buffer 0.5 ATR.
- V5 constraint: one active position per magic, matching the source `HasOpenPosition()` gate.

### Exit
- Fixed stop-loss and take-profit from inputs, default 150 points SL and 200 points TP.
- Optional breakeven: after 100 points profit, move stop to entry plus 10 points.

### Stop Loss
- Fixed point stop from source input; P3 may sweep stop and target ranges.

### Position Sizing
- Source supports fixed lot or risk percent. V5 build uses fixed $1,000 risk for P2 baseline and 0.25% percent risk live default.

### Zusätzliche Filter
- Session filter, spread filter, manual news-time filter, Friday cutoff, and max drawdown pause exist in source.
- For V5, drawdown pause is treated as a no-trade filter, not adaptive parameter tuning.

## Concepts (was ist das für eine Strategie)
- [[concepts/breakout]] - primary
- [[concepts/trend-following]] - primary
- [[concepts/momentum]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full GitHub repository and file URLs are cited; author/institution visible as Algosphere Quant / e49nana. |
| R2 Mechanical | PASS | Signal function contains explicit six-condition long/short rules plus fixed exits. |
| R3 Data Available | PASS | Uses OHLC, EMA, RSI, ATR, spread, and time filters available on DWX forex, metals, and index CFDs. |
| R4 ML Forbidden | PASS | Source states no martingale/grid/hedging and selected code uses fixed indicators with one-trade-at-a-time gating; no ML. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10094_gh-h4-zone]] - same broad source batch, but zone-retest rather than indicator breakout.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Research note: cadence estimate assumes M5/M15 breakout scans with multiple filters; 120 trades per year per symbol is conservative pending P2 data.*
