# QM5_11905_hui-chan-shiryaev-zhou-3day-d1 - Strategy Spec

**EA ID:** QM5_11905
**Slug:** `hui-chan-shiryaev-zhou-3day-d1`
**Source:** `5d8e3a47-6c92-5b71-9f48-d2a6c1e3b5f8`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

This EA mechanises the Hui and Chan Shiryaev-Zhou drift-to-variance index on
closed D1 bars. For each symbol it computes rolling daily log returns over
`strategy_moving_window_n = 130` bars, annualises the return mean and variance,
then estimates:

`beta_hat = annualised_mean_return / annualised_return_variance - 0.5`

A fresh long signal occurs when `beta_hat` is non-negative for three consecutive
closed D1 bars and the prior reading was negative. A fresh short signal is the
mirror case: three consecutive negative readings after a non-negative prior
reading. The EA opens at market after the fresh persistence trigger, using a
D1 ATR stop. Open positions close on the opposite three-bar persistence signal,
the broker stop, Friday close, or the hard `strategy_time_stop_bars` timeout.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_moving_window_n` | 130 | 20-500 | Number of closed D1 bars in the rolling log-return estimator. |
| `strategy_trading_days_yr` | 250 | 200-260 | Annualisation factor for mean return and variance. |
| `strategy_confirmation_days` | 3 | 3 fixed | Card-specified persistence length before a fresh regime trigger. |
| `strategy_beta_threshold` | 0.0 | -2.0-2.0 | Zero line used to classify positive versus negative SZ regimes. |
| `strategy_atr_period` | 14 | 5-100 | D1 ATR period used for the hard stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.5-10.0 | ATR multiplier for the stop loss. |
| `strategy_time_stop_bars` | 60 | 0-250 | Maximum D1 bars to hold if no opposite signal appears; 0 disables. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid D1 major FX pair.
- `GBPUSD.DWX` - liquid D1 major FX pair.
- `USDJPY.DWX` - liquid D1 major FX pair.
- `USDCAD.DWX` - liquid D1 major FX pair.
- `USDCHF.DWX` - liquid D1 major FX pair.
- `AUDUSD.DWX` - liquid D1 major FX pair.
- `NZDUSD.DWX` - liquid D1 major FX pair.
- `EURJPY.DWX` - liquid D1 cross with sufficient DWX history.
- `GBPJPY.DWX` - liquid D1 cross with sufficient DWX history.
- `AUDJPY.DWX` - liquid D1 cross with sufficient DWX history.

**Explicitly NOT for:**
- Non-DWX symbols - unavailable to the V5 backtest registry.
- Single-stock CFDs - the card ports a broad index timing rule to major FX only.
- Intraday timeframes - the estimator and confirmation rule are defined on D1.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | About 8 |
| Typical hold time | Several days to about 3 months |
| Expected drawdown profile | Trend-following false-regime drawdowns controlled by ATR stop and 60-bar timeout |
| Regime preference | Low-frequency directional drift regimes |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `5d8e3a47-6c92-5b71-9f48-d2a6c1e3b5f8`
**Source type:** peer-reviewed paper
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11905_hui-chan-shiryaev-zhou-3day-d1.md`
**R1-R4 verdict (Q00):** approved card; R1 PASS, R2 mechanical PASS, R3 data PASS, R4 no-ML PASS.

Eddie C.M. Hui and Ka Kwan Kevin Chan, "Alternative trading strategies to beat
'buy-and-hold'," Physica A: Statistical Mechanics and its Applications 534
(2019) 120800. DOI: 10.1016/j.physa.2019.04.061.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3%-0.5% |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-30 | Initial build from approved card | Commit pending |
