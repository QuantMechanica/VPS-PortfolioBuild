# QM5_10998_the5ers-ema-cci-pullback - Strategy Spec

**EA ID:** QM5_10998
**Slug:** the5ers-ema-cci-pullback
**Source:** 1d445184-7c47-57da-9856-a123682a932d (see `sources/the5ers-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades H4 forex trend pullbacks. A long setup requires EMA20 above EMA50, a recent CCI(20) reading at or below -75, the just-closed candle touching the EMA20/50 zone, and that candle closing back above EMA20. A short setup mirrors this with EMA20 below EMA50, a recent CCI(20) reading at or above +75 within the configured pullback-state window, an EMA-zone touch, and a close back below EMA20. The stop is placed beyond the recent 5-bar swing with a 0.25 ATR buffer, profit target is the closer of 1.5R or the recent 20-bar structure target, and any remaining position is closed after 8 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_fast_period | 20 | 1+ | Fast EMA used for trend state and close-back trigger |
| strategy_ema_slow_period | 50 | 1+ | Slow EMA used with the fast EMA to form the pullback zone |
| strategy_cci_period | 20 | 1+ | CCI lookback period using typical price |
| strategy_cci_threshold | 75.0 | 0+ | Oversold/overbought CCI threshold |
| strategy_cci_state_lookback | 10 | 1+ | Closed H4 bars over which CCI pullback state may occur |
| strategy_atr_period | 14 | 1+ | ATR period for filters and stop buffer |
| strategy_sep_atr_mult | 0.25 | 0+ | Minimum EMA20/50 separation in ATR units |
| strategy_swing_lookback | 5 | 1+ | Closed bars used for swing stop placement |
| strategy_sl_atr_buffer | 0.25 | 0+ | ATR buffer beyond the swing stop |
| strategy_tp_rr | 1.5 | 0+ | R-multiple target candidate |
| strategy_struct_lookback | 20 | 1+ | Closed bars used for structure target |
| strategy_time_stop_bars | 8 | 1+ | Maximum H4 bars to hold a trade |
| strategy_vol_pctile_lookback | 120 | 1+ | Closed bars used for ATR percentile floor |
| strategy_vol_pctile | 20.0 | 0-100 | Minimum ATR percentile allowed for entry |

---

## 3. Symbol Universe

**Designed for:**
- GBPUSD.DWX - Source article uses GBP/USD H4 as the primary forex example.
- EURUSD.DWX - Major DWX forex pair matching the card's multi-major basket.
- USDJPY.DWX - Major DWX forex pair matching the card's multi-major basket.
- AUDUSD.DWX - Major DWX forex pair matching the card's multi-major basket.
- EURJPY.DWX - Major DWX forex cross matching the card's multi-major basket.

**Explicitly NOT for:**
- Non-FX symbols - the card source and R3 basket are forex-specific.

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
| Trades / year / symbol | 45 |
| Typical hold time | Up to 12 H4 bars |
| Expected drawdown profile | Moderate trend-pullback losses controlled by swing stops |
| Regime preference | Trend continuation with sufficient ATR and EMA separation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1d445184-7c47-57da-9856-a123682a932d
**Source type:** article
**Pointer:** https://the5ers.com/pullback-crossover/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10998_the5ers-ema-cci-pullback.md`

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
| v1 | 2026-06-25 | Initial build from card | d1431e9a-9bbd-43dd-bbce-8b3847414218 |
