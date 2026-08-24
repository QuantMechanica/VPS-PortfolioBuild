# QM5_1229 EURCHF Q02 capacity recheck

Date: 2026-08-24 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `BLOCKED_CAPACITY`; no Q02 successor was enqueued.

## Selection and collision guard

The governed approved-card scan found no registry-valid card without an EA
directory, so the build lane had no safe non-duplicate target. The diverse
infrastructure lane was then checked for FX, energy beyond XNG, rates, crypto,
and market-neutral pairs. The existing farm task
`076c4a69-79c6-4b41-9034-37a895783719` remains the strongest clean handoff:

- EA: `QM5_1229_carver-statevol`;
- target: `EURCHF.DWX`, D1, Q02;
- source work item: `8870ee05-fbc6-4bc2-a721-b3cba2a334c5`;
- source verdict: `INFRA_FAIL` after three infrastructure-only `BARS_ZERO`
  attempts;
- source: Rob Carver's structural state-of-volatility research;
- risk: backtest setfile `RISK_FIXED=1000`, `RISK_PERCENT=0`; and
- diversity: CHF exposure is absent from the certified book described in the
  paced-fleet mission.

The fresh database read found no pending, claimed, active, or running work item
for `QM5_1229`; no downstream row for `QM5_1229 / EURCHF.DWX`; and no successor
newer than the failed source row. The earlier claim is deliberately still
`BLOCKED` with verdict `BLOCKED_CAPACITY`, assigned to `codex`. No new task or
duplicate ownership record was created.

Artifact identities remain unchanged from the 2026-08-18 diagnosis:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `98c621bdcf2e22ced88e2da30387789ba7219b42e83b37963ce1b0521689080f` |
| EX5 | `a1cb81c11a932a1f3f5f00f1af7a32952466d26fcbf3ff31434a4cc22256eda1` |
| EURCHF D1 backtest setfile | `a78381adf6e6b4653c196e50140bd68af0e8d91cd33d4a895f5809e809f49eaa` |

The full infrastructure diagnosis, archive admission, strict compile evidence,
and exact append-only handoff remain recorded in
`2026-08-18_qm5_1229_eurchf_q02_history_isolation_capacity_stop.md`.

## Mandatory CPU stop

The CPU admission probe used the worker's governed whole-host
`GetSystemTimes` delta implementation. After priming the counter, five
two-second samples were collected from `2026-08-24T15:36:48Z` through
`2026-08-24T15:36:56Z`:

| Sample | CPU load |
|---:|---:|
| 1 | 91.41% |
| 2 | 96.39% |
| 3 | 98.00% |
| 4 | 98.75% |
| 5 | 96.80% |

Average load was 96.27%; maximum load was 98.75%. The maximum exceeds the
governed `CPU_MAX_LOAD_PERCENT=97.0` ceiling in
`tools/strategy_farm/terminal_worker.py`.

Per the mission's explicit stop condition, no append-only Q02 row, dispatcher
tick, smoke test, compile, MetaTrader launch, or phase runner was started. The
source row remains immutable and the farm task remains released as
`BLOCKED_CAPACITY`. No EA, setfile, registry, Strategy Card, portfolio gate,
portfolio manifest, deploy artifact, `T_Live` path, or AutoTrading state was
changed.
