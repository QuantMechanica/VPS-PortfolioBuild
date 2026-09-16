# Receipt — OWNER-DEC-REQUEUE-LIFT-20260916-D4 authority registration — QM5_11731

- Owner decision id: `OWNER-DEC-REQUEUE-LIFT-20260916-D4` (ratified via OWNER
  package `docs/ops/OWNER_DECISION_PACKAGE_D4_D5_2026-09-16.md`, DECISION 4,
  APPROVE WITH CONDITIONS; interim delegation `OWNER-DEC-REQUEUE-LIFT-20260916`)
- Operator: `kimi-interim` (D4 execution)
- Date (UTC): 2026-09-16
- EA: `QM5_11731` (slug `QM5_11731_tc-m5-s20-ema3-bb-macd`) — **scoped to this
  EA only; no generic force-rebuild authority is created**

## What was registered (append-only, fail-closed)

1. `tools/strategy_farm/compile_work_items.py`:
   - `REQUEUE_LIFT_D4_FORCE_REBUILD_OWNER_REFERENCE = "OWNER-DEC-REQUEUE-LIFT-20260916-D4"`
   - `REQUEUE_LIFT_D4_FORCE_REBUILD_EA_IDS = frozenset({"QM5_11731"})` (+ numeric form)
   - `REQUEUE_LIFT_D4_FORCE_REBUILD_DECISION_DOC` → the decision document below
   - `requeue_lift_d4_force_rebuild_allowlist(repo_root)` — unions into
     `force_rebuild_allowlist`; waives only `FORCE_REBUILD_WAIVABLE_REASONS`
   - `force_rebuild_owner_reference` / `force_rebuild_evidence_note` extended
     for the D4 wave (payload records the D4 owner reference + decision doc)
   - Pattern mirrors the pre-0803 document-bound wave: the hardcoded EA-id name
     AND the decision document in this checkout (exact owner reference AND the
     `QM5_11731` name) must both agree, else the bypass stays off. Removing or
     rewriting the document revokes the authority without a code change.
2. `docs/ops/evidence/2026-09-16_requeue_lifts/OWNER-DEC-REQUEUE-LIFT-20260916-D4_QM5_11731_force_rebuild.md`
   — the OWNER decision document the code binds to.

## Verification (live, pre-commit)

- `requeue_lift_d4_force_rebuild_allowlist(repo)` → `frozenset({'11731'})`
- `classify_candidate(...)` for `QM5_11731_tc-m5-s20-ema3-bb-macd` →
  `eligible: True`, `reasons: []`, `force_rebuild_authorized: True`,
  `force_rebuild_waived_reasons: ['BUILD_TASK_EXISTS', 'EX5_ALREADY_PRESENT']`,
  symbols = 4 × .DWX, timeframe M5 (resolved from existing setfiles).
- Test suite `tools/strategy_farm/tests/test_compile_work_items.py`:
  **93 passed, 1 failed** — the single failure
  (`test_compile_profile_stdlib_failure_is_persisted_as_infra_not_compile_fail`)
  is **pre-existing** (fails identically with the change stashed; live-DB
  `VerdictTaxonomyContractError`, unrelated to this registration).

## Guardrails honored

- No existing `.ex5` deleted or un-committed; no historical build task reopened.
- No DB rows hand-written; enqueue path is the governed classifier.
- Exclusion file untouched at this step (hash still D2A after-hash
  `3f092f0a…f3f3`, `QM5_11731` line present) — lift happens only after a valid
  fresh build identity exists.

## Continuation

Next: `farmctl enqueue-compile --apply` → release the rollout hold bounded to
the new COMPILE_EA item → canonical compile → exclusion lift →
`intake-first-q02` EURUSD.DWX M5 canary → pilot checks a–e → governed fanout.
