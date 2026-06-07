# QM5_11187_ft-adx-stoch - Strategy Spec

**EA ID:** QM5_11187
**Slug:** `ft-adx-stoch`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades long-only M5 oversold reversals. A long entry is allowed when ADX(14) is above 50 or ADX(35) is above 26, CCI(14) is below -100, the prior fast and slow stochastic readings are oversold, and fast %K crosses above fast %D on the current closed bar. The entry also requires a positive 12-bar tick-volume mean and a valid close price. Exits occur on the source signal, on the source ROI ladder by position age, on the ATR stop, or on framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_adx_fast_period` | 14 | 2-100 | Fast ADX period used in the entry regime gate. |
| `strategy_adx_slow_period` | 35 | 2-150 | Slow ADX period used in entry and exit gates. |
| `strategy_adx_fast_min` | 50.0 | 0-100 | Minimum ADX(14) value that qualifies the high-ADX regime. |
| `strategy_adx_slow_min` | 26.0 | 0-100 | Minimum ADX(35) value that qualifies the high-ADX regime. |
| `strategy_exit_adx_slow_max` | 25.0 | 0-100 | ADX(35) ceiling for the source exit signal. |
| `strategy_cci_period` | 14 | 2-100 | CCI period for the oversold entry filter. |
| `strategy_cci_entry_max` | -100.0 | -300-0 | Maximum CCI value allowed for entry. |
| `strategy_fast_stoch_k` | 5 | 2-100 | Fast stochastic K period. |
| `strategy_fast_stoch_d` | 3 | 1-50 | Fast stochastic D period. |
| `strategy_fast_stoch_slowing` | 3 | 1-50 | Fast stochastic slowing value. |
| `strategy_slow_stoch_k` | 50 | 2-200 | Slow stochastic K period. |
| `strategy_slow_stoch_d` | 3 | 1-50 | Slow stochastic D period. |
| `strategy_slow_stoch_slowing` | 3 | 1-50 | Slow stochastic slowing value. |
| `strategy_fast_oversold` | 20.0 | 0-50 | Prior fast stochastic K and D must both be below this level. |
| `strategy_slow_oversold` | 30.0 | 0-60 | Prior slow stochastic K and D must both be below this level. |
| `strategy_fast_exit_overbought` | 70.0 | 50-100 | Fast stochastic K or D level required for source exit. |
| `strategy_ema_exit_period` | 5 | 2-100 | EMA period used by the source exit close filter. |
| `strategy_volume_mean_period` | 12 | 1-100 | Closed-bar tick-volume mean lookback. |
| `strategy_volume_mean_min` | 0.75 | 0-1000 | Minimum 12-bar mean tick volume. |
| `strategy_min_close` | 0.000001 | 0-1 | Minimum closed price required before entry. |
| `strategy_atr_stop_period` | 14 | 2-100 | ATR period used for the MT5 baseline stop. |
| `strategy_atr_stop_mult` | 2.0 | 0.1-20 | ATR multiple used for stop distance. |
| `strategy_max_spread_stop_frac` | 0.08 | 0-1 | Maximum spread as a fraction of planned stop distance. |
| `strategy_roi_0m_pct` | 5.0 | 0-100 | ROI exit threshold before 20 minutes. |
| `strategy_roi_20m_pct` | 4.0 | 0-100 | ROI exit threshold from 20 minutes. |
| `strategy_roi_30m_pct` | 3.0 | 0-100 | ROI exit threshold from 30 minutes. |
| `strategy_roi_60m_pct` | 1.0 | 0-100 | ROI exit threshold from 60 minutes. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major included in the approved R3 portable basket.
- `GBPUSD.DWX` - liquid FX major included in the approved R3 portable basket.
- `USDJPY.DWX` - liquid FX major included in the approved R3 portable basket.
- `XAUUSD.DWX` - liquid metal CFD included in the approved R3 portable basket.

**Explicitly NOT for:**
- `BTCUSD.DWX` - the source was crypto, but the approved card ports the strategy to DWX FX and metals only.
- `SP500.DWX` - not part of the approved R3 basket for this card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `160` |
| Typical hold time | `20-60 minutes from ROI ladder, longer if waiting for source exit or stop` |
| Expected drawdown profile | `Moderate mean-reversion drawdowns bounded by 2x ATR stop and fixed-risk sizing.` |
| Regime preference | `High-ADX oversold reversal / mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** `GitHub strategy source`
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/Strategy004.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11187_ft-adx-stoch.md`

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
| v1 | 2026-06-07 | Initial build from card | a02f2f53-db47-4f32-9b54-92da7359be0e |
