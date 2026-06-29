---
ea_id: QM5_12771
slug: wti-thu-prem
source_id: QUAY-WTI-DOW-2019
target_symbols: [XTIUSD.DWX]
period: D1
g0_status: APPROVED
---

# WTI Thursday Calendar Premium

This is the EA-local copy of the approved strategy card at
`strategy-seeds/cards/approved/QM5_12771_wti-thu-prem_card.md`.

## Entry

- BUY `XTIUSD.DWX` on a new broker-calendar Thursday D1 bar.
- Use ATR(20) on completed D1 bars for the hard stop.

## Exit

- Stop loss: ATR * 2.25.
- Flatten on the first non-Thursday D1 bar or after one calendar day.

## Risk

- Q02 setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- One position per magic, no grid, no martingale, no ML, no external feeds.
