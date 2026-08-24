# Review — Drain-Blocker Nr. 1: registry dispatch precondition (task 8d1d903f)

Date: 2026-08-24
Reviewer: Claude (review lane)
Router task: `8d1d903f-39cc-461f-ab90-7b932ce62fee` (ops_issue, assigned codex)
Worker verdict: `IMPLEMENTED_FAIL_CLOSED; LIVE_BATCH_BLOCKED_BY_CARD_IDENTITY_CONTRACTS`
Worker artifact: `docs/ops/evidence/2026-08-23_registry_dispatch_drain_blocker.md`
Implementation commit: `c3751fddd` (`fix(farm): gate builds on governed registry proof`)

## Scope
ops_issue: verify the delivered dispatcher/allocator fix against repo+DB, read-only. No
enqueue, no factory toggle, no T_Live, no registry mutation.

## Verified (file:line + command)

- **Commit present on branch.** `git show --stat c3751fddd` → 5 files, +919/-125; contained
  on `agents/board-advisor`.
- **A — fail-closed dispatch precondition.** `render_codex_build_prompt`
  (`farmctl.py:24419`) calls `magic_allocation_precheck` (`farmctl.py:24432`) BEFORE creating
  the `build_ea` task; on `ready==False` it returns `written:False` and schedules a
  deduplicated precondition task via `_ensure_magic_precondition_task`
  (`farmctl.py:24441` → `agent_router.ensure_magic_precondition_task:758`). No build prompt is
  emitted. This replaces the 37 identical refusal documents with one gate.
- **precheck fail-closed taxonomy.** `magic_allocation_precheck` (`farmctl.py:3122`) returns
  distinct non-ready classifications incl. `card_target_symbols_missing_or_invalid`,
  `ea_id_not_registered` (→GOVERNED_ALLOCATE), `registry_identity_conflict`
  (→`REVIEW_REQUIRED_DO_NOT_REACTIVATE`), `allocated_then_retired`
  (→`REVIEW_REQUIRED_DO_NOT_UNRETIRE`), `mixed_magic_history`. Retired non-reactivation guard
  is explicit — matches the 2026-08-15 collision precedent (commit 3e75ce562).
- **B — allocator discovery on live cards.** `governed_magic_allocator.py:33`
  `DEFAULT_APPROVED_CARDS = D:/QM/strategy_farm/artifacts/cards_approved`;
  `load_approved_card_candidates` (`:208`) globs the live dir, stamps stage `approved_live`
  (`:225`), and excludes duplicate identity/slug groups as groups rather than picking a winner.
  The frozen 08-17 worklists remain only as optional non-default args (`:912-913`). A card
  approved after 08-17 now enters the candidate set with no hand-edited worklist.
- **C — approval→reservation link.** Final `approve-card` calls
  `_approved_card_registry_precondition` (`farmctl.py:24769` → `:3386`) on the final approved
  path — the deterministic step that was missing.
- **Tests green (cited suite).**
  `python -m pytest -q tools/strategy_farm/tests/test_magic_allocation_precheck.py
  test_governed_magic_allocator.py test_mnt012_build_guards.py` → **28 passed in 6.29s**
  (worker reported 27; one additional guard test now present, still all green).

## Spot-checks against DB/repo (read-only)
- `ea_id_registry.csv`: 1508/1521/1593 ABSENT confirmed; 1612/1623 active with slug.
- QM5_1487 identity conflict CONFIRMED: registry slug `as-kda-defensive` vs approved card
  `raschke-3-10-oscillator-cross-h4` → correct fail-closed refusal, no auto-reservation.
- QM5_1426 approved card file now PRESENT in the live dir (worker measured it absent on
  08-22). Not a code defect — discovery reads the live dir dynamically, so this only shifts
  the card into the `card_target_symbols_missing_or_invalid` bucket rather than
  `approved card absent`. Still 0 build-ready without symbol scope.

## Assessment
Acceptance items A, B, C are implemented, wired, and verified. Item D (bounded live
backfill of the blocked cohort) is honestly and correctly NOT executed: 0/53 refusal-class
rows are safely allocatable because the cards lack explicit `target_symbols` scope or carry
identity conflicts (QM5_1487). Inventing card scope or rekeying an active identity is outside
this task and would breach the fail-closed registry contract — the worker's refusal is the
right behavior, not a defect. The remaining work is upstream card-governance / OWNER
adjudication, not a Codex code defect, so RECYCLE is not warranted.

## Verdict: APPROVED
Code deliverable is clean for merge/effect. Item D is parked as an OWNER card-governance
follow-up (restore/scope QM5_1426 + 51 scope-incomplete cards; adjudicate the QM5_1487
identity conflict) before any live bounded backfill can run.
