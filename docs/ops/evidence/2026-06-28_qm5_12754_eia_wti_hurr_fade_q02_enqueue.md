# QM5_12754 EIA WTI Hurricane Fade Q02 Enqueue - 2026-06-28

Scope: branch `agents/board-advisor`; no `T_Live`, deploy manifest, portfolio
gate, or AutoTrading changes.

## Built

- `QM5_12754_eia-wti-hurr-fade`
  - Edge: `XTIUSD.DWX` D1 structural hurricane-season failed-upside-spike fade.
  - Source lineage: official U.S. Energy Information Administration source
    `EIA-WTI-HURRICANE-2025`, "Refining industry risks from 2025 hurricane
    season".
  - Runtime data: Darwinex MT5 OHLC and broker calendar only; no EIA feed,
    hurricane feed, weather API, refinery data, inventory data, CSV, API, ML,
    grid, or martingale.
  - Logic: during broker D1 months August through October by default, short
    XTIUSD.DWX only after the prior D1 bar stretches above SMA, rejects the
    upside move, and closes bearish in the lower part of its range; flatten at
    the D1 mean, window end, max hold, Friday close, or ATR hard stop.
  - Dedup: not the existing WTI hurricane breakout, refinery turnaround fade,
    WPSR, OPEC, ETF roll, month/weekday, CAD/oil, XTI/XNG, XAU/XAG, or XNG RSI
    commodity logic.
  - Risk: RISK_FIXED backtest setfile, `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Artifacts

- Source note: `strategy-seeds/sources/EIA-WTI-HURRICANE-2025/index.md`
- Card: `strategy-seeds/cards/approved/QM5_12754_eia-wti-hurr-fade_card.md`
- Farm approved-card mirror:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12754_eia-wti-hurr-fade_card.md`
- EA source:
  `framework/EAs/QM5_12754_eia-wti-hurr-fade/QM5_12754_eia-wti-hurr-fade.mq5`
- Compiled EA:
  `framework/EAs/QM5_12754_eia-wti-hurr-fade/QM5_12754_eia-wti-hurr-fade.ex5`
- Spec: `framework/EAs/QM5_12754_eia-wti-hurr-fade/SPEC.md`
- Setfile:
  `framework/EAs/QM5_12754_eia-wti-hurr-fade/sets/QM5_12754_eia-wti-hurr-fade_XTIUSD.DWX_D1_backtest.set`
- Build result: `artifacts/qm5_12754_build_result.json`

## Registry

- `framework/registry/ea_id_registry.csv`:
  `12754,eia-wti-hurr-fade,EIA-WTI-HURRICANE-2025,active,Development,2026-06-28`
- `framework/registry/magic_numbers.csv`:
  `12754,eia-wti-hurr-fade,0,XTIUSD.DWX,127540000,2026-06-28,Development,active`
- `framework/include/QM/QM_MagicResolver.mqh` regenerated with
  `update_magic_resolver.py`.

## Validation

- Compile:
  - command:
    `python tools/strategy_farm/compile_ea.py --ea-label QM5_12754_eia-wti-hurr-fade --force --json --fail-on-error`
  - result: `COMPILED`
  - errors: 0
  - warnings: 0
  - ex5 size: 284870 bytes
  - log:
    `framework/build/compile/20260628_183827/QM5_12754_eia-wti-hurr-fade.compile.log`
- Build check:
  - command:
    `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12754_eia-wti-hurr-fade -SkipCompile`
  - result: PASS
  - failures: 0
  - warnings: 16 existing shared-framework DWX advisory warnings
  - report: `D:/QM/reports/framework/21/build_check_20260628_183842.json`
- Symbol scope:
  - command:
    `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12754_eia-wti-hurr-fade --json --fail-on-leak`
  - result: `SINGLE_SYMBOL_OK`
- Spec validation:
  - command:
    `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12754_eia-wti-hurr-fade`
  - result: PASS
- Card schema lint:
  - command:
    `python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/approved/QM5_12754_eia-wti-hurr-fade_card.md`
  - result: `status=ok`, `ml_hits=[]`, `missing_sections=[]`
- Setfile hash:
  `441b287bd63e2ad8de3b416fb1d37e8df787688c94232360e2fc58ff832100c8`

## Q02 Queue

- Build task: `185dd7bb-42a2-4df2-82e9-43ea56f01aff`
- `record-build` result: `recorded=true`, `new_status=done`,
  `smoke_result=deferred_p2_smoke`
- Q02 work item:

| Field | Value |
|---|---|
| Work item | `feb22651-727c-4a2e-8672-62c1cd9e61d7` |
| EA | `QM5_12754` |
| Symbol | `XTIUSD.DWX` |
| Timeframe | `D1` |
| Phase | `Q02` |
| Status at handoff | `pending` |
| Setfile | `QM5_12754_eia-wti-hurr-fade_XTIUSD.DWX_D1_backtest.set` |

No manual MT5 backtest was launched in this step. The paced worker fleet owns
Q02 dispatch.
