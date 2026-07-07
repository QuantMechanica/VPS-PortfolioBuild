# Farmctl Canonical Guards: Layer 1–3 (2026-07-03 Incident Response)

**Date**: 2026-07-03  
**Task**: 1a52d28d  
**Incident**: 2026-07-03T07:42Z — worktree-run hygiene pass false-invalidated 5167 work_items  
**Restored from**: farm_state_20260703T0855Z_pre_0742_restore.sqlite  

## Three Guard Layers

### Layer 1: FRAMEWORK_EAS_DIR Canonical Anchor (farmctl.py + repair.py)

**Problem**: `FRAMEWORK_EAS_DIR = REPO_ROOT / "framework" / "EAs"` resolved relative to the
running script. From a worktree, only ~225/2657 EA dirs are present (committed subset),
so R11 preflight check returned `ea_dir_missing` for ~92% of pending work_items.

**Fix**: 
- `farmctl.py`: `CANONICAL_REPO_ROOT = Path(os.environ.get("QM_CANONICAL_REPO_ROOT", r"C:\QM\repo"))`
  and `FRAMEWORK_EAS_DIR = CANONICAL_REPO_ROOT / "framework" / "EAs"`
- `repair.py`: New `CANONICAL_REPO_ROOT` / `CANONICAL_EAS_DIR` constants mirror farmctl.
  `_pending_work_item_artifact_failure` and `_ea_dir_for_id` now use `CANONICAL_EAS_DIR`.
- Override: `QM_CANONICAL_REPO_ROOT` env var for non-standard installations.

**First shipped**: commit `881d17ee6` (agents/board-advisor, 2026-07-03T14:44).

### Layer 2: Canonical Self-Check in farmctl.py main() (NEW this cycle)

**Problem**: Even with Layer 1 fixing the path, state-mutating commands run from worktrees
can trigger other side effects (stale relative paths in embedded references, etc.).

**Fix**: `_assert_canonical_checkout(command)` called before every state-mutating
subcommand (pump, repair, dispatch-tick, tick, backfill-work-items, enqueue-backtest,
approve-card, reject-card, seed-sources). Aborts with a loud stderr message and exit(1)
if the running script path != canonical_script path.

- Override: `QM_ALLOW_NONCANONICAL=1` env var
- State-mutating set: `_STATE_MUTATING_COMMANDS` (frozenset in farmctl.py)
- Read-only commands (health, status, pipeline, mt5-slots, events, etc.) are exempt.

### Layer 3: Mass-Invalidation Circuit Breaker in repair.py (NEW this cycle)

**Problem**: Without Layer 1 fix, R11 (`repair_pending_unclaimable_work_items`) could set
thousands of work_items to `status=failed, verdict=INVALID` in a single run.

**Fix**: Dry-run pass BEFORE any DB writes in R11:
1. Count how many pending work_items would fail the preflight check
2. If count > `MASS_INVALIDATION_THRESHOLD` (200), abort without committing
3. Write alarm to `D:/QM/strategy_farm/state/health_alarms.log` with class=mass_invalidation

- Override: `QM_ALLOW_NONCANONICAL=1` env var
- Does NOT stop other repair handlers (R1–R10, R12–R13) — only R11 is affected.
- Also provides `_write_mass_invalidation_alarm()` as a reusable hook.

## Additional Fix: c8051e18 Unblock

Task c8051e18 (QM5_12847 rescue) was blocked with note "run farmctl ONLY from C:/QM/repo".
With Layer 1 in place and Layer 2 enforcing this for all state-mutating runs, c8051e18
can proceed. Action: update c8051e18 BLOCKED → TODO with a note referencing this evidence.

## Verification

```python
# Layer 1: confirm FRAMEWORK_EAS_DIR points to canonical
python -c "import farmctl; print(farmctl.FRAMEWORK_EAS_DIR)"
# -> C:\QM\repo\framework\EAs

# Layer 2: confirm worktree run would abort (from claude-orchestration-3 worktree)
cd C:/QM/worktrees/claude-orchestration-3
python tools/strategy_farm/farmctl.py pump  # exits 1 with ABORT message
# from canonical: C:/QM/repo/tools/strategy_farm/farmctl.py pump -> runs normally

# Layer 3: confirm circuit breaker with simulated large INVALID count
# (would require manually setting CANONICAL_EAS_DIR to empty dir; not tested in prod)
```
