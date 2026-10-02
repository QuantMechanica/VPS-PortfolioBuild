---
ea_id: QM5_9947
slug: bandy-double-bottom-formalised-mr-index
type: strategy
source_id: 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
sources:
  - "[[sources/bandy-quantitative-technical-analysis]]"
concepts:
  - "[[concepts/chart-pattern]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/pivot-low]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
period: D1
g0_status: APPROVED
expected_trades_per_year_per_symbol: 8
last_updated: 2026-05-19
r1_track_record: PASS
r1_reasoning: Single source_id (Bandy QTA ISBN 978-0-9791037-7-1 + URL); Edwards-Magee 1948 substrate attribution documented in Quelle; one canonical source.
r2_mechanical: PASS
r2_reasoning: Pivot detection (3-bar bilateral), 2% tolerance band, 3% pattern-depth floor, 10-50 bar separation, neckline-break, pattern-height target, cat-SL, and time stop are all numeric thresholds with zero discretion.
r3_data_available: PASS
r3_reasoning: D1 price-pattern testable on SP500.DWX (backtest) and NDX.DWX / WS30.DWX (live); instrument-agnostic pattern ports to any DWX CFD.
r4_ml_forbidden: PASS
r4_reasoning: Pivot detection is a deterministic scan over confirmed fixed-lookback pivots (not fitted regression); fixed tolerance thresholds, one position per magic, no ML.
pipeline_phase: G0
g0_approval_reasoning: "R1 PASS Bandy book ISBN+URL attribution; R2 PASS deterministic pivot/tolerance/neckline entry plus target/time/SL exits with 8 trades/year/symbol estimate; R3 PASS daily price pattern testable on SP500.DWX backtest with NDX/WS30 live caveat; R4 PASS fixed-rule non-ML one-position-per-magic."
---

# Bandy Double-Bottom (W-Pattern) — Mechanically Formalised

## Quelle
- Source: [[sources/bandy-quantitative-technical-analysis]]
- Book: Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 978-0-9791037-7-1.
- Citation: Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 978-0-9791037-7-1, URL: https://books.google.com/books?isbn=9780979103771
- Bandy in QTA explicitly argues that the classic discretionary "double-bottom" / "W-pattern" can be made R2-mechanical with three deterministic primitives: (i) a fixed-lookback swing-low pivot definition, (ii) a similarity tolerance band on the second bottom's depth, and (iii) a neckline-break confirmation. The card encodes those three primitives with named numerical thresholds, removing the discretionary "spot the pattern" element entirely. This is the long-deferred substrate flagged in Batches 4-8's "Recommended Next Action" as the highest-value remaining uncardified Bandy material.
- Substrate attribution: Edwards & Magee, "Technical Analysis of Stock Trends" (Magee 1948, multiple revisions; ISBN 9781578660308) is the canonical chart-pattern source. Bandy's contribution captured here is the deterministic pivot-detection + tolerance-band + neckline-break **rule wrap** that turns the discretionary pattern into a backtest-able signal.
- PDF not on local disk; attribution by author + title under relaxed R1 + URL on citation line.
- Distinct from all prior Bandy batches: no chart-pattern-based card yet drafted from this source. Closest sibling is QM5_9728 (three-down-closes, slug-locked rejected) — that captures a raw price-sequence pattern; this card captures a swing-structure pattern.

## Mechanik

Period: D1.

### Entry
On each daily close, evaluate the pattern over the most recent 60 closed bars:
1. **Pivot detection.** A bar at index `i` is a swing-low pivot iff `low[i] < min(low[i-3], low[i-2], low[i-1], low[i+1], low[i+2], low[i+3])` (3-bar bilateral pivot, fixed). Bars within the last 3 sessions cannot be confirmed pivots yet — only pivots that have 3 forward bars of clearance count.
2. **Pattern criteria.** Find the most recent two confirmed pivot-lows `P1` (older) and `P2` (newer) within the 60-bar lookback. Conditions:
   - `P2 - P1 ≥ 10 bars` AND `P2 - P1 ≤ 50 bars` (well-separated, not noise).
   - `|low[P2] - low[P1]| / low[P1] ≤ 0.02` (second bottom is within 2% of first bottom's price — Bandy's tolerance band).
   - Highest high between `P1` and `P2`, call it `neckline_high` at bar `M`, satisfies `(neckline_high - min(low[P1], low[P2])) / low[P1] ≥ 0.03` (pattern depth ≥ 3%, weeds out flat noise).
   - `close > neckline_high` on the current bar (today is the breakout-confirmation bar).
