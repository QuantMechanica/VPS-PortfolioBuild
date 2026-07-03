# Canonical-Checkout Guard — Layers 1-3 Implementation Evidence

**Task**: 1a52d28d — URGENT GUARD: canonical-checkout self-check + mass-invalidation circuit breaker
**Date**: 2026-07-03
**Commit**: f13f40efe

## Background

Incident 2026-07-03 07:42: `repair_pending_unclaimable_work_items` ran from the agents/board-advisor
worktree, which carries only ~225 of 2657 EA dirs. Script-relative FRAMEWORK_EAS_DIR resolved
to the worktree torso, false-flagging the remaining ~2432 EA dirs as missing → 5167 work_items
bulk-invalidated. Restored from farm_state_20260703T0855Z_pre_0742_restore.sqlite.

## Changes

### Layer 1 — FRAMEWORK_EAS_DIR anchored to canonical checkout

`farmctl.py` lines 36-43:
- Added `CANONICAL_REPO_ROOT = Path(os.environ.get("QM_CANONICAL_REPO_ROOT", r"C:\QM\repo"))`
- `FRAMEWORK_EAS_DIR = CANONICAL_REPO_ROOT / "framework" / "EAs"` (was `REPO_ROOT / ...`)
- All 6 inline `REPO_ROOT / "framework" / "EAs"` occurrences inside farmctl.py replaced with `FRAMEWORK_EAS_DIR`

`repair.py`: Both direct uses replaced with `farmctl.FRAMEWORK_EAS_DIR`.

### Layer 2 — Canonical self-check hard-abort

`_require_canonical_checkout()` added to farmctl.py after constants block.
- Checks `Path(__file__).resolve()` is under `C:\QM\repo`
- `sys.exit(1)` with loud message if not
- Wired into: `pump`, `repair`, `backfill-work-items`, `enqueue-backtest` CLI handlers
- Bypass: `QM_ALLOW_NONCANONICAL=1`

### Layer 3 — Mass-invalidation circuit breaker

`_check_mass_invalidation_circuit_breaker(conn, count, context)` added to farmctl.py.
- Limit: 200 items per run
- Writes to `D:/QM/strategy_farm/state/health_alarms.log` class=mass_invalidation
- Exits 1 before any mutations
- Wired into: `repair_pending_unclaimable_work_items` (R11, the exact handler that caused the incident)
- Bypass: `QM_ALLOW_NONCANONICAL=1`

## Test Results

```
tests/test_farmctl_canonical_guard.py — 7/7 PASSED
  test_layer1_framework_eas_dir_uses_canonical     PASSED
  test_layer2_canonical_check_passes_for_canonical_path  PASSED
  test_layer2_canonical_check_aborts_for_worktree  PASSED
  test_layer2_canonical_check_env_bypass           PASSED
  test_layer3_circuit_breaker_below_limit          PASSED
  test_layer3_circuit_breaker_above_limit          PASSED
  test_layer3_circuit_breaker_env_bypass           PASSED
```

## Task c8051e18 (12847 rescue)

Task c8051e18 was blocked pending this fix. Now that Layer 2 is live (hard-abort if not canonical),
it is safe to unblock: any future farmctl run from a worktree will abort immediately with a clear
error rather than false-invalidating items. Recommendation: unblock c8051e18, noting that all
farmctl repair/pump commands must be run from C:/QM/repo.
