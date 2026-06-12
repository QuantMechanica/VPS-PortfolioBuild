# QM5_10326_close-auct-rev - Strategy Spec

**EA ID:** QM5_10326
**Slug:** close-auct-rev
**Source:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9 (see `artifacts/cards_approved/QM5_10326_close-auct-rev.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA waits for the M15 bar that closes the final 30 minutes of the U.S. cash session proxy. It measures the move from the start of that window to the final close, and trades the opposite direction when the move is at least 0.75 x ATR(14) / close and the two-bar tick volume is above its rolling 70th percentile. It skips the signal when the final-bar spread is above its rolling 80th percentile, then exits after four M15 bars, at a 50% retracement of the pressure move, or by the overnight time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 14 | 2-200 | ATR period used for entry threshold and stop distance. |
| strategy_pressure_atr_mult | 0.75 | 0.10-5.00 | Minimum close-window move as ATR fraction. |
| strategy_stop_atr_mult | 0.75 | 0.10-5.00 | Stop distance as ATR fraction. |
| strategy_retrace_fraction | 0.50 | 0.10-1.00 | Fraction of the pressure move that triggers early exit. |
| strategy_hold_bars | 4 | 1-96 | Maximum hold in M15 bars. |
| strategy_prior_bar_hhmm_broker | 2230 | 0000-2359 | Broker-time M15 bar that starts the final 30-minute window. |
| strategy_final_bar_hhmm_broker | 2245 | 0000-2359 | Broker-time M15 bar that completes the final 30-minute window. |
| strategy_volume_lookback_days | 60 | 20-252 | Final-window volume samples used for percentile filter. |
| strategy_volume_percentile | 70.0 | 0-100 | Required rolling tick-volume percentile. |
| strategy_spread_lookback_bars | 960 | 96-10000 | M15 spread samples used for percentile filter. |
| strategy_spread_percentile | 80.0 | 0-100 | Spread percentile above which entries are skipped. |
| strategy_min_percentile_samples | 20 | 5-252 | Minimum samples required before percentile filters are valid. |
| strategy_skip_news_days | true | true/false | Uses the framework skip-day news mode as the scheduled FOMC-day proxy. |
| strategy_skip_us_early_closes | true | true/false | Skips common U.S. cash-market early-close dates. |
| strategy_overnight_stop_hhmm | 1330 | 0000-2359 | Broker-time overnight stop if the short hold has not already closed. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 custom symbol matches the card's S&P 500 close-auction pressure proxy; backtest-only caveat applies.
- NDX.DWX - Nasdaq 100 index CFD fits the U.S. large-cap close-window pressure basket.
- WS30.DWX - Dow 30 index CFD fits the U.S. large-cap close-window pressure basket.

**Explicitly NOT for:**
- EURUSD.DWX - FX does not share the U.S. equity cash close auction structure.
- XAUUSD.DWX - Commodity spot trading does not match the card's equity-index closing auction mechanism.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | Four M15 bars, with overnight time stop as a fallback |
| Expected drawdown profile | Short-horizon mean-reversion losses when close pressure continues instead of reverting |
| Regime preference | Closing-window pressure reversal after high-volume dislocations |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
**Source type:** paper
**Pointer:** Yanbin Wu, "Closing Auction, Passive Investing, and Stock Prices", SSRN abstract 3440239, 2019
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10326_close-auct-rev.md`; note that the body table lists R3 as UNKNOWN while frontmatter records `r3_data_available: PASS`.

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
| v1 | 2026-06-12 | Initial build from card | 733854b5-e9d3-44d6-91c8-b6d83dc173a9 |
