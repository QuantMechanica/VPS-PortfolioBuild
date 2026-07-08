# QM5_10481 stale setfile canonicalization repair

Date: 2026-07-08
Agent branch: agents/board-advisor
Target: QM5_10481_mql5-exec-ao
Priority path: built-but-stuck diverse EA blocked at Q02 by infra

## Root cause

Q02 work item `d5952c11-319c-4501-8ca4-de6c69c3d60b` failed `ONINIT_FAILED` on `EURUSD.DWX`.

The work item resolved a stale worktree setfile:

`C:\QM\worktrees\claude-orchestration-3\framework\EAs\QM5_10481_mql5-exec-ao\sets\QM5_10481_mql5-exec-ao_EURUSD.DWX_M15_backtest.set`

That stale setfile has:

`qm_magic_slot_offset=14`

The active registry row is:

`10481,mql5-exec-ao,0,EURUSD.DWX,104810000,2026-05-28,Codex,active`

The canonical repo setfile already has:

`qm_magic_slot_offset=0`

So the Q02 infra failure was caused by dispatching a stale worktree setfile whose symbol slot no longer matched the active magic registry.

## Repair

`tools/strategy_farm/farmctl.py` now canonicalizes stale absolute worktree setfile paths before launching Q02/Q03+ work items:

- Only absolute paths containing a `worktrees` path component are considered.
- Only paths under an EA `sets` directory are considered.
- The EA directory must match the work item EA id prefix.
- The replacement is used only when a same-name canonical repo setfile exists under `C:\QM\repo\framework\EAs`.
- When a work item launches with the canonical replacement, `work_items.setfile_path` and payload `setfile_path` are updated to the effective canonical path.

This prevents future dispatch from relaunching stale worktree copies for same-name canonical setfiles, while leaving unmatched exploration/ablation files untouched.

## Queue state

Farm DB event recorded:

`events.id=226265`, event `infra_repair_stale_setfile_canonicalization_ready`, entity `QM5_10481`.

Current `QM5_10481` Q02 pending rows:

- total pending Q02 rows: 25
- canonical repo setfile rows: 24
- stale worktree rows: 1

The remaining stale row is an ablation setfile without a same-name canonical repo replacement, so it was not rewritten.

## Verification

- `framework/scripts/build_check.ps1 -EALabel QM5_10481_mql5-exec-ao -Strict -SkipCompile`: PASS, 0 failures, 0 warnings. Report: `D:\QM\reports\framework\21\build_check_20260708_072329.json`.
- Registry/setfile slot audit: 37 active registry rows, 0 slot errors across canonical repo setfiles.
- `python -m py_compile tools/strategy_farm/farmctl.py`: PASS.
- `python -m pytest tools/strategy_farm/tests/test_setfile_canonicalization.py tools/strategy_farm/tests/test_enqueue_skips_missing_setfiles.py tools/strategy_farm/tests/test_unenqueued_ea_filter.py`: 6 passed.
- No T_Live, AutoTrading, or portfolio gate files were touched.
- No backtest was launched in this unit of work.
