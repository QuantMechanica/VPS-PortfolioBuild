# FX cointegration paced CPU-ceiling stop

Recorded: 2026-09-12T14:00:54Z (16:00:54 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `a72e087e8c8c7bc89343da636f06a932ba378f0f`

## Outcome

The binding host CPU ceiling fired before any compile or Q02 queue mutation was
eligible. Five fresh whole-host samples were `100.000000%`, `95.327083%`,
`92.154041%`, `91.615050%`, and `81.837998%`: average `92.186834%`, maximum
`100.000000%`. The maximum exceeded the mission's 97% hard ceiling.

No compile enqueue, Q02 enqueue or requeue, dispatch tick, tester launch,
terminal reservation, or terminal control followed.

## Non-duplicate routing result

The frozen 66-pair scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` has no unbuilt
relationship. Its published survivors are already built and past Q02:

- `QM5_12532` AUDUSD/NZDUSD has Q02 PASS and subsequently failed Q05.
- `QM5_12533` EURJPY/GBPJPY has Q02 PASS and subsequently failed Q04.

The selected existing-forex fallback remains the EURUSD/GBPUSD H1 logical
basket `QM5_12507_pair-coint-z`. Its exact canonical Q02 identity is present
once and only once:

| Field | Value |
| --- | --- |
| Work item | `547c4fd3-f3fd-4c59-b9dc-654e96521251` |
| Logical symbol | `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` |
| State | `pending`, unclaimed, attempt 0, no verdict |
| Active holds | 0 |
| Priority track | `true` |
| Exact open identity count | 1 |

Appending another Q02 row would be duplicate work, so the existing governed
row was preserved for the resident paced workers.

## PACER guard and artifact bindings

No MQ5 source was generated or changed, and no compile command was enqueued.
Therefore the mandatory post-write/pre-compile pin-audit trigger did not arise.
The source and package hashes remain unchanged from the most recent successful
pin-audit evidence:

- MQ5: `569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`
- EX5: `b9baf4b48e02b9ced91b2d86d24b87245b595b506d1763b279e36bb9074ba4aa`
- basket manifest: `195cf0517e6e99649e0f40c259cea93e9af5a05cfc913fe901a33c39896fea56`
- logical setfile: `f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99`

The logical backtest setfile remains bound to `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Capacity and safety snapshot

At observation time the farm contained 4 active and 6,017 pending work items.
Three factory terminals were observed under `D:/QM/mt5/T1..T12` (`T6`, `T8`,
and `T10`). Two unrelated terminal processes were excluded. No `T_Live`
terminal process was observed, and no live surface was queried or controlled.

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No T_Live manifest, AutoTrading state, or live deployment artifact changed.
- No card, EA, EX5, setfile, basket manifest, registry, magic row, work-item
  state, priority, verdict, worker, or terminal changed.
- Pre-existing unrelated shared-worktree changes were preserved and excluded
  from this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_paced_cpu_stop_20260912T140054Z_board_advisor.json`.
