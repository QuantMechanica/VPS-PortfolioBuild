---
ea_id: QM5_9980
slug: bandy-double-top-formalised-mr-index
type: strategy
source_id: 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
sources:
  - "[[sources/bandy-quantitative-technical-analysis]]"
concepts:
  - "[[concepts/chart-pattern]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/pivot-high]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
period: D1
g0_status: APPROVED
expected_trades_per_year_per_symbol: 6
last_updated: 2026-05-19
r1_track_record: PASS
r1_reasoning: "Single source_id present; Bandy QTA cited with ISBN and Google Books URL providing traceable lineage."
r2_mechanical: PASS
r2_reasoning: "3-bar bilateral pivot-high detection, 2% tolerance band, 3% depth minimum, neckline-break-down confirmation, measured-move target, bearish 200-SMA regime gate, and bounded cat-SL all use explicit numeric thresholds with no discretion."
r3_data_available: PASS
r3_reasoning: "D1 timeframe; testable on SP500.DWX (backtest), NDX.DWX/WS30.DWX (live), FX majors, and XAUUSD — all available on the DWX MT5 feed."
r4_ml_forbidden: PASS
r4_reasoning: "Closed-form pivot detection with fixed tolerance thresholds; no online learning, no martingale, and one position per magic."
g0_approval_reasoning: "R1 PASS Bandy QTA book ISBN+URL; R2 PASS deterministic pivot/tolerance/neckline entry plus target/SL/time exit with 6 trades/year/symbol estimate; R3 PASS DWX indices/FX/XAU testable with SP500 backtest caveat; R4 PASS fixed-rule non-ML one-position-per-magic."
---

# Bandy Double-Top (M-Pattern) — Mechanically Formalised