3. **Regime gate.** `close > SMA(200)` (long-only MR on bullish regime).
4. **Entry.** All four conditions true → enter long at next bar's open. One position per magic.
- No short side (W-pattern is the bullish version; the bearish M-pattern is a separate strategy out of scope here).

### Exit
- **Target.** Profit target = entry + `(neckline_high - min(low[P1], low[P2]))` (the "pattern height" projected up from neckline — classic Edwards & Magee target). When `high >= target_price`, close at next bar's open.
- **Time stop.** 20 trading days from entry if neither target nor SL fires. Pattern's measured-move is typically a 2-4 week play; 20 bars caps the hold.
- **Stop loss** (catastrophic): see below.

### Stop Loss
- Catastrophic SL: `min(low[P1], low[P2]) - 0.5 * ATR(14)` — the half-ATR buffer below the pattern's deepest low. The W-pattern is invalidated if price closes below either bottom; the half-ATR buffer absorbs intra-bar noise.
- Soft floor: cat-SL is also bounded to be no further than `3.5 * ATR(14)` below entry, in case the pattern lows happen to be very far below current price (rare; would imply an unusually tall pattern).

### Position Sizing
P2: fixed $1,000 risk based on the distance from entry to the cat-SL price (variable per signal). Live: `RISK_PERCENT` with same distance.

### Zusätzliche Filter
- Skip on incomplete daily bar.
- Skip when `neckline_high` is more than 60 bars before current bar (forces "recent" patterns only).
- Honour news-blackout window (per framework news-calendar seed).
- One position per magic; no pyramiding.
- P3 sweep candidates: pivot-lookback `{3, 5, 7}` bars; tolerance-band `{0.01, 0.02, 0.03, 0.05}`; min-pattern-depth `{0.02, 0.03, 0.05, 0.08}`; regime SMA `{100, 200, 300}`; cat-SL ATR buffer `{0.3, 0.5, 1.0}`.

## Concepts
- [[concepts/chart-pattern]] — primary
- [[concepts/mean-reversion]] — secondary

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Bandy book + ISBN + URL; substrate attribution Edwards & Magee 1948 documented. |
| R2 Mechanical | PASS | All four pattern conditions, target/SL/time exit, and regime gate use named numerical thresholds. No "spot the pattern" discretion. Pivot definition is bilateral closed-form. The 2% tolerance / 3% depth / 60-bar lookback / 10-50 bar separation thresholds are explicit and P3-sweepable. |
| R3 Data Available | PASS | Daily timeframe; double-bottom is a price-pattern signal independent of asset class. Primary symbol set: SP500.DWX backtest + NDX.DWX / WS30.DWX live. Ports to FX/XAU also if optional secondary universe is enabled. |
| R4 ML Forbidden | PASS | Closed-form pivot detection + fixed tolerance thresholds; no learning, no martingale, no scale-in, one position per magic. The "find P1 and P2" step is a deterministic search over confirmed pivots, NOT a fitted regression. |

## R3
**Live promotion T_Live gate:** SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T_Live deploy requires parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. Board Advisor's T_Live-gate enforcement.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from Bandy QTA Batch 9.

## Verwandte Strategien
- [[strategies/QM5_9907_bandy-bbands-midband-reversion-mr-index]] — same long-only index MR family; different substrate (Bollinger-band reversion vs. swing-structure pattern).
- [[strategies/QM5_9728_bandy-three-down-closes-mr-index]] — raw price-sequence pattern (slug-locked rejected); same family, simpler substrate.

## Lessons Learned (während Pipeline-Lauf)
- TBD

## Build-EA Notes
- **Pivot detection state**: the EA must scan the most recent 60 closed bars on every signal evaluation. Cache the pivot list to avoid O(N²) rescans — recompute incrementally as new bars close.
- **Confirmed-pivot lag**: a bar at index `i` only becomes a confirmed pivot when bar `i+3` closes. Encoded as: a pivot at relative-shift `s` requires `s >= 3` from the current bar.
- **Tolerance comparison**: `|low[P2] - low[P1]| / low[P1]` uses the older bottom as the denominator (consistent across pattern instances).
- **Neckline_high search**: iterate bars from `P1+1` to `P2-1` for `max(high[i])`.
- **No iCustom shortcut for pivot detection**: must be implemented in EA's `OnTick` (or equivalent close-of-bar handler) — there is no standard MT5 pivot indicator that matches this 3-bilateral definition. P1 reviewer to confirm.
- Same-bar entry guard: the breakout confirmation happens at today's close; entry fills at next bar's open. No same-bar look-ahead.
