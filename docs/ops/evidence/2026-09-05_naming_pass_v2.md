# Public strategy naming pass v2 (CEO workflow) - 2026-09-05

Written 17:56Z. Ledger: `public-data/naming/strategy_names.v2.json` (schema qm.strategy-naming-ledger/v2, review_status OWNER_CEO_REVIEW_REQUIRED).

## Why

The v3.1 archive producer (7e16ba130a) named 3,338 families from a bounded mechanism vocabulary: only 187 distinct names (e.g. "Average Trend Turn" x308). The OWNER asked for sounding, unique names ("klingende Strategie-Bezeichnungen").

## Method

- Input: private join of every family to its card headline/lead or non-boilerplate SPEC section 1 (`naming_input_v2.jsonl`, 3,338 rows; text source card 1,279 / spec 2,059 / none 0).
- 17 naming agents (200 families each, advanced-gate families first) under binding rules: 2-4 word evocative English names tied to the mechanism, no Strategy/EA/Bot words, no parameters or numbers that reveal settings, no claims, distinguishing qualifiers for shared mechanisms; taglines one honest mechanical sentence (max 16 words).
- Collision pass (case-insensitive): 1 collision resolved with a market qualifier.
- Two independent critics on 60-name samples each: both ACCEPT (4 and 3 rejections); all 7 corrections applied (two tagline trims, three renames incl. "Awesome Oscillator Trend Entry" and "Euro Cross Spread", one tagline parameter leak softened).

## Counts

| Metric | Value |
|---|---:|
| Families named | 3338 |
| Distinct names | 3338 |
| Collisions resolved | 1 |
| Taglines flagged > 16 words (review_flags) | 22 |
| Provenance carried from v1 (spec sha, card revision ids) | 3,336 of 3,338 |

## Random sample of 40 (seed 11)

