# DL-077 — Low-Frequency-Aware Q08 Davey Sub-Gates

- **Status:** PROPOSED (awaiting OWNER ratification)
- **Date:** 2026-06-26
- **Author:** Claude
- **Related:** DL-070 (Q08 low-freq floor), DL-075 (8.4/8.6/8.10 → SOFT), DL-076 (Q04 low-freq pooled OOS), and the 2026-06-26 Q08.5 / Q09 `-Year 0` fixes (commits `57cd8e8e0`, `4ecf2003f`).

## 1. Problem (measured, not asserted)

Q08 is the final quality gate, but its Davey statistical battery is **largely non-functional
for the low-frequency structural edges the funnel deliberately selects.** Across all 149 Q08
aggregates on disk, per sub-gate:

| Sub-gate | Outcome | INVALID/never-PASS | Why |
|---|---|---|---|
| 8.2 dsr_mc_fdr | 121 INVALID / 28 PASS | **81% INVALID** | needs ≥60 daily-return days; low-freq edges have ~58 active days |
| 8.10 regime_crisis | 128 INVALID / 9 FAIL / 12 PASS | **86% INVALID** | too few trades per regime window |
| 8.6 chopping_block | 119 INVALID / 13 FAIL / 17 PASS | **80% INVALID** | too few trades |
| 8.9 runs_test | 92 INVALID / 57 PASS | **62% INVALID** | too few trades for a runs test on the sliced window |
| 8.4 seasonal | 121 FAIL / 28 INVALID / **0 PASS** | **never passes** | "all 12 months net-positive" is unachievable; softened to SOFT (DL-075) |
| 8.5 neighborhood | (was vacuous-PASS / false-FAIL — fixed 2026-06-26) | — | `-Year 0` window bug + empty-perturbation vacuous pass |

**Root cause: a frequency mismatch, not a code bug.** The Davey gates assume *high-frequency*
data (dozens of daily returns, many trades per regime, long win/loss sequences). The funnel,
by design (cost gates kill high-freq), selects *low-frequency* edges (5–50 trades/yr). So the
EAs that reach Q08 mostly can't be evaluated — the verdict ends up resting on the 2–3 gates
that happen to compute (8.7 PBO, 8.8 edge-decay) plus the profitability check. **Q08 has not
been meaningfully validating low-frequency sleeve quality.** This is very likely why the book
stalled: the final gate was mostly blind to exactly the kind of edge we produce.

## 2. Principle (the DL-076 pattern, applied to Q08)

DL-076 solved the identical problem at Q04: a low-freq edge sliced into 3×1yr OOS folds was
"noise per fold," so Q04 added a **pooled-OOS** path under the *same* bar. Apply the same three
principles to the Q08 Davey gates:

1. **Evaluate on the pooled full-history per-trade stream**, not thin daily/monthly/regime
   slices. A low-freq EA has 40–400 trades over 2017–2025 — enough for trade-level statistics,
   even when active *days* are too few. The stream already exists (`q08_trades`).
2. **Distinguish FAIL (a real quality failure) from INVALID (insufficient data to test).**
   INVALID must **never HARD-fail** — failing an EA on a gate that could not run is a false
   negative (exactly what the `-Year 0` bug did at scale).
3. **Require a minimum number of *computable* sub-gates for a clean PASS** — so an EA cannot
   pass Q08 on 1–2 gates while the rest are INVALID. Adapt the gates to compute; don't just
   skip them.

## 3. Per-sub-gate recalibration

- **8.2 DSR/MC/FDR** — compute the Deflated Sharpe on the **per-trade return stream** (not the
  ≥60-daily-return requirement). Keep the FDR trial-count deflation. Low-freq eligibility:
  when active daily returns < 60, switch to the trade-level estimator with a wider-CI caveat.
- **8.9 runs-test** — run the win/loss runs test on the **full-history pooled trades** (40–400
  points is sufficient); it is currently INVALID only because it is sliced too thin.
- **8.6 chopping-block** — evaluate the consecutive-loss / streak metric on the pooled stream
  with a trade-count-scaled threshold instead of a fixed minimum.
- **8.10 regime-crisis** — pool **all crisis-window trades** (concatenated) vs non-crisis,
  rather than requiring N trades inside each individual regime. If even the pooled crisis
  bucket is empty, return **INVALID-non-blocking** (already SOFT per DL-075).
- **8.4 seasonal** — replace "all 12 months net-positive" (unachievable, 0/149) with
  "net-positive over the full window AND ≥ majority of *active* months positive AND no
  catastrophic month" — a month with no trades is not a losing month. (Stays SOFT.)

## 4. Aggregator change

Make INVALID explicitly non-blocking for the HARD sub-gates (8.2/8.5/8.7/8.8/8.9): an INVALID
status cannot contribute to FAIL_HARD. Add a **min-evidence guard**: a clean Q08 PASS requires
≥ K computable (PASS/FAIL, not INVALID) sub-gates among the quality battery (recommend K=4),
else the verdict caps at FAIL_SOFT (robust-enough-for-portfolio-track but not gold-PASS).

## 5. Recommendation & decision

**Recommend ratifying** and implementing the pooled-stream low-freq path for 8.2/8.6/8.9/8.10,
the 8.4 bar change, and the aggregator INVALID-non-blocking + min-evidence guard. This is the
single highest-leverage unblock for the book: it makes the final gate actually evaluate the
edges we produce, instead of passing them vacuously or invalidating them.

**OWNER decision points:**
1. Ratify the pooled-stream principle for Q08 (parallel to DL-076 at Q04)? **[recommend yes]**
2. The min-evidence K (gates required for a clean PASS) — recommend **4**.
3. Conservatism: keep INVALID strictly non-blocking, or require a minimum evidence floor so
   "mostly INVALID" cannot reach FAIL_SOFT either? (Trades breadth against rigor.)

Until ratified, the two `-Year 0` fixes already restore 8.5 + Q09; the certified sleeves are
being re-validated against the fixed 8.5. This DL is the deeper, structural fix.
