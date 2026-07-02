# 85582fe4 Calendar-Cadence Primitive Migration

Task: `85582fe4-2e2b-4499-92f0-cbde24346218`

Date: 2026-07-01

Implementation checkout: `C:\QM\repo`

Note: the orchestration worktree `C:\QM\worktrees\codex-orchestration-1` only contained `QM5_10009`; `QM5_1556` and `QM5_12852` were present in the live factory checkout, so the EA edits and verification were performed in `C:\QM\repo`.

## Changes

### `QM5_1556_aa-zak-mom12`

File: `framework/EAs/QM5_1556_aa-zak-mom12/QM5_1556_aa-zak-mom12.mq5`

Lines changed: `+8 / -30`

- Removed local `Strategy_MonthKey`, `Strategy_IsFirstD1BarOfMonth`, and raw D1 `iTime(...)` monthly cadence logic.
- Replaced monthly rebalance key source with `QM_CalendarPeriodKey(PERIOD_MN1)`.
- Kept the EA-owned `g_last_entry_rebalance_key` / `g_last_exit_rebalance_key` once-per-period comparisons.
- Fixed the ordering bug: `const bool nb = QM_IsNewBar();` is consumed once and now fronts equity streaming, management, exit evaluation, and entry evaluation.

### `QM5_10009_rw-fx-cointeg-bb`

File: `framework/EAs/QM5_10009_rw-fx-cointeg-bb/QM5_10009_rw-fx-cointeg-bb.mq5`

Lines changed: `+8 / -11`

- Removed local `MonthKey` and raw D1 `iTime(...)` monthly hedge-freeze key.
- Replaced the hedge-freeze key with `QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1)`.
- Removed raw D1 `iTime(...)` timestamps from basket max-hold accounting; the existing in-memory entry timestamp now uses `TimeCurrent()`.
- Left the static hedge weights `g_weights[3] = {1.0, -1.0, -1.0}` unchanged.

### `QM5_12852_wti-may-prem`

File: `framework/EAs/QM5_12852_wti-may-prem/QM5_12852_wti-may-prem.mq5`

Lines changed: `+9 / -16`

- Removed local current-bar month helper and raw D1 `iTime(...)` calendar gates.
- Replaced current month checks with `QM_CalendarPeriodKey(PERIOD_MN1)`.
- Replaced current day entry/exit keys with `QM_CalendarPeriodKey(PERIOD_D1)`.
- Kept position-open time handling for the existing one-day stale guard and max-hold timer.

## Verification

Forbidden calendar grep:

```text
rg -n "\biTime\s*\(|perf-allowed" <three target .mq5 files>
result: no matches
```

Strict compile:

```text
powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EALabel QM5_1556_aa-zak-mom12
compile_one.result=PASS
compile_one.errors=0
compile_one.warnings=0
compile_one.log=C:\QM\repo\framework\build\compile\20260701_205118\QM5_1556_aa-zak-mom12.compile.log
compile_one.ex5=C:\QM\repo\framework\EAs\QM5_1556_aa-zak-mom12\QM5_1556_aa-zak-mom12.ex5

powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EALabel QM5_10009_rw-fx-cointeg-bb
compile_one.result=PASS
compile_one.errors=0
compile_one.warnings=0
compile_one.log=C:\QM\repo\framework\build\compile\20260701_205129\QM5_10009_rw-fx-cointeg-bb.compile.log
compile_one.ex5=C:\QM\repo\framework\EAs\QM5_10009_rw-fx-cointeg-bb\QM5_10009_rw-fx-cointeg-bb.ex5

powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EALabel QM5_12852_wti-may-prem
compile_one.result=PASS
compile_one.errors=0
compile_one.warnings=0
compile_one.log=C:\QM\repo\framework\build\compile\20260701_205142\QM5_12852_wti-may-prem.compile.log
compile_one.ex5=C:\QM\repo\framework\EAs\QM5_12852_wti-may-prem\QM5_12852_wti-may-prem.ex5
```

Strict build check / framework corset:

```text
QM5_1556_aa-zak-mom12:
build_check.result=PASS
build_check.failures=0
build_check.report=D:\QM\reports\framework\21\build_check_20260701_205234.json

QM5_10009_rw-fx-cointeg-bb:
build_check.result=PASS
build_check.failures=0
build_check.report=D:\QM\reports\framework\21\build_check_20260701_205251.json

QM5_12852_wti-may-prem:
build_check.result=PASS
build_check.failures=0
build_check.report=D:\QM\reports\framework\21\build_check_20260701_205308.json
```

Compiled `.ex5` timestamps:

```text
C:\QM\repo\framework\EAs\QM5_1556_aa-zak-mom12\QM5_1556_aa-zak-mom12.ex5        2026-07-01T20:52:38Z
C:\QM\repo\framework\EAs\QM5_10009_rw-fx-cointeg-bb\QM5_10009_rw-fx-cointeg-bb.ex5 2026-07-01T20:52:56Z
C:\QM\repo\framework\EAs\QM5_12852_wti-may-prem\QM5_12852_wti-may-prem.ex5      2026-07-01T20:53:14Z
```

Verdict: `PASS - calendar cadence migrated to QM_CalendarPeriodKey primitives; strict compile 0/0 for all three; build_check PASS/failures=0 for all three.`
