# QM5_12814 WTI USD Confirm Build And Q02 Enqueue

Date: 2026-06-30
Branch: `agents/board-advisor`

## Edge Selected

Built `QM5_12814_wti-usd-confirm`: a low-frequency structural WTI sleeve on
`XTIUSD.DWX` confirmed by closed-bar `EURUSD.DWX` direction as a broad USD
weakness/strength proxy.

Source lineage is `EIA-OIL-USD-FX-2017`, the U.S. Energy Information
Administration working paper "The Relationship between Oil Prices and Exchange
Rates". Runtime data is limited to Darwinex MT5 D1 OHLC and broker calendar
state; the EA does not read EIA data, DXY, APIs, CSV files, futures curves, or
external macro feeds.

## Duplicate Review

- XAU/XAG ratio reversion is already built as `QM5_12577`; XAU/XAG breakout is
  already built as `QM5_12724`.
- Existing WTI/CAD builds are `QM5_12607`, `QM5_12609`, and `QM5_12722`; this
  build uses EURUSD as a broad USD proxy and trades only XTIUSD.
- Existing WTI families cover weekday/month seasonality, WPSR, OPEC, refinery,
  hurricane, expiry/roll, driving season, distillate, SPR, TSMOM, reversal,
  volatility-contraction, and XTI/XNG or oil/metal ratios. This build is not an
  event/calendar or basket sleeve.
- Existing XNG sleeves include RSI/pullback, seasonality, storage, weather, LNG,
  TSMOM, and weekend-gap concepts. This build adds WTI crude exposure.

## Artifacts

- Source: `strategy-seeds/sources/EIA-OIL-USD-FX-2017/source.md`
- Card: `strategy-seeds/cards/approved/QM5_12814_wti-usd-confirm_card.md`
- EA: `framework/EAs/QM5_12814_wti-usd-confirm/QM5_12814_wti-usd-confirm.mq5`
- EX5: `framework/EAs/QM5_12814_wti-usd-confirm/QM5_12814_wti-usd-confirm.ex5`
- SPEC: `framework/EAs/QM5_12814_wti-usd-confirm/SPEC.md`
- Setfile: `framework/EAs/QM5_12814_wti-usd-confirm/sets/QM5_12814_wti-usd-confirm_XTIUSD.DWX_D1_backtest.set`
- Registry rows:
  - `framework/registry/ea_id_registry.csv`: `12814,wti-usd-confirm,...`
  - `framework/registry/magic_numbers.csv`: slot 0 `XTIUSD.DWX`, magic `128140000`

## Validation

- `python framework\scripts\skill_card_schema_lint.py --card strategy-seeds\cards\approved\QM5_12814_wti-usd-confirm_card.md`
  - PASS: status ok, no ML hits, no missing sections.
- `python framework\scripts\validate_spec_doc.py framework\EAs\QM5_12814_wti-usd-confirm`
  - PASS: 1 PASS, 0 FAIL.
- `python tools\strategy_farm\validate_symbol_scope.py --ea-label QM5_12814_wti-usd-confirm --verbose --fail-on-leak`
  - PASS: `SINGLE_SYMBOL_OK`, `n_violations=0`.
  - Note: `strategy_usd_proxy_symbol` is read-only and appears as an unresolved variable arg, not as a traded-symbol leak.
- `powershell -ExecutionPolicy Bypass -File framework\scripts\compile_one.ps1 -EALabel QM5_12814_wti-usd-confirm -Strict`
  - PASS: 0 errors, 0 warnings, `.ex5` produced.
  - Compile log: `C:\QM\repo\framework\build\compile\20260630_035547\QM5_12814_wti-usd-confirm.compile.log`
- `powershell -ExecutionPolicy Bypass -File framework\scripts\build_check.ps1 -EALabel QM5_12814_wti-usd-confirm -Strict -SkipCompile`
  - PASS: 0 failures.
  - Warnings: 16 shared-framework lazy-indicator advisories under `framework/include/QM/`, matching recent builds.
  - Build check report: `D:\QM\reports\framework\21\build_check_20260630_035601.json`

## Q02 Enqueue

Command:

```powershell
python tools\strategy_farm\sweep_enqueue_built_eas.py --apply --ea QM5_12814 --queue-ceiling 10000 --max-part2-per-run 0
```

Result:

- `part1 never_tested: enqueued=1 skipped=0`
- Work item: `53915b9e-c6b6-4532-84c7-92909e3c7599`
- Farm DB: `D:\QM\strategy_farm\state\farm_state.sqlite`
- Phase: `Q02`
- EA: `QM5_12814`
- Symbol: `XTIUSD.DWX`
- Status: `pending`
- Created: `2026-06-30T03:56:25+00:00`
- Setfile: `C:\QM\repo\framework\EAs\QM5_12814_wti-usd-confirm\sets\QM5_12814_wti-usd-confirm_XTIUSD.DWX_D1_backtest.set`

No backtest was run in this build turn.

## Live Scope

No `T_Live` manifest, AutoTrading setting, deploy manifest, or portfolio gate
file was touched.
