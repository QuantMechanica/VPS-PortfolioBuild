---
strategy_id: HOLLSTEIN-MAX-2021_XTI_XNG_S02
source_id: HOLLSTEIN-MAX-2021
ea_id: QM5_13131
slug: energy-kurt-rank
status: APPROVED
g0_status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
source_citation: "Hollstein, Prokopczuk, and Tharann (2021), Anomalies in Commodity Futures Markets, Quarterly Journal of Finance 11(4), article 2150017, DOI 10.1142/S2010139221500178."
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
period: D1
logical_symbol: QM5_13131_XTI_XNG_HKURT_D1
expected_trade_frequency: "One monthly XTI/XNG historical-kurtosis package after 253 completed D1 bars; approximately 12 completed packages/year."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.02
expected_dd_pct: 28.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
g0_approval_reasoning: "OWNER mission 2026-07-11: complete peer-reviewed source and appendix; exact prior-252-return Pearson historical-kurtosis rank, monthly paired hold, equal fixed risk, ATR hard stops, and restart-safe no-reentry; native registered XTI/XNG data; no ML/banned logic; manual dedup CLEAN before atomic allocation. Insignificant two-portfolio evidence and the post-financialization sign reversal are explicit Q02 kill risks."
---

# XTI/XNG Historical-Kurtosis Rank

## Hypothesis

Test the source's full-sample positive historical-kurtosis relation in a
two-energy carrier: buy the higher-kurtosis leg and short the lower-kurtosis
leg for one broker month.

## Entry Rules

- Run one logical basket from `XTIUSD.DWX` D1 with `XNGUSD.DWX` at slot 1.
- On the first tradable D1 bar of each month, load 253 completed closes and
  calculate exactly 252 simple returns for each leg.
- Calculate the mean, sample variance with denominator 251, and fourth central
  moment with denominator 252; Pearson kurtosis is moment four divided by
  squared variance.
- Buy the higher-kurtosis leg and sell the lower-kurtosis leg; stay flat on a
  tie or invalid/incomplete data.
- Split `RISK_FIXED=1000` equally and attach a frozen `ATR(20) * 3.5` hard
  stop to each leg.
- Current positions and entry-deal history forbid a second package in the same
  broker month.

## Exit And Risk Rules

Close the package at the next month transition, after 35 days, or immediately
on orphan/invalid composition. Friday close is disabled only for the monthly
hold. No TP, trail, grid, martingale, pyramiding, external runtime data, banned
indicator, or ML is authorized.

The paper's full-sample tercile result is positive, but its directly relevant
two-portfolio result and regression slope are insignificant, and the
post-financialization spread is negative and insignificant. The 2017+ Q02 run
is out of sample. The paper ranks a broad futures universe; this port ranks two
continuous CFDs. Both limitations are falsification risks, not waiver grounds.

This rule is distinct from `QM5_13118_energy-skew-rank` (third moment),
`QM5_13129_energy-rsj` (one-month signed semivariance), and
`QM5_13130_xti-xng-lowmax` (top-five upside order statistic). It uses every
return in a centered fourth moment and has no RSI, momentum, carry,
spread-z-score, breakout, or calendar input.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`. No live artifact, T_Live,
AutoTrading, deploy manifest, portfolio gate, or admission change is approved.

Full canonical card: `strategy-seeds/cards/energy-kurt-rank_card.md`.

Q01 compile/build checks passed with zero errors and warnings on 2026-07-11.
Q02 work item `4697672b-b54a-46b9-979a-12cff2d1e578` is pending and unclaimed.
