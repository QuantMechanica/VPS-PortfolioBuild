# Evidence: Task 1a52d28d — Canonical-Checkout Guard (Layers 1-2-3)

**Task:** URGENT GUARD: canonical-checkout self-check + mass-invalidation circuit breaker in farmctl  
**Date:** 2026-07-03  
**Session:** agents/claude-orchestration-2  
**Status:** REVIEW (implementation complete, tests pass)

---

## Incident Context

2026-07-03 07:42: farmctl repair run from a worktree resolved `FRAMEWORK_EAS_DIR`
relative to the script location. Worktrees carry ~225 of 2657 canonical EA dirs → 
R11 handler (`repair_pending_unclaimable_work_items`) false-invalidated **5167** 
pending work_items with `ea_dir_missing`. All restored from backup. Evidence:
`D:/QM/strategy_farm/artifacts/ops/incident_mass_invalidation_restore_2026-07-03.json`

Root cause: `FRAMEWORK_EAS_DIR = REPO_ROOT / "framework" / "EAs"` where `REPO_ROOT`
is script-relative → in a worktree, this resolves the worktree subset, not the
canonical EA tree.

---

## Layer 1: CANONICAL_REPO_ROOT anchor

**Files:** `tools/strategy_farm/farmctl.py`, `tools/strategy_farm/repair.py`

### farmctl.py
```python
CANONICAL_REPO_ROOT = Path(os.environ.get("QM_CANONICAL_REPO_ROOT", r"C:\QM\repo"))
FRAMEWORK_EAS_DIR = CANONICAL_REPO_ROOT / "framework" / "EAs"
```
Replaced the former `FRAMEWORK_EAS_DIR = REPO_ROOT / "framework" / "EAs"`.  
`QM_CANONICAL_REPO_ROOT` env override available for deliberate tests.

### repair.py
- Added `CANONICAL_REPO_ROOT = Path(os.environ.get("QM_CANONICAL_REPO_ROOT", r"C:\QM\repo"))`
- `_pending_work_item_artifact_failure`: `ea_root` now uses `CANONICAL_REPO_ROOT`
- `_ea_dir_for_id`: EA glob now uses `CANONICAL_REPO_ROOT`

Note: Layer 1 was also implemented in commit 881d17ee6 on `agents/board-advisor` 
(the canonical runtime). This task adds it to `agents/claude-orchestration-2` for 
the Codex review + main merge path.

---

## Layer 2: Canonical self-check hard-abort

**File:** `tools/strategy_farm/farmctl.py`

Added `_CANONICAL_CHECKOUT = Path(r"C:\QM\repo")` constant and  
`_assert_canonical_checkout()` function:

```python
def _assert_canonical_checkout() -> None:
    if os.environ.get("QM_ALLOW_NONCANONICAL") == "1":
        return
    try:
        Path(__file__).resolve().relative_to(_CANONICAL_CHECKOUT.resolve())
    except ValueError:
        print("[FATAL] farmctl state-mutating command REFUSED. ...", file=sys.stderr)
        sys.exit(1)
```

Called at the start of `pump` and `repair` dispatch in `main()`:
- Line: `elif args.command == "pump": _assert_canonical_checkout(); print_json(pump(root))`
- Line: `elif args.command == "repair": _assert_canonical_checkout(); ...`

Override: `QM_ALLOW_NONCANONICAL=1` for deliberate test scenarios.

---

## Layer 3: Mass-invalidation circuit breaker

**File:** `tools/strategy_farm/repair.py`

`repair_pending_unclaimable_work_items` now pre-scans all pending rows with a single
pass (avoiding double-call of `_pending_work_item_artifact_failure`), then:

- If `len(failing) > _R11_CIRCUIT_BREAKER_LIMIT (200)`:
  - Writes alarm to `D:/QM/strategy_farm/state/health_alarms.log`:  
    `{timestamp}\tmass_invalidation\t{count}\t{detail}`
  - Returns `[{"action": "ABORTED", "target": "circuit_breaker", ...}]`
  - **No DB updates made**
- If below limit: proceeds normally with the pre-computed `(row, failure)` pairs

---

## Tests

**File:** `tools/strategy_farm/tests/test_canonical_checkout_guard.py` (NEW)

9 tests, all pass:
```
Layer1CanonicalRootTests::test_env_override_respected         PASSED
Layer1CanonicalRootTests::test_framework_eas_dir_not_script_relative PASSED
Layer1CanonicalRootTests::test_framework_eas_dir_uses_canonical_root PASSED
Layer1CanonicalRootTests::test_repair_ea_root_uses_canonical  PASSED
Layer2CanonicalSelfCheckTests::test_aborts_when_in_worktree   PASSED
Layer2CanonicalSelfCheckTests::test_noncanonical_override_bypasses_check PASSED
Layer2CanonicalSelfCheckTests::test_passes_when_under_canonical PASSED
Layer3CircuitBreakerTests::test_circuit_breaker_does_not_fire_at_limit PASSED
Layer3CircuitBreakerTests::test_circuit_breaker_fires_above_limit PASSED
```

`py_compile` verification:
```
python -m py_compile tools/strategy_farm/farmctl.py  → OK
python -m py_compile tools/strategy_farm/repair.py   → OK
```

---

## Task c8051e18 Status

Task c8051e18 (12847 rescue) is already in state APPROVED — not blocked. No unblock
action needed.

---

## Codex Review Notes

- Only commit `tools/strategy_farm/farmctl.py`, `tools/strategy_farm/repair.py`, and
  `tools/strategy_farm/tests/test_canonical_checkout_guard.py`
- Worktree has unrelated dirty files (QM5_10069 sets, QM5_10070 EA, etc.) — exclude
- After review, merge to `main` so all worktrees inherit the canonical anchor
- The `_assert_canonical_checkout()` check uses `Path(__file__)` which is the farmctl
  script path, not the CWD — a symlink or scheduled task that points to the worktree
  copy would still trip the guard correctly
