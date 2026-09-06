# OWNER Vorlage — M11: Optimisation-branch utility check + release-cohort cutoff

- **Date:** 2026-09-06 · **Author:** Claude (Orchestrator) · **Task:** `93cd0e1c-1b91-4a36-b864-571d3cea167c` (M11, audit finding C)
- **Class:** ROT — analysis only. Nothing here changes the census, the pre-registered selection rule (DL-089), K/L/G thresholds, verdicts, the candidate pool, or the counter. The cohort/cutoff below is a **recommendation for an OWNER Mission-Control card**. No Auffangregel (ROT).
- **Standing release 2026-09-05 03:55Z:** everything except the purchase. This item is *not* covered by that release — it defines a candidate-pool cutoff, which stays ROT.

## 1 · The question

The optimisation branch (gates Q12 filter → Q13 parameter → Q14 head-to-head, fed by the DL-089 pattern-filter walk-forward census, `docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md`) is currently *mandatory* for every Q10/Q11 survivor and costs roughly one full ~1,085-cell census program per (EA, symbol) pair. Every Q14 closure to date is `KEEP_INCUMBENT`; not one challenger has ever been promoted. The CEO audit's finding C (Priority 1) therefore asks, before we spend thousands more pattern cells: **does this optimisation type add measurable value per tester-hour, and if we cannot yet prove it, what is the pre-registered stopping/continuation rule and the bounded release cohort (fixed cutoff date, inclusion/exclusion rules, an immutable incumbent per pair, and a small sealed variant set) that lets us lock in what is already terminal without draining the whole 10k-cell backlog?**

## 2 · Measured facts (all from `farm_state.sqlite` read-only, dirs on `D:`)

### 2a · The Q14 closures

Twelve optimisation-fork closure rows, **all `KEEP_INCUMBENT`, zero `CHALLENGER_PROMOTED`** (11 distinct pairs; the audit saw nine — three more closed on 09-05). Each carries a "no-change" receipt with reason `NO_CHALLENGER_BOTH_UPSTREAM_STAGES_NO_CHANGE` under `D:\QM\reports\optimization_fork\<id>\receipt.json`. "Measured cells" = full backtests actually run for that pair's census program (the rest were skipped by the activity criterion or the D1 pre-screen; `pend` = still un-run).

| # | EA (incumbent) | Symbol | Closed | Q14 verdict | census measured / pending | counter |
|---|---|---|---|---|---|---|
| 1 | QM5_10706 | GBPUSD | 08-25 | KEEP_INCUMBENT | 343 / 742 | counts |
| 2 | QM5_11421 | EURUSD | 08-25 (re-run 09-02) | KEEP_INCUMBENT | 237 / 0 | counts |
| 3 | QM5_11422 | USDCAD | 08-25 | KEEP_INCUMBENT | 255 / 830 | counts |
| 4 | QM5_1537 | XAGUSD | 09-03 | KEEP_INCUMBENT | 612 / 0 | counts |
| 5 | QM5_13054 | XTIUSD | 09-03 | KEEP_INCUMBENT | 449 / 0 | counts |
| 6 | QM5_20048 | XTIUSD | 09-04 | KEEP_INCUMBENT | 165 / 0 | counts |
| 7 | QM5_21505 | XAGUSD | 09-04 | KEEP_INCUMBENT | 165 / 0 | counts |
| 8 | QM5_11910 | NZDUSD | 09-04 | KEEP_INCUMBENT | 165 / 0 | counts (8th) |
| 9 | QM5_21507 | XAUUSD | 09-05 | KEEP_INCUMBENT | 1,041 / 48 | not yet (witness/contiguity) |
| 10 | QM5_20266 | XTIUSD | 09-05 | KEEP_INCUMBENT | 943 / 146 | not yet |
| 11 | QM5_12710 | XTIUSD | 09-05 | KEEP_INCUMBENT | 697 / 83 | not yet |

