# QM5_10253_tv-ifvg-sweep - Strategy Spec

**EA ID:** QM5_10253
**Slug:** `tv-ifvg-sweep`
**Source:** `c84ae47e-8ea0-56f1-8b25-4436b6dda5b5` (see `strategy-seeds/sources/c84ae47e-8ea0-56f1-8b25-4436b6dda5b5/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades only on M15 bars during the London-open and NY-open broker-hour windows. A long setup requires H4 EMA(13) > EMA(21) > EMA(34), H1 close above EMA(21), H1 EMA(13) > EMA(21), an M15 sell-side sweep of the prior 20-bar low, and a displacement candle whose body is at least 1.0 ATR(14). After a bullish three-bar imbalance forms with the latest closed M15 low above the high two bars earlier, the EA stores that IFVG zone and enters long on the first later closed-bar retest into it. Shorts mirror the same rules using bearish EMA bias, buy-side sweep, bearish IFVG, a stop above the sweep high, a fixed 2R target, and a 32 M15-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_execution_tf` | `PERIOD_M15` | M15 expected | Execution timeframe from the card. |
| `strategy_fast_ema` | 13 | 1-200 | Fast EMA for H4 bias and H1 continuation. |
| `strategy_mid_ema` | 21 | 1-200 | Middle EMA for H4 bias and H1 continuation. |
| `strategy_slow_ema` | 34 | 1-300 | Slow EMA for H4 bias. |
| `strategy_sweep_lookback` | 20 | 3-100 | Prior M15 high/low window used for liquidity sweeps. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for displacement and stop offset. |
| `strategy_displacement_atr_mult` | 1.0 | 0.1-5.0 | Minimum displacement body as a multiple of ATR(14). |
| `strategy_sl_atr_mult` | 0.25 | 0.01-2.0 | Stop offset beyond the sweep high/low. |
| `strategy_tp_r_multiple` | 2.0 | 0.5-10.0 | Fixed target in R multiples. |
| `strategy_max_hold_bars` | 32 | 1-500 | Time stop in M15 bars. |
| `strategy_london_start_hour` | 8 | 0-23 | Broker-hour start of London-open trade window. |
| `strategy_london_end_hour` | 11 | 0-24 | Broker-hour end of London-open trade window. |
| `strategy_ny_start_hour` | 14 | 0-23 | Broker-hour start of NY-open trade window. |
| `strategy_ny_end_hour` | 17 | 0-24 | Broker-hour end of NY-open trade window. |
| `strategy_max_spread_points` | 0 | 0-10000 | Optional spread cap; 0 disables the extra cap. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - primary card symbol and liquid volatility instrument for sweep/IFVG behavior.
- `EURUSD.DWX` - card-listed DWX FX symbol with sufficient OHLC and ATR history.
- `GBPUSD.DWX` - card-listed DWX FX symbol with sufficient OHLC and ATR history.
- `NDX.DWX` - card-listed DWX index symbol for liquid intraday continuation moves.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the build may only register broker-supported `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | H4 EMA(13/21/34), H1 close and EMA(13/21) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Up to 32 M15 bars, roughly 8 hours |
| Expected drawdown profile | Volatility-expansion continuation with fixed 2R reward/risk and one position per magic. |
| Regime preference | Volatility-expansion pullback-continuation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c84ae47e-8ea0-56f1-8b25-4436b6dda5b5`
**Source type:** TradingView public open-source script
**Pointer:** `https://www.tradingview.com/script/x6Xam693-Multicator-Sweeps-IFVG-Zone-Alerts-by-Olu777/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10253_tv-ifvg-sweep.md`

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
| v1 | 2026-06-09 | Initial build from card | 9cd0c4f3-85b8-4ab6-8435-d9f05b684143 |
