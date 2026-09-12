# FX cointegration paced CPU-ceiling stop

Recorded: 2026-09-12T18:15:38Z (20:15:38 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `728e13b4204b2c439c61f0cee49cb6151aa9e44d`

## Outcome

The binding host CPU ceiling fired before any compile or Q02 queue mutation was
eligible. Five fresh whole-host samples were `70.901%`, `69.565%`, `74.807%`,
`78.420%`, and `98.180%`: average `78.375%`, maximum `98.180%`. The maximum
exceeded the mission's 97% hard ceiling, so the stop was latched for this run.

No compile enqueue, Q02 enqueue or requeue, dispatch tick, tester launch,
terminal reservation, or terminal control followed.

## Non-duplicate routing result

The frozen 66-pair scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` has no unbuilt
relationship. Its published survivors are already built and past Q02:

- `QM5_12532` AUDUSD/NZDUSD has Q02 PASS and subsequently failed Q05.
- `QM5_12533` EURJPY/GBPJPY has Q02 PASS and subsequently failed Q04.

The selected existing-forex fallback remains the low-frequency EURUSD/GBPUSD
H1 logical basket `QM5_12507_pair-coint-z`. Its exact canonical Q02 identity is
present once and only once:

| Field | Value |
| --- | --- |
| Work item | `547c4fd3-f3fd-4c59-b9dc-654e96521251` |
| Logical symbol | `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` |
| State | `pending`, unclaimed, attempt 0, no verdict |
| Priority track | `true` |
| Exact open identity count | 1 |

Appending another Q02 row would be duplicate work. The existing governed row
was preserved for the resident paced workers.

## PACER guard and artifact bindings

No MQ5 source was generated or changed, and no compile command was enqueued.
Therefore the mandatory post-write/pre-compile pin-audit trigger did not arise.
The selected basket's package hashes were re-read without mutation:

- MQ5: `569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`
- EX5: `b9baf4b48e02b9ced91b2d86d24b87245b595b506d1763b279e36bb9074ba4aa`
- basket manifest: `195cf0517e6e99649e0f40c259cea93e9af5a05cfc913fe901a33c39896fea56`
- logical setfile: `f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99`

The logical backtest setfile remains bound to `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Capacity and safety snapshot

At admission time the farm contained five active rows: three `OPT_CENSUS`, one
Q02, and one Q07. Five factory terminals were running (`T3`, `T5`, `T6`, `T8`,
and `T9`). One active census row completed during the later read-only
reconciliation; that did not clear the already-latched CPU stop. No `T_Live`
terminal process was observed.

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No T_Live manifest, AutoTrading state, or live deployment artifact changed.
- No card, EA, EX5, setfile, basket manifest, registry, magic row, work-item
  state, priority, verdict, worker, or terminal changed.
- Pre-existing unrelated shared-worktree changes were preserved and excluded
  from this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_paced_cpu_stop_20260912T181538Z_board_advisor.json`.
