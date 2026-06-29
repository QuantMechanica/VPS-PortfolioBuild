# QM5_12782_katz-seas-xti - Strategy Spec

**EA ID:** QM5_12782
**Slug:** `katz-seas-xti`
**Source:** `katz-encyclopedia-2000-ch8`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

---

## 1. Strategy Logic

This EA is the `XTIUSD.DWX` D1 energy port of Katz and McCormick's Ch.8 seasonal crossover with Stochastic confirmation. It builds a day-of-year seasonal momentum curve from prior-year ATR-normalized D1 movement, integrates that curve into a seasonal pseudo-price, and trades only when the seasonal pseudo-price crosses a displaced SMA while Stochastic %K confirms an extreme.

Confirmed entries are stop orders one tick beyond the signal bar high or low. Exits use the Katz SES baseline: ATR hard stop, ATR profit target, and a 10-D1-bar time exit.

---

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_seasonal_years` | 10 | Maximum prior years sampled for each day-of-year seasonal momentum value. |
| `strategy_min_years` | 6 | Minimum prior-year samples required before a seasonal value is valid. |
| `strategy_seasonal_sma` | 15 | SMA period applied to the cumulative seasonal pseudo-price. |
| `strategy_sma_displacement` | 7 | Bars by which the seasonal SMA is displaced for crossover comparison. |
| `strategy_momentum_atr` | 20 | ATR lookback used to normalize prior-year one-day momentum samples. |
| `strategy_exit_atr` | 50 | ATR lookback used for SES stop and target distances. |
| `strategy_sl_atr_mult` | 1.0 | Stop distance multiplier applied to ATR. |
| `strategy_tp_atr_mult` | 4.0 | Profit-target distance multiplier applied to ATR. |
| `strategy_stoch_k` | 5 | Stochastic %K period. |
| `strategy_stoch_d` | 3 | Stochastic %D period. |
| `strategy_stoch_slowing` | 3 | Stochastic slowing parameter. |
| `strategy_stoch_long_max` | 25.0 | Maximum %K allowed for long confirmation. |
| `strategy_stoch_short_min` | 75.0 | Minimum %K allowed for short confirmation. |
| `strategy_stop_valid_bars` | 3 | Number of D1 bars a confirmation stop remains valid. |
| `strategy_time_exit_bars` | 10 | Maximum holding period in D1 bars. |
| `strategy_history_bars` | 4500 | D1 bars copied for the prior-year seasonal table. |
| `strategy_max_spread_points` | 1000 | Maximum current `XTIUSD.DWX` spread allowed for entries. |

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` - WTI crude-oil CFD; energy port motivated by the Katz Ch.8 commodity-market evidence.

**Explicitly not for:**

- XAU/GDAXI ports already covered by `QM5_12546`.
- XTI/XNG, XAU/XAG, oil/gold, and oil/silver baskets.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` framework gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `6-10` after six-year warmup |
| Typical hold time | Stop orders valid for 3 D1 bars; filled trades time-exit after 10 D1 bars. |
| Expected drawdown profile | Card frontmatter expected DD is 18%. |
| Regime preference | Commodity seasonal inflection with current-price Stochastic confirmation. |

---

## 6. Source Citation

**Source ID:** `katz-encyclopedia-2000-ch8`
**Source type:** book
**Pointer:** Katz and McCormick (2000), Ch.8, pp. 185-189, Tests 7-9, Table 8-3; local cache `D:/QM/strategy_farm/source_cache/katz-mccormick-encyclopedia-2000.txt`
**Repo research note:** `docs/research/LIBRARY_MINING_katz-mccormick-encyclopedia-2000_2026-06.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest Q02+ | RISK_FIXED | `$1,000` per trade |
| Live, if ever approved | RISK_PERCENT | Allocated only by portfolio process |

This build does not touch `T_Live`, AutoTrading, deploy manifests, or portfolio-gate files.

---

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-06-29 | Initial XTIUSD energy port from Katz Ch.8 adaptive seasonal crossover |
