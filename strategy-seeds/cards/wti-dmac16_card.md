---
copy_of: strategy-seeds/cards/approved/QM5_13100_wti-dmac16_card.md
ea_id: QM5_13100
slug: wti-dmac16
strategy_id: SZAKMARY-WTI-DMAC16-2010
source_id: SZAKMARY-WTI-DMAC16-2010
status: APPROVED
g0_status: APPROVED
target_symbols: [XTIUSD.DWX]
period: D1
pipeline_phase: Q02
last_updated: 2026-07-09
---

# WTI Monthly 1/6 DMAC Neutral-Band Trend

Canonical approved card:
`strategy-seeds/cards/approved/QM5_13100_wti-dmac16_card.md`.

Source-exact monthly rule: compare the latest completed month-end WTI close
with the arithmetic mean of six completed month-end closes. Hold long above a
2.5% upper band, short below a 2.5% lower band, and flat inside the band.

Backtests use `XTIUSD.DWX` D1, `RISK_FIXED=1000`, and no live file. Friday
close is explicitly disabled to preserve the source's month-to-month holding
rule. No portfolio gate, T_Live manifest, deploy manifest, or AutoTrading state
is touched.
