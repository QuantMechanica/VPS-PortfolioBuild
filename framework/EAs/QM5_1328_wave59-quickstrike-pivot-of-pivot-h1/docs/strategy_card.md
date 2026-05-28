---
ea_id: QM5_1328
slug: wave59-quickstrike-pivot-of-pivot-h1
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/pivot-of-pivot]]"
  - "[[concepts/numeric-setup-entry]]"
indicators:
  - "[[indicators/daily-pivot]]"
  - "[[indicators/atr]]"
  - "[[indicators/ema]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 Beann Wave59 books/ISBN and FF attribution; R2 deterministic pivot-of-pivot/EMA/session entries/exits; R3 DWX FX/metals/indices testable; R4 no ML, fixed formulas/params, 1-pos-per-magic."
---

# Wave59 QuickStrike — Pivot-of-Pivot intraday breakout (H1)

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Original author: Earik Beann — *Wave59 QuickTips* manual (Wave59 Technologies, 2008) and *The Handbook of Market Esoterica* (Wave59 Publishing, 2009, ISBN 978-0982261101). Earik Beann founded Wave59 Technologies in 2002 and developed the proprietary "QuickStrike" numeric-setup family — combinations of cycle-based pivots derived from prior-period highs/lows. The most-mechanical subset of QuickStrike — the **Pivot-of-Pivot (PoP)** setup — uses the prior-day classic pivot as the anchor for an intraday H1 breakout filtered by a second-derived pivot ("the pivot of the pivot"). The PoP setup is documented in Beann's 2008 QuickTips manual chapter on "second-order pivots".
- FF cluster URL: FF Trading Systems forum search "Wave59 QuickStrike" / "Earik Beann pivot" / "Wave59 PoP" / "pivot of pivot" — multiple named-handle threads in the Trading-Systems subforum from 2010–2018 implementing community ports of Wave59 mechanics. Wave59 itself was a closed-source platform but the *mechanical* portion of QuickStrike (the deterministic numeric-setup rules) was published in Beann's 2008/2009 books and Wave59 user-group materials.
- Distinct from QM5_1290 (classic-pivot fade/break, daily pivot only): QM5_1328 uses a second-derived pivot — the daily-pivot's value treated as the high/low/close input to *another* pivot calculation, yielding "PoP" levels offset from the standard R1/S1. The PoP levels are typically tighter than R1/S1 but wider than the pivot itself; they act as breakout confirmation gates rather than pivot-as-fade levels.

## Mechanik

Pivot calculations (D1 prior-day OHLC):

