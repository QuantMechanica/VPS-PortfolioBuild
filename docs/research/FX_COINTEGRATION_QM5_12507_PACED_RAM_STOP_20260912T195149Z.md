# FX cointegration QM5_12507 paced RAM-admission stop

Recorded: 2026-09-12T19:51:49Z (21:51:49 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `86295357fc107068dbc4f27722149c7c5bf260fd`

## Outcome

The 66-pair discovery frontier has no unbuilt relationship remaining. The two
published strict survivors are already built and past Q02: `QM5_12532`
(AUDUSD/NZDUSD) passed Q02 before failing Q05, while `QM5_12533`
(EURJPY/GBPJPY) passed Q02 before failing Q04. The mission's fallback clause
therefore applies.

The concrete non-duplicate fallback is the low-frequency EURUSD/GBPUSD H1
logical basket `QM5_12507_pair-coint-z`. Its exact canonical Q02 row already
exists once, remains pending and unclaimed at attempt 0, is on the priority
track, and has no active hold. A second enqueue would be duplicate work.

The existing row was not dispatched because its governed multi-symbol RAM
admission failed. Free RAM was `34.79 GiB`; the `heavy_or_unknown_multisymbol`
class requires a `44 GiB` reservation plus a `14 GiB` post-launch floor, or
`58 GiB` free. The shortfall was `23.21 GiB`. CPU was clear: five fresh
whole-host samples averaged `66.692%`, peaked at `78.063%`, and stayed below
the `97%` ceiling.

No compile enqueue, Q02 enqueue or requeue, dispatch tick, tester launch,
terminal reservation, or terminal control followed.

## Selected canonical row

| Field | Value |
| --- | --- |
| EA | `QM5_12507_pair-coint-z` |
| Pair | `EURUSD.DWX` / `GBPUSD.DWX` |
| Logical symbol | `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` |
| Work item | `547c4fd3-f3fd-4c59-b9dc-654e96521251` |
| State | `pending`, unclaimed, attempt 0, no verdict |
| Priority | `true` (`owner_2026-08-30_fx_portfolio_existing_logical_basket_fallback`) |
| Exact open identity count | 1 |
| Active holds | 0 |

Five rows were already active at admission: Q07 on T3 and T5, plus
`OPT_CENSUS` on T4, T6, and T7.

## PACER guard and package validation

No MQ5 source was generated or changed, so no compile command became eligible.
The selected source was nevertheless checked immediately before the admission
decision with the binding command:

`python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5`

It exited 0 with `EA_FRAMEWORK_INPUT_PINNED` hit count 0. The package also
returned `BASKET_OK` with zero symbol-scope violations, and its targeted basket
manifest test passed. The manifest declares four history symbols: EURUSD,
GBPUSD, NDX, and WS30.

Artifact hashes:

- MQ5: `569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`
- EX5: `b9baf4b48e02b9ced91b2d86d24b87245b595b506d1763b279e36bb9074ba4aa`
- basket manifest: `195cf0517e6e99649e0f40c259cea93e9af5a05cfc913fe901a33c39896fea56`
- logical setfile: `f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99`

The logical backtest setfile remains fixed-risk:
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Safe refusal and scope

An existing forex continuation (`QM5_12712`, Q10_NEWS) was considered, but the
canonical enqueue refused it without mutation because its Q08 evidence was
missing or unreadable. No evidence was fabricated and no gate was bypassed.

- No card, EA, EX5, setfile, basket manifest, registry, magic row, work-item
  state, priority, verdict, worker, or terminal changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
  T_Live manifest, AutoTrading state, or live deployment surface changed.
- Pre-existing unrelated shared-worktree changes were preserved and excluded
  from this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_paced_ram_stop_20260912T195149Z_board_advisor.json`.
