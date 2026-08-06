# Claude review spawn-gate repair — 2026-08-06

Router task: `f79fb07f-998c-431c-b9bf-813e4245c6ee`

Scope: deterministic pump / Claude final-EA-review automation only

Verdict: `REPAIRED_AND_REAL_SPAWN_PROVEN`

## Incident

`claude_review_starved` reported ten builds awaiting final review and no review
spawn in four hours. The surrounding automation was alive:

- `QM_StrategyFarm_ClaudeOrchestration_15min` ran as `SYSTEM`, result `0`, and
  refreshed `lane_claude_heartbeat.json` at 14:45 local.
- `QM_StrategyFarm_Pump_5min` ran as `SYSTEM`, result `0`.
- `CLAUDE_DISABLED.flag` was absent; the router exposed Claude as enabled with
  `max_parallel=3`; quota state was below pace and did not block Claude.
- No Claude orchestration lock survived the host crash. The only orchestration
  lock present during diagnosis belonged to the active Codex lane.

The standalone Claude orchestration lane was not the review spawner. Its
`claude_work_available()` guard only covers `agent_tasks`. Final EA reviews are
spawned directly by pump section 5c in `farmctl.py`.

## Root cause

Eight consecutive completed pump logs from 11:16:44 through 12:46:46 UTC
showed `claude_active_before=1`, `claude_review_slots=2`, and the same two failed
decisions every cycle:

1. `d186904d-71fd-4080-a126-4bde58836da0` / `QM5_13033` was the oldest selected
   build, but its payload had no `codex_result`; prompt rendering failed.
2. `3c6339bd-59c7-479f-891f-085483113394` / `QM5_20182` was build generation 1.
   It had a generation-0 auto-review (`6a72a077-...`), which the selector
   correctly did not treat as current, but `_spawn_claude_for_review()` used a
   generation-blind JSON `LIKE` check and rejected it as already reviewed.

The SQL applied `LIMIT 2` before renderability was established. Both free slots
were therefore consumed by permanently non-spawnable rows, hiding nine
render-ready builds. The primary decision field also reported the first failed
attempt even if a later attempt succeeded.

Primary pre-fix evidence:

- `D:/QM/strategy_farm/logs/pump_task_20260806T123938Z.log`
- identical failure pair also appears in `T122837Z`, `T121753Z`, `T120339Z`,
  `T113236Z`, `T112020Z`, and `T110327Z` logs.

## Repair

Operational commit: `8e56e80ea798f007ea266fc45aa13c41f9c2249c`

- Candidate selection now parses valid top-level JSON objects, matches exact
  build generations, requires a non-empty object `codex_result`, and applies
  the oldest-first limit only after those predicates.
- Claude and Codex final-review idempotence now share an exact-generation,
  formatting-independent lookup.
- Pump scans a bounded four-candidates-per-slot window and continues after a
  failed attempt until its successful-spawn budget is filled.
- Pump logs `claude_review_candidate_ids` and `claude_review_scan_limit` and
  exposes the first successful spawn as the primary result.

Bound source hashes after the commit:

- `tools/strategy_farm/farmctl.py`:
  `D10BA09BA1881CDB95EE10A87D62ABC0DE124389067EFF806BE6A545592BE1A3`
- `tools/strategy_farm/tests/test_claude_review_candidate_selection.py`:
  `E507E8E3E51590CA5C789A1174BC5C18241B6A7B0A38EA0E962A90DC5ADE1135`

## Verification

Focused tests:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_claude_review_candidate_selection.py \
  tools/strategy_farm/tests/test_health_starvation.py \
  tools/strategy_farm/tests/test_review_repair.py
20 passed

python -m pytest -q \
  tools/strategy_farm/tests/test_auto_build_routing.py \
  tools/strategy_farm/tests/test_factory_off_build_interlock.py \
  tools/strategy_farm/tests/test_unenqueued_ea_filter.py
39 passed, 12 subtests passed
```

The patched selector was then run read-only against the live database and
returned nine render-ready candidates, beginning with current generations of
`QM5_20182` and `QM5_20184`; it excluded the unrenderable `QM5_13033` row.

## Real scheduler-owned spawn proof

No manual `claude`, Codex, pump, or scheduled-task kick was issued. The already
scheduled pump child (`python ... farmctl.py pump`, PID 17116, created 15:02:54
local) loaded the canonical repair and spawned:

| Created local | Claude PID | Review task | Build / generation | Live log |
|---|---:|---|---|---|
| 15:04:55 | 15160 | `e7223e29-5a7c-45ad-b7e7-99c44861305a` | `3c6339bd-59c7-479f-891f-085483113394` / 1 (`QM5_20182`) | `claude_review_e7223e29-5a7c-45ad-b7e7-99c44861305a.live.log` |
| 15:05:19 | 8176 | `ccd48f43-ec78-44bb-8f16-26ce43929cdd` | `1818ec0b-73e9-4ce0-b474-bffe559d474c` / 1 (`QM5_20184`) | `claude_review_ccd48f43-ec78-44bb-8f16-26ce43929cdd.live.log` |

Both process trees were authenticated as
`farmctl.py pump -> cmd.exe /c claude.cmd -p -> claude.exe`, with the expected
`--permission-mode bypassPermissions` and governed `C:/QM/repo`,
`D:/QM/strategy_farm`, and `D:/QM/reports` directories. Both `ea_review` rows
were `pending` when captured. This proves spawn only; it does not assert or
pre-empt either independent Claude verdict.

## Safety and state

- No `T_Live`, AutoTrading, deploy manifest, or live-book state was touched.
- No `terminal64.exe` was launched or interrupted.
- No factory work item or pipeline verdict was mutated by this repair.
- Existing user changes in both canonical and `main` worktrees were preserved;
  only the two code/test paths above and this evidence document were scoped.
- Builder/approver separation remains intact: the new review tasks stay pending
  for Claude output and are not self-approved or advanced by Codex.