Standard daily pivot (Beann's "first-order pivot"):
- `P = (high_D1[1] + low_D1[1] + close_D1[1]) / 3`
- `R1 = 2P − low_D1[1]`
- `S1 = 2P − high_D1[1]`
- `R2 = P + (high_D1[1] − low_D1[1])`
- `S2 = P − (high_D1[1] − low_D1[1])`

Pivot-of-Pivot (Beann's "second-order pivot") — uses {R1, S1, P} as the synthetic OHLC for a second pivot:
- `PoP_high = R1` (treats R1 as the synthetic high)
- `PoP_low = S1` (treats S1 as the synthetic low)
- `PoP_close = P` (treats P as the synthetic close)
- `PoP_pivot = (PoP_high + PoP_low + PoP_close) / 3 = (R1 + S1 + P) / 3`
- `PoP_R1 = 2 × PoP_pivot − PoP_low = 2(R1 + S1 + P)/3 − S1`
- `PoP_S1 = 2 × PoP_pivot − PoP_high = 2(R1 + S1 + P)/3 − R1`

Auxiliary (H1):
- `EMA(50, H1)` — intraday-trend filter
- `ATR(14, H1)` — SL sizing

### Entry — BUY
On H1 bar close, during NY-session window (broker-time 13:30–20:00):
1. **Close above PoP_R1**: `close[0] > PoP_R1 AND close[1] <= PoP_R1` (first-close-outside the second-order pivot upper level).
2. **Day's high beyond standard R1**: `daily_high_so_far > R1` (confirms the day is in a directional regime, not range-bound around the pivot).
3. **Intraday trend bullish**: `close > EMA(50, H1)`.
4. **PoP-band meaningful**: `PoP_R1 − PoP_S1 > 0.5 × ATR(14, D1)` — kills entries on days where the prior-day OHLC compressed the PoP-band too tight (Inside-Day pattern).
5. **No open position on this symbol** (1-pos-per-magic, HR14).

Enter BUY at the close of the signal H1 bar.

### Entry — SELL
Mirror — `close[0] < PoP_S1 AND close[1] >= PoP_S1`; `daily_low_so_far < S1`; `close < EMA(50, H1)`; PoP-band width gate; no open position; NY-session window.

### Exit
- **Take Profit (primary)**: `R1` for BUYs (the standard first-order R1 acts as the natural intraday target above PoP_R1). SELL mirror at `S1`.
- **Take Profit (extended)**: `R2` for BUYs if the standard R1 was already crossed before entry (rare — only happens on gap-up days). SELL mirror at `S2`.
- **Day-end exit (MANDATORY)**: All open positions close at `21:00` broker-time. Wave59 QuickStrike is intraday by construction; no overnight carry.
- **Time-stop within session**: 8 H1 bars without TP/SL hit → market close. 8 bars on H1 ≈ 8 hours, which covers most of the NY-session window after entry.
- **Pivot-flip exit**: BUY closes if `close < P` (price returns below the first-order pivot — the directional regime has failed). SELL mirror at `close > P`.

### Stop Loss
- BUY: `min(low[0], low[1]) − 0.3 × ATR(14, H1)` — last 2 H1 bars' low + small cushion. P3-sweep multiplier 0.2–0.5.
- SELL: `max(high[0], high[1]) + 0.3 × ATR(14, H1)`.
- Cap on initial-SL distance: `1.5 × ATR(14, H1)` — intraday-fast SL hygiene; PoP setups by Beann's design have tight stop distances.
- Hard SL — no widening. Day-end and pivot-flip exits provide in-position management.

### Position Sizing
- HR4: `RISK_FIXED = $1.000` per trade for P2 baseline.
- Live: `RISK_PERCENT = 0.5%` of equity.

### Zusätzliche Filter
- One open trade per symbol direction (1-pos-per-magic, HR14).
- Re-arm: after position close (any exit), the PoP levels do NOT recompute mid-session (they are based on prior-day OHLC and are static for the trading day). A new same-direction entry requires the next trading day's pivot computation.
- Session: NY-session only (13:30–20:00 broker-time, NY-Close convention). Outside this window, no new entries — but PoP-pivot levels are still drawn on chart for visual reference. The day-end hard close fires at 21:00 (1 hour after NY-session window ends, allowing some post-session momentum).
- Spread guard: skip if spread > 1.2 × 20-bar median spread (tight intraday spread requirement).
- News-blackout: skip new entries ±20 min around high-impact news in the NY session.

## Target symbols
- FX majors: EURUSD, GBPUSD, USDJPY, AUDUSD (Wave59's documented FX coverage in 2008 QuickTips manual)
- Metals: XAUUSD.DWX
- Index CFDs: NDX.DWX, WS30.DWX (the US-equity indices Beann's Wave59 platform targeted)
- Period: H1

## Concepts (was ist das für eine Strategie)
- [[concepts/pivot-of-pivot]] — primary (Beann's second-order pivot construction: feed first-order pivot levels {R1, S1, P} as synthetic OHLC into another pivot calculation; the resulting PoP levels are the breakout gates).
- [[concepts/numeric-setup-entry]] — secondary (Wave59's broader QuickStrike family treats price levels derived from cyclic/numeric formulas as deterministic entry gates rather than discretionary support/resistance).

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PENDING | Earik Beann, *Wave59 QuickTips* (2008) and *The Handbook of Market Esoterica* (Wave59 Publishing, 2009, ISBN 978-0982261101) — named published author with multiple titles + Wave59 Technologies platform business. FF Trading-Systems community ports 2010–2018. Relaxed-R1 PASS. (Beann's broader Gann/cycle work is more discretionary; this card extracts only the *mechanical* PoP subset from QuickStrike.) |
| R2 Mechanical | PENDING | Standard pivot + second-order pivot are closed-form arithmetic of prior-day OHLC. Close-above-PoP_R1 / EMA(50) / day-high-vs-R1 / band-width gate are all deterministic comparisons. The session-window and day-end exit are clock-based, also deterministic. Fully reducible to MQL5 OnTick + OnTimer. |
| R3 Data Available | PENDING | FX majors, XAUUSD.DWX, NDX.DWX, WS30.DWX on Darwinex feed all support D1 prior-day OHLC + H1 close-of-bar. No SP500.DWX dependency. |
| R4 ML Forbidden | PENDING | No ML, fixed pivot formula + fixed EMA period + fixed ATR cap + fixed session window, single position per magic, hard intraday day-end close. No martingale, no averaging-in, no adaptive parameters tied to PnL. PASS. The numeric-setup nature is *deterministic-formula-on-prior-OHLC*, NOT learned weights — fundamentally distinct from ML. |

## Pipeline-Verlauf
- G0: <Datum, Verdict, Begründung>
- P1: <Datum, .ex5-Pfad>
- P2: <Datum, report.csv-Pfad, PASS-Symbole>

## Verwandte Strategien
- [[strategies/QM5_1290-classic-pivot-points-fade-break]] — sibling pivot-based card, uses *first-order* daily pivots only (R1/S1/P as direct fade or break levels). QM5_1328 uses the *second-order* PoP construction as the breakout gate. Same pivot-formula primitive, one level of recursion deeper.
- [[strategies/QM5_1305-camarilla-vwap-confluence-intraday]] — Camarilla pivots (Nick Stott formulation) + VWAP confluence. Different pivot formula (Camarilla constants vs Beann's PoP-of-classic) and different confluence (VWAP vs EMA-50). Both are intraday-pivot mechanics.
- [[strategies/QM5_1286-camarilla-monthly-pivots-position]] — Camarilla pivots on a monthly anchor. QM5_1328 is daily-anchored intraday — different timeframe scale.
- [[strategies/QM5_1328]] (this) is the only registry card combining Wave59's *second-order pivot* construction with an EMA-50 intraday-trend filter; the second-order recursion is the distinguishing primitive.

## Lessons Learned (während Pipeline-Lauf)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
