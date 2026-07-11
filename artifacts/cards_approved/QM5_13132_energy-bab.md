---
strategy_id: FRAZZINI-BAB-2014_XTI_XNG_S01
source_id: FRAZZINI-BAB-2014
ea_id: QM5_13132
slug: energy-bab
status: APPROVED
g0_status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
source_citation: "Frazzini and Pedersen (2014), Betting Against Beta, Journal of Financial Economics 111(1), 1-25, DOI 10.1016/j.jfineco.2013.10.005; NBER Working Paper 16601."
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
period: D1
logical_symbol: QM5_13132_XTI_XNG_BAB_D1
expected_trade_frequency: "One monthly beta-matched XTI/XNG package after 258 completed closes; approximately 12 completed packages/year."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.03
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
g0_approval_reasoning: "OWNER mission 2026-07-11: complete peer-reviewed source and appendices; exact one-year Dimson beta with five lags, 0.5 shrinkage, monthly low-beta-long/high-beta-short package, beta-matched fixed-risk sizing, ATR stops, and restart-safe no-reentry; native registered XTI/XNG data; no ML/banned logic; manual dedup CLEAN before atomic allocation."
---

# XTI/XNG Betting Against Beta

On the first tradable XTI D1 bar of each broker month, form a two-leg
inverse-volatility energy benchmark, estimate 252-observation Dimson betas for
XTI and XNG with five benchmark lags, shrink each beta halfway toward one, buy
the lower-beta leg, and short the higher-beta leg.

Target inverse-beta notional exposure by splitting `RISK_FIXED=1000` in
proportion to relative ATR divided by beta. Reject a package if broker lot
rounding leaves more than 20% relative beta-exposure mismatch. Both legs carry
frozen `ATR(20) * 3.5` hard stops and close at the next month transition,
after 35 days, or on orphan/invalid composition. Current positions and entry
deal history suppress same-month re-entry.

The source uses 24 commodity futures and excess returns; this port uses only
XTI/XNG continuous CFDs and raw close returns. The commodity-only source
result is statistically weak. Those limits are binding Q02 kill risks.

This is not the existing XTI/XNG momentum, return-spread, carry, value,
same-calendar, skew, kurtosis, MAX, RSJ, momentum-reversal, trend, or breakout
logic, and it has no RSI relation to `QM5_12567`. Existing BAB EAs cover
indices/FX, not an energy package.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`. No live artifact, T_Live,
AutoTrading, deploy manifest, portfolio gate, or admission change is approved.

Full canonical card: `strategy-seeds/cards/energy-bab_card.md`.

Q01 compile/build checks passed with zero errors and warnings on 2026-07-11.
Q02 work item `92097f32-58bb-4c86-9b54-5ee371716499` is pending and unclaimed.
