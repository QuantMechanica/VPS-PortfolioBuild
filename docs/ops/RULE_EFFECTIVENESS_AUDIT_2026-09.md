# Rule Effectiveness Audit — 2026-09

**Authority:** OWNER directive 2026-09-15 §20–§21 (Continuous Book Evolution),
`docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_verbatim.md`.
**Decision record:** `decisions/2026-09-15_owner_continuous_book_evolution.md` (OWNER-DEC-CBE-20260915).
**Auditor:** Claude (board-advisor slice `b3_docs_rule_audit`), 2026-09-15.
**Evidence base (read-only, dated 2026-09-15):** the Phase-A audit reports under
`docs/ops/evidence/2026-09-15_continuous_book_evolution/audit/` — `rule_inventory_code.md`
(F1–F13 enforcement points), `pipeline_factory_state.md`, `quota_tasks_routing_resources.md`,
`research_disk_guard.md`, `ftmo_demo_state.md`, `vault_doc_drift.md`.

This audit does **not** re-litigate the directive's decisions. Where the directive already
decides a rule (§4, §8, §10, §15, §22, §23, §24, §31, §33, §34, §37), the disposition
records that decision and points to the implementing slice; only genuinely unresolved
high-impact questions are surfaced as OWNER questions (there are none new).

## §20 rule-class legend

- **A — SAFETY / EVIDENCE:** prevents invalid evidence, contamination, hidden live risk,
  non-determinism, accidental live actions, lost provenance. Protect strongly.
- **B — ECONOMIC / SELECTION:** current belief about what makes a strategy good. May evolve.
- **C — PROCESS:** how work is organized. May be optimized.
- **D — HISTORICAL CONSTRAINT:** exists because of old infrastructure / prior limits. Does
  not survive automatically.

## Disposition legend

- **SUPERSEDED-implemented (slice X):** the directive supersedes it and a code/doc/contract
  change lands in the named slice.
- **SUPERSEDED-pending (phase Y):** the directive supersedes it; the concrete change is owned
  by a later phase (E portfolio engine, F FTMO, H weekly automation).
- **KEPT-intentional:** the rule is class-A safety or otherwise still earns its cost; kept
  with the stated reason.
- **OWNER question:** genuinely unresolved and high-impact (none new in this audit).

---

## 1. Fixed 25-candidate book trigger (F1)

- **Original purpose / decision:** DRIVE-TO-25 campaign / OWNER-DEC-A1 (2026-08-25, memory
  `project_qm_drive_to_25_campaign_2026-08-25`); count definition sealed
  `decisions/2026-08-27_owner_count_definition_option_a.md`. Intent: a book must be built from
  a large-enough qualified pool that portfolio selection is meaningful.
- **Enforcement:** hard fail-closed refusal — `tools/strategy_farm/book_build_guard.py:31`
  (`MIN_QUALIFIED_PAIRS = 25`), refusal `:238-242`, `BookBuildRefused` exit 2;
  `tools/strategy_farm/config/gate_manifest.v4.json:370-385` `book_trigger.requires_all[0] =
  qualified_candidates_ge_25`. Diagnostic counter `tools/strategy_farm/path_to_25.py:29`.
- **§20 class:** **B** (economic/selection) wrapped in a **D-shaped hard block** (an arbitrary
  count as a fail-closed gate).
- **Current benefit:** guaranteed that no book was built from a trivially small pool. It also
  forced a healthy diversity reservoir before construction.
- **Current cost:** the gate is now **satisfied and no longer binding** — `book_guard.qualified_pairs=26 ≥ 25`,
  both DXZ and FTMO OWNER order artifacts present (`pipeline_factory_state.md` finding 2). The
  cost was historical: it framed candidate count as the business goal (WAY TO 25) and could, in
  principle, have blocked a strong 9-candidate book (§4). It also concentrated attention on
  count rather than book quality.
- **Safety impact:** none. Removing the fixed minimum does not admit weak strategies — the
  per-(EA,symbol) qualification predicates (Q02–Q14) still fail closed; the OWNER-order
  artifact requirement is retained.
- **Recommendation:** stop treating `<25` as a refusal reason; keep `qualified_pairs` as a
  `GuardResult` diagnostic and keep the OWNER-order requirement. Drop `qualified_candidates_ge_25`
  from `gate_manifest.v4.json book_trigger.requires_all`; keep `owner_order_artifact_present`.
- **Rollback:** restore `MIN_QUALIFIED_PAIRS = 25` and re-add the `requires_all` element; the
  count definition seal is untouched, so the old behaviour is one constant + one manifest entry.
- **DISPOSITION:** **SUPERSEDED-implemented (slice `b1_book_guard_q15`)** per directive §4/§68B.
  The number-of-strategies-is-not-a-goal framing (§3) is a Mission-Control/docs change
  (slice `b2_missioncontrol_docs`). This audit doc records the supersession; the guard code +
  manifest + `test_book_build_guard.py` changes belong to the book-guard slice.

## 2. Q17 mandatory min-lot live burn-in (F2)

