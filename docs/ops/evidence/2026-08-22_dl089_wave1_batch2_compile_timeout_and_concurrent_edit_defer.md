# DL-089 Wave 1 batch 2 — compile timeout root-caused + fixed; classifier work deferred (concurrent edit)

Router task: `05084e43-581e-40e3-9f0c-1c5b002849de` (claude, ops_issue, priority 88)
Context evidence: `docs/ops/evidence/2026-08-22_execution_contract_requal_flag_crosscheck.md`,
`docs/ops/evidence/2026-08-21_dl089_wave1_batch1.md`,
`docs/ops/evidence/2026-08-21_dl089_wave1_batch2_partial.md`,
`docs/ops/evidence/2026-08-22_compile_ea_worker_rollout_1fb9943f.md`

## Part B — compile_one.ps1 120s timeout: root-caused and fixed

`D:/QM/reports/compile/*/result.json` telemetry (281 historical rows) shows the
120s Python-side `subprocess.run(..., timeout=120)` budget in
`tools/strategy_farm/compile_ea.py` had essentially no headroom under real host
load: on 2026-08-21, two genuine `COMPILED` runs on a busy host already took
101.52s (`QM5_20096`) and 113.74s (`QM5_12354`) minutes before `QM5_10919`
(DL-089 batch 2, first attempt) was killed at exactly 120.41s with
`compile_one.ps1 timeout after 120s` and no verdict. Compiles immediately
before/after that spike were back in the 20-50s range — a transient
CPU-contention spike, not a structural defect in `compile_one.ps1` (which uses
`Start-Process -Wait` with no internal timeout of its own; the 120s ceiling is
purely the Python wrapper's).

Fix applied in `tools/strategy_farm/compile_ea.py`: replaced the bare
`timeout=120` literal (two call sites: the `subprocess.run` call and the
timeout-failure reason string) with a named `COMPILE_ONE_TIMEOUT_SECONDS = 300`
constant, documented inline with the telemetry basis above. 300s keeps ~2.6x
margin over the worst observed genuine compile on a loaded host while still
bounding a truly hung MetaEditor process. This is the only change in the
commit; blast radius is exactly the compile-gate timeout used at Q02 dispatch
(`farmctl.py:_compile_gate_check`) and any `compile_ea.py` invocation.

Verification: `python -m pytest tools/strategy_farm/tests/test_build_guardrails.py
tools/strategy_farm/tests/test_compile_work_items.py -q` — 29 passed (no test
pins the old 120s literal). `python -m py_compile tools/strategy_farm/compile_ea.py`
— clean.

## A second, orthogonal blocker found while verifying the fix

Re-running `python tools/strategy_farm/compile_ea.py --ea-id 10919 --force`
after the timeout fix did **not** reproduce a timeout — it failed fast (3.71s)
with `reason_class=INCLUDE_MIRROR_REFUSED`. Reading
`tools/strategy_farm/include_mirror.py:validate_compile_contract`: any
ad-hoc `compile_ea.py --force` invocation is now categorically refused
(`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`) whenever any `terminal64.exe` process is
alive and no `pipeline_work_item_id`/claimed terminal is supplied — which is
always true on this 24/7 factory (`farmctl.py mt5-slots` showed all 10
terminals occupied at check time). The guard's own inline comment references a
"2026-08-22 ceremony" hardening this exact refusal. In other words: the
ad-hoc `--force` path that produced DL-089 batch 1's five EAs on 2026-08-21 has
since been deliberately closed off; the **only** sanctioned path now is the
governed `COMPILE_EA` work-item queue (`pipeline_work_item_id` + claimed
T1-T10 terminal), which is exactly what this task's Part A (classifier
force-rebuild extension) targets. This confirms the task's own instructions
were correctly scoped — no attempt was made to bypass this guard (that would
risk exactly the kind of live-terminal interruption the Hard Rules forbid).

## Part A — classifier force-rebuild extension: deferred, not duplicated

While investigating Part A, `tools/strategy_farm/compile_work_items.py` and
its test file `tools/strategy_farm/tests/test_compile_work_items.py` were
found **already modified in the working tree** with a complete,
independently-tested implementation of exactly this requirement:
`DL089_FORCE_REBUILD_OWNER_REFERENCE` / `DL089_FORCE_REBUILD_EA_IDS` bound to
`owner_priority_tracks.json`, a `dl089_force_rebuild_allowlist()` helper
requiring **both** the hardcoded id list and a live matching registry row
(fails closed if either is missing/removed), wired into `classify_candidate`,
`enqueue_compile_eas`, and `run_compile_work_item`, plus three new tests
covering the bypass, the fail-closed-without-registry-row case, and that
structural guards (e.g. a retired magic row) are never waived. File mtimes
(`compile_work_items.py` 09:59-10:00 local, checked at 10:00:51 local — under
a minute old) confirm this is a **live, currently-active concurrent edit**,
not stale orphaned work from an earlier interrupted cycle.

Per this task's own collision guidance ("if the lease is live, skip/defer
instead of duplicating the task"), no changes were made to
`compile_work_items.py` or its test file. Two now-redundant additions of my
own (an unused generic `owner_priority_force_rebuild_ea_ids` helper) were
written and then reverted before this evidence was recorded, to avoid leaving
dead code next to the live implementation; `git diff` for that file now shows
only the concurrent process's changes. `pytest
tools/strategy_farm/tests/test_compile_work_items.py -q` passes 12/12 against
that in-flight state.

## Disposition

- **Part B (timeout): DONE.** Committed on `agents/board-advisor` with an
  explicit pathspec for `tools/strategy_farm/compile_ea.py` only.
- **Part A (classifier): IN FLIGHT by another concurrent process**, not
  duplicated here. Whoever owns that edit should commit it, then release+enqueue
  the 16 remaining Wave-1 EAs through the governed `COMPILE_EA` path once
  `docs/ops/evidence/2026-08-22_compile_ea_worker_rollout_1fb9943f.md`'s
  capacity constraint (all resident workers busy) clears.
- Router task `05084e43` is **left `IN_PROGRESS`**, not moved to `REVIEW` —
  its Part A is not this artifact's work to claim, and closing it now would
  misrepresent a still-active concurrent edit as finished/reviewed.

## Guardrails observed

No T_Live state, AutoTrading setting, terminal process, or active backtest was
started, stopped, or interrupted. The one live compile attempt
(`QM5_10919 --force`) was refused fail-closed by the factory's own guard before
touching MetaEditor or any terminal. No pipeline/gate verdict was asserted or
inferred.
