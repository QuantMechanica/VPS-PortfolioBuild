# QM5_12624 FX Cointegration Q02 Priority Payload Repair

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

The controlling 66-pair scan (`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`)
has no unbuilt strict-threshold FX cointegration survivor beyond `QM5_12532`
and `QM5_12533`; both now have logical-basket Q02 `PASS` rows. I used the
mission fallback and advanced an existing next-best FX basket: `QM5_12624`
`EURJPY.DWX` / `AUDJPY.DWX`.

`QM5_12624` already had one non-duplicate pending Q02 row after the news-off
setfile repair:

| Field | Value |
|---|---|
| Work item | `f346f9e9-7dc9-4cff-be60-4dec96784e77` |
| EA | `QM5_12624` |
| Logical symbol | `QM5_12624_EURJPY_AUDJPY_COINTEGRATION_D1` |
| Status before | `pending` |
| Setfile | `framework/EAs/QM5_12624_edgelab-eurjpy-audjpy-cointegration/sets/QM5_12624_edgelab-eurjpy-audjpy-cointegration_QM5_12624_EURJPY_AUDJPY_COINTEGRATION_D1_D1_backtest.set` |

No new work item was inserted.

## Mutation

Backed up SQLite before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12624_priority_payload_20260628_191658Z.sqlite`

Updated only the existing pending row payload:

- Added `priority_track=true`.
- Added `priority_reason=fx_market_neutral_basket_diversity_q02_payload_parity_2026-06-28`.
- Added durable `basket_symbol_count=2`.
- Preserved `portfolio_scope=basket`, host `EURJPY.DWX`, `tester_currency=JPY`,
  `tester_deposit=15000000`, `risk_fixed=150000`, and `timeout_min=120`.
- Cleared stale runtime claim keys left from a prior released claim (`pid`,
  `started_at_iso`, `claimed_at_iso`, `claimed_by_worker_pid`, `terminal`,
  `log_path`, `report_root`, and related run-stage fields).

The DB row remained `pending`, `claimed_by=NULL`, with no active duplicate.

## Verification

Read-back from `D:/QM/strategy_farm/state/farm_state.sqlite`:

| Check | Result |
|---|---|
| Target status | `pending` |
| Pending/active duplicates for same EA/phase/logical symbol | `1` |
| Stale runtime payload keys present | `[]` |
| Priority pending basket Q02 order | `QM5_12624` before `QM5_12751` |

The paced worker fleet owns execution from this row; no manual MT5 run was
launched.
