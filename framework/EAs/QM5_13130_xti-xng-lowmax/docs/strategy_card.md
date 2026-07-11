---
strategy_id: HOLLSTEIN-MAX-2021_XTI_XNG_S01
source_id: HOLLSTEIN-MAX-2021
ea_id: QM5_13130
slug: xti-xng-lowmax
status: APPROVED
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_13130_XTI_XNG_LOWMAX_D1
period: D1
---

# Approved Build Reference - QM5_13130 XTI/XNG Low-MAX

Canonical card: `strategy-seeds/cards/xti-xng-lowmax_card.md`.

On the first tradable XTI D1 bar of each broker month, use 253 completed closes
to calculate exactly 252 simple returns for XTI and XNG. Sort each return
vector, average the five largest observations, buy the lower-MAX leg, and
short the higher-MAX leg.

Split `RISK_FIXED=1000` equally, attach frozen `ATR(20) * 3.5` hard stops, and
close at the next month transition, after 35 days, or on orphan/invalid
composition. Current positions and entry deals suppress same-month re-entry.

The paper's full-sample and two-portfolio MAX results are null; direction comes
only from its post-financialization subsample ending in 2015. Q02 is therefore
a genuine out-of-sample test of a narrow two-CFD carrier. No source performance,
portfolio admission, or live action is authorized.
