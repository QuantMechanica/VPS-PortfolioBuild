---
ea_id: QM5_10075
slug: gh-santi-pa2
type: strategy
source_id: 3b3ec48a-0755-5187-9331-afb36e174175
sources:
  - "[[sources/github-mql5-stars-20]]"
concepts:
  - "[[concepts/price-action]]"
  - "[[concepts/reversal-breakout]]"
indicators:
  - "[[indicators/candlestick-pattern]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 40
last_updated: 2026-05-19
g0_approval_reasoning: "R1 linked GitHub source/author; R2 mechanical two-bar trigger plus profit/time exit with ~40 trades/year/symbol; R3 OHLC price action testable on DWX; R4 fixed rules no ML/grid/martingale one-position."
---

# GitHub Santiago Two Bar Price Action Reversal

## Quelle
- Source: [[sources/github-mql5-stars-20]]
- Page / Timestamp: `santiago-cruzlopez/MQL5`, `1_Expert_Advisors_EA/018_Price_Action_EA.mq5`, https://github.com/santiago-cruzlopez/MQL5/blob/master/1_Expert_Advisors_EA/018_Price_Action_EA.mq5
- Source-code author/institution: Santiago Cruz / AlgoNet Inc., https://www.mql5.com/en/users/algo-trader/
- Source citation URL 2026: https://github.com/santiago-cruzlopez/MQL5/blob/master/1_Expert_Advisors_EA/018_Price_Action_EA.mq5
- Target symbols: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX.

## Mechanik

### Entry
- Source comment specifies daily timeframe; V5 can test D1 first, then lower timeframes only as separate parameter variants.
- On each new bar, inspect the last closed candle and the candle before it.
- Bearish-extension reversal setup: if the last closed candle is bearish and closes below the prior candle low, set a buy trigger at that closed candle high.
- Bullish-extension reversal setup: if the last closed candle is bullish and closes above the prior candle high, set a sell trigger at that closed candle low.
- During the following bar, enter market buy if ask reaches the buy trigger; enter market sell if bid reaches the sell trigger.
- After entry, clear both trigger prices. V5 constraint: one active position per symbol/magic.

### Exit
- At the first new bar after entry, close if the position is currently profitable.
- If no profitable bar-close exit occurs, close after 10 bars in the market.

### Stop Loss
- Source does not attach a hard SL.
- For V5 build, add framework protective stop default for baseline safety while preserving source profit-or-time exit as primary close logic.

### Position Sizing
- Source default volume: fixed lot 0.01.
- V5 baseline: fixed risk $1,000 for P2.

### Zusatzliche Filter
- Trade only when the symbol trading session is open.
- Optional spread/session/news filters may be added by V5 framework defaults.

## Concepts (was ist das fur eine Strategie)
- [[concepts/price-action]] - primary
- [[concepts/reversal-breakout]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full GitHub file URL and named source-code author/institution are cited. |
| R2 Mechanical | PASS | Two-bar pattern, trigger prices, profit exit, and 10-bar time exit are deterministic. |
| R3 Data Available | PASS | Uses OHLC and session-open data available on DWX symbols. |
| R4 ML Forbidden | PASS | Fixed rule set with no ML, martingale, grid, or adaptive parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10077_gh-kai-setup91]] - related pending-order price action, but this card trades counter to the extension candle.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
