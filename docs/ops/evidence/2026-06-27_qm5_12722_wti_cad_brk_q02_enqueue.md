# QM5_12722 WTI/CAD Breakout Basket - Q02 Enqueue Evidence

Date: 2026-06-27
Branch: agents/board-advisor
EA: QM5_12722_wti-cad-brk
Strategy source id: BOC-CAD-OIL-BRK-2026

## Scope

Built a new low-frequency structural commodity/energy sleeve as a two-leg
market-neutral basket on `XTIUSD.DWX` and `USDCAD.DWX`.

The signal is `ln(XTIUSD.DWX) - beta * ln(USDCAD.DWX)`. A D1 upside channel
break opens long WTI plus short USDCAD; a downside channel break opens short WTI
plus long USDCAD. This is intentionally different from the existing WTI/CAD
mean-reversion basket (`QM5_12609`) and WTI-only CAD-confirmation edge
(`QM5_12607`).

No `T_Live` files, AutoTrading settings, deploy manifests, or portfolio gate
files were touched.

## Artifacts

- Card: `strategy-seeds/cards/approved/QM5_12722_wti-cad-brk_card.md`
- EA source: `framework/EAs/QM5_12722_wti-cad-brk/QM5_12722_wti-cad-brk.mq5`
- Compiled EA: `framework/EAs/QM5_12722_wti-cad-brk/QM5_12722_wti-cad-brk.ex5`
- Spec: `framework/EAs/QM5_12722_wti-cad-brk/SPEC.md`
- Basket manifest: `framework/EAs/QM5_12722_wti-cad-brk/basket_manifest.json`
- Q02 setfile: `framework/EAs/QM5_12722_wti-cad-brk/sets/QM5_12722_wti-cad-brk_QM5_12722_XTI_USDCAD_BRK_D1_D1_backtest.set`

Registry rows present:

- `framework/registry/ea_id_registry.csv`: `12722,wti-cad-brk,BOC-CAD-OIL-BRK-2026,active,Development,2026-06-27`
- `framework/registry/magic_numbers.csv`: slots 0 and 1 for `XTIUSD.DWX` and `USDCAD.DWX`

## Validation

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12722_wti-cad-brk`
  - Result: `SPEC_DOC_VALIDATION passed=1 failed=0`
- `python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/approved/QM5_12722_wti-cad-brk_card.md`
  - Result: `status=ok`, `ml_hits=[]`, `missing_sections=[]`
- `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12722_wti-cad-brk/QM5_12722_wti-cad-brk.mq5 -Strict`
  - Result: PASS, errors 0, warnings 0
  - Compile log: `C:\QM\repo\framework\build\compile\20260627_182346\QM5_12722_wti-cad-brk.compile.log`
  - Summary: `D:\QM\reports\compile\20260627_182346\summary.csv`
- `framework/scripts/build_check.ps1 -EALabel QM5_12722_wti-cad-brk -Strict -SkipCompile`
  - Result: PASS, failures 0
  - Warnings: 16 framework include advisories
  - Report: `D:\QM\reports\framework\21\build_check_20260627_182419.json`

## Q02 Queue

Farm state backup before enqueue:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12722_q02_enqueue_20260627_182453Z.sqlite`

Enqueued work item:

- ID: `b5ed6711-65f2-472a-8f6-bd24c874c4ef`
- Phase: `Q02`
- Kind: `backtest`
- Status: `pending`
- Symbol: `QM5_12722_XTI_USDCAD_BRK_D1`
- Timeframe: `D1`
- Setfile: `QM5_12722_wti-cad-brk_QM5_12722_XTI_USDCAD_BRK_D1_D1_backtest.set`

No manual MT5 backtest was launched in this step.
