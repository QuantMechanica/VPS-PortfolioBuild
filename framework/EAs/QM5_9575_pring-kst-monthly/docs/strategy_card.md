---
ea_id: QM5_9575
slug: pring-kst-monthly
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-strategies-and-systems]]"
concepts:
  - "[[concepts/momentum]]"
  - "[[concepts/long-cycle-trend]]"
indicators:
  - "[[indicators/kst]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id UUID present; ForexFactory URL plus Pring McGraw-Hill 1993 and 2014 KST publication lineage — one canonical source."
r2_mechanical: PASS
r2_reasoning: "Monthly ROC/SMA/KST formulas are closed-form; cross entry, opposite-cross/MA exits, W1 ATR stop, and 12-bar time stop are fully specified."
r3_data_available: PASS
r3_reasoning: "Monthly KST concept portable to DWX FX and CFD symbols; note MT5 tester produces 0 bars on MN1 — Codex must rewrite as D1-native 252-bar proxy before build."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed ROC periods, SMA smoothing weights, and KST level thresholds; one position per magic; no ML, adaptive parameters, or martingale."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 4
last_updated: 2026-05-19
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX, XAUUSD.DWX, XTIUSD.DWX, GDAXI.DWX, NDX.DWX, WS30.DWX, UK100.DWX, FRA40.DWX, JP225.DWX]
g0_approval_reasoning: "R1 PASS: ForexFactory URL plus Pring book lineage; R2 PASS: deterministic monthly KST/SMA cross entries, opposite-cross/MA/time exits, ATR stop, stated ~4 trades/year/symbol and basket cadence; R3 PASS: OHLC-only rules portable to DWX FX/CFDs; R4 PASS: fixed periods/weights, no ML/grid/martingale, o"
---

# Pring Monthly KST Long-Cycle Trend (M1 Bars)

## Quelle

- Source: [[sources/forexfactory-strategies-and-systems]]
- Primary URL: https://www.forexfactory.com/thread/post/14002890
  (ForexFactory Trading Systems sub-forum, Martin Pring KST long-cycle
  thread cluster, monthly-cycle discussion, posts circa 2015-2025).
- Author lineage: Martin J. Pring -- *Martin Pring on Market Momentum*
  (McGraw-Hill 1993), ch. 8 "Know Sure Thing" and ch. 9 "Long-Term
  KST"; Pring -- *Technical Analysis Explained*, 5th ed. (McGraw-Hill
  2014), ch. 22.
- Distinctness sibling cards: QM5_1298 uses D1 KST, QM5_9501 uses W1
  long-term KST, QM5_1967 and QM5_2132 use H4 variants. This card uses
  monthly bars to test the business-cycle KST thesis at the slowest
  practical CFD cadence. Cadence is intentionally low but not one-shot:
  multi-symbol testing across FX majors, metals, oil and index CFDs gives
  sufficient basket observations for P2/P3 screening.

## Mechanik

### Indicator

Use completed monthly bars (`M1` timeframe in MT5). Monthly KST:

```
ROC1 = ROC(close, 6 months)
ROC2 = ROC(close, 9 months)
ROC3 = ROC(close, 12 months)
ROC4 = ROC(close, 18 months)

KST = SMA(ROC1, 6) * 1
    + SMA(ROC2, 6) * 2
    + SMA(ROC3, 9) * 3
    + SMA(ROC4, 9) * 4

Signal = SMA(KST, 9)
LongCycleMA = SMA(close, 18 months)
```

Warm-up requirement: at least 36 completed monthly bars.

### Entry

Long trigger:

1. Monthly KST crosses above Signal:
   `KST[t-1] <= Signal[t-1]` AND `KST[t] > Signal[t]`.
2. Long-cycle bias: `Close[t] > LongCycleMA[t]`.
3. KST is below +20 at cross (`KST[t] < 20`) to avoid chasing a mature
   monthly momentum climax.
4. Entry at the next tradable bar open after the monthly close.

Short trigger mirrors: KST crosses below Signal, close below
LongCycleMA, and `KST[t] > -20`.

Magic = `9575 * 10000 + slot`; one position per magic.

### Exit

- Primary exit: opposite KST/Signal cross on completed monthly bar.
- Protective exit: monthly close crosses the LongCycleMA in the opposite
  direction.
- Time stop: exit after 12 completed monthly bars.

### Stop Loss

- Long: `SL = entry - 3.0*ATR(14, W1)`.
- Short: `SL = entry + 3.0*ATR(14, W1)`.

The W1 ATR stop avoids the extremely coarse distance that a monthly ATR
would impose while still matching the slow-cycle thesis.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.5%` of equity at entry.

### Zusätzliche Filter

- Entries only on the first liquid session after a completed monthly bar.
- Spread filter: skip if spread > `0.20*ATR(14,W1)`.
- News filter: skip if the entry open is within +/-60 minutes of a
  high-impact event for either symbol currency; retry on the next H4 open
  within the first two trading days of the month.
- No pyramiding. One active position per symbol/magic.

## Concepts (was ist das für eine Strategie)

- [[concepts/momentum]] -- primary.
- [[concepts/long-cycle-trend]] -- secondary.

## R1-R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | ForexFactory URL plus Pring 1993 / 2014 McGraw-Hill KST publication lineage. |
| R2 Mechanical | UNKNOWN | Monthly ROC/SMA/KST formulas, explicit cross entry, exits, W1 ATR stop and time stop. |
| R3 Data Available | UNKNOWN | Requires long monthly OHLC history but no exotic data; DWX symbols with 2003+ history are sufficient. |
| R4 ML Forbidden | UNKNOWN | Fixed periods/weights/thresholds. No ML, no adaptive parameters, no martingale, one-position-per-magic. |

### R3 SP500.DWX live-promotion caveat

Live promotion T_Live gate: SP500.DWX is not broker-routable. If the EA
passes P0-P9 on SP500.DWX only, T_Live deploy requires a
parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf

- G0: 2026-05-19, PENDING -- drafted by Research from source
  6e967762-b26d-59a3-b076-35c17f2e7c36 Batch 60.

## Verwandte Strategien

- [[strategies/QM5_1298_pring-kst-d1]] -- daily KST.
- [[strategies/QM5_9501_pring-kst-w1]] -- weekly KST. Distinct:
  9575 uses monthly completed bars and slower ROC windows.
- [[strategies/QM5_1967_pring-kst-h4]] -- H4 tuned KST.
- [[strategies/QM5_2132_pring-kst-histogram-h4]] -- H4 histogram
  variant.

## Lessons Learned (während Pipeline-Lauf)

- 2026-05-19: G0 should scrutinize cadence. Expected cadence is only
  about four trades/year/symbol, but multi-symbol basket breadth keeps it
  above an annual one-shot edge. If P2 trade count is too low, reject as
  cadence-insufficient rather than R1/R2/R4 deficient.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
