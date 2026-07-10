---
strategy_id: KISS-RSJ-2025_XTI_XNG_S01
source_id: KISS-RSJ-2025
ea_id: QM5_13129
slug: energy-rsj
status: APPROVED
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_13129_ENERGY_RSJ_D1
period: D1
---

# Approved Build Reference - QM5_13129 Energy RSJ

Canonical card: `strategy-seeds/cards/energy-rsj_card.md`.

On the first XTI D1 bar of each broker month, compute each leg's normalized
relative signed jump from simple close-to-close returns in the immediately
preceding complete month:

`RSJ = (sum_positive_return_squared - sum_negative_return_squared) / sum_all_return_squared`.

Buy the lower-RSJ energy leg and short the higher-RSJ leg. Require 15 valid
returns per leg, split `RISK_FIXED=1000` equally, attach frozen
`ATR(20) * 3.5` hard stops, and close at the next month transition, after 35
days, or on orphan/invalid composition. No same-month re-entry is allowed.

This is a two-CFD carrier of a 36-future source result. It is not the 12-month
Pearson-skew signal in `QM5_13118`, and the source explicitly distinguishes RSJ
from realized skewness. Q02 is the falsification gate; no portfolio admission
or live action is authorized.
