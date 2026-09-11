# FX cointegration QM5_12507 paced hard-CPU stop

Recorded: 2026-09-11T21:18:23Z (23:18 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `cf212b32ede650fe0831dcf6d15041e8587c4566`

## Outcome

The governed 66-pair FX cointegration frontier remains fully mechanized. All
66 relationships are represented by existing builds, so creating another
Strategy Card, EA identity, basket manifest, compile row, or Q02 row would be
duplicate work.

The two preferred anchors do not require Q02 infrastructure repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has canonical Q02 `PASS`, followed by
  Q04 `PASS` and Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has canonical Q02 `PASS`, followed
  by Q04 `FAIL`.

The concrete existing-forex fallback is therefore the EURUSD/GBPUSD H1
market-neutral sleeve `QM5_12507_pair-coint-z`. Its exact logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` remains pending, unclaimed, attempt zero,
verdict-free, and already `priority_track=true`. It is the only pending Q02 row
whose logical symbol contains `COINTEGRATION`, so no duplicate enqueue, requeue,
or priority mutation was performed.

## PACER guard and artifact bindings

No MQ5 was generated or modified and no compile work was enqueued. The selected
source nevertheless passed the binding audit:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

The logical basket setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The current artifacts remain hash-bound:

- MQ5: `569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`
- EX5: `b9baf4b48e02b9ced91b2d86d24b87245b595b506d1763b279e36bb9074ba4aa`
- basket manifest: `195cf0517e6e99649e0f40c259cea93e9af5a05cfc913fe901a33c39896fea56`
- logical setfile: `f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99`

## Binding capacity stop

Five whole-host CPU samples were `99.804810%`, `96.191528%`, `91.895451%`,
`76.367786%`, and `66.719920%`. Their average was `86.195899%` and their
maximum was `99.804810%`, so the mission's explicit 97% hard ceiling fired.
Free physical memory was also only `37.425 GiB` of `63.120 GiB`, below the
fleet's `58 GiB` heavy-multisymbol admission floor.

The farm had eight active and 7,342 pending work items, with seven factory MT5
terminals running (`T1`, `T4`, `T5`, `T6`, `T7`, `T8`, and `T9`). Per the
mission contract, execution stopped before queue mutation, compile or Q02
enqueue, dispatch, tester launch, terminal reservation, or terminal control.
The resident paced worker can consume the existing unique Q02 row after host
admission recovers.

## Safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry, magic
  row, queue identity, claim, verdict, or priority state changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No deploy manifest, `T_Live`, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this commit.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_hard_cpu_stop_20260911T211823Z_board_advisor.json`.

