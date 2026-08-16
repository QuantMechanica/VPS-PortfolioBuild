---
ea_id: QM5_1257
slug: lemishko-fx-cointpair
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/pairs-trading]]"
  - "[[concepts/cointegration]]"
indicators:
  - "[[indicators/cointegration-test]]"
  - "[[indicators/z-score]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02_PASS
last_updated: 2026-08-16
g0_approval_reasoning: "SSRN Lemishko-Landi-Caicedo 2024 (abstract 4771108) R1-R4 PASS: named authors+SSRN URL, Engle-Granger coint + frozen monthly OLS hedge ratio (no online adaptation), 7-pair major FX DWX universe, no ML"
---

# Lemishko-Landi-Caicedo Forex Cointegration Pair

## Hypothesis

Major FX rates that share a stable long-run equilibrium can temporarily
diverge while their fitted residual remains mean reverting. Trading both legs
as one bounded-risk package seeks convergence exposure instead of a naked
directional currency position. The approved source supplies the structural
cointegration method; profitability for any particular pair remains an
empirical pipeline question.

## Quelle
- Source: [[sources/ssrn-financial-economics-network]]
- Paper: Tetiana Lemishko, Alexandre Landi, Juliana Caicedo-Llano, "Cointegration-Based Strategies in Forex Pairs Trading", SSRN, posted 2024-04-15, revised 2024-12-18.
- URL: https://ssrn.com/abstract=4771108
- Location: SSRN abstract proposes applying cointegration-based pair trading to Forex markets and focuses on deviations from long-term equilibrium relationships.

## Rules

### Entry
- Monthly, evaluate candidate DWX FX pairs from the major FX universe: `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `USDCAD.DWX`.
- For each candidate pair-of-pairs, run an Engle-Granger cointegration test on the prior 252 daily closes.
- Keep only combinations with p-value <= 0.05 and positive spread half-life between 2 and 30 trading days.
- Estimate hedge ratio by ordinary least squares on the same 252-day window; freeze it until the next monthly selection.
- Compute spread z-score on H1 bars using a 60-bar rolling mean and standard deviation.
- Enter long spread when z-score <= -2.0: long underpriced leg, short overpriced leg by frozen hedge ratio.
- Enter short spread when z-score >= +2.0: short overpriced leg, long underpriced leg by frozen hedge ratio.

### Exit
- Close when spread z-score crosses 0.
- Time stop: close after 10 trading days.
- Structural stop: close immediately if daily z-score exceeds +/-3.5 against the position.

### Stop Loss
- Combined pair stop at 1.5R.
- If either leg cannot be priced or traded, close the other leg immediately.

## Risk
- P2 baseline: fixed combined pair risk USD 1,000.
- Leg notionals follow frozen hedge ratio, capped so neither leg carries more than 70% of gross notional.

### Additional Safety Filters
- One active pair per magic number.
- Skip if pair spread cost exceeds 20% of the expected z-score reversion distance.
- Do not re-estimate hedge ratio intramonth; this avoids online parameter adaptation.

### Active Q02 Binding
- Pair slot: `8`.
- Host and first traded leg: `GBPUSD.DWX`, H1.
- Companion traded leg: `USDJPY.DWX`.
- Logical symbol: `QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1`.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- The frozen sign-aware 66-pair scan ranks this relationship 58 of 66:
  DEV net Sharpe `-0.103537893720`, OOS net Sharpe `-0.419922430787`,
  OOS return `-3.600289808739%`, 16 OOS state changes, fitted DEV beta
  `-0.388288093234`, and half-life `76.715376014881` D1 bars.
- Those adverse values are falsification evidence, not a performance claim.
  A cadence or economic failure retires this binding and does not authorize a
  refit, extra filter, or rescue tuning.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/pairs-trading]] - primary
- [[concepts/cointegration]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Named authors and SSRN URL: Tetiana Lemishko, Alexandre Landi, Juliana Caicedo-Llano, https://ssrn.com/abstract=4771108. |
| R2 Mechanical | PASS | Fixed monthly cointegration screen, frozen hedge ratio, z-score entry and mean-reversion exit. |
| R3 Data Available | PASS | Uses only major DWX FX OHLC prices. |
| R4 ML Forbidden | PASS | Cointegration and OLS are deterministic statistical transforms; no ML, neural net, online learning, martingale, or adaptive intramonth parameter update. |

## Pipeline-Verlauf
- G0: 2026-05-18, APPROVED.
- Q01: 2026-08-12, slot-8 logical basket packaged for strict build validation.
- Q02: 2026-08-12, task `39ee6910-5d04-4087-83b0-65a6fd6b22f9`
  created exactly one pending logical-basket work item,
  `d4cd660c-c81a-41d3-8a4c-ad21d3319816`; no dispatch was run.
- Q02: 2026-08-16, PASS on that exact logical-basket work item after 290
  Model-4 trades over 2018-07-02 through 2022-12-31. The run had no ONINIT
  failure and retained stable EX5 and fixed-risk setfile bindings. Q04 enqueue
  was deferred because the explicit backtest CPU ceiling was binding.

## Verwandte Strategien
- [[strategies/QM5_1129_gatev-distance-pairs]] - distance-based pairs; this card uses cointegration and Forex pairs.
- [[strategies/QM5_1227_neely-fx-channel]] - FX technical trend-following, not pair mean reversion.

## Lessons Learned (waehrend Pipeline-Lauf)
- Q02 established executable basket cadence, not economic merit. The bound
  run was adverse (PF 0.65, net profit -7,003.44, drawdown 7,920.49 / 7.90%),
  so no rescue tuning, refit, filter, or profitability claim is authorized.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
