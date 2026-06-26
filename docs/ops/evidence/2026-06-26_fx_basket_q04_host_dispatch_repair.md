# FX Basket Q04 Host Dispatch Repair - 2026-06-26

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` documents only two qualifying FX
cointegration pairs from the 66-pair scan:

- `QM5_12533` EURJPY/GBPJPY D1 cointegration basket.
- `QM5_12532` AUDUSD/NZDUSD D1 cointegration basket.

No third unbuilt pair met the documented threshold, so this cycle advanced the existing FX basket
path instead of creating a weaker duplicate card.

## Defect

`QM5_12532` had already passed logical-basket Q02, then failed its Q04 early probe with
`REPORT_MISSING`. The fold logs showed the runner launched MT5 on the logical basket symbol
`QM5_12532_AUDNZD_COINTEGRATION_D1`, which MT5 cannot select in Market Watch.

Basket Q02 already used `host_symbol`; Q04 real-phase dispatch did not.

## Fix

- `tools/strategy_farm/farmctl.py`: real phase runner command construction now resolves
  `host_symbol` / `host_timeframe` from work-item payload, or falls back to `basket_manifest.json`
  when the work-item symbol is the manifest logical symbol.
- `framework/scripts/q04_walkforward.py`: Q04 can receive `--logical-symbol`, run MT5 on the host
  symbol, and still write aggregate evidence under the logical basket symbol.
- `tools/strategy_farm/tests/test_cascade_real_phase_runners.py`: added a regression test proving
  Q04 basket dispatch sends `--symbol EURJPY.DWX` plus the logical label.

## Queue Action

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_pre_q04_basket_host_requeue_20260626183452.sqlite`

Repaired work item:

| EA | Work item | Phase | Logical symbol | Host symbol | New status |
|---|---|---|---|---|---|
| `QM5_12532` | `94f89f07-58ad-487f-a0ab-b57c4e99106a` | `Q04` | `QM5_12532_AUDNZD_COINTEGRATION_D1` | `AUDUSD.DWX` | `pending` |

The stale report root was archived to:

`D:/QM/reports/work_items/94f89f07-58ad-487f-a0ab-b57c4e99106a.requeued_20260626T1834520000`

Audit event inserted:

`q04_basket_host_symbol_requeue`

## Current State

- `QM5_12532` logical Q02: `PASS`.
- `QM5_12532` logical Q04: reset to `pending` with host metadata.
- `QM5_12533` logical Q02: active retry was already running on `T3`; it was not interrupted.
- A dispatch tick after the repair did not launch new work because `farmctl next` reports
  `repair_required` for multiple active sources. The repaired Q04 item remains visible as pending.

## Validation

- `python -m unittest tools.strategy_farm.tests.test_cascade_real_phase_runners`: PASS.
- `python -m unittest framework.scripts.tests.test_q04_walkforward`: PASS.
