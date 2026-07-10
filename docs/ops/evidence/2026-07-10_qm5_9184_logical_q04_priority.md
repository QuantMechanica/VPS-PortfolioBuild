# QM5_9184 Logical Q04 Priority Track — 2026-07-10

Scope: branch `agents/board-advisor`; no `T_Live`, AutoTrading, deploy
manifest, portfolio-admission, portfolio KPI, or Q08-contribution changes.

## Decision

The strict 66-pair scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` has only two published
survivors:

| EA | Pair | Current state |
|---|---|---|
| `QM5_12532` | `AUDUSD.DWX` / `NZDUSD.DWX` | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | `EURJPY.DWX` / `GBPJPY.DWX` | Q02 PASS, Q04 FAIL |

Neither is Q02-blocked. A de-duplication check found 20 approved card
filenames matching `cointegration` or `coint`, all 20 with matching
`framework/EAs` directories. No reputable-source, approved, allocated,
unbuilt FX pair remains locally, so creating another card or EA would be
duplicate work and would violate the card/build approval boundary.

The non-duplicate fallback is the existing `QM5_9184` AUDUSD/NZDUSD
cointegration basket. Its logical-basket Q02 work item
`f10fcf97-b4fb-4286-9188-d51415c8fb60` completed PASS at
`2026-07-10T01:05:05Z`, after which the farm created exactly one logical Q04
row. This change priority-tracks that existing row; it does not enqueue or
dispatch another test.

## Queue Change

Database backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_9184_q04_priority_20260710T013131Z.sqlite`

| Field | Value |
|---|---|
| Work item | `0b1e3b58-95c0-4f94-8849-0c6f5d3040d0` |
| EA | `QM5_9184_jstm-pair-cointegration-fx` |
| Phase | `Q04` |
| Logical symbol | `QM5_9184_AUDUSD_NZDUSD_COINTEGRATION_D1` |
| Host | `AUDUSD.DWX`, D1 |
| Basket legs | `AUDUSD.DWX`, `NZDUSD.DWX` |
| Status after | `pending` |
| `priority_track` before / after | absent / `true` |
| Pending/active duplicate count after | `1` |

The existing payload now records the OWNER forex-portfolio reason,
`priority_updated_at_utc=2026-07-10T01:31:31Z`, and
`priority_updated_by=codex/agents-board-advisor`. The queue snapshot placed
this work item first in `queued_top`.

## Validation

The logical backtest setfile is
`framework/EAs/QM5_9184_jstm-pair-cointegration-fx/sets/QM5_9184_jstm-pair-cointegration-fx_QM5_9184_AUDUSD_NZDUSD_COINTEGRATION_D1_D1_backtest.set`.
It declares backtest `risk_mode: FIXED`, `RISK_FIXED=1000`, and
`RISK_PERCENT=0`.

Results:

- FX basket manifest tests: PASS, 14 tests.
- Symbol-scope validation: `BASKET_OK`, 0 violations.
- Spec validation: PASS.
- No-compile build check: PASS, 0 failures, 0 warnings.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260710_013057.json`.
- Queue duplicate guard: exactly one pending/active row for the logical Q04
  key.

## CPU Ceiling and Guardrails

At the post-change snapshot, the farm had seven active work items, all Q02,
claimed by `T1`, `T2`, `T3`, `T4`, `T6`, `T7`, and `T8`. Per the mission stop
condition, no manual MT5 backtest, dispatch tick, or extra work item was
launched.

`T_Live` and AutoTrading were not touched. No portfolio gate,
`portfolio_admission`, portfolio KPI, Q08 contribution, or T_Live manifest was
read for mutation or changed.

Machine-readable companion:
`artifacts/qm5_9184_logical_q04_priority_20260710T013131Z.json`.
