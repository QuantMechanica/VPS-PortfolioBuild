---
ea_id: QM5_12777
slug: wti-dec-fade
source_id: QUAY-WTI-DEC-2019
target_symbols: [XTIUSD.DWX]
period: D1
g0_status: APPROVED
---

# WTI December Calendar Fade

This is the EA-local copy of the approved strategy card at
`strategy-seeds/cards/approved/QM5_12777_wti-dec-fade_card.md`.

## Entry

- SELL `XTIUSD.DWX` on a new broker-calendar December D1 bar.
- Use ATR(20) on completed D1 bars for the hard stop.

## Exit

- Stop loss: ATR * 2.25.
- Flatten on the first post-entry D1 bar, when December ends, or after one
  calendar day.

## Risk

- Q02 setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- One position per magic, no grid, no martingale, no ML, no external feeds.

