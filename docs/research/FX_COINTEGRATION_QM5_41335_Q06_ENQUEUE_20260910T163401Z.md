# FX funnel fallback: QM5_41335 Q06 enqueue

Recorded: 2026-09-10T16:34:48Z (18:34 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `754546e68b13b7579bd2d48687510e384d97990d`

## Outcome

No unbuilt pair was created. The frozen sign-aware 66-pair FX cointegration
frontier remains fully represented: the reconciliation checked 16 approved
next-best cards, found all 16 matching EA directories, and found no unbuilt
approved identity. Creating another card, EA, compile row, or Q02 row would
duplicate governed work.

The preferred anchors do not have the Q02 setup defects named in the mission:

- `QM5_12532` AUDUSD/NZDUSD has Q02 `PASS`, Q04 `PASS`, then terminal Q05
  `FAIL`.
- `QM5_12533` EURJPY/GBPJPY has Q02 `PASS`, then terminal Q04 `FAIL`.

The authorized fallback therefore advanced the existing structural,
low-frequency FX card `QM5_41335_fx-usd-exhaustion-reversal-opt` on
`AUDUSD.DWX` D1. Its Q05 row
`5b046970-f847-42c6-a3df-77b2d5ec11bc` completed `PASS` with PF `1.15`, 99
trades, and `5.14103%` drawdown.

Exactly one Q06 successor was enqueued from that authenticated predecessor:

`20341cb3-786b-4485-9750-73fc6a81dba6`

Verification found it pending, unclaimed, at attempt zero, without a verdict,
and already `priority_track=true`. It is the sole open Q06 row for the exact
EA/symbol identity. No dispatch tick or tester launch was performed.

## PACER guard and risk binding

No MQ5 was generated or changed and no compile work was enqueued. The existing
source was nevertheless checked before the queue mutation:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_41335_fx-usd-exhaustion-reversal-opt/QM5_41335_fx-usd-exhaustion-reversal-opt.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

The canonical backtest setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. Bound hashes are:

- MQ5: `d7eec6373be1b7b865902cd8420b2a3fe305c7a7e026603e9baef9e32ee1e7bc`
- EX5: `f17045107715b1ee127011f14ee60ad36e6ad23e8dbfc372819a27d4bb596280`
- baseline setfile: `6ed5b4fe7549362276fa8812bcbf9450f6aca2b3b03fd169336a89799874bd47`
- Q05 aggregate: `b16386bb33283b9c515e4a3869517221a8c459df31595f094cd9c4f485b05096`

## Capacity

The five pre-enqueue CPU samples were `31.19%`, `27.93%`, `27.36%`, `27.29%`,
and `26.77%` (average `28.108%`, maximum `31.19%`). The five post-enqueue
samples were `57.94%`, `52.41%`, `42.59%`, `42.19%`, and `42.39%` (average
`47.504%`, maximum `57.94%`). Neither window reached the binding 97% ceiling.

## Safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry row, or
  magic row changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this commit.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_41335_q06_enqueue_20260910T163401Z_board_advisor.json`.
