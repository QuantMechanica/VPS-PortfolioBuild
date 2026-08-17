# Stranded-INFRA Frontier Guard

Date: 2026-08-17
Branch: `agents/board-advisor`
Farm claim: `7a8e12c6-896d-40a4-84df-da71d587fdef`

## Outcome

The hourly `sweep_enqueue_built_eas.py` selector now treats an INFRA_FAIL row
as historical when either of these facts already exists for the same lineage:

1. the same `(EA, phase, symbol, setfile)` has a terminal non-INFRA
   disposition, including rows stored with `status='failed'`; or
2. the same `(EA, symbol)` has any work item at a deeper canonical phase.

Both predicates run in the candidate-selection SQL. Per-row checks remain as
race guards before enqueue. This prevents stale Q02/Q03/Q08 rows from consuming
tester capacity after the farm has already judged or advanced them.

## Why this unit

- The approved diversity build backlog had no unbuilt FX card with both an EA
  registry allocation and deterministic magic rows.
- The apparent diverse Q02/Q03 rescue rows were either active work, indicator
  stacks/high-frequency systems, or historical rows superseded by real strategy
  or downstream verdicts.
- Remaining reputable FX ideas in the OWNER orthogonality program are explicitly
  DATA_PROBE/RESEARCH_TICKET items rather than card-ready build candidates.
- Tester capacity was saturated, so no MT5 backtest was started.

## Read-only production impact measurement

The pre-change hourly predicates were replayed read-only against
`D:/QM/strategy_farm/state/farm_state.sqlite`, then the two new guards were
applied to those groups:

| Phase | Old hourly candidates | Failed terminal dispositions suppressed | Already-advanced suppressed | Remaining before existing file/registry guards |
|---|---:|---:|---:|---:|
| Q02 | 555 | 32 | 97 | 426 |
| Q03 | 14 | 0 | 14 | 0 |
| Q08 | 12 | 0 | 4 | 8 |
| **Total** | **581** | **32** | **115** | **434** |

The guard removes 147 stale candidate groups from repeated hourly consideration.
This measurement did not mutate work items.

## Verification

```text
python -m py_compile tools/strategy_farm/sweep_enqueue_built_eas.py \
  tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py

python -m pytest \
  tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py \
  tools/strategy_farm/tests/test_requeue_stranded_infra.py -q

29 passed in 11.15s
```

The regression fixture proves both blocked paths while preserving the valid
terminal-failed logical-basket retry case. `git diff --check` passed.

## Boundaries

- No Q-phase was run or advanced manually.
- No EA, setfile, registry, portfolio gate, T_Live file, manifest, or
  AutoTrading state was changed.
- The only farm-state mutation was the scoped coordination claim. A pre-claim
  online SQLite backup with `PRAGMA quick_check=ok` is stored at
  `D:/QM/strategy_farm/state/backups/farm_state_before_sweep_infra_frontier_claim_20260817T010428Z.sqlite`.
