# FX cointegration QM5_12507 paced CPU stop

Recorded: 2026-09-11T18:45:47Z (20:45 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `2c956f5703a2b2f06b22cb5e57a037737762c36c`

## Outcome

The requested 66-pair sign-aware FX cointegration frontier remains fully
mechanized: all 66 relationships are covered and no unbuilt relationship is
available. A new Card, EA, basket manifest, registry identity, compile row, or
Q02 row would duplicate governed work.

The preferred anchors do not need Q02 setup repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has canonical Q02 `PASS`, then Q04
  `PASS` and Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has canonical Q02 `PASS`, then
  Q04 `FAIL`.

The concrete existing-forex fallback remains the EURUSD/GBPUSD H1
market-neutral basket `QM5_12507_pair-coint-z`. Its exact logical Q02 row
`547c4fd3-f3fd-4c59-b9dc-654e96521251` was reread as pending, unclaimed,
attempt zero, and verdict-free. Because that identity already exists exactly
once, no duplicate enqueue or requeue was performed.

The previous single-symbol fallback `QM5_41335` is no longer eligible to
advance: its Q08 row `ca09ce75-f7c9-4bea-b19b-19a77850b032` is terminal
`FAIL_HARD`. Separately, the existing market-neutral basket `QM5_12778`
reached Q09 `PASS`; this run only observed that result and did not duplicate
it.

## PACER guard and bindings

No MQ5 was generated or modified and no compile work was enqueued. The
selected source nevertheless passed the binding audit:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

The logical basket setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The checked artifacts remain hash-bound:

- MQ5: `569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`
- EX5: `b9baf4b48e02b9ced91b2d86d24b87245b595b506d1763b279e36bb9074ba4aa`
- basket manifest: `195cf0517e6e99649e0f40c259cea93e9af5a05cfc913fe901a33c39896fea56`
- logical setfile: `f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99`

## Binding capacity stop

Five one-second whole-host CPU samples were `69.857564%`, `64.563504%`,
`77.684763%`, `100.0%`, and `100.0%`. The average was `82.421166%` and the
maximum was `100.0%`, so the explicit 97% ceiling fired. Free physical memory
was `25.211 GiB` of `63.12 GiB`; the farm had five active and 7,545 pending
work items.

Per the mission contract, execution stopped before queue mutation, compile or
Q02 enqueue, dispatch, tester launch, terminal reservation, or terminal
control. The resident paced worker can consume the existing QM5_12507 row
after host admission recovers.

## Safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry, magic
  row, queue identity, claim, verdict, or priority state changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No deploy manifest, `T_Live`, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this commit.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_hard_cpu_stop_20260911T184547Z_board_advisor.json`.
