# QM5_12533_edgelab-eurjpy-gbpjpy-cointegration - Strategy Spec

**EA ID:** QM5_12533
**Slug:** edgelab-eurjpy-gbpjpy-cointegration
**Source:** claude_cross_asset_discovery_2026-06-09
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades the EURJPY.DWX and GBPJPY.DWX cointegration spread on D1 closes. It computes `S = ln(EURJPY) - beta * ln(GBPJPY)` with beta defaulting to 0.75, then calculates a 60-bar z-score of that spread. It opens a short-spread package when z is above +2.0 and a long-spread package when z is below -2.0. It closes both legs when the cached spread z-score has reverted inside +/-0.5, while each leg also carries a 2.0 * ATR(20, D1) protective stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_z_lookback_d1 | 60 | 20+ | D1 bars used for rolling spread mean and standard deviation |
| strategy_beta | 0.75 | >0 | Hedge coefficient in `ln(EURJPY) - beta * ln(GBPJPY)` |
| strategy_entry_z | 2.0 | >0 | Absolute z-score threshold for opening a spread package |
| strategy_exit_z | 0.5 | >=0 | Absolute z-score threshold for closing the open package |
| strategy_atr_period_d1 | 20 | 2+ | D1 ATR period for per-leg hard stop distance |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiplier for each leg's hard stop |
| strategy_deviation_points | 20 | 0+ | Broker deviation points for market leg entries |

---

## 3. Symbol Universe

**Designed for:**
- EURJPY.DWX - leg 1 of the approved EURJPY GBPJPY cointegration pair and the spread numerator.
- GBPJPY.DWX - leg 2 of the approved EURJPY GBPJPY cointegration pair and the beta-weighted spread denominator.

**Explicitly NOT for:**
- Other `.DWX` symbols - the card is a fixed two-leg FX-cross pair, not a portable multi-pair strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 24 |
| Typical hold time | days to weeks |
| Expected drawdown profile | Approximately 8% expected drawdown, with ATR stops containing structural-break tails |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** claude_cross_asset_discovery_2026-06-09
**Source type:** paper plus internal Edge Lab discovery
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration.md`

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
| v1 | 2026-06-09 | Initial build from card | 7fe478b5-35ec-4cfa-ab03-7df60d53ab95 |
