---
ea_id: QM5_10050
slug: ff-corr-triad-h1
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "Blud4oilPrgm, Correlation EA, ForexFactory, 2009-06-11, https://www.forexfactory.com/thread/post/2804461"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/cross-pair-confirmation]]"
  - "[[concepts/moving-average-crossover]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX]
period: H1
expected_trade_frequency: "Three-pair H1 MA-cross concurrence is restrictive; conservative estimate 15-40 trades/year on EURUSD."
expected_trades_per_year_per_symbol: 28
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 FF URL+handle; R2 mechanical H1 triad MA-cross entry with ATR TP/SL exits and ~28 trades/year on EURUSD; R3 DWX FX symbols testable; R4 fixed no-ML one-position."
---

# ForexFactory Correlation Triad H1 MA Cross

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: Blud4oilPrgm, "Correlation EA", ForexFactory, 2009, URL https://www.forexfactory.com/thread/post/2804461.
- Author / handle: `Blud4oilPrgm`.
- Source location: first post defines H1 MA(15)/MA(30) cross states on EURUSD, USDCHF, and EURCHF, with EURUSD execution only when all three pair signals agree; the same thread gives ATR(10)-derived TP and 3 x ATR stop code.

## Mechanik

### Entry
- Evaluate at each completed H1 bar.
- Compute SMA(15) and SMA(30) on EURUSD.DWX, USDCHF.DWX, and EURCHF.DWX.
- Long EURUSD:
  - EURUSD: SMA(15) crosses above SMA(30) on the just-closed H1 bar.
  - EURCHF: SMA(15) crosses above SMA(30) on the just-closed H1 bar.
  - USDCHF: SMA(15) crosses below SMA(30) on the just-closed H1 bar.
  - Enter long EURUSD at the next H1 open.
- Short EURUSD mirrors:
  - EURUSD and EURCHF cross below SMA(30).
  - USDCHF crosses above SMA(30).
  - Enter short EURUSD at the next H1 open.

### Exit
- TP = 1 x ATR(10,H1) on EURUSD at entry.
- Optional source management mentions closing half at 1 x ATR and trailing the balance; V5 baseline compresses this into a single position with full TP at 1 x ATR.
- Exit on opposite triad signal before TP/SL.

### Stop Loss
- SL = 3 x ATR(10,H1) on EURUSD at entry, matching the thread's ATR stop code.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Requires EURUSD.DWX, USDCHF.DWX, and EURCHF.DWX H1 data to be available and synchronized.
- One active EURUSD position per magic.
- Skip if any confirmation symbol has a missing H1 bar at the decision timestamp.

## Concepts
- [[concepts/cross-pair-confirmation]] - primary
- [[concepts/moving-average-crossover]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory URL plus named handle `Blud4oilPrgm`. |
| R2 Mechanical | PASS | Source specifies timeframe, three MA-cross conditions, target symbol, ATR TP, ATR SL, and trailing/partial variant. |
| R3 DWX-testbar | PASS | EURUSD, USDCHF, and EURCHF are standard DWX FX symbols; all signals use H1 OHLC-derived SMA/ATR. |
| R4 No ML | PASS | Fixed MA/ATR periods, one EURUSD position, no ML/grid/martingale/adaptive equity parameters. |

## R3
Primary P2 basket: EURUSD.DWX only. Confirmation data required from USDCHF.DWX and EURCHF.DWX.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9951_ff-macd-bias-ema48-m15]] - single-symbol MACD/EMA bias; this card is cross-pair MA-cross concurrence.
- [[strategies/QM5_9976_ff-ema-fibo-rsi-stoch]] - indicator stack on one symbol; this card's primitive is cross-symbol confirmation.

## Lessons Learned
- TBD during pipeline run.

