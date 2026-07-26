# Multisymbol Q08 capacity decision — ticket `213aa9c3`

Date: 2026-07-26  
Scope: factory admission and Q08 neighborhood memory only. No terminal launch,
AutoTrading, T_Live, setfile, verdict, or pipeline state change.

## Evidence

During Q08 work item `804a2f4d` (`QM5_13059`), the process census recorded:

| tester class | private bytes | working set |
|---|---:|---:|
| multisymbol | 26.38 GB | 21.11 GB |
| ordinary | 11.60 GB | 11.50 GB |
| ordinary | 9.98 GB | 9.92 GB |

Those three testers consumed about 48 GB of a 63 GB host. Free physical RAM
reached 0.4 GB and workers T2/T8/T10 disappeared. At the same time the admission
brake logged `commit_reserved_gb=68.0` and
`effective_commit_headroom_gb=-5.4`, proving that it correctly prevented *new*
claims. It could not undo ordinary jobs admitted before the multisymbol tester
finished ballooning.

The current code already serializes multisymbol jobs and reserves a 44 GB
expected peak with a 48 GB multisymbol commit-headroom threshold. Commit
`d88a89392`'s flat one-hour reservation was unsafe because it double-counted
allocated memory; the measured-usage decay now on `agents/board-advisor`
preserves launch-race protection without that double count.

## Decision 1 — drain to a quiet fleet before multisymbol admission

Keep `MULTISYMBOL_COMMIT_MIN_FREE_GB=48` and
`MULTISYMBOL_COMMIT_RESERVATION_GB=44`. The values are conservative enough for
the observed 26.38 GB run and the documented 20–44 GB range. Changing them does
not close the timing hole.

The missing control is a durable **multisymbol drain mode**:

1. When an eligible multisymbol item reaches the claim frontier, stop admitting
   new ordinary work.
2. Wait until the active ordinary tester count is zero.
3. Re-check the existing 12 GB physical-RAM and 48 GB effective-commit floors
   atomically with the claim.
4. Admit exactly one multisymbol item; preserve the existing serialization and
   measured-usage reservation decay.
5. Resume ordinary admission only after that multisymbol work item leaves
   `active`.

The recommended ordinary-active limit at multisymbol claim time is **N=0**, not
N=1. A worst-case 44 GB multisymbol plus the observed 11.60 GB ordinary tester
would leave only about 7 GB before the OS, terminals, workers, and other
services. That is too close to the existing 4 GB emergency RAM floor and gives
little protection against another balloon phase.

This should be implemented as a drain state, not merely `if active_ordinary > 0:
skip multisym`. A skip-only rule would allow workers to keep claiming ordinary
rows and could starve the multisymbol frontier indefinitely.

No admission-code change is made in this ticket: proving drain-state fairness
and fleet behavior requires a controlled OFF-window acceptance run longer than
the two-minute observation that previously produced a false stability claim.

## Decision 2 — do not lower the Q08 neighborhood parameter cap as a memory fix

`Q08_NEIGHBORHOOD_MAX_PARAMS` is already 2. The aggregator passes it to
`q08_5_neighborhood_runner.py` and calculates `1 + 2 * max_params` support runs.
Those runs are sequential subprocess work. Lowering the value reduces total
runtime and the number of perturbation runs, but it does **not** cap the peak
memory of the single multisymbol MT5 tester that reached 26.38 GB.

Setting it below 2 would therefore weaken the Q08 robustness sample without
solving the measured peak-memory mechanism. A real per-tester memory cap would
need support in the MT5 runner/process boundary and evidence that forced
termination produces an infrastructure verdict rather than a false strategy
verdict. That is separate implementation work and must not be inferred from
`--neighborhood-max-params`.

## Focused verification

- `terminal_worker.py` defines the 48 GB threshold, 44 GB reservation, one-hour
  multisymbol balloon window, measured-usage decay, and multisymbol
  serialization.
- `farmctl.py` defines `Q08_NEIGHBORHOOD_MAX_PARAMS = 2`.
- `aggregate.py` maps that cap to `1 + 2 * max_params` sequential neighborhood
  runs; it does not impose a process-memory limit.
- Existing reservation-decay unit tests remain the relevant arithmetic
  regression suite; this evidence makes no executable change.

Verdict: **REVIEW — capacity decision recorded.** Preserve the reservation
brake; design and acceptance-test a starvation-safe N=0 drain mode in an
OWNER-approved OFF window. Do not lower the neighborhood parameter cap as a
substitute for memory isolation.
