# QM5_12736 WTI Roll Fade Q02 Enqueue - 2026-06-28

Scope: branch `agents/board-advisor`; no `T_Live`, deploy manifest, portfolio
gate, or AutoTrading changes.

## Built

- `QM5_12736_wti-roll-fade`
  - Edge: `XTIUSD.DWX` D1 structural ETF roll-pressure short sleeve.
  - Source lineage: official CFTC Office of the Chief Economist paper
    `CFTC-ETF-ROLL-WTI-2014`, "Predatory or Sunshine Trading? Evidence from
    Crude Oil ETF Rolls".
  - Runtime data: Darwinex MT5 OHLC and broker calendar only; no ETF feed,
    futures curve, CFTC feed, COT data, CSV, API, ML, grid, or martingale.
  - Logic: during broker D1 trading days 5-9 of the current month, short once
    per month only after prior D1 downside confirmation and a close below SMA;
    flatten by roll-window end, month change, SMA recovery, max hold, Friday
    close, or ATR hard stop.
  - Dedup: not WTI month/weekday, WPSR, refinery, hurricane, OPEC,
    CME-expiry breakout, CAD/oil, XTI/XNG, XAU/XAG, or XNG RSI commodity logic.
  - Risk: RISK_FIXED backtest setfile, `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Artifacts

- Source note: `strategy-seeds/sources/CFTC-ETF-ROLL-WTI-2014/source.md`
- Card: `strategy-seeds/cards/approved/QM5_12736_wti-roll-fade_card.md`
- Farm approved-card mirror:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12736_wti-roll-fade_card.md`
- EA source: `framework/EAs/QM5_12736_wti-roll-fade/QM5_12736_wti-roll-fade.mq5`
- Compiled EA: `framework/EAs/QM5_12736_wti-roll-fade/QM5_12736_wti-roll-fade.ex5`
- Spec: `framework/EAs/QM5_12736_wti-roll-fade/SPEC.md`
- Setfile:
  `framework/EAs/QM5_12736_wti-roll-fade/sets/QM5_12736_wti-roll-fade_XTIUSD.DWX_D1_backtest.set`
- Build result: `artifacts/qm5_12736_build_result.json`

## Registry

- `framework/registry/ea_id_registry.csv`:
  `12736,wti-roll-fade,CFTC-ETF-ROLL-WTI-2014,active,Research,2026-06-28`
- `framework/registry/magic_numbers.csv`:
  `12736,wti-roll-fade,0,XTIUSD.DWX,127360000,2026-06-28,Development,active`
- `framework/include/QM/QM_MagicResolver.mqh` regenerated with
  `update_magic_resolver.py`.

## Validation

- Compile:
  - command:
    `python tools/strategy_farm/compile_ea.py --ea-label QM5_12736_wti-roll-fade --force --json --fail-on-error`
  - result: `COMPILED`
  - errors: 0
  - warnings: 0
  - ex5 size: 280688 bytes
  - log:
    `framework/build/compile/20260628_064329/QM5_12736_wti-roll-fade.compile.log`
- Build check:
  - command:
    `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12736_wti-roll-fade -SkipCompile`
  - result: PASS
  - failures: 0
  - warnings: 16 existing shared-framework DWX advisory warnings
  - report: `D:/QM/reports/framework/21/build_check_20260628_064344.json`
- Symbol scope:
  - command:
    `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12736_wti-roll-fade --json --fail-on-leak`
  - result: `SINGLE_SYMBOL_OK`
- Spec validation:
  - command:
    `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12736_wti-roll-fade`
  - result: PASS
- Card schema lint:
  - command:
    `python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/approved/QM5_12736_wti-roll-fade_card.md`
  - result: `status=ok`, `ml_hits=[]`, `missing_sections=[]`
- Setfile hash:
  `a8a46a92446470eeab67660d2b2a90dccfa273148fff79f15ec9bf03cbc40f80`

## Q02 Queue

- Build task: `4b270fc0-08d5-4cc7-be77-6528b0535c46`
- `record-build` result: `recorded=true`, `new_status=done`,
  `smoke_result=deferred_p2_smoke`
- Q02 work item:

| Field | Value |
|---|---|
| Work item | `79b404c2-e8e7-4897-a56c-492502b3c087` |
| EA | `QM5_12736` |
| Symbol | `XTIUSD.DWX` |
| Timeframe | `D1` |
| Phase | `Q02` |
| Status at handoff | `pending` |
| Setfile | `QM5_12736_wti-roll-fade_XTIUSD.DWX_D1_backtest.set` |

No manual MT5 backtest was launched in this step. The paced worker fleet owns
Q02 dispatch.
