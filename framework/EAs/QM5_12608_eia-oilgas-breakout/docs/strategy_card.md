---
ea_id: QM5_12608
slug: eia-oilgas-breakout
type: strategy
source_id: EIA-OILGAS-BREAKOUT-2026
g0_status: APPROVED
---

# EIA Oil/Gas Ratio Breakout

Build-time reference copy. Canonical card:
`strategy-seeds/cards/eia-oilgas-breakout_card.md`.

Framework alignment:

- no_trade: host chart guard, D1 guard, parameter guard, spread caps.
- trade_entry: two-leg XTI/XNG log-ratio channel breakout.
- trade_management: package integrity only.
- trade_close: spread-average failure exit, max-hold exit, per-leg ATR stops.
