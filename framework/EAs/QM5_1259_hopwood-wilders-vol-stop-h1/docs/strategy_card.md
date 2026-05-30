---
ea_id: QM5_1259
slug: hopwood-wilders-vol-stop-h1
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/volatility-stop]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/ema]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "FF Hopwood thread/282290 + Wilder 1978 Volatility System R1-R4 PASS: named FF handle+book cornerstone, ATR(7)x3 trail flip closed-form, major FX+XAUUSD DWX, bounded worst-case per trade no ML"
---

# QM5_1259 Hopwood Wilders Volatility-Stop H1 Trend-Follower

## Quelle
- Primary: ForexFactory Steve Hopwood master thread (community-canonical
  Hopwood EA index) — thread/282290 "Steve Hopwood Forex". The
  Wilders-Volatility-Stop variant is one of Hopwood's recurring
  trend-with-volatility-trail EAs implementing Welles Wilder's original
  Volatility System (chandelier-style ATR trail flips long↔short on
  break of the trail).
- URL: https://www.forexfactory.com/thread/282290
- Author: `Steve Hopwood` (named ForexFactory identity).
- Mechanic provenance: Welles Wilder, "New Concepts in Technical Trading
  Systems" (1978), Volatility System chapter — closed-form
  ATR-multiple trailing line that flips position on close beyond. Not
  adaptive, no ML.

## Mechanik

### Entry
- Compute `ATR(7, H1)` and `EMA(200, H1)`. Maintain a Wilder
  Volatility-Stop line `VS[t]`:
  - Initialize on first bar: if `Close[0] > EMA(200, H1)` then
    `VS[0] = Close[0] - 3.0 × ATR(7)[0]` (long-trail), else
    `VS[0] = Close[0] + 3.0 × ATR(7)[0]` (short-trail).
  - On each subsequent closed bar `t`:
    - If currently long-trailing: `VS[t] = max(VS[t-1],
      Close[t] - 3.0 × ATR(7)[t])`. If `Close[t] < VS[t]` → FLIP to
      short-trailing, set `VS[t] = Close[t] + 3.0 × ATR(7)[t]`.
    - If currently short-trailing: `VS[t] = min(VS[t-1],
      Close[t] + 3.0 × ATR(7)[t])`. If `Close[t] > VS[t]` → FLIP to
      long-trailing, set `VS[t] = Close[t] - 3.0 × ATR(7)[t]`.
- Trigger bar = H1 close.
- LONG: VS flips from short-trailing to long-trailing on closed bar
  AND `Close[1] > EMA(200, H1)`. Enter at next bar open.
- SHORT: VS flips from long-trailing to short-trailing on closed bar
  AND `Close[1] < EMA(200, H1)`. Enter at next bar open.
- One position per symbol per magic (HR14).

### Exit
- Primary: VS flip opposite direction on closed H1 bar → exit at next
  bar open (and re-enter the new direction if EMA(200) filter aligns).
- Secondary: hard stop at the current VS line (it IS the trailing
  stop). VS is bounded-worst-case: max loss per trade = entry-vs-
  initial-VS distance + slippage.
- Tertiary: optional take-profit at `entry ± 4 × ATR(7)` (P3
  sweepable in {3.0, 4.0, 5.0, off}).

### Stop Loss
- The Volatility-Stop line IS the SL. Initial SL on entry =
  `3.0 × ATR(7)` from entry (P3 sweep {2.0, 2.5, 3.0, 3.5, 4.0}).
- The trail tightens only — never widens — once the position is open
  (Wilder's original rule).

### Position Sizing
- `RISK_FIXED = $1000` for P2-baseline (HR4).
- `RISK_PERCENT = 0.5%` for live (RISK_PERCENT-mode in T6 set file).
- Lot size derived from initial SL distance × pip-value.

### Filters
- Spread cap: 25 pts.
- News-filter hook (off by default for P2 — callable for live).
- No grid, no martingale, no scale-in. VS bounds worst-case per trade.

## Concepts
- [[concepts/trend-following]] — primary (EMA(200) bias gates direction;
  VS flip captures trend reversals)
- [[concepts/volatility-stop]] — primary trail mechanic (Wilder 1978)

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named FF handle (Steve Hopwood), specific master-thread URL, community-canonical Hopwood Volatility-Stop EA. Relaxed-R1 (2026-05-15) requires only a verifiable link. |
| R2 Mechanisch | PASS | Wilder's Volatility System is closed-form (1978 reference text); ATR + trailing-stop flip + EMA-bias are unambiguous. No discretion. |
| R3 DWX-testbar | PASS | Volatility-Stop trend mechanic targets major FX pairs — all in DWX feed. Suggested P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, plus XAUUSD.DWX (gold often profits from ATR-trail trend systems). |
| R4 No ML | PASS | Fixed ATR period (7), fixed multiplier (3.0), fixed EMA period (200). The trail is deterministic, bounded worst-case per trade (max loss = entry-to-initial-VS distance). No adaptive lot sizing, no ML, no online learning, no grid, no martingale, no scale-in. |

All four PASS expected — G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-18 — drafted from ForexFactory batch 6 (Hopwood
  Wilders-Volatility-Stop variant)

## Implementation Notes for Codex (P1)
- ATR is a built-in MT5 indicator (`iATR`). Wilder's smoothing
  (period 7) is the default for `iATR`.
- VS line is maintained as a custom state variable (not a built-in).
  Update on every closed-bar tick (use `OnTick` with closed-bar gate
  via `iTime(_Symbol, PERIOD_H1, 0) != lastBarTime`).
- Flip detection: track `mode ∈ {long-trail, short-trail}` as enum.
  Detect mode change between current and previous bar — that is the
  signal.
- EMA(200) on H1 — single TF, no MTF handle complexity.
- DWX symbols for P2: **EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX,
  AUDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, XAUUSD.DWX**.
- Smoke (P1): EURUSD.DWX H1 one month; full P2: 1-year H1 per symbol.

## Verwandte Strategien
- Sibling of QM5_1116 (hopwood-asctrend-h1-tf), QM5_1117
  (hopwood-rsi-pullback-h1), QM5_1223 (hopwood-dmi-cross-h1),
  QM5_1228 (hopwood-stochastic-cross-h1), QM5_1229
  (hopwood-ma-rainbow-h4), QM5_1258 (hopwood-bermaui-rsi-h1) —
  same Hopwood cluster, different primitive (oscillator-cross
  vs MA-alignment vs Wilder-volatility-trail).
- Differentiator: this is the only Hopwood-cluster card that uses a
  closed-form VOLATILITY-trail to define BOTH the entry trigger
  (flip-on-break) and the running stop. Other cluster cards use an
  oscillator trigger + a separate ATR stop. Expect higher mean-trade-
  duration and lower trade-count than the oscillator-based siblings.

## Lessons Learned (während Pipeline-Lauf)
- *(populated as pipeline progresses)*
