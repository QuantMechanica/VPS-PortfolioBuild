# QM5_12806 XNG Reverse Weekend Build And Q02 Enqueue

Date: 2026-06-29
Branch: `agents/board-advisor`

## Edge Selected

Built `QM5_12806_xng-rev-weekend`: a structural low-frequency natural-gas
reverse-weekend sleeve on `XNGUSD.DWX`.

Source lineage is Hoelscher, Mbanga, and Nelson, "TGIF? The Weekend Effect in
Energy Commodities", Journal of Finance Issues. Runtime data is limited to
Darwinex MT5 D1 OHLC and broker calendar state.

## Duplicate Review

- XAU/XAG ratio candidates already exist as `QM5_12577_cme-xauxag-ratio` and
  `QM5_12724_cme-xauxag-brk`.
- XTI trend/seasonality candidates already exist across WTI TSMOM, roll,
  month-of-year, day-of-week, weekend, WPSR, OPEC, hurricane, refinery, SPR,
  CAD/oil, and XTI/XNG baskets.
- Existing XNG sleeves include RSI/pullback, broad seasonality, isolated
  seasonal windows, storage, hurricane, freeze-fade, LNG, storage id-breakout,
  weekend-gap continuation, four-week reversal, and 12-month TSMOM.
- This build is pure XNG reverse-weekend day-of-week logic: Monday long and
  Friday short, with no RSI, no weather gap/body trigger, no storage/event
  timing, no month-of-year map, no basket, and no metals/index exposure.

## Artifacts

- Card: `strategy-seeds/cards/approved/QM5_12806_xng-rev-weekend_card.md`
- EA: `framework/EAs/QM5_12806_xng-rev-weekend/QM5_12806_xng-rev-weekend.mq5`
- SPEC: `framework/EAs/QM5_12806_xng-rev-weekend/SPEC.md`
- Setfile: `framework/EAs/QM5_12806_xng-rev-weekend/sets/QM5_12806_xng-rev-weekend_XNGUSD.DWX_D1_backtest.set`
- Build result: `artifacts/qm5_12806_build_result.json`

## Validation

- `python framework\scripts\skill_card_schema_lint.py --card strategy-seeds\cards\approved\QM5_12806_xng-rev-weekend_card.md`
  - PASS: status ok, no ML hits, no missing sections.
- `python framework\scripts\validate_spec_doc.py framework\EAs\QM5_12806_xng-rev-weekend`
  - PASS: 1 PASS, 0 FAIL.
- `python tools\strategy_farm\validate_symbol_scope.py --ea-label QM5_12806_xng-rev-weekend --verbose --fail-on-leak`
  - PASS: SINGLE_SYMBOL_OK, n_violations=0.
- `powershell -ExecutionPolicy Bypass -File framework\scripts\compile_one.ps1 -EALabel QM5_12806_xng-rev-weekend -Strict`
  - PASS: 0 errors, 0 warnings, `.ex5` produced.
  - log: `C:/QM/repo/framework/build/compile/20260629_200741/QM5_12806_xng-rev-weekend.compile.log`
- `powershell -ExecutionPolicy Bypass -File framework\scripts\build_check.ps1 -EALabel QM5_12806_xng-rev-weekend -Strict -SkipCompile`
  - PASS: 0 failures.
  - warnings: 16 existing shared-framework DWX advisory warnings under
    `framework/include/QM/`.
  - report: `D:/QM/reports/framework/21/build_check_20260629_200754.json`
- `.mq5` SHA256: `77c436f72fc95c72d0efb5ea94cfe0f0749ff3fda55f8bb0ef101fac15afd89f`
- `.ex5` SHA256: `aac10467faa8619d745f15c69ee46d64ff0aa29623fa1567bce134ac619ba17e`

## Q02 Enqueue

Command:

```powershell
python tools\strategy_farm\sweep_enqueue_built_eas.py --apply --ea QM5_12806 --queue-ceiling 10000 --max-part2-per-run 0
```

Result:

- `part1 never_tested: enqueued=1 skipped=0`
- Work item: `6926273a-22be-40e5-aa81-9c60c7ef0ac1`
- Phase: `Q02`
- EA: `QM5_12806`
- Symbol: `XNGUSD.DWX`
- Status: `pending`
- Created: `2026-06-29T20:08:18+00:00`
- Setfile:
  `C:/QM/repo/framework/EAs/QM5_12806_xng-rev-weekend/sets/QM5_12806_xng-rev-weekend_XNGUSD.DWX_D1_backtest.set`
- Backtest risk settings: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

No backtest was run in this build turn.

## Live Scope

No `T_Live` manifest, AutoTrading setting, deploy manifest, or portfolio gate
file was touched.
