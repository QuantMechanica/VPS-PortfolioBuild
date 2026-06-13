# QM5_10503_mql5-candlebw - Strategy Spec

**EA ID:** QM5_10503
**Slug:** `mql5-candlebw`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades CandlesticksBW color changes on closed H4 bars. The local deterministic port uses the official CandlesticksBW direction classes: bullish when both Bill Williams AO and AC rise versus the prior bar, bearish when both fall, and neutral otherwise. It opens long when the just-closed bar changes from bearish or neutral to bullish, opens short when it changes from bullish or neutral to bearish, closes on the opposite color-change signal, and closes any open position when the configured session interval ends.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_work_tf` | `PERIOD_H4` | MT5 timeframe enum | Timeframe used for CandlesticksBW AO/AC state and ATR stop calculations. |
| `strategy_ao_fast_period` | `5` | `>0` and `< strategy_ao_slow_period` | Fast median-price SMA period for the AO component. |
| `strategy_ao_slow_period` | `34` | `> strategy_ao_fast_period` | Slow median-price SMA period for the AO component. |
| `strategy_ac_smooth_period` | `5` | `>0` | SMA length applied to AO for the AC component. |
| `strategy_session_enabled` | `true` | `true/false` | Enables the card's fixed trading interval filter and end-of-session close. |
| `strategy_session_start_hour` | `0` | `0-23` | Broker-session entry window start hour. |
| `strategy_session_start_minute` | `0` | `0-59` | Broker-session entry window start minute. |
| `strategy_session_end_hour` | `23` | `0-23` | Broker-session entry window end hour; positions close outside the interval. |
| `strategy_session_end_minute` | `59` | `0-59` | Broker-session entry window end minute; default mirrors source 23:59 close behavior. |
| `strategy_atr_period` | `14` | `>0` | ATR period for the protective stop. |
| `strategy_atr_sl_mult` | `1.5` | `>0` | ATR multiplier for SL distance. |
| `strategy_take_profit_rr` | `1.5` | `>0` | Take-profit multiple of initial stop risk. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX symbol with H4 DWX data availability.
- `GBPUSD.DWX` - card-listed major FX symbol with H4 DWX data availability.
- `USDJPY.DWX` - card-listed major FX symbol with H4 DWX data availability.
- `XAUUSD.DWX` - card-listed metal symbol with H4 DWX data availability.

**Explicitly NOT for:**
- Non-DWX symbols - the build follows the DWX symbol registry and does not register broker aliases.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | H4 color-change swing; usually hours to several days, with session-end flattening if reached. |
| Expected drawdown profile | ATR-bounded single-position trend-color system with fixed 1.5R target. |
| Regime preference | Trend-color continuation / momentum expansion. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/20905`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10503_mql5-candlebw.md`

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
| v1 | 2026-06-13 | Initial build from card | 4e6207c9-4353-4be3-b706-434c5bd31698 |
