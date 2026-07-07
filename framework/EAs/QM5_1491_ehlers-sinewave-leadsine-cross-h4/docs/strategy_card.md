---
ea_id: QM5_1491
slug: ehlers-sinewave-leadsine-cross-h4
expected_trades_per_year_per_symbol: 100
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/cycle-phase-turn]]"
  - "[[concepts/sinewave-cross]]"
indicators:
  - "[[indicators/ehlers-sinewave]]"
  - "[[indicators/ehlers-hilbert-transformer]]"
  - "[[indicators/atr]]"
  - "[[indicators/sma-d1-50]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id present; body cites FF cluster URL plus Ehlers Wiley 2001 (ISBN 978-0-471-40567-1) and TASC Nov 2000, satisfying the one-source-per-card rule.
r2_mechanical: PASS
r2_reasoning: Six closed-form gates over Hilbert-quadrature transformer, Phase/DCPeriod, ATR, and D1 SMA(50); all are deterministic published closed-form computations with no discretionary elements.
r3_data_available: PASS
r3_reasoning: Pure close-price DSP filters (high-pass IIR, FIR quadrature) plus ATR and D1 SMA are testable on every DWX instrument with clean H4 bars.
r4_ml_forbidden: PASS
r4_reasoning: Fixed alpha (0.07), fixed SMA periods, fixed phase offset (pi/4); DCPeriod is a published closed-form smoother, not a fitted model; no ML or adaptive PnL logic.
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS source attribution via FF cluster plus Ehlers ISBN books/TASC article; R2 PASS deterministic LeadSine/Sinewave entry/exit/SL rules; R3 PASS close-price DSP/ATR/SMA testable on DWX symbols; R4 PASS no ML/online learning/adaptive PnL logic and single-position compatible."
---

# Ehlers Sinewave / Lead-Sinewave Cross (H4)

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Page / Timestamp: ForexFactory Trading Systems subforum cluster
  "Ehlers Sinewave EA" / "Sinewave indicator MT4" / "LeadSine cross
  detector" threads (2009-2024). John F. Ehlers, *Rocket Science
  for Traders: Digital Signal Processing Applications* (Wiley 2001,
  ISBN 978-0-471-40567-1), ch. 9 ("The Sinewave Indicator"). John
  F. Ehlers, *Cybernetic Analysis for Stocks and Futures: Cutting-
  Edge DSP Technology to Improve Your Trading* (Wiley 2004, ISBN
  978-0-471-46307-4), ch. 5. Ehlers, "Stay in Phase", *Technical
  Analysis of Stocks and Commodities* (TASC) Nov 2000 (Vol. 18,
  No. 11).

## Mechanik

The Ehlers Sinewave Indicator decomposes price into an
instantaneous phase angle via a Hilbert transformer and then
emits two sinusoidal signals: Sinewave[t] = sin(Phase[t]) and
LeadSine[t] = sin(Phase[t] + 45°). Where Sinewave and LeadSine
cross identifies the inflection of the dominant price cycle —
a turn from upswing to downswing or vice versa.

Distinct from QM5_1486 (Ehlers Center-of-Gravity / Signal cross,
which uses a closed-form CG-of-median + lag-1 cross) and from
QM5_1353 (Ehlers Fisher Transform zero-cross, which uses the
inverse Fisher transform of normalized price range). The
Sinewave Indicator works in the *phase domain*, not the price
domain, and is specifically designed by Ehlers for ranging /
cyclic markets — the trend-mode-detector gate below filters out
non-cyclic regimes where the indicator is unreliable per Ehlers's
own warning in *Rocket Science* p. 142.

```
HighPass[t]    = (1 - alpha/2)^2 * (close[t] - 2*close[t-1] + close[t-2])
                 + 2*(1 - alpha) * HighPass[t-1]
                 - (1 - alpha)^2 * HighPass[t-2]
                 (alpha = 0.07, Ehlers high-pass cutoff)
Smooth[t]      = (HighPass[t] + 2*HighPass[t-1] + 2*HighPass[t-2]
                  + HighPass[t-3]) / 6
DetrendIQ[t]   = Hilbert-quadrature transformer applied to Smooth
                 (Ehlers Rocket Science ch. 7 closed-form 7-bar FIR)
Phase[t]       = atan2(Quadrature[t], InPhase[t])
DCPeriod[t]    = smoothed dominant cycle (Ehlers ch. 8 closed-form,
                 typically 8 to 50 bars)
TrendMode[t]   = 1 if DCPeriod[t] > 50 OR ABS(Phase[t] -
                 Phase[t-DCPeriod/2]) < pi/4
                 else 0
Sinewave[t]    = sin(Phase[t])
LeadSine[t]    = sin(Phase[t] + pi/4)
```

### Entry (bullish; bearish mirror)

All six gates must PASS on bar t:

1. **LeadSine/Sinewave cross gate**: LeadSine[t] > Sinewave[t]
   AND LeadSine[t-1] <= Sinewave[t-1]. (Bear-mirror: LeadSine[t]
   < Sinewave[t] AND LeadSine[t-1] >= Sinewave[t-1].) Cycle-turn
   trigger.
