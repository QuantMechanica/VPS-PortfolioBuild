---
ea_id: QM5_1249
slug: hsu-carry-stop
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/currency-carry]]"
  - "[[concepts/stop-loss]]"
indicators:
  - "[[indicators/rate-differential]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; SSRN URL with named academic authors Hsu-Taylor-Wang 2019 provides clear lineage."
r2_mechanical: PASS
r2_reasoning: "Rate-differential ranking, monthly rebalance, and fixed ATR stop are deterministic rules Codex can implement."
r3_data_available: PASS
r3_reasoning: "Target carry pairs are standard DWX FX instruments; strategy stays flat when the rates CSV is missing."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed carry ranking and fixed ATR stop; no ML, online learning, martingale, or multiple positions per magic."
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "Hsu-Taylor-Wang 2019 FX carry with fixed ATR stop on 6 DWX JPY/USD-cross pairs; mechanical monthly rate-diff rank (stays flat if rates CSV missing); R1-R4 PASS"
---

# Hsu-Taylor-Wang FX Carry With Fixed Stop

## Quelle
- Source: [[sources/ssrn-financial-economics-network]]
- URL: https://ssrn.com/abstract=3158101
- Named source author: Po-Hsuan Hsu, Mark P. Taylor, Zigan Wang, "The Out-of-Sample Performance of Carry Trades" (2019).
- Location: SSRN abstract states that the paper investigates out-of-sample profitability of carry-trade strategies, including stop-loss strategies, across 48 currencies from 1983 to 2015.

## Mechanik

### Entry
1. Trade DWX major carry pairs with available monthly short-rate CSV: `AUDJPY.DWX`, `NZDJPY.DWX`, `GBPJPY.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`.
2. On the first trading day of each month, compute each pair's interest-rate differential from a deterministic monthly rates CSV.
3. Open LONG pairs where base-currency rate minus quote-currency rate ranks in the top 2 and is positive.
4. Open SHORT pairs where base-currency rate minus quote-currency rate ranks in the bottom 2 and is negative.

### Exit
- Rebalance monthly; close pairs that leave the top/bottom 2 or whose differential crosses zero.
- Close immediately on fixed stop-loss hit.

### Stop Loss
- Fixed stop at `2.5 * ATR(D1, 20)` from entry.
- After a stopped trade, do not re-enter the same symbol until the next monthly rebalance.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per active pair.
- Live: `RISK_PERCENT = 0.25` per active pair.

### Zusätzliche Filter
- If the monthly rates CSV is missing or stale, stay flat.
- Optional P3 filter: block new carry entries when basket realized volatility over 20 D1 bars exceeds its 252-day 80th percentile.
- P3 sweep: rank count `{1, 2, 3}`, ATR stop `{2.0, 2.5, 3.0}`, rebalance `{monthly, quarterly}`.

## Concepts (was ist das für eine Strategie)
- [[concepts/currency-carry]] - primary
- [[concepts/stop-loss]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Verifiable SSRN URL with named academic authors and institutions. |
| R2 Mechanical | UNKNOWN | Rate-differential ranking, monthly rebalance, and fixed ATR stop are deterministic. |
| R3 Data Available | UNKNOWN | DWX has the FX pairs, but carry ranking requires an OWNER-provided deterministic monthly short-rate CSV. |
| R4 ML Forbidden | UNKNOWN | Fixed carry ranking and fixed stop-loss; no ML, online learning, adaptive allocation, martingale, or unbounded grid. |

## Pipeline-Verlauf
- G0: 2026-05-18, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1127_menkhoff-carry-vol-filter]] - carry strategy with global FX-volatility on/off gate.
- [[strategies/QM5_1203_ananta-fx-rate-diff]] - rate-differential momentum implementation pattern.

## Lessons Learned (während Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`.*