Upstream sub-stages confirm the same picture branch-wide: **12× `NO_FILTER_CHANGE` (Q12)** and **14× `NO_PARAMETER_CHANGE` (Q13)**. One pilot-era challenger was ever spawned (`CHALLENGER_SPAWNED`, Q15, QM5_21001/USDJPY, 08-14, opt_track era) and it was never promoted; for the whole DL-089 census era (from 08-22) the count of spawned or promoted challengers is **zero**. Where a filter candidate did surface (10706, per the 04-09 finding) it lost the sealed Q16 head-to-head.

**What each contributed to the counter:** the branch's product is *robustness confirmation*, not improvement — reaching Q14-terminal is what makes a pair "count", regardless of KEEP vs. CHALLENGER. The counter (`qualified_pairs_current` in `public-data/funnel-stats.json`, `book_build_guard`) is **8 / 25** (target in `D:/QM/reports/state/pipeline_state.json` = 25). Of the 11 terminal pairs only 8 currently qualify; the other 3 (09-05 closures) are blocked on M01 contiguity / witness re-runs, not on the optimisation result.

### 2b · Census cost so far and to drain

Snapshot now (`work_items where phase='OPT_CENSUS'`): **8,437 MEASURED**, 5,446 SKIPPED_EXCLUDED (activity criterion), 2,093 SKIPPED_PRESCREEN (D1 pre-screen), **10,178 pending**, 2 active — 26,158 cells across **24 programs** (~1,085–1,161 cells budgeted per program). Measured fraction of everything terminal so far = 8,437 / 15,976 ≈ **53%**.

- **Rate:** the census MEASURED **~104 cells/hour** sustained on 09-05/09-06 (hourly range 94–116; `updated_at` histogram). At present the census is claiming essentially the *whole* factory: total factory throughput is also ~104 MEASURED/h and there have been **no Q02 completions for ~3h** (OPEN_ITEMS 01:59Z 06-09) because the census outranks Q02 in claim order.
- **Spent to date:** ~8,437 backtests = on the order of ~80 full-factory-hours-equivalent, accrued 08-22 → 06-09 at a rising, shared rate (early days ran ~9 cells/h serially; MEMORY 30-08).
- **To drain the current 10,178 pending:** ~98 factory-hours (~4 days dedicated) if all were measured; **~50 factory-hours (~2 days)** at the historical 53% measured fraction (the D1 pre-screen and activity exclusion skip the rest cheaply).
- **Full path to 25 without change:** add ~8 more Q11-ready pairs still without a program (13 exist, ~8 needed; NDX behind the 44 GB RAM limit) × ~1,085 cells ≈ +8,700 cells. Total remaining budget ≈ **~18,900 cells**; the 04-09 prognosis put "25 without change" at **2–3 weeks** of shared factory time. This is exactly the "thousands more pattern cells" the audit flags.

### 2c · Conversion funnel (the value question)

| Stage | Count | Source |
|---|---|---|
| Census programs enrolled (Q10/Q11 survivors) | 24 | `OPT_CENSUS` distinct programs |
| Cells MEASURED | 8,437 | verdict=MEASURED |
| Distinct pairs reaching Q14-terminal | 11 (12 rows) | phase=Q14 KEEP_INCUMBENT |
| Q14 closures promoting a challenger | **0** | zero CHALLENGER_PROMOTED |
| Counter pairs added by optimisation *value* | **0** | all KEEP_INCUMBENT |
| Realized config uplift to the book | **0 / 11 pairs** | — |