- **Four-Candle Color Breakout** - Places a stop order when four timeframes all print same-colored closes.  (was: Candle Continuation; Price action)
- **Butterfly Pattern Reversal** - Trades the Butterfly XABCD extension reversal at the potential reversal zone.  (was: Harmonic Swing; Price action)
- **Flag Crack Breakdown** - Trades an hourly break of a daily flag pattern in the direction of the prior trend.  (was: Trend Pullback; Pullback)
- **Energy Momentum Carry Pair** - Longs the stronger of crude and gas and shorts the weaker when momentum and carry agree.  (was: Carry Regime; Carry)
- **Failed Test Continuation** - Enters the trend after a breakout, pullback and a failed counter-trend test.  (was: Candle Continuation; Price action)
- **Triple MACD Wave** - Enters on the agreement of three progressively smoothed MACD momentum waves.  (was: Directional Momentum; Momentum)
- **Know Sure Thing Histogram** - Trades momentum turns on the histogram of Pring's composite oscillator.  (was: Market Divergence; Relative structure)
- **Fractal Level Breakout** - Breaks the latest confirmed fractal level, skipping low-volatility conditions.  (was: Price Range Break; Breakout)
- **Swing Regression Breakout** - Fits a regression line after a large swing and trades its breach.  (was: Pivot Structure Turn; Price action)
- **Engulfing Expansion Long** - Buys a bullish engulfing after three lower closes above the short average.  (was: Volatility Regime; Volatility)
- **Fixed-Volatility Trend** - Runs an EWMAC trend forecast scaled by a slow fixed volatility estimate.  (was: Directional Momentum; Momentum)
- **Stochastic Donchian Trend Break** - Combines a Stochastic pullback with a Donchian break inside an EMA trend.  (was: Channel Breakout; Breakout)
- **Gap Retracement Entry** - Enters a fair-value gap retracement after a break of structure.  (was: Opening Gap Response; Price action)
- **Gas Export Breakout** - Trades a natural gas breakout framed by structural LNG export demand.  (was: Monthly Range Compression Break; Breakout)
- **Dual Screen Stack Touch** - Buys EMA touches while both timeframes hold a contained EMA stack.  (was: Volatility Envelope; Volatility)
- **DAX Morning Breakout** - Buys a break of the four-hour high in the DAX morning window, midweek only.  (was: Price Range Break; Breakout)
- **Room To Left Pin Bar** - Trades a long-tailed pin bar with clear room to its left on the daily.  (was: Rejection Bar Turn; Price action)
- **Confluence Score Breakout** - Combines regime, higher-timeframe bias, pivots and volume into one trend-continuation score.  (was: Candle Continuation; Price action)
- **Dual SuperTrend Flip** - Enters on a fast SuperTrend flip aligned with the slow SuperTrend on M30.  (was: Directional Trend; Trend)
- **European Index Dip** - Buys European indices above the long average after three falling RSI readings.  (was: Daily Trend Pullback; Pullback)
- **Bar Streak Reverse** - Flips long or short after a run of same-direction closed bars.  (was: Price Reversal; Reversal)
- **Ehlers Decycler Trend** - Follows the low-frequency trend isolated by Ehlers' lag-reduced decycler filter.  (was: Directional Trend; Trend)
- **Weekly Know Sure Thing** - Trades weekly KST signal-line crosses in the direction of the long trend.  (was: Weekly Directional Momentum; Momentum)
- **Bullish Exhaustion Short** - Shorts after three bullish daily closes break a volatility-scaled trigger.  (was: Price Reversal; Reversal)
- **Volume Trap Reversal** - Buys a bearish trap candle followed by a fair-value gap on trap volume.  (was: Opening Gap Response; Price action)
- **Double SMA Volatility Stop** - Trades a fast-slow SMA crossover with a fixed volatility stop.  (was: Average Trend Turn; Trend)
- **Copper Weekend Premium** - Buys copper into the weekend and closes at the Monday reopen.  (was: Monday Volatility Regime; Volatility)
- **Trend Pullback To Midband** - Trades hourly pullbacks to the Bollinger mean in the direction of the long-EMA trend.  (was: Volatility Envelope; Volatility)
- **Second Pullback Continuation** - Enters on the second pullback after a strong breakout to a new extreme.  (was: Candle Continuation; Price action)
- **Cycle Trough Buy** - Buys a projected market-cycle trough counted from significant pivot lows.  (was: Pivot Structure Turn; Price action)
- **Laguerre Filter Cross** - Trades price crossing an Ehlers Laguerre filter that smooths with minimal lag.  (was: Round Level Response; Price action)
- **Gold Silver Normal-Score Reversion** - Fades the gold-silver ratio on a normal-scores rank location shift.  (was: Monthly Relative Value Reversion; Relative value)
- **Repeated Median Ratio Fade** - Fades the gold-silver ratio using a repeated-median slope across thirteen months.  (was: Pivot Structure Turn; Price action)
- **DeMark Anti-Differential Turn** - Fades a three-bar decline when a strong reversal close appears.  (was: Exhaustion Sequence; Price action)
- **Pragmatic Dual Momentum** - Holds top-momentum proxies that also stay above their long-term average, else cash.  (was: Monthly Tactical Rotation; Rotation)
- **Turtle Trend Breakout** - Buys strength on a fresh multi-week high while above a long average.  (was: Channel Breakout; Breakout)
- **Fast Cross Confirmation** - Trades a fast SMA-over-EMA cross confirmed by a stochastic or MACD cross.  (was: Directional Momentum; Momentum)
- **New High Acceptance Break** - Enters after price accepts above a freshly broken swing high on strong impulse.  (was: Candle Continuation; Price action)
- **ADX Confirmed Trend Ride** - Rides the trend when price clears two averages and ADX shows strength.  (was: Average Trend Turn; Trend)
- **Dual SuperTrend Momentum** - Enters when two SuperTrends and the MACD histogram all agree.  (was: Directional Momentum; Momentum)

## Status

Not yet published: the v3.1 archive producer still reads the v1 ledger. Next: point the producer at v2 (review flags preserved), regenerate the dry run, OWNER/CEO review of the sample, then the website v3 generation.
