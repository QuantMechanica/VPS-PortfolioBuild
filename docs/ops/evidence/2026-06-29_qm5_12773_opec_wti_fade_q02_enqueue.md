# QM5_12773 OPEC WTI Post-Window Fade Q02 Enqueue Evidence

Date: 2026-06-29
Branch: agents/board-advisor
EA: `QM5_12773_opec-wti-fade`
Strategy source id: `OPEC-WTI-POSTFADE-2026`

## Scope

Built and enqueued a low-frequency structural WTI energy sleeve on
`XTIUSD.DWX`.

The rule scans the June/December OPEC risk window, days 1-14, for a qualifying
D1 impulse. During days 15-24 it fades stretched same-direction follow-through
when price is ATR-stretched away from SMA(50). Runtime data is Darwinex MT5
OHLC plus broker calendar only.

This is intentionally different from `QM5_12598_opec-wti-brk`, which follows
Donchian breakouts inside the event window. `QM5_12773` waits until after that
window and takes the opposite side of stretched continuation.

No `T_Live` files, AutoTrading settings, deploy manifests, or portfolio gate
files were touched.

## Artifacts

- Card: `strategy-seeds/cards/approved/QM5_12773_opec-wti-fade_card.md`
- EA source: `framework/EAs/QM5_12773_opec-wti-fade/QM5_12773_opec-wti-fade.mq5`
- Compiled EA: `framework/EAs/QM5_12773_opec-wti-fade/QM5_12773_opec-wti-fade.ex5`
- Spec: `framework/EAs/QM5_12773_opec-wti-fade/SPEC.md`
- Q02 setfile: `framework/EAs/QM5_12773_opec-wti-fade/sets/QM5_12773_opec-wti-fade_XTIUSD.DWX_D1_backtest.set`

Registry rows:

- `framework/registry/ea_id_registry.csv`: `12773,opec-wti-fade,OPEC-WTI-POSTFADE-2026,active,Development,2026-06-29`
- `framework/registry/magic_numbers.csv`: `12773,opec-wti-fade,0,XTIUSD.DWX,127730000,2026-06-29,Development,active`

## Validation

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12773_opec-wti-fade`
  - Result: `PASS  QM5_12773_opec-wti-fade`
- `python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/approved/QM5_12773_opec-wti-fade_card.md`
  - Result: `status=ok`, `ml_hits=[]`, `missing_sections=[]`
- `python framework/scripts/update_magic_resolver.py`
  - Result: PASS, resolver regenerated with 13,681 rows, registry sha prefix `B4D191334AE90607`
- `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12773_opec-wti-fade/QM5_12773_opec-wti-fade.mq5 -Strict`
  - Result: PASS, 0 errors, 0 warnings
  - Compile log: `C:\QM\repo\framework\build\compile\20260629_100924\QM5_12773_opec-wti-fade.compile.log`
- `framework/scripts/build_check.ps1 -EALabel QM5_12773_opec-wti-fade -Strict -SkipCompile`
  - Result: PASS, failures 0
  - Warnings: 16 existing shared-framework DWX advisory warnings
  - Build-check report: `D:\QM\reports\framework\21\build_check_20260629_100941.json`
- `.mq5` SHA256: `cbf6e9863cc412ce1853dbcf571b6c43adac6dbaac5f7c3203afba49f5d3dbe8`
- `.ex5` SHA256: `1098f11a0ead0ce20ef560c88fd7b7452e1cdd3624d296c238b98307e93328d4`

## Q02 Queue

Enqueue command:

`python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_12773 --queue-ceiling 10000`

Farm evidence JSON:

`D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json`

Enqueued work item:

- ID: `7a4dfd78-0270-44e1-8225-35bf6d3d3ae2`
- Phase: `Q02`
- Kind: `backtest`
- Status: `pending`
- Symbol/timeframe: `XTIUSD.DWX` / D1
- Setfile: `C:\QM\repo\framework\EAs\QM5_12773_opec-wti-fade\sets\QM5_12773_opec-wti-fade_XTIUSD.DWX_D1_backtest.set`
- Backtest risk settings: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`

No manual MT5 backtest was launched in this step.
