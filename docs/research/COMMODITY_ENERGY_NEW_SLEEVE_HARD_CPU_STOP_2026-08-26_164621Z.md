# Commodity/energy new sleeve: hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T16:46:21Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `bf2a264bd2f4363554c7b7639c58b98dc59c3f41`

Status: stopped at the explicit backtest CPU ceiling before choosing or
allocating another commodity edge

## Binding capacity result

The mission requires work to stop when the backtest CPU ceiling is reached.
Five fresh one-second whole-host readings were `96.1%`, `94.4%`, `84.0%`,
`76.6%`, and `97.5%`. The average was `89.72%` and the maximum was `97.5%`.
The governed rule binds when either average or maximum is at least `97%`, so
the maximum independently fired the hard stop.

Immediately before the sample, the read-only `farmctl mt5-slots` snapshot
showed six governed factory terminals active: T1, T5, T6, T7, T9, and T10.
All ten terminal-worker daemons were present, six terminal reservations were
active, and no orphaned factory terminal process was reported. `T_Live` and
the unrelated FTMO terminal were observed only so they could be excluded;
neither was controlled.

## Non-duplicate frontier decision

The deterministic EA registry and EA tree both currently end at `QM5_41169`.
The latest commodity frontier already contains three distinct low-frequency
mechanics:

- `QM5_41167_wti-coxstuart-tr`: monthly WTI paired-sign trend;
- `QM5_41168_xauxag-mcoxstuart-rv`: monthly market-neutral XAU/XAG paired-sign
  reversion; and
- `QM5_41169_wti-foster-record-tr`: monthly WTI forward-record-count trend.

Fresh canonical work-item evidence also shows that `QM5_41169` already has
one governed `COMPILE_EA` successor, work item
`4a6e89aa-9405-4e9b-b292-bae442b52015`, still pending without a verdict. It
would be incorrect to duplicate that compile or enqueue Q02 before a current
strict compile and Q01 PASS.

Because the CPU stop bound before candidate selection, this run deliberately
did not consume a new source identity, claim that an untested candidate is
non-duplicate, or allocate the next EA ID. A later unsaturated run can perform
the reputable-source and functional-equivalence audit against the then-current
frontier before selecting exactly one edge.

## Actions and safety boundary

No source approval, Strategy Card, EA ID, magic row, resolver, EA source,
EX5, setfile, basket manifest, compile, build check, Q02 row, queue priority,
dispatcher tick, terminal reservation, tester, or backtest was created or
changed. The pre-existing shared-worktree changes were preserved and excluded
from this evidence-only commit.

No portfolio gate or admission state changed. No live/demo/shadow/stress
artifact was created. AutoTrading, `T_Live`, the T_Live manifest, and all
terminal processes were untouched.

Machine-readable evidence:
`artifacts/commodity_energy_new_sleeve_hard_cpu_stop_20260826T164621Z_board_advisor.json`.
