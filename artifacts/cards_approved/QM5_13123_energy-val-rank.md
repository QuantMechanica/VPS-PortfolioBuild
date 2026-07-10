---
strategy_id: AMP-VALUE-2013_XTI_XNG_S01
source_id: AMP-VALUE-2013
ea_id: QM5_13123
slug: energy-val-rank
status: APPROVED
g0_status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
source_citation: "Asness, Moskowitz, and Pedersen (2013), Value and Momentum Everywhere, The Journal of Finance 68(3), 929-985, DOI 10.1111/jofi.12021."
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
period: D1
logical_symbol: QM5_13123_ENERGY_VALUE_D1
expected_trade_frequency: "Approximately 12 paired packages/year after the 66-month warm-up."
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
g0_approval_reasoning: "OWNER mission 2026-07-10: peer-reviewed source plus Internet Appendix; fixed 54-66-month anchor average, cross-sectional energy value rank, monthly paired hold; native registered XTI/XNG D1 data; no ML/banned indicator; exact dedup CLEAN."
---

# XTI/XNG Long-Horizon Commodity Value Rank

## Source

Asness, Clifford S.; Moskowitz, Tobias J.; and Pedersen, Lasse Heje (2013),
"Value and Momentum Everywhere", *The Journal of Finance* 68(3), 929-985,
DOI https://doi.org/10.1111/jofi.12021. The full paper and Internet Appendix
were reviewed.

## Mechanical Rule

- Run one logical basket from `XTIUSD.DWX` D1 with `XNGUSD.DWX` as slot 1.
- On the first tradable D1 bar of each broker month, reconstruct each leg's
  latest completed close and the 13 completed month-end closes at inclusive
  lags 54 through 66 months.
- Compute `ln(mean(anchor_closes) / latest_close)` for each leg.
- Buy the higher-value leg and short the lower-value leg; stay flat on a tie or
  any stale/missing endpoint.
- Split `RISK_FIXED=1000` equally and attach a frozen `ATR(20) * 3.5` hard stop
  to each leg.
- Close at the next month transition, after 35 days, or on orphan/invalid
  package repair. Friday close is disabled only for the monthly hold.

## Non-Duplicate And Risk Boundary

This is not commodity RSI (`QM5_12567`), six-month/52-week reversal, raw
XTI/XNG momentum, return-spread reversion, carry, calendar history, skewness,
momentum/reversal disagreement, or trend-confirmed momentum. Unlike
`QM5_12919`, it is pure commodity value on a paired XTI/XNG carrier and uses
the source's 4.5-5.5-year anchor average rather than a single 60-month
endpoint.

The paper uses 27 futures; this two-CFD carrier is a falsification test and
does not import source performance. Q02 retires it below five completed
packages/year or on insufficient 66-month history. Q09 alone judges realized
portfolio correlation.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`. No live setfile, `T_Live`,
AutoTrading, deploy manifest, portfolio gate, or admission artifact is allowed.

Full canonical card: `strategy-seeds/cards/energy-val-rank_card.md`.