- **Original purpose / decision:** `decisions/2026-04-26_v5_sub_gate_reconstruction.md` (P10
  reconstruction) + OWNER 2026-04-26 DXZ-live-only. Intent: bound money-at-risk on a sleeve's
  first live exposure while a KS kill-switch watches for backtest/live divergence.
- **Enforcement:** **none in code** — Q17 "Live Burn-In DXZ" is `authority: OWNER`,
  `runner: MANUAL` (`gate_manifest.v4.json:277-288`). The rule lives only in
  `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` P10 (min-lot, 14-day, KS) and
  `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md:162` ("14-day min, min-lot, KS kill-switch").
- **§20 class:** **A** (first-live risk control) in its *intent*, but the **mandatory min-lot**
  form is **D** (historical) — mandatory min-lot does not automatically produce meaningful
  evidence, and a min-lot stream can be too sparse to validate anything.
- **Current benefit:** caps first-live loss to the smallest tradeable size.
- **Current cost:** min-lot streams often close the 14-day window with `N_fwd < 30` →
  `INSUFFICIENT_DATA` (spec P10), i.e. the burn-in produces no decision-grade evidence yet
  consumes the calendar window; and a universal min-lot default blocks introducing a
  well-validated sleeve at its intended probation weight.
- **Safety impact:** relaxing the *lot floor* does not remove the safety control — live
  activation stays OWNER-only (§64) and the KS kill-switch is retained. Initial risk becomes
  a function of evidence rather than a fixed floor.
- **Recommendation:** refactor Q17 into an **evidence-based live introduction / probation /
  deployment stage** (§10). Appropriate initial live risk depends on: validated historical
  evidence, novelty, tail risk, execution uncertainty, broker-equivalence confidence, current
  portfolio risk, available live evidence, liquidity, expected trade frequency. Valid choices:
  intended full portfolio weight / reduced probation weight / staged risk increase /
  incumbent-challenger parallel observation / no introduction. Any reduced-risk probation must
  carry an explicit evidence/risk reason — min-lot is one option, never the default checkbox.
- **Rollback:** the SUPERSEDED block is retained verbatim in the spec/runbook; reverting is
  restoring the old block as current guidance.
- **DISPOSITION:** **SUPERSEDED-implemented (slice `b3_docs_rule_audit`)** for the doc surfaces
  (P10 section of `PIPELINE_V5_SUB_GATE_SPEC.md`, runbook line 162); the evidence-based
  initial-risk ladder is defined in `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md` §Q17 and the vault
  Q17 page (slice `b2`). No code line to flip (Q17 is manual).

## 3. Q17 fixed 14-day waiting period (F3)

- **Original purpose / decision:** inherited P10 window,
  `decisions/2026-04-26_v5_sub_gate_reconstruction.md:40`. Intent: a minimum observation window
  before size-up.
- **Enforcement:** **none in code** — same manual Q17 gate as F2; doc only
  (`PIPELINE_V5_SUB_GATE_SPEC.md` P10 "14 calendar days", `:284` INSUFFICIENT_DATA → 14-day
  extension; `BOOK_CEREMONY_RUNBOOK_2026-09.md:162`).
- **Distinct rules that are NOT this one and must be KEPT (class A):** the news-calendar
  staleness gate (14-day → `INIT_FAILED`) in `framework/include/QM/QM_News.mqh::QM_NewsInit`
  and the manifest news-age check (`age < 336 h`) are safety/evidence, unrelated to the Q17 wait.
- **§20 class:** **C/D** — a fixed calendar block that can stall weekly portfolio evolution
  purely because it historically existed.
- **Current benefit:** a minimum look before acting; useful as a default, not as an absolute.
- **Current cost:** a fixed 14-day wait can prevent a weekly recomposition from acting on
  material new evidence merely because a sleeve has not sat 14 days — directly against §6/§10.
- **Safety impact:** none if the burn-in becomes evidence-dependent probation; OWNER live
  authority unchanged.
- **Recommendation:** make the 14-day burn-in an **evidence-dependent probation window**, not a
  universal calendar block; a sleeve with strong validated evidence may enter at probation
  weight without a fixed wait, and a novel sleeve may warrant a longer look.
- **Rollback:** restore the SUPERSEDED block as current guidance.
- **DISPOSITION:** **SUPERSEDED-implemented (slice `b3_docs_rule_audit`)** (docs); ladder in
  `CONTINUOUS_BOOK_EVOLUTION.md` §Q17. Per directive §10.

## 4. Family caps — max 3 per family (F4)

- **Original purpose / decision:** discrete caps OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904
  (`decisions/2026-09-04_owner_receipts_briefing_2_4.md`). Intent: prevent a book from being
  dominated by one strategy family.
- **Enforcement (documented, NOT active — drift D1):** `ftmo_probability_contract.v1.json:39`
  `q15_discrete_count_caps.family_max = 3` (`status: OWNER_RATIFIED`, `source: build_book_ftmo.py:60,66`).
  Those source lines are **stale** — `:60` is `FUND_SCORE_FLOOR = 1.0` and `:66-69` is a comment
  stating the FTMO book uses aggregate correlation/cluster control, **not** a per-family count
  cap. No `family_max` check exists in any builder (`build_book_ftmo.py`, `build_book_dxz.py`,
  `book_reoptimizer.py`; grep-confirmed in `rule_inventory_code.md` F4).
