# QM5_12407_oil-pred-eq - Strategy Spec

**EA ID:** QM5_12407
**Slug:** oil-pred-eq
**Source:** b7832a20-938e-5f24-b9d7-e0b2ab63b623
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades long-only equity index exposure using crude oil as a monthly timing input. On the first tradable D1 bar of a new month, it builds completed monthly closes from D1 bars for `XTIUSD.DWX` and the chart equity index, fits a rolling linear regression where prior-month oil return predicts next-month equity return, and opens a long position when the expected equity return is above the configured threshold. If the monthly signal is missing or at/below the threshold, any existing long position is closed and the EA remains flat.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_oil_symbol` | `XTIUSD.DWX` | DWX symbol string | Crude oil proxy used as the regression predictor. |
| `strategy_regression_lookback_months` | `60` | 60-120 or all available in later sweeps | Number of paired monthly observations used in the rolling OLS fit. |
| `strategy_min_paired_observations` | `60` | >= 60 | Minimum valid paired observations required before trading. |
| `strategy_monthly_threshold` | `0.0` | 0.0, cash proxy, 0.0025 | Expected monthly return hurdle for long exposure. |
| `strategy_atr_period` | `20` | > 1 | D1 ATR period for the emergency stop. |
| `strategy_atr_sl_mult` | `2.5` | > 0 | ATR multiple for the emergency stop. |
| `strategy_spread_median_days` | `60` | > 0 | D1 lookback for the median-spread filter; zero DWX spreads do not block trading. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - card's equity-market benchmark; backtest-only custom S&P 500 symbol.
- `NDX.DWX` - live-routable US large-cap parallel-validation target.
- `WS30.DWX` - live-routable US large-cap parallel-validation target.

**Explicitly NOT for:**
- `XTIUSD.DWX` - signal input only; the card uses oil to predict equity returns, not as the traded target.
- Non-DWX equity or oil symbols - outside the validated DWX matrix and registry discipline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `XTIUSD.DWX` D1 closes as signal input |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` entry gate |

The card is monthly. The implementation uses D1 month-boundary detection because `.DWX` MN1 history is unavailable in the tester.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `12` |
| Typical hold time | About one month when the signal is renewed; shorter if the next monthly signal turns flat. |
| Expected drawdown profile | Equity-timing drawdowns from missed rebounds and unstable oil-equity relationships. |
| Regime preference | Intermarket monthly timing, long-flat, price-only regression. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b7832a20-938e-5f24-b9d7-e0b2ab63b623
**Source type:** public code implementation / Quantpedia-style strategy note
**Pointer:** Papers With Backtest / Quantpedia implementation, Crude Oil Predicts Equity Returns, https://github.com/paperswithbacktest/awesome-systematic-trading/blob/main/static/strategies/crude-oil-predicts-equity-returns.py
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_12407_oil-pred-eq.md`

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
| v1 | 2026-06-18 | Initial build from card | d3a937ce-b689-4f52-9c9f-ba550c21c2c0 |
