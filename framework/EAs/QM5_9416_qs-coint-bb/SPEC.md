# QM5_9416_qs-coint-bb — Strategy Spec

**EA ID:** QM5_9416
**Slug:** `qs-coint-bb`
**Source:** `842161b9-a728-55c7-97e8-33e33719b70c`
**Author of this spec:** Development
**Last revised:** 2026-07-01

---

## 1. Strategy Logic

D1 cointegrated index-pair mean-reversion. The EA runs on the y-leg chart symbol (SP500.DWX). It loads daily closes for both the y-leg and a configurable x-leg symbol (default NDX.DWX) via CopyRates. An OLS regression on log-prices over `strategy_ols_period` bars (default 252) yields hedge ratio beta. Beta is re-estimated every `strategy_reestimate_bars` bars (default 21, approximately monthly).

Spread: `spread_t = log(close_y) - beta * log(close_x)`

Z-score: mean and standard deviation of the spread over the most recent `strategy_bb_period` bars (default 15). Entry fires on the closed D1 bar when `|zscore| >= strategy_entry_z` (default 1.5) and no position is open. Long spread when zscore < -1.5; short spread when zscore > +1.5. Exit when zscore reverts inside `strategy_exit_z` (default 0.5), or when `|zscore| >= strategy_stop_z` (default 4.0), or when beta leaves the valid range. Stop loss uses ATR-based distance.

Two symbol pairs supported via `strategy_x_symbol`: NDX.DWX (default) or WS30.DWX. Run on SP500.DWX chart; x-leg bars fetched via CopyRates on each new D1 bar.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_x_symbol` | `NDX.DWX` | NDX.DWX / WS30.DWX | X-leg symbol for the spread |
| `strategy_bb_period` | 15 | 5-50 | Lookback bars for spread mean/std (z-score denominator) |
| `strategy_entry_z` | 1.5 | 1.0-3.0 | Z-score magnitude threshold to open a position |
| `strategy_exit_z` | 0.5 | 0.1-1.0 | Z-score magnitude threshold to close (mean-reversion target) |
| `strategy_stop_z` | 4.0 | 2.0-6.0 | Z-score magnitude hard stop (spread divergence) |
| `strategy_ols_period` | 252 | 100-504 | OLS regression window in D1 bars (approx 1 year) |
| `strategy_reestimate_bars` | 21 | 5-63 | Re-estimate beta every N bars (approx monthly) |
| `strategy_beta_min` | 0.25 | 0.01-1.0 | Minimum valid hedge ratio |
| `strategy_beta_max` | 4.0 | 1.0-10.0 | Maximum valid hedge ratio |
| `strategy_atr_period` | 14 | 5-50 | ATR period for stop-loss calculation |
| `strategy_atr_sl_mult` | 2.0 | 0.5-5.0 | ATR multiplier for stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - y-leg; chart symbol; SP500/NDX and SP500/WS30 pairs are structurally cointegrated US equity indices
- `NDX.DWX` - x-leg default; Nasdaq vs S&P cointegration is empirically well-documented
- `WS30.DWX` - x-leg alternative via `strategy_x_symbol=WS30.DWX`; Dow Jones vs S&P pair

**Explicitly NOT for:**
- Forex or commodity symbols - OLS spread semantics assume index-level price correlation; regime and beta validity checks would not apply
- `SP500.DWX` as x-leg - only valid as y-leg (chart symbol)
- Live trading of `SP500.DWX` - backtest-only per DWX symbol matrix; live promotion requires parallel validation on NDX.DWX or WS30.DWX

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | D1 CopyRates for both y-leg and x-leg |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~80 |
| Typical hold time | 1-10 days |
| Expected drawdown profile | Mean-reversion with bounded spread divergence stops |
| Regime preference | Mean-reversion / pairs cointegration |
| Win rate target (qualitative) | medium-high (>50% typical for cointegrated mean-reversion) |

---

## 6. Source Citation

**Source ID:** `842161b9-a728-55c7-97e8-33e33719b70c`
**Source type:** article
**Pointer:** https://www.quantstart.com/articles/aluminum-smelting-cointegration-strategy-in-qstrader/ (QuantStart / QuarkGluon Ltd.)
**R1-R4 verdict (Q00):** all PASS - see `artifacts/cards_approved/QM5_9416_qs-coint-bb.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-01 | Initial build from card | pending build commit |