## Quelle
- Source: [[sources/bandy-quantitative-technical-analysis]]
- Book: Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 978-0-9791037-7-1.
- Citation: Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 978-0-9791037-7-1, URL: https://books.google.com/books?isbn=9780979103771
- Bandy in QTA argues that the discretionary "double-top" / "M-pattern" can be made R2-mechanical with three deterministic primitives in the same manner as the W-pattern (double-bottom): (i) a fixed-lookback swing-high pivot definition, (ii) a similarity tolerance band on the second top's height, and (iii) a neckline-break-down confirmation. This card cardifies the **bearish mirror** of QM5_9947 (double-bottom long entry) — same pivot-detection state machine, opposite direction. Period: D1. The Bandy contribution captured here is the deterministic pivot-detection + tolerance-band + neckline-break-down rule wrap that turns the discretionary bearish chart pattern into a backtest-able short-entry signal under a bear-regime gate.
- Substrate attribution: Edwards & Magee, "Technical Analysis of Stock Trends" (Magee 1948, multiple revisions; ISBN 9781578660308) — canonical chart-pattern source for both W and M patterns. Bandy contribution captured here is the deterministic rule wrap (mirror of QM5_9947's W-pattern wrap).
- PDF not on local disk; attribution by author + title under relaxed R1 + URL on citation line.
- Distinct from QM5_9947 (W-pattern long entry, bullish regime, bullish target), QM5_9728 (three-down-closes raw price-sequence MR — slug-locked rejected), and all other prior Bandy batch cards. Same pivot-detection state machine as 9947, opposite direction.

## Mechanik

Period: D1.

### Entry
On each daily close, evaluate the pattern over the most recent 60 closed bars:
1. **Pivot detection.** A bar at index `i` is a swing-high pivot iff `high[i] > max(high[i-3], high[i-2], high[i-1], high[i+1], high[i+2], high[i+3])` (3-bar bilateral pivot, fixed; mirror of 9947's swing-low pivot). Bars within the last 3 sessions cannot be confirmed pivots yet — only pivots with 3 forward bars of clearance count.
2. **Pattern criteria.** Find the most recent two confirmed pivot-highs `P1` (older) and `P2` (newer) within the 60-bar lookback. Conditions:
   - `P2 - P1 ≥ 10 bars` AND `P2 - P1 ≤ 50 bars` (well-separated, not noise).
   - `|high[P2] - high[P1]| / high[P1] ≤ 0.02` (second top within 2% of first top's price — Bandy's tolerance band, mirror of 9947).
   - Lowest low between `P1` and `P2`, call it `neckline_low` at bar `M`, satisfies `(max(high[P1], high[P2]) - neckline_low) / max(high[P1], high[P2]) ≥ 0.03` (pattern depth ≥ 3%, weeds out flat noise).
   - `close < neckline_low` on the current bar (today is the breakdown-confirmation bar).
3. **Regime gate.** `close < SMA(200)` (short-only on bearish regime; mirror of 9947's `close > SMA(200)` long-regime requirement).
4. **Entry.** All four conditions true → enter short at next bar's open. One position per magic.
- No long side (M-pattern is the bearish version; the bullish W-pattern lives in QM5_9947).

### Exit
- **Target.** Profit target = entry − `(max(high[P1], high[P2]) - neckline_low)` (the "pattern height" projected down from neckline — classic Edwards & Magee measured-move). When `low <= target_price`, close at next bar's open.
- **Time stop.** 20 trading days from entry if neither target nor SL fires.
- **Stop loss** (catastrophic): see below.

### Stop Loss
- Catastrophic SL: `max(high[P1], high[P2]) + 0.5 * ATR(14)` — the half-ATR buffer above the pattern's highest top. The M-pattern is invalidated if price closes above either top; the half-ATR buffer absorbs intra-bar noise (mirror of 9947's `min - 0.5×ATR`).
- Soft cap: cat-SL is bounded to be no further than `3.5 * ATR(14)` above entry, in case the pattern highs happen to be far above current price.

### Position Sizing
P2: fixed $1,000 risk based on the distance from entry to the cat-SL price (variable per signal). Live: `RISK_PERCENT` with same distance.

### Zusätzliche Filter
- Skip on incomplete daily bar.
- Skip when `neckline_low` is more than 60 bars before current bar (forces "recent" patterns only).
- Honour news-blackout window (per framework news-calendar seed).
- One position per magic; no pyramiding.
- Primary universe is indices (SP500.DWX / NDX.DWX / WS30.DWX) where the chart-pattern substrate is most thoroughly studied; also testable on FX majors and XAUUSD where short MR is operationally normal (a notable departure from the long-only index-MR family — the M-pattern is inherently a bearish setup).
- P3 sweep candidates: pivot-lookback `{3, 5, 7}` bars; tolerance-band `{0.01, 0.02, 0.03, 0.05}`; min-pattern-depth `{0.02, 0.03, 0.05, 0.08}`; regime SMA `{100, 200, 300}`; cat-SL ATR buffer `{0.3, 0.5, 1.0}`.

## Concepts
- [[concepts/chart-pattern]] — primary
- [[concepts/mean-reversion]] — secondary

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Bandy book + ISBN + URL; substrate attribution Edwards & Magee 1948 documented in Quelle. Mirror-pattern of approved QM5_9947 (same rule-wrap construction). |
| R2 Mechanical | PASS | All four pattern conditions, target/SL/time exit, and bearish regime gate use named numerical thresholds. Pivot definition is bilateral closed-form (same 3-bar-bilateral definition as 9947). 2% tolerance / 3% depth / 60-bar lookback / 10-50 bar separation thresholds explicit and P3-sweepable. |
| R3 Data Available | PASS | D1 timeframe; chart pattern is asset-class-independent. Primary symbols SP500.DWX backtest + NDX.DWX / WS30.DWX live; also testable on FX majors and XAUUSD (short-MR is operationally normal on FX/CFD). |
| R4 ML Forbidden | PASS | Closed-form pivot detection + fixed tolerance thresholds; no learning, no martingale, no scale-in, one position per magic. |

## R3
**Live promotion T_Live gate:** SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T_Live deploy requires parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. Board Advisor's T_Live-gate enforcement.

## Target Symbols
SP500.DWX (backtest), NDX.DWX, WS30.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX. Daily (D1) bars only.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from Bandy QTA Batch 11.

## Verwandte Strategien
- [[strategies/QM5_9947_bandy-double-bottom-formalised-mr-index]] — direct mirror: same 60-bar lookback, 3-bar-bilateral pivot definition, 2% tolerance, 3% depth, neckline-break confirmation, 20-day time stop, measured-move target — but bullish direction with swing-LOW pivots and bull-regime gate.
- [[strategies/QM5_9728_bandy-three-down-closes-mr-index]] — slug-locked rejected raw price-sequence pattern; same family, simpler substrate.
- [[strategies/QM5_9907_bandy-bbands-midband-reversion-mr-index]] — long-only index MR with band substrate; head-to-head bullish-MR vs. bearish-pattern-MR comparison on the same index universe.

## Lessons Learned (während Pipeline-Lauf)
- TBD

## Build-EA Notes
- **Pivot detection state**: same 3-bar-bilateral search as QM5_9947 but with `high[]` instead of `low[]` and `>` instead of `<`. The pivot scanner can share code with 9947 — parameterise on direction.
- **Confirmed-pivot lag**: a bar at index `i` becomes confirmed only when bar `i+3` closes. Encoded as `s >= 3` from current bar.
- **Tolerance comparison**: `|high[P2] - high[P1]| / high[P1]` uses the older top as the denominator (same convention as 9947's low denominator).
- **Neckline_low search**: iterate bars from `P1+1` to `P2-1` for `min(low[i])`.
- **No iCustom shortcut for pivot detection**: must be implemented in EA's bar-close handler — no standard MT5 indicator matches this 3-bilateral definition. P1 reviewer to confirm.
- Same-bar entry guard: breakdown confirmation at today's close; entry fills at next bar's open. No same-bar look-ahead.
- **Short-side execution on indices**: the EA must handle short orders on Darwinex CFD indices. This card is the first short-only strategy in this source's batches — operationally normal on FX/CFD but worth flagging for the build reviewer to confirm the framework's order-side handling is correct.
