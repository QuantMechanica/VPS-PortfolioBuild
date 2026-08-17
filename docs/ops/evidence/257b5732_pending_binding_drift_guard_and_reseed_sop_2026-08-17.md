# Pending artifact-binding drift guard and governed disposition

- Router task: `257b5732-9be0-489b-bef8-f740cba3fe9b`
- Cycle time: 2026-08-17 UTC
- Branch: `agents/board-advisor`
- Scope: pending-row binding integrity only; no terminal was started or interrupted and no pipeline verdict is asserted.

## Detector

`health.py` now runs `pending_artifact_binding_drift` over every pending row that carries an MQ5, EX5, or setfile binding. Artifact paths are resolved the same way as worker preflight and raw SHA-256 bytes are compared to disk. MQ5 and setfile mismatches are additionally compared against LF- and CRLF-normalized variants:

- `LINE_ENDINGS_ONLY`: an expected hash equals a newline-only representation of the current bytes;
- `CONTENT_CHANGED`: no newline-only representation matches;
- `MISSING`: the bound artifact path is absent.

Any mismatch is a health `FAIL`. Output includes short row ID, EA, Q-phase, artifact role, classification, and whether an active hold already protects the row. This makes a freshly drifted row visible on the scheduled health/cockpit surface without a manual database query.

Production verification reproduced the authoritative census: nine `CONTENT_CHANGED` artifact mismatches across five pending rows. No newline-only residue remained after Claude's earlier 15-row remediation.

## Per-EA governed disposition

No old binding was patched. No successor was reported merely because it existed.

| EA / rows | Source edit and review evidence | Disposition | Why |
|---|---|---|---|
| QM5_20181: `824ca951`, `a0d6400a` | FTMO lifecycle/ownership series through `85db6178c`; router tasks `eabfd168` and `08e241e2` are PASSED | PARKED under the pre-existing non-restart `FTMO_BOOK3_Q02_ISOLATED_ONLY` hold | A conflicting stronger OWNER isolation hold already makes both rows unclaimable. It was not replaced. Current MQ5 and both setfiles are content-changed, so any future isolated run needs a fresh final build and bindings. |
| QM5_10649: `c2ce418a` | repair commit `92e590b3b`; Gemini implementation task `c162c123` APPROVED only after Codex re-review `224c77f8` APPROVED | PARKED under new non-restart `ARTIFACT_BINDING_CONTENT_CHANGED` hold | EX5, MQ5, and setfile all changed. The open Q04 row cannot authenticate the reviewed repair, and the generic append-only path refuses an open duplicate. |
| QM5_10203: `8abafefb` | SL/TP normalization commit `3d853ab6b`; originating task `9cb41afa` APPROVED | PARKED under new non-restart `ARTIFACT_BINDING_CONTENT_CHANGED` hold | MQ5 changed while the row remains bound to the old source. A compile plus governed open-row replacement is required. |
| QM5_1443: `48f156eb` | SL/TP normalization commit `3d853ab6b`; originating task `9cb41afa` APPROVED | PARKED under new non-restart `ARTIFACT_BINDING_CONTENT_CHANGED` hold | MQ5 changed while the row remains bound to the old source. A compile plus governed open-row replacement is required. |

The three new holds were applied one EA at a time with exact row/status/claim preconditions and read-back proof that each row is unclaimable. Database backups:

- `D:\QM\strategy_farm\state\backups\farm_state_before_governed_hold_20260817T090238Z.sqlite` (QM5_10649)
- `D:\QM\strategy_farm\state\backups\farm_state_before_governed_hold_20260817T090427Z.sqlite` (QM5_10203)
- `D:\QM\strategy_farm\state\backups\farm_state_before_governed_hold_20260817T090619Z.sqlite` (QM5_1443)

The two QM5_20181 rows were already unclaimable and no database mutation was made for them.

## Generic `*.set` / `*.mq5 -text` migration

The detector was installed first, as required. The generic attribute change was then evaluated but deliberately not applied in this cycle. Adding `*.set -text` and `*.mq5 -text` changes future checkout bytes for 19,188 setfiles and the EA source fleet. Existing Git blobs and current working-copy bytes are not uniformly identical, so a bare attribute commit could make a fresh checkout invalidate bindings even though today's working tree remains unchanged.

A safe migration therefore needs a dedicated clean-worktree maintenance stage that is excluded by this task's `no Factory OFF/ON` constraint:

1. capture the detector census immediately before the change;
2. add both generic `-text` rules;
3. renormalize and review the resulting large byte diff in isolation;
4. re-run the census from a fresh checkout;
5. keep the change only if no currently runnable pending row becomes drifted; and
6. commit the attribute/renormalization change separately from detector and row dispositions.

This is a specific safety blocker, not a judgement deferral: without a maintenance boundary, the requested migration can create the exact evidence corruption it is intended to prevent.

## Requeue/re-seed SOP acceptance

The canonical Strategy Farm runbook now requires:

1. compile exactly once and bind only after that final compile;
2. reproduce worker preflight on every created successor;
3. report `runnable/created`, not `created`;
4. count a mismatched successor as not runnable and park it;
5. permit newline-only rebinding only with normalized-byte proof; and
6. require per-EA review plus a governed append-only successor for any content change.

For this task the delivery count is `0/0` successors: five unsafe old rows were parked, not falsely reported as requeued.

## Verification

Focused detector and Q09 health tests pass, Python bytecode compilation passes, and `git diff --check` passes. Production read-only detector output after the holds remains a FAIL by design and marks every mismatch as `HELD`; the fault stays visible until governed successors replace the stale rows.
