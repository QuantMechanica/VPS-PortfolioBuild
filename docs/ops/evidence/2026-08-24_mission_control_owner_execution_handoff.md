# Mission Control OWNER execution handoff — 2026-08-24

Status: canonical rollout complete.

Authority: `decisions/2026-08-24_owner_mission_control_execution_handoff.md`

## Contract

1. `YES`/`NO` is written as an immutable v2 receipt before any task exists.
2. The receipt reserves one UUIDv5 execution task ID.
3. The receipt hashes the OWNER-visible card and records the exact selected
   effect; later feed drift makes the handoff fail closed.
4. The execution manifest maps the exact decision and choice to objective,
   allowed actions, acceptance criteria and global prohibitions.
5. One `ops_issue` task requiring `code + ops + summary` is inserted. Only the
   Claude lane satisfies that capability combination in the governed registry.
6. The existing router assigns it; the existing Claude scheduled lane executes
   it and returns an evidence artifact to `REVIEW`.
7. Mission Control projects the live task state through `COMPLETE` (`PASSED`).
8. `VERTAGT` never creates a task.

The service attempts the handoff immediately. The existing five-minute router
task also reconciles every authorized receipt, so a crash between receipt and
task insert cannot lose the order. UUID identity and receipt-hash validation
make concurrent/repeated reconciliation idempotent.

The live Factory serializes SQLite writers. The handoff therefore uses the
shared bounded BUSY/LOCKED retry policy and opens a fresh connection for every
attempt. A durable receipt is retained as `RETRY_PENDING` if contention still
outlasts the immediate attempt; the five-minute reconciliation retries the same
task identity.

## Hard boundaries

Every task payload carries false flags for live execution, Factory pause,
AutoTrading and deployment. The global deny-list also excludes gate criteria,
candidate universes, book construction and destructive evidence mutation.
Free-form OWNER notes explicitly cannot expand scope.

## Isolated verification

```text
focused pytest: 30 passed, 1 skipped
router/orchestration regression: 89 passed
Python byte compilation: PASS
execution manifest JSON parse: PASS
```

The focused tests cover receipt idempotency, terminal/deferred semantics,
tamper refusal, exactly-one task insertion, Claude-only capabilities, state
projection, loopback handoff, Mission Control rendering and legacy snapshot
compatibility.

## Canonical and live rollout

```text
canonical commit: 481a092c3 (agents/board-advisor)
SQLite contention hardening commit: f1db49beb
canonical regression: 119 passed, 1 skipped
receipt dry-run/apply: receipt_count=0, eligible_count=0, errors=0
intake PID after contention-hardening restart: 25308
intake health: ok=true, mode=ROUTER_HANDOFF, open_count=6, revision=1
startup reconcile: ok=true, receipt_count=0, errors=0
Claude burn authorization: active through 2026-08-24T23:00:00+02:00
quota governor: CLAUDE_DISABLED released by its managed-owner contract
Claude ops_issue spawn gate: allowed=true (OWNER burn authorization active)
Mission Control: 6 owner cards, 6 CLAUDE READY plans
Mission Control bytes: 70,927; cockpit.html SHA == cockpit_v2.html SHA
Linear gate frontier: last top-level section, 30 preview rows, 14,639 only in drill-down
Vault queue: 6 cards, generated text names router handoff
Company Reference lint: PASS
```

Operational caveat observed without pausing the Factory: the general router
logs at `08:36`, `08:41`, `08:46` and `09:01Z` ended with SQLite `database is
locked`; the last substantive successful log began at `08:27Z`. Receipt
reconciliation runs before that broader router work, and the loopback service
is healthy, so an OWNER answer remains durable and receives the bounded direct
handoff retries. Assignment to Claude can nevertheless be delayed until a
lock-free router cycle. This contention was not cleared by stopping or slowing
Factory workers.

No live OWNER answer was fabricated for rollout. Consequently no production
execution task exists yet; the first real `YES`/`NO` click will create it.
Factory workers, T1-T10, T_Live and AutoTrading were not changed or interrupted.
