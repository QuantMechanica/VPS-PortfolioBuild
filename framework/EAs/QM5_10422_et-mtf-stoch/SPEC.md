# QM5_10422_et-mtf-stoch - Strategy Spec

**EA ID:** QM5_10422
**Slug:** `et-mtf-stoch`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades on M30 using a completed H4 stochastic cross. It opens long when H4 StochK crosses above H4 StochD and opens short when H4 StochK crosses below H4 StochD, evaluated only after the H4 bar has closed. Each entry uses an M30 ATR(20) stop multiplied by 1.8, moves the stop to breakeven after price reaches +1R, and exits on the opposite completed H4 stochastic cross or after 20 M30 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | `PERIOD_H1`, `PERIOD_H4`, `PERIOD_D1` | Higher timeframe used for the stochastic cross signal. |
| `strategy_stoch_k` | `5` | `5`-`14` | Stochastic K period. |
| `strategy_stoch_d` | `3` | `3` | Stochastic D period. |
| `strategy_stoch_slow` | `3` | `3` | Stochastic slowing value. |
| `strategy_atr_period` | `20` | `20` | M30 ATR period used for initial stop distance. |
| `strategy_atr_sl_mult` | `1.8` | `1.2`-`2.4` | Multiplier applied to ATR(20) for the initial stop. |
| `strategy_time_exit_bars` | `20` | `12`-`32` | Maximum hold time in execution-timeframe bars. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed FX major with DWX data available.
- `GBPUSD.DWX` - Card-listed FX major with DWX data available.
- `XAUUSD.DWX` - Card-listed gold CFD with DWX data available.
- `SP500.DWX` - Card-listed S&P 500 proxy; valid for backtest with T6 routability caveat.
- `GDAXI.DWX` - Canonical DWX DAX symbol used for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - Not canonical DWX S&P 500 symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | Completed `H4` stochastic K/D values by default; P3 can test `H1` and `D1`. |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` plus `QM_IsNewBar(_Symbol, strategy_signal_tf)` for completed signal bars |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | `up to 20 M30 bars unless opposite H4 cross occurs` |
| Expected drawdown profile | `Moderate, ATR-defined stop with breakeven after +1R.` |
| Regime preference | `Multi-timeframe oscillator trend turns and pullbacks.` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/amibroker-afl-guidance.95396/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10422_et-mtf-stoch.md`

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
| v1 | 2026-05-25 | Initial build from card | 62df79e0-15c2-4c02-8bed-4ef2fd62cc31 |
