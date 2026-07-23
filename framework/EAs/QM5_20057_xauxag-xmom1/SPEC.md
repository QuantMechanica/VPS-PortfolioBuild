# QM5_20057_xauxag-xmom1 - Strategy Spec

**EA ID:** QM5_20057  
**Slug:** `xauxag-xmom1`  
**Strategy ID:** `FMR-MOMTS-2010_XAU_XAG_S02`

Run one logical basket from `XAUUSD.DWX` D1. At each broker-month transition,
reconstruct two completed month-end closes for XAU and XAG, calculate one
simple monthly returns and their arithmetic average, buy the higher-return leg,
and short the lower-return leg. Close at the next month transition or after 40
days. Split `RISK_FIXED` equally, use frozen ATR hard stops, and flatten orphans.

The canonical rules, source boundary, parameters, kill criteria, and framework
alignment are in `strategy-seeds/cards/xauxag-xmom1_card.md`.