2. **Cycle-mode gate**: TrendMode[t] == 0 AND TrendMode[t-1] ==
   0 AND TrendMode[t-2] == 0. Ehlers's own warning: the Sinewave
   only emits valid signals during cyclic regimes; in trend mode
   the phase angle drifts monotonically and crosses become
   meaningless.
3. **Cycle-bottom gate**: Sinewave[t] < -0.5 OR Sinewave[t] >
   0.5 (depending on bullish/bearish). Ensures the cross is
   near a cycle extremum, not mid-cycle drift. For longs:
   Sinewave[t] < -0.5; for shorts: Sinewave[t] > 0.5.
4. **Macro-bias gate**: D1 close > D1 SMA(50) AND D1 SMA(50)[t]
   > D1 SMA(50)[t-5] for longs. (Bear-mirror for shorts.)
   Restricts cycle-turn-longs to up-trending daily context.
5. **ATR floor gate**: ATR(14)[t] > 0.6 * SMA(ATR(14), 200)[t].
   Suppresses flat-low-vol regimes where Sinewave crosses cluster
   on noise.
6. **No-recent-opposite-cross gate**: no opposite LeadSine/
   Sinewave cross within the last 12 H4 bars. Prevents same-
   cycle whipsaw entry.

Direction: long on bullish LeadSine cross / short on bearish.
Order: market on H4 close of bar t.

### Exit

- **TP1**: 1.5 * ATR(14)[t] from entry — close 60% of position.
- **TP2**: opposite LeadSine/Sinewave cross (next cycle inflection)
  — close remaining 40%.
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
- Warm-up filter: require >= 200 H4 bars of history before the
  first entry (Hilbert transformer FIR + DCPeriod smoothing +
  200-bar ATR SMA + D1 SMA(50) warm-up).

### Target symbols

Pure close-price indicator family with explicit cycle-mode gate
— preferentially testable on instruments with detectable cyclic
behavior. Initial P2 baseline scope: EURUSD.DWX, GBPUSD.DWX,
USDJPY.DWX, AUDUSD.DWX (FX majors, Ehlers tested cycle DSP on
FX historically), NDX.DWX, WS30.DWX, GDAXI.DWX, UK100.DWX (index
CFDs), XAUUSD.DWX, XTIUSD.DWX (commodities, typically less
cyclic — included for P2 negative-control evidence). H4 timeframe.

## Concepts (was ist das für eine Strategie)
- [[concepts/cycle-phase-turn]] — primary (phase-domain cycle
  inflection trigger via Sinewave/LeadSine cross)
- [[concepts/sinewave-cross]] — secondary (sin/sin-with-45-deg-
  lead cross as the inflection signal)

## R1-R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PENDING | FF Trading Systems cluster URL + Ehlers Wiley 2001 ch. 9 (ISBN-cited) + Ehlers Wiley 2004 ch. 5 (ISBN-cited) + Ehlers TASC Nov 2000 — named-author DSP-trading book. John F. Ehlers is a publicly-identifiable practitioner (MESA Software founder, multiple Wiley books on DSP applied to markets). R1 PASS expected under relaxed 2026-05-15 criteria. |
| R2 Mechanical | PENDING | All six gates are closed-form arithmetic over Hilbert-quadrature transformer output + Phase atan2 + DCPeriod heuristic + ATR + D1 SMA(50). Phase/DCPeriod are deterministic 7-bar FIR + Ehlers's published smoother — no learning, no fit. NO discretionary elements. R2 PASS expected. |
| R3 Data Available | PENDING | Pure close-price input. Hilbert transformer + DCPeriod + ATR + D1 SMA(50) all derive from native MT5 close/H/L feeds. Testable on every DWX symbol (FX majors, indices, XAUUSD, XTIUSD). R3 PASS expected. |
| R4 ML Forbidden | PENDING | No ML, no online adaptation, no parameter learning. The DCPeriod estimator is a published closed-form smoother (Ehlers ch. 8), not a fitted model. Fixed alpha (0.07), fixed SMA periods, fixed phase-offset (pi/4). Single position per magic per HR14. ATR-bounded SL. R4 PASS expected. |

## Pipeline-Verlauf
- G0: PENDING

## Verwandte Strategien
- [[strategies/QM5_1486_ehlers-cg-oscillator-cross-h4]] — sibling
  (different Ehlers primitive: Center-of-Gravity of median +
  Signal cross. CG operates in price-amplitude domain; Sinewave
  in phase-angle domain. The two emit different trigger
  timings.)
- [[strategies/QM5_1353_ehlers-fisher-transform-h1]] — sibling
  (different Ehlers primitive: inverse-Fisher transform of
  normalized price range. Fisher operates on range distribution;
  Sinewave on cycle phase.)
- [[strategies/QM5_1487_raschke-3-10-oscillator-cross-h4]] —
  distinguished (Raschke 3-10 is a simple-MA difference;
  Sinewave is a Hilbert-derived phase signal — entirely different
  signal-processing topology.)

## Lessons Learned (während Pipeline-Lauf)
- <Datum>: <Erkenntnis> — siehe `docs/ops/LESSONS_LEARNED_<YYYY-MM>.md`

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
