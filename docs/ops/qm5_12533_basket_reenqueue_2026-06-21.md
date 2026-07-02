# QM5_12533 Basket Re-Enqueue Triage

Task: `1d6986db-721f-47d7-8f23-96c23f8d8e1f`

Date: 2026-06-22

## Verdict

Fresh Q02 basket enqueue was not performed. The live `farmctl enqueue-backtest` gate correctly refused the only `QM5_12533` predecessor review because it is still recorded as `REJECT_REWORK`, not `APPROVE_FOR_BACKTEST`.

This task should not be force-enqueued by direct DB edits. The next valid action is to create or record a real approving EA review after the basket fix is reviewed, and to add the logical basket setfile expected by the basket enqueue helper.

## Evidence

- Live factory checkout has the EA directory:
  - `C:/QM/repo/framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration`
- Live factory checkout has a basket manifest:
  - `C:/QM/repo/framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration/basket_manifest.json`
  - `logical_symbol`: `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`
  - `host_symbol`: `EURJPY.DWX`
  - `host_timeframe`: `D1`
  - `basket_symbols`: `EURJPY.DWX`, `GBPJPY.DWX`
- Existing `QM5_12533` Q02 work items are terminal:
  - `Q02 done INFRA_FAIL`: 1 EURJPY.DWX row
  - `Q02 failed INFRA_FAIL`: 12 EURJPY.DWX rows
  - `Q02 done FAIL`: 1 GBPJPY.DWX row
  - `Q02 failed INFRA_FAIL`: 12 GBPJPY.DWX rows
  - active/pending rows: 0
- Supported live enqueue command result:

```json
{
  "enqueued": false,
  "reason": "Review verdict was 'REJECT_REWORK', not APPROVE_FOR_BACKTEST"
}
```

Command:

```powershell
python C:\QM\repo\tools\strategy_farm\farmctl.py enqueue-backtest --review-task-id 6580e4b3-9b1f-4a70-a389-e87a41ce1b05 --phase Q02
```

## Gate Blockers

1. `tasks.id=6580e4b3-9b1f-4a70-a389-e87a41ce1b05` is the only `QM5_12533` `ea_review` predecessor found in `D:/QM/strategy_farm/state/farm_state.sqlite`, and its verdict is `REJECT_REWORK`.
2. The basket enqueue helper in `C:/QM/repo/tools/strategy_farm/farmctl.py` requires `APPROVE_FOR_BACKTEST` for Q02.
3. The helper expects a logical basket setfile named like:

```text
C:/QM/repo/framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration/sets/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration_QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1_D1_backtest.set
```

That file does not currently exist. The available setfiles are still per-leg:

- `QM5_12533_edgelab-eurjpy-gbpjpy-cointegration_EURJPY.DWX_D1_backtest.set`
- `QM5_12533_edgelab-eurjpy-gbpjpy-cointegration_GBPJPY.DWX_D1_backtest.set`

The host `EURJPY.DWX` setfile uses compliant backtest risk settings:

```text
RISK_FIXED=1000
RISK_PERCENT=0
qm_magic_slot_offset=0
```

## QM5_12532 Q04 Check

`QM5_12532` has one Q04 work item:

- work item: `dcfcfe4c-3948-4836-a7d5-ea814148bb30`
- symbol: `NZDUSD.DWX`
- verdict: `FAIL`
- evidence: `D:/QM/reports/work_items/dcfcfe4c-3948-4836-a7d5-ea814148bb30/QM5_12532/Q04/NZDUSD.DWX/aggregate.json`

The Q04 aggregate reason is:

```text
F1:pf_net=0.000;F2:pf_net=0.000;F3:trades=0
```

Fold details:

- F1 2023 OOS: 7 aggregate trades, `gross_total=-455.4`, `sim_commission_total=14.65`, `pf_net=0.0`
- F2 2024 OOS: 5 aggregate trades, `gross_total=-217.39`, `sim_commission_total=13.0`, `pf_net=0.0`
- F3 2025 OOS: `NO_HISTORY` / `BARS_ZERO` / `HISTORY_CONTEXT_INVALID`, 0 trades

The known multi-day swap caveat is real for this family, and `PORTFOLIO_GAP_DIRECTED_EDGES_2026-06-21.md` calls it out. However, the current Q04 evidence is not a clean swap-only failure: the completed 2023 and 2024 folds are already negative before adding any modeled swap, and the 2025 fold is an infrastructure/history failure. Treating `QM5_12532` as dead solely because of this Q04 row would be too strong, but treating it as merely a swap-model false fail would also be unsupported.

## Required Next Action

To complete the requested `QM5_12533` basket re-enqueue without bypassing pipeline controls:

1. Add the logical host basket setfile for `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` using the EURJPY.DWX host configuration and compliant backtest risk settings.
2. Run/record the mandatory review after the basket manifest and logical setfile are present.
3. Once the predecessor `ea_review` verdict is `APPROVE_FOR_BACKTEST`, rerun:

```powershell
python C:\QM\repo\tools\strategy_farm\farmctl.py enqueue-backtest --review-task-id <approved_review_task_id> --phase Q02
```

Expected result after those blockers are cleared: exactly one pending Q02 work item with `symbol=QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`, `portfolio_scope=basket`, `host_symbol=EURJPY.DWX`, and the manifest path in payload JSON.
