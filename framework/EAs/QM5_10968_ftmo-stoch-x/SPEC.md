# QM5_10968_ftmo-stoch-x - Strategy Spec

**EA ID:** QM5_10968
**Slug:** ftmo-stoch-x
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades H1 stochastic extreme crossovers in the direction of the H4 trend. A long setup requires Stochastic(14,3,3) to have had both lines below 20 within the prior three H1 bars, then %K crossing above %D while leaving the oversold area, with the H1 close above the prior H1 high and H4 close above EMA(100). A short setup mirrors this from above 80, requires %K crossing below %D while leaving overbought, the H1 close below the prior H1 low, and H4 close below EMA(100). Exits are the fixed 1.8R target, stop loss, stochastic opposite crossover, framework Friday close, or a 48-H1-bar time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | H1 | Signal timeframe from the card. |
| `strategy_trend_tf` | `PERIOD_H4` | H4 | Higher timeframe for the trend filter. |
| `strategy_stoch_k` | 14 | 1-100 | Stochastic %K period. |
| `strategy_stoch_d` | 3 | 1-50 | Stochastic %D period. |
| `strategy_stoch_slowing` | 3 | 1-50 | Stochastic slowing period. |
| `strategy_oversold` | 20.0 | 0-50 | Oversold extreme threshold. |
| `strategy_overbought` | 80.0 | 50-100 | Overbought extreme threshold. |
| `strategy_long_leave_max` | 30.0 | 0-50 | Maximum stochastic value accepted as just leaving oversold. |
| `strategy_short_leave_min` | 70.0 | 50-100 | Minimum stochastic value accepted as just leaving overbought. |
| `strategy_extreme_lookback` | 3 | 1-10 | Prior H1 bars that can arm the extreme condition. |
| `strategy_trend_ema_period` | 100 | 10-300 | H4 EMA trend filter period. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for volatility and stop filters. |
| `strategy_atr_percentile_lookback` | 100 | 20-300 | Lookback bars for ATR percentile filter. |
| `strategy_atr_percentile_cutoff` | 20.0 | 0-100 | Skip entries below this ATR percentile. |
| `strategy_swing_lookback` | 8 | 2-50 | Bars used for swing high/low stop anchor. |
| `strategy_swing_atr_buffer` | 0.25 | 0-2 | ATR buffer beyond the swing stop. |
| `strategy_min_stop_atr` | 0.5 | 0.1-5 | Minimum stop distance in ATR multiples. |
| `strategy_max_stop_atr` | 3.0 | 0.5-10 | Maximum stop distance in ATR multiples. |
| `strategy_take_profit_rr` | 1.8 | 0.5-10 | Take-profit multiple of initial risk. |
| `strategy_time_exit_bars` | 48 | 1-240 | Maximum holding time in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed DWX major FX symbol with native OHLC, stochastic, EMA, and ATR support.
- `GBPUSD.DWX` - Card-listed DWX major FX symbol using the same H1/H4 oscillator trend structure.
- `USDJPY.DWX` - Card-listed DWX major FX symbol using the same H1/H4 oscillator trend structure.
- `XAUUSD.DWX` - Card-listed DWX gold symbol with liquid H1/H4 OHLC and ATR support.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research and backtest artifacts must use broker-available `.DWX` symbols.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no tick-data guarantee for P2 and later phases.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | H4 close versus EMA(100,H4) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | Up to 48 H1 bars |
| Expected drawdown profile | Moderate oscillator mean-reversion drawdown with stops bounded by 0.5-3.0 ATR. |
| Regime preference | Mean-reversion primary, momentum secondary, filtered by H4 trend. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** blog
**Pointer:** FTMO, "Technical analysis - how to use Stochastic Oscillator", 2023-04-21, https://ftmo.com/en/technical-analysis-how-to-use-stochastic-oscillator/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10968_ftmo-stoch-x.md`

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
| v1 | 2026-06-06 | Initial build from card | 928c536d-c622-4423-9a83-9167e12865e7 |
