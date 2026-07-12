---
copy_of: strategy-seeds/cards/xau-xag-qc_card.md
strategy_id: SCHWEIKERT-QC-2018_XAU_XAG_S01
source_id: SCHWEIKERT-QC-2018
ea_id: QM5_13205
slug: xau-xag-qc
status: APPROVED
g0_status: APPROVED
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
logical_symbol: QM5_13205_XAU_XAG_QC_D1
period: D1
---

# Build-Time Card Reference

Canonical rules: `strategy-seeds/cards/xau-xag-qc_card.md`.

The build must retain exact constrained 10/50/90 conditional-quantile
coefficients from asymmetric check loss, a monthly 504-pair fit with one
held-out signal pair, weekly conditional-envelope signals, the QM-defined
positive beta-span gate, beta-target notional sizing scaled to one fixed-risk
stop budget, conditional-median/time exits, and two-leg lifecycle repair.

Mid-month restarts reconstruct the exact first-host-bar-of-month anchored
model rather than sliding the frozen window. A persisted broker-week attempt
marker is written before either leg so full broker rejection remains
restart-safe even when no deal exists.

The source supplies structural state-dependent lineage only. It does not
supply the QM thresholds or a profitable trading claim. No live or portfolio
artifact is authorized.
