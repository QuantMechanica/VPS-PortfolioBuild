---
ea_id: QM5_1494
slug: dorsey-mass-index-reversal-bulge-h4
expected_trades_per_year_per_symbol: 100
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/volatility-expansion-reversal]]"
  - "[[concepts/range-expansion-bulge]]"
indicators:
  - "[[indicators/mass-index]]"
  - "[[indicators/ema-9]]"
  - "[[indicators/atr]]"
  - "[[indicators/sma-d1-50]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id present; body cites FF cluster URL plus Dorsey TASC June 1992 (named-author peer-reviewed article) and Colby/Meyers Encyclopedia (ISBN 978-0-07-012057-1), satisfying the one-source-per-card rule.
r2_mechanical: PASS
r2_reasoning: Six closed-form arithmetic gates over Mass Index double-EMA-ratio rolling sum, EMA(9), ATR, and D1 SMA(50); Dorsey's verbal bulge rule is reduced to explicit threshold crossings (27→26.5).
r3_data_available: PASS
r3_reasoning: Pure OHLC high-low input plus EMA, ATR, and D1 SMA are testable on every DWX instrument with reliable H/L bars.
r4_ml_forbidden: PASS
r4_reasoning: Fixed thresholds (27/26.5 from Dorsey TASC 1992), fixed lookbacks (9/9/25/16/14/200/50), no ML or adaptive PnL parameters, single position per magic.
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 cites FF/TASC/book references; R2 has deterministic Mass Index entry/exit/SL rules; R3 OHLC/ATR/D1-SMA testable on DWX symbols; R4 fixed-parameter non-ML single-position design."
---

# Dorsey Mass Index Reversal Bulge (H4)

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Page / Timestamp: ForexFactory Trading Systems subforum
  cluster "Mass Index EA" / "Dorsey Mass Index MT4" / "Reversal
  bulge detector" threads (2009-2023). Donald Dorsey, "The Mass
  Index: It Bulges Before Trend Reversals", *Technical Analysis
  of Stocks and Commodities* (TASC) June 1992 (Vol. 10, No. 6),
  pp. 265-269. Subsequent treatment in Colby + Meyers, *The
  Encyclopedia of Technical Market Indicators*, 2nd ed.
  (McGraw-Hill 2003, ISBN 978-0-07-012057-1), ch. 109. Standard
  reference in J. Welles Wilder's lineage of volatility-
  expansion indicators (alongside ADX / DMI / Parabolic SAR
  family).

## Mechanik

The Mass Index measures volatility expansion via the
high-low range, smoothed by a double-EMA ratio:

```
HL[t]           = high[t] - low[t]
EMA9_HL[t]      = EMA(9, HL)[t]
EMA9_EMA9_HL[t] = EMA(9, EMA9_HL)[t]
Ratio[t]        = EMA9_HL[t] / EMA9_EMA9_HL[t]
MassIndex[t]    = sum(Ratio[t-24..t])   (25-bar rolling sum)
```

Dorsey's "reversal bulge" pattern (TASC 1992):

> When the Mass Index rises above 27, then subsequently falls
> below 26.5, a trend reversal is signaled.

Critically, the Mass Index alone does not have direction —
it only signals *that* a reversal is likely, not which way.
Dorsey himself proposed combining it with a directional filter
(a 9-period EMA slope on close). This card adopts that
combination as the directional mechanism, mechanized below.

### Entry (long on bullish-bulge — bearish mirror)

All six gates must PASS on bar t:

1. **Bulge-set-up gate**: MassIndex peaked above 27 within
   the trailing 16 H4 bars — i.e., max(MassIndex[t-16..t-1])
   > 27.
2. **Bulge-trigger gate**: MassIndex[t] < 26.5 AND
   MassIndex[t-1] >= 26.5. Dorsey's exact threshold crossing
   that defines the bulge completion.
3. **Direction-from-EMA9 gate**: at the bulge peak (the bar
   in 1. with MassIndex max), close > EMA(9, close) — implies
   the *prior* short-term move was up, so the reversal signal
   is **bearish** for that case; **invert for long entries**.
   Formally: for a long entry on bar t, at the bulge-peak bar
   t_peak, EMA(9, close)[t_peak] > close[t_peak] (short-term
   down-move pre-bulge → bullish reversal). (Bear-mirror:
   t_peak had close > EMA9 → bearish reversal.)
4. **Macro-bias gate**: D1 close > D1 SMA(50) AND D1 SMA(50)[t]
   > D1 SMA(50)[t-5] for long entries (bear-mirror for shorts).
   Dorsey's pattern works best when the *reversal* aligns with
   the dominant daily trend (i.e., the H4 reversal is a
   short-term pullback within a daily trend, not a counter-
   trend reversal of the daily trend).
5. **ATR floor gate**: ATR(14)[t] > 0.6 * SMA(ATR(14), 200)[t].
   Mass Index can fire in compressed-vol regimes where the
   subsequent reversal lacks tradable range — ATR floor filters
   these out.
