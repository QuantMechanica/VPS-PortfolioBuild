# QM5_10921_grimes-bearflag - Strategy Spec

**EA ID:** QM5_10921
**Slug:** grimes-bearflag
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades D1 continuation flags after a sharp momentum break. A short setup requires a recent close below the prior 20-bar close low, a lower Keltner Channel touch, a nearby 60-bar MACD-line low, then a 2-8 bar bounce that retraces no more than half of the breakdown leg. It enters short when the latest D1 close breaks below the bounce low; the long setup mirrors the same structure after an upside breakout. Positions use a flag-structure stop, close or trail at 1R, and time out after 10 D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_keltner_period | 20 | >= 1 | EMA and ATR period for the Keltner channel. |
| strategy_keltner_atr_mult | 2.25 | > 0 | ATR multiplier added to/subtracted from the EMA midline. |
| strategy_break_lookback | 20 | >= 1 | Prior closed bars used for support/resistance close break. |
| strategy_break_recent_bars | 10 | >= 1 | Maximum age of the impulse break before the trigger. |
| strategy_macd_fast | 12 | >= 1 | MACD fast EMA period. |
| strategy_macd_slow | 26 | > fast | MACD slow EMA period. |
| strategy_macd_signal | 9 | >= 1 | MACD signal period. |
| strategy_macd_extreme_lookback | 60 | >= 2 | Lookback for MACD 60-bar high/low confirmation. |
| strategy_macd_near_bars | 3 | >= 0 | Allowed bar distance between MACD extreme and impulse break. |
| strategy_bounce_min_bars | 2 | >= 1 | Minimum reluctant-bounce length. |
| strategy_bounce_max_bars | 8 | >= min | Maximum reluctant-bounce length. |
| strategy_max_retrace | 0.50 | 0.0-1.0 | Maximum allowed bounce retracement of the impulse leg. |
| strategy_reject_retrace | 0.618 | 0.0-1.0 | Explicit rejection threshold for over-deep retracements. |
| strategy_atr_period | 14 | >= 1 | ATR period for stop buffer and trailing stop. |
| strategy_stop_atr_buffer | 0.25 | >= 0 | ATR buffer beyond the bounce high/low for the stop. |
| strategy_max_stop_atr | 3.0 | > 0 | Reject entries whose stop distance exceeds this ATR multiple. |
| strategy_target_r | 1.0 | > 0 | R multiple used for the primary target decision. |
| strategy_trail_atr_mult | 2.0 | > 0 | ATR multiple for trailing after a 1R continuation close. |
| strategy_max_hold_bars | 10 | >= 1 | Maximum D1 bars held before strategy exit. |
| strategy_spread_stop_fraction | 0.10 | > 0 | Maximum spread as a fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed FX major with continuous D1 DWX history.
- GBPUSD.DWX - card-listed FX major with continuous D1 DWX history.
- XAUUSD.DWX - card-listed metal with momentum and flag behaviour.
- XTIUSD.DWX - card-listed oil CFD with trend-continuation behaviour.
- GDAXI.DWX - DAX proxy used because card-listed GER40.DWX is not present in the DWX matrix.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Up to 10 D1 bars |
| Expected drawdown profile | Fixed-risk continuation trades with stops capped at 3 ATR. |
| Regime preference | Trend continuation after volatility expansion and shallow pullback |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, "A bear flag in Treasuries: a good setup and a clean trade", 2022-01-21; "Bear flags in cryptos", 2019-10-02
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10921_grimes-bearflag.md`

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
| v1 | 2026-06-06 | Initial build from card | be29e6d7-1dec-4384-85fc-7eaf113cdb74 |
