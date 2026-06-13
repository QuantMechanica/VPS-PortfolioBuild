---
ea_id: QM5_10644
slug: qa-volz-event
type: strategy
source_id: 35e40f89-5980-5d15-8964-70f9760db187
source_citation: "Quant Arb, Event-Based Alpha: A Quick Guide, The Quant Stack / algos.org, 2024-05-31, https://www.algos.org/p/event-based-alpha-a-quick-guide and archive https://archive.ph/2026.01.06-215845/https%3A/www.algos.org/p/event-based-alpha-a-quick-guide"
sources:
  - "[[sources/quant-arb-x-substack]]"
concepts:
  - "[[concepts/event-momentum]]"
  - "[[concepts/volume-zscore]]"
  - "[[concepts/intraday-momentum]]"
indicators: [VolumeZScore, ATR]
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX, XAUUSD.DWX]
period: M1
expected_trade_frequency: "Volume-z event detection can trigger around unscheduled shocks and scheduled high-impact releases. With strict z-score and one-trade/day caps, conservative cadence is 25 trades/year/symbol."
expected_trades_per_year_per_symbol: 25
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id (35e40f89) with article URL and archive URL; Quant Arb handle and 2024-05-31 date cited."
r2_mechanical: PASS
r2_reasoning: "Mechanical: vol_z>=4.0 plus directional ATR-pct return confirmation and 5-bar breakout on M1, 1.25xATR stop, 10-bar time exit or signal-bar-failure exit; all thresholds specified."
r3_data_available: PASS
r3_reasoning: "SP500.DWX, NDX.DWX, WS30.DWX, and XAUUSD.DWX are DWX-testable; volume proxy uses native DWX tick volume which is available."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed volume-z and price thresholds, one position per magic per day, no ML or adaptive PnL-dependent parameters."
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS: source URL/archive cited; R2 PASS: fixed M1 volume-z directional entry, ATR/time exits and ~25 trades/year/symbol; R3 PASS: DWX index/commodity CFDs testable with SP500 T6 caveat; R4 PASS: fixed rules, no ML/grid/martingale, one-position."
---

# Quant Arb Volume Z-Score Event Momentum

## Quelle
- Source: [[sources/quant-arb-x-substack]]
- URL: https://www.algos.org/p/event-based-alpha-a-quick-guide
- Archive URL: https://archive.ph/2026.01.06-215845/https%3A/www.algos.org/p/event-based-alpha-a-quick-guide
- Author / handle: Quant Arb (`https://x.com/quant_arb`, Substack profile linked from article).
- Date: 2024-05-31.
- Location: sections "Data Sources", "Fun Chart Stuff", and "Spread Stuff"; the article discusses statistical event trades detected from price/volume patterns.

## Mechanik

### Entry
- Run on M1 bars.
- Compute `vol_z = (tick_volume_current - SMA(tick_volume, 60)) / StdDev(tick_volume, 60)` on completed M1 bars.
- Compute `ret_1 = close[1] / close[2] - 1`.
- Compute `atr_pct = ATR(14,M1) / close[1]`.
- Long setup:
  - `vol_z >= 4.0`.
  - `ret_1 >= 0.75 * atr_pct`.
  - Close[1] is above the high of the prior 5 completed M1 bars.
  - Spread is below `3 * median_spread_20_sessions_same_minute`.
  - Enter long at next bar open.
- Short setup:
  - `vol_z >= 4.0`.
  - `ret_1 <= -0.75 * atr_pct`.
  - Close[1] is below the low of the prior 5 completed M1 bars.
  - Spread is below `3 * median_spread_20_sessions_same_minute`.
  - Enter short at next bar open.

### Exit
- Primary time exit after 10 M1 bars.
- Early exit if a completed M1 bar closes back through the entry signal bar open.
- Exit if opposite volume-z momentum signal appears.

### Stop Loss
- Initial stop: `1.25 * ATR(14,M1)`.
- Move stop to break-even after +1R.
- No profit target in baseline; the edge hypothesis is short-lived continuation after event detection.

### Position Sizing
- P2 baseline: fixed $1,000 risk.
- One active position per symbol/magic.
- Maximum one entry per symbol per trading day.

### Zusaetzliche Filter
- Skip the first and last 10 minutes of the main index session.
- Skip if the preceding 30 M1 bars have fewer than 20 nonzero-volume bars.
- Skip if spread is unavailable or above cap.
- Optional ablation: disable entries within scheduled high-impact news windows to separate unscheduled shock momentum from calendar events.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full article URL and archive URL identify Quant Arb and date. |
| R2 Mechanical | PASS | Source proposes statistical event trading via volume and price patterns; this card formalizes fixed M1 z-score, direction, stop, and time-exit rules. |
| R3 DWX-testbar | PASS | Uses only DWX tick-volume and price bars on index/commodity CFDs; no external feed is required for the baseline. |
| R4 No ML | PASS | Fixed volume-z and price thresholds; no ML, adaptive parameters, grid, martingale, or multi-position stacking. |

## R3
Primary P2 basket: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `XAUUSD.DWX`.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- The author says event momentum can be studied by average returns after the event.
- The author suggests using volume and price patterns such as volume z-score.
- The author says "Spreads kill."

## Parameters To Test
- Volume z-score threshold: 3.0, 4.0, 5.0, 6.0.
- Volume lookback: 30, 60, 120 M1 bars.
- Return threshold: 0.50, 0.75, 1.00 ATR percentage.
- Breakout lookback: 3, 5, 10 bars.
- Stop: 1.0, 1.25, 1.5, 2.0 ATR(14,M1).
- Time exit: 5, 10, 15, 30 M1 bars.
- Daily cap: 1, 2, 3 entries/day.

## Initial Risk Profile
Short-horizon event strategy with material spread/slippage risk. Baseline avoids external event parsing but may overfit to generic volume shocks; P3/P4 should check whether gains survive strict spread filters and OOS event regimes.

## Framework Alignment
```yaml
modules_used:
  no_trade:
    used: true
    notes: "Spread cap, session-edge skip, nonzero-volume gate, daily trade cap."
  trade_entry:
    used: true
    notes: "M1 volume z-score plus directional ATR-scaled return and short breakout confirmation."
  trade_management:
    used: true
    notes: "ATR stop and break-even after +1R."
  trade_close:
    used: true
    notes: "10-bar time stop, signal-bar failure, or opposite event momentum signal."
hard_rules_at_risk:
  - scalping_p5b_latency
at_risk_explanation: |
  The strategy trades M1 event impulses and can be sensitive to spread and execution delay, so P5b latency/noise calibration is important.
```

## Pipeline-Verlauf
- G0: PENDING.

