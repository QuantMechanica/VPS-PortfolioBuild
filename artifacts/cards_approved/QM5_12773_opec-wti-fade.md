---
ea_id: QM5_12773
slug: opec-wti-fade
type: strategy
source_id: OPEC-WTI-POSTFADE-2026
g0_status: APPROVED
---

# OPEC WTI Post-Window Impulse Fade

Canonical approved card:
`strategy-seeds/cards/approved/QM5_12773_opec-wti-fade_card.md`.

Summary: D1 `XTIUSD.DWX` post-OPEC fade. It requires a qualifying June/December
event-window impulse during days 1-14, then fades stretched same-direction
follow-through during days 15-24 using only Darwinex OHLC, broker calendar,
SMA, and ATR. This is distinct from `QM5_12598_opec-wti-brk`, which follows
breakouts inside the event window.
