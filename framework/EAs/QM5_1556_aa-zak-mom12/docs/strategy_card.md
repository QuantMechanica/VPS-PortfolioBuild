---
ea_id: QM5_1556
slug: aa-zak-mom12
type: strategy
source_id: ede348b4-0fa7-5be1-baa8-09e9089b67b7
g0_status: APPROVED
---

# Alpha Architect Zakamulin 12-Month Momentum Timing

Build-time reference copy. Canonical runtime card:
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_1556_aa-zak-mom12.md`.

Framework alignment:

- no_trade: D1 chart guard and strategy parameter guard.
- trade_entry: first-D1-bar monthly rebalance, D1 252-bar momentum ratio above 100, one long position per symbol/magic, ATR stop.
- trade_management: no trailing, scaling, martingale, or grid.
- trade_close: first-D1-bar monthly signal flip to cash when momentum is no longer positive.
- news_hook: delegates to the central V5 news filter.
