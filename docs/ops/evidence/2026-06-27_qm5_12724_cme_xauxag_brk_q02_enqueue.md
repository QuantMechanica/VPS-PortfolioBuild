# QM5_12724 CME XAU/XAG Breakout Basket - Q02 Enqueue Evidence

Date: 2026-06-27
Branch: agents/board-advisor
EA: QM5_12724_cme-xauxag-brk
Strategy source id: CME-GSR-SPREAD-2025

## Scope

Completed and enqueued a low-frequency structural precious-metals relative-value
basket on `XAUUSD.DWX` and `XAGUSD.DWX`.

The signal is `ln(XAUUSD.DWX) - beta * ln(XAGUSD.DWX)`. A D1 upside channel
break opens long XAU plus short XAG; a downside channel break opens short XAU
plus long XAG. This is intentionally different from the existing XAU/XAG
z-score reversion basket (`QM5_12577`) and from oil/gold, oil/silver, XTI/XNG,
WTI event/calendar, XNG, and RSI commodity sleeves.

No `T_Live` files, AutoTrading settings, deploy manifests, or portfolio gate
files were touched.

## Artifacts

- Card: `strategy-seeds/cards/approved/QM5_12724_cme-xauxag-brk_card.md`
- EA source: `framework/EAs/QM5_12724_cme-xauxag-brk/QM5_12724_cme-xauxag-brk.mq5`
- Compiled EA: `framework/EAs/QM5_12724_cme-xauxag-brk/QM5_12724_cme-xauxag-brk.ex5`
- Spec: `framework/EAs/QM5_12724_cme-xauxag-brk/SPEC.md`
- Basket manifest: `framework/EAs/QM5_12724_cme-xauxag-brk/basket_manifest.json`
- Q02 setfile: `framework/EAs/QM5_12724_cme-xauxag-brk/sets/QM5_12724_cme-xauxag-brk_QM5_12724_XAU_XAG_BRK_D1_D1_backtest.set`

Registry rows already present:

- `framework/registry/ea_id_registry.csv`: `12724,cme-xauxag-brk,CME-GSR-SPREAD-2025,active,Development,2026-06-27`
- `framework/registry/magic_numbers.csv`: slots 0 and 1 for `XAUUSD.DWX` and `XAGUSD.DWX`

## Validation

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12724_cme-xauxag-brk`
  - Result: `PASS  QM5_12724_cme-xauxag-brk`
- `python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/approved/QM5_12724_cme-xauxag-brk_card.md`
  - Result: `status=ok`, `ml_hits=[]`, `missing_sections=[]`
- `pwsh -File framework/scripts/build_check.ps1 -EALabel QM5_12724_cme-xauxag-brk`
  - Result: PASS, failures 0
  - Compile: PASS, errors 0, warnings 0
  - Compile log: `C:\QM\repo\framework\build\compile\20260627_190918\QM5_12724_cme-xauxag-brk.compile.log`
  - Compiled EX5: `C:\QM\repo\framework\EAs\QM5_12724_cme-xauxag-brk\QM5_12724_cme-xauxag-brk.ex5`
  - Build-check report: `D:\QM\reports\framework\21\build_check_20260627_190918.json`
  - Warnings: 16 existing shared-framework DWX advisory warnings

## Q02 Queue

Farm state backup before enqueue:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12724_q02_enqueue_20260627_191025Z.sqlite`

Enqueued work item:

- ID: `932ad00e-bcf5-4666-8725-294f4fcbb13a`
- Phase: `Q02`
- Kind: `backtest`
- Status: `pending`
- Symbol: `QM5_12724_XAU_XAG_BRK_D1`
- Timeframe: `D1`
- Setfile: `QM5_12724_cme-xauxag-brk_QM5_12724_XAU_XAG_BRK_D1_D1_backtest.set`
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Portfolio scope: `basket`

No manual MT5 backtest was launched in this step.
