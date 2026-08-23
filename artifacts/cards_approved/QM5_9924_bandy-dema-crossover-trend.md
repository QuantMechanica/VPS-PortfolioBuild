---
ea_id: QM5_9924
slug: bandy-dema-crossover-trend
type: strategy
source_id: 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
sources:
  - "[[sources/bandy-quantitative-technical-analysis]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/regime-filter]]"
indicators:
  - "[[indicators/dema]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
period: D1
g0_status: APPROVED
expected_trades_per_year_per_symbol: 14
last_updated: 2026-05-19
r1_track_record: PASS
r1_reasoning: Single source_id (Bandy QTA ISBN 9780979183850 + URL) with Mulloy 1994 DEMA substrate attribution; one canonical source per card.
r2_mechanical: PASS
r2_reasoning: DEMA fast/slow periods, 200-SMA regime gate, Chandelier ATR trail, and time stop are fully numeric and mechanically implementable.
r3_data_available: PASS
r3_reasoning: D1 trend logic portable to FX majors, XAUUSD, NDX.DWX, WS30.DWX, and oil — all live-routable DWX instruments.
r4_ml_forbidden: PASS
r4_reasoning: DEMA is a closed-form nested-EMA (MT5 native iDEMA); fixed parameters, one position per magic, no adaptive learning.
pipeline_phase: G0
g0_approval_reasoning: "R1 PASS: Bandy book ISBN/URL plus Mulloy DEMA attribution; R2 PASS: deterministic DEMA cross entries, opposite-cross/Chandelier/time exits with ~14 trades/year/symbol; R3 PASS: D1 trend rules portable to FX/XAU/oil/NDX/WS30 and SP500 backtest caveat covered; R4 PASS: fixed-rule non-ML one-position-p"
---

# Bandy DEMA Crossover Trend (Long/Short)

## Quelle
- Source: [[sources/bandy-quantitative-technical-analysis]]
- Book: Howard B. Bandy, "Quantitative Technical Analysis: An Integrated Approach to Trading System Development and Trade Management", Blue Owl Press, 2015, ISBN 9780979183850.
- Citation: Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 9780979183850, URL: https://books.google.com/books/about/Quantitative_Technical_Analysis.html?id=LTJJngEACAAJ
- Bandy in QTA's MA-system chapter explicitly compares the EMA/DEMA/TEMA family for lag-reduction. DEMA (Patrick Mulloy, "Smoothing Data with Faster Moving Averages", Technical Analysis of Stocks & Commodities, January 1994) uses `DEMA(n) = 2*EMA(close,n) - EMA(EMA(close,n),n)` — a single-pass nested-EMA correction, distinct from TEMA's two-pass correction `TEMA(n) = 3*EMA(close,n) - 3*EMA(EMA(close,n),n) + EMA(EMA(EMA(close,n),n),n)`. DEMA sits between EMA (no lag correction) and TEMA (over-correction risk) in the lag/responsiveness trade-off. Batch 5 source notes explicitly flagged "DEMA-specific variant defer to future batch" alongside QM5_9910 (TEMA-ADX crossover); this card captures that deferred DEMA slot. Distinct from QM5_9910 (TEMA — three-pass correction), QM5_9914 (ZLEMA — Ehlers zero-lag), QM5_9923 (HMA — Hull WMA composition). Bandy's contribution captured here is the **DEMA(8)/DEMA(21) parameter pairing, 200-SMA regime gate, ATR-Chandelier trail, and no-ADX-gate baseline** (the no-ADX-gate is deliberate to head-to-head against TEMA+ADX 9910 — isolates whether the ADX gate adds edge over the substrate alone).
- Substrate attribution: Patrick Mulloy, "Smoothing Data with Faster Moving Averages", TASC Jan 1994 (DEMA original publication); ATR from Wilder 1978. Bandy's contribution is the composite signal definition.
- PDF not on local disk; attribution by author + title under relaxed R1.

## Mechanik

Period: D1.

### Entry
On each daily close of the target instrument:
- Compute `dema_fast = DEMA(close, 8) = 2*EMA(close, 8) - EMA(EMA(close, 8), 8)`.
- Compute `dema_slow = DEMA(close, 21) = 2*EMA(close, 21) - EMA(EMA(close, 21), 21)`.
- Compute `regime = SMA(close, 200)`.
- Long entry at next bar's open if `dema_fast` crosses above `dema_slow` AND `close > regime`.
- Short entry at next bar's open if `dema_fast` crosses below `dema_slow` AND `close < regime`.
- One position per magic; reversal allowed only by first closing the open side.

### Exit
- Long: exit on opposite DEMA cross OR Chandelier trail hit OR time stop.
- Short: mirror.
- Time stop: 60 trading days.
- P3 sweep candidates: DEMA fast `5 / 8 / 13`; DEMA slow `18 / 21 / 26`; regime SMA `100 / 200 / 300`; Chandelier ATR mult `2.0 / 2.5 / 3.0`; time stop `45 / 60 / 90`.

### Stop Loss
Chandelier trailing stop: long stop = `HHV(high, 22) - 2.5*ATR(14)`; short stop = `LLV(low, 22) + 2.5*ATR(14)`. Stop ratchets only in the direction of the trade.

### Position Sizing
P2: fixed $1,000 risk based on the initial Chandelier-stop distance. Live: `RISK_PERCENT`.

### Zusätzliche Filter
- Skip on incomplete daily bar.
- One position per magic; long/short mutually exclusive.
- Optional P3 filter: require `|dema_fast - dema_slow|/atr14 >= 0.20` on the cross bar (separation gate).

## Build-EA Notes
MT5 has `iDEMA` native — Codex should use the built-in handle, not roll a custom EMA-of-EMA loop. Confirm `iDEMA` is single-pass DEMA (it is — MT5 standard library returns `2*EMA - EMA(EMA)`), not a TEMA confusion.

## Concepts
- [[concepts/trend-following]] — primary
- [[concepts/regime-filter]] — secondary

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named Bandy book + ISBN + URL; Mulloy DEMA substrate (1994) explicit in Quelle. |
| R2 Mechanical | PASS | Explicit DEMA periods, regime gate, Chandelier trail formula, time stop. |
| R3 Data Available | PASS | Daily timeframe; testable on FX majors, XAUUSD, oil CFD, live-routable index CFDs (NDX.DWX, WS30.DWX). SP500.DWX backtest-optional. |
| R4 ML Forbidden | PASS | DEMA is a closed-form deterministic nested-EMA composition; not adaptive learning. Fixed parameters; one position per magic; no martingale; no scale-in. |

## R3
Multi-instrument portable; not SP500-only. **Live promotion T_Live gate:** SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T_Live deploy requires parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. The primary symbol set is FX/XAU/NDX/WS30/oil, where the caveat is moot.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from Bandy QTA Batch 7.

## Verwandte Strategien
- [[strategies/QM5_9910_bandy-tema-adx-crossover-trend]] — TEMA — sibling lag-reduced MA with ADX gate added; this card is the ADX-free DEMA baseline for head-to-head comparison.
- [[strategies/QM5_9923_bandy-hma-crossover-trend]] — HMA — sibling lag-reduced MA, WMA composition.
- [[strategies/QM5_9914_bandy-zlema-distance-trend]] — ZLEMA — Ehlers zero-lag, distance-from-MA trigger.

## Lessons Learned (während Pipeline-Lauf)
- TBD
