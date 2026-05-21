# Deep Audit 2026-05-20

Scope: repo, strategy_farm DB, scheduled tasks, pipeline runners, agent routing,
guardrails, dashboards, tests, and live process state. This is a cascading audit:
Layer 1 inventories the system, Layer 2 drills into active subsystems, Layer 3
records concrete defects and remediations.

## Layer 1 Inventory

- Repo files: 11,348 tracked/untracked filesystem entries visible via `rg --files`.
- Main heavy areas:
  - `framework/`: 7,139 files, including 188 EA directories, 4,797 setfiles, 191 mq5 files, 188 ex5 files.
  - `docs/ops/`: 5,869 files, mostly markdown/json evidence.
  - `tools/strategy_farm/`: 109 files.
  - `D:/QM/strategy_farm/state/farm_state.sqlite`: 20.8 MB.
- Scheduled task split:
  - Active StrategyFarm task set is healthy: `AgentRouter_5min`, `Cockpit_2min`,
    `Dashboard_Hourly`, `GmailAlarm_Hourly`, `Health_15min`, `MorningBrief_0700`,
    `Pump_5min`, `QuotaReceiver`, `Repair_Hourly`, `TerminalWorkers_AT_STARTUP`,
    `Tick_5min`.
  - Older Paperclip/QM task family is mostly disabled. Treat it as legacy unless
    explicitly re-enabled by OWNER.
- Live process guardrail:
  - No Claude process running.
  - `D:/QM/strategy_farm/CLAUDE_DISABLED.flag` present:
    `OWNER 2026-05-19: Claude token burn disabled. Revisit Friday 2026-05-22 only after quota/OWNER confirmation.`
  - Codex and Gemini processes are active.

## Layer 2 Pipeline State

Health after remediation:

- Overall: `WARN`
- `FAIL`: 0
- `WARN`: 1 (`codex_bridge_heartbeat`; legacy bridge stale, direct pump Codex active)
- `OK`: 18
- MT5: 10/10 terminal worker daemons alive.
- Work queue: about 251 pending, 10 active at the last health run.
- Quota snapshot: OK, Codex fresh, Claude ignored because disabled.

Work item shape:

- `work_items`: 5,365 rows.
- PASS evidence paths exist for all sampled PASS rows.
- Negative evidence remains weaker: 2,889 done/failed rows have no `evidence_path`.
  Most are historical `summary_missing_retries_exhausted`, history-skip invalidations,
  active timeouts, and prior cleanup invalidations.
- Highest current real chain lead remains `QM5_1056 / NDX.DWX`:
  - P4 PASS rows exist.
  - P5 PASS rows exist.
  - P5b PASS rows exist.
  - P5c is now the active bottleneck and is failing on real crisis-slice evidence.

## Layer 3 Findings

### Fixed: Real Phase Evidence Overwrite

Problem:

- Real phase runners wrote shared artifacts under
  `D:/QM/reports/pipeline/<EA>/<Phase>/summary.json`.
- Multiple variants of the same EA/phase can run and finish over time.
- Work-item rows then pointed at a shared file that may have been overwritten by
  a later variant.
- This was visible in `QM5_1056 / NDX.DWX`: many P5/P5b/P5c rows shared the
  same phase-level evidence path even though their setfiles differed.

Fix:

- `tools/strategy_farm/farmctl.py`
  - `_spawn_phase_runner_for_work_item` now gives real phase runners an isolated
    work-item output root:
    `D:/QM/reports/work_items/<work_item_id>/...`.
- `tools/strategy_farm/terminal_worker.py`
  - Real phase summary lookup now prefers the work-item `report_root`.
  - PASS artifacts are mirrored back to the canonical pipeline phase directory
    for downstream phase inputs and dashboard convenience.

Evidence:

- New P5c process command now uses:
  `--out-prefix D:/QM/reports/work_items/<work_item_id>`.
- Targeted tests passed:
  - `tools.strategy_farm.tests.test_terminal_worker_atomic_claim`
  - `tools.strategy_farm.tests.test_cascade_chain_p2_to_p8`
  - `tools.strategy_farm.tests.test_cascade_real_phase_runners`
  - `framework.scripts.tests.test_phase_runners_contract`
  - `framework.scripts.tests.test_phase_verdict_semantics`

Deployment:

- DB backup before worker restart:
  `D:/QM/strategy_farm/state/backups/farm_state_pre_worker_patch_restart_20260520T195742Z.sqlite`
- Active work items were requeued before restarting workers.
- Workers restarted via `tools/strategy_farm/start_terminal_workers.py --dedupe`.
- No manual `terminal64.exe` start was performed.

### Fixed: Remaining Popup-Class PowerShell Calls

Problem:

- Two StrategyFarm helper paths still called `powershell.exe` without
  `CREATE_NO_WINDOW`.

Fix:

- `tools/strategy_farm/repair.py`
- `tools/strategy_farm/render_cockpit.py`

Both now pass `creationflags=subprocess.CREATE_NO_WINDOW` when available.


### Fixed: Missing Build Artifacts Consumed MT5 Slots

Problem:

- `QM5_2010` P2 work_items were active even though the repo EA directory had
  no matching `.ex5`.
- `run_smoke.ps1` logged `run_smoke.deploy_skip=source_missing` but still
  launched MT5. The item then degraded into `summary_missing` / timeout noise.
- Some generated work_items also pointed at setfiles that no longer existed in
  the EA `sets/` directory.

Fix:

