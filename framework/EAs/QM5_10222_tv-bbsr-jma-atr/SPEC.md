# QM5_10222_tv-bbsr-jma-atr - Strategy Spec

**EA ID:** QM5_10222
**Slug:** tv-bbsr-jma-atr
**Source:** 30591366-874b-5bee-b47c-da2fca20b728
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades Bollinger Band re-entry signals with Stochastic confirmation and a low-lag JMA proxy. A long signal occurs when the last closed bar closes back above the lower Bollinger Band after the prior close was below the lower band, Stochastic K and D are both below the oversold threshold, and the HMA proxy is rising. A short signal mirrors this at the upper Bollinger Band with Stochastic K and D above the overbought threshold and a falling HMA proxy. Initial stop and ongoing trade management use an ATR trailing stop, and an open position is closed when the opposite entry signal appears.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_bb_period | 20 | 2-200 | Bollinger Band lookback period. |
| strategy_bb_deviation | 2.0 | 0.5-5.0 | Bollinger Band standard deviation multiplier. |
| strategy_stoch_k | 14 | 2-100 | Stochastic K period. |
| strategy_stoch_d | 3 | 1-50 | Stochastic D period. |
| strategy_stoch_slowing | 3 | 1-50 | Stochastic slowing value. |
| strategy_stoch_oversold | 20.0 | 1.0-50.0 | Maximum K and D value for long entries. |
| strategy_stoch_overbought | 80.0 | 50.0-99.0 | Minimum K and D value for short entries. |
| strategy_hma_period | 55 | 4-300 | HMA period used as the card-authorized JMA proxy. |
| strategy_atr_period | 14 | 2-100 | ATR period for initial and trailing stop. |
| strategy_atr_mult | 2.0 | 0.5-10.0 | ATR multiplier for initial and trailing stop. |
| strategy_session_start_hour | 7 | 0-23 | Broker hour when baseline trading may begin. |
| strategy_session_end_hour | 22 | 0-23 | Broker hour when baseline trading stops. |
| strategy_max_spread_atr_frac | 0.10 | 0.0-1.0 | Maximum spread as a fraction of ATR. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card target; liquid major FX pair suited to Bollinger/Stochastic reversal testing.
- GBPUSD.DWX - card target; liquid major FX pair suited to Bollinger/Stochastic reversal testing.
- XAUUSD.DWX - card target; liquid metal CFD with reversal and volatility regimes.
- GDAXI.DWX - canonical DWX DAX symbol used for the card's GER40 target.
- NDX.DWX - card target; liquid US index CFD with volatility/reversal behavior.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to GDAXI.DWX.
- SPX500.DWX, SPY.DWX, ES.DWX - unavailable phantom symbols under DWX discipline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 and H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Not specified in card; position is held until ATR trailing stop, opposite signal, or framework close. |
| Expected drawdown profile | Not specified in card. |
| Regime preference | Mean-reversion from volatility extremes with momentum confirmation. |
| Win rate target (qualitative) | Not specified in card. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView script page
**Pointer:** https://www.tradingview.com/script/59farSw2-BBSR-Extreme-Strategy-nachodog/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10222_tv-bbsr-jma-atr.md`

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
| v1 | 2026-06-09 | Initial build from card | d75f3d88-efcc-4c5c-b450-d33a03975bda |
