# QM5_9725_ff-roadmap-tl-retest-m5 - Strategy Spec

**EA ID:** QM5_9725
**Slug:** ff-roadmap-tl-retest-m5
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see ForexFactory Roadmap source)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades completed M5-bar Roadmap break-and-retest setups during the London and early New York window. For a long setup it finds the two most recent descending 2-left/2-right swing highs in the last 48 M5 bars, waits for a close above that bearish counter-trendline, then waits up to six bars for a bullish retest near the broken line and above EMA(8, close). The short setup mirrors this with ascending swing lows, a close below the line, and a bearish retest. The trade is filtered by daily open, SMA(200), RSI(14), spread-to-ATR, and compressed-triangle rejection; exits use the nearest ADR/prior-session/1.8R target, a close back through the broken line, or a 24-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_signal_tf | PERIOD_M5 | M1-H1 practical | Base timeframe for Roadmap signal evaluation. |
| strategy_ema_period | 8 | >=1 | Roadmap EMA close period used on the retest bar. |
| strategy_sma_period | 200 | >=20 | Trend context SMA period. |
| strategy_rsi_period | 14 | >=2 | RSI period for alternate trend context confirmation. |
| strategy_atr_period | 14 | >=2 | ATR period for retest tolerance, spread filter, and stop bounds. |
| strategy_trendline_lookback_bars | 48 | >=12 | M5 bars scanned for counter-trendline swing anchors. |
| strategy_fractal_left_right | 2 | >=2 | Bars on each side required for a swing high or swing low. |
| strategy_min_anchor_gap_bars | 8 | >=1 | Minimum bars between the two trendline anchors. |
| strategy_retest_window_bars | 6 | >=1 | Bars allowed after breakout for a retest entry. |
| strategy_retest_atr_mult | 0.20 | >0 | Maximum distance from broken line as a fraction of ATR. |
| strategy_sl_atr_buffer | 0.25 | >=0 | ATR buffer beyond the retest swing for the stop. |
| strategy_stop_min_atr | 0.60 | >0 | Minimum initial stop distance in ATR. |
| strategy_stop_max_atr | 2.00 | >minimum | Maximum initial stop distance in ATR. |
| strategy_tp_r_multiple | 1.80 | >0 | R-multiple target when ADR/prior-session level is farther away. |
| strategy_adr_days | 14 | >=1 | Days used for average daily range. |
| strategy_prior_session_bars | 72 | >=1 | Bounded M5 proxy for prior-session high and low. |
| strategy_session_start_hour | 7 | 0-23 | Broker-hour start of allowed London/early NY entry window. |
| strategy_session_end_hour | 17 | 0-23 | Broker-hour end of allowed London/early NY entry window. |
| strategy_max_spread_atr_pct | 12.0 | >=0 | Blocks entries when spread exceeds this percent of ATR. |
| strategy_triangle_width_atr_mult | 0.45 | >0 | Width threshold for compressed triangle side-door rejection. |
| strategy_triangle_apex_bars | 8 | >=1 | Future bars to apex that trigger compressed-triangle rejection. |
| strategy_time_stop_bars | 24 | >=1 | Maximum hold in M5 bars before strategy exit. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid FX Roadmap market with native DWX M5 data.
- GBPUSD.DWX - card-listed liquid FX Roadmap market with native DWX M5 data.
- XAUUSD.DWX - card-listed metal Roadmap market with native DWX M5 data.
- NDX.DWX - card-listed index Roadmap market with native DWX M5 data.

**Explicitly NOT for:**
- SP500.DWX - not listed in the card's R3 basket.
- WS30.DWX - not listed in the card's R3 basket.
- Non-DWX symbols - outside the broker/custom-symbol matrix used by the pipeline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | D1 daily open and ADR levels |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Up to 24 M5 bars, roughly 2 hours maximum |
| Expected drawdown profile | Intraday fixed-risk losses bounded by retest-swing ATR stops |
| Regime preference | Intraday momentum after trendline break and retest |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/993524-roadmap-a-way-to-read-markets
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9725_ff-roadmap-tl-retest-m5.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | b0024543-cd02-4abe-bdd8-16f6d80f8ab5 |
