---
ea_id: QM5_20091
slug: pricebob-extreme-reversal-fade-gdaxi
type: strategy
source_id: 68eff294-e3b2-5010-82d8-e9dd5f4130e6
sources:
  - "[[sources/forexfactory-pricebob-strategy-thread-1331012]]"
concepts:
  - "[[concepts/tight-trading-range-breakout]]"
  - "[[concepts/exhaustion-fade]]"
indicators:
  - "[[indicators/consolidation-box-detector]]"
  - "[[indicators/session-range-tracker]]"
g0_status: APPROVED
target_symbols: [GDAXI.DWX]
expected_trades_per_year_per_symbol: 30
last_updated: 2026-07-27
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
g0_approval_reasoning: "R1 single FF lineage retained; R2 deterministic M5 TTR extreme-fade entry and explicit SL/TP/time exit with cadence corrected to 30/year/symbol; R3 directly testable on GDAXI.DWX; R4 deterministic, ML-free, bounded to one position per magic."
expected_pf: 1.15
expected_dd_pct: 20.0
---

# PriceBob "Breakout Mode" — Extreme-of-Session TTR Reversal Fade (Intraday, GDAXI)

## Quelle
- Source: [[sources/forexfactory-pricebob-strategy-thread-1331012]]
- Forex Factory thread "The PriceBob Strategy", https://www.forexfactory.com/thread/1331012-the-pricebob-strategy
  (indexed sub-pages this batch: `?page=28`, `?page=31`, `?page=13`).
  Anonymous forum handles; link-only attribution per relaxed R1
  (2026-05-15/06-30), R1-recovery lane (2026-07-23). Batch 2 of
  resume-mining (see source note).
- Sibling card to `QM5_20090` (same Brooks TTR "Breakout Mode" pattern
  family: inside-inside / outside-inside-inside / inside-outside-inside
  consolidation boxes). This card mines a distinct, thread-attributed
  variant: indexed snippets state that "when there is a 'signal pattern'
  close to the extreme of the day, price tends to reverse" (as opposed to
  continue) — i.e. the same TTR/signal-bar pattern is traded as a
  **reversal (fade)** when it forms near the session's high or low, rather
  than as a continuation breakout. A related snippet mentions signal
  patterns being scored/located using "2 midpoints (1 last-bar mid and the
  average of the candles in the pattern)" — a scoring refinement not
  implemented here (kept as a documented Codex/P3 side-parameter
  possibility, not required for R2 PASS).
- Direct thread text not pulled verbatim (403 on WebFetch/agy, reconfirmed
  this session). Mechanics reconstructed from indexed snippets; treat the
  "near-extreme" proximity threshold as an approximation pending verbatim
  verification.
- **Porting note (R3):** intraday consolidation/exhaustion pattern, not
  fixed-time-anchored; generalizes to any liquid session-traded index or FX
  instrument. Ported to **GDAXI** (DAX) — a European index CFD not yet used
  by any other card in this source's output, chosen for diversification and
  because European index session extremes (post-open expansion into a
  midday/afternoon extreme) are a well-documented analog for this kind of
  exhaustion-fade setup.

## Mechanik

### Entry
- Uses the **same TTR (tight trading range) box detector** as `QM5_20090`:
  N = 4 consecutive M5 bars, each true range `<= 0.6 x ATR(14, M5)`,
  non-expanding envelope (`<= 0.1 x ATR` buffer).
- **Extreme-proximity gate**: only act on a TTR box if it forms within
  `15%` of the current session's range from the session's running high (for
  a short-fade setup) or running low (for a long-fade setup). (Session
  range = running session high minus running session low from session
  open to the current bar.) A TTR box that forms mid-range is **not**
  traded by this card — that is the continuation setup covered by
  `QM5_20090` instead.
- **Fade direction is the opposite of the extreme**: a TTR box near the
  session **high** → place a **sell-stop below the box low** (betting the
  extreme holds and price reverses down). A TTR box near the session
  **low** → place a **buy-stop above the box high** (betting the extreme
  holds and price reverses up). This is the mirror-image order placement
  of `QM5_20090`'s continuation breakout on the identical box.
- Single pending order per detected box (not a bracket — only the
  fade-direction order is placed, since the continuation-direction trade at
  a session extreme is deliberately not this card's setup). One position
  per magic; no new box scanned while a position is open.
- Frequency cap: max **2 fade signals per session** (extremes are, by
  construction, rarer than the general TTR population `QM5_20090` scans).

### Exit
- Take-profit: scaled retracement target back toward the session's
  midpoint — `entry price -+ (0.5 x current session range)` in the fade
  direction, capped at a maximum of `2.0 x TTR box range` (whichever is
  reached first defines the take-profit distance, computed once at entry).
- No trailing stop, no breakeven move.
- Time-stop: flatten at session end if neither TP nor SL is hit.

### Stop Loss
- SL = the recent extreme plus/minus a fixed buffer beyond the box edge
  nearest the extreme (long fade: SL just below the session low that
  triggered the extreme-proximity gate, minus buffer; short fade: SL just
  above the session high, plus buffer) — i.e. the stop sits just beyond the
  extreme itself, since a further push past the extreme invalidates the
  reversal thesis.

### Position Sizing
- P2 baseline: `RISK_FIXED` (HR4). Live: `RISK_PERCENT`.

### Zusätzliche Filter
- Skip TTR boxes with range `< 0.15 x ATR(14, D1)` (same tightness floor as
  `QM5_20090`).
- News filter: skip entries inside the standing high-impact news window
  (exhaustion fades are particularly vulnerable to news-driven range
  extension — this filter matters more here than on the continuation
  sibling).
- Spread filter: skip entry if spread `> 25%` of the TTR box range.

## Concepts
- [[concepts/tight-trading-range-breakout]] — shared pattern detector
- [[concepts/exhaustion-fade]] — primary (reversal-at-extreme interpretation)

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | TIER_C | Anonymous FF thread; link-only attribution sufficient under relaxed R1; never a rejection reason. |
| R2 Mechanical | PASS | Explicit, thread-sourced premise (signal pattern near session extreme -> reversal). Explicit box detector (shared with sibling card), explicit extreme-proximity gate, explicit fade-direction order placement, explicit SL/TP. Exact proximity threshold (15%) and TP scaling are Codex-fill/P3-sweep candidates. |
| R3 Data Available | PASS | GDAXI.DWX, index CFD, confirmed in `dwx_symbol_matrix.csv`. Pattern-based, applies directly to a session-traded index. |
| R4 ML Forbidden | PASS | Deterministic box-detection and extreme-proximity gate (fixed, price-history-only thresholds), bounded to 2 signals/session, single order per box (not a runaway bracket), no ML, no martingale. |

## Pipeline-Verlauf
- G0: 2026-07-23, PENDING, drafted from FF thread 1331012 batch 2 (R1-recovery lane, resume-mining).

## Verwandte Strategien
- [[strategies/QM5_20090_pricebob-ttr-brooks-stoporder-breakout-audusd]] —
  same TTR box detector, opposite trading thesis (continuation breakout,
  anywhere in the session, vs. this card's extreme-only reversal fade).
  Natural A/B pair for P2/P4 comparison.
- [[strategies/QM5_20066_pricebob-atr-gated-lbma-breakout-xauusd]] — a
  different false-breakout-avoidance idea (ATR-gated actionable break)
  applied to the fixed reference-bar family rather than the floating TTR
  pattern family.

## Lessons Learned (während Pipeline-Lauf)
- TBD

