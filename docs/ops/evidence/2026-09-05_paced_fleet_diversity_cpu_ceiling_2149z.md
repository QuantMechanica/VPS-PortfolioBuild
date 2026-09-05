# Paced Fleet Diversity — Current-State Correction and CPU Ceiling Stop

Date: `2026-09-05T21:49:05Z`

Branch: `agents/board-advisor`

Outcome: `NO CLAIM; NO BUILD; NO COMPILE; NO SMOKE; NO Q02 ENQUEUE — BACKTEST CPU CEILING`

## Diversity-first selection and collision check

The canonical farm database at
`D:/QM/strategy_farm/state/farm_state.sqlite` was inspected read-only before
any task, EA, registry, or queue mutation.

The pending-build surface is not a clean greenfield backlog. It contains 85
pending `build_ea` rows, of which 41 pass the shared read-only
`_build_task_claim_guard`. The apparent highest-priority FX row,
`QM5_11483_williams-l-outside-bar-exhaustion-d1`, is not valid new build work:
it already has five Q02 PASS rows and reached Q07. Rebuilding or re-enqueueing
it would duplicate completed pipeline work.

The previously documented FX fallback,
`QM5_41011_tokyo-london-bank-flow-handover`, was also revalidated rather than
blindly resumed. Its pending build row
`3245e4d6-da72-4d7e-bfb6-c35abe2cb5f3` still names the three-JPY-pair universe
`EURJPY.DWX`, `GBPJPY.DWX`, and `USDJPY.DWX`, but the pipeline has already
advanced since the 2026-08-30 capacity-stop note:

| Phase | Work item | Symbol | Current verdict |
|---|---|---|---|
| `COMPILE_EA` | `0024abc6-5b34-4f4d-8c84-92e13a12755a` | — | `COMPILE_OK` |
| `Q02` | `0679b7fd-4466-4e58-8b76-03b0ee7291bb` | `USDJPY.DWX` | `PASS` |
| `Q04` | `eac1f249-a169-4858-ba2d-9d58e6024e21` | `USDJPY.DWX` | `FAIL` |

Therefore `QM5_41011` is no longer a built-but-stuck Q02/Q03 infrastructure
repair candidate. No claim was taken and no duplicate Q02 row was created.
Its current source and binary remain bound to the repaired hashes:

- MQ5 SHA-256: `19eda5c89b952f0e9a0f8f0bdac05387c5bfe14be5332296d3ad1395e0e6d3b7`
- EX5 SHA-256: `3b6d6a604cb1025b175d826b688fd85875bc83809388bfc0f49f706d221cfc36`

All three canonical backtest presets still declare `RISK_FIXED=1000` and
`RISK_PERCENT=0`.

## Binding CPU stop

Five consecutive whole-host processor samples immediately before any
CPU-bearing action were:

```text
90, 96, 91, 97, 91 percent
```

Average CPU was `93.0%`; maximum CPU was `97.0%`. The paced-fleet ceiling is
binding when either value is at least 97%, so the mission's explicit stop rule
fired.

The same read-only `farmctl mt5-slots` census found governed tester processes
active on `T2`, `T3`, `T4`, `T5`, and `T8`. The farm rows visible in that
snapshot included Q07 and OPT_CENSUS work; no duplicate workers or orphaned
terminal processes were reported.

## Safety boundary and next action

No farm task or work item was claimed, mutated, or enqueued. No EA source,
binary, setfile, registry, portfolio gate, deploy manifest, or live manifest
was changed. No tester was launched or interrupted. `T_Live` and AutoTrading
were not touched.

The next below-ceiling paced wake must repeat the canonical DB collision check
and choose a genuinely stranded diverse Q02/Q03 INFRA lineage. It must not use
the stale 2026-08-30 description of `QM5_41011` as proof that the EA is still
waiting for its first Q02 handoff.
