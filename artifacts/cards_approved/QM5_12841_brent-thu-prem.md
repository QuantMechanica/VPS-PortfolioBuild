---
ea_id: QM5_12841
slug: brent-thu-prem
type: strategy
strategy_id: QUAY-WTI-DOW-2019_BRENT_S01
source_id: QUAY-WTI-DOW-2019
source_citation: "Quayyum, H. A., Khan, M. A. M. and Ali, S. M. Seasonality in crude oil returns. Soft Computing 24, 7857-7873 (2020). DOI https://doi.org/10.1007/s00500-019-04329-0"
strategy_type_flags: [calendar-seasonality, day-of-week, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XBRUSD.DWX]
period: D1
g0_status: APPROVED
status: APPROVED
pipeline_phase: Q02
last_updated: 2026-07-01
expected_pf: 1.08
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
---

# Brent Thursday Calendar Premium

Approved copy of `strategy-seeds/cards/approved/QM5_12841_brent-thu-prem_card.md`.

This card mechanizes a deterministic Brent D1 Thursday premium from the
peer-reviewed Quayyum et al. crude-oil day-of-week source. It buys
`XBRUSD.DWX` on broker-calendar Thursday, exits on the next D1 bar or a
one-day stale-position guard, uses a per-trade ATR hard stop, and runs Q02 with
`RISK_FIXED=1000`.

It is not a duplicate of `QM5_12771_wti-thu-prem` because it targets the Brent
benchmark, not WTI. It does not add XAU, SP500, NDX, or XNG exposure and uses no
external runtime feed, ML, grid, martingale, portfolio gate file, live manifest,
or AutoTrading control.
