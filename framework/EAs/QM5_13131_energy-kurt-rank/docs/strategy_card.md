---
strategy_id: HOLLSTEIN-MAX-2021_XTI_XNG_S02
source_id: HOLLSTEIN-MAX-2021
ea_id: QM5_13131
slug: energy-kurt-rank
status: APPROVED
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_13131_XTI_XNG_HKURT_D1
period: D1
---

# Approved Build Reference - QM5_13131 Energy Kurtosis Rank

Canonical card: `strategy-seeds/cards/energy-kurt-rank_card.md`.

On the first tradable XTI D1 bar of each broker month, use 253 completed closes
to calculate exactly 252 simple returns for XTI and XNG. Compute source-defined
Pearson historical kurtosis, buy the higher-kurtosis leg, and short the lower-
kurtosis leg.

Split `RISK_FIXED=1000` equally, attach frozen `ATR(20) * 3.5` hard stops, and
close at the next month transition, after 35 days, or on orphan/invalid
composition. Current positions and entry-deal history suppress same-month
re-entry.

The source's directly relevant two-portfolio and regression tests are
insignificant, and its post-financialization spread reverses sign. Q02 is a
genuine out-of-sample test of a narrow two-CFD carrier. No source performance,
portfolio admission, or live action is authorized.
