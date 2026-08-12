# Custom-history copy-on-claim amendment — implementation evidence

- Router task: `a83d3b5c-165d-4f45-8178-ba8664a93140`
- Priority: `95`
- Task state at handoff: `REVIEW`
- Evidence recorded: `2026-08-09T15:57:55Z`
- Implementation status: `READY_FOR_CLAUDE_REVIEW`
- Implementation commit: `6f0658b280690af72b6e5fa57b9ca30de7eb54d8`
- Canonical branch: `agents/board-advisor`
- OWNER decision: `decisions/2026-08-09_custom_history_isolation_amendment_copy_on_claim.md`
- Decision commit: `6ea32c263`
- Approved window: `custom_history_variant_a_20260809`

## Scope delivered

The OWNER-approved Variant A amendment is implemented without changing the
active ramp, activation record, terminal processes, or AutoTrading state.

1. `terminal_worker.py` now privatizes the claimed terminal's declared host,
   conversion, and basket Custom-history archives after the pre-dispatch gate
   and before runner spawn.
2. `custom_history_copy_on_claim.py` performs a same-directory temporary copy,
   verifies size and manifest SHA-256, atomically replaces the terminal path,
   and proves the resulting inode is terminal-private with link count one.
   Re-entry verifies an existing private copy and makes no further mutation;
   missing or mismatched archives fail closed.
3. The isolation audit accepts either the immutable family hardlink or a
   manifest-SHA-matching terminal-private inode. Family link minima are derived
   dynamically, private files are hashed even by the dispatch-fast audit, and
   private inode aliases across terminals are rejected.
4. `custom_history_acl.ps1` Apply/Verify removes and refuses legacy runner
   write/delete deny rules while retaining manifest and receipt integrity.
5. `run_smoke.ps1` invokes the Custom-history gate and acquires a farm terminal
   reservation before resolving the terminal executable or launching it. Under active
   isolation, factory smoke requires the worker-bound work-item identity so the
   copy-on-claim proof cannot be bypassed. The script releases only its own
   reservation.
6. The Sunday runbook now states the mixed-topology contract, gate/reservation
   sequence, decision/window binding, and the Claude-only restoration,
   re-audit, recycle, and ramp handoff.

## Focused verification

All task-owned verification passed against implementation commit `6f0658b28`:

- Python syntax compilation: PASS for every changed Python module and test.
- PowerShell AST parsing: PASS for `run_smoke.ps1` and
  `custom_history_acl.ps1`.
- Copy/audit/gate/worker regression set: `38 passed in 3.26s`.
- Atomic claim, phase-runner lineage, and job containment set:
  `77 passed in 38.87s`.
- `Test-RunSmokeCustomHistoryAdmission.ps1`: PASS.
- `Test-RunSmokeTerminalRunningGuard.ps1`: PASS.
- `Test-NewsCalendarGate.ps1`: PASS.
- `git diff --check`: PASS (line-ending notices only).

The focused Python set covered successful copy and atomic replacement,
manifest mismatch refusal, idempotent private verification, declared
host/conversion/basket scope, mixed family/private audits, private hash drift,
cross-terminal private inode aliases, pre-gate/copy/post-gate/launch ordering,
ramp hold refusal, active-claim binding, reservation races, release ownership,
and direct-smoke refusal while isolation is active.

`ruff` was not available in this checkout's Python environment; the invocation
returned `No module named ruff`. This does not replace or weaken the passing
syntax, focused regression, PowerShell, or diff checks above.

## Live read-only gate observation

No restoration or activation mutation was performed during implementation.
No terminal was launched, stopped, or interrupted.

- T5: `PASS_ISOLATED`, `admission_allowed=false`, reason
  `custom_history_ramp_hold`. This correctly enforces the active one-terminal
  ramp.
- T1: `FAIL_CLOSED`; audit SHA-256
  `499979156209e7362e47c996dd7da51a599d358e0987fae1a23b201c64c1bc77`.
  The audit reports 108 missing T1 `XAUUSD.DWX` archive paths (9 history files
  plus 99 monthly tick files), represented by 108
  `MANIFEST_ARCHIVE_FILE_MISSING` and 108
  `TERMINAL_MANIFEST_INCOMPLETE` findings.
- Activation SHA-256:
  `b508a8981cf10fd7b81ef9e97ba07ce60839e259b05df46d3878d608a77222e9`.
- Manifest SHA-256:
  `fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`.
- Containment remains engaged. The implementation therefore makes no live
  admission, restoration, or pipeline verdict claim.

The task context's earlier restored `11/11` observation is no longer true for
the current T1 filesystem. The new gate detects that drift and remains
fail-closed, as required.

## Claude review handoff

Claude must review commit `6f0658b28`, then—within OWNER authority and the
approved window—perform any required T1 restoration, dual fresh-process full
re-audit, worker recycle, containment decision, and controlled ramp action.
Those operations were intentionally not self-approved by Codex.

Short router verdict:
`IMPLEMENTED_TESTED; LIVE_REAUDIT_HELD_T1_XAU_108_MISSING`
