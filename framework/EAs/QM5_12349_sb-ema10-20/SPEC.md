# QM5_12349_sb-ema10-20 - Strategy Spec

**EA ID:** QM5_12349
**Slug:** sb-ema10-20
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA evaluates the last completed M1 bar. It buys when EMA(10) is above EMA(20) on that bar and EMA(10) was below EMA(20) for the configured prior confirmation bars. It sells when EMA(10) is below EMA(20) on the completed bar and EMA(10) was above EMA(20) for the configured prior confirmation bars. Opposite signals close the current position and request a new market entry in the opposite direction; the protective stop is 2.0 * ATR(14) from entry by default.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ema` | 10 | 1-100 | Fast EMA period used for crossover direction. |
| `strategy_slow_ema` | 20 | 2-200 | Slow EMA period; must be greater than the fast EMA. |
| `strategy_cross_confirm_bars` | 2 | 1-5 | Number of prior completed bars that must be on the opposite side before a cross is valid. |
| `strategy_atr_period` | 14 | 1-100 | ATR period used for the hard protective stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | ATR multiplier for stop-loss distance. |
| `strategy_warmup_bars` | 200 | 20-1000 | Minimum indicator history required before signals are accepted. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major with M1 OHLC data.
- `GBPUSD.DWX` - card-listed liquid FX major with M1 OHLC data.
- `USDJPY.DWX` - card-listed liquid FX major with M1 OHLC data.
- `XAUUSD.DWX` - card-listed liquid metal CFD with M1 OHLC data.
- `GDAXI.DWX` - DAX-equivalent DWX symbol used because `GER40.DWX` is not in `dwx_symbol_matrix.csv`.
- `NDX.DWX` - card-listed liquid US index CFD with M1 OHLC data.
- `WS30.DWX` - card-listed liquid US index CFD with M1 OHLC data.

**Explicitly NOT for:**
- `GER40.DWX` - card-listed name is not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.
- `SP500.DWX` - card marks it optional only, not part of the primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `180` |
| Typical hold time | Minutes to hours, until the opposite EMA cross or framework risk/time exit. |
| Expected drawdown profile | High-cadence intraday trend-following with spread drag and noise sensitivity. |
| Regime preference | Trend-following intraday regimes. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** public GitHub repository
**Pointer:** https://github.com/s-brez/trading-server/blob/dev/model.py, `EMACrossTestingOnly`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12349_sb-ema10-20.md`

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
| v1 | 2026-06-11 | Initial build from card | 1f8ecc07-17f4-40ca-b12c-edd701d8f76f |
