# QM5_12507 FX Cointegration Q04 Priority - 2026-07-09

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

The controlling scan remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`.

- Strict 66-pair survivors `QM5_12532` and `QM5_12533` are already built and no
  longer Q02-blocked.
- Approved cointegration-card de-dup check found 23 approved cointegration cards
  and 23 matching EA folders; no unbuilt approved FX cointegration card remains.
- The live fallback is `QM5_12507_pair-coint-z`, whose `basket_manifest.json`
  declares the `EURUSD.DWX`/`GBPUSD.DWX` H1 forex sleeve logical symbol
  `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1`.

## Queue Mutation

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Existing pending work item priority-marked:

| Field | Value |
|---|---|
| Work item | `f6242187-0a9c-46aa-8319-fd7aee20617c` |
| EA | `QM5_12507` |
| Phase | `Q04` |
| Symbol | `GBPUSD.DWX` |
| Logical symbol | `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` |
| Setfile | `framework/EAs/QM5_12507_pair-coint-z/sets/QM5_12507_pair-coint-z_GBPUSD.DWX_H1_backtest.set` |
| Status after | `pending` |
| Priority updated | `2026-07-09T01:47:59Z` |

Payload fields added:

- `priority_track=true`
- `priority_reason=OWNER 2026-07-09 forex portfolio mission: advance existing QM5_12507 EURUSD~GBPUSD cointegration FX sleeve to Q04 via existing pending GBPUSD row; no duplicate work_item and no manual MT5 dispatch under active CPU ceiling.`
- `priority_updated_by=codex/agents-board-advisor`

Duplicate guard after mutation:

- Pending/active rows for `(QM5_12507, Q04, GBPUSD.DWX)`: `1`
- New work items created: `0`

## Verification

`framework/scripts/mt5_queue_status.py --sqlite D:/QM/strategy_farm/state/farm_state.sqlite --limit 5`
reported the promoted row as first in `queued_top`.

Current farm saturation at verification:

- Active work items: `7`
- Pending work items: `5114`
- Factory tester processes observed: active `terminal64.exe`/`metatester64.exe`
  on the paced worker fleet
- Non-factory terminal processes present: FTMO and `C:/QM/mt5/T_Live/MT5_Base/terminal64.exe`

No manual MT5 dispatch was launched under the CPU-ceiling constraint.

## Guardrails

- `T_Live` not touched
- AutoTrading not touched
- `portfolio_admission`, portfolio KPI, and Q08 contribution files not touched
- No Q02 duplicate enqueue
- No portfolio-gate mutation
