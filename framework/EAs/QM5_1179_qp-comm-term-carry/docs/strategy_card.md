---
ea_id: QM5_1179
slug: qp-comm-term-carry
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-17
card_body_incomplete: true
card_body_missing: "source_citation,target_symbols"
---

# Quantpedia Commodity Term-Structure Carry

## Quelle

- Source: Quantpedia Encyclopedia, "Term Structure Effect in Commodities".
- Named source authors: Quantpedia cites Erb/Harvey, Gorton/Rouwenhorst, Shwayder/James, and related commodity term-structure papers.
- Location: "Simple trading strategy" section.
- External URL intentionally omitted from this local EA copy because the V5 build checker forbids URL patterns inside EA folders.

## Mechanik

### Entry

At the first tradable day of each month:

1. Read a checked-in roll-yield CSV for each approved commodity proxy. Required fields: symbol, month, front_contract_price, next_contract_price, roll_yield.
2. Rank all eligible commodities by prior month roll yield.
3. Open LONG positions in the top 20% highest roll-yield commodities.
4. Open SHORT positions in the bottom 20% lowest roll-yield commodities.
5. Equal-risk each active leg; no more than one position per symbol/magic slot.

### Exit

- Close and rebalance all legs at the next monthly rebalance.
- If fewer than five commodities have valid roll-yield data, skip the month.

### Stop Loss

- Per-leg stop: 2.5x ATR(20) on D1.
- Portfolio safety: aggregate active risk cannot exceed `RISK_FIXED = 1000` in P2 baseline.

### Position Sizing

- P2 baseline: split `RISK_FIXED = 1000` USD equally across active legs.
- Live: split `RISK_PERCENT = 0.25` equally across active legs.

### Zusaetzliche Filter

- Target symbols: XAUUSD.DWX, XTIUSD.DWX, XNGUSD.DWX, XAGUSD.DWX, XCUUSD.DWX, only where approved DWX trade legs and roll-yield signal rows exist.
- Source trades futures; DWX implementation trades spot/CFD proxies using external roll-yield signal data.
- Exclude any commodity without approved DWX trade leg or approved signal-only proxy.
- No dynamic hedge ratio, no futures-curve optimization, no grid/martingale.
