---
ea_id: QM5_9923
slug: bandy-hma-crossover-trend
type: strategy
source_id: 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
sources:
  - "[[sources/bandy-quantitative-technical-analysis]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/regime-filter]]"
indicators:
  - "[[indicators/hma]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
period: D1
g0_status: APPROVED
expected_trades_per_year_per_symbol: 16
last_updated: 2026-05-19
r1_track_record: PASS
r1_reasoning: Single source_id (Bandy QTA ISBN 9780979183850 + URL) with explicit Hull 2005 HMA substrate attribution; lineage unambiguous.
r2_mechanical: PASS
r2_reasoning: HMA crossover periods, 200-SMA regime gate, Chandelier ATR trail formula, and 60-day time stop are all numeric and fully Codex-implementable.
r3_data_available: PASS
r3_reasoning: D1 trend logic ports to FX majors, XAUUSD, NDX.DWX, WS30.DWX, and oil CFDs — all live-routable on Darwinex.
r4_ml_forbidden: PASS
r4_reasoning: HMA is a closed-form WMA composition; fixed periods, one position per magic, no martingale, no adaptive learning.
pipeline_phase: G0
g0_approval_reasoning: "R1 PASS: Bandy book ISBN+URL cited; R2 PASS: deterministic HMA cross/regime/chandelier/time-stop with ~16 trades/year/symbol; R3 PASS: D1 trend logic portable to DWX FX/XAU/oil/indices; R4 PASS: fixed-rule non-ML one-position-per-magic."
---

# Bandy HMA Crossover Trend (Long/Short)

## Quelle
- Source: [[sources/bandy-quantitative-technical-analysis]]
- Book: Howard B. Bandy, "Quantitative Technical Analysis: An Integrated Approach to Trading System Development and Trade Management", Blue Owl Press, 2015, ISBN 9780979183850.
- Citation: Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 9780979183850, URL: https://books.google.com/books/about/Quantitative_Technical_Analysis.html?id=LTJJngEACAAJ
- Bandy in QTA's MA-system chapter compares lag-reduced moving averages (EMA, DEMA, TEMA, ZLEMA, HMA) for their whipsaw/responsiveness trade-off. Bandy's framing: HMA (Alan Hull, 2005) is the most aggressive lag-reduction MA via the construction `HMA(n) = WMA(2*WMA(close, n/2) - WMA(close, n), sqrt(n))` — it's a WMA of (twice-the-half-WMA minus full-WMA), with the outer smoothing length equal to the square root of the full lookback. This card captures Bandy's HMA(9)/HMA(21) crossover trend variant with the 200-SMA regime gate + ATR-Chandelier trailing stop overlay. Distinct from QM5_9910 (TEMA-ADX-crossover), QM5_9914 (ZLEMA-distance-trend), and QM5_9915 (SMA-cross with Donchian confirmation, slug-locked rejected) by substrate; HMA's square-root outer smoothing makes the indicator response visibly different from TEMA's nested-EMA-correction.
- Substrate attribution: Alan Hull, "Active Investing: A Complete Answer", Wrightbooks 2005, ISBN 0731404211; WMA substrate is generic; ATR from Wilder 1978. Bandy's contribution is the HMA(9)/HMA(21) parameter pairing with the regime+trail composite — these specific period choices and stop overlay are not in Hull's original publication, which presented HMA as a single fast trend gauge rather than a crossover system.
- PDF not on local disk; attribution by author + title under relaxed R1.

## Mechanik

Period: D1.

### Entry
On each daily close of the target instrument:
- Compute `hma_fast = HMA(close, 9)`, `hma_slow = HMA(close, 21)` (Hull MA formula above).
- Compute `regime = SMA(close, 200)`.
- Long entry at next bar's open if `hma_fast` crosses above `hma_slow` AND `close > regime`.
- Short entry at next bar's open if `hma_fast` crosses below `hma_slow` AND `close < regime`.
- One position per magic; reversal allowed only by first closing the open side.

### Exit
- Long: exit on opposite HMA cross OR Chandelier trail hit OR time stop.
- Short: mirror.
- Time stop: 60 trading days.
- P3 sweep candidates: HMA fast `7 / 9 / 12`; HMA slow `18 / 21 / 26`; regime SMA `100 / 200 / 300`; Chandelier ATR mult `2.0 / 2.5 / 3.0`; time stop `45 / 60 / 90`.

### Stop Loss
Chandelier trailing stop: long stop = `HHV(high, 22) - 2.5*ATR(14)`; short stop = `LLV(low, 22) + 2.5*ATR(14)`. Stop ratchets only in the direction of the trade.

### Position Sizing
P2: fixed $1,000 risk based on the initial Chandelier-stop distance. Live: `RISK_PERCENT`.

### Zusätzliche Filter
- Skip on incomplete daily bar.
- One position per magic; long/short mutually exclusive.
- Optional P3 filter: require `|hma_fast - hma_slow|/atr14 >= 0.25` on the cross bar (separation gate — prevents fast-slow ties from firing on micro-pivots).

## Build-EA Notes
HMA is not a native MT5 indicator. Codex must implement HMA explicitly:
1. `wma_half = iCustom(... WMA, length=n/2)` or inline weighted-MA loop.
2. `wma_full = iCustom(... WMA, length=n)` or inline.
3. `raw = 2*wma_half - wma_full`.
4. `hma = WMA(raw, sqrt(n))` (sqrt rounded to int).

For `n=9`, the half-WMA length is 4 (rounded) or 5 (rounded up — pick a deterministic convention), full-WMA length is 9, outer-WMA length is 3. For `n=21`, half is 10 or 11, full is 21, outer is 5 (sqrt(21)≈4.58). P1 reviewer should confirm the rounding convention is documented and used consistently.

## Concepts
- [[concepts/trend-following]] — primary
- [[concepts/regime-filter]] — secondary

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named Bandy book + ISBN + URL; Hull HMA substrate (2005) explicit in Quelle. |
| R2 Mechanical | PASS | Explicit HMA periods, regime gate, Chandelier trail formula, time stop. |
| R3 Data Available | PASS | Daily timeframe; testable on FX majors, XAUUSD, oil CFD, live-routable index CFDs (NDX.DWX, WS30.DWX). SP500.DWX backtest-optional. |
| R4 ML Forbidden | PASS | HMA is a closed-form deterministic weighted-MA composition; not adaptive learning. Fixed parameters; one position per magic; no martingale; no scale-in. |

## R3
Multi-instrument portable; not SP500-only. **Live promotion T_Live gate:** SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T_Live deploy requires parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. The primary symbol set is FX/XAU/NDX/WS30/oil, where the caveat is moot.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from Bandy QTA Batch 7.

## Verwandte Strategien
- [[strategies/QM5_9910_bandy-tema-adx-crossover-trend]] — TEMA(8)/TEMA(21) — sibling lag-reduced MA, has ADX gate.
- [[strategies/QM5_9914_bandy-zlema-distance-trend]] — ZLEMA — sibling lag-reduced MA, distance-from-MA trigger.
- [[strategies/QM5_9911_bandy-donchian-20-classic-breakout-trend]] — Donchian breakout — no MA-cross trigger.

## Lessons Learned (während Pipeline-Lauf)
- TBD
