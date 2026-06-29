---
ea_id: QM5_12807
slug: xng-52w-anchor
source_id: BIANCHI-COMM-52W-2016
g0_status: APPROVED
status: APPROVED
period: D1
target_symbols: [XNGUSD.DWX]
---

# Natural Gas 52-Week Anchor Momentum

Build-time card copy. Canonical source:
`strategy-seeds/cards/approved/QM5_12807_xng-52w-anchor_card.md`.

Monthly D1 `XNGUSD.DWX` 52-week high/low anchor momentum:

- BUY when the prior close is at least `strategy_anchor_long_min` of the
  252-D1 closing high and 63-D1 return is positive beyond the threshold.
- SELL when the prior close is no more than `strategy_anchor_short_max` times
  the 252-D1 closing low and 63-D1 return is negative beyond the threshold.
- Exit on monthly rebalance or max hold; use ATR hard stop.

R1-R4: PASS/PASS/PASS/PASS. Runtime uses DWX OHLC only.
