# QM5_10435_mql5-ma-cross - Strategy Spec

**EA ID:** QM5_10435
**Slug:** `mql5-ma-cross`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-27

---

## 1. Strategy Logic

The EA trades a daily moving-average crossover. It opens long when the fast moving average crosses above the slow moving average on the last completed D1 bar and that bar closes above the fast average; it opens short on the inverse condition with the close below the fast average. The baseline uses 100/200 SMA and requires the last completed W1 close to agree with a W1 100-period moving average. Positions close on an opposite fast/slow crossover, with an optional fast-MA price-close exit disabled by default.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ma_period` | 100 | 1+ | Fast moving average period. |
| `strategy_slow_ma_period` | 200 | greater than fast period | Slow moving average period. |
| `strategy_ma_method` | `MODE_SMA` | `MODE_SMA`, `MODE_EMA`, `MODE_LWMA`, `MODE_SMMA` | Moving average method; baseline is SMA. |
| `strategy_use_htf_filter` | `true` | `true` / `false` | Require higher-timeframe close to agree with trend. |
| `strategy_htf_timeframe` | `PERIOD_W1` | MT5 timeframe enum | Higher timeframe for the trend filter. |
| `strategy_htf_ma_period` | 100 | 1+ | Higher-timeframe moving average period. |
| `strategy_min_bars` | 220 | 1+ | Minimum chart bars required before trading. |
| `strategy_atr_period` | 14 | 1+ | ATR period for stop placement. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiple used for the stop. |
| `strategy_atr_sl_cap_mult` | 4.0 | >0 | Maximum ATR multiple allowed for the stop. |
| `strategy_use_fast_ma_exit` | `false` | `true` / `false` | Optional exit on close through the fast MA. |
| `strategy_take_profit_pips` | 0 | 0+ | Fixed pip take-profit; 0 disables baseline TP. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with DWX D1 OHLC coverage.
- `GBPUSD.DWX` - card-listed FX major with DWX D1 OHLC coverage.
- `USDJPY.DWX` - card-listed FX major with DWX D1 OHLC coverage.
- `NDX.DWX` - card-listed liquid index CFD with DWX D1 OHLC coverage.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no registered DWX data target.
- Single stocks and sector ETFs - not part of the approved R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `W1` close versus `W1` MA(100) when `strategy_use_htf_filter=true` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 8 |
| Typical hold time | Multi-day to multi-week trend holds |
| Expected drawdown profile | Trend-following whipsaws during sideways regimes |
| Regime preference | Trend |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/70916`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10435_mql5-ma-cross.md`

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
| v1 | 2026-05-27 | Initial build from card | 3c287bb8-8c51-4148-a276-1b5a8a3f0dd9 |
