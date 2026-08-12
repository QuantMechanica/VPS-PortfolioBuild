# Company Processes

End-to-end contracts for QuantMechanica V5. The active authority and gate index is
[process_registry.md](process_registry.md).

Each active process should state:

- trigger;
- required inputs and evidence;
- deterministic state transitions and decision thresholds;
- safe exits, escalation, and kill conditions;
- OWNER decisions, where human authority is actually required.

Worker names describe capability assignments only. They are not approval layers.
Source authorization, G0, deterministic build/test gates, and OWNER promotion must
remain distinct.

## Core index

| # | Process | File |
|---|---|---|
| 1 | EA Life-Cycle | [01-ea-lifecycle.md](01-ea-lifecycle.md) |
| 2 | Zero-trades recovery | [02-zt-recovery.md](02-zt-recovery.md) |
| 3 | Portfolio deploy | [03-v-portfolio-deploy.md](03-v-portfolio-deploy.md) |
| 4 | Incident response | [04-incident-response.md](04-incident-response.md) |
| 5 | Dashboard refresh | [05-dashboard-refresh.md](05-dashboard-refresh.md) |
| 9 | Disaster recovery | [09-disaster-recovery.md](09-disaster-recovery.md) |
| 11 | Disk and sync | [11-disk-and-sync.md](11-disk-and-sync.md) |
| 13 | Strategy research | [13-strategy-research.md](13-strategy-research.md) |
| 14 | EA enhancement | [14-ea-enhancement-loop.md](14-ea-enhancement-loop.md) |
| 15 | Pipeline load balancing | [15-pipeline-op-load-balancing.md](15-pipeline-op-load-balancing.md) |
| 16 | Backtest execution discipline | [16-backtest-execution-discipline.md](16-backtest-execution-discipline.md) |

Other numbered files are historical until rewritten and added to the active registry.
They cannot introduce approval gates or override current contracts.
