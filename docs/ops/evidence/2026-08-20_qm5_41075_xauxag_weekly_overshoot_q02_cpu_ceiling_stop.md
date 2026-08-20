# QM5_41075 Q02 CPU-ceiling stop

Date: 2026-08-20

Branch: `agents/board-advisor`

EA: `QM5_41075_xauxag-wovershoot-rv`

Outcome: `Q01 PASS`; `Q02 NOT_ENQUEUED_CPU_CEILING`

## Diversity-first target reconciliation

`QM5_41075` is the already-built, OWNER-approved completed-week XAU/XAG
relative reversal-overshoot basket at branch HEAD `c43a745b9`. It is one
logical market-neutral pair rather than another directional index carrier.
The governed build contains the compiled EX5, one aggregate-package D1
backtest setfile with `RISK_FIXED=1000` and `RISK_PERCENT=0`, a basket
manifest, the approved card copy, and deterministic reference tests.

The canonical farm database was queried through the supported target view:

```text
python tools/strategy_farm/farmctl.py work-items --ea QM5_41075
count=0
```

Therefore no Q02 row existed for this exact identity at the preflight. No
other EA was selected, built, claimed, or enqueued.

## Binding capacity stop

The canonical `farmctl mt5-slots` inventory at
`2026-08-20T21:00:18+00:00` reported seven running governed research
terminals, equal to the paced terminal ceiling: `T1`, `T2`, `T3`, `T5`,
`T6`, `T7`, and `T8`. It reported no duplicate terminal workers and no
orphaned terminal processes.

The immediately following whole-host probe sampled five two-second CPU
intervals:

```text
100.00, 94.84, 99.76, 94.98, 98.10 percent
average=97.54 percent
maximum=100.00 percent
hard ceiling=97 percent
```

Three samples exceeded the explicit 97% ceiling and the average also
exceeded it. The mission stop rule therefore bound before any queue or tester
mutation.

`T_Live` and the unrelated FTMO terminal were observed only so they could be
excluded from the governed research count. Neither was controlled or
modified.

## Safe handoff

Q02 was not enqueued, dispatched, reserved, or run. No smoke or manual
backtest was launched, no terminal was stopped, and no farm row, registry,
resolver, EA source, binary, setfile, basket manifest, portfolio gate, or
T_Live manifest was changed by this capacity unit.

After both terminal and whole-host CPU headroom return, re-run the exact
`QM5_41075` work-item query before using a target-only Q02 enqueue. If a row
has appeared, do not enqueue a sibling. Q02 remains responsible for trade
generation and governed economic falsification; this record is not a
pipeline PASS beyond the existing Q01 evidence and does not authorize live
use.

Machine-readable evidence is in
`artifacts/qm5_41075_q02_cpu_ceiling_stop_20260820T210211Z_board_advisor.json`.
