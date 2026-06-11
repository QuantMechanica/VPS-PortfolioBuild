---
ea_id: QM5_10016
slug: ff-ema100-bb-tdi-h1
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "hammadshahir, Simple Strategy For New Traders, ForexFactory, 2016-09-25, https://www.forexfactory.com/thread/post/9159848"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/bollinger-pullback]]"
  - "[[concepts/ema-trend-filter]]"
  - "[[concepts/tdi-confirmation]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/tdi]]"
  - "[[indicators/rsi]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, AUDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "EMA100/Bollinger/TDI pullbacks on H1; estimate 30-70 trades/year/symbol after anti-chop filters."
expected_trades_per_year_per_symbol: 45
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id with ForexFactory URL and named handle hammadshahir."
r2_mechanical: PASS
r2_reasoning: "Card specifies EMA(100), BB(20,2), deterministic TDI-proxy cross, and Bollinger-bandwidth anti-chop filter as explicit entry/exit rules — all implementable by Codex."
r3_data_available: PASS
r3_reasoning: "EURUSD/GBPUSD/AUDJPY/XAUUSD.DWX are available DWX H1 symbols."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed indicator thresholds, one position per magic, no ML/adaptive/grid/martingale."
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL/handle present; R2 card gives deterministic EMA100/BB/TDI pullback entries and TP/SL/TDI/time exits with ~45 trades/year/symbol; R3 DWX FX/XAU testable; R4 fixed non-ML one-position rules."
---

# ForexFactory EMA100 Bollinger TDI Pullback H1

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: hammadshahir, "Simple Strategy For New Traders", ForexFactory, 2016, URL https://www.forexfactory.com/thread/post/9159848.
- Author / handle: `hammadshahir`.
- Source location: first post defines Bollinger Bands(20,2), EMA100 close, TDI with RSI/Stochastic alternatives, H1/H4/D1, long only above or bouncing from EMA100 near middle/lower Bollinger with TDI cross up, SL 20-30 pips or below EMA100/previous low, TP at upper band or TDI cross down; short mirrors below EMA100.

## Mechanik

### Entry
- Work on H1 baseline; P3 may sweep H4.
- Compute EMA(100), Bollinger Bands(20,2), TDI green/red lines. If TDI implementation is unavailable in P1, use RSI(7) signal SMA(2) crossing RSI(7) baseline SMA(7) as deterministic TDI proxy.
- Long:
  - Close[1] > EMA100[1].
  - Low[1] <= Bollinger middle band or Low[1] <= EMA100[1] + 0.25 * ATR(14,H1).
  - Close[1] > EMA100[1].
  - TDI green crosses above TDI red on bar [1].
  - Bollinger Bandwidth(20,2) > its 100-bar 25th percentile to avoid source-described chaos.
  - Enter long at next H1 open.
- Short mirrors below EMA100 with TDI green crossing below red and price near middle/upper band.

### Exit
- Long TP at upper Bollinger Band.
- Short TP at lower Bollinger Band.
- Exit early on opposite TDI cross.
- Time stop: 20 H1 bars.

### Stop Loss
- Long SL = min(previous swing low over 5 bars, EMA100 - 5 pips), but no tighter than 20 pips and no wider than 30 pips on FX majors.
- Short SL mirrors above previous swing high / EMA100.
- XAUUSD uses 0.8 * ATR(14,H1) for the 20-30 pip source stop analog.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Skip if price crossed EMA100 more than 3 times in the last 20 bars.
- One active position per symbol/magic.

## Concepts
- [[concepts/bollinger-pullback]] - primary
- [[concepts/ema-trend-filter]] - secondary
- [[concepts/tdi-confirmation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory URL plus named handle `hammadshahir`. |
| R2 Mechanical | UNKNOWN | Source is mostly mechanical but uses "avoid chaos" and TDI template language; card formalizes those into Bollinger bandwidth and EMA-cross-count filters for reviewer adjudication. |
| R3 DWX-testbar | PASS | Uses OHLC-derived EMA, Bollinger, RSI/TDI proxy on DWX FX/metals. |
| R4 No ML | PASS | Fixed indicators and thresholds, one position, no ML/grid/martingale. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, AUDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9929_ff-bb-rsi-stoch-m30]] - similar BB oscillator confirmation; this card's differentiator is EMA100 trend/bounce plus TDI cross and source anti-chaos filter.
- [[strategies/QM5_9957_ff-tf15-tdi-10ema-m15]] - TDI/EMA M15 system; this card is slower H1 Bollinger pullback.

## Lessons Learned
- TBD during pipeline run.

