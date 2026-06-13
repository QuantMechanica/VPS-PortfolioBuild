# QM5_12546_katz-seasonal-crossover-stoch-confirmation-stop-d1 - Strategy Spec

**EA ID:** QM5_12546
**Slug:** `katz-seasonal-crossover-stoch-confirmation-stop-d1`
**Source:** `katz-encyclopedia-2000-ch8` (see `D:/QM/strategy_farm/source_cache/katz-mccormick-encyclopedia-2000.txt`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA builds a D1 day-of-year seasonal momentum curve from prior-year ATR-normalized one-day price movement, then resets the cumulative seasonal pseudo-price at the start of each calendar year. A long setup requires the seasonal pseudo-price to cross above its displaced 15-period seasonal SMA on the last closed D1 bar while Fast Stochastic %K is below 25; a short setup mirrors the crossover with %K above 75. Confirmed entries use stop orders one tick beyond the signal bar high or low, with a 1.0 ATR(50) money-management stop, 4.0 ATR(50) profit target, and a 10 D1 bar time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_seasonal_years` | 10 | 6-20 | Maximum prior years sampled for each day-of-year seasonal momentum value. |
| `strategy_min_years` | 6 | 1-10 | Minimum prior-year samples required before a seasonal value is valid. |
| `strategy_seasonal_sma` | 15 | 2-60 | SMA period applied to the cumulative seasonal pseudo-price. |
| `strategy_sma_displacement` | 7 | 0-20 | Bars by which the seasonal SMA is displaced forward for crossover comparison. |
| `strategy_momentum_atr` | 20 | 2-100 | ATR lookback used to normalize prior-year one-day momentum samples. |
| `strategy_exit_atr` | 50 | 2-200 | ATR lookback used for SES stop and target distances. |
| `strategy_sl_atr_mult` | 1.0 | 0.1-10.0 | Stop distance multiplier applied to ATR(50). |
| `strategy_tp_atr_mult` | 4.0 | 0.1-20.0 | Profit target distance multiplier applied to ATR(50). |
| `strategy_stoch_k` | 5 | 2-50 | Stochastic %K period. |
| `strategy_stoch_d` | 3 | 1-20 | Stochastic %D period. |
| `strategy_stoch_slowing` | 3 | 1-20 | Stochastic slowing parameter. |
| `strategy_stoch_long_max` | 25.0 | 0.0-50.0 | Maximum %K value allowed for a long confirmation. |
| `strategy_stoch_short_min` | 75.0 | 50.0-100.0 | Minimum %K value allowed for a short confirmation. |
| `strategy_stop_valid_bars` | 3 | 1-10 | Number of D1 bars a confirmation stop order remains valid. |
| `strategy_time_exit_bars` | 10 | 1-60 | Maximum holding period in D1 bars. |
| `strategy_history_bars` | 4500 | 1500-8000 | D1 bars copied for the prior-year seasonal table. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - precious-metals proxy named by R3 for Katz's strongest source-market cluster.

**Explicitly NOT for:**
- `XAGUSD.DWX` - close metals proxy, but not listed in the card R3 PASS row for registration.
- `GDAXI.DWX` - secondary candidate only; the card did not require it in the portable R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `8` |
| Typical hold time | Stop orders valid for 3 D1 bars; filled trades time-exit after 10 D1 bars. |
| Expected drawdown profile | Card frontmatter expected DD is 18%. |
| Regime preference | Seasonal momentum crossover in precious metals with stochastic confirmation near price extremes. |
| Win rate target (qualitative) | Medium; source OOS win rate was 44%. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `katz-encyclopedia-2000-ch8`
**Source type:** book
**Pointer:** Katz & McCormick (2000), Ch.8, pp. 185-189, Tests 7-9, Table 8-3; local cache `D:/QM/strategy_farm/source_cache/katz-mccormick-encyclopedia-2000.txt`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12546_katz-seasonal-crossover-stoch-confirmation-stop-d1.md`

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
| v1 | 2026-06-13 | Initial build from card | 61aa0274-8543-4185-a897-eb55fdf6cac6 |
