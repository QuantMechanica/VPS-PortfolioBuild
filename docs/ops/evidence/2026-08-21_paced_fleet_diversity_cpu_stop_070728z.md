# Paced Fleet Diversity Funnel — Hard CPU Stop

Date: 2026-08-21 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `NO CLAIM; NO BUILD; NO ENQUEUE — HARD CPU CEILING`

## Diversity and collision preflight

The canonical farm database was opened read-only and returned
`quick_check=ok`. Its 37 pending `build_ea` rows produced these results through
the canonical build-claim guard:

| Disposition | Count |
|---|---:|
| Q02 excluded | 3 |
| Active blocked marker | 7 |
| Terminal final failure | 18 |
| Card missing | 2 |
| R1-R4 gate not ready | 5 |
| Mechanically eligible | 2 |

Neither eligible row is a valid fresh-build claim:

- `QM5_11483_williams-l-outside-bar-exhaustion-d1`, task
  `557db8df-51ab-4636-b361-58b314813f0b`, already has an MQ5, EX5, and 16
  completed farm work items through Q07. Its five Q02 rows are PASS. Rebuilding
  it from the legacy pending row would duplicate completed funnel work.
- `QM5_11657_pp-hs-rev`, task
  `593a9825-a8dc-462f-bdda-c00ddb710d58`, already has an MQ5, EX5, SPEC, and
  five H4 `RISK_FIXED=1000` backtest setfiles. Its task payload preserves an
  earlier CPU-ceiling deferral before smoke/Q02, and it has no work item yet.
  This is the next useful diversity handoff once capacity is genuinely free,
  not a new build target under the present ceiling.

No open `agent_tasks` claim was found. No farm or agent claim was taken.

## Binding capacity evidence

At the read, the farm had 2,227 pending and six active work items: five Q07
rows and one Q03 row. The active symbols were two FX rows
(`USDJPY.DWX` twice), two metals rows (`XAUUSD.DWX` twice), one index row
(`NDX.DWX`), and one energy row (`XTIUSD.DWX`).

The canonical `farmctl.py mt5-slots` census at `2026-08-21T07:05:41Z` found
five governed tester processes on T1, T2, T8, T9, and T10. SQLite subsequently
showed a sixth active claim on T5/Q03; it had not appeared in the earlier
process snapshot. The observations are reported separately rather than
pretended atomic.

A fresh five-sample Windows performance-counter window, at two-second
intervals, returned:

```text
99.95%, 100.00%, 99.90%, 99.76%, 100.00%
```

Average CPU was 99.92% and maximum CPU was 100.00%, both above the governed
97% hard ceiling. This independently binds the mission's explicit stop rule.

## Stop boundary and next action

No claim, card, EA, registry row, resolver, build check, compile, smoke, Q02
enqueue/re-enqueue, dispatcher tick, terminal reservation, or process-control
action was performed. No portfolio gate, deploy manifest, `T_Live` surface, or
AutoTrading state was touched.

When sustained CPU is below 97% and tester capacity is available, the next
paced wake should recheck ownership of `QM5_11657`, run its one standard smoke,
then record-build and enqueue the existing five-symbol H4 fixed-risk basket
exactly once. Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260821T070728Z_board_advisor.json`.
