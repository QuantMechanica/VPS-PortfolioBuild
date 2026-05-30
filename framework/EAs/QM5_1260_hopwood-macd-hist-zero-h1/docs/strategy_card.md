---
ea_id: QM5_1260
slug: hopwood-macd-hist-zero-h1
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/macd-histogram]]"
indicators:
  - "[[indicators/macd]]"
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS FF source URL; R2 PASS mechanical MACD histogram zero-cross/EMA entry and exits; R3 PASS on DWX FX symbols; R4 PASS fixed non-ML one-position rules."
---

# QM5_1260 Hopwood MACD-Histogram Zero-Cross H1 Trend-Follower

## Quelle
- Primary: ForexFactory Steve Hopwood master thread (community-canonical
  Hopwood EA index) — thread/282290 "Steve Hopwood Forex". The
  MACD-Histogram zero-cross variant is one of Hopwood's recurring
  momentum-with-trend-filter EAs implementing a MACD-histogram-zero
  trigger with an EMA(200) directional bias.
- URL: https://www.forexfactory.com/thread/282290
- Author: `Steve Hopwood` (named ForexFactory identity).
- Mechanic provenance: MACD (Appel, 1979) histogram = MACD-line − signal-
  line. A zero-cross of the histogram = momentum-acceleration regime
  change. Wrapped in a one-position-per-magic EA by Hopwood with a
  trend filter. Not adaptive, no ML.

## Mechanik

### Entry
- Compute `MACD(12, 26, 9, H1)` and derive histogram = `MACD - signal`.
  Compute `EMA(200, H1)`.
- Trigger bar = H1 close.
- LONG: previous closed bar shows `Hist[1] > 0` AND `Hist[2] <= 0`
  (histogram crosses UP through zero) AND `Close[1] > EMA(200, H1)`.
  Enter at next bar open.
- SHORT: mirror — `Hist[1] < 0` AND `Hist[2] >= 0` AND
  `Close[1] < EMA(200, H1)`. Enter at next bar open.
- One position per symbol per magic (HR14). Opposite zero-cross
  closes current position before reversing.

### Exit
- Primary: opposite-direction histogram zero-cross on closed H1 bar
  — exit at next bar open.
- Secondary: fixed RR = 2.0 take-profit from entry (P3 sweepable in
  {1.5, 2.0, 3.0}).
- Tertiary: histogram absolute-value collapse < `0.25 × max-abs-Hist
  over last 20 bars` for ≥ 3 closed bars (momentum-fade exit,
  P3-toggleable).

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
- [[concepts/macd-histogram]] — primary trigger (histogram zero-cross
  captures momentum-acceleration regime shift)

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named FF handle (Steve Hopwood), specific master-thread URL, community-canonical Hopwood MACD-Histogram-Zero EA. Relaxed-R1 (2026-05-15) requires only a verifiable link. |
| R2 Mechanisch | PASS | MACD is closed-form (Appel 1979), histogram = MACD − signal is arithmetic. Zero-cross + EMA-bias + fixed-RR exits are unambiguous. No discretion. |
| R3 DWX-testbar | PASS | MACD-histogram zero-cross trend mechanic targets major FX pairs — all in DWX feed. Suggested P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, EURJPY.DWX, GBPJPY.DWX. |
| R4 No ML | PASS | Fixed MACD periods (12, 26, 9), fixed zero threshold, fixed EMA period (200), fixed ATR multiplier, fixed RR. No adaptive lot sizing. No ML, no online learning, no grid, no martingale. |

All four PASS expected — G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-18 — drafted from ForexFactory batch 6 (Hopwood
  MACD-Histogram-Zero-Cross variant)

## Implementation Notes for Codex (P1)
- MACD is a built-in MT5 indicator (`iMACD`, fast=12, slow=26,
  signal=9, applied price = `PRICE_CLOSE`). Histogram buffer is
  `MAIN_LINE - SIGNAL_LINE` (or use the platform's combined buffer).
- Zero-cross detection: compare `Hist[1]` (last closed bar) vs
  `Hist[2]` (prior closed bar). Trigger only when sign actually
  flips — i.e., `Hist[1] * Hist[2] < 0` (strict, not ≤).
- EMA(200) on H1 — single TF, no MTF handle complexity.
- Momentum-fade exit (tertiary): keep a 20-bar rolling max of
  `|Hist|` and compare current `|Hist|` to 25% of that max.
- DWX symbols for P2: **EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX,
  AUDUSD.DWX, EURJPY.DWX, GBPJPY.DWX**.
- Smoke (P1): EURUSD.DWX H1 one month; full P2: 1-year H1 per symbol.

## Verwandte Strategien
- Sibling of QM5_1116 (hopwood-asctrend-h1-tf), QM5_1117
  (hopwood-rsi-pullback-h1), QM5_1223 (hopwood-dmi-cross-h1),
  QM5_1228 (hopwood-stochastic-cross-h1), QM5_1229
  (hopwood-ma-rainbow-h4), QM5_1258 (hopwood-bermaui-rsi-h1),
  QM5_1259 (hopwood-wilders-vol-stop-h1) — same Hopwood cluster,
  different oscillator primitive.
- Differentiator vs QM5_1224 (antor-mtf-macd-scalper): 1224 uses MTF
  MACD synchronization across M5/M15/H1 for scalp entries. This card
  uses single-TF MACD-HISTOGRAM zero-cross on H1 for swing entries —
  different timing primitive (acceleration regime vs sync confirmation)
  and different trade frequency profile.

## Lessons Learned (während Pipeline-Lauf)
- *(populated as pipeline progresses)*
