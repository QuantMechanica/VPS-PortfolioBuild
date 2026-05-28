---
ea_id: QM5_10129
slug: tv-rsi-gauss-breakout
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
source_citation: "PresentTrading, RSI + Gaussian Channel Strategy, TradingView, https://www.tradingview.com/script/oc2vZUcN-RSI-Gauss-WiP/"
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/breakout]]"
indicators:
  - "[[indicators/rsi]]"
  - "[[indicators/gaussian-channel]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX]
period: H1
expected_trade_frequency: "Filtered channel breakout with RSI confirmation; estimate 35-70 trades/year/symbol on H1."
expected_trades_per_year_per_symbol: 50
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView source URL/handle cited; R2 deterministic Gaussian channel+RSI entry/exit with ATR stop and ~50 trades/year/symbol; R3 ports to DWX FX/gold/index CFDs; R4 fixed rules, no ML/grid/martingale."
---

# TradingView RSI Gaussian Breakout

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Citation: PresentTrading, "RSI + Gaussian Channel Strategy", TradingView, 2026 access URL https://www.tradingview.com/script/oc2vZUcN-RSI-Gauss-WiP/.
- Author / handle: `PresentTrading`.
- Source location: public script page describes a Gaussian Channel with RSI entry/exit confirmation, ATR-based dynamic stop-loss, and updated momentum-velocity exit filters.

## Mechanik

### Entry
- Baseline parameters:
  - RSI length 14.
  - Gaussian Channel length 144; channel multiplier 1.414 unless Pine source exposes a different default.
  - ATR length 14 for protective stop.
- Long entry when close crosses above the Gaussian upper channel and RSI(14) > 50.
- Short entry when close crosses below the Gaussian lower channel and RSI(14) < 50.

### Exit
- Close long when close crosses back below the Gaussian midline or RSI(14) < 50.
- Close short when close crosses back above the Gaussian midline or RSI(14) > 50.
- Optional source update: if Pine source exposes a fixed momentum-slope exhaustion condition, test it as a filter variant only, not as an adaptive parameter.

### Stop Loss
- Long stop: entry price - 2.0 * ATR(14).
- Short stop: entry price + 2.0 * ATR(14).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Trade H1 primary, H4 robustness secondary.
- Skip if spread > 10% of ATR stop distance.
- Do not use any performance-adaptive threshold updates.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/breakout]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full TradingView URL plus author handle `PresentTrading`. |
| R2 Mechanical | PASS | Channel breakout, RSI confirmation, channel/RSI exits, and ATR stop are deterministic. |
| R3 DWX-testbar | PASS | OHLC-derived RSI/channel/ATR logic ports to DWX FX, gold, and index CFDs. |
| R4 No ML | PASS | Fixed indicators and fixed stop multipliers; no ML, grid, martingale, or online parameter adaptation. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10111_tv-pmax-flip]] - related trend reversal family, but this card uses a smoother Gaussian channel breakout trigger.

## Lessons Learned
- TBD during pipeline run.
