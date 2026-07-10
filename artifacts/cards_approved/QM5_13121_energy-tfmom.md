---
strategy_id: CLARE-TFMOM-2014_XTI_XNG_S01
source_id: CLARE-TFMOM-2014
ea_id: QM5_13121
slug: energy-tfmom
status: APPROVED
g0_status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
source_citation: "Clare, Seaton, Smith, and Thomas (2014), Trend following, risk parity and momentum in commodity futures, International Review of Financial Analysis 31, 1-12, DOI 10.1016/j.irfa.2013.10.001."
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
period: D1
logical_symbol: QM5_13121_ENERGY_TFMOM_D1
expected_trade_frequency: "Approximately 5-9 eligible paired packages/year after warm-up."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.05
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
g0_approval_reasoning: "OWNER mission 2026-07-10: peer-reviewed source; fixed 12-month rank, 7-month two-sided trend confirmation, 60-D1 inverse-volatility weights, monthly paired hold; native registered XTI/XNG D1 data; no ML/banned indicator; exact dedup clean."
---

# XTI/XNG Trend-Filtered Momentum

## Source

Clare, Andrew; Seaton, James; Smith, Peter N.; and Thomas, Stephen
(2014), "Trend following, risk parity and momentum in commodity futures",
*International Review of Financial Analysis* 31, 1-12, DOI
https://doi.org/10.1016/j.irfa.2013.10.001. The complete paper was reviewed.

## Mechanical Rule

- Run one logical basket from XTIUSD.DWX D1 with XNGUSD.DWX as slot 1.
- On the first tradable D1 bar of each broker month, rank the two legs by
  synchronized 12-completed-month log return.
- Require the winner above its latest seven completed month-end close mean and
  the loser below its own mean; otherwise stay flat.
- Buy the confirmed winner and short the confirmed loser.
- Divide `RISK_FIXED=1000` using 60-D1 inverse-volatility weights and attach a
  frozen `ATR(20) * 3.5` hard stop to each leg.
- Close at the next month transition, after 35 days, or on orphan/invalid
  package repair. Friday close is disabled only for the monthly hold.

## Non-Duplicate And Risk Boundary

This is not commodity RSI (`QM5_12567`), raw XTI/XNG momentum (`QM5_12733`),
return-spread reversion, carry, momentum-IVol, skewness, or the 12/18-month
momentum-reversal package (`QM5_13120`). The source uses 28 futures; this
two-CFD carrier is a falsification test and does not import source performance.
Q02 retires it below five completed packages/year. Q09 alone judges realized
portfolio correlation.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`. No live setfile, T_Live,
AutoTrading, deploy manifest, portfolio gate, or admission artifact is allowed.

Full canonical card:
`strategy-seeds/cards/energy-tfmom_card.md`.