- **Active family control (different dimension, KEEP):** the SP-C3 percent-of-budget family cap
  (`family = 57.5%` of the 11.0% stop-risk budget) in
  `tools/strategy_farm/portfolio/concentration_tail.py:162-204` +
  `concentration_tail_limits.v1.json:9` — an economic concentration input, not the discrete "≤3".
- **§20 class:** **B** (economic/selection).
- **Current benefit:** as a discrete cap, none today (not enforced). As documentation it
  signals "avoid family concentration" — which the SP-C3 percent cap already enforces on an
  economic basis.
- **Current cost:** the discrete cap, if re-activated, would treat "three genuinely different
  XAUUSD mechanisms" as automatically redundant merely by family label (§8), and the stale
  `source` pointer is a live drift that misleads readers.
- **Safety impact:** none — concentration risk is carried by the SP-C3 percent-of-budget cap +
  measured dependence.
- **Recommendation:** flip `q15_discrete_count_caps.status` from `OWNER_RATIFIED` to
  `ADVISORY`/`DIAGNOSTIC`, correct the stale `source` pointer, and keep the SP-C3 percent cap
  as a portfolio-risk input. Add trade-overlap / return-dependence / tail-dependence /
  timing-dependence / mechanism-similarity outputs so real economic dependence is measured (§8).
- **Rollback:** set `status` back to `OWNER_RATIFIED`.
- **DISPOSITION:** **SUPERSEDED-implemented (slice `b1_book_guard_q15` / contract)** per §8;
  dependence-measure outputs are **SUPERSEDED-pending (Phase E portfolio engine)**.

## 5. Symbol caps — max 2 per symbol (F5)

- **Original purpose / decision:** same as F4 (OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904). Intent:
  prevent a book from stacking too many sleeves on one symbol.
- **Enforcement (documented, NOT active — drift D1):** `ftmo_probability_contract.v1.json:39`
  `symbol_max = 2`. `build_book_ftmo.py:66-69` comment **explicitly rejects** a per-symbol cap
  ("the FTMO book MAY run multiple EAs/strategies on the same symbol … NOT via a per-symbol cap").
- **Active symbol control (KEEP):** SP-C3 `symbol = 46%` of budget
  (`concentration_tail_limits.v1.json:8`), enforced via `concentration_tail.py:135-158`.
- **§20 class:** **B** (economic/selection).
- **Current benefit / cost / safety:** as F4 — discrete cap not enforced; economic
  concentration carried by SP-C3; discrete cap would misclassify genuinely different mechanisms
  on the same symbol as redundant.
- **Recommendation:** reclassify the discrete `symbol_max` to `ADVISORY`; retain the SP-C3
  percent-of-budget symbol cap as a risk input; measure real economic dependence (§8).
- **Rollback:** set `status` back to `OWNER_RATIFIED`.
- **DISPOSITION:** **SUPERSEDED-implemented (slice `b1` / contract)** per §8; dependence
  measures **SUPERSEDED-pending (Phase E)**.

## 6. Fixed pairwise correlation caps (F6)

- **Original purpose / decision:** book-admission `0.50` — OWNER 2026-07-15 (comment
  `build_book_ftmo.py:77`); Q09 marginal `0.40` — `decisions/2026-07-20_DL-083_marginal_eval_threshold_calibration.md`.
  Intent: exclude sleeves that duplicate an incumbent's return stream.
- **Enforcement (multiple, active):** book admission `0.50` (ROT_SEALED)
  `tools/strategy_farm/portfolio/portfolio_correlation.py:77`, `build_book_ftmo.py:75,84,196`
  (`value >= cap → CLUSTER_CORRELATION_EXCLUDED`; unknown corr → `CLUSTER_CORRELATION_UNVERIFIED`
  fail-closed `:307-312`); reoptimizer `--max-corr 0.50` `book_reoptimizer.py:6,91`; Q09
  marginal `0.40` `ftmo_timebox_eval.py:112-114`; contract map
  `ftmo_probability_contract.v1.json:28-31`.
- **§20 class:** **A/B** — correlation control is genuine portfolio risk (A), but the *fixed
  number* is an economic belief (B).
- **Current benefit:** a simple, deterministic guard against obviously duplicated streams; the
  `CLUSTER_CORRELATION_UNVERIFIED` fail-closed path is real safety.
- **Current cost:** a single static Pearson cutoff both over-rejects (two mechanisms that are
  economically distinct but incidentally correlated in-sample) and under-detects (low linear
  correlation but shared tail/timing dependence) — §8 asks for measured economic dependence,
  not one arbitrary number.
- **Safety impact:** the *mechanism* must stay; the `UNVERIFIED` fail-closed must stay. Relaxing
  the fixed number to an admit-with-WARN feeding a richer dependence panel does not weaken
  safety provided the fail-closed path on *unknown* correlation is preserved.
- **Recommendation:** convert the hard `>= cap` exclusion (`build_book_ftmo.py:196`,
  `portfolio_correlation.py:77`) into an **admit-with-WARN** that feeds a portfolio dependence
  panel (add trade-overlap, tail-dependence, timing-dependence); keep
  `CLUSTER_CORRELATION_UNVERIFIED` fail-closed. The `0.50` is `ROT_SEALED`, so the change must
  carry a dated decision record and must **not** be replaced by a new arbitrary cap (§8).
