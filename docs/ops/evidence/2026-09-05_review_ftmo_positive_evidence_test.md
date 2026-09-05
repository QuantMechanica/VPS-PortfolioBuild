# Independent review — FTMO positive-evidence acceptance test

Reviewed: `docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md`  
Source SHA-256: `5697ceec273c716da9e21318d28c885e364466587bd0453c1485a6a679c51f7c`  
Date: 2026-09-05  
Verdict: **FAIL**

The draft has a sound pre-result seal concept, governed-only live semantics, a two-sided lift/keep structure, and a separate OWNER purchase ceremony. It is not yet safe to ratify because three load-bearing statistical clauses are internally inconsistent or non-operational. The minimal diff below is not applied.

## Findings

### F1 — BLOCKER: §D silently drops the stricter P1 lower-bound

The draft says it will apply the strictest existing set and explicitly identifies the unresolved 0.80-vs-0.70 conflict (`OWNER_VORLAGE...:129`, `:209`). But the operative lift rule requires only P1 lower-95 ≥ 0.70 (`:156-159`). The currently ratified builder constant is `P1_LOWER_BOUND_FLOOR = 0.80` (`tools/strategy_farm/portfolio/build_book_ftmo.py:53-54`), and the timebox evaluator embeds `design_bar_p1 = 0.80` (`tools/strategy_farm/portfolio/ftmo_timebox_eval.py:69-91`). Thus a result with point 0.82 and lower bound 0.75 would lift under §D while failing the builder/timebox bar.

Required correction: pending OWNER reconciliation, §D must require point ≥0.80 **and lower-95 ≥0.80**. This is the intersection/stricter set and introduces no new number.

### F2 — BLOCKER: declared trials are not DSR selection trials

The draft says the DSR calculation uses “declared trial count 154 per identity” and that an identity ledger count overrides it (`OWNER_VORLAGE...:141`, `:161`, `:201`). The implementation explicitly says the opposite distinction:

- `framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py:41-46`: `selection_trial_count` is the number selected from; measuring 154 cells is not necessarily selection.
- `framework/scripts/emit_q16_lineage.py:16-21`: a preregistered predicate has selection count 1 even if all 154 cells were measured; the value is never derived from the measured count.
- `sub_8_2_dsr_mc_fdr.py:161-176`: missing or `<2` uses the fleet default 369; an explicit selection count `c` uses effective candidates `369 + c - 1`. Therefore explicit 154 means 522, not 154.
- `sub_8_2_dsr_mc_fdr.py:225-245`: the decisive quantity is a null p-value `<0.05`. The draft phrase “does not reject edge” is directionally wrong; the gate rejects the multiple-testing null/supports edge.

Required correction: seal and consume each identity’s actual `selection_trial_count`, preserve the engine’s effective-count rule, and use “rejects the null” wording. Do not default declared count 154 into selection multiplicity.

### F3 — BLOCKER: the “powered holdout” has no predeclared power rule

The draft calls a minimum-power floor binding, but supplies no minimum effective n, target interval width, detectable effect, type-II error/power, or deterministic pass/fail calculation (`OWNER_VORLAGE...:143-148`). Alpha 0.05 describes type-I error; it does not establish sample adequacy. `ftmo_timebox_eval.py:925-950` reports HAC effective n but enforces no minimum, while its only bootstrap sample guard is 100 replications (`:299-315`), which is computational replication count, not market sample size.

OQ-2 therefore is not decidable as written: “powered” can be assigned after results are known. A multi-seed bootstrap also does not add independent market observations and cannot repair an under-powered market window. Multiple non-overlapping sealed windows or a longer sealed OOS can add observations; extra random seeds only test Monte Carlo stability.

Required correction: before results, OWNER must choose an admissible market population and an explicit power/precision rule (for example, a fixed minimum HAC effective n and/or maximum CI width, with its existing authority or an explicitly acknowledged new ROT threshold). Until then §D must remain inert. Remove “multi-seed” as a way to widen the evidence population.

### F4 — HIGH: “strictest go-criteria set” omits four rulepack criteria

The operative D.1 list (`OWNER_VORLAGE...:156-160`) includes only probability thresholds and positive net expectancy. The referenced rulepack also requires:

- official snapshot age ≤7 days (`FTMO_2S_100K_SWING_V2.json:457-463`);
- zero unadjudicated execution-fidelity mismatches (`:464-469`);
- complete intratrade MTM, costs, swaps, margin and pending state; closed-P&L proxy forbidden (`:470-475`);
- ≥1 clean Free Trial/shadow run with zero operational defects (`:494-498`).

Either add these as necessary conditions for the claimed “strictest existing go-criteria set,” or rename D.1 to the “statistical subset” and explicitly state the omitted items remain purchase gates. Complete MTM must in any case precede an FTMO rule-breach probability claim.

### F5 — HIGH: the evaluator and DSR multiplicity inputs are not sealed

The seal pins the contract, roster/streams, rulepack, official snapshot, builder, DSR engine, and repaired calendar (`OWNER_VORLAGE...:186-195`). `prepare-config` embeds the rules/bootstrap and pins stream/rulepack/cost inputs (`ftmo_timebox_eval.py:440-510`), but it does not bind the evaluator source that implements resampling, outcomes and HAC. A post-seal evaluator-code change could alter the result with an unchanged config.

Required correction: record the evaluator module SHA-256, the prepared-config SHA-256, exact cost snapshot, and per-identity Q07/Q08/lineage inputs carrying `selection_trial_count`. Current module hashes for review reproducibility are:

- `ftmo_timebox_eval.py`: `abe760efc399b74abe48da6d6dadc60bce70c75fbd689d5c55b2ac35dca7c68d`
- `build_book_ftmo.py`: `255322de5e4d47cc1dde7a0424101e4d3bb28e939c4e60ea48334a71c3dc7bc5`
- `sub_8_2_dsr_mc_fdr.py`: `906bef88c9d903c7dccdc01a60a4a9e65c0fcd70ca99879836dd35ac354e8fe1`
- `opt_census.py`: `17f19954bc481755788338cf1b2c5ea3c0d2f425c7daa3ebf73fe7b3fcf2ef18`
- `emit_q16_lineage.py`: `d518dee53016ca26f89f8e775c589603d3460e244dbc878c6fa70fbd4687d3cc`

### F6 — MEDIUM: integration citations contradict the current branch

Line 6 correctly says the sibling files and receipt rows 1–17 are present and this is row 18. Later text still says receipt row 8 is cross-branch/not present (`:76`), proposes receipt row 9 (`:199-203`), and says the three siblings/rows 7–8 are absent (`:214`). On the reviewed branch, `decisions/2026-09-02_owner_receipts_ceo_asks.md:28` already contains pending row 18. The three cited sibling files also exist. These stale statements make the prescribed signature target ambiguous.

Required correction: re-verify all anchors now and consistently identify the existing pending row 18; do not append a second row 9/18.

## Checks that pass

- Provider/go-criterion numbers in §B match the current rulepack at lines 457-504; the rulepack file SHA-256 is correctly stated as `298ef1285eca49ea7f010ebc0a9353b5a821fccb40a025be129f5ca5314fd992`.
- The provider snapshot digest at rulepack line 24 matches the value quoted by the draft.
- FUND_SCORE 1.0, P1 lower-bound 0.80, correlation 0.50, weight budget 10.0, unit weight 1.0, and minimum sleeves 3 match `build_book_ftmo.py:53-77,463-477`.
- The 25-pair counter is correctly treated as necessary but not sufficient (`book_build_guard.py:28,235-239`; draft `:21,:123,:174`).
- Governed-only live attribution is internally consistent and symmetric: manual magic=0 trades count neither for nor against; live is supporting only and cannot lift or block (`OWNER_VORLAGE...:64-71,:163-165`).
- The keep-side refutation list mirrors failures of the stated lift conjunction (`:167-174`), apart from the threshold/multiplicity defects above.
- Purchase, T_Live, AutoTrading and deployment remain separate OWNER actions (`:28,:195-197`).

## Minimal corrective diff — not applied

```diff
--- a/docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md
+++ b/docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md
@@ §C DSR / multiple-testing engine
-Declared trial count for the pattern-WF selection = 154 ... otherwise the fleet default 154 applies.
+The measured census declares 154 arms, but declared_trial_count is not selection_trial_count. Seal each identity's explicit selection_trial_count from its Q07/Q08/Q16 lineage. The DSR engine uses fleet default 369 when selection_trial_count is missing or <2, and 369 + selection_trial_count - 1 otherwise. Never derive selection multiplicity from the 154 measured arms.
@@ §C Minimum-power floor
-Whether the source is widened to a multi-seed / multi-window sealed holdout ... is the OQ-2 OWNER choice.
+§D remains inert until OWNER seals (a) the market-observation population and (b) an operational precision/power predicate stated before results: fixed minimum HAC effective n and/or maximum CI width, with explicit authority. Additional bootstrap seeds do not add market observations and cannot satisfy this predicate; only additional non-overlapping sealed windows or a longer sealed OOS can widen the population.
@@ §D D.1
-P1 point ≥ 80 % AND P1 lower-95 ≥ 70 % (rulepack :480), AND
+P1 point ≥ 80 % AND P1 lower-95 ≥ 80 % (intersection of rulepack :480 and builder/timebox 0.80 pending OQ-1), AND
@@ §D after the probability bullets
+The result must also satisfy rulepack freshness (:462), execution fidelity (:468), complete-MTM (:474), and clean shadow/Free-Trial (:498) criteria; otherwise it is not the strictest existing go-criteria set.
@@ §D D.2
-The DSR / E[max SR under null] correction does not reject edge ... over the declared trial count 154 per identity ...
+The DSR engine rejects the multiple-testing null with p < 0.05 (equivalently DSR probability > 0.95) using the sealed per-identity selection_trial_count and the engine's effective-candidate-count rule; the 154 measured arms are not substituted for selection multiplicity.
@@ §E seal procedure
 6. The DSR engine sha ...
-7. The calendar-bundle sha AFTER the E1/E4 repair.
+7. The ftmo_timebox_eval.py module SHA, prepared-config SHA, exact FTMO cost snapshot SHA, and every Q07/Q08/Q16 lineage input carrying selection_trial_count.
+8. The calendar-bundle sha AFTER the E1/E4 repair.
@@ §F
-append ... as the next free row — shown as row 9 ...
+amend the existing pending receipt row 18 in place after re-verifying every now-present anchor; do not append a duplicate row.
@@ OQ-2
-broader sealed holdout (multi-seed / multi-window ...)
+broader sealed holdout (non-overlapping multi-window or enlarged OOS) plus the predeclared numeric ESS/precision rule above; multiple bootstrap seeds alone do not enlarge the evidence population.
```

## Disposition

Keep receipt row 18 `PENDING`. After the blocker corrections, rerun the independent review against the exact amended file and hashes before OWNER ratification or opening any evaluation result.