6. **No-recent-bulge gate**: no prior Mass Index reversal
   bulge entry within the last 30 H4 bars. Mass Index bulges
   can occasionally chain in extended high-vol regimes;
   30-bar cooldown prevents re-entry on the same vol cluster.

Direction: long on bullish reversal-bulge / short on bearish.
Order: market on H4 close of bar t.

### Exit

- **TP1**: 1.5 * ATR(14)[t] from entry — close 60% of
  position.
- **TP2**: EMA(9, close) re-crosses against trade direction
  (EMA9 turns down for longs / up for shorts) — close
  remaining 40%.
- **Time-stop**: 24 H4 bars elapsed without TP1 → close at
  market. (Mass Index reversals are typically 1-5 day moves;
  24 H4 bars ~ 4 trading days.)

### Stop Loss

Hard SL at 2.0 * ATR(14)[t_entry] from entry. Fixed at fill,
never trailed.

### Position Sizing

P2 baseline: RISK_FIXED = $1000 per trade per HR4. Live:
RISK_PERCENT = 0.5%.

### Zusätzliche Filter

- News-blackout: 60 min around NFP / ECB / FOMC.
- Spread filter: spread <= 1.5 * 20-bar median.
- Warm-up filter: require >= 250 H4 bars of history before
  the first entry (25-bar Mass Index rolling sum + double-
  EMA(9) of high-low range + 200-bar ATR baseline + D1 SMA(50)
  warm-up + 30-bar bulge-cooldown lookback).

### Target symbols

Mass Index uses High-Low range — works on every DWX instrument
that has reliable H/L (all of them under DWX feed). Initial P2
baseline scope: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX,
USDCAD.DWX (FX majors), NDX.DWX, WS30.DWX, GDAXI.DWX, UK100.DWX
(index CFDs — Dorsey's original 1992 paper tested on equity-
index futures, indices map naturally), XAUUSD.DWX, XTIUSD.DWX
(commodities). H4 timeframe.

## Concepts (was ist das für eine Strategie)
- [[concepts/volatility-expansion-reversal]] — primary
  (Mass Index bulge detects high-low range expansion as a
  reversal precursor)
- [[concepts/range-expansion-bulge]] — secondary (specific
  topology: Index rises above 27 then falls below 26.5 — the
  bulge shape Dorsey named in TASC 1992)

## R1-R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PENDING | FF Trading Systems cluster URL + Dorsey TASC June 1992 (named-author peer-reviewed magazine article with named title "The Mass Index: It Bulges Before Trend Reversals") + Colby + Meyers *Encyclopedia of Technical Market Indicators* McGraw-Hill 2003 ch. 109 (ISBN-cited). Donald Dorsey is a publicly-identifiable practitioner (TASC contributor, MetaStock indicator-library contributor). R1 PASS expected under relaxed 2026-05-15 criteria. |
| R2 Mechanical | PENDING | All six gates are closed-form arithmetic over Mass Index (deterministic double-EMA-ratio rolling sum) + EMA(9, close) + ATR + D1 SMA(50). Direction gate is explicit (EMA9-vs-close inequality at bulge-peak). Dorsey's verbal "before trend reversals" reduced to (a) the explicit 27 → 26.5 threshold crossing he stated and (b) a EMA9-based direction filter he proposed in the original TASC article. No discretionary elements remain. R2 PASS expected. |
| R3 Data Available | PENDING | Pure OHLC input (high, low, close) + EMA + ATR + D1 SMA — testable on every DWX symbol. R3 PASS expected. |
| R4 ML Forbidden | PENDING | No ML, no adaptive parameters, fixed thresholds (27 / 26.5 from Dorsey TASC 1992), fixed lookbacks (9/9/25/16/14/200/50/30). Single position per magic per HR14. ATR-bounded SL. R4 PASS expected. |

## Pipeline-Verlauf
- G0: PENDING

## Verwandte Strategien
- [[strategies/QM5_1444_vortex-indicator-cross-h4]] — sibling
  (Vortex Indicator — Botes/Siepman 2009 — is the same family
  of high-low-range-derived indicators as Mass Index; Vortex
  trigger is VI+/VI- cross, Mass Index trigger is bulge
  threshold-crossing. Same H4 family, different mechanic
  primitive.)
- [[strategies/QM5_1437_carter-ttm-squeeze-h4]] — distinguished
  (TTM Squeeze detects vol-*compression* (Bollinger inside
  Keltner) followed by momentum release; Mass Index detects
  vol-*expansion* followed by reversal. Inverse vol-regime
  primitives.)
- [[strategies/QM5_1492_connors-vix-spike-reversal-h4]] —
  distinguished (Connors-VIX-port uses ATR-stretch as the
  vol-spike trigger followed by mean-reversion entry; Mass
  Index uses the bulge-completion threshold-crossing as the
  reversal trigger with EMA9-direction filter. Both are
  vol-spike-reversal primitives but with different trigger
  topologies — ratio-of-EMA vs. ratio-of-ATR.)

## Lessons Learned (während Pipeline-Lauf)
- <Datum>: <Erkenntnis> — siehe `docs/ops/LESSONS_LEARNED_<YYYY-MM>.md`

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
