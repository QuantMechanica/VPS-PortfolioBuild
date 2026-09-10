# FX funnel fallback: QM5_41335 Q07 enqueue and CPU-ceiling stop

Recorded: 2026-09-10T18:55:30Z (20:55 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `e9c00e1bf4c6b9fb5f63df6362df388e3f7c2929`

## Outcome

No duplicate Strategy Card or EA was created. The frozen sign-aware 66-pair
FX cointegration scan remains fully mechanized, as recorded by
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`.
The preferred anchors have no Q02 setup defect to repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, then
  terminal Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS`, then terminal
  Q04 `FAIL`.

The authorized existing-forex fallback therefore advanced
`QM5_41335_fx-usd-exhaustion-reversal-opt` on `AUDUSD.DWX` D1. Its Q06 row
`20341cb3-786b-4485-9750-73fc6a81dba6` completed `PASS` at
2026-09-10T18:49:59Z with PF `1.21`, 92 trades, `5.54711%` drawdown, and the
authenticated harsh rejection probability `0.1`.

Exactly one Q07 successor was appended from that terminal predecessor:

`25e274d5-3cb6-4382-ac9b-87f04b6c2857`

At verification it was pending, unclaimed, attempt zero, verdict-null,
hold-free, and already carried `priority_track=true`. A direct exact-identity
check found one and only one open Q07 row for this EA and symbol. No dispatch
tick or tester launch was performed.

## PACER guard and bindings

No MQ5 was generated or edited and no compile work was enqueued. The existing
source passed the binding framework-input-pin audit immediately before the
Q07 cascade:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_41335_fx-usd-exhaustion-reversal-opt/QM5_41335_fx-usd-exhaustion-reversal-opt.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

The canonical backtest setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. Bound hashes are:

- MQ5: `d7eec6373be1b7b865902cd8420b2a3fe305c7a7e026603e9baef9e32ee1e7bc`
- EX5: `f17045107715b1ee127011f14ee60ad36e6ad23e8dbfc372819a27d4bb596280`
- baseline setfile: `6ed5b4fe7549362276fa8812bcbf9450f6aca2b3b03fd169336a89799874bd47`
- Q06 aggregate: `47f103fa2c24cf1ca08b2f924ae80f8eb1cdeb969cbbc2859e3a4f361e53f2c7`

## Narrow intake-validator repair

The first-Q02 intake validator previously required every
`basket_manifest.json` dependency to have a traded compile symbol and magic
row. That incorrectly rejects manifests which explicitly divide their full
dependency set into `execution_symbols` and read-only `signal_only_symbols`.
The validator now compares compile symbols only with the explicit execution
role while requiring the two disjoint roles to cover the full basket and the
host to be executable. Manifests without explicit execution roles retain the
old exact-match rule. The focused regression suite passed: `21 passed`.

This repair did not bypass QM5_41141's separate review-entry gate; its Q02 was
not enqueued.

## Binding CPU-ceiling stop

The pre-enqueue five-sample CPU window was `64.267%`, `58.989%`, `57.814%`,
`69.062%`, and `69.775%` (average `63.981%`, maximum `69.775%`).

The immediate post-enqueue window was `99.707%`, `99.805%`, `99.024%`,
`99.805%`, and `98.731%` (average `99.414%`, maximum `99.805%`). This crossed
the binding 97% backtest CPU ceiling. Free physical memory was `42.214 GiB`.
All further queue, dispatch, tester, and terminal activity stopped at that
point; the pending Q07 row was left for the resident paced worker.

## Safety

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No `T_Live` manifest, terminal, AutoTrading state, or live artifact changed.
- No EA source, EX5, setfile, registry row, or magic row changed.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this commit.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_41335_q07_enqueue_cpu_stop_20260910T185530Z_board_advisor.json`.
