# Statistical Two-Pass Gate Contract — Design Proposal

Router task: `STAT-CONTRACT-TWO-PASS-FUNNEL` (`0257da30-b228-4f0c-ab9c-28aac88717f4`),
`QM-TODO-20260822-402`. Authority for the underlying pipeline order: OWNER-DEC-STAT-CONTRACT
+ OWNER chat 2026-08-23 (`decisions/2026-08-22_owner_pipeline_realignment_q09_q11.md`,
`decisions/2026-08-23_owner_gate_manifest_v4_linear.md`). This document is **analysis and
design only** — no gate threshold, window, verdict, or activation state changes. Numeric
ROT items are called out explicitly and require separate OWNER ratification.

## 0. Baseline correction — this proposal targets v4, not v3

The task payload was authored against gate manifest **v3** (`Q10A`, `Q09`=News, `Q10`=
Incumbent, `Q14`/`Q15`=Pattern/Param, `Q16`=Head-to-Head). Gate manifest **v4** went ACTIVE
2026-08-23T17:55Z (`2f0777085`, `tools/strategy_farm/config/gate_manifest.v4.json`,
`decisions/2026-08-23_owner_gate_manifest_v4_linear.md`) — a **pure renumbering + linearization**
("no gate threshold, window, criterion, seed or verdict changes... only identifiers, order
and phase grouping"). v4 topology already structurally satisfies several of the 11 acceptance
criteria below. This document therefore does **not** propose another renumbering — it proposes
**contract-level** deltas (thresholds, search-space definitions, sealed-evidence wiring)
layered onto the existing v4 gate IDs. All references below use **v4 IDs**; the v3→v4 map is
in `gate_manifest.v4.json:contract_equivalence`.

v4 topology (for reference):

| Macro phase | Gates |
|---|---|
| 1 Strategiebeweis | Q00 Research Intake · Q01 Build & Spec · Q02 Baseline Screening · Q03 Parameter Sweep · Q04 Walk-Forward+Commission · Q05 Gross Full-History · Q06 Stress HARSH · Q07 Multi-Seed · Q08 Davey Statistical Validation |
| 2 Optimierung | Q09 Baseline Full Run · Q10 News+FTMO Recommendation · Q11 Incumbent Full-History Confirmation · Q12 Pattern Filter Selection (DL-089) · Q13 Parameter Optimization & Freeze · Q14 Best-Settings Head-to-Head + Holdout (**terminal**, `next=null`) |
| 3 Buchbewertung | Q15 Final Portfolio Construction (book-trigger only) · Q16 Operational Readiness · Q17 Live Burn-In DXZ |

## 1. Criterion-by-criterion status

Legend: **SATISFIED** = v4 topology/code already meets this; **PARTIAL** = structurally
present but a concrete gap remains; **GAP** = not addressed, needs a new contract.

### C1 — Q02 pre-registered, regime-aware window contract; CONTRADICTED/INSUFFICIENT/INVALID split
**GAP.** Not verified against a Q02 runner script in this pass (no `q02_*.py` found under
`framework/scripts/`; Q02 = "Baseline Screening", `evidence_role: CHEAP_PROMOTION_SCREEN`,
`reuse_rule: REUSE_ID_UNCHANGED_HASH_BOUND`). No evidence of a three-way outcome split
(CONTRADICTED vs INSUFFICIENT vs INVALID) distinct from the current PASS/FAIL/INFRA taxonomy
used farm-wide (`work_item_clean_view.py`: strategy/open/infra/invalid/governance/review/
draft_defect/measurement). **Design owed**, see §3.1.

### C2 — Q03 stability-test vs declared DEV-calibration, both configs hash-bound
**PARTIAL.** Q03 = "Parameter Sweep", hash-bound reuse rule already enforced
(`REUSE_ID_UNCHANGED_HASH_BOUND`). DL-089 (pattern-filter census, `decisions/DL-089...`,
OWNER-ratified 2026-08-21) already established the precedent of hash-binding both the raw
card config and a selected DEV config with `declared_trial_count`. What is **not** yet
generalized: Q03 itself does not visibly distinguish "stability test, no strategy change" runs
from "declared DEV calibration" runs as two named lanes with independent hash chains. Needs
explicit dual-lane labeling at Q03, reusing the DL-089 hash-binding pattern.

### C3 — Q04 nested WF w/ purge+embargo, or honestly-named Locked-Parameter Sequential OOS
**SATISFIED.** `framework/scripts/q04_walkforward.py:1-23`: 3 anchored expanding-window
folds, 12-month sequential OOS each (F1 OOS 2023, F2 OOS 2024, F3 OOS 2025), commission-
adjusted, params locked from the Q03 plateau pick. The v4 manifest already names this
correctly: `gate_manifest.v4.json` Q04 `evidence_role: "LOCKED_PARAMETER_SEQUENTIAL_OOS"` —
**not** claimed as nested walk-forward with purge/embargo. This is the honest label the
criterion asks for. No change needed; a window-consumption matrix (DEV/Validation/
FINAL_HOLDOUT per gate) is still owed as a **presentation** artifact — see §3.2.

### C4 — Q08 target-neutral; portfolio correlation/tail-contribution deferred to Q15
**GAP — concrete, code-confirmed violation.** The v4 manifest labels Q08
`evidence_role: "TARGET_NEUTRAL_EVIDENCE_DOSSIER"`, but Q08's own sub-gates are **not**
target-neutral:
- `framework/scripts/q08_davey/sub_8_1_correlation.py:1-18` — "Q08.1 Correlation vs existing
  portfolio": pairwise `|Pearson r| < 0.50` against **every EA currently in book status**
  (old-numbering "Q11+", i.e. today's Q15+). `ABS_R_MAX = 0.50` directly gates PASS/FAIL at
  Q08 — Phase 1, before the candidate has even been requalified through optimization (Phase 2)
  or reached book construction (Phase 3, Q15). "Empty portfolio pool = trivial PASS" also
  makes the verdict **order-dependent** (first-mover advantage: identical strategies pass or
  fail Q08 depending on what already happened to be admitted earlier).
- `framework/scripts/q08_davey/sub_8_3_tail_dependence.py` — same class of portfolio-relative
  check (not read in this pass; flagged for the same reason by naming/import grouping in
  `aggregate.py:38`).
- `framework/scripts/q16_head_to_head.py:48-49,690,699` (v4 Q14, terminal optimization gate) —
  `CORR_ADMIT_MAX = 0.15` / `CORR_REJECT_MIN = 0.40` against portfolio regime correlation
  **directly participate in the CHALLENGER_PROMOTED vs KEEP_INCUMBENT verdict** (line 690:
  `pair_corr["max_abs_regime_corr"] < CORR_ADMIT_MAX`). Portfolio correlation is therefore
  consumed twice before Q15: once at Q08 (Phase 1) and once at Q14 (end of Phase 2).

This is exactly the defect the criterion anticipates. Proposed contract delta (ROT — needs
OWNER ratification, see §4): move `sub_8_1_correlation` and `sub_8_3_tail_dependence` out of
the Q08 PASS/FAIL verdict into an **informational dossier field** (measured, stored,
surfaced, never gating), matching how Q10 `Q10_PORTFOLIO` is already informational-only per
OWNER E1 2026-08-22. Q14's correlation gate is harder to relocate cleanly because
"does the challenger still diversify vs. the current book" is a legitimate question — but it
answers a Phase-3 (book) question inside a Phase-2 (per-EA) terminal gate. Recommend either
(a) split Q14 into a target-neutral edge comparison (CHALLENGER_PROMOTED/KEEP_INCUMBENT on
edge quality alone) with portfolio-fit re-checked at Q15 as an admission filter, not a Q14
verdict input, or (b) keep Q14 as-is and document it explicitly as a deliberate exception with
OWNER sign-off. This document takes no position — it is a ROT decision.

### C5 — Q09 canonical baseline contract, own build/set/report hashes; hardcoded ToDate defect addressed
**GAP — concrete, code-confirmed defect, currently live.** `framework/scripts/_phase_utils.py:
330-332`:
```
FULL_HISTORY_FROM = "2017.01.01"
FULL_HISTORY_TO = "2025.12.31"
FULL_HISTORY_YEAR = "2025"
```
Consumed by `framework/scripts/q08_davey/aggregate.py:945-953` (`-ToDate "2025.12.31"` on the
Q08 full-history baseline run) and by every other importer of `_phase_utils.full_history_window`
— which almost certainly includes the v4 Q09 "Baseline Full Run" (evidence_role
`PRE_NEWS_FULL_HISTORY_BASELINE`, reuse rule `REUSE_ONLY_HASH_BOUND_FULL_HISTORY_Q08_BASELINE` —
i.e. Q09 explicitly reuses the Q08 baseline run, so it inherits this cutoff). **Today is
2026-08-24: the "full-history" window is >8 months stale**, silently excluding all of 2026
from what is billed as the canonical pre-optimization baseline and from the Q14 before/after
comparison that references it. This is not a hypothetical — every currently-running Q08/Q09
baseline is measuring an incomplete history. Fix (GRÜN — no criterion change, pure currency
maintenance per Stehende Vollmacht): make `FULL_HISTORY_TO` a rolling "yesterday, broker-time"
value or a governed re-cut cadence (e.g. quarterly), NOT a literal string. Needs a Codex ticket;
not a threshold change, so no OWNER ratification required — flagged here because it sits
directly inside the contract this task was asked to design.

Q09 does not yet have its own hash-bound build/setfile/report identity **independent** of the
Q08 evidence it reuses (the reuse rule ties it structurally to Q08's baseline artifact) — this
satisfies "own canonical baseline contract" only partially; recommend Q09 stamp its own
build+setfile+window+report hash triple even when the numeric result is reused, so the Q14
comparison has an explicit, dated Q09-side hash to diff against, not an inherited Q08 hash.

### C6 — Q10 separates news-edge optimization from FTMO-compliance; No-Filter + News-only in search space; no same-window selection-as-confirmation
**GAP.** `framework/scripts/q09_news_mode.py:1-60` (v4 Q10): the pipeline applies a **fixed
default** (`DEFAULT_TEMPORAL = PRE30_POST30`, `DEFAULT_COMPLIANCE = DXZ`) per explicit OWNER
policy ("pipeline does NOT stall waiting for OWNER... default is auto-applied"). A diagnostic
`--sweep` across all 7 temporal modes exists but is optional/diagnostic, not the formal
selection mechanism. There is no visible No-Filter (`QM_NEWS_TEMPORAL_OFF` is present in
`ALL_TEMPORAL_MODES` but only reachable via `--sweep`) vs News-only edge-optimization pass that
is then validated out-of-sample before being reported as an FTMO-compliance recommendation.
Today's Q10 answers "is Mode 3 acceptable" by construction, not "which mode is best, and is
that choice validated." Needs a two-pass redesign: Pass A = edge search across
{OFF, News-only, DXZ-compliant modes} on a DEV slice; Pass B = the winning mode confirmed on
a held-out slice distinct from the DEV slice used for selection. This is the core ask of the
router task and is currently unmet.

### C7 — Q12/Q13 pattern (0..3/direction) + numeric params, sequential, no-change cells, frequency floor, full declared_trial_count
**PARTIAL, likely close to satisfied.** Q12 = DL-089 pattern-filter selection contract, already
OWNER-ratified with 13 decisions (`decisions/DL-089...`, memory `project_qm_pattern_permission
_filter_wf_...2026-08-21`): anchored WF, consistency ≥2/3 @ +5%, `declared_trial_count=154`,
cap 3 filters/direction, zero-filter = valid pass-through (manifest note, not an
`EXPLICIT_Q14_ADMISSION` gate anymore — this itself is a v4 topology fix vs the v3 concern).
Q13 = "Parameter Optimization & Freeze", `evidence_role: DEV_ONLY_PARAMETER_SWEEP_AND_FREEZE` —
**not independently verified in this pass** whether no-change cells and a frequency floor are
wired into Q13's own runner (no `q13_*`/param-opt script was read). Recommend a focused Codex
verification ticket rather than re-deriving DL-089 here.

### C8 — No unaudited Q10→Q11 direct path; every candidate gets a terminal optimization audit; KEEP_INCUMBENT must be a real audit outcome, not a skip
**SATISFIED by v4 topology.** The `ordinary_chain` is strictly monotone (Q10→Q11→Q12→Q13→Q14,
`linearity_invariant: STRICTLY_MONOTONE`); Q12's zero-filter and Q13's no-change are explicitly
valid **pass-through** states, not exits — the candidate still must reach Q14. Q14 is
`terminal_optimization_gate: true` with exactly two `valid_outcomes`
(`CHALLENGER_PROMOTED`, `KEEP_INCUMBENT`) and is a **sealed, SHA-bound, analytic-only
evaluator** (`q16_head_to_head.py:1-8`, "no terminal, DB, queue, or live surface access").
The book trigger (`gate_manifest.v4.json:book_trigger`) requires
`highest_contiguous_valid_gate == Q14 with terminal requalification verdict`, i.e. a candidate
structurally cannot reach Q15 (book) without a real Q14 evaluator run. `KEEP_INCUMBENT` is
therefore an audited outcome, not a bypass. No further design work needed here; this criterion
is a good example of v4 already delivering what the task asked for.

### C9 — Q14 pairwise vs Q09 baseline + incumbent, full-history descriptive only, promotion on sealed OOS/holdout with PBO/DSR/FDR/trial-deflation
**PARTIAL — the statistical machinery exists but is not applied where the criterion needs it.**
Q08 already implements real, non-trivial statistics:
- `sub_8_2_dsr_mc_fdr.py:1-45` — Deflated Sharpe Ratio (Bailey & López de Prado 2014), Tier-1
  core (`DSR_P_MIN=0.05`) + Tier-2 Benjamini-Hochberg FDR watchlist. **Two defects**: (a)
  `N_CANDIDATE_STRATEGIES = 369` is a hardcoded comment-flagged estimate ("rough V5 candidate
  count... TODO(calibration): once the farm wires a real candidate-Sharpe...") — the farm has
  well over 100k work-item rows and thousands of distinct EA/symbol pairs today, so this cohort
  size is almost certainly stale by more than an order of magnitude, which understates the
  deflation and overstates significance for every DSR check that uses it. (b) deflation only
  applies when a trial ledger is present (`MIN_SELECTION_TRIALS_FOR_DEFLATION=2`); "ordinary
  Q08 runs (which carry no trial ledger) are bit-identical to before" — i.e. the bulk of the
  funnel gets a single-trial DSR with no multiple-testing correction at all.
- `sub_8_7_pbo.py:1-30` — real PBO via CSCV (López de Prado & Bailey 2014, `PBO_MAX=0.40`,
  `PBO_MIN_SPLITS=10`), but it slices the **Q03 parameter sweep** only. It measures overfitting
  of the pre-optimization parameter selection, not of the Q12 pattern-filter or Q13
  re-optimization search that happens later in Phase 2.
- `q16_head_to_head.py` (Q14) reads a `TRIAL_LEDGER_SCHEMA: qm.opt-trial-ledger/v1` and
  propagates `declared_trial_count` as evidence metadata (`:282-320`) — but does **not**
  recompute PBO or DSR itself for the frozen post-Q12/Q13 configuration. The Q08 PBO/DSR
  dossier is measured before the optimization search that produced the thing Q14 is actually
  promoting; the search-space that produced the challenger (Q12 pattern selection × Q13 param
  refit) has its own selection multiplicity that is currently only tracked as a trial *count*,
  never fed into a PBO/DSR computation at the point of promotion.

Fix (ROT — new statistical requirement at an existing gate, needs OWNER ratification): Q14
should run its own DSR/PBO pass over the Q12×Q13 trial ledger before returning
`CHALLENGER_PROMOTED`, using the same `sub_8_2_dsr_mc_fdr`/`sub_8_7_pbo` machinery already
built for Q08 rather than new code. `N_CANDIDATE_STRATEGIES` must be computed from a live query
against `work_items`/`ea_metrics`, not a hardcoded constant, in both places.

### C10 — Prospective/supersession plan for repeatedly-tested 2023-2026 data; old evidence never overwritten
**PARTIAL.** DL-090 (`decisions/DL-090_backtest_report_retention_policy.md`, OWNER-ratified
2026-08-23) already guarantees every PASS run and every standing rejection is retained
permanently (memory: 37,652/111,396 runs = 33.8%, never overwritten) — this satisfies the
"old evidence never overwritten" half. What is **not** addressed: a policy for how many times
the *same* 2023-2026 historical window may be re-used as "confirmation" across repeated Q02-Q14
cycles for the same (EA, symbol) before that reuse itself becomes a data-snooping concern
(distinct from DSR's cross-candidate selection bias — this is cross-*attempt*, same-candidate,
same-window reuse). Q17 Live Burn-In DXZ is structurally the correct prospective/out-of-sample-
in-time check (it trades forward in real time, so it cannot be re-fit to). Recommend: (a) a
per-(EA,symbol) "historical-window touch count" surfaced from the trial ledger infrastructure
already built for Q12/Q13, so repeated re-use is visible, not silently absorbed; (b) treat Q17
burn-in explicitly as the supersession mechanism for claims made on 2023-2026 data — a book
candidate's real "out of time" evidence is the burn-in, not another full-history re-run.

### C11 — Deliverable format (diff, gate-page diff, machine contract/test matrix, migration plan, OWNER decision template)
**This document.** §0-1 = diff vs v4 and gate-page-level status; §2 = machine contract/test
matrix; §3 = migration plan; §4 = OWNER decision template. No activation performed.

## 2. Machine contract / test matrix

| Contract item | Current enforcement point | Test needed |
|---|---|---|
| Q08 target-neutrality | `sub_8_1_correlation.py`, `sub_8_3_tail_dependence.py` gate PASS/FAIL | New: assert Q08 verdict is invariant to portfolio composition (run same candidate against empty vs. populated book pool, verdict must match once correlation is informational-only) |
| Q09 baseline currency | `_phase_utils.FULL_HISTORY_TO` | New: fail-closed check that `FULL_HISTORY_TO` age (data_date − now) is below a governed max (e.g. 45 days), not a literal string equality test |
| Q10 news/FTMO separation | `q09_news_mode.py` default-apply | New: Pass-A/Pass-B split test — selection window ≠ confirmation window; assert the reported "best mode" was never scored on the confirmation slice during selection |
| Q12 pattern selection | DL-089 contract, `gate_manifest.v4.json` `selection_contract: DL-089` | Existing (per memory); re-verify `declared_trial_count` propagation end-to-end into Q14's ledger read (`q16_head_to_head.py:282`) |
| Q13 param freeze | Not verified this pass | New: locate/confirm no-change-cell + frequency-floor wiring |
| Q14 terminal audit completeness | `book_trigger.requires_all` in `gate_manifest.v4.json` | Existing — confirm `highest_contiguous_valid_gate` computation actually rejects any row missing a real Q14 evaluator artifact (not just a stamped Qxx string) |
| Q14 PBO/DSR on frozen config | Not present | New: extend `q16_head_to_head.py` to call `sub_8_2_dsr_mc_fdr`/`sub_8_7_pbo` against the Q12×Q13 trial ledger before `CHALLENGER_PROMOTED` |
| `N_CANDIDATE_STRATEGIES` currency | Hardcoded `369` in `sub_8_2_dsr_mc_fdr.py:34` | New: replace with a live count query; add a staleness assertion (fail if constant age > N days without a matching live count) |
| Evidence retention | DL-090, `docs/ops/evidence/...` job `4e67a1a0` | Existing — no new test |

## 3. Migration plan

No gate IDs, thresholds, or windows change in this document. All items are either (a) pure
maintenance/currency fixes with no criterion change (GRÜN, Stehende Vollmacht), or (b) new
statistical requirements at existing gates (ROT, OWNER ratification required, §4).

1. **GRÜN — ship without further sign-off:** `FULL_HISTORY_TO` rolling-window fix
   (`_phase_utils.py`); `N_CANDIDATE_STRATEGIES` live-query fix
   (`sub_8_2_dsr_mc_fdr.py`); Q09 own-hash stamping alongside its reused Q08 baseline.
2. **Needs a focused verification ticket, not a design decision:** Q13 no-change-cell +
   frequency-floor wiring (C7); DL-089→Q14 `declared_trial_count` propagation test (C7/C9).
3. **ROT — blocked on OWNER decision template §4:** Q08/Q14 portfolio-correlation relocation
   (C4); Q10 two-pass news/FTMO redesign (C6); Q14 PBO/DSR extension (C9); Q02
   CONTRADICTED/INSUFFICIENT/INVALID split design (C1); Q03 dual-lane hash-binding (C2);
   historical-window touch-count + Q17-as-supersession policy (C10).
4. Sequencing: none of the ROT items block each other, but C6 (Q10 two-pass) and C9 (Q14
   PBO/DSR) are the highest-value fixes because they sit directly on the funnel's promotion
   path (Q10 recommendation, Q14 promotion) rather than on peripheral dossier fields.

## 4. OWNER decision template — ROT items requiring ratification

| # | Item | Recommendation | Cost of waiting |
|---|---|---|---|
| D1 | Q08 `sub_8_1_correlation`/`sub_8_3_tail_dependence` verdict role | Move from PASS/FAIL-gating to informational dossier field (mirrors Q10_PORTFOLIO precedent, OWNER E1 2026-08-22) | Every Q08 run today is order-dependent on book composition; candidates can flip PASS/FAIL with no change to their own edge |
| D2 | Q14 portfolio-correlation gate (`CORR_ADMIT_MAX`/`CORR_REJECT_MIN`) | Either split into a target-neutral edge verdict + separate Q15 admission filter, or explicitly ratify as a deliberate Phase-2 exception | Currently blends per-EA and per-book judgment inside one terminal verdict without a documented rationale |
| D3 | Q10 two-pass news/FTMO redesign (No-Filter + News-only in search space, DEV vs. confirmation window split) | Adopt Pass-A/Pass-B design in §1 C6 | Current Q10 recommendation is a fixed-default application, not a validated selection; FTMO-suitability claims are not backed by an out-of-sample check |
| D4 | Q14 PBO/DSR extension over the Q12×Q13 trial ledger | Wire `sub_8_2_dsr_mc_fdr`/`sub_8_7_pbo` into `q16_head_to_head.py` before `CHALLENGER_PROMOTED` | Promotions to the book pool currently carry no overfitting statistic for the optimization search that produced them |
| D5 | Q02 CONTRADICTED/INSUFFICIENT/INVALID three-way split | Needs a from-scratch design against whatever Q02 runner is canonical today (not located in this pass) | Q02 taxonomy currently collapses these into the farm-wide PASS/FAIL/infra taxonomy, losing the distinction the criterion asks for |
| D6 | Q03 dual-lane hash-binding (stability test vs. declared DEV calibration) | Generalize the DL-089 hash-binding pattern to Q03 | Ambiguity between "we re-ran the same strategy" and "we calibrated it" at the earliest gate propagates downstream |
| D7 | Historical-window touch-count + Q17-as-supersession policy | Adopt §1 C10 recommendation | Repeated 2023-2026 window reuse across cycles is currently invisible; no prospective check is named as authoritative |

Auffangregel note: none of D1-D7 are executed under standing authorization — all touch gate
criteria/verdict logic (ROT, per Stehende Vollmacht §"ROT (never autonomous)"). This table is
the submitted Vorlage; absent an OWNER response the 12h Auffangregel does **not** apply to ROT
items and no default execution follows.

## 5. Explicit non-actions (hard constraints honored)

- `OPS-GATE-MANIFEST-V3-ACTIVATE` (router `8b233c0f`) was not touched; its terminal state
  (APPROVED, superseded by v4) was read only.
- No gate threshold, window, verdict, or live/book-promotion state was changed.
- No work-item enqueue, verdict mutation, or factory/terminal/T_Live action was taken.
- Full-history comparisons are not represented anywhere in this document as independent OOS
  evidence.
- `QM-TODO-20260822-402` is the pre-existing vault checkbox this document updates; no second
  checkbox was created.
