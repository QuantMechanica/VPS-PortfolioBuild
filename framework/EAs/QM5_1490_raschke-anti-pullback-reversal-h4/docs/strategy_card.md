---
ea_id: QM5_1490
slug: raschke-anti-pullback-reversal-h4
expected_trades_per_year_per_symbol: 100
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/pullback-continuation]]"
  - "[[concepts/dual-oscillator-divergence]]"
indicators:
  - "[[indicators/raschke-3-10-oscillator]]"
  - "[[indicators/atr]]"
  - "[[indicators/sma-d1-50]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id present; body cites FF cluster URL plus Raschke/Connors Street Smarts (ISBN 978-0-9650461-0-1), satisfying the one-source-per-card rule under relaxed 2026-05-15 criteria.
r2_mechanical: PASS
r2_reasoning: Seven closed-form arithmetic gates over Osc/Signal/ATR/D1 SMA/stdev/cooldown; no discretionary elements remain.
r3_data_available: PASS
r3_reasoning: Pure close-price oscillator family (SMA-3, SMA-10, SMA-16) plus ATR and D1 SMA(50) are testable on every DWX instrument.
r4_ml_forbidden: PASS
r4_reasoning: Fixed periods (3/10/16), fixed ATR multipliers, fixed 50-bar stdev and 30-bar cooldown; no ML, no adaptive PnL parameters, single position per magic.
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS source attribution via FF cluster plus Raschke/Connors ISBN book; R2 PASS deterministic Anti entry/exit/SL rules; R3 PASS pure price/ATR/SMA testable on DWX symbols; R4 PASS no ML/adaptive/grid and single-position compatible."
---

# Raschke "Anti" Pullback-Reversal (H4)

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Page / Timestamp: ForexFactory Trading Systems subforum cluster
  "Raschke Anti pattern" / "Raschke 3-10 Anti EA" / "Anti setup
  pullback detector" threads (2009-2023). Linda Bradford Raschke +
  Laurence A. Connors, *Street Smarts: High Probability Short-Term
  Trading Strategies* (M Gordon Publishing 1996, ISBN
  978-0-9650461-0-1), ch. 8 ("Anti"). The "Anti" is Raschke's
  named name for a counter-pullback re-acceleration pattern she
  used at Trout Trading: the slow signal line of the 3-10
  Oscillator continues in the prevailing trend direction while
  the fast Osc retraces against it, then re-accelerates back into
  the trend.

## Mechanik

The Raschke "Anti" uses the same 3-10 Oscillator as
QM5_1487, but the trigger is a re-cross *back into* the macro
trend after a counter-trend retracement of the fast Osc — not
the initial cross used in QM5_1487. The mechanic is a pullback-
continuation primitive within an established momentum regime,
distinct from a fresh momentum-acceleration cross.

```
Fast[t]     = SMA(3, close)[t]
Slow[t]     = SMA(10, close)[t]
Osc[t]      = Fast[t] - Slow[t]
Signal[t]   = SMA(16, Osc)[t]
```

The Signal series defines the slow trend direction of the
oscillator; the Osc series is the fast component that retraces
and re-accelerates.

### Entry (bullish; bearish mirror)

All seven gates must PASS on bar t:

1. **Macro-trend gate**: D1 close > D1 SMA(50) AND D1 SMA(50)[t]
   > D1 SMA(50)[t-5]. (Bear-mirror: < and slope negative.) The
   "Anti" only fires in line with the daily trend.
2. **Signal-trend gate**: Signal[t] > Signal[t-3] AND
   Signal[t-3] > Signal[t-6]. (Bear-mirror: monotonic decline.)
   Slow oscillator must be confirmed in the trade direction.
3. **Retracement gate (counter-move setup)**: within the
   trailing 8 H4 bars before t, Osc crossed *below* Signal at
   least once (Osc[t-k] < Signal[t-k] for at least one k in
   1..8). (Bear-mirror: Osc crossed above Signal.) This is the
   "Anti" retracement leg.
4. **Re-cross gate (trigger)**: Osc[t] > Signal[t] AND
   Osc[t-1] <= Signal[t-1]. (Bear-mirror: Osc[t] < Signal[t]
   AND Osc[t-1] >= Signal[t-1].) Fast Osc re-crosses Signal
   back into the macro-trend direction on bar t.
