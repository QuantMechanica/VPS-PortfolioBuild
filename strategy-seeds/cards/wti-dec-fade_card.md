---
ea_id: QM5_12777
slug: wti-dec-fade
type: strategy
source_id: QUAY-WTI-DEC-2019
source_citation: "Quayyum, H. A., Khan, M. A. M. and Ali, S. M. Seasonality in crude oil returns. Soft Computing 24, 7857-7873 (2020). DOI https://doi.org/10.1007/s00500-019-04329-0"
target_symbols: [XTIUSD.DWX]
period: D1
g0_status: APPROVED
---

# WTI December Calendar Fade

Canonical approved card:
`strategy-seeds/cards/approved/QM5_12777_wti-dec-fade_card.md`.

## Hypothesis

WTI late-year calendar weakness may persist strongly enough that December-only
D1 shorts add a distinct low-frequency energy sleeve.

## Rules

- Trade only `XTIUSD.DWX` on D1.
- Sell only during broker-calendar December.
- Exit on the next D1 bar, December end, max-hold guard, Friday close, or ATR
  hard stop.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`; one position per magic; no
grid, martingale, ML, or external runtime data.

