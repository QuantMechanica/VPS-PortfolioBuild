# Process Registry

Status: active, 2026-07-22

This registry lists active process contracts. Historical issue-system and agent-role
workflows are not governance and must not be used as approval gates.

## Authority

- OWNER is the sole human approval authority.
- Filesystem state and deterministic controller state are operational truth.
- Worker personas may implement, inspect, or recommend; they do not acquire
  authority from a title.
- `g0_status: APPROVED`, recorded by OWNER after R1-R4, authorizes EA build,
  instrumentation, debugging, compilation, T1-T5 deployment, and non-live tests.
- Build and phase PASS/FAIL decisions come from artifact-bound deterministic rules.
- T6/live promotion is a separate OWNER decision and requires the full evidence
  package, execution contract, and signed deploy manifest.

## Active processes

| # | Process | Contract | Authority / automated gate |
|---|---|---|---|
| 1 | EA lifecycle | [01-ea-lifecycle.md](01-ea-lifecycle.md) | Deterministic lifecycle state; OWNER promotion |
| 2 | Zero-trades recovery | [02-zt-recovery.md](02-zt-recovery.md) | Diagnostic evidence, not discretionary rejection |
| 3 | Portfolio deploy | [03-v-portfolio-deploy.md](03-v-portfolio-deploy.md) | OWNER-signed deployment only |
| 4 | Incident response | [04-incident-response.md](04-incident-response.md) | Incident commander assigned by OWNER or runbook |
| 5 | Dashboard refresh | [05-dashboard-refresh.md](05-dashboard-refresh.md) | Generated state only |
| 9 | Disaster recovery | [09-disaster-recovery.md](09-disaster-recovery.md) | Runbook safety boundaries |
| 11 | Disk and sync | [11-disk-and-sync.md](11-disk-and-sync.md) | Runbook safety boundaries |
| 13 | Strategy research | [13-strategy-research.md](13-strategy-research.md) | OWNER source/G0; deterministic downstream gates |
| 14 | EA enhancement | [14-ea-enhancement-loop.md](14-ea-enhancement-loop.md) | Full phase rerun for every new version |
| 15 | Pipeline load balancing | [15-pipeline-op-load-balancing.md](15-pipeline-op-load-balancing.md) | Controller scheduling |
| 16 | Backtest execution discipline | [16-backtest-execution-discipline.md](16-backtest-execution-discipline.md) | Version-bound tester evidence |

Any surviving unlisted role-hierarchy record is historical evidence only. It is
non-binding and cannot block work.

## Gate invariants

1. A card without `g0_status: APPROVED` cannot enter build.
2. An approved G0 card cannot be blocked by obsolete role signatures or by a
   conflicting descriptive `status: DRAFT` field.
3. A build cannot enter phase tests until source, binary, registry, setfiles, and
   deployed hashes satisfy the build contract.
4. A phase result is valid only when bound to the exact binary, setfile, symbol,
   timeframe, data interval, model, and costs actually tested.
5. `ZERO_TRADES` is investigated as entry/data/filter behavior before a strategy
   verdict is made.
6. No upstream approval implies T6/live permission.
7. AutoTrading is never toggled by an agent.

## Skills

Skills are reusable execution instructions, not authorities. Their technical
preconditions still apply, but obsolete role names inside a legacy skill cannot add
an approval requirement that conflicts with this registry. When skill text and this
registry disagree on governance, stop only for a real safety precondition, record the
drift, and follow OWNER plus the deterministic gate contract.

## Maintenance

The worker changing a workflow updates its process contract in the same change. An
evidence audit should flag:

- role-name approvals;
- results not bound to artifact hashes and actual tester dates;
- G0/build/test/promotion conflation;
- references to retired orchestration systems;
- links to deleted governance documents.
