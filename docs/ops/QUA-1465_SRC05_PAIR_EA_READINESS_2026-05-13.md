# QUA-1465 Pair-EA Infrastructure Readiness Check (SRC05 Stat-Arb)

Date: 2026-05-13
Owner: CTO
Scope: Confirm whether current pipeline infrastructure can execute SRC05 pair/stat-arb cards without violating V5 hard rules.

## Verdict

Status: BLOCKED (not ready for native two-leg pair execution).

Rationale: the active queue/scheduler contract is strictly single-symbol per job. SRC05 stat-arb cards require deterministic two-leg job semantics (leg A + leg B + spread state) that do not exist in the current dispatch schema.

## Evidence (code-level)

1. Queue schema enforces one `symbol` field only.
   - `framework/scripts/build_multi_ea_queue.py` requires fields `ea_id`, `phase`, `symbol`, `config_hash` and rejects non-`.DWX` symbols.
2. Scheduler validation enforces one `symbol` field only.
   - `framework/scripts/multi_ea_scheduler.py` validates only `ea_id`, `phase`, `symbol`, `config_hash`.
3. Scheduler launch command passes one symbol to smoke/phase runners.
   - `framework/scripts/multi_ea_scheduler.py` builds commands with a single `-Symbol` (P0/P1) or one-item `-Symbols @('...')` list.
4. Unit tests confirm the same single-symbol contract and `.DWX` suffix rule.
   - `framework/tests/unit/test_build_multi_ea_queue.py`
   - `framework/tests/unit/test_multi_ea_scheduler.py`

## Hard Rule Readiness Matrix (for SRC05)

1. Model 4 Every Real Tick: CONDITIONAL PASS.
   - Infra path supports existing Model 4 runs, but no pair-specific preflight ensures both legs are sourced/validated atomically.
2. `RISK_FIXED` + `RISK_PERCENT`: CONDITIONAL PASS.
   - Preserved at EA/framework level; infra does not yet enforce pair-level synchronization of risk mode across both legs.
3. `.DWX` discipline: PASS for single-symbol contract.
   - Existing validators enforce `.DWX` suffix on `symbol`.
4. Magic-number collision prevention: CONDITIONAL PASS.
   - Existing framework guard exists, but pair cards need explicit two-leg slot registry policy for deterministic leg allocation.
5. 4-module modularity boundary: NOT ASSESSED in this infra check.
   - This heartbeat evaluated pipeline orchestration readiness, not EA code structure.

## Immediate Gaps to Close

1. Extend queue contract to pair-aware jobs:
   - `symbol_a`, `symbol_b`, `pair_id`, `hedge_spec_hash` (or equivalent immutable spread config reference).
2. Extend scheduler state contract:
   - Track pair job atomicity and terminal reservation lifecycle for both legs.
3. Add pair preflight guard:
   - Verify both `.DWX` symbols, both setfile references, consistent risk mode, and deterministic magic-slot mapping before launch.
4. Add pair run artifact contract:
   - Persist per-leg execution evidence plus pair-level spread/trade synchronization evidence.
5. Add unit tests:
   - queue validation (pair fields, `.DWX` both legs), scheduler dispatch (atomic pair launch/defer), failure recovery semantics.

## Minimal Verification Run (this heartbeat)

Command executed:

```powershell
python -m unittest framework.tests.unit.test_build_multi_ea_queue framework.tests.unit.test_multi_ea_scheduler -v
```

Result: PASS (8 tests, 0 failures), confirming current single-symbol infrastructure is stable but not pair-native.

## Next Action

Create child implementation issues to deliver pair-aware queue + scheduler schema evolution and tests before any SRC05 stat-arb card enters pipeline smoke.
