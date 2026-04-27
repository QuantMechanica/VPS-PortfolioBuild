QUA-246 update: Pipeline-Operator design package is published.

Published files:
- `processes/15-pipeline-op-load-balancing.md`
- `AGENTS.md` (Pipeline-Operator queue/de-dup addendum)
- `processes/README.md` (index row for process 15)
- `docs/ops/QUA-246_PIPELINE_OP_HANDOFF_2026-04-27.md` (handoff summary + next action)
- `infra/scripts/Invoke-PipelineQueueDryRun.ps1` (implementation smoke script)
- `docs/ops/QUA-246_QUEUE_DRYRUN_EVIDENCE_2026-04-27.md` (dry-run execution evidence)

Delivered content:
1. Allocation policy: least-loaded round-robin with symbol-affinity tie-break.
2. De-dup contract: tuple `(ea_id, version, symbol, phase, sub_gate_config)` never runs twice; table schema + lock write protocol defined.
3. Queue lifecycle: enqueue -> claim -> running -> ack, including stale-claim handling.
4. Evidence path + audit steps: run-level artifacts and verification flow documented.
5. AGENTS addendum: behavior codified for Pipeline-Operator.

Open acceptance items:
- Doc-KM to publish corresponding Notion page/mirror update.
- Pipeline-Operator to confirm first subsequent backtest run via new de-dup queue with evidence tuple.
