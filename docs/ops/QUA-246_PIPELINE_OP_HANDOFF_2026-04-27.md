# QUA-246 Pipeline-Operator Design Handoff (2026-04-27)

Issue: [QUA-246](/QUA/issues/QUA-246)  
Author: Pipeline-Operator (Codex local)  
Status: design published, implementation confirmation pending

## Published Artifacts

- `processes/15-pipeline-op-load-balancing.md`
- `AGENTS.md` (Pipeline-Operator addendum for queue/de-dup behavior)
- `processes/README.md` index entry for process 15
- `infra/scripts/Invoke-PipelineQueueDryRun.ps1` (queue/de-dup execution smoke tool)
- `docs/ops/QUA-246_QUEUE_DRYRUN_EVIDENCE_2026-04-27.md` (dry-run evidence)

## Delivered In This Handoff

1. Allocation policy defined: least-loaded round-robin with symbol-affinity tie-break.
2. De-dup registry contract defined, including:
   - tuple key `(ea_id, version, symbol, phase, sub_gate_config)`
   - location, schema columns, and lock-based write protocol
3. Queue mechanics defined: enqueue -> claim -> running -> ack with stale-claim handling.
4. Evidence path and required run artifacts defined for auditability.
5. AGENTS addendum committed for behavior change codification.

## Open Acceptance Items

1. Doc-KM publishes the same process spec to Notion mirror.
2. First subsequent backtest run must execute using the de-dup queue contract and be confirmed on issue thread.

## Dependency Blocks

1. **Blocked item:** Notion mirror publication of process 15  
   **Unblock owner:** Documentation-KM  
   **Unblock action:** publish/update the Notion page mapped to process 15 and let nightly mirror sync land file diff.
2. **Blocked item:** first real backtest confirmation using new queue/de-dup contract  
   **Unblock owner:** Pipeline-Operator  
   **Unblock action:** run next eligible cohort through queue lifecycle and post final evidence tuple on QUA-246.

## Next Action

- **Owner:** Pipeline-Operator  
- **Action:** run next eligible backtest cohort using the new queue/de-dup contract and post confirmation evidence (`run_key`, terminal, report_dir, final status) on QUA-246.
