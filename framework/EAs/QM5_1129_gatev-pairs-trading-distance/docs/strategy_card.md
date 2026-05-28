---
ea_id: QM5_1129
slug: gatev-pairs-trading-distance
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/pair-trade]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/spread-zscore]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-17
g0_approval_reasoning: "R1 PASS: SSRN 141615 URL and named RFS paper; R2 PASS: deterministic distance/z-score entry and zero-cross/max-hold exits; R3 PASS: port/testable on DWX natural pairs; R4 PASS: fixed thresholds, no ML/adaptive/grid/martingale, explicit two-slot pair allocation."
---

# QM5_1129 Gatev-Goetzmann-Rouwenhorst Distance Pairs Trading

## Quelle
- Primary: SSRN 141615 — "Pairs Trading: Performance of a Relative-Value
  Arbitrage Rule" by Evan Gatev, William N. Goetzmann, K. Geert
  Rouwenhorst. Review of Financial Studies 19(3), Fall 2006
  (working paper 1999).
  URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=141615
- Reported result: 12-month formation period selects pairs by minimum
  sum-of-squared-distance of normalised prices. 6-month trading period:
  open trade when normalised-price spread breaches **2 historical-stddev**
  of formation-period spread, close when spread crosses **zero**. On
  US equity universe 1962-2002 the rule generated annualised excess
  return ~11 % with Sharpe ~1.0 before transaction costs. Modern
  replications confirm the effect is weaker post-2003 but survives in
  natural-pair contexts (commodity twins, cross-listed indices).
- Lineage: Vidyamurthy "Pairs Trading: Quantitative Methods and Analysis"
  (Wiley 2004), Avellaneda/Lee (SSRN 1153505, statarb-PCA extension).

## Mechanik

### Entry
- **Step 0 — Pair pre-selection** (offline, P0 manual): on V5's DXZ
  universe the natural pair candidates are: (a) AUDUSD ↔ NZDUSD
  (commodity-block twin currencies), (b) EURUSD ↔ GBPUSD (European
  major), (c) GDAXI ↔ UK100 (European blue-chip indices), (d) USDJPY
  ↔ EURJPY (JPY-cross pair). P0 backtest tests all four; P2 baseline
  uses AUDUSD-NZDUSD only (cleanest fundamental coupling).
- **Step 1 — Formation period** (rolling): every D1 bar, on a trailing
  252-bar window, normalise both legs to price-index-100 at window
  start. Compute `spread[t] = norm_A[t] - norm_B[t]`. Record formation
  mean `mu_f` and formation stddev `sigma_f`.
- **Step 2 — Trading rule** (current bar):
  - `z = (spread_today - mu_f) / sigma_f`
  - If `z > +2.0` and **no current open position** → enter:
    **short A + long B**, equal-dollar legs.
  - If `z < -2.0` and no current open position → enter:
    **long A + short B**.
  - Position is one composite trade with two leg orders, paired by magic
    number per HR4 (2 magic slots, one EA per pair).

### Exit
- Close when `|z| < 0.1` (spread reverts through zero — paper's "spread
  crosses zero" rule, with small dead band to avoid flip-flop on noise).
- **Force-close at 6 months** (~126 D1 bars) — paper's max-holding rule;
  pairs that don't revert in 6 months are considered structurally broken.
- **Stop-loss exit**: if `|z| > 4.0` mid-trade (spread doubled
  away) → close (one-shot disaster exit, paper does not have this but
  V5 HR5 mandates per-position max-loss).

### Stop Loss
Per-leg ATR(D1,14) * 3 hard stop AND portfolio MAX_DD 20% trip (HR3/5).
Plus the `|z|>4.0` composite stop above.

### Position Sizing
V5 standard: `RISK_FIXED = $1,000` per **pair-trade** (split equally
across the two legs → $500 per leg). `RISK_PERCENT` for live (HR4).

### Zusätzliche Filter
- Both legs must have full 252-bar D1 history.
- Skip new entries during weeks with major scheduled news on either
  underlying (NFP, ECB rate decision, BoE for the European pair).
- Optional regime overlay (P3): pause new entries if AUDUSD-NZDUSD pair
  is in a "decoupling" regime (e.g., 60d rolling correlation < 0.5).
- V5 mandatory: MAX_DD trip.

## Concepts
- [[concepts/pair-trade]] -- primary, family-defining
- [[concepts/mean-reversion]] -- spread is assumed mean-reverting

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Gatev/Goetzmann/Rouwenhorst RFS 2006, ~3000 citations; canonical distance-method pairs reference. All three authors are tenured (Rouwenhorst=Yale, Goetzmann=Yale, Gatev=Boston College). Hundreds of follow-up replications |
| R2 Mechanical | PASS | All three steps (formation stats, z-score, entry/exit thresholds) are closed-form. Pair pre-selection is one-time offline judgement, not per-bar discretion |
| R3 Data Available | PASS (ported) | Paper's US-equity-pair universe is not on DXZ. Port to natural DXZ pairs is clean: AUDUSD-NZDUSD (commodity twins, historical correlation ~0.85), EURUSD-GBPUSD (European major pair, correlation ~0.7), GDAXI-UK100 (European blue-chip pair). Smaller universe than paper (4 pairs vs hundreds) but each pair is more fundamentally-coupled than random US-equity matches, which improves the prior |
| R4 ML Forbidden | PASS | Distance-method pairs trading is the *non-ML* baseline in the statarb literature (Avellaneda-Lee PCA is the ML-adjacent extension; we do NOT do that). Z-score formula, fixed thresholds, no learning |

## Pipeline-Verlauf
- G0: 2026-05-17 — drafted from SSRN FEN batch 2 (autonomous wake), PENDING

## Verwandte Strategien
- New family for V5: first **pair-trade** strategy. Existing 80+ cards are
  all single-instrument. Adds composite-trade complexity (2 magic slots,
  paired entry/exit) which Codex must implement carefully — see Implementation
  Notes
- Adjacent (in spirit): QM5_1083 (chan-gld-gdx-z2) — Z-score-2 mean-
  reversion on a single instrument (gold). Same z-score-2 entry, single-leg

## Lessons Learned (während Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- **Pair pre-selection is offline** — P2 baseline tests AUDUSD-NZDUSD only.
  P3 sweep tests the other three pairs independently. EA is parametrised
  by "Pair_A" and "Pair_B" symbol inputs.
- DWX symbols: AUDUSD.DWX + NZDUSD.DWX (P2 baseline).
  P3 expansion: EURUSD.DWX + GBPUSD.DWX, GDAXI.DWX + UK100.DWX,
  USDJPY.DWX + EURJPY.DWX.
- Timeframe: D1 (paper uses daily prices; intraday introduces
  microstructure noise the distance method wasn't designed for).
- Normalised price = `price[t] / price[window_start]` (price-relative
  index, not log-return).
- **Two magic slots per pair** per HR4 — Codex must issue one
  `OrderSend` per leg with distinct magic numbers. Composite-trade close
  must close BOTH legs atomically (one fails → close the other immediately).
- Hedging note: this is a **net-delta-zero** trade in dollar terms but
  the two legs are tracked as independent positions. P0 verification on
  T1 should confirm the net P&L sums correctly across both legs.
- P3 sweep variants: z-entry 1.5 / 2.0 / 2.5; z-exit 0 / 0.1 / 0.5;
  formation window 126 / 252 / 504 D1 bars; max-hold 60 / 126 / 252 D1
  bars; correlation-regime overlay on/off.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung pipeline_phase aktualisieren + last_updated. Bei FAIL: pipeline_phase: DEAD + Lessons-Learned-Eintrag.*