- **Rollback:** restore the hard `>= cap` exclusion and the sealed `0.50`.
- **DISPOSITION:** **SUPERSEDED-pending (Phase B + Phase E)** per §8. The directive decides the
  relaxation; because the `0.50` is ROT_SEALED, the implementing change carries the dated
  decision `decisions/2026-09-15_owner_continuous_book_evolution.md` and richer dependence
  measures. No new OWNER question (the directive §8 already authorizes converting static caps to
  risk inputs).

## 7. HR16 — one research / one EA development at a time (F7)

- **Original purpose / decision:** vault Hard Rule HR16 (`01 Identity/Hard Rules`), an
  old-infra serialization + token-spend constraint.
- **Enforcement:** **no dedicated code gate** — HR16 is vault doctrine. Nearest knobs: the
  research reservoir throttle (`agent_router.py` `min_ready_strategy_cards` default 5) and
  per-lane `max_parallel: 1`.
- **§20 class:** **D** (historical constraint).
- **Current benefit:** kept token spend and evidence isolation simple when infrastructure and
  quota were tight and evidence isolation was not yet robust.
- **Current cost:** it serializes independent useful work (research + mechanization + coding +
  reviews) that could safely run in parallel, throttling throughput on a machine and quota
  budget that can now support controlled parallelism (§24).
- **Safety impact:** none provided the §24 conditions hold — evidence isolated, task identity
  clear, repo changes non-conflicting, compute allows, MT5 capacity protected, AI quotas allow,
  critical-path work protected. The determinism-first spirit (§26) is preserved.
- **Recommendation:** mark HR16 superseded in the vault; allow controlled parallelism under the
  §24 conditions; keep `min_ready_strategy_cards` as an anti-idea-spam pacer; raise
  `max_parallel` only on lanes where compute/quota permit.
- **Rollback:** re-assert HR16 as binding in the vault; set `max_parallel: 1` on all lanes.
- **DISPOSITION:** **SUPERSEDED-implemented (docs: vault annex slice `b2`; ops annex here in
  `OPERATING_RULES_2026-07-03.md`)** per §24. Router `max_parallel` tuning is
  **SUPERSEDED-pending (ops, as compute/quota permit)**.

## 8. Research source restrictions R1–R4 (F8)

