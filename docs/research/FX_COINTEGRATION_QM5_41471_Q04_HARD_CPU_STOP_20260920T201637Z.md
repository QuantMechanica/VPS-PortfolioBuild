# FX cointegration QM5_41471 Q04 hard CPU stop

Recorded: `2026-09-20T20:16:37Z` (`22:16:37` Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `92d69ee487a725974f635b2e834fc6843367156e`

## Selection and current state

The frozen 66-pair FX cointegration scan remains exhausted. Its two published
positive-hedge survivors and all five strict sign-aware additions are already
mechanized, so creating a new card would duplicate the governed frontier.

The preferred anchors are not Q02 setup blockers:

| EA | Current authenticated chain |
| --- | --- |
| `QM5_12532` | Q02 PASS / Q04 PASS / Q05 FAIL |
| `QM5_12533` | Q02 PASS / Q04 FAIL |

The dependency-correct existing-forex fallback remains the repaired D1
AUDUSD/EURJPY market-neutral basket
`QM5_41471_edgelab-audusd-eurjpy-cointegration-symfix`:

| Phase | Work item | State |
| --- | --- | --- |
| COMPILE_EA | `8250ae30-c5c6-43be-baa1-9c342c939ea4` | `done / COMPILE_OK` |
| Q02 | `26aaec94-02ee-4a71-9eed-68b624b45adc` | `done / PASS` |
| Q03 | `29572952-d18f-4efe-8e74-5fe5d16398b3` | `done / PASS` |
| Q04 | `fd6c5f93-f638-4307-b41a-ccb4599e9e32` | `done / INFRA_FAIL` |

The terminal Q04 row is the pre-launch `FOLD_ERROR_FILENOTFOUNDERROR` path
failure repaired by commit `259d82d65d42dfe1310f57230488bdae376d1d54`.
There is still no pending or active QM5_41471 successor. The fresh canonical
query found nine active factory jobs globally: two OPT_CENSUS, four Q02, two
Q03, and one Q04, occupying T1, T2, T3, T4, T6, T7, T8, T9, and T10.

## PACER build guard

No `.mq5` source was generated or edited and no enqueue-compile command was
issued. The selected existing source was checked read-only:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_41471_edgelab-audusd-eurjpy-cointegration-symfix/QM5_41471_edgelab-audusd-eurjpy-cointegration-symfix.mq5"
```

It returned exit 0, `ok=true`, and zero `EA_FRAMEWORK_INPUT_PINNED` findings.
The logical backtest set remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

Artifact bindings remain unchanged:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `16ea2f16fc5675a077e207aec0d0626150ffb6f481670b37c87a3f8b4271f783` |
| EX5 | `cdfb4f0212bf6e50d7e8a402877d185e184664c168167afd28970fbd2456de43` |
| basket manifest | `5f625eda561429d434f53e25201f380a66b42c19d56f74296bda86815910e887` |
| logical backtest set | `d78f0820bfcc6ddb0c83d0ed78b5f4a99032f60db1fbc6312ef790927bacfef6` |

## Binding CPU stop

Immediately before the intended append-only Q04 successor enqueue, five fresh
whole-host CPU samples were taken two seconds apart:

```text
96.294829%
99.708232%
99.030359%
99.414420%
97.754803%
```

Average CPU was `98.440529%`; maximum CPU was `99.708232%`. The mission's
backtest CPU ceiling binds when any sample reaches 97%, so the ceiling is hard
active. Free physical memory was `27.147 GiB` of `63.120 GiB`.

No Q04 successor, Q02 row, priority mutation, dispatch tick, tester launch,
terminal reservation, or compile work was created. The next safe action after
capacity clears remains one append-only Q04 successor from Q03 PASS
`29572952-d18f-4efe-8e74-5fe5d16398b3`, preserving infrastructure row
`fd6c5f93-f638-4307-b41a-ccb4599e9e32` and the current EX5 binding above.

## Safety

- No Strategy Card, EA source/binary, setfile, basket manifest, registry,
  magic row, work-item row, verdict, priority, or hold was changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface was touched.
- No `T_Live` manifest, terminal, deploy artifact, AutoTrading state, or live
  artifact was touched.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_41471_q04_hard_cpu_stop_20260920T201637Z_board_advisor.json`.
