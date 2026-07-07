# QM5_13039 XTI Gasdraw Momentum Q02 Enqueue

Date: 2026-07-07
Branch: `agents/board-advisor`

## Scope

Built a new low-frequency commodity/energy sleeve:
`QM5_13039_xti-gasdraw-mom`.

- Target: `XTIUSD.DWX`
- Timeframe: D1
- Source lineage: official EIA weekly total gasoline stocks and Weekly
  Petroleum Status Report source family.
- Runtime data: `XTIUSD.DWX` price/ATR/SMA/calendar only. No external web,
  API, CSV, ML, grid, martingale, or banned indicators.
- Risk setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Non-Duplicate Rationale

This is not the already-built XAU/XAG ratio basket sleeve and not a second XNG
variant. It is also distinct from `QM5_13035_xti-prod-sup-brk`: that EA uses a
product-supplied demand-proxy Donchian breakout with symmetric seasonal
long/short logic. `QM5_13039` is long-only, gasoline-stock-pressure lineage,
driving-season only, and requires a short pullback followed by a bullish
Wednesday/Thursday WPSR-window reaction above a rising `SMA(50)`.

## Source Citations

- EIA weekly total gasoline stocks:
  https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WGTSTUS1
- EIA Weekly Petroleum Status Report:
  https://www.eia.gov/petroleum/supply/weekly/
- EIA petroleum data portal:
  https://www.eia.gov/petroleum/data.php

## Build Evidence

- Card lint:
  `python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/approved/QM5_13039_xti-gasdraw-mom_card.md`
  - Result: `status=ok`, no ML hits, no missing sections.
- SPEC validation:
  `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_13039_xti-gasdraw-mom`
  - Result: `PASS`.
- Symbol scope:
  `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_13039_xti-gasdraw-mom --json`
  - Result: `SINGLE_SYMBOL_OK`.
- Build guardrails:
  `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_13039_xti-gasdraw-mom`
  - Result: `PASS`.
- Magic resolver:
  `python framework/scripts/update_magic_resolver.py`
  - Result: resolver regenerated; warnings only for pre-existing missing old EA
    dirs `1001`, `1015`, and `1016`.
- Compile:
  `python tools/strategy_farm/compile_ea.py --ea-label QM5_13039_xti-gasdraw-mom --force --json --fail-on-error`
  - Verdict: `COMPILED`
  - Errors: 0
  - Warnings: 0
  - EX5: `C:\QM\repo\framework\EAs\QM5_13039_xti-gasdraw-mom\QM5_13039_xti-gasdraw-mom.ex5`
  - EX5 size: 316052 bytes
  - Compile log:
    `C:\QM\repo\framework\build\compile\20260707_134015\QM5_13039_xti-gasdraw-mom.compile.log`
- Strict build check:
  `powershell -NoProfile -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_13039_xti-gasdraw-mom -Strict -SkipCompile`
  - Result: `PASS`
  - Report: `D:\QM\reports\framework\21\build_check_20260707_134034.json`

## Q02 Queue Evidence

Command:

```powershell
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_13039 --queue-ceiling 10000 --max-part2-per-run 0
```

Result:

- `part1 never_tested: enqueued=1 skipped=0`
- Canonical sweep evidence:
  `D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json`
- Work item id: `acc9fd44-4bba-4233-b4ed-fabed4581b81`
- Phase/status: `Q02` / `pending`
- Symbol: `XTIUSD.DWX`
- Setfile:
  `C:\QM\repo\framework\EAs\QM5_13039_xti-gasdraw-mom\sets\QM5_13039_xti-gasdraw-mom_XTIUSD.DWX_D1_backtest.set`
- Enqueued at UTC: `2026-07-07T13:40:45+00:00`

## Constraints

No `T_Live` manifest, portfolio gate, AutoTrading setting, or live setfile was
touched. No backtest was launched by this build step.
