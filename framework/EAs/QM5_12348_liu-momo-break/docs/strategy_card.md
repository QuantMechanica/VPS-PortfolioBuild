---
ea_id: QM5_12348
slug: liu-momo-break
type: strategy
source_id: 72f9fcfa-6c75-5544-80c4-31e15c9817ab
source_citation: "amor71/LiuAlgoTrader, examples/quickstart/momentum_long_simplified.py and tradeplan.toml, MomentumLongV3, https://github.com/amor71/LiuAlgoTrader/blob/master/examples/quickstart/momentum_long_simplified.py"
sources:
  - "[[sources/github-topic-algorithmic-trading-python]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
indicators:
  - "[[indicators/macd]]"
  - "[[indicators/rsi]]"
  - "[[indicators/atr]]"
target_symbols: [GER40.DWX, NDX.DWX, WS30.DWX, XAUUSD.DWX, EURUSD.DWX, GBPUSD.DWX]
period: M1
expected_trade_frequency: "Session opening-range breakout with MACD/RSI filters; conservative estimate 20-70 completed trades/year/symbol."
expected_trades_per_year_per_symbol: 40
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-26
strategy_type_flags: [opening-range-breakout, momentum, macd-confirmation, rsi-filter, atr-stop, long-only]
g0_approval_reasoning: "R1 single source_id with public LiuAlgoTrader files attribution; R2 fixed M1 opening-range breakout exits/stops with plausible 20-70 trades/year/symbol; R3 portable to DWX indices/metals/FX; R4 deterministic no ML and one-position-per-magic."
---

# LiuAlgoTrader Momentum Opening Breakout

## Quelle
- Source: [[sources/github-topic-algorithmic-trading-python]]
- Topic URL: https://github.com/topics/algorithmic-trading?l=python
- Repository: https://github.com/amor71/LiuAlgoTrader
- Primary file: https://github.com/amor71/LiuAlgoTrader/blob/master/examples/quickstart/momentum_long_simplified.py
- Tradeplan file: https://github.com/amor71/LiuAlgoTrader/blob/master/examples/quickstart/tradeplan.toml
- Source citation: 2026 URL https://github.com/amor71/LiuAlgoTrader/blob/master/examples/quickstart/momentum_long_simplified.py
- Author / institution: GitHub handle `amor71`.
- Source location: `MomentumLongV3`.

## Mechanik

### Entry
- Run on M1 bars during the configured schedule: start 15 minutes after session open, duration 60 minutes.
- Compute the first-15-minute opening high.
- Enter long only when current close is above that 15-minute high.
- Confirm MACD is positive, rising for the last three MACD observations, above signal by the source's 1.1 multiplier, and histogram is rising for three observations.
- Confirm intrabar momentum: if VWAP is available, require `vwap > open > previous_minute_close`; if VWAP is unavailable, require `close > open > previous_minute_close`.
- Confirm RSI(20) is below `75`.

### Exit
- Close if price reaches the source stop.
- Close if RSI(20) reaches the source sell limit (`85` during morning rush, else `79`).
- Close if price is above target and MACD is non-positive.
- Close on source bail-out logic: MACD falls below signal after favorable movement or after whipsaw recovery.
- Source partial scale-out is ported to full close for one-position-per-magic compatibility.

### Stop Loss
- Source derives `stop_price` with `find_stop`.
- P2 deterministic port: entry minus `1.5 * ATR(14)` on M1 session bars.
- Target: `entry + 3R`, matching `target_price = 3 * (close - stop) + close`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: `RISK_PERCENT = 0.25`.
- One open position per symbol/magic; no partial positions in baseline.

### Additional Filters
- Use London/US index session mapping per symbol.
- Optional P3 gate: skip if spread exceeds P2 defaults or ATR(14) is below its 120-bar median.
- Friday close flatten uses V5 framework defaults.

## Concepts
- [[concepts/opening-range-breakout]] - source buys a momentum break above the first 15-minute session high with MACD and RSI confirmation.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Source-Link | PASS | Single source_id with public GitHub topic, repository, author handle, exact strategy file, and exact tradeplan URL. |
| R2 Mechanical | PASS | Source defines fixed opening range, MACD, RSI, stop, target, and sell conditions. |
| R3 DWX-testbar | PASS | Uses M1 OHLC plus VWAP fallback; portable to DWX index, metals, and FX CFDs using close/open fallback if VWAP is unavailable. |
| R4 No ML | PASS | Deterministic fixed-rule day-trade logic; no ML, online learning, grid, martingale, or multiple positions per magic. |

## R3
Primary P2 basket: GER40.DWX, NDX.DWX, WS30.DWX, XAUUSD.DWX, EURUSD.DWX, GBPUSD.DWX. SP500.DWX is optional backtest-only. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source tradeplan schedules `MomentumLongV3` from 15 minutes after market open for 60 minutes.
- Source computes `high_15m` from the first 15 minutes after market open.
- Source requires close above the first-15-minute high before MACD/RSI confirmation.
- Source uses RSI limit `75` before entry and derives stop/target prices after confirmation.

## Parameters To Test
- Opening range: `15`, `20`, `30` minutes.
- Entry window: `45`, `60`, `90` minutes after range completion.
- RSI entry max: `70`, `75`, `80`.
- Stop: `1.0`, `1.5`, `2.0 * ATR(14)`.
- Target: `2R`, `3R`, `4R`.

## Initial Risk Profile
Intraday momentum breakout with multiple confirmations. Main risks are session mapping, gap-heavy equity assumptions, and VWAP availability; P2 should use close/open fallback and test index CFDs first.

## Pipeline-Verlauf
- G0: 2026-05-26, PENDING, drafted from `amor71/LiuAlgoTrader`.

## Lessons Learned
- TBD during pipeline run.
