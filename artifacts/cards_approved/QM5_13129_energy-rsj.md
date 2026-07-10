---
strategy_id: KISS-RSJ-2025_XTI_XNG_S01
source_id: KISS-RSJ-2025
ea_id: QM5_13129
slug: energy-rsj
status: APPROVED
g0_status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
source_citation: "Kiss and Ferreira Batista Martins (2025), Good Volatility, Bad Volatility and the Cross Section of Commodity Returns, Finance Research Letters 86, article 108656, DOI 10.1016/j.frl.2025.108656."
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
period: D1
logical_symbol: QM5_13129_ENERGY_RSJ_D1
expected_trade_frequency: "One monthly XTI/XNG RSJ package after warm-up; approximately 12 completed packages/year."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.05
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
g0_approval_reasoning: "OWNER mission 2026-07-11: complete peer-reviewed source; fixed one-month daily-return RSJ rank, monthly paired hold, equal fixed risk, ATR hard stops; native registered XTI/XNG data; no ML/banned logic; dedup CLEAN before atomic allocation."
---

# XTI/XNG Relative-Signed-Jump Rank

## Hypothesis

Trade the source's negative commodity RSJ premium in a two-energy carrier:
buy the lower-RSJ leg and short the higher-RSJ leg for one broker month.

## Entry Rules

- Run one logical basket from `XTIUSD.DWX` D1 with `XNGUSD.DWX` at slot 1.
- On the first tradable D1 bar of each month, use only simple close-to-close
  returns from the immediately preceding complete broker month.
- For each leg calculate `RV+` from squared positive returns and `RV-` from
  squared negative returns, then `RSJ=(RV+-RV-)/(RV++RV-)`.
- Require at least 15 returns and positive finite total realized variance.
- Buy the lower-RSJ leg and sell the higher-RSJ leg; stay flat on a tie or
  invalid data.
- Split `RISK_FIXED=1000` equally and attach a frozen `ATR(20) * 3.5` hard
  stop to each leg.

## Exit And Risk Rules

Close the package at the next month transition, after 35 days, or immediately
on orphan/invalid composition. Friday close is disabled only for the monthly
hold. No same-month re-entry, TP, trail, grid, martingale, pyramiding, external
runtime data, banned indicator, or ML is authorized.

The paper uses 36 collateralized commodity futures and extreme portfolios;
this port uses two continuous CFDs and equal risk. That narrowing and basis
mismatch are Q02 falsification risks. It is distinct from `QM5_13118` because
RSJ separates positive and negative squared returns over one month instead of
estimating 12-month Pearson skewness; the source also shows RSJ is not subsumed
by skewness.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`. No live artifact, T_Live,
AutoTrading, deploy manifest, portfolio gate, or admission change is approved.

Full canonical card: `strategy-seeds/cards/energy-rsj_card.md`.
