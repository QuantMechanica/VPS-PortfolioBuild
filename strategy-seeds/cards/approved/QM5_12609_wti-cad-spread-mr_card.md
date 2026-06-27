---
copy_of: strategy-seeds/cards/wti-cad-spread-mr_card.md
ea_id: QM5_12609
slug: wti-cad-spread-mr
g0_status: APPROVED
last_updated: 2026-06-27
---

# WTI CAD Spread Mean Reversion

Approved card copy for `QM5_12609_wti-cad-spread-mr`.

Canonical card: `strategy-seeds/cards/wti-cad-spread-mr_card.md`.

This two-leg D1 basket trades z-score reversion of
`ln(XTIUSD.DWX) + beta * ln(USDCAD.DWX)`. High spread sells both legs; low
spread buys both legs. It is not a duplicate of `QM5_12607_wti-cad-confirm`,
which trades only XTIUSD.DWX and uses USDCAD.DWX as a read-only confirmation
series.
