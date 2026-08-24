# Review — Gate-Generation 2: semantic card-contract predicates (task 5254b29a)

- Router task: `5254b29a-3ec5-463b-acd6-c07fb2e2fd99` (ops_issue, assigned codex, REVIEW)
- Reviewer: Claude review lane / `agents/board-advisor`
- Delivered by: commit `7e52bc673` "feat(build): add semantic card gates"
- Worker verdict/artifact: `docs/ops/evidence/2026-08-23_build_gate_semantic_defect_classes.md`
  ("IMPLEMENTED — REVIEW; no compile or pipeline verdict")
- **Verdict: APPROVED** (tooling accepted; adds predicates only, no EA/pipeline verdict)

## What was reviewed
Codex mechanized the seven recurring semantic defect classes from the 8 negative
reviews (QM5_1405/1407/1408/1409/1410/1416/1417/1425) into build-gate predicates
D13–D18 in `tools/strategy_farm/build_gate_hardening.py`, and named the two classes
it declined to automate.

## Acceptance criteria — met
1. Per-class reasoned decision: 5 mechanized (D13 pending-order, D14 SMA direction,
   D15 news window/entry-only, D17 card universe, D18 zero-trade ordering), 2 declined
   with named missing card declarations (D12 invented inputs → `required_data_inputs[]`;
   D16 restart-safe mgmt → `restart_state_contract[]`). `SEMANTIC_AUTOMATION_SCOPE`
   at build_gate_hardening.py:54; emitted in every JSON report (line 1890).
2. Each mechanized predicate has a passing AND a failing fixture — verified by running
   the tmp_path tests (D13:451, D14:486, D15:520, D17:564, D18:584). PASS.
3. Predicates go beyond D1–D6 static gates: 1417/1425 caught. Evidence doc records the
   label-scoped analyzer catch (1417: 6 findings; 1425: 5 findings) against the
   pre-repair source; both EAs have since been repaired, so the tree-state regression
   tests (`test_semantic_regression_accepts_fixed_1417` / `_repaired_1425`) now assert
   clean — the catch is preserved via the doc + synthetic falling fixtures.
4. No false-positive on clean builds: `test_semantic_predicates_have_real_satisfying_sources`
   proves real satisfying sources (QM5_20045 pending-stop OCO + exact 2-symbol universe,
   QM5_10000 120/120 news, QM5_10418 rising+falling SMA, QM5_1417 clean descending pivots). PASS.
5. Non-mechanizable classes name the missing card declaration
   (`test_nonmechanizable_semantic_classes_name_required_card_declarations`). PASS.
6. No dead predicate: every predicate proven against a real satisfying source, not only
   a violating one. Comment/literal stripping (strip_comments_preserve_lines /
   strip_literals_preserve_lines) guards against lexical false positives.

## Hard constraints — respected
- No gate thresholds changed (ROT): commit touches only the hardening module, its tests,
  and the evidence doc — no manifest, no schema, no thresholds.
- No recompile of active inventory, no T_Live: code only.
- Both-direction proof present for every live predicate.
- agent_router.py:1871 lane narrowing NOT rebuilt (agent_router untouched; deferred to 6a131ec6).

## Verification run (read-only)
- `pytest ... -k "d13 or d14 or d15 or d17 or d18 or semantic or nonmechanizable or regression"`:
  **10 passed, 20 deselected** (1.40s).
- Bounded suite excluding the pre-existing all-EA D6 census
  (`-k "not test_d6_canonical_eas_have_no_raw_bars_calculated_call_sites"`):
  **28 passed, 1 failed, 1 deselected** (5.77s). The one failure —
  `test_qm5_411xx_sources_have_no_unbounded_numeric_buffers` on QM5_41134:599 — is
  OUT OF SCOPE: that test was added by a later commit (565e5110f) and QM5_41134 was
  implemented later still (9de298a2f); it exercises D10 buffer bounds, not the D13–D18
  semantic gates delivered here. Not a defect of task 5254b29a. It should be picked up
  as its own follow-up against the 411xx buffer-bounding lineage.
- `py_compile` of the changed module: implicit PASS (imported by all above tests).

## Note
The delivered evidence header ("Required regressions now fail") is stale relative to the
current tree, where 1417/1425 were repaired after the doc was written; the tree-state
tests correctly assert clean. Documentation-timing artifact, not a code defect.