- **Original purpose / decision:** OWNER 2026-06-30 (`processes/qb_reputable_source_criteria.md`:
  R1 single-source/type-open, R2 mechanizable, R3 ≥1 DWX instrument, R4 no runtime-ML/martingale);
  internal-source contract `docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md` (QM-RESEARCH:// R1).
  Intent: only mechanizable, provenance-anchored ideas enter the pipeline, and no ML/basket
  runaway reaches EA runtime.
- **Enforcement:** `card_intake_prescreen.py` (mechanism-overlap dedup, rules/falsification
  headings, runtime-ML span handling, internal-source reason `:539-548`);
  `tools/strategy_farm/research_source.py` (QM-RESEARCH:// mint/verify,
  `source_hash = sha256(source.md)` fail-closed).
- **§20 class:** **A** (evidence/provenance + runtime-ML reject). Already permissive on author.
- **Current benefit:** fail-closed provenance/hash lineage; keeps unmechanizable or ML-runtime
  ideas out. This is exactly the safety §71 protects.
- **Current cost:** near-zero if authorship is generalized. The only friction is if the internal
  R1 tooling is unnecessarily Kimi-specific (§37) — Fable and multi-agent authorship must be
  first-class.
- **Safety impact:** must be preserved — R1 hash provenance and R4 runtime-ML reject are
  directive-protected (§36, §42, §71). Do not loosen R2/R3/R4.
- **Recommendation:** generalize `source_author` handling in `research_source.py` and
  `card_intake_prescreen.py:539-548` to accept `Fable` / another authorized agent / documented
  multi-agent collaboration, not only Kimi; preserve hash/provenance fail-closed and the R4
  runtime-ML reject. No restriction to loosen otherwise — R1–R4 are already source-agnostic.
- **Rollback:** restrict `source_author` to the prior Kimi-only set.
- **DISPOSITION:** **KEPT-intentional** for R1 provenance / R2 mechanizable / R3 DWX / R4
  runtime-ML reject (class A, directive-aligned §36/§41/§42). Author generalization is
  **SUPERSEDED-implemented (Phase C, slice `research_source`)** per §37 — not this slice.

## 9. FTMO purchase thresholds — FUND_SCORE floor, P(pass≤30d), 60-day (F9)

- **Original purpose / decision:** rulepack `FTMO_2S_100K_SWING_V2.json` / `..._STANDARD_V2.json`;
  contract `ftmo_probability_contract.v1.json` (`PENDING_OWNER_RATIFICATION`); DSR gate
  `framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py`. Intent: only economically fundable books
  reach an OWNER purchase recommendation, and speed-to-target was tracked to bound challenge time.
- **Enforcement (book-build gates, NOT a purchase button):** `build_book_ftmo.py:60`
  `FUND_SCORE_FLOOR = 1.0`; `P1_LOWER_BOUND_FLOOR` / `lower_95_min = 0.80`; horizon 60d/30d
  `ftmo_probability_contract.v1.json:15-16`; DSR `dsr_p_min 0.05 / dsr_prob_min 0.95`.
  **No purchase automation exists** — grep for purchase/BUY returned nothing; purchase is
  OWNER-only (§64), satisfying §70 "paid purchase cannot occur through automation".
- **§20 class:** **B** (economic/selection).
- **Current benefit:** FUND_SCORE / P1-lower / DSR are legitimate economic evidence that a book
  can fund a challenge; the directive explicitly keeps them as evidence (§15).
- **Current cost:** treating the *speed* metrics (≤30d, hard-60-day first-passage) as pass/fail
  conflicts with the OWNER's stated priority — **probability of success first, speed second**
  (§15, §57). FTMO removed the max period (`ftmo_demo_state.md` finding 4), so a hard-60-day
  first-passage target is no longer a real venue constraint.
- **Safety impact:** none. The purchase gate is OWNER-only and no automation can buy; keeping
  the evidence gates protects against recommending an unfundable book.
- **Recommendation:** keep FUND_SCORE / P1-lower / DSR as evidence gates for FTMO-book
  admission. Reframe the speed metrics (≤30d, 60-day first-passage) in
  `ftmo_probability_contract.v1.json` and `docs/ops/FTMO_CHALLENGE_READINESS.md` as
  **secondary diagnostics**, not pass/fail. The final paid decision answers: "is buying this one
  100k 2-Step Challenge now a sufficiently high-confidence positive-EV decision?" (§15).
- **Rollback:** restore the speed metrics to pass/fail status in the contract/readiness doc.
- **DISPOSITION:** **SUPERSEDED-pending (Phase F FTMO)** per §15 for the speed-metric reframe;
  **KEPT-intentional** for FUND_SCORE / P1-lower / DSR as evidence and for the purchase being
  OWNER-only (§64/§70).

## 10. FTMO density rules (F10)

- **Original purpose / decision:** activity criterion OWNER 2026-08-20, OQ-18 closed
  (`docs/ops/ACTIVITY_CRITERION.md`, ≥10 distinct entry-days/scored year); FTMO density from the
  FTMO rulepack. Intent: a fundable challenge book must trade enough to hit the target inside a
  reasonable window and to satisfy the ≥4-trading-day requirement.
- **Enforcement:** `build_book_ftmo.py:400-438` `_density` (`minimum_sleeves`,
  `density_evidence_complete`, `each_sleeve_active_days_per_60d >= min_active_days_per_60d`,
  `minimum_trading_days_phase1 = 4`); return-density ranking `ftmo_candidate_efficiency.py`;
  activity criterion `portfolio/audit_activity_criterion.py:78`.
- **§20 class:** **B** (economic/selection).
- **Current benefit:** density is a genuine positive selector for FTMO — opportunity density and
  time-to-target matter, and the ≥4-day rule is an FTMO venue requirement.
- **Current cost:** the risk is a **floor that excludes valuable high-frequency systems** — the
  directive now explicitly *values* scalping / higher-frequency / trailing systems for FTMO
  (§16, §18, §19, §48). A per-sleeve hard density reject could fail-closed a legitimately
  low-frequency sleeve inside an otherwise dense book, and there must be **no new upper cap** that
  penalizes scalping.
- **Safety impact:** none; density is an economic input, not a safety control.
- **Recommendation:** keep density as an economic **input** to FTMO fitness (§57); make the
  `each_sleeve_active_days_per_60d` check a portfolio-level warning rather than a per-sleeve hard
  reject; add no upper-frequency cap (§18).
- **Rollback:** restore the per-sleeve hard density reject.
- **DISPOSITION:** **SUPERSEDED-pending (Phase F FTMO / Phase E)** per §16/§18/§48 — density
  becomes an FTMO-fitness input; **KEPT-intentional** for the FTMO ≥4-trading-day venue rule
  (a real challenge constraint) and the activity criterion as a qualification predicate.

## 11. Redundant pipeline gates / serial dependencies (F11)

- **Original purpose / decision:** rebaseline v4 `decisions/2026-08-23_owner_gate_manifest_v4_linear.md`.
  Intent: a strictly monotone Q00→Q17 chain with a linearity invariant so evidence dependency is
  unambiguous.
- **Enforcement (contract):** `gate_manifest.v4.json:290-309` `ordinary_chain` with
  `linearity_invariant` (`:310`); per-gate `next` fields force the serial walk; backfill planner
  `:386-395` (FRONTIER_FIRST global, EARLIEST_MISSING_PREREQUISITE per pair).
- **Already-parallel / decoupled (no change):** Q02–Q08 run in parallel across T1–T10 (the
  throughput metric); Q10_PORTFOLIO is informational, never a pre-Q11 abort (OWNER E1 2026-08-22).
- **§20 class:** **C** (process).
- **Current benefit:** unambiguous evidence lineage; the pipeline protects QuantMechanica from
  fooling itself (§22).
- **Current cost:** three full-history re-runs — Q05 (Gross Full-History Robustness), Q09
  (Baseline Full Run), Q11 (Incumbent Full-History Confirmation) — each re-execute full history
  though `reuse_rule` already permits hash-bound reuse. Separately, the live throughput cost is
  **not** in the manifest but in the frontier: 51 pairs wait at Q11 for Q12, only 2 have cleared
  Q12, Q13 produces only NO_PARAMETER_CHANGE (`pipeline_factory_state.md` findings 2, 5).
- **Safety impact:** none if criteria are unchanged — this is an efficiency audit; **do not
  lower any pass criterion to create PASSes** (§22, RED boundary).
- **Recommendation:** (a) collapse Q05/Q09/Q11 full-history runs to a single hash-bound artifact
  reused across the three roles when build+setfile+window+contract hashes are equal (the
  `reuse_rule` already sanctions it — enforce in the backfill planner); (b) fan out Q07 multi-seed
  replicates in parallel; (c) confirm no gate re-derives another's evidence. Keep the
  evidence-dependency ordering intact.
- **Rollback:** disable hash-bound reuse enforcement; the manifest chain is unchanged.
- **DISPOSITION:** **SUPERSEDED-pending (Phase B/E efficiency work)** per §22/§23 — no criterion
  changes; the reuse/parallelization is an efficiency change owned by the pipeline slice.
  The global-**drain-barrier** doctrine (a separate rule) is **SUPERSEDED-implemented** (docs
  annexes here + §23) — the pipeline is continuous, not a global drain barrier.

## 12. AI quota restrictions (F12)

- **Original purpose / decision:** quota governor OWNER 2026-06-21; codex budget line OWNER
  2026-09-13 (`feedback_codex_weekly_pacing_2026-09-13`); kimi governor OWNER 2026-09-15
  (OWNER-DEC-KIMI-INTEGRATION-20260915). Intent: pace weekly AI spend and provide runaway/cost
  protection; **backtests are never throttled**.
- **Enforcement:** `agent_quota_gate.v1.json` (hard_exhaustion weekly 98% / 5h 95%; per-class
  research/build/ops thresholds; `never_gate` backtest/deterministic; `owner_priority_min 70`);
  `quota_governor.py` (`FLOOR_USED_PCT 15`, `HARD_CEIL_PCT 90`, `CODEX_LOW_TOKENS.flag` /
  `CLAUDE_DISABLED.flag`); `codex_budget_line.py` (`DEFAULT_TARGET_AT_RESET_PCT 92`);
  `agy_governor.py` (`AGY_LOW_QUOTA.flag`); `kimi_governor.py` (caps `{day:40, week:200}`,
  `conserve_pct 70`, `KIMI_LOW_QUOTA.flag`).
- **§20 class:** **A/C** — runaway/cost protection (A) + pacing (C). Backtests never throttled.
- **Current benefit:** keeps Codex/Claude weekly spend on-pace toward resets and prevents a
  runaway Kimi loop from burning the subscription. Live state (`quota_tasks_routing_resources.md`
  finding 3): Claude weekly 83% (`CLAUDE_DISABLED.flag`), Codex weekly 80% (budget-line
  exceeded), agy token expired (401), Kimi NORMAL (2/40 day, 2/200 week, `local_ledger_only`).
- **Current cost:** the Kimi 40/day-200/week caps run today as **hard caps, not the §33
  fallback**, because there is no real telemetry (`usage_source: local_ledger_only`) — the UI
  shows ~0.01% monthly usage yet the local ledger would trip long before real capacity is used,
  wasting most of an already-paid subscription (§30/§33).
- **Safety impact:** the runaway/anomaly protection must be kept (§33 "do not remove runaway
  protection"); the Codex/Claude weekly governors are legitimate cost safety and stay
  unchanged; the backtest `never_gate` exemption must not be touched.
- **Recommendation:** wire a real Kimi-usage snapshot (§31/§32) into `kimi_governor.py` and
  prefer it when `usage_source` is authoritative, keeping 40/200 only as the anomaly/runaway
  floor. Leave `quota_governor.py` / `codex_budget_line.py` / `agy_governor.py` thresholds and
  the `never_gate` backtest exemption unchanged.
- **Rollback:** ignore the telemetry snapshot and revert to the local ledger as the binding cap
  (config-only via `kimi_governor_state.json`).
- **DISPOSITION:** **KEPT-intentional** for the Codex/Claude/agy governors and the backtest
  `never_gate` exemption (class A safety); **SUPERSEDED-pending (Phase C Kimi)** for reclassing
  the Kimi 40/200/70 numbers to fallback guardrails once real telemetry lands (§33).

## 13. Resource thresholds (F13)

Four distinct thresholds; only one is superseded.

### 13a. 80 GB research disk guard (class D — arbitrary) — SUPERSEDED

- **Original purpose / decision:** Kimi edge-discovery design (`docs/ops/KIMI_EDGE_DISCOVERY_DESIGN.md`
  §2.3 D6 gate). Intent: research yields to a disk-pressured factory.
- **Enforcement:** `tools/strategy_farm/research/research_env.py:48-51`
  `RESEARCH_DISK_MIN_FREE_GB = 80.0`, watching drive `D:/`.
- **Current cost:** the tester-cache purge holds D: at its **60 GB** low-water, so **80 > 60
  means research on D: is structurally, permanently refused** — the live guard returns
  `allowed:false … DISK_LOW:61.2GB<80.0GB` (`research_disk_guard.md` finding 4). The floor is
  not evidence-based: research's real D: footprint is ~0.3 GB (the venv) and its dataset output
  already writes to C: (`observe_projector.py DEFAULT_OUT_ROOT = C:\QM\repo\artifacts\research_datasets`).
  The required layering is `worker_disk_floor (40) ≤ purge_low_water (60) ≤ research_floor`; the
  80 GB value sits above the disk's operating band, so it is never satisfied.
- **Safety impact:** none — research consumes ≈0 on D:; the guard watches the wrong drive at the
  wrong threshold. Never delete canonical evidence/verdicts/immutable reports/trade streams to
  free space (§34, RED boundary).
- **Recommendation:** make the guard evidence-based — watch the drive research actually uses
  (C:, where the datasets land) and set a floor from measured need
  (`RESEARCH_DISK_MIN_FREE_GB = 20.0` = max(measured 0.3 GB × 2, 20 GB margin)); add env
  overrides (`QM_RESEARCH_DRIVE`, `QM_RESEARCH_DISK_MIN_FREE_GB`); optionally relocate the venv
  off D:. Fallback: keep D: but set the floor to the purge low-water (60) so the two can never
  contradict.
- **Rollback:** restore `RESEARCH_DISK_MIN_FREE_GB = 80.0` and `DEFAULT_RESEARCH_DRIVE = D:/`.
- **DISPOSITION:** **SUPERSEDED-pending (Phase C Kimi, slice `research_env`)** per §34. This
  audit doc records the correct enforcement path — `tools/strategy_farm/research/research_env.py`
  — so any doc citing the guard uses the full path, not a bare `research_env.py`.

### 13b. RAM classes 44 / 24 / 12 GB (class A — measured OOM protection) — KEPT

- **Original purpose / decision:** measured working-set reservations; index-by-base RAM table
  2026-09-14 (`docs/ops/evidence/2026-09-14_index_ram_table/`); worker thresholds OWNER
  2026-08-15. Intent: prevent OOM when a heavy multi-symbol / index-tick backtest claims a slot.
- **Enforcement:** `tools/strategy_farm/terminal_worker.py` — `RAM_MIN_FREE_GB 14.0`,
  `COMMIT_MIN_FREE_GB 24.0`, multi-symbol 12.0, `MULTISYMBOL_COMMIT_RESERVATION_GB 44.0`,
  two-leg-metal 24.0, `SINGLE_INDEX_TICK_COMMIT_RESERVATION_GB 44.0`, index-by-base table
  (`SP500 44.0`, others provisional). Rollback env `QM_INDEX_TICK_RESERVATION_TABLE=0`.
- **§20 class:** **A** (OOM/crash protection).
- **Current benefit:** prevents the factory from crashing a terminal by over-committing RAM.
- **Current cost (LIVE, must be recorded per this slice):** the **flat 44 GB
  `heavy_or_unknown_multisymbol` reservation** is **un-winnable on the ~67.8 GB box** when other
  work holds memory, and the `drain_predrain` head-of-line claim preflight keeps a 44 GB row at
  the claim head. Result on 2026-09-15: **6 of 10 terminals idle ~2.95 hours** in
  `drain_predrain_open` for a single un-winnable QM5_10025 reservation, census throughput fallen
  to **0/hour** against **732 claimable rows** (`pipeline_factory_state.md` findings 3, 5, 9;
  worker logs `ram_class_skipped=251`, `drain_predrain_open waited_seconds≈10,600`). This is the
  single costliest process rule live today (§72) — but the cost is the **flat/head-of-line
  interaction**, not the RAM-safety reservation itself.
- **Safety impact:** removing RAM reservations would risk OOM — the reservation values must be
  KEPT. The fix is to (a) reclassify `heavy_or_unknown_multisymbol` from a flat 44 GB reservation
  to a measured per-EA footprint so it is winnable, and/or (b) park the un-winnable rows so they
  do not poison the claim head (GRÜN infra repair — re-queue/park, no verdict touch).
- **Recommendation:** keep the measured RAM reservations; reclassify the flat
  `heavy_or_unknown_multisymbol` class to a measured footprint and fix the head-of-line claim
  preflight so an un-winnable row cannot idle the fleet. (Factory remediation, not a docs change
  — flagged here as the highest-cost live rule per §21/§72.)
- **Rollback:** `QM_INDEX_TICK_RESERVATION_TABLE=0` restores the prior flat behaviour.
- **DISPOSITION:** **KEPT-intentional** (RAM safety, class A); the flat-reservation /
  head-of-line remediation is **SUPERSEDED-pending (Phase A/D factory remediation)** — an
  efficiency/infra fix, not a safety relaxation. Recorded here because §21 requires the
  RAM-class rule's live cost (6/10 terminals idle ~3 h) be captured.

### 13c. tester_cache_purge low-water 60 GB (class A — disk safety) — KEPT

- **Original purpose / decision:** OWNER 2026-06-21 factory recovery. Intent: keep D: from
  filling with regenerable tester cache during 10-terminal saturation (~50–100 GB/hr burn).
- **Enforcement:** live scheduled-task action runs `-LowWaterGB 60`
  (`tools/strategy_farm/tester_cache_purge.ps1`, 10-min cadence). Clears only regenerable
  `T*\Tester\bases` + `T*\Tester\Agent-*`; never touches `Bases\Custom`, `D:\QM\reports`,
  verdicts, or `T_Live`; evidence-guarded, fail-closed.
- **§20 class:** **A** (disk safety, evidence-guarded).
- **Current cost:** none — protective. **Drift to fix (D2):** the script default is stale (150)
  and CLAUDE.md / `COMPANY_AUDIT_LIVE_SOURCES_2026-05-30.md` still describe "no-op ≥150 GB /
  LowWater 80→150"; the live value is **60**.
- **Recommendation:** KEEP the 60 GB low-water; reconcile the stale docs/script default to 60.
- **Rollback:** n/a (kept).
- **DISPOSITION:** **KEPT-intentional**; doc reconciliation to LowWater 60 is a Phase B/§65
  drift fix (CLAUDE.md + COMPANY_AUDIT annex — see slice `b2` and the COMPANY_AUDIT annex).

### 13d. Worker CPU pause 97% / resume 90% (class A — crash protection) — KEPT

- **Original purpose / decision:** OWNER 2026-08-15. Intent: pause a worker's claim/launch when
  the host CPU is saturated, to avoid thrashing.
- **Enforcement:** `terminal_worker.py:210-211` `CPU_MAX_LOAD_PERCENT 97.0`,
  `CPU_RESUME_LOAD_PERCENT 90.0`; guard sleep 20 s.
- **§20 class:** **A** (crash/thrash protection).
- **Current cost:** none; note that observed high CPU is often idle-claim-scan spin (1 core per
  worker), not throughput — the pause is not the throughput bottleneck (the RAM head-of-line is).
- **Recommendation / Rollback / DISPOSITION:** **KEPT-intentional** — unchanged.

---

## Summary disposition table

| # | Rule | §20 class | Disposition |
|---|------|-----------|-------------|
| 1 | Fixed 25-candidate trigger | B (+D block) | SUPERSEDED-implemented (slice b1 guard/manifest; b2 docs) — §4 |
| 2 | Q17 mandatory min-lot | A intent / D form | SUPERSEDED-implemented (slice b3 docs; ladder in CBE doc) — §10 |
| 3 | Q17 fixed 14-day wait | C/D | SUPERSEDED-implemented (slice b3 docs) — §10 |
| 4 | Family cap ≤3 | B | SUPERSEDED-implemented (contract → ADVISORY); dependence measures pending Phase E — §8 |
| 5 | Symbol cap ≤2 | B | SUPERSEDED-implemented (contract → ADVISORY); dependence measures pending Phase E — §8 |
| 6 | Fixed pairwise correlation cap | A/B | SUPERSEDED-pending (Phase B+E, dated decision; ROT_SEALED 0.50) — §8 |
| 7 | HR16 one-at-a-time | D | SUPERSEDED-implemented (vault + ops annexes); router tuning pending ops — §24 |
| 8 | Research source R1–R4 | A | KEPT (R1/R2/R3/R4); author generalization pending Phase C — §36/§37/§42 |
| 9 | FTMO purchase thresholds | B | KEPT (FUND_SCORE/P1/DSR + OWNER-only purchase); speed-metric reframe pending Phase F — §15 |
| 10 | FTMO density rules | B | KEPT (≥4-day venue rule + activity criterion); density→fitness input pending Phase F/E — §16/§18 |
| 11 | Redundant gates / serial deps | C | SUPERSEDED-pending (Phase B/E efficiency, no criterion change) — §22/§23 |
| 12 | AI quota restrictions | A/C | KEPT (Codex/Claude/agy + backtest never-gate); Kimi caps → fallback pending Phase C — §33 |
| 13a | 80 GB research disk guard | D | SUPERSEDED-pending (Phase C, slice research_env) — §34 |
| 13b | RAM classes 44/24/12 GB | A | KEPT (safety); flat/head-of-line remediation pending Phase A/D — cost: 6/10 terminals idle ~3 h |
| 13c | tester purge low-water 60 GB | A | KEPT; doc reconciliation to 60 (Phase B drift) |
| 13d | Worker CPU pause 97/90 | A | KEPT — unchanged |

## Open questions strictly requiring OWNER

**None new.** Directive §4/§8/§10/§15/§22/§23/§24/§33/§34/§37 decide every conversion above,
and §21/§68 order implementing the already-decided items without re-approval. Two pre-existing
tensions are noted for the implementing phases (not blockers): the OQ9 sleeve≠EA budget tension
(`ftmo_probability_contract.v1.json:39` — dissolved by §8, routed to Phase E) and the
ROT_SEALED `0.50` correlation cap (§8 authorizes relaxation; the implementing change carries the
dated CBE decision, not a new OWNER question).
