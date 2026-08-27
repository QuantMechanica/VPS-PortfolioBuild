# QM5_41011 FX diversity compile handoff — hard CPU-ceiling stop

Date: 2026-08-27 02:00 UTC

Branch: `agents/board-advisor`

Outcome: `TARGET_IDENTIFIED; NO MUTATION — HARD HOST-CPU CEILING`

## Highest-value non-duplicate target

The approved build backlog and diverse-instrument infrastructure frontier were
read before any farm mutation. The next valid target is
`QM5_41011_tokyo-london-bank-flow-handover`, a structural M15 FX session-range
handover strategy for `EURJPY.DWX`, `GBPJPY.DWX`, and `USDJPY.DWX`.

The approved Strategy Card is
`strategy-seeds/cards/approved/QM5_41011_tokyo-london-bank-flow-handover.md`.
It has OWNER-authorized `g0_status: APPROVED`, active deterministic magic rows,
three fixed-risk backtest presets, and no banned or ML indicator dependency.
The mechanic is a low-frequency Tokyo-to-London liquidity-handover breakout,
so it advances the requested FX diversity rather than adding another
index/metal/energy build.

No newer unbuilt forex or crypto card was eligible under the standard build
preflight: the observed new-card candidates did not yet have active allocated
magic rows. Existing nominal backlog rows with completed Q02/Q04 history were
rejected as duplicate builds.

## Exact blocked handoff

The card-faithful source repair already exists in commit `f8f772c3c`. The
repository artifacts are internally stale at this handoff:

| Artifact | SHA-256 |
|---|---|
| current MQ5 | `19eda5c89b952f0e9a0f8f0bdac05387c5bfe14be5332296d3ad1395e0e6d3b7` |
| older EX5 | `7a9dcbbc0de4f62ae7f8d2b0c46752f704fa005ee319562fda34c404de20e0a3` |

The canonical compile work item is singular and unclaimed:

- work item: `38660d91-9dc6-4e3d-a71e-0f4369dd12a5`;
- phase: `COMPILE_EA`;
- status: `pending`;
- activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`;
- bound source SHA-256: the current MQ5 hash above; and
- governed set targets: the three JPY-cross M15 backtest presets, each with
  `RISK_FIXED=1000` and `RISK_PERCENT=0`.

`farmctl compile-status` reported one pending, one activation-held, zero
active, zero compiled, and zero failed rows. The exact-ID governed release
utility can release this hold through the normal terminal-worker path; it was
deliberately not run in this slot.

## Binding capacity stop

A five-sample whole-host processor check immediately before the 02:00 UTC farm
snapshot returned:

```text
100.0000
100.0000
88.3966
88.6859
96.8144
```

The average was approximately `94.78%` and the maximum was `100%`. The farm's
explicit hard host-CPU ceiling binds when any sample exceeds `97%`, independent
of the terminal-count ceiling. The subsequent read-only `farmctl mt5-slots`
snapshot at `2026-08-27T02:00:51Z` found three active governed tester roots
(`T1`, `T6`, and `T10`); `T_Live` and the unrelated FTMO terminal were observed
only so they could be excluded.

Per the mission stop condition, this slot did not release or claim the compile
work item, run MetaEditor, launch a smoke/backtest, enqueue Q02, tick a worker,
or alter the farm database.

## Capacity-clear continuation

After a fresh five-sample check stays at or below the hard ceiling, the next
paced slot should recheck the work-item CAS state and source hash, release only
work item `38660d91-9dc6-4e3d-a71e-0f4369dd12a5` through
`release_compile_wave.py --work-item-id`, and let a resident governed worker
compile it. On a strict 0-error/0-warning compile and passing targeted build
check, record the completed build through `farmctl record-build` so the three
fixed-risk Q02 targets are enqueued once. It must not create a second compile
row or an ad-hoc Q02 duplicate.

No EA source, EX5, Strategy Card, setfile, registry, resolver, portfolio gate,
portfolio or deploy manifest, `T_Live` path, or AutoTrading state was changed.
