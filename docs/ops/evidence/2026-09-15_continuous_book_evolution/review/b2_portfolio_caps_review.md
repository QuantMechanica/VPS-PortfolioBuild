# Adversarial review — slice `b2_portfolio_caps`

Reviewer: adversarial review subagent, 2026-09-15.
Patch: `scratchpad/patches_bc/b2_portfolio_caps.patch` (999 lines, 9 files), read in full.
Authority: OWNER-DEC-CBE-20260915 (directive §7, §8, §59, §68B, §70, §71).
Verdict: **ACCEPT_WITH_FIXES** — no blocking defects; three follow-up (major) items; two notes (minor).

---

## Verification performed

- Read the full patch, the verbatim directive, and both audits (`rule_inventory_code.md`
  F4/F5/F6 + drift D1/D4; `portfolio_engine_existing.md` findings 6/9).
- `git apply --check` on the canonical repo tree: **applies cleanly, exit 0** (all 9 files).
- Extracted new `risk_diagnostics.py` from the patch and `py_compile`d it: **compiles OK**.
- Applied the contract hunk to an isolated copy and `json.load`d it: **valid JSON**,
  `hard_book_admission.value == 0.50` retained, `status == ADVISORY`, `superseded_by` present.
- Confirmed current source context matches the patch's "before" lines
  (`concentration_tail.py`, `build_book_ftmo.py:306-322`, `build_book_dxz.py:208`, contract :30).
- Repo-wide grep for renamed / removed symbols to find broken callers (see §3).
- Verified the manifest schema (`dual_book_manifest.v1.schema.json`) admits the new fields
  and that `book_builder_common.validate_dual_book_manifest` stays consistent.

---

## 1. RED boundaries

`red_boundary_crossed = TRUE` — a **contract criterion was reclassified**, but the change is
**explicitly OWNER-authorized, value-preserving, and properly recorded**. Detail:

- **ROT_SEALED correlation cap 0.50 → ADVISORY** (`ftmo_probability_contract.v1.json`
  `caps_absolute_layered.hard_book_admission`; `portfolio_correlation.py:77`). This is a
  contract-criterion change that is normally ROT. It is authorized by the directive: §8
  ("fixed pairwise correlation limit ... must no longer be treated as absolute Hard Rules"),
  §68B ("replace hard portfolio caps with evidence-based portfolio risk analysis"), §67
  ("Do NOT ask OWNER to reapprove decisions already explicit here"). The **numeric value
  0.50 is retained** (as advisory reference + Layer-A CI measurement band); no threshold
  number was invented or weakened. Supersession is recorded in three places
  (`former_status`/`superseded_by`/`advisory_note` in the contract, code comments in
  `portfolio_correlation.py` + `build_book_ftmo.py`, and the slice report) — satisfies
  `no_silent_reclassification`. **Not a violation; not blocking.**
- **OWNER_RATIFIED discrete caps (family≤3 / symbol≤2) → ADVISORY** — same authorization
  chain (§8). Numbers kept as warning thresholds. Recorded identically.
- **§71 safety preserved:** `CLUSTER_CORRELATION_UNVERIFIED` (unmeasured pair) stays
  fail-closed (verified in code + test `test_ftmo_unverified_correlation_still_fails_closed_
  under_advisory_regime`). Unknown reject dimensions are treated as HARD in
  `risk_diagnostics.split_rejects` (fail-closed by default).
- **No other RED touch:** `application_authority` stays `OWNER_ONLY`; `deployment_action`
  and `autotrading_action` stay `NONE` (validation `book_builder_common.py:435-446`
  unchanged and still enforced). No T_Live/AutoTrading toggle, no purchase path, no
  evidence rewrite (the report is a new file; no history deleted; audit findings intact),
  no farm-DB write, no credential/token exposure.

## 2. Directive fidelity

- **§7/§8 — caps → advisory diagnostics: DONE.** Per-dimension concentration breaches now
  emit `cap_warnings[]` (cap name, value, threshold, unit, severity, affected_sleeves,
  superseded_hard_cap) instead of `concentration_reject`. `concentration_reject` now carries
  only the surviving hard guards (`joint_tail` venue-daily-loss + fail-closed `data`).
  `passed`/`builder_eligible` in `concentration_tail.evaluate` are naturally driven by the
  hard-guard-only `rejects` (line 500 `passed = not rejects` unchanged; correct by
  construction).
