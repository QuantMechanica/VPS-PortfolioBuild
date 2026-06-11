# QM5_10030_rw-fx-eur-basket - Strategy Spec

**EA ID:** QM5_10030
**Slug:** rw-fx-eur-basket
**Source:** dcbac84f-6ecf-5d21-9630-50faa69306ec
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA evaluates a D1 European FX basket made from EURUSD.DWX, GBPUSD.DWX, EURGBP.DWX, EURJPY.DWX, GBPJPY.DWX, USDCHF.DWX, and EURCHF.DWX. On each closed D1 bar it computes a frozen-coefficient log spread, then calculates a 60-bar z-score from the spread mean and standard deviation. If the spread z-score is above +2.0, the current routed leg sells the rich spread; if the z-score is below -2.0, the current routed leg buys the cheap spread. Exit occurs when the cached spread z-score is back inside +/-0.50, when the position has been held for 20 trading days, when the adverse spread move exceeds 2.5 standard deviations from the entry side, or through the framework Friday close.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_z_lookback_d1` | 60 | >=20 | D1 bars used for basket spread z-score mean and standard deviation. |
| `strategy_entry_z` | 2.0 | >0 | Absolute spread z-score threshold for new basket-leg entries. |
| `strategy_exit_z` | 0.50 | >=0 | Absolute spread z-score threshold for mean-reversion exit. |
| `strategy_stop_std_mult` | 2.50 | >0 | Adverse z-score distance beyond the entry side for basket-level stop. |
| `strategy_time_stop_bars` | 20 | >=0 | Maximum calendar-day hold before strategy exit. |
| `strategy_atr_period_d1` | 14 | >0 | ATR period for per-leg platform SL. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiple for per-leg platform SL. |
| `strategy_stationarity_bars` | 252 | >=30 | D1 spread bars used for rolling AR(1) stationarity guard. |
| `strategy_stationarity_max_phi` | 0.98 | 0-1 | Maximum allowed lag-1 spread persistence; higher fails the stationarity check. |
| `strategy_max_spread_points` | 60 | >=0 | Maximum allowed current broker spread per leg; 0 disables this guard. |
| `strategy_weight_eurusd` | 1.0 | fixed/sweep | Frozen coefficient for EURUSD.DWX in the log spread. |
| `strategy_weight_gbpusd` | 1.0 | fixed/sweep | Frozen coefficient for GBPUSD.DWX in the log spread. |
| `strategy_weight_eurgbp` | 1.0 | fixed/sweep | Frozen coefficient for EURGBP.DWX in the log spread. |
| `strategy_weight_eurjpy` | 1.0 | fixed/sweep | Frozen coefficient for EURJPY.DWX in the log spread. |
| `strategy_weight_gbpjpy` | 1.0 | fixed/sweep | Frozen coefficient for GBPJPY.DWX in the log spread. |
| `strategy_weight_usdchf` | 1.0 | fixed/sweep | Frozen coefficient for USDCHF.DWX in the log spread. |
| `strategy_weight_eurchf` | 1.0 | fixed/sweep | Frozen coefficient for EURCHF.DWX in the log spread. |

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 European FX basket leg and DWX matrix member.
- `GBPUSD.DWX` - card R3 European FX basket leg and DWX matrix member.
- `EURGBP.DWX` - card R3 European FX basket leg and DWX matrix member.
- `EURJPY.DWX` - card R3 European FX basket leg and DWX matrix member.
- `GBPJPY.DWX` - card R3 European FX basket leg and DWX matrix member.
- `USDCHF.DWX` - card R3 European FX basket leg and DWX matrix member.
- `EURCHF.DWX` - card R3 European FX basket leg and DWX matrix member.

**Explicitly NOT for:**
- Any non-registered symbol - the EA rejects chart symbols outside the seven registered basket legs and rejects a chart whose `qm_magic_slot_offset` does not match the registered symbol slot.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry gate |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Up to 20 trading days |
| Expected drawdown profile | Mean-reversion basket drawdowns during persistent FX spread dislocations, capped by per-leg ATR guards and basket z-stop. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

## 6. Source Citation

This card was mechanised from:

**Source ID:** dcbac84f-6ecf-5d21-9630-50faa69306ec
**Source type:** blog index / strategy family reference
**Pointer:** Robot Wealth, "Index of Strategies", FX European Currency basket section, https://robotwealth.com/index-of-strategies/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10030_rw-fx-eur-basket.md`

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
| v1 | 2026-06-11 | Initial build from card | d5c2fb20-caa5-4bd2-8884-2829d6b35ae7 |
