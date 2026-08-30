# QM5_41011 FX stale-EX5 recovery — Q02 handoff completed

Date: `2026-08-30`

Branch: `agents/board-advisor`

Outcome: `BUILD DONE; Q02 CANARY PENDING`

## Selection and collision guard

This is the capacity-clear continuation of build task
`3245e4d6-da72-4d7e-bfb6-c35abe2cb5f3`, previously stopped before smoke by
the binding CPU ceiling. The task remained pending and assigned to
`codex:agents/board-advisor`; no Q02/Q03 row and no sibling active task existed
when it was atomically resumed.

The higher-ranked `QM5_41005` candidate was rejected as duplicate work after
the governed compile classifier found its already-delivered stale EX5 and
source-hash-bound setfiles (`EX5_ALREADY_PRESENT`,
`BOUND_SETFILE_HASH_EXISTS`). That build task was closed `blocked`; no rebuild
guard or OWNER-scoped authority was bypassed.

## Governed build identity

The source repair and compile receipt remain those produced by governed work
item `0024abc6-5b34-4f4d-8c84-92e13a12755a`:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `19eda5c89b952f0e9a0f8f0bdac05387c5bfe14be5332296d3ad1395e0e6d3b7` |
| EX5 | `3b6d6a604cb1025b175d826b688fd85875bc83809388bfc0f49f706d221cfc36` |
| EURJPY M15 set | `273c571c2f0982e7266258277ac2bbb8cce2ab849beb9157072ca801150e0ed0` |
| GBPJPY M15 set | `cfc390dd3c6a41bd359a71f5d193292dfb6c44914abfc2324aa80d1bd61569c0` |
| USDJPY M15 set | `95cf26926ac449781eb3c815c8b7ac3374959c44521c009f0de8a3852d151f89` |

The compile evidence reports `COMPILE_OK`, build check `PASS`, and zero errors
and warnings. All three backtest presets retain `RISK_FIXED=1000` and
`RISK_PERCENT=0`.

## Capacity and one-pass smoke disposition

The fresh governed `GetSystemTimes` admission window sampled five two-second
whole-host CPU readings:

```text
60.0978
69.2345
81.7871
78.5540
91.1864
```

Average load was `76.1720%`; maximum load was `91.1864%`, below the hard
`97.0%` ceiling. The one permitted EURJPY 2024 smoke request was then made
with `-Terminal any -Period M15 -MinTrades 1 -SmokeMode`. The governed
resolver returned `status=no_capacity` before selecting a terminal, so no
tester process was launched and no retry was attempted. The build result
truthfully records the sanctioned `deferred_p2_smoke` saturation waiver at
`D:\QM\strategy_farm\artifacts\builds\3245e4d6-da72-4d7e-bfb6-c35abe2cb5f3.json`.

## Funnel handoff

`farmctl record-build` completed the build task and atomically enqueued one
staged Q02 canary:

| Work item | Symbol | Timeframe | Status |
|---|---|---|---|
| `0679b7fd-4466-4e58-8b76-03b0ee7291bb` | `USDJPY.DWX` | `M15` | `pending` |

The cohort policy deferred EURJPY and GBPJPY until the canary resolves; it did
not create duplicate rows.

## Verification

- `test_qm5_41011_rework_static.py`: `7 passed`.
- `validate_spec_doc.py`: `PASS`.
- `validate_build_guardrails.py --max-news-stale-hours 336`: `PASS`.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, zero findings.
- Farm DB: build task `done`; exactly one Q02 row, `pending`, attempt count `0`.

No Q02 backtest was manually dispatched. No portfolio gate, portfolio or
deploy manifest, `T_Live` path, AutoTrading state, or live terminal was
touched.
