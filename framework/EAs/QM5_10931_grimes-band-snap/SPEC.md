# QM5_10931_grimes-band-snap - Strategy Spec

**EA ID:** QM5_10931
**Slug:** grimes-band-snap
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA evaluates H4 closed bars for a Keltner-channel snapback. A long setup requires the prior H4 bar to close below EMA(20) minus 2.25 ATR(20), RSI(14) on that prior bar to be at or below 30, and the newest closed bar to close back inside the lower band while the EMA slope is not strongly down. A short setup mirrors that rule above the upper band with RSI at or above 70 and a non-strong-up EMA slope. The target is the signal-bar EMA(20), the stop is placed 0.25 ATR beyond the signal bar's low or high, the stop moves to breakeven after 1R, and positions close after 8 H4 bars or an adverse close outside the same band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_timeframe | PERIOD_H4 | M1-MN1 | Timeframe used for signal, stops, and hold-bar counting. |
| strategy_ema_period | 20 | >1 | EMA period for Keltner center and target. |
| strategy_atr_period | 20 | >1 | ATR period for Keltner width and stop padding. |
| strategy_keltner_atr_mult | 2.25 | >0 | ATR multiple added to/subtracted from EMA for Keltner bands. |
| strategy_rsi_period | 14 | >1 | RSI period used on the prior closed bar. |
| strategy_rsi_long_max | 30.0 | 0-100 | Maximum prior-bar RSI for a long setup. |
| strategy_rsi_short_min | 70.0 | 0-100 | Minimum prior-bar RSI for a short setup. |
| strategy_slope_bars | 5 | >0 | EMA slope lookback in bars. |
| strategy_max_slope_atr | 0.75 | >0 | Maximum adverse EMA slope measured in ATR units. |
| strategy_stop_pad_atr | 0.25 | >=0 | ATR padding beyond signal low/high for stop placement. |
| strategy_max_stop_atr | 3.0 | >0 | Reject trades whose stop distance exceeds this ATR multiple. |
| strategy_max_hold_bars | 8 | >0 | Time exit after this many strategy-timeframe bars. |
| strategy_max_spread_stop_frac | 0.10 | >0 | Reject if spread exceeds this fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed major FX pair with full DWX availability.
- GBPUSD.DWX - card-listed major FX pair with full DWX availability.
- USDJPY.DWX - card-listed major FX pair with full DWX availability.
- XAUUSD.DWX - card-listed metal symbol with full DWX availability.
- GDAXI.DWX - available DWX DAX proxy for card-listed GER40.DWX, which is not present in the matrix.

**Explicitly NOT for:**
- GER40.DWX - card-stated DAX name is not present in `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | H4 snapback hold, capped at 8 H4 bars |
| Expected drawdown profile | Mean-reversion losses cluster during sustained slide-along-band regimes |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, "Technicals for everyone: overbought / oversold", 2014-11-18, cited in `D:\QM\strategy_farm\artifacts\cards_approved\QM5_10931_grimes-band-snap.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10931_grimes-band-snap.md`

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
| v1 | 2026-06-06 | Initial build from card | a8b1495c-ba63-4bd1-ab29-d7f13389674b |
