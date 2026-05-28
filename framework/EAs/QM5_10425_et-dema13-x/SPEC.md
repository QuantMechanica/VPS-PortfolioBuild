# QM5_10425_et-dema13-x - Strategy Spec

**EA ID:** QM5_10425
**Slug:** et-dema13-x
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades M1 completed-bar crosses of a static completed-D1 EMA(13) level. It opens long when the last closed M1 close crosses above the D1 EMA(13), and opens short when the last closed M1 close crosses below it. Each initial trade uses a 1.0R stop and 2.5R target, where R is the greater of 20 symbol points and ATR(20) on M1. If an initial trade is stopped, the EA may reverse once in the opposite direction with a 1.0R stop and 1.25R target, then waits flat for the next fresh cross.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_daily_ema_period | 13 | 2-100 | Completed D1 EMA period projected onto intraday bars. |
| strategy_atr_period | 20 | 2-200 | M1 ATR period used to normalize the R distance. |
| strategy_source_points | 20 | 1-10000 | Minimum source point distance used in the max(20 points, ATR) R rule. |
| strategy_initial_target_rr | 2.5 | 0.1-10.0 | Initial trade target in R multiples. |
| strategy_reversal_target_rr | 1.25 | 0.1-10.0 | One allowed reversal target in R multiples. |
| strategy_reversal_enabled | true | true/false | Enables or disables the card's bounded one-stop reversal. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Liquid major FX pair from the card's R3 P2 basket.
- GBPUSD.DWX - Liquid major FX pair from the card's R3 P2 basket.
- XAUUSD.DWX - Gold DWX symbol from the card's R3 P2 basket.
- GDAXI.DWX - Available DWX DAX symbol used as the nearest matrix-valid port for card target GER40.DWX.
- NDX.DWX - Nasdaq 100 DWX index CFD from the card's R3 P2 basket.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is used instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M1 |
| Multi-timeframe refs | Completed D1 EMA(13) |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Intraday; trades close by bracket SL/TP or Friday close. |
| Expected drawdown profile | High cadence and likely whipsaw around a daily EMA level; bounded by one reversal only. |
| Regime preference | intraday crossover / stop-reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/afl-code-required-for-ema-based-strategy.300170/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10425_et-dema13-x.md`

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
| v1 | 2026-05-25 | Initial build from card | b9c05539-c8f8-404b-8ce3-8cc9fdfad08c |
