# QUA-340 Unblock Payload (Pipeline-Operator)

- issue: QUA-340 / SRC04_S02a
- generated_utc: 2026-04-28T10:21:13.3683178Z
- readiness_ready_for_queued_smoke: False
- card_ea_id_raw: TBD
- registry_path: C:\QM\worktrees\pipeline-operator\framework\registry\magic_numbers.csv
- readiness_evidence_json: C:\QM\worktrees\pipeline-operator\artifacts\qua-340-real\qua340_readiness_check_2026-04-28_102113.json

## Required Unblock Owners

1. CEO + CTO
2. CTO / Development

## Required Unblock Actions

1. Set numeric `ea_id` for `SRC04_S02a` in strategy card (replace `TBD`).
2. Add active row for that `ea_id` in `framework/registry/magic_numbers.csv`.
3. Build and deploy `QM5_<ea_id>.ex5` to `D:\QM\mt5\T1..T5\MQL5\Experts\QM\`.
4. Pipeline-Operator reruns queued smoke with new digest (`qua340-smoke-010`).

## Pipeline-Operator Next Command (after unblock)

```powershell
.\infra\scripts\Invoke-QUA340ReadinessCheck.ps1
.\infra\scripts\Invoke-PipelineQueuedSmokeRun.ps1 -EAId <ea_id> -Version v5.0.0-qua340 -Symbol EURUSD.DWX -Phase P2 -SubGateConfig qua340-smoke-010 -Terminal T2 -Year 2022 -Period M15 -Runs 2 -MinTrades 1
```