- **§8 "no new arbitrary permanent cap": SATISFIED.** The only hard guards are the
  pre-existing portfolio-level ones (joint-tail / venue-daily-loss in `concentration_tail`,
  account risk budget `admitted_weight <= account_weight_budget` in `build_book_ftmo`) plus
  fail-closed data validity. No new numeric cap was introduced.
- **§70 "warnings do not silently become a no-op": SATISFIED.** Warnings are asserted
  present in output (`risk_diagnostics` block embedded unconditionally in both manifests +
  `analysis_summary`) and rendered by consumers (`risk_diagnostics.markdown`,
  `concentration_tail.markdown_panel` advisory section) in `evidence.md`. Correlation
  admit-with-WARN produces `correlation_warnings` + a `dependence_panel` entry. Tests assert
  presence (`test_risk_diagnostics_surface_cap_warnings_and_hard_guards`,
  `test_family_cap_breach_is_advisory_and_book_still_builds`,
  `test_ftmo_aggregate_control_admits_high_corr_with_warn_and_panel_entry`).
- **Stale source pointer (audit D1) fixed:** `q15_discrete_count_caps.source` corrected from
  the false `build_book_ftmo.py:60,66` to `NOT_BUILDER_ENFORCED; origin decisions/2026-09-04
  _owner_receipts_briefing_2_4.md`. Correct — those lines are `FUND_SCORE_FLOOR` + a comment
  that explicitly rejects a per-symbol/family count cap.
- **ROT supersession recorded:** yes (see §1).
- **Determinism (§26/§58): PRESERVED and tested** (`test_ftmo_aggregate_control_is_
  deterministic_under_warn_admission` compares `json.dumps(sort_keys=True)` of two runs).

## 3. Correctness

- **Patch applies cleanly; new module compiles; contract JSON valid** (see Verification).
- **Schema OK:** `dual_book_manifest.v1.schema.json` has top-level `additionalProperties:
  true`, so the new top-level `risk_diagnostics` validates; the `concentration_tail`
  subschema sets no `additionalProperties:false`, so the new `cap_warnings` key validates.
  Status enum unchanged — a surviving hard-guard breach still maps to
  `CONCENTRATION_CAP_BREACH`.
- **No broken external callers of renamed/removed symbols (grep-verified):**
  - `checks["concentration_tail_caps"]` → renamed to `concentration_tail_hard_guards`; the
    key is only produced at `build_book_ftmo.py:594` and consumed locally by
    `bar_met = all(checks.values())`. No other reader in the repo.
  - `CLUSTER_CORRELATION_EXCLUDED` → the only remaining references after the patch are
    historical evidence docs (immutable) and the `build_book_ftmo.py` **docstring**
    (see MAJOR-1). No production consumer (dashboards/cockpit/readiness) reads it.
  - `aggregate_control["excluded"]` — high-corr pairs move to `correlation_warnings`/
    `dependence_panel`; `excluded` now holds only genuinely-rejected pairs
    (UNVERIFIED / RISK_BUDGET_EXHAUSTED). Only consumer of the exclusion reason was the
    test (updated by the patch).
- **`_final_status` (DXZ) logic sound:** blocks only on `risk_diagnostics.hard_guard_rejects`
  (joint_tail/data + unknown-as-hard); advisory cap breaches no longer force
  `CONCENTRATION_CAP_BREACH`. `book_builder_common.py:448-451` invariants
  (builder_eligible ⇒ ratified; positive status ⇒ builder_eligible) remain consistent.
- **Behavior change (intended, deterministic, noted):** in `select_under_aggregate_control`
  a high-corr sleeve is now *admitted* (admit-with-WARN) and therefore **consumes the
  account weight budget**, where previously it was excluded and consumed none. This can trip
  `RISK_BUDGET_EXHAUSTED` earlier for later (lower-score) candidates. This is the correct
  §8 semantics (portfolio-level risk budget is the hard guard) and is deterministic; flagged
  only so it is not mistaken for a regression.
- **`dependence_panel_entry`** handles `None` correlation (→ `UNVERIFIED`); admitted pairs
  always have a measured correlation (an unverified peer forces rejection earlier), so panel
  entries for admitted pairs are `WARN`/`OK`, never spuriously `UNVERIFIED`. Correct.
