# FX Basket Q02 Timeout Alignment - 2026-06-26

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` documents only two FX cointegration
pairs from the 66-pair scan that cleared the stated build threshold:

- `QM5_12533` - `EURJPY/GBPJPY` D1 cointegration basket.
- `QM5_12532` - `AUDUSD/NZDUSD` D1 cointegration basket.

Because both qualifying pairs are already built, I advanced the existing Forex basket Q02 path
instead of creating a weaker duplicate card from below-threshold scan rows.

## Queue Action

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_pre_fx_basket_timeout_align_20260626_154643.sqlite`

Aligned the logical basket Q02 work-item payload metadata to the basket ceiling:

| EA | Work item | Symbol | Status at repair | `timeout_min` before | `timeout_min` after |
|---|---|---|---|---:|---:|
| `QM5_12533` | `fe14e345-8ea4-4fbd-a77d-831df5fedc51` | `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` | `active` on `T3` | 45 | 120 |
| `QM5_12532` | `e4890d77-b865-4a48-b946-315faefca920` | `QM5_12532_AUDNZD_COINTEGRATION_D1` | `pending` | null | 120 |

The active-row `updated_at` timestamps were restored after the payload update so active-run age
remains measured from the original worker claim time.

An audit event was inserted:

`fx_basket_q02_timeout_align`

## Current State

- `QM5_12533` is actively running Q02 as the logical EURJPY/GBPJPY basket on `T3`.
- `QM5_12532` remains pending as the logical AUD/NZD basket.
- No duplicate Q02 work item was inserted.
- No component-leg rows were revived.
