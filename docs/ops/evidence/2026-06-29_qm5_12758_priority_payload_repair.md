# QM5_12758 FX Cointegration Q02 Priority Payload Repair - 2026-06-29

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

`QM5_12532` and `QM5_12533` are no longer Q02-blocked; both have logical-basket
Q02 PASS rows in `D:/QM/strategy_farm/state/farm_state.sqlite`.

The strict 66-pair scan remains exhausted. A read-only rerun of the D1 scan
ranking found the next OOS-positive unbuilt pair after existing EdgeLab baskets
through `QM5_12758` is `GBPUSD.DWX` / `GBPJPY.DWX`, with DEV Sharpe `-0.26`,
OOS net Sharpe `0.10`, OOS return `+0.95%`, 17 OOS state changes, hedge `0.01`,
and 109-day half-life. It has no allocated cointegration registry row or magic
rows, so no new EA was created.

Per the mission fallback, this pass advanced the existing pending FX basket:
`QM5_12758` (`GBPUSD.DWX` / `EURAUD.DWX`).

## Mutation

Target work item:

| Field | Value |
|---|---|
| Work item | `0e925c0c-5a27-459c-86d2-cdaddd2b2e9f` |
| EA | `QM5_12758` |
| Logical symbol | `QM5_12758_GBPUSD_EURAUD_COINTEGRATION_D1` |
| Phase | `Q02` |
| Status before | `pending` |

Backed up SQLite before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12758_priority_payload_20260628_230248Z.sqlite`

Updated only the existing pending row payload:

- Added `priority_track=true`.
- Added `priority_reason=fx_market_neutral_basket_diversity_q02_payload_parity_2026-06-29`.
- Confirmed durable basket fields: `portfolio_scope=basket`, `basket_symbol_count=2`,
  `basket_symbols=["GBPUSD.DWX","EURAUD.DWX"]`, `tester_currency=USD`,
  `tester_deposit=100000`.
- Removed stale runtime claim keys defensively; none were required for a pending row.

Refreshed runtime worker hint file for older terminal workers:

`D:/QM/strategy_farm/state/multisymbol_eas.txt`

Backup:

`D:/QM/strategy_farm/state/backups/multisymbol_eas_before_qm5_12758_20260628_230316Z.txt`

`QM5_12758` is now present alongside `QM5_12751` and `QM5_12756`.

## Verification

Read-back from `D:/QM/strategy_farm/state/farm_state.sqlite`:

| Check | Result |
|---|---|
| Target status | `pending` |
| Target claimed_by | `NULL` |
| Pending/active duplicates for same EA/phase/logical symbol | `1` |
| `priority_track` | `true` |
| `portfolio_scope` | `basket` |
| `basket_symbol_count` | `2` |
| Runtime hint | `QM5_12758` present |

Priority pending basket order after mutation showed `QM5_12758` in the priority
Q02 basket group, behind `QM5_12624` and before later cooled-down baskets.

No duplicate Q02 row was inserted and no manual MT5 backtest was launched. The
paced worker fleet owns execution from this row.