The pre-registered success metric (return_to_maxdd improvement ≥ +5% relative in ≥2/3 of walk-forward years, DL-089 rule #1/#2) has selected **no** filter or parameter change over the incumbent in any completed pair. Statistically, 0 promotions in 11 pairs bounds the true promotion rate only loosely — a rule-of-three 95% upper bound is ≈ 3/11 ≈ **27%** — so "the branch never helps" is *not yet proven*; what *is* proven is that it has **not helped once in 11 pairs** while consuming the factory's throughput.

## 3 · Options for the OWNER

### Option A — Continue unchanged
Drain all 10,178 pending and enrol the ~8 remaining Q11 pairs (Amendment C), running every survivor through the full census.
- **Counter effect:** reaches ~25 in ~2–3 weeks; **0 additional config uplift** expected.
- **Cost:** ~18,900 more cell-budget; the census keeps monopolising the factory and starves Q02–Q10 (the counter's real bottleneck: net-new terminal pairs).
- **Reversibility:** high (append-only; nothing overwritten).
- **Refutation criterion:** if the next **5** completed pairs still promote 0 Q16-surviving challengers, "mandatory broad optimisation adds value" is refuted (0/16, upper bound ≈ 19%).

### Option B — Bounded release cohort + fixed cutoff **(recommended)**
Freeze a cohort at a **fixed date (propose 2026-09-09 00:00Z)** of the pairs already terminal or ≥50% measured; finish only those; **pause enrolment of new programs**; hold the rest append-only.
- **Cohort contract for the card:** (i) **inclusion** = every pair Q14-terminal *or* whose census program is ≥50% measured at the cutoff (today: the 11 terminal pairs + the 6 programs already at pending=0 + the near-complete 21507/20266/12710); (ii) **exclusion** = programs below threshold and not-yet-enrolled Q11 pairs → deferred to *on-demand*, not mandatory; (iii) **immutable incumbent** = the incumbent `.ex5`/`.set` SHA is frozen, the census may only emit KEEP or a *sealed* challenger, no silent reselection; (iv) **small declared variant set** = the ≤3 buy + ≤3 sell pattern filters plus the DL-088 numeric levers already enumerated (`declared_trial_count = 154` + numeric), sealed — no post-hoc additions (ROT); (v) **the rest** stays as append-only `COHORT_DEFERRED` holds, re-openable by a later card.
- **Counter effect:** locks in ~8→~11–15 pairs quickly for a few thousand cells instead of 18,900; the remaining path to 25 shifts to Q02–Q10 throughput.
- **Cost:** finish only the near-complete programs (~a few thousand cells, most already measured); frees the factory within ~1–2 days.
- **Reversibility:** high. **Refutation:** if a cohort pair's sealed variant set later shows a Q16-surviving challenger on spot-check, re-open the branch on-demand.

### Option C — Pause the branch in favour of Q02–Q10 throughput
Hold all pending OPT_CENSUS cells now (append-only), keep the 11 terminal pairs, redirect the factory to Q02–Q10 to make *new* terminal pairs toward 25.
- **Counter effect:** the 8 counted pairs stay; growth comes from fresh strategies clearing Q08→Q11→Q14, which is where the 25 target is actually gated.
- **Cost:** ~0 additional census cells; frees ~all current throughput immediately.
- **Reversibility:** high (holds are append-only, released on card). **Refutation:** if one week of Q02–Q10 focus produces fewer net-new terminal pairs than the census would have, reconsider.

## 4 · Recommendation

**Option B.** It answers finding C directly — stop before "thousands more cells" without proof — while (a) banking the pairs already through, (b) keeping every byte of evidence append-only, and (c) re-registering the utility test as a refutable rule (Option A's 5-pair refutation criterion becomes the on-demand re-entry test). Practically B ≈ "finish what is nearly done, then behave like C for everything new."

**Cost of waiting:** while this sits undecided the census keeps full claim priority, so every day of Option-A-by-default burns **~2,500 measured backtests** of factory time that has returned **0 config uplift in 11 pairs** and is currently blocking Q02 entirely (no Q02 completions in 3h). The counter's real constraint — net-new terminal pairs — is starved to re-confirm incumbents we already trust. One decision day ≈ ~2,500 cells ≈ the entire drain of two more programs that will, on the evidence, also say KEEP_INCUMBENT.

## 5 · Limits

- **"0 promoted" is a strong, verdict-level fact** (0 `CHALLENGER_PROMOTED` branch-wide). **"0 uplift" is bounded, not certain**: rule-of-three puts the 95% upper bound on the promotion rate at ~27% (11 pairs). I did **not** open all 8,437 per-cell `summary.json` files; the closure receipts are no-change receipts and per-cell return_to_maxdd deltas live in the individual cell summaries (`D:\QM\reports\work_items\<id>\...\summary.json`).
- **Tester-hours are cell-count × current rate**, not a sum of run durations; the early serial period (~9 cells/h) was far slower, so "hours spent" is an order-of-magnitude figure, not a ledger.
- **Counter = 8** is the `book_build_guard` / funnel-stats value; the gap to 11 terminal pairs is M01 contiguity + witness re-runs (10706/11421/11422/20048), which I did not independently re-derive per pair.
- **Two Q14 taxonomies exist:** the DL-089 optimisation-fork closures (above) and an older 08-13 pilot batch (11 `OPT_ELIGIBLE` + 3 `OPT_REJECTED`, opt_track/opt_card, VOL-REGIME-FILTER / EXIT-SURGERY) — excluded from the closure count as a different mechanism.
- **This is ROT and analysis-only.** The cohort, the cutoff, the immutable-incumbent rule and the sealed variant set require an OWNER Mission-Control card; nothing here has changed the census, a threshold, a verdict, or the counter, and no Auffangregel applies.

## Evidence

- DB (read-only): `D:/QM/strategy_farm/state/farm_state.sqlite` — `work_items` phase `Q14`, `OPT_CENSUS`; `agent_tasks` `93cd0e1c…`.
- `public-data/funnel-stats.json` (snapshot 2026-09-05T16:26Z: `qualified_pairs_current`=8, `qualified_pairs_target`=25, 7,461 census cells measured).
- `D:/QM/reports/state/pipeline_state.json` (2026-09-06T02:26Z: target 25; by_gate_v4 Q14=11).
- Closure receipts: `D:\QM\reports\optimization_fork\<id>\receipt.json`; census cells: `D:\QM\strategy_farm\artifacts\opt_census\DL089_<EA>_<SYM>_2019_2025\`.
- Plan/decision: `docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md`, `decisions/DL-089_pattern_filter_wf_census_v3.md`.
- Prior related Vorlage: `docs/ops/OWNER_VORLAGE_2026-09-04_census_shortening_amendment_c_bundle_rule.md`; audit map `docs/ops/CEO_AUDIT_INTEGRATION_2026-09-05.md` (M11).

## 6 - CEO review (Orchestrator, 2026-09-06 03:17Z) - corrections and the recommendation that goes to the OWNER

The analysis above (sections 1-5) was produced by an agent on the Claude lane and is kept verbatim. Two facts changed under it and one framing must be corrected before the OWNER decides:

1. **The counter is 11 / 25, not 8.** `build_qualified_roster.py --venue dxz --dry-run` (03:13Z) and `pipeline_state.json` (`operator_surface.book_guard.qualified_pairs`, 03:11Z) both count 11 qualified pairs: the three 09-05 closures (21507/XAUUSD, 20266/XTIUSD, 12710/XTIUSD) qualify now. The public `funnel-stats.json` still shows 8 because its snapshot is from 09-05 16:26Z (stale, not a different definition). The "8 vs 11 = contiguity gap" reading in sections 2a/5 is therefore obsolete.
2. **Under the OWNER's counting rule the census IS the counter path.** OWNER-DEC-A1 counts terminal v4 Q14 pairs; a `KEEP_INCUMBENT` closure counts exactly like a promotion. So "0 promotions" is an *audit* finding about the branch's optimisation value, but it is not a reason to stop the census while 25 is the goal: Option C freezes the counter at 11, and Option B (>=50 % measured cutoff) caps it at roughly 15 - see the program table below. The Option C text ("growth comes from fresh strategies clearing Q08 -> Q11 -> Q14") is wrong under A1, because Q14 requires the census.
3. **The 13 remaining programs are the 13 pairs Amendment C enrolled (OWNER YES, 2026-09-05, receipt row 14)** - i.e. the queue order of the census is already an OWNER decision in force. Reordering or pausing it is a card, never GRUEN.

Remaining census by program (03:2xZ; pending / measured / skipped), all `_opt` measurement siblings of counted or enrolled pairs:

| program | pair symbol | pending | measured | skipped | state |
|---|---|---|---|---|---|
| 41162, 41194, 41195, 41303, 41304, 41332 | EUR, XTI, XAG, XTI, XAG, NZD | 0 | 165-612 | 477-924 | terminal, counted |
| 41343, 41344 | EUR, EUR | 4 | 70 / 7 | 1,015 / 1,078 | terminal, counted |
| 41196, 41331, 41198 | XAU, XTI, XTI | 48 / 83 / 146 | 1,041 / 697 / 943 | 0 / 309 / 0 | terminal, counted (09-05) |
| 41097 | USDJPY | 227 | 858 | 0 | in progress |
| 41307, 41333, 41342, 41197, 41161, 41305, 41302, 41163, 41301, 41324, 41322, 41345 | XTI, XAU, EUR, GBP, GBP, XTI, XAU, CAD, XAU, JPY, XAU, XAU | 600-1,073 | 12-453 | 0-140 | in progress |

**Counter arithmetic.** 10,178 pending cells at the sustained ~104-130 MEASURED/h (03:01Z: 130/h; D1 pre-screen skips are free) = **3-4 factory-days** to drain all 13 programs. If they close like the first 12 (every one `KEEP_INCUMBENT`, none failed), that is **+13 -> 24 / 25**. The 25th pair needs one more Q11 survivor, and Q02-Q10 is exactly what the census currently starves (0 Q02 completions in >3 h, 772 Q02 rows pending) - that resumes automatically once the census pool empties, because the claim order is census-first. `pipeline_state.eta_to_25` for reference: {"target_pairs": 25, "qualified_pairs": 11, "remaining_pairs": 14, "eta_days": 10.89, "measured_q14_pairs_per_day": 1.286, "sample_completed_pairs": 9, "rate_window_days": 7, "reliability": "MEASURED", "capacity_lower_bound_days": 0.4, "basis": "remaining sealed strict-v4 contiguous-Q14 trigger pairs / trailing-7d raw valid v4 Q14 pair completion rate", "caveat": "The observed Q14 sample may contain NO_CHANGE pilots that are not strictly qualified. The rate is a throughput proxy, not a survival model or queue-empty ETA; it never changes the sealed trigger count."}.

**CEO recommendation (differs from section 4): Option A with a pre-registered refutation rule, not Option B.**
- Keep the census running exactly as decided (Amendment C queue order). It is the shortest path to 24/25 (~3-4 days), every byte stays append-only, and nothing is re-decided.
- Register the audit finding as a *refutation rule*, not as a stop: if the next **5** Q14 closures again promote no challenger (0/16 overall, rule-of-three upper bound ~19 %), the *mandatory* optimisation branch is refuted for the book that follows - then the branch becomes on-demand (Option B's cohort contract) **for pairs beyond 25**, and the Q14-terminal requirement in the counting rule is put to the OWNER again. Until then the branch stays mandatory because the counting rule says so.
- Fix the public counter (regenerate `funnel-stats.json` from the guard) before the website deploy - stale 8 vs. live 11 would be an evidence error on the public site.

**Cost of waiting on this card:** none for the counter (Option A is the running state). The cost of choosing B or C is a stalled counter (15 or 11) in exchange for ~3-4 factory-days returned to Q02-Q10, which produce no counted pair until they reach Q14 themselves. The 12 h Auffangregel does not apply (ROT); the running state continues either way.