- **No Windows path issues:** new code introduces no filesystem paths;
  `concentration_tail.REPO_ROOT` via `Path(__file__).resolve().parents[3]` unchanged.

## 4. Tests (§70)

- The §70-relevant tests are present and meaningful: advisory-warning conversion, family cap
  advisory + book still builds, joint-tail hard guard still fails closed, DXZ final status
  only blocks on hard guard, FTMO admit-with-WARN + panel entry (positive and negative
  correlation), determinism, unverified-still-fails-closed, and a direct
  `risk_diagnostics.build` presence/hard-guard assertion.
- Summary line shows **38 passed / 1 skipped** (dual-book + concentration + contract) and a
  clean regression sweep (87 passed). Patch applies cleanly and imports resolve, consistent
  with the claim. I did not re-execute pytest (read-only constraint on the repo tree), but
  every static precondition for the claim checks out.
- Gap (MINOR-1): no *end-to-end manifest* test asserts `build_dxz_manifest(...)
  ["risk_diagnostics"]["cap_warnings"]` / `build_ftmo_manifest(...)["risk_diagnostics"]`
  is populated. The builders embed it unconditionally, but a manifest-level assertion would
  harden §70 against a future refactor.

## 5. Docs

- Code comments are English, cite the dated decision (OWNER-DEC-CBE-20260915), and name the
  superseded status. Contract carries `former_status`/`superseded_by`/`advisory_note`.
  Report records the ROT supersession. No history deleted.
- **MAJOR-1 (stale docstring):** `build_book_ftmo.py` `select_under_aggregate_control`
  docstring (lines 253-256, unchanged by the patch) still states control (a) *"reject any
  candidate whose ... correlation ... exceeds max_pairwise_correlation
  (CLUSTER_CORRELATION_EXCLUDED)"*. After this slice the behavior is admit-with-WARN; the
  docstring now contradicts the code and the inline comments. Doc-only, non-behavioral, but
  it is the contract description of the changed function (§66). Fix in follow-up.

## Findings

**Blocking:** none.

**Major (fix in a follow-up slice):**
- **MAJOR-1** — Stale docstring in `build_book_ftmo.py:253-256` still describes the removed
  `CLUSTER_CORRELATION_EXCLUDED` hard-exclusion; update it to the admit-with-WARN semantics.
- **MAJOR-2** — Dependence panel is **correlation-only**. The task said to include
  *trade-overlap "if the existing overlap primitive exists"* — and it does
  (`portfolio_correlation.py` has occupancy/trade-overlap + signed-daily-direction overlap
  per audit Finding 1). The slice defers trade_overlap/downside_correlation to Phase-E
  `metrics.py`. §70 is still met (correlation WARN + panel entry are present and asserted, so
  no silent no-op), but §8's "measure real economic dependence" is only partially realized;
  wire the existing trade-overlap primitive into the FTMO panel in a follow-up.
- **MAJOR-3** — `book_reoptimizer.py --max-corr 0.50` greedy selection still applies a hard
  pairwise-correlation cut (audit F6). Correctly out of this slice's named files and flagged
  by the implementer, but it means the §8 "advisory" conversion is not yet complete across
  all active selection paths; schedule the follow-up slice.

**Minor (note):**
- **MINOR-1** — Add an end-to-end manifest test asserting `risk_diagnostics.cap_warnings`
  is populated from a full `build_*_manifest` run (hardens §70).
- **MINOR-2** — DXZ `risk_diagnostics.dependence_panel` is empty (DXZ has no pairwise-corr
  admission cutoff; that lives in `book_reoptimizer.py`). Documented in the report as
  deferred to Phase E. Acceptable; consumers should not assume a non-empty DXZ panel.

## Conclusion

The slice does what §7/§8/§70 require: static concentration + discrete + correlation caps
become advisory diagnostics; the pre-existing portfolio-level risk constraints (joint-tail /
venue-daily-loss / account risk budget) remain the only hard guards; no new arbitrary
permanent cap is invented; warnings are present in the builder result JSON and rendered in
evidence, with regression tests. The ROT_SEALED correlation cap reclassification is
OWNER-authorized (§8), value-preserving (0.50 retained), and recorded. Patch applies cleanly,
the new module compiles, the contract remains valid JSON, and no external caller breaks.
**ACCEPT_WITH_FIXES** (majors are follow-ups, not apply-blockers).
