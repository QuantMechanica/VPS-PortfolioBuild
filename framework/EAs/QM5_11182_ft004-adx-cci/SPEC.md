# QM5_11182_ft004-adx-cci - Strategy Spec

**EA ID:** QM5_11182
**Slug:** `ft004-adx-cci`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades long-only M5 reversals after a strong directional move. It enters when ADX(14) is above 50 or ADX(35) is above 26, CCI(14) is below -100, both the prior fast and slow stochastic readings are oversold, and fast stochastic crosses upward from fastK below fastD to fastK above fastD. It requires a 12-bar rolling tick-volume mean above 0.75 and a positive closed-bar close, then exits with the source ROI ladder or when ADX(35) fades below 25, stochastic is overbought, prior fastK remains below prior fastD, and close is above EMA(5). The source -10% stop is preserved as the initial stop so the V5 risk model can size the trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_adx_fast_period` | 14 | 2-100 | Fast ADX lookback for the entry trend-strength condition. |
| `strategy_adx_fast_threshold` | 50.0 | 35-60 | Minimum ADX(14) value that allows entry. |
| `strategy_adx_slow_period` | 35 | 5-100 | Slow ADX lookback for entry and exit. |
| `strategy_adx_slow_threshold` | 26.0 | 20-30 | Minimum ADX(35) value that allows entry. |
| `strategy_adx_exit_threshold` | 25.0 | 15-35 | Maximum ADX(35) value for strategy exit. |
| `strategy_cci_period` | 14 | 2-100 | CCI lookback for oversold entry. |
| `strategy_cci_entry` | -100.0 | -150--75 | Maximum CCI value for long entry. |
| `strategy_fast_stoch_k` | 5 | 2-50 | Fast stochastic K period. |
| `strategy_fast_stoch_d` | 3 | 1-20 | Fast stochastic D period. |
| `strategy_fast_stoch_slowing` | 3 | 1-20 | Fast stochastic slowing value. |
| `strategy_slow_stoch_k` | 50 | 10-100 | Slow stochastic K period. |
| `strategy_slow_stoch_d` | 3 | 1-20 | Slow stochastic D period. |
| `strategy_slow_stoch_slowing` | 3 | 1-20 | Slow stochastic slowing value. |
| `strategy_fast_stoch_oversold` | 20.0 | 10-30 | Prior fast stochastic K and D must be below this level. |
| `strategy_slow_stoch_oversold` | 30.0 | 20-40 | Prior slow stochastic K and D must be below this level. |
| `strategy_exit_stoch` | 70.0 | 60-80 | Fast stochastic overbought threshold for strategy exit. |
| `strategy_ema_exit_period` | 5 | 2-50 | EMA period used by the source exit rule. |
| `strategy_volume_mean_bars` | 12 | 2-50 | Closed bars used for the rolling tick-volume mean. |
| `strategy_min_volume_mean` | 0.75 | 0-10 | Minimum rolling tick-volume mean required for entry. |
| `strategy_min_close` | 0.00000100 | 0-0.001 | Minimum closed-bar close required by the source guard. |
| `strategy_stoploss_pct` | 10.0 | 1-20 | Source stoploss percentage below entry. |
| `strategy_roi_0_pct` | 5.0 | 0-10 | Profit target from entry until 20 minutes. |
| `strategy_roi_20_pct` | 4.0 | 0-10 | Profit target after 20 minutes. |
| `strategy_roi_30_pct` | 3.0 | 0-10 | Profit target after 30 minutes. |
| `strategy_roi_60_pct` | 1.0 | 0-10 | Profit target after 60 minutes. |
| `strategy_atr_period` | 14 | 2-100 | ATR lookback for the M5 spread guard. |
| `strategy_max_spread_atr_pct` | 15.0 | 0-100 | Maximum spread as a percentage of ATR. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX symbol from the approved P2 basket.
- `GBPUSD.DWX` - liquid major FX symbol from the approved P2 basket.
- `USDJPY.DWX` - liquid major FX symbol from the approved P2 basket.
- `XAUUSD.DWX` - liquid metals symbol from the approved P2 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - they are not valid DWX backtest targets.
- Symbols with missing tick volume - the entry rule depends on the 12-bar rolling tick-volume floor.

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
| Trades / year / symbol | 75 |
| Typical hold time | 367.3 minutes from the source README sample. |
| Expected drawdown profile | Medium risk due to M5 scalping and source -10% stop. |
| Regime preference | ADX-filtered oscillator mean reversion after oversold stochastic and CCI states. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** GitHub strategy repository
**Pointer:** Gerald Lonlas / freqtrade community, `Strategy004.py`, commit `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`, https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/Strategy004.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11182_ft004-adx-cci.md`

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
| v1 | 2026-06-07 | Initial build from card | de40d219-c4b1-40df-be69-09c632f4319a |
