# QM5_12834 WTI/JPY Spread Q02 Enqueue Evidence

Date: 2026-06-30
Branch: agents/board-advisor

## Edge

- EA: `QM5_12834_wti-jpy-spread`
- Source/card: `EIA-BOJ-WTI-JPY-2026_S02`
- Logic: D1 two-leg relative-value basket, `ln(XTIUSD) - beta * ln(USDJPY)`.
- Q02 symbol: `QM5_12834_XTI_USDJPY_SPREAD_D1`
- Backtest risk: `RISK_FIXED=1000`

## Verification

- Compile: `python tools/strategy_farm/compile_ea.py --ea-label QM5_12834_wti-jpy-spread --force --json`
- Compile result: `COMPILED`, 0 errors, 0 warnings.
- EX5: `framework/EAs/QM5_12834_wti-jpy-spread/QM5_12834_wti-jpy-spread.ex5`
- Strict check: `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12834_wti-jpy-spread -Strict -SkipCompile`
- Strict check result: `PASS`, 0 failures, 16 framework include advisories.
- Build check report: `D:/QM/reports/framework/21/build_check_20260630_194024.json`

## Farm Handoff

- Runtime approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12834_wti-jpy-spread_card.md`
- Build task: `17cc5722-006e-4267-b849-ecd328b3d308`
- Build result: `D:/QM/strategy_farm/artifacts/builds/17cc5722-006e-4267-b849-ecd328b3d308.json`
- `record-build` status: `done`
- Q02 work item: `5a0aefae-6e1d-41df-ab15-5746b2f2044e`
- Q02 status: `pending`

No `T_Live`, AutoTrading, or portfolio gate files were changed.