5. **Cross-separation gate**: |Osc[t] - Signal[t]| > 0.15 *
   ATR(14)[t]. Suppresses flat-line drift re-crosses.
6. **Retracement-depth gate**: min(Osc[t-k]) within k in 1..8
   was at least 0.4 * stdev(Osc, 50) below Signal[t-k] at its
   trough. (Bear-mirror: max above Signal.) Filters shallow
   re-crosses that aren't genuine Antis.
7. **No-recent-Anti gate**: no prior Anti trigger (gate 4
   PASS) in the trailing 30 H4 bars. Prevents whipsaw stacking.

Direction: long on bullish Anti / short on bearish Anti.
Order: market on H4 close of bar t.

### Exit

- **TP1**: 1.5 * ATR(14)[t] from entry — close 60% of position.
- **TP2**: opposite Signal-line slope change (Signal[t] <
  Signal[t-3] for longs; > for shorts) — close remaining 40%.
- **Time-stop**: 24 H4 bars elapsed without TP1 → close at
  market.

### Stop Loss

Hard SL at 2.0 * ATR(14)[t_entry] from entry. Fixed at fill,
never trailed.

### Position Sizing

P2 baseline: RISK_FIXED = $1000 per trade per HR4. Live:
RISK_PERCENT = 0.5%.

### Zusätzliche Filter

- News-blackout: 60 min around NFP / ECB / FOMC.
- Spread filter: spread <= 1.5 * 20-bar median.
- Warm-up filter: require >= 100 H4 bars of history before the
  first entry (Signal SMA(16) of Osc + 50-bar stdev window +
  D1 SMA(50) warm-up + 30-bar Anti-cooldown lookback).

### Target symbols

Pure close-price indicator family — testable on every DWX
instrument. Initial P2 baseline scope: EURUSD.DWX, GBPUSD.DWX,
USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX (FX majors), NDX.DWX,
WS30.DWX, GDAXI.DWX, UK100.DWX (index CFDs), XAUUSD.DWX,
XTIUSD.DWX (commodities). H4 timeframe.

## Concepts (was ist das für eine Strategie)
- [[concepts/pullback-continuation]] — primary (Anti is the
  retrace-and-resume continuation primitive in Raschke's
  framework)
- [[concepts/dual-oscillator-divergence]] — secondary (Osc and
  Signal temporarily diverge during the Anti retracement leg,
  then re-converge on the re-cross)

## R1-R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PENDING | FF Trading Systems cluster URL + Raschke + Connors *Street Smarts* M Gordon Publishing 1996 ch. 8 (ISBN-cited) — named-author book, named pattern with author attribution. R1 PASS expected under relaxed 2026-05-15 criteria. |
| R2 Mechanical | PENDING | Seven closed-form arithmetic gates over Osc + Signal + ATR + D1 macro-bias + stdev-normalized retracement depth + cooldown. NO discretionary elements (the "Anti" is fully reduced to retrace-lookback + re-cross + cooldown). R2 PASS expected. |
| R3 Data Available | PENDING | Three SMAs of close + ATR + D1 SMA(50) — pure price. Testable on every DWX symbol. R3 PASS expected. |
| R4 ML Forbidden | PENDING | No ML, no adaptive parameters, fixed SMA periods (3/10/16) and fixed retracement-depth (50-bar stdev) and fixed cooldown (30 bars). Single position per magic per HR14. ATR-bounded SL. R4 PASS expected. |

## Pipeline-Verlauf
- G0: PENDING

## Verwandte Strategien
- [[strategies/QM5_1487_raschke-3-10-oscillator-cross-h4]] — sibling
  (same indicator family — uses fresh Osc/Signal cross as trigger;
  this card uses *re-cross after counter-retracement* as trigger.
  The two patterns can fire on the same instrument but rarely
  simultaneously — distinct trade-setup primitives in Raschke's
  taxonomy.)
- [[strategies/QM5_1478_raschke-80-20-reversal-h1]] — sibling
  (different Raschke primitive, range-position based)
- [[strategies/QM5_1479_raschke-holy-grail-adx-ema20-h1]] — sibling
  (different Raschke primitive, ADX-pullback based)

## Lessons Learned (während Pipeline-Lauf)
- <Datum>: <Erkenntnis> — siehe `docs/ops/LESSONS_LEARNED_<YYYY-MM>.md`

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
