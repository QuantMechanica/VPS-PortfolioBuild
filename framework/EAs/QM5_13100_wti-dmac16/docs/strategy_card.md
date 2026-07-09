---
copy_of: strategy-seeds/cards/approved/QM5_13100_wti-dmac16_card.md
ea_id: QM5_13100
slug: wti-dmac16
source_id: SZAKMARY-WTI-DMAC16-2010
status: APPROVED
---

# Strategy Card Copy - QM5_13100_wti-dmac16

Build-time reference for
`strategy-seeds/cards/approved/QM5_13100_wti-dmac16_card.md`.

The EA evaluates `XTIUSD.DWX` once per broker-calendar month. It compares the
latest completed month-end close with the arithmetic mean of six completed
month-end closes, holds long above a 2.5% upper band, short below a 2.5% lower
band, and flat inside the neutral zone. A frozen ATR hard stop provides the V5
fixed-risk distance; there is no take-profit or daily crossover.

Q02 uses `RISK_FIXED=1000` and `RISK_PERCENT=0`. Friday close is explicitly
disabled to preserve the source's month-to-month holding rule. No live file,
T_Live manifest, deploy manifest, portfolio gate, or AutoTrading state is
touched.
