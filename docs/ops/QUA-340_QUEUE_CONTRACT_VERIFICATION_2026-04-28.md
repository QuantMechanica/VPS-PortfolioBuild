# QUA-340 Queue Contract Verification — 2026-04-28

Issue: QUA-340 `SRC04_S02a`  
Agent: Pipeline-Operator  
Scope of this heartbeat: queue/de-dup contract hardening aligned to AGENTS addendum (`T1`-`T5`, tuple de-dup, `enqueue -> claim -> running -> ack(final)`).

## Change Applied

Updated `infra/scripts/Invoke-PipelineQueueDryRun.ps1` so tuple de-dup is enforced before queue/evidence append.

Behavior now:
- Lock + dedup preflight happens first (`factory_run_dedup_v1.lock` + `factory_run_dedup_v1.csv`).
- Duplicate tuple throws immediately and does not append queue row.
- Queue lifecycle transitions are now emitted as:
  - `enqueue`
  - `claim`
  - `running`
  - `ack` (with `final_status`)
- Dedup registry row stores `status=ack` and `final_status=<succeeded|failed|no_report|aborted>`.

## Evidence (Dry Run)

State root:
- `C:\QM\worktrees\pipeline-operator\artifacts\qua-340\state`

Evidence root:
- `C:\QM\worktrees\pipeline-operator\artifacts\qua-340\factory_runs`

Accepted run:
- `run_key`: `f31a52c9f35cea3b3758e0f51ea3d1e2e4faf64af68b5390d804230a73635b8c`
- tuple: `(QM5_3400, v5.0.0-qua340, EURUSD, P2, qua340-dryrun-001)`
- terminal: `T2`
- final_status: `succeeded`

Duplicate retry (same tuple):
- rejected with: `Duplicate tuple detected for run_key=f31a52c9f35cea3b3758e0f51ea3d1e2e4faf64af68b5390d804230a73635b8c`

Queue ledger line (single line only, no duplicate append):
- `artifacts/qua-340/state/factory_run_queue_v1.jsonl`

Dedup row:
- `artifacts/qua-340/state/factory_run_dedup_v1.csv`

## Next Action

Run first eligible non-dry production cohort for SRC04_S02a through the same lifecycle and post final ack evidence tuple:
- `run_key`
- terminal (`T1`-`T5`)
- report dir (`D:\QM\reports\factory_runs\...`)
- final ack status
