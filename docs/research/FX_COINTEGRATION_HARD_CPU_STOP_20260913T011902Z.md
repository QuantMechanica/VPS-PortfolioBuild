# FX cointegration fallback hard CPU stop

Recorded: 2026-09-13T01:19:02.7310341Z (2026-09-13 03:19 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `b1af0fd51a4e61c3cd273e4c7aa45622707ee1de`

## Outcome

The frozen 66-pair FX cointegration discovery is fully represented by existing
builds. Creating another scan-derived Strategy Card, EA identity, basket
manifest, compile row, or Q02 row would duplicate governed work. The two
preferred anchors are not blocked at Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, then Q05
  `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS`, then Q04 `FAIL`.

The selected existing-forex continuation was
`QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1`. Its authenticated chain has
Q02-Q07 PASS and current-contract Q09 PASS. The required Q08 regeneration is
already represented exactly once by work item
`b68d05cd-e52c-43a5-96aa-5e0306efa60f`: pending, unclaimed, attempt zero,
verdict-free, and `priority_track=true`. It was fifth in the canonical queue
snapshot. A second Q08 row would be duplicate work; Q10_NEWS cannot be validly
enqueued until this row produces readable Q08 evidence.

The prior Q02 fallback is also preserved exactly once. Work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` remains pending and unclaimed for
`QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1`, with attempt zero and no verdict.
No duplicate Q02 row was appended.

## PACER and artifact checks

No generated MQ5 source was written or edited and no compile command was
enqueued. A precautionary read-only execution of the binding input-pin audit
against the selected existing source returned exit zero, `ok=true`, and zero
`EA_FRAMEWORK_INPUT_PINNED` findings:

```powershell
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py `
  --check-source "C:/QM/repo/framework/EAs/QM5_12712_edgelab-eurgbp-euraud-cointegration/QM5_12712_edgelab-eurgbp-euraud-cointegration.mq5"
```

The canonical logical setfile remains fixed-risk with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Current hashes are:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `afdfd1a80dbfcd2c398ddc92dffe2181e5727f3837c37df2a772f25b68e171d1` |
| EX5 | `0003ed98f590e95a28a08e7d8198639b48213e882e8c5d2428cad4422355c982` |
| basket manifest | `a15214089f0efd8564a1ee6f2d6bb09164cde12d742ad8627fa1f7870d6e773a` |
| logical backtest set | `105a23da1d33d559cff4ff19a5e8c5c51e8a72eb6cec5b7f6a92ecedaea6208c` |

## Binding CPU stop

Five fresh whole-host samples taken two seconds apart were `96.778473%`,
`98.730946%`, `94.582030%`, `98.540062%`, and `98.442818%`. Average CPU was
`97.414866%` and maximum CPU was `98.730946%`. Both measures crossed the
binding 97% ceiling.

The concurrent farm snapshot contained seven active and 5,423 pending work
items. Free physical memory was 41.492 GiB of 63.120 GiB. After the ceiling
fired, no enqueue, requeue, claim, dispatch tick, tester launch, terminal
reservation, terminal control, compile, or backtest was attempted.

## Safety

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  path changed.
- No `T_Live` manifest, terminal, deploy artifact, AutoTrading state, or live
  artifact changed.
- No Card, EA source or binary, setfile, basket manifest, registry, magic row,
  farm task, work item, priority, claim, hold, or verdict changed.
- Unrelated shared-worktree changes were preserved and excluded from this
  evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_hard_cpu_stop_20260913T011902Z_board_advisor.json`.
