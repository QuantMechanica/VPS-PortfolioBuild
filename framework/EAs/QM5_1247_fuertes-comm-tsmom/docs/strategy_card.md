---
ea_id: QM5_1247
slug: fuertes-comm-tsmom
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/commodity-momentum]]"
  - "[[concepts/term-structure]]"
indicators:
  - "[[indicators/rate-of-change]]"
  - "[[indicators/term-spread]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "Fuertes-Miffre-Rallis JBF 2010 mom+term-structure double-sort; deterministic with curve CSV (stays flat if missing); R1-R4 PASS"
---

# Fuertes-Miffre-Rallis Commodity Momentum Term-Structure Filter

## Quelle
- Source: [[sources/ssrn-financial-economics-network]]
- URL: ssrn.com/abstract=1127213
- Named source author: Ana-Maria Fuertes, Joelle Miffre, Georgios Rallis, "Tactical Allocation in Commodity Futures Markets: Combining Momentum and Term Structure Signals" (Journal of Banking and Finance, 2010).
- Location: SSRN abstract states that the paper combines momentum and term-structure signals in commodity futures and reports stronger abnormal return for the double-sort strategy than for either signal alone.

## Mechanik

### Entry
1. Trade `XAUUSD.DWX`, `XAGUSD.DWX`, and `XTIUSD.DWX` only when a monthly deterministic futures-curve CSV is present for each commodity root.
2. On the first trading day of each month, compute:
   - `mom = trailing_12m_return` from DWX daily closes.
   - `term_spread = near_contract_price / deferred_contract_price - 1` from the external curve CSV.
3. Rank symbols by combined score `score = rank(mom) + rank(term_spread)`.
4. Open LONG on the highest combined-score symbol if `mom > 0` and `term_spread > 0`.
5. Open SHORT on the lowest combined-score symbol if `mom < 0` and `term_spread < 0`.

### Exit
- Rebalance monthly; close legs that no longer meet top/bottom rank and sign conditions.
- Close any leg immediately if either signal flips sign against the position at a monthly check.

### Stop Loss
- Hard stop at `3.0 * ATR(D1, 20)` from entry.
- No averaging down; one position per symbol/magic.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per active leg.
- Live: `RISK_PERCENT = 0.25` per active leg.

### Zusätzliche Filter
- If the futures-curve CSV is missing or stale, the EA must stay flat.
- Require at least 252 daily bars for momentum.
- P3 sweep: momentum window `{6, 9, 12}` months; term-spread sign threshold `{0, 0.5%, 1.0%}`.

## Concepts
- [[concepts/commodity-momentum]] - primary
- [[concepts/term-structure]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Verifiable SSRN URL; named authors; Journal of Banking and Finance publication lineage. |
| R2 Mechanical | UNKNOWN | Monthly momentum/term-spread ranks and exits are deterministic. |
| R3 Data Available | UNKNOWN | DWX can trade commodity CFDs, but the source's futures-curve signal requires an OWNER-provided deterministic monthly curve CSV; without it, implementation stays flat. |
| R4 ML Forbidden | UNKNOWN | Fixed-form double-sort rule; no learning, adaptive online coefficients, martingale, or grid. |