- `tools/strategy_farm/terminal_worker.py`
  - `_run_claimed_item` now preflights `setfile_path`, unique EA directory, and
    matching `.ex5` before spawning a runner.
  - Failures are marked `failed/INVALID` immediately and write
    `D:/QM/reports/work_items/<id>/<EA>/<Phase>/preflight_failure.json`.

Evidence:

- Targeted worker/cascade/phase tests passed after the patch: 21 tests OK.
- Live farm now records `ex5_missing` / `setfile_missing` preflight evidence for
  bad `QM5_2010`/`QM5_2014` rows instead of consuming terminal slots.
- Worker fleet was restarted after a DB backup:
  `D:/QM/strategy_farm/state/backups/farm_state_pre_preflight_worker_restart_20260520T200742Z.sqlite`.

### Finding: EA Registry / Build Artifact Drift

Repository EA inventory:

- `framework/EAs`: 188 `QM5_*` directories.
- 18 directories have missing setfiles, missing `.ex5`, or duplicate `.ex5`.
- Active-risk examples:
  - `QM5_2010_nnfx-v2-h4-bias-h1-pullback`: `.mq5` and 4 setfiles, no `.ex5`.
  - `QM5_3001`..`QM5_3005`: `.mq5` and setfiles, no `.ex5`.
  - `QM5_1002` has duplicate/legacy build directories.
  - `QM5_1003` has two `.ex5` files in one EA directory.

Action: build/review gates should not enqueue P2 until P1/build deployment is
clean. The new worker preflight protects MT5 capacity, but upstream should still
prevent invalid rows from entering the queue.

### Finding: Strategy Archive Is Not a Pure DB Mirror

After regenerating dashboards:

- DB distinct EAs in `work_items`: 79.
- Strategy detail pages rendered: 166.
- DB EAs without detail pages: `QM5_3001`..`QM5_3005`.
- Detail pages without current DB work_items: 92, mostly archive/legacy/research
  entries.

Conclusion: `strategies.html` is a broader strategy archive, not a live pipeline
view. Cockpit must keep a separate live queue/control section so OWNER does not
read archive count as backtest progress.

### Finding: Agent Orchestrator Is Not Yet Production Queue

The capability router exists and syncs the agent registry:

- `codex`: enabled, max_parallel 3.
- `gemini`: enabled, max_parallel 2.
- `claude`: disabled, max_parallel 0.

But the production load still lives mostly in legacy `tasks` + `work_items`:

- `agent_tasks`: 1 row.
- legacy `tasks`: 1,604 rows.
- `work_items`: 5,365 rows.

Conclusion: the orchestrator is installed and policy-correct, but not yet the
central execution queue. This is acceptable while the farm pump remains the
production driver, but Cockpit/Docs should not imply full migration.

### Finding: Broad Framework Test Discovery Is Not Green

Targeted tests for the patched path are green. Full `framework/scripts/tests`
discovery currently has 9 failures and 4 errors. They appear to be pre-existing
test drift:

- Tests reference removed/renamed `p2_baseline` functions.
- P5b test still passes deprecated args (`--paths`, `--seed`).
- P8 test expects non-MT5 `mode_results`, while current P8 requires real MT5
  news replay for a passable gate.
- Several dispatcher tests expect old terminal affinity/capacity behavior.

Action: update or retire stale tests so full discovery becomes meaningful again.

### Finding: Negative Evidence Is Under-Indexed

PASS paths are reliable, but many FAIL/INVALID rows lack `evidence_path`. The
payload usually contains enough reason fields, but dashboard/root-cause analysis
would improve if terminal-worker failure paths wrote a small failure artifact
and set `evidence_path` for:

- summary-missing retry exhaustion
- active timeout
- worker/terminal death
- history-skip invalidations

### Finding: P5c Bottleneck Is Real, Not Synthetic

Current P5c failures are real MT5 crisis-slice failures. The latest runner uses
real slice reruns and records unavailable `NO_HISTORY` slices separately. The
strategy is blocked because available crisis slices fail trade/PF gates, not
because P5c is missing a runner.

## Current Risk Register

1. High: shared real-phase evidence was corrupting traceability for historical
   rows. Fixed for new runs; old rows remain historical and should not be used
   as per-variant proof without checking their original logs.
2. Medium: full framework test suite is stale; targeted tests are green but broad
   CI signal is noisy.
3. Medium: negative evidence rows without `evidence_path` weaken root-cause
   analysis.
4. Medium: build/queue gates can still enqueue EAs with missing `.ex5` or stale
   setfile paths; worker preflight now protects MT5 capacity.
5. Medium: Strategy Archive is not a live DB mirror; Cockpit needs explicit live
   queue/control counts.
6. Medium: agent router is present but not yet the source of truth for all work.
7. Low: legacy bridge heartbeat warning remains, but direct pump Codex is active.

## Next Audit Layers

1. Registry and EA integrity:
   `ea_id_registry.csv`, `magic_numbers.csv`, EA directory naming, mq5/ex5/setfile
   consistency.
2. Strategy archive and cockpit consistency:
   DB vs `public-data/*.json` vs dashboards vs EA detail pages.
3. Phase runner contract matrix:
   required inputs, output artifacts, downstream consumers, and tests for each
   Q/P stage.
4. Test-suite cleanup:
   classify every broad discovery failure as stale-test, real regression, or
   retired subsystem.
5. Historical evidence cleanup:
   mark old shared-evidence rows as `legacy_shared_phase_artifact` in payload or
   regenerate if needed.
