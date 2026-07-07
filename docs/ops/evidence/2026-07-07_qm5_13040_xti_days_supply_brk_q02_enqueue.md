# QM5_13040 XTI Days-of-Supply Breakout Q02 Enqueue

Date: 2026-07-07  
Branch: `agents/board-advisor`

## Scope

Built a new low-frequency energy sleeve:
`QM5_13040_xti-days-supply-brk`.

- Target: `XTIUSD.DWX`
- Timeframe: D1
- Source lineage: official EIA crude-oil days-of-supply series and Weekly
  Petroleum Status Report.
- Runtime data: `XTIUSD.DWX` price, ATR, SMA, spread, and broker calendar only.
- Risk setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Non-Duplicate Rationale

This is a monthly capped tight-stock-cover breakout proxy. It is not the
existing XAU/XAG basket, not `QM5_12567` commodity RSI logic, and not a second
XNG sleeve. Within WTI, it is not WPSR two-event momentum, one-bar
aftershock/fade/pre-event/inside-bar logic, field production, product-supplied
demand, gasoline-stock pressure, SPR, Cushing, refinery, hurricane, OPEC/IEA,
DPR/PSM/STEO, COT, rig-count, roll/expiry, month-only seasonality, WTI/Brent,
XTI/XNG, or oil-metal relative value.

## Source Citations

- EIA crude oil days of supply:
  https://www.eia.gov/dnav/pet/PET_SUM_SNDW_A_EPC0_VSD_DAYS_W.htm
- EIA Weekly Petroleum Status Report:
  https://www.eia.gov/petroleum/supply/weekly/

## Build Evidence

- Card lint:
  `python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/xti-days-supply-brk_card.md`
  - Result: `status=ok`, no ML hits, no missing sections.
- Approved card lint:
  `python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/approved/QM5_13040_xti-days-supply-brk_card.md`
  - Result: `status=ok`, no ML hits, no missing sections.
- SPEC validation:
  `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_13040_xti-days-supply-brk`
  - Result: `PASS`.
- Symbol scope:
  `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_13040_xti-days-supply-brk --json`
  - Result: `SINGLE_SYMBOL_OK`.
- Build guardrails:
  `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_13040_xti-days-supply-brk`
  - Result: `PASS`.
- Magic resolver:
  `python framework/scripts/update_magic_resolver.py`
  - Result: resolver regenerated; warnings only for pre-existing missing old EA
    dirs `1001`, `1015`, and `1016`.
- Compile:
  `python tools/strategy_farm/compile_ea.py --ea-label QM5_13040_xti-days-supply-brk --force --json --fail-on-error`
  - Verdict: `COMPILED`
  - Errors: 0
  - Warnings: 0
  - EX5: `C:\QM\repo\framework\EAs\QM5_13040_xti-days-supply-brk\QM5_13040_xti-days-supply-brk.ex5`
  - EX5 size: 317246 bytes
  - Compile log:
    `C:\QM\repo\framework\build\compile\20260707_144029\QM5_13040_xti-days-supply-brk.compile.log`
- Strict build check:
  `powershell -NoProfile -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_13040_xti-days-supply-brk -Strict -SkipCompile`
  - Result: `PASS`, 0 failures, 0 warnings
  - Report: `D:\QM\reports\framework\21\build_check_20260707_144048.json`

## Q02 Queue Evidence

Command:

```powershell
python tools\strategy_farm\sweep_enqueue_built_eas.py --apply --ea QM5_13040 --queue-ceiling 10000 --max-part2-per-run 0
```

Result:

- `part1 never_tested: enqueued=1 skipped=0`
- Canonical sweep evidence:
  `D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json`
- Work item id: `41d48215-b002-48a0-b2f1-bd6ef319d9e9`
- Phase/status: `Q02` / `pending`
- Symbol: `XTIUSD.DWX`
- Setfile:
  `C:\QM\repo\framework\EAs\QM5_13040_xti-days-supply-brk\sets\QM5_13040_xti-days-supply-brk_XTIUSD.DWX_D1_backtest.set`
- Enqueued at UTC: `2026-07-07T14:41:01+00:00`

## Constraints

No `T_Live` manifest, portfolio gate, AutoTrading setting, or live setfile was
touched. No backtest was launched by this build step.
