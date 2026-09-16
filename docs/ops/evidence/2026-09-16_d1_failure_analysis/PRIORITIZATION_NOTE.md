# Prioritization note — D1 V3 Q08 cohort failure concentration

Date: 2026-09-16. Full analysis: `ANALYSIS.md` (same directory). Verdict: the 11 FAIL_HARDs are an
**economic filter** (universal §8.2 DSR EDGE_HARD, ann. Sharpe ≤ 0.42 over 2017–2025), **not artifact
bias** — the `empty_strategy_params` setfile defect (8/13 rows) never enters `hard_causes`, rows with
full §8.5/§8.7 evidence fail identically, and DL082 ext-option-D cannot rescue an §8.2 EDGE_HARD.

1. **Remaining 3 rows** (brief said 4; 11882 finished during analysis): 10269 gawd-wma30 trend —
   same family as 10267 (−22.6% net); expect FAIL_HARD on §8.2 (its setfile has 5 params, evidence
   will be complete). 13012 grimes-complex-pb MR — evidence will run (12 params). 10280 whc-rsrs —
   **EMPTY setfile: §8.5/§8.7 will go INVALID again**; backfill params before running or expect a
   repeat of 10211's INVALID. Do NOT requeue any FAIL_HARD row over the setfile defect — the defect
   is not what failed them.
2. **Q08 DSR remainder cohort (agent-34 audit)**: cross-reference in `CROSSREF_agent34_q08_dsr_remainder.md`.
   Expect §8.2 DSR to dominate hard causes there as well; apply the same two-axis test before
   attributing anything to tooling.
3. **Admission lint, not gate loosening**: add a pre-enqueue check that the target setfile carries
   ≥1 `strategy_*` param (or a deliberate ablation fallback), and make `_guess_baseline_setfile`'s
   ablation pickup deterministic rather than glob-order luck. This restores evidence completeness;
   it would not change any FAIL_HARD.
4. **Future NDX/GDAXI candidates**: pre-screen ann. Sharpe ≥ ~0.5 on the 9-year D1 window (below that
   is an automatic §8.2 fail at cohort trade counts); prefer MR families over trend/MA for index
   sleeves (only MR rows escaped FAIL_HARD); require non-negative INFLATION_2022 crisis-window P&L;
   demote high-PBO (>50%) plateaus even when §8.5 passes.
5. **Q08 stays as-is** per OWNER §12: the failure concentration is the gate working correctly. The
   one true loss (10211, DSR p=0.010, excluded by the setfile defect) is recovered by fixing the
   setfile pipeline, not by recalibrating the gate.
