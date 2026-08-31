# DL-089 EUR idle-program claim fairness repair

Date: 2026-08-31 UTC  
Router task: `18333995-2cd8-4743-8182-a44ad63a3733`  
Branch: `agents/board-advisor`

## Verdict

The EUR baseline gap was not stale lane bookkeeping and not a missing refill.
The canonical claim order allowed an older authenticated second-lane frontier
from a program already running under `L=2` to beat the authenticated head of an
idle program. Repeated refills could therefore keep EUR at zero active cells
while K/G still had room.

The bounded repair adds an `OPT_CENSUS` tie-break: among otherwise-priority
frontiers, a sealed head whose `program_id` has no active census row is ordered
before an additional lane for an already-running program. All transaction-local
K/L/G ceilings, same-arm and duplicate-pair checks, symbol cap, pruning token,
history, commit, and terminal guards remain unchanged.

## Read-only production evidence

Against `D:/QM/strategy_farm/state/farm_state.sqlite`:

- EUR head `98add2f9-a6e3-55ce-b81f-15cd108e98a2` was `pending`, unclaimed,
  `OPT_CENSUS`, `arm=baseline`, `year=2021`, with both
  `priority_track=true` and `opt_census_frontier_priority=true`.
- Its predecessors 2019 and 2020 were terminal `MEASURED`.
- No active `EURUSD.DWX` row existed at the diagnostic snapshot, so neither the
  symbol cap nor an EUR active lane explained the skip.
- The live census snapshot had six active cells across three other programs at
  the first focused capture, while the configured environment was `K=8`,
  `L=2`, `G=8`; later it had four active cells across three programs. Capacity
  therefore existed.
- Before the repair the EUR head was position 32 in the canonical pending order,
  behind older frontier rows from other programs. Lane occupancy is rebuilt on
  every claim from rows whose status is currently `active`; there is no durable
  occupancy counter to go stale.

This establishes a claim-order fairness defect at the L=2 transition, not a
ledger, window, or state-reconciliation defect.

## Code change

`tools/strategy_farm/farmctl.py::pending_claim_order_sql()` now emits
`_opt_census_idle_program_rank` and uses it immediately after authenticated
frontier rank in both ordering modes. The active-program set is an uncorrelated
`SELECT DISTINCT` subquery, evaluated once by SQLite rather than rescanning the
queue per row.

Two regressions pin the contract:

1. SQL ordering: an idle program's newer authenticated baseline head precedes
   an older second-lane head from a running program.
2. Atomic claim: with `K=2`, `L=2`, `G=3` and one program already active, a free
   worker claims the idle program head in the same claim cycle, even though the
   running program's second-lane row is older.

The latter is the bounded liveness invariant (`N=1` claim cycle once the row is
the eligible idle-program frontier and K/G capacity is free). After each EUR
baseline year becomes terminal, the next sealed year becomes that same idle
frontier, so the 2021-2025 baseline chain can drain without second-lane refill
starvation. The repair does not manufacture a terminal verdict; real chain
completion remains evidenced only by normal worker receipts.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_opt_census_dispatch.py tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q
108 passed in 57.42s
```

```text
git diff --check -- tools/strategy_farm/farmctl.py \
  tools/strategy_farm/tests/test_opt_census_dispatch.py \
  tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py
PASS (no whitespace errors; only checkout line-ending notices)
```

The repaired live read-only selector returned 9,186 rows in 0.631 seconds. An
initial correlated implementation took 11.64 seconds and was discarded before
commit; the shipped uncorrelated form avoids adding claim-path latency.

No terminal was started, stopped, or restarted. No active backtest was
interrupted. AutoTrading and T_Live were untouched. No work-item status,
verdict, payload, priority flag, ledger, setfile, or pipeline evidence was
mutated during diagnosis or verification.

