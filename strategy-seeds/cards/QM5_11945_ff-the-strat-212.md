---
ea_id: 11945
slug: ff-the-strat-212
g0_status: APPROVED
r1_track_record: price_action_legend
source_id: price_action_legend
r2_mechanical: true
r3_data_available: true
r4_ml_forbidden: true
expected_trades_per_year_per_symbol: 100
target_symbols: ["EURUSD.DWX"]
last_updated: 2026-08-21
g0_approval_reasoning: "R1 traceable (Rob Smith The Strat); R2 now closed-form (2U/2D/inside scenario inequalities, 2-1-2 on bars 3/2/1, FTFC weekly+daily, inside-bar SL, candle-3 extreme TP) via respecification; R3 EURUSD.DWX governed; R4 mechanical, 1-pos-per-magic, no ML."
expected_pf: 1.25
expected_dd_pct: 12.0
---

# FF — The Strat (2-1-2 Reversal)

Source: Rob Smith, "The Strat" methodology (lineage `price_action_legend`).
Target symbols: EURUSD.DWX

## Thesis
"The Strat" candle scenarios: Scenario 1 = inside bar; Scenario 2 = directional bar. A 2-1-2 sequence identifies a trend that consolidates then reverses.

## Candle Scenario Definitions (closed bars, on H1)
- **Scenario 2-up (`2U`):** `High[t] > High[t-1]` AND `Low[t] >= Low[t-1]`.
- **Scenario 2-down (`2D`):** `Low[t] < Low[t-1]` AND `High[t] <= High[t-1]`.
- **Scenario 1 (inside):** `High[t] <= High[t-1]` AND `Low[t] >= Low[t-1]`.

## Entry Rules (evaluated on closed H1 bars [3],[2],[1] = candles 1,2,3)
- **Bearish 2-1-2 (Short):** candle[3] is `2U`, candle[2] is Scenario 1 (inside candle[3]), candle[1] is `2D` (breaks below `Low[2]`).
- **Bullish 2-1-2 (Long):** candle[3] is `2D`, candle[2] is Scenario 1, candle[1] is `2U` (breaks above `High[2]`).
- **FTFC Filter:** trade Long only if the current Weekly and Daily bars are both bullish (`Close > Open`); Short only if both bearish. Same-color continuity.
- **Entry:** at the close of candle[1] (which has already broken the inside bar). One position per magic.

## Exit & Management
- **Stop Loss:** the opposite end of the inside bar (candle[2]) — `High[2]` for Shorts, `Low[2]` for Longs.
- **Take Profit:** the prior extreme of candle[3] (the Scenario-2 candle) — `Low[3]` for Shorts, `High[3]` for Longs.
- **Position Sizing:** RISK_FIXED (backtest) / RISK_PERCENT (live) tied to the stop distance.

## Respecification Provenance (2026-08-21)
- **Defective passage:** entry "1 pip beyond the extreme of the Inside Bar"; target "The previous high/low of the Scenario 2 candle (Candle 1) or next Broadening Formation level"; multi-timeframe "D1 for bias, H1 for entry".
- **Correction:** the Strat scenarios given explicit closed-form inequalities; the 2-1-2 sequence pinned to bars [3]/[2]/[1]; entry taken at candle[1] close (its break of the inside bar already defines the trigger); the target "or" resolved to the deterministic **candle[3] prior extreme** (dropping the discretionary Broadening-Formation branch); FTFC pinned to Weekly+Daily same-color. No new mechanics — these are Rob Smith's canonical Strat definitions.

## Edge Lab FTMO Block
- Drawdown: <=5% daily / <=10% total.
- News Blackout: Mandatory.
- Horizon: Swing / Intraday (H1).
- No Martingale/Grid/Averaging.
- Mechanical/No-ML.
