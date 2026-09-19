# FX cointegration QM5_41471 Q04 path repair and CPU stop

Recorded: `2026-09-19T09:08:38Z` (`11:08:38` Europe/Berlin)

Branch: `agents/board-advisor`

Repair commit: `259d82d65d42dfe1310f57230488bdae376d1d54`

## Outcome

The frozen 66-pair FX cointegration frontier has no eligible unbuilt
relationship. Its two published positive-hedge survivors and five strict
sign-aware additions are already mechanized. The preferred anchors are not
Q02 setup blockers: `QM5_12532` has Q02 PASS / Q04 PASS / Q05 FAIL, and
`QM5_12533` has Q02 PASS / Q04 FAIL.

The selected existing-forex fallback is the D1 AUDUSD/EURJPY market-neutral
basket successor `QM5_41471_edgelab-audusd-eurjpy-cointegration-symfix`. It
has current Q02 and Q03 PASS evidence and one terminal Q04 infrastructure row:

| Phase | Work item | State |
| --- | --- | --- |
| Q02 | `26aaec94-02ee-4a71-9eed-68b624b45adc` | `done / PASS` |
| Q03 | `29572952-d18f-4efe-8e74-5fe5d16398b3` | `done / PASS` |
| Q04 | `fd6c5f93-f638-4307-b41a-ccb4599e9e32` | `done / INFRA_FAIL` |

The Q04 result is not an economic rejection. All three folds stopped before
tester launch with `FOLD_ERROR_FILENOTFOUNDERROR`. The injected setfile path
was 275 characters because the runner repeated the full logical-symbol plus
work-item identity beneath an already UUID-qualified work-item scratch root.

Commit `259d82d65d` keeps the full durable evidence identity but replaces the
duplicated scratch leaf with a stable 12-hex SHA-256 component. The same
production-shaped injected setfile path is now 209 characters. Scratch data
remains isolated per work item and the durable Q04 evidence layout is
unchanged.

Focused validation:

```text
python -m pytest framework/scripts/tests/test_q04_walkforward.py -q
34 passed
```

A broader 43-test Q04 selection produced 42 passes and one unrelated existing
SH-3 fixture failure in
`test_q02_completed_strategy_fail_is_not_retried`: its temporary SQLite table
does not admit the canonical `strategy` taxonomy. The new path regression test
passed.

## PACER build guard

No `.mq5` source was generated or edited and no compile command was enqueued.
The existing QM5_41471 source was nevertheless checked with the binding audit
command and returned exit 0, `ok=true`, and zero
`EA_FRAMEWORK_INPUT_PINNED` findings. Its logical backtest set remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Artifact bindings:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `16ea2f16fc5675a077e207aec0d0626150ffb6f481670b37c87a3f8b4271f783` |
| EX5 | `cdfb4f0212bf6e50d7e8a402877d185e184664c168167afd28970fbd2456de43` |
| basket manifest | `5f625eda561429d434f53e25201f380a66b42c19d56f74296bda86815910e887` |
| logical backtest set | `d78f0820bfcc6ddb0c83d0ed78b5f4a99032f60db1fbc6312ef790927bacfef6` |

## Binding CPU stop

Immediately before the governed append-only Q04 enqueue, five fresh whole-host
CPU samples were taken two seconds apart:

```text
82.531484%
99.611995%
91.635728%
77.785338%
83.525684%
```

Average CPU was `87.018046%`; maximum CPU was `99.611995%`. Because the
mission's backtest CPU ceiling binds when any sample reaches 97%, the enqueue
was refused. A final live query confirmed QM5_41471 has no pending or active
work item. No Q04 successor, priority mutation, dispatch tick, tester launch,
terminal reservation, or compile work was created.

The next safe action after capacity clears is one append-only Q04 successor
from Q03 PASS `29572952-d18f-4efe-8e74-5fe5d16398b3`, preserving infrastructure
row `fd6c5f93-f638-4307-b41a-ccb4599e9e32`, with the current EX5 hash above.

## Safety

- No Strategy Card, EA source/binary, setfile, basket manifest, registry, magic
  row, work-item row, verdict, priority, or hold was changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface was touched.
- No `T_Live` manifest, terminal, deploy artifact, AutoTrading state, or live
  artifact was touched.
- Existing unrelated shared-worktree changes were preserved and excluded from
  both commits.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_41471_q04_path_repair_cpu_stop_20260919T090838Z_board_advisor.json`.
