---
ea_id: QM5_10492
slug: mql5-daydream
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Scriptor idea, Vladimir Karputov (barabashkakvn) code, Daydream, MQL5 CodeBase, published 2018-10-25, https://www.mql5.com/en/code/22021"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/channel-reversal]]"
  - "[[concepts/price-channel]]"
indicators: [Price Channel]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "Price-channel overshoot reversal on H1; one-position-per-symbol cap + 48-bar time-stop bound realized frequency. Smoke evidence 2024: USDJPY 9 trades/yr, EURUSD 6 trades/yr; realistic estimate ~8 trades/year/symbol (card_overclaim correction 2026-06-16, was 60)."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 source URL present; R2 mechanical channel overshoot entry and bounded exits with ~60 trades/year/symbol; R3 portable to DWX OHLC symbols; R4 fixed non-ML one-position rules."
---

# MQL5 Daydream Price Channel Reversal

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Scriptor idea, Vladimir Karputov (barabashkakvn) code, "Daydream", MQL5 CodeBase, published 2018-10-25, URL https://www.mql5.com/en/code/22021.
- Source location: page states the EA searches the minimum and maximum price over `Channel bars` starting with bar #1; if Close of bar #0 is below the minimum it opens buy, and if Close of bar #0 exceeds the maximum it opens sell. Take profit is virtual and closes at market.

## Mechanik

### Entry
- On each new bar, compute the minimum low and maximum high over `channel_bars`, starting with completed bar #1.
- Long:
  - Close[0] is below the channel minimum.
  - No active position for this symbol/magic.
- Short:
  - Close[0] is above the channel maximum.
  - No active position for this symbol/magic.
- Baseline `channel_bars` = 20, swept in P3.

### Exit
- Virtual TP from source mapped to fixed broker-side TP baseline = 1.5R.
- Protective SL baseline = 1.0 * ATR(14) beyond the breakout close, because the edge is mean reversion.
- Close on opposite channel overshoot signal.
- Time stop after 48 H1 bars.

### Stop Loss
- ATR stop, normalized by symbol tick size and broker stop level.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Skip high-impact news windows when QM news filter is active.
- Minimum ATR floor to avoid tiny-channel signals in dead markets.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL with title, idea author, code author, and publish date. |
| R2 Mechanical | PASS | Source gives explicit channel-min/channel-max reversal entries. |
| R3 DWX-testbar | PASS | Channel high/low and close-price logic are directly testable on DWX OHLC data. |
| R4 No ML | PASS | No ML, no grid/martingale, no adaptive volume; V5 enforces one position. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10456_mql5-donchian]] - channel breakout family; this card reverses channel overshoots.

## Lessons Learned
- TBD during pipeline run.
