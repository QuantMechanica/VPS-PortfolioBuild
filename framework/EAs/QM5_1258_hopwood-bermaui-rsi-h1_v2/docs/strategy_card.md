---
ea_id: QM5_1258
slug: hopwood-bermaui-rsi-h1
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/oscillator-smoothing]]"
indicators:
  - "[[indicators/rsi]]"
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "FF Hopwood thread/282290 Bermaui-RSI variant R1-R4 PASS: named FF handle+URL, RSI-of-RSI deterministic + EMA(200) bias + fixed-RR exits, major FX DWX, fixed periods no adaptive"
---

# QM5_1258 Hopwood Bermaui-RSI H1 Trend-Follower

## Quelle
- Primary: ForexFactory Steve Hopwood master thread (community-canonical
  Hopwood EA index) — thread/282290 "Steve Hopwood Forex". The
  Bermaui-RSI variant is one of Hopwood's recurring derivative-of-RSI
  EAs that smooths RSI through a second RSI pass (RSI-of-RSI / "BB-RSI"
  pattern) plus an EMA(200) directional bias on H1.
- URL: https://www.forexfactory.com/thread/282290
- Author: `Steve Hopwood` (named ForexFactory identity, open-sourced ~30
  MT4 EAs over 2009-2018, same provenance as QM5_1116 / QM5_1117 /
  QM5_1223 / QM5_1228 / QM5_1229).
- Mechanic provenance: Bermaui's smoothed-RSI indicator (community FF
  variant of double-smoothed RSI) wrapped in a one-position-per-magic
  EA by Hopwood. Not adaptive, no ML.

## Mechanik

### Entry
- Compute `RSI(14, H1)` then a second `RSI(14)` over the first RSI
  series → "Bermaui-RSI" smoothed oscillator (range 0..100, less noisy
  than raw RSI). Compute `EMA(200, H1)`.
- Trigger bar = H1 close.
- LONG: previous closed bar shows `BermauiRSI[1] > 50` AND
  `BermauiRSI[2] <= 50` (cross UP through midline) AND
  `Close[1] > EMA(200, H1)`. Enter at next bar open.
- SHORT: mirror — Bermaui-RSI crosses DOWN through 50 AND
  `Close[1] < EMA(200, H1)`.
- One position per symbol per magic (HR14). Opposite midline-cross
  closes current position before reversing.

### Exit
- Primary: opposite-direction Bermaui-RSI midline cross on closed
  H1 bar — exit at next bar open.
- Secondary: fixed RR = 2.0 take-profit from entry (P3 sweepable in
  {1.5, 2.0, 3.0}).
- Tertiary: Bermaui-RSI re-enters mid-zone (45-55) for ≥ 4 closed
  bars (trend-fade exit, P3-toggleable).

### Stop Loss
- Initial SL: `ATR(14, H1) × 2.0` from entry (P3 sweep
  {1.5, 2.0, 2.5, 3.0}).
- No trailing stop in baseline. P3-optional break-even after
  `1 × ATR` in profit.

### Position Sizing
- `RISK_FIXED = $1000` for P2-baseline (HR4).
- `RISK_PERCENT = 0.5%` for live (RISK_PERCENT-mode in T6 set file).
- Lot size derived from SL distance × pip-value.

### Filters
- Spread cap: 25 pts.
- News-filter hook (off by default for P2 — callable for live).
- No grid, no martingale, no scale-in. One position, one stop,
  deterministic.

## Concepts
- [[concepts/trend-following]] — primary (EMA(200) bias gates direction)
- [[concepts/oscillator-smoothing]] — secondary (RSI-of-RSI smoothing
  reduces midline-cross whipsaw)

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named FF handle (Steve Hopwood), specific master-thread URL, community-canonical Bermaui-RSI Hopwood variant. Relaxed-R1 (2026-05-15) requires only a verifiable link. |
| R2 Mechanisch | PASS | RSI is closed-form (Wilder 1978); RSI-of-RSI is a deterministic second pass; midline-cross + EMA-bias + fixed-RR exits are unambiguous. No discretion. |
| R3 DWX-testbar | PASS | Bermaui-RSI trend mechanic targets major FX pairs — all in DWX feed. Suggested P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, EURJPY.DWX, GBPJPY.DWX. |
| R4 No ML | PASS | Fixed RSI period (14), fixed midline (50), fixed EMA period (200), fixed ATR multiplier, fixed RR. No adaptive lot sizing. No ML, no online learning, no grid, no martingale. |

All four PASS expected — G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-18 — drafted from ForexFactory batch 6 (Hopwood
  Bermaui-RSI variant)

## Implementation Notes for Codex (P1)
- RSI is a built-in MT5 indicator (`iRSI` handle, applied price =
  `PRICE_CLOSE`). For RSI-of-RSI, compute RSI(14) over the raw RSI(14)
  output buffer — MQL5 lets you feed an indicator buffer into a second
  RSI handle via the `iRSIOnArray`-equivalent pattern (or manual SMA
  smoothing of gains/losses on the RSI series).
- Midline-cross detection: compare closed-bar [1] vs prior-closed-bar
  [2]; do NOT trigger on intra-bar oscillation.
- EMA(200) on H1 — single TF, no MTF handle complexity.
- DWX symbols for P2: **EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX,
  AUDUSD.DWX, EURJPY.DWX, GBPJPY.DWX**.
- Smoke (P1): EURUSD.DWX H1 one month; full P2: 1-year H1 per symbol.

## Verwandte Strategien
- Sibling of QM5_1116 (hopwood-asctrend-h1-tf), QM5_1117
  (hopwood-rsi-pullback-h1), QM5_1223 (hopwood-dmi-cross-h1),
  QM5_1228 (hopwood-stochastic-cross-h1), QM5_1229
  (hopwood-ma-rainbow-h4) — same Hopwood cluster, different
  oscillator primitive (SAR vs RSI extreme vs DMI vs Stoch vs MA
  ribbon vs smoothed-RSI midline).
- Differentiator vs 1117 (raw RSI pullback): Bermaui-RSI uses RSI-of-RSI
  smoothing → trigger is midline crossing of the SMOOTHED oscillator,
  not extreme of the raw oscillator. Slower, fewer false signals than
  1117, similar trade frequency to 1228 Stochastic-cross.

## Lessons Learned (während Pipeline-Lauf)
- *(populated as pipeline progresses)*
