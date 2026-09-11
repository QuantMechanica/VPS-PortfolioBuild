# FX cointegration QM5_12507 hard CPU stop

Recorded: 2026-09-11T14:02:10Z (16:02 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `1f3b437367380c2f34b435783b0cd4019dc99fef`

## Outcome

The frozen sign-aware 66-pair FX cointegration scan remains fully mechanized:
66 relationships are covered and zero are unbuilt. Creating another Card, EA,
registry identity, basket manifest, compile row, or Q02 row would duplicate
governed work.

The preferred anchors do not have a current Q02 setup defect:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, then
  terminal Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS`, then terminal
  Q04 `FAIL`.

The concrete nonterminal existing-forex fallback remains
`QM5_12507_pair-coint-z`, the EURUSD/GBPUSD H1 market-neutral basket. Its
canonical logical Q02 work item `547c4fd3-f3fd-4c59-b9dc-654e96521251` is
still pending, unclaimed, attempt zero, verdict-free, priority-tracked, and
without an active hold. It remains the single open logical Q02 identity. No
duplicate enqueue, requeue, priority mutation, payload rewrite, dispatch tick,
tester launch, or terminal control was performed.

## PACER guard and bindings

The existing source passed the binding framework-input-pin audit:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

No `.mq5` was generated or modified, so no compile command was required or
enqueued. Current artifact hashes are:

- MQ5: `569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`
- EX5: `b9baf4b48e02b9ced91b2d86d24b87245b595b506d1763b279e36bb9074ba4aa`
- basket manifest: `195cf0517e6e99649e0f40c259cea93e9af5a05cfc913fe901a33c39896fea56`
- logical setfile: `f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99`

The logical backtest setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## Binding capacity stop

Five one-second whole-host CPU samples were `99.707187%`, `100.000000%`,
`99.242753%`, `94.726521%`, and `92.680331%` (average `97.271358%`, maximum
`100.000000%`). Both the average and maximum met or exceeded the explicit 97%
ceiling, so the binding CPU stop fired.

Free physical memory was also only `31.542 GiB` of `63.120 GiB`, below the
repository's `58 GiB` heavy-multisymbol admission floor. Five work items were
active; four current factory MT5 children were observed on T5, T6, T7, and T8,
while `D:/QM/strategy_farm/state/launch_gate_max.txt` remained `1`. The active
T10 OPT_CENSUS claim had no current child in the path-anchored process snapshot;
this does not create admissible multisymbol capacity.

Per the mission's explicit ceiling rule, work stopped before Q02 enqueue or
requeue, dispatch tick, tester launch, terminal reservation, terminal control,
or compile. The unique existing Q02 row remains available to the resident paced
worker after host admission recovers.

## Safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry row, or
  magic row changed.
- No work-item status, verdict, priority, claim, payload, tester, reservation,
  or terminal process changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No `T_Live` manifest, terminal, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this commit.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_hard_cpu_stop_20260911T140210Z_board_advisor.json`.
